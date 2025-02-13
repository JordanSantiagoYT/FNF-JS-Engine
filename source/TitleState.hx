package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import haxe.Json;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end
import options.GraphicsSettingsSubState;
//import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.system.ui.FlxSoundTray;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.Assets;

#if VIDEOS_ALLOWED
import VideoSprite;
#end

using StringTools;
typedef TitleData =
{

	titlex:Float,
	titley:Float,
	startx:Float,
	starty:Float,
	gfx:Float,
	gfy:Float,
	backgroundSprite:String,
	bpm:Int,
	endY:Float,
}
class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	public static var sarcasmEgg:String;
	public var inCutscene:Bool = false;
	var canPause:Bool = true;

	final sarcasmKeys:Array<String> = [
		'ANNOUNCER'
	];
	final allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	final allowedShit = ~/^[ABCDEFGHIJKLMNOPQRSTUVWXYZ]+$/;
	var sarcasmKeysBuffer:String = '';

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;
	
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	var mustUpdate:Bool = false;

	public static var titleJSON:TitleData;

	public static var updateVersion:String = '';

	override public function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		MusicBeatState.windowNameSuffix = " - Title Screen";
		// ???
		MusicBeatState.windowNameSuffix = "";

		MusicBeatState.windowNamePrefix = Assets.getText(Paths.txt("windowTitleBase", "preload"));

		curWacky = FlxG.random.getObject(getIntroTextShit());

		// DEBUG BULLSHIT

		swagShader = new ColorSwap();
		super.create();

		#if (CHECK_FOR_UPDATES)
		if(ClientPrefs.checkForUpdates && !closedState && !Main.askedToUpdate) {
			trace('checking for update');
			var http = new haxe.Http("https://raw.githubusercontent.com/JordanSantiagoYT/FNF-JS-Engine/main/THECHANGELOG.md");
			var returnedData:Array<String> = [];

			http.onData = function (data:String)
			{
    				var versionEndIndex:Int = data.indexOf(';');
    				returnedData[0] = data.substring(0, versionEndIndex);

    				// Extract the changelog after the version number
    				returnedData[1] = data.substring(versionEndIndex + 1, data.length);
				updateVersion = returnedData[0];
				var curVersion:String = MainMenuState.psychEngineJSVersion.trim();
				trace('version online: ' + updateVersion + ', your version: ' + curVersion);
				if(updateVersion != curVersion) {
					trace('versions arent matching!');
					OutdatedState.currChanges = returnedData[1];
					mustUpdate = true;
					Main.askedToUpdate = true;
				}
				if(updateVersion == curVersion) {
					trace('the versions match!');
				}
			}

			http.onError = function (error) {
				trace('error: $error');
			}

			http.request();
		}
		#end

		Highscore.load();

		// IGNORE THIS!!!
		titleJSON = Json.parse(Paths.getTextFromFile('images/gfDanceTitle.json'));

		if(!initialized)
		{
			if(FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		FlxG.mouse.visible = false;
		#if FREEPLAY
		FlxG.switchState(FreeplayState.new);
		#elseif CHARTING
		FlxG.switchState(ChartingState.new);
		#else
		if(FlxG.save.data.flashing == null && !FlashingState.leftState) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(FlashingState.new);
		} else {
			if (initialized)
				startIntro();
			else
			{
				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					startIntro();
				});
			}
		}
		#end
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;


	/***************/
    /*    VIDEO    */
	/***************/
	public var vidSprite:VideoSprite = null;
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
				Sys.exit(0);
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
				throw 'Is anyone there?';
			});
		}
		#else
		FlxG.log.warn('Platform not supported!');
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			throw 'Is anyone there?';
		});
		#end
		return null;
	}
	function startIntro()
	{
		if (!initialized)
		{
			if(FlxG.sound.music == null && ClientPrefs.daMenuMusic != 'None') {
				FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic), 0);
			}
		}

		switch(ClientPrefs.daMenuMusic) // change this if you're making a source mod, like add your own or something
		{
			case 'Mashup' | 'VS Impostor' | 'VS Nonsense V2': 
				Conductor.changeBPM(102);
			case 'Dave & Bambi':
				Conductor.changeBPM(148);
			case 'Dave & Bambi (Old)':
				Conductor.changeBPM(150);
			case 'DDTO+':
				Conductor.changeBPM(120);
			case 'Anniversary':
				Conductor.changeBPM(115);
			case 'Base Game' | 'Default' | 'None' | 'Christmas': // just in case you're not making a source mod & wanna change this
				Conductor.changeBPM(titleJSON.bpm);
			default: // fallback
				Conductor.changeBPM(titleJSON.bpm);
		}
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite();

		if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != "none"){
			bg.loadGraphic(Paths.image(titleJSON.backgroundSprite));
		}else{
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		}
		add(bg);

		logoBl = new FlxSprite(titleJSON.titlex, titleJSON.titley);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');

		logoBl.antialiasing = ClientPrefs.globalAntialiasing;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		swagShader = new ColorSwap();
		gfDance = new FlxSprite(titleJSON.gfx, titleJSON.gfy);

		gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
		gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing;

		add(gfDance);
		gfDance.shader = swagShader.shader;
		add(logoBl);
		logoBl.shader = swagShader.shader;

		titleText = new FlxSprite(titleJSON.startx, titleJSON.starty);
		#if (desktop && MODS_ALLOWED)
		var path = "mods/" + Paths.currentModDirectory + "/images/titleEnter.png";
		//trace(path, FileSystem.exists(path));
		if (!FileSystem.exists(path)){
			path = "mods/images/titleEnter.png";
		}
		//trace(path, FileSystem.exists(path));
		if (!FileSystem.exists(path)){
			path = "assets/images/titleEnter.png";
		}
		//trace(path, FileSystem.exists(path));
		titleText.frames = FlxAtlasFrames.fromSparrow(BitmapData.fromFile(path),File.getContent(StringTools.replace(path,".png",".xml")));
		#else

		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		#end
		var animFrames:Array<FlxFrame> = [];
		@:privateAccess {
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (animFrames.length > 0) {
			newTitle = true;
			
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else {
			newTitle = false;
			
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		
		titleText.antialiasing = ClientPrefs.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		add(titleText);

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();

		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		add(ngSpr);
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.globalAntialiasing;

		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

		if (initialized)
			skipIntro();
		else
			initialized = true;

		// credGroup.add(credTextShit);
	}

	function getIntroTextShit():Array<Array<String>>
	{
		var fullText:String = Assets.getText(Paths.txt('introText'));

		var firstArray:Array<String> = fullText.split('\n');
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}
		
		if (newTitle) {
			titleTimer += CoolUtil.boundTo(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		// for testing purposes
		/*
		if (FlxG.keys.checkStatus(FlxKey.SEVEN, JUST_PRESSED))
			throw 'Crash test';
		*/


		
		sarcasmKeysBuffer += KeyboardFunctions.keypressToString();
		if (sarcasmKeysBuffer.length >= 32)
			sarcasmKeysBuffer = sarcasmKeysBuffer.substring(1);

		for (wordRaw in sarcasmKeys)
		{
			final word:String = wordRaw.toUpperCase();
			if (sarcasmKeysBuffer.contains(word) && allowedShit.match(word))
			{
				switch (word)
				{
					case 'ANNOUNCER':
						FlxG.sound.play(Paths.sound('sarcasmComplete'));
						trace('Were you talking about Portal 2?');
						sarcasmKeysBuffer = '';

		                var randomVar:Int = 0;
						if (!ClientPrefs.wheatleySpace) randomVar = Std.random(15);
			            if (ClientPrefs.wheatleySpace) randomVar = 8;
		                trace(randomVar);
	                	if (randomVar == 8)
		                {
			                trace('Hello? Anyone in there? Hello?...');
							#if VIDEOS_ALLOWED
							startVideo('alone');
							#else 
							throw 'Is anyone there?';
							#end
		                }
				}
			}
		}

		if (initialized && !transitioning && skippedIntro)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;
				
				timer = FlxEase.quadInOut(timer);
				
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}
			
			if(pressedEnter)
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;
				
				if(titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(ClientPrefs.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					if (mustUpdate) {
						FlxG.switchState(OutdatedState.new);
					} else {
						FlxG.switchState(MainMenuState.new);
					}
					closedState = true;
				});
			}
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null) {
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0; //Basically curBeat but won't be skipped if you hold the tab or resize the screen
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		FlxG.camera.zoom += 0.015;

		FlxTween.tween(FlxG.camera, {zoom: 1}, Conductor.crochet / 1200, {ease: FlxEase.quadOut});

		if(logoBl != null)
			logoBl.animation.play('bump', true);

		if(gfDance != null) {
			danceLeft = !danceLeft;
			if (danceLeft)
				gfDance.animation.play('danceRight');
			else
				gfDance.animation.play('danceLeft');
		}

		if(!closedState) {
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					if (ClientPrefs.daMenuMusic != 'None')
						FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic), 0);

					FlxG.sound.music?.fadeIn(4, 0, 0.7);
				case 2:
					#if PSYCH_WATERMARKS
					createCoolText(['JS Engine by'], 15);
					#else
					createCoolText(['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er']);
					#end
				case 4:
					#if PSYCH_WATERMARKS
					addMoreText('Jordan Santiago', 15);
					addMoreText('Moxie', 15);
					addMoreText('UltimateQuack', 15);
					addMoreText('Shadow Mario', 15);
					addMoreText('RiverOaken', 15);
					#else
					addMoreText('present');
					#end
				case 5:
					deleteCoolText();
				case 6:
					#if PSYCH_WATERMARKS
					createCoolText(['Not associated', 'with'], -40);
					#else
					createCoolText(['In association', 'with'], -40);
					#end
				case 8:
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
				case 9:
					deleteCoolText();
					ngSpr.visible = false;
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					addMoreText('Friday');
				case 15:
					addMoreText('Night');
				case 16:
					addMoreText('Funkin');

				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			FlxTween.tween(logoBl, {y: titleJSON.endY}, 1.4, {ease: FlxEase.expoInOut});

			logoBl.angle = -4;

			new FlxTimer().start(0.01, function(tmr:FlxTimer)
			{
				if (logoBl.angle == -4)
					FlxTween.angle(logoBl, logoBl.angle, 4, 4, {ease: FlxEase.quartInOut});
				if (logoBl.angle == 4)
					FlxTween.angle(logoBl, logoBl.angle, -4, 4, {ease: FlxEase.quartInOut});
			}, 0);

			remove(ngSpr);
			remove(credGroup);
			FlxG.camera.flash(FlxColor.WHITE, 4);
			skippedIntro = true;
		}
	}
}

// copied & pasted from an haxelib, but it's better
private class KeyboardFunctions
{
    /**
     * Just a simple function to determine which key was pressed. Good for sequential keypresses. An example of how to use this is by simply adding the value to a string in the update function.
     * 
     * Ex: 
     * ```
     * public var value:String = '';
     * override function update(elapsed:Float) {
     *      value += keypressToString(); // This will add a key to the string everytime a key is pressed
     * }
     * ```
     * @return Key that was pressed as a String
     */
    public static function keypressToString():String
    {
        var characterToAdd:String = "";
        if (FlxG.keys.justPressed.ANY) {
            final key = cast(FlxG.keys.firstJustPressed(), FlxKey);
            if (key != FlxKey.NONE){
                final i = key.toString().toUpperCase();
                characterToAdd += FlxKey.fromStringMap.get(i);
            }
        }
        return characterToAdd;
    }
}