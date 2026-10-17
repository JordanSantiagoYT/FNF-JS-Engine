#ifndef PHOENIX_PROFILER_H
#define PHOENIX_PROFILER_H

/*
 * Phoenix Engine - Native C/C++ Frame Profiler
 *
 * Header-only C99 / C++11+ library providing high-resolution monotonic timing,
 * arbitrary nested phase accounting (update, render, audio, GC) with both
 * exclusive and inclusive durations, managed heap delta tracking, configurable
 * low-overhead process RSS sampling, ring-buffer percentile statistics, and
 * atomic .log file export into debug/log/.
 *
 * ============================================================================
 * METRIC DEFINITIONS, UNITS, WINDOWS, AND LIMITATIONS
 * ============================================================================
 * 1. Frame Time (`frameTimeMs`, milliseconds):
 *    - End-to-end wall-clock duration of a completed frame.
 *    - Measured using the platform monotonic clock (`QueryPerformanceCounter`,
 *      `mach_absolute_time`, or `CLOCK_MONOTONIC`) as `max(workTimeMs,
 *      nowMs - lastFrameEndMs)` when consecutive frames are recorded, or
 *      `max(workTimeMs, explicitFrameTimeMs)` when an explicit frame interval
 *      is supplied by the caller.
 *    - Disabling and re-enabling the profiler resets `lastFrameEndMs` so time
 *      spent while disabled is never attributed to the first frame after resume.
 *
 * 2. Active Work Time (`workTimeMs`, milliseconds):
 *    - Monotonic duration between `beginFrame` and `endFrame` (`endMs - startMs`),
 *      excluding inter-frame sleep / vsync wait prior to `beginFrame`.
 *
 * 3. Subsystem Exclusive & Inclusive Timings (milliseconds):
 *    - Exclusive durations: `updateTimeMs`, `renderTimeMs`, `audioTimeMs`,
 *      `gcPauseMs`. Tracked via an explicit LIFO phase activation stack
 *      (`phaseStack`). Whenever any child phase completes inside an enclosing
 *      parent phase (e.g., Audio inside Update, Render inside Update during
 *      FFmpeg capture, or explicit GC inside Audio inside Update), the child's
 *      raw inclusive duration is subtracted from the immediate parent's
 *      exclusive time so nested durations are never double-counted.
 *    - Inclusive durations: `updateInclusiveMs`, `renderInclusiveMs`,
 *      `audioInclusiveMs`, `gcInclusiveMs`. Total wall-clock time spent inside
 *      the outermost activation(s) of each phase, including any nested child
 *      phases that ran within it.
 *    - Re-entrant calls to the same phase (`phaseDepth[phase] > 1`) are coalesced
 *      into the outermost activation of that phase.
 *    - `otherTimeMs = max(0, workTimeMs - (updateTimeMs + renderTimeMs +
 *      audioTimeMs + gcPauseMs))`.
 *
 * 4. Instantaneous, Rolling, Average, and Low-Percentile FPS (`fps`, `rollingFps`,
 *    `avgFps`, `onePercentLowFps`, `pointOnePercentLowFps`, `slowest1PctAvgFps`,
 *    `slowest01PctAvgFps`, frames per second):
 *    - `fps`: Instantaneous frame rate `1000.0 / frameTimeMs` for a single frame.
 *    - `rollingFps`: Harmonic mean FPS (`rollingWindowCount * 1000.0 /
 *      rollingWindowMs`) over the trailing ~1000 ms sliding window of completed
 *      frames, maintained in O(1) amortized time.
 *    - `avgFps`: Session-wide harmonic mean FPS (`totalFrames * 1000.0 /
 *      sessionDurationMs`) across all recorded frames since init/reset.
 *    - Percentiles (`p50FrameTimeMs`, `p95FrameTimeMs`, `p99FrameTimeMs`,
 *      `p999FrameTimeMs`): Computed over the ring buffer (up to
 *      `PHOENIX_PROFILER_RING_CAPACITY = 2048` most recent frames) using
 *      Hyndman-Fan Type 7 linear interpolation (`pos = q * (N - 1)`).
 *    - `onePercentLowFps` and `pointOnePercentLowFps`: Defined as the reciprocal
 *      of the 99th and 99.9th percentile frame times (`1000.0 / p99FrameTimeMs`
 *      and `1000.0 / p999FrameTimeMs`).
 *    - `slowest1PctAvgFps` and `slowest01PctAvgFps`: Harmonic mean FPS of the
 *      slowest `ceil(0.01 * N)` and `ceil(0.001 * N)` buffered frames
 *      (`1000.0 / mean(slowest K frameTimeMs)`).
 *
 * 5. Garbage Collection & Heap Metrics (`gcPauseMs`, `gcCount`, `explicitGcCount`,
 *    `implicitGcCount`, `allocBytes`, `gcReclaimedBytes`, `netHeapDeltaBytes`):
 *    - `gcPauseMs`: Directly measured synchronous GC pause duration from
 *      `beginGC`/`endGC` (or `recordGCPause` with a positive measured duration).
 *      Negative heap deltas NEVER fabricate an estimated pause duration and NEVER
 *      subtract estimated time from `updateTimeMs`, `renderTimeMs`, or `audioTimeMs`.
 *    - `explicitGcCount` / `gcCount`: Count of directly measured GC pause events.
 *    - `implicitGcCount`: Count of observed negative heap-delta intervals outside
 *      an explicit `beginGC`/`endGC` scope (or `recordGCPause(..., isExplicit=0)`).
 *      Documented as an observed heap-contraction indicator rather than an exact
 *      count of internal GC cycles.
 *    - `allocBytes`: Sum of observed positive heap-usage deltas across phase
 *      boundaries within the frame, plus any explicit `recordAllocation` bytes.
 *    - `gcReclaimedBytes`: Sum of observed negative heap-usage deltas (`-delta`)
 *      across phase boundaries within the frame, plus any explicit reclaimed bytes.
 *    - `netHeapDeltaBytes`: `frameEndHeapBytes - frameStartHeapBytes`. For heap
 *      observations within a frame, `observedAllocBytes - observedReclaimedBytes
 *      == netHeapDeltaBytes`.
 *
 * 6. Process Memory (RSS) & CPU Utilization (`rssBytes`, `peakRssBytes`,
 *    `cpuTimeMs`, `cpuUtilizationPct`, `cpuNormalizedPct`):
 *    - Process RSS and peak RSS are sampled in a single pass once every
 *      `rssSampleIntervalFrames` frames (default: 60 frames, ~1s at 60 FPS)
 *      and on summary/export. `sample.rssSampled` is 1 when freshly sampled on
 *      that frame and 0 when carried forward from the previous sample.
 *    - Note: Platform RSS semantics differ slightly by OS (`WorkingSetSize` on
 *      Windows, `mach_task_basic_info.resident_size` on macOS/iOS, and
 *      `/proc/self/statm` resident pages + `getrusage.ru_maxrss` on Linux/Android).
 *    - `cpuTimeMs`: Process user + kernel CPU time consumed during the session.
 *    - `cpuUtilizationPct`: `(cpuTimeMs / sessionDurationMs) * 100.0` (single-core
 *      equivalent; can reach `100% * logicalCpuCount` across threads).
 *    - `cpuNormalizedPct`: `cpuUtilizationPct / logicalCpuCount` (`0-100%` of host
 *      logical CPU capacity).
 *    - `cpuTimeAvailable`, `rssAvailable`, `heapStatsAvailable`: Explicit flags
 *      (`1` = available, `0` = unavailable on current platform/mode).
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <errno.h>

#if defined(_WIN32) || defined(_WIN64)
  #ifndef WIN32_LEAN_AND_MEAN
    #define WIN32_LEAN_AND_MEAN
  #endif
  #ifndef NOMINMAX
    #define NOMINMAX
  #endif
  #include <windows.h>
  #include <psapi.h>
  #include <direct.h>
  #include <io.h>
  #if defined(_MSC_VER)
    #pragma comment(lib, "psapi.lib")
  #endif
#elif defined(__APPLE__) && defined(__MACH__)
  #include <mach/mach.h>
  #include <mach/mach_time.h>
  #include <sys/resource.h>
  #include <sys/stat.h>
  #include <sys/time.h>
  #include <unistd.h>
  #include <fcntl.h>
#elif defined(__linux__) || defined(__ANDROID__) || defined(__unix__) || defined(__POSIX__)
  #include <sys/resource.h>
  #include <sys/stat.h>
  #include <sys/time.h>
  #include <unistd.h>
  #include <fcntl.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef PHOENIX_PROFILER_RING_CAPACITY
  #define PHOENIX_PROFILER_RING_CAPACITY 2048
#endif

#ifndef PHOENIX_PROFILER_STATE_NAME_MAX
  #define PHOENIX_PROFILER_STATE_NAME_MAX 96
#endif

#ifndef PHOENIX_PROFILER_PATH_MAX
  #define PHOENIX_PROFILER_PATH_MAX 512
#endif

#ifndef PHOENIX_PROFILER_TOP_SLOWEST_COUNT
  #define PHOENIX_PROFILER_TOP_SLOWEST_COUNT 10
#endif

#ifndef PHOENIX_PROFILER_MAX_PHASE_STACK
  #define PHOENIX_PROFILER_MAX_PHASE_STACK 16
#endif

#ifndef PHOENIX_PROFILER_DEFAULT_RSS_SAMPLE_INTERVAL
  #define PHOENIX_PROFILER_DEFAULT_RSS_SAMPLE_INTERVAL 60
#endif

#ifndef PHOENIX_PROFILER_OVERLAY_SORT_INTERVAL
  #define PHOENIX_PROFILER_OVERLAY_SORT_INTERVAL 15
#endif

typedef enum PhoenixProfilerPhase
{
  PHOENIX_PHASE_UPDATE = 0,
  PHOENIX_PHASE_RENDER = 1,
  PHOENIX_PHASE_AUDIO  = 2,
  PHOENIX_PHASE_GC     = 3,
  PHOENIX_PHASE_COUNT  = 4
} PhoenixProfilerPhase;

typedef struct PhoenixPhaseStackEntry
{
  int phase;
  double startMs;
  double childDurationMs;
} PhoenixPhaseStackEntry;

typedef struct PhoenixFrameSample
{
  uint64_t frameIndex;
  double timestampMs;
  double frameTimeMs;
  double workTimeMs;
  double fps;
  double rollingFps;
  double updateTimeMs;
  double renderTimeMs;
  double audioTimeMs;
  double gcPauseMs;
  double otherTimeMs;
  double updateInclusiveMs;
  double renderInclusiveMs;
  double audioInclusiveMs;
  double gcInclusiveMs;
  int64_t allocBytes;
  uint32_t allocCount;
  int64_t gcReclaimedBytes;
  int64_t netHeapDeltaBytes;
  int64_t heapUsedBytes;
  int64_t heapReservedBytes;
  size_t rssBytes;
  size_t peakRssBytes;
  uint32_t gcCount;
  uint32_t explicitGcCount;
  uint32_t implicitGcCount;
  uint32_t drawCalls;
  uint32_t updateSteps;
  int rssSampled;
  char stateName[PHOENIX_PROFILER_STATE_NAME_MAX];
} PhoenixFrameSample;

typedef struct PhoenixProfilerSummary
{
  uint64_t totalFrames;
  size_t bufferedFrames;
  double sessionDurationMs;
  double targetFps;
  double targetFrameTimeMs;

  double currentFps;
  double avgFps;
  double minFps;
  double maxFps;
  double onePercentLowFps;
  double pointOnePercentLowFps;
  double slowest1PctAvgFps;
  double slowest01PctAvgFps;

  double lastFrameTimeMs;
  double avgFrameTimeMs;
  double minFrameTimeMs;
  double maxFrameTimeMs;
  double stdDevFrameTimeMs;
  double p50FrameTimeMs;
  double p95FrameTimeMs;
  double p99FrameTimeMs;
  double p999FrameTimeMs;

  double avgUpdateTimeMs;
  double maxUpdateTimeMs;
  double p95UpdateTimeMs;

  double avgRenderTimeMs;
  double maxRenderTimeMs;
  double p95RenderTimeMs;

  double avgAudioTimeMs;
  double maxAudioTimeMs;
  double p95AudioTimeMs;

  double avgOtherTimeMs;
  double maxOtherTimeMs;

  uint64_t totalGcCount;
  uint64_t totalExplicitGcCount;
  uint64_t totalImplicitGcCount;
  uint64_t framesWithGc;
  double totalGcPauseMs;
  double avgGcPauseMs;
  double maxGcPauseMs;
  uint64_t maxGcPauseFrame;
  uint64_t totalGcReclaimedBytes;

  uint64_t totalAllocBytes;
  uint64_t totalAllocCount;
  double avgAllocBytesPerFrame;
  double allocRateBytesPerSec;
  int64_t peakFrameAllocBytes;
  uint64_t peakFrameAllocFrame;
  int64_t currentHeapUsedBytes;
  int64_t currentHeapReservedBytes;
  int64_t peakHeapUsedBytes;
  int64_t peakHeapReservedBytes;
  size_t currentRssBytes;
  size_t peakRssBytes;

  uint64_t droppedFrames;
  uint64_t spikeCount16Ms;
  uint64_t spikeCount25Ms;
  uint64_t spikeCount33Ms;
  uint64_t spikeCount50Ms;
  double avgDrawCalls;
  uint32_t maxDrawCalls;

  double cpuTimeMs;
  double cpuUtilizationPct;
  double cpuNormalizedPct;
  int logicalCpuCount;
  int cpuTimeAvailable;
  int rssAvailable;
  int heapStatsAvailable;
  uint32_t rssSampleIntervalFrames;
} PhoenixProfilerSummary;

typedef struct PhoenixProfilerState
{
  int initialized;
  int enabled;
  int inFlightFrame;
  int exportInProgress;
  int collectMemoryMetrics;
  uint32_t rssSampleIntervalFrames;

  double targetFps;
  double sessionStartMs;
  double sessionStartCpuSec;
  int cpuClockValid;
  int rssAvailable;
  int heapStatsAvailable;
  int logicalCpuCount;

  double currentFrameStartMs;
  double lastFrameStartMs;
  double lastFrameEndMs;
  double currentRollingFps;
  double rollingWindowMs;
  size_t rollingWindowCount;

  uint64_t cachedOverlayFrame;
  double cachedOverlayP95Ms;
  double cachedOverlayP99Ms;

  PhoenixPhaseStackEntry phaseStack[PHOENIX_PROFILER_MAX_PHASE_STACK];
  int phaseStackSize;
  int phaseDepth[PHOENIX_PHASE_COUNT];

  int hasObservedHeap;
  int64_t lastObservedHeapBytes;
  int64_t frameStartHeapBytes;
  int64_t currentHeapUsedBytes;
  int64_t currentHeapReservedBytes;
  int64_t peakHeapUsedBytes;
  int64_t peakHeapReservedBytes;
  size_t lastSampledRssBytes;
  size_t lastSampledPeakRssBytes;

  uint64_t totalFrames;
  double sumFrameTimeMs;
  double sumSqFrameTimeMs;
  double minFrameTimeMs;
  double maxFrameTimeMs;

  double sumUpdateTimeMs;
  double maxUpdateTimeMs;
  double sumRenderTimeMs;
  double maxRenderTimeMs;
  double sumAudioTimeMs;
  double maxAudioTimeMs;
  double sumOtherTimeMs;
  double maxOtherTimeMs;

  uint64_t totalGcCount;
  uint64_t totalExplicitGcCount;
  uint64_t totalImplicitGcCount;
  uint64_t framesWithGc;
  double totalGcPauseMs;
  double maxGcPauseMs;
  uint64_t maxGcPauseFrame;
  uint64_t totalGcReclaimedBytes;

  uint64_t totalAllocBytes;
  uint64_t totalAllocCount;
  int64_t peakFrameAllocBytes;
  uint64_t peakFrameAllocFrame;

  uint64_t droppedFrames;
  uint64_t spikeCount16Ms;
  uint64_t spikeCount25Ms;
  uint64_t spikeCount33Ms;
  uint64_t spikeCount50Ms;
  uint64_t totalDrawCalls;
  uint32_t maxDrawCalls;

  char currentStateName[PHOENIX_PROFILER_STATE_NAME_MAX];
  size_t currentStateNameLen;
  PhoenixFrameSample activeSample;

  size_t ringWriteIndex;
  size_t ringCount;
  PhoenixFrameSample samples[PHOENIX_PROFILER_RING_CAPACITY];
} PhoenixProfilerState;

/* ============================================================================
 * Numeric & String Sanitization Helpers
 * ============================================================================ */

