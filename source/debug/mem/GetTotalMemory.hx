package debug.mem;

import debug.Memory;
#if cpp
import cpp.SizeT;

/**
 * Gets the accurate memory counter
 * Original C code by David Robert Nadeau
 * @see https://web.archive.org/web/20190716205300/http://nadeausoftware.com/articles/2012/07/c_c_tip_how_get_process_resident_set_size_physical_memory_use
 */
@:buildXml('<include name="../../../../source/debug/mem/build.xml" />')
@:include("memory.h")
extern class GetTotalMemory
{
	@:native("getPeakRSS")
	static function getPeakRSS():SizeT;

	@:native("getCurrentRSS")
	static function getCurrentRSS():SizeT;
}
#else
/**
 * If you are not running on a C++ platform, the code just will not work properly, so get the garbage collector memory usage.
 */
class GetTotalMemory
{
	/**
	 * (Non cpp platform)
	 * Returns 0.
	 */
	public static function getPeakRSS():Float
	{
		// might not be the smartest move?
		var memPeak:Float;

		if (getCurrentRSS() > memPeak)
			memPeak = getCurrentRSS();

		return memPeak;
	}

	/**
	 * (Non cpp platform)
	 * Returns the memory count in Memory.hx
	 */
	public static function getCurrentRSS():Float
	{
		return Memory.gay();
	}
}
#end
