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
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import mobile.flixel.FlxButton;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;

/**
 * A zone with 4 hint's (A hitbox).
 * It's really easy to customize the layout.
 */
class FlxHitbox extends FlxSpriteGroup
{
	private var laneCount:Int;
	private var laneColors:Array<FlxColor>;
	private var fillsViewport:Bool;
	private var requestedWidth:Int;
	private var requestedHeight:Int;
	private var layoutWidth:Int;
	private var layoutHeight:Int;

	public var hints(default, null):Array<FlxButton>;

	/**
	 * Create the zone.
	 *
	 * @param ammo The ammount of hints you want to create.
	 * @param perHintWidth The width that the hints will use.
	 * @param perHintHeight The height that the hints will use.
	 * @param colors The color per hint.
	 */
	public function new(ammo:UInt, perHintWidth:Int, perHintHeight:Int, colors:Array<FlxColor>):Void
	{
		super();

		hints = [];
		laneCount = Std.int(ammo);
		requestedWidth = perHintWidth * laneCount;
		requestedHeight = perHintHeight;
		// Preserve deliberately smaller mod hitboxes. The built-in 4-lane
		// hitbox uses floor(width/4); give its last lane the remainder too.
		fillsViewport = laneCount > 0 && perHintWidth == Std.int(FlxG.width / laneCount) && perHintHeight == FlxG.height;
		laneColors = colors != null && colors.length >= laneCount ? colors : [for (i in 0...laneCount) FlxColor.WHITE];
		layoutWidth = fillsViewport ? FlxG.width : requestedWidth;
		layoutHeight = fillsViewport ? FlxG.height : requestedHeight;

		if (laneCount > 0 && layoutWidth >= laneCount && layoutHeight > 0)
		{
			final extraHeight:Int = ScreenLayout.hitboxExtraHeight(layoutHeight, ClientPrefs.mobileCEx);
			final mainHeight:Int = layoutHeight - extraHeight;
			final mainY:Int = extraHeight > 0 && !ClientPrefs.hitboxPos ? extraHeight : 0;
			for (i in 0...laneCount)
			{
				final start:Int = ScreenLayout.laneStart(i, laneCount, layoutWidth);
				final end:Int = ScreenLayout.laneStart(i + 1, laneCount, layoutWidth);
				add(hints[i] = createHint(start, mainY, end - start, mainHeight, laneColors[i]));
			}
			if (extraHeight > 0)
				add(hints[laneCount] = createHint(0, ClientPrefs.hitboxPos ? mainHeight : 0, layoutWidth, extraHeight, 0xFF0066FF));
		}

		scrollFactor.set();
		FlxG.signals.gameResized.add(onGameResized);
	}

	private function onGameResized(_:Int, _:Int):Void
	{
		if (fillsViewport) updateLayout(FlxG.width, FlxG.height);
	}

	/** Rebuild the graphics and hit tests together, without replacing bound buttons. */
	public function updateLayout(width:Int, height:Int):Void
	{
		if (width <= 0 || height <= 0 || laneCount <= 0 || width < laneCount || hints.length < laneCount) return;
		final extraHeight:Int = ScreenLayout.hitboxExtraHeight(height, ClientPrefs.mobileCEx);
		final mainY:Int = extraHeight > 0 && !ClientPrefs.hitboxPos ? extraHeight : 0;
		final mainHeight:Int = height - extraHeight;

		// The preference can change before the next orientation/window resize.
		// Keep the actual fifth button in sync so no dead quarter is left behind.
		if (extraHeight > 0 && hints.length == laneCount)
		{
			final extra = createHint(0, ClientPrefs.hitboxPos ? mainHeight : 0, width, extraHeight, 0xFF0066FF);
			// FlxSpriteGroup.add() does not inherit the parent's visibility.
			// A hidden gameplay hitbox must not accept touch during a resize.
			extra.visible = hints[0].visible;
			add(hints[laneCount] = extra);
		}
		else if (extraHeight == 0 && hints.length > laneCount)
		{
			final extra:FlxButton = hints.pop();
			remove(extra, true);
			extra.destroy();
		}

		for (i in 0...laneCount)
		{
			final start:Int = ScreenLayout.laneStart(i, laneCount, width);
			final end:Int = ScreenLayout.laneStart(i + 1, laneCount, width);
			final hint:FlxButton = hints[i];
			if (hint.width != end - start || hint.height != mainHeight)
				hint.loadGraphic(createHintGraphic(end - start, mainHeight, laneColors[i]));
			hint.setPosition(start, mainY);
		}
		if (extraHeight > 0)
		{
			final extra:FlxButton = hints[laneCount];
			if (extra.width != width || extra.height != extraHeight)
				extra.loadGraphic(createHintGraphic(width, extraHeight, 0xFF0066FF));
			extra.setPosition(0, ClientPrefs.hitboxPos ? mainHeight : 0);
		}
		layoutWidth = width;
		layoutHeight = height;
	}

