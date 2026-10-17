package debug;

import debug.Memory;
import debug.profiler.NativeFrameProfiler;
import lime.system.System as LimeSystem;
import states.MainMenuState;
import utils.MemoryUtil;
#if cpp
import utils.PlatformUtil;
#end

/**
 * Snapshot of metrics captured for a single rendered frame.
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
  var allocBytes:Float;
  var netHeapDeltaBytes:Float;
  var gcReclaimedBytes:Float;
  var heapUsedBytes:Float;
  var heapReservedBytes:Float;
  var rssBytes:Float;
  var peakRssBytes:Float;
  var allocCount:Int;
  var gcCount:Int;
  var explicitGcCount:Int;
  var implicitGcCount:Int;
  var updateSteps:Int;
  var drawCalls:Int;
  var stateName:String;
}

/**
 * Aggregated session and percentile statistics across profiled frames.
 */
typedef FrameProfileSummary =
{
  var totalFrames:Int;
  var bufferedFrames:Int;
  var targetFps:Float;
  var sessionDurationMs:Float;
  var cpuTimeMs:Float;
  var cpuUtilizationPct:Float;

  var avgFrameTimeMs:Float;
  var minFrameTimeMs:Float;
  var maxFrameTimeMs:Float;
  var stdDevFrameTimeMs:Float;
  var p50FrameTimeMs:Float;
  var p95FrameTimeMs:Float;
  var p99FrameTimeMs:Float;
  var p999FrameTimeMs:Float;
  var spikeCount25Ms:Int;
  var spikeCount33Ms:Int;

  var avgFps:Float;
  var currentFps:Float;
  var minFps:Float;
  var maxFps:Float;
  var onePercentLowFps:Float;
  var pointOnePercentLowFps:Float;

  var avgUpdateTimeMs:Float;
  var maxUpdateTimeMs:Float;
  var p99UpdateTimeMs:Float;
  var totalUpdateTimeMs:Float;
  var updateFrameSharePct:Float;

  var avgRenderTimeMs:Float;
  var maxRenderTimeMs:Float;
  var p99RenderTimeMs:Float;
  var totalRenderTimeMs:Float;
  var renderFrameSharePct:Float;

  var avgAudioTimeMs:Float;
  var maxAudioTimeMs:Float;
  var p99AudioTimeMs:Float;
  var totalAudioTimeMs:Float;
  var audioFrameSharePct:Float;

  var totalGcCount:Int;
  var totalExplicitGcCount:Int;
  var totalImplicitGcCount:Int;
  var framesWithGc:Int;
  var totalGcPauseMs:Float;
  var avgGcPausePerFrameMs:Float;
  var avgGcPausePerCollectionMs:Float;
  var maxGcPauseMs:Float;
  var maxGcPauseFrame:Int;
  var gcFrameSharePct:Float;
  var totalGcReclaimedBytes:Float;

  var totalAllocBytes:Float;
  var totalAllocCount:Int;
  var avgAllocBytesPerFrame:Float;
  var allocRateBytesPerSec:Float;
  var peakFrameAllocBytes:Float;
  var peakFrameAllocFrame:Int;
  var startHeapUsedBytes:Float;
  var currentHeapUsedBytes:Float;
  var peakHeapUsedBytes:Float;
  var currentHeapReservedBytes:Float;
  var currentRssBytes:Float;
  var peakRssBytes:Float;
}

/**
 * Full Frame Profiler for Phoenix Engine (Haxe + Native C/C++).
 *
 * Records per-frame frametime, FPS, heap allocations, GC pauses, and time
 * spent on updates, rendering, and audio, and exports structured `.log`
 * reports to the `debug/log/` directory.
 */
class FrameProfiler
{
  public static inline final LOG_DIR:String = "debug/log";
  public static inline final DEFAULT_LOG_FILE:String = "debug/log/frame_profiler.log";

  /** Whether to automatically export a `.log` report to `debug/log/` when the game exits. */
  public static var autoExportOnExit:Bool = #if PROFILE_FRAMES true #else false #end;

  /** Path of the most recently exported `.log` file, or empty string if none yet. */
  public static var lastExportedLogPath(default, null):String = "";

  /** Whether the frame profiler is currently recording frames. */
  public static var enabled(get, set):Bool;

  static var _initialized:Bool = false;

  static inline function get_enabled():Bool
    return NativeFrameProfiler.isEnabled();

  static inline function set_enabled(value:Bool):Bool
  {
    NativeFrameProfiler.setEnabled(value);
    return value;
  }

