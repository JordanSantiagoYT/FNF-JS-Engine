package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.addons.display.FlxBackdrop;
import openfl.display.BlendMode;
import flixel.util.FlxAxes;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	public static var currChanges:String = "dk";

	var warnText:FlxText;
	var changelog:FlxText;
	var updateText:FlxText;
	var checker:FlxBackdrop;
	var bg:FlxSprite;
	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		MusicBeatState.windowNameSuffix2 = " (Outdated!)";

		super.create();

		bg = new FlxSprite(0, 0).loadGraphic(Paths.image("aboutMenu", "preload"));
		bg.color = 0xFFffd700;
		bg.scale.set(1.1, 1.1);
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		checker = new FlxBackdrop(Paths.image('checker', 'preload'), FlxAxes.XY);
		checker.scale.set(4, 4);
		checker.color = 0xFFb8860b;
		checker.blend = BlendMode.LAYER;
		add(checker);
		checker.scrollFactor.set(0, 0.07);
		checker.alpha = 0.2;
		checker.updateHitbox();

		warnText = new FlxText(0, 10, FlxG.width,
			"HEY! Your Patos Engine is outdated!\n"
			+ 'v' + MainMenuState.psychEngineJSVersion + ' < v' + TitleState.updateVersion + '\n'
			,32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		warnText.screenCenter(X);
		add(warnText);

		changelog = new FlxText(100, warnText.y + warnText.height + 20, 1080, currChanges, 16);
		changelog.setFormat(Paths.font("vcr.ttf"), Std.int(16), FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(changelog);

		updateText = new FlxText(0, 10, FlxG.width,
			"Press SPACE to view the full changelog, ENTER to update or ESCAPE to ignore this!"
			,24);
		updateText.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			updateText.y = 710 - updateText.height;
			updateText.x = 10;
		add(updateText);
	}

	override function update(elapsed:Float)
	{
		checker.x += 0.45 / (ClientPrefs.framerate / 60);
		checker.y += (0.16 / (ClientPrefs.framerate / 60));
		if(!leftState) {
			if (FlxG.keys.justPressed.ENTER) {
				leftState = true;
				#if windows FlxG.switchState(UpdateState.new);
				#else
				CoolUtil.browserLoad("https://github.com/PatoFlamejanteTV/FNF-Patos-Engine/releases/latest");
				#end
			}
			if (FlxG.keys.justPressed.SPACE) {
				CoolUtil.browserLoad("https://github.com/PatoFlamejanteTV/FNF-Patos-Engine/releases/latest");
			}
			else if(controls.BACK) {
				leftState = true;
			}

			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						FlxG.switchState(MainMenuState.new);
					}
				});
				FlxTween.tween(changelog, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						FlxG.switchState(MainMenuState.new);
					}
				});
				FlxTween.tween(updateText, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						FlxG.switchState(MainMenuState.new);
					}
				});
				FlxTween.tween(checker, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						FlxG.switchState(MainMenuState.new);
					}
				});
				FlxTween.tween(bg, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						FlxG.switchState(MainMenuState.new);
					}
				});
			}
		}
		super.update(elapsed);
	}
}
