package backend;

/**
 * Pure layout math for the 1280x720 game. Keeping it separate from Flixel makes
 * the aspect-ratio and touch-boundary rules testable without a renderer.
 */
class ScreenLayout
{
	public static inline var BASE_WIDTH:Int = 1280;
	public static inline var BASE_HEIGHT:Int = 720;

	/** The logical width at a fixed 720-pixel height; narrow screens letterbox. */
	public static function viewportWidth(deviceWidth:Int, deviceHeight:Int, widescreen:Bool):Int
	{
		if (!widescreen || deviceWidth <= 0 || deviceHeight <= 0)
			return BASE_WIDTH;

		return Std.int(Math.max(BASE_WIDTH, Math.ceil(deviceWidth * BASE_HEIGHT / deviceHeight)));
	}

	/** Left edge of the centered, mod-compatible 1280-pixel gameplay/UI area. */
	public static inline function contentLeft(viewportWidth:Int):Float
		return Math.max(0, (viewportWidth - BASE_WIDTH) / 2);

	/** Contiguous touch lanes covering all pixels, including rounding remainders. */
	public static inline function laneStart(index:Int, lanes:Int, viewportWidth:Int):Int
		return Std.int(Math.floor(index * viewportWidth / lanes));

	/** Reserve a positive extra-control strip without creating a zero-height lane. */
	public static inline function hitboxExtraHeight(height:Int, enabled:Bool):Int
		return enabled && height > 1 ? Std.int(Math.max(1, Math.floor(height / 4))) : 0;

	/** Preserve a button's distance from its nearest edge on a resize. */
	public static inline function anchoredPosition(position:Float, oldSize:Int, newSize:Int, extent:Float):Float
	{
		// Classify by the button's center, not its left edge: wide buttons
		// straddling the midpoint still belong to the right-side cluster.
		var moved:Float = position + (position + extent / 2 >= oldSize / 2 ? newSize - oldSize : 0);
		return Math.max(0, Math.min(Math.max(0, newSize - extent), moved));
	}
}
