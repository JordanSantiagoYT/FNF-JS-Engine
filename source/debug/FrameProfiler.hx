package debug;

import Date;
import DateTools;
import Type;
import backend.ClientPrefs;
#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end
import debug.profiler.NativeFrameProfiler;
import flixel.FlxG;
import lime.app.Application;
#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif neko
import neko.vm.Gc;
#end
#if sys
import Sys;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Per-frame sample snapshot captured by the Phoenix Engine frame profiler.
 *
 * Units & Semantics:
 * - All durations are in milliseconds.
 * - Exclusive durations (`updateTimeMs`, `renderTimeMs`, `audioTimeMs`, `gcPauseMs`):
 *   Nested child phase durations are subtracted from their enclosing parent phase
 *   via an explicit LIFO phase stack (`phaseStack`).
 * - Inclusive durations (`updateInclusiveMs`, `renderInclusiveMs`,
 *   `audioInclusiveMs`, `gcInclusiveMs`): Total time spent inside the outermost
 *   activation(s) of each phase, including nested child phases.
 * - `gcPauseMs` and `gcCount`/`explicitGcCount` reflect directly measured GC pauses.
 * - `implicitGcCount` counts observed negative heap-delta intervals outside explicit
 *   GC scopes (heuristic indicator of uninstrumented collection, not an exact cycle count).
 * - `rssSampled` is `true` when process RSS was freshly sampled on this frame and
 *   `false` when carried forward from the previous periodic RSS sample.
 */
typedef FrameSample =
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

/**
 * Aggregated statistical summary across the profiling session and ring buffer.
 *
 * Percentile & Low-FPS Semantics:
 * - Percentiles (`p50`, `p95`, `p99`, `p999`) use Hyndman-Fan Type 7 linear
 *   interpolation (`pos = q * (N - 1)`) over the ring buffer (up to 2,048 frames).
 * - `onePercentLowFps` = `1000.0 / p99FrameTimeMs` (reciprocal of P99 frametime).
 * - `pointOnePercentLowFps` = `1000.0 / p999FrameTimeMs` (reciprocal of P99.9 frametime).
 * - `slowest1PctAvgFps` and `slowest01PctAvgFps` = harmonic mean FPS of the slowest
 *   `ceil(0.01 * N)` and `ceil(0.001 * N)` buffered frames.
 * - `cpuTimeAvailable`, `rssAvailable`, `heapStatsAvailable` explicitly indicate
 *   whether the underlying platform/runtime metrics are available.
 */
typedef FrameProfileSummary =
{
  var totalFrames:Int;
  var bufferedFrames:Int;
  var sessionDurationMs:Float;
  var targetFps:Float;
  var targetFrameTimeMs:Float;

  var currentFps:Float;
  var avgFps:Float;
  var minFps:Float;
  var maxFps:Float;
  var onePercentLowFps:Float;
  var pointOnePercentLowFps:Float;
  var slowest1PctAvgFps:Float;
  var slowest01PctAvgFps:Float;

  var lastFrameTimeMs:Float;
  var avgFrameTimeMs:Float;
  var minFrameTimeMs:Float;
  var maxFrameTimeMs:Float;
  var stdDevFrameTimeMs:Float;
  var p50FrameTimeMs:Float;
  var p95FrameTimeMs:Float;
  var p99FrameTimeMs:Float;
  var p999FrameTimeMs:Float;

  var avgUpdateTimeMs:Float;
  var maxUpdateTimeMs:Float;
  var p95UpdateTimeMs:Float;

  var avgRenderTimeMs:Float;
  var maxRenderTimeMs:Float;
  var p95RenderTimeMs:Float;

  var avgAudioTimeMs:Float;
  var maxAudioTimeMs:Float;
  var p95AudioTimeMs:Float;

  var avgOtherTimeMs:Float;
  var maxOtherTimeMs:Float;

  var totalGcCount:Int;
  var totalExplicitGcCount:Int;
  var totalImplicitGcCount:Int;
  var framesWithGc:Int;
  var totalGcPauseMs:Float;
  var avgGcPauseMs:Float;
  var maxGcPauseMs:Float;
  var maxGcPauseFrame:Int;
  var totalGcReclaimedBytes:Float;

  var totalAllocBytes:Float;
  var totalAllocCount:Int;
  var avgAllocBytesPerFrame:Float;
  var allocRateBytesPerSec:Float;
  var peakFrameAllocBytes:Float;
  var peakFrameAllocFrame:Int;
  var currentHeapUsedBytes:Float;
  var currentHeapReservedBytes:Float;
  var peakHeapUsedBytes:Float;
  var peakHeapReservedBytes:Float;
  var currentRssBytes:Float;
  var peakRssBytes:Float;

  var droppedFrames:Int;
  var spikeCount16Ms:Int;
  var spikeCount25Ms:Int;
  var spikeCount33Ms:Int;
  var spikeCount50Ms:Int;
  var avgDrawCalls:Float;
  var maxDrawCalls:Int;

  var cpuTimeMs:Float;
  var cpuUtilizationPct:Float;
  var cpuNormalizedPct:Float;
  var logicalCpuCount:Int;
  var cpuTimeAvailable:Bool;
  var rssAvailable:Bool;
  var heapStatsAvailable:Bool;
  var rssSampleIntervalFrames:Int;
};

