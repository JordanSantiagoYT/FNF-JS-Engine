#ifndef PHOENIX_PROFILER_H
#define PHOENIX_PROFILER_H

#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>
#include <direct.h>
#elif defined(__unix__) || defined(__unix) || defined(unix) || (defined(__APPLE__) && defined(__MACH__))
#include <unistd.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#if defined(__APPLE__) && defined(__MACH__)
#include <mach/mach.h>
#include <mach/mach_time.h>
#endif
#endif

#ifndef PHOENIX_PROFILER_RING_CAPACITY
#define PHOENIX_PROFILER_RING_CAPACITY 2048
#endif

#ifndef PHOENIX_PROFILER_STATE_NAME_MAX
#define PHOENIX_PROFILER_STATE_NAME_MAX 64
#endif

#ifndef PHOENIX_PROFILER_PATH_MAX
#define PHOENIX_PROFILER_PATH_MAX 512
#endif

#define PHOENIX_PROFILER_LOG_DIR "debug/log"
#define PHOENIX_PROFILER_DEFAULT_LOG_FILE "debug/log/frame_profiler.log"

#define PHOENIX_PHASE_UPDATE 0
#define PHOENIX_PHASE_RENDER 1
#define PHOENIX_PHASE_AUDIO 2
#define PHOENIX_PHASE_GC 3
#define PHOENIX_PHASE_COUNT 4

/**
 * Single-frame profiler sample stored in the circular frame buffer.
 * All time values are in milliseconds; all memory values are in bytes.
 */
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
  int64_t allocBytes;
  int64_t netHeapDeltaBytes;
  int64_t gcReclaimedBytes;
  int64_t heapUsedBytes;
  int64_t heapReservedBytes;
  size_t rssBytes;
  size_t peakRssBytes;
  int allocCount;
  int gcCount;
  int explicitGcCount;
  int implicitGcCount;
  int updateSteps;
  int drawCalls;
  char stateName[PHOENIX_PROFILER_STATE_NAME_MAX];
} PhoenixFrameSample;

/**
 * Aggregated frame profiler summary across the session and buffered window.
 */
typedef struct PhoenixProfilerSummary
{
  uint64_t totalFrames;
  size_t bufferedFrames;
  double targetFps;
  double sessionDurationMs;
  double cpuTimeMs;
  double cpuUtilizationPct;

  double avgFrameTimeMs;
  double minFrameTimeMs;
  double maxFrameTimeMs;
  double stdDevFrameTimeMs;
  double p50FrameTimeMs;
  double p95FrameTimeMs;
  double p99FrameTimeMs;
  double p999FrameTimeMs;
  uint64_t spikeCount25Ms;
  uint64_t spikeCount33Ms;

  double avgFps;
  double currentFps;
  double minFps;
  double maxFps;
  double onePercentLowFps;
  double pointOnePercentLowFps;

  double avgUpdateTimeMs;
  double maxUpdateTimeMs;
  double p99UpdateTimeMs;
  double totalUpdateTimeMs;
  double updateFrameSharePct;

  double avgRenderTimeMs;
  double maxRenderTimeMs;
  double p99RenderTimeMs;
  double totalRenderTimeMs;
  double renderFrameSharePct;

  double avgAudioTimeMs;
  double maxAudioTimeMs;
  double p99AudioTimeMs;
  double totalAudioTimeMs;
  double audioFrameSharePct;

  uint64_t totalGcCount;
  uint64_t totalExplicitGcCount;
  uint64_t totalImplicitGcCount;
  uint64_t framesWithGc;
  double totalGcPauseMs;
  double avgGcPausePerFrameMs;
  double avgGcPausePerCollectionMs;
  double maxGcPauseMs;
  uint64_t maxGcPauseFrame;
  double gcFrameSharePct;
  int64_t totalGcReclaimedBytes;

  int64_t totalAllocBytes;
  uint64_t totalAllocCount;
  double avgAllocBytesPerFrame;
  double allocRateBytesPerSec;
  int64_t peakFrameAllocBytes;
  uint64_t peakFrameAllocFrame;
  int64_t startHeapUsedBytes;
  int64_t currentHeapUsedBytes;
  int64_t peakHeapUsedBytes;
  int64_t currentHeapReservedBytes;
  size_t currentRssBytes;
  size_t peakRssBytes;
} PhoenixProfilerSummary;

/**
 * Self-contained frame profiler state with a fixed-capacity ring buffer.
 * Holds all per-frame and session accumulators without dynamic allocation.
 */
typedef struct PhoenixProfilerState
{
  int initialized;
  int enabled;
  int inFlightFrame;
  int hasObservedHeap;

  double targetFps;
  double sessionStartTimeMs;
  double sessionStartCpuSeconds;
  double currentFrameStartMs;
  double lastFrameStartMs;
  double lastFrameEndMs;

  double phaseStartMs[PHOENIX_PHASE_COUNT];
  int64_t phaseHeapStart[PHOENIX_PHASE_COUNT];
  int phaseDepth[PHOENIX_PHASE_COUNT];

  double nestedAudioInUpdateMs;
  double nestedGcInUpdateMs;
  double nestedGcInRenderMs;
  double nestedGcInAudioMs;

  double emaUpdateMs;
  double emaRenderMs;
  double emaAudioMs;

  int64_t frameStartHeapBytes;
  int64_t lastObservedHeapBytes;
  int64_t lastObservedReservedBytes;

  double rollingWindowMs;
  int rollingWindowFrames;
  double currentRollingFps;

  uint64_t totalFrames;
  double totalDurationMs;
  double minFrameTimeMs;
  double maxFrameTimeMs;
  double sumFrameTimeMs;
  double sumSqFrameTimeMs;
  uint64_t spikeCount25Ms;
  uint64_t spikeCount33Ms;

  double totalUpdateTimeMs;
  double maxUpdateTimeMs;
  double totalRenderTimeMs;
  double maxRenderTimeMs;
  double totalAudioTimeMs;
  double maxAudioTimeMs;

  uint64_t totalGcCount;
  uint64_t totalExplicitGcCount;
  uint64_t totalImplicitGcCount;
  uint64_t framesWithGc;
  double totalGcPauseMs;
  double maxGcPauseMs;
  uint64_t maxGcPauseFrame;
  int64_t totalGcReclaimedBytes;

  int64_t totalAllocBytes;
  uint64_t totalAllocCount;
  int64_t peakFrameAllocBytes;
  uint64_t peakFrameAllocFrame;
  int64_t startHeapUsedBytes;
  int64_t currentHeapUsedBytes;
  int64_t peakHeapUsedBytes;
  int64_t currentHeapReservedBytes;
  size_t currentRssBytes;
  size_t peakRssBytes;

  char currentStateName[PHOENIX_PROFILER_STATE_NAME_MAX];
  PhoenixFrameSample activeSample;

  size_t writeIndex;
  size_t sampleCount;
  PhoenixFrameSample samples[PHOENIX_PROFILER_RING_CAPACITY];
} PhoenixProfilerState;

/**
 * Monotonic timestamp in milliseconds from an unspecified origin.
 * Returns zero if unavailable on this platform.
 */
static inline double phoenixProfilerNowMs(void)
{
#if defined(_WIN32)
  LARGE_INTEGER counter, frequency;
  if (!QueryPerformanceFrequency(&frequency) || frequency.QuadPart <= 0 || !QueryPerformanceCounter(&counter))
    return 0.0;
  return ((double)counter.QuadPart * 1000.0) / (double)frequency.QuadPart;
#elif defined(__APPLE__) && defined(__MACH__)
  mach_timebase_info_data_t scale;
  if (mach_timebase_info(&scale) != KERN_SUCCESS || scale.denom == 0)
    return 0.0;
  return (double)mach_absolute_time() * ((double)scale.numer / (double)scale.denom) / 1e6;
#elif defined(CLOCK_MONOTONIC)
  struct timespec value;
  if (clock_gettime(CLOCK_MONOTONIC, &value) != 0)
    return 0.0;
  return (double)value.tv_sec * 1000.0 + (double)value.tv_nsec / 1e6;
#else
  return 0.0;
#endif
}

/**
 * Total user + kernel CPU seconds consumed by the current process.
 * Returns zero if unavailable on this platform.
 */
