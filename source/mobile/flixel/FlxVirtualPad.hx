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

package mobile.flixel;

import backend.ClientPrefs;
import backend.ScreenLayout;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxTileFrames;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import mobile.flixel.FlxButton;
import openfl.display.BitmapData;
import openfl.utils.Assets;

enum FlxDPadMode
{
	UP_DOWN;
	LEFT_RIGHT;
	LEFT_FULL;
	RIGHT_FULL;
	BOTH_FULL;
	DIALOGUE_PORTRAIT_EDITOR;
	MENU_CHARACTER_EDITOR;
	NOTE_SPLASH_DEBUG;
	NONE;
}

enum FlxActionMode
{
	A;
	B;
	P;
	A_B;
	B_C;
	A_B_C;
	A_B_E;
	A_B_X_Y;
	A_B_C_X_Y;
	A_B_C_X_Y_Z;
	A_B_C_D_V_X_Y_Z;
	CHART_EDITOR;
	DIALOGUE_PORTRAIT_EDITOR;
	CHARACTER_EDITOR;
	MENU_CHARACTER_EDITOR;
	NOTE_SPLASH_DEBUG;
	NONE;
}

/**
 * A gamepad.
 * It's easy to customize the layout.
 */
class FlxVirtualPad extends FlxTypedSpriteGroup<FlxButton>
{
	private var layoutWidth:Int;

	public var buttonLeft:FlxButton = new FlxButton(0, 0);
	public var buttonUp:FlxButton = new FlxButton(0, 0);
	public var buttonRight:FlxButton = new FlxButton(0, 0);
	public var buttonDown:FlxButton = new FlxButton(0, 0);

	public var buttonLeft2:FlxButton = new FlxButton(0, 0);
	public var buttonUp2:FlxButton = new FlxButton(0, 0);
	public var buttonRight2:FlxButton = new FlxButton(0, 0);
	public var buttonDown2:FlxButton = new FlxButton(0, 0);

	public var buttonA:FlxButton = new FlxButton(0, 0);
	public var buttonB:FlxButton = new FlxButton(0, 0);
	public var buttonP:FlxButton = new FlxButton(0, 0);
	public var buttonC:FlxButton = new FlxButton(0, 0);
	public var buttonD:FlxButton = new FlxButton(0, 0);
	public var buttonE:FlxButton = new FlxButton(0, 0);
	public var buttonF:FlxButton = new FlxButton(0, 0);
	public var buttonG:FlxButton = new FlxButton(0, 0);
	public var buttonV:FlxButton = new FlxButton(0, 0);
	public var buttonX:FlxButton = new FlxButton(0, 0);
	public var buttonY:FlxButton = new FlxButton(0, 0);
	public var buttonZ:FlxButton = new FlxButton(0, 0);

	public var buttonEx:FlxButton = new FlxButton(0, 0);