static inline int phoenixProfilerIsFinite(double value)
{
  /* In IEEE-754 floating point, NaN != NaN and Inf - Inf != 0.0 */
  return (value == value) && ((value - value) == 0.0);
}

static inline double phoenixProfilerSanitizeDuration(double value)
{
  if (!phoenixProfilerIsFinite(value) || value < 0.0)
    return 0.0;
  if (value > 86400000.0) /* Cap single duration at 24h to guard against corrupted clocks */
    return 86400000.0;
  return value;
}

static inline uint64_t phoenixProfilerSafeAddU64(uint64_t a, uint64_t b)
{
  return (UINT64_MAX - a < b) ? UINT64_MAX : (a + b);
}

static inline int64_t phoenixProfilerSafeAddI64(int64_t a, int64_t b)
{
  if (b > 0 && a > INT64_MAX - b)
    return INT64_MAX;
  if (b < 0 && a < INT64_MIN - b)
    return INT64_MIN;
  return a + b;
}

static inline int64_t phoenixProfilerSafeSubI64(int64_t a, int64_t b)
{
  if (b < 0 && a > INT64_MAX + b)
    return INT64_MAX;
  if (b > 0 && a < INT64_MIN + b)
    return INT64_MIN;
  return a - b;
}

/*
 * Copies `src` into `dst` (up to `capacity - 1` bytes) while preserving
 * printable characters (including commas and quotes) and normalizing ASCII
 * control characters (`\r`, `\n`, `\t`, `< 32`) to spaces so state names remain
 * safe in single-line headers and can be properly RFC 4180 escaped in CSV.
 */
static inline size_t phoenixProfilerCopyString(char *dst, size_t capacity, const char *src)
{
  size_t i = 0;
  if (dst == NULL || capacity == 0)
    return 0;

  if (src == NULL || src[0] == '\0')
  {
    src = "UnknownState";
  }

  while (i + 1 < capacity && src[i] != '\0')
  {
    unsigned char ch = (unsigned char)src[i];
    if (ch < 32 || ch == 127)
      dst[i] = ' ';
    else
      dst[i] = (char)ch;
    ++i;
  }
  dst[i] = '\0';
  return i;
}

/*
 * Formats `src` as a valid RFC 4180 CSV field into `dst`.
 * - Normalizes `\r` and `\n` to `' '` so line-oriented and RFC 4180 CSV parsers
 *   both see one record per line.
 * - If the field contains `,`, `"`, `\r`, `\n`, or leading/trailing spaces,
 *   encloses the field in double quotes `"..."` and escapes `"` as `""`.
 */
static inline void phoenixProfilerFormatCsvField(const char *src, char *dst, size_t capacity)
{
  int needsQuotes = 0;
  size_t i = 0;
  size_t outIdx = 0;
  size_t len = 0;

  if (dst == NULL || capacity == 0)
    return;

  if (src == NULL || src[0] == '\0')
  {
    src = "UnknownState";
  }

  while (src[len] != '\0')
  {
    char ch = src[len];
    if (ch == ',' || ch == '"' || ch == '\r' || ch == '\n')
      needsQuotes = 1;
    ++len;
  }
  if (len > 0 && (src[0] == ' ' || src[len - 1] == ' '))
    needsQuotes = 1;

  if (!needsQuotes)
  {
    phoenixProfilerCopyString(dst, capacity, src);
    return;
  }

  if (outIdx + 1 < capacity)
    dst[outIdx++] = '"';

  for (i = 0; i < len && outIdx + 2 < capacity; ++i)
  {
    unsigned char ch = (unsigned char)src[i];
    if (ch == '"')
    {
      if (outIdx + 3 < capacity)
      {
        dst[outIdx++] = '"';
        dst[outIdx++] = '"';
      }
      else
      {
        break;
      }
    }
    else if (ch < 32 || ch == 127)
    {
      dst[outIdx++] = ' ';
    }
    else
    {
      dst[outIdx++] = (char)ch;
    }
  }

  if (outIdx + 1 < capacity)
    dst[outIdx++] = '"';
  dst[outIdx] = '\0';
}

/* ============================================================================
 * High-Resolution Monotonic Clock & Platform Resource Queries
 * ============================================================================ */

static inline double phoenixProfilerNowMs(void)
{
#if defined(_WIN32) || defined(_WIN64)
  static LARGE_INTEGER sFrequency = {0};
  LARGE_INTEGER counter;
  if (sFrequency.QuadPart == 0)
  {
    if (!QueryPerformanceFrequency(&sFrequency) || sFrequency.QuadPart == 0)
      return (double)GetTickCount64();
  }
  QueryPerformanceCounter(&counter);
  return ((double)counter.QuadPart * 1000.0) / (double)sFrequency.QuadPart;
#elif defined(__APPLE__) && defined(__MACH__)
  static mach_timebase_info_data_t sTimebase = {0, 0};
  uint64_t ticks;
  if (sTimebase.denom == 0)
    (void)mach_timebase_info(&sTimebase);
  ticks = mach_absolute_time();
  return ((double)ticks * (double)sTimebase.numer) / ((double)sTimebase.denom * 1000000.0);
#elif defined(CLOCK_MONOTONIC)
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0)
    return ((double)ts.tv_sec * 1000.0) + ((double)ts.tv_nsec / 1000000.0);
  return ((double)clock() * 1000.0) / (double)CLOCKS_PER_SEC;
#else
  return ((double)clock() * 1000.0) / (double)CLOCKS_PER_SEC;
#endif
}

static inline int phoenixProfilerQueryCpuSeconds(double *outSeconds)
{
  if (outSeconds == NULL)
    return 0;
  *outSeconds = 0.0;

#if defined(_WIN32) || defined(_WIN64)
  FILETIME createTime, exitTime, kernelTime, userTime;
  ULARGE_INTEGER kernel, user;
  if (GetProcessTimes(GetCurrentProcess(), &createTime, &exitTime, &kernelTime, &userTime))
  {
    kernel.LowPart = kernelTime.dwLowDateTime;
    kernel.HighPart = kernelTime.dwHighDateTime;
    user.LowPart = userTime.dwLowDateTime;
    user.HighPart = userTime.dwHighDateTime;
    *outSeconds = (double)(kernel.QuadPart + user.QuadPart) * 1e-7;
    return 1;
  }
  return 0;
#elif defined(CLOCK_PROCESS_CPUTIME_ID)
  struct timespec ts;
  if (clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts) == 0)
  {
    *outSeconds = (double)ts.tv_sec + ((double)ts.tv_nsec * 1e-9);
    return 1;
  }
  {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) == 0)
    {
      *outSeconds = (double)usage.ru_utime.tv_sec + ((double)usage.ru_utime.tv_usec * 1e-6)
                  + (double)usage.ru_stime.tv_sec + ((double)usage.ru_stime.tv_usec * 1e-6);
      return 1;
    }
  }
  return 0;
#elif defined(__APPLE__) || defined(__linux__) || defined(__unix__)
  struct rusage usage;
  if (getrusage(RUSAGE_SELF, &usage) == 0)
  {
    *outSeconds = (double)usage.ru_utime.tv_sec + ((double)usage.ru_utime.tv_usec * 1e-6)
                + (double)usage.ru_stime.tv_sec + ((double)usage.ru_stime.tv_usec * 1e-6);
    return 1;
  }
  return 0;
#else
  return 0;
#endif
}

static inline double phoenixProfilerCpuSeconds(void)
{
  double sec = 0.0;
  (void)phoenixProfilerQueryCpuSeconds(&sec);
  return sec;
}

static inline int phoenixProfilerLogicalCpuCount(void)
{
#if defined(_WIN32) || defined(_WIN64)
  SYSTEM_INFO sysinfo;
  GetSystemInfo(&sysinfo);
  return sysinfo.dwNumberOfProcessors > 0 ? (int)sysinfo.dwNumberOfProcessors : 1;
#elif defined(_SC_NPROCESSORS_ONLN)
  long count = sysconf(_SC_NPROCESSORS_ONLN);
  return count > 0 ? (int)count : 1;
#else
  return 1;
#endif
}

/*
 * Queries both current RSS and peak RSS in a single pass to minimize syscall
 * overhead. Returns 1 if at least one RSS metric is available, 0 otherwise.
 */
static inline int phoenixProfilerSampleProcessMemory(size_t *outCurrentRss, size_t *outPeakRss)
{
  size_t currentRss = 0;
  size_t peakRss = 0;

#if defined(_WIN32) || defined(_WIN64)
  PROCESS_MEMORY_COUNTERS pmc;
  if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc)))
  {
    currentRss = (size_t)pmc.WorkingSetSize;
    peakRss = (size_t)pmc.PeakWorkingSetSize;
  }