static inline double phoenixProfilerCpuSeconds(void)
{
#if defined(_WIN32)
  FILETIME creation, exitTime, kernel, user;
  ULARGE_INTEGER kernelTicks, userTicks;
  if (!GetProcessTimes(GetCurrentProcess(), &creation, &exitTime, &kernel, &user))
    return 0.0;
  kernelTicks.LowPart = kernel.dwLowDateTime;
  kernelTicks.HighPart = kernel.dwHighDateTime;
  userTicks.LowPart = user.dwLowDateTime;
  userTicks.HighPart = user.dwHighDateTime;
  return ((double)kernelTicks.QuadPart + (double)userTicks.QuadPart) / 1e7;
#elif defined(__unix__) || defined(__unix) || defined(unix) || (defined(__APPLE__) && defined(__MACH__))
  struct rusage usage;
  if (getrusage(RUSAGE_SELF, &usage) != 0)
    return 0.0;
  return (double)usage.ru_utime.tv_sec + (double)usage.ru_stime.tv_sec +
    ((double)usage.ru_utime.tv_usec + (double)usage.ru_stime.tv_usec) / 1e6;
#else
  return 0.0;
#endif
}

/**
 * Current process resident set size (physical RAM) in bytes.
 * Returns zero if unavailable on this platform.
 */
static inline size_t phoenixProfilerCurrentRSS(void)
{
#if defined(_WIN32)
  PROCESS_MEMORY_COUNTERS info;
  if (!GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info)))
    return (size_t)0;
  return (size_t)info.WorkingSetSize;
#elif defined(__APPLE__) && defined(__MACH__)
  struct mach_task_basic_info info;
  mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS)
    return (size_t)0;
  return (size_t)info.resident_size;
#elif defined(__linux__) || defined(__linux) || defined(linux) || defined(__gnu_linux__)
  long rssPages = 0L;
  long pageSize = 0L;
  FILE *fp = fopen("/proc/self/statm", "r");
  if (fp == NULL)
    return (size_t)0;
  if (fscanf(fp, "%*s%ld", &rssPages) != 1)
  {
    fclose(fp);
    return (size_t)0;
  }
  fclose(fp);
  pageSize = sysconf(_SC_PAGESIZE);
  if (rssPages <= 0 || pageSize <= 0)
    return (size_t)0;
  return (size_t)rssPages * (size_t)pageSize;
#else
  return (size_t)0;
#endif
}

/**
 * Peak process resident set size (physical RAM) in bytes.
 * Returns zero if unavailable on this platform.
 */
static inline size_t phoenixProfilerPeakRSS(void)
{
#if defined(_WIN32)
  PROCESS_MEMORY_COUNTERS info;
  if (!GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info)))
    return (size_t)0;
  return (size_t)info.PeakWorkingSetSize;
#elif defined(__unix__) || defined(__unix) || defined(unix) || (defined(__APPLE__) && defined(__MACH__))
  struct rusage usage;
  size_t peak = (size_t)0;
  size_t current = phoenixProfilerCurrentRSS();
  if (getrusage(RUSAGE_SELF, &usage) == 0 && usage.ru_maxrss > 0)
  {
#if defined(__APPLE__) && defined(__MACH__)
    peak = (size_t)usage.ru_maxrss;
#else
    peak = (size_t)usage.ru_maxrss * (size_t)1024;
#endif
  }
  return current > peak ? current : peak;
#else
  return (size_t)0;
#endif
}

/**
 * Dependency-free square root helper (Newton-Raphson) so callers do not need -lm.
 * Returns zero for non-positive inputs.
 */
static inline double phoenixProfilerSqrt(double value)
{
  double guess;
  double scale = 1.0;
  double scaled = value;
  int i;
  if (value <= 0.0)
    return 0.0;
  while (scaled >= 4.0)
  {
    scaled *= 0.25;
    scale *= 2.0;
  }
  while (scaled < 0.25)
  {
    scaled *= 4.0;
    scale *= 0.5;
  }
  guess = 0.5 * (1.0 + scaled);
  for (i = 0; i < 8; ++i)
    guess = 0.5 * (guess + scaled / guess);
  return guess * scale;
}

/**
 * In-place heap sort for an array of doubles in ascending order.
 */
static inline void phoenixProfilerSortDoubles(double *values, size_t count)
{
  size_t start;
  size_t end;
  if (values == NULL || count < 2)
    return;

  start = count / 2;
  while (start > 0)
  {
    size_t root;
    --start;
    root = start;
    while (root * 2 + 1 < count)
    {
      size_t child = root * 2 + 1;
      size_t swapIdx = root;
      if (values[swapIdx] < values[child])
        swapIdx = child;
      if (child + 1 < count && values[swapIdx] < values[child + 1])
        swapIdx = child + 1;
      if (swapIdx == root)
        break;
      {
        double tmp = values[root];
        values[root] = values[swapIdx];
        values[swapIdx] = tmp;
        root = swapIdx;
      }
    }
  }

  end = count - 1;
  while (end > 0)
  {
    double tmp = values[end];
    size_t root = 0;
    values[end] = values[0];
    values[0] = tmp;
    while (root * 2 + 1 < end)
    {
      size_t child = root * 2 + 1;
      size_t swapIdx = root;
      if (values[swapIdx] < values[child])
        swapIdx = child;
      if (child + 1 < end && values[swapIdx] < values[child + 1])
        swapIdx = child + 1;
      if (swapIdx == root)
        break;
      tmp = values[root];
      values[root] = values[swapIdx];
      values[swapIdx] = tmp;
      root = swapIdx;
    }
    --end;
  }
}

/**
 * Selects a percentile (0.0 to 1.0) from a sorted ascending array of doubles.
 * Returns zero if count is zero.
 */
static inline double phoenixProfilerPercentileSorted(const double *sortedValues, size_t count, double percentile)
{
  double pos;
  size_t lower;
  size_t upper;
  double weight;
  if (sortedValues == NULL || count == 0)
    return 0.0;
  if (percentile <= 0.0)
    return sortedValues[0];
  if (percentile >= 1.0)
    return sortedValues[count - 1];
  pos = percentile * (double)(count - 1);
  lower = (size_t)pos;
  upper = lower + 1 < count ? lower + 1 : lower;
  weight = pos - (double)lower;
  return sortedValues[lower] * (1.0 - weight) + sortedValues[upper] * weight;
}

/**
 * Copies a state name safely into a fixed-size destination buffer.
 */
static inline void phoenixProfilerCopyString(char *dest, size_t capacity, const char *src, const char *fallback)
{
  const char *chosen = (src != NULL && src[0] != '\0') ? src : fallback;
  size_t i = 0;
  if (dest == NULL || capacity == 0)
    return;
  if (chosen == NULL)
  {
    dest[0] = '\0';
    return;
  }
  while (i + 1 < capacity && chosen[i] != '\0')
  {
    char ch = chosen[i];
    if (ch == '\r' || ch == '\n' || ch == ',')
      ch = '_';
    dest[i] = ch;
    ++i;
  }
  dest[i] = '\0';
}

/**
 * Initializes or resets a PhoenixProfilerState with the specified target FPS.
 */
static inline void phoenixProfilerInit(PhoenixProfilerState *state, double targetFps)
{
  if (state == NULL)
    return;
  memset(state, 0, sizeof(PhoenixProfilerState));
  state->initialized = 1;
  state->enabled = 1;
  state->targetFps = targetFps > 0.0 ? targetFps : 60.0;
  state->sessionStartTimeMs = phoenixProfilerNowMs();
  state->sessionStartCpuSeconds = phoenixProfilerCpuSeconds();
  state->currentRssBytes = phoenixProfilerCurrentRSS();
  state->peakRssBytes = phoenixProfilerPeakRSS();
  phoenixProfilerCopyString(state->currentStateName, PHOENIX_PROFILER_STATE_NAME_MAX, "InitState", "Unknown");
}

/**
 * Resets all recorded frames and accumulators while preserving targetFps and enabled flag.
 */
static inline void phoenixProfilerReset(PhoenixProfilerState *state)
{
  double targetFps;
  int enabled;
  char savedState[PHOENIX_PROFILER_STATE_NAME_MAX];
  if (state == NULL)
    return;
  targetFps = state->initialized && state->targetFps > 0.0 ? state->targetFps : 60.0;
  enabled = state->initialized ? state->enabled : 1;
  phoenixProfilerCopyString(savedState, PHOENIX_PROFILER_STATE_NAME_MAX,
    state->initialized ? state->currentStateName : "Unknown", "Unknown");
  phoenixProfilerInit(state, targetFps);
  state->enabled = enabled;
  phoenixProfilerCopyString(state->currentStateName, PHOENIX_PROFILER_STATE_NAME_MAX, savedState, "Unknown");
}

/**
 * Enables (non-zero) or pauses (zero) frame profiling on the given state.
 */
static inline void phoenixProfilerSetEnabled(PhoenixProfilerState *state, int enabled)
{
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  state->enabled = enabled ? 1 : 0;
  if (!state->enabled)
    state->inFlightFrame = 0;
}

