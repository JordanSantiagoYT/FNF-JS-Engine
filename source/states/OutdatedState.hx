package states;

import backend.ClientPrefs;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.MusicBeatState;
import backend.Paths;
import flixel.addons.display.FlxBackdrop;
import flixel.effects.FlxFlicker;
import flixel.util.FlxAxes;
#if !flash
import lime.app.Application;
#end
import openfl.display.BlendMode;

import backend.Controls;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	public static var currChanges:String = "dk";

	var warnText:FlxText;
	var changelog:FlxText;
	var updateText:FlxText;
	var checker:FlxBackdrop;
	var bg:FlxSprite;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(bg, 1.1);
		if (warnText != null) { warnText.fieldWidth = FlxG.width; warnText.screenCenter(X); }
		if (changelog != null) changelog.x = ScreenLayout.contentLeft(FlxG.width) + 100;
		if (updateText != null) updateText.fieldWidth = FlxG.width - 20;
	}

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		MusicBeatState.windowNameSuffix2 = " (Outdated!)";

		super.create();

		bg = new FlxSprite(0, 0).loadGraphic(Paths.image("aboutMenu", "preload"));
		bg.color = 0xFFffd700;
		ViewportVisuals.cover(bg, 1.1);
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
			"HEY! Your Phoenix Engine is outdated!\n"
			+ 'v' + MainMenuState.phoenixEngineVersion + ' < v' + TitleState.updateVersion + '\n'
			,32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		warnText.screenCenter(X);
		add(warnText);

		changelog = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 100, warnText.y + warnText.height + 20, 1080, currChanges, 16);
		changelog.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(changelog);

		updateText = new FlxText(0, 10, FlxG.width,
			mobile.MobileControls.enabled ? "Press A to go to GitHub to update, or B to ignore this!"
			: "Press SPACE/ENTER to go to GitHub to update, or ESCAPE to ignore this!"
			,24);
		updateText.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		updateText.y = 710 - updateText.height;
		updateText.x = 10;
		add(updateText);

		addVirtualPad(NONE, A_B);
	}

	override function update(elapsed:Float)
	{
		checker.x += 0.45 / (ClientPrefs.framerate / 60);
		checker.y += (0.16 / (ClientPrefs.framerate / 60));
		if(!leftState) {
			if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || controls.ACCEPT) {
				CoolUtil.browserLoad("https://github.com/havaianasdestruido/FNF-Phoenix-Engine/releases/latest");
			}
			else if(controls.BACK) {
				leftState = true;
			}

			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				for (i in members)
					FlxTween.tween(i, {alpha: 0}, 1, {
						onComplete: function (twn:FlxTween) {
							FlxG.switchState(MainMenuState.new);
						}
					});
			}
		}
		super.update(elapsed);
	}
}