/**
 * Full-engine Haxe + C/C++ Frame Profiler for FNF-Phoenix-Engine.
 *
 * Manages five independent lifecycle states:
 * 1. Initialization (`FrameProfiler.initialized`):
 *    Set by `FrameProfiler.init()`. Repeated calls to `init(targetFps)` without
 *    `forceReset = true` update `targetFps` idempotently without clearing
 *    collected history or registering duplicate shutdown hooks.
 * 2. Metric Recording (`FrameProfiler.enabled`, `startRecording()`, `stopRecording()`):
 *    Enabled by default on `init()` so background ring-buffer history is ready
 *    when the user opens the overlay (`F3`) or exports a report (`F6`).
 *    Calling `stopRecording()` (`enabled = false`) stops all sampling and resets
 *    inter-frame baselines; `startRecording()` (`enabled = true`) resumes
 *    recording while preserving previously recorded session totals.
 * 3. Overlay Visibility (`FrameProfiler.overlayVisible` / `ClientPrefs.frameProfiler`):
 *    Hidden by default (`false`). Toggling the HUD overlay (`F3`, `showOverlay()`,
 *    `hideOverlay()`, `toggleOverlay()`) never stops recording, never resets
 *    recorded samples, and never re-initializes the profiler.
 * 4. Automatic Exit Export (`FrameProfiler.autoExportOnExit`):
 *    Disabled by default (`false`), enabled via `--profile` / `-profile` /
 *    `--frame-profiler` CLI flags, `-DPROFILE_FRAMES`, or setting
 *    `FrameProfiler.autoExportOnExit = true`. Completely independent of
 *    `overlayVisible`.
 * 5. Export In Progress (`FrameProfiler.exportInProgress`):
 *    True while a `.log` report is actively being written and finalized,
 *    preventing re-entrant export calls.
 */
class FrameProfiler
{
  public static inline var LOG_DIR:String = "debug/log";

  /**
   * Whether `FrameProfiler.init()` has been called.
   */
  public static var initialized(default, null):Bool = false;

  /**
   * Whether metric recording is currently active.
   */
  public static var enabled(get, set):Bool;

  /**
   * Whether the live HUD profiler overlay is visible (`ClientPrefs.frameProfiler`).
   */
  public static var overlayVisible(get, set):Bool;

  /**
   * Whether a `.log` export is currently in progress.
   */
  public static var exportInProgress(get, never):Bool;

  /**
   * Process RSS sampling interval in frames (`0` = on-demand only, `1` = every frame,
   * default `60` = once per ~1 second at 60 FPS).
   */
  public static var rssSampleIntervalFrames(get, set):Int;

  /**
   * Whether managed heap and process RSS metrics are collected (`true` = full
   * profiling, `false` = timing-only mode).
   */
  public static var collectMemoryMetrics(get, set):Bool;

  /**
   * Whether a `.log` report should be exported automatically on application exit.
   * Independent of `overlayVisible` (`ClientPrefs.frameProfiler`).
   */
  public static var autoExportOnExit:Bool = false;

  /**
   * Path of the most recent `.log` file successfully written to `debug/log/`.
   */
  public static var lastExportedLogPath(default, null):String = "";

  private static var _recordingEnabled:Bool = false;
  private static var _collectMemory:Bool = true;
  private static var _exitHookRegistered:Bool = false;
  private static var _exitExportCompleted:Bool = false;
  private static var _currentStateName:String = "InitialState";
  private static var _lastStateInstance:Dynamic = null;

  /**
   * Initializes the frame profiler.
   * If already initialized and `forceReset` is `false`, updates `targetFps`
   * idempotently without wiping recorded frames or registering duplicate hooks.
   */
  public static function init(targetFps:Float = 60.0, forceReset:Bool = false):Void
  {
    if (!initialized || forceReset)
    {
      NativeFrameProfiler.init(targetFps);
      initialized = true;
      _recordingEnabled = true;
      _collectMemory = NativeFrameProfiler.getCollectMemoryMetrics();
      _exitExportCompleted = false;
      _lastStateInstance = null;
    }
    else
    {
      NativeFrameProfiler.ensureInit(targetFps);
    }

    #if sys
    try
    {
      for (arg in Sys.args())
      {
        if (arg == "--profile" || arg == "-profile" || arg == "--frame-profiler")
        {
          autoExportOnExit = true;
          ClientPrefs.frameProfiler = true;
        }
      }
    }
    catch (_:Dynamic) {}
    #end

    #if PROFILE_FRAMES
    autoExportOnExit = true;
    #end
  }

  /**
   * Registers the application exit callback at most once across the process lifetime.
   */
  public static function registerExitHook():Void
  {
    if (_exitHookRegistered)
      return;
    #if !flash
    try
    {
      if (Application.current != null && Application.current.onExit != null)
      {
        _exitHookRegistered = true;
        Application.current.onExit.add(function(_:Int) {
          handleApplicationExit();
        });
      }
    }
    catch (_:Dynamic) {}
    #end
  }

  public static inline function ensureInitialized():Void
  {
    if (!initialized)
    {
      var fps:Float = (FlxG.drawFramerate > 0) ? FlxG.drawFramerate : 60.0;
      init(fps, false);
    }
  }

  /**
   * Clears all recorded frame samples and resets cumulative session statistics.
   */
  public static function reset():Void
  {
    ensureInitialized();
    NativeFrameProfiler.reset();
    _exitExportCompleted = false;
    _lastStateInstance = null;
  }

  /**
   * Explicitly enables frame/phase metric recording.
   */
  public static function startRecording():Void
  {
    enabled = true;
  }

  /**
   * Explicitly disables frame/phase metric recording without clearing history.
   */
  public static function stopRecording():Void
  {
    enabled = false;
  }

  private static function get_enabled():Bool
  {
    return initialized && _recordingEnabled;
  }

  private static function set_enabled(value:Bool):Bool
  {
    ensureInitialized();
    _recordingEnabled = value;
    NativeFrameProfiler.setEnabled(value);
    return value;
  }

  private static function get_overlayVisible():Bool
  {
    return ClientPrefs.frameProfiler;
  }

  private static function set_overlayVisible(value:Bool):Bool
  {
    ClientPrefs.frameProfiler = value;
    return value;
  }

  private static function get_exportInProgress():Bool
  {
    return initialized && NativeFrameProfiler.isExportInProgress();
  }

  /**
   * Shows the live profiler HUD overlay without resetting or altering recording state.
   */
  public static function showOverlay():Void
  {
    overlayVisible = true;
    awardFirstUseAchievement();
  }