	/**
	 * Create a gamepad.
	 *
	 * @param   DPadMode     The D-Pad mode. `LEFT_FULL` for example.
	 * @param   ActionMode   The action buttons mode. `A_B_C` for example.
	 */
	public function new(DPad:FlxDPadMode, Action:FlxActionMode, ?Extra:Bool = false):Void
	{
		super();

		switch (DPad)
		{
			case UP_DOWN:
				add(buttonUp = createButton(0, FlxG.height - 258, 'up', 0x00FF00));
				add(buttonDown = createButton(0, FlxG.height - 131, 'down', 0x00FFFF));
			case LEFT_RIGHT:
				add(buttonLeft = createButton(0, FlxG.height - 131, 'left', 0xFF00FF));
				add(buttonRight = createButton(127, FlxG.height - 131, 'right', 0xFF0000));
			case LEFT_FULL:
				add(buttonUp = createButton(105, FlxG.height - 356, 'up', 0x00FF00));
				add(buttonLeft = createButton(0, FlxG.height - 246, 'left', 0xFF00FF));
				add(buttonRight = createButton(207, FlxG.height - 246, 'right', 0xFF0000));
				add(buttonDown = createButton(105, FlxG.height - 131, 'down', 0x00FFFF));
			case RIGHT_FULL:
				add(buttonUp = createButton(FlxG.width - 258, FlxG.height - 404, 'up', 0x00FF00));
				add(buttonLeft = createButton(FlxG.width - 384, FlxG.height - 305, 'left', 0xFF00FF));
				add(buttonRight = createButton(FlxG.width - 132, FlxG.height - 305, 'right', 0xFF0000));
				add(buttonDown = createButton(FlxG.width - 258, FlxG.height - 197, 'down', 0x00FFFF));
			case BOTH_FULL:
				add(buttonUp = createButton(105, FlxG.height - 356, 'up', 0x00FF00));
				add(buttonLeft = createButton(0, FlxG.height - 246, 'left', 0xFF00FF));
				add(buttonRight = createButton(207, FlxG.height - 246, 'right', 0xFF0000));
				add(buttonDown = createButton(105, FlxG.height - 131, 'down', 0x00FFFF));
				add(buttonUp2 = createButton(FlxG.width - 258, FlxG.height - 404, 'up', 0x00FF00));
				add(buttonLeft2 = createButton(FlxG.width - 384, FlxG.height - 305, 'left', 0xFF00FF));
				add(buttonRight2 = createButton(FlxG.width - 132, FlxG.height - 305, 'right', 0xFF0000));
				add(buttonDown2 = createButton(FlxG.width - 258, FlxG.height - 197, 'down', 0xA100FFFF));
			case DIALOGUE_PORTRAIT_EDITOR:
				add(buttonUp = createButton(105, FlxG.height - 356, 'up', 0x00FF00));
				add(buttonLeft = createButton(0, FlxG.height - 246, 'left', 0xFF00FF));
				add(buttonRight = createButton(207, FlxG.height - 246, 'right', 0xFF0000));
				add(buttonDown = createButton(105, FlxG.height - 131, 'down', 0x00FFFF));
				add(buttonUp2 = createButton(105, 0, 'up', 0xFF12FA05));
				add(buttonLeft2 = createButton(0, 102, 'left', 0xFFC24B99));
				add(buttonRight2 = createButton(207, 102, 'right', 0xFFF9393F));
				add(buttonDown2 = createButton(105, 210, 'down', 0xFF00FFFF));
			case MENU_CHARACTER_EDITOR:
				add(buttonUp = createButton(105, 0, 'up', 0x00FF00));
				add(buttonLeft = createButton(0, 102, 'left', 0xFF00FF));
				add(buttonRight = createButton(207, 102, 'right', 0xFF0000));
				add(buttonDown = createButton(105, 210, 'down', 0x00FFFF));
			case NOTE_SPLASH_DEBUG:
				add(buttonUp = createButton(0, 125, 'up', 0xFF12FA05));
				add(buttonLeft = createButton(0, 0, 'left', 0xFFC24B99));
				add(buttonRight = createButton(127, 0, 'right', 0xFFF9393F));
				add(buttonDown = createButton(127, 125, 'down', 0xFF00FFFF));
				add(buttonUp2 = createButton(127, 393, 'up', 0xFF12FA05));
				add(buttonLeft2 = createButton(0, 393, 'left', 0xFFC24B99));
				add(buttonRight2 = createButton(FlxG.width - 135, 393, 'right', 0xFFF9393F));
				add(buttonDown2 = createButton(FlxG.width - 265, 393, 'down', 0xFF00FFFF));
			case NONE: // do nothing
		}

		switch (Action)
		{
			case A:
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case B:
				add(buttonB = createButton(FlxG.width - 132, FlxG.height - 131, 'b', 0xFFCB00));
			case P:
				add(buttonP = createButton(FlxG.width - 132, 0, 'p', 0xFFCB00));
			case A_B:
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case B_C:
				add(buttonC = createButton(FlxG.width - 262, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonB = createButton(FlxG.width - 132, FlxG.height - 131, 'b', 0xFFCB00));
			case A_B_C:
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_E:
				add(buttonE = createButton(FlxG.width - 392, FlxG.height - 131, 'e', 0xFF7D00));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_X_Y:
				add(buttonX = createButton(FlxG.width - 522, FlxG.height - 131, 'x', 0x99062D));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonY = createButton(FlxG.width - 392, FlxG.height - 131, 'y', 0x4A35B9));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_C_X_Y:
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonX = createButton(FlxG.width - 262, FlxG.height - 251, 'x', 0x99062D));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonY = createButton(FlxG.width - 132, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_C_X_Y_Z:
				add(buttonX = createButton(FlxG.width - 392, FlxG.height - 251, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, FlxG.height - 251, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case A_B_C_D_V_X_Y_Z:
				add(buttonV = createButton(FlxG.width - 522, FlxG.height - 251, 'v', 0x49A9B2));
				add(buttonD = createButton(FlxG.width - 522, FlxG.height - 131, 'd', 0x0078FF));
				add(buttonX = createButton(FlxG.width - 392, FlxG.height - 251, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, FlxG.height - 251, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case CHARACTER_EDITOR:
				add(buttonF = createButton(FlxG.width - 132, FlxG.height - 371, 'f', 0xB1FC00));
				add(buttonV = createButton(FlxG.width - 522, FlxG.height - 251, 'v', 0x49A9B2));
				add(buttonD = createButton(FlxG.width - 522, FlxG.height - 131, 'd', 0x0078FF));
				add(buttonX = createButton(FlxG.width - 392, FlxG.height - 251, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, FlxG.height - 251, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case CHART_EDITOR:
				add(buttonUp2 = createButton(FlxG.width - 652, FlxG.height - 251, 'up', 0x00FF00));
				add(buttonDown2 = createButton(FlxG.width - 652, FlxG.height - 131, 'down', 0x00FFFF));
				add(buttonF = createButton(FlxG.width - 132, FlxG.height - 371, 'f', 0xB1FC00));
				add(buttonG = createButton(FlxG.width - 262, FlxG.height - 371, 'g', 0x3D3722));
				add(buttonV = createButton(FlxG.width - 522, FlxG.height - 251, 'v', 0x49A9B2));
				add(buttonD = createButton(FlxG.width - 522, FlxG.height - 131, 'd', 0x0078FF));
				add(buttonX = createButton(FlxG.width - 392, FlxG.height - 251, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, FlxG.height - 131, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, FlxG.height - 251, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, FlxG.height - 131, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, FlxG.height - 251, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 131, 'a', 0xFF0000));
			case DIALOGUE_PORTRAIT_EDITOR:
				add(buttonX = createButton(FlxG.width - 392, 4, 'x', 0x99062D));
				add(buttonC = createButton(FlxG.width - 392, 129, 'c', 0x44FF00));
				add(buttonY = createButton(FlxG.width - 262, 4, 'y', 0x4A35B9));
				add(buttonB = createButton(FlxG.width - 262, 129, 'b', 0xFFCB00));
				add(buttonZ = createButton(FlxG.width - 132, 4, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, 129, 'a', 0xFF0000));
			case MENU_CHARACTER_EDITOR:
				add(buttonY = createButton(FlxG.width - 392, 4, 'y', 0x4A35B9));
				add(buttonX = createButton(FlxG.width - 522, 4, 'x', 0x99062D));
				add(buttonB = createButton(FlxG.width - 262, 4, 'b', 0xFFCB00));
				add(buttonA = createButton(FlxG.width - 132, 4, 'a', 0xFF0000));
			case NOTE_SPLASH_DEBUG:
				add(buttonB = createButton(FlxG.width - 258, FlxG.height - 135, 'b', 0xFFCB00));
				add(buttonE = createButton(FlxG.width - 132, 0, 'e', 0xFF7D00));
				add(buttonX = createButton(FlxG.width - 258, 0, 'x', 0x99062D));
				add(buttonY = createButton(FlxG.width - 132, 250, 'y', 0x4A35B9));
				add(buttonZ = createButton(FlxG.width - 258, 250, 'z', 0xCCB98E));
				add(buttonA = createButton(FlxG.width - 132, FlxG.height - 135, 'a', 0xFF0000));
				add(buttonC = createButton(FlxG.width - 132, 125, 'c', 0x44FF00));
				add(buttonV = createButton(FlxG.width - 258, 125, 'v', 0x49A9B2));
			case NONE: // do nothing
		}

		if (Extra) add(buttonEx = createButton((DPad == LEFT_FULL) ? FlxG.width - 131 : 0, 589, 'g', 0x3D3722));

		scrollFactor.set();
		// Right-edge buttons above use FlxG.width at construction; anchor their
		// existing positions only on subsequent viewport changes.
		layoutWidth = FlxG.width;
		FlxG.signals.gameResized.add(onGameResized);
	}

	private function onGameResized(_:Int, _:Int):Void
	{
		if (layoutWidth == FlxG.width) return;
		for (button in this)
			button.x = ScreenLayout.anchoredPosition(button.x, layoutWidth, FlxG.width, button.width);
		layoutWidth = FlxG.width;
	}

	/** Remove the listener; FlxTypedSpriteGroup owns the child buttons. */
	override public function destroy():Void
	{
		FlxG.signals.gameResized.remove(onGameResized);
		super.destroy();
	}

	private function createButton(X:Float, Y:Float, Graphic:String, Color:Int = 0xFFFFFF):FlxButton
	{
		var graphic:FlxGraphic;

		final path:String = 'shared:assets/shared/images/virtualpad/$Graphic.png';
		#if MODS_ALLOWED
		final modsPath:String = Paths.modsImages('virtualpad/$Graphic');
		if(sys.FileSystem.exists(modsPath))
			graphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(modsPath));
		else #end if(Assets.exists(path))
			graphic = FlxGraphic.fromBitmapData(Assets.getBitmapData(path));
		else
			graphic = FlxGraphic.fromBitmapData(Assets.getBitmapData('shared:assets/shared/images/virtualpad/default.png'));

		var button:FlxButton = new FlxButton(X, Y);
		button.frames = FlxTileFrames.fromGraphic(graphic, FlxPoint.get(Std.int(graphic.width / 2), graphic.height));
		button.solid = false;
		button.immovable = true;
		button.moves = false;
		button.scrollFactor.set();
		button.color = Color;
		button.antialiasing = ClientPrefs.globalAntialiasing;
		button.alpha = ClientPrefs.mobileCAlpha;
		#if FLX_DEBUG
		button.ignoreDrawDebug = true;
		#end
		return button;
	}
}
