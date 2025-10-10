package;

import MusicBeatState;
import flixel.system.FlxBasePreloader;
import flixel.util.FlxColor;
import lime.app.Application;

class Constants
{
  // MORE MIGHT BE ADDED LATER THIS IS JUST SOMETHING!!!!

	/**
	 * Preloader sitelock.
	 * Matching is done by `FlxStringUtil.getDomain`, so any URL on the domain will work.
	 * The first link in this list is the one users will be redirected to if they try to access the game from a different URL.
	 */
	public static final SITE_LOCK:Array<String> = [
		"https://github.com/JordanSantiagoYT/FNF-JS-Engine/releases", // GitHub, baybee!
		FlxBasePreloader.LOCAL // localhost for dev stuff
	];

	/**
	 * LANGUAGE
	 */
	// ==============================
	public static final SITE_LOCK_TITLE:String = "You Loser!";

	public static final SITE_LOCK_DESC:String = "Go play JS Engine on here:";
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
	 * The horizontal offset of the strumline from the left edge of the screen.
	 */
	public static final STRUMLINE_X_OFFSET:Float = 48;

	/**
	 * The vertical offset of the strumline from the top edge of the screen.
	 */
	public static final STRUMLINE_Y_OFFSET:Float = 24;

	/**
   * The amount, in percent, to scale the icon by when bopping.
   */
  static final BOP_SCALE:Float = 0.2;

	/**
	 * Color for the preloader site lock foreground
	 */
	public static final COLOR_PRELOADER_LOCK_FG:FlxColor = 0xB96F10;

	/**
	 * The title of the game, for debug printing purposes.
	 * Change this if you're making an engine.
	 */
	public static final TITLE:String = "Friday Night Funkin': JS Engine";

	/**
	 * Color for the preloader site lock text
	 */
	public static final COLOR_PRELOADER_LOCK_FONT:FlxColor = 0xCCCCCC;

	/**
	 * Color for the preloader site lock link
	 */
	public static final COLOR_PRELOADER_LOCK_LINK:FlxColor = 0xEEB211;

	/**
	 * A suffix to add to the game version.
	 * Add a suffix to prototype builds and remove it for releases.
	 */
	public static final VERSION_SUFFIX:String = #if debug ' PROTOTYPE' #else '' #end;

	/**
	 * Each step of the preloader has to be on screen at least this long.
	 *
	 * 0 = The preloader immediately moves to the next step when it's ready.
	 * 1 = The preloader waits for 1 second before moving to the next step.
	 *     The progress bare is automatically rescaled to match.
	 */
	public static final PRELOADER_MIN_STAGE_TIME:Float = 0.1;
}