#elif defined(__APPLE__) && defined(__MACH__)
  struct mach_task_basic_info info;
  mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS)
  {
    currentRss = (size_t)info.resident_size;
    peakRss = (size_t)info.resident_size_max;
  }
  {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) == 0 && usage.ru_maxrss > 0)
    {
      size_t rusagePeak = (size_t)usage.ru_maxrss; /* bytes on Darwin */
      if (rusagePeak > peakRss)
        peakRss = rusagePeak;
    }
  }
#elif defined(__linux__) || defined(__ANDROID__)
  static long sPageSize = 0;
  int fd;
  if (sPageSize <= 0)
  {
    sPageSize = sysconf(_SC_PAGESIZE);
    if (sPageSize <= 0)
      sPageSize = 4096;
  }
  fd = open("/proc/self/statm", O_RDONLY);
  if (fd >= 0)
  {
    char buf[128];
    ssize_t bytesRead = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (bytesRead > 0)
    {
      size_t idx = 0;
      uint64_t rssPages = 0;
      buf[bytesRead] = '\0';
      /* Skip first field (total program size) */
      while (buf[idx] == ' ' || buf[idx] == '\t')
        ++idx;
      while (buf[idx] >= '0' && buf[idx] <= '9')
        ++idx;
      while (buf[idx] == ' ' || buf[idx] == '\t')
        ++idx;
      /* Parse second field (resident set size in pages) */
      while (buf[idx] >= '0' && buf[idx] <= '9')
      {
        rssPages = (rssPages * 10ULL) + (uint64_t)(buf[idx] - '0');
        ++idx;
      }
      currentRss = (size_t)(rssPages * (uint64_t)sPageSize);
    }
  }
  {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) == 0 && usage.ru_maxrss > 0)
    {
      size_t rusagePeak = (size_t)usage.ru_maxrss * (size_t)1024; /* KiB on Linux */
      peakRss = rusagePeak;
    }
  }
#endif

  if (currentRss > peakRss)
    peakRss = currentRss;

  if (outCurrentRss != NULL)
    *outCurrentRss = currentRss;
  if (outPeakRss != NULL)
    *outPeakRss = peakRss;

  return (currentRss > 0 || peakRss > 0) ? 1 : 0;
}

static inline size_t phoenixProfilerCurrentRSS(void)
{
  size_t current = 0;
  (void)phoenixProfilerSampleProcessMemory(&current, NULL);
  return current;
}

static inline size_t phoenixProfilerPeakRSS(void)
{
  size_t peak = 0;
  (void)phoenixProfilerSampleProcessMemory(NULL, &peak);
  return peak;
}

/* ============================================================================
 * Internal Sorting & Statistical Helpers
 * ============================================================================ */

static inline void phoenixProfilerSiftDown(double *arr, size_t start, size_t end)
{
  size_t root = start;
  while ((root * 2 + 1) <= end)
  {
    size_t child = root * 2 + 1;
    size_t swapIdx = root;
    if (arr[swapIdx] < arr[child])
      swapIdx = child;
    if (child + 1 <= end && arr[swapIdx] < arr[child + 1])
      swapIdx = child + 1;
    if (swapIdx == root)
      return;
    {
      double tmp = arr[root];
      arr[root] = arr[swapIdx];
      arr[swapIdx] = tmp;
      root = swapIdx;
    }
  }
}

static inline void phoenixProfilerSortDoubles(double *arr, size_t count)
{
  size_t start;
  size_t end;
  if (arr == NULL || count < 2)
    return;

  start = (count - 2) / 2;
  while (1)
  {
    phoenixProfilerSiftDown(arr, start, count - 1);
    if (start == 0)
      break;
    --start;
  }

  end = count - 1;
  while (end > 0)
  {
    double tmp = arr[end];
    arr[end] = arr[0];
    arr[0] = tmp;
    --end;
    phoenixProfilerSiftDown(arr, 0, end);
  }
}

/*
 * Hyndman-Fan Type 7 linear interpolation quantile over ascending sorted array:
 * pos = percentile * (count - 1), interpolating linearly between floor(pos)
 * and ceil(pos).
 */
static inline double phoenixProfilerPercentileFromSorted(const double *sorted, size_t count, double percentile)
{
  double pos;
  size_t lower;
  size_t upper;
  double weight;

  if (sorted == NULL || count == 0)
    return 0.0;
  if (count == 1 || percentile <= 0.0)
    return sorted[0];
  if (percentile >= 1.0)
    return sorted[count - 1];

  pos = percentile * (double)(count - 1);
  lower = (size_t)pos;
  upper = lower + 1;
  if (upper >= count)
    return sorted[count - 1];
  weight = pos - (double)lower;
  return sorted[lower] * (1.0 - weight) + sorted[upper] * weight;
}

/*
 * Computes the harmonic mean FPS (`1000.0 / meanFrameTimeMs`) of the slowest
 * `ceil(tailFraction * count)` frames at the upper tail of `sortedFrameTimes`.
 */
static inline double phoenixProfilerSlowestTailMeanFps(const double *sortedFrameTimes, size_t count, double tailFraction)
{
  size_t tailCount;
  size_t i;
  double sumMs = 0.0;
  double avgMs;

  if (sortedFrameTimes == NULL || count == 0 || tailFraction <= 0.0)
    return 0.0;

  tailCount = (size_t)((tailFraction * (double)count) + 0.999999999);
  if (tailCount < 1)
    tailCount = 1;
  if (tailCount > count)
    tailCount = count;

  for (i = count - tailCount; i < count; ++i)
  {
    if (sortedFrameTimes[i] > 0.0)
      sumMs += sortedFrameTimes[i];
  }

  avgMs = sumMs / (double)tailCount;
  return avgMs > 0.0 ? (1000.0 / avgMs) : 0.0;
}

static inline double phoenixProfilerSqrt(double x)
{
  double guess;
  int i;
  if (!phoenixProfilerIsFinite(x) || x <= 0.0)
    return 0.0;
  guess = x > 1.0 ? x * 0.5 : 1.0;
  for (i = 0; i < 20; ++i)
    guess = 0.5 * (guess + (x / guess));
  return guess;
}

/*
 * Observes a managed heap measurement (`heapUsedBytes`) at a frame or phase
 * boundary.
 * - Positive delta (`heapUsedBytes > lastObservedHeapBytes`): Added to
 *   `activeSample.allocBytes` and increments `activeSample.allocCount`.
 * - Negative delta (`heapUsedBytes < lastObservedHeapBytes`): Added (`-delta`)
 *   to `activeSample.gcReclaimedBytes`. If outside an explicit `beginGC`/`endGC`
 *   phase, increments `activeSample.implicitGcCount` (observed heap contraction
 *   interval) without fabricating a GC pause duration or inflating `gcCount`.
 */
static inline void phoenixProfilerObserveHeap(
  PhoenixProfilerState *state,
  int64_t heapUsedBytes,
  int isExplicitGcEnd)
{
  int64_t delta;

  if (state == NULL || !state->collectMemoryMetrics || heapUsedBytes < 0)
    return;

  state->heapStatsAvailable = 1;
  state->currentHeapUsedBytes = heapUsedBytes;
  if (heapUsedBytes > state->peakHeapUsedBytes)
    state->peakHeapUsedBytes = heapUsedBytes;

  if (!state->hasObservedHeap)
  {
    state->lastObservedHeapBytes = heapUsedBytes;
    state->hasObservedHeap = 1;
    return;
  }

  delta = phoenixProfilerSafeSubI64(heapUsedBytes, state->lastObservedHeapBytes);
  state->lastObservedHeapBytes = heapUsedBytes;

  if (!state->inFlightFrame)
    return;

  if (delta > 0)
  {
    state->activeSample.allocBytes = phoenixProfilerSafeAddI64(state->activeSample.allocBytes, delta);
    state->activeSample.allocCount += 1;
  }
  else if (delta < 0)
  {
    int64_t reclaimed = phoenixProfilerSafeSubI64(0, delta);
    state->activeSample.gcReclaimedBytes = phoenixProfilerSafeAddI64(state->activeSample.gcReclaimedBytes, reclaimed);
    if (!isExplicitGcEnd && state->phaseDepth[PHOENIX_PHASE_GC] <= 0)
    {
      state->activeSample.implicitGcCount += 1;
    }
  }
}

/* ============================================================================
 * Lifecycle, Configuration, and Recording API
 * ============================================================================ */

static inline void phoenixProfilerReset(PhoenixProfilerState *state)
{
  double targetFps;
  int enabled;
  int collectMemory;
  uint32_t rssInterval;
  char savedStateName[PHOENIX_PROFILER_STATE_NAME_MAX];

  if (state == NULL)
    return;

  targetFps = (phoenixProfilerIsFinite(state->targetFps) && state->targetFps > 0.0) ? state->targetFps : 60.0;
  enabled = state->initialized ? state->enabled : 1;
  collectMemory = state->initialized ? state->collectMemoryMetrics : 1;
  rssInterval = state->initialized ? state->rssSampleIntervalFrames : (uint32_t)PHOENIX_PROFILER_DEFAULT_RSS_SAMPLE_INTERVAL;
  phoenixProfilerCopyString(savedStateName, sizeof(savedStateName),
    state->initialized ? state->currentStateName : "InitialState");

  memset(state, 0, sizeof(PhoenixProfilerState));

  state->initialized = 1;
  state->enabled = enabled;
  state->collectMemoryMetrics = collectMemory;
  state->rssSampleIntervalFrames = rssInterval;
  state->targetFps = targetFps;
  state->sessionStartMs = phoenixProfilerNowMs();
  state->cpuClockValid = phoenixProfilerQueryCpuSeconds(&state->sessionStartCpuSec);
  state->logicalCpuCount = phoenixProfilerLogicalCpuCount();
  state->minFrameTimeMs = 1e12;
  state->currentStateNameLen = phoenixProfilerCopyString(
    state->currentStateName, sizeof(state->currentStateName), savedStateName);
}

static inline void phoenixProfilerInit(PhoenixProfilerState *state, double targetFps)
{
  if (state == NULL)
    return;
  memset(state, 0, sizeof(PhoenixProfilerState));
  state->initialized = 1;
  state->enabled = 1;
  state->collectMemoryMetrics = 1;
  state->rssSampleIntervalFrames = (uint32_t)PHOENIX_PROFILER_DEFAULT_RSS_SAMPLE_INTERVAL;
  state->targetFps = (phoenixProfilerIsFinite(targetFps) && targetFps > 0.0) ? targetFps : 60.0;
  phoenixProfilerCopyString(state->currentStateName, sizeof(state->currentStateName), "InitialState");
  phoenixProfilerReset(state);
}

/*
 * Idempotent initialization helper: initializes `state` only if it has not
 * already been initialized; otherwise updates `targetFps` without clearing
 * collected samples or resetting counters.
 */
static inline void phoenixProfilerEnsureInit(PhoenixProfilerState *state, double targetFps)
{
  if (state == NULL)
    return;
  if (!state->initialized)
  {
    phoenixProfilerInit(state, targetFps);
  }
  else if (phoenixProfilerIsFinite(targetFps) && targetFps > 0.0)
  {
    state->targetFps = targetFps;
  }
}

static inline int phoenixProfilerIsInitialized(const PhoenixProfilerState *state)
{
  return (state != NULL && state->initialized) ? 1 : 0;
}

static inline int phoenixProfilerIsExportInProgress(const PhoenixProfilerState *state)
{
  return (state != NULL && state->initialized && state->exportInProgress) ? 1 : 0;
}

static inline void phoenixProfilerSetEnabled(PhoenixProfilerState *state, int enabled)
{
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);

  if (!enabled)
  {
    int i;
    state->enabled = 0;
    state->inFlightFrame = 0;
    state->phaseStackSize = 0;
    for (i = 0; i < PHOENIX_PHASE_COUNT; ++i)
      state->phaseDepth[i] = 0;
    /* Reset inter-frame baselines so time/heap deltas while disabled are not attributed on resume */
    state->lastFrameEndMs = 0.0;
    state->lastFrameStartMs = 0.0;
    state->currentFrameStartMs = 0.0;
    state->hasObservedHeap = 0;
  }
  else if (!state->enabled)
  {
    state->enabled = 1;
    state->inFlightFrame = 0;
    state->phaseStackSize = 0;
    state->lastFrameEndMs = 0.0;
    state->lastFrameStartMs = 0.0;
    state->currentFrameStartMs = 0.0;
    state->hasObservedHeap = 0;
  }
}

static inline int phoenixProfilerIsEnabled(const PhoenixProfilerState *state)
{
  return (state != NULL && state->initialized && state->enabled) ? 1 : 0;
}