  /**
   * Hides the live profiler HUD overlay without stopping recording or resetting history.
   */
  public static function hideOverlay():Void
  {
    overlayVisible = false;
  }

  /**
   * Toggles the on-screen profiler overlay (`F3`) without resetting or corrupting
   * recorded frame samples or re-initializing the profiler.
   */
  public static function toggleOverlay():Bool
  {
    overlayVisible = !overlayVisible;
    if (overlayVisible)
      awardFirstUseAchievement();
    return overlayVisible;
  }

  /** Awards the badge only when the player actively opens the profiler. */
  private static function awardFirstUseAchievement():Void
  {
    #if ACHIEVEMENTS_ALLOWED
    if (!Achievements.isUnlocked("mr_robot") && Achievements.exists("mr_robot"))
      Achievements.unlock("mr_robot");
    #end
  }

  private static function get_rssSampleIntervalFrames():Int
  {
    ensureInitialized();
    return NativeFrameProfiler.getRssSampleInterval();
  }

  private static function set_rssSampleIntervalFrames(intervalFrames:Int):Int
  {
    ensureInitialized();
    final sanitized = intervalFrames > 0 ? intervalFrames : 0;
    NativeFrameProfiler.setRssSampleInterval(sanitized);
    return sanitized;
  }

  private static function get_collectMemoryMetrics():Bool
  {
    ensureInitialized();
    return _collectMemory;
  }

  private static function set_collectMemoryMetrics(value:Bool):Bool
  {
    ensureInitialized();
    _collectMemory = value;
    NativeFrameProfiler.setCollectMemoryMetrics(value);
    return value;
  }

  public static function setTargetFps(targetFps:Float):Void
  {
    ensureInitialized();
    NativeFrameProfiler.setTargetFps(targetFps);
  }

  public static function setStateName(stateName:String):Void
  {
    ensureInitialized();
    if (stateName != null && stateName != "" && stateName != _currentStateName)
    {
      _currentStateName = stateName;
      NativeFrameProfiler.setStateName(stateName);
    }
  }

  /**
   * Queries current managed heap usage in bytes from the runtime GC, or `-1.0`
   * when memory collection is disabled or unavailable on the target runtime.
   */
  public static inline function queryHeapUsedBytes():Float
  {
    if (!_collectMemory)
      return -1.0;
    #if cpp
    return Gc.memInfo64(Gc.MEM_INFO_USAGE);
    #elseif hl
    var stats = Gc.stats();
    return stats != null ? stats.currentMemory : -1.0;
    #else
    return -1.0;
    #end
  }

  /**
   * Queries reserved managed heap memory in bytes from the runtime GC, or `-1.0`
   * when memory collection is disabled or unavailable on the target runtime.
   */
  public static inline function queryHeapReservedBytes():Float
  {
    if (!_collectMemory)
      return -1.0;
    #if cpp
    return Gc.memInfo64(Gc.MEM_INFO_RESERVED);
    #elseif hl
    var stats = Gc.stats();
    return stats != null ? stats.totalAllocated : -1.0;
    #else
    return -1.0;
    #end
  }

  /**
   * Marks the start of a new frame.
   */
  public static inline function beginFrame():Void
  {
    if (!initialized || !_recordingEnabled)
      return;

    if (FlxG.state != null && FlxG.state != _lastStateInstance)
    {
      _lastStateInstance = FlxG.state;
      final cls = Type.getClass(FlxG.state);
      if (cls != null)
        setStateName(Type.getClassName(cls));
    }

    NativeFrameProfiler.beginFrame(queryHeapUsedBytes(), queryHeapReservedBytes());
  }

  /**
   * Marks the completion of the current frame.
   */
  public static inline function endFrame(drawCalls:Int = 0, frameTimeMs:Float = 0.0):Void
  {
    if (!initialized || !_recordingEnabled)
      return;

    NativeFrameProfiler.endFrame(
      queryHeapUsedBytes(),
      queryHeapReservedBytes(),
      drawCalls,
      frameTimeMs);
  }

  /**
   * Marks the start of the gameplay/state update phase.
   */
  public static inline function beginUpdate():Void
  {
    if (!initialized || !_recordingEnabled)
      return;
    NativeFrameProfiler.beginUpdate(queryHeapUsedBytes());
  }

  /**
   * Marks the end of the gameplay/state update phase.
   */
  public static inline function endUpdate():Float
  {
    if (!initialized || !_recordingEnabled)
      return 0.0;
    return NativeFrameProfiler.endUpdate(queryHeapUsedBytes());
  }

  /**
   * Marks the start of the rendering phase.
   */
  public static inline function beginRender():Void
  {
    if (!initialized || !_recordingEnabled)
      return;
    NativeFrameProfiler.beginRender(queryHeapUsedBytes());
  }

  /**
   * Marks the end of the rendering phase.
   */
  public static inline function endRender():Float
  {
    if (!initialized || !_recordingEnabled)
      return 0.0;
    return NativeFrameProfiler.endRender(queryHeapUsedBytes());
  }

  /**
   * Marks the start of the audio processing/synchronization phase.
   */
  public static inline function beginAudio():Void
  {
    if (!initialized || !_recordingEnabled)
      return;
    NativeFrameProfiler.beginAudio(queryHeapUsedBytes());
  }

  /**
   * Marks the end of the audio processing/synchronization phase.
   */
  public static inline function endAudio():Float
  {
    if (!initialized || !_recordingEnabled)
      return 0.0;
    return NativeFrameProfiler.endAudio(queryHeapUsedBytes());
  }

  /**
   * Marks the start of an explicit synchronous garbage collection cycle.
   * No-op on targets that do not expose synchronous GC (`!cpp && !hl && !neko`).
   */
  public static inline function beginGC(major:Bool = true):Void
  {
    #if (cpp || hl || neko)
    if (!initialized || !_recordingEnabled)
      return;
    NativeFrameProfiler.beginGC(queryHeapUsedBytes());
    #end
  }

