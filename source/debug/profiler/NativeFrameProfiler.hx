package debug.profiler;

#if !cpp
import Date;
import debug.mem.GetTotalMemory;
import haxe.Timer;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#end

/**
 * Low-level native C/C++ bridge for the Phoenix Engine frame profiler.
 *
 * On `cpp` (hxcpp) targets, all calls delegate directly to the inline C/C++
 * functions in `phoenix_profiler.h` (`PhoenixProfilerState`), using native OS
 * monotonic clocks (`QueryPerformanceCounter`, `mach_absolute_time`, or
 * `clock_gettime(CLOCK_MONOTONIC)`), an explicit LIFO phase stack, and bounded
 * low-overhead process RSS sampling.
 *
 * On non-`cpp` targets, a behaviorally equivalent Haxe fallback implementation
 * is provided with identical phase-stack accounting, honest GC/heap semantics,
 * configurable RSS sampling, and RFC 4180 CSV report formatting.
 */
#if cpp
@:buildXml('<include name="../../../../source/debug/profiler/build.xml" />')
@:cppFileCode('
#include "phoenix_profiler.h"

static PhoenixProfilerState gPhoenixProfiler;
static PhoenixFrameSample gPhoenixLastSample;
static PhoenixProfilerSummary gPhoenixLastSummary;
static char gPhoenixOverlayBuf[512];

static inline PhoenixProfilerState* phoenixGetProfiler(void)
{
  if (!gPhoenixProfiler.initialized)
    phoenixProfilerInit(&gPhoenixProfiler, 60.0);
  return &gPhoenixProfiler;
}
')
#end
class NativeFrameProfiler
{
  public static inline var PHASE_UPDATE:Int = 0;
  public static inline var PHASE_RENDER:Int = 1;
  public static inline var PHASE_AUDIO:Int = 2;
  public static inline var PHASE_GC:Int = 3;

  public static inline var RING_CAPACITY:Int = 2048;
  public static inline var DEFAULT_RSS_SAMPLE_INTERVAL:Int = 60;

  #if cpp
  @:functionCode('
    phoenixProfilerInit(&gPhoenixProfiler, (double)targetFps);
  ')
  public static function init(targetFps:Float = 60.0):Void {}

  @:functionCode('
    phoenixProfilerEnsureInit(&gPhoenixProfiler, (double)targetFps);
  ')
  public static function ensureInit(targetFps:Float = 60.0):Void {}

  @:functionCode('
    return phoenixProfilerIsInitialized(&gPhoenixProfiler) != 0;
  ')
  public static function isInitialized():Bool
  {
    return false;
  }

  @:functionCode('
    return phoenixProfilerIsExportInProgress(&gPhoenixProfiler) != 0;
  ')
  public static function isExportInProgress():Bool
  {
    return false;
  }

  @:functionCode('
    phoenixProfilerAbortInFlightFrame(phoenixGetProfiler());
  ')
  public static function abortInFlightFrame():Void {}

  @:functionCode('
    phoenixProfilerReset(phoenixGetProfiler());
  ')
  public static function reset():Void {}

  @:functionCode('
    phoenixProfilerSetEnabled(phoenixGetProfiler(), enabled ? 1 : 0);
  ')
  public static function setEnabled(enabled:Bool):Void {}

  @:functionCode('
    return phoenixProfilerIsEnabled(phoenixGetProfiler()) != 0;
  ')
  public static function isEnabled():Bool
  {
    return false;
  }

  @:functionCode('
    phoenixProfilerSetRssSampleInterval(phoenixGetProfiler(), intervalFrames > 0 ? (uint32_t)intervalFrames : 0);
  ')
  public static function setRssSampleInterval(intervalFrames:Int):Void {}

  @:functionCode('
    return (int)phoenixProfilerGetRssSampleInterval(phoenixGetProfiler());
  ')
  public static function getRssSampleInterval():Int
  {
    return DEFAULT_RSS_SAMPLE_INTERVAL;
  }

  @:functionCode('
    phoenixProfilerSetCollectMemoryMetrics(phoenixGetProfiler(), enabled ? 1 : 0);
  ')
  public static function setCollectMemoryMetrics(enabled:Bool):Void {}

  @:functionCode('
    return phoenixProfilerGetCollectMemoryMetrics(phoenixGetProfiler()) != 0;
  ')
  public static function getCollectMemoryMetrics():Bool
  {
    return true;
  }

  @:functionCode('
    phoenixProfilerSetTargetFps(phoenixGetProfiler(), (double)targetFps);
  ')
  public static function setTargetFps(targetFps:Float):Void {}

  @:functionCode('
    const char *raw = stateName.utf8_str();
    phoenixProfilerSetStateName(phoenixGetProfiler(), raw != NULL ? raw : "UnknownState");
  ')
  public static function setStateName(stateName:String):Void {}

  @:functionCode('
    return phoenixProfilerNowMs();
  ')
  public static function nowMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    phoenixProfilerBeginFrame(phoenixGetProfiler(), (int64_t)heapUsedBytes, (int64_t)heapReservedBytes);
  ')
  public static function beginFrame(heapUsedBytes:Float, heapReservedBytes:Float):Void {}

  @:functionCode('
    phoenixProfilerEndFrameAt(
      phoenixGetProfiler(),
      phoenixProfilerNowMs(),
      (double)explicitFrameTimeMs,
      (int64_t)heapUsedBytes,
      (int64_t)heapReservedBytes,
      drawCalls > 0 ? (uint32_t)drawCalls : 0);
  ')
  public static function endFrame(
    heapUsedBytes:Float,
    heapReservedBytes:Float,
    drawCalls:Int,
    explicitFrameTimeMs:Float = 0.0):Void {}

  @:functionCode('
    phoenixProfilerBeginUpdate(phoenixGetProfiler(), (int64_t)heapUsedBytes);
  ')
  public static function beginUpdate(heapUsedBytes:Float):Void {}

  @:functionCode('
    return phoenixProfilerEndUpdate(phoenixGetProfiler(), (int64_t)heapUsedBytes);
  ')
  public static function endUpdate(heapUsedBytes:Float):Float
  {
    return 0.0;
  }

  @:functionCode('
    phoenixProfilerBeginRender(phoenixGetProfiler(), (int64_t)heapUsedBytes);
  ')
  public static function beginRender(heapUsedBytes:Float):Void {}

  @:functionCode('
    return phoenixProfilerEndRender(phoenixGetProfiler(), (int64_t)heapUsedBytes);
  ')
  public static function endRender(heapUsedBytes:Float):Float
  {
    return 0.0;
  }

  @:functionCode('
    phoenixProfilerBeginAudio(phoenixGetProfiler(), (int64_t)heapUsedBytes);
  ')
  public static function beginAudio(heapUsedBytes:Float):Void {}

  @:functionCode('
    return phoenixProfilerEndAudio(phoenixGetProfiler(), (int64_t)heapUsedBytes);
  ')
  public static function endAudio(heapUsedBytes:Float):Float
  {
    return 0.0;
  }

  @:functionCode('
    phoenixProfilerBeginGC(phoenixGetProfiler(), (int64_t)heapUsedBytes);
  ')
  public static function beginGC(heapUsedBytes:Float):Void {}

  @:functionCode('
    return phoenixProfilerEndGC(phoenixGetProfiler(), (int64_t)heapUsedBytes);
  ')
  public static function endGC(heapUsedBytes:Float):Float
  {
    return 0.0;
  }

  @:functionCode('
    phoenixProfilerRecordPhaseMs(phoenixGetProfiler(), phase, (double)durationMs);
  ')
  public static function recordPhaseMs(phase:Int, durationMs:Float):Void {}

  @:functionCode('
    phoenixProfilerRecordAllocation(phoenixGetProfiler(), (int64_t)bytes, count > 0 ? (uint32_t)count : 1);
  ')
  public static function recordAllocation(bytes:Float, count:Int = 1):Void {}

  @:functionCode('
    phoenixProfilerRecordGCPause(phoenixGetProfiler(), (double)pauseMs, (int64_t)reclaimedBytes, isExplicit ? 1 : 0);
  ')
  public static function recordGCPause(pauseMs:Float, reclaimedBytes:Float, isExplicit:Bool = true):Void {}

  @:functionCode('
    return phoenixProfilerGetLastFrame(phoenixGetProfiler(), &gPhoenixLastSample) != 0;
  ')
  public static function loadLastFrame():Bool
  {
    return false;
  }

  @:functionCode('
    if (chronologicalIndex < 0)
      return false;
    return phoenixProfilerGetBufferedFrame(phoenixGetProfiler(), (size_t)chronologicalIndex, &gPhoenixLastSample) != 0;
  ')
  public static function loadBufferedFrame(chronologicalIndex:Int):Bool
  {
    return false;
  }

  @:functionCode('
    return (int)phoenixGetProfiler()->ringCount;
  ')
  public static function getBufferedFrameCount():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSample.frameIndex;
  ')
  public static function lastSampleFrameIndex():Int
  {
    return 0;
  }

  @:functionCode('
    return gPhoenixLastSample.timestampMs;
  ')
  public static function lastSampleTimestampMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.frameTimeMs;
  ')
  public static function lastSampleFrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.workTimeMs;
  ')
  public static function lastSampleWorkTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.fps;
  ')
  public static function lastSampleFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.rollingFps;
  ')
  public static function lastSampleRollingFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.updateTimeMs;
  ')
  public static function lastSampleUpdateTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.renderTimeMs;
  ')
  public static function lastSampleRenderTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.audioTimeMs;
  ')
  public static function lastSampleAudioTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.gcPauseMs;
  ')
  public static function lastSampleGcPauseMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.otherTimeMs;
  ')
  public static function lastSampleOtherTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.updateInclusiveMs;
  ')
  public static function lastSampleUpdateInclusiveMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.renderInclusiveMs;
  ')
  public static function lastSampleRenderInclusiveMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.audioInclusiveMs;
  ')
  public static function lastSampleAudioInclusiveMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSample.gcInclusiveMs;
  ')
  public static function lastSampleGcInclusiveMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSample.allocBytes;
  ')
  public static function lastSampleAllocBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (int)gPhoenixLastSample.allocCount;
  ')
  public static function lastSampleAllocCount():Int
  {
    return 0;
  }

  @:functionCode('
    return (double)gPhoenixLastSample.gcReclaimedBytes;
  ')
  public static function lastSampleGcReclaimedBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSample.netHeapDeltaBytes;
  ')
  public static function lastSampleNetHeapDeltaBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSample.heapUsedBytes;
  ')
  public static function lastSampleHeapUsedBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSample.heapReservedBytes;
  ')
  public static function lastSampleHeapReservedBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSample.rssBytes;
  ')
  public static function lastSampleRssBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSample.peakRssBytes;
  ')
  public static function lastSamplePeakRssBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (int)gPhoenixLastSample.gcCount;
  ')
  public static function lastSampleGcCount():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSample.explicitGcCount;
  ')
  public static function lastSampleExplicitGcCount():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSample.implicitGcCount;
  ')
  public static function lastSampleImplicitGcCount():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSample.drawCalls;
  ')
  public static function lastSampleDrawCalls():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSample.updateSteps;
  ')
  public static function lastSampleUpdateSteps():Int
  {
    return 0;
  }

  @:functionCode('
    return gPhoenixLastSample.rssSampled != 0;
  ')
  public static function lastSampleRssSampled():Bool
  {
    return false;
  }

  @:functionCode('
    return ::String(gPhoenixLastSample.stateName);
  ')
  public static function lastSampleStateName():String
  {
    return "UnknownState";
  }

  @:functionCode('
    phoenixProfilerComputeSummary(phoenixGetProfiler(), &gPhoenixLastSummary);
  ')
  public static function refreshSummary():Void {}

  @:functionCode('
    return (int)gPhoenixLastSummary.totalFrames;
  ')
  public static function summaryTotalFrames():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.bufferedFrames;
  ')
  public static function summaryBufferedFrames():Int
  {
    return 0;
  }

  @:functionCode('
    return gPhoenixLastSummary.sessionDurationMs;
  ')
  public static function summarySessionDurationMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.targetFps;
  ')
  public static function summaryTargetFps():Float
  {
    return 60.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.targetFrameTimeMs;
  ')
  public static function summaryTargetFrameTimeMs():Float
  {
    return 16.6667;
  }

  @:functionCode('
    return gPhoenixLastSummary.currentFps;
  ')
  public static function summaryCurrentFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgFps;
  ')
  public static function summaryAvgFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.minFps;
  ')
  public static function summaryMinFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.maxFps;
  ')
  public static function summaryMaxFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.onePercentLowFps;
  ')
  public static function summaryOnePercentLowFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.pointOnePercentLowFps;
  ')
  public static function summaryPointOnePercentLowFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.slowest1PctAvgFps;
  ')
  public static function summarySlowest1PctAvgFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.slowest01PctAvgFps;
  ')
  public static function summarySlowest01PctAvgFps():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.lastFrameTimeMs;
  ')
  public static function summaryLastFrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgFrameTimeMs;
  ')
  public static function summaryAvgFrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.minFrameTimeMs;
  ')
  public static function summaryMinFrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.maxFrameTimeMs;
  ')
  public static function summaryMaxFrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.stdDevFrameTimeMs;
  ')
  public static function summaryStdDevFrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.p50FrameTimeMs;
  ')
  public static function summaryP50FrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.p95FrameTimeMs;
  ')
  public static function summaryP95FrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.p99FrameTimeMs;
  ')
  public static function summaryP99FrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.p999FrameTimeMs;
  ')
  public static function summaryP999FrameTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgUpdateTimeMs;
  ')
  public static function summaryAvgUpdateTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.maxUpdateTimeMs;
  ')
  public static function summaryMaxUpdateTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.p95UpdateTimeMs;
  ')
  public static function summaryP95UpdateTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgRenderTimeMs;
  ')
  public static function summaryAvgRenderTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.maxRenderTimeMs;
  ')
  public static function summaryMaxRenderTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.p95RenderTimeMs;
  ')
  public static function summaryP95RenderTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgAudioTimeMs;
  ')
  public static function summaryAvgAudioTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.maxAudioTimeMs;
  ')
  public static function summaryMaxAudioTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.p95AudioTimeMs;
  ')
  public static function summaryP95AudioTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgOtherTimeMs;
  ')
  public static function summaryAvgOtherTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.maxOtherTimeMs;
  ')
  public static function summaryMaxOtherTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.totalGcCount;
  ')
  public static function summaryTotalGcCount():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.totalExplicitGcCount;
  ')
  public static function summaryTotalExplicitGcCount():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.totalImplicitGcCount;
  ')
  public static function summaryTotalImplicitGcCount():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.framesWithGc;
  ')
  public static function summaryFramesWithGc():Int
  {
    return 0;
  }

  @:functionCode('
    return gPhoenixLastSummary.totalGcPauseMs;
  ')
  public static function summaryTotalGcPauseMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgGcPauseMs;
  ')
  public static function summaryAvgGcPauseMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.maxGcPauseMs;
  ')
  public static function summaryMaxGcPauseMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.maxGcPauseFrame;
  ')
  public static function summaryMaxGcPauseFrame():Int
  {
    return 0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.totalGcReclaimedBytes;
  ')
  public static function summaryTotalGcReclaimedBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.totalAllocBytes;
  ')
  public static function summaryTotalAllocBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.totalAllocCount;
  ')
  public static function summaryTotalAllocCount():Int
  {
    return 0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgAllocBytesPerFrame;
  ')
  public static function summaryAvgAllocBytesPerFrame():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.allocRateBytesPerSec;
  ')
  public static function summaryAllocRateBytesPerSec():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.peakFrameAllocBytes;
  ')
  public static function summaryPeakFrameAllocBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.peakFrameAllocFrame;
  ')
  public static function summaryPeakFrameAllocFrame():Int
  {
    return 0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.currentHeapUsedBytes;
  ')
  public static function summaryCurrentHeapUsedBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.currentHeapReservedBytes;
  ')
  public static function summaryCurrentHeapReservedBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.peakHeapUsedBytes;
  ')
  public static function summaryPeakHeapUsedBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.peakHeapReservedBytes;
  ')
  public static function summaryPeakHeapReservedBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.currentRssBytes;
  ')
  public static function summaryCurrentRssBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (double)gPhoenixLastSummary.peakRssBytes;
  ')
  public static function summaryPeakRssBytes():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.droppedFrames;
  ')
  public static function summaryDroppedFrames():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.spikeCount16Ms;
  ')
  public static function summarySpikeCount16Ms():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.spikeCount25Ms;
  ')
  public static function summarySpikeCount25Ms():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.spikeCount33Ms;
  ')
  public static function summarySpikeCount33Ms():Int
  {
    return 0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.spikeCount50Ms;
  ')
  public static function summarySpikeCount50Ms():Int
  {
    return 0;
  }

  @:functionCode('
    return gPhoenixLastSummary.avgDrawCalls;
  ')
  public static function summaryAvgDrawCalls():Float
  {
    return 0.0;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.maxDrawCalls;
  ')
  public static function summaryMaxDrawCalls():Int
  {
    return 0;
  }

  @:functionCode('
    return gPhoenixLastSummary.cpuTimeMs;
  ')
  public static function summaryCpuTimeMs():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.cpuUtilizationPct;
  ')
  public static function summaryCpuUtilizationPct():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.cpuNormalizedPct;
  ')
  public static function summaryCpuNormalizedPct():Float
  {
    return 0.0;
  }

  @:functionCode('
    return gPhoenixLastSummary.logicalCpuCount;
  ')
  public static function summaryLogicalCpuCount():Int
  {
    return 1;
  }

  @:functionCode('
    return gPhoenixLastSummary.cpuTimeAvailable != 0;
  ')
  public static function summaryCpuTimeAvailable():Bool
  {
    return false;
  }

  @:functionCode('
    return gPhoenixLastSummary.rssAvailable != 0;
  ')
  public static function summaryRssAvailable():Bool
  {
    return false;
  }

  @:functionCode('
    return gPhoenixLastSummary.heapStatsAvailable != 0;
  ')
  public static function summaryHeapStatsAvailable():Bool
  {
    return false;
  }

  @:functionCode('
    return (int)gPhoenixLastSummary.rssSampleIntervalFrames;
  ')
  public static function summaryRssSampleIntervalFrames():Int
  {
    return DEFAULT_RSS_SAMPLE_INTERVAL;
  }

  @:functionCode('
    if (phoenixProfilerFormatOverlay(phoenixGetProfiler(), gPhoenixOverlayBuf, sizeof(gPhoenixOverlayBuf)))
      return ::String(gPhoenixOverlayBuf);
    return ::String("");
  ')
  public static function formatOverlay():String
  {
    return "";
  }

  @:functionCode('
    char resolved[PHOENIX_PROFILER_PATH_MAX];
    const char *req = requestedPath.utf8_str();
    const char *ver = engineVersion.utf8_str();
    const char *plat = platformName.utf8_str();
    if (phoenixProfilerExportLog(phoenixGetProfiler(), req, ver, plat, resolved, sizeof(resolved)))
      return ::String(resolved);
    return ::String("");
  ')
  public static function exportLog(
    requestedPath:String = "",
    engineVersion:String = "0.3.2",
    platformName:String = "C++/hxcpp"):String
  {
    return "";
  }

  #else
  private static var _initialized:Bool = false;
  private static var _enabled:Bool = true;
  private static var _inFlight:Bool = false;
  private static var _exportInProgress:Bool = false;
  private static var _collectMemory:Bool = true;
  private static var _rssSampleInterval:Int = DEFAULT_RSS_SAMPLE_INTERVAL;
  private static var _targetFps:Float = 60.0;
  private static var _sessionStartMs:Float = 0.0;
  private static var _currentFrameStartMs:Float = 0.0;
  private static var _lastFrameEndMs:Float = 0.0;
  private static var _currentRollingFps:Float = 0.0;
  private static var _rollingWindowMs:Float = 0.0;
  private static var _rollingWindowCount:Int = 0;
  private static var _currentStateName:String = "InitialState";

  private static var _cachedOverlayFrame:Int = 0;
  private static var _cachedOverlayP95:Float = 0.0;
  private static var _cachedOverlayP99:Float = 0.0;

  private static var _phaseStack:Array<{phase:Int, startMs:Float, childDurationMs:Float}> = [];
  private static var _phaseDepth:Array<Int> = [0, 0, 0, 0];

  private static var _hasObservedHeap:Bool = false;
  private static var _heapStatsAvailable:Bool = false;
  private static var _rssAvailable:Bool = false;
  private static var _lastObservedHeap:Float = 0.0;
  private static var _frameStartHeap:Float = 0.0;
  private static var _currentHeapUsed:Float = 0.0;
  private static var _currentHeapReserved:Float = 0.0;
  private static var _peakHeapUsed:Float = 0.0;
  private static var _peakHeapReserved:Float = 0.0;
  private static var _lastSampledRss:Float = 0.0;
  private static var _lastSampledPeakRss:Float = 0.0;

  private static var _totalFrames:Int = 0;
  private static var _sumFrameTimeMs:Float = 0.0;
  private static var _sumSqFrameTimeMs:Float = 0.0;
  private static var _minFrameTimeMs:Float = 1e12;
  private static var _maxFrameTimeMs:Float = 0.0;

  private static var _sumUpdateMs:Float = 0.0;
  private static var _maxUpdateMs:Float = 0.0;
  private static var _sumRenderMs:Float = 0.0;
  private static var _maxRenderMs:Float = 0.0;
  private static var _sumAudioMs:Float = 0.0;
  private static var _maxAudioMs:Float = 0.0;
  private static var _sumOtherMs:Float = 0.0;
  private static var _maxOtherMs:Float = 0.0;

  private static var _totalGcCount:Int = 0;
  private static var _totalExplicitGcCount:Int = 0;
  private static var _totalImplicitGcCount:Int = 0;
  private static var _framesWithGc:Int = 0;
  private static var _totalGcPauseMs:Float = 0.0;
  private static var _maxGcPauseMs:Float = 0.0;
  private static var _maxGcPauseFrame:Int = 0;
  private static var _totalGcReclaimedBytes:Float = 0.0;

  private static var _totalAllocBytes:Float = 0.0;
  private static var _totalAllocCount:Int = 0;
  private static var _peakFrameAllocBytes:Float = 0.0;
  private static var _peakFrameAllocFrame:Int = 0;

  private static var _droppedFrames:Int = 0;
  private static var _spike16:Int = 0;
  private static var _spike25:Int = 0;
  private static var _spike33:Int = 0;
  private static var _spike50:Int = 0;
  private static var _totalDrawCalls:Int = 0;
  private static var _maxDrawCalls:Int = 0;

  private static var _samples:Array<FallbackSample> = [];
  private static var _ringWriteIndex:Int = 0;
  private static var _ringCount:Int = 0;
  private static var _activeSample:FallbackSample = null;
  private static var _loadedSample:FallbackSample = null;

  private static var _summaryP50:Float = 0.0;
  private static var _summaryP95:Float = 0.0;
  private static var _summaryP99:Float = 0.0;
  private static var _summaryP999:Float = 0.0;
  private static var _summarySlowest1PctFps:Float = 0.0;
  private static var _summarySlowest01PctFps:Float = 0.0;
  private static var _summaryP95Update:Float = 0.0;
  private static var _summaryP95Render:Float = 0.0;
  private static var _summaryP95Audio:Float = 0.0;

  private static inline function isFiniteFloat(v:Float):Bool
  {
    return !Math.isNaN(v) && Math.isFinite(v);
  }

  private static inline function sanitizeDuration(v:Float):Float
  {
    if (!isFiniteFloat(v) || v < 0.0)
      return 0.0;
    return v > 86400000.0 ? 86400000.0 : v;
  }

  private static function sanitizeSingleLine(s:String):String
  {
    if (s == null || s == "")
      return "UnknownState";
    var buf = new StringBuf();
    for (i in 0...s.length)
    {
      var code = StringTools.fastCodeAt(s, i);
      if (code < 32 || code == 127)
        buf.addChar(32);
      else
        buf.addChar(code);
    }
    return buf.toString();
  }

  public static function escapeCsvField(s:String):String
  {
    if (s == null || s == "")
      return "UnknownState";
    var needsQuotes = false;
    for (i in 0...s.length)
    {
      var c = StringTools.fastCodeAt(s, i);
      if (c == ",".code || c == "\"".code || c == "\r".code || c == "\n".code)
      {
        needsQuotes = true;
        break;
      }
    }
    if (s.length > 0 && (StringTools.fastCodeAt(s, 0) == 32 || StringTools.fastCodeAt(s, s.length - 1) == 32))
      needsQuotes = true;

    if (!needsQuotes)
      return sanitizeSingleLine(s);

    var buf = new StringBuf();
    buf.addChar("\"".code);
    for (i in 0...s.length)
    {
      var c = StringTools.fastCodeAt(s, i);
      if (c == "\"".code)
      {
        buf.add("\"\"");
      }
      else if (c < 32 || c == 127)
      {
        buf.addChar(32);
      }
      else
      {
        buf.addChar(c);
      }
    }
    buf.addChar("\"".code);
    return buf.toString();
  }

  public static function nowMs():Float
  {
    return Timer.stamp() * 1000.0;
  }

  public static function init(targetFps:Float = 60.0):Void
  {
    _initialized = true;
    _enabled = true;
    _collectMemory = true;
    _rssSampleInterval = DEFAULT_RSS_SAMPLE_INTERVAL;
    _targetFps = (isFiniteFloat(targetFps) && targetFps > 0.0) ? targetFps : 60.0;
    reset();
  }

  public static function ensureInit(targetFps:Float = 60.0):Void
  {
    if (!_initialized)
      init(targetFps);
    else if (isFiniteFloat(targetFps) && targetFps > 0.0)
      _targetFps = targetFps;
  }

  public static function isInitialized():Bool
  {
    return _initialized;
  }

  public static function isExportInProgress():Bool
  {
    return _exportInProgress;
  }

  public static function abortInFlightFrame():Void
  {
    if (!_inFlight)
      return;
    _inFlight = false;
    _phaseStack = [];
    _phaseDepth = [0, 0, 0, 0];
    if (_hasObservedHeap)
      _lastObservedHeap = _frameStartHeap;
  }

  public static function reset():Void
  {
    if (!_initialized)
      _initialized = true;
    _inFlight = false;
    _exportInProgress = false;
    _sessionStartMs = nowMs();
    _currentFrameStartMs = 0.0;
    _lastFrameEndMs = 0.0;
    _currentRollingFps = 0.0;
    _rollingWindowMs = 0.0;
    _rollingWindowCount = 0;
    _cachedOverlayFrame = 0;
    _cachedOverlayP95 = 0.0;
    _cachedOverlayP99 = 0.0;
    _phaseStack = [];
    _phaseDepth = [0, 0, 0, 0];
    _hasObservedHeap = false;
    _heapStatsAvailable = false;
    _rssAvailable = false;
    _lastObservedHeap = 0.0;
    _frameStartHeap = 0.0;
    _currentHeapUsed = 0.0;
    _currentHeapReserved = 0.0;
    _peakHeapUsed = 0.0;
    _peakHeapReserved = 0.0;
    _lastSampledRss = 0.0;
    _lastSampledPeakRss = 0.0;
    _totalFrames = 0;
    _sumFrameTimeMs = 0.0;
    _sumSqFrameTimeMs = 0.0;
    _minFrameTimeMs = 1e12;
    _maxFrameTimeMs = 0.0;
    _sumUpdateMs = 0.0;
    _maxUpdateMs = 0.0;
    _sumRenderMs = 0.0;
    _maxRenderMs = 0.0;
    _sumAudioMs = 0.0;
    _maxAudioMs = 0.0;
    _sumOtherMs = 0.0;
    _maxOtherMs = 0.0;
    _totalGcCount = 0;
    _totalExplicitGcCount = 0;
    _totalImplicitGcCount = 0;
    _framesWithGc = 0;
    _totalGcPauseMs = 0.0;
    _maxGcPauseMs = 0.0;
    _maxGcPauseFrame = 0;
    _totalGcReclaimedBytes = 0.0;
    _totalAllocBytes = 0.0;
    _totalAllocCount = 0;
    _peakFrameAllocBytes = 0.0;
    _peakFrameAllocFrame = 0;
    _droppedFrames = 0;
    _spike16 = 0;
    _spike25 = 0;
    _spike33 = 0;
    _spike50 = 0;
    _totalDrawCalls = 0;
    _maxDrawCalls = 0;
    _samples = [];
    _ringWriteIndex = 0;
    _ringCount = 0;
    _activeSample = null;
    _loadedSample = null;
  }

  public static function setEnabled(enabled:Bool):Void
  {
    if (!_initialized)
      init(60.0);
    if (!enabled)
    {
      _enabled = false;
      _inFlight = false;
      _phaseStack = [];
      _phaseDepth = [0, 0, 0, 0];
      _lastFrameEndMs = 0.0;
      _currentFrameStartMs = 0.0;
      _hasObservedHeap = false;
    }
    else if (!_enabled)
    {
      _enabled = true;
      _inFlight = false;
      _phaseStack = [];
      _phaseDepth = [0, 0, 0, 0];
      _lastFrameEndMs = 0.0;
      _currentFrameStartMs = 0.0;
      _hasObservedHeap = false;
    }
  }

  public static function isEnabled():Bool
  {
    return _initialized && _enabled;
  }

  public static function setRssSampleInterval(intervalFrames:Int):Void
  {
    if (!_initialized)
      init(60.0);
    _rssSampleInterval = intervalFrames > 0 ? intervalFrames : 0;
  }

  public static function getRssSampleInterval():Int
  {
    return _rssSampleInterval;
  }

  public static function setCollectMemoryMetrics(enabled:Bool):Void
  {
    if (!_initialized)
      init(60.0);
    _collectMemory = enabled;
    if (!enabled)
      _hasObservedHeap = false;
  }

  public static function getCollectMemoryMetrics():Bool
  {
    return _collectMemory;
  }

  public static function setTargetFps(targetFps:Float):Void
  {
    if (isFiniteFloat(targetFps) && targetFps > 0.0)
      _targetFps = targetFps;
  }

  public static function setStateName(stateName:String):Void
  {
    _currentStateName = sanitizeSingleLine(stateName);
    if (_activeSample != null)
      _activeSample.stateName = _currentStateName;
  }

  private static function observeHeap(heapUsedBytes:Float, isExplicitGcEnd:Bool):Void
  {
    if (!_collectMemory || !isFiniteFloat(heapUsedBytes) || heapUsedBytes < 0.0)
      return;
    _heapStatsAvailable = true;
    _currentHeapUsed = heapUsedBytes;
    if (heapUsedBytes > _peakHeapUsed)
      _peakHeapUsed = heapUsedBytes;
    if (!_hasObservedHeap)
    {
      _lastObservedHeap = heapUsedBytes;
      _hasObservedHeap = true;
      return;
    }
    var delta = heapUsedBytes - _lastObservedHeap;
    _lastObservedHeap = heapUsedBytes;
    if (!_inFlight || _activeSample == null)
      return;
    if (delta > 0.0)
    {
      _activeSample.allocBytes += delta;
      _activeSample.allocCount += 1;
    }
    else if (delta < 0.0)
    {
      _activeSample.gcReclaimedBytes += (-delta);
      if (!isExplicitGcEnd && _phaseDepth[PHASE_GC] <= 0)
      {
        _activeSample.implicitGcCount += 1;
      }
    }
  }

  public static function beginFrame(heapUsedBytes:Float, heapReservedBytes:Float):Void
  {
    if (!_initialized)
      init(60.0);
    if (!_enabled)
      return;
    if (_inFlight)
      abortInFlightFrame();
    var now = nowMs();
    _inFlight = true;
    _currentFrameStartMs = now;
    _phaseStack = [];
    _phaseDepth = [0, 0, 0, 0];
    _activeSample = {
      frameIndex: _totalFrames + 1,
      timestampMs: now >= _sessionStartMs ? (now - _sessionStartMs) : 0.0,
      frameTimeMs: 0.0,
      workTimeMs: 0.0,
      fps: 0.0,
      rollingFps: 0.0,
      updateTimeMs: 0.0,
      renderTimeMs: 0.0,
      audioTimeMs: 0.0,
      gcPauseMs: 0.0,
      otherTimeMs: 0.0,
      updateInclusiveMs: 0.0,
      renderInclusiveMs: 0.0,
      audioInclusiveMs: 0.0,
      gcInclusiveMs: 0.0,
      allocBytes: 0.0,
      allocCount: 0,
      gcReclaimedBytes: 0.0,
      netHeapDeltaBytes: 0.0,
      heapUsedBytes: _currentHeapUsed,
      heapReservedBytes: _currentHeapReserved,
      rssBytes: 0.0,
      peakRssBytes: 0.0,
      gcCount: 0,
      explicitGcCount: 0,
      implicitGcCount: 0,
      drawCalls: 0,
      updateSteps: 0,
      rssSampled: false,
      stateName: _currentStateName
    };
    if (_collectMemory && isFiniteFloat(heapReservedBytes) && heapReservedBytes >= 0.0)
    {
      _currentHeapReserved = heapReservedBytes;
      if (heapReservedBytes > _peakHeapReserved)
        _peakHeapReserved = heapReservedBytes;
    }
    if (_collectMemory && isFiniteFloat(heapUsedBytes) && heapUsedBytes >= 0.0)
    {
      _heapStatsAvailable = true;
      if (!_hasObservedHeap)
      {
        _lastObservedHeap = heapUsedBytes;
        _hasObservedHeap = true;
      }
      _frameStartHeap = _lastObservedHeap;
      observeHeap(heapUsedBytes, false);
    }
    else
    {
      _frameStartHeap = _hasObservedHeap ? _lastObservedHeap : 0.0;
    }
    _activeSample.heapUsedBytes = _currentHeapUsed;
    _activeSample.heapReservedBytes = _currentHeapReserved;
  }

  private static function beginPhase(phase:Int, heapUsedBytes:Float):Void
  {
    if (!_initialized)
      init(60.0);
    if (!_enabled || phase < 0 || phase > 3)
      return;
    if (!_inFlight)
      beginFrame(heapUsedBytes, _currentHeapReserved);
    else if (_collectMemory && heapUsedBytes >= 0.0)
      observeHeap(heapUsedBytes, false);

    if (_phaseDepth[phase] <= 0)
    {
      _phaseDepth[phase] = 1;
      _phaseStack.push({phase: phase, startMs: nowMs(), childDurationMs: 0.0});
      if (phase == PHASE_UPDATE && _activeSample != null)
        _activeSample.updateSteps += 1;
    }
    else
    {
      _phaseDepth[phase] += 1;
    }
  }

  private static function popTopPhaseAt(now:Float, heapUsedBytes:Float):Float
  {
    if (_phaseStack.length <= 0 || _activeSample == null)
      return 0.0;
    var entry = _phaseStack.pop();
    var phase = entry.phase;
    if (phase >= 0 && phase <= 3)
      _phaseDepth[phase] = 0;

    var raw = sanitizeDuration(now - entry.startMs);
    var exclusive = raw - entry.childDurationMs;
    if (exclusive < 0.0)
      exclusive = 0.0;

    if (_collectMemory && heapUsedBytes >= 0.0)
      observeHeap(heapUsedBytes, phase == PHASE_GC);

    if (phase == PHASE_UPDATE)
    {
      _activeSample.updateTimeMs += exclusive;
      _activeSample.updateInclusiveMs += raw;
    }
    else if (phase == PHASE_RENDER)
    {
      _activeSample.renderTimeMs += exclusive;
      _activeSample.renderInclusiveMs += raw;
    }
    else if (phase == PHASE_AUDIO)
    {
      _activeSample.audioTimeMs += exclusive;
      _activeSample.audioInclusiveMs += raw;
    }
    else if (phase == PHASE_GC)
    {
      _activeSample.gcPauseMs += exclusive;
      _activeSample.gcInclusiveMs += raw;
      _activeSample.explicitGcCount += 1;
      _activeSample.gcCount += 1;
    }

    if (_phaseStack.length > 0)
      _phaseStack[_phaseStack.length - 1].childDurationMs += raw;

    return exclusive;
  }

  private static function endPhase(phase:Int, heapUsedBytes:Float):Float
  {
    if (!_initialized || !_enabled || !_inFlight || _activeSample == null)
      return 0.0;
    if (phase < 0 || phase > 3 || _phaseDepth[phase] <= 0)
      return 0.0;
    if (_phaseDepth[phase] > 1)
    {
      _phaseDepth[phase] -= 1;
      return 0.0;
    }

    var targetIdx = -1;
    var i = _phaseStack.length - 1;
    while (i >= 0)
    {
      if (_phaseStack[i].phase == phase)
      {
        targetIdx = i;
        break;
      }
      --i;
    }
    if (targetIdx < 0)
    {
      _phaseDepth[phase] = 0;
      return 0.0;
    }

    var now = nowMs();
    while (_phaseStack.length - 1 > targetIdx)
    {
      popTopPhaseAt(now, -1.0);
    }
    return popTopPhaseAt(now, heapUsedBytes);
  }

  public static function beginUpdate(heapUsedBytes:Float):Void
  {
    beginPhase(PHASE_UPDATE, heapUsedBytes);
  }

  public static function endUpdate(heapUsedBytes:Float):Float
  {
    return endPhase(PHASE_UPDATE, heapUsedBytes);
  }

  public static function beginRender(heapUsedBytes:Float):Void
  {
    beginPhase(PHASE_RENDER, heapUsedBytes);
  }

  public static function endRender(heapUsedBytes:Float):Float
  {
    return endPhase(PHASE_RENDER, heapUsedBytes);
  }

  public static function beginAudio(heapUsedBytes:Float):Void
  {
    beginPhase(PHASE_AUDIO, heapUsedBytes);
  }

  public static function endAudio(heapUsedBytes:Float):Float
  {
    return endPhase(PHASE_AUDIO, heapUsedBytes);
  }

  public static function beginGC(heapUsedBytes:Float):Void
  {
    beginPhase(PHASE_GC, heapUsedBytes);
  }

  public static function endGC(heapUsedBytes:Float):Float
  {
    return endPhase(PHASE_GC, heapUsedBytes);
  }

  public static function recordPhaseMs(phase:Int, durationMs:Float):Void
  {
    var cleanMs = sanitizeDuration(durationMs);
    if (!_initialized || !_enabled || !_inFlight || _activeSample == null || cleanMs <= 0.0)
      return;
    if (phase == PHASE_UPDATE)
    {
      _activeSample.updateTimeMs += cleanMs;
      _activeSample.updateInclusiveMs += cleanMs;
      _activeSample.updateSteps += 1;
    }
    else if (phase == PHASE_RENDER)
    {
      _activeSample.renderTimeMs += cleanMs;
      _activeSample.renderInclusiveMs += cleanMs;
    }
    else if (phase == PHASE_AUDIO)
    {
      _activeSample.audioTimeMs += cleanMs;
      _activeSample.audioInclusiveMs += cleanMs;
    }
    else if (phase == PHASE_GC)
    {
      _activeSample.gcPauseMs += cleanMs;
      _activeSample.gcInclusiveMs += cleanMs;
      _activeSample.gcCount += 1;
      _activeSample.explicitGcCount += 1;
    }
    else
      return;

    if (_phaseStack.length > 0 && _phaseStack[_phaseStack.length - 1].phase != phase)
      _phaseStack[_phaseStack.length - 1].childDurationMs += cleanMs;
  }

  public static function recordAllocation(bytes:Float, count:Int = 1):Void
  {
    if (!_initialized || !_enabled || !_inFlight || _activeSample == null)
      return;
    if (isFiniteFloat(bytes) && bytes > 0.0)
      _activeSample.allocBytes += bytes;
    _activeSample.allocCount += (count > 0 ? count : 1);
  }

  public static function recordGCPause(pauseMs:Float, reclaimedBytes:Float, isExplicit:Bool = true):Void
  {
    var cleanPauseMs = sanitizeDuration(pauseMs);
    if (!_initialized || !_enabled || !_inFlight || _activeSample == null)
      return;
    if (cleanPauseMs > 0.0)
    {
      _activeSample.gcPauseMs += cleanPauseMs;
      _activeSample.gcInclusiveMs += cleanPauseMs;
      if (_phaseStack.length > 0 && _phaseStack[_phaseStack.length - 1].phase != PHASE_GC)
        _phaseStack[_phaseStack.length - 1].childDurationMs += cleanPauseMs;
    }
    if (isFiniteFloat(reclaimedBytes) && reclaimedBytes > 0.0)
      _activeSample.gcReclaimedBytes += reclaimedBytes;
    if (isExplicit)
    {
      _activeSample.explicitGcCount += 1;
      _activeSample.gcCount += 1;
    }
    else
    {
      _activeSample.implicitGcCount += 1;
      if (cleanPauseMs > 0.0)
        _activeSample.gcCount += 1;
    }
  }

  public static function endFrame(
    heapUsedBytes:Float,
    heapReservedBytes:Float,
    drawCalls:Int,
    explicitFrameTimeMs:Float = 0.0):Void
  {
    if (!_initialized || !_enabled)
      return;
    if (!_inFlight)
      beginFrame(heapUsedBytes, heapReservedBytes);
    var now = nowMs();
    while (_phaseStack.length > 0)
    {
      popTopPhaseAt(now, -1.0);
    }
    if (_collectMemory && heapUsedBytes >= 0.0)
      observeHeap(heapUsedBytes, false);
    if (_collectMemory && isFiniteFloat(heapReservedBytes) && heapReservedBytes >= 0.0)
    {
      _currentHeapReserved = heapReservedBytes;
      if (heapReservedBytes > _peakHeapReserved)
        _peakHeapReserved = heapReservedBytes;
    }

    var workMs = sanitizeDuration(now - _currentFrameStartMs);
    var frameMs = workMs;
    if (isFiniteFloat(explicitFrameTimeMs) && explicitFrameTimeMs > 0.0)
    {
      var cleanExp = sanitizeDuration(explicitFrameTimeMs);
      frameMs = cleanExp >= workMs ? cleanExp : workMs;
    }
    else if (_lastFrameEndMs > 0.0 && now >= _lastFrameEndMs)
    {
      var delta = sanitizeDuration(now - _lastFrameEndMs);
      frameMs = (delta >= workMs && delta < 10000.0) ? delta : workMs;
    }
    if (frameMs <= 0.0)
      frameMs = 0.0001;

    _lastFrameEndMs = now;
    _inFlight = false;

    var nextFrameNum = _totalFrames + 1;
    if (_collectMemory && _rssSampleInterval > 0
        && (nextFrameNum == 1 || (nextFrameNum % _rssSampleInterval) == 0))
    {
      var curRss = GetTotalMemory.getCurrentRSS();
      var pkRss = GetTotalMemory.getPeakRSS();
      if (curRss > 0.0 || pkRss > 0.0)
      {
        _rssAvailable = true;
        _lastSampledRss = curRss;
        if (pkRss > _lastSampledPeakRss)
          _lastSampledPeakRss = pkRss;
        if (curRss > _lastSampledPeakRss)
          _lastSampledPeakRss = curRss;
        _activeSample.rssSampled = true;
      }
      else
      {
        _activeSample.rssSampled = false;
      }
    }
    else
    {
      _activeSample.rssSampled = false;
    }

    _activeSample.workTimeMs = workMs;
    _activeSample.frameTimeMs = frameMs;
    _activeSample.fps = 1000.0 / frameMs;
    var accounted = _activeSample.updateTimeMs + _activeSample.renderTimeMs + _activeSample.audioTimeMs + _activeSample.gcPauseMs;
    _activeSample.otherTimeMs = workMs > accounted ? (workMs - accounted) : 0.0;
    _activeSample.heapUsedBytes = _currentHeapUsed;
    _activeSample.heapReservedBytes = _currentHeapReserved;
    _activeSample.netHeapDeltaBytes = _currentHeapUsed - _frameStartHeap;
    _activeSample.rssBytes = _lastSampledRss;
    _activeSample.peakRssBytes = _lastSampledPeakRss;
    _activeSample.drawCalls = drawCalls > 0 ? drawCalls : 0;

    if (_ringCount == RING_CAPACITY && _rollingWindowCount >= RING_CAPACITY)
    {
      var overwrittenFt = _samples[_ringWriteIndex].frameTimeMs;
      _rollingWindowMs = _rollingWindowMs > overwrittenFt ? (_rollingWindowMs - overwrittenFt) : 0.0;
      _rollingWindowCount = RING_CAPACITY - 1;
    }

    if (_samples.length < RING_CAPACITY)
      _samples.push(_activeSample);
    else
      _samples[_ringWriteIndex] = _activeSample;
    _ringWriteIndex = (_ringWriteIndex + 1) % RING_CAPACITY;
    if (_ringCount < RING_CAPACITY)
      _ringCount += 1;

    _rollingWindowMs += frameMs;
    _rollingWindowCount += 1;
    while (_rollingWindowCount > 1)
    {
      var oldestIdx = (_ringWriteIndex + RING_CAPACITY - _rollingWindowCount) % RING_CAPACITY;
      var oldestFt = _samples[oldestIdx].frameTimeMs;
      if ((_rollingWindowMs - oldestFt) >= 1000.0 || _rollingWindowCount > 240)
      {
        _rollingWindowMs -= oldestFt;
        if (_rollingWindowMs < 0.0)
          _rollingWindowMs = 0.0;
        _rollingWindowCount -= 1;
      }
      else
      {
        break;
      }
    }
    _currentRollingFps = _rollingWindowMs > 0.0 ? ((_rollingWindowCount * 1000.0) / _rollingWindowMs) : 0.0;
    _activeSample.rollingFps = _currentRollingFps;

    _totalFrames += 1;
    _sumFrameTimeMs += frameMs;
    _sumSqFrameTimeMs += frameMs * frameMs;
    if (frameMs < _minFrameTimeMs)
      _minFrameTimeMs = frameMs;
    if (frameMs > _maxFrameTimeMs)
      _maxFrameTimeMs = frameMs;

    _sumUpdateMs += _activeSample.updateTimeMs;
    if (_activeSample.updateTimeMs > _maxUpdateMs)
      _maxUpdateMs = _activeSample.updateTimeMs;
    _sumRenderMs += _activeSample.renderTimeMs;
    if (_activeSample.renderTimeMs > _maxRenderMs)
      _maxRenderMs = _activeSample.renderTimeMs;
    _sumAudioMs += _activeSample.audioTimeMs;
    if (_activeSample.audioTimeMs > _maxAudioMs)
      _maxAudioMs = _activeSample.audioTimeMs;
    _sumOtherMs += _activeSample.otherTimeMs;
    if (_activeSample.otherTimeMs > _maxOtherMs)
      _maxOtherMs = _activeSample.otherTimeMs;

    _totalGcCount += _activeSample.gcCount;
    _totalExplicitGcCount += _activeSample.explicitGcCount;
    _totalImplicitGcCount += _activeSample.implicitGcCount;
    if (_activeSample.gcCount > 0 || _activeSample.implicitGcCount > 0 || _activeSample.gcPauseMs > 0.0)
      _framesWithGc += 1;
    _totalGcPauseMs += _activeSample.gcPauseMs;
    if (_activeSample.gcPauseMs > _maxGcPauseMs)
    {
      _maxGcPauseMs = _activeSample.gcPauseMs;
      _maxGcPauseFrame = _activeSample.frameIndex;
    }
    _totalGcReclaimedBytes += _activeSample.gcReclaimedBytes;

    _totalAllocBytes += _activeSample.allocBytes;
    _totalAllocCount += _activeSample.allocCount;
    if (_activeSample.allocBytes > _peakFrameAllocBytes)
    {
      _peakFrameAllocBytes = _activeSample.allocBytes;
      _peakFrameAllocFrame = _activeSample.frameIndex;
    }

    var budget = _targetFps > 0.0 ? (1000.0 / _targetFps) : 16.6667;
    if (frameMs > budget * 1.5)
      _droppedFrames += 1;
    if (frameMs > 16.6667)
      _spike16 += 1;
    if (frameMs > 25.0)
      _spike25 += 1;
    if (frameMs > 33.3333)
      _spike33 += 1;
    if (frameMs > 50.0)
      _spike50 += 1;

    _totalDrawCalls += _activeSample.drawCalls;
    if (_activeSample.drawCalls > _maxDrawCalls)
      _maxDrawCalls = _activeSample.drawCalls;
  }

  public static function loadLastFrame():Bool
  {
    if (_ringCount == 0)
      return false;
    var idx = (_ringWriteIndex + RING_CAPACITY - 1) % RING_CAPACITY;
    _loadedSample = _samples[idx];
    return _loadedSample != null;
  }

  public static function loadBufferedFrame(chronologicalIndex:Int):Bool
  {
    if (chronologicalIndex < 0 || chronologicalIndex >= _ringCount)
      return false;
    var startIdx = _ringCount < RING_CAPACITY ? 0 : _ringWriteIndex;
    var idx = (startIdx + chronologicalIndex) % RING_CAPACITY;
    _loadedSample = _samples[idx];
    return _loadedSample != null;
  }

  public static function getBufferedFrameCount():Int
  {
    return _ringCount;
  }

  public static function lastSampleFrameIndex():Int return _loadedSample != null ? _loadedSample.frameIndex : 0;
  public static function lastSampleTimestampMs():Float return _loadedSample != null ? _loadedSample.timestampMs : 0.0;
  public static function lastSampleFrameTimeMs():Float return _loadedSample != null ? _loadedSample.frameTimeMs : 0.0;
  public static function lastSampleWorkTimeMs():Float return _loadedSample != null ? _loadedSample.workTimeMs : 0.0;
  public static function lastSampleFps():Float return _loadedSample != null ? _loadedSample.fps : 0.0;
  public static function lastSampleRollingFps():Float return _loadedSample != null ? _loadedSample.rollingFps : 0.0;
  public static function lastSampleUpdateTimeMs():Float return _loadedSample != null ? _loadedSample.updateTimeMs : 0.0;
  public static function lastSampleRenderTimeMs():Float return _loadedSample != null ? _loadedSample.renderTimeMs : 0.0;
  public static function lastSampleAudioTimeMs():Float return _loadedSample != null ? _loadedSample.audioTimeMs : 0.0;
  public static function lastSampleGcPauseMs():Float return _loadedSample != null ? _loadedSample.gcPauseMs : 0.0;
  public static function lastSampleOtherTimeMs():Float return _loadedSample != null ? _loadedSample.otherTimeMs : 0.0;
  public static function lastSampleUpdateInclusiveMs():Float return _loadedSample != null ? _loadedSample.updateInclusiveMs : 0.0;
  public static function lastSampleRenderInclusiveMs():Float return _loadedSample != null ? _loadedSample.renderInclusiveMs : 0.0;
  public static function lastSampleAudioInclusiveMs():Float return _loadedSample != null ? _loadedSample.audioInclusiveMs : 0.0;
  public static function lastSampleGcInclusiveMs():Float return _loadedSample != null ? _loadedSample.gcInclusiveMs : 0.0;
  public static function lastSampleAllocBytes():Float return _loadedSample != null ? _loadedSample.allocBytes : 0.0;
  public static function lastSampleAllocCount():Int return _loadedSample != null ? _loadedSample.allocCount : 0;
  public static function lastSampleGcReclaimedBytes():Float return _loadedSample != null ? _loadedSample.gcReclaimedBytes : 0.0;
  public static function lastSampleNetHeapDeltaBytes():Float return _loadedSample != null ? _loadedSample.netHeapDeltaBytes : 0.0;
  public static function lastSampleHeapUsedBytes():Float return _loadedSample != null ? _loadedSample.heapUsedBytes : 0.0;
  public static function lastSampleHeapReservedBytes():Float return _loadedSample != null ? _loadedSample.heapReservedBytes : 0.0;
  public static function lastSampleRssBytes():Float return _loadedSample != null ? _loadedSample.rssBytes : 0.0;
  public static function lastSamplePeakRssBytes():Float return _loadedSample != null ? _loadedSample.peakRssBytes : 0.0;
  public static function lastSampleGcCount():Int return _loadedSample != null ? _loadedSample.gcCount : 0;
  public static function lastSampleExplicitGcCount():Int return _loadedSample != null ? _loadedSample.explicitGcCount : 0;
  public static function lastSampleImplicitGcCount():Int return _loadedSample != null ? _loadedSample.implicitGcCount : 0;
  public static function lastSampleDrawCalls():Int return _loadedSample != null ? _loadedSample.drawCalls : 0;
  public static function lastSampleUpdateSteps():Int return _loadedSample != null ? _loadedSample.updateSteps : 0;
  public static function lastSampleRssSampled():Bool return _loadedSample != null ? _loadedSample.rssSampled : false;
  public static function lastSampleStateName():String return _loadedSample != null ? _loadedSample.stateName : "UnknownState";

  private static function percentile(sorted:Array<Float>, p:Float):Float
  {
    if (sorted.length == 0)
      return 0.0;
    if (sorted.length == 1 || p <= 0.0)
      return sorted[0];
    if (p >= 1.0)
      return sorted[sorted.length - 1];
    var pos = p * (sorted.length - 1);
    var lo = Std.int(Math.floor(pos));
    var hi = lo + 1;
    if (hi >= sorted.length)
      return sorted[sorted.length - 1];
    var w = pos - lo;
    return sorted[lo] * (1.0 - w) + sorted[hi] * w;
  }

  private static function slowestTailMeanFps(sorted:Array<Float>, tailFraction:Float):Float
  {
    if (sorted.length == 0 || tailFraction <= 0.0)
      return 0.0;
    var tailCount = Std.int(Math.ceil(tailFraction * sorted.length));
    if (tailCount < 1)
      tailCount = 1;
    if (tailCount > sorted.length)
      tailCount = sorted.length;
    var sumMs = 0.0;
    for (i in (sorted.length - tailCount)...sorted.length)
    {
      if (sorted[i] > 0.0)
        sumMs += sorted[i];
    }
    var avgMs = sumMs / tailCount;
    return avgMs > 0.0 ? (1000.0 / avgMs) : 0.0;
  }

  public static function refreshSummary():Void
  {
    if (_collectMemory && _lastSampledRss == 0.0 && _lastSampledPeakRss == 0.0)
    {
      var cur = GetTotalMemory.getCurrentRSS();
      var pk = GetTotalMemory.getPeakRSS();
      if (cur > 0.0 || pk > 0.0)
      {
        _rssAvailable = true;
        _lastSampledRss = cur;
        _lastSampledPeakRss = pk > cur ? pk : cur;
      }
    }
    if (_ringCount == 0)
    {
      _summaryP50 = 0.0;
      _summaryP95 = 0.0;
      _summaryP99 = 0.0;
      _summaryP999 = 0.0;
      _summarySlowest1PctFps = 0.0;
      _summarySlowest01PctFps = 0.0;
      _summaryP95Update = 0.0;
      _summaryP95Render = 0.0;
      _summaryP95Audio = 0.0;
      return;
    }
    var ft:Array<Float> = [];
    var ut:Array<Float> = [];
    var rt:Array<Float> = [];
    var at:Array<Float> = [];
    for (i in 0..._ringCount)
    {
      ft.push(_samples[i].frameTimeMs);
      ut.push(_samples[i].updateTimeMs);
      rt.push(_samples[i].renderTimeMs);
      at.push(_samples[i].audioTimeMs);
    }
    ft.sort(Reflect.compare);
    ut.sort(Reflect.compare);
    rt.sort(Reflect.compare);
    at.sort(Reflect.compare);
    _summaryP50 = percentile(ft, 0.50);
    _summaryP95 = percentile(ft, 0.95);
    _summaryP99 = percentile(ft, 0.99);
    _summaryP999 = percentile(ft, 0.999);
    _cachedOverlayFrame = _totalFrames;
    _cachedOverlayP95 = _summaryP95;
    _cachedOverlayP99 = _summaryP99;
    _summarySlowest1PctFps = slowestTailMeanFps(ft, 0.01);
    _summarySlowest01PctFps = slowestTailMeanFps(ft, 0.001);
    _summaryP95Update = percentile(ut, 0.95);
    _summaryP95Render = percentile(rt, 0.95);
    _summaryP95Audio = percentile(at, 0.95);
  }

  public static function summaryTotalFrames():Int return _totalFrames;
  public static function summaryBufferedFrames():Int return _ringCount;
  public static function summarySessionDurationMs():Float return _sumFrameTimeMs;
  public static function summaryTargetFps():Float return _targetFps;
  public static function summaryTargetFrameTimeMs():Float return _targetFps > 0.0 ? (1000.0 / _targetFps) : 16.6667;
  public static function summaryCurrentFps():Float return _currentRollingFps;
  public static function summaryAvgFps():Float return _totalFrames > 0 && _sumFrameTimeMs > 0.0 ? ((_totalFrames * 1000.0) / _sumFrameTimeMs) : 0.0;
  public static function summaryMinFps():Float return _maxFrameTimeMs > 0.0 ? (1000.0 / _maxFrameTimeMs) : 0.0;
  public static function summaryMaxFps():Float return _minFrameTimeMs < 1e11 && _minFrameTimeMs > 0.0 ? (1000.0 / _minFrameTimeMs) : 0.0;
  public static function summaryOnePercentLowFps():Float return _summaryP99 > 0.0 ? (1000.0 / _summaryP99) : 0.0;
  public static function summaryPointOnePercentLowFps():Float return _summaryP999 > 0.0 ? (1000.0 / _summaryP999) : 0.0;
  public static function summarySlowest1PctAvgFps():Float return _summarySlowest1PctFps;
  public static function summarySlowest01PctAvgFps():Float return _summarySlowest01PctFps;
  public static function summaryLastFrameTimeMs():Float return loadLastFrame() ? _loadedSample.frameTimeMs : 0.0;
  public static function summaryAvgFrameTimeMs():Float return _totalFrames > 0 ? (_sumFrameTimeMs / _totalFrames) : 0.0;
  public static function summaryMinFrameTimeMs():Float return _minFrameTimeMs < 1e11 ? _minFrameTimeMs : 0.0;
  public static function summaryMaxFrameTimeMs():Float return _maxFrameTimeMs;
  public static function summaryStdDevFrameTimeMs():Float
  {
    if (_totalFrames <= 0)
      return 0.0;
    var mean = _sumFrameTimeMs / _totalFrames;
    var variance = (_sumSqFrameTimeMs / _totalFrames) - (mean * mean);
    return variance > 0.0 ? Math.sqrt(variance) : 0.0;
  }
  public static function summaryP50FrameTimeMs():Float return _summaryP50;
  public static function summaryP95FrameTimeMs():Float return _summaryP95;
  public static function summaryP99FrameTimeMs():Float return _summaryP99;
  public static function summaryP999FrameTimeMs():Float return _summaryP999;
  public static function summaryAvgUpdateTimeMs():Float return _totalFrames > 0 ? (_sumUpdateMs / _totalFrames) : 0.0;
  public static function summaryMaxUpdateTimeMs():Float return _maxUpdateMs;
  public static function summaryP95UpdateTimeMs():Float return _summaryP95Update;
  public static function summaryAvgRenderTimeMs():Float return _totalFrames > 0 ? (_sumRenderMs / _totalFrames) : 0.0;
  public static function summaryMaxRenderTimeMs():Float return _maxRenderMs;
  public static function summaryP95RenderTimeMs():Float return _summaryP95Render;
  public static function summaryAvgAudioTimeMs():Float return _totalFrames > 0 ? (_sumAudioMs / _totalFrames) : 0.0;
  public static function summaryMaxAudioTimeMs():Float return _maxAudioMs;
  public static function summaryP95AudioTimeMs():Float return _summaryP95Audio;
  public static function summaryAvgOtherTimeMs():Float return _totalFrames > 0 ? (_sumOtherMs / _totalFrames) : 0.0;
  public static function summaryMaxOtherTimeMs():Float return _maxOtherMs;
  public static function summaryTotalGcCount():Int return _totalGcCount;
  public static function summaryTotalExplicitGcCount():Int return _totalExplicitGcCount;
  public static function summaryTotalImplicitGcCount():Int return _totalImplicitGcCount;
  public static function summaryFramesWithGc():Int return _framesWithGc;
  public static function summaryTotalGcPauseMs():Float return _totalGcPauseMs;
  public static function summaryAvgGcPauseMs():Float return _totalGcCount > 0 ? (_totalGcPauseMs / _totalGcCount) : 0.0;
  public static function summaryMaxGcPauseMs():Float return _maxGcPauseMs;
  public static function summaryMaxGcPauseFrame():Int return _maxGcPauseFrame;
  public static function summaryTotalGcReclaimedBytes():Float return _totalGcReclaimedBytes;
  public static function summaryTotalAllocBytes():Float return _totalAllocBytes;
  public static function summaryTotalAllocCount():Int return _totalAllocCount;
  public static function summaryAvgAllocBytesPerFrame():Float return _totalFrames > 0 ? (_totalAllocBytes / _totalFrames) : 0.0;
  public static function summaryAllocRateBytesPerSec():Float return _sumFrameTimeMs > 0.0 ? ((_totalAllocBytes * 1000.0) / _sumFrameTimeMs) : 0.0;
  public static function summaryPeakFrameAllocBytes():Float return _peakFrameAllocBytes;
  public static function summaryPeakFrameAllocFrame():Int return _peakFrameAllocFrame;
  public static function summaryCurrentHeapUsedBytes():Float return _currentHeapUsed;
  public static function summaryCurrentHeapReservedBytes():Float return _currentHeapReserved;
  public static function summaryPeakHeapUsedBytes():Float return _peakHeapUsed;
  public static function summaryPeakHeapReservedBytes():Float return _peakHeapReserved;
  public static function summaryCurrentRssBytes():Float return _collectMemory ? _lastSampledRss : 0.0;
  public static function summaryPeakRssBytes():Float return _collectMemory ? _lastSampledPeakRss : 0.0;
  public static function summaryDroppedFrames():Int return _droppedFrames;
  public static function summarySpikeCount16Ms():Int return _spike16;
  public static function summarySpikeCount25Ms():Int return _spike25;
  public static function summarySpikeCount33Ms():Int return _spike33;
  public static function summarySpikeCount50Ms():Int return _spike50;
  public static function summaryAvgDrawCalls():Float return _totalFrames > 0 ? (_totalDrawCalls / _totalFrames) : 0.0;
  public static function summaryMaxDrawCalls():Int return _maxDrawCalls;
  public static function summaryCpuTimeMs():Float return 0.0;
  public static function summaryCpuUtilizationPct():Float return 0.0;
  public static function summaryCpuNormalizedPct():Float return 0.0;
  public static function summaryLogicalCpuCount():Int return 1;
  public static function summaryCpuTimeAvailable():Bool return false;
  public static function summaryRssAvailable():Bool return _collectMemory && _rssAvailable;
  public static function summaryHeapStatsAvailable():Bool return _collectMemory && _heapStatsAvailable;
  public static function summaryRssSampleIntervalFrames():Int return _rssSampleInterval;

  private static function roundStr(v:Float, decimals:Int = 2):String
  {
    var mult = Math.pow(10, decimals);
    var r = Math.round(v * mult) / mult;
    return Std.string(r);
  }

  public static function formatOverlay():String
  {
    if (_ringCount == 0 || !loadLastFrame())
      return "";
    if (_cachedOverlayFrame == 0
        || _totalFrames < _cachedOverlayFrame
        || (_totalFrames - _cachedOverlayFrame) >= 15)
    {
      var ft:Array<Float> = [];
      for (i in 0..._ringCount)
        ft.push(_samples[i].frameTimeMs);
      ft.sort(Reflect.compare);
      _cachedOverlayP95 = percentile(ft, 0.95);
      _cachedOverlayP99 = percentile(ft, 0.99);
      _cachedOverlayFrame = _totalFrames;
    }
    var p95 = _cachedOverlayP95;
    var p99 = _cachedOverlayP99;
    var low1 = p99 > 0.0 ? (1000.0 / p99) : 0.0;
    var allocKb = _loadedSample.allocBytes / 1024.0;
    return 'Frame: ${roundStr(_loadedSample.frameTimeMs, 2)}ms (P95 ${roundStr(p95, 2)} / P99 ${roundStr(p99, 2)}ms) | 1% Low: ${roundStr(low1, 1)} FPS\n'
      + 'Upd: ${roundStr(_loadedSample.updateTimeMs, 2)}ms | Rnd: ${roundStr(_loadedSample.renderTimeMs, 2)}ms | Aud: ${roundStr(_loadedSample.audioTimeMs, 2)}ms | GC: ${roundStr(_loadedSample.gcPauseMs, 2)}ms (${_totalGcCount})\n'
      + 'Alloc: ${roundStr(allocKb, 1)} KB/f | Draws: ${_loadedSample.drawCalls} | F3 HUD | F6 Export .log';
  }

  public static function resolveLogPath(requestedPath:String):String
  {
    var base = "";
    if (requestedPath != null && requestedPath != "")
    {
      var normalized = StringTools.replace(requestedPath, "\\", "/");
      var parts = normalized.split("/");
      var rawBase = parts.length > 0 ? parts[parts.length - 1] : "";
      var start = 0;
      while (start < rawBase.length)
      {
        var c = StringTools.fastCodeAt(rawBase, start);
        if (c == ".".code || c == " ".code || c == "\t".code)
          start++;
        else
          break;
      }
      var buf = new StringBuf();
      for (i in start...rawBase.length)
      {
        var ch = StringTools.fastCodeAt(rawBase, i);
        if (ch < 32 || ch == 127 || ch == "/".code || ch == "\\".code || ch == ":".code
            || ch == "*".code || ch == "?".code || ch == "\"".code || ch == "<".code
            || ch == ">".code || ch == "|".code)
          buf.addChar("_".code);
        else
          buf.addChar(ch);
      }
      base = StringTools.trim(buf.toString());
      while (StringTools.endsWith(base, "."))
        base = base.substr(0, base.length - 1);
    }

    if (base == "" || base == "log")
    {
      var stamp = DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S");
      base = 'frame_profiler_${stamp}.log';
    }
    else if (!StringTools.endsWith(base, ".log"))
    {
      base += ".log";
    }
    return 'debug/log/${base}';
  }

  public static function exportLog(
    requestedPath:String = "",
    engineVersion:String = "0.3.2",
    platformName:String = "Haxe"):String
  {
    #if sys
    if (!_initialized || _exportInProgress)
      return "";
    _exportInProgress = true;
    var resolved = resolveLogPath(requestedPath);
    var tempPath = '${resolved}.tmp';
    try
    {
      if (!FileSystem.exists("debug"))
        FileSystem.createDirectory("debug");
      if (!FileSystem.exists("debug/log"))
        FileSystem.createDirectory("debug/log");
      var report = debug.FrameProfiler.formatReport(engineVersion, platformName);
      File.saveContent(tempPath, report);
      if (FileSystem.exists(tempPath) && !FileSystem.isDirectory(tempPath))
      {
        if (FileSystem.exists(resolved))
          FileSystem.deleteFile(resolved);
        FileSystem.rename(tempPath, resolved);
        _exportInProgress = false;
        if (FileSystem.exists(resolved) && !FileSystem.isDirectory(resolved))
          return resolved;
      }
    }
    catch (_:Dynamic)
    {
      try
      {
        if (FileSystem.exists(tempPath))
          FileSystem.deleteFile(tempPath);
      }
      catch (_:Dynamic) {}
    }
    _exportInProgress = false;
    return "";
    #else
    return "";
    #end
  }
  #end
}

#if !cpp
private typedef FallbackSample =
{
  var frameIndex:Int;
  var timestampMs:Float;
  var frameTimeMs:Float;
  var workTimeMs:Float;
  var fps:Float;
  var rollingFps:Float;
  var updateTimeMs:Float;
  var renderTimeMs:Float;
  var audioTimeMs:Float;
  var gcPauseMs:Float;
  var otherTimeMs:Float;
  var updateInclusiveMs:Float;
  var renderInclusiveMs:Float;
  var audioInclusiveMs:Float;
  var gcInclusiveMs:Float;
  var allocBytes:Float;
  var allocCount:Int;
  var gcReclaimedBytes:Float;
  var netHeapDeltaBytes:Float;
  var heapUsedBytes:Float;
  var heapReservedBytes:Float;
  var rssBytes:Float;
  var peakRssBytes:Float;
  var gcCount:Int;
  var explicitGcCount:Int;
  var implicitGcCount:Int;
  var drawCalls:Int;
  var updateSteps:Int;
  var rssSampled:Bool;
  var stateName:String;
};
#end
