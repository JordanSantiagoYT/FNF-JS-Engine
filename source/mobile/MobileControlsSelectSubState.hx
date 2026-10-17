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
import backend.ViewportVisuals;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.input.touch.FlxTouch;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import mobile.flixel.FlxButton;
import mobile.flixel.FlxHitbox;
import mobile.flixel.FlxVirtualPad;
import openfl.utils.Assets;

class MobileControlsSelectSubState extends FlxSubState
{
	private final controlsItems:Array<String> = ClientPrefs.mobileCPlayStateVpad ? ['Pad-Right', 'Pad-Left', 'Pad-Custom', 'Hitbox'] : ['Hitbox'];

	private var virtualPad:FlxVirtualPad;
	private var hitbox:FlxHitbox;
	private var background:FlxSprite;
	private var exitButton:FlxButton;
	private var upPosition:FlxText;
	private var downPosition:FlxText;
	private var leftPosition:FlxText;
	private var rightPosition:FlxText;
	private var exPosition:FlxText;
	private var grpControls:FlxText;
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;
	private var curSelected:Int = 0;
	private var buttonBinded:Bool = false;
	private var bindButton:FlxButton;
	private var resetButton:FlxButton;

	override function create()
	{
		for (i in 0...controlsItems.length)
			if (controlsItems[i] == MobileControls.mode)
				curSelected = i;

		background = new FlxSprite(0, 0).makeGraphic(1, 1,
			FlxColor.fromRGB(FlxG.random.int(0, 255), FlxG.random.int(0, 255), FlxG.random.int(0, 255)));
		ViewportVisuals.fill(background);
		background.scrollFactor.set();
		background.alpha = 0.4;
		add(background);

		exitButton = new FlxButton(FlxG.width - 200, 50, 'Exit', function()
		{
			MobileControls.mode = controlsItems[Math.floor(curSelected)];

			if (controlsItems[Math.floor(curSelected)] == 'Pad-Custom')
				MobileControls.customVirtualPad = virtualPad;

			FlxTransitionableState.skipNextTransOut = FlxTransitionableState.skipNextTransIn = true;
			FlxG.resetState();
		});
		exitButton.setGraphicSize(Std.int(exitButton.width) * 3);
		exitButton.label.setFormat("VCR OSD Mono", 21, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		exitButton.color = FlxColor.LIME;
		add(exitButton);

		resetButton = new FlxButton(exitButton.x, exitButton.y + 100, 'Reset', function()
		{
			if (controlsItems[Math.floor(curSelected)] == 'Pad-Custom' && resetButton.visible)
			{
				final defaults = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.mobileCEx);
				MobileControls.customVirtualPad = defaults;
				defaults.destroy();
				reloadMobileControls('Pad-Custom');
			}
		});
		resetButton.setGraphicSize(Std.int(resetButton.width) * 3);
		resetButton.label.setFormat("VCR OSD Mono", 21, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		resetButton.color = FlxColor.RED;
		resetButton.visible = false;
		add(resetButton);

		grpControls = new FlxText(0, 100, 0, '', 32);
		grpControls.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		grpControls.borderSize = 3;
		grpControls.borderQuality = 1;
		grpControls.screenCenter(X);
		add(grpControls);

		leftArrow = new FlxSprite(grpControls.x - 60, grpControls.y - 25);
		leftArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		leftArrow.animation.addByPrefix('idle', 'arrow left');
		leftArrow.animation.play('idle');
		add(leftArrow);

		rightArrow = new FlxSprite(grpControls.x + grpControls.width + 10, grpControls.y - 25);
		rightArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.play('idle');
		add(rightArrow);

		rightPosition = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, FlxG.height - 24, 0, '', 16);
		rightPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		rightPosition.borderSize = 3;
		rightPosition.borderQuality = 1;
		add(rightPosition);

		leftPosition = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, FlxG.height - 44, 0, '', 16);
		leftPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		leftPosition.borderSize = 3;
		leftPosition.borderQuality = 1;
		add(leftPosition);