/**
 * Returns non-zero if the profiler is currently enabled, zero otherwise.
 */
static inline int phoenixProfilerIsEnabled(const PhoenixProfilerState *state)
{
  if (state == NULL)
    return 0;
  return state->initialized ? state->enabled : 1;
}

/**
 * Updates the target framerate used for frame-budget comparisons.
 */
static inline void phoenixProfilerSetTargetFps(PhoenixProfilerState *state, double targetFps)
{
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, targetFps);
  if (targetFps > 0.0)
    state->targetFps = targetFps;
}

/**
 * Updates the active game state label attached to subsequent frames.
 */
static inline void phoenixProfilerSetStateName(PhoenixProfilerState *state, const char *stateName)
{
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  phoenixProfilerCopyString(state->currentStateName, PHOENIX_PROFILER_STATE_NAME_MAX, stateName, "Unknown");
  if (state->inFlightFrame)
    phoenixProfilerCopyString(state->activeSample.stateName, PHOENIX_PROFILER_STATE_NAME_MAX, stateName, "Unknown");
}

/**
 * Internal helper that inspects GC heap changes between phase boundaries.
 * Positive deltas record allocations; negative deltas record GC collections.
 */
static inline void phoenixProfilerObserveHeap(
  PhoenixProfilerState *state,
  int64_t heapUsedBytes,
  int isExplicitGcEnd,
  double phaseElapsedMs,
  int activePhase)
{
  int64_t delta;
  if (state == NULL || heapUsedBytes < 0)
    return;

  if (!state->hasObservedHeap)
  {
    state->lastObservedHeapBytes = heapUsedBytes;
    state->frameStartHeapBytes = heapUsedBytes;
    state->startHeapUsedBytes = heapUsedBytes;
    state->currentHeapUsedBytes = heapUsedBytes;
    state->peakHeapUsedBytes = heapUsedBytes;
    state->hasObservedHeap = 1;
    return;
  }

  delta = heapUsedBytes - state->lastObservedHeapBytes;
  if (delta > 0)
  {
    state->activeSample.allocBytes += delta;
    state->activeSample.allocCount += 1;
  }
  else if (delta < 0)
  {
    int64_t reclaimed = -delta;
    state->activeSample.gcReclaimedBytes += reclaimed;
    if (!isExplicitGcEnd && state->phaseDepth[PHOENIX_PHASE_GC] <= 0)
    {
      double estimatedPauseMs = 0.0;
      state->activeSample.implicitGcCount += 1;
      state->activeSample.gcCount += 1;
      if (phaseElapsedMs > 0.0)
      {
        double baselineMs = 0.0;
        if (activePhase == PHOENIX_PHASE_UPDATE)
          baselineMs = state->emaUpdateMs;
        else if (activePhase == PHOENIX_PHASE_RENDER)
          baselineMs = state->emaRenderMs;
        else if (activePhase == PHOENIX_PHASE_AUDIO)
          baselineMs = state->emaAudioMs;

        if (baselineMs > 0.0 && phaseElapsedMs > baselineMs)
          estimatedPauseMs = phaseElapsedMs - baselineMs;
        else
          estimatedPauseMs = phaseElapsedMs * 0.25;

        if (estimatedPauseMs < 0.02)
          estimatedPauseMs = 0.02;
        if (estimatedPauseMs > phaseElapsedMs * 0.9)
          estimatedPauseMs = phaseElapsedMs * 0.9;

        state->activeSample.gcPauseMs += estimatedPauseMs;
        if (activePhase == PHOENIX_PHASE_AUDIO)
          state->nestedGcInAudioMs += estimatedPauseMs;
        else if (activePhase == PHOENIX_PHASE_UPDATE)
          state->nestedGcInUpdateMs += estimatedPauseMs;
        else if (activePhase == PHOENIX_PHASE_RENDER)
          state->nestedGcInRenderMs += estimatedPauseMs;
      }
    }
  }

  state->lastObservedHeapBytes = heapUsedBytes;
  state->currentHeapUsedBytes = heapUsedBytes;
  if (heapUsedBytes > state->peakHeapUsedBytes)
    state->peakHeapUsedBytes = heapUsedBytes;
}

/**
 * Begins recording a new frame at an explicit monotonic timestamp (ms).
 */
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

  if (state->totalFrames == 0 && !state->inFlightFrame)
  {
    state->sessionStartTimeMs = nowMs;
    state->sessionStartCpuSeconds = phoenixProfilerCpuSeconds();
    if (heapUsedBytes > 0)
      state->startHeapUsedBytes = heapUsedBytes;
  }

  memset(&state->activeSample, 0, sizeof(PhoenixFrameSample));
  phoenixProfilerCopyString(
    state->activeSample.stateName,
    PHOENIX_PROFILER_STATE_NAME_MAX,
    state->currentStateName,
    "Unknown");

  for (i = 0; i < PHOENIX_PHASE_COUNT; ++i)
  {
    state->phaseStartMs[i] = 0.0;
    state->phaseHeapStart[i] = heapUsedBytes;
    state->phaseDepth[i] = 0;
  }

  state->nestedAudioInUpdateMs = 0.0;
  state->nestedGcInUpdateMs = 0.0;
  state->nestedGcInRenderMs = 0.0;
  state->nestedGcInAudioMs = 0.0;

  if (heapUsedBytes >= 0)
    phoenixProfilerObserveHeap(state, heapUsedBytes, 0, 0.0, -1);

  state->frameStartHeapBytes = heapUsedBytes >= 0 ? heapUsedBytes : state->lastObservedHeapBytes;
  if (heapReservedBytes >= 0)
  {
    state->lastObservedReservedBytes = heapReservedBytes;
    state->currentHeapReservedBytes = heapReservedBytes;
  }
  state->currentFrameStartMs = nowMs;
  state->inFlightFrame = 1;
}

/**
 * Begins recording a new frame using the native monotonic clock.
 */
static inline void phoenixProfilerBeginFrame(
  PhoenixProfilerState *state,
  int64_t heapUsedBytes,
  int64_t heapReservedBytes)
{
  phoenixProfilerBeginFrameAt(state, phoenixProfilerNowMs(), heapUsedBytes, heapReservedBytes);
}

/**
 * Begins a subsystem phase (PHOENIX_PHASE_UPDATE, RENDER, AUDIO, or GC) at an explicit timestamp.
 */
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
  if (!state->inFlightFrame)
    phoenixProfilerBeginFrameAt(state, nowMs, heapUsedBytes, state->lastObservedReservedBytes);

  if (heapUsedBytes >= 0)
    phoenixProfilerObserveHeap(state, heapUsedBytes, 0, 0.0, -1);

  if (state->phaseDepth[phase] == 0)
  {
    state->phaseStartMs[phase] = nowMs;
    state->phaseHeapStart[phase] = state->lastObservedHeapBytes;
    if (phase == PHOENIX_PHASE_UPDATE)
      state->activeSample.updateSteps += 1;
  }
  state->phaseDepth[phase] += 1;
}

/**
 * Begins a subsystem phase using the native monotonic clock.
 */
static inline void phoenixProfilerBeginPhase(
  PhoenixProfilerState *state,
  int phase,
  int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhaseAt(state, phase, phoenixProfilerNowMs(), heapUsedBytes);
}

/**
 * Ends a subsystem phase at an explicit timestamp and returns the net phase duration in milliseconds.
 */
