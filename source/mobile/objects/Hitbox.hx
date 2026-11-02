package mobile.objects;

import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import mobile.MobileInput;

/**
 * Gameplay controls: four tall lanes that behave like the four arrow keys.
 *
 * Lanes are plain touch areas, so you can slide from lane to lane, hold sustains with one finger
 * and use all four lanes at once. A small pause button sits in the top-right corner and is
 * "exclusive", so tapping it never hits a note.
 */
class Hitbox extends FlxTypedGroup<TouchButton>
{
	/** Lane colours, left to right: purple, blue, green, red (same order as the note directions). */
	static final COLORS:Array<Int> = [0xC24B99, 0x00FFFF, 0x12FA05, 0xF9393F];

	public var lanes(default, null):Array<TouchButton> = [];
	public var pauseButton(default, null):TouchButton;
	public var extraButton(default, null):TouchButton;

	/**
	 * @param alpha     idle opacity of the lanes (0 hides them but they keep working)
	 * @param style     0 = gradient, 1 = flat, 2 = outline only
	 * @param bottomOnly true = lanes cover the lower part of the screen only, false = the whole screen
	 * @param extra     adds the Bot Energy button
	 */
	public function new(alpha:Float, style:Int, bottomOnly:Bool, extra:Bool)
	{
		super();

		final laneW = Std.int(FlxG.width / 4);
		final laneH = bottomOnly ? Std.int(FlxG.height * 0.62) : FlxG.height;
		final top = FlxG.height - laneH;
		final ids:Array<MobileButtonID> = [NOTE_LEFT, NOTE_DOWN, NOTE_UP, NOTE_RIGHT];

		for (i in 0...4)
		{
			final lane = new TouchButton(i * laneW, top, ids[i], MobileGraphics.hitboxLane(laneW, laneH, COLORS[i], style));
			lane.pressedScale = 1; // lanes should not shrink, they tile the screen
			lane.pressedAlpha = Math.min(1, alpha + 0.45);
			lane.setIdleAlpha(alpha);
			lane.antialiasing = false;
			lanes.push(lane);
			add(lane);
		}

		pauseButton = new TouchButton(FlxG.width - 96 - 14, 14, PAUSE, MobileGraphics.pauseButton(96));
		pauseButton.priority = 10;
		pauseButton.exclusive = true;
		pauseButton.hitPadding = 14;
		pauseButton.pressedScale = 0.9;
		pauseButton.setIdleAlpha(0.75);
		add(pauseButton);

		if (extra)
		{
			extraButton = new TouchButton(14, 14, BOT_ENERGY, MobileGraphics.letterButton(96, 'E', 0xFFD29922));
			extraButton.priority = 10;
			extraButton.exclusive = true;
			extraButton.hitPadding = 14;
			extraButton.setIdleAlpha(0.7);
			add(extraButton);
		}
	}

	public function setActive(value:Bool):Void
	{
		visible = value;
		active = value;
		for (button in members)
			if (button != null)
			{
				button.touchEnabled = value;
				button.visible = value;
			}
	}

	public function assignCamera(camera:FlxCamera):Void
	{
		cameras = [camera];
		for (button in members)
			if (button != null)
				button.cameras = [camera];
	}
}