static inline void phoenixProfilerSetRssSampleInterval(PhoenixProfilerState *state, uint32_t intervalFrames)
{
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  state->rssSampleIntervalFrames = intervalFrames;
}

static inline uint32_t phoenixProfilerGetRssSampleInterval(const PhoenixProfilerState *state)
{
  if (state == NULL || !state->initialized)
    return (uint32_t)PHOENIX_PROFILER_DEFAULT_RSS_SAMPLE_INTERVAL;
  return state->rssSampleIntervalFrames;
}

static inline void phoenixProfilerSetCollectMemoryMetrics(PhoenixProfilerState *state, int enabled)
{
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  state->collectMemoryMetrics = enabled ? 1 : 0;
  if (!state->collectMemoryMetrics)
    state->hasObservedHeap = 0;
}

static inline int phoenixProfilerGetCollectMemoryMetrics(const PhoenixProfilerState *state)
{
  if (state == NULL || !state->initialized)
    return 1;
  return state->collectMemoryMetrics;
}

static inline void phoenixProfilerSetTargetFps(PhoenixProfilerState *state, double targetFps)
{
  if (state == NULL || !phoenixProfilerIsFinite(targetFps) || targetFps <= 0.0)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, targetFps);
  state->targetFps = targetFps;
}

static inline void phoenixProfilerSetStateName(PhoenixProfilerState *state, const char *stateName)
{
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  state->currentStateNameLen = phoenixProfilerCopyString(
    state->currentStateName, sizeof(state->currentStateName), stateName);
  if (state->inFlightFrame)
  {
    memcpy(state->activeSample.stateName, state->currentStateName, state->currentStateNameLen + 1);
  }
}

static inline void phoenixProfilerAbortInFlightFrame(PhoenixProfilerState *state)
{
  int i;
  if (state == NULL || !state->inFlightFrame)
    return;
  state->inFlightFrame = 0;
  state->phaseStackSize = 0;
  for (i = 0; i < PHOENIX_PHASE_COUNT; ++i)
    state->phaseDepth[i] = 0;
  if (state->hasObservedHeap)
    state->lastObservedHeapBytes = state->frameStartHeapBytes;
}

static inline void phoenixProfilerBeginFrameAt(
  PhoenixProfilerState *state,
  double nowMs,
  int64_t heapUsedBytes,
  int64_t heapReservedBytes)
{
  int i;
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  if (!state->enabled)
    return;

  if (!phoenixProfilerIsFinite(nowMs) || nowMs < 0.0)
    nowMs = phoenixProfilerNowMs();

  /* If a previous frame was interrupted without endFrame, roll back its partial state cleanly */
  if (state->inFlightFrame)
    phoenixProfilerAbortInFlightFrame(state);

  state->inFlightFrame = 1;
  state->currentFrameStartMs = nowMs;
  state->phaseStackSize = 0;
  for (i = 0; i < PHOENIX_PHASE_COUNT; ++i)
    state->phaseDepth[i] = 0;

  memset(&state->activeSample, 0, offsetof(PhoenixFrameSample, stateName));
  state->activeSample.frameIndex = state->totalFrames + 1;
  state->activeSample.timestampMs = (nowMs >= state->sessionStartMs) ? (nowMs - state->sessionStartMs) : 0.0;
  memcpy(state->activeSample.stateName, state->currentStateName, state->currentStateNameLen + 1);

  if (state->collectMemoryMetrics && heapReservedBytes >= 0)
  {
    state->currentHeapReservedBytes = heapReservedBytes;
    if (heapReservedBytes > state->peakHeapReservedBytes)
      state->peakHeapReservedBytes = heapReservedBytes;
  }

  /*
   * Capture frameStartHeapBytes BEFORE observing any inter-frame heap change
   * so that (allocBytes - gcReclaimedBytes == netHeapDeltaBytes) holds over
   * the entire frame interval from frameStartHeapBytes to frameEndHeapBytes.
   */
  if (state->collectMemoryMetrics && heapUsedBytes >= 0)
  {
    state->heapStatsAvailable = 1;
    if (!state->hasObservedHeap)
    {
      state->lastObservedHeapBytes = heapUsedBytes;
      state->hasObservedHeap = 1;
    }
    state->frameStartHeapBytes = state->lastObservedHeapBytes;
    phoenixProfilerObserveHeap(state, heapUsedBytes, 0);
  }
  else
  {
    state->frameStartHeapBytes = state->hasObservedHeap ? state->lastObservedHeapBytes : 0;
  }

  state->activeSample.heapUsedBytes = state->currentHeapUsedBytes;
  state->activeSample.heapReservedBytes = state->currentHeapReservedBytes;
}

static inline void phoenixProfilerBeginFrame(
  PhoenixProfilerState *state,
  int64_t heapUsedBytes,
  int64_t heapReservedBytes)
{
  if (state == NULL || !state->initialized || !state->enabled)
  {
    if (state != NULL && !state->initialized)
      phoenixProfilerBeginFrameAt(state, phoenixProfilerNowMs(), heapUsedBytes, heapReservedBytes);
    return;
  }
  phoenixProfilerBeginFrameAt(state, phoenixProfilerNowMs(), heapUsedBytes, heapReservedBytes);
}

static inline void phoenixProfilerBeginPhaseAt(
  PhoenixProfilerState *state,
  int phase,
  double nowMs,
  int64_t heapUsedBytes)
{
  if (state == NULL || phase < 0 || phase >= PHOENIX_PHASE_COUNT)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  if (!state->enabled)
    return;

  if (!phoenixProfilerIsFinite(nowMs) || nowMs < 0.0)
    nowMs = phoenixProfilerNowMs();

  if (!state->inFlightFrame)
    phoenixProfilerBeginFrameAt(state, nowMs, heapUsedBytes, state->currentHeapReservedBytes);
  else if (state->collectMemoryMetrics && heapUsedBytes >= 0)
    phoenixProfilerObserveHeap(state, heapUsedBytes, 0);

  if (state->phaseDepth[phase] <= 0)
  {
    state->phaseDepth[phase] = 1;
    if (state->phaseStackSize < PHOENIX_PROFILER_MAX_PHASE_STACK)
    {
      PhoenixPhaseStackEntry *entry = &state->phaseStack[state->phaseStackSize++];
      entry->phase = phase;
      entry->startMs = nowMs;
      entry->childDurationMs = 0.0;
    }
    if (phase == PHOENIX_PHASE_UPDATE)
      state->activeSample.updateSteps += 1;
  }
  else
  {
    state->phaseDepth[phase] += 1;
  }
}

static inline void phoenixProfilerBeginPhase(
  PhoenixProfilerState *state,
  int phase,
  int64_t heapUsedBytes)
{
  if (state == NULL || phase < 0 || phase >= PHOENIX_PHASE_COUNT)
    return;
  if (state->initialized && !state->enabled)
    return;
  phoenixProfilerBeginPhaseAt(state, phase, phoenixProfilerNowMs(), heapUsedBytes);
}

/*
 * Pops and closes the top entry on `state->phaseStack` at `nowMs`, accumulating
 * its exclusive duration (`rawElapsedMs - childDurationMs`) and inclusive
 * duration (`rawElapsedMs`) into the phase's counters and crediting
 * `rawElapsedMs` to the enclosing parent phase on the stack (if any).
 */
static inline double phoenixProfilerPopTopPhaseAt(
  PhoenixProfilerState *state,
  double nowMs,
  int64_t heapUsedBytes)
{
  PhoenixPhaseStackEntry entry;
  int phase;
  double rawElapsedMs;
  double exclusiveElapsedMs;

  if (state == NULL || state->phaseStackSize <= 0)
    return 0.0;

  entry = state->phaseStack[--state->phaseStackSize];
  phase = entry.phase;
  if (phase >= 0 && phase < PHOENIX_PHASE_COUNT)
    state->phaseDepth[phase] = 0;

  rawElapsedMs = phoenixProfilerSanitizeDuration(nowMs - entry.startMs);
  exclusiveElapsedMs = rawElapsedMs - entry.childDurationMs;
  if (exclusiveElapsedMs < 0.0)
    exclusiveElapsedMs = 0.0;

  if (state->collectMemoryMetrics && heapUsedBytes >= 0)
  {
    phoenixProfilerObserveHeap(state, heapUsedBytes, phase == PHOENIX_PHASE_GC ? 1 : 0);
  }

  if (phase == PHOENIX_PHASE_UPDATE)
  {
    state->activeSample.updateTimeMs += exclusiveElapsedMs;
    state->activeSample.updateInclusiveMs += rawElapsedMs;
  }
  else if (phase == PHOENIX_PHASE_RENDER)
  {
    state->activeSample.renderTimeMs += exclusiveElapsedMs;
    state->activeSample.renderInclusiveMs += rawElapsedMs;
  }
  else if (phase == PHOENIX_PHASE_AUDIO)
  {
    state->activeSample.audioTimeMs += exclusiveElapsedMs;
    state->activeSample.audioInclusiveMs += rawElapsedMs;
  }
  else if (phase == PHOENIX_PHASE_GC)
  {
    state->activeSample.gcPauseMs += exclusiveElapsedMs;
    state->activeSample.gcInclusiveMs += rawElapsedMs;
    state->activeSample.explicitGcCount += 1;
    state->activeSample.gcCount += 1;
  }

  if (state->phaseStackSize > 0)
  {
    state->phaseStack[state->phaseStackSize - 1].childDurationMs += rawElapsedMs;
  }

  return exclusiveElapsedMs;
}

static inline double phoenixProfilerEndPhaseAt(
  PhoenixProfilerState *state,
  int phase,
  double nowMs,
  int64_t heapUsedBytes)
{
  int targetStackIdx = -1;
  int i;

  if (state == NULL || !state->initialized || !state->enabled || !state->inFlightFrame)
    return 0.0;
  if (phase < 0 || phase >= PHOENIX_PHASE_COUNT)
    return 0.0;
  if (state->phaseDepth[phase] <= 0)
    return 0.0;

  if (!phoenixProfilerIsFinite(nowMs) || nowMs < 0.0)
    nowMs = phoenixProfilerNowMs();

  if (state->phaseDepth[phase] > 1)
  {
    state->phaseDepth[phase] -= 1;
    return 0.0;
  }

  /* Locate `phase` on the active phase stack (normally at top: phaseStackSize - 1) */
  for (i = state->phaseStackSize - 1; i >= 0; --i)
  {
    if (state->phaseStack[i].phase == phase)
    {
      targetStackIdx = i;
      break;
    }
  }

  if (targetStackIdx < 0)
  {
    state->phaseDepth[phase] = 0;
    return 0.0;
  }

  /*
   * If any inner child phases were left unclosed inside `phase` (e.g. due to
   * an early return or exception), close them in LIFO order first so their
   * durations are properly attributed and deducted from `phase`.
   */
  while (state->phaseStackSize - 1 > targetStackIdx)
  {
    (void)phoenixProfilerPopTopPhaseAt(state, nowMs, -1);
  }

  return phoenixProfilerPopTopPhaseAt(state, nowMs, heapUsedBytes);
}

static inline double phoenixProfilerEndPhase(
  PhoenixProfilerState *state,
  int phase,
  int64_t heapUsedBytes)
{
  if (state == NULL || !state->initialized || !state->enabled || !state->inFlightFrame)
    return 0.0;
  return phoenixProfilerEndPhaseAt(state, phase, phoenixProfilerNowMs(), heapUsedBytes);
}

static inline void phoenixProfilerBeginUpdate(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhase(state, PHOENIX_PHASE_UPDATE, heapUsedBytes);
}

static inline double phoenixProfilerEndUpdate(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhase(state, PHOENIX_PHASE_UPDATE, heapUsedBytes);
}

static inline void phoenixProfilerBeginRender(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhase(state, PHOENIX_PHASE_RENDER, heapUsedBytes);
}

static inline double phoenixProfilerEndRender(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhase(state, PHOENIX_PHASE_RENDER, heapUsedBytes);
}

static inline void phoenixProfilerBeginAudio(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhase(state, PHOENIX_PHASE_AUDIO, heapUsedBytes);
}

static inline double phoenixProfilerEndAudio(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhase(state, PHOENIX_PHASE_AUDIO, heapUsedBytes);
}

static inline void phoenixProfilerBeginGC(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhase(state, PHOENIX_PHASE_GC, heapUsedBytes);
}

static inline double phoenixProfilerEndGC(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhase(state, PHOENIX_PHASE_GC, heapUsedBytes);
}

