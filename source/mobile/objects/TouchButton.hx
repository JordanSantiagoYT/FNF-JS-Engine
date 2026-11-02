package mobile.objects;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import mobile.MobileInput;

/**
 * A screen area that reports touches to `MobileInput`.
 * It never reads the touches itself: `MobileInput` tests every registered button once per frame.
 */
class TouchButton extends FlxSprite
{
	public var id:MobileButtonID;

	/** Buttons with a higher priority get to look at the touches first. */
	public var priority:Int = 0;

	/** An exclusive button takes the touches it catches away from the buttons below it. */
	public var exclusive:Bool = false;

	/** When false the button is ignored by `MobileInput` (used when a layer is hidden). */
	public var touchEnabled:Bool = true;

	/** Extra touch area around the sprite, in game pixels. */
	public var hitPadding:Float = 0;

	public var idleAlpha:Float = 0.6;
	public var pressedAlpha:Float = 1.0;

	/** Scale applied while the button is held (a tiny "pressed" cue that costs nothing). */
	public var pressedScale:Float = 0.92;

	var wasPressed:Bool = false;

	public function new(x:Float, y:Float, id:MobileButtonID, graphic:FlxGraphic)
	{
		super(x, y);
		this.id = id;
		loadGraphic(graphic);
		scrollFactor.set();
		moves = false;
		immovable = true;
		alpha = idleAlpha;
		antialiasing = true;
		MobileInput.register(this);
	}

	public inline function containsView(px:Float, py:Float):Bool
	{
		return px >= x - hitPadding && px <= x + width + hitPadding && py >= y - hitPadding && py <= y + height + hitPadding;
	}

	override function update(elapsed:Float):Void
	{
		// no super.update(): the button has no animation and does not move, so skipping it is free
		final isPressed = MobileInput.pressed(id) && touchEnabled;
		if (isPressed != wasPressed)
		{
			wasPressed = isPressed;
			alpha = isPressed ? pressedAlpha : idleAlpha;
			final s = isPressed ? pressedScale : 1.0;
			scale.set(s, s);
		}
	}

	/** Re-applies the idle alpha (used when the alpha option changes). */
	public function setIdleAlpha(value:Float):Void
	{
		idleAlpha = value;
		if (!wasPressed)
			alpha = value;
	}

	override function destroy():Void
	{
		MobileInput.unregister(this);
		super.destroy();
	}
}