  /**
   * Marks the end of an explicit synchronous garbage collection cycle.
   */
  public static inline function endGC():Float
  {
    #if (cpp || hl || neko)
    if (!initialized || !_recordingEnabled)
      return 0.0;
    return NativeFrameProfiler.endGC(queryHeapUsedBytes());
    #else
    return 0.0;
    #end
  }

  /**
   * Manually records a subsystem phase duration in milliseconds.
   */
  public static inline function recordPhaseMs(phase:Int, durationMs:Float):Void
  {
    if (!initialized || !_recordingEnabled)
      return;
    NativeFrameProfiler.recordPhaseMs(phase, durationMs);
  }

  /**
   * Manually records an allocation event (`bytes` and `count`).
   */
  public static inline function recordAllocation(bytes:Float, count:Int = 1):Void
  {
    if (!initialized || !_recordingEnabled)
      return;
    NativeFrameProfiler.recordAllocation(bytes, count);
  }

  /**
   * Manually records a garbage collection pause (`pauseMs`, `reclaimedBytes`, `isExplicit`).
   */
  public static inline function recordGCPause(pauseMs:Float, reclaimedBytes:Float = 0.0, isExplicit:Bool = true):Void
  {
    if (!initialized || !_recordingEnabled)
      return;
    NativeFrameProfiler.recordGCPause(pauseMs, reclaimedBytes, isExplicit);
  }

  /**
   * Returns a snapshot of the most recently completed frame, or `null` if no
   * frames have been recorded yet.
   */
  public static function getLastFrame():Null<FrameSample>
  {
    ensureInitialized();
    if (!NativeFrameProfiler.loadLastFrame())
      return null;
    return readLoadedSample();
  }

  /**
   * Returns a snapshot of the buffered frame at `chronologicalIndex`
   * (`0` = oldest frame in ring buffer, `getBufferedFrameCount() - 1` = newest).
   */
  public static function getBufferedFrame(chronologicalIndex:Int):Null<FrameSample>
  {
    ensureInitialized();
    if (!NativeFrameProfiler.loadBufferedFrame(chronologicalIndex))
      return null;
    return readLoadedSample();
  }

  public static function getBufferedFrameCount():Int
  {
    ensureInitialized();
    return NativeFrameProfiler.getBufferedFrameCount();
  }

  private static function readLoadedSample():FrameSample
  {
    return {
      frameIndex: NativeFrameProfiler.lastSampleFrameIndex(),
      timestampMs: NativeFrameProfiler.lastSampleTimestampMs(),
      frameTimeMs: NativeFrameProfiler.lastSampleFrameTimeMs(),
      workTimeMs: NativeFrameProfiler.lastSampleWorkTimeMs(),
      fps: NativeFrameProfiler.lastSampleFps(),
      rollingFps: NativeFrameProfiler.lastSampleRollingFps(),
      updateTimeMs: NativeFrameProfiler.lastSampleUpdateTimeMs(),
      renderTimeMs: NativeFrameProfiler.lastSampleRenderTimeMs(),
      audioTimeMs: NativeFrameProfiler.lastSampleAudioTimeMs(),
      gcPauseMs: NativeFrameProfiler.lastSampleGcPauseMs(),
      otherTimeMs: NativeFrameProfiler.lastSampleOtherTimeMs(),
      updateInclusiveMs: NativeFrameProfiler.lastSampleUpdateInclusiveMs(),
      renderInclusiveMs: NativeFrameProfiler.lastSampleRenderInclusiveMs(),
      audioInclusiveMs: NativeFrameProfiler.lastSampleAudioInclusiveMs(),
      gcInclusiveMs: NativeFrameProfiler.lastSampleGcInclusiveMs(),
      allocBytes: NativeFrameProfiler.lastSampleAllocBytes(),
      allocCount: NativeFrameProfiler.lastSampleAllocCount(),
      gcReclaimedBytes: NativeFrameProfiler.lastSampleGcReclaimedBytes(),
      netHeapDeltaBytes: NativeFrameProfiler.lastSampleNetHeapDeltaBytes(),
      heapUsedBytes: NativeFrameProfiler.lastSampleHeapUsedBytes(),
      heapReservedBytes: NativeFrameProfiler.lastSampleHeapReservedBytes(),
      rssBytes: NativeFrameProfiler.lastSampleRssBytes(),
      peakRssBytes: NativeFrameProfiler.lastSamplePeakRssBytes(),
      gcCount: NativeFrameProfiler.lastSampleGcCount(),
      explicitGcCount: NativeFrameProfiler.lastSampleExplicitGcCount(),
      implicitGcCount: NativeFrameProfiler.lastSampleImplicitGcCount(),
      drawCalls: NativeFrameProfiler.lastSampleDrawCalls(),
      updateSteps: NativeFrameProfiler.lastSampleUpdateSteps(),
      rssSampled: NativeFrameProfiler.lastSampleRssSampled(),
      stateName: NativeFrameProfiler.lastSampleStateName()
    };
  }

