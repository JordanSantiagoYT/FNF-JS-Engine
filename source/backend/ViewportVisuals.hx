package backend;

import flixel.FlxG;
import flixel.FlxSprite;

/** Layout for full-screen artwork and solid overlays (never non-uniformly stretch art). */
class ViewportVisuals
{
	/** Cover the viewport with a menu image; preserve its aspect ratio. */
	public static function cover(sprite:FlxSprite, minimumScale:Float = 1):Void
	{
		if (sprite == null || sprite.frameWidth <= 0 || sprite.frameHeight <= 0) return;
		final scale:Float = Math.max(minimumScale, Math.max(FlxG.width / sprite.frameWidth, FlxG.height / sprite.frameHeight));
		sprite.scale.set(scale, scale);
		sprite.updateHitbox();
		sprite.screenCenter();
	}

	/** Cover camera zoom/rotation, even on an ultrawide viewport, with a solid stage flash. */
	public static function overscan(sprite:FlxSprite):Void
	{
		if (sprite == null) return;
		sprite.setPosition(-FlxG.width, -FlxG.height);
		sprite.setGraphicSize(FlxG.width * 3, FlxG.height * 3);
		sprite.updateHitbox();
	}

	/** Expand an opaque/solid rectangle to the current viewport. */
	public static function fill(sprite:FlxSprite, height:Int = -1):Void
	{
		if (sprite == null) return;
		sprite.setGraphicSize(FlxG.width, height < 0 ? FlxG.height : height);
		sprite.updateHitbox();
	}
}
