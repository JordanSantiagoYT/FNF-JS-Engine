package play;

// REFACTOR: explicit imports for shader subtypes
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

import backend.ClientPrefs;
import backend.Conductor;
import backend.Conductor.Rating;
import backend.CoolUtil;
import backend.DiscordClient;
import backend.Highscore;
#if MODS_ALLOWED
#end
import backend.MusicBeatState;
import backend.WeekData;

import data.Section.SwagSection;
import data.Song;
import data.StageData;

import editors.CharacterEditorState;
import editors.ChartingState;

import flixel.addons.effects.FlxTrail;
import flixel.input.keyboard.FlxKey;
import flixel.ui.FlxBar;
import flixel.util.FlxSort;

import objects.*;

import openfl.events.KeyboardEvent;
import openfl.system.System;

import play.BaseStage;
import play.BaseStage.Countdown;
// REFACTOR: import kept for safety against stale global `BaseStage.Countdown` in source\import.hx
import play.CutsceneHandler;
import play.helpers.PlayStateAndroidMedia;
import play.objects.*;

import headers.Play;

import shaders.CrossFade;
import shaders.PulseEffectAlt;

import states.FreeplayState;
import states.LoadingState;
import states.MainMenuState;
import states.RenderingDoneSubState;
import states.StoryMenuState;
import states.substates.GameOverSubstate;
import states.substates.PauseSubState;

// REFACTOR: imports for relocated root classes
import backend.Controls;
import backend.Screenshot;
import objects.Alphabet;
import objects.AttachedSprite;
import objects.Character;
import objects.DialogueBoxPsych;
import objects.HealthIcon;
import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;
import objects.VideoSprite;

#if SHADERS_ALLOWED
#end

class PlayState extends MusicBeatState
{
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public static var instance:PlayState;
	public static var STRUM_X = 48;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public var renderPath(default, null):String = ClientPrefs.renderPath;

	public static var middleScroll:Bool = false;

	public static var ratingStuff:Array<Dynamic> = [];

	private var tauntKey:Array<FlxKey>;

	var lastUpdateTime:Float = 0.0;

	//event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Boyfriend> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	#if (LUA_ALLOWED || PYTHON_ALLOWED)
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	#else
	public var modchartSprites:Map<String, Dynamic> = new Map<String, Dynamic>();
	#end
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, FlxText> = new Map<String, FlxText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();

	public var hitSoundString:String = ClientPrefs.hitsoundType;

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";

	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var npsSpeedMult:Float = 1;

	public var frameCaptured:Int = 0;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public var grpCrossFade:FlxTypedGroup<CrossFade>;
	public var grpGFCrossFade:FlxTypedGroup<CrossFade>;
	public var grpBFCrossFade:FlxTypedGroup<CrossFade>;
	public var shaderUpdates:Array<Float->Void> = [];
	var botplayUsed:Bool = false;
	public static var curStage:String = '';
	public static var stageUI:String = "normal";
	public static var isPixelStage:Bool = false;

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var wasOriginallyFreeplay:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	var curTime:Float = 0;
	var songCalc:Float = 0;

	public var healthDrainAmount:Float = 0.023;
	public var healthDrainFloor:Float = 0.1;

	var strumsHit:Array<Bool> = [false, false, false, false, false, false, false, false];
	public var splashesPerFrame:Array<Int> = [0, 0, 0, 0];

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;
	var intro3:FlxSound;
	var intro2:FlxSound;
	var intro1:FlxSound;
	var introGo:FlxSound;
	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Boyfriend = null;
	public var bfNoteskin:String = null;
	public var dadNoteskin:String = null;

	public static var iconOffset:Int = 26;

	var tankmanAscend:Bool = false; // funni (2021 nostalgia oh my god)

	public var notes:FlxTypedGroup<Note>;
	public var sustainNotes:FlxTypedGroup<Note>;
	public var killNotes:Array<Note> = [];
	public var unspawnNotes:Array<PreloadedChartNote> = [];
	public var eventNotes:Array<EventNote> = [];

	//Handles the new epic mega sexy cam code that i've done
	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;
	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpHoldSplashes:FlxTypedGroup<SustainSplash>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 2.5;
	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health:Float;
	private var displayedHealth:Float;
	public var maxHealth:Float = 2;

	public var botEnergy:Float = 1;

	public var totalNotesPlayed:Float = 0;
	public var combo:Float = 0;
	public var maxCombo:Float = 0;
	public var missCombo:Int = 0;

	var notesAddedCount:Int = 0;
	var eventIndex:Int = 0;
	var notesToRemoveCount:Int = 0;
	var oppNotesToRemoveCount:Int = 0;

	var endingTimeLimit:Int = 20;

	//current zoom factor for camGame. Affects how much camGame is zoomed by, so tweening can actually be used.
	var camBopFactor:Float = 0;
	var camBopInterval:Float = 4;
	var camBopIntensity:Float = 1;

	var twistModifier:Float = 1;
	var twistAmount:Float = 1;
	var camTwistIntensity:Float = 0;
	var camTwistIntensity2:Float = 3;
	var camTwist:Bool = false;

	private var healthBarBG:AttachedSprite; //The image used for the health bar.
	public var healthBar:FlxBar;
	var songPercent:Float = 0;

	private var timeBarBG:AttachedSprite;
	public var timeBar:FlxBar;

	private var energyBarBG:AttachedSprite;
	public var energyBar:FlxBar;
	public var energyTxt:FlxText;

	public var ratingsData:Array<Rating> = Rating.loadDefault();
	public var perfects:Int = 0;
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var poorRatings:Int = 0;
	public var nps:Float = 0;
	public var maxNPS:Float = 0;
	public var oppNPS:Float = 0;
	public var maxOppNPS:Float = 0;
	public var enemyHits:Float = 0;
	public var opponentNoteTotal:Float = 0;
	public var polyphonyOppo:Float = 1;
	public var polyphonyBF:Float = 1;

	var pixelRatingPrefix:String = "";
	var pixelRatingSuffix:String = '';

	private var lerpingScore:Bool = false;

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;
	public static var playerIsCheating:Bool = false; //Whether the player is cheating. Enables if you change BOTPLAY or Practice Mode in the Pause menu

	public static var disableBotWatermark:Bool = false;

	public var shownScore:Float = 0;

	public var fcStrings:Array<String> = ['No Play', 'PFC', 'SFC', 'GFC', 'BFC', 'FC', 'SDCB', 'Clear', 'TDCB', 'QDCB'];
	public var hitStrings:Array<String> = ['Perfect!!!', 'Sick!!', 'Good!', 'Bad.', 'Shit.', 'Miss..'];

	var charChangeTimes:Array<Float> = [];
	var charChangeNames:Array<String> = [];
	var charChangeTypes:Array<Int> = [];

	var multiChangeEvents:Array<Array<Float>> = [[], []];

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var hpDrainLevel:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var sickOnly:Bool = false;
	public var cpuControlled(default, set):Bool = false;
	inline function set_cpuControlled(value:Bool){
		cpuControlled = value;
		if (botplayTxt != null) // this assures it'll always show up
			botplayTxt.visible = (!ClientPrefs.hideHud && ClientPrefs.botTxtStyle != 'Hide') ? cpuControlled : false;

		return cpuControlled;
	}
	public var practiceMode:Bool = false;
	public var opponentDrain:Bool = false;
	public static var opponentChart:Bool = false;
	public static var bothSides:Bool = false;
	var randomMode:Bool = false;
	var flip:Bool = false;
	var stairs:Bool = false;
	var waves:Bool = false;
	var oneK:Bool = false;
	var randomSpeedThing:Bool = false;
	public var trollingMode:Bool = false;
	public var jackingtime:Float = 0;
	public var minSpeed:Float = 0.1;
	public var maxSpeed:Float = 10;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;
	public var renderedTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;
	var hitsoundImage:FlxSprite;
	var hitsoundImageToLoad:String;

	//ok moxie this doesn't cause memory leaks
	public var scoreTxtUpdateFrame:Int = 0;
	public var popUpsFrame:Int = 0;
	public var missRecalcsPerFrame:Int = 0;
	public var hitImagesFrame:Int = 0;

	var notesHitArray:Array<Float> = [];
	var oppNotesHitArray:Array<Float> = [];
	var notesHitDateArray:Array<Float> = [];
	var oppNotesHitDateArray:Array<Float> = [];

	var dialogue:Array<String> = ['blah blah blah', 'coolswag'];
	var dialogueJson:DialogueFile = null;

	var EngineWatermark:FlxText;

	public static var screenshader:PulseEffectAlt;

	var disableTheTripper:Bool = false;
	var disableTheTripperAt:Int;

	var heyTimer:Float;

	public var singDurMult:Int = 1;

	//ms timing popup shit
	public var msTxt:MSText;
	public var msTimer:FlxTimer = null;
	public var restartTimer:FlxTimer = null;

	//ms timing popup shit except for simplified ratings
	public var judgeTxt:JudgeText;
	public var judgeTxtTimer:FlxTimer = null;

	public var oppScore:Float = 0;
	public var songScore:Float = 0;
	public var songHits:Int = 0;
	public var songMisses:Float = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;

	var scoreTxtTween:FlxTween;

	public static var campaignScore:Float = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public static var shouldDrainHealth:Bool = false;

	//Private value for defaultCamZoom. This is so tweening can be used without calling a 'set' function every frame.
	private var _defaultCamZoom:Float = 1.05;

	public var defaultCamZoom(get, set):Float;

	public var ogCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;

	public static var sectionsLoaded:Int = 0;
	public var notesLoadedRN:Int = 0;

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	var heyStopTrying:Bool = false;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	var keysPressed:Array<Bool> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	// Lua shit
	#if LUA_ALLOWED
	public var luaArray:Array<FunkinLua> = [];
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	#end

	// Python shit
	#if PYTHON_ALLOWED
	public var pythonArray:Array<PythonScript> = [];
	private var pythonDebugGroup:FlxTypedGroup<DebugLuaText>;
	#end
	public var introSoundsSuffix:String = '';

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;
	private var controlArray:Array<String>;

	public var songName:String;

	var formattedScore:String;
	var formattedSongMisses:String;
	var formattedCombo:String;
	var formattedMaxCombo:String;
	var formattedNPS:String;
	var formattedMaxNPS:String;
	var formattedOppNPS:String;
	var formattedMaxOppNPS:String;
	var npsString:String;
	var accuracy:String;
	var fcString:String;
	var hitsound:FlxSound;

	var botText:String;
	var tempScore:String;

	var startingTime:Float = haxe.Timer.stamp();
	var endingTime:Float = haxe.Timer.stamp();

	// FFMpeg values :)
	var ffmpegMode = ClientPrefs.ffmpegMode;
	var targetFPS = ClientPrefs.targetFPS;
	var unlockFPS = ClientPrefs.unlockFPS;
	var renderGCRate = ClientPrefs.renderGCRate;
	static var capture:Screenshot = new Screenshot();

