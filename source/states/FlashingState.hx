package states;

import backend.ClientPrefs;
import backend.ViewportVisuals;
import backend.MusicBeatState;
import backend.Paths;
import flixel.effects.FlxFlicker;
#if !flash
import lime.app.Application;
#end

import backend.Controls;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;
	var background:FlxSprite;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.fill(background);
		if (warnText != null)
		{
			warnText.fieldWidth = FlxG.width;
			warnText.screenCenter(Y);
		}
	}

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		MusicBeatState.windowNameSuffix = " - Flashing Lights Warning Screen";

		super.create();

		background = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		ViewportVisuals.fill(background);
		add(background);

		warnText = new FlxText(0, 0, FlxG.width,
			"Hey, watch out!\n
			This Mod contains some flashing lights!\n
			Press ENTER to disable them now or go to Options Menu.\n
			Press ESCAPE to ignore this message.\n
			You've been warned!",
			32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);

		addVirtualPad(NONE, A_B);
	}

	override function update(elapsed:Float)
	{
		if(!leftState) {
			var back:Bool = controls.BACK;
			if (controls.ACCEPT || back) {
				leftState = true;
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				if(!back) {
					ClientPrefs.flashing = false;
					ClientPrefs.saveSettings();
					FlxG.sound.play(Paths.sound('confirmMenu'));
					FlxFlicker.flicker(warnText, 1, 0.1, false, true, function(flk:FlxFlicker) {
						new FlxTimer().start(0.5, function (tmr:FlxTimer) {
							FlxG.switchState(TitleState.new);
						});
					});
				} else {
					FlxG.sound.play(Paths.sound('cancelMenu'));
					FlxTween.tween(warnText, {alpha: 0}, 1, {
						onComplete: function (twn:FlxTween) {
							FlxG.switchState(TitleState.new);
						}
					});
				}
			}
		}
		super.update(elapsed);
	}
}