  /**
   * Computes and returns the full statistical summary across the current session.
   */
  public static function getSummary():FrameProfileSummary
  {
    ensureInitialized();
    NativeFrameProfiler.refreshSummary();
    return {
      totalFrames: NativeFrameProfiler.summaryTotalFrames(),
      bufferedFrames: NativeFrameProfiler.summaryBufferedFrames(),
      sessionDurationMs: NativeFrameProfiler.summarySessionDurationMs(),
      targetFps: NativeFrameProfiler.summaryTargetFps(),
      targetFrameTimeMs: NativeFrameProfiler.summaryTargetFrameTimeMs(),
      currentFps: NativeFrameProfiler.summaryCurrentFps(),
      avgFps: NativeFrameProfiler.summaryAvgFps(),
      minFps: NativeFrameProfiler.summaryMinFps(),
      maxFps: NativeFrameProfiler.summaryMaxFps(),
      onePercentLowFps: NativeFrameProfiler.summaryOnePercentLowFps(),
      pointOnePercentLowFps: NativeFrameProfiler.summaryPointOnePercentLowFps(),
      slowest1PctAvgFps: NativeFrameProfiler.summarySlowest1PctAvgFps(),
      slowest01PctAvgFps: NativeFrameProfiler.summarySlowest01PctAvgFps(),
      lastFrameTimeMs: NativeFrameProfiler.summaryLastFrameTimeMs(),
      avgFrameTimeMs: NativeFrameProfiler.summaryAvgFrameTimeMs(),
      minFrameTimeMs: NativeFrameProfiler.summaryMinFrameTimeMs(),
      maxFrameTimeMs: NativeFrameProfiler.summaryMaxFrameTimeMs(),
      stdDevFrameTimeMs: NativeFrameProfiler.summaryStdDevFrameTimeMs(),
      p50FrameTimeMs: NativeFrameProfiler.summaryP50FrameTimeMs(),
      p95FrameTimeMs: NativeFrameProfiler.summaryP95FrameTimeMs(),
      p99FrameTimeMs: NativeFrameProfiler.summaryP99FrameTimeMs(),
      p999FrameTimeMs: NativeFrameProfiler.summaryP999FrameTimeMs(),
      avgUpdateTimeMs: NativeFrameProfiler.summaryAvgUpdateTimeMs(),
      maxUpdateTimeMs: NativeFrameProfiler.summaryMaxUpdateTimeMs(),
      p95UpdateTimeMs: NativeFrameProfiler.summaryP95UpdateTimeMs(),
      avgRenderTimeMs: NativeFrameProfiler.summaryAvgRenderTimeMs(),
      maxRenderTimeMs: NativeFrameProfiler.summaryMaxRenderTimeMs(),
      p95RenderTimeMs: NativeFrameProfiler.summaryP95RenderTimeMs(),
      avgAudioTimeMs: NativeFrameProfiler.summaryAvgAudioTimeMs(),
      maxAudioTimeMs: NativeFrameProfiler.summaryMaxAudioTimeMs(),
      p95AudioTimeMs: NativeFrameProfiler.summaryP95AudioTimeMs(),
      avgOtherTimeMs: NativeFrameProfiler.summaryAvgOtherTimeMs(),
      maxOtherTimeMs: NativeFrameProfiler.summaryMaxOtherTimeMs(),
      totalGcCount: NativeFrameProfiler.summaryTotalGcCount(),
      totalExplicitGcCount: NativeFrameProfiler.summaryTotalExplicitGcCount(),
      totalImplicitGcCount: NativeFrameProfiler.summaryTotalImplicitGcCount(),
      framesWithGc: NativeFrameProfiler.summaryFramesWithGc(),
      totalGcPauseMs: NativeFrameProfiler.summaryTotalGcPauseMs(),
      avgGcPauseMs: NativeFrameProfiler.summaryAvgGcPauseMs(),
      maxGcPauseMs: NativeFrameProfiler.summaryMaxGcPauseMs(),
      maxGcPauseFrame: NativeFrameProfiler.summaryMaxGcPauseFrame(),
      totalGcReclaimedBytes: NativeFrameProfiler.summaryTotalGcReclaimedBytes(),
      totalAllocBytes: NativeFrameProfiler.summaryTotalAllocBytes(),
      totalAllocCount: NativeFrameProfiler.summaryTotalAllocCount(),
      avgAllocBytesPerFrame: NativeFrameProfiler.summaryAvgAllocBytesPerFrame(),
      allocRateBytesPerSec: NativeFrameProfiler.summaryAllocRateBytesPerSec(),
      peakFrameAllocBytes: NativeFrameProfiler.summaryPeakFrameAllocBytes(),
      peakFrameAllocFrame: NativeFrameProfiler.summaryPeakFrameAllocFrame(),
      currentHeapUsedBytes: NativeFrameProfiler.summaryCurrentHeapUsedBytes(),
      currentHeapReservedBytes: NativeFrameProfiler.summaryCurrentHeapReservedBytes(),
      peakHeapUsedBytes: NativeFrameProfiler.summaryPeakHeapUsedBytes(),
      peakHeapReservedBytes: NativeFrameProfiler.summaryPeakHeapReservedBytes(),
      currentRssBytes: NativeFrameProfiler.summaryCurrentRssBytes(),
      peakRssBytes: NativeFrameProfiler.summaryPeakRssBytes(),
      droppedFrames: NativeFrameProfiler.summaryDroppedFrames(),
      spikeCount16Ms: NativeFrameProfiler.summarySpikeCount16Ms(),
      spikeCount25Ms: NativeFrameProfiler.summarySpikeCount25Ms(),
      spikeCount33Ms: NativeFrameProfiler.summarySpikeCount33Ms(),
      spikeCount50Ms: NativeFrameProfiler.summarySpikeCount50Ms(),
      avgDrawCalls: NativeFrameProfiler.summaryAvgDrawCalls(),
      maxDrawCalls: NativeFrameProfiler.summaryMaxDrawCalls(),
      cpuTimeMs: NativeFrameProfiler.summaryCpuTimeMs(),
      cpuUtilizationPct: NativeFrameProfiler.summaryCpuUtilizationPct(),
      cpuNormalizedPct: NativeFrameProfiler.summaryCpuNormalizedPct(),
      logicalCpuCount: NativeFrameProfiler.summaryLogicalCpuCount(),
      cpuTimeAvailable: NativeFrameProfiler.summaryCpuTimeAvailable(),
      rssAvailable: NativeFrameProfiler.summaryRssAvailable(),
      heapStatsAvailable: NativeFrameProfiler.summaryHeapStatsAvailable(),
      rssSampleIntervalFrames: NativeFrameProfiler.summaryRssSampleIntervalFrames()
    };
  }

  private static inline function roundDec(val:Float, decimals:Int = 2):Float
  {
    var mult = Math.pow(10, decimals);
    return Math.round(val * mult) / mult;
  }