static inline double phoenixProfilerEndPhaseAt(
  PhoenixProfilerState *state,
  int phase,
  double nowMs,
  int64_t heapUsedBytes)
{
  double rawElapsedMs;
  double netElapsedMs;
  if (state == NULL || phase < 0 || phase >= PHOENIX_PHASE_COUNT)
    return 0.0;
  if (!state->initialized || !state->enabled || !state->inFlightFrame)
    return 0.0;
  if (state->phaseDepth[phase] <= 0)
    return 0.0;

  state->phaseDepth[phase] -= 1;
  if (state->phaseDepth[phase] > 0)
    return 0.0;

  rawElapsedMs = nowMs - state->phaseStartMs[phase];
  if (rawElapsedMs < 0.0)
    rawElapsedMs = 0.0;

  if (phase == PHOENIX_PHASE_GC)
  {
    if (heapUsedBytes >= 0)
      phoenixProfilerObserveHeap(state, heapUsedBytes, 1, rawElapsedMs, PHOENIX_PHASE_GC);
    state->activeSample.explicitGcCount += 1;
    state->activeSample.gcCount += 1;
    state->activeSample.gcPauseMs += rawElapsedMs;

    if (state->phaseDepth[PHOENIX_PHASE_AUDIO] > 0)
      state->nestedGcInAudioMs += rawElapsedMs;
    else if (state->phaseDepth[PHOENIX_PHASE_UPDATE] > 0)
      state->nestedGcInUpdateMs += rawElapsedMs;
    else if (state->phaseDepth[PHOENIX_PHASE_RENDER] > 0)
      state->nestedGcInRenderMs += rawElapsedMs;

    return rawElapsedMs;
  }

  if (heapUsedBytes >= 0)
    phoenixProfilerObserveHeap(state, heapUsedBytes, 0, rawElapsedMs, phase);

  if (phase == PHOENIX_PHASE_AUDIO)
  {
    netElapsedMs = rawElapsedMs - state->nestedGcInAudioMs;
    state->nestedGcInAudioMs = 0.0;
    if (netElapsedMs < 0.0)
      netElapsedMs = 0.0;
    state->activeSample.audioTimeMs += netElapsedMs;
    state->emaAudioMs = state->emaAudioMs > 0.0
      ? (state->emaAudioMs * 0.9 + netElapsedMs * 0.1)
      : netElapsedMs;
    if (state->phaseDepth[PHOENIX_PHASE_UPDATE] > 0)
      state->nestedAudioInUpdateMs += rawElapsedMs;
    return netElapsedMs;
  }

  if (phase == PHOENIX_PHASE_UPDATE)
  {
    netElapsedMs = rawElapsedMs - state->nestedAudioInUpdateMs - state->nestedGcInUpdateMs;
    state->nestedAudioInUpdateMs = 0.0;
    state->nestedGcInUpdateMs = 0.0;
    if (netElapsedMs < 0.0)
      netElapsedMs = 0.0;
    state->activeSample.updateTimeMs += netElapsedMs;
    state->emaUpdateMs = state->emaUpdateMs > 0.0
      ? (state->emaUpdateMs * 0.9 + netElapsedMs * 0.1)
      : netElapsedMs;
    return netElapsedMs;
  }

  if (phase == PHOENIX_PHASE_RENDER)
  {
    netElapsedMs = rawElapsedMs - state->nestedGcInRenderMs;
    state->nestedGcInRenderMs = 0.0;
    if (netElapsedMs < 0.0)
      netElapsedMs = 0.0;
    state->activeSample.renderTimeMs += netElapsedMs;
    state->emaRenderMs = state->emaRenderMs > 0.0
      ? (state->emaRenderMs * 0.9 + netElapsedMs * 0.1)
      : netElapsedMs;
    return netElapsedMs;
  }

  return 0.0;
}

/**
 * Ends a subsystem phase using the native monotonic clock and returns duration in milliseconds.
 */
static inline double phoenixProfilerEndPhase(
  PhoenixProfilerState *state,
  int phase,
  int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhaseAt(state, phase, phoenixProfilerNowMs(), heapUsedBytes);
}

/**
 * Begins the game update phase.
 */
static inline void phoenixProfilerBeginUpdate(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhase(state, PHOENIX_PHASE_UPDATE, heapUsedBytes);
}

/**
 * Ends the game update phase and returns the net update duration in milliseconds.
 */
static inline double phoenixProfilerEndUpdate(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhase(state, PHOENIX_PHASE_UPDATE, heapUsedBytes);
}

/**
 * Begins the rendering phase.
 */
static inline void phoenixProfilerBeginRender(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhase(state, PHOENIX_PHASE_RENDER, heapUsedBytes);
}

/**
 * Ends the rendering phase and returns the net render duration in milliseconds.
 */
static inline double phoenixProfilerEndRender(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhase(state, PHOENIX_PHASE_RENDER, heapUsedBytes);
}

/**
 * Begins the audio phase.
 */
static inline void phoenixProfilerBeginAudio(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhase(state, PHOENIX_PHASE_AUDIO, heapUsedBytes);
}

/**
 * Ends the audio phase and returns the net audio duration in milliseconds.
 */
static inline double phoenixProfilerEndAudio(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhase(state, PHOENIX_PHASE_AUDIO, heapUsedBytes);
}

/**
 * Begins an explicit garbage collection pause measurement.
 */
static inline void phoenixProfilerBeginGC(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  phoenixProfilerBeginPhase(state, PHOENIX_PHASE_GC, heapUsedBytes);
}

/**
 * Ends an explicit garbage collection pause measurement and returns pause duration in milliseconds.
 */
static inline double phoenixProfilerEndGC(PhoenixProfilerState *state, int64_t heapUsedBytes)
{
  return phoenixProfilerEndPhase(state, PHOENIX_PHASE_GC, heapUsedBytes);
}

/**
 * Directly adds a pre-measured duration (ms) to the specified phase of the current frame.
 */
static inline void phoenixProfilerRecordPhaseMs(PhoenixProfilerState *state, int phase, double durationMs)
{
  if (state == NULL || durationMs <= 0.0 || phase < 0 || phase >= PHOENIX_PHASE_COUNT)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  if (!state->enabled)
    return;
  if (!state->inFlightFrame)
    phoenixProfilerBeginFrame(state, state->lastObservedHeapBytes, state->lastObservedReservedBytes);

  if (phase == PHOENIX_PHASE_UPDATE)
  {
    state->activeSample.updateTimeMs += durationMs;
    state->activeSample.updateSteps += 1;
  }
  else if (phase == PHOENIX_PHASE_RENDER)
  {
    state->activeSample.renderTimeMs += durationMs;
  }
  else if (phase == PHOENIX_PHASE_AUDIO)
  {
    state->activeSample.audioTimeMs += durationMs;
  }
  else if (phase == PHOENIX_PHASE_GC)
  {
    state->activeSample.gcPauseMs += durationMs;
    state->activeSample.explicitGcCount += 1;
    state->activeSample.gcCount += 1;
  }
}

/**
 * Directly records an allocation event (bytes and allocation count) on the current frame.
 */
static inline void phoenixProfilerRecordAllocation(PhoenixProfilerState *state, int64_t bytes, int count)
{
  if (state == NULL || bytes <= 0)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  if (!state->enabled)
    return;
  if (!state->inFlightFrame)
    phoenixProfilerBeginFrame(state, state->lastObservedHeapBytes, state->lastObservedReservedBytes);

  state->activeSample.allocBytes += bytes;
  state->activeSample.allocCount += count > 0 ? count : 1;
}

/**
 * Directly records a GC pause duration (ms) and reclaimed bytes on the current frame.
 */
static inline void phoenixProfilerRecordGCPause(
  PhoenixProfilerState *state,
  double pauseMs,
  int64_t reclaimedBytes,
  int isExplicit)
{
  if (state == NULL)
    return;
  if (!state->initialized)
    phoenixProfilerInit(state, 60.0);
  if (!state->enabled)
    return;
  if (!state->inFlightFrame)
    phoenixProfilerBeginFrame(state, state->lastObservedHeapBytes, state->lastObservedReservedBytes);

  if (pauseMs > 0.0)
    state->activeSample.gcPauseMs += pauseMs;
  if (reclaimedBytes > 0)
    state->activeSample.gcReclaimedBytes += reclaimedBytes;
  state->activeSample.gcCount += 1;
  if (isExplicit)
    state->activeSample.explicitGcCount += 1;
  else
    state->activeSample.implicitGcCount += 1;
}

/**
 * Adds draw call counts to the current frame.
 */
static inline void phoenixProfilerAddDrawCalls(PhoenixProfilerState *state, int drawCalls)
{
  if (state == NULL || drawCalls <= 0 || !state->initialized || !state->enabled)
    return;
  if (state->inFlightFrame)
    state->activeSample.drawCalls += drawCalls;
}

/**
 * Completes the current frame at an explicit timestamp, stores the sample in the ring buffer,
 * updates session statistics, and returns a pointer to the stored sample (or NULL if disabled).
 */
