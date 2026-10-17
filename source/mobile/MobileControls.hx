/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile;

import backend.ClientPrefs;
import backend.ScreenLayout;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxSignal;
import mobile.flixel.FlxButton;
import mobile.flixel.FlxHitbox;
import mobile.flixel.FlxVirtualPad;

class MobileControls extends FlxSpriteGroup
{
	public static var customVirtualPad(get, set):FlxVirtualPad;
	public static var mode(get, set):String;
	public static var enabled(get, never):Bool;

	public var virtualPad:FlxVirtualPad;
	public var hitbox:FlxHitbox;

	public function new()
	{
		super();

		switch (MobileControls.mode)
		{
			case 'Pad-Right':
				virtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.mobileCEx);
				add(virtualPad);
			case 'Pad-Left':
				virtualPad = new FlxVirtualPad(LEFT_FULL, NONE, ClientPrefs.mobileCEx);
				add(virtualPad);
			case 'Pad-Custom':
				virtualPad = MobileControls.customVirtualPad;
				add(virtualPad);
			case 'Hitbox':
				hitbox = new FlxHitbox(4, Std.int(FlxG.width / 4), FlxG.height, [0xFF00FF, 0x00FFFF, 0x00FF00, 0xFF0000]);
				add(hitbox);
		}
	}

	/**
	 * Sets the camera that draws the mobile controls and that their touch input is checked on.
	 *
	 * Flixel only forwards `cameras` to the direct members of a sprite group, so the buttons living
	 * inside `hitbox`/`virtualPad` would keep a `null` cameras list. In that case they are drawn and
	 * hit-tested on the default draw target (the gameplay camera), scrolling along with it.
	 *
	 * @param value The cameras the mobile controls should use.
	 */
	override function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		if (hitbox != null)
			hitbox.cameras = value;

		if (virtualPad != null)
			virtualPad.cameras = value;

		return super.set_cameras(value);
	}

	override public function destroy():Void
	{
		super.destroy(); // Children own their resize listeners; avoid destroying twice.
		virtualPad = null;
		hitbox = null;
	}

	private static function get_mode():String
	{
		if (FlxG.save.data.mobileCMode == null)
		{
			FlxG.save.data.mobileCMode = 'Hitbox';
			FlxG.save.flush();
		}

		return FlxG.save.data.mobileCMode;
	}

	private static function set_mode(mode:String = 'Hitbox'):String
	{
		FlxG.save.data.mobileCMode = mode;
		FlxG.save.flush();

		return mode;
	}

	private static function get_customVirtualPad():FlxVirtualPad
	{
		var virtualPad:FlxVirtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.mobileCEx);
		if (FlxG.save.data.buttons == null)
			return virtualPad;

		var tempCount:Int = 0;
		final savedWidth:Int = FlxG.save.data.buttonsWidth == null ? ScreenLayout.BASE_WIDTH : Std.int(FlxG.save.data.buttonsWidth);
		for (button in virtualPad)
		{
			if (tempCount < FlxG.save.data.buttons.length && FlxG.save.data.buttons[tempCount] != null)
			{
				button.x = ScreenLayout.anchoredPosition(FlxG.save.data.buttons[tempCount].x, savedWidth, FlxG.width, button.width);
				button.y = FlxG.save.data.buttons[tempCount].y;
			}
			tempCount++;
		}

		return virtualPad;
	}

	private static function set_customVirtualPad(virtualPad:FlxVirtualPad):FlxVirtualPad
	{
		FlxG.save.data.buttons = [for (button in virtualPad) FlxPoint.get(button.x, button.y)];
		// Legacy saves without this field were authored in the 1280-wide viewport.
		FlxG.save.data.buttonsWidth = FlxG.width;
		FlxG.save.flush();
		return virtualPad;
	}

	private static function get_enabled():Bool
		return ClientPrefs.mobileCAlpha >= 0.1;
}
