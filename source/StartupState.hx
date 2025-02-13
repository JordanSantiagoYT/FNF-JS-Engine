package;

import flixel.input.keyboard.FlxKey;

class StartupState extends MusicBeatState
{
	var logo:FlxSprite;
	var skipTxt:FlxText;

	var maxIntros:Int = 6;
	var date:Date = Date.now();

	var canChristmas = false;

	private var vidSprite:VideoSprite = null;
	private function startVideo(name:String, ?library:String = null, ?callback:Void->Void = null, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		var foundFile:Bool = false;
		var fileName:String = Paths.video(name, library);

		#if sys
		if (FileSystem.exists(fileName))
		#else
		if (OpenFlAssets.exists(fileName))
		#end
		foundFile = true;

		if (foundFile)
		{
			vidSprite = new VideoSprite(fileName, false, canSkip, loop);

			// Finish callback
			function onVideoEnd()
			{
				FlxG.switchState(TitleState.new);
				vidSprite?.destroy();
				if (vidSprite != null)
					vidSprite = null;
			}
			vidSprite.finishCallback = (callback != null) ? callback.bind() : onVideoEnd;
			vidSprite.onSkip = (callback != null) ? callback.bind() : onVideoEnd;
			insert(0, vidSprite);

			if (playOnLoad)
				vidSprite.videoSprite.play();
			return vidSprite;
		}
		else {
			FlxG.log.error("Video not found: " + fileName);
			new FlxTimer().start(0.1, function(tmr:FlxTimer) {
				doIntro();
			});
		}
		#else
		FlxG.log.warn('Platform not supported!');
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			doIntro();
		});
		#end
		return null;
	}

	override public function create():Void
	{
		if (date.getMonth() == 11 && date.getDate() >= 16 && date.getDate() <= 31) //Only triggers if the date is between 12/16 and 12/31
		{
			canChristmas = true;
			maxIntros += 1; //JOLLY SANTA!!!
		}

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		logo = new FlxSprite().loadGraphic(Paths.image('sillyLogo', 'splash'));
		logo.scrollFactor.set();
		logo.screenCenter();
		logo.alpha = 0;
		logo.active = true;
		add(logo);

		skipTxt = new FlxText(0, FlxG.height, 0, 'Press ENTER To Skip', 16);
		skipTxt.setFormat("Comic Sans MS Bold", 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		skipTxt.borderSize = 1.5;
		skipTxt.antialiasing = true;
		skipTxt.scrollFactor.set();
		skipTxt.alpha = 0;
		skipTxt.y -= skipTxt.textField.textHeight;
		if (vidSprite != null)
			insert(1, skipTxt);
		else
			add(skipTxt);

		FlxTween.tween(skipTxt, {alpha: 1}, 1);

		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			doIntro();
		});

		super.create();
	}

	function onIntroDone(?fadeDelay:Float = 0) {
		FlxTween.tween(logo, {alpha: 0}, 1, {
			startDelay: fadeDelay,
			ease: FlxEase.linear,
			onComplete: function(_) {
				FlxG.switchState(TitleState.new);
			}
		});
	}

	function doIntro() {
		#if debug // for testing purposes
			startVideo('broCopiedDenpa', 'splash');
		#else
		final debugShit = true;
		final theIntro:Int = FlxG.random.int(0, maxIntros);
		if (debugShit)
			startVideo('bambiStartup', 'splash'); // shit was crashing & I don't feel like making debug builds :P
		else
		{
			switch (theIntro) {
				case 0:
					FlxG.sound.play(Paths.sound('startup', 'splash'));
					logo.scale.set(0.1,0.1);
					logo.updateHitbox();
					logo.screenCenter();
					FlxTween.tween(logo, {alpha: 1, "scale.x": 1, "scale.y": 1}, 0.95, {ease: FlxEase.expoOut, onComplete: _ -> onIntroDone()});
				case 1:
					FlxG.sound.play(Paths.sound('startup', 'splash'));
					FlxG.sound.play(Paths.sound('FIREINTHEHOLE', 'splash'));
					logo.loadGraphic(Paths.image('lobotomy', 'splash'));
					logo.scale.set(0.1,0.1);
					logo.updateHitbox();
					logo.screenCenter();
					FlxTween.tween(logo, {alpha: 1, "scale.x": 1, "scale.y": 1}, 1.35, {ease: FlxEase.expoOut, onComplete: _ -> onIntroDone()});
				case 2:
					FlxG.sound.play(Paths.sound('screwedEngine', 'splash'));
					logo.loadGraphic(Paths.image('ScrewedLogo', 'splash'));
					logo.scale.set(0.1,0.1);
					logo.updateHitbox();
					logo.screenCenter();
					FlxTween.tween(logo, {alpha: 1, "scale.x": 1, "scale.y": 1}, 1.35, {ease: FlxEase.expoOut, onComplete: _ -> onIntroDone(0.6)});
				case 3:
					// secret muaahahhahhahaahha
					FlxG.sound.play(Paths.sound('tada', 'splash'));
					logo.loadGraphic(Paths.image('JavaScriptLogo', 'splash'));
					logo.scale.set(0.1,0.1);
					logo.updateHitbox();
					logo.screenCenter();
					FlxTween.tween(logo, {alpha: 1, "scale.x": 1, "scale.y": 1}, 1.35, {ease: FlxEase.expoOut, onComplete: _ -> onIntroDone(0.6)});
				case 4:
					startVideo('bambiStartup', 'splash');
				case 5:
					startVideo('broCopiedDenpa', 'splash');
				case 6:
					if (canChristmas)
					{
						FlxG.sound.play(Paths.sound('JollySanta', 'splash'));
						logo.loadGraphic(Paths.image('JollySantaLogo', 'splash'));
						logo.scale.set(0.1,0.1);
						logo.updateHitbox();
						logo.screenCenter();
						FlxTween.tween(logo, {alpha: 1, "scale.x": 1, "scale.y": 1}, 2, {ease: FlxEase.expoOut, onComplete: _ -> onIntroDone(1.5)});
					} 
					else 
						doIntro();
			}
		}
		#end
	}

	override function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.ENTER) FlxG.switchState(TitleState.new);
		super.update(elapsed);
	}
}