static inline const PhoenixFrameSample *phoenixProfilerEndFrameAt(
  PhoenixProfilerState *state,
  double nowMs,
  double explicitFrameTimeMs,
  int64_t heapUsedBytes,
  int64_t heapReservedBytes,
  int drawCalls)
{
  int phase;
  double workTimeMs;
  double frameTimeMs;
  double accountedMs;
  size_t rssBytes;
  size_t peakRssBytes;
  PhoenixFrameSample *stored;

  if (state == NULL)
    return NULL;
  if (!state->initialized || !state->enabled || !state->inFlightFrame)
    return NULL;

  for (phase = PHOENIX_PHASE_COUNT - 1; phase >= 0; --phase)
  {
    while (state->phaseDepth[phase] > 0)
      phoenixProfilerEndPhaseAt(state, phase, nowMs, heapUsedBytes);
  }

  if (heapUsedBytes >= 0)
    phoenixProfilerObserveHeap(state, heapUsedBytes, 0, 0.0, -1);
  if (heapReservedBytes >= 0)
  {
    state->lastObservedReservedBytes = heapReservedBytes;
    state->currentHeapReservedBytes = heapReservedBytes;
  }

  workTimeMs = nowMs - state->currentFrameStartMs;
  if (workTimeMs < 0.0)
    workTimeMs = 0.0;

  accountedMs = state->activeSample.updateTimeMs +
    state->activeSample.renderTimeMs +
    state->activeSample.audioTimeMs +
    state->activeSample.gcPauseMs;
  if (workTimeMs < accountedMs)
    workTimeMs = accountedMs;

  if (explicitFrameTimeMs > 0.0)
  {
    frameTimeMs = explicitFrameTimeMs >= workTimeMs ? explicitFrameTimeMs : workTimeMs;
  }
  else if (state->lastFrameEndMs > 0.0)
  {
    double deltaFromLastEnd = nowMs - state->lastFrameEndMs;
    frameTimeMs = (deltaFromLastEnd >= workTimeMs && deltaFromLastEnd < 10000.0)
      ? deltaFromLastEnd
      : workTimeMs;
  }
  else
  {
    frameTimeMs = workTimeMs;
  }

  if (frameTimeMs <= 0.0)
    frameTimeMs = state->targetFps > 0.0 ? (1000.0 / state->targetFps) : 16.6667;

  state->rollingWindowFrames += 1;
  state->rollingWindowMs += frameTimeMs;
  if (state->rollingWindowMs >= 1000.0)
  {
    state->currentRollingFps = ((double)state->rollingWindowFrames * 1000.0) / state->rollingWindowMs;
    state->rollingWindowFrames = 0;
    state->rollingWindowMs = 0.0;
  }
  else if (state->currentRollingFps <= 0.0)
  {
    state->currentRollingFps = ((double)state->rollingWindowFrames * 1000.0) / state->rollingWindowMs;
  }

  rssBytes = phoenixProfilerCurrentRSS();
  peakRssBytes = phoenixProfilerPeakRSS();
  if (rssBytes > peakRssBytes)
    peakRssBytes = rssBytes;
  state->currentRssBytes = rssBytes;
  if (peakRssBytes > state->peakRssBytes)
    state->peakRssBytes = peakRssBytes;

  state->totalFrames += 1;
  state->activeSample.frameIndex = state->totalFrames;
  state->activeSample.timestampMs = nowMs - state->sessionStartTimeMs;
  if (state->activeSample.timestampMs < 0.0)
    state->activeSample.timestampMs = state->totalDurationMs + frameTimeMs;
  state->activeSample.frameTimeMs = frameTimeMs;
  state->activeSample.workTimeMs = workTimeMs;
  state->activeSample.fps = 1000.0 / frameTimeMs;
  state->activeSample.rollingFps = state->currentRollingFps;
  state->activeSample.otherTimeMs = frameTimeMs > accountedMs ? (frameTimeMs - accountedMs) : 0.0;
  state->activeSample.heapUsedBytes = state->lastObservedHeapBytes;
  state->activeSample.heapReservedBytes = state->lastObservedReservedBytes;
  state->activeSample.netHeapDeltaBytes = state->lastObservedHeapBytes - state->frameStartHeapBytes;
  state->activeSample.rssBytes = rssBytes;
  state->activeSample.peakRssBytes = state->peakRssBytes;
  if (drawCalls > 0)
    state->activeSample.drawCalls += drawCalls;

  state->totalDurationMs += frameTimeMs;
  state->sumFrameTimeMs += frameTimeMs;
  state->sumSqFrameTimeMs += frameTimeMs * frameTimeMs;
  if (state->totalFrames == 1 || frameTimeMs < state->minFrameTimeMs)
    state->minFrameTimeMs = frameTimeMs;
  if (state->totalFrames == 1 || frameTimeMs > state->maxFrameTimeMs)
    state->maxFrameTimeMs = frameTimeMs;
  if (frameTimeMs > 25.0)
    state->spikeCount25Ms += 1;
  if (frameTimeMs > 33.3333)
    state->spikeCount33Ms += 1;

  state->totalUpdateTimeMs += state->activeSample.updateTimeMs;
  if (state->activeSample.updateTimeMs > state->maxUpdateTimeMs)
    state->maxUpdateTimeMs = state->activeSample.updateTimeMs;

  state->totalRenderTimeMs += state->activeSample.renderTimeMs;
  if (state->activeSample.renderTimeMs > state->maxRenderTimeMs)
    state->maxRenderTimeMs = state->activeSample.renderTimeMs;

  state->totalAudioTimeMs += state->activeSample.audioTimeMs;
  if (state->activeSample.audioTimeMs > state->maxAudioTimeMs)
    state->maxAudioTimeMs = state->activeSample.audioTimeMs;

  if (state->activeSample.gcCount > 0 || state->activeSample.gcPauseMs > 0.0)
  {
    state->framesWithGc += 1;
    state->totalGcCount += (uint64_t)state->activeSample.gcCount;
    state->totalExplicitGcCount += (uint64_t)state->activeSample.explicitGcCount;
    state->totalImplicitGcCount += (uint64_t)state->activeSample.implicitGcCount;
    state->totalGcPauseMs += state->activeSample.gcPauseMs;
    state->totalGcReclaimedBytes += state->activeSample.gcReclaimedBytes;
    if (state->activeSample.gcPauseMs > state->maxGcPauseMs)
    {
      state->maxGcPauseMs = state->activeSample.gcPauseMs;
      state->maxGcPauseFrame = state->totalFrames;
    }
  }

  state->totalAllocBytes += state->activeSample.allocBytes;
  state->totalAllocCount += (uint64_t)state->activeSample.allocCount;
  if (state->activeSample.allocBytes > state->peakFrameAllocBytes)
  {
    state->peakFrameAllocBytes = state->activeSample.allocBytes;
    state->peakFrameAllocFrame = state->totalFrames;
  }

  stored = &state->samples[state->writeIndex];
  *stored = state->activeSample;
  state->writeIndex = (state->writeIndex + 1) % PHOENIX_PROFILER_RING_CAPACITY;
  if (state->sampleCount < PHOENIX_PROFILER_RING_CAPACITY)
    state->sampleCount += 1;

  state->lastFrameStartMs = state->currentFrameStartMs;
  state->lastFrameEndMs = nowMs;
  state->inFlightFrame = 0;

  return stored;
}

/**
 * Completes the current frame using the native monotonic clock.
 */
static inline const PhoenixFrameSample *phoenixProfilerEndFrame(
  PhoenixProfilerState *state,
  int64_t heapUsedBytes,
  int64_t heapReservedBytes,
  int drawCalls)
{
  return phoenixProfilerEndFrameAt(
    state,
    phoenixProfilerNowMs(),
    0.0,
    heapUsedBytes,
    heapReservedBytes,
    drawCalls);
}

/**
 * Copies the most recently completed frame sample into outSample.
 * Returns 1 if a frame was available, 0 otherwise.
 */
static inline int phoenixProfilerGetLastFrame(
  const PhoenixProfilerState *state,
  PhoenixFrameSample *outSample)
{
  size_t lastIdx;
  if (state == NULL || outSample == NULL || state->sampleCount == 0)
    return 0;
  lastIdx = (state->writeIndex + PHOENIX_PROFILER_RING_CAPACITY - 1) % PHOENIX_PROFILER_RING_CAPACITY;
  *outSample = state->samples[lastIdx];
  return 1;
}

/**
 * Copies a buffered frame sample in chronological order (0 = oldest in buffer, sampleCount - 1 = newest).
 * Returns 1 on success, 0 if chronologicalIndex is out of range.
 */
static inline int phoenixProfilerGetBufferedFrame(
  const PhoenixProfilerState *state,
  size_t chronologicalIndex,
  PhoenixFrameSample *outSample)
{
  size_t oldestIdx;
  size_t actualIdx;
  if (state == NULL || outSample == NULL || chronologicalIndex >= state->sampleCount)
    return 0;
  oldestIdx = state->sampleCount < PHOENIX_PROFILER_RING_CAPACITY ? 0 : state->writeIndex;
  actualIdx = (oldestIdx + chronologicalIndex) % PHOENIX_PROFILER_RING_CAPACITY;
  *outSample = state->samples[actualIdx];
  return 1;
}

/**
 * Computes full session and percentile statistics into outSummary.
 */