static inline void phoenixProfilerRecordPhaseMs(
  PhoenixProfilerState *state,
  int phase,
  double durationMs)
{
  double cleanMs = phoenixProfilerSanitizeDuration(durationMs);
  if (state == NULL || !state->initialized || !state->enabled || !state->inFlightFrame || cleanMs <= 0.0)
    return;

  if (phase == PHOENIX_PHASE_UPDATE)
  {
    state->activeSample.updateTimeMs += cleanMs;
    state->activeSample.updateInclusiveMs += cleanMs;
    state->activeSample.updateSteps += 1;
  }
  else if (phase == PHOENIX_PHASE_RENDER)
  {
    state->activeSample.renderTimeMs += cleanMs;
    state->activeSample.renderInclusiveMs += cleanMs;
  }
  else if (phase == PHOENIX_PHASE_AUDIO)
  {
    state->activeSample.audioTimeMs += cleanMs;
    state->activeSample.audioInclusiveMs += cleanMs;
  }
  else if (phase == PHOENIX_PHASE_GC)
  {
    state->activeSample.gcPauseMs += cleanMs;
    state->activeSample.gcInclusiveMs += cleanMs;
    state->activeSample.gcCount += 1;
    state->activeSample.explicitGcCount += 1;
  }
  else
  {
    return;
  }

  /* If recorded while inside an enclosing parent phase, credit childDurationMs */
  if (state->phaseStackSize > 0 && state->phaseStack[state->phaseStackSize - 1].phase != phase)
  {
    state->phaseStack[state->phaseStackSize - 1].childDurationMs += cleanMs;
  }
}

static inline void phoenixProfilerRecordAllocation(
  PhoenixProfilerState *state,
  int64_t bytes,
  uint32_t count)
{
  if (state == NULL || !state->initialized || !state->enabled || !state->inFlightFrame)
    return;
  if (bytes > 0)
    state->activeSample.allocBytes = phoenixProfilerSafeAddI64(state->activeSample.allocBytes, bytes);
  state->activeSample.allocCount += (count > 0 ? count : 1);
}

static inline void phoenixProfilerRecordGCPause(
  PhoenixProfilerState *state,
  double pauseMs,
  int64_t reclaimedBytes,
  int isExplicit)
{
  double cleanPauseMs = phoenixProfilerSanitizeDuration(pauseMs);
  if (state == NULL || !state->initialized || !state->enabled || !state->inFlightFrame)
    return;

  if (cleanPauseMs > 0.0)
  {
    state->activeSample.gcPauseMs += cleanPauseMs;
    state->activeSample.gcInclusiveMs += cleanPauseMs;
    if (state->phaseStackSize > 0 && state->phaseStack[state->phaseStackSize - 1].phase != PHOENIX_PHASE_GC)
    {
      state->phaseStack[state->phaseStackSize - 1].childDurationMs += cleanPauseMs;
    }
  }
  if (reclaimedBytes > 0)
  {
    state->activeSample.gcReclaimedBytes = phoenixProfilerSafeAddI64(
      state->activeSample.gcReclaimedBytes, reclaimedBytes);
  }
  if (isExplicit)
  {
    state->activeSample.explicitGcCount += 1;
    state->activeSample.gcCount += 1;
  }
  else
  {
    state->activeSample.implicitGcCount += 1;
    if (cleanPauseMs > 0.0)
      state->activeSample.gcCount += 1;
  }
}

static inline const PhoenixFrameSample *phoenixProfilerEndFrameAt(
  PhoenixProfilerState *state,
  double nowMs,
  double explicitFrameTimeMs,
  int64_t heapUsedBytes,
  int64_t heapReservedBytes,
  uint32_t drawCalls)
{
  double workTimeMs;
  double frameTimeMs;
  double accountedMs;
  double targetBudgetMs;
  PhoenixFrameSample *sample;
  PhoenixFrameSample *stored;
  size_t nextFrameNumber;

  if (state == NULL || !state->initialized || !state->enabled)
    return NULL;

  if (!phoenixProfilerIsFinite(nowMs) || nowMs < 0.0)
    nowMs = phoenixProfilerNowMs();

  if (!state->inFlightFrame)
    phoenixProfilerBeginFrameAt(state, nowMs, heapUsedBytes, heapReservedBytes);

  /* Close any still-open phases in LIFO stack order so parent-child deductions stay exact */
  while (state->phaseStackSize > 0)
  {
    (void)phoenixProfilerPopTopPhaseAt(state, nowMs, -1);
  }

  if (state->collectMemoryMetrics && heapUsedBytes >= 0)
    phoenixProfilerObserveHeap(state, heapUsedBytes, 0);
  if (state->collectMemoryMetrics && heapReservedBytes >= 0)
  {
    state->currentHeapReservedBytes = heapReservedBytes;
    if (heapReservedBytes > state->peakHeapReservedBytes)
      state->peakHeapReservedBytes = heapReservedBytes;
  }

  sample = &state->activeSample;
  workTimeMs = phoenixProfilerSanitizeDuration(nowMs - state->currentFrameStartMs);

  if (phoenixProfilerIsFinite(explicitFrameTimeMs) && explicitFrameTimeMs > 0.0)
  {
    double cleanExplicit = phoenixProfilerSanitizeDuration(explicitFrameTimeMs);
    frameTimeMs = cleanExplicit >= workTimeMs ? cleanExplicit : workTimeMs;
  }
  else if (state->lastFrameEndMs > 0.0 && nowMs >= state->lastFrameEndMs)
  {
    double deltaFromLastEnd = phoenixProfilerSanitizeDuration(nowMs - state->lastFrameEndMs);
    frameTimeMs = (deltaFromLastEnd >= workTimeMs && deltaFromLastEnd < 10000.0)
      ? deltaFromLastEnd
      : workTimeMs;
  }
  else
  {
    frameTimeMs = workTimeMs;
  }

  if (frameTimeMs <= 0.0)
    frameTimeMs = 0.0001;

  state->lastFrameStartMs = state->currentFrameStartMs;
  state->lastFrameEndMs = nowMs;
  state->inFlightFrame = 0;

  /* Sample process RSS only on configured interval frames to keep hot-path overhead minimal */
  nextFrameNumber = (size_t)(state->totalFrames + 1);
  if (state->collectMemoryMetrics && state->rssSampleIntervalFrames > 0
      && (nextFrameNumber == 1 || (nextFrameNumber % (size_t)state->rssSampleIntervalFrames) == 0))
  {
    size_t curRss = 0;
    size_t pkRss = 0;
    if (phoenixProfilerSampleProcessMemory(&curRss, &pkRss))
    {
      state->rssAvailable = 1;
      state->lastSampledRssBytes = curRss;
      if (pkRss > state->lastSampledPeakRssBytes)
        state->lastSampledPeakRssBytes = pkRss;
      if (curRss > state->lastSampledPeakRssBytes)
        state->lastSampledPeakRssBytes = curRss;
      sample->rssSampled = 1;
    }
    else
    {
      sample->rssSampled = 0;
    }
  }
  else
  {
    sample->rssSampled = 0;
  }

  sample->workTimeMs = workTimeMs;
  sample->frameTimeMs = frameTimeMs;
  sample->fps = 1000.0 / frameTimeMs;

  accountedMs = sample->updateTimeMs + sample->renderTimeMs + sample->audioTimeMs + sample->gcPauseMs;
  sample->otherTimeMs = workTimeMs > accountedMs ? (workTimeMs - accountedMs) : 0.0;

  sample->heapUsedBytes = state->currentHeapUsedBytes;
  sample->heapReservedBytes = state->currentHeapReservedBytes;
  sample->netHeapDeltaBytes = phoenixProfilerSafeSubI64(state->currentHeapUsedBytes, state->frameStartHeapBytes);
  sample->rssBytes = state->lastSampledRssBytes;
  sample->peakRssBytes = state->lastSampledPeakRssBytes;
  sample->drawCalls = drawCalls;

  /* Update O(1) amortized trailing ~1000ms sliding-window rolling FPS */
  if (state->ringCount == PHOENIX_PROFILER_RING_CAPACITY
      && state->rollingWindowCount >= PHOENIX_PROFILER_RING_CAPACITY)
  {
    double overwrittenFt = state->samples[state->ringWriteIndex].frameTimeMs;
    state->rollingWindowMs = state->rollingWindowMs > overwrittenFt
      ? (state->rollingWindowMs - overwrittenFt)
      : 0.0;
    state->rollingWindowCount = PHOENIX_PROFILER_RING_CAPACITY - 1;
  }

  stored = &state->samples[state->ringWriteIndex];
  *stored = *sample;
  state->ringWriteIndex = (state->ringWriteIndex + 1) % PHOENIX_PROFILER_RING_CAPACITY;
  if (state->ringCount < PHOENIX_PROFILER_RING_CAPACITY)
    state->ringCount += 1;

  state->rollingWindowMs += frameTimeMs;
  state->rollingWindowCount += 1;
  while (state->rollingWindowCount > 1)
  {
    size_t oldestIdx = (state->ringWriteIndex + PHOENIX_PROFILER_RING_CAPACITY - state->rollingWindowCount)
      % PHOENIX_PROFILER_RING_CAPACITY;
    double oldestFt = state->samples[oldestIdx].frameTimeMs;
    if ((state->rollingWindowMs - oldestFt) >= 1000.0 || state->rollingWindowCount > 240)
    {
      state->rollingWindowMs -= oldestFt;
      if (state->rollingWindowMs < 0.0)
        state->rollingWindowMs = 0.0;
      state->rollingWindowCount -= 1;
    }
    else
    {
      break;
    }
  }
  state->currentRollingFps = state->rollingWindowMs > 0.0
    ? (((double)state->rollingWindowCount * 1000.0) / state->rollingWindowMs)
    : 0.0;
  stored->rollingFps = state->currentRollingFps;
  sample->rollingFps = state->currentRollingFps;

  /* Update cumulative session statistics */
  state->totalFrames += 1;
  state->sumFrameTimeMs += frameTimeMs;
  state->sumSqFrameTimeMs += frameTimeMs * frameTimeMs;
  if (frameTimeMs < state->minFrameTimeMs)
    state->minFrameTimeMs = frameTimeMs;
  if (frameTimeMs > state->maxFrameTimeMs)
    state->maxFrameTimeMs = frameTimeMs;

  state->sumUpdateTimeMs += sample->updateTimeMs;
  if (sample->updateTimeMs > state->maxUpdateTimeMs)
    state->maxUpdateTimeMs = sample->updateTimeMs;

  state->sumRenderTimeMs += sample->renderTimeMs;
  if (sample->renderTimeMs > state->maxRenderTimeMs)
    state->maxRenderTimeMs = sample->renderTimeMs;

  state->sumAudioTimeMs += sample->audioTimeMs;
  if (sample->audioTimeMs > state->maxAudioTimeMs)
    state->maxAudioTimeMs = sample->audioTimeMs;

  state->sumOtherTimeMs += sample->otherTimeMs;
  if (sample->otherTimeMs > state->maxOtherTimeMs)
    state->maxOtherTimeMs = sample->otherTimeMs;

  state->totalGcCount = phoenixProfilerSafeAddU64(state->totalGcCount, (uint64_t)sample->gcCount);
  state->totalExplicitGcCount = phoenixProfilerSafeAddU64(state->totalExplicitGcCount, (uint64_t)sample->explicitGcCount);
  state->totalImplicitGcCount = phoenixProfilerSafeAddU64(state->totalImplicitGcCount, (uint64_t)sample->implicitGcCount);
  if (sample->gcCount > 0 || sample->implicitGcCount > 0 || sample->gcPauseMs > 0.0)
    state->framesWithGc += 1;
  state->totalGcPauseMs += sample->gcPauseMs;
  if (sample->gcPauseMs > state->maxGcPauseMs)
  {
    state->maxGcPauseMs = sample->gcPauseMs;
    state->maxGcPauseFrame = sample->frameIndex;
  }
  if (sample->gcReclaimedBytes > 0)
  {
    state->totalGcReclaimedBytes = phoenixProfilerSafeAddU64(
      state->totalGcReclaimedBytes, (uint64_t)sample->gcReclaimedBytes);
  }

  if (sample->allocBytes > 0)
  {
    state->totalAllocBytes = phoenixProfilerSafeAddU64(
      state->totalAllocBytes, (uint64_t)sample->allocBytes);
    if (sample->allocBytes > state->peakFrameAllocBytes)
    {
      state->peakFrameAllocBytes = sample->allocBytes;
      state->peakFrameAllocFrame = sample->frameIndex;
    }
  }
  state->totalAllocCount = phoenixProfilerSafeAddU64(state->totalAllocCount, (uint64_t)sample->allocCount);

  targetBudgetMs = state->targetFps > 0.0 ? (1000.0 / state->targetFps) : 16.6667;
  if (frameTimeMs > targetBudgetMs * 1.5)
    state->droppedFrames += 1;
  if (frameTimeMs > 16.6667)
    state->spikeCount16Ms += 1;
  if (frameTimeMs > 25.0)
    state->spikeCount25Ms += 1;
  if (frameTimeMs > 33.3333)
    state->spikeCount33Ms += 1;
  if (frameTimeMs > 50.0)
    state->spikeCount50Ms += 1;

  state->totalDrawCalls = phoenixProfilerSafeAddU64(state->totalDrawCalls, (uint64_t)drawCalls);
  if (drawCalls > state->maxDrawCalls)
    state->maxDrawCalls = drawCalls;

  return stored;
}

