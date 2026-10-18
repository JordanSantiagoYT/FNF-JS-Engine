package mobile.flixel;

/**
 * Input transitions for a lane that may be held by several fingers at once.
 * Only the first contact presses it, and only the last contact releases it.
 * Kept independent of Flixel so overlapping-touch cases can be tested directly.
 */
class HitboxTouchLogic
{
	public static inline var NONE:Int = 0;
	public static inline var PRESS:Int = 1;
	public static inline var RELEASE:Int = 2;
	public static inline var CANCEL:Int = 3;

	public static inline function transition(wasPressed:Bool, anyPressedOver:Bool, anyReleasedOver:Bool):Int
	{
		if (anyPressedOver) return wasPressed ? NONE : PRESS;
		if (wasPressed) return anyReleasedOver ? RELEASE : CANCEL;
		return NONE;
	}
}