static inline void phoenixProfilerComputeSummary(
  const PhoenixProfilerState *state,
  PhoenixProfilerSummary *outSummary)
{
  double scratch[PHOENIX_PROFILER_RING_CAPACITY];
  size_t i;
  size_t count;

  if (outSummary == NULL)
    return;
  memset(outSummary, 0, sizeof(PhoenixProfilerSummary));
  if (state == NULL || !state->initialized)
    return;

  outSummary->totalFrames = state->totalFrames;
  outSummary->bufferedFrames = state->sampleCount;
  outSummary->targetFps = state->targetFps;
  outSummary->sessionDurationMs = state->totalDurationMs;

  {
    double cpuDeltaSec = phoenixProfilerCpuSeconds() - state->sessionStartCpuSeconds;
    if (cpuDeltaSec < 0.0)
      cpuDeltaSec = 0.0;
    outSummary->cpuTimeMs = cpuDeltaSec * 1000.0;
    outSummary->cpuUtilizationPct = state->totalDurationMs > 1e-6
      ? (outSummary->cpuTimeMs * 100.0) / state->totalDurationMs
      : 0.0;
  }

  outSummary->startHeapUsedBytes = state->startHeapUsedBytes;
  outSummary->currentHeapUsedBytes = state->currentHeapUsedBytes;
  outSummary->peakHeapUsedBytes = state->peakHeapUsedBytes;
  outSummary->currentHeapReservedBytes = state->currentHeapReservedBytes;
  outSummary->currentRssBytes = state->currentRssBytes > 0 ? state->currentRssBytes : phoenixProfilerCurrentRSS();
  outSummary->peakRssBytes = state->peakRssBytes > 0 ? state->peakRssBytes : phoenixProfilerPeakRSS();

  if (state->totalFrames == 0)
    return;

  outSummary->avgFrameTimeMs = state->sumFrameTimeMs / (double)state->totalFrames;
  outSummary->minFrameTimeMs = state->minFrameTimeMs;
  outSummary->maxFrameTimeMs = state->maxFrameTimeMs;
  {
    double meanSq = state->sumSqFrameTimeMs / (double)state->totalFrames;
    double variance = meanSq - (outSummary->avgFrameTimeMs * outSummary->avgFrameTimeMs);
    outSummary->stdDevFrameTimeMs = variance > 0.0 ? phoenixProfilerSqrt(variance) : 0.0;
  }
  outSummary->spikeCount25Ms = state->spikeCount25Ms;
  outSummary->spikeCount33Ms = state->spikeCount33Ms;

  outSummary->avgFps = state->totalDurationMs > 1e-6
    ? ((double)state->totalFrames * 1000.0) / state->totalDurationMs
    : 0.0;
  outSummary->currentFps = state->currentRollingFps > 0.0 ? state->currentRollingFps : outSummary->avgFps;
  outSummary->minFps = state->maxFrameTimeMs > 1e-6 ? (1000.0 / state->maxFrameTimeMs) : 0.0;
  outSummary->maxFps = state->minFrameTimeMs > 1e-6 ? (1000.0 / state->minFrameTimeMs) : 0.0;

  outSummary->totalUpdateTimeMs = state->totalUpdateTimeMs;
  outSummary->avgUpdateTimeMs = state->totalUpdateTimeMs / (double)state->totalFrames;
  outSummary->maxUpdateTimeMs = state->maxUpdateTimeMs;
  outSummary->updateFrameSharePct = state->totalDurationMs > 1e-6
    ? (state->totalUpdateTimeMs * 100.0) / state->totalDurationMs
    : 0.0;

  outSummary->totalRenderTimeMs = state->totalRenderTimeMs;
  outSummary->avgRenderTimeMs = state->totalRenderTimeMs / (double)state->totalFrames;
  outSummary->maxRenderTimeMs = state->maxRenderTimeMs;
  outSummary->renderFrameSharePct = state->totalDurationMs > 1e-6
    ? (state->totalRenderTimeMs * 100.0) / state->totalDurationMs
    : 0.0;

  outSummary->totalAudioTimeMs = state->totalAudioTimeMs;
  outSummary->avgAudioTimeMs = state->totalAudioTimeMs / (double)state->totalFrames;
  outSummary->maxAudioTimeMs = state->maxAudioTimeMs;
  outSummary->audioFrameSharePct = state->totalDurationMs > 1e-6
    ? (state->totalAudioTimeMs * 100.0) / state->totalDurationMs
    : 0.0;

  outSummary->totalGcCount = state->totalGcCount;
  outSummary->totalExplicitGcCount = state->totalExplicitGcCount;
  outSummary->totalImplicitGcCount = state->totalImplicitGcCount;
  outSummary->framesWithGc = state->framesWithGc;
  outSummary->totalGcPauseMs = state->totalGcPauseMs;
  outSummary->avgGcPausePerFrameMs = state->totalGcPauseMs / (double)state->totalFrames;
  outSummary->avgGcPausePerCollectionMs = state->totalGcCount > 0
    ? state->totalGcPauseMs / (double)state->totalGcCount
    : 0.0;
  outSummary->maxGcPauseMs = state->maxGcPauseMs;
  outSummary->maxGcPauseFrame = state->maxGcPauseFrame;
  outSummary->gcFrameSharePct = state->totalDurationMs > 1e-6
    ? (state->totalGcPauseMs * 100.0) / state->totalDurationMs
    : 0.0;
  outSummary->totalGcReclaimedBytes = state->totalGcReclaimedBytes;

  outSummary->totalAllocBytes = state->totalAllocBytes;
  outSummary->totalAllocCount = state->totalAllocCount;
  outSummary->avgAllocBytesPerFrame = (double)state->totalAllocBytes / (double)state->totalFrames;
  outSummary->allocRateBytesPerSec = state->totalDurationMs > 1e-6
    ? ((double)state->totalAllocBytes * 1000.0) / state->totalDurationMs
    : 0.0;
  outSummary->peakFrameAllocBytes = state->peakFrameAllocBytes;
  outSummary->peakFrameAllocFrame = state->peakFrameAllocFrame;

  count = state->sampleCount;
  if (count > 0)
  {
    for (i = 0; i < count; ++i)
      scratch[i] = state->samples[i].frameTimeMs;
    phoenixProfilerSortDoubles(scratch, count);
    outSummary->p50FrameTimeMs = phoenixProfilerPercentileSorted(scratch, count, 0.50);
    outSummary->p95FrameTimeMs = phoenixProfilerPercentileSorted(scratch, count, 0.95);
    outSummary->p99FrameTimeMs = phoenixProfilerPercentileSorted(scratch, count, 0.99);
    outSummary->p999FrameTimeMs = phoenixProfilerPercentileSorted(scratch, count, 0.999);
    outSummary->onePercentLowFps = outSummary->p99FrameTimeMs > 1e-6
      ? (1000.0 / outSummary->p99FrameTimeMs)
      : 0.0;
    outSummary->pointOnePercentLowFps = outSummary->p999FrameTimeMs > 1e-6
      ? (1000.0 / outSummary->p999FrameTimeMs)
      : 0.0;

    for (i = 0; i < count; ++i)
      scratch[i] = state->samples[i].updateTimeMs;
    phoenixProfilerSortDoubles(scratch, count);
    outSummary->p99UpdateTimeMs = phoenixProfilerPercentileSorted(scratch, count, 0.99);

    for (i = 0; i < count; ++i)
      scratch[i] = state->samples[i].renderTimeMs;
    phoenixProfilerSortDoubles(scratch, count);
    outSummary->p99RenderTimeMs = phoenixProfilerPercentileSorted(scratch, count, 0.99);

    for (i = 0; i < count; ++i)
      scratch[i] = state->samples[i].audioTimeMs;
    phoenixProfilerSortDoubles(scratch, count);
    outSummary->p99AudioTimeMs = phoenixProfilerPercentileSorted(scratch, count, 0.99);
  }
}

/**
 * Resolves and sanitizes a requested log path so that it always resides inside a
 * "debug/log/" directory and ends with ".log", blocking any ".." path traversal.
 * Returns 1 on success, 0 on invalid arguments.
 */