static inline const PhoenixFrameSample *phoenixProfilerEndFrame(
  PhoenixProfilerState *state,
  int64_t heapUsedBytes,
  int64_t heapReservedBytes,
  uint32_t drawCalls)
{
  if (state == NULL || !state->initialized || !state->enabled)
    return NULL;
  return phoenixProfilerEndFrameAt(state, phoenixProfilerNowMs(), 0.0, heapUsedBytes, heapReservedBytes, drawCalls);
}

static inline int phoenixProfilerGetLastFrame(
  const PhoenixProfilerState *state,
  PhoenixFrameSample *outSample)
{
  size_t lastIdx;
  if (state == NULL || outSample == NULL || state->ringCount == 0)
    return 0;
  lastIdx = (state->ringWriteIndex + PHOENIX_PROFILER_RING_CAPACITY - 1) % PHOENIX_PROFILER_RING_CAPACITY;
  *outSample = state->samples[lastIdx];
  return 1;
}

static inline int phoenixProfilerGetBufferedFrame(
  const PhoenixProfilerState *state,
  size_t chronologicalIndex,
  PhoenixFrameSample *outSample)
{
  size_t startIdx;
  size_t actualIdx;
  if (state == NULL || outSample == NULL || chronologicalIndex >= state->ringCount)
    return 0;
  startIdx = (state->ringCount < PHOENIX_PROFILER_RING_CAPACITY) ? 0 : state->ringWriteIndex;
  actualIdx = (startIdx + chronologicalIndex) % PHOENIX_PROFILER_RING_CAPACITY;
  *outSample = state->samples[actualIdx];
  return 1;
}

/* ============================================================================
 * Summary Calculation
 * ============================================================================ */

static inline void phoenixProfilerComputeSummary(
  PhoenixProfilerState *state,
  PhoenixProfilerSummary *outSummary)
{
  double scratch[PHOENIX_PROFILER_RING_CAPACITY];
  size_t count;
  size_t i;
  PhoenixFrameSample lastSample;

  if (outSummary == NULL)
    return;
  memset(outSummary, 0, sizeof(PhoenixProfilerSummary));
  if (state == NULL || !state->initialized)
    return;

  outSummary->totalFrames = state->totalFrames;
  outSummary->bufferedFrames = state->ringCount;
  outSummary->sessionDurationMs = state->sumFrameTimeMs;
  outSummary->targetFps = state->targetFps > 0.0 ? state->targetFps : 60.0;
  outSummary->targetFrameTimeMs = 1000.0 / outSummary->targetFps;
  outSummary->logicalCpuCount = state->logicalCpuCount > 0 ? state->logicalCpuCount : 1;
  outSummary->cpuTimeAvailable = state->cpuClockValid;
  outSummary->heapStatsAvailable = state->heapStatsAvailable;
  outSummary->rssSampleIntervalFrames = state->rssSampleIntervalFrames;

  outSummary->currentHeapUsedBytes = state->currentHeapUsedBytes;
  outSummary->currentHeapReservedBytes = state->currentHeapReservedBytes;
  outSummary->peakHeapUsedBytes = state->peakHeapUsedBytes;
  outSummary->peakHeapReservedBytes = state->peakHeapReservedBytes;

  if (state->collectMemoryMetrics)
  {
    size_t curRss = state->lastSampledRssBytes;
    size_t pkRss = state->lastSampledPeakRssBytes;
    if (curRss == 0 && pkRss == 0)
    {
      if (phoenixProfilerSampleProcessMemory(&curRss, &pkRss))
      {
        state->rssAvailable = 1;
        state->lastSampledRssBytes = curRss;
        state->lastSampledPeakRssBytes = pkRss;
        outSummary->rssAvailable = 1;
      }
      else
      {
        outSummary->rssAvailable = 0;
      }
    }
    else
    {
      outSummary->rssAvailable = state->rssAvailable;
    }
    outSummary->currentRssBytes = curRss;
    outSummary->peakRssBytes = pkRss;
  }
  else
  {
    outSummary->rssAvailable = 0;
    outSummary->currentRssBytes = 0;
    outSummary->peakRssBytes = 0;
  }

  if (state->totalFrames == 0 || state->ringCount == 0)
    return;

  if (phoenixProfilerGetLastFrame(state, &lastSample))
  {
    outSummary->lastFrameTimeMs = lastSample.frameTimeMs;
    outSummary->currentFps = lastSample.rollingFps > 0.0 ? lastSample.rollingFps : lastSample.fps;
  }

  outSummary->avgFrameTimeMs = state->sumFrameTimeMs / (double)state->totalFrames;
  outSummary->minFrameTimeMs = state->minFrameTimeMs < 1e11 ? state->minFrameTimeMs : outSummary->avgFrameTimeMs;
  outSummary->maxFrameTimeMs = state->maxFrameTimeMs;

  outSummary->avgFps = outSummary->avgFrameTimeMs > 0.0 ? (1000.0 / outSummary->avgFrameTimeMs) : 0.0;
  outSummary->minFps = outSummary->maxFrameTimeMs > 0.0 ? (1000.0 / outSummary->maxFrameTimeMs) : 0.0;
  outSummary->maxFps = outSummary->minFrameTimeMs > 0.0 ? (1000.0 / outSummary->minFrameTimeMs) : 0.0;

  {
    double mean = outSummary->avgFrameTimeMs;
    double variance = (state->sumSqFrameTimeMs / (double)state->totalFrames) - (mean * mean);
    outSummary->stdDevFrameTimeMs = variance > 0.0 ? phoenixProfilerSqrt(variance) : 0.0;
  }

  outSummary->avgUpdateTimeMs = state->sumUpdateTimeMs / (double)state->totalFrames;
  outSummary->maxUpdateTimeMs = state->maxUpdateTimeMs;
  outSummary->avgRenderTimeMs = state->sumRenderTimeMs / (double)state->totalFrames;
  outSummary->maxRenderTimeMs = state->maxRenderTimeMs;
  outSummary->avgAudioTimeMs = state->sumAudioTimeMs / (double)state->totalFrames;
  outSummary->maxAudioTimeMs = state->maxAudioTimeMs;
  outSummary->avgOtherTimeMs = state->sumOtherTimeMs / (double)state->totalFrames;
  outSummary->maxOtherTimeMs = state->maxOtherTimeMs;

  outSummary->totalGcCount = state->totalGcCount;
  outSummary->totalExplicitGcCount = state->totalExplicitGcCount;
  outSummary->totalImplicitGcCount = state->totalImplicitGcCount;
  outSummary->framesWithGc = state->framesWithGc;
  outSummary->totalGcPauseMs = state->totalGcPauseMs;
  outSummary->avgGcPauseMs = state->totalGcCount > 0
    ? (state->totalGcPauseMs / (double)state->totalGcCount)
    : 0.0;
  outSummary->maxGcPauseMs = state->maxGcPauseMs;
  outSummary->maxGcPauseFrame = state->maxGcPauseFrame;
  outSummary->totalGcReclaimedBytes = state->totalGcReclaimedBytes;

  outSummary->totalAllocBytes = state->totalAllocBytes;
  outSummary->totalAllocCount = state->totalAllocCount;
  outSummary->avgAllocBytesPerFrame = (double)state->totalAllocBytes / (double)state->totalFrames;
  outSummary->allocRateBytesPerSec = state->sumFrameTimeMs > 0.0
    ? (((double)state->totalAllocBytes * 1000.0) / state->sumFrameTimeMs)
    : 0.0;
  outSummary->peakFrameAllocBytes = state->peakFrameAllocBytes;
  outSummary->peakFrameAllocFrame = state->peakFrameAllocFrame;

  outSummary->droppedFrames = state->droppedFrames;
  outSummary->spikeCount16Ms = state->spikeCount16Ms;
  outSummary->spikeCount25Ms = state->spikeCount25Ms;
  outSummary->spikeCount33Ms = state->spikeCount33Ms;
  outSummary->spikeCount50Ms = state->spikeCount50Ms;
  outSummary->avgDrawCalls = (double)state->totalDrawCalls / (double)state->totalFrames;
  outSummary->maxDrawCalls = state->maxDrawCalls;

  if (state->cpuClockValid)
  {
    double nowCpuSec = 0.0;
    if (phoenixProfilerQueryCpuSeconds(&nowCpuSec) && nowCpuSec >= state->sessionStartCpuSec)
    {
      double elapsedCpuMs = (nowCpuSec - state->sessionStartCpuSec) * 1000.0;
      outSummary->cpuTimeMs = elapsedCpuMs;
      outSummary->cpuUtilizationPct = state->sumFrameTimeMs > 0.0
        ? ((elapsedCpuMs / state->sumFrameTimeMs) * 100.0)
        : 0.0;
      outSummary->cpuNormalizedPct = outSummary->cpuUtilizationPct / (double)outSummary->logicalCpuCount;
    }
    else
    {
      outSummary->cpuTimeAvailable = 0;
    }
  }

  /* Reuse a single 16 KB scratch buffer across all 4 percentile sorts */
  count = state->ringCount;
  for (i = 0; i < count; ++i)
    scratch[i] = state->samples[i].frameTimeMs;
  phoenixProfilerSortDoubles(scratch, count);

  outSummary->p50FrameTimeMs = phoenixProfilerPercentileFromSorted(scratch, count, 0.50);
  outSummary->p95FrameTimeMs = phoenixProfilerPercentileFromSorted(scratch, count, 0.95);
  outSummary->p99FrameTimeMs = phoenixProfilerPercentileFromSorted(scratch, count, 0.99);
  outSummary->p999FrameTimeMs = phoenixProfilerPercentileFromSorted(scratch, count, 0.999);

  state->cachedOverlayFrame = state->totalFrames;
  state->cachedOverlayP95Ms = outSummary->p95FrameTimeMs;
  state->cachedOverlayP99Ms = outSummary->p99FrameTimeMs;

  outSummary->onePercentLowFps = outSummary->p99FrameTimeMs > 0.0
    ? (1000.0 / outSummary->p99FrameTimeMs)
    : 0.0;
  outSummary->pointOnePercentLowFps = outSummary->p999FrameTimeMs > 0.0
    ? (1000.0 / outSummary->p999FrameTimeMs)
    : 0.0;
  outSummary->slowest1PctAvgFps = phoenixProfilerSlowestTailMeanFps(scratch, count, 0.01);
  outSummary->slowest01PctAvgFps = phoenixProfilerSlowestTailMeanFps(scratch, count, 0.001);

  for (i = 0; i < count; ++i)
    scratch[i] = state->samples[i].updateTimeMs;
  phoenixProfilerSortDoubles(scratch, count);
  outSummary->p95UpdateTimeMs = phoenixProfilerPercentileFromSorted(scratch, count, 0.95);

  for (i = 0; i < count; ++i)
    scratch[i] = state->samples[i].renderTimeMs;
  phoenixProfilerSortDoubles(scratch, count);
  outSummary->p95RenderTimeMs = phoenixProfilerPercentileFromSorted(scratch, count, 0.95);

  for (i = 0; i < count; ++i)
    scratch[i] = state->samples[i].audioTimeMs;
  phoenixProfilerSortDoubles(scratch, count);
  outSummary->p95AudioTimeMs = phoenixProfilerPercentileFromSorted(scratch, count, 0.95);
}

/*
 * Formats a compact 3-line HUD overlay directly from `state` without allocating
 * Haxe anonymous structures, caching P95/P99 percentile sorts across
 * `PHOENIX_PROFILER_OVERLAY_SORT_INTERVAL` frames.
 */