	// Callbacks for stages
	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	override public function create()
	{
		FlxG.mouse.visible = false;
		//Stops playing on a height that isn't divisible by 2
		if (ClientPrefs.ffmpegMode && ClientPrefs.resolution != null) {
			#if desktop
			var resolutionValue = cast(ClientPrefs.resolution, String);

			if (resolutionValue != null) {
				var parts = resolutionValue.split('x');

				if (parts.length == 2) {
					var width = Std.parseInt(parts[0]);
					var height = Std.parseInt(parts[1]);

					if (width != null && height != null) {
						CoolUtil.resetResScale(width, height);
						FlxG.resizeGame(width, height);
						lime.app.Application.current.window.width = width;
						lime.app.Application.current.window.height = height;
					}
				}
			}
			#end
		}
		if (ffmpegMode) {
			if (unlockFPS)
			{
				FlxG.updateFramerate = 1000;
				FlxG.drawFramerate = 1000;
			}
			FlxG.fixedTimestep = true;
			FlxG.animationTimeScale = ClientPrefs.framerate / targetFPS;
			if (!ClientPrefs.oldFFmpegMode) initRender(renderPath);
			FlxG.signals.preStateSwitch.addOnce(() -> stopRender());
		}

		if (noteLimit == 0) noteLimit = 2147483647;

		#if sys
		if (FileSystem.exists(Paths.getSharedPath('sounds/hitsounds/' + ClientPrefs.hitsoundType.toLowerCase() + '.txt')))
			hitsoundImageToLoad = File.getContent(Paths.getSharedPath('sounds/hitsounds/' + ClientPrefs.hitsoundType.toLowerCase() + '.txt'));
		else if (FileSystem.exists(Paths.modFolders('sounds/hitsounds/' + ClientPrefs.hitsoundType.toLowerCase() + '.txt')))
			hitsoundImageToLoad = File.getContent(Paths.modFolders('sounds/hitsounds/' + ClientPrefs.hitsoundType.toLowerCase() + '.txt'));
		#end

		#if cpp
		inline cpp.vm.Gc.enable(ClientPrefs.enableGC || ffmpegMode && !ClientPrefs.noRenderGC); //lagspike prevention
		#end
		inline Paths.clearStoredMemory();

		#if sys
		debug.FrameProfiler.beginGC(true);
		System.gc();
		debug.FrameProfiler.endGC();
		#end

		// for lua
		instance = this;

		screenshader = new PulseEffectAlt();

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed', 1);
		tauntKey = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('taunt'));

		keysArray = [];

		controlArray = ['NOTE_LEFT', 'NOTE_DOWN', 'NOTE_UP', 'NOTE_RIGHT'];

		for (e in controlArray)
			keysArray.push(ClientPrefs.copyKey(ClientPrefs.keyBinds.get(e.toLowerCase())));

		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
		{
			keysPressed.push(false);
		}

