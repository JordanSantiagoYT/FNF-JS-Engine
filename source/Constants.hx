package;

import flixel.system.FlxBasePreloader;
import flixel.util.FlxColor;

/**
 * A store of unchanging, globally relevant values.
 */
@:nullSafety
class Constants
{
  /**
	 * Preloader sitelock.
	 * Matching is done by `FlxStringUtil.getDomain`, so any URL on the domain will work.
	 * The first link in this list is the one users will be redirected to if they try to access the game from a different URL.
	 */
	public static final SITE_LOCK:Array<String> = [
		"https://github.com/JordanSantiagoYT/FNF-JS-Engine/releases/latest", // GitHub, baybee!
		FlxBasePreloader.LOCAL // localhost for dev stuff
	];

	/**
	 * LANGUAGE
	 */
	// ==============================
	public static final SITE_LOCK_TITLE:String = "You Loser!";

	public static final SITE_LOCK_DESC:String = "Go play JS Engine on here:";

  /**
   * The base colors used by notes.
   */
  public static var COLOR_NOTES:Array<FlxColor> = [
    0xFFFF22AA, // left (0)
    0xFF00EEFF, // down (1)
    0xFF00CC00, // up (2)
    0xFFCC1111 // right (3)
  ];

  /**
   * Color for the preloader background
   */
  public static final COLOR_PRELOADER_BG:FlxColor = 0xFF000000;

  /**
   * Color for the preloader progress bar
   */
  public static final COLOR_PRELOADER_BAR:FlxColor = 0xFFA4FF11;

  /**
   * Color for the preloader site lock background
   */
  public static final COLOR_PRELOADER_LOCK_BG:FlxColor = 0xFF1B1717;

  /**
   * Color for the preloader site lock foreground
   */
  public static final COLOR_PRELOADER_LOCK_FG:FlxColor = 0xB96F10;

  /**
   * Color for the preloader site lock text
   */
  public static final COLOR_PRELOADER_LOCK_FONT:FlxColor = 0xCCCCCC;

  /**
   * Color for the preloader site lock link
   */
  public static final COLOR_PRELOADER_LOCK_LINK:FlxColor = 0xEEB211;

  /**
   * Each step of the preloader has to be on screen at least this long.
   *
   * 0 = The preloader immediately moves to the next step when it's ready.
   * 1 = The preloader waits for 1 second before moving to the next step.
   *     The progress bare is automatically rescaled to match.
   */
  public static final PRELOADER_MIN_STAGE_TIME:Float = 0.1;
}
