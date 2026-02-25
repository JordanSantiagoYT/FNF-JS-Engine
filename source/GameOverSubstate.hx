package;

import Character.Boyfriend;

class GameOverSubstate extends MusicBeatSubstate
{
	public var boyfriend:Character;
	public var genericCharacter:FlxSprite; 
	private var camFollow:FlxPoint;
	private var camFollowPos:FlxObject;

	var stagePostfix:String = "";

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';
	public static var deathDelay:Float = 0;
	
	public static var genericName:String;
	public static var genericSound:String;
	public static var genericMusic:String;

	public static var instance:GameOverSubstate;
	var parentPlayState:PlayState = null; // assuring PlayState isn't null
	public function new(?char:Character, ps:PlayState)
	{
		super();
		this.parentPlayState = ps;

		if (char == null)
		{
			trace("GameOverSubstate: No character passed. Using generic fallback.");
			doGenericGameOver();
			return;
		}

		createDeathCharacter(char, parentPlayState);
	}
	
	function createDeathCharacter(char:Character, game:PlayState)
	{
		var deathName:String = characterName != null 
			? characterName 
			: char.curCharacter + "-dead";

		boyfriend = new Character(
			char.x - char.positionArray[0],
			char.y - char.positionArray[1],
			deathName,
			char.isPlayer
		);

		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];

		add(boyfriend);