		downPosition = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, FlxG.height - 64, 0, '', 16);
		downPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		downPosition.borderSize = 3;
		downPosition.borderQuality = 1;
		add(downPosition);

		upPosition = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, FlxG.height - 84, 0, '', 16);
		upPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		upPosition.borderSize = 3;
		upPosition.borderQuality = 1;
		add(upPosition);

		exPosition = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, FlxG.height - 104, 0, '', 16);
		exPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		exPosition.borderSize = 3;
		exPosition.borderQuality = 1;
		add(exPosition);

		changeSelection();

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];

		super.create();
	}

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.fill(background);
		if (exitButton != null) exitButton.x = FlxG.width - 200;
		if (resetButton != null) resetButton.x = FlxG.width - 200;
		if (grpControls != null)
		{
			grpControls.screenCenter(X);
			if (leftArrow != null) leftArrow.x = grpControls.x - 60;
			if (rightArrow != null) rightArrow.x = grpControls.x + grpControls.width + 10;
		}
		for (text in [upPosition, downPosition, leftPosition, rightPosition, exPosition])
			if (text != null) text.x = ScreenLayout.contentLeft(FlxG.width) + 10;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		for (touch in FlxG.touches.list)
		{
			if (touch.overlaps(leftArrow) && touch.justPressed)
				changeSelection(-1);
			else if (touch.overlaps(rightArrow) && touch.justPressed)
				changeSelection(1);

			if (controlsItems[Math.floor(curSelected)] == 'Pad-Custom')
			{
				if (buttonBinded)
				{
					if (touch.justReleased)
					{
						bindButton = null;
						buttonBinded = false;
					}
					else
						moveButton(touch, bindButton);
				}
				else
				{
					virtualPad.forEachAlive((button:FlxButton) ->
					{
						if (button.justPressed)
							moveButton(touch, button);
					});
				}
				virtualPad.forEachAlive((button:FlxButton) ->
				{
					if (button != bindButton && buttonBinded)
					{
						bindButton.centerBounds();
						button.bounds.immovable = true;
						bindButton.bounds.immovable = false;
						button.centerBounds();
						FlxG.overlap(bindButton.bounds, button.bounds, function(a:Dynamic, b:Dynamic)
						{
							bindButton.centerInBounds();
							button.centerBounds();
							bindButton.bounds.immovable = true;
							button.bounds.immovable = false;
						}, function(a:Dynamic, b:Dynamic)
						{
							if (!bindButton.bounds.immovable)
							{
								if (bindButton.bounds.x > button.bounds.x)
									bindButton.bounds.x = button.bounds.x + 100;
								else
									bindButton.bounds.x = button.bounds.x - 100;

								if (bindButton.bounds.y > button.bounds.y)
									bindButton.bounds.y = button.bounds.y + 55;
								else if (bindButton.bounds.y != button.bounds.y)
									bindButton.bounds.y = button.bounds.y - 55;
							}
							return true;
						});
					}
				});
			}
		}

		if (virtualPad != null && controlsItems[Math.floor(curSelected)] == 'Pad-Custom')
		{
			if (virtualPad.buttonUp != null)
				upPosition.text = 'Button Up X:' + virtualPad.buttonUp.x + ' Y:' + virtualPad.buttonUp.y;

			if (virtualPad.buttonDown != null)
				downPosition.text = 'Button Down X:' + virtualPad.buttonDown.x + ' Y:' + virtualPad.buttonDown.y;

			if (virtualPad.buttonLeft != null)
				leftPosition.text = 'Button Left X:' + virtualPad.buttonLeft.x + ' Y:' + virtualPad.buttonLeft.y;

			if (virtualPad.buttonRight != null)
				rightPosition.text = 'Button Right X:' + virtualPad.buttonRight.x + ' Y:' + virtualPad.buttonRight.y;

			if (virtualPad.buttonEx != null)
				exPosition.text = 'Button Extra X:' + virtualPad.buttonEx.x + ' Y:' + virtualPad.buttonEx.y;
		}
	}

	private function changeSelection(change:Int = 0):Void
	{
		curSelected += change;

		if (curSelected < 0)
			curSelected = controlsItems.length - 1;
		else if (curSelected >= controlsItems.length)
			curSelected = 0;

		grpControls.text = controlsItems[Math.floor(curSelected)];
		grpControls.screenCenter(X);

		leftArrow.x = grpControls.x - 60;
		rightArrow.x = grpControls.x + grpControls.width + 10;

		var daChoice:String = controlsItems[Math.floor(curSelected)];

		reloadMobileControls(daChoice);

		resetButton.visible = daChoice == 'Pad-Custom';
		upPosition.visible = daChoice == 'Pad-Custom';
		downPosition.visible = daChoice == 'Pad-Custom';
		leftPosition.visible = daChoice == 'Pad-Custom';
		rightPosition.visible = daChoice == 'Pad-Custom';
		exPosition.visible = daChoice == 'Pad-Custom';
	}

	private function moveButton(touch:FlxTouch, button:FlxButton):Void
	{
		bindButton = button;
		bindButton.x = touch.x - Std.int(bindButton.width / 2);
		bindButton.y = touch.y - Std.int(bindButton.height / 2);

		if (!buttonBinded)
			buttonBinded = true;
	}

	private function reloadMobileControls(daChoice:String):Void
	{
		switch (daChoice)
		{
			case 'Pad-Right':
				removeControls();
				virtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.mobileCEx);
				add(virtualPad);
			case 'Pad-Left':
				removeControls();
				virtualPad = new FlxVirtualPad(LEFT_FULL, NONE, ClientPrefs.mobileCEx);
				add(virtualPad);
			case 'Pad-Custom':
				removeControls();
				virtualPad = MobileControls.customVirtualPad;
				add(virtualPad);
			case 'Hitbox':
				removeControls();
				hitbox = new FlxHitbox(4, Std.int(FlxG.width / 4), FlxG.height, [0xFF00FF, 0x00FFFF, 0x00FF00, 0xFF0000]);
				add(hitbox);
			default:
				removeControls();
		}

		if (virtualPad != null)
			virtualPad.visible = (daChoice != 'Hitbox');

		if (hitbox != null)
			hitbox.visible = (daChoice == 'Hitbox');
	}

	private function removeControls():Void
	{
		if (virtualPad != null)
		{
			remove(virtualPad);
			virtualPad.destroy();
			virtualPad = null;
		}

		if (hitbox != null)
		{
			remove(hitbox);
			hitbox.destroy();
			hitbox = null;
		}
	}
}
