package stages;
import backend.ClientPrefs;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.Paths;
import objects.BGSprite;
import play.BaseStage;
import play.PlayState;

import objects.DialogueBox;
import states.substates.GameOverSubstate;
import stages.objects.*;


class School extends BaseStage
{
	var bgGirls:BackgroundGirls;
	var introBlack:FlxSprite;
	override public function onViewportResize():Void
		ViewportVisuals.overscan(introBlack);

	override function create()
	{
		var _song = PlayState.SONG;
		GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
		GameOverSubstate.loopSoundName = 'gameOver-pixel';
		GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
		GameOverSubstate.characterName = 'bf-pixel-dead';

		var bgSky:BGSprite = new BGSprite('weeb/weebSky', 0, 0, 0.1, 0.1);
		add(bgSky);
		bgSky.antialiasing = false;

		var repositionOffset = -200;

		var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', repositionOffset, 0, 0.6, 0.90);
		add(bgSchool);
		bgSchool.antialiasing = false;

		var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', repositionOffset, 0, 0.95, 0.95);
		add(bgStreet);
		bgStreet.antialiasing = false;

		var scaledWidth = Std.int(bgSky.width * PlayState.daPixelZoom);
		if(!ClientPrefs.lowQuality) {
			var fgTrees:BGSprite = new BGSprite('weeb/weebTreesBack', repositionOffset + 170, 130, 0.9, 0.9);
			fgTrees.setGraphicSize(Std.int(scaledWidth * 0.8));
			fgTrees.updateHitbox();
			add(fgTrees);
			fgTrees.antialiasing = false;
		}

		var bgTrees:FlxSprite = new FlxSprite(repositionOffset - 380, -800);
		bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
		bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
		bgTrees.animation.play('treeLoop');
		bgTrees.scrollFactor.set(0.85, 0.85);
		add(bgTrees);
		bgTrees.antialiasing = false;

		if(!ClientPrefs.lowQuality) {
			var treeLeaves:BGSprite = new BGSprite('weeb/petals', repositionOffset, -40, 0.85, 0.85, ['PETALS ALL'], true);
			treeLeaves.setGraphicSize(scaledWidth);
			treeLeaves.updateHitbox();
			add(treeLeaves);
			treeLeaves.antialiasing = false;
		}

		bgSky.setGraphicSize(scaledWidth);
		bgSchool.setGraphicSize(scaledWidth);
		bgStreet.setGraphicSize(scaledWidth);
		bgTrees.setGraphicSize(Std.int(scaledWidth * 1.4));

		bgSky.updateHitbox();
		bgSchool.updateHitbox();
		bgStreet.updateHitbox();
		bgTrees.updateHitbox();

		if(!ClientPrefs.lowQuality) {
			bgGirls = new BackgroundGirls(-100, 190);
			bgGirls.scrollFactor.set(0.9, 0.9);
			add(bgGirls);
		}
		setDefaultGF('gf-pixel');

		if(isStoryMode && !seenCutscene)
		{
			switch (songName)
			{
				case 'senpai':
					FlxG.sound.playMusic(Paths.music('Lunchbox'), 0);
					FlxG.sound.music.fadeIn(1, 0, 0.8);
				case 'roses':
					FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'));
			}
			initDoof();
			setStartCallback(schoolIntro);
		}
	}

	override function beatHit()
	{
		if(bgGirls != null) bgGirls.dance();
	}

	// For events
	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "BG Freaks Expression":
				if(bgGirls != null) bgGirls.swapDanceType();
		}
	}

	var doof:DialogueBox = null;
	function initDoof()
	{
		var file:String = Paths.txt(songName + '/' + songName + 'Dialogue'); //Checks for vanilla/Senpai dialogue
		trace(file);
		#if MODS_ALLOWED
		if (!FileSystem.exists(file))
		#else
		if (!OpenFlAssets.exists(file))
		#end
		{
			startCountdown();
			return;
		}

		doof = new DialogueBox(false, CoolUtil.coolTextFile(file));
		doof.cameras = [camHUD];
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = PlayState.instance.startNextDialogue;
		doof.skipDialogueThing = PlayState.instance.skipDialogue;
	}

	function schoolIntro():Void
	{
		inCutscene = true;
		introBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		ViewportVisuals.overscan(introBlack);
		introBlack.scrollFactor.set();
		if(songName == 'senpai') add(introBlack);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			introBlack.alpha -= 0.15;

			if (introBlack.alpha > 0)
				tmr.reset(0.3);
			else
			{
				if (doof != null)
					add(doof);
				else
					startCountdown();

				remove(introBlack);
				introBlack.destroy();
				introBlack = null;
			}
		});
	}
}