  /**
   * Formats a compact HUD string suitable for `FPSCounter` without allocating
   * full `FrameSample` / `FrameProfileSummary` structures.
   */
  public static function getOverlayText():String
  {
    if (!initialized)
      return "";
    return NativeFrameProfiler.formatOverlay();
  }

  /**
   * Escapes a string field according to RFC 4180 CSV rules (normalizing raw
   * control chars to spaces and quoting fields containing `,`, `"`, `\r`, `\n`,
   * or leading/trailing spaces).
   */
  public static function escapeCsvField(value:String):String
  {
    if (value == null || value == "")
      return "UnknownState";
    var needsQuotes = false;
    for (i in 0...value.length)
    {
      var ch = StringTools.fastCodeAt(value, i);
      if (ch == ",".code || ch == "\"".code || ch == "\r".code || ch == "\n".code)
      {
        needsQuotes = true;
        break;
      }
    }
    if (value.length > 0 && (StringTools.fastCodeAt(value, 0) == 32 || StringTools.fastCodeAt(value, value.length - 1) == 32))
      needsQuotes = true;

    if (!needsQuotes)
    {
      var clean = new StringBuf();
      for (i in 0...value.length)
      {
        var ch = StringTools.fastCodeAt(value, i);
        clean.addChar((ch < 32 || ch == 127) ? 32 : ch);
      }
      return clean.toString();
    }

    var buf = new StringBuf();
    buf.addChar("\"".code);
    for (i in 0...value.length)
    {
      var ch = StringTools.fastCodeAt(value, i);
      if (ch == "\"".code)
        buf.add("\"\"");
      else if (ch < 32 || ch == 127)
        buf.addChar(32);
      else
        buf.addChar(ch);
    }
    buf.addChar("\"".code);
    return buf.toString();
  }

  private static function sanitizeSingleLine(value:String, fallback:String = "Unknown"):String
  {
    if (value == null || value == "")
      return fallback;
    var buf = new StringBuf();
    for (i in 0...value.length)
    {
      var ch = StringTools.fastCodeAt(value, i);
      buf.addChar((ch < 32 || ch == 127) ? 32 : ch);
    }
    return buf.toString();
  }

  private static function dominantSubsystem(sample:FrameSample):String
  {
    var maxVal = sample.otherTimeMs;
    var label = "Other/Idle";
    if (sample.updateTimeMs >= maxVal)
    {
      maxVal = sample.updateTimeMs;
      label = "Update";
    }
    if (sample.renderTimeMs >= maxVal)
    {
      maxVal = sample.renderTimeMs;
      label = "Render";
    }
    if (sample.audioTimeMs >= maxVal)
    {
      maxVal = sample.audioTimeMs;
      label = "Audio";
    }
    if (sample.gcPauseMs >= maxVal && sample.gcPauseMs > 0.0)
      label = "GC Pause";
    return label;
  }