	/** Clean up memory and the resize listener when the owning state closes. */
	override public function destroy():Void
	{
		FlxG.signals.gameResized.remove(onGameResized);
		super.destroy(); // FlxSpriteGroup destroys its children.
		hints.splice(0, hints.length);
	}

	private function createHint(X:Float, Y:Float, Width:Int, Height:Int, Color:Int = 0xFFFFFF):FlxButton
	{
		final pressAlpha:Float = ClientPrefs.mobileCAlpha >= 0.9 ? ClientPrefs.mobileCAlpha - 0.2 : ClientPrefs.mobileCAlpha;
		// Keep the zones faintly visible at rest so players can see where to press.
		// ("Hidden" hitboxes stay invisible and give no press feedback.)
		final restAlpha:Float = (ClientPrefs.hitboxType == "Hidden") ? 0.00001 : ClientPrefs.mobileCAlpha * 0.35;
		var hint:FlxButton = new FlxButton(X, Y);
		hint.loadGraphic(createHintGraphic(Width, Height, Color));
		hint.solid = false;
		hint.multiTouch = true;
		hint.immovable = true;
		hint.moves = false;
		hint.antialiasing = ClientPrefs.globalAntialiasing;
		hint.scrollFactor.set();
		hint.alpha = restAlpha;
		if (ClientPrefs.hitboxType != "Hidden")
		{
			hint.onDown.callback = function()
			{
				if (hint.alpha != pressAlpha)
					hint.alpha = pressAlpha;
			}
			hint.onUp.callback = function()
			{
				if (hint.alpha != restAlpha)
					hint.alpha = restAlpha;
			}
			hint.onOut.callback = function()
			{
				if (hint.alpha != restAlpha)
					hint.alpha = restAlpha;
			}
		}
		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end
		return hint;
	}

	private function createHintGraphic(Width:Int, Height:Int, Color:Int = 0xFFFFFF):BitmapData
	{
		var guh:Float = ClientPrefs.mobileCAlpha;
		if (guh >= 0.9)
			guh = ClientPrefs.mobileCAlpha - 0.07;
		var shape:Shape = new Shape();
		shape.graphics.beginFill(Color);
		if (ClientPrefs.hitboxType == "No Gradient")
		{
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(Width, Height, 0, 0, 0);

			shape.graphics.beginGradientFill(RADIAL, [Color, Color], [0, guh], [60, 255], matrix, PAD, RGB, 0);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.endFill();
		}
		else if (ClientPrefs.hitboxType == "No Gradient (Old)")
		{
			shape.graphics.lineStyle(10, Color, 1);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.endFill();
		}
		else
		{
			shape.graphics.lineStyle(3, Color, 1);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.lineStyle(0, 0, 0);
			shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
			shape.graphics.endFill();
			shape.graphics.beginGradientFill(RADIAL, [Color, FlxColor.TRANSPARENT], [guh, 0], [0, 255], null, null, null, 0.5);
			shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
			shape.graphics.endFill();
		}
		var bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape, true);
		return bitmap;
	}
}