static inline int phoenixProfilerResolveLogPath(
  const char *requestedPath,
  char *outPath,
  size_t outCapacity)
{
  char normalized[PHOENIX_PROFILER_PATH_MAX];
  const char *baseName;
  const char *debugLogSubstr;
  size_t len = 0;
  size_t i;
  int hasTraversal = 0;

  if (outPath == NULL || outCapacity < 32)
    return 0;

  if (requestedPath == NULL || requestedPath[0] == '\0')
  {
    snprintf(outPath, outCapacity, "%s", PHOENIX_PROFILER_DEFAULT_LOG_FILE);
    return 1;
  }

  for (i = 0; requestedPath[i] != '\0' && len + 1 < PHOENIX_PROFILER_PATH_MAX; ++i)
  {
    char ch = requestedPath[i];
    if (ch == '\\')
      ch = '/';
    if (ch == ':' || ch == '*' || ch == '?' || ch == '"' || ch == '<' || ch == '>' || ch == '|' || ch == '\r' || ch == '\n')
      ch = '_';
    normalized[len++] = ch;
  }
  normalized[len] = '\0';

  if (strstr(normalized, "..") != NULL)
    hasTraversal = 1;

  debugLogSubstr = strstr(normalized, "debug/log/");
  if (!hasTraversal && debugLogSubstr != NULL && debugLogSubstr[10] != '\0')
  {
    snprintf(outPath, outCapacity, "%s", normalized);
  }
  else
  {
    baseName = strrchr(normalized, '/');
    baseName = baseName != NULL ? (baseName + 1) : normalized;
    while (*baseName == '.' || *baseName == ' ' || *baseName == '/')
      ++baseName;
    if (*baseName == '\0')
      baseName = "frame_profiler.log";
    snprintf(outPath, outCapacity, "%s/%s", PHOENIX_PROFILER_LOG_DIR, baseName);
  }

  len = strlen(outPath);
  if (len < 4 || strcmp(outPath + len - 4, ".log") != 0)
  {
    if (len + 4 >= outCapacity)
      return 0;
    snprintf(outPath + len, outCapacity - len, ".log");
  }

  return 1;
}

/**
 * Ensures all parent directories of filePath exist (e.g. "debug" and "debug/log").
 * Returns 1 on success, 0 on failure.
 */
static inline int phoenixProfilerEnsureParentDirs(const char *filePath)
{
  char dirBuf[PHOENIX_PROFILER_PATH_MAX];
  size_t i;
  size_t len;
  if (filePath == NULL || filePath[0] == '\0')
    return 0;

  len = strlen(filePath);
  if (len >= PHOENIX_PROFILER_PATH_MAX)
    return 0;
  memcpy(dirBuf, filePath, len + 1);

  for (i = 1; i < len; ++i)
  {
    if (dirBuf[i] == '/' || dirBuf[i] == '\\')
    {
      char saved = dirBuf[i];
      int rc;
      dirBuf[i] = '\0';
#if defined(_WIN32)
      rc = _mkdir(dirBuf);
#elif defined(__unix__) || defined(__unix) || defined(unix) || (defined(__APPLE__) && defined(__MACH__))
      rc = mkdir(dirBuf, 0755);
#else
      rc = 0;
#endif
      if (rc != 0 && errno != EEXIST)
      {
        dirBuf[i] = saved;
        return 0;
      }
      dirBuf[i] = saved;
    }
  }
  return 1;
}

/**
 * Returns the dominant subsystem bottleneck label for a single frame sample.
 */
static inline const char *phoenixProfilerDominantSubsystem(const PhoenixFrameSample *sample)
{
  double maxVal;
  const char *label = "OTHER/VSYNC";
  if (sample == NULL)
    return label;
  maxVal = sample->otherTimeMs;
  if (sample->updateTimeMs >= maxVal && sample->updateTimeMs > 0.0)
  {
    maxVal = sample->updateTimeMs;
    label = "UPDATE";
  }
  if (sample->renderTimeMs >= maxVal && sample->renderTimeMs > 0.0)
  {
    maxVal = sample->renderTimeMs;
    label = "RENDER";
  }
  if (sample->audioTimeMs >= maxVal && sample->audioTimeMs > 0.0)
  {
    maxVal = sample->audioTimeMs;
    label = "AUDIO";
  }
  if (sample->gcPauseMs >= maxVal && sample->gcPauseMs > 0.0)
  {
    label = "GC_PAUSE";
  }
  return label;
}

/**
 * Writes the full frame profiler report and per-frame CSV log to a file inside debug/log/.
 * Returns 1 on success, 0 on failure.
 */