  /**
   * Initializes the Frame Profiler and configures the target framerate.
   * @param targetFps Target framerate in frames per second.
   */
  public static function init(targetFps:Float = 60.0):Void
  {
    NativeFrameProfiler.init(targetFps);
    _initialized = true;
    #if sys
    final args = Sys.args();
    if (args.contains("-profile") || args.contains("--profile"))
      autoExportOnExit = true;
    #end
  }

  /**
   * Starts or resumes recording frame profiling data.
   */
  public static function start():Void
  {
    if (!_initialized)
      init(FlxG.drawFramerate > 0 ? FlxG.drawFramerate : 60.0);
    NativeFrameProfiler.setEnabled(true);
  }

  /**
   * Pauses frame profiling without clearing previously recorded frames.
   */
  public static function stop():Void
  {
    NativeFrameProfiler.setEnabled(false);
  }

  /**
   * Toggles frame profiler recording on or off and returns the new state.
   * @return Bool
   */
  public static function toggle():Bool
  {
    final nextState = !enabled;
    enabled = nextState;
    return nextState;
  }

  /**
   * Clears all recorded frame samples and resets session accumulators.
   */
  public static function reset():Void
  {
    if (!_initialized)
      init(60.0);
    else
      NativeFrameProfiler.reset();
  }

  /**
   * Updates the target framerate used for frame budget calculations.
   * @param targetFps Target framerate in frames per second.
   */
  public static function setTargetFPS(targetFps:Float):Void
  {
    NativeFrameProfiler.setTargetFps(targetFps);
  }

  /**
   * Updates the active state label attached to subsequent frames.
   * @param stateName Active FlxState class name.
   */
  public static function setStateName(stateName:String):Void
  {
    NativeFrameProfiler.setStateName(stateName != null ? stateName : "Unknown");
  }

  /**
   * Returns current GC heap usage in bytes.
   * @return Float
   */
  public static inline function getHeapUsedBytes():Float
  {
    #if cpp
    return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
    #elseif hl
    return hl.Gc.stats().currentMemory;
    #else
    return Memory.gay();
    #end
  }

