package;

/**
 * A store of unchanging, globally relevant values.
 */
@:nullSafety
class Constants
{
  /**
   *
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
}
