package debug.profiler;

/**
 * Low-level native C/C++ bridge for the Phoenix Engine Frame Profiler.
 * On C++ targets (`#if cpp`), delegates frame timing, phase accounting,
 * heap/GC observation, ring-buffer storage, percentile math, and `.log` file
 * export to `phoenix_profiler.h` with zero per-frame heap allocations.
 * On non-C++ targets, provides a portable pure-Haxe fallback with an identical API.
 */
#if cpp
@:buildXml('<include name="../../../../source/debug/profiler/build.xml" />')
@:cppFileCode('
#include "phoenix_profiler.h"

static PhoenixProfilerState gPhoenixProfiler;
static PhoenixProfilerSummary gPhoenixSummary;
static PhoenixFrameSample gPhoenixSample;
')
class NativeFrameProfiler
{
  public static inline final PHASE_UPDATE:Int = 0;
  public static inline final PHASE_RENDER:Int = 1;
  public static inline final PHASE_AUDIO:Int = 2;
  public static inline final PHASE_GC:Int = 3;
  public static inline final RING_CAPACITY:Int = 2048;

  /**
   * Initializes the native profiler state with the given target FPS.
   * @param targetFps Target framerate for frame budget calculations.
   */
  @:functionCode('
    phoenixProfilerInit(&gPhoenixProfiler, (double)targetFps);
  ')
  public static function init(targetFps:Float = 60.0):Void {}

  /**
   * Resets all recorded frames and session statistics.
   */
  @:functionCode('
    phoenixProfilerReset(&gPhoenixProfiler);
  ')
  public static function reset():Void {}

  /**
   * Enables or pauses frame profiling.
   * @param enabled Whether profiling is active.
   */
  @:functionCode('
    phoenixProfilerSetEnabled(&gPhoenixProfiler, enabled ? 1 : 0);
  ')
  public static function setEnabled(enabled:Bool):Void {}

  /**
   * Returns whether the native frame profiler is currently enabled.
   * @return Bool
   */
  @:functionCode('
    return phoenixProfilerIsEnabled(&gPhoenixProfiler) != 0;
  ')
  public static function isEnabled():Bool
  {
    return true;
  }

  /**
   * Sets the target FPS used for frame budget calculations.
   * @param targetFps Target framerate in frames per second.
   */
  @:functionCode('
    phoenixProfilerSetTargetFps(&gPhoenixProfiler, (double)targetFps);
  ')
  public static function setTargetFps(targetFps:Float):Void {}

  /**
   * Updates the current game state name associated with recorded frames.
   * @param stateName Active FlxState class name.
   */
  @:functionCode('
    const char *raw = stateName.utf8_str();
    phoenixProfilerSetStateName(&gPhoenixProfiler, raw != NULL ? raw : "Unknown");
  ')
  public static function setStateName(stateName:String):Void {}

  /**
   * Returns a high-resolution monotonic timestamp in milliseconds.
   * @return Float
   */
  @:functionCode('
    return phoenixProfilerNowMs();
  ')
  public static function nowMs():Float
  {
    return 0.0;
  }

  /**
   * Begins recording a new frame.
   * @param heapUsedBytes Current GC heap usage in bytes.
   * @param heapReservedBytes Current GC reserved heap in bytes.
   */
  @:functionCode('
    phoenixProfilerBeginFrame(&gPhoenixProfiler, (int64_t)heapUsedBytes, (int64_t)heapReservedBytes);
  ')
  public static function beginFrame(heapUsedBytes:Float, heapReservedBytes:Float):Void {}

  /**
   * Begins a subsystem phase (`PHASE_UPDATE`, `PHASE_RENDER`, `PHASE_AUDIO`, `PHASE_GC`).
   * @param phase Subsystem phase constant.
   * @param heapUsedBytes Current GC heap usage in bytes.
   */
  @:functionCode('
    phoenixProfilerBeginPhase(&gPhoenixProfiler, phase, (int64_t)heapUsedBytes);
  ')
  public static function beginPhase(phase:Int, heapUsedBytes:Float):Void {}

  /**
   * Ends a subsystem phase and returns the net elapsed time in milliseconds.
   * @param phase Subsystem phase constant.
   * @param heapUsedBytes Current GC heap usage in bytes.
   * @return Float
   */
  @:functionCode('
    return phoenixProfilerEndPhase(&gPhoenixProfiler, phase, (int64_t)heapUsedBytes);
  ')
  public static function endPhase(phase:Int, heapUsedBytes:Float):Float
  {
    return 0.0;
  }

  /**
   * Directly adds a pre-measured duration (in ms) to a subsystem phase on the active frame.
   * @param phase Subsystem phase constant.
   * @param durationMs Duration in milliseconds.
   */
  @:functionCode('
    phoenixProfilerRecordPhaseMs(&gPhoenixProfiler, phase, (double)durationMs);
  ')
  public static function recordPhaseMs(phase:Int, durationMs:Float):Void {}

  /**
   * Directly records an allocation event on the active frame.
   * @param bytes Positive bytes allocated.
   * @param count Number of allocation events.
   */
  @:functionCode('
    phoenixProfilerRecordAllocation(&gPhoenixProfiler, (int64_t)bytes, count);
  ')
  public static function recordAllocation(bytes:Float, count:Int = 1):Void {}

  /**
   * Directly records a garbage collection pause on the active frame.
   * @param pauseMs GC pause duration in milliseconds.
   * @param reclaimedBytes Bytes reclaimed by GC.
   * @param isExplicit Whether the GC was triggered explicitly.
   */
  @:functionCode('
    phoenixProfilerRecordGCPause(&gPhoenixProfiler, (double)pauseMs, (int64_t)reclaimedBytes, isExplicit ? 1 : 0);
  ')
  public static function recordGCPause(pauseMs:Float, reclaimedBytes:Float = 0.0, isExplicit:Bool = true):Void {}

  /**
   * Adds draw call counts to the active frame.
   * @param drawCalls Number of draw calls executed.
   */
  @:functionCode('
    phoenixProfilerAddDrawCalls(&gPhoenixProfiler, drawCalls);
  ')
  public static function addDrawCalls(drawCalls:Int):Void {}

  /**
   * Ends the current frame, commits the frame sample to the native ring buffer,
   * and updates session statistics.
   * @param heapUsedBytes Current GC heap usage in bytes.
   * @param heapReservedBytes Current GC reserved heap in bytes.
   * @param drawCalls Draw calls executed during the frame.
   * @param explicitFrameTimeMs Optional explicit frame delta in milliseconds (0 for automatic).
   */
  @:functionCode('
    phoenixProfilerEndFrameAt(
      &gPhoenixProfiler,
      phoenixProfilerNowMs(),
      (double)explicitFrameTimeMs,
      (int64_t)heapUsedBytes,
      (int64_t)heapReservedBytes,
      drawCalls);
  ')
  public static function endFrame(
    heapUsedBytes:Float,
    heapReservedBytes:Float,
    drawCalls:Int = 0,
    explicitFrameTimeMs:Float = 0.0):Void {}

  /**
   * Refreshes the cached summary snapshot from the native profiler state.
   */
  @:functionCode('
    phoenixProfilerComputeSummary(&gPhoenixProfiler, &gPhoenixSummary);
  ')
  public static function refreshSummary():Void {}

  /**
   * Refreshes the cached last-frame sample from the native profiler state.
   * @return Bool True if at least one frame has been recorded.
   */
  @:functionCode('
    return phoenixProfilerGetLastFrame(&gPhoenixProfiler, &gPhoenixSample) != 0;
  ')
  public static function refreshLastFrame():Bool
  {
    return false;
  }

  /**
   * Loads the buffered frame at `chronologicalIndex` (0 = oldest in ring buffer) into the sample cache.
   * @param chronologicalIndex Index from 0 to bufferedFrames - 1.
   * @return Bool True if the frame exists.
   */
  @:functionCode('
    return phoenixProfilerGetBufferedFrame(&gPhoenixProfiler, (size_t)chronologicalIndex, &gPhoenixSample) != 0;
  ')
  public static function loadBufferedFrame(chronologicalIndex:Int):Bool
  {
    return false;
  }

  /**
   * Resolves a requested log file name to a safe path inside `debug/log/` ending in `.log`.
   * @param requestedPath Optional custom file name or path.
   * @return String
   */
  @:functionCode('
    char resolved[PHOENIX_PROFILER_PATH_MAX];
    const char *raw = requestedPath.utf8_str();
    if (!phoenixProfilerResolveLogPath(raw, resolved, sizeof(resolved)))
      return ::String(PHOENIX_PROFILER_DEFAULT_LOG_FILE);
    return ::String(resolved);
  ')
  public static function resolveLogPath(requestedPath:String):String
  {
    return "debug/log/frame_profiler.log";
  }

  /**
   * Exports the full profiler report and frame timeline to a `.log` file in `debug/log/`.
   * @param requestedPath Optional custom filename or path inside `debug/log/`.
   * @param engineVersion Engine version string for the report header.
   * @param platformInfo Platform/OS description string for the report header.
   * @return String The resolved path written on success, or empty string on failure.
   */
  @:functionCode('
    char resolved[PHOENIX_PROFILER_PATH_MAX];
    const char *pathRaw = requestedPath.utf8_str();
    const char *verRaw = engineVersion.utf8_str();
    const char *platRaw = platformInfo.utf8_str();
    if (!phoenixProfilerExportLog(&gPhoenixProfiler, pathRaw, verRaw, platRaw, resolved, sizeof(resolved)))
      return ::String("");
    return ::String(resolved);
  ')
  public static function exportLog(requestedPath:String, engineVersion:String, platformInfo:String):String
  {
    return "";
  }

  // Cached sample getters (populated by refreshLastFrame / loadBufferedFrame)

  @:functionCode('return (double)gPhoenixSample.frameIndex;')
  public static function sampleFrameIndex():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.timestampMs;')
  public static function sampleTimestampMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.frameTimeMs;')
  public static function sampleFrameTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.workTimeMs;')
  public static function sampleWorkTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.fps;')
  public static function sampleFps():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.rollingFps;')
  public static function sampleRollingFps():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.updateTimeMs;')
  public static function sampleUpdateTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.renderTimeMs;')
  public static function sampleRenderTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.audioTimeMs;')
  public static function sampleAudioTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.gcPauseMs;')
  public static function sampleGcPauseMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.otherTimeMs;')
  public static function sampleOtherTimeMs():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSample.allocBytes;')
  public static function sampleAllocBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSample.netHeapDeltaBytes;')
  public static function sampleNetHeapDeltaBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSample.gcReclaimedBytes;')
  public static function sampleGcReclaimedBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSample.heapUsedBytes;')
  public static function sampleHeapUsedBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSample.heapReservedBytes;')
  public static function sampleHeapReservedBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSample.rssBytes;')
  public static function sampleRssBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSample.peakRssBytes;')
  public static function samplePeakRssBytes():Float
    return 0.0;

  @:functionCode('return gPhoenixSample.allocCount;')
  public static function sampleAllocCount():Int
    return 0;

  @:functionCode('return gPhoenixSample.gcCount;')
  public static function sampleGcCount():Int
    return 0;

  @:functionCode('return gPhoenixSample.explicitGcCount;')
  public static function sampleExplicitGcCount():Int
    return 0;

  @:functionCode('return gPhoenixSample.implicitGcCount;')
  public static function sampleImplicitGcCount():Int
    return 0;

  @:functionCode('return gPhoenixSample.updateSteps;')
  public static function sampleUpdateSteps():Int
    return 0;

  @:functionCode('return gPhoenixSample.drawCalls;')
  public static function sampleDrawCalls():Int
    return 0;

  @:functionCode('return ::String(gPhoenixSample.stateName);')
  public static function sampleStateName():String
    return "Unknown";

  // Cached summary getters (populated by refreshSummary)

  @:functionCode('return (double)gPhoenixSummary.totalFrames;')
  public static function summaryTotalFrames():Float
    return 0.0;

  @:functionCode('return (int)gPhoenixSummary.bufferedFrames;')
  public static function summaryBufferedFrames():Int
    return 0;

  @:functionCode('return gPhoenixSummary.targetFps;')
  public static function summaryTargetFps():Float
    return 60.0;

  @:functionCode('return gPhoenixSummary.sessionDurationMs;')
  public static function summarySessionDurationMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.cpuTimeMs;')
  public static function summaryCpuTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.cpuUtilizationPct;')
  public static function summaryCpuUtilizationPct():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.avgFrameTimeMs;')
  public static function summaryAvgFrameTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.minFrameTimeMs;')
  public static function summaryMinFrameTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.maxFrameTimeMs;')
  public static function summaryMaxFrameTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.stdDevFrameTimeMs;')
  public static function summaryStdDevFrameTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.p50FrameTimeMs;')
  public static function summaryP50FrameTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.p95FrameTimeMs;')
  public static function summaryP95FrameTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.p99FrameTimeMs;')
  public static function summaryP99FrameTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.p999FrameTimeMs;')
  public static function summaryP999FrameTimeMs():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.spikeCount25Ms;')
  public static function summarySpikeCount25Ms():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.spikeCount33Ms;')
  public static function summarySpikeCount33Ms():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.avgFps;')
  public static function summaryAvgFps():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.currentFps;')
  public static function summaryCurrentFps():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.minFps;')
  public static function summaryMinFps():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.maxFps;')
  public static function summaryMaxFps():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.onePercentLowFps;')
  public static function summaryOnePercentLowFps():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.pointOnePercentLowFps;')
  public static function summaryPointOnePercentLowFps():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.avgUpdateTimeMs;')
  public static function summaryAvgUpdateTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.maxUpdateTimeMs;')
  public static function summaryMaxUpdateTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.p99UpdateTimeMs;')
  public static function summaryP99UpdateTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.totalUpdateTimeMs;')
  public static function summaryTotalUpdateTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.updateFrameSharePct;')
  public static function summaryUpdateFrameSharePct():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.avgRenderTimeMs;')
  public static function summaryAvgRenderTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.maxRenderTimeMs;')
  public static function summaryMaxRenderTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.p99RenderTimeMs;')
  public static function summaryP99RenderTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.totalRenderTimeMs;')
  public static function summaryTotalRenderTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.renderFrameSharePct;')
  public static function summaryRenderFrameSharePct():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.avgAudioTimeMs;')
  public static function summaryAvgAudioTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.maxAudioTimeMs;')
  public static function summaryMaxAudioTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.p99AudioTimeMs;')
  public static function summaryP99AudioTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.totalAudioTimeMs;')
  public static function summaryTotalAudioTimeMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.audioFrameSharePct;')
  public static function summaryAudioFrameSharePct():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.totalGcCount;')
  public static function summaryTotalGcCount():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.totalExplicitGcCount;')
  public static function summaryTotalExplicitGcCount():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.totalImplicitGcCount;')
  public static function summaryTotalImplicitGcCount():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.framesWithGc;')
  public static function summaryFramesWithGc():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.totalGcPauseMs;')
  public static function summaryTotalGcPauseMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.avgGcPausePerFrameMs;')
  public static function summaryAvgGcPausePerFrameMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.avgGcPausePerCollectionMs;')
  public static function summaryAvgGcPausePerCollectionMs():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.maxGcPauseMs;')
  public static function summaryMaxGcPauseMs():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.maxGcPauseFrame;')
  public static function summaryMaxGcPauseFrame():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.gcFrameSharePct;')
  public static function summaryGcFrameSharePct():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.totalGcReclaimedBytes;')
  public static function summaryTotalGcReclaimedBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.totalAllocBytes;')
  public static function summaryTotalAllocBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.totalAllocCount;')
  public static function summaryTotalAllocCount():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.avgAllocBytesPerFrame;')
  public static function summaryAvgAllocBytesPerFrame():Float
    return 0.0;

  @:functionCode('return gPhoenixSummary.allocRateBytesPerSec;')
  public static function summaryAllocRateBytesPerSec():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.peakFrameAllocBytes;')
  public static function summaryPeakFrameAllocBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.peakFrameAllocFrame;')
  public static function summaryPeakFrameAllocFrame():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.startHeapUsedBytes;')
  public static function summaryStartHeapUsedBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.currentHeapUsedBytes;')
  public static function summaryCurrentHeapUsedBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.peakHeapUsedBytes;')
  public static function summaryPeakHeapUsedBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.currentHeapReservedBytes;')
  public static function summaryCurrentHeapReservedBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.currentRssBytes;')
  public static function summaryCurrentRssBytes():Float
    return 0.0;

  @:functionCode('return (double)gPhoenixSummary.peakRssBytes;')
  public static function summaryPeakRssBytes():Float
    return 0.0;
}
#else
import debug.mem.GetTotalMemory;

private class FallbackSample
{
  public var frameIndex:Float = 0;
  public var timestampMs:Float = 0;
  public var frameTimeMs:Float = 0;
  public var workTimeMs:Float = 0;
  public var fps:Float = 0;
  public var rollingFps:Float = 0;
  public var updateTimeMs:Float = 0;
  public var renderTimeMs:Float = 0;
  public var audioTimeMs:Float = 0;
  public var gcPauseMs:Float = 0;
  public var otherTimeMs:Float = 0;
  public var allocBytes:Float = 0;
  public var netHeapDeltaBytes:Float = 0;
  public var gcReclaimedBytes:Float = 0;
  public var heapUsedBytes:Float = 0;
  public var heapReservedBytes:Float = 0;
  public var rssBytes:Float = 0;
  public var peakRssBytes:Float = 0;
  public var allocCount:Int = 0;
  public var gcCount:Int = 0;
  public var explicitGcCount:Int = 0;
  public var implicitGcCount:Int = 0;
  public var updateSteps:Int = 0;
  public var drawCalls:Int = 0;
  public var stateName:String = "Unknown";

  public function new() {}

  public function reset(state:String):Void
  {
    frameIndex = 0;
    timestampMs = 0;
    frameTimeMs = 0;
    workTimeMs = 0;
    fps = 0;
    rollingFps = 0;
    updateTimeMs = 0;
    renderTimeMs = 0;
    audioTimeMs = 0;
    gcPauseMs = 0;
    otherTimeMs = 0;
    allocBytes = 0;
    netHeapDeltaBytes = 0;
    gcReclaimedBytes = 0;
    heapUsedBytes = 0;
    heapReservedBytes = 0;
    rssBytes = 0;
    peakRssBytes = 0;
    allocCount = 0;
    gcCount = 0;
    explicitGcCount = 0;
    implicitGcCount = 0;
    updateSteps = 0;
    drawCalls = 0;
    stateName = state;
  }

  public function copyFrom(other:FallbackSample):Void
  {
    frameIndex = other.frameIndex;
    timestampMs = other.timestampMs;
    frameTimeMs = other.frameTimeMs;
    workTimeMs = other.workTimeMs;
    fps = other.fps;
    rollingFps = other.rollingFps;
    updateTimeMs = other.updateTimeMs;
    renderTimeMs = other.renderTimeMs;
    audioTimeMs = other.audioTimeMs;
    gcPauseMs = other.gcPauseMs;
    otherTimeMs = other.otherTimeMs;
    allocBytes = other.allocBytes;
    netHeapDeltaBytes = other.netHeapDeltaBytes;
    gcReclaimedBytes = other.gcReclaimedBytes;
    heapUsedBytes = other.heapUsedBytes;
    heapReservedBytes = other.heapReservedBytes;
    rssBytes = other.rssBytes;
    peakRssBytes = other.peakRssBytes;
    allocCount = other.allocCount;
    gcCount = other.gcCount;
    explicitGcCount = other.explicitGcCount;
    implicitGcCount = other.implicitGcCount;
    updateSteps = other.updateSteps;
    drawCalls = other.drawCalls;
    stateName = other.stateName;
  }
}

class NativeFrameProfiler
{
  public static inline final PHASE_UPDATE:Int = 0;
  public static inline final PHASE_RENDER:Int = 1;
  public static inline final PHASE_AUDIO:Int = 2;
  public static inline final PHASE_GC:Int = 3;
  public static inline final RING_CAPACITY:Int = 2048;

  static var _initialized:Bool = false;
  static var _enabled:Bool = true;
  static var _inFlightFrame:Bool = false;
  static var _hasObservedHeap:Bool = false;

  static var _targetFps:Float = 60.0;
  static var _sessionStartTimeMs:Float = 0.0;
  static var _currentFrameStartMs:Float = 0.0;
  static var _lastFrameEndMs:Float = 0.0;

  static var _phaseStartMs:Array<Float> = [0.0, 0.0, 0.0, 0.0];
  static var _phaseDepth:Array<Int> = [0, 0, 0, 0];

  static var _nestedAudioInUpdateMs:Float = 0.0;
  static var _nestedGcInUpdateMs:Float = 0.0;
  static var _nestedGcInRenderMs:Float = 0.0;
  static var _nestedGcInAudioMs:Float = 0.0;

  static var _emaUpdateMs:Float = 0.0;
  static var _emaRenderMs:Float = 0.0;
  static var _emaAudioMs:Float = 0.0;

  static var _frameStartHeapBytes:Float = 0.0;
  static var _lastObservedHeapBytes:Float = 0.0;
  static var _lastObservedReservedBytes:Float = 0.0;

  static var _rollingWindowMs:Float = 0.0;
  static var _rollingWindowFrames:Int = 0;
  static var _currentRollingFps:Float = 0.0;

  static var _totalFrames:Float = 0.0;
  static var _totalDurationMs:Float = 0.0;
  static var _minFrameTimeMs:Float = 0.0;
  static var _maxFrameTimeMs:Float = 0.0;
  static var _sumFrameTimeMs:Float = 0.0;
  static var _sumSqFrameTimeMs:Float = 0.0;
  static var _spikeCount25Ms:Float = 0.0;
  static var _spikeCount33Ms:Float = 0.0;

  static var _totalUpdateTimeMs:Float = 0.0;
  static var _maxUpdateTimeMs:Float = 0.0;
  static var _totalRenderTimeMs:Float = 0.0;
  static var _maxRenderTimeMs:Float = 0.0;
  static var _totalAudioTimeMs:Float = 0.0;
  static var _maxAudioTimeMs:Float = 0.0;

  static var _totalGcCount:Float = 0.0;
  static var _totalExplicitGcCount:Float = 0.0;
  static var _totalImplicitGcCount:Float = 0.0;
  static var _framesWithGc:Float = 0.0;
  static var _totalGcPauseMs:Float = 0.0;
  static var _maxGcPauseMs:Float = 0.0;
  static var _maxGcPauseFrame:Float = 0.0;
  static var _totalGcReclaimedBytes:Float = 0.0;

  static var _totalAllocBytes:Float = 0.0;
  static var _totalAllocCount:Float = 0.0;
  static var _peakFrameAllocBytes:Float = 0.0;
  static var _peakFrameAllocFrame:Float = 0.0;
  static var _startHeapUsedBytes:Float = 0.0;
  static var _currentHeapUsedBytes:Float = 0.0;
  static var _peakHeapUsedBytes:Float = 0.0;
  static var _currentHeapReservedBytes:Float = 0.0;
  static var _currentRssBytes:Float = 0.0;
  static var _peakRssBytes:Float = 0.0;

  static var _currentStateName:String = "InitState";
  static var _activeSample:FallbackSample = new FallbackSample();
  static var _cachedSample:FallbackSample = new FallbackSample();
  static var _samples:Array<FallbackSample> = [];
  static var _writeIndex:Int = 0;
  static var _sampleCount:Int = 0;

  static var _p50FrameTimeMs:Float = 0.0;
  static var _p95FrameTimeMs:Float = 0.0;
  static var _p99FrameTimeMs:Float = 0.0;
  static var _p999FrameTimeMs:Float = 0.0;
  static var _p99UpdateTimeMs:Float = 0.0;
  static var _p99RenderTimeMs:Float = 0.0;
  static var _p99AudioTimeMs:Float = 0.0;
  static var _stdDevFrameTimeMs:Float = 0.0;

  public static function init(targetFps:Float = 60.0):Void
  {
    _initialized = true;
    _enabled = true;
    _inFlightFrame = false;
    _hasObservedHeap = false;
    _targetFps = targetFps > 0.0 ? targetFps : 60.0;
    _sessionStartTimeMs = nowMs();
    _currentFrameStartMs = 0.0;
    _lastFrameEndMs = 0.0;
    _rollingWindowMs = 0.0;
    _rollingWindowFrames = 0;
    _currentRollingFps = 0.0;
    _totalFrames = 0.0;
    _totalDurationMs = 0.0;
    _minFrameTimeMs = 0.0;
    _maxFrameTimeMs = 0.0;
    _sumFrameTimeMs = 0.0;
    _sumSqFrameTimeMs = 0.0;
    _spikeCount25Ms = 0.0;
    _spikeCount33Ms = 0.0;
    _totalUpdateTimeMs = 0.0;
    _maxUpdateTimeMs = 0.0;
    _totalRenderTimeMs = 0.0;
    _maxRenderTimeMs = 0.0;
    _totalAudioTimeMs = 0.0;
    _maxAudioTimeMs = 0.0;
    _totalGcCount = 0.0;
    _totalExplicitGcCount = 0.0;
    _totalImplicitGcCount = 0.0;
    _framesWithGc = 0.0;
    _totalGcPauseMs = 0.0;
    _maxGcPauseMs = 0.0;
    _maxGcPauseFrame = 0.0;
    _totalGcReclaimedBytes = 0.0;
    _totalAllocBytes = 0.0;
    _totalAllocCount = 0.0;
    _peakFrameAllocBytes = 0.0;
    _peakFrameAllocFrame = 0.0;
    _startHeapUsedBytes = 0.0;
    _currentHeapUsedBytes = 0.0;
    _peakHeapUsedBytes = 0.0;
    _currentHeapReservedBytes = 0.0;
    _currentRssBytes = GetTotalMemory.getCurrentRSS();
    _peakRssBytes = GetTotalMemory.getPeakRSS();
    _writeIndex = 0;
    _sampleCount = 0;
    if (_samples.length < RING_CAPACITY)
    {
      for (_ in _samples.length...RING_CAPACITY)
        _samples.push(new FallbackSample());
    }
  }

  public static function reset():Void
  {
    var savedTarget = _targetFps;
    var savedEnabled = _enabled;
    var savedState = _currentStateName;
    init(savedTarget);
    _enabled = savedEnabled;
    _currentStateName = savedState;
  }

  public static function setEnabled(enabled:Bool):Void
  {
    if (!_initialized)
      init(60.0);
    _enabled = enabled;
    if (!_enabled)
      _inFlightFrame = false;
  }

  public static function isEnabled():Bool
  {
    return _initialized ? _enabled : true;
  }

  public static function setTargetFps(targetFps:Float):Void
  {
    if (!_initialized)
      init(targetFps);
    if (targetFps > 0.0)
      _targetFps = targetFps;
  }

  public static function setStateName(stateName:String):Void
  {
    if (!_initialized)
      init(60.0);
    _currentStateName = (stateName != null && stateName.length > 0) ? stateName : "Unknown";
    if (_inFlightFrame)
      _activeSample.stateName = _currentStateName;
  }

  public static function nowMs():Float
  {
    return haxe.Timer.stamp() * 1000.0;
  }

  static function observeHeap(heapUsedBytes:Float, isExplicitGcEnd:Bool, phaseElapsedMs:Float, activePhase:Int):Void
  {
    if (heapUsedBytes < 0.0)
      return;
    if (!_hasObservedHeap)
    {
      _lastObservedHeapBytes = heapUsedBytes;
      _frameStartHeapBytes = heapUsedBytes;
      _startHeapUsedBytes = heapUsedBytes;
      _currentHeapUsedBytes = heapUsedBytes;
      _peakHeapUsedBytes = heapUsedBytes;
      _hasObservedHeap = true;
      return;
    }

    var delta = heapUsedBytes - _lastObservedHeapBytes;
    if (delta > 0.0)
    {
      _activeSample.allocBytes += delta;
      _activeSample.allocCount += 1;
    }
    else if (delta < 0.0)
    {
      var reclaimed = -delta;
      _activeSample.gcReclaimedBytes += reclaimed;
      if (!isExplicitGcEnd && _phaseDepth[PHASE_GC] <= 0)
      {
        _activeSample.implicitGcCount += 1;
        _activeSample.gcCount += 1;
        if (phaseElapsedMs > 0.0)
        {
          var est = phaseElapsedMs * 0.25;
          if (est < 0.02)
            est = 0.02;
          _activeSample.gcPauseMs += est;
        }
      }
    }
    _lastObservedHeapBytes = heapUsedBytes;
    _currentHeapUsedBytes = heapUsedBytes;
    if (heapUsedBytes > _peakHeapUsedBytes)
      _peakHeapUsedBytes = heapUsedBytes;
  }

  public static function beginFrame(heapUsedBytes:Float, heapReservedBytes:Float):Void
  {
    if (!_initialized)
      init(60.0);
    if (!_enabled)
      return;
    var now = nowMs();
    if (_totalFrames == 0 && !_inFlightFrame)
    {
      _sessionStartTimeMs = now;
      if (heapUsedBytes > 0.0)
        _startHeapUsedBytes = heapUsedBytes;
    }
    _activeSample.reset(_currentStateName);
    for (i in 0...4)
    {
      _phaseStartMs[i] = 0.0;
      _phaseDepth[i] = 0;
    }
    _nestedAudioInUpdateMs = 0.0;
    _nestedGcInUpdateMs = 0.0;
    _nestedGcInRenderMs = 0.0;
    _nestedGcInAudioMs = 0.0;
    observeHeap(heapUsedBytes, false, 0.0, -1);
    _frameStartHeapBytes = heapUsedBytes >= 0.0 ? heapUsedBytes : _lastObservedHeapBytes;
    if (heapReservedBytes >= 0.0)
    {
      _lastObservedReservedBytes = heapReservedBytes;
      _currentHeapReservedBytes = heapReservedBytes;
    }
    _currentFrameStartMs = now;
    _inFlightFrame = true;
  }

  public static function beginPhase(phase:Int, heapUsedBytes:Float):Void
  {
    if (phase < 0 || phase >= 4)
      return;
    if (!_initialized)
      init(60.0);
    if (!_enabled)
      return;
    if (!_inFlightFrame)
      beginFrame(heapUsedBytes, _lastObservedReservedBytes);
    observeHeap(heapUsedBytes, false, 0.0, -1);
    if (_phaseDepth[phase] == 0)
    {
      _phaseStartMs[phase] = nowMs();
      if (phase == PHASE_UPDATE)
        _activeSample.updateSteps += 1;
    }
    _phaseDepth[phase] += 1;
  }

  public static function endPhase(phase:Int, heapUsedBytes:Float):Float
  {
    if (phase < 0 || phase >= 4 || !_initialized || !_enabled || !_inFlightFrame)
      return 0.0;
    if (_phaseDepth[phase] <= 0)
      return 0.0;
    _phaseDepth[phase] -= 1;
    if (_phaseDepth[phase] > 0)
      return 0.0;

    var rawElapsedMs = nowMs() - _phaseStartMs[phase];
    if (rawElapsedMs < 0.0)
      rawElapsedMs = 0.0;

    if (phase == PHASE_GC)
    {
      observeHeap(heapUsedBytes, true, rawElapsedMs, PHASE_GC);
      _activeSample.explicitGcCount += 1;
      _activeSample.gcCount += 1;
      _activeSample.gcPauseMs += rawElapsedMs;
      if (_phaseDepth[PHASE_AUDIO] > 0)
        _nestedGcInAudioMs += rawElapsedMs;
      else if (_phaseDepth[PHASE_UPDATE] > 0)
        _nestedGcInUpdateMs += rawElapsedMs;
      else if (_phaseDepth[PHASE_RENDER] > 0)
        _nestedGcInRenderMs += rawElapsedMs;
      return rawElapsedMs;
    }

    observeHeap(heapUsedBytes, false, rawElapsedMs, phase);
    var netElapsedMs = rawElapsedMs;
    if (phase == PHASE_AUDIO)
    {
      netElapsedMs = Math.max(0.0, rawElapsedMs - _nestedGcInAudioMs);
      _nestedGcInAudioMs = 0.0;
      _activeSample.audioTimeMs += netElapsedMs;
      if (_phaseDepth[PHASE_UPDATE] > 0)
        _nestedAudioInUpdateMs += rawElapsedMs;
    }
    else if (phase == PHASE_UPDATE)
    {
      netElapsedMs = Math.max(0.0, rawElapsedMs - _nestedAudioInUpdateMs - _nestedGcInUpdateMs);
      _nestedAudioInUpdateMs = 0.0;
      _nestedGcInUpdateMs = 0.0;
      _activeSample.updateTimeMs += netElapsedMs;
    }
    else if (phase == PHASE_RENDER)
    {
      netElapsedMs = Math.max(0.0, rawElapsedMs - _nestedGcInRenderMs);
      _nestedGcInRenderMs = 0.0;
      _activeSample.renderTimeMs += netElapsedMs;
    }
    return netElapsedMs;
  }

  public static function recordPhaseMs(phase:Int, durationMs:Float):Void
  {
    if (durationMs <= 0.0 || phase < 0 || phase >= 4)
      return;
    if (!_initialized)
      init(60.0);
    if (!_enabled)
      return;
    if (!_inFlightFrame)
      beginFrame(_lastObservedHeapBytes, _lastObservedReservedBytes);
    if (phase == PHASE_UPDATE)
    {
      _activeSample.updateTimeMs += durationMs;
      _activeSample.updateSteps += 1;
    }
    else if (phase == PHASE_RENDER)
      _activeSample.renderTimeMs += durationMs;
    else if (phase == PHASE_AUDIO)
      _activeSample.audioTimeMs += durationMs;
    else if (phase == PHASE_GC)
    {
      _activeSample.gcPauseMs += durationMs;
      _activeSample.explicitGcCount += 1;
      _activeSample.gcCount += 1;
    }
  }

  public static function recordAllocation(bytes:Float, count:Int = 1):Void
  {
    if (bytes <= 0.0)
      return;
    if (!_initialized)
      init(60.0);
    if (!_enabled)
      return;
    if (!_inFlightFrame)
      beginFrame(_lastObservedHeapBytes, _lastObservedReservedBytes);
    _activeSample.allocBytes += bytes;
    _activeSample.allocCount += count > 0 ? count : 1;
  }

  public static function recordGCPause(pauseMs:Float, reclaimedBytes:Float = 0.0, isExplicit:Bool = true):Void
  {
    if (!_initialized)
      init(60.0);
    if (!_enabled)
      return;
    if (!_inFlightFrame)
      beginFrame(_lastObservedHeapBytes, _lastObservedReservedBytes);
    if (pauseMs > 0.0)
      _activeSample.gcPauseMs += pauseMs;
    if (reclaimedBytes > 0.0)
      _activeSample.gcReclaimedBytes += reclaimedBytes;
    _activeSample.gcCount += 1;
    if (isExplicit)
      _activeSample.explicitGcCount += 1;
    else
      _activeSample.implicitGcCount += 1;
  }

  public static function addDrawCalls(drawCalls:Int):Void
  {
    if (_inFlightFrame && drawCalls > 0)
      _activeSample.drawCalls += drawCalls;
  }

  public static function endFrame(
    heapUsedBytes:Float,
    heapReservedBytes:Float,
    drawCalls:Int = 0,
    explicitFrameTimeMs:Float = 0.0):Void
  {
    if (!_initialized || !_enabled || !_inFlightFrame)
      return;
    var i = 3;
    while (i >= 0)
    {
      while (_phaseDepth[i] > 0)
        endPhase(i, heapUsedBytes);
      --i;
    }
    observeHeap(heapUsedBytes, false, 0.0, -1);
    if (heapReservedBytes >= 0.0)
    {
      _lastObservedReservedBytes = heapReservedBytes;
      _currentHeapReservedBytes = heapReservedBytes;
    }
    var now = nowMs();
    var workTimeMs = Math.max(0.0, now - _currentFrameStartMs);
    var accountedMs = _activeSample.updateTimeMs + _activeSample.renderTimeMs + _activeSample.audioTimeMs + _activeSample.gcPauseMs;
    if (workTimeMs < accountedMs)
      workTimeMs = accountedMs;

    var frameTimeMs = workTimeMs;
    if (explicitFrameTimeMs > 0.0)
      frameTimeMs = Math.max(explicitFrameTimeMs, workTimeMs);
    else if (_lastFrameEndMs > 0.0)
    {
      var delta = now - _lastFrameEndMs;
      if (delta >= workTimeMs && delta < 10000.0)
        frameTimeMs = delta;
    }
    if (frameTimeMs <= 0.0)
      frameTimeMs = _targetFps > 0.0 ? (1000.0 / _targetFps) : 16.6667;

    _rollingWindowFrames += 1;
    _rollingWindowMs += frameTimeMs;
    if (_rollingWindowMs >= 1000.0)
    {
      _currentRollingFps = (_rollingWindowFrames * 1000.0) / _rollingWindowMs;
      _rollingWindowFrames = 0;
      _rollingWindowMs = 0.0;
    }
    else if (_currentRollingFps <= 0.0)
    {
      _currentRollingFps = (_rollingWindowFrames * 1000.0) / _rollingWindowMs;
    }

    _currentRssBytes = GetTotalMemory.getCurrentRSS();
    _peakRssBytes = Math.max(_peakRssBytes, GetTotalMemory.getPeakRSS());

    _totalFrames += 1.0;
    _activeSample.frameIndex = _totalFrames;
    _activeSample.timestampMs = Math.max(0.0, now - _sessionStartTimeMs);
    _activeSample.frameTimeMs = frameTimeMs;
    _activeSample.workTimeMs = workTimeMs;
    _activeSample.fps = 1000.0 / frameTimeMs;
    _activeSample.rollingFps = _currentRollingFps;
    _activeSample.otherTimeMs = Math.max(0.0, frameTimeMs - accountedMs);
    _activeSample.heapUsedBytes = _lastObservedHeapBytes;
    _activeSample.heapReservedBytes = _lastObservedReservedBytes;
    _activeSample.netHeapDeltaBytes = _lastObservedHeapBytes - _frameStartHeapBytes;
    _activeSample.rssBytes = _currentRssBytes;
    _activeSample.peakRssBytes = _peakRssBytes;
    if (drawCalls > 0)
      _activeSample.drawCalls += drawCalls;

    _totalDurationMs += frameTimeMs;
    _sumFrameTimeMs += frameTimeMs;
    _sumSqFrameTimeMs += frameTimeMs * frameTimeMs;
    if (_totalFrames == 1.0 || frameTimeMs < _minFrameTimeMs)
      _minFrameTimeMs = frameTimeMs;
    if (_totalFrames == 1.0 || frameTimeMs > _maxFrameTimeMs)
      _maxFrameTimeMs = frameTimeMs;
    if (frameTimeMs > 25.0)
      _spikeCount25Ms += 1.0;
    if (frameTimeMs > 33.3333)
      _spikeCount33Ms += 1.0;

    _totalUpdateTimeMs += _activeSample.updateTimeMs;
    if (_activeSample.updateTimeMs > _maxUpdateTimeMs)
      _maxUpdateTimeMs = _activeSample.updateTimeMs;
    _totalRenderTimeMs += _activeSample.renderTimeMs;
    if (_activeSample.renderTimeMs > _maxRenderTimeMs)
      _maxRenderTimeMs = _activeSample.renderTimeMs;
    _totalAudioTimeMs += _activeSample.audioTimeMs;
    if (_activeSample.audioTimeMs > _maxAudioTimeMs)
      _maxAudioTimeMs = _activeSample.audioTimeMs;

    if (_activeSample.gcCount > 0 || _activeSample.gcPauseMs > 0.0)
    {
      _framesWithGc += 1.0;
      _totalGcCount += _activeSample.gcCount;
      _totalExplicitGcCount += _activeSample.explicitGcCount;
      _totalImplicitGcCount += _activeSample.implicitGcCount;
      _totalGcPauseMs += _activeSample.gcPauseMs;
      _totalGcReclaimedBytes += _activeSample.gcReclaimedBytes;
      if (_activeSample.gcPauseMs > _maxGcPauseMs)
      {
        _maxGcPauseMs = _activeSample.gcPauseMs;
        _maxGcPauseFrame = _totalFrames;
      }
    }

    _totalAllocBytes += _activeSample.allocBytes;
    _totalAllocCount += _activeSample.allocCount;
    if (_activeSample.allocBytes > _peakFrameAllocBytes)
    {
      _peakFrameAllocBytes = _activeSample.allocBytes;
      _peakFrameAllocFrame = _totalFrames;
    }

    _samples[_writeIndex].copyFrom(_activeSample);
    _writeIndex = (_writeIndex + 1) % RING_CAPACITY;
    if (_sampleCount < RING_CAPACITY)
      _sampleCount += 1;

    _lastFrameEndMs = now;
    _inFlightFrame = false;
  }

  static function computePercentile(vals:Array<Float>, p:Float):Float
  {
    if (vals.length == 0)
      return 0.0;
    vals.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
    var pos = p * (vals.length - 1);
    var lo = Std.int(Math.floor(pos));
    var hi = lo + 1 < vals.length ? lo + 1 : lo;
    var w = pos - lo;
    return vals[lo] * (1.0 - w) + vals[hi] * w;
  }

  public static function refreshSummary():Void
  {
    if (_totalFrames <= 0.0)
      return;
    var avg = _sumFrameTimeMs / _totalFrames;
    var variance = (_sumSqFrameTimeMs / _totalFrames) - (avg * avg);
    _stdDevFrameTimeMs = variance > 0.0 ? Math.sqrt(variance) : 0.0;

    if (_sampleCount > 0)
    {
      var ft = [for (i in 0..._sampleCount) _samples[i].frameTimeMs];
      _p50FrameTimeMs = computePercentile(ft, 0.50);
      _p95FrameTimeMs = computePercentile(ft, 0.95);
      _p99FrameTimeMs = computePercentile(ft, 0.99);
      _p999FrameTimeMs = computePercentile(ft, 0.999);
      _p99UpdateTimeMs = computePercentile([for (i in 0..._sampleCount) _samples[i].updateTimeMs], 0.99);
      _p99RenderTimeMs = computePercentile([for (i in 0..._sampleCount) _samples[i].renderTimeMs], 0.99);
      _p99AudioTimeMs = computePercentile([for (i in 0..._sampleCount) _samples[i].audioTimeMs], 0.99);
    }
  }

  public static function refreshLastFrame():Bool
  {
    if (_sampleCount <= 0)
      return false;
    var idx = (_writeIndex + RING_CAPACITY - 1) % RING_CAPACITY;
    _cachedSample.copyFrom(_samples[idx]);
    return true;
  }

  public static function loadBufferedFrame(chronologicalIndex:Int):Bool
  {
    if (chronologicalIndex < 0 || chronologicalIndex >= _sampleCount)
      return false;
    var oldest = _sampleCount < RING_CAPACITY ? 0 : _writeIndex;
    var idx = (oldest + chronologicalIndex) % RING_CAPACITY;
    _cachedSample.copyFrom(_samples[idx]);
    return true;
  }

  public static function resolveLogPath(requestedPath:String):String
  {
    if (requestedPath == null || StringTools.trim(requestedPath).length == 0)
      return "debug/log/frame_profiler.log";
    var norm = StringTools.replace(requestedPath, "\\", "/");
    for (bad in [":", "*", "?", "\"", "<", ">", "|", "\r", "\n"])
      norm = StringTools.replace(norm, bad, "_");
    var hasTraversal = norm.indexOf("..") >= 0;
    var out:String;
    if (!hasTraversal && norm.indexOf("debug/log/") >= 0)
      out = norm;
    else
    {
      var slash = norm.lastIndexOf("/");
      var base = slash >= 0 ? norm.substr(slash + 1) : norm;
      while (base.length > 0 && (base.charAt(0) == "." || base.charAt(0) == " "))
        base = base.substr(1);
      if (base.length == 0)
        base = "frame_profiler.log";
      out = "debug/log/" + base;
    }
    if (!StringTools.endsWith(out, ".log"))
      out += ".log";
    return out;
  }

  public static function exportLog(requestedPath:String, engineVersion:String, platformInfo:String):String
  {
    var resolved = resolveLogPath(requestedPath);
    #if sys
    try
    {
      var slashIdx = resolved.lastIndexOf("/");
      if (slashIdx > 0)
      {
        var dir = resolved.substr(0, slashIdx);
        if (!sys.FileSystem.exists(dir))
          sys.FileSystem.createDirectory(dir);
      }
      sys.io.File.saveContent(resolved, debug.FrameProfiler.formatReport(engineVersion, platformInfo, resolved));
      return resolved;
    }
    catch (_:Dynamic)
    {
      return "";
    }
    #else
    return resolved;
    #end
  }

  public static function sampleFrameIndex():Float
    return _cachedSample.frameIndex;

  public static function sampleTimestampMs():Float
    return _cachedSample.timestampMs;

  public static function sampleFrameTimeMs():Float
    return _cachedSample.frameTimeMs;

  public static function sampleWorkTimeMs():Float
    return _cachedSample.workTimeMs;

  public static function sampleFps():Float
    return _cachedSample.fps;

  public static function sampleRollingFps():Float
    return _cachedSample.rollingFps;

  public static function sampleUpdateTimeMs():Float
    return _cachedSample.updateTimeMs;

  public static function sampleRenderTimeMs():Float
    return _cachedSample.renderTimeMs;

  public static function sampleAudioTimeMs():Float
    return _cachedSample.audioTimeMs;

  public static function sampleGcPauseMs():Float
    return _cachedSample.gcPauseMs;

  public static function sampleOtherTimeMs():Float
    return _cachedSample.otherTimeMs;

  public static function sampleAllocBytes():Float
    return _cachedSample.allocBytes;

  public static function sampleNetHeapDeltaBytes():Float
    return _cachedSample.netHeapDeltaBytes;

  public static function sampleGcReclaimedBytes():Float
    return _cachedSample.gcReclaimedBytes;

  public static function sampleHeapUsedBytes():Float
    return _cachedSample.heapUsedBytes;

  public static function sampleHeapReservedBytes():Float
    return _cachedSample.heapReservedBytes;

  public static function sampleRssBytes():Float
    return _cachedSample.rssBytes;

  public static function samplePeakRssBytes():Float
    return _cachedSample.peakRssBytes;

  public static function sampleAllocCount():Int
    return _cachedSample.allocCount;

  public static function sampleGcCount():Int
    return _cachedSample.gcCount;

  public static function sampleExplicitGcCount():Int
    return _cachedSample.explicitGcCount;

  public static function sampleImplicitGcCount():Int
    return _cachedSample.implicitGcCount;

  public static function sampleUpdateSteps():Int
    return _cachedSample.updateSteps;

  public static function sampleDrawCalls():Int
    return _cachedSample.drawCalls;

  public static function sampleStateName():String
    return _cachedSample.stateName;

  public static function summaryTotalFrames():Float
    return _totalFrames;

  public static function summaryBufferedFrames():Int
    return _sampleCount;

  public static function summaryTargetFps():Float
    return _targetFps;

  public static function summarySessionDurationMs():Float
    return _totalDurationMs;

  public static function summaryCpuTimeMs():Float
    return 0.0;

  public static function summaryCpuUtilizationPct():Float
    return 0.0;

  public static function summaryAvgFrameTimeMs():Float
    return _totalFrames > 0.0 ? (_sumFrameTimeMs / _totalFrames) : 0.0;

  public static function summaryMinFrameTimeMs():Float
    return _minFrameTimeMs;

  public static function summaryMaxFrameTimeMs():Float
    return _maxFrameTimeMs;

  public static function summaryStdDevFrameTimeMs():Float
    return _stdDevFrameTimeMs;

  public static function summaryP50FrameTimeMs():Float
    return _p50FrameTimeMs;

  public static function summaryP95FrameTimeMs():Float
    return _p95FrameTimeMs;

  public static function summaryP99FrameTimeMs():Float
    return _p99FrameTimeMs;

  public static function summaryP999FrameTimeMs():Float
    return _p999FrameTimeMs;

  public static function summarySpikeCount25Ms():Float
    return _spikeCount25Ms;

  public static function summarySpikeCount33Ms():Float
    return _spikeCount33Ms;

  public static function summaryAvgFps():Float
    return _totalDurationMs > 1e-6 ? (_totalFrames * 1000.0 / _totalDurationMs) : 0.0;

  public static function summaryCurrentFps():Float
    return _currentRollingFps > 0.0 ? _currentRollingFps : summaryAvgFps();

  public static function summaryMinFps():Float
    return _maxFrameTimeMs > 1e-6 ? (1000.0 / _maxFrameTimeMs) : 0.0;

  public static function summaryMaxFps():Float
    return _minFrameTimeMs > 1e-6 ? (1000.0 / _minFrameTimeMs) : 0.0;

  public static function summaryOnePercentLowFps():Float
    return _p99FrameTimeMs > 1e-6 ? (1000.0 / _p99FrameTimeMs) : 0.0;

  public static function summaryPointOnePercentLowFps():Float
    return _p999FrameTimeMs > 1e-6 ? (1000.0 / _p999FrameTimeMs) : 0.0;

  public static function summaryAvgUpdateTimeMs():Float
    return _totalFrames > 0.0 ? (_totalUpdateTimeMs / _totalFrames) : 0.0;

  public static function summaryMaxUpdateTimeMs():Float
    return _maxUpdateTimeMs;

  public static function summaryP99UpdateTimeMs():Float
    return _p99UpdateTimeMs;

  public static function summaryTotalUpdateTimeMs():Float
    return _totalUpdateTimeMs;

  public static function summaryUpdateFrameSharePct():Float
    return _totalDurationMs > 1e-6 ? (_totalUpdateTimeMs * 100.0 / _totalDurationMs) : 0.0;

  public static function summaryAvgRenderTimeMs():Float
    return _totalFrames > 0.0 ? (_totalRenderTimeMs / _totalFrames) : 0.0;

  public static function summaryMaxRenderTimeMs():Float
    return _maxRenderTimeMs;

  public static function summaryP99RenderTimeMs():Float
    return _p99RenderTimeMs;

  public static function summaryTotalRenderTimeMs():Float
    return _totalRenderTimeMs;

  public static function summaryRenderFrameSharePct():Float
    return _totalDurationMs > 1e-6 ? (_totalRenderTimeMs * 100.0 / _totalDurationMs) : 0.0;

  public static function summaryAvgAudioTimeMs():Float
    return _totalFrames > 0.0 ? (_totalAudioTimeMs / _totalFrames) : 0.0;

  public static function summaryMaxAudioTimeMs():Float
    return _maxAudioTimeMs;

  public static function summaryP99AudioTimeMs():Float
    return _p99AudioTimeMs;

  public static function summaryTotalAudioTimeMs():Float
    return _totalAudioTimeMs;

  public static function summaryAudioFrameSharePct():Float
    return _totalDurationMs > 1e-6 ? (_totalAudioTimeMs * 100.0 / _totalDurationMs) : 0.0;

  public static function summaryTotalGcCount():Float
    return _totalGcCount;

  public static function summaryTotalExplicitGcCount():Float
    return _totalExplicitGcCount;

  public static function summaryTotalImplicitGcCount():Float
    return _totalImplicitGcCount;

  public static function summaryFramesWithGc():Float
    return _framesWithGc;

  public static function summaryTotalGcPauseMs():Float
    return _totalGcPauseMs;

  public static function summaryAvgGcPausePerFrameMs():Float
    return _totalFrames > 0.0 ? (_totalGcPauseMs / _totalFrames) : 0.0;

  public static function summaryAvgGcPausePerCollectionMs():Float
    return _totalGcCount > 0.0 ? (_totalGcPauseMs / _totalGcCount) : 0.0;

  public static function summaryMaxGcPauseMs():Float
    return _maxGcPauseMs;

  public static function summaryMaxGcPauseFrame():Float
    return _maxGcPauseFrame;

  public static function summaryGcFrameSharePct():Float
    return _totalDurationMs > 1e-6 ? (_totalGcPauseMs * 100.0 / _totalDurationMs) : 0.0;

  public static function summaryTotalGcReclaimedBytes():Float
    return _totalGcReclaimedBytes;

  public static function summaryTotalAllocBytes():Float
    return _totalAllocBytes;

  public static function summaryTotalAllocCount():Float
    return _totalAllocCount;

  public static function summaryAvgAllocBytesPerFrame():Float
    return _totalFrames > 0.0 ? (_totalAllocBytes / _totalFrames) : 0.0;

  public static function summaryAllocRateBytesPerSec():Float
    return _totalDurationMs > 1e-6 ? (_totalAllocBytes * 1000.0 / _totalDurationMs) : 0.0;

  public static function summaryPeakFrameAllocBytes():Float
    return _peakFrameAllocBytes;

  public static function summaryPeakFrameAllocFrame():Float
    return _peakFrameAllocFrame;

  public static function summaryStartHeapUsedBytes():Float
    return _startHeapUsedBytes;

  public static function summaryCurrentHeapUsedBytes():Float
    return _currentHeapUsedBytes;

  public static function summaryPeakHeapUsedBytes():Float
    return _peakHeapUsedBytes;

  public static function summaryCurrentHeapReservedBytes():Float
    return _currentHeapReservedBytes;

  public static function summaryCurrentRssBytes():Float
    return _currentRssBytes;

  public static function summaryPeakRssBytes():Float
    return _peakRssBytes;
}
#end
