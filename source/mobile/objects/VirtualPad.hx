package mobile.objects;

import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import mobile.MobileInput;

enum PadMode
{
	/** no pad at all */
	NONE;

	/** D-pad + A + B (the default for menus) */
	FULL;

	/** D-pad + A + B + X + Y + C (menus that have extra shortcuts, like Freeplay) */
	FULL_EXTRA;

	/** only A and B */
	AB;

	/** only A */
	A_ONLY;

	/** only the D-pad */
	DPAD;
}

/**
 * On-screen D-pad and face buttons for menus.
 *
 * Layout is in game coordinates (1280x720). Because everything is drawn on its own camera, the pad
 * stays on top of every state and substate and is not affected by their camera effects.
 */
class VirtualPad extends FlxTypedGroup<TouchButton>
{
	public var mode(default, null):PadMode;

	public var buttonUp:TouchButton;
	public var buttonDown:TouchButton;
	public var buttonLeft:TouchButton;
	public var buttonRight:TouchButton;
	public var buttonA:TouchButton;
	public var buttonB:TouchButton;
	public var buttonX:TouchButton;
	public var buttonY:TouchButton;
	public var buttonC:TouchButton;

	public function new(mode:PadMode, alpha:Float)
	{
		super();
		this.mode = mode;

		final S = 108; // d-pad button size
		final cx = 20 + S * 1.5; // d-pad centre x
		final cy = 720 - 20 - S * 1.5; // d-pad centre y

		if (mode == FULL || mode == FULL_EXTRA || mode == DPAD)
		{
			buttonUp = make(cx - S * .5, cy - S * 1.5, UP, MobileGraphics.arrowButton(S, 0));
			buttonDown = make(cx - S * .5, cy + S * .5, DOWN, MobileGraphics.arrowButton(S, 1));
			buttonLeft = make(cx - S * 1.5, cy - S * .5, LEFT, MobileGraphics.arrowButton(S, 2));
			buttonRight = make(cx + S * .5, cy - S * .5, RIGHT, MobileGraphics.arrowButton(S, 3));
		}

		final R = 128; // face button size
		final rx = 1280 - 20 - R;
		final ry = 720 - 20 - R;
		if (mode == FULL || mode == FULL_EXTRA || mode == AB || mode == A_ONLY)
			buttonA = make(rx, ry - 20, A, MobileGraphics.letterButton(R, 'A', 0xFF2EA043));
		if (mode == FULL || mode == FULL_EXTRA || mode == AB)
			buttonB = make(rx - R - 12, ry + 20, B, MobileGraphics.letterButton(R, 'B', 0xFFD73A49));
		if (mode == FULL_EXTRA)
		{
			buttonX = make(rx - R - 12, ry - R - 4, X, MobileGraphics.letterButton(R, 'X', 0xFF2F81F7));
			buttonY = make(rx, ry - R - 44, Y, MobileGraphics.letterButton(R, 'Y', 0xFFD29922));
			buttonC = make(rx - R * 2 - 24, ry + 20, C, MobileGraphics.letterButton(R, 'C', 0xFF8957E5));
		}

		setAlpha(alpha);
	}

	function make(x:Float, y:Float, id:MobileButtonID, graphic:flixel.graphics.FlxGraphic):TouchButton
	{
		final button = new TouchButton(x, y, id, graphic);
		button.hitPadding = 8; // fingers are bigger than the drawn button
		add(button);
		return button;
	}

	public function setAlpha(value:Float):Void
	{
		for (button in members)
			if (button != null)
				button.setIdleAlpha(value);
	}

	/** Shows/hides the pad and keeps `MobileInput` from reading touches on a hidden pad. */
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