  /**
   * Returns current GC reserved heap size in bytes.
   * @return Float
   */
  public static inline function getHeapReservedBytes():Float
  {
    #if cpp
    return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_RESERVED);
    #elseif hl
    return hl.Gc.stats().totalAllocated;
    #else
    return Memory.gay();
    #end
  }

  /**
   * Marks the start of a new frame.
   */
  public static function beginFrame():Void
  {
    if (!_initialized)
      init(60.0);
    if (!NativeFrameProfiler.isEnabled())
      return;
    if (FlxG.state != null)
    {
      final cls = Type.getClass(FlxG.state);
      if (cls != null)
        NativeFrameProfiler.setStateName(Type.getClassName(cls));
    }
    NativeFrameProfiler.beginFrame(getHeapUsedBytes(), getHeapReservedBytes());
  }

  /**
   * Marks the end of the current frame and commits its metrics to the ring buffer.
   * @param drawCalls Number of draw calls executed during the frame.
   * @param explicitFrameTimeMs Optional frame delta in milliseconds (0 for automatic monotonic measurement).
   */
  public static function endFrame(drawCalls:Int = 0, explicitFrameTimeMs:Float = 0.0):Void
  {
    if (!_initialized || !NativeFrameProfiler.isEnabled())
      return;
    NativeFrameProfiler.endFrame(getHeapUsedBytes(), getHeapReservedBytes(), drawCalls, explicitFrameTimeMs);
  }

  /**
   * Marks the start of the game update phase (`FlxGame.step` / `FlxGame.update`).
   */
  public static inline function beginUpdate():Void
  {
    if (NativeFrameProfiler.isEnabled())
      NativeFrameProfiler.beginPhase(NativeFrameProfiler.PHASE_UPDATE, getHeapUsedBytes());
  }

  /**
   * Marks the end of the game update phase and returns the net update duration in milliseconds.
   * @return Float
   */
  public static inline function endUpdate():Float
  {
    if (!NativeFrameProfiler.isEnabled())
      return 0.0;
    return NativeFrameProfiler.endPhase(NativeFrameProfiler.PHASE_UPDATE, getHeapUsedBytes());
  }

  /**
   * Marks the start of the rendering phase (`FlxGame.draw` / frame pipe).
   */
  public static inline function beginRender():Void
  {
    if (NativeFrameProfiler.isEnabled())
      NativeFrameProfiler.beginPhase(NativeFrameProfiler.PHASE_RENDER, getHeapUsedBytes());
  }

  /**
   * Marks the end of the rendering phase and returns the net render duration in milliseconds.
   * @param drawCalls Optional draw call count to record for this render pass.
   * @return Float
   */
  public static inline function endRender(drawCalls:Int = 0):Float
  {
    if (!NativeFrameProfiler.isEnabled())
      return 0.0;
    if (drawCalls > 0)
      NativeFrameProfiler.addDrawCalls(drawCalls);
    return NativeFrameProfiler.endPhase(NativeFrameProfiler.PHASE_RENDER, getHeapUsedBytes());
  }

  /**
   * Marks the start of an audio update or sync phase (`FlxG.sound.update`, `soundTray`, vocal sync).
   */
  public static inline function beginAudio():Void
  {
    if (NativeFrameProfiler.isEnabled())
      NativeFrameProfiler.beginPhase(NativeFrameProfiler.PHASE_AUDIO, getHeapUsedBytes());
  }

  /**
   * Marks the end of an audio phase and returns the net audio duration in milliseconds.
   * @return Float
   */
  public static inline function endAudio():Float
  {
    if (!NativeFrameProfiler.isEnabled())
      return 0.0;
    return NativeFrameProfiler.endPhase(NativeFrameProfiler.PHASE_AUDIO, getHeapUsedBytes());
  }

  /**
   * Marks the start of a garbage collection pause.
   * @param major Whether a major collection is being performed.
   */
  public static inline function beginGC(major:Bool = false):Void
  {
    if (NativeFrameProfiler.isEnabled())
      NativeFrameProfiler.beginPhase(NativeFrameProfiler.PHASE_GC, getHeapUsedBytes());
  }

  /**
   * Marks the end of a garbage collection pause and returns the pause duration in milliseconds.
   * @return Float
   */
  public static inline function endGC():Float
  {
    if (!NativeFrameProfiler.isEnabled())
      return 0.0;
    return NativeFrameProfiler.endPhase(NativeFrameProfiler.PHASE_GC, getHeapUsedBytes());
  }

  /**
   * Runs a garbage collection cycle while measuring and recording its pause time and reclaimed memory.
   * @param major Whether to perform a major collection.
   * @return Float Measured GC pause duration in milliseconds.
   */
  public static function collectGarbage(major:Bool = false):Float
  {
    beginGC(major);
    #if cpp
    cpp.vm.Gc.run(major);
    #elseif hl
    hl.Gc.major();
    #else
    openfl.system.System.gc();
    #end
    return endGC();
  }

  /**
   * Measures a callback as part of the update phase and returns its result.
   * @param fn Callback to profile.
   * @return T
   */
  public static inline function measureUpdate<T>(fn:Void->T):T
  {
    beginUpdate();
    final result = fn();
    endUpdate();
    return result;
  }

  /**
   * Measures a callback as part of the rendering phase and returns its result.
   * @param fn Callback to profile.
   * @return T
   */
  public static inline function measureRender<T>(fn:Void->T):T
  {
    beginRender();
    final result = fn();
    endRender();
    return result;
  }

  /**
   * Measures a callback as part of the audio phase and returns its result.
   * @param fn Callback to profile.
   * @return T
   */
  public static inline function measureAudio<T>(fn:Void->T):T
  {
    beginAudio();
    final result = fn();
    endAudio();
    return result;
  }

  /**
   * Measures a callback as a garbage collection operation and returns its result.
   * @param major Whether the operation is a major GC.
   * @param fn Callback to profile.
   * @return T
   */
  public static inline function measureGC<T>(major:Bool, fn:Void->T):T
  {
    beginGC(major);
    final result = fn();
    endGC();
    return result;
  }

  /**
   * Directly records an allocation event on the current frame.
   * @param bytes Number of bytes allocated.
   * @param count Number of allocations.
   */
  public static inline function recordAllocation(bytes:Float, count:Int = 1):Void
  {
    NativeFrameProfiler.recordAllocation(bytes, count);
  }

  /**
   * Directly records a GC pause duration and reclaimed byte count on the current frame.
   * @param pauseMs Duration of the GC pause in milliseconds.
   * @param reclaimedBytes Bytes reclaimed by the collection.
   * @param isExplicit Whether the GC was explicitly requested.
   */
  public static inline function recordGCPause(pauseMs:Float, reclaimedBytes:Float = 0.0, isExplicit:Bool = true):Void
  {
    NativeFrameProfiler.recordGCPause(pauseMs, reclaimedBytes, isExplicit);
  }

  /**
   * Directly adds update duration (in ms) to the current frame.
   * @param durationMs Update time in milliseconds.
   */
  public static inline function recordUpdateTime(durationMs:Float):Void
  {
    NativeFrameProfiler.recordPhaseMs(NativeFrameProfiler.PHASE_UPDATE, durationMs);
  }

  /**
   * Directly adds rendering duration (in ms) to the current frame.
   * @param durationMs Render time in milliseconds.
   */
  public static inline function recordRenderTime(durationMs:Float):Void
  {
    NativeFrameProfiler.recordPhaseMs(NativeFrameProfiler.PHASE_RENDER, durationMs);
  }

  /**
   * Directly adds audio duration (in ms) to the current frame.
   * @param durationMs Audio time in milliseconds.
   */
  public static inline function recordAudioTime(durationMs:Float):Void
  {
    NativeFrameProfiler.recordPhaseMs(NativeFrameProfiler.PHASE_AUDIO, durationMs);
  }

  /**
   * Adds draw call counts to the current frame.
   * @param drawCalls Number of draw calls.
   */
  public static inline function addDrawCalls(drawCalls:Int):Void
  {
    NativeFrameProfiler.addDrawCalls(drawCalls);
  }

  static function readCachedSample():FrameSample
  {
    return {
      frameIndex: Std.int(NativeFrameProfiler.sampleFrameIndex()),
      timestampMs: NativeFrameProfiler.sampleTimestampMs(),
      frameTimeMs: NativeFrameProfiler.sampleFrameTimeMs(),
      workTimeMs: NativeFrameProfiler.sampleWorkTimeMs(),
      fps: NativeFrameProfiler.sampleFps(),
      rollingFps: NativeFrameProfiler.sampleRollingFps(),
      updateTimeMs: NativeFrameProfiler.sampleUpdateTimeMs(),
      renderTimeMs: NativeFrameProfiler.sampleRenderTimeMs(),
      audioTimeMs: NativeFrameProfiler.sampleAudioTimeMs(),
      gcPauseMs: NativeFrameProfiler.sampleGcPauseMs(),
      otherTimeMs: NativeFrameProfiler.sampleOtherTimeMs(),
      allocBytes: NativeFrameProfiler.sampleAllocBytes(),
      netHeapDeltaBytes: NativeFrameProfiler.sampleNetHeapDeltaBytes(),
      gcReclaimedBytes: NativeFrameProfiler.sampleGcReclaimedBytes(),
      heapUsedBytes: NativeFrameProfiler.sampleHeapUsedBytes(),
      heapReservedBytes: NativeFrameProfiler.sampleHeapReservedBytes(),
      rssBytes: NativeFrameProfiler.sampleRssBytes(),
      peakRssBytes: NativeFrameProfiler.samplePeakRssBytes(),
      allocCount: NativeFrameProfiler.sampleAllocCount(),
      gcCount: NativeFrameProfiler.sampleGcCount(),
      explicitGcCount: NativeFrameProfiler.sampleExplicitGcCount(),
      implicitGcCount: NativeFrameProfiler.sampleImplicitGcCount(),
      updateSteps: NativeFrameProfiler.sampleUpdateSteps(),
      drawCalls: NativeFrameProfiler.sampleDrawCalls(),
      stateName: NativeFrameProfiler.sampleStateName()
    };
  }

  /**
   * Returns the most recently completed frame sample, or `null` if no frames have been recorded yet.
   * @return Null<FrameSample>
   */
  public static function getLastFrame():Null<FrameSample>
  {
    if (!NativeFrameProfiler.refreshLastFrame())
      return null;
    return readCachedSample();
  }

  /**
   * Returns the buffered frame history in chronological order (oldest to newest).
   * @param maxFrames Optional maximum number of most-recent frames to return.
   * @return Array<FrameSample>
   */
  public static function getFrameHistory(?maxFrames:Int):Array<FrameSample>
  {
    NativeFrameProfiler.refreshSummary();
    final buffered = NativeFrameProfiler.summaryBufferedFrames();
    if (buffered <= 0)
      return [];
    var startIdx = 0;
    if (maxFrames != null && maxFrames > 0 && maxFrames < buffered)
      startIdx = buffered - maxFrames;
    final out:Array<FrameSample> = [];
    for (i in startIdx...buffered)
    {
      if (NativeFrameProfiler.loadBufferedFrame(i))
        out.push(readCachedSample());
    }
    return out;
  }

  /**
   * Computes and returns the aggregated session summary statistics.
   * @return FrameProfileSummary
   */
  public static function getSummary():FrameProfileSummary
  {
    NativeFrameProfiler.refreshSummary();
    return {
      totalFrames: Std.int(NativeFrameProfiler.summaryTotalFrames()),
      bufferedFrames: NativeFrameProfiler.summaryBufferedFrames(),
      targetFps: NativeFrameProfiler.summaryTargetFps(),
      sessionDurationMs: NativeFrameProfiler.summarySessionDurationMs(),
      cpuTimeMs: NativeFrameProfiler.summaryCpuTimeMs(),
      cpuUtilizationPct: NativeFrameProfiler.summaryCpuUtilizationPct(),

      avgFrameTimeMs: NativeFrameProfiler.summaryAvgFrameTimeMs(),
      minFrameTimeMs: NativeFrameProfiler.summaryMinFrameTimeMs(),
      maxFrameTimeMs: NativeFrameProfiler.summaryMaxFrameTimeMs(),
      stdDevFrameTimeMs: NativeFrameProfiler.summaryStdDevFrameTimeMs(),
      p50FrameTimeMs: NativeFrameProfiler.summaryP50FrameTimeMs(),
      p95FrameTimeMs: NativeFrameProfiler.summaryP95FrameTimeMs(),
      p99FrameTimeMs: NativeFrameProfiler.summaryP99FrameTimeMs(),
      p999FrameTimeMs: NativeFrameProfiler.summaryP999FrameTimeMs(),
      spikeCount25Ms: Std.int(NativeFrameProfiler.summarySpikeCount25Ms()),
      spikeCount33Ms: Std.int(NativeFrameProfiler.summarySpikeCount33Ms()),

      avgFps: NativeFrameProfiler.summaryAvgFps(),
      currentFps: NativeFrameProfiler.summaryCurrentFps(),
      minFps: NativeFrameProfiler.summaryMinFps(),
      maxFps: NativeFrameProfiler.summaryMaxFps(),
      onePercentLowFps: NativeFrameProfiler.summaryOnePercentLowFps(),
      pointOnePercentLowFps: NativeFrameProfiler.summaryPointOnePercentLowFps(),

      avgUpdateTimeMs: NativeFrameProfiler.summaryAvgUpdateTimeMs(),
      maxUpdateTimeMs: NativeFrameProfiler.summaryMaxUpdateTimeMs(),
      p99UpdateTimeMs: NativeFrameProfiler.summaryP99UpdateTimeMs(),
      totalUpdateTimeMs: NativeFrameProfiler.summaryTotalUpdateTimeMs(),
      updateFrameSharePct: NativeFrameProfiler.summaryUpdateFrameSharePct(),

      avgRenderTimeMs: NativeFrameProfiler.summaryAvgRenderTimeMs(),
      maxRenderTimeMs: NativeFrameProfiler.summaryMaxRenderTimeMs(),
      p99RenderTimeMs: NativeFrameProfiler.summaryP99RenderTimeMs(),
      totalRenderTimeMs: NativeFrameProfiler.summaryTotalRenderTimeMs(),
      renderFrameSharePct: NativeFrameProfiler.summaryRenderFrameSharePct(),

      avgAudioTimeMs: NativeFrameProfiler.summaryAvgAudioTimeMs(),
      maxAudioTimeMs: NativeFrameProfiler.summaryMaxAudioTimeMs(),
      p99AudioTimeMs: NativeFrameProfiler.summaryP99AudioTimeMs(),
      totalAudioTimeMs: NativeFrameProfiler.summaryTotalAudioTimeMs(),
      audioFrameSharePct: NativeFrameProfiler.summaryAudioFrameSharePct(),

      totalGcCount: Std.int(NativeFrameProfiler.summaryTotalGcCount()),
      totalExplicitGcCount: Std.int(NativeFrameProfiler.summaryTotalExplicitGcCount()),
      totalImplicitGcCount: Std.int(NativeFrameProfiler.summaryTotalImplicitGcCount()),
      framesWithGc: Std.int(NativeFrameProfiler.summaryFramesWithGc()),
      totalGcPauseMs: NativeFrameProfiler.summaryTotalGcPauseMs(),
      avgGcPausePerFrameMs: NativeFrameProfiler.summaryAvgGcPausePerFrameMs(),
      avgGcPausePerCollectionMs: NativeFrameProfiler.summaryAvgGcPausePerCollectionMs(),
      maxGcPauseMs: NativeFrameProfiler.summaryMaxGcPauseMs(),
      maxGcPauseFrame: Std.int(NativeFrameProfiler.summaryMaxGcPauseFrame()),
      gcFrameSharePct: NativeFrameProfiler.summaryGcFrameSharePct(),
      totalGcReclaimedBytes: NativeFrameProfiler.summaryTotalGcReclaimedBytes(),

      totalAllocBytes: NativeFrameProfiler.summaryTotalAllocBytes(),
      totalAllocCount: Std.int(NativeFrameProfiler.summaryTotalAllocCount()),
      avgAllocBytesPerFrame: NativeFrameProfiler.summaryAvgAllocBytesPerFrame(),
      allocRateBytesPerSec: NativeFrameProfiler.summaryAllocRateBytesPerSec(),
      peakFrameAllocBytes: NativeFrameProfiler.summaryPeakFrameAllocBytes(),
      peakFrameAllocFrame: Std.int(NativeFrameProfiler.summaryPeakFrameAllocFrame()),
      startHeapUsedBytes: NativeFrameProfiler.summaryStartHeapUsedBytes(),
      currentHeapUsedBytes: NativeFrameProfiler.summaryCurrentHeapUsedBytes(),
      peakHeapUsedBytes: NativeFrameProfiler.summaryPeakHeapUsedBytes(),
      currentHeapReservedBytes: NativeFrameProfiler.summaryCurrentHeapReservedBytes(),
      currentRssBytes: NativeFrameProfiler.summaryCurrentRssBytes(),
      peakRssBytes: NativeFrameProfiler.summaryPeakRssBytes()
    };
  }

  static inline function round2(v:Float):Float
    return Math.fround(v * 100.0) / 100.0;

  static inline function round3(v:Float):Float
    return Math.fround(v * 1000.0) / 1000.0;

  /**
   * Returns a compact multi-line HUD string suitable for `FPSCounter` display.
   * @return String
   */
  public static function getOverlayText():String
  {
    final last = getLastFrame();
    final sum = getSummary();
    if (last == null)
      return "Profiler: waiting for frames...";

    var text = 'Frametime: ${round2(last.frameTimeMs)} ms (Avg: ${round2(sum.avgFrameTimeMs)} ms | 1% Low: ${Math.round(sum.onePercentLowFps)} FPS)';
    text += '\nUpdate: ${round3(last.updateTimeMs)} ms | Render: ${round3(last.renderTimeMs)} ms | Audio: ${round3(last.audioTimeMs)} ms';
    text += '\nAlloc: ${MemoryUtil.formatMemory(last.allocBytes)}/f (Rate: ${MemoryUtil.formatMemory(sum.allocRateBytesPerSec)}/s)'
      + ' | GC: ${sum.totalGcCount} (${round3(sum.totalGcPauseMs)} ms total, max ${round3(sum.maxGcPauseMs)} ms)';
    return text;
  }

  static function cleanTimestamp():String
  {
    var now = Date.now().toString();
    now = StringTools.replace(now, " ", "_");
    now = StringTools.replace(now, ":", "-");
    return now;
  }

  static function getPlatformDescription():String
  {
    var pName = LimeSystem.platformName != null ? LimeSystem.platformName : "Unknown";
    var pVer = LimeSystem.platformVersion != null ? LimeSystem.platformVersion : "";
    var arch = #if cpp PlatformUtil.getArch() #else "" #end;
    var parts:Array<String> = [pName];
    if (arch != null && arch.length > 0)
      parts.push(arch);
    if (pVer.length > 0 && pVer != pName)
      parts.push(pVer);
    return parts.join(" ");
  }

  /**
   * Resolves a requested log filename into a sanitized `.log` path inside `debug/log/`.
   * @param fileName Optional custom filename (defaults to a timestamped `frame_profiler_<date>.log`).
   * @return String
   */
  public static function resolveLogPath(?fileName:String):String
  {
    var requested = fileName;
    if (requested == null || StringTools.trim(requested).length == 0)
      requested = '$LOG_DIR/frame_profiler_${cleanTimestamp()}.log';
    return NativeFrameProfiler.resolveLogPath(requested);
  }

  /**
   * Formats the full frame profiler report and CSV frame table as a string.
   * @param engineVersion Optional engine version override.
   * @param platformInfo Optional platform info override.
   * @param logPath Optional resolved log file path for header display.
   * @return String
   */
  public static function formatReport(?engineVersion:String, ?platformInfo:String, ?logPath:String):String
  {
    final ver = (engineVersion != null && engineVersion.length > 0)
      ? engineVersion
      : MainMenuState.phoenixEngineVersion;
    final plat = (platformInfo != null && platformInfo.length > 0)
      ? platformInfo
      : getPlatformDescription();
    final path = (logPath != null && logPath.length > 0) ? logPath : DEFAULT_LOG_FILE;
    final sum = getSummary();
    final history = getFrameHistory();
    final last = history.length > 0 ? history[history.length - 1] : null;
    final activeState = last != null ? last.stateName : "Unknown";

    final buf = new StringBuf();
    buf.add("================================================================================\n");
    buf.add("PHOENIX ENGINE - FRAME PROFILER LOG REPORT\n");
    buf.add("================================================================================\n");
    buf.add('Engine Version       : $ver\n');
    buf.add('Platform             : $plat\n');
    buf.add('Log File             : $path\n');
    buf.add('Target FPS           : ${round2(sum.targetFps)}\n');
    buf.add('Total Frames         : ${sum.totalFrames} (Buffered: ${sum.bufferedFrames} / ${NativeFrameProfiler.RING_CAPACITY})\n');
    buf.add('Session Duration     : ${round3(sum.sessionDurationMs)} ms (${round3(sum.sessionDurationMs / 1000.0)} s)\n');
    buf.add('Process CPU Time     : ${round3(sum.cpuTimeMs)} ms (${round2(sum.cpuUtilizationPct)}% utilization)\n');
    buf.add('Active State         : $activeState\n\n');

    buf.add("--------------------------------------------------------------------------------\n");
    buf.add("[1] FRAMETIME & FPS SUMMARY\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add('Avg Frametime        : ${round3(sum.avgFrameTimeMs)} ms\n');
    buf.add('Min Frametime        : ${round3(sum.minFrameTimeMs)} ms\n');
    buf.add('Max Frametime        : ${round3(sum.maxFrameTimeMs)} ms\n');
    buf.add('Frametime StdDev     : ${round3(sum.stdDevFrameTimeMs)} ms\n');
    buf.add('P50 Frametime        : ${round3(sum.p50FrameTimeMs)} ms\n');
    buf.add('P95 Frametime        : ${round3(sum.p95FrameTimeMs)} ms\n');
    buf.add('P99 Frametime        : ${round3(sum.p99FrameTimeMs)} ms\n');
    buf.add('P99.9 Frametime      : ${round3(sum.p999FrameTimeMs)} ms\n');
    buf.add('Frame Spikes (>25ms) : ${sum.spikeCount25Ms}\n');
    buf.add('Frame Spikes (>33ms) : ${sum.spikeCount33Ms}\n');
    buf.add('Avg FPS              : ${round2(sum.avgFps)}\n');
    buf.add('Current Rolling FPS  : ${round2(sum.currentFps)}\n');
    buf.add('Min FPS              : ${round2(sum.minFps)}\n');
    buf.add('Max FPS              : ${round2(sum.maxFps)}\n');
    buf.add('1% Low FPS           : ${round2(sum.onePercentLowFps)}\n');
    buf.add('0.1% Low FPS         : ${round2(sum.pointOnePercentLowFps)}\n\n');

    buf.add("--------------------------------------------------------------------------------\n");
    buf.add("[2] SUBSYSTEM TIMINGS (UPDATES, RENDERING, AUDIO)\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add('Updates (avg/max/p99): ${round3(sum.avgUpdateTimeMs)} ms / ${round3(sum.maxUpdateTimeMs)} ms / ${round3(sum.p99UpdateTimeMs)} ms (Total: ${round3(sum.totalUpdateTimeMs)} ms, ${round2(sum.updateFrameSharePct)}% of frame)\n');
    buf.add('Render  (avg/max/p99): ${round3(sum.avgRenderTimeMs)} ms / ${round3(sum.maxRenderTimeMs)} ms / ${round3(sum.p99RenderTimeMs)} ms (Total: ${round3(sum.totalRenderTimeMs)} ms, ${round2(sum.renderFrameSharePct)}% of frame)\n');
    buf.add('Audio   (avg/max/p99): ${round3(sum.avgAudioTimeMs)} ms / ${round3(sum.maxAudioTimeMs)} ms / ${round3(sum.p99AudioTimeMs)} ms (Total: ${round3(sum.totalAudioTimeMs)} ms, ${round2(sum.audioFrameSharePct)}% of frame)\n\n');

    buf.add("--------------------------------------------------------------------------------\n");
    buf.add("[3] GARBAGE COLLECTION (GC PAUSES)\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add('Total GC Collections : ${sum.totalGcCount} (Explicit: ${sum.totalExplicitGcCount}, Implicit: ${sum.totalImplicitGcCount})\n');
    buf.add('Frames With GC       : ${sum.framesWithGc}\n');
    buf.add('Total GC Pause Time  : ${round3(sum.totalGcPauseMs)} ms (${round2(sum.gcFrameSharePct)}% of session)\n');
    buf.add('Avg GC Pause / Frame : ${round3(sum.avgGcPausePerFrameMs)} ms\n');
    buf.add('Avg GC Pause / Event : ${round3(sum.avgGcPausePerCollectionMs)} ms\n');
    buf.add('Max GC Pause         : ${round3(sum.maxGcPauseMs)} ms (Frame #${sum.maxGcPauseFrame})\n');
    buf.add('Total GC Reclaimed   : ${Std.int(sum.totalGcReclaimedBytes)} bytes (${MemoryUtil.formatMemory(sum.totalGcReclaimedBytes)})\n\n');

    buf.add("--------------------------------------------------------------------------------\n");
    buf.add("[4] ALLOCATIONS & MEMORY USAGE\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add('Total Allocations    : ${Std.int(sum.totalAllocBytes)} bytes (${MemoryUtil.formatMemory(sum.totalAllocBytes)}) across ${sum.totalAllocCount} events\n');
    buf.add('Avg Alloc / Frame    : ${round2(sum.avgAllocBytesPerFrame)} bytes (${MemoryUtil.formatMemory(sum.avgAllocBytesPerFrame)})\n');
    buf.add('Allocation Rate      : ${MemoryUtil.formatMemory(sum.allocRateBytesPerSec)}/s\n');
    buf.add('Peak Frame Alloc     : ${Std.int(sum.peakFrameAllocBytes)} bytes (${MemoryUtil.formatMemory(sum.peakFrameAllocBytes)}) on Frame #${sum.peakFrameAllocFrame}\n');
    buf.add('Start GC Heap Used   : ${Std.int(sum.startHeapUsedBytes)} bytes (${MemoryUtil.formatMemory(sum.startHeapUsedBytes)})\n');
    buf.add('Current GC Heap Used : ${Std.int(sum.currentHeapUsedBytes)} bytes (${MemoryUtil.formatMemory(sum.currentHeapUsedBytes)})\n');
    buf.add('Peak GC Heap Used    : ${Std.int(sum.peakHeapUsedBytes)} bytes (${MemoryUtil.formatMemory(sum.peakHeapUsedBytes)})\n');
    buf.add('Current GC Reserved  : ${Std.int(sum.currentHeapReservedBytes)} bytes (${MemoryUtil.formatMemory(sum.currentHeapReservedBytes)})\n');
    buf.add('Current Process RSS  : ${Std.int(sum.currentRssBytes)} bytes (${MemoryUtil.formatMemory(sum.currentRssBytes)})\n');
    buf.add('Peak Process RSS     : ${Std.int(sum.peakRssBytes)} bytes (${MemoryUtil.formatMemory(sum.peakRssBytes)})\n\n');

    buf.add("--------------------------------------------------------------------------------\n");
    buf.add("[5] PER-FRAME TIMELINE (CSV)\n");
    buf.add("--------------------------------------------------------------------------------\n");
    buf.add("frame,timestamp_ms,frametime_ms,work_ms,fps,rolling_fps,update_ms,render_ms,audio_ms,gc_pause_ms,other_ms,alloc_bytes,alloc_count,net_heap_delta_bytes,gc_reclaimed_bytes,gc_count,explicit_gc_count,implicit_gc_count,heap_used_bytes,heap_reserved_bytes,rss_bytes,peak_rss_bytes,draw_calls,update_steps,state\n");
    for (s in history)
    {
      buf.add('${s.frameIndex},${round3(s.timestampMs)},${round3(s.frameTimeMs)},${round3(s.workTimeMs)},${round2(s.fps)},${round2(s.rollingFps)},'
        + '${round3(s.updateTimeMs)},${round3(s.renderTimeMs)},${round3(s.audioTimeMs)},${round3(s.gcPauseMs)},${round3(s.otherTimeMs)},'
        + '${Std.int(s.allocBytes)},${s.allocCount},${Std.int(s.netHeapDeltaBytes)},${Std.int(s.gcReclaimedBytes)},'
        + '${s.gcCount},${s.explicitGcCount},${s.implicitGcCount},${Std.int(s.heapUsedBytes)},${Std.int(s.heapReservedBytes)},'
        + '${Std.int(s.rssBytes)},${Std.int(s.peakRssBytes)},${s.drawCalls},${s.updateSteps},${s.stateName}\n');
    }
    return buf.toString();
  }

  /**
   * Exports the recorded profiler metrics and frame history to a `.log` file in `debug/log/`.
   * @param fileName Optional custom filename inside `debug/log/` (defaults to timestamped `.log` file).
   * @return String The normalized file path written, or empty string if writing failed.
   */
  public static function exportLog(?fileName:String):String
  {
    if (!_initialized)
      init(60.0);

    final targetPath = resolveLogPath(fileName);
    final engineVersion = MainMenuState.phoenixEngineVersion;
    final platformInfo = getPlatformDescription();

    #if sys
    try
    {
      if (!FileSystem.exists("debug"))
        FileSystem.createDirectory("debug");
      if (!FileSystem.exists(LOG_DIR))
        FileSystem.createDirectory(LOG_DIR);
    }
    catch (_:Dynamic) {}
    #end

    final writtenPath = NativeFrameProfiler.exportLog(targetPath, engineVersion, platformInfo);
    if (writtenPath != null && writtenPath.length > 0)
    {
      lastExportedLogPath = writtenPath;
      return writtenPath;
    }

    #if sys
    try
    {
      File.saveContent(targetPath, formatReport(engineVersion, platformInfo, targetPath));
      lastExportedLogPath = targetPath;
      return targetPath;
    }
    catch (_:Dynamic) {}
    #end

    return "";
  }
}
