package;

import flixel.addons.display.FlxBackdrop;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxAxes;
import openfl.display.BlendMode;

class RenderingDoneSubState extends MusicBeatSubstate {
	var background:FlxSprite;
	var RenderText:FlxText;
	var saveTxt:FlxText;

	var checker:FlxBackdrop;
	var timeTaken:Float = 0;

	public function new(timeTakenLol:Float) {
		super();
		FlxG.sound.music.volume = 1;

		timeTaken = timeTakenLol;
	}

	override public function create() {
		super.create();
		PlayState.stopRender();

		final leDate = Date.now();
		if (leDate.getHours() >= 6 && leDate.getHours() <= 18) {
			FlxG.sound.playMusic(Paths.music('PeggleCreditsOST'), 0);
		} else {
			FlxG.sound.playMusic(Paths.music('PeggleNightsProgressOST'), 0);
		}
		FlxG.sound.music.fadeIn(2, 0, 0.5);

		background = new FlxSprite(0, 0).loadGraphic(Paths.image('aboutMenu'));
		background.scale.set(1.1, 1.1);
		background.color = FlxColor.CYAN;
		background.scrollFactor.set();
		background.alpha = 0;
		background.updateHitbox();
		background.screenCenter();
		background.antialiasing = ClientPrefs.globalAntialiasing;
		add(background);

		checker = new FlxBackdrop(Paths.image('checker', 'preload'), FlxAxes.XY);
		checker.scale.set(4, 4);
		checker.color = 0xFFb8860b;
		checker.blend = BlendMode.LAYER;
		add(checker);
		checker.scrollFactor.set(0, 0.07);
		checker.alpha = 0.2;
		checker.updateHitbox();

		RenderText = new FlxText(0, 140, 0, '', 124);
		RenderText.text = "Rendering Complete!\n\nSong: " + PlayState.SONG.song + "\nTime Taken: " + CoolUtil.formatTime(timeTaken * 1000, 3) + "\nRendering finished on " + leDate;
		RenderText.scrollFactor.set();
		RenderText.setFormat(Paths.font("vcr.ttf"), 50, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		RenderText.updateHitbox();
		RenderText.screenCenter(X);
		add(RenderText);

		saveTxt = new FlxText(0, 540, 0, "Press ENTER to continue.\n" + #if windows 'You can find your video in ${ClientPrefs.renderPath}!' #else 'You can find your song to render in ${ClientPrefs.renderPath}!\nThe command to render can be found\nin the readme file, also located there!' #end, 124);
		saveTxt.scrollFactor.set();
		saveTxt.setFormat(Paths.font("vcr.ttf"), 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		saveTxt.updateHitbox();
		saveTxt.screenCenter(X);
		add(saveTxt);

		RenderText.alpha = saveTxt.alpha = 0;

		FlxTween.tween(background, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(RenderText, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.2});
		FlxTween.tween(saveTxt, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.2});
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		checker.x += 0.45 / (ClientPrefs.framerate / 60);
		checker.y += (0.16 / (ClientPrefs.framerate / 60));

		if (controls.ACCEPT) {
			FlxTween.tween(background, {alpha: 0}, 0.4, {ease: FlxEase.quartInOut});
			FlxTween.tween(RenderText, {alpha: 0}, 0.4, {ease: FlxEase.quartInOut});
			FlxTween.tween(saveTxt, {alpha: 0}, 0.4, {ease: FlxEase.quartInOut});
			FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
			if (PlayState.isStoryMode)
				FlxG.switchState(StoryMenuState.new);
			if (PlayState.chartingMode)
			{
				FlxG.switchState(new editors.ChartingState());
				PlayState.chartingMode = true;
			}
			else if (!PlayState.isStoryMode)
				FlxG.switchState(FreeplayState.new);
		}
	}
}
