package mobile.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import mobile.backend.AssetExtractor;

/**
 * First state on phones. Copies the game files out of the APK when needed (first launch / new build),
 * shows progress, then hands over to the normal `InitState`.
 *
 * It only uses code-drawn graphics and flixel's built-in font, since the assets it is preparing
 * are not available as files yet.
 */
class MobileInitState extends FlxState
{
	var extractor:AssetExtractor;
	var bar:FlxSprite;
	var barBack:FlxSprite;
	var title:FlxText;
	var info:FlxText;
	var skipFrames:Int = 2; // let one frame draw before the heavy work starts

	override function create():Void
	{
		super.create();
		FlxG.autoPause = false;
		bgColor = 0xFF101018;

		if (!AssetExtractor.needed())
		{
			FlxG.switchState(() -> new InitState());
			return;
		}

		extractor = new AssetExtractor();

		title = new FlxText(0, 250, FlxG.width, "Preparing game files", 40);
		title.alignment = CENTER;
		add(title);

		info = new FlxText(60, 480, FlxG.width - 120, "This only happens the first time\n(and after an update).", 24);
		info.alignment = CENTER;
		info.color = 0xFFAAAAAA;
		add(info);

		barBack = new FlxSprite((FlxG.width - 760) / 2, 400).makeGraphic(760, 28, 0xFF2A2A38);
		add(barBack);
		bar = new FlxSprite(barBack.x, barBack.y).makeGraphic(760, 28, 0xFF5CE08A);
		bar.origin.set(0, 0);
		bar.scale.x = 0;
		add(bar);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (extractor == null)
			return;

		if (skipFrames > 0)
		{
			skipFrames--;
			return;
		}

		extractor.step();

		final progress = extractor.total == 0 ? 1.0 : extractor.done / extractor.total;
		bar.scale.x = progress;
		title.text = 'Preparing game files  ${Std.int(progress * 100)}%';

		if (extractor.error != null)
		{
			title.text = "Something went wrong";
			title.color = FlxColor.RED;
			info.text = extractor.error;
			info.color = FlxColor.WHITE;
			extractor = null;
		}
		else if (extractor.finished)
		{
			extractor = null;
			FlxG.switchState(() -> new InitState());
		}
	}
}