static inline int phoenixProfilerExportLog(
  const PhoenixProfilerState *state,
  const char *requestedPath,
  const char *engineVersion,
  const char *platformInfo,
  char *outResolvedPath,
  size_t outPathCapacity)
{
  char resolvedPath[PHOENIX_PROFILER_PATH_MAX];
  char lineBuf[1024];
  PhoenixProfilerSummary summary;
  FILE *fp;
  size_t i;
  int n;
  const char *verStr = (engineVersion != NULL && engineVersion[0] != '\0') ? engineVersion : "0.3.2";
  const char *platStr = (platformInfo != NULL && platformInfo[0] != '\0') ? platformInfo : "Native C/C++";

  if (state == NULL)
    return 0;

  if (!phoenixProfilerResolveLogPath(requestedPath, resolvedPath, sizeof(resolvedPath)))
    return 0;

  if (!phoenixProfilerEnsureParentDirs(resolvedPath))
    return 0;

  fp = fopen(resolvedPath, "wb");
  if (fp == NULL)
    return 0;

  phoenixProfilerComputeSummary(state, &summary);

  n = snprintf(lineBuf, sizeof(lineBuf),
    "================================================================================\n"
    "PHOENIX ENGINE - FRAME PROFILER LOG REPORT\n"
    "================================================================================\n"
    "Engine Version       : %s\n"
    "Platform             : %s\n"
    "Log File             : %s\n"
    "Target FPS           : %.2f\n"
    "Total Frames         : %llu (Buffered: %llu / %d)\n"
    "Session Duration     : %.3f ms (%.3f s)\n"
    "Process CPU Time     : %.3f ms (%.2f%% utilization)\n"
    "Active State         : %s\n\n",
    verStr,
    platStr,
    resolvedPath,
    summary.targetFps,
    (unsigned long long)summary.totalFrames,
    (unsigned long long)summary.bufferedFrames,
    (int)PHOENIX_PROFILER_RING_CAPACITY,
    summary.sessionDurationMs,
    summary.sessionDurationMs / 1000.0,
    summary.cpuTimeMs,
    summary.cpuUtilizationPct,
    state->initialized ? state->currentStateName : "Unknown");
  if (n > 0)
    fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);

  n = snprintf(lineBuf, sizeof(lineBuf),
    "--------------------------------------------------------------------------------\n"
    "[1] FRAMETIME & FPS SUMMARY\n"
    "--------------------------------------------------------------------------------\n"
    "Avg Frametime        : %.4f ms\n"
    "Min Frametime        : %.4f ms\n"
    "Max Frametime        : %.4f ms\n"
    "Frametime StdDev     : %.4f ms\n"
    "P50 Frametime        : %.4f ms\n"
    "P95 Frametime        : %.4f ms\n"
    "P99 Frametime        : %.4f ms\n"
    "P99.9 Frametime      : %.4f ms\n"
    "Frame Spikes (>25ms) : %llu\n"
    "Frame Spikes (>33ms) : %llu\n"
    "Avg FPS              : %.2f\n"
    "Current Rolling FPS  : %.2f\n"
    "Min FPS              : %.2f\n"
    "Max FPS              : %.2f\n"
    "1%% Low FPS           : %.2f\n"
    "0.1%% Low FPS         : %.2f\n\n",
    summary.avgFrameTimeMs,
    summary.minFrameTimeMs,
    summary.maxFrameTimeMs,
    summary.stdDevFrameTimeMs,
    summary.p50FrameTimeMs,
    summary.p95FrameTimeMs,
    summary.p99FrameTimeMs,
    summary.p999FrameTimeMs,
    (unsigned long long)summary.spikeCount25Ms,
    (unsigned long long)summary.spikeCount33Ms,
    summary.avgFps,
    summary.currentFps,
    summary.minFps,
    summary.maxFps,
    summary.onePercentLowFps,
    summary.pointOnePercentLowFps);
  if (n > 0)
    fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);

  n = snprintf(lineBuf, sizeof(lineBuf),
    "--------------------------------------------------------------------------------\n"
    "[2] SUBSYSTEM TIMINGS (UPDATES, RENDERING, AUDIO)\n"
    "--------------------------------------------------------------------------------\n"
    "Updates (avg/max/p99): %.4f ms / %.4f ms / %.4f ms (Total: %.3f ms, %.2f%% of frame)\n"
    "Render  (avg/max/p99): %.4f ms / %.4f ms / %.4f ms (Total: %.3f ms, %.2f%% of frame)\n"
    "Audio   (avg/max/p99): %.4f ms / %.4f ms / %.4f ms (Total: %.3f ms, %.2f%% of frame)\n\n",
    summary.avgUpdateTimeMs,
    summary.maxUpdateTimeMs,
    summary.p99UpdateTimeMs,
    summary.totalUpdateTimeMs,
    summary.updateFrameSharePct,
    summary.avgRenderTimeMs,
    summary.maxRenderTimeMs,
    summary.p99RenderTimeMs,
    summary.totalRenderTimeMs,
    summary.renderFrameSharePct,
    summary.avgAudioTimeMs,
    summary.maxAudioTimeMs,
    summary.p99AudioTimeMs,
    summary.totalAudioTimeMs,
    summary.audioFrameSharePct);
  if (n > 0)
    fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);

  n = snprintf(lineBuf, sizeof(lineBuf),
    "--------------------------------------------------------------------------------\n"
    "[3] GARBAGE COLLECTION (GC PAUSES)\n"
    "--------------------------------------------------------------------------------\n"
    "Total GC Collections : %llu (Explicit: %llu, Implicit: %llu)\n"
    "Frames With GC       : %llu\n"
    "Total GC Pause Time  : %.4f ms (%.2f%% of session)\n"
    "Avg GC Pause / Frame : %.4f ms\n"
    "Avg GC Pause / Event : %.4f ms\n"
    "Max GC Pause         : %.4f ms (Frame #%llu)\n"
    "Total GC Reclaimed   : %lld bytes (%.2f KB / %.2f MB)\n\n",
    (unsigned long long)summary.totalGcCount,
    (unsigned long long)summary.totalExplicitGcCount,
    (unsigned long long)summary.totalImplicitGcCount,
    (unsigned long long)summary.framesWithGc,
    summary.totalGcPauseMs,
    summary.gcFrameSharePct,
    summary.avgGcPausePerFrameMs,
    summary.avgGcPausePerCollectionMs,
    summary.maxGcPauseMs,
    (unsigned long long)summary.maxGcPauseFrame,
    (long long)summary.totalGcReclaimedBytes,
    (double)summary.totalGcReclaimedBytes / 1024.0,
    (double)summary.totalGcReclaimedBytes / (1024.0 * 1024.0));
  if (n > 0)
    fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);

  n = snprintf(lineBuf, sizeof(lineBuf),
    "--------------------------------------------------------------------------------\n"
    "[4] ALLOCATIONS & MEMORY USAGE\n"
    "--------------------------------------------------------------------------------\n"
    "Total Allocations    : %lld bytes (%.2f KB / %.2f MB) across %llu events\n"
    "Avg Alloc / Frame    : %.2f bytes (%.2f KB)\n"
    "Allocation Rate      : %.2f KB/s (%.2f MB/s)\n"
    "Peak Frame Alloc     : %lld bytes (%.2f KB) on Frame #%llu\n"
    "Start GC Heap Used   : %lld bytes (%.2f MB)\n"
    "Current GC Heap Used : %lld bytes (%.2f MB)\n"
    "Peak GC Heap Used    : %lld bytes (%.2f MB)\n"
    "Current GC Reserved  : %lld bytes (%.2f MB)\n"
    "Current Process RSS  : %llu bytes (%.2f MB)\n"
    "Peak Process RSS     : %llu bytes (%.2f MB)\n\n",
    (long long)summary.totalAllocBytes,
    (double)summary.totalAllocBytes / 1024.0,
    (double)summary.totalAllocBytes / (1024.0 * 1024.0),
    (unsigned long long)summary.totalAllocCount,
    summary.avgAllocBytesPerFrame,
    summary.avgAllocBytesPerFrame / 1024.0,
    summary.allocRateBytesPerSec / 1024.0,
    summary.allocRateBytesPerSec / (1024.0 * 1024.0),
    (long long)summary.peakFrameAllocBytes,
    (double)summary.peakFrameAllocBytes / 1024.0,
    (unsigned long long)summary.peakFrameAllocFrame,
    (long long)summary.startHeapUsedBytes,
    (double)summary.startHeapUsedBytes / (1024.0 * 1024.0),
    (long long)summary.currentHeapUsedBytes,
    (double)summary.currentHeapUsedBytes / (1024.0 * 1024.0),
    (long long)summary.peakHeapUsedBytes,
    (double)summary.peakHeapUsedBytes / (1024.0 * 1024.0),
    (long long)summary.currentHeapReservedBytes,
    (double)summary.currentHeapReservedBytes / (1024.0 * 1024.0),
    (unsigned long long)summary.currentRssBytes,
    (double)summary.currentRssBytes / (1024.0 * 1024.0),
    (unsigned long long)summary.peakRssBytes,
    (double)summary.peakRssBytes / (1024.0 * 1024.0));
  if (n > 0)
    fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);

  n = snprintf(lineBuf, sizeof(lineBuf),
    "--------------------------------------------------------------------------------\n"
    "[5] TOP SLOWEST FRAMES (BOTTLENECK ANALYSIS)\n"
    "--------------------------------------------------------------------------------\n");
  if (n > 0)
    fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);

  if (state->sampleCount > 0)
  {
    int used[PHOENIX_PROFILER_RING_CAPACITY];
    size_t topLimit = state->sampleCount < 10 ? state->sampleCount : 10;
    size_t rank;
    memset(used, 0, sizeof(used));
    for (rank = 0; rank < topLimit; ++rank)
    {
      size_t bestIdx = 0;
      double bestTime = -1.0;
      for (i = 0; i < state->sampleCount; ++i)
      {
        if (!used[i] && state->samples[i].frameTimeMs > bestTime)
        {
          bestTime = state->samples[i].frameTimeMs;
          bestIdx = i;
        }
      }
      used[bestIdx] = 1;
      {
        const PhoenixFrameSample *s = &state->samples[bestIdx];
        n = snprintf(lineBuf, sizeof(lineBuf),
          "  #%llu | Frame %llu | %.4f ms (%.1f FPS) | Upd: %.4f ms | Rnd: %.4f ms | Aud: %.4f ms | GC: %.4f ms | Alloc: %lld B | Bottleneck: %s | State: %s\n",
          (unsigned long long)(rank + 1),
          (unsigned long long)s->frameIndex,
          s->frameTimeMs,
          s->fps,
          s->updateTimeMs,
          s->renderTimeMs,
          s->audioTimeMs,
          s->gcPauseMs,
          (long long)s->allocBytes,
          phoenixProfilerDominantSubsystem(s),
          s->stateName);
        if (n > 0)
          fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);
      }
    }
  }
  else
  {
    n = snprintf(lineBuf, sizeof(lineBuf), "  (No frames recorded)\n");
    if (n > 0)
      fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);
  }

  n = snprintf(lineBuf, sizeof(lineBuf),
    "\n--------------------------------------------------------------------------------\n"
    "[6] PER-FRAME TIMELINE (CSV)\n"
    "--------------------------------------------------------------------------------\n"
    "frame,timestamp_ms,frametime_ms,work_ms,fps,rolling_fps,update_ms,render_ms,audio_ms,gc_pause_ms,other_ms,alloc_bytes,alloc_count,net_heap_delta_bytes,gc_reclaimed_bytes,gc_count,explicit_gc_count,implicit_gc_count,heap_used_bytes,heap_reserved_bytes,rss_bytes,peak_rss_bytes,draw_calls,update_steps,state\n");
  if (n > 0)
    fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);

  for (i = 0; i < state->sampleCount; ++i)
  {
    PhoenixFrameSample s;
    if (phoenixProfilerGetBufferedFrame(state, i, &s))
    {
      n = snprintf(lineBuf, sizeof(lineBuf),
        "%llu,%.4f,%.4f,%.4f,%.2f,%.2f,%.4f,%.4f,%.4f,%.4f,%.4f,%lld,%d,%lld,%lld,%d,%d,%d,%lld,%lld,%llu,%llu,%d,%d,%s\n",
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
        s.allocCount,
        (long long)s.netHeapDeltaBytes,
        (long long)s.gcReclaimedBytes,
        s.gcCount,
        s.explicitGcCount,
        s.implicitGcCount,
        (long long)s.heapUsedBytes,
        (long long)s.heapReservedBytes,
        (unsigned long long)s.rssBytes,
        (unsigned long long)s.peakRssBytes,
        s.drawCalls,
        s.updateSteps,
        s.stateName);
      if (n > 0)
        fwrite(lineBuf, 1, (size_t)n < sizeof(lineBuf) ? (size_t)n : sizeof(lineBuf) - 1, fp);
    }
  }

  fflush(fp);
  fclose(fp);

  if (outResolvedPath != NULL && outPathCapacity > 0)
    snprintf(outResolvedPath, outPathCapacity, "%s", resolvedPath);

  return 1;
}

#endif