		screenshader.waveAmplitude = 1;
		screenshader.waveFrequency = 2;
		screenshader.waveSpeed = 1;
		screenshader.shader.time = new flixel.math.FlxRandom().float(-100000, 100000);

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		hpDrainLevel = ClientPrefs.getGameplaySetting('drainlevel', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		sickOnly = ClientPrefs.getGameplaySetting('onlySicks', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);
		opponentChart = ClientPrefs.getGameplaySetting('opponentplay', false);
		bothSides = ClientPrefs.getGameplaySetting('bothsides', false);
		trollingMode = ClientPrefs.getGameplaySetting('thetrollingever', false);
		opponentDrain = ClientPrefs.getGameplaySetting('opponentdrain', false);
		randomMode = ClientPrefs.getGameplaySetting('randommode', false);
		flip = ClientPrefs.getGameplaySetting('flip', false);
		stairs = ClientPrefs.getGameplaySetting('stairmode', false);
		waves = ClientPrefs.getGameplaySetting('wavemode', false);
		oneK = ClientPrefs.getGameplaySetting('onekey', false);
		randomSpeedThing = ClientPrefs.getGameplaySetting('randomspeed', false);
		jackingtime = ClientPrefs.getGameplaySetting('jacks', 0);
		minSpeed = ClientPrefs.getGameplaySetting('randomspeedmin', 0.1);
		maxSpeed = ClientPrefs.getGameplaySetting('randomspeedmax', 10);

		middleScroll = ClientPrefs.middleScroll || bothSides;
		if (bothSides) opponentChart = false;

		if (ffmpegMode)
			cpuControlled = true;

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		grpHoldSplashes = new FlxTypedGroup<SustainSplash>((ClientPrefs.maxSplashLimit != 0 ? ClientPrefs.maxSplashLimit : 10000));
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>((ClientPrefs.maxSplashLimit != 0 ? ClientPrefs.maxSplashLimit : 10000));

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		persistentUpdate = true;
		persistentDraw = true;
		if (SONG == null)
			SONG = Song.loadFromJson('test');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		if (!chartingMode) CoolUtil.currentDifficulty = CoolUtil.difficultyString();

		#if DISCORD_ALLOWED
		storyDifficultyText = CoolUtil.difficulties[storyDifficulty];

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "BRB! - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		curStage = (!ClientPrefs.charsAndBG ? "" : SONG.stage);
		//trace('stage is: ' + curStage);
		if(SONG.stage == null || SONG.stage.length < 1)
			curStage = StageData.vanillaSongStage(Song.loadedSongName);

		SONG.stage = curStage;

		var stageData:StageFile = StageData.getStageFile(curStage);

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else if (stageData.isPixelStage)
			stageUI = "pixel";

		_defaultCamZoom = ogCamZoom = stageData.defaultZoom;
		isPixelStage = stageData.isPixelStage;
		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		startCallback = startCountdown;
		endCallback = endSong;

		switch (curStage)
		{
			case 'stage': new stages.StageWeek1(); //Week 1
			case 'spooky': new stages.Spooky(); //Week 2
			case 'philly': new stages.Philly(); //Week 3
			case 'limo': new stages.Limo(); //Week 4
			case 'mall': new stages.Mall(); //Week 5 - Cocoa, Eggnog
			case 'mallEvil': new stages.MallEvil(); //Week 5 - Winter Horrorland
			case 'school': new stages.School(); //Week 6 - Senpai, Roses
			case 'schoolEvil': new stages.SchoolEvil(); //Week 6 - Thorns
			case 'tank': new stages.Tank(); //Week 7 - Ugh, Guns, Stress
			case 'phillyStreets': new stages.PhillyStreets(); 	//Weekend 1 - Darnell, Lit Up, 2Hot
			case 'phillyBlazin': new stages.PhillyBlazin();	//Weekend 1 - Blazin
			case 'phillyStreetsBF': new stages.PhillyStreetsBF(); //Darnell (BF Mix)
		}

		if (Paths.formatToSongPath(SONG.song) == 'stress')
			GameOverSubstate.characterName = 'bf-holding-gf-dead';

		if (Note.globalRgbShaders.length > 0) Note.globalRgbShaders = [];
		Paths.initDefaultSkin(SONG.arrowSkin);
		Paths.initNote(SONG.arrowSkin);

		if(isPixelStage) {
			introSoundsSuffix = '-pixel';
		}

		if (ClientPrefs.crossFadeLimit != null)
			grpCrossFade = new FlxTypedGroup<CrossFade>(ClientPrefs.crossFadeLimit); // limit
		else
			grpCrossFade = new FlxTypedGroup<CrossFade>(4); // limit

		if (ClientPrefs.crossFadeLimit != null)
			grpGFCrossFade = new FlxTypedGroup<CrossFade>(ClientPrefs.crossFadeLimit); // limit
		else
			grpGFCrossFade = new FlxTypedGroup<CrossFade>(4); // limit

		if (ClientPrefs.boyfriendCrossFadeLimit != null)
			grpBFCrossFade = new FlxTypedGroup<CrossFade>(ClientPrefs.boyfriendCrossFadeLimit); // limit
		else
			grpBFCrossFade = new FlxTypedGroup<CrossFade>(1); // limit

		add(grpCrossFade);
		add(grpGFCrossFade);
		add(grpBFCrossFade);

		add(gfGroup); //Needed for blammed lights

		add(dadGroup);
		add(boyfriendGroup);

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		#if PYTHON_ALLOWED
		pythonDebugGroup = new FlxTypedGroup<DebugLuaText>();
		pythonDebugGroup.cameras = [camOther];
		add(pythonDebugGroup);
		#end

		// "GLOBAL" SCRIPTS
		#if (LUA_ALLOWED || PYTHON_ALLOWED)
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('scripts/'));
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/scripts/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/scripts/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					#if LUA_ALLOWED
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						new FunkinLua(folder + file);
						filesPushed.push(file);
					}
					#end
					#if PYTHON_ALLOWED
					if(file.endsWith('.py') && !filesPushed.contains(file))
					{
						new PythonScript(folder + file);
						filesPushed.push(file);
					}
					#end
				}
			}
		}
		#end

		// STAGE SCRIPTS
		#if (MODS_ALLOWED && LUA_ALLOWED)
		startLuasOnFolder('stages/' + curStage + '.lua');
		#end
		#if (MODS_ALLOWED && PYTHON_ALLOWED)
		startPythonScriptOnFolder('stages/' + curStage + '.py');
		#end
		var gfVersion:String = SONG.gfVersion;

		if(gfVersion == null || gfVersion.length < 1)
		{
			switch (curStage)
			{
				case 'limo':
					gfVersion = 'gf-car';
				case 'mall' | 'mallEvil':
					gfVersion = 'gf-christmas';
				case 'school' | 'schoolEvil':
					gfVersion = 'gf-pixel';
				case 'tank':
					gfVersion = 'gf-tankmen';
				default:
					gfVersion = 'gf';
			}


			switch(Paths.formatToSongPath(SONG.song))
			{
				case 'stress':
					gfVersion = 'pico-speaker';
			}
			SONG.gfVersion = gfVersion; //Fix for the Chart Editor
		}
		health = maxHealth / 2;
		displayedHealth = maxHealth / 2;

		if (!stageData.hide_girlfriend && ClientPrefs.charsAndBG)
		{
			gf = new Character(0, 0, gfVersion);
			startCharacterPos(gf);
			gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
			startCharacterLua(gf.curCharacter);
		}

		var ratingQuoteStuff:Array<Dynamic> = Mods.mergeAllTextsNamed('data/ratingQuotes/${ClientPrefs.rateNameStuff}.txt', '', true);
		if (ratingQuoteStuff == null || ratingQuoteStuff.indexOf(null) != -1){
			trace('Failed to find quotes for ratings!');
			// this should help fix a crash
			ratingQuoteStuff = [
				['How are you this bad?', 0.1],
				['You Suck!', 0.2],
				['Horribly Shit', 0.3],
				['Shit', 0.4],
				['Bad', 0.5],
				['Bruh', 0.6],
				['Meh', 0.69],
				['Nice', 0.7],
				['Good', 0.8],
				['Great', 0.9],
				['Sick!', 1],
				['Perfect!!', 1]
			];
			ratingStuff = ratingQuoteStuff.copy();
		}
		else
		{
			for (i in 0...ratingQuoteStuff.length)
			{
				var quotes:Array<Dynamic> = ratingQuoteStuff[i].split(',');
				if (quotes.length > 2) //In case your quote has more than 1 comma
				{
					var quotesToRemove:Int = 0;
					for (i in 1...quotes.length-1)
					{
						quotesToRemove++;
						quotes[0] += ',' + quotes[i];
					}
					if (quotesToRemove > 0)
						quotes.splice(1, quotesToRemove);

				}
				ratingStuff.push(quotes);
			}
		}

		if (!ClientPrefs.charsAndBG)
		{
			dad = new Character(0, 0, "");
			dadGroup.add(dad);

			boyfriend = new Boyfriend(0, 0, "");
			boyfriendGroup.add(boyfriend);
		} else {
			dad = new Character(0, 0, SONG.player2);
			startCharacterPos(dad, true);
			dadGroup.add(dad);
			startCharacterLua(dad.curCharacter);
			dadNoteskin = dad.noteskin;

			boyfriend = new Boyfriend(0, 0, SONG.player1);
			startCharacterPos(boyfriend);
			boyfriendGroup.add(boyfriend);
			startCharacterLua(boyfriend.curCharacter);
			bfNoteskin = boyfriend.noteskin;
		}

		shouldDrainHealth = (opponentDrain || (opponentChart ? boyfriend.healthDrain : dad.healthDrain));
		if (!opponentDrain && !Math.isNaN((opponentChart ? boyfriend : dad).drainAmount) && (opponentChart ? boyfriend : dad).drainFloor != 0) healthDrainAmount = opponentChart ? boyfriend.drainAmount : dad.drainAmount;
		if (!opponentDrain && !Math.isNaN((opponentChart ? boyfriend : dad).drainFloor) && (opponentChart ? boyfriend : dad).drainFloor != 0) healthDrainFloor = opponentChart ? boyfriend.drainFloor : dad.drainFloor;

		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}

		var file:String = Paths.json(songName + '/dialogue'); //Checks for json/Psych Engine dialogue
		if (OpenFlAssets.exists(file)) {
			dialogueJson = DialogueBoxPsych.parseDialogue(file);
		}

		var file:String = Paths.txt(songName + '/' + songName + 'Dialogue'); //Checks for vanilla/Senpai dialogue
		if (OpenFlAssets.exists(file)) {
			dialogue = CoolUtil.coolTextFile(file);
		}

		Conductor.songPosition = -5000 / Conductor.songPosition;

		popUpGroup = new FlxTypedSpriteGroup<Popup>();
		add(popUpGroup);

		var showTime:Bool = (ClientPrefs.timeBarType != 'Disabled');

		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = showTime;
		if(ClientPrefs.downScroll) timeTxt.y = FlxG.height - 44;
		switch (ClientPrefs.timeBarStyle)
		{
			case 'Vanilla':
				timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				timeTxt.borderSize = 2;

			case 'Leather Engine':
				timeTxt.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				timeTxt.borderSize = 2;

			case 'JS Engine':
				timeTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				timeTxt.borderSize = 3;

			case 'TGT V4':
				timeTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				timeTxt.borderSize = 2;

			case 'Kade Engine':
				timeTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				timeTxt.borderSize = 1;

			case 'Dave Engine':
				timeTxt.setFormat(Paths.font("comic.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				timeTxt.borderSize = 2;

			case 'Doki Doki+':
				timeTxt.setFormat(Paths.font("Aller_rg.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				timeTxt.borderSize = 2;

			case 'VS Impostor':
				timeTxt.x = STRUM_X + (FlxG.width / 2) - 585;
				timeTxt.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
				timeTxt.borderSize = 1;
		}


		if(ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.text = SONG.song;
		}
		updateTime = showTime;

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height / 4);  // Adjust y position if needed for specific timeBarTypes
		timeBarBG.scrollFactor.set();
		timeBarBG.alpha = 0;
		timeBarBG.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
		timeBarBG.xAdd = -4;
		timeBarBG.yAdd = -4;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.numDivisions = 800; // Adjust numDivisions if needed for performance
		timeBar.alpha = 0;
		timeBar.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
		if (ClientPrefs.timeBarStyle != 'Dave Engine') add(timeBar);
		timeBarBG.sprTracker = timeBar;

		switch (ClientPrefs.timeBarStyle) {
			case 'VS Impostor':
				timeBarBG.loadGraphic(Paths.image('impostorTimeBar'));
				timeBar.createFilledBar(0xFF2e412e, 0xFF44d844);
				timeTxt.x += 10;
				timeTxt.y += 4;

			case 'Vanilla', 'TGT V4':
				timeBarBG.loadGraphic(Paths.image('timeBar'));
				timeBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);
				timeBarBG.color = FlxColor.BLACK;

			case 'Leather Engine':
				if (timeBarBG != null && timeBar != null){
					timeBarBG.destroy();
					timeBar.destroy();
				}
				timeBarBG = new AttachedSprite('editorHealthBar');
				timeBarBG.x = timeTxt.x;
				timeBarBG.y = timeTxt.y + (timeTxt.height / 8);
				timeBarBG.scrollFactor.set();
				timeBarBG.alpha = 0;
				timeBarBG.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
				timeBarBG.color = FlxColor.BLACK;
				timeBarBG.xAdd = -4;
				timeBarBG.yAdd = -4;
				timeBarBG.screenCenter(X);
				add(timeBarBG);

				timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
				'songPercent', 0, 1);
				timeBar.scrollFactor.set();
				timeBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);
				timeBar.numDivisions = 400; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
				timeBar.alpha = 0;
				timeBar.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
				add(timeBar);
				timeBarBG.sprTracker = timeBar;

			case 'Kade Engine':
				if (timeBarBG != null && timeBar != null){
					timeBarBG.destroy();
					timeBar.destroy();
				}
				timeBarBG = new AttachedSprite('editorHealthBar');
				timeBarBG.x = timeTxt.x;
				timeBarBG.y = timeTxt.y + (timeTxt.height / 8);
				timeBarBG.scrollFactor.set();
				timeBarBG.alpha = 0;
				timeBarBG.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
				timeBarBG.color = FlxColor.BLACK;
				timeBarBG.xAdd = -4;
				timeBarBG.yAdd = -4;
				timeBarBG.screenCenter(X);
				add(timeBarBG);

				timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
				'songPercent', 0, 1);
				timeBar.scrollFactor.set();
				timeBar.createFilledBar(FlxColor.GRAY, FlxColor.LIME);
				timeBar.numDivisions = 800; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
				timeBar.alpha = 0;
				timeBar.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
				add(timeBar);
				timeBarBG.sprTracker = timeBar;

			case 'Dave Engine':
				if (timeBarBG != null && timeBar != null){
					timeBarBG.destroy();
					timeBar.destroy();
				}
				timeBarBG = new AttachedSprite('DnBTimeBar');
				timeBarBG.screenCenter(X);
				timeBarBG.y = timeTxt.y + (timeTxt.height / 4);
				timeBarBG.antialiasing = true;
				timeBarBG.scrollFactor.set();
				timeBarBG.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
				timeBarBG.xAdd = -4;
				timeBarBG.yAdd = -4;
				add(timeBarBG);

				timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
				'songPercent', 0, 1);
				timeBar.scrollFactor.set();
				timeBar.numDivisions = 800; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
				timeBar.alpha = 0;
				timeBar.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
				timeBarBG.sprTracker = timeBar;
				timeBar.createFilledBar(FlxColor.GRAY, FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]));
				insert(members.indexOf(timeBarBG), timeBar);

			case 'Doki Doki+':
				timeBarBG.loadGraphic(Paths.image("dokiTimeBar"));
				timeBarBG.screenCenter(X);
				timeBar.createGradientBar([FlxColor.TRANSPARENT], [FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]), FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2])]);

			case 'JS Engine':
				if (timeBarBG != null && timeBar != null){
					timeBarBG.destroy();
					timeBar.destroy();
				}
				timeBarBG = new AttachedSprite('healthBar');
				timeBarBG.screenCenter(X);
				timeBarBG.x = timeTxt.x;
				timeBarBG.y = timeTxt.y + (timeTxt.height / 8);
				timeBarBG.scrollFactor.set();
				timeBarBG.alpha = 0;
				timeBarBG.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
				timeBarBG.color = FlxColor.BLACK;
				timeBarBG.xAdd = -4;
				timeBarBG.yAdd = -4;
				timeBarBG.screenCenter(X);
				add(timeBarBG);

				timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
				'songPercent', 0, 1);
				timeBar.scrollFactor.set();
				timeBar.numDivisions = 1000; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
				timeBar.alpha = 0;
				timeBar.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');
				timeBarBG.sprTracker = timeBar;
				timeBar.createGradientBar([FlxColor.TRANSPARENT], [FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]), FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2])]);
			add(timeBar);
		}
		add(timeTxt);

		timeBarBG.visible = showTime && !ClientPrefs.timeBarType.contains('(No Bar)');

		energyBarBG = new AttachedSprite('timeBar');
		energyBarBG.x = FlxG.width * 0.81;
		energyBarBG.y = FlxG.height / 2;  // Adjust y position if needed for specific timeBarTypes
		energyBarBG.scrollFactor.set();
		energyBarBG.alpha = 0;
		energyBarBG.visible = false;
		energyBarBG.xAdd = -4;
		energyBarBG.yAdd = -4;
		energyBarBG.angle = 90;
		add(energyBarBG);

		energyBar = new FlxBar(energyBarBG.x, energyBarBG.y, RIGHT_TO_LEFT, Std.int(energyBarBG.width - 8), Std.int(energyBarBG.height - 8), this,
			'botEnergy', 0, 2);
		energyBar.scrollFactor.set();
		energyBar.numDivisions = 1000;
		energyBar.alpha = 0;
		energyBar.visible = false;
		energyBar.angle = 90;
		energyBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);
		add(energyBar);
		energyBarBG.sprTracker = energyBar;

		energyTxt = new FlxText(FlxG.width * 0.81, FlxG.height / 2, 400, "", 20);
		energyTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE,FlxColor.BLACK);
		energyTxt.scrollFactor.set();
		energyTxt.alpha = 0;
		energyTxt.borderSize = 1.25;
		energyTxt.visible = false;
		add(energyTxt);

		energyBarBG.cameras = energyBar.cameras = energyTxt.cameras = [camHUD];

		sustainNotes = new FlxTypedGroup<Note>();
		add(sustainNotes);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);

		notes = new FlxTypedGroup<Note>();
		add(notes);
		notes.visible = sustainNotes.visible = ClientPrefs.showNotes; //that was easier than expected

		add(grpNoteSplashes);
		add(grpHoldSplashes);

		if(ClientPrefs.timeBarType == 'Song Name' && ClientPrefs.timeBarStyle == 'VS Impostor')
		{
			timeTxt.size = 14;
		}

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0001;

		SustainSplash.startCrochet = Conductor.stepCrochet;
		SustainSplash.frameRate = Math.floor(24 / 100 * SONG.bpm);
		var splash:SustainSplash = new SustainSplash();
		grpHoldSplashes.add(splash);
		splash.visible = true;
		splash.alpha = 0.0001;

		playerStrums = new FlxTypedGroup<StrumNote>();
		opponentStrums = new FlxTypedGroup<StrumNote>();

		// trace ('Loading chart...');

		addVirtualPad(NONE, P);
		addVirtualPadCamera();
		virtualPad.visible = true;
		addMobileControls();

		if (dad.flixelTrail && dad.trailLength != null && dad.trailDelay != null && dad.trailAlpha != null && dad.trailDiff != null)
		{
			var dadTrail = new FlxTrail(dad, null, dad.trailLength, dad.trailDelay, dad.trailAlpha,
				dad.trailDiff); // nice //target, graphic, length, delay, alpha, diff
			insert(members.indexOf(dadGroup) - 1, dadTrail);
		}

		if (boyfriend.flixelTrail && boyfriend.trailLength != null && boyfriend.trailDelay != null && boyfriend.trailAlpha != null
			&& boyfriend.trailDiff != null)
		{
			var bfTrail = new FlxTrail(boyfriend, null, boyfriend.trailLength, boyfriend.trailDelay, boyfriend.trailAlpha, boyfriend.trailDiff); // nice
			insert(members.indexOf(boyfriendGroup) - 1, bfTrail);
		}
		generateSong(startOnTime);

		callOnLuas('onCreate');

		if (SONG.event7 == null || SONG.event7 == '') SONG.event7 == 'None';

		if (curSong.toLowerCase() == "guns") // added this to bring back the old 2021 fnf vibes, i wish the fnf fandom revives one day :(
		{
			final randomVar:Int = (ClientPrefs.noGunsRNG) ? 8 : Std.random(15);
			// trace(randomVar);
			if (randomVar == 8)
			{
				trace('AWW YEAH, ITS ASCENDING TIME');
				tankmanAscend = true;
			}
		}

		camFollow = FlxPoint.get();
		camFollowPos = new FlxObject();

		snapCamFollowToPos(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		if (prevCamFollowPos != null)
		{
			camFollowPos = prevCamFollowPos;
			prevCamFollowPos = null;
		}
		add(camFollowPos);
		if (!ClientPrefs.charsAndBG) _defaultCamZoom = 100;
		else
		{
			FlxG.camera.follow(camFollowPos, LOCKON, 1);
			FlxG.camera.zoom = defaultCamZoom;
			FlxG.camera.snapToTarget();

			FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		}
		moveCameraSection();

		msTxt = new MSText(camHUD);
		insert(members.indexOf(strumLineNotes), msTxt);

		judgeTxt = new JudgeText(camHUD);
		add(judgeTxt);

		switch(ClientPrefs.healthBarStyle)
		{
			case 'Dave Engine':
				healthBarBG = new AttachedSprite('DnBHealthBar');

			case 'Doki Doki+':
				healthBarBG = new AttachedSprite('dokiHealthBar');

			default:
				healthBarBG = new AttachedSprite('healthBar');
		}

		healthBarBG.y = FlxG.height * 0.89;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.visible = !ClientPrefs.hideHud;
		healthBarBG.xAdd = -4;
		healthBarBG.yAdd = -4;
		add(healthBarBG);
		if(ClientPrefs.downScroll) healthBarBG.y = 0.11 * FlxG.height;

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'displayedHealth', 0, maxHealth);
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.hideHud;
		healthBar.alpha = ClientPrefs.healthBarAlpha;
		insert(members.indexOf(healthBarBG), healthBar);
		healthBarBG.sprTracker = healthBar;

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.hideHud;
		iconP1.alpha = ClientPrefs.healthBarAlpha;
		add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.hideHud;
		iconP2.alpha = ClientPrefs.healthBarAlpha;
		add(iconP2);
		reloadHealthBarColors(dad.healthColorArray, boyfriend.healthColorArray);

		if (ClientPrefs.smoothHealth) healthBar.numDivisions = Std.int(healthBar.width);

		if (SONG.player1.startsWith('bf') || SONG.player1.startsWith('boyfriend')) {
			final iconToChange:String = switch (ClientPrefs.bfIconStyle){
				case 'VS Nonsense V2': 'bfnonsense';
				case 'Doki Doki+': 'bfdoki';
				case 'Leather Engine': 'bfleather';
				case "Mic'd Up": 'bfmup';
				case "FPS Plus": 'bffps';
				case "OS 'Engine'": 'bfos';
				default: 'bf';
			}
			if (iconToChange != 'bf')
				iconP1.changeIcon(iconToChange);
		}

		if (ClientPrefs.timeBarType == 'Disabled') {
			timeBarBG.destroy();
			timeBar.destroy();
		}

		//figured i'd optimize the code for the enginewatermark creation. after all a lot of lines here were mostly the same

		EngineWatermark = new FlxText(4,FlxG.height * 0.9 + 50,0,"", 16);
		EngineWatermark.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE,FlxColor.BLACK);
		EngineWatermark.scrollFactor.set();
		EngineWatermark.text = SONG.song;
		add(EngineWatermark);

		switch(ClientPrefs.watermarkStyle)
		{
			case 'Vanilla': EngineWatermark.text = SONG.song + " " + CoolUtil.difficultyString() + " | JSE " + MainMenuState.psychEngineJSVersion;
			case 'Forever Engine':
				EngineWatermark.text = "JS Engine v" + MainMenuState.psychEngineJSVersion;
				EngineWatermark.x = FlxG.width - EngineWatermark.width - 5;
			case 'JS Engine':
				if (!ClientPrefs.downScroll) EngineWatermark.y = FlxG.height * 0.1 - 70;
				EngineWatermark.text = "Playing " + SONG.song + " on " + CoolUtil.difficultyString() + " - JSE v" + MainMenuState.psychEngineJSVersion;
			case 'Dave Engine':
				EngineWatermark.setFormat(Paths.font("comic.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE,FlxColor.BLACK);
				EngineWatermark.text = SONG.song;
				EngineWatermark.y = healthBar.y + 50;

			default:
		}

		if (ClientPrefs.watermarkStyle == 'Hide' && EngineWatermark != null) EngineWatermark.visible = false;

		// TODO: cleanup playstate, by moving most of this and other duplicate functions like healthbop, etc
		scoreTxt = new FlxText(0, healthBarBG.y + 50, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE,FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1;
		scoreTxt.visible = !ClientPrefs.hideHud;
		add(scoreTxt);

		var style:String = ClientPrefs.scoreStyle;
		var dadColors:Array<Int> = CoolUtil.getHealthColors(dad);

		// Configuration for each style
		var styleSettings = { // profiency using typedefs
			'JS Engine': {
				font: "vcr.ttf", size: 18, color: FlxColor.fromRGB(dadColors[0], dadColors[1], dadColors[2]),
				yOffset: null, borderSize: 2, xOverride: null
			},
			'Dave Engine': {
				font: "comic.ttf", size: 20, color: FlxColor.WHITE,
				yOffset: 40, borderSize: 1.25, xOverride: null
			},
			'Psych Engine': {
				font: "vcr.ttf", size: 20, color: FlxColor.WHITE,
				yOffset: 36, borderSize: 1.25, xOverride: null
			},
			'VS Impostor': {
				font: "vcr.ttf", size: 20, color: FlxColor.fromRGB(dadColors[0], dadColors[1], dadColors[2]),
				yOffset: 36, borderSize: 1.25, xOverride: null
			},
			'Doki Doki+': {
				font: "Aller_rg.ttf", size: 20, color: FlxColor.WHITE,
				yOffset: 48, borderSize: 1.25, xOverride: null
			},
			'TGT V4': {
				font: "calibri.ttf", size: 20, color: FlxColor.WHITE,
				yOffset: 48, borderSize: 1.25, xOverride: null
			},
			'Forever Engine': {
				font: "vcr.ttf", size: 18, color: FlxColor.WHITE,
				yOffset: 40, borderSize: 1.25, xOverride: null
			},
			'Vanilla': {
				font: "vcr.ttf", size: 16, color: FlxColor.WHITE,
				yOffset: 30, borderSize: 1.25, xOverride: 200
			}
		};

		// Apply settings if style is in the map
		if (Reflect.hasField(styleSettings, style)) {
			final s = Reflect.getProperty(styleSettings, style);
			if (s.yOffset != null) scoreTxt.y = healthBarBG.y + s.yOffset;
			if (s.xOverride != null) scoreTxt.x = s.xOverride;
			scoreTxt.setFormat(Paths.font(s.font), s.size, s.color, CENTER, OUTLINE, FlxColor.BLACK);
			scoreTxt.borderSize = s.borderSize;
			if (style == 'Forever Engine' || style == 'Vanilla') updateScore();
		}

		style = null;

		if (!ClientPrefs.charsAndBG) {
			remove(dadGroup);
			remove(boyfriendGroup);
			remove(gfGroup);
			gfGroup.destroy();
			dadGroup.destroy();
			boyfriendGroup.destroy();
		}

		renderedTxt = new FlxText(0, healthBarBG.y - 50, FlxG.width, "", 32);
		renderedTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		renderedTxt.scrollFactor.set();
		renderedTxt.borderSize = 1.25;
		renderedTxt.cameras = [camHUD];
		renderedTxt.visible = ClientPrefs.showRendered;

		if (ClientPrefs.downScroll) renderedTxt.y = healthBar.y + 50;
		if (ClientPrefs.scoreStyle == 'VS Impostor') renderedTxt.y = healthBar.y + (ClientPrefs.downScroll ? 100 : -100);
		add(renderedTxt);

		//create default botplay text
		botplayTxt = new FlxText(400, timeBarBG.y + 55, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled && (!ClientPrefs.hideHud && ClientPrefs.botTxtStyle != 'Hide');
		add(botplayTxt);
		if (ClientPrefs.downScroll)
			botplayTxt.y = timeBarBG.y - 78;

		// just because, people keep making issues about it
		try{
			var botStyle = ClientPrefs.botTxtStyle;
			switch(botStyle)
			{
				case 'Vanilla': //Do nothing.
				case 'JS Engine':
					botplayTxt.text = 'Botplay Mode';
					botplayTxt.borderSize = 1.5;

				case 'Doki Doki+':
					botplayTxt.setFormat(Paths.font("Aller_rg.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				case 'TGT V4':
					botplayTxt.setFormat(Paths.font("calibri.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				case 'Dave Engine':
					botplayTxt.setFormat(Paths.font("comic.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				case 'VS Impostor':
					botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.fromRGB(dadColors[0], dadColors[1], dadColors[2]), CENTER, OUTLINE, FlxColor.BLACK);
			}
		}
		catch(e){
			trace("Failed to display/create botplayTxt: " + e);
		}
		if (botplayTxt != null){
			if (!cpuControlled && practiceMode) {
				botplayTxt.text = 'Practice Mode';
				botplayTxt.visible = true;
			}
		}

		if (ClientPrefs.hideHud) {
			final hudItems:Array<Dynamic> = [scoreTxt, botplayTxt, healthBarBG, healthBar, iconP2, iconP1, timeBarBG, timeBar, timeTxt];
			for (item in hudItems) if (item != null) item.visible = false;
		}

		strumLineNotes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		grpHoldSplashes.cameras = [camHUD];
		sustainNotes.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		if (EngineWatermark != null) EngineWatermark.cameras = [camHUD];
		if (scoreTxt != null) scoreTxt.cameras = [camHUD];
		if (botplayTxt != null) botplayTxt.cameras = [camHUD];
		timeBar.cameras = [camHUD];
		timeBarBG.cameras = [camHUD];
		timeTxt.cameras = [camHUD];
		popUpGroup.cameras = [camHUD];

		startingSong = true;
		MusicBeatState.windowNameSuffix = " - " + SONG.song + " " + (isStoryMode ? "(Story Mode)" : "(Freeplay)");

		#if (LUA_ALLOWED || PYTHON_ALLOWED)
		for (notetype in noteTypeMap.keys())
		{
			#if LUA_ALLOWED
			startLuasOnFolder('custom_notetypes/' + notetype + '.lua');
			#end
			#if PYTHON_ALLOWED
			startPythonScriptOnFolder('custom_notetypes/' + notetype + '.py');
			#end
		}
		for (event in eventPushedMap.keys())
		{
			#if LUA_ALLOWED
			startLuasOnFolder('custom_events/' + event + '.lua');
			#end
			#if PYTHON_ALLOWED
			startPythonScriptOnFolder('custom_events/' + event + '.py');
			#end
		}
		#end
		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		if(eventNotes.length > 1)
		{
			for (event in eventNotes) event.strumTime -= eventNoteEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}

		// SONG SPECIFIC SCRIPTS
		#if (LUA_ALLOWED || PYTHON_ALLOWED)
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/' + Paths.formatToSongPath(SONG.song) + '/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('data/' + Paths.formatToSongPath(SONG.song) + '/'));
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/data/' + Paths.formatToSongPath(SONG.song) + '/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/data/' + Paths.formatToSongPath(SONG.song) + '/' ));// using push instead of insert because these should run after everything else
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					#if LUA_ALLOWED
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						new FunkinLua(folder + file);
						filesPushed.push(file);
					}
					#end
					#if PYTHON_ALLOWED
					if(file.endsWith('.py') && !filesPushed.contains(file))
					{
						new PythonScript(folder + file);
						filesPushed.push(file);
					}
					#end
				}
			}
		}
		#end

		RecalculateRating();

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		//PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		if (hitSoundString != "none")
			hitsound = FlxG.sound.load(Paths.sound("hitsounds/" + Std.string(hitSoundString).toLowerCase()));
		if(ClientPrefs.hitsoundVolume > 0) Paths.sound('hitsound');
		hitsound.volume = ClientPrefs.hitsoundVolume;
		hitsound.pitch = playbackRate;
		for (i in 1...4) Paths.sound('missnote$i');
		Paths.image('alphabet');

		if (PauseSubState.songName != null)
			Paths.music(PauseSubState.songName);
		else if(ClientPrefs.pauseMusic != 'None')
			Paths.music(Paths.formatToSongPath(ClientPrefs.pauseMusic));

		cacheCountdown();
		cachePopUpScore();

		startCallback();

		resetRPC();
		callOnLuas('onCreatePost');
		stagesFunc(function(stage:BaseStage) stage.createPost());

		super.create();
		Paths.clearUnusedMemory();

		startingTime = haxe.Timer.stamp();

		#if android
		// Android media session / audio focus / wake lock integration.
		PlayStateAndroidMedia.start(this);
		#end
	}

	#if SHADERS_ALLOWED
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	public function createRuntimeShader(shaderName:String):ErrorHandledRuntimeShader
	{
		// REFACTOR: delegated to play.helpers
		return PlayStateScripts.createRuntimeShader(this, shaderName);
	}

	public function initLuaShader(name:String)
	{
		// REFACTOR: delegated to play.helpers
		return PlayStateScripts.initLuaShader(this, name);
	}
	#end

	inline function set_songSpeed(value:Float):Float
	{
		songSpeed = value;
		noteKillOffset = 350 / songSpeed;
		return value;
	}

	inline function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if(generatedMusic)
		{
			vocals.pitch = opponentVocals.pitch = value;
			FlxG.sound.music.pitch = value;
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		#if debug
		trace('Anim speed: ' + FlxG.animationTimeScale);
		#end
		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000 * value;
		setOnLuas('playbackRate', playbackRate);
		#else
		playbackRate = 1.0;
		#end
		return playbackRate;
	}

	inline function set_polyphony(value:Float, which:Int):Float
	{
		switch (which) {
		    case 0:
		        polyphonyOppo = value;
		        polyphonyBF = value;
		    case 1:
		        polyphonyOppo = value;
		    case 2:
		        polyphonyBF = value;
		    // just in case, as an anti-crash prevention maybe?
		    default:
				polyphonyOppo = value;
		        polyphonyBF = value;
		}
		return value;
	}

	inline function get_defaultCamZoom():Float
	{
		return _defaultCamZoom;
	}

	inline function set_defaultCamZoom(value:Float):Float
	{
		cameraTwn?.cancel();

		if (camZooming) {
			cameraTwn = FlxTween.tween(this, {_defaultCamZoom: value}, 2 / playbackRate / camZoomingDecay, {ease: FlxEase.expoOut, onComplete:
				function (twn:FlxTween) {
					cameraTwn = null;
				}
			});
		} else {
			_defaultCamZoom = value;
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: value}, 2 / playbackRate / camZoomingDecay, {ease: FlxEase.expoOut, onComplete:
				function (twn:FlxTween) {
					cameraTwn = null;
				}
			});
		}
		return value;
	}

	public function addTextToDebug(text:String, color:FlxColor) {
		// REFACTOR: delegated to play.helpers
		PlayStateScripts.addTextToDebug(this, text, color);
	}

	public function reloadHealthBarColors(leftColorArray:Array<Int>, rightColorArray:Array<Int>) {
		healthBar.createFilledBar(FlxColor.fromRGB(leftColorArray[0], leftColorArray[1], leftColorArray[2]),
		FlxColor.fromRGB(rightColorArray[0], rightColorArray[1], rightColorArray[2]));

		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		// REFACTOR: delegated to play.helpers
		PlayStateCharacters.addCharacterToList(this, newCharacter, type);
	}

	function startCharacterLua(name:String)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCharacters.startCharacterLua(this, name);
	}

	public function addShaderToCamera(cam:String,effect:Dynamic){//STOLE FROM ANDROMEDA	// actually i got it from old psych engine
		// REFACTOR: delegated to play.helpers
		PlayStateScripts.addShaderToCamera(this, cam, effect);
	}

	public function removeShaderFromCamera(cam:String,effect:Dynamic){
		// REFACTOR: delegated to play.helpers
		PlayStateScripts.removeShaderFromCamera(this, cam, effect);
	}

	public function clearShaderFromCamera(cam:String){
		// REFACTOR: delegated to play.helpers
		PlayStateScripts.clearShaderFromCamera(this, cam);
	}

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		// REFACTOR: delegated to play.helpers
		return PlayStateScripts.getLuaObject(this, tag, text);
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		// REFACTOR: delegated to play.helpers
		PlayStateCharacters.startCharacterPos(this, char, gfCheck);
	}

	/***************/
	/*    VIDEO    */
	/***************/
	public var videoCutscene:VideoSprite = null;
	public function startVideo(name:String, ?library:String = null, ?callback:Void->Void = null, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		// REFACTOR: delegated to play.helpers
		return PlayStateCutscenes.startVideo(this, name, library, callback, forMidSong, canSkip, loop, playOnLoad);
	}

	public function startAndEnd()
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCutscenes.startAndEnd(this);
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCutscenes.startDialogue(this, dialogueFile, song);
	}

	public function changeTheSettingsBitch() {
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.changeTheSettingsBitch(this);
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCountdown.cacheCountdown(this);
	}

	public static function formatNumber(number:Float, ?decimals:Bool = false):String //simplified number formatting
	{
		return (number < 10e11 ? FlxStringUtil.formatMoney(number, false) : CoolUtil.formatCompactNumber(number));
	}

	public function startCountdown():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCountdown.startCountdown(this);
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		// REFACTOR: delegated to play.helpers
		return PlayStateCountdown.createCountdownSprite(this, image, antialias);
	}

	public function addBehindGF(obj:FlxObject)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.addBehindGF(this, obj);
	}
	public function addBehindBF(obj:FlxObject)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.addBehindBF(this, obj);
	}
	public function addBehindDad (obj:FlxObject)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.addBehindDad(this, obj);
	}

	public function clearNotesBefore(time:Float)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.clearNotesBefore(this, time);
	}

	var comboInfo = ClientPrefs.showComboInfo;
	var showNPS = ClientPrefs.showNPS;
	var missString:String = '';
	public dynamic function updateScore(miss:Bool = false)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateRating.updateScore(this, miss);
	}

	public function setSongTime(time:Float)
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.setSongTime(this, time);
	}

	public function startNextDialogue() {
		// REFACTOR: delegated to play.helpers
		PlayStateCutscenes.startNextDialogue(this);
	}

	public function skipDialogue() {
		// REFACTOR: delegated to play.helpers
		PlayStateCutscenes.skipDialogue(this);
	}

	function startSong():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.startSong(this);
	}

	var ogSongSpeed:Float = 0;
	public function lerpSongSpeed(num:Float, time:Float):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.lerpSongSpeed(this, num, time);
	}

	var stair:Int = 0;
	var firstNoteData:Int = 0;
	var assignedFirstData:Bool = false;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
	private function generateSong(?startingPoint:Float = 0):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateChartLoader.generateSong(this, startingPoint);
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote) {
		// REFACTOR: delegated to play.helpers
		PlayStateEvents.eventPushed(this, event);
	}

	function eventPushedUnique(event:EventNote) {
		// REFACTOR: delegated to play.helpers
		PlayStateEvents.eventPushedUnique(this, event);
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		// REFACTOR: delegated to play.helpers
		return PlayStateEvents.eventNoteEarlyTrigger(this, event);
	}

	function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
	{
		// REFACTOR: delegated to play.helpers
		return PlayStateEvents.sortByTime(this, Obj1, Obj2);
	}

	function sortNotesByTime(Obj1:Note, Obj2:Note):Int {
		// REFACTOR: delegated to play.helpers
		return PlayStateEvents.sortNotesByTime(this, Obj1, Obj2);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.generateStaticArrows(this, player);
	}

	override function openSubState(SubState:flixel.FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				pauseVocals();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = false);
		}

		super.openSubState(SubState);
	}

	public var canResync:Bool = true;
	override function closeSubState()
	{
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong && canResync && !ffmpegMode)
			{
				resyncVocals();
			}

			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = true);
			paused = false;
			callOnLuas('onResume');
			resetRPC(startTimer != null && startTimer.finished);
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		try {if (health > 0 && !paused) resetRPC(Conductor.songPosition > 0.0);}
		catch(e) {};
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		#if DISCORD_ALLOWED
		try {if (health > 0 && !paused && autoUpdateRPC && FlxG.autoPause) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());}
		catch(e) {};
		#end

		super.onFocusLost();
	}

	// Updating Discord Rich Presence.
	public var autoUpdateRPC:Bool = true; //performance setting for custom RPC things
	function resetRPC(?showTime:Bool = false)
	{
		#if DISCORD_ALLOWED
		if(!autoUpdateRPC) return;

		if (showTime)
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
		else
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function resyncVocals():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.resyncVocals(this);
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	public var takenTime:Float = haxe.Timer.stamp();
	public var totalRenderTime:Float = 0;

	var noteLimit = ClientPrefs.maxNotes;
	var limitNC = 0;
	public var amountOfRenderedNotes:Float = 0;
	public var maxRenderedNotes:Float = 0;
	public var skippedCount:Float = 0;
	public var maxSkipped:Float = 0;

	var canUseBotEnergy:Bool = false;
	var usingBotEnergy:Bool = false;
	var noEnergy:Bool = false;
	var holdingBotEnergyBind:Bool = false;
	var strumsHeld:Array<Bool> = [false, false, false, false];
	var strumHeldAmount:Int = 0;
	var holdArray:Array<Bool> = [false, false, false, false];
	var pressArray:Array<Bool> = [false, false, false, false];
	var releaseArray:Array<Bool> = [false, false, false, false];
	var notesBeingHit:Bool = false;
	var notesBeingMissed:Bool = false;
	var hitResetTimer:Float = 0;
	var missResetTimer:Float = 0;
	var botEnergyCooldown:Float = 0;
	var energyDrainSpeed:Float = 1;
	var energyRefillSpeed:Float = 1;

	override public function update(elapsed:Float)
	{
		grpCrossFade.update(elapsed);
		grpCrossFade.forEachDead(function(img:CrossFade)
		{
			grpCrossFade.remove(img, true);
		});

		grpGFCrossFade.update(elapsed);
		grpGFCrossFade.forEachDead(function(img:CrossFade)
		{
			grpGFCrossFade.remove(img, true);
		});

		grpBFCrossFade.update(elapsed);
		grpBFCrossFade.forEachDead(function(img:CrossFade)
		{
			grpBFCrossFade.remove(img, true);
		});

		if (ffmpegMode) elapsed = 1 / ClientPrefs.targetFPS;
		if (screenshader.enabled)
		{
			if(disableTheTripperAt <= curStep || isDead)
				disableTheTripper = true;

			if(disableTheTripper)
			{
				screenshader.shader.waveAmplitude -= (elapsed / 2);
			}

			if (screenshader.shader.waveAmplitude > 0)
				screenshader.update(elapsed);
			else 
			{
				removeShaderFromCamera('camGame', screenshader);
				screenshader.enabled = false;
			}
			// FlxG.watch.addQuick("RainbowShaderAmp", screenshader.shader.waveAmplitude);
		}

		if (!cpuControlled && canUseBotEnergy)
		{
			if (controls.BOT_ENERGY_P && !noEnergy)
			{
				usingBotEnergy = true;
			}
			else
			{
				usingBotEnergy = false;
			}
			if (notesBeingHit && hitResetTimer >= 0)
			{
				health += elapsed / 2;
				hitResetTimer -= elapsed * playbackRate;
				if (hitResetTimer <= 0) notesBeingHit = false;
				if (missResetTimer > 0) missResetTimer -= 0.01 / (ClientPrefs.framerate / 60) * playbackRate;
			}
			if (notesBeingMissed && missResetTimer >= 0)
			{
				if (missResetTimer > 0.1) missResetTimer = 0.1;
				health -= missResetTimer / (ClientPrefs.framerate / 60) * playbackRate;
				missResetTimer -= elapsed * playbackRate;
				if (missResetTimer <= 0) notesBeingMissed = false;
			}
			if (usingBotEnergy)
				botEnergy -= (elapsed / 5) * strumHeldAmount * energyDrainSpeed * playbackRate;
			else
				botEnergy += (elapsed / 5) * energyRefillSpeed * playbackRate;

			if (botEnergy > 2) botEnergy = 2;

			if (botEnergy <= 0 && !noEnergy)
			{
				botEnergyCooldown = 1;
				noEnergy = true;
			}

			if (noEnergy)
			{
				botEnergyCooldown -= elapsed;
				if (botEnergyCooldown <= 0)
				{
					if (!controls.BOT_ENERGY_P)
						noEnergy = false;
				}
			}
		}

		if (botEnergy > 0.2 && botEnergy < 1.8) energyBar.color = energyTxt.color = 0xFF0094FF;
		if (botEnergy < 0.2) energyBar.color = energyTxt.color = 0xFFC60000;
		if (botEnergy > 1.8) energyBar.color = energyTxt.color = 0xFF00BC12;

		energyTxt.text = (botEnergy < 2 ? FlxMath.roundDecimal(botEnergy * 50, 0) + '%' : 'Full');
		energyTxt.y = (FlxG.height / 1.3) - (botEnergy * 50 * 4);

		callOnLuas('onUpdate', [elapsed]);
		super.update(elapsed);

		if (tankmanAscend && curStep > 895 && curStep < 1151) camGame.zoom = 0.8;

		if(!inCutscene && ClientPrefs.charsAndBG) {
			final lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed * playbackRate, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
			if (ClientPrefs.charsAndBG && !boyfriendIdled) {
				if(!startingSong && !endingSong && boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name.startsWith('idle')) {
					boyfriendIdleTime += elapsed;
					if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
						boyfriendIdled = true;
					}
				} else {
					boyfriendIdleTime = 0;
				}
			}
		}
		// REFACTOR: delegated to play.helpers
		PlayStateRating.updateNps(this);

		if (scoreTxtUpdateFrame > 0) scoreTxtUpdateFrame = 0;
		if (popUpsFrame > 0) popUpsFrame = 0;
		if (missRecalcsPerFrame > 0) missRecalcsPerFrame = 0;
		strumsHit = [false, false, false, false, false, false, false, false];
		for (i in 0...splashesPerFrame.length)
			if (splashesPerFrame[i] > 0) splashesPerFrame[i] = 0;

		if (hitImagesFrame > 0) hitImagesFrame = 0;

		if (lerpingScore) updateScore();
		if (shownScore != songScore && ClientPrefs.scoreStyle == 'JS Engine' && Math.abs(shownScore - songScore) >= 10) {
			shownScore = FlxMath.lerp(shownScore, songScore, 0.2 / ((!ffmpegMode ? ClientPrefs.framerate : targetFPS) / 60));
				lerpingScore = true; // Indicate that lerping is in progress
		} else {
			shownScore = songScore;
			lerpingScore = false;
			updateScore(); //Update scoreTxt one last time
		}

			if (!opponentChart) displayedHealth = ClientPrefs.smoothHealth ? FlxMath.lerp(displayedHealth, health, 0.1 / ((!ffmpegMode ? ClientPrefs.framerate : targetFPS) / 60)) : health;
			else displayedHealth = ClientPrefs.smoothHealth ? FlxMath.lerp(displayedHealth, maxHealth - health, 0.1 / ((!ffmpegMode ? ClientPrefs.framerate : targetFPS) / 60)) : maxHealth - health;

		setOnLuas('curDecStep', curDecStep);
		setOnLuas('curDecBeat', curDecBeat);

		if(botplayTxt != null && botplayTxt.visible && ClientPrefs.botTxtFade) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180 * playbackRate);
		}
		if(botplayTxt != null && cpuControlled && !botplayUsed) botplayUsed = true;

		if (controls.PAUSE && startedCountdown && canPause && !heyStopTrying)
		{
			final ret:Dynamic = callOnLuas('onPause', [], false);
			#if (LUA_ALLOWED || PYTHON_ALLOWED)
			if(ret != FunkinLua.Function_Stop)
				openPauseMenu();
			#else
			openPauseMenu();
			#end
		}

		if (FlxG.keys.anyJustPressed(debugKeysChart) && !endingSong && !inCutscene)
		{
			if (SONG.event7 != null && SONG.event7 != "---" && SONG.event7 != '' && SONG.event7 != 'None')
			switch(SONG.event7)
				{
				case "---" | null | '' | 'None':
				if (!ClientPrefs.antiCheatEnable)
				{
				openChartEditor();
				}
				else
				{
				PlayState.SONG = Song.loadFromJson('Anti-cheat-song', 'Anti-cheat-song');
				LoadingState.loadAndSwitchState(PlayState.new);
				}
				case "Game Over":
					health = 0;
				case "Go to Song":
						PlayState.SONG = Song.loadFromJson(SONG.event7Value + (CoolUtil.difficultyString() == 'NORMAL' ? '' : '-' + CoolUtil.difficulties[storyDifficulty]), SONG.event7Value);
				LoadingState.loadAndSwitchState(PlayState.new);
				case "Close Game":
					System.exit(0);
				case "Play Video":
					updateTime = false;
					FlxG.sound.music.volume = 0;
					vocals.volume = opponentVocals.volume = 0;
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					KillNotes();
					heyStopTrying = true;

					var bg = new FlxSprite(-FlxG.width, -FlxG.height).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
					add(bg);
					bg.cameras = [camHUD];
					startVideo(SONG.event7Value, function() #if sys Sys.exit(0) #else {} #end);
				}
			else if (!ClientPrefs.antiCheatEnable)
				{
					openChartEditor();
				}
				else
				{
					PlayState.SONG = Song.loadFromJson('Anti-cheat-song', 'Anti-cheat-song');
					LoadingState.loadAndSwitchState(PlayState.new);
				}
		}


		if (iconP1.animation.numFrames == 3) {
			if (healthBar.percent < 20)
				iconP1.animation.curAnim.curFrame = 1;
			else if (healthBar.percent > 80)
				iconP1.animation.curAnim.curFrame = 2;
			else
				iconP1.animation.curAnim.curFrame = 0;
		}
		else {
			if (healthBar.percent < 20)
				iconP1.animation.curAnim.curFrame = 1;
			else
				iconP1.animation.curAnim.curFrame = 0;
		}
		if (iconP2.animation.numFrames == 3) {
			if (healthBar.percent > 80)
				iconP2.animation.curAnim.curFrame = 1;
			else if (healthBar.percent < 20)
				iconP2.animation.curAnim.curFrame = 2;
			else
				iconP2.animation.curAnim.curFrame = 0;
		} else {
			if (healthBar.percent > 80)
				iconP2.animation.curAnim.curFrame = 1;
			else
				iconP2.animation.curAnim.curFrame = 0;
		}

		if (health > maxHealth)
			health = maxHealth;

		updateIconsScale(elapsed);
		updateIconsPosition();

		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene) {
			canResync = false;
			persistentUpdate = false;
			paused = true;
			if(FlxG.sound.music != null) FlxG.sound.music.stop();
			if (vocals != null) vocals.stop();
			if (opponentVocals != null) opponentVocals.stop();
			#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
			FlxG.switchState(new CharacterEditorState(SONG.player2));
		}

		if (startedCountdown && !paused)
		{
			debug.FrameProfiler.beginAudio();
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			if (!ffmpegMode)
			{
				if (Conductor.songPosition > Conductor.offset)
				{
					Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 5));
					var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
					if (timeDiff > 1000 * Math.max(playbackRate, 1))
						Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
				}
				if (Conductor.songPosition < 200 && Math.abs(vocals.time - FlxG.sound.music.time) >= 20) setVocalsTime(FlxG.sound.music.time);
			}
			debug.FrameProfiler.endAudio();
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= 0)
				startSong();
			else if(!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5;
		}
		else
		{
			if (!paused)
			{
				if(updateTime)
				{
					songPercent = (Conductor.songPosition - ClientPrefs.noteOffset) / songLength;

					if (Conductor.songPosition - lastUpdateTime >= 1.0)
					{
						lastUpdateTime = Conductor.songPosition;
						if (ClientPrefs.timeBarType != 'Song Name')
						{
							timeTxt.text = ClientPrefs.timeBarType.contains('Time Left') ? CoolUtil.getSongDuration(Conductor.songPosition, songLength) : CoolUtil.formatTime(Conductor.songPosition)
							+ (ClientPrefs.timeBarType.contains('Modern Time') ? ' / ' + CoolUtil.formatTime(songLength) : '');

							if (ClientPrefs.timeBarType == 'Song Name + Time')
								timeTxt.text = SONG.song + ' (' + CoolUtil.formatTime(Conductor.songPosition) + ' / ' + CoolUtil.formatTime(songLength) + ')';
						}

						if (cpuControlled && ClientPrefs.timeBarType != 'Song Name' && ClientPrefs.botWatermark) timeTxt.text += ' (Bot)';
					}
				}
				if(ffmpegMode) {
					if(!endingSong && Conductor.songPosition >= FlxG.sound.music.length - 20) {
						finishSong();
						endSong();
					}
				}
			}
		}

		if (camZooming)
		{
			camBopFactor = FlxMath.lerp(0, camBopFactor, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));

			FlxG.camera.zoom = defaultCamZoom + camBopFactor;
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
		}

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong && !heyStopTrying)
		{
			doDeathCheck(true);
			trace("RESET = True");
		}
		if (health <= 0) doDeathCheck();

		skippedCount = 0;

		spawnNotes();

		if (generatedMusic)
		{
			if(!inCutscene)
			{
				if(!cpuControlled) {
					handleKeyInput();
				}
				else if (ClientPrefs.charsAndBG) playerDance();

				amountOfRenderedNotes = 0;
				notes.forEach(updateNote);
				if (notes.length > 1)
					notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
				sustainNotes.forEach(updateNote);
				if (sustainNotes.length > 1)
					sustainNotes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
			}

			destroyNotes();

			while(eventNotes.length > 0 && eventNotes[eventIndex] != null && Conductor.songPosition > eventNotes[eventIndex].strumTime) {
				var value1:String = '';
				if(eventNotes[eventIndex].value1 != null)
					value1 = eventNotes[eventIndex].value1;

				var value2:String = '';
				if(eventNotes[eventIndex].value2 != null)
					value2 = eventNotes[eventIndex].value2;

				triggerEventNote(eventNotes[eventIndex].event, value1, value2, eventNotes[eventIndex].strumTime);
				eventIndex++;
			}
		}

		#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
			if(FlxG.keys.justPressed.THREE) { //Go 10 seconds back into the past :O
				setSongTime(Conductor.songPosition - 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		if ((trollingMode || SONG.song.toLowerCase() == 'anti-cheat-song') && startedCountdown && canPause && !endingSong) {
			if (FlxG.sound.music.length - Conductor.songPosition <= endingTimeLimit) {
				KillNotes(); //kill any existing notes
				FlxG.sound.music.time = 0;
				if (SONG.needsVoices) setVocalsTime(0);
				lastUpdateTime = 0.0;
				Conductor.songPosition = 0;
				notesAddedCount = eventIndex = 0;

				if (SONG.song.toLowerCase() != 'anti-cheat-song')
				{
						var noteIndex:Int = 0;
						while (unspawnNotes.length > 0 && unspawnNotes[noteIndex] != null)
						{
							unspawnNotes[noteIndex].wasHit = false;
							noteIndex++;
						}
				}
				if (canResync) resyncVocals();
				SONG.song.toLowerCase() != 'anti-cheat-song' ? loopSongLol() : loopCallback(0);
			}
		}

		if (ClientPrefs.showRendered)
		{
			if (!ffmpegMode) renderedTxt.text = 'Rendered/Skipped: ${formatNumber(amountOfRenderedNotes)}/${formatNumber(skippedCount)}/${formatNumber(maxRenderedNotes)}/${formatNumber(maxSkipped)}';
			else renderedTxt.text = 'Rendered Notes: ${formatNumber(amountOfRenderedNotes)}/${formatNumber(maxRenderedNotes)}/${formatNumber(notes.members.length + sustainNotes.members.length)}';
		}

		setOnLuas('cameraX', camFollowPos.x);
		setOnLuas('cameraY', camFollowPos.y);
		setOnLuas('botPlay', cpuControlled);
		callOnLuas('onUpdatePost', [elapsed]);

		if (shaderUpdates.length > 0)
			for (i in shaderUpdates){
				i(elapsed);
			}

		if (ffmpegMode)
		{
			if (!ClientPrefs.oldFFmpegMode) pipeFrame();
			else
			{
				var filename = CoolUtil.zeroFill(frameCaptured, 7);
				try {
					capture.save(renderPath + Paths.formatToSongPath(SONG.song) + #if !windows '/' #else '\\' #end, filename);
				}
				catch (e) //If it catches an error, try capturing the frame again. If it still catches an error, skip the frame
				{
					try {
						capture.save(renderPath + Paths.formatToSongPath(SONG.song) + #if !windows '/' #else '\\' #end, filename);
					}
					catch (e) {}
				}
			}
			if (ClientPrefs.renderGCRate > 0 && (frameCaptured / targetFPS) % ClientPrefs.renderGCRate == 0)
			{
				debug.FrameProfiler.beginGC(true);
				System.gc();
				debug.FrameProfiler.endGC();
			}
			frameCaptured++;
		}
	}

	// Health icon updaters
	// This variable tracks the reset time for the Dave & Bambi/Strident Crisis icons.
	var iconSizeResetTime:Float = 0;
	public dynamic function updateIconsScale(elapsed:Float)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.updateIconsScale(this, elapsed);
	}

	var percent:Float = 0;
	var center:Float = 0;
	public dynamic function updateIconsPosition()
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.updateIconsPosition(this);
	}

	function openPauseMenu()
	{
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		if(FlxG.sound.music != null) {
			FlxG.sound.music.pause();
			pauseVocals();
		}
		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		if(autoUpdateRPC) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function openChartEditor()
	{
		canResync = false;
		persistentUpdate = false;
		paused = true;
		if(FlxG.sound.music != null) FlxG.sound.music.stop();
		chartingMode = true;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end
		FlxG.switchState(new ChartingState());
	}

	public function loopCallback(startingPoint:Float = 0)
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.loopCallback(this, startingPoint);
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	public var gameOverTimer:FlxTimer;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if ((skipHealthCheck || health <= 0) && !practiceMode && !isDead)
		{
			var ret:Dynamic = callOnLuas('onGameOver', [], false);
			stagesFunc(function(stage:BaseStage) stage.onGameOver());
			#if (LUA_ALLOWED || PYTHON_ALLOWED)
			if(ret != FunkinLua.Function_Stop) {
				boyfriend.stunned = true;
				deathCounter++;

				canResync = false;
				paused = true;

				vocals.stop();
				opponentVocals.stop();
				FlxG.sound.music.stop();

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				#if (LUA_ALLOWED || PYTHON_ALLOWED)
				modchartTimers.clear();
				modchartTweens.clear();
				#end
				FlxG.camera.filters = [];

				if(GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend, PlayState.instance));
						gameOverTimer = null;
					});
				}
				else
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend, PlayState.instance));
				}

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if(autoUpdateRPC) DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
			#else
			boyfriend.stunned = true;
			deathCounter++;

			canResync = false;
			paused = true;

			vocals.stop();
			opponentVocals.stop();
			FlxG.sound.music.stop();

			persistentUpdate = false;
			persistentDraw = false;
			FlxTimer.globalManager.clear();
			FlxTween.globalManager.clear();
			FlxG.camera.filters = [];

			if(GameOverSubstate.deathDelay > 0)
			{
				gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend, PlayState.instance));
					gameOverTimer = null;
				});
			}
			else
			{
				vocals.stop();
				opponentVocals.stop();
				FlxG.sound.music.stop();
				openSubState(new GameOverSubstate(boyfriend, PlayState.instance));
			}

			#if DISCORD_ALLOWED
			if(autoUpdateRPC) DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			#end
			isDead = true;
			return true;
			#end
		}
		return false;
	}

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String, strumTime:Float) {
		// REFACTOR: delegated to play.helpers
		PlayStateEvents.triggerEventNote(this, eventName, value1, value2, strumTime);
	}

	function sendWindowsNotification(title:String, desc:String, isEvent:Bool = false) {
		// REFACTOR: delegated to play.helpers
		PlayStateEvents.sendWindowsNotification(this, title, desc, isEvent);
	}

	public function moveCameraSection():Void {
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.moveCameraSection(this);
	}

	var cameraTwn:FlxTween;
	public function moveCamera(focus:String = "bf")
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.moveCamera(this, focus);
	}

	function snapCamFollowToPos(x:Float, y:Float) {
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.snapCamFollowToPos(this, x, y);
	}

	public function unpauseVocals()
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.unpauseVocals(this);
	}
	public function pauseVocals()
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.pauseVocals(this);
	}
	public function setVocalsTime(time:Float)
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.setVocalsTime(this, time);
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.finishSong(this, ignoreNoteOffset);
	}

	public function loopSongLol()
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.loopSongLol(this);
	}

	function calculateTrollModeStuff(pb:Float):Float {
		// REFACTOR: delegated to play.helpers
		return PlayStatePlayback.calculateTrollModeStuff(this, pb);
	}

	function calculateResetTime():Float {
		// REFACTOR: delegated to play.helpers
		return PlayStatePlayback.calculateResetTime(this);
	}

	public var transitioning = false;
	public function endSong():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.endSong(this);
	}

	public function KillNotes() {
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.KillNotes(this);
	}

	public function restartSong(noTrans:Bool = true)
	{
		// REFACTOR: delegated to play.helpers
		PlayStatePlayback.restartSong(this, noTrans);
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;
	public var totalNotes:Float = 0;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	// Stores Ratings and Combo Sprites in a group
	public var popUpGroup:FlxTypedSpriteGroup<Popup>;

	private function cachePopUpScore()
	{
		// REFACTOR: delegated to play.helpers
		PlayStateRating.cachePopUpScore(this);
	}

	var rating:Popup = null;
	var numScore:Popup = null;
	var daRating:Rating = null;
	var noteDiff = 0.0;

	function judgeNote(note:Note = null, ?miss:Bool = false)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateRating.judgeNote(this, note, miss);
	}

	var separatedScore:Array<Dynamic> = [];
	private function popUpScore(note:Note = null, ?miss:Bool = false):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateRating.popUpScore(this, note, miss);
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateInput.onKeyPress(this, event);
	}

	public var strumsBlocked:Array<Bool> = [];
	private function keyPressed(key:Int):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateInput.keyPressed(this, key);
	}

	function sortHitNotes(a:Dynamic, b:Dynamic):Int
	{
		// REFACTOR: delegated to play.helpers
		return PlayStateInput.sortHitNotes(a, b);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateInput.onKeyRelease(this, event);
	}

	private function keyReleased(key:Int)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateInput.keyReleased(this, key);
	}

	public function getKeyFromEvent(key:FlxKey):Int
	{
		// REFACTOR: delegated to play.helpers
		return PlayStateInput.getKeyFromEvent(this, key);
	}

	// Hold notes
	private function handleKeyInput():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateInput.handleKeyInput(this);
	}

	public function parseKeys(ret:Array<Bool>, ?suffix:String = ''):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateInput.parseKeys(this, ret, suffix);
	}

	function noteMiss(daNote:Note = null, daNoteAlt:PreloadedChartNote = null):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		if (daNote != null)
		{
			// REFACTOR: delegated to play.helpers
			PlayStateNotes.noteMiss(this, daNote, daNoteAlt);
		}
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNotes.noteMissPress(this, direction);
	}

	//This function handles note spawning.
	var NOTE_SPAWN_TIME:Float = 0;
	var targetNote:PreloadedChartNote = null;
	var spawnedNote:Note;
	function spawnNotes()
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNotes.spawnNotes(this);
	}

	function updateNote(daNote:Note):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNotes.updateNote(this, daNote);
	}

	var oppTrigger:Bool = false;
	var doGf:Bool = false;
	var playerChar = null;
	var canPlay = true;
	var holdAnim:String = '';
	var animToPlay:String = 'singLEFT';
	var animCheck:String = 'hey';
	function goodNoteHit(note:Note, noteAlt:PreloadedChartNote = null):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNotes.goodNoteHit(this, note, noteAlt);
	}

	var oppChar = null;
	var gfTrigger:Bool = false;
	function opponentNoteHit(daNote:Note, noteAlt:PreloadedChartNote = null):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNotes.opponentNoteHit(this, daNote, noteAlt);
	}

	public function invalidateNote(note:Note):Void {
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.invalidateNote(this, note);
	}

	var noteKill:Note = null;
	public function destroyNotes():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.destroyNotes(this);
	}

	public function spawnHoldSplashOnNote(note:Note, ?isDad:Bool = false) {
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.spawnHoldSplashOnNote(this, note, isDad);
	}

	public function spawnHoldSplash(note:Note) {
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.spawnHoldSplash(this, note);
	}

	public function spawnNoteSplashOnNote(isDad:Bool, note:Note) {
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.spawnNoteSplashOnNote(this, isDad, note);
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		// REFACTOR: delegated to play.helpers
		PlayStateNoteHelpers.spawnNoteSplash(this, x, y, data, note);
	}

	override function destroy() {
		#if android
		PlayStateAndroidMedia.stop(this);
		#end

		#if LUA_ALLOWED
		for (lua in luaArray) {
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = [];
		FunkinLua.customFunctions.clear();
		FunkinLua.registeredFunctions.clear();
		#end

		#if PYTHON_ALLOWED
		for (python in pythonArray) {
			python.call('onDestroy', []);
			python.stop();
		}
		pythonArray = [];
		PythonScript.customFunctions.clear();
		PythonScript.registeredFunctions.clear();
		#end

		if (camFollow != null) camFollow.put();

		/*
		#if HSCRIPT_ALLOWED
		if(FunkinLua.hscript != null) FunkinLua.hscript = null;
		#end
		*/

		stagesFunc(function(stage:BaseStage) stage.destroy());

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		FlxG.animationTimeScale = 1;
		FlxG.sound.music.pitch = 1;
		#if cpp
		cpp.vm.Gc.enable(true);
		#end
		KillNotes();
		unspawnNotes = [];
		eventNotes = [];
		MusicBeatState.windowNamePrefix = Assets.getText(Paths.txt("windowTitleBase", "preload"));
		if(ffmpegMode) {
			if (FlxG.fixedTimestep) {
				FlxG.fixedTimestep = false;
				FlxG.animationTimeScale = 1;
			}
			if(unlockFPS) {
				FlxG.drawFramerate = ClientPrefs.framerate;
				FlxG.updateFramerate = ClientPrefs.framerate;
			}
		}

		Paths.noteSkinFramesMap.clear();
		Paths.noteSkinAnimsMap.clear();
		Paths.splashSkinFramesMap.clear();
		Paths.splashSkinAnimsMap.clear();
		Paths.splashConfigs.clear();
		Paths.splashAnimCountMap.clear();
		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();

		super.destroy();
	}

	override function stepHit()
	{
		super.stepHit();

		// REFACTOR: delegated to play.helpers
		if (tankmanAscend) PlayStateCamera.tankmanStep(this);

		setOnLuas('curStep', curStep);
		callOnLuas('onStepHit');
	}

	var lastBeatHit:Int = -1;
	var twisted = false;

	override function beatHit()
	{
		super.beatHit();

		if (lastBeatHit == curBeat) return;

		if (curBeat % 32 == 0 && randomSpeedThing)
		{
			var randomSpeed = FlxMath.roundDecimal(FlxG.random.float(minSpeed, maxSpeed), 2);
			lerpSongSpeed(randomSpeed, 1);
		}
		if (camZooming && !endingSong && !startingSong && camHUD.zoom < 1.35 && usingBopIntervalEvent && ClientPrefs.camZooms && (curBeat % camBopInterval == 0))
		{
			camBopFactor += 0.015 * camBopIntensity;
			camHUD.zoom += 0.03 * camBopIntensity;
		} /// WOOO YOU CAN NOW MAKE IT AWESOME

		if (camTwist && curBeat % gfSpeed == 0)
		{
			doTwist();
		}

		if (iconP1.visible || iconP2.visible)
			bopIcons();

		if (ClientPrefs.charsAndBG) characterBopper(curBeat);
		lastBeatHit = curBeat;

		setOnLuas('curBeat', curBeat); //DAWGG?????
		callOnLuas('onBeatHit');
	}
	public function characterBopper(beat:Int):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.characterBopper(this, beat);
	}

	public function playerDance():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.playerDance(this);
	}

	public function doTwist()
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.doTwist(this);
	}

	var usingBopIntervalEvent = false;
	override function sectionHit()
	{
		super.sectionHit();

		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
			{
				moveCameraSection();
			}

			if (ClientPrefs.timeBarStyle == 'Leather Engine') timeBar.color = SONG.notes[curSection].mustHitSection ? FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]) : FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]);

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.changeBPM(SONG.notes[curSection].bpm);
				SustainSplash.startCrochet = Conductor.stepCrochet;
				SustainSplash.frameRate = Math.floor(24 / 100 * Conductor.bpm);
				setOnLuas('curBpm', Conductor.bpm);
				setOnLuas('crochet', Conductor.crochet);
				setOnLuas('stepCrochet', Conductor.stepCrochet);
				if (Conductor.bpm >= 500) singDurMult = gfSpeed;
				else singDurMult = 1;
			}
			setOnLuas('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnLuas('altAnim', SONG.notes[curSection].altAnim);
			setOnLuas('gfSection', SONG.notes[curSection].gfSection);
			if (camZooming && !endingSong && !startingSong && camHUD.zoom < 1.35 && !usingBopIntervalEvent && ClientPrefs.camZooms)
			{
				camBopFactor += 0.015 * camBopIntensity;
				camHUD.zoom += 0.03 * camBopIntensity;
			}
		}

		setOnLuas('curSection', curSection);
		callOnLuas('onSectionHit');
	}

	public function bopIcons(?bopBF:Bool = false)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateCamera.bopIcons(this, bopBF);
	}

	#if LUA_ALLOWED
	public function startLuasOnFolder(luaFile:String)
	{
		for (script in luaArray)
		{
			if(script.scriptName == luaFile) return false;
		}

		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(luaToLoad))
		{
			new FunkinLua(luaToLoad);
			return true;
		}
		else
		{
			luaToLoad = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaToLoad))
			{
				new FunkinLua(luaToLoad);
				return true;
			}
		}
		#elseif sys
		var luaToLoad:String = Paths.getPreloadPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		{
			new FunkinLua(luaToLoad);
			return true;
		}
		#end
		return false;
	}
	#end

	#if PYTHON_ALLOWED
	public function startPythonScriptOnFolder(pyFile:String)
	{
		for (script in pythonArray)
		{
			if(script.scriptName == pyFile) return false;
		}

		#if MODS_ALLOWED
		var pyToLoad:String = Paths.modFolders(pyFile);
		if(FileSystem.exists(pyToLoad))
		{
			new PythonScript(pyToLoad);
			return true;
		}
		else
		{
			pyToLoad = Paths.getPreloadPath(pyFile);
			if(FileSystem.exists(pyToLoad))
			{
				new PythonScript(pyToLoad);
				return true;
			}
		}
		#elseif sys
		var pyToLoad:String = Paths.getPreloadPath(pyFile);
		if(OpenFlAssets.exists(pyToLoad))
		{
			new PythonScript(pyToLoad);
			return true;
		}
		#end
		return false;
	}
	#end

	/**
	 * Dispatch a callback to every Lua AND Python script. Returns the last
	 * non-`Function_Continue` value returned by any script.
	 */
	public function callOnScripts(event:String, args:Array<Dynamic> = null, ignoreStops = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		#if LUA_ALLOWED
		var returnVal = FunkinLua.Function_Continue;
		#elseif PYTHON_ALLOWED
		var returnVal = PythonScript.Function_Continue;
		#else
		var returnVal:Dynamic = null;
		#end
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [];

		var stopAll:Bool = false;

		#if LUA_ALLOWED
		for (script in luaArray) {
			if(stopAll) break;
			if(exclusions.contains(script.scriptName))
				continue;

			final myValue = script.call(event, args);
			if(myValue == FunkinLua.Function_StopLua && !ignoreStops) {
				stopAll = true;
				break;
			}

			if(myValue != null && myValue != FunkinLua.Function_Continue) {
				returnVal = myValue;
			}
		}
		#end

		#if PYTHON_ALLOWED
		for (script in pythonArray) {
			if(stopAll) break;
			if(exclusions.contains(script.scriptName))
				continue;

			final myValue = script.call(event, args);
			if(myValue == PythonScript.Function_StopAll && !ignoreStops) {
				stopAll = true;
				break;
			}

			if(myValue != null && myValue != PythonScript.Function_Continue) {
				returnVal = myValue;
			}
		}
		#end
		return returnVal;
	}

	public inline function hasActiveScripts():Bool {
		var hasScripts = false;
		#if LUA_ALLOWED
		if (luaArray.length > 0) hasScripts = true;
		#end
		#if PYTHON_ALLOWED
		if (pythonArray.length > 0) hasScripts = true;
		#end
		return hasScripts;
	}

	// Kept for compatibility: dispatches to both Lua and Python scripts.
	public function callOnLuas(event:String, args:Array<Dynamic> = null, ignoreStops = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		if (!hasActiveScripts()) return null;
		return callOnScripts(event, args, ignoreStops, exclusions, excludeValues);
	}

	public function setOnScripts(variable:String, arg:Dynamic) {
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			luaArray[i].set(variable, arg);
		}
		#end

		#if PYTHON_ALLOWED
		for (i in 0...pythonArray.length) {
			pythonArray[i].set(variable, arg);
		}
		#end
	}

	// Kept for compatibility: dispatches to both Lua and Python scripts.
	public function setOnLuas(variable:String, arg:Dynamic) {
		setOnScripts(variable, arg);
	}

	function StrumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = isDad ? opponentStrums.members[id] : playerStrums.members[id];

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingString:String;
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating(badHit:Bool = false) {
		// REFACTOR: delegated to play.helpers
		PlayStateRating.RecalculateRating(this, badHit);
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		// REFACTOR: delegated to play.helpers
		PlayStateRating.checkForAchievement(this, achievesToCheck);
	}
	#end

	var curLight:Int = -1;
	var curLightEvent:Int = -1;

	#if sys
	public static var process:Process;
	var ffmpegExists:Bool = false;
	#end

	private function initRender(renderPath:String = "assets/gameRenders/", ?prefixName:String = null):Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateRender.initRender(this, renderPath, prefixName);
	}

	var img = null;
	var bytes = null;
	private function pipeFrame():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateRender.pipeFrame(this);
	}

	public static function stopRender():Void
	{
		// REFACTOR: delegated to play.helpers
		PlayStateRender.stopRender();
	}
}


