package mobile;

import flixel.FlxG;
import flixel.input.FlxInput;
import flixel.input.IFlxInputManager;
import mobile.objects.TouchButton;

/**
 * Every virtual button the touch layer can report.
 * The first block is the D-pad / face buttons used in menus, the second block is gameplay.
 */
enum abstract MobileButtonID(Int) from Int to Int
{
	var UP = 0;
	var DOWN = 1;
	var LEFT = 2;
	var RIGHT = 3;
	var A = 4;
	var B = 5;
	var X = 6;
	var Y = 7;
	var NOTE_LEFT = 8;
	var NOTE_DOWN = 9;
	var NOTE_UP = 10;
	var NOTE_RIGHT = 11;
	var PAUSE = 12;
	var BOT_ENERGY = 13;
	var C = 14;
	var TOTAL = 15;
}

/**
 * Turns raw touches into one `FlxInput` per virtual button.
 *
 * It is registered in `FlxG.inputs`, so it is polled right before the state updates.
 * That keeps `justPressed` frame-accurate (no extra latency for rhythm input) and lets
 * `Controls` read the buttons like any other input device.
 *
 * Touches are checked against every registered `TouchButton`, so a finger that slides from one
 * hitbox lane to the next releases the old lane and presses the new one, and several fingers
 * can hold several lanes at the same time.
 */
class MobileInput implements IFlxInputManager
{
	public static var instance(default, null):MobileInput;

	static final inputs:Array<FlxInput<Int>> = [for (i in 0...(MobileButtonID.TOTAL : Int)) new FlxInput<Int>(i)];
	static final down:Array<Bool> = [for (i in 0...(MobileButtonID.TOTAL : Int)) false];
	static final buttons:Array<TouchButton> = [];
	static final claimed:Array<Bool> = [];
	static final point:flixel.math.FlxPoint = flixel.math.FlxPoint.get();

	/** Set from the options menu: short vibration when a button goes down. */
	public static var vibrate:Bool = false;

	public static function init():Void
	{
		if (instance != null)
			return;
		instance = new MobileInput();
		FlxG.inputs.add(instance);
	}

	public static inline function input(id:MobileButtonID):FlxInput<Int>
		return inputs[id];

	public static inline function pressed(id:MobileButtonID):Bool
		return inputs[id].pressed;

	public static inline function justPressed(id:MobileButtonID):Bool
		return inputs[id].justPressed;

	public static inline function justReleased(id:MobileButtonID):Bool
		return inputs[id].justReleased;

	public static function register(button:TouchButton):Void
	{
		if (buttons.contains(button))
			return;
		buttons.push(button);
		// higher priority first, so exclusive buttons (pause...) can claim touches before the lanes
		buttons.sort((a, b) -> b.priority - a.priority);
	}

	public static function unregister(button:TouchButton):Void
	{
		buttons.remove(button);
	}

	public static function releaseAll():Void
	{
		for (i in 0...inputs.length)
		{
			down[i] = false;
			inputs[i].reset();
		}
	}

	function new() {}

	public function update():Void
	{
		for (i in 0...down.length)
			down[i] = false;

		final touches = FlxG.touches.list;
		while (claimed.length < touches.length)
			claimed.push(false);
		for (i in 0...touches.length)
			claimed[i] = false;

		if (touches.length > 0)
		{
			for (button in buttons)
			{
				if (!button.exists || !button.touchEnabled)
					continue;

				final camera = button.camera;
				for (i in 0...touches.length)
				{
					final touch = touches[i];
					if (touch == null || !(touch.pressed || touch.justPressed))
						continue;
					if (claimed[i] && !button.exclusive)
						continue;

					touch.getPositionInCameraView(camera, point);
					if (button.containsView(point.x, point.y))
					{
						down[button.id] = true;
						if (button.exclusive)
							claimed[i] = true;
					}
				}
			}
		}

		// press()/release() first, update() after: this makes JUST_PRESSED last exactly one frame,
		// the same way FlxKeyboard behaves.
		var buzz:Bool = false;
		for (i in 0...inputs.length)
		{
			final input = inputs[i];
			if (down[i] && !input.pressed)
			{
				input.press();
				buzz = true;
			}
			else if (!down[i] && input.pressed)
				input.release();
			input.update();
		}

		#if mobile
		if (buzz && vibrate)
			lime.ui.Haptic.vibrate(0, 12);
		#end
	}

	public function reset():Void
		releaseAll();

	public function destroy():Void
	{
		releaseAll();
		buttons.resize(0);
	}

	public function onFocus():Void {}

	public function onFocusLost():Void
		releaseAll();
}
