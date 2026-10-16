package debug.system;

#if cpp
/** Read-only native process/host queries. No sampling threads or allocations. */
@:buildXml('<include name="../../../../source/debug/system/build.xml" />')
@:include("phoenix_system.h")
extern class SystemInfo
{
  /** Monotonic seconds from an unspecified origin; only differences are meaningful. Returns zero on failure. */
  @:native("phoenixMonotonicSeconds")
  static function monotonicSeconds():Float;

  /** Total user + kernel CPU seconds across all process threads; zero on failure. */
  @:native("phoenixProcessCPUSeconds")
  static function processCPUSeconds():Float;

  /** Online logical CPU count (at least one), not an affinity/container quota. */
  @:native("phoenixLogicalCPUCount")
  static function logicalCPUCount():Int;

  /** Native page size in bytes, or zero if unavailable. */
  @:native("phoenixPageSize")
  static function pageSize():cpp.SizeT;

  /** Host physical RAM in bytes, or zero if unavailable. Not free RAM or a container limit. */
  @:native("phoenixTotalPhysicalMemory")
  static function totalPhysicalMemory():Float;
}
#else
/** Portable fallback: elapsed timing only; native-only queries report unavailable. */
class SystemInfo
{
  /** Runtime timestamp in seconds; use differences rather than calendar dates. */
  public static inline function monotonicSeconds():Float
    return haxe.Timer.stamp();

  /** Native process CPU accounting is unavailable on this target. */
  public static inline function processCPUSeconds():Float
    return 0;

  /** Conservative fallback; does not claim knowledge of host hardware. */
  public static inline function logicalCPUCount():Int
    return 1;

  /** Native page size is unavailable on this target. */
  public static inline function pageSize():Float
    return 0;

  /** Host RAM is unavailable on this target (GC usage is not physical RAM). */
  public static inline function totalPhysicalMemory():Float
    return 0;
}
#end