		camFollow = FlxPoint.get();
		camFollow.set(
			boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0],
			boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]
		);
		camFollowPos = new FlxObject(game.camFollowPos.x, game.camFollowPos.y);
		add(camFollowPos);
	}
	
	inline function startGeneric() {
		var tweens:Array<FlxTween> = [];
		inline function doTween(goals:Dynamic, dur:Float, ?props:flixel.tweens.FlxTween.TweenOptions)
			tweens.push(FlxTween.tween(genericCharacter, goals, dur, props));
		
		final frameDur:Float = 1/24;
		genericCharacter.alpha = 0.0;
		genericCharacter.scale.set(2.25, 2.25);

		doTween({"scale.x": 1.220, "scale.y": 1.220, alpha: 1}, 1, {ease: FlxEase.circIn});				
		doTween({"scale.x": 1.196, "scale.y": 1.196}, frameDur, {
			onComplete: (_)->{ 
				if (!isEnding) 
					FlxG.sound.play(Paths.sound(genericSound), false);
			}}
		);
		doTween({"scale.x": 1.1, "scale.y": 1.1}, frameDur*35);
		doTween({"scale.x": 1.0, "scale.y": 1.0}, frameDur * 60, {
			onStart: (_) ->{
				if (!isEnding)
					FlxG.sound.playMusic(Paths.music(genericMusic), 0.6, true);
				
				if (FlxG.sound.music != null)
					FlxG.sound.music.fadeIn(0.4, 0.6, 1.0);
			}
		});
		doTween({"scale.x": 1.01, "scale.y": 1.01}, frameDur * 24, {type: PINGPONG});
		
		for (i in 0...tweens.length-1)
			tweens[i].then(tweens[i+1]);
		tweens = null;
	}
	
	function doGenericGameOver()
	{
		genericCharacter = new FlxSprite(0, 0);
		genericCharacter.loadGraphic(Paths.image(genericName));
		genericCharacter.scrollFactor.set();
		genericCharacter.screenCenter();
		add(genericCharacter);

		camFollowPos = new FlxObject(FlxG.width / 2, FlxG.height / 2);
		add(camFollowPos);
	}

	public static function resetVariables() {
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		deathDelay = 0;
		
		genericName = 'characters/gameover/placeholder'; 
		genericSound = "gameoverGeneric";
		genericMusic = "";

		var _song = PlayState.SONG;
		if(_song != null)
		{
			if(_song.gameOverChar != null && _song.gameOverChar.trim().length > 0) characterName = _song.gameOverChar;
			if(_song.gameOverSound != null && _song.gameOverSound.trim().length > 0) deathSoundName = _song.gameOverSound;
			if(_song.gameOverLoop != null && _song.gameOverLoop.trim().length > 0) loopSoundName = _song.gameOverLoop;
			if(_song.gameOverEnd != null && _song.gameOverEnd.trim().length > 0) endSoundName = _song.gameOverEnd;
		}
	}
	
	inline function usingCharacter():Bool
	{
		return boyfriend != null;
	}

	var charX:Float = 0;
	var charY:Float = 0;

	var overlay:FlxSprite;
	var overlayConfirmOffsets:FlxPoint = FlxPoint.get();
	override function create()
	{
		instance = this;

		Conductor.songPosition = 0;

		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		if (usingCharacter())
		{
			boyfriend.skipDance = true;
			add(boyfriend);

			FlxG.sound.play(Paths.sound(deathSoundName));
			boyfriend.playAnim('firstDeath');
		}
		else
		{
			startGeneric(); // play generic animation
		}
		if (camFollow == null)
		{
			camFollow = FlxPoint.get(
				FlxG.camera.scroll.x + FlxG.camera.width * 0.5,
				FlxG.camera.scroll.y + FlxG.camera.height * 0.5
			);
		}
		camFollowPos = new FlxObject(camFollow.x, camFollow.y, 1, 1);
		add(camFollowPos);

		FlxG.camera.follow(camFollowPos, LOCKON, 0.01);
		FlxG.camera.focusOn(camFollow);

		parentPlayState.setOnLuas('inGameOver', true);
		parentPlayState.callOnLuas('onGameOverStart', []);
		FlxG.sound.music.loadEmbedded(Paths.music(loopSoundName), true);
		
		if (usingCharacter())
		{
			if(characterName == 'pico-dead')
			{
				overlay = new FlxSprite(boyfriend.x + 205, boyfriend.y - 80);
				overlay.frames = Paths.getSparrowAtlas('Pico_Death_Retry');
				overlay.animation.addByPrefix('deathLoop', 'Retry Text Loop', 24, true);
				overlay.animation.addByPrefix('deathConfirm', 'Retry Text Confirm', 24, false);
				overlay.antialiasing = ClientPrefs.globalAntialiasing;
				overlayConfirmOffsets.set(250, 200);
				overlay.visible = false;
				add(overlay);

				boyfriend.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
				{
					switch(name)
					{
						case 'firstDeath':
							if(frameNumber >= 36 - 1)
							{
								overlay.visible = true;
								overlay.animation.play('deathLoop');
								boyfriend.animation.callback = null;
							}
						default:
							boyfriend.animation.callback = null;
					}
				}

				if(parentPlayState.gf != null && parentPlayState.gf.curCharacter == 'nene')
				{
					var neneKnife:FlxSprite = new FlxSprite(boyfriend.x - 450, boyfriend.y - 250);
					neneKnife.frames = Paths.getSparrowAtlas('NeneKnifeToss');
					neneKnife.animation.addByPrefix('anim', 'knife toss', 24, false);
					neneKnife.antialiasing = ClientPrefs.globalAntialiasing;
					neneKnife.animation.finishCallback = function(_)
					{
						neneKnife.visible = false;

						new FlxTimer().start(0.01, function(tmr:FlxTimer) {
							if(neneKnife != null) {
								remove(neneKnife);
								neneKnife.destroy();
							}
						});
					}
					insert(0, neneKnife);
					neneKnife.animation.play('anim', true);
				}
			}
		}

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		parentPlayState.callOnLuas('onUpdate', [elapsed]);

		var justPlayedLoop:Bool = false;
		if (usingCharacter())
		{
			if (!boyfriend.isAnimationNull()
				&& boyfriend.getAnimationName() == 'firstDeath'
				&& boyfriend.isAnimationFinished())
			{
				boyfriend.playAnim('deathLoop');

				if (overlay != null && overlay.animation.exists('deathLoop'))
				{
					overlay.visible = true;
					overlay.animation.play('deathLoop');
				}

				coolStartDeath();
			}
			justPlayedLoop = true;
		}

		if(!isEnding)
		{
			if (controls.ACCEPT)
			{
				endGameOver();
			}
			else if (controls.BACK)
			{
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
				FlxG.camera.visible = false;
				FlxG.sound.music.stop();
				PlayState.deathCounter = 0;
				PlayState.seenCutscene = false;
				PlayState.chartingMode = false;

				WeekData.loadTheFirstEnabledMod();
				if (PlayState.isStoryMode)
					FlxG.switchState(new StoryMenuState());
				else
					FlxG.switchState(new FreeplayState());

				FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
				parentPlayState.callOnLuas('onGameOverConfirm', [false]);
			}
			else if (justPlayedLoop)
			{
				switch(PlayState.SONG.stage)
				{
					case 'tank':
						coolStartDeath(0.2);

						var exclude:Array<Int> = [];

						FlxG.sound.play(Paths.sound('jeffGameover/jeffGameover-' + FlxG.random.int(1, 25, exclude)), 1, false, null, true, function() {
							if(!isEnding)
							{
								FlxG.sound.music.fadeIn(0.2, 1, 4);
							}
						});

					default:
						coolStartDeath();
				}
			}

			if (FlxG.sound.music.playing)
			{
				Conductor.songPosition = FlxG.sound.music.time;
			}
		}
		parentPlayState.callOnLuas('onUpdatePost', [elapsed]);
	}

	var isEnding:Bool = false;
	function coolStartDeath(?volume:Float = 1):Void
	{
		FlxG.sound.music.play(true);
		FlxG.sound.music.volume = volume;
	}

	function endGameOver():Void
	{
		if (!isEnding)
		{
			isEnding = true;
			if (usingCharacter())
			{
				if (boyfriend.hasAnimation('deathConfirm'))
					boyfriend.playAnim('deathConfirm', true);
				else if (boyfriend.hasAnimation('deathLoop'))
					boyfriend.playAnim('deathLoop', true);
			}
			else if (genericCharacter != null)
			{
				FlxTween.cancelTweensOf(genericCharacter);
				FlxTween.tween(genericCharacter,
					{alpha: 0, "scale.x": 0, "scale.y": 0},
					0.8,
					{ease: FlxEase.quadIn}
				);
			}

			if(overlay != null && overlay.animation.exists('deathConfirm'))
			{
				overlay.visible = true;
				overlay.animation.play('deathConfirm');
				overlay.offset.set(overlayConfirmOffsets.x, overlayConfirmOffsets.y);
			}
			FlxG.sound.music.stop();
			try {FlxG.sound.play(Paths.music(endSoundName));}
			catch(e) {trace('Failed to play the end track!');}

			new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
				{
					FlxG.resetState();
				});
			});
			parentPlayState.callOnLuas('onGameOverConfirm', [true]);
		}
	}

	override function destroy()
	{
		instance = null;
		if (camFollow != null)
			camFollow.put();
		
		super.destroy();
	}
}