static inline int phoenixProfilerFormatOverlay(
  PhoenixProfilerState *state,
  char *outBuffer,
  size_t outCapacity)
{
  PhoenixFrameSample lastSample;
  double p95Ft = 0.0;
  double p99Ft = 0.0;
  double low1PctFps = 0.0;
  double allocKb = 0.0;
  int written;

  if (outBuffer == NULL || outCapacity == 0)
    return 0;
  outBuffer[0] = '\0';

  if (state == NULL || !state->initialized || state->ringCount == 0)
    return 0;
  if (!phoenixProfilerGetLastFrame(state, &lastSample))
    return 0;

  if (state->cachedOverlayFrame == 0
      || state->totalFrames < state->cachedOverlayFrame
      || (state->totalFrames - state->cachedOverlayFrame) >= (uint64_t)PHOENIX_PROFILER_OVERLAY_SORT_INTERVAL)
  {
    double frameTimes[PHOENIX_PROFILER_RING_CAPACITY];
    size_t i;
    for (i = 0; i < state->ringCount; ++i)
      frameTimes[i] = state->samples[i].frameTimeMs;
    phoenixProfilerSortDoubles(frameTimes, state->ringCount);
    state->cachedOverlayP95Ms = phoenixProfilerPercentileFromSorted(frameTimes, state->ringCount, 0.95);
    state->cachedOverlayP99Ms = phoenixProfilerPercentileFromSorted(frameTimes, state->ringCount, 0.99);
    state->cachedOverlayFrame = state->totalFrames;
  }

  p95Ft = state->cachedOverlayP95Ms;
  p99Ft = state->cachedOverlayP99Ms;
  low1PctFps = p99Ft > 0.0 ? (1000.0 / p99Ft) : 0.0;
  allocKb = (double)lastSample.allocBytes / 1024.0;

  written = snprintf(
    outBuffer,
    outCapacity,
    "Frame: %.2fms (P95 %.2f / P99 %.2fms) | 1%% Low: %.1f FPS\n"
    "Upd: %.2fms | Rnd: %.2fms | Aud: %.2fms | GC: %.2fms (%llu)\n"
    "Alloc: %.1f KB/f | Draws: %u | F3 HUD | F6 Export .log",
    lastSample.frameTimeMs,
    p95Ft,
    p99Ft,
    low1PctFps,
    lastSample.updateTimeMs,
    lastSample.renderTimeMs,
    lastSample.audioTimeMs,
    lastSample.gcPauseMs,
    (unsigned long long)state->totalGcCount,
    allocKb,
    (unsigned int)lastSample.drawCalls);

  return (written > 0 && (size_t)written < outCapacity) ? 1 : 0;
}

/* ============================================================================
 * Directory Creation, Strict Path Normalization & Atomic .log File Export
 * ============================================================================ */

static inline int phoenixProfilerMakeDirSingle(const char *path)
{
  if (path == NULL || path[0] == '\0')
    return 0;
#if defined(_WIN32) || defined(_WIN64)
  if (_mkdir(path) == 0 || errno == EEXIST)
    return 1;
  return 0;
#else
  if (mkdir(path, 0755) == 0 || errno == EEXIST)
    return 1;
  return 0;
#endif
}

static inline int phoenixProfilerEnsureParentDirs(const char *filePath)
{
  char temp[PHOENIX_PROFILER_PATH_MAX];
  size_t len;
  size_t i;

  if (filePath == NULL || filePath[0] == '\0')
    return 0;

  len = strlen(filePath);
  if (len >= sizeof(temp))
    return 0;

  memcpy(temp, filePath, len + 1);
  for (i = 1; i < len; ++i)
  {
    if (temp[i] == '/' || temp[i] == '\\')
    {
      char saved = temp[i];
      temp[i] = '\0';
      if (strcmp(temp, ".") != 0 && strcmp(temp, "..") != 0 && temp[0] != '\0')
      {
        if (!phoenixProfilerMakeDirSingle(temp))
          return 0;
      }
      temp[i] = saved;
    }
  }
  return 1;
}

/*
 * Strictly resolves any requested log path into `debug/log/<basename>.log`.
 * - Extracts only the final filename component after any `/` or `\`.
 * - Strips path traversal (`..`), leading dots/spaces, and filesystem-invalid
 *   characters (`:`, `*`, `?`, `"`, `<`, `>`, `|`, control chars).
 * - Guarantees that the resolved path NEVER escapes `debug/log/`.
 */
static inline int phoenixProfilerResolveLogPath(
  const char *requestedPath,
  char *outPath,
  size_t outCapacity)
{
  char baseName[256];
  size_t baseLen = 0;
  time_t nowSec;
  struct tm *tmInfo;

  if (outPath == NULL || outCapacity < 32)
    return 0;

  baseName[0] = '\0';

  if (requestedPath != NULL && requestedPath[0] != '\0')
  {
    const char *lastSlash = requestedPath;
    const char *p = requestedPath;
    while (*p != '\0')
    {
      if (*p == '/' || *p == '\\')
        lastSlash = p + 1;
      ++p;
    }

    /* Skip leading dots and whitespace */
    while (*lastSlash == '.' || *lastSlash == ' ' || *lastSlash == '\t')
      ++lastSlash;

    while (*lastSlash != '\0' && baseLen + 6 < sizeof(baseName))
    {
      unsigned char ch = (unsigned char)*lastSlash++;
      if (ch < 32 || ch == 127 || ch == '/' || ch == '\\' || ch == ':'
          || ch == '*' || ch == '?' || ch == '"' || ch == '<' || ch == '>' || ch == '|')
      {
        baseName[baseLen++] = '_';
      }
      else
      {
        baseName[baseLen++] = (char)ch;
      }
    }
    /* Trim trailing spaces and dots */
    while (baseLen > 0 && (baseName[baseLen - 1] == ' ' || baseName[baseLen - 1] == '.'))
      --baseLen;
    baseName[baseLen] = '\0';
  }

  /* If no valid basename remained (e.g., "", "..", "/", "debug/log/"), generate default */
  if (baseLen == 0 || strcmp(baseName, "log") == 0)
  {
    nowSec = time(NULL);
    tmInfo = localtime(&nowSec);
    if (tmInfo != NULL)
    {
      snprintf(
        baseName,
        sizeof(baseName),
        "frame_profiler_%04d-%02d-%02d_%02d-%02d-%02d.log",
        tmInfo->tm_year + 1900,
        tmInfo->tm_mon + 1,
        tmInfo->tm_mday,
        tmInfo->tm_hour,
        tmInfo->tm_min,
        tmInfo->tm_sec);
    }
    else
    {
      snprintf(baseName, sizeof(baseName), "frame_profiler.log");
    }
    baseLen = strlen(baseName);
  }
  else
  {
    if (baseLen < 4 || strcmp(baseName + baseLen - 4, ".log") != 0)
    {
      snprintf(baseName + baseLen, sizeof(baseName) - baseLen, ".log");
      baseLen = strlen(baseName);
    }
  }

  {
    int written = snprintf(outPath, outCapacity, "debug/log/%s", baseName);
    if (written <= 0 || (size_t)written >= outCapacity)
    {
      outPath[0] = '\0';
      return 0;
    }
  }
  return 1;
}

