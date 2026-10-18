package stages;
import backend.ClientPrefs;
import backend.ViewportVisuals;
import backend.Paths;
import objects.BGSprite;
import play.BaseStage;

import objects.Character;
import objects.Note;

class Spooky extends BaseStage
{
	var halloweenBG:BGSprite;
	var halloweenWhite:BGSprite;
	var lightningFlash:FlxSprite;

	override public function onViewportResize():Void
	{
		ViewportVisuals.overscan(halloweenWhite);
		ViewportVisuals.overscan(lightningFlash);
	}

	override function create()
	{
		if(!ClientPrefs.lowQuality) {
			halloweenBG = new BGSprite('halloween_bg', -200, -100, ['halloweem bg0', 'halloweem bg lightning strike']);
		} else {
			halloweenBG = new BGSprite('halloween_bg_low', -200, -100);
		}
		add(halloweenBG);

		//PRECACHE SOUNDS
		Paths.sound('thunder_1');
		Paths.sound('thunder_2');

		//Monster cutscene
		if (isStoryMode && !seenCutscene)
		{
			switch(songName)
			{
				case 'monster':
					setStartCallback(monsterCutscene);
			}
		}
	}
	override function createPost()
	{
		halloweenWhite = new BGSprite(null, 0, 0, 0, 0);
		halloweenWhite.makeGraphic(1, 1, FlxColor.WHITE);
		ViewportVisuals.overscan(halloweenWhite);
		halloweenWhite.alpha = 0;
		halloweenWhite.blend = ADD;
		add(halloweenWhite);
	}

	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;
	override function beatHit()
	{
		if (FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset)
		{
			lightningStrike();
		}
	}

	function lightningStrike():Void
	{
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
		if(!ClientPrefs.lowQuality) halloweenBG.animation.play('halloweem bg lightning strike');

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if(boyfriend.animOffsets.exists('scared')) {
			boyfriend.playAnim('scared');
		}

		if(dad.animOffsets.exists('scared')) {
			dad.playAnim('scared');
		}

		if(gf != null && gf.animOffsets.exists('scared')) {
			gf.playAnim('scared', true);
		}

		if(ClientPrefs.camZooms) {
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;

			if(!game.camZooming) { //Just a way for preventing it to be permanently zoomed until Skid & Pump hits a note
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 0.5);
				FlxTween.tween(camHUD, {zoom: 1}, 0.5);
			}
		}

		if(ClientPrefs.flashing) {
			halloweenWhite.alpha = 0.4;
			FlxTween.tween(halloweenWhite, {alpha: 0.5}, 0.075);
			FlxTween.tween(halloweenWhite, {alpha: 0}, 0.25, {startDelay: 0.15});
		}
	}

	function monsterCutscene()
	{
		inCutscene = true;
		camHUD.visible = false;

		FlxG.camera.focusOn(new FlxPoint(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100));

		// character anims
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
		if(gf != null) gf.playAnim('scared', true);
		boyfriend.playAnim('scared', true);

		// white flash
		lightningFlash = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		ViewportVisuals.overscan(lightningFlash);
		lightningFlash.scrollFactor.set();
		lightningFlash.blend = ADD;
		add(lightningFlash);
		FlxTween.tween(lightningFlash, {alpha: 0}, 1, {
			startDelay: 0.1,
			ease: FlxEase.linear,
			onComplete: function(twn:FlxTween)
			{
				remove(lightningFlash);
				lightningFlash.destroy();
				lightningFlash = null;

				camHUD.visible = true;
				startCountdown();
			}
		});
	}
}