  /**
   * Formats a complete `.log` report in Haxe matching the 6-section native C/C++
   * report layout (`[1]` through `[6]`), including top slowest frames and
   * RFC 4180 CSV escaping.
   */
  public static function formatReport(?engineVersion:String, ?platformName:String):String
  {
    ensureInitialized();
    final sum = getSummary();
    final ver = sanitizeSingleLine(engineVersion != null && engineVersion != "" ? engineVersion : getEngineVersion(), "0.3.2");
    final plat = sanitizeSingleLine(platformName != null && platformName != "" ? platformName : getPlatformLabel(), "Haxe");
    final safeState = sanitizeSingleLine(_currentStateName, "InitialState");
    final nowStr = DateTools.format(Date.now(), "%Y-%m-%d %H:%M:%S");

    var buf = new StringBuf();
    buf.add("================================================================================\n");
    buf.add("PHOENIX ENGINE - FRAME PROFILER LOG REPORT\n");
    buf.add("================================================================================\n");
    buf.add('Generated At           : ${nowStr}\n');
    buf.add('Engine Version         : ${ver}\n');
    buf.add('Platform / Runtime     : ${plat}\n');
    buf.add('Active State           : ${safeState}\n');
    buf.add('Target Framerate       : ${roundDec(sum.targetFps, 2)} FPS (${roundDec(sum.targetFrameTimeMs, 4)} ms/frame budget)\n');
    buf.add('Session Duration       : ${roundDec(sum.sessionDurationMs, 3)} ms (${roundDec(sum.sessionDurationMs / 1000.0, 2)} s)\n');
    buf.add('Total Frames Recorded  : ${sum.totalFrames} (Ring Buffer Window: ${sum.bufferedFrames} / ${NativeFrameProfiler.RING_CAPACITY} frames)\n');
    if (sum.cpuTimeAvailable)
    {
      buf.add('Process CPU Time       : ${roundDec(sum.cpuTimeMs, 3)} ms (${roundDec(sum.cpuUtilizationPct, 2)}% single-core eq; ${roundDec(sum.cpuNormalizedPct, 2)}% across ${sum.logicalCpuCount} logical CPUs)\n');
    }
    else
    {
      buf.add("Process CPU Time       : N/A (unavailable on this platform/runtime)\n");
    }
    buf.add('RSS Sampling Interval  : ${sum.rssSampleIntervalFrames} frames (0 = on-demand only)\n\n');

    buf.add("[1] FRAMETIME & FPS SUMMARY\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add('Average FPS            : ${roundDec(sum.avgFps, 2)} FPS\n');
    buf.add('Current Rolling FPS    : ${roundDec(sum.currentFps, 2)} FPS (1.0s trailing sliding window)\n');
    buf.add('Min / Max FPS          : ${roundDec(sum.minFps, 2)} FPS / ${roundDec(sum.maxFps, 2)} FPS\n');
    buf.add('1% Low / 0.1% Low FPS  : ${roundDec(sum.onePercentLowFps, 2)} FPS (1000/P99) / ${roundDec(sum.pointOnePercentLowFps, 2)} FPS (1000/P99.9)\n');
    buf.add('Slowest 1% / 0.1% Mean : ${roundDec(sum.slowest1PctAvgFps, 2)} FPS / ${roundDec(sum.slowest01PctAvgFps, 2)} FPS (harmonic mean of slowest tail frames)\n');
    buf.add('Average Frametime      : ${roundDec(sum.avgFrameTimeMs, 4)} ms (StdDev: ${roundDec(sum.stdDevFrameTimeMs, 4)} ms)\n');
    buf.add('Min / Max Frametime    : ${roundDec(sum.minFrameTimeMs, 4)} ms / ${roundDec(sum.maxFrameTimeMs, 4)} ms\n');
    buf.add('Frametime Percentiles  : P50=${roundDec(sum.p50FrameTimeMs, 4)} ms | P95=${roundDec(sum.p95FrameTimeMs, 4)} ms | P99=${roundDec(sum.p99FrameTimeMs, 4)} ms | P99.9=${roundDec(sum.p999FrameTimeMs, 4)} ms\n');
    buf.add('Dropped / Spike Frames : >1.5x Budget=${sum.droppedFrames} | >16.7ms=${sum.spikeCount16Ms} | >25ms=${sum.spikeCount25Ms} | >33.3ms=${sum.spikeCount33Ms} | >50ms=${sum.spikeCount50Ms}\n\n');

    buf.add("[2] SUBSYSTEM TIMINGS (UPDATES, RENDERING, AUDIO)\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add('Update Timings         : Avg=${roundDec(sum.avgUpdateTimeMs, 4)} ms | P95=${roundDec(sum.p95UpdateTimeMs, 4)} ms | Max=${roundDec(sum.maxUpdateTimeMs, 4)} ms\n');
    buf.add('Render Timings         : Avg=${roundDec(sum.avgRenderTimeMs, 4)} ms | P95=${roundDec(sum.p95RenderTimeMs, 4)} ms | Max=${roundDec(sum.maxRenderTimeMs, 4)} ms\n');
    buf.add('Audio Timings          : Avg=${roundDec(sum.avgAudioTimeMs, 4)} ms | P95=${roundDec(sum.p95AudioTimeMs, 4)} ms | Max=${roundDec(sum.maxAudioTimeMs, 4)} ms\n');
    buf.add('Other / Unaccounted    : Avg=${roundDec(sum.avgOtherTimeMs, 4)} ms | Max=${roundDec(sum.maxOtherTimeMs, 4)} ms\n');
    buf.add('Draw Calls             : Avg=${roundDec(sum.avgDrawCalls, 1)} / frame | Max=${sum.maxDrawCalls}\n\n');

    buf.add("[3] GARBAGE COLLECTION (GC PAUSES & HEAP CONTRACTIONS)\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add('Measured GC Events     : ${sum.totalGcCount} (Explicit: ${sum.totalExplicitGcCount})\n');
    buf.add('Observed Contractions  : ${sum.totalImplicitGcCount} intervals (uninstrumented negative heap deltas; heuristic)\n');
    buf.add('Frames With GC Activity: ${sum.framesWithGc}\n');
    buf.add('Measured GC Pause Time : Total=${roundDec(sum.totalGcPauseMs, 4)} ms | Avg=${roundDec(sum.avgGcPauseMs, 4)} ms | Max=${roundDec(sum.maxGcPauseMs, 4)} ms (Frame #${sum.maxGcPauseFrame})\n');
    buf.add('Observed Reclaimed Heap: ${Std.int(sum.totalGcReclaimedBytes)} bytes (${roundDec(sum.totalGcReclaimedBytes / (1024.0 * 1024.0), 2)} MB)\n\n');

    buf.add("[4] ALLOCATIONS & MEMORY USAGE\n");
    buf.add("--------------------------------------------------------------------------------\n");
    if (sum.heapStatsAvailable)
    {
      buf.add('Observed Alloc Growth  : ${Std.int(sum.totalAllocBytes)} bytes (${roundDec(sum.totalAllocBytes / (1024.0 * 1024.0), 2)} MB) across ${sum.totalAllocCount} positive-delta intervals\n');
      buf.add('Avg Alloc / Frame      : ${roundDec(sum.avgAllocBytesPerFrame, 1)} bytes/frame (${roundDec(sum.avgAllocBytesPerFrame / 1024.0, 2)} KB/frame)\n');
      buf.add('Allocation Rate        : ${roundDec(sum.allocRateBytesPerSec / 1024.0, 2)} KB/s (${roundDec(sum.allocRateBytesPerSec / (1024.0 * 1024.0), 2)} MB/s)\n');
      buf.add('Peak Frame Allocation  : ${Std.int(sum.peakFrameAllocBytes)} bytes (${roundDec(sum.peakFrameAllocBytes / 1024.0, 2)} KB) on Frame #${sum.peakFrameAllocFrame}\n');
      buf.add('Managed Heap (Current) : Used=${Std.int(sum.currentHeapUsedBytes)} bytes (${roundDec(sum.currentHeapUsedBytes / (1024.0 * 1024.0), 2)} MB) | Reserved=${Std.int(sum.currentHeapReservedBytes)} bytes (${roundDec(sum.currentHeapReservedBytes / (1024.0 * 1024.0), 2)} MB)\n');
      buf.add('Managed Heap (Peak)    : Used=${Std.int(sum.peakHeapUsedBytes)} bytes (${roundDec(sum.peakHeapUsedBytes / (1024.0 * 1024.0), 2)} MB) | Reserved=${Std.int(sum.peakHeapReservedBytes)} bytes (${roundDec(sum.peakHeapReservedBytes / (1024.0 * 1024.0), 2)} MB)\n');
    }
    else
    {
      buf.add("Managed Heap Metrics   : N/A (not collected or unavailable on this runtime)\n");
    }
    if (sum.rssAvailable)
    {
      buf.add('Process RSS Memory     : Current=${Std.int(sum.currentRssBytes)} bytes (${roundDec(sum.currentRssBytes / (1024.0 * 1024.0), 2)} MB) | Peak=${Std.int(sum.peakRssBytes)} bytes (${roundDec(sum.peakRssBytes / (1024.0 * 1024.0), 2)} MB)\n\n');
    }
    else
    {
      buf.add("Process RSS Memory     : N/A (unavailable or disabled)\n\n");
    }

    final count = getBufferedFrameCount();
    final allSamples:Array<FrameSample> = [];
    for (i in 0...count)
    {
      final s = getBufferedFrame(i);
      if (s != null)
        allSamples.push(s);
    }

    final sortedBySlowest = allSamples.copy();
    sortedBySlowest.sort(function(a:FrameSample, b:FrameSample):Int {
      if (b.frameTimeMs > a.frameTimeMs)
        return 1;
      if (b.frameTimeMs < a.frameTimeMs)
        return -1;
      return 0;
    });

    buf.add("[5] TOP SLOWEST FRAMES (BOTTLENECK ANALYSIS)\n");
    buf.add("--------------------------------------------------------------------------------\n");
    if (sortedBySlowest.length == 0)
    {
      buf.add("No frames recorded.\n\n");
    }
    else
    {
      final topCount = sortedBySlowest.length < 10 ? sortedBySlowest.length : 10;
      for (i in 0...topCount)
      {
        final s = sortedBySlowest[i];
        final rankStr = (i + 1) < 10 ? '0${i + 1}' : '${i + 1}';
        final cleanState = sanitizeSingleLine(s.stateName, "UnknownState");
        buf.add('#${rankStr} Frame ${s.frameIndex} @ ${roundDec(s.timestampMs, 2)}ms: Frametime=${roundDec(s.frameTimeMs, 4)}ms (${roundDec(s.fps, 1)} FPS) | Upd=${roundDec(s.updateTimeMs, 4)}ms | Rnd=${roundDec(s.renderTimeMs, 4)}ms | Aud=${roundDec(s.audioTimeMs, 4)}ms | GC=${roundDec(s.gcPauseMs, 4)}ms | Alloc=${Std.int(s.allocBytes)}B | Bottleneck=${dominantSubsystem(s)} | State=${cleanState}\n');
      }
      buf.add("\n");
    }

    buf.add("[6] PER-FRAME TIMELINE (CSV)\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add("frame,timestamp_ms,frametime_ms,work_ms,fps,rolling_fps,update_ms,render_ms,audio_ms,gc_pause_ms,other_ms,alloc_bytes,alloc_count,gc_reclaimed_bytes,net_heap_delta_bytes,heap_used_bytes,heap_reserved_bytes,rss_bytes,peak_rss_bytes,gc_count,explicit_gc,implicit_gc,draw_calls,update_steps,state\n");

    for (s in allSamples)
    {
      final csvState = escapeCsvField(s.stateName);
      buf.add('${s.frameIndex},${roundDec(s.timestampMs, 4)},${roundDec(s.frameTimeMs, 4)},${roundDec(s.workTimeMs, 4)},${roundDec(s.fps, 2)},${roundDec(s.rollingFps, 2)},${roundDec(s.updateTimeMs, 4)},${roundDec(s.renderTimeMs, 4)},${roundDec(s.audioTimeMs, 4)},${roundDec(s.gcPauseMs, 4)},${roundDec(s.otherTimeMs, 4)},${Std.int(s.allocBytes)},${s.allocCount},${Std.int(s.gcReclaimedBytes)},${Std.int(s.netHeapDeltaBytes)},${Std.int(s.heapUsedBytes)},${Std.int(s.heapReservedBytes)},${Std.int(s.rssBytes)},${Std.int(s.peakRssBytes)},${s.gcCount},${s.explicitGcCount},${s.implicitGcCount},${s.drawCalls},${s.updateSteps},${csvState}\n');
    }

    return buf.toString();
  }

  /**
   * Exports the current frame profiler session to a `.log` file inside `debug/log/`.
   * Returns the resolved path on success, or `""` on failure. Never updates
   * `lastExportedLogPath` when an export fails.
   */
  public static function exportLog(?fileName:String):String
  {
    ensureInitialized();
    if (exportInProgress)
      return "";
    final requested = fileName != null ? fileName : "";
    final ver = getEngineVersion();
    final plat = getPlatformLabel();

    final exported = NativeFrameProfiler.exportLog(requested, ver, plat);
    if (exported != null && exported != "")
    {
      #if sys
      try
      {
        if (FileSystem.exists(exported) && !FileSystem.isDirectory(exported))
        {
          lastExportedLogPath = exported;
          trace('[FrameProfiler] Exported frame profile log to: ${exported}');
          return exported;
        }
      }
      catch (_:Dynamic) {}
      #else
      lastExportedLogPath = exported;
      return exported;
      #end
    }

    return "";
  }

  /**
   * Handles automatic log export during application shutdown.
   * Safe when initialization was incomplete or recording was never started,
   * and idempotent across repeated shutdown callbacks.
   */
  public static function handleApplicationExit():String
  {
    if (!initialized || !autoExportOnExit || _exitExportCompleted)
      return "";
    _exitExportCompleted = true;
    NativeFrameProfiler.abortInFlightFrame();
    return exportLog();
  }

  private static function getEngineVersion():String
  {
    try
    {
      if (Application.current != null && Application.current.meta != null)
      {
        final v = Application.current.meta.get("version");
        if (v != null && v != "")
          return v;
      }
    }
    catch (_:Dynamic) {}
    return "0.3.2";
  }

  private static function getPlatformLabel():String
  {
    #if windows
    return "Windows (C++/hxcpp)";
    #elseif mac
    return "macOS (C++/hxcpp)";
    #elseif linux
    return "Linux (C++/hxcpp)";
    #elseif android
    return "Android (C++/hxcpp)";
    #elseif ios
    return "iOS (C++/hxcpp)";
    #elseif hl
    return "HashLink";
    #else
    return "Haxe";
    #end
  }
}