static inline int phoenixProfilerFinalizeTempFile(const char *tempPath, const char *finalPath)
{
  if (tempPath == NULL || finalPath == NULL)
    return 0;
#if defined(_WIN32) || defined(_WIN64)
  if (MoveFileExA(tempPath, finalPath, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
    return 1;
  (void)remove(finalPath);
  return rename(tempPath, finalPath) == 0 ? 1 : 0;
#else
  return rename(tempPath, finalPath) == 0 ? 1 : 0;
#endif
}

static inline const char *phoenixProfilerDominantSubsystem(const PhoenixFrameSample *sample)
{
  double maxVal;
  const char *label = "Other/Idle";
  if (sample == NULL)
    return label;
  maxVal = sample->otherTimeMs;
  if (sample->updateTimeMs >= maxVal)
  {
    maxVal = sample->updateTimeMs;
    label = "Update";
  }
  if (sample->renderTimeMs >= maxVal)
  {
    maxVal = sample->renderTimeMs;
    label = "Render";
  }
  if (sample->audioTimeMs >= maxVal)
  {
    maxVal = sample->audioTimeMs;
    label = "Audio";
  }
  if (sample->gcPauseMs >= maxVal && sample->gcPauseMs > 0.0)
  {
    label = "GC Pause";
  }
  return label;
}

/*
 * Exports a complete 6-section .log report to `debug/log/<basename>.log`.
 * - Non-destructive to any active in-flight frame (`samples` and `totalFrames`
 *   contain only completed frames).
 * - Guarded by `state->exportInProgress` against re-entrant export calls.
 * - Writes to `<resolvedPath>.tmp`, verifies `ferror`/`fflush`/`fclose`, and
 *   atomically renames to `<resolvedPath>` so failed or partial writes never
 *   corrupt an existing log file or leave a partial `.log` file behind.
 */
static inline int phoenixProfilerExportLog(
  PhoenixProfilerState *state,
  const char *requestedPath,
  const char *engineVersion,
  const char *platformName,
  char *outResolvedPath,
  size_t outResolvedCapacity)
{
  char resolvedPath[PHOENIX_PROFILER_PATH_MAX];
  char tempPath[PHOENIX_PROFILER_PATH_MAX + 16];
  char safeEngineVer[64];
  char safePlatform[64];
  char safeStateName[PHOENIX_PROFILER_STATE_NAME_MAX];
  PhoenixProfilerSummary summary;
  FILE *fp;
  time_t nowSec;
  struct tm *tmInfo;
  char timestampStr[64];
  size_t i;
  size_t j;
  size_t slowestIndices[PHOENIX_PROFILER_TOP_SLOWEST_COUNT];
  size_t slowestCount = 0;

  if (outResolvedPath != NULL && outResolvedCapacity > 0)
    outResolvedPath[0] = '\0';

  if (state == NULL || !state->initialized || state->exportInProgress)
    return 0;

  if (!phoenixProfilerResolveLogPath(requestedPath, resolvedPath, sizeof(resolvedPath)))
    return 0;

  if (!phoenixProfilerEnsureParentDirs(resolvedPath))
    return 0;

  snprintf(tempPath, sizeof(tempPath), "%s.tmp", resolvedPath);

  state->exportInProgress = 1;
  fp = fopen(tempPath, "wb");
  if (fp == NULL)
  {
    state->exportInProgress = 0;
    return 0;
  }

  phoenixProfilerComputeSummary(state, &summary);

  phoenixProfilerCopyString(safeEngineVer, sizeof(safeEngineVer),
    (engineVersion != NULL && engineVersion[0] != '\0') ? engineVersion : "0.3.2");
  phoenixProfilerCopyString(safePlatform, sizeof(safePlatform),
    (platformName != NULL && platformName[0] != '\0') ? platformName : "Native");
  phoenixProfilerCopyString(safeStateName, sizeof(safeStateName), state->currentStateName);

  nowSec = time(NULL);
  tmInfo = localtime(&nowSec);
  if (tmInfo != NULL)
  {
    strftime(timestampStr, sizeof(timestampStr), "%Y-%m-%d %H:%M:%S", tmInfo);
  }
  else
  {
    snprintf(timestampStr, sizeof(timestampStr), "Unknown");
  }

  fprintf(fp, "================================================================================\n");
  fprintf(fp, "PHOENIX ENGINE - FRAME PROFILER LOG REPORT\n");
  fprintf(fp, "================================================================================\n");
  fprintf(fp, "Generated At           : %s\n", timestampStr);
  fprintf(fp, "Engine Version         : %s\n", safeEngineVer);
  fprintf(fp, "Platform / Runtime     : %s\n", safePlatform);
  fprintf(fp, "Active State           : %s\n", safeStateName);
  fprintf(fp, "Target Framerate       : %.2f FPS (%.4f ms/frame budget)\n",
    summary.targetFps, summary.targetFrameTimeMs);
  fprintf(fp, "Session Duration       : %.3f ms (%.2f s)\n",
    summary.sessionDurationMs, summary.sessionDurationMs / 1000.0);
  fprintf(fp, "Total Frames Recorded  : %llu (Ring Buffer Window: %zu / %d frames)\n",
    (unsigned long long)summary.totalFrames,
    summary.bufferedFrames,
    PHOENIX_PROFILER_RING_CAPACITY);
  if (summary.cpuTimeAvailable)
  {
    fprintf(fp, "Process CPU Time       : %.3f ms (%.2f%% single-core eq; %.2f%% across %d logical CPUs)\n",
      summary.cpuTimeMs,
      summary.cpuUtilizationPct,
      summary.cpuNormalizedPct,
      summary.logicalCpuCount);
  }
  else
  {
    fprintf(fp, "Process CPU Time       : N/A (unavailable on this platform/runtime)\n");
  }
  fprintf(fp, "RSS Sampling Interval  : %u frames (0 = on-demand only)\n\n",
    (unsigned int)summary.rssSampleIntervalFrames);

  fprintf(fp, "[1] FRAMETIME & FPS SUMMARY\n");
  fprintf(fp, "--------------------------------------------------------------------------------\n");
  fprintf(fp, "Average FPS            : %.2f FPS\n", summary.avgFps);
  fprintf(fp, "Current Rolling FPS    : %.2f FPS (1.0s trailing sliding window)\n", summary.currentFps);
  fprintf(fp, "Min / Max FPS          : %.2f FPS / %.2f FPS\n", summary.minFps, summary.maxFps);
  fprintf(fp, "1%% Low / 0.1%% Low FPS  : %.2f FPS (1000/P99) / %.2f FPS (1000/P99.9)\n",
    summary.onePercentLowFps, summary.pointOnePercentLowFps);
  fprintf(fp, "Slowest 1%% / 0.1%% Mean : %.2f FPS / %.2f FPS (harmonic mean of slowest tail frames)\n",
    summary.slowest1PctAvgFps, summary.slowest01PctAvgFps);
  fprintf(fp, "Average Frametime      : %.4f ms (StdDev: %.4f ms)\n",
    summary.avgFrameTimeMs, summary.stdDevFrameTimeMs);
  fprintf(fp, "Min / Max Frametime    : %.4f ms / %.4f ms\n",
    summary.minFrameTimeMs, summary.maxFrameTimeMs);
  fprintf(fp, "Frametime Percentiles  : P50=%.4f ms | P95=%.4f ms | P99=%.4f ms | P99.9=%.4f ms\n",
    summary.p50FrameTimeMs, summary.p95FrameTimeMs, summary.p99FrameTimeMs, summary.p999FrameTimeMs);
  fprintf(fp, "Dropped / Spike Frames : >1.5x Budget=%llu | >16.7ms=%llu | >25ms=%llu | >33.3ms=%llu | >50ms=%llu\n\n",
    (unsigned long long)summary.droppedFrames,
    (unsigned long long)summary.spikeCount16Ms,
    (unsigned long long)summary.spikeCount25Ms,
    (unsigned long long)summary.spikeCount33Ms,
    (unsigned long long)summary.spikeCount50Ms);

  fprintf(fp, "[2] SUBSYSTEM TIMINGS (UPDATES, RENDERING, AUDIO)\n");
  fprintf(fp, "--------------------------------------------------------------------------------\n");
  fprintf(fp, "Update Timings         : Avg=%.4f ms | P95=%.4f ms | Max=%.4f ms\n",
    summary.avgUpdateTimeMs, summary.p95UpdateTimeMs, summary.maxUpdateTimeMs);
  fprintf(fp, "Render Timings         : Avg=%.4f ms | P95=%.4f ms | Max=%.4f ms\n",
    summary.avgRenderTimeMs, summary.p95RenderTimeMs, summary.maxRenderTimeMs);
  fprintf(fp, "Audio Timings          : Avg=%.4f ms | P95=%.4f ms | Max=%.4f ms\n",
    summary.avgAudioTimeMs, summary.p95AudioTimeMs, summary.maxAudioTimeMs);
  fprintf(fp, "Other / Unaccounted    : Avg=%.4f ms | Max=%.4f ms\n",
    summary.avgOtherTimeMs, summary.maxOtherTimeMs);
  fprintf(fp, "Draw Calls             : Avg=%.1f / frame | Max=%u\n\n",
    summary.avgDrawCalls, (unsigned int)summary.maxDrawCalls);

  fprintf(fp, "[3] GARBAGE COLLECTION (GC PAUSES & HEAP CONTRACTIONS)\n");
  fprintf(fp, "--------------------------------------------------------------------------------\n");
  fprintf(fp, "Measured GC Events     : %llu (Explicit: %llu)\n",
    (unsigned long long)summary.totalGcCount,
    (unsigned long long)summary.totalExplicitGcCount);
  fprintf(fp, "Observed Contractions  : %llu intervals (uninstrumented negative heap deltas; heuristic)\n",
    (unsigned long long)summary.totalImplicitGcCount);
  fprintf(fp, "Frames With GC Activity: %llu\n",
    (unsigned long long)summary.framesWithGc);
  fprintf(fp, "Measured GC Pause Time : Total=%.4f ms | Avg=%.4f ms | Max=%.4f ms (Frame #%llu)\n",
    summary.totalGcPauseMs,
    summary.avgGcPauseMs,
    summary.maxGcPauseMs,
    (unsigned long long)summary.maxGcPauseFrame);
  fprintf(fp, "Observed Reclaimed Heap: %llu bytes (%.2f MB)\n\n",
    (unsigned long long)summary.totalGcReclaimedBytes,
    (double)summary.totalGcReclaimedBytes / (1024.0 * 1024.0));

  fprintf(fp, "[4] ALLOCATIONS & MEMORY USAGE\n");
  fprintf(fp, "--------------------------------------------------------------------------------\n");
  if (summary.heapStatsAvailable)
  {
    fprintf(fp, "Observed Alloc Growth  : %llu bytes (%.2f MB) across %llu positive-delta intervals\n",
      (unsigned long long)summary.totalAllocBytes,
      (double)summary.totalAllocBytes / (1024.0 * 1024.0),
      (unsigned long long)summary.totalAllocCount);
    fprintf(fp, "Avg Alloc / Frame      : %.1f bytes/frame (%.2f KB/frame)\n",
      summary.avgAllocBytesPerFrame, summary.avgAllocBytesPerFrame / 1024.0);
    fprintf(fp, "Allocation Rate        : %.2f KB/s (%.2f MB/s)\n",
      summary.allocRateBytesPerSec / 1024.0,
      summary.allocRateBytesPerSec / (1024.0 * 1024.0));
    fprintf(fp, "Peak Frame Allocation  : %lld bytes (%.2f KB) on Frame #%llu\n",
      (long long)summary.peakFrameAllocBytes,
      (double)summary.peakFrameAllocBytes / 1024.0,
      (unsigned long long)summary.peakFrameAllocFrame);
    fprintf(fp, "Managed Heap (Current) : Used=%lld bytes (%.2f MB) | Reserved=%lld bytes (%.2f MB)\n",
      (long long)summary.currentHeapUsedBytes,
      (double)summary.currentHeapUsedBytes / (1024.0 * 1024.0),
      (long long)summary.currentHeapReservedBytes,
      (double)summary.currentHeapReservedBytes / (1024.0 * 1024.0));
    fprintf(fp, "Managed Heap (Peak)    : Used=%lld bytes (%.2f MB) | Reserved=%lld bytes (%.2f MB)\n",
      (long long)summary.peakHeapUsedBytes,
      (double)summary.peakHeapUsedBytes / (1024.0 * 1024.0),
      (long long)summary.peakHeapReservedBytes,
      (double)summary.peakHeapReservedBytes / (1024.0 * 1024.0));
  }
  else
  {
    fprintf(fp, "Managed Heap Metrics   : N/A (not collected or unavailable on this runtime)\n");
  }
  if (summary.rssAvailable)
  {
    fprintf(fp, "Process RSS Memory     : Current=%zu bytes (%.2f MB) | Peak=%zu bytes (%.2f MB)\n\n",
      summary.currentRssBytes,
      (double)summary.currentRssBytes / (1024.0 * 1024.0),
      summary.peakRssBytes,
      (double)summary.peakRssBytes / (1024.0 * 1024.0));
  }
  else
  {
    fprintf(fp, "Process RSS Memory     : N/A (unavailable or disabled)\n\n");
  }

  /* Identify top N slowest frames in the buffered ring */
  for (i = 0; i < state->ringCount; ++i)
  {
    double ft = state->samples[i].frameTimeMs;
    size_t insertPos = slowestCount;
    for (j = 0; j < slowestCount; ++j)
    {
      if (ft > state->samples[slowestIndices[j]].frameTimeMs)
      {
        insertPos = j;
        break;
      }
    }
    if (insertPos < PHOENIX_PROFILER_TOP_SLOWEST_COUNT)
    {
      size_t limit = slowestCount < (PHOENIX_PROFILER_TOP_SLOWEST_COUNT - 1)
        ? slowestCount
        : (PHOENIX_PROFILER_TOP_SLOWEST_COUNT - 1);
      for (j = limit; j > insertPos; --j)
        slowestIndices[j] = slowestIndices[j - 1];
      slowestIndices[insertPos] = i;
      if (slowestCount < PHOENIX_PROFILER_TOP_SLOWEST_COUNT)
        ++slowestCount;
    }
  }

  fprintf(fp, "[5] TOP SLOWEST FRAMES (BOTTLENECK ANALYSIS)\n");
  fprintf(fp, "--------------------------------------------------------------------------------\n");
  if (slowestCount == 0)
  {
    fprintf(fp, "No frames recorded.\n\n");
  }
  else
  {
    for (i = 0; i < slowestCount; ++i)
    {
      const PhoenixFrameSample *s = &state->samples[slowestIndices[i]];
      char sState[PHOENIX_PROFILER_STATE_NAME_MAX];
      phoenixProfilerCopyString(sState, sizeof(sState), s->stateName);
      fprintf(
        fp,
        "#%02zu Frame %llu @ %.2fms: Frametime=%.4fms (%.1f FPS) | Upd=%.4fms | Rnd=%.4fms | Aud=%.4fms | GC=%.4fms | Alloc=%lldB | Bottleneck=%s | State=%s\n",
        i + 1,
        (unsigned long long)s->frameIndex,
        s->timestampMs,
        s->frameTimeMs,
        s->fps,
        s->updateTimeMs,
        s->renderTimeMs,
        s->audioTimeMs,
        s->gcPauseMs,
        (long long)s->allocBytes,
        phoenixProfilerDominantSubsystem(s),
        sState);
    }
    fprintf(fp, "\n");
  }

  fprintf(fp, "[6] PER-FRAME TIMELINE (CSV)\n");
  fprintf(fp, "--------------------------------------------------------------------------------\n");
  fprintf(
    fp,
    "frame,timestamp_ms,frametime_ms,work_ms,fps,rolling_fps,update_ms,render_ms,audio_ms,gc_pause_ms,other_ms,alloc_bytes,alloc_count,gc_reclaimed_bytes,net_heap_delta_bytes,heap_used_bytes,heap_reserved_bytes,rss_bytes,peak_rss_bytes,gc_count,explicit_gc,implicit_gc,draw_calls,update_steps,state\n");

  for (i = 0; i < state->ringCount; ++i)
  {
    PhoenixFrameSample s;
    char csvState[PHOENIX_PROFILER_STATE_NAME_MAX * 2 + 4];
    if (!phoenixProfilerGetBufferedFrame(state, i, &s))
      continue;
    phoenixProfilerFormatCsvField(s.stateName, csvState, sizeof(csvState));
    fprintf(
      fp,
      "%llu,%.4f,%.4f,%.4f,%.2f,%.2f,%.4f,%.4f,%.4f,%.4f,%.4f,%lld,%u,%lld,%lld,%lld,%lld,%zu,%zu,%u,%u,%u,%u,%u,%s\n",
      (unsigned long long)s.frameIndex,
      s.timestampMs,
      s.frameTimeMs,
      s.workTimeMs,
      s.fps,
      s.rollingFps,
      s.updateTimeMs,
      s.renderTimeMs,
      s.audioTimeMs,
      s.gcPauseMs,
      s.otherTimeMs,
      (long long)s.allocBytes,
      (unsigned int)s.allocCount,
      (long long)s.gcReclaimedBytes,
      (long long)s.netHeapDeltaBytes,
      (long long)s.heapUsedBytes,
      (long long)s.heapReservedBytes,
      s.rssBytes,
      s.peakRssBytes,
      (unsigned int)s.gcCount,
      (unsigned int)s.explicitGcCount,
      (unsigned int)s.implicitGcCount,
      (unsigned int)s.drawCalls,
      (unsigned int)s.updateSteps,
      csvState);
  }

  if (ferror(fp) != 0)
  {
    fclose(fp);
    (void)remove(tempPath);
    state->exportInProgress = 0;
    return 0;
  }
  if (fflush(fp) != 0)
  {
    fclose(fp);
    (void)remove(tempPath);
    state->exportInProgress = 0;
    return 0;
  }
  if (fclose(fp) != 0)
  {
    (void)remove(tempPath);
    state->exportInProgress = 0;
    return 0;
  }

  if (!phoenixProfilerFinalizeTempFile(tempPath, resolvedPath))
  {
    (void)remove(tempPath);
    state->exportInProgress = 0;
    return 0;
  }

  state->exportInProgress = 0;
  if (outResolvedPath != NULL && outResolvedCapacity > 0)
  {
    snprintf(outResolvedPath, outResolvedCapacity, "%s", resolvedPath);
  }
  return 1;
}

#ifdef __cplusplus
}
#endif

#endif /* PHOENIX_PROFILER_H */
