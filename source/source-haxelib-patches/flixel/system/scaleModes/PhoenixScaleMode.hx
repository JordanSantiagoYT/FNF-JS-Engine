package flixel.system.scaleModes;

import backend.ClientPrefs;
import backend.ScreenLayout;
import flixel.FlxG;

/**
 * Ratio scaling with a fixed logical height. In widescreen mode the scene grows
 * sideways instead of stretching 16:9 art or clipping the camera; otherwise it
 * behaves exactly like Flixel's default RatioScaleMode.
 *
 * This lives in flixel.system.scaleModes because FlxG grants scale modes access
 * to its read-only logical width/height.
 */
class PhoenixScaleMode extends RatioScaleMode
{
	override public function onMeasure(Width:Int, Height:Int):Void
	{
		// Minimized desktop windows can report zero dimensions. Keep the last
		// valid viewport until the next real resize instead of dividing by zero.
		if (Width <= 0 || Height <= 0) return;

		FlxG.width = ScreenLayout.viewportWidth(Width, Height, ClientPrefs.widescreen);
		FlxG.height = ScreenLayout.BASE_HEIGHT;
		if (ClientPrefs.widescreen && FlxG.width > ScreenLayout.BASE_WIDTH)
		{
			// Ceil-to-integer logical widths are at most one pixel wider than
			// the exact aspect. RatioScaleMode floors the physical game height
			// and can leave a one-pixel bar on 21:9 displays. Fill the physical
			// surface; the rounding difference is below one logical pixel.
			gameSize.set(Width, Height);
		}
		else updateGameSize(Width, Height); // original 16:9 letterboxing
		updateDeviceSize(Width, Height);
		updateScaleOffset();
		updateGamePosition();
	}
}
