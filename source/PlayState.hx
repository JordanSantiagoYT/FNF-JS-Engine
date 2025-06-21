package;

import Achievements;
import Character.Boyfriend;
import Conductor.Rating;
import DialogueBoxPsych;
import FunkinLua;
import Note.EventNote;
import Note.PreloadedChartNote;
import Note;
import Section.SwagSection;
import Shaders;
import Song.SwagSong;
import StageData;
import editors.CharacterEditorState;
import editors.ChartingState;
import flixel.FlxObject;
import flixel.input.keyboard.FlxKey;
import flixel.ui.FlxBar;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import haxe.Json;
import lime.system.System;
import lime.utils.Assets;
import objects.*;
import openfl.events.KeyboardEvent;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets as OpenFlAssets;
import utils.*;

using StringTools;
#if !flash
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
#end


class PlayState extends MusicBeatState
{
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public static var instance:PlayState;
	public static var STRUM_X = 48.5;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var middleScroll:Bool = false;

	public static var ratingStuff:Array<Dynamic> = [];

	private var tauntKey:Array<FlxKey>;

	public var camGameShaders:Array<ShaderEffect> = [];
	public var camHUDShaders:Array<ShaderEffect> = [];
	public var camOtherShaders:Array<ShaderEffect> = [];

	var lastUpdateTime:Float = 0.0;

	//event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Boyfriend> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	public var variables:Map<String, Dynamic> = new Map();
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
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

	var randomBotplayText:String;

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
	public var firstNoteStrumTime:Float = 0;
	var winning:Bool = false;
	var losing:Bool = false;

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
	public var unspawnNotesCopy:Array<PreloadedChartNote> = [];
	public var eventNotes:Array<EventNote> = [];
	public var eventNotesCopy:Array<EventNote> = [];

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
	public var laneunderlay:FlxSprite;
	public var laneunderlayOpponent:FlxSprite;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
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
		var notesToRemoveCount:Int = 0;
		var oppNotesToRemoveCount:Int = 0;
	public var iconBopsThisFrame:Int = 0;
	public var iconBopsTotal:Int = 0;

	var endingTimeLimit:Int = 20;

	var camBopInterval:Float = 4;
	var camBopIntensity:Float = 1;

	var twistShit:Float = 1;
	var twistAmount:Float = 1;
	var camTwistIntensity:Float = 0;
	var camTwistIntensity2:Float = 3;
	var camTwist:Bool = false;

	private var healthBarBG:AttachedSprite; //The image used for the health bar.
	public var healthBar:FlxBar;
	var songPercent:Float = 0;
	var playbackRateDecimal:Float = 0;

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
	public var shits:Int = 0;
	public var nps:Float = 0;
	public var maxNPS:Float = 0;
	public var oppNPS:Float = 0;
	public var maxOppNPS:Float = 0;
	public var enemyHits:Float = 0;
	public var opponentNoteTotal:Float = 0;
	public var polyphonyOppo:Float = 1;
	public var polyphonyBF:Float = 1;

	var pixelShitPart1:String = "";
	var pixelShitPart2:String = '';

	public var oldNPS:Float = 0;
	public var oldOppNPS:Float = 0;

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
	public var judgeCountStrings:Array<String> = ['Perfects', 'Sicks', 'Goods', 'Bads', 'Shits', 'Misses'];

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
		if (botplayTxt != null && !ClientPrefs.showcaseMode) // this assures it'll always show up
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

	private var npsIncreased:Bool = false;
	private var npsDecreased:Bool = false;

	private var oppNpsIncreased:Bool = false;
	private var oppNpsDecreased:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;
	public var renderedTxt:FlxText;
	public var ytWatermark:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;
	var secretsong:FlxSprite;
	var hitsoundImage:FlxSprite;
	var hitsoundImageToLoad:String;

	//ok moxie this doesn't cause memory leaks
	public var scoreTxtUpdateFrame:Int = 0;
	public var judgeCountUpdateFrame:Int = 0;
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

	public static var screenshader:Shaders.PulseEffectAlt = new PulseEffectAlt();

	var disableTheTripper:Bool = false;
	var disableTheTripperAt:Int;

	var heyTimer:Float;

	public var singDurMult:Int = 1;

	//ms timing popup shit
	public var msTxt:FlxText;
	public var msTimer:FlxTimer = null;
	public var restartTimer:FlxTimer = null;

	//ms timing popup shit except for simplified ratings
	public var judgeTxt:FlxText;
	public var judgeTxtTimer:FlxTimer = null;

	public var oppScore:Float = 0;
	public var songScore:Float = 0;
	public var songHits:Int = 0;
	public var songMisses:Float = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;

	var hitTxt:FlxText;

	var scoreTxtTween:FlxTween;
	var timeTxtTween:FlxTween;
	var judgementCounter:FlxText;

	public static var campaignScore:Float = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public static var shouldDrainHealth:Bool = false;

	public var defaultCamZoom:Float = 1.05;

	public var ogCamZoom:Float = 1.05;

	var ogBotTxt:String = '';

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

	#if desktop
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
	public var luaArray:Array<FunkinLua> = [];
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	public var introSoundsSuffix:String = '';

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;
	private var controlArray:Array<String>;

	public var songName:String;

	//cam panning
	var moveCamTo:HaxeVector<Float> = new HaxeVector(2);

	var getTheBotplayText:Int = 0;

	var theListBotplay:Array<String> = [];

		var formattedScore:String;
		var formattedSongMisses:String;
		var formattedCombo:String;
		var formattedMaxCombo:String;
		var formattedNPS:String;
		var formattedMaxNPS:String;
		var formattedOppNPS:String;
		var formattedMaxOppNPS:String;
		var formattedEnemyHits:String;
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
	var ffmpegInfo = ClientPrefs.ffmpegInfo;
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
		}
		if (ffmpegMode) {
			if (unlockFPS)
			{
				FlxG.updateFramerate = 1000;
				FlxG.drawFramerate = 1000;
			}
			FlxG.fixedTimestep = true;
			FlxG.animationTimeScale = ClientPrefs.framerate / targetFPS;
			if (!ClientPrefs.oldFFmpegMode) initRender();
		}
		theListBotplay = CoolUtil.coolTextFile(Paths.txt('botplayText'));

		if (FileSystem.exists(Paths.getSharedPath('sounds/hitsounds/' + ClientPrefs.hitsoundType.toLowerCase() + '.txt')))
			hitsoundImageToLoad = File.getContent(Paths.getSharedPath('sounds/hitsounds/' + ClientPrefs.hitsoundType.toLowerCase() + '.txt'));
		else if (FileSystem.exists(Paths.modFolders('sounds/hitsounds/' + ClientPrefs.hitsoundType.toLowerCase() + '.txt')))
			hitsoundImageToLoad = File.getContent(Paths.modFolders('sounds/hitsounds/' + ClientPrefs.hitsoundType.toLowerCase() + '.txt'));

		randomBotplayText = theListBotplay[FlxG.random.int(0, theListBotplay.length - 1)];

		inline cpp.vm.Gc.enable(ClientPrefs.enableGC || ffmpegMode && !ClientPrefs.noRenderGC); //lagspike prevention
		inline Paths.clearStoredMemory();

		#if sys
		openfl.system.System.gc();
		#end

		// for lua
		instance = this;

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed', 1);
		tauntKey = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('qt_taunt'));

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
		screenshader.shader.uTime.value[0] = new flixel.math.FlxRandom().float(-100000, 100000);
		screenshader.shader.uampmul.value[0] = 0;

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

		if (ClientPrefs.showcaseMode || ffmpegMode)
			cpuControlled = true;

		// var gameCam:FlxCamera = FlxG.camera;
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
			SONG = Song.loadFromJson('tutorial');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		if (!chartingMode) CoolUtil.currentDifficulty = CoolUtil.difficultyString();

		#if desktop
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
		if(SONG.stage == null || SONG.stage.length < 1) {
			switch (songName)
			{
				case 'spookeez' | 'south' | 'monster':
					curStage = 'spooky';
				case 'pico' | 'blammed' | 'philly' | 'philly-nice':
					curStage = 'philly';
				case 'milf' | 'satin-panties' | 'high':
					curStage = 'limo';
				case 'cocoa' | 'eggnog':
					curStage = 'mall';
				case 'winter-horrorland':
					curStage = 'mallEvil';
				case 'senpai' | 'roses':
					curStage = 'school';
				case 'thorns':
					curStage = 'schoolEvil';
				case 'ugh' | 'guns' | 'stress':
					curStage = 'tank';
				default:
					curStage = 'stage';
			}
		}
		SONG.stage = curStage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		if(stageData == null) { //Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = {
				directory: "",
				defaultZoom: 0.9,
				isPixelStage: false,
				stageUI: "normal",

				boyfriend: [770, 100],
				girlfriend: [400, 130],
				opponent: [100, 100],
				hide_girlfriend: true,

				camera_boyfriend: [0, 0],
				camera_opponent: [0, 0],
				camera_girlfriend: [0, 0],
				camera_speed: 1
			};
		}

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else {
			if (stageData.isPixelStage)
				stageUI = "pixel";
		}

		defaultCamZoom = ogCamZoom = stageData.defaultZoom;
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
		add(gfGroup); //Needed for blammed lights

		add(dadGroup);
		add(boyfriendGroup);

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		// "GLOBAL" SCRIPTS
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('scripts/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/scripts/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/scripts/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		#end

		// STAGE SCRIPTS
		#if (MODS_ALLOWED && LUA_ALLOWED)
		startLuasOnFolder('stages/' + curStage + '.lua');
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

		var ratingQuoteStuff:Array<Dynamic> = Paths.mergeAllTextsNamed('data/ratingQuotes/${ClientPrefs.rateNameStuff}.txt', '', true);
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

		laneunderlayOpponent = new FlxSprite(70, 0).makeGraphic(500, FlxG.height * 2, FlxColor.BLACK);
		laneunderlayOpponent.alpha = ClientPrefs.laneUnderlayAlpha;
		laneunderlayOpponent.scrollFactor.set();
		laneunderlayOpponent.screenCenter(Y);
		laneunderlayOpponent.visible = ClientPrefs.laneUnderlay;

		laneunderlay = new FlxSprite(70 + (FlxG.width / 2), 0).makeGraphic(500, FlxG.height * 2, FlxColor.BLACK);
		laneunderlay.alpha = ClientPrefs.laneUnderlayAlpha;
		laneunderlay.scrollFactor.set();
		laneunderlay.screenCenter(Y);
		laneunderlay.visible = ClientPrefs.laneUnderlay;

		if (ClientPrefs.laneUnderlay)
		{
			insert(1, laneunderlayOpponent);
			insert(1, laneunderlay);
		}

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

		trace ('Loading chart...');
		generateSong(SONG.song, startOnTime);

		callOnLuas('onCreate');

		if (SONG.event7 == null || SONG.event7 == '') SONG.event7 == 'None';

		if (curSong.toLowerCase() == "guns") // added this to bring back the old 2021 fnf vibes, i wish the fnf fandom revives one day :(
		{
			final randomVar:Int = (ClientPrefs.noGunsRNG) ? 8 : Std.random(15);
			trace(randomVar);
			if (randomVar == 8)
			{
				trace('AWW YEAH, ITS ASCENDING TIME');
				tankmanAscend = true;
			}
		}

		if (notes.members[0] != null) firstNoteStrumTime = notes.members[0].strumTime;

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
		if (!ClientPrefs.charsAndBG) FlxG.camera.zoom = 100; //zoom it in very big to avoid high RAM usage!!
		if (ClientPrefs.charsAndBG)
		{
			FlxG.camera.follow(camFollowPos, LOCKON, 1);
			FlxG.camera.zoom = defaultCamZoom;
			FlxG.camera.snapToTarget();

			FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		}
		moveCameraSection();

		msTxt = new FlxText(0, 0, 0, "");
		msTxt.cameras = [camHUD];
		msTxt.scrollFactor.set();
		msTxt.setFormat("vcr.ttf", 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		if (ClientPrefs.scoreStyle == 'Tails Gets Trolled V4') msTxt.setFormat("calibri.ttf", 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		if (ClientPrefs.scoreStyle == 'TGT V4') msTxt.setFormat("comic.ttf", 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		if (ClientPrefs.scoreStyle == 'Doki Doki+') msTxt.setFormat("Aller_rg.ttf", 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		msTxt.x = 408 + 250;
		msTxt.y = 290 - 25;
		if (PlayState.isPixelStage) {
			msTxt.x = 408 + 260;
			msTxt.y = 290 + 20;
		}
		msTxt.x += ClientPrefs.comboOffset[0];
		msTxt.y -= ClientPrefs.comboOffset[1];
		msTxt.active = false;
		msTxt.visible = false;
		insert(members.indexOf(strumLineNotes), msTxt);

		judgeTxt = new FlxText(400, timeBarBG.y + 120, FlxG.width - 800, "");
		judgeTxt.cameras = [camHUD];
		judgeTxt.scrollFactor.set();
		judgeTxt.setFormat("vcr.ttf", 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		if (ClientPrefs.scoreStyle == 'Tails Gets Trolled V4') judgeTxt.setFormat("calibri.ttf", 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		if (ClientPrefs.scoreStyle == 'Dave and Bambi') judgeTxt.setFormat("comic.ttf", 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		if (ClientPrefs.scoreStyle == 'Doki Doki+') judgeTxt.setFormat("Aller_rg.ttf", 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		judgeTxt.active = false;
		judgeTxt.size = 32;
		judgeTxt.visible = false;
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

		if (ClientPrefs.showcaseMode && !ClientPrefs.charsAndBG) {
			hitTxt = new FlxText(0, 20, 10000, "test", 42);
			hitTxt.setFormat(Paths.font("vcr.ttf"), 42, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			hitTxt.scrollFactor.set();
			hitTxt.borderSize = 2;
			hitTxt.visible = true;
			hitTxt.cameras = [camHUD];
			hitTxt.screenCenter(Y);
			add(hitTxt);
			var chromaScreen = new FlxSprite(-5000, -2000).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.GREEN);
			chromaScreen.scrollFactor.set(0, 0);
			chromaScreen.scale.set(3, 3);
			chromaScreen.updateHitbox();
			add(chromaScreen);
		}

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

		// Showcase and HUD logic
		if (ClientPrefs.showcaseMode) {
			final items = (ClientPrefs.showcaseST == 'AMZ')
				? [scoreTxt, botplayTxt, timeBarBG, timeBar, timeTxt]
				: [scoreTxt, botplayTxt, healthBarBG, healthBar, iconP1, iconP2];
			for (item in items) if (item != null) item.visible = false;
		}

		if (ClientPrefs.hideHud) {
			final hudItems:Array<Dynamic> = [scoreTxt, botplayTxt, healthBarBG, healthBar, iconP2, iconP1, timeBarBG, timeBar, timeTxt];
			for (item in hudItems) if (item != null) item.visible = false;
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
		if (ClientPrefs.scoreTxtSize > 0 && scoreTxt != null && !ClientPrefs.showcaseMode && !ClientPrefs.hideHud) scoreTxt.size = ClientPrefs.scoreTxtSize;

		final ytWMPosition = switch(ClientPrefs.ytWatermarkPosition)
		{
			case 'Top': FlxG.height * 0.2;
			case 'Middle': FlxG.height / 2;
			case 'Bottom': FlxG.height * 0.8;
			default: FlxG.height / 2;
		}

		final path:String = Paths.txt("ytWatermarkInfo", "preload");
		final ytWatermarkText:String = Assets.exists(path) ? Assets.getText(path) : '';
		ytWatermark = new FlxText(0, ytWMPosition, FlxG.width, ytWatermarkText, 40);
		ytWatermark.setFormat(Paths.font("vcr.ttf"), 25, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		ytWatermark.scrollFactor.set();
		ytWatermark.borderSize = 1.25;
		ytWatermark.alpha = 0.5;
		ytWatermark.cameras = [camOther];
		ytWatermark.visible = ClientPrefs.ytWatermarkPosition != 'Hidden';
		add(ytWatermark);

		renderedTxt = new FlxText(0, healthBarBG.y - 50, FlxG.width, "", 32);
		renderedTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		renderedTxt.scrollFactor.set();
		renderedTxt.borderSize = 1.25;
		renderedTxt.cameras = [camHUD];
		renderedTxt.visible = ClientPrefs.showRendered;

		if (ClientPrefs.downScroll) renderedTxt.y = healthBar.y + 50;
		if (ClientPrefs.scoreStyle == 'VS Impostor') renderedTxt.y = healthBar.y + (ClientPrefs.downScroll ? 100 : -100);
		add(renderedTxt);

		judgementCounter = new FlxText(0, FlxG.height / 2 - 80, 0, "", 20);
		judgementCounter.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		judgementCounter.borderSize = 2;
		judgementCounter.scrollFactor.set();
		judgementCounter.visible = ClientPrefs.ratingCounter && !ClientPrefs.showcaseMode;
		add(judgementCounter);
		if (ClientPrefs.ratingCounter) updateRatingCounter();

		//create default botplay text
		botplayTxt = new FlxText(400, timeBarBG.y + 55, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled && !ClientPrefs.showcaseMode;
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
				if (ClientPrefs.showcaseMode && ClientPrefs.showcaseST != 'AMZ') {
				botplayTxt.y += (!ClientPrefs.downScroll ? 60 : -60);
				botplayTxt.text = 'NPS: $nps/$maxNPS\nOpp NPS: $oppNPS/$maxOppNPS';
				botplayTxt.visible = true;
			}
		}
		if (ClientPrefs.showRendered)
			renderedTxt.text = 'Rendered Notes: ' + formatNumber(notes.length);

		laneunderlayOpponent.cameras = [camHUD];
		laneunderlay.cameras = [camHUD];
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
		judgementCounter.cameras = [camHUD];
		if (scoreTxt != null) scoreTxt.cameras = [camHUD];
		if (botplayTxt != null) botplayTxt.cameras = [camHUD];
		timeBar.cameras = [camHUD];
		timeBarBG.cameras = [camHUD];
		timeTxt.cameras = [camHUD];
		popUpGroup.cameras = [camHUD];

		startingSong = true;
		MusicBeatState.windowNameSuffix = " - " + SONG.song + " " + (isStoryMode ? "(Story Mode)" : "(Freeplay)");

		#if LUA_ALLOWED
		for (notetype in noteTypeMap.keys())
		{
			startLuasOnFolder('custom_notetypes/' + notetype + '.lua');
		}
		for (event in eventPushedMap.keys())
		{
			startLuasOnFolder('custom_events/' + event + '.lua');
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
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/' + Paths.formatToSongPath(SONG.song) + '/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('data/' + Paths.formatToSongPath(SONG.song) + '/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/data/' + Paths.formatToSongPath(SONG.song) + '/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/data/' + Paths.formatToSongPath(SONG.song) + '/' ));// using push instead of insert because these should run after everything else
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		#end

		startCallback();
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

		if(cpuControlled && ClientPrefs.randomBotplayText && ClientPrefs.botTxtStyle != 'Hide' && botplayTxt != null && ffmpegInfo != 'Frame Time')
			botplayTxt.text = theListBotplay[FlxG.random.int(0, theListBotplay.length - 1)];

		if (botplayTxt != null) ogBotTxt = botplayTxt.text;

		resetRPC();
		callOnLuas('onCreatePost');
		stagesFunc(function(stage:BaseStage) stage.createPost());

		cacheCountdown();
		cachePopUpScore();

		super.create();
		Paths.clearUnusedMemory();

		startingTime = haxe.Timer.stamp();
	}

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		if(!ClientPrefs.shaders) return new FlxRuntimeShader();

		#if (!flash && MODS_ALLOWED && sys)
		if(!runtimeShaders.exists(name) && !initLuaShader(name))
		{
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String)
	{
		if(!ClientPrefs.shaders) return false;

		if(runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/shaders/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if (FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		return false;
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
		trace('Anim speed: ' + FlxG.animationTimeScale);
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

	public function addTextToDebug(text:String, color:FlxColor) {
		#if LUA_ALLOWED
		var newText:FunkinLua.DebugLuaText = luaDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);
		newText.setFormat(Paths.font("old_windows.ttf"));

		Sys.println(text);
		#end
	}

	public function reloadHealthBarColors(leftColorArray:Array<Int>, rightColorArray:Array<Int>) {
		if (!ClientPrefs.ogHPColor) {
				healthBar.createFilledBar(FlxColor.fromRGB(leftColorArray[0], leftColorArray[1], leftColorArray[2]),
				FlxColor.fromRGB(rightColorArray[0], rightColorArray[1], rightColorArray[2]));
		} else {
				healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
		}

		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Boyfriend = new Boyfriend(0, 0, newCharacter);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterLua(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterLua(newDad.curCharacter);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterLua(newGf.curCharacter);
				}
		}
	}

	function startCharacterLua(name:String)
	{
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		if(FileSystem.exists(Paths.modFolders(luaFile))) {
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		} else {
			luaFile = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaFile)) {
				doPush = true;
			}
		}
		#else
		luaFile = Paths.getPreloadPath(luaFile);
		if(Assets.exists(luaFile)) {
			doPush = true;
		}
		#end

		if(doPush)
		{
			for (script in luaArray)
			{
				if(script.scriptName == luaFile) return;
			}
			luaArray.push(new FunkinLua(luaFile));
		}
		#end
	}

	public function addShaderToCamera(cam:String,effect:Dynamic){//STOLE FROM ANDROMEDA	// actually i got it from old psych engine
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				camHUDShaders.push(effect);
				var newCamEffects:Array<BitmapFilter>=[]; // IT SHUTS HAXE UP IDK WHY BUT WHATEVER IDK WHY I CANT JUST ARRAY<SHADERFILTER>
				for(i in camHUDShaders){
					newCamEffects.push(new ShaderFilter(i.shader));
				}
				camHUD.filters = newCamEffects;
			case 'camother' | 'other':
				camOtherShaders.push(effect);
				var newCamEffects:Array<BitmapFilter>=[]; // IT SHUTS HAXE UP IDK WHY BUT WHATEVER IDK WHY I CANT JUST ARRAY<SHADERFILTER>
				for(i in camOtherShaders){
					newCamEffects.push(new ShaderFilter(i.shader));
				}
				camOther.filters = newCamEffects;
			case 'camgame' | 'game':
				camGameShaders.push(effect);
				var newCamEffects:Array<BitmapFilter>=[]; // IT SHUTS HAXE UP IDK WHY BUT WHATEVER IDK WHY I CANT JUST ARRAY<SHADERFILTER>
				for(i in camGameShaders){
					newCamEffects.push(new ShaderFilter(i.shader));
				}
				camGame.filters = newCamEffects;
			default:
				if(modchartSprites.exists(cam)) {
					Reflect.setProperty(modchartSprites.get(cam),"shader",effect.shader);
				} else if(modchartTexts.exists(cam)) {
					Reflect.setProperty(modchartTexts.get(cam),"shader",effect.shader);
				} else {
					var OBJ = Reflect.getProperty(PlayState.instance,cam);
					Reflect.setProperty(OBJ,"shader", effect.shader);
				}
		}
  }

  public function removeShaderFromCamera(cam:String,effect:ShaderEffect){
	switch(cam.toLowerCase()) {
		case 'camhud' | 'hud':
			camHUDShaders.remove(effect);
			var newCamEffects:Array<BitmapFilter>=[];
			for(i in camHUDShaders){
				newCamEffects.push(new ShaderFilter(i.shader));
			}
			camHUD.filters = newCamEffects;
		case 'camother' | 'other':
			camOtherShaders.remove(effect);
			var newCamEffects:Array<BitmapFilter>=[];
			for(i in camOtherShaders){
				newCamEffects.push(new ShaderFilter(i.shader));
			}
			camOther.filters = newCamEffects;
		default:
			if(modchartSprites.exists(cam)) {
				Reflect.setProperty(modchartSprites.get(cam),"shader",null);
			} else if(modchartTexts.exists(cam)) {
				Reflect.setProperty(modchartTexts.get(cam),"shader",null);
			} else {
				var OBJ = Reflect.getProperty(PlayState.instance,cam);
				Reflect.setProperty(OBJ,"shader", null);
			}
		}
  }
  public function clearShaderFromCamera(cam:String){
	switch(cam.toLowerCase()) {
		case 'camhud' | 'hud':
			camHUDShaders = [];
			var newCamEffects:Array<BitmapFilter>=[];
			camHUD.filters = newCamEffects;
		case 'camother' | 'other':
			camOtherShaders = [];
			var newCamEffects:Array<BitmapFilter>=[];
			camOther.filters = newCamEffects;
		case 'camgame' | 'game':
			camGameShaders = [];
			var newCamEffects:Array<BitmapFilter>=[];
			camGame.filters = newCamEffects;
		default:
			camGameShaders = [];
			var newCamEffects:Array<BitmapFilter>=[];
			camGame.filters = newCamEffects;
	}
  }

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		if(modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if(text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		if(variables.exists(tag)) return variables.get(tag);
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	/***************/
    /*    VIDEO    */
	/***************/
	public var videoCutscene:VideoSprite = null;
	public function startVideo(name:String, ?library:String = null, ?callback:Void->Void = null, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		inCutscene = true;
		canPause = false;

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
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);

			// Finish callback
			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					canPause = false;
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = (callback != null) ? callback.bind() : onVideoEnd;
				videoCutscene.onSkip = (callback != null) ? callback.bind() : onVideoEnd;
			}
			add(videoCutscene);

			if (playOnLoad)
				videoCutscene.videoSprite.play();
			return videoCutscene;
		}
		#if (LUA_ALLOWED)
		else addTextToDebug("Video not found: " + fileName, FlxColor.RED);
		#else
		else FlxG.log.error("Video not found: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		#end
		return null;
	}

	public function startAndEnd()
	{
		if(endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	public function changeTheSettingsBitch() {
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		hpDrainLevel = ClientPrefs.getGameplaySetting('drainlevel', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		sickOnly = ClientPrefs.getGameplaySetting('onlySicks', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);
		opponentChart = ClientPrefs.getGameplaySetting('opponentplay', false);
		trollingMode = ClientPrefs.getGameplaySetting('thetrollingever', false);
		opponentDrain = ClientPrefs.getGameplaySetting('opponentdrain', false);
		randomMode = ClientPrefs.getGameplaySetting('randommode', false);
		flip = ClientPrefs.getGameplaySetting('flip', false);
		stairs = ClientPrefs.getGameplaySetting('stairmode', false);
		waves = ClientPrefs.getGameplaySetting('wavemode', false);
		oneK = ClientPrefs.getGameplaySetting('onekey', false);
		randomSpeedThing = ClientPrefs.getGameplaySetting('randomspeed', false);
		jackingtime = ClientPrefs.getGameplaySetting('jacks', 0);
		playbackRate = ClientPrefs.getGameplaySetting('songspeed', 1);
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		ogSongSpeed = songSpeed;

		shouldDrainHealth = (opponentDrain || (opponentChart ? boyfriend.healthDrain : dad.healthDrain));
		if (!opponentDrain && !Math.isNaN((opponentChart ? boyfriend : dad).drainAmount)) healthDrainAmount = opponentChart ? boyfriend.drainAmount : dad.drainAmount;
		if (!opponentDrain && !Math.isNaN((opponentChart ? boyfriend : dad).drainFloor)) healthDrainFloor = opponentChart ? boyfriend.drainFloor : dad.drainFloor;
	}

	var fps:Float = 60;
	var bfCanPan:Bool = false;
	var dadCanPan:Bool = false;
	var doPan:Bool = false;
	function camPanRoutine(anim:String = 'singUP', who:String = 'bf'):Void {
		if (SONG.notes[curSection] != null)
		{
			fps = FlxG.updateFramerate;
			bfCanPan = SONG.notes[curSection].mustHitSection;
			dadCanPan = !SONG.notes[curSection].mustHitSection;
			switch (who) {
				case 'bf' | 'boyfriend': doPan = bfCanPan;
				case 'oppt' | 'dad': doPan = dadCanPan;
			}
			//FlxG.elapsed is stinky poo poo for this, it just makes it look jank as fuck
			if (doPan && cameraSpeed > 0) {
				if (fps == 0) fps = 1;
				switch (anim.split('-')[0])
				{
					case 'singUP': moveCamTo[1] = -40*ClientPrefs.panIntensity*240/fps;
					case 'singDOWN': moveCamTo[1] = 40*ClientPrefs.panIntensity*240/fps;
					case 'singLEFT': moveCamTo[0] = -40*ClientPrefs.panIntensity*240/fps;
					case 'singRIGHT': moveCamTo[0] = 40*ClientPrefs.panIntensity*240/fps;
				}
			}
		}
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
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = switch(stageUI) {
			case "pixel": ['${stageUI}UI/ready-pixel', '${stageUI}UI/set-pixel', '${stageUI}UI/date-pixel'];
			case "normal": ["ready", "set" ,"go"];
			default: ['${stageUI}UI/ready', '${stageUI}UI/set', '${stageUI}UI/go'];
		}
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts) Paths.image(asset);

		intro3 = new FlxSound().loadEmbedded(Paths.sound('intro3' + introSoundsSuffix));
		intro2 = new FlxSound().loadEmbedded(Paths.sound('intro2' + introSoundsSuffix));
		intro1 = new FlxSound().loadEmbedded(Paths.sound('intro1' + introSoundsSuffix));
		introGo = new FlxSound().loadEmbedded(Paths.sound('introGo' + introSoundsSuffix));
	}

	public static function formatCompactNumber(number:Float):String
	{
		var suffixes1:Array<String> = ['ni', 'mi', 'bi', 'tri', 'quadri', 'quinti', 'sexti', 'septi', 'octi', 'noni'];
		var tenSuffixes:Array<String> = ['', 'deci', 'viginti', 'triginti', 'quadraginti', 'quinquaginti', 'sexaginti', 'septuaginti', 'octoginti', 'nonaginti', 'centi'];
		var decSuffixes:Array<String> = ['', 'un', 'duo', 'tre', 'quattuor', 'quin', 'sex', 'septe', 'octo', 'nove'];
		var centiSuffixes:Array<String> = ['centi', 'ducenti', 'trecenti', 'quadringenti', 'quingenti', 'sescenti', 'septingenti', 'octingenti', 'nongenti'];

		var magnitude:Int = 0;
		var num:Float = number;
		var tenIndex:Int = 0;

		while (num >= 1000.0)
		{
			num /= 1000.0;

			if (magnitude == suffixes1.length - 1) {
				tenIndex++;
			}

			magnitude++;

			if (magnitude == 21) {
				tenIndex++;
				magnitude = 11;
			}
		}

		// Determine which set of suffixes to use
		var suffixSet:Array<String> = (magnitude <= suffixes1.length) ? suffixes1 : ((magnitude <= suffixes1.length + decSuffixes.length) ? decSuffixes : centiSuffixes);

		// Use the appropriate suffix based on magnitude
		var suffix:String = (magnitude <= suffixes1.length) ? suffixSet[magnitude - 1] : suffixSet[magnitude - 1 - suffixes1.length];
		var tenSuffix:String = (tenIndex <= 10) ? tenSuffixes[tenIndex] : centiSuffixes[tenIndex - 11];

		// Use the floor value for the compact representation
		var compactValue:Float = Math.floor(num * 100) / 100;

		if (compactValue <= 0.001) {
			return "0"; // Return 0 if compactValue = null
		} else {
			var illionRepresentation:String = "";

			if (magnitude > 0) {
				illionRepresentation += suffix + tenSuffix;
			}

				if (magnitude > 1) illionRepresentation += "llion";

			return compactValue + (magnitude == 0 ? "" : " ") + (magnitude == 1 ? 'thousand' : illionRepresentation);
		}
	}

	public static function formatNumber(number:Float, ?decimals:Bool = false):String //simplified number formatting
	{
		return (number < 10e11 ? FlxStringUtil.formatMoney(number, false) : formatCompactNumber(number));
	}

	public function startCountdown():Void
	{
		if(startedCountdown) {
			callOnLuas('onStartCountdown');
			return;
		}

		inCutscene = false;
		var ret:Dynamic = callOnLuas('onStartCountdown');

		if (SONG.song.toLowerCase() == 'anti-cheat-song')
		{
			secretsong = new FlxSprite().loadGraphic(Paths.image('secretSong'));
			secretsong.antialiasing = ClientPrefs.globalAntialiasing;
			secretsong.scrollFactor.set();
			secretsong.setGraphicSize(Std.int(secretsong.width / FlxG.camera.zoom));
			secretsong.updateHitbox();
			secretsong.screenCenter();
			secretsong.cameras = [camGame];
			add(secretsong);
		}
		if (middleScroll)
		{
			laneunderlayOpponent.alpha = 0;
			laneunderlay.screenCenter(X);
		}

		if(ret != FunkinLua.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			generateStaticArrows(0);
			generateStaticArrows(1);
			for (i in 0...opponentStrums.length) {
				setOnLuas('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnLuas('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				if(bothSides) opponentStrums.members[i].visible = false;
			}
			for (i in 0...playerStrums.length) {
				setOnLuas('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnLuas('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5;
			setOnLuas('startedCountdown', true);
			callOnLuas('onCountdownStarted');

			var swagCounter:Int = 0;

			if(startOnTime < 0) startOnTime = 0;

			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return;
			}

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				if (ClientPrefs.charsAndBG) characterBopper(tmr.loopsLeft);

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				var introImagesArray:Array<String> = switch(stageUI) {
					case "pixel": ['${stageUI}UI/ready-pixel', '${stageUI}UI/set-pixel', '${stageUI}UI/date-pixel'];
					case "normal": ["ready", "set" ,"go"];
					default: ['${stageUI}UI/ready', '${stageUI}UI/set', '${stageUI}UI/go'];
				}
				introAssets.set(stageUI, introImagesArray);

				var introAlts:Array<String> = introAssets.get(stageUI);
				var antialias:Bool = ClientPrefs.globalAntialiasing;
				if(isPixelStage) {
					introAlts = introAssets.get('pixel');
					antialias = false;
				}

				var tick:Countdown = THREE;

				if (swagCounter > 0 && swagCounter < 4) createCountdownSprite(introAlts[swagCounter-1], antialias);

				switch (swagCounter)
				{
					case 0:
						intro3.volume = FlxG.sound.volume;
						intro3.play();
						tick = THREE;
					case 1:
						intro2.volume = FlxG.sound.volume;
						intro2.play();
						tick = TWO;
					case 2:
						intro1.volume = FlxG.sound.volume;
						intro1.play();
						tick = ONE;
					case 3:
						introGo.volume = FlxG.sound.volume;
						introGo.play();
						tick = GO;
						if (ClientPrefs.tauntOnGo && ClientPrefs.charsAndBG)
						{
							final charsToHey = [dad, boyfriend, gf];
							for (char in charsToHey)
							{
								if(char != null)
								{
									if (char.animOffsets.exists('hey') || char.animOffsets.exists('cheer'))
									{
										char.playAnim(char.animOffsets.exists('hey') ? 'hey' : 'cheer', true);
										char.specialAnim = true;
										char.heyTimer = 0.6;
									} else if (char.animOffsets.exists('singUP') && (!char.animOffsets.exists('hey') || !char.animOffsets.exists('cheer')))
									{
										char.playAnim('singUP', true);
										char.specialAnim = true;
										char.heyTimer = 0.6;
									}
								}
							}
						}
					case 4:
					tick = START;
					if (SONG.songCredit != null && SONG.songCredit.length > 0)
					{
						var creditsPopup:CreditsPopUp = new CreditsPopUp(FlxG.width, 200, SONG.song, SONG.songCredit);
						creditsPopup.cameras = [camHUD];
						creditsPopup.scrollFactor.set();
						creditsPopup.x = creditsPopup.width * -1;
						add(creditsPopup);

						FlxTween.tween(creditsPopup, {x: 0}, 0.5, {ease: FlxEase.backOut, onComplete: function(tweeen:FlxTween)
						{
							FlxTween.tween(creditsPopup, {x: creditsPopup.width * -1} , 1, {ease: FlxEase.backIn, onComplete: function(tween:FlxTween)
							{
								creditsPopup.destroy();
							}, startDelay: 3});
						}});
					}
				}

				for (group in [notes, sustainNotes]) group.forEachAlive(function(note:Note) {
					if(ClientPrefs.opponentStrums || !ClientPrefs.opponentStrums || middleScroll || !note.mustPress)
					{
						note.alpha *= 0.35;
					}
					if(ClientPrefs.opponentStrums || !ClientPrefs.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha;
						if(middleScroll && !note.mustPress) {
							note.alpha *= 0.35;
						}
					}
				});
				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				callOnLuas('onCountdownTick', [swagCounter]);

				swagCounter += 1;
			}, 5);
		}
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(notes), spr);
		FlxTween.tween(spr, {"scale.x": 0, "scale.y": 0, alpha: 0}, Conductor.crochet / 1000 / playbackRate, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	public function addBehindGF(obj:FlxObject)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxObject)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad (obj:FlxObject)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		for (group in [notes, sustainNotes])
		{
			var i:Int = group.length - 1;
			while (i >= 0) {
				var daNote:Note = group.members[i];
				if(daNote.strumTime - 350 < time)
				{
					daNote.active = false;
					daNote.visible = false;
					daNote.ignoreNote = true;
					group.remove(daNote, true);
				}
				--i;
			}
		}
	}

	var comboInfo = ClientPrefs.showComboInfo;
	var showNPS = ClientPrefs.showNPS;
	var missString:String = '';
	public function updateScore(miss:Bool = false)
	{
		scoreTxtUpdateFrame++;
		if (!scoreTxt.visible || scoreTxt == null)
			return;
		//GAH DAYUM THIS IS MORE OPTIMIZED THAN BEFORE
		var divider = switch (ClientPrefs.scoreStyle)
		{
			case 'Leather Engine': '~';
			case 'Forever Engine': '•';
			default: '|';
		}
		formattedScore = formatNumber(songScore);
		if (ClientPrefs.scoreStyle == 'JS Engine') formattedScore = formatNumber(shownScore);
		formattedSongMisses = formatNumber(songMisses);
		formattedCombo = formatNumber(combo);
		formattedNPS = formatNumber(nps);
		formattedMaxNPS = formatNumber(maxNPS);
		npsString = showNPS ? ' $divider ' + (cpuControlled && ClientPrefs.botWatermark ? 'Bot ' : '') + 'NPS/Max: ' + formattedNPS + '/' + formattedMaxNPS : '';
		accuracy = Highscore.floorDecimal(ratingPercent * 100, 2) + '%';
		fcString = ratingFC;
		missString = (!instakillOnMiss ? switch(ClientPrefs.scoreStyle)
		{
			case 'Kade Engine', 'VS Impostor': ' $divider Combo Breaks: ' + formattedSongMisses;
			case 'Doki Doki+': ' $divider Breaks: ' + formattedSongMisses;
			default:
				' $divider Misses: ' + formattedSongMisses;
		} : '');

		botText = cpuControlled && ClientPrefs.botWatermark ? ' $divider Botplay Mode' : '';

		if (cpuControlled && ClientPrefs.botWatermark)
			tempScore = 'Bot Score: ' + formattedScore + (comboInfo ? ' $divider Bot Combo: ' + formattedCombo : '') + npsString + botText;

		else switch (ClientPrefs.scoreStyle)
		{
			case 'Kade Engine', 'Doki Doki+':
				tempScore = 'Score: ' + formattedScore + missString + (comboInfo ? ' $divider Combo: ' + formattedCombo : '') + npsString + ' $divider Accuracy: ' + accuracy + ' $divider (' + fcString + ') ' + ratingName;

			case "Dave Engine":
				tempScore = 'Score: ' + formattedScore + missString + (comboInfo ? ' $divider Combo: ' + formattedCombo : '') + npsString + ' $divider Accuracy: ' + accuracy + ' $divider ' + fcString;

			case "Forever Engine":
				tempScore = 'Score: ' + formattedScore + ' $divider Accuracy: $accuracy ['  + fcString + ']' + missString + (comboInfo ? ' $divider Combo: ' + formattedCombo : '') + npsString + ' $divider Rank: ' + ratingName;

			case "Psych Engine", "JS Engine", "TGT V4":
				tempScore = 'Score: ' + formattedScore + missString + (comboInfo ? ' $divider Combo: ' + formattedCombo : '') + npsString + ' $divider Rating: ' + ratingName + (ratingName != '?' ? ' (${accuracy}) - $fcString' : '');

			case "Leather Engine":
				tempScore = '< Score: ' + formattedScore + missString + (comboInfo ? ' $divider Combo: ' + formattedCombo : '') + npsString + ' $divider Rating: ' + ratingName + (ratingName != '?' ? ' (${accuracy}) - $fcString' : '');

			case 'VS Impostor':
				tempScore = 'Score: ' + formattedScore + missString + (comboInfo ? ' $divider Combo: ' + formattedCombo : '') + npsString + ' $divider Accuracy: $accuracy ['  + fcString + ']';

			case 'Vanilla':
				tempScore = 'Score: ' + formattedScore;
		}

		scoreTxt.text = '${tempScore}\n';

		callOnLuas('onUpdateScore', [miss]);
	}

	public function setSongTime(time:Float)
	{
		if(time < 0) time = 0;

		FlxG.sound.music.pause();
		pauseVocals();

		FlxG.sound.music.time = time;
		FlxG.sound.music.play();
		FlxG.sound.music.pitch = playbackRate;
		if (ffmpegMode) FlxG.sound.music.volume = 0;

		if (Conductor.songPosition <= vocals.length)
		{
			setVocalsTime(time);
			#if FLX_PITCH
			vocals.pitch = playbackRate;
			opponentVocals.pitch = playbackRate;
			#end
		}
		vocals.play();
		opponentVocals.play();
		if (ffmpegMode) vocals.volume = opponentVocals.volume = 0;
		Conductor.songPosition = time;
		songTime = time;
		if (time > 0) clearNotesBefore(time);
	}

	public function startNextDialogue() {
		dialogueCount++;
		callOnLuas('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue() {
		callOnLuas('onSkipDialogue', [dialogueCount]);
	}

	var songTime:Float = 0;

	function startSong():Void
	{
		startingSong = false;

		var diff:String = (SONG.specialAudioName.length > 1 ? SONG.specialAudioName : CoolUtil.difficultyString()).toLowerCase();
		@:privateAccess
		if (!ffmpegMode) {
			FlxG.sound.playMusic(inst._sound, 1, false);
			FlxG.sound.music.onComplete = finishSong.bind();
			vocals.play();
			opponentVocals.play();
		} else {
			FlxG.sound.playMusic(inst._sound, 0, false);
			vocals.play(); vocals.volume = 0;
			opponentVocals.play(); opponentVocals.volume = 0;
		}
		if (!ffmpegMode && (!trollingMode || SONG.song.toLowerCase() != 'anti-cheat-song'))
			FlxG.sound.music.onComplete = finishSong.bind();

		FlxG.sound.music.pitch = playbackRate;
		vocals.pitch = opponentVocals.pitch = playbackRate;

		setSongTime(Math.max(0, startOnTime - 500) + Conductor.offset);
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			pauseVocals();
		}
		curTime = Conductor.songPosition - ClientPrefs.noteOffset;
		songPercent = (curTime / songLength);

		stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		if (ClientPrefs.lengthIntro) FlxTween.tween(this, {songLength: FlxG.sound.music.length}, 1, {ease: FlxEase.expoOut});
		if (!ClientPrefs.lengthIntro) songLength = FlxG.sound.music.length; //so that the timer won't just appear as 0
		if (ClientPrefs.timeBarType != 'Disabled') {
		timeBar.scale.x = 0.01;
		timeBarBG.scale.x = 0.01;
		FlxTween.tween(timeBar, {alpha: 1, "scale.x": 1}, 1, {ease: FlxEase.expoOut});
		FlxTween.tween(timeBarBG, {alpha: 1, "scale.x": 1}, 1, {ease: FlxEase.expoOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		}

		if (ClientPrefs.ratingCounter && judgeCountUpdateFrame <= 4 && judgementCounter != null) updateRatingCounter();
		if (scoreTxtUpdateFrame <= 4 && scoreTxt != null) updateScore();

		// TODO: Lock other note inputs
		if (oneK)
		{
			playerStrums.forEachAlive(function(daNote:FlxSprite)
			{
				if (daNote != playerStrums.members[firstNoteData])
				{
					FlxTween.cancelTweensOf(daNote);
					FlxTween.tween(daNote, {alpha: 0}, 0.7, {ease: FlxEase.expoOut});
				}
			});
			opponentStrums.forEachAlive(function(daNote:FlxSprite)
			{
				if (daNote != opponentStrums.members[firstNoteData])
				{
					FlxTween.cancelTweensOf(daNote);
					FlxTween.tween(daNote, {alpha: 0}, 0.7, {ease: FlxEase.expoOut});
				}
			});
			FlxG.sound.play(Paths.sound('FunnyVanish'));
		}

		#if DISCORD_ALLOWED
		if(autoUpdateRPC) {
			if (cpuControlled) detailsText = detailsText + ' (using a bot)';
			// Updating Discord Rich Presence (with Time Left)
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		}
		#end
		setOnLuas('songLength', songLength);
		callOnLuas('onSongStart');
	}

	var ogSongSpeed:Float = 0;
	public function lerpSongSpeed(num:Float, time:Float):Void
	{
		FlxTween.num(playbackRate, num, time, {onUpdate: function(tween:FlxTween){
			var ting = FlxMath.lerp(playbackRate, num, tween.percent);
			var ting2 = FlxMath.lerp(songSpeed, ogSongSpeed / playbackRate, tween.percent);
			if (ting != 0) //divide by 0 is a verry bad
				playbackRate = ting; //why cant i just tween a variable

			if (ting2 != 0)
				songSpeed = ogSongSpeed / playbackRate;

			setVocalsTime(Conductor.songPosition);
			if (!ffmpegMode) resyncVocals();
		}});
	}

	var debugNum:Int = 0;
	var stair:Int = 0;
	var firstNoteData:Int = 0;
	var assignedFirstData:Bool = false;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
	private function generateSong(dataPath:String, ?startingPoint:Float = 0):Void
	{
		var offsetStart = (startingPoint > 0 ? 500 : 0);
	   	final startTime = haxe.Timer.stamp();

		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		ogSongSpeed = songSpeed;

		Conductor.changeBPM(SONG.bpm);

		curSong = SONG.song;

		var diff:String = (SONG.specialAudioName.length > 1 ? SONG.specialAudioName : CoolUtil.difficultyString()).toLowerCase();

		if (SONG.windowName != null && SONG.windowName != '')
			MusicBeatState.windowNamePrefix = SONG.windowName;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (SONG.needsVoices)
			{
				var playerVocals = Paths.voices(curSong, diff, (boyfriend.vocalsFile == null || boyfriend.vocalsFile.length < 1) ? 'Player' : boyfriend.vocalsFile);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(curSong, diff));

				var oppVocals = Paths.voices(curSong, diff, (dad.vocalsFile == null || dad.vocalsFile.length < 1) ? 'Opponent' : dad.vocalsFile);
				if(oppVocals != null) opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch(e) {}

		vocals.pitch = opponentVocals.pitch = playbackRate;
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);
		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(SONG.song, diff));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);

		final noteData:Array<SwagSection> = SONG.notes;

		var eventsToLoad:String = (SONG.specialEventsName.length > 1 ? SONG.specialEventsName : CoolUtil.difficultyString()).toLowerCase();

		final songName:String = Paths.formatToSongPath(SONG.song);
		final file:String = Paths.songEvents(songName, eventsToLoad);
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.json(file)) || FileSystem.exists(Paths.modsJson(file))) {
		#else
		if (OpenFlAssets.exists(file)) {
		#end
			var eventsData:Array<Dynamic> = Song.loadFromJson(Paths.songEvents(songName, eventsToLoad, true), songName).events;
			for (event in eventsData) //Event Notes
			{
				for (i in 0...event[1].length)
				{
					if (event[0] >= startingPoint + offsetStart)
					{
						var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
						var subEvent:EventNote = {
							strumTime: newEventNote[0] + ClientPrefs.noteOffset,
							event: newEventNote[1],
							value1: newEventNote[2],
							value2: newEventNote[3]
						};
						eventNotes.push(subEvent);
						eventPushed(subEvent);
					}
				}
			}
		}
		for (event in SONG.events) //Event Notes
		{
			for (i in 0...event[1].length)
			{
				if (event[0] >= startingPoint + offsetStart)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:EventNote = {
						strumTime: newEventNote[0] + ClientPrefs.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		}
		var stepCrochet:Float = 0.0;
		var currentBPMLol:Float = Conductor.bpm;
		var currentMultiplier:Float = 1;
		var gottaHitNote:Bool = false;
		var swagNote:PreloadedChartNote;
		for (section in noteData) {
			if (section.changeBPM) currentBPMLol = section.bpm;

			for (songNotes in section.sectionNotes) {
				if (songNotes[0] >= startingPoint + offsetStart) {
					final daStrumTime:Float = songNotes[0];
					var daNoteData:Int = 0;
					if (!assignedFirstData && oneK)
					{
						firstNoteData = Std.int(songNotes[1] % 4);
						assignedFirstData = true;
					}
					if (!randomMode && !flip && !stairs && !waves) daNoteData = Std.int(songNotes[1] % 4);

					if (oneK) daNoteData = firstNoteData;

					if (randomMode) daNoteData = FlxG.random.int(0, 3);

					if (flip) daNoteData = Std.int(Math.abs((songNotes[1] % 4) - 3));

					if (stairs && !waves) {
						daNoteData = stair % 4;
						stair++;
					}

					if (waves) {
						switch (stair % 6) {
							case 0 | 1 | 2 | 3:
								daNoteData = stair % 6;
							case 4:
								daNoteData = 2;
							case 5:
								daNoteData = 1;
						}
						stair++;
					}

					gottaHitNote = ((songNotes[1] < 4 && !opponentChart)
						|| (songNotes[1] > 3 && opponentChart) ? section.mustHitSection : !section.mustHitSection);

					if ((bothSides || gottaHitNote) && songNotes[3] != 'Hurt Note') {
						totalNotes += 1;
					}
					if (!bothSides && !gottaHitNote) {
						opponentNoteTotal += 1;
					}

					if (daStrumTime >= charChangeTimes[0])
					{
						switch (charChangeTypes[0])
						{
							case 0:
								var boyfriendToGrab:Boyfriend = boyfriendMap.get(charChangeNames[0]);
								if (boyfriendToGrab != null) bfNoteskin = boyfriendToGrab.noteskin;
							case 1:
								var dadToGrab:Character = dadMap.get(charChangeNames[0]);
								if (dadToGrab != null) dadNoteskin = dadToGrab.noteskin;
						}
						charChangeTimes.shift();
						charChangeNames.shift();
						charChangeTypes.shift();
					}

					if (multiChangeEvents[0].length > 0 && daStrumTime >= multiChangeEvents[0][0])
					{
						currentMultiplier = multiChangeEvents[1][0];
						multiChangeEvents[0].shift();
						multiChangeEvents[1].shift();
					}

					swagNote = cast {
						strumTime: daStrumTime,
						noteData: daNoteData,
						mustPress: bothSides || gottaHitNote,
						oppNote: (opponentChart ? gottaHitNote : !gottaHitNote),
						noteType: songNotes[3],
						animSuffix: (songNotes[3] == 'Alt Animation' || section.altAnim ? '-alt' : ''),
						noteskin: (gottaHitNote ? bfNoteskin : dadNoteskin),
						gfNote: songNotes[3] == 'GF Sing' || (section.gfSection && songNotes[1] < 4),
						noAnimation: songNotes[3] == 'No Animation',
						noMissAnimation: songNotes[3] == 'No Animation',
						sustainLength: songNotes[2],
						hitHealth: 0.023,
						missHealth: songNotes[3] != 'Hurt Note' ? 0.0475 : 0.3,
						wasHit: false,
						hitCausesMiss: songNotes[3] == 'Hurt Note',
						multSpeed: 1,
						noteDensity: currentMultiplier,
						ignoreNote: songNotes[3] == 'Hurt Note' && gottaHitNote
					};
					if (swagNote.noteskin.length > 0 && !Paths.noteSkinFramesMap.exists(swagNote.noteskin)) inline Paths.initNote(swagNote.noteskin);

					if(!Std.isOfType(songNotes[3], String)) swagNote.noteType = ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts

					if(Std.isOfType(songNotes[3], Bool)) swagNote.animSuffix = (songNotes[3] || section.altAnim ? '-alt' : ''); //Compatibility with charts made by SNIFF

					if (!noteTypeMap.exists(swagNote.noteType)) {
						noteTypeMap.set(swagNote.noteType, true);
					}

					unspawnNotes.push(swagNote);

					if (jackingtime > 0) {
						for (i in 0...Std.int(jackingtime)) {
							final jackNote:PreloadedChartNote = cast {
								strumTime: swagNote.strumTime + (15000 / SONG.bpm) * (i + 1),
								noteData: swagNote.noteData,
								mustPress: swagNote.mustPress,
								oppNote: swagNote.oppNote,
								noteType: swagNote.noteType,
								animSuffix: (songNotes[3] == 'Alt Animation' || section.altAnim ? '-alt' : ''),
								noteskin: (gottaHitNote ? bfNoteskin : dadNoteskin),
								gfNote: swagNote.gfNote,
								isSustainNote: false,
								isSustainEnd: false,
								parentST: 0,
								hitHealth: swagNote.hitHealth,
								missHealth: swagNote.missHealth,
								wasHit: false,
								multSpeed: 1,
								noteDensity: currentMultiplier,
								hitCausesMiss: swagNote.hitCausesMiss,
								ignoreNote: swagNote.ignoreNote
							};
							unspawnNotes.push(jackNote);
						}
					}

					if (swagNote.sustainLength < 1) continue;

					stepCrochet = 15000 / currentBPMLol;

					final roundSus:Int = Math.round(swagNote.sustainLength / stepCrochet);
					if (roundSus > 0) {
						for (susNote in 0...roundSus + 1) {

							final sustainNote:PreloadedChartNote = cast {
								strumTime: daStrumTime + (stepCrochet * susNote),
								noteData: daNoteData,
								mustPress: bothSides || gottaHitNote,
								oppNote: (opponentChart ? gottaHitNote : !gottaHitNote),
								noteType: songNotes[3],
								animSuffix: (songNotes[3] == 'Alt Animation' || section.altAnim ? '-alt' : ''),
								noteskin: (gottaHitNote ? bfNoteskin : dadNoteskin),
								gfNote: songNotes[3] == 'GF Sing' || (section.gfSection && songNotes[1] < 4),
								noAnimation: songNotes[3] == 'No Animation',
								isSustainNote: true,
								isSustainEnd: susNote == roundSus,
								parentST: swagNote.strumTime,
								parentSL: swagNote.sustainLength,
								hitHealth: 0.023,
								missHealth: songNotes[3] != 'Hurt Note' ? 0.0475 : 0.1,
								wasHit: false,
								multSpeed: 1,
								noteDensity: currentMultiplier,
								hitCausesMiss: songNotes[3] == 'Hurt Note',
								ignoreNote: songNotes[3] == 'Hurt Note' && swagNote.mustPress
							};
							unspawnNotes.push(sustainNote);
						}
					}
				} else {
					final gottaHitNote:Bool = ((songNotes[1] < 4 && !opponentChart)
						|| (songNotes[1] > 3 && opponentChart) ? section.mustHitSection : !section.mustHitSection);
					if ((bothSides || gottaHitNote) && !songNotes.hitCausesMiss) {
						totalNotes += 1;
						combo += 1;
						totalNotesPlayed += 1;
					}
					if (!bothSides && !gottaHitNote) {
						opponentNoteTotal += 1;
						enemyHits += 1;
					}
				}
			}
			sectionsLoaded += 1;
			notesLoadedRN += section.sectionNotes.length;
			Sys.print('\rSection $sectionsLoaded loaded! (' + notesLoadedRN + ' notes)');
		}

		bfNoteskin = boyfriend.noteskin;
		dadNoteskin = dad.noteskin;

		if (ClientPrefs.noteColorStyle == 'Char-Based')
		{
			for (group in [notes, sustainNotes])
				for (note in group){
					if (note == null)
						continue;
					if (ClientPrefs.enableColorShader) note.updateRGBColors();
				}
		}

		unspawnNotes.sort(sortByTime);
		eventNotes.sort(sortByTime);
		unspawnNotesCopy = unspawnNotes.copy();
		eventNotesCopy = eventNotes.copy();
		generatedMusic = true;

		sectionsLoaded = 0;

		final endTime = haxe.Timer.stamp();

		openfl.system.System.gc();

		final elapsedTime = endTime - startTime;

		trace('\nDone! \n\nTime taken: ' + CoolUtil.formatTime(elapsedTime * 1000) + "\nAverage NPS while loading: " + Math.floor(notesLoadedRN / elapsedTime));
		notesLoadedRN = 0;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote) {
		switch (event.event)
		{
			case 'Change Character':
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						charType = Std.parseInt(event.value1);
						if(Math.isNaN(charType)) charType = 0;
				}
				charChangeTimes.push(event.strumTime);
				charChangeNames.push(event.value2);
				charChangeTypes.push(charType);
			case 'Change Note Multiplier':
				var noteMultiplier:Float = Std.parseFloat(event.value1);
				if (Math.isNaN(noteMultiplier))
					noteMultiplier = 1;

				multiChangeEvents[0].push(event.strumTime);
				multiChangeEvents[1].push(noteMultiplier);
		}
		eventPushedUnique(event);
		if(eventPushedMap.exists(event.event)) {
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		if(!eventPushedMap.exists(event.event)) {
			eventPushedMap.set(event.event, true);
		}
	}

	function eventPushedUnique(event:EventNote) {
		switch(event.event) {
			case 'Change Character':
			if (ClientPrefs.charsAndBG)
			{
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						charType = Std.parseInt(event.value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);
			}
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		var returnedValue:Null<Float> = callOnLuas('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], [], [0]);
		if(returnedValue != null && returnedValue != 0 && returnedValue != FunkinLua.Function_Continue) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int {
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
		final strumLine:FlxPoint = FlxPoint.get(middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, (ClientPrefs.downScroll) ? FlxG.height - 150 : 50);
		for (i in 0...4)
		{
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if(!ClientPrefs.opponentStrums) targetAlpha = 0;
				else if(middleScroll) targetAlpha = ClientPrefs.oppNoteAlpha;
			}

			final noteSkinExists:Bool = Paths.fileExists("images/noteskins/" + (player == 0 ? dadNoteskin : bfNoteskin) + '.png', IMAGE);

			var babyArrow:StrumNote = new StrumNote(middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player);
			babyArrow.downScroll = ClientPrefs.downScroll;
			if (noteSkinExists)
			{
				babyArrow.texture = "noteskins/" + (player == 0 ? dad.noteskin : boyfriend.noteskin);
				babyArrow.useRGBShader = false;
			}
			if (!isStoryMode && !skipArrowStartTween)
			{
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1/(Conductor.bpm/240) / playbackRate, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i) / (Conductor.bpm/240) / playbackRate});
			}
			else
			{
				babyArrow.alpha = targetAlpha;
			}

			if (player == 1)
			{
				if (!opponentChart || opponentChart && middleScroll) playerStrums.add(babyArrow);
				else opponentStrums.add(babyArrow);
			}
			else
			{
				if(middleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) { //Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				if (!opponentChart || opponentChart && middleScroll) opponentStrums.add(babyArrow);
				else playerStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
		strumLine.put();
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
		try {if (health > 0 && !paused && autoUpdateRPC) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());}
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
		if(finishTimer != null || ffmpegMode) return;

		FlxG.sound.music.pitch = playbackRate;
		vocals.pitch = opponentVocals.pitch = playbackRate;
		if(!(Conductor.songPosition > 20 && FlxG.sound.music.time < 20))
		{
			pauseVocals();
			FlxG.sound.music.pause();

			if(FlxG.sound.music.time >= FlxG.sound.music.length)
				Conductor.songPosition = FlxG.sound.music.length;
			else
				Conductor.songPosition = FlxG.sound.music.time;

			setVocalsTime(Conductor.songPosition);

			FlxG.sound.music.play();
			for (i in [vocals, opponentVocals])
				if (i != null && i.time <= i.length) i.play();
		}
		else
		{
			while(Conductor.songPosition > 20 && FlxG.sound.music.time < 20)
			{
				FlxG.sound.music.time = Conductor.songPosition;
				setVocalsTime(Conductor.songPosition);

				FlxG.sound.music.play();
				for (i in [vocals, opponentVocals])
					if (i != null && i.time <= i.length) i.play();
			}
		}
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var pbRM:Float = 2.0;

	public var takenTime:Float = haxe.Timer.stamp();
	public var totalRenderTime:Float = 0;

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
	var notesBeingHit:Bool = false;
	var notesBeingMissed:Bool = false;
	var hitResetTimer:Float = 0;
	var missResetTimer:Float = 0;
	var botEnergyCooldown:Float = 0;
	var energyDrainSpeed:Float = 1;
	var energyRefillSpeed:Float = 1;

	override public function update(elapsed:Float)
	{
		if (ffmpegMode) elapsed = 1 / ClientPrefs.targetFPS;
		if (screenshader.Enabled)
		{
			if(disableTheTripperAt == curStep)
			{
				disableTheTripper = true;
			}
			if(isDead)
			{
				disableTheTripper = true;
			}

			FlxG.camera.filters = [new ShaderFilter(screenshader.shader)];
			screenshader.update(elapsed);
			if(disableTheTripper)
			{
				screenshader.shader.uampmul.value[0] -= (elapsed / 2);
			}
		}
		if (ClientPrefs.pbRControls)
		{
			if (FlxG.keys.pressed.SHIFT) {
				if (pbRM != 4.0) pbRM = 4.0;
			} else {
				if (pbRM != 2.0) pbRM = 2.0;
			}
	   			if (FlxG.keys.justPressed.SLASH)
						playbackRate /= pbRM;

				if (FlxG.keys.justPressed.PERIOD)
		   			playbackRate *= pbRM;
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
					if (!FlxG.keys.pressed.CONTROL)
						noEnergy = false;
				}
			}
		}

		if (botEnergy > 0.2 && botEnergy < 1.8) energyBar.color = energyTxt.color = 0xFF0094FF;
		if (botEnergy < 0.2) energyBar.color = energyTxt.color = 0xFFC60000;
		if (botEnergy > 1.8) energyBar.color = energyTxt.color = 0xFF00BC12;

		energyTxt.text = (botEnergy < 2 ? FlxMath.roundDecimal(botEnergy * 50, 0) + '%' : 'Full');
		energyTxt.y = (FlxG.height / 1.3) - (botEnergy * 50 * 4);

		if (ClientPrefs.showcaseMode && botplayTxt != null)
		{
			botplayTxt.text = '${formatNumber(Math.abs(enemyHits))}/${formatNumber(Math.abs(totalNotesPlayed))}\nNPS: ${formatNumber(nps)}/${formatNumber(maxNPS)}\nOpp NPS: ${formatNumber(oppNPS)}/${formatNumber(maxOppNPS)}';
			if (polyphonyOppo != 1 || polyphonyBF != 1)
			{
				var set:String = formatNumber(polyphonyBF);
				if (formatNumber(polyphonyOppo) != formatNumber(polyphonyBF))
					set = formatNumber(polyphonyOppo) + "/" + formatNumber(polyphonyBF);
				botplayTxt.text += '\nNote Multiplier: ' + set;
			}
		}

		callOnLuas('onUpdate', [elapsed]);
		super.update(elapsed);

		if (tankmanAscend && curStep > 895 && curStep < 1151)
		{
			camGame.zoom = 0.8;
		}
		if (healthBar.percent >= 80 && !winning)
		{
			winning = true;
			reloadHealthBarColors(dad.losingColorArray, boyfriend.winningColorArray);
		}
		if (healthBar.percent <= 20 && !losing)
		{
			losing = true;
			reloadHealthBarColors(dad.winningColorArray, boyfriend.losingColorArray);
		}
		if (healthBar.percent >= 20 && losing || healthBar.percent <= 80 && winning)
		{
			losing = false;
			winning = false;
			reloadHealthBarColors(dad.healthColorArray, boyfriend.healthColorArray);
		}

		if(!inCutscene && ClientPrefs.charsAndBG) {
			final lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed * playbackRate, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x + moveCamTo[0]/102, camFollow.x + moveCamTo[0]/102, lerpVal), FlxMath.lerp(camFollowPos.y + moveCamTo[1]/102, camFollow.y + moveCamTo[1]/102, lerpVal));
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
			final panLerpVal:Float = CoolUtil.clamp(elapsed * 4.4 * cameraSpeed, 0, 1);
			moveCamTo[0] = FlxMath.lerp(moveCamTo[0], 0, panLerpVal);
			moveCamTo[1] = FlxMath.lerp(moveCamTo[1], 0, panLerpVal);
		}
		if (ClientPrefs.showNPS && (notesHitDateArray.length > 0 || oppNotesHitDateArray.length > 0)) {
			notesToRemoveCount = 0;
			var i = 0;

			while (i < notesHitDateArray.length) {
				if (!Math.isNaN(notesHitDateArray[i]) && (notesHitDateArray[i] + 1000 * npsSpeedMult < Conductor.songPosition)) {
					notesToRemoveCount++;
				}
				i++;
			}

			if (notesToRemoveCount > 0) {
				notesHitDateArray.splice(0, notesToRemoveCount);
				notesHitArray.splice(0, notesToRemoveCount);
			}

			nps = 0;
			for (value in notesHitArray)
				nps += value;

			oppNotesToRemoveCount = 0;
			i = 0;

			while (i < oppNotesHitDateArray.length) {
				if (!Math.isNaN(oppNotesHitDateArray[i]) && (oppNotesHitDateArray[i] + 1000 * npsSpeedMult < Conductor.songPosition)) {
					oppNotesToRemoveCount++;
				}
				i++;
			}

			if (oppNotesToRemoveCount > 0) {
				oppNotesHitDateArray.splice(0, oppNotesToRemoveCount);
				oppNotesHitArray.splice(0, oppNotesToRemoveCount);
			}

			oppNPS = 0;
			for (value in oppNotesHitArray) {
				oppNPS += value;
			}

			if (oppNPS > maxOppNPS) {
				maxOppNPS = oppNPS;
			}
			if (nps > maxNPS) {
				maxNPS = nps;
			}

			if (ClientPrefs.ratingCounter && judgeCountUpdateFrame <= 8 && judgementCounter != null) updateRatingCounter();
			if (scoreTxtUpdateFrame <= 8 && scoreTxt != null) updateScore();
		}

		if (ClientPrefs.showcaseMode && !ClientPrefs.charsAndBG) {
		hitTxt.text = 'Notes Hit: ' + formatNumber(totalNotesPlayed) + ' / ' + formatNumber(totalNotes)
		+ '\nNPS: ' + formatNumber(nps) + '/' + formatNumber(maxNPS)
		+ '\nOpponent Notes Hit: ' + formatNumber(enemyHits) + ' / ' + formatNumber(opponentNoteTotal)
		+ '\nOpponent NPS: ' + formatNumber(oppNPS) + '/' + formatNumber(maxOppNPS)
		+ '\nTotal Note Hits: ' + formatNumber(Math.abs(totalNotesPlayed + enemyHits))
		+ '\nVideo Speedup: ' + Math.abs(playbackRate / playbackRate / playbackRate) + 'x';
		}

		if (judgeCountUpdateFrame > 0) judgeCountUpdateFrame = 0;
		if (scoreTxtUpdateFrame > 0) scoreTxtUpdateFrame = 0;
		if (iconBopsThisFrame > 0) iconBopsThisFrame = 0;
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
		if((botplayTxt != null && cpuControlled && !ClientPrefs.showcaseMode && !botplayUsed) && ClientPrefs.randomBotplayText) {
			botplayUsed = true;
			if(botplayTxt.text == "this text is gonna kick you out of botplay in 10 seconds" || botplayTxt.text == "Your Botplay Free Trial will end in 10 seconds.")
				{
					new FlxTimer().start(10, function(tmr:FlxTimer)
						{
							cpuControlled = false;
							botplayUsed = false;
							botplayTxt.visible = false;
						});
				}
			if(botplayTxt.text == "You use botplay? In 10 seconds I knock your botplay thing and text so you'll never use it >:)")
				{
					new FlxTimer().start(10, function(tmr:FlxTimer)
						{
							cpuControlled = false;
							botplayUsed = false;
							FlxG.sound.play(Paths.sound('pipe'), 10);
							botplayTxt.visible = false;
							PauseSubState.botplayLockout = true;
						});
				}
			if(botplayTxt.text == "you have 10 seconds to run.")
				{
					new FlxTimer().start(10, function(tmr:FlxTimer)
						{
							#if VIDEOS_ALLOWED
							startVideo('scary', function() Sys.exit(0));
							#else
							throw 'You should RUN, any minute now.'; // thought this'd be cooler
							// Sys.exit(0);
							#end
						});
				}
			if(botplayTxt.text == "you're about to die in 30 seconds")
				{
					new FlxTimer().start(30, function(tmr:FlxTimer)
						{
							health = 0;
						});
				}
			if(botplayTxt.text == "3 minutes until Boyfriend steals your liver.")
				{
				var title:String = 'Incoming Alert from Boyfriend';
				var message:String = '3 minutes until Boyfriend steals your liver!';
				FlxG.sound.music.pause();
				pauseVocals();

				lime.app.Application.current.window.alert(message, title);
				FlxG.sound.music.resume();
				unpauseVocals();
					new FlxTimer().start(180, function(tmr:FlxTimer)
						{
							Sys.exit(0);
						});
				}
			if(botplayTxt.text == "[DATA EXPUNGED]")
				{
				new FlxTimer().start(5, function(tmr:FlxTimer)
					{
						sendWindowsNotification('[DATA EXPUNGED]', 'Nice try...');
						for (i in 0...5) trace('[DATA EXPUNGED]'); // he is taking over >:)
						Sys.exit(0);
					});
				}

			if(botplayTxt.text == "3 minutes until I steal your liver.")
				{
				var title:String = 'Incoming Alert from Jordan';
				var message:String = '3 minutes until I steal your liver.';
				FlxG.sound.music.pause();
				pauseVocals();

				lime.app.Application.current.window.alert(message, title);
				unpauseVocals();
					new FlxTimer().start(180, function(tmr:FlxTimer)
						{
							Sys.exit(0);
						});
				}
		}

		if (controls.PAUSE && startedCountdown && canPause && !heyStopTrying)
		{
			final ret:Dynamic = callOnLuas('onPause', [], false);
			if(ret != FunkinLua.Function_Stop)
				openPauseMenu();
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
					openfl.system.System.exit(0);
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
					startVideo(SONG.event7Value, function() Sys.exit(0));
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
				if(updateTime && FlxG.game.ticks % (Std.int(ClientPrefs.framerate / 60) > 0 ? Std.int(ClientPrefs.framerate / 60) : 1) == 0) {
					if (timeBar.visible) {
						songPercent = Conductor.songPosition / songLength;
					}
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
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
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
					keyShit();
				}
				else if (ClientPrefs.charsAndBG) playerDance();

				amountOfRenderedNotes = 0;
				for (group in [notes, sustainNotes])
				{
					group.forEach(function(daNote)
					{
						updateNote(daNote);
					});
					group.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
				}
			}

			destroyNotes();

			while(eventNotes.length > 0 && Conductor.songPosition > eventNotes[0].strumTime) {

				var value1:String = '';
				if(eventNotes[0].value1 != null)
					value1 = eventNotes[0].value1;

				var value2:String = '';
				if(eventNotes[0].value2 != null)
					value2 = eventNotes[0].value2;

				triggerEventNote(eventNotes[0].event, value1, value2, eventNotes[0].strumTime);
				eventNotes.shift();
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
			if(FlxG.keys.justPressed.THREE) { //Go 10 seconds into the future :O
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

				if (SONG.song.toLowerCase() != 'anti-cheat-song')
				{
					unspawnNotes = unspawnNotesCopy.copy();
					eventNotes = eventNotesCopy.copy();
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
			if (!ffmpegMode) renderedTxt.text = 'Rendered/Skipped: ${formatNumber(amountOfRenderedNotes)}/${formatNumber(skippedCount)}/${formatNumber(notes.members.length + sustainNotes.members.length)}/${formatNumber(maxSkipped)}';
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
					capture.save(Paths.formatToSongPath(SONG.song) + #if linux '/' #else '\\' #end, filename);
				}
				catch (e) //If it catches an error, try capturing the frame again. If it still catches an error, skip the frame
				{
					try {
						capture.save(Paths.formatToSongPath(SONG.song) + #if linux '/' #else '\\' #end, filename);
					}
					catch (e) {}
				}
			}
			if (ClientPrefs.renderGCRate > 0 && (frameCaptured / targetFPS) % ClientPrefs.renderGCRate == 0) openfl.system.System.gc();
			frameCaptured++;
		}

		if(botplayTxt != null && botplayTxt.visible) {
			switch (ffmpegInfo)
			{
				case 'Frame Time': botplayTxt.text = CoolUtil.floatToStringPrecision(haxe.Timer.stamp() - takenTime, 3) + 's';
				case 'Time Remaining':
					var timeETA:String = CoolUtil.formatTime((FlxG.sound.music.length - Conductor.songPosition) * (60 / Main.fpsVar.currentFPS), 2);
					if (ClientPrefs.showcaseMode) botplayTxt.text += '\nTime Remaining: ' + timeETA;
					else botplayTxt.text = ogBotTxt + '\nTime Remaining: ' + timeETA;
				case 'Rendering Time':
					totalRenderTime = haxe.Timer.stamp() - startingTime;
					if (ClientPrefs.showcaseMode) botplayTxt.text += '\nTime Taken: ' + CoolUtil.formatTime(totalRenderTime * 1000, 2);
					else botplayTxt.text = ogBotTxt + '\nTime Taken: ' + CoolUtil.formatTime(totalRenderTime * 1000, 2);

				default:
			}
		}
		takenTime = haxe.Timer.stamp();
	}

	// Health icon updaters
	public dynamic function updateIconsScale(elapsed:Float)
	{
		if (ClientPrefs.iconBounceType == 'Old Psych') {
			iconP1.setGraphicSize(Std.int(FlxMath.lerp(iconP1.frameWidth, iconP1.width, CoolUtil.boundTo(1 - (elapsed * 30 * playbackRate), 0, 1))),
				Std.int(FlxMath.lerp(iconP1.frameHeight, iconP1.height, CoolUtil.boundTo(1 - (elapsed * 30 * playbackRate), 0, 1))));
			iconP2.setGraphicSize(Std.int(FlxMath.lerp(iconP2.frameWidth, iconP2.width, CoolUtil.boundTo(1 - (elapsed * 30 * playbackRate), 0, 1))),
				Std.int(FlxMath.lerp(iconP2.frameHeight, iconP2.height, CoolUtil.boundTo(1 - (elapsed * 30 * playbackRate), 0, 1))));
		}
		if (ClientPrefs.iconBounceType == 'Strident Crisis') {
			iconP1.setGraphicSize(Std.int(FlxMath.lerp(iconP1.frameWidth, iconP1.width, 0.50 / playbackRate)),
				Std.int(FlxMath.lerp(iconP1.frameHeight, iconP1.height, 0.50 / playbackRate)));
			iconP2.setGraphicSize(Std.int(FlxMath.lerp(iconP2.frameWidth, iconP2.width, 0.50 / playbackRate)),
				Std.int(FlxMath.lerp(iconP2.frameHeight, iconP1.height, 0.50 / playbackRate)));
			iconP1.updateHitbox();
			iconP2.updateHitbox();
		}
		if (ClientPrefs.iconBounceType == 'Dave and Bambi') {
			iconP1.setGraphicSize(Std.int(FlxMath.lerp(iconP1.frameWidth, iconP1.width, 0.8 / playbackRate)),
				Std.int(FlxMath.lerp(iconP1.frameHeight, iconP1.height, 0.8 / playbackRate)));
			iconP2.setGraphicSize(Std.int(FlxMath.lerp(iconP2.frameWidth, iconP2.width, 0.8 / playbackRate)),
				Std.int(FlxMath.lerp(iconP2.frameHeight, iconP2.height, 0.8 / playbackRate)));
		}
		if (ClientPrefs.iconBounceType == 'Plank Engine') {
			final funnyBeat = (Conductor.songPosition / 1000) * (Conductor.bpm / 60);

			iconP1.offset.y = Math.abs(Math.sin(funnyBeat * Math.PI))  * 16 - 4;
			iconP2.offset.y = Math.abs(Math.sin(funnyBeat * Math.PI))  * 16 - 4;
		}
		if (ClientPrefs.iconBounceType == 'New Psych' || ClientPrefs.iconBounceType == 'VS Steve') {
			final mult:Float = FlxMath.lerp(1, iconP1.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
			iconP1.scale.set(mult, mult);
			iconP1.updateHitbox();

			final mult:Float = FlxMath.lerp(1, iconP2.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
			iconP2.scale.set(mult, mult);
			iconP2.updateHitbox();
		}

		if (ClientPrefs.iconBounceType == 'Golden Apple') {
			iconP1.centerOffsets();
			iconP2.centerOffsets();
		}
		iconP1.updateHitbox();
		iconP2.updateHitbox();
	}

	var percent:Float = 0;
	var center:Float = 0;
	public dynamic function updateIconsPosition()
	{
		if (ClientPrefs.smoothHealth)
		{
			percent = 1 - (ClientPrefs.smoothHPBug ? (displayedHealth / maxHealth) : (FlxMath.bound(displayedHealth, 0, maxHealth) / maxHealth));

			iconP1.x = 0 + healthBar.x + (healthBar.width * percent) + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
			iconP2.x = 0 + healthBar.x + (healthBar.width * percent) - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
		}
		else //mb forgot to include this
		{
			center = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01));
			iconP1.x = center + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
			iconP2.x = center - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
		}
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
		var notesToKill:Int = 0;
		var eventsToRemove:Int = 0;
		KillNotes(); //kill any existing notes
		FlxG.sound.music.time = startingPoint;
		if (SONG.needsVoices) setVocalsTime(startingPoint);
		lastUpdateTime = startingPoint;
		Conductor.songPosition = startingPoint;

		unspawnNotes = unspawnNotesCopy.copy();
		eventNotes = eventNotesCopy.copy();
		for (n in unspawnNotes)
			if (n.strumTime <= startingPoint)
				notesToKill++;

		for (e in eventNotes)
			if (e.strumTime <= startingPoint)
				eventsToRemove++;

		if (notesToKill > 0)
			unspawnNotes.splice(0, notesToKill);

		if (eventsToRemove > 0)
			eventNotes.splice(0, eventsToRemove);

		if (!ClientPrefs.showNotes)
		{
			var noteIndex:Int = 0;
			while (unspawnNotes.length > 0 && unspawnNotes[noteIndex] != null)
			{
				unspawnNotes[noteIndex].wasHit = false;
				noteIndex++;
			}
		}
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	public var gameOverTimer:FlxTimer;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead)
		{
			if (ClientPrefs.instaRestart)
			{
				restartSong(true);
			}
			var ret:Dynamic = callOnLuas('onGameOver', [], false);
			stagesFunc(function(stage:BaseStage) stage.onGameOver());
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
				#if LUA_ALLOWED
				modchartTimers.clear();
				modchartTweens.clear();
				#end
				FlxG.camera.setFilters([]);

				if(GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend));
						gameOverTimer = null;
					});
				}
				else
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend));
				}

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if(autoUpdateRPC) DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String, strumTime:Float) {
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if(Math.isNaN(flValue1)) flValue1 = null;
		if(Math.isNaN(flValue2)) flValue2 = null;

		switch(eventName) {
			case 'Hey!':
				if (ClientPrefs.charsAndBG) {
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = time;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = time;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value) || value < 1) value = 1;
				gfSpeed = value;
				if (Conductor.bpm >= 500) singDurMult = value;

			case 'Enable Camera Bop':
				camZooming = true;

			case 'Disable Camera Bop':
				camZooming = false;
				FlxG.camera.zoom = defaultCamZoom;
				camHUD.zoom = 1;

			case 'Enable Bot Energy':
				if (!cpuControlled)
				{
					canUseBotEnergy = true;
					energyBarBG.visible = energyBar.visible = energyTxt.visible = true;
					var varsFadeIn:Array<Dynamic> = [energyBarBG, energyBar, energyTxt];
					for (i in 0...varsFadeIn.length) FlxTween.tween(varsFadeIn[i], {alpha: 1}, 0.75, {ease: FlxEase.expoOut});
				}

			case 'Disable Bot Energy':
				if (!cpuControlled)
				{
					canUseBotEnergy = false;
					if (usingBotEnergy) usingBotEnergy = false;
					var varsFadeIn:Array<Dynamic> = [energyBarBG, energyBar, energyTxt];
					for (i in 0...varsFadeIn.length)
						FlxTween.tween(varsFadeIn[i], {alpha: 0}, 0.75, {
							ease: FlxEase.expoOut,
								onComplete: function(_){
									varsFadeIn[i].visible = false;
								}});
				}

			case 'Set Bot Energy Speeds':
				var drainSpeed:Float = Std.parseFloat(value1);
				if (Math.isNaN(drainSpeed)) drainSpeed = 1;
				energyDrainSpeed = drainSpeed;

				var refillSpeed:Float = Std.parseFloat(value2);
				if (Math.isNaN(refillSpeed)) refillSpeed = 1;
				energyRefillSpeed = refillSpeed;

			case 'Credits Popup':
			{
				var string1:String = value1;
				if (value1.length < 1) string1 = SONG.song;
				var string2:String = value2;
				if (value2.length < 1) string2 = SONG.songCredit;
				var creditsPopup:CreditsPopUp = new CreditsPopUp(FlxG.width, 200, string1, string2);
				creditsPopup.camera = camHUD;
				creditsPopup.scrollFactor.set();
				creditsPopup.x = creditsPopup.width * -1;
				add(creditsPopup);

				FlxTween.tween(creditsPopup, {x: 0}, 0.5, {ease: FlxEase.backOut, onComplete: function(tweeen:FlxTween)
				{
					FlxTween.tween(creditsPopup, {x: creditsPopup.width * -1} , 1, {ease: FlxEase.backIn, onComplete: function(tween:FlxTween)
					{
						creditsPopup.destroy();
							}, startDelay: 3});
						}});
			}
			case 'Camera Bopping':
				var _interval:Int = Std.parseInt(value1);
				if (Math.isNaN(_interval))
					_interval = 4;
				var _intensity:Float = Std.parseFloat(value2);
				if (Math.isNaN(_intensity))
					_intensity = 1;

				camBopIntensity = _intensity;
				camBopInterval = _interval;
				if (_interval != 4) usingBopIntervalEvent = true;
					else usingBopIntervalEvent = false;

			case 'Camera Twist':
				camTwist = true;
				var _intensity:Float = Std.parseFloat(value1);
				if (Math.isNaN(_intensity))
					_intensity = 0;
				var _intensity2:Float = Std.parseFloat(value2);
				if (Math.isNaN(_intensity2))
					_intensity2 = 0;
				camTwistIntensity = _intensity;
				camTwistIntensity2 = _intensity2;
				if (_intensity2 == 0)
				{
					camTwist = false;
					for (i in [camHUD, camGame])
					{
						FlxTween.cancelTweensOf(i);
						FlxTween.tween(i, {angle: 0, x: 0, y: 0}, 1, {ease: FlxEase.sineOut});
					}
				}
			case 'Change Note Multiplier':
				var noteMultiplier:Float = Std.parseFloat(value1);
				if (Math.isNaN(noteMultiplier))
					noteMultiplier = 1;

				if (value2 == "") {
					polyphonyOppo = noteMultiplier;
					polyphonyBF = noteMultiplier;
				} else {
					switch(value2) {
						case "1": polyphonyOppo = noteMultiplier;
						case "2": polyphonyBF = noteMultiplier;
					}
				}
				//trace(value2 + " | " + polyphonyBF + ", " + polyphonyOppo);

			case 'Set Camera Zoom':
				var newZoom:Float = Std.parseFloat(value1);
				if (Math.isNaN(newZoom))
					newZoom = ogCamZoom;
				defaultCamZoom = newZoom;

			case 'Fake Song Length':
				var fakelength:Float = Std.parseFloat(value1);
				fakelength *= (Math.isNaN(fakelength) ? 1 : 1000); //don't multiply if value1 is null, but do if value1 is not null
				var doTween:Bool = value2 == "true" ? true : false;
				if (Math.isNaN(fakelength))
					fakelength = FlxG.sound.music.length;
				if (doTween = true) FlxTween.tween(this, {songLength: fakelength}, 1, {ease: FlxEase.expoOut});
				if (doTween = true && (Math.isNaN(fakelength))) FlxTween.tween(this, {songLength: FlxG.sound.music.length}, 1, {ease: FlxEase.expoOut});
				songLength = fakelength;

			case 'Add Camera Zoom':
				if(ClientPrefs.camZooms && FlxG.camera.zoom < 1.35) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if(Math.isNaN(val2)) val2 = 0;

						switch(val2) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null && ClientPrefs.charsAndBG)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			// Evil
			case 'Windows Notification':
				if (value1 == "") value1 = "JS Engine";
				if (value2 == "") value2 = "Are you doing that one bambi song?";
				sendWindowsNotification(value1, value2, true);

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					var val1:Float = Std.parseFloat(value1);
					var val2:Float = Std.parseFloat(value2);
					if(Math.isNaN(val1)) val1 = 0;
					if(Math.isNaN(val2)) val2 = 0;

					isCameraOnForcedPos = false;
					if(!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2))) {
						camFollow.x = val1;
						camFollow.y = val2;
						isCameraOnForcedPos = true;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}


			case 'Change Character':
			if (ClientPrefs.charsAndBG)
			{
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType) {
					case 0:
						if(boyfriend.curCharacter != value2) {
							if(!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							if (!value2.startsWith('bf') && !value2.startsWith('boyfriend')) iconP1.changeIcon(boyfriend.healthIcon);
							else {
								if (ClientPrefs.bfIconStyle == 'VS Nonsense V2') iconP1.changeIcon('bfnonsense');
								if (ClientPrefs.bfIconStyle == 'Doki Doki+') iconP1.changeIcon('bfdoki');
								if (ClientPrefs.bfIconStyle == 'Leather Engine') iconP1.changeIcon('bfleather');
								if (ClientPrefs.bfIconStyle == "Mic'd Up") iconP1.changeIcon('bfmup');
								if (ClientPrefs.bfIconStyle == "FPS Plus") iconP1.changeIcon('bffps');
								if (ClientPrefs.bfIconStyle == "OS 'Engine'") iconP1.changeIcon('bfos');
							}
							if (boyfriend.noteskin != null) bfNoteskin = boyfriend.noteskin;
						}
						setOnLuas('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf');
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf')) {
								if(wasGf && gf != null) {
									gf.visible = true;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
							if (ClientPrefs.botTxtStyle == 'VS Impostor') {
								if (botplayTxt != null) FlxTween.color(botplayTxt, 1, botplayTxt.color, FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]));

								if (scoreTxt != null && !ClientPrefs.hideHud) FlxTween.color(scoreTxt, 1, scoreTxt.color, FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]));
							}
							if (ClientPrefs.scoreStyle == 'JS Engine' && !ClientPrefs.hideHud)
								if (scoreTxt != null) FlxTween.color(scoreTxt, 1, scoreTxt.color, FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]));

							if (dad.noteskin != null) dadNoteskin = dad.noteskin;
						}
						setOnLuas('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2))
								{
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnLuas('gfName', gf.curCharacter);
						}
				}
				shouldDrainHealth = (opponentDrain || (opponentChart ? boyfriend.healthDrain : dad.healthDrain));
				if (!opponentDrain && !Math.isNaN((opponentChart ? boyfriend : dad).drainAmount)) healthDrainAmount = opponentChart ? boyfriend.drainAmount : dad.drainAmount;
				if (!opponentDrain && !Math.isNaN((opponentChart ? boyfriend : dad).drainFloor)) healthDrainFloor = opponentChart ? boyfriend.drainFloor : dad.drainFloor;
				if (!ClientPrefs.ogHPColor) reloadHealthBarColors(dad.healthColorArray, boyfriend.healthColorArray);
				if (ClientPrefs.showNotes)
				{
					for (i in strumLineNotes.members)
					{
						var noteskin:String = (i.player == 0 ? dadNoteskin : bfNoteskin);
						if (noteskin != null)
						{
							i.updateNoteSkin(noteskin);
							i.useRGBShader = noteskin.length < 1 && ClientPrefs.enableColorShader;
						}
					}
				}
				if (ClientPrefs.noteColorStyle == 'Char-Based')
				{
					for (group in [notes, sustainNotes])
						for (note in group){
							if (note == null)
								continue;
							if (ClientPrefs.enableColorShader) note.updateRGBColors();
						}
				}
			}

			case 'Rainbow Eyesore':
				#if linux
				#if LUA_ALLOWED
				addTextToDebug('Rainbow shader does not work on Linux right now!', FlxColor.RED);
				#else
				trace('Rainbow shader does not work on Linux right now!');
				#end
				return;
				#end
				if(ClientPrefs.flashing && ClientPrefs.shaders) {
					var timeRainbow:Int = Std.parseInt(value1);
					var speedRainbow:Float = Std.parseFloat(value2);
					disableTheTripper = false;
					disableTheTripperAt = timeRainbow;
					FlxG.camera.filters = [new ShaderFilter(screenshader.shader)];
					screenshader.waveAmplitude = 1;
					screenshader.waveFrequency = 2;
					screenshader.waveSpeed = speedRainbow * playbackRate;
					screenshader.shader.uTime.value[0] = new flixel.math.FlxRandom().float(-100000, 100000);
					screenshader.shader.uampmul.value[0] = 1;
					screenshader.Enabled = true;
				}
			case 'Popup':
				var title:String = (value1);
				var message:String = (value2);
				FlxG.sound.music.pause();
				pauseVocals();

				lime.app.Application.current.window.alert(message, title);
				FlxG.sound.music.resume();
				unpauseVocals();
			case 'Popup (No Pause)':
				var title:String = (value1);
				var message:String = (value2);

				lime.app.Application.current.window.alert(message, title);

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1;
				if(Math.isNaN(val2)) val2 = 0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1;

				if(val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2 / playbackRate, {ease: FlxEase.linear, onComplete:
						function (twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}

			case 'Change Song Name':
				if(ClientPrefs.timeBarType == 'Song Name')
				{
					if (value1.length > 1)
						timeTxt.text = value1;
					else timeTxt.text = curSong;
				}

			case 'Set Property':
				try
				{
					var split:Array<String> = value1.split('.');
					if(split.length > 1) {
						FunkinLua.setVarInArray(FunkinLua.getPropertyLoopThingWhatever(split), split[split.length-1], value2);
					} else {
						FunkinLua.setVarInArray(this, value1, value2);
					}
				}
				catch(e:Dynamic)
				{
					var len:Int = e.message.indexOf('\n') + 1;
					if(len <= 0) len = e.message.length;
					#if LUA_ALLOWED
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, len), FlxColor.RED);
					#else
					FlxG.log.warn('ERROR ("Set Property" Event) - ' + e.message.substr(0, len));
					#end
				}
		}
		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnLuas('onEvent', [eventName, value1, value2, strumTime]);
	}

	function sendWindowsNotification(title:String, desc:String, isEvent:Bool = false) {
		// haha i got them from slushi engine :) (by nael2xd)
		#if windows
		function getWindowsVersion() {
			var windowsVersions:Map<String, Int> = [
				"Windows 11" => 11,
				"Windows 10" => 10,
				"Windows 8.1" => 8,
				"Windows 8" => 8,
				"Windows 7" => 7,
			];

			var platformLabel = System.platformLabel;
			var words = platformLabel.split(" ");
			var windowsIndex = words.indexOf("Windows");
			var result = "";
			if (windowsIndex != -1 && windowsIndex < words.length - 1)
			{
				result = words[windowsIndex] + " " + words[windowsIndex + 1];
			}

			if (windowsVersions.exists(result)) return windowsVersions.get(result);

			return 0;
		}

		var powershellCommand = "powershell -Command \"& {$ErrorActionPreference = 'Stop';"
		+ "$title = '"
		+ desc
		+ "';"
		+ "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null;"
		+ "$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText01);"
		+ "$toastXml = [xml] $template.GetXml();"
		+ "$toastXml.GetElementsByTagName('text').AppendChild($toastXml.CreateTextNode($title)) > $null;"
		+ "$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;"
		+ "$xml.LoadXml($toastXml.OuterXml);"
		+ "$toast = [Windows.UI.Notifications.ToastNotification]::new($xml);"
		+ "$toast.Tag = 'Test1';"
		+ "$toast.Group = 'Test2';"
		+ "$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('"
		+ title
		+ "');"
		+ "$notifier.Show($toast);}\"";

		if (title != null && title != "" && desc != null && desc != "" && getWindowsVersion() != 7)
			new HiddenProcess(powershellCommand);

		#else
		if (isEvent) {
			#if linux
			addTextToDebug('Windows Notifications are not currently supported on Linux!', FlxColor.RED);
			return;
			#else
			trace('Windows Notifications are not currently supported on this platform!');
			return;
			#end
		}
		#end
	}

	public function moveCameraSection():Void {
		if(SONG.notes[curSection] == null) return;

		if (gf != null && SONG.notes[curSection].gfSection)
		{
			moveCameraToGirlfriend();
			callOnLuas('onMoveCamera', ['gf']);
			return;
		}

		if (!SONG.notes[curSection].mustHitSection)
		{
			moveCamera(true);
			callOnLuas('onMoveCamera', ['dad']);
		}
		else
		{
			moveCamera(false);
			callOnLuas('onMoveCamera', ['boyfriend']);
		}
	}

	public function moveCameraToGirlfriend()
	{
		camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
		camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
		camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
		tweenCamIn();
	}

	var cameraTwn:FlxTween;
	public function moveCamera(isDad:Bool)
	{
		if(isDad)
		{
			if(dad == null) return;
			camFollow.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			if(boyfriend == null) return;
			camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
					function (twn:FlxTween)
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	public function tweenCamIn() {
		if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3) {
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
				function (twn:FlxTween) {
					cameraTwn = null;
				}
			});
		}
	}

	function snapCamFollowToPos(x:Float, y:Float) {
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
	}

	public function unpauseVocals()
	{
		for (i in [vocals, opponentVocals])
			if (i != null && i.time <= FlxG.sound.music.length)
				i.resume();
	}
	public function pauseVocals()
	{
		for (i in [vocals, opponentVocals])
			if (i != null && i.time <= FlxG.sound.music.length)
				i.pause();
	}
	public function setVocalsTime(time:Float)
	{
		for (i in [vocals, opponentVocals])
			if (i != null && i.time < vocals.length)
				i.time = time;
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		if (!trollingMode && SONG.song.toLowerCase() != 'anti-cheat-song') {
			updateTime = false;
			FlxG.sound.music.volume = 0;
			vocals.volume = opponentVocals.volume = 0;
			FlxG.mouse.unload(); // just in case you changed it beforehand
			pauseVocals();
			if(!ffmpegMode){
				if(ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
					endCallback();
				} else {
					finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
						endCallback();
					});
				}
			} else endCallback();
		}
	}

	public function loopSongLol()
	{
		stepsToDo = /* You need stepsToDo to change, otherwise the sections break. */ curStep = curBeat = curSection = 0; // Wow.
		oldStep  = -1;

		// And now it's time for the actual troll mode stuff
		var TROLL_MAX_SPEED:Float = 2048; // Default is medium max speed
		switch(ClientPrefs.trollMaxSpeed) {
			case 'Lowest':
				TROLL_MAX_SPEED = 256;
			case 'Lower':
				TROLL_MAX_SPEED = 512;
			case 'Low':
				TROLL_MAX_SPEED = 1024;
			case 'Medium':
				TROLL_MAX_SPEED = 2048;
			case 'High':
				TROLL_MAX_SPEED = 5120;
			case 'Highest':
				TROLL_MAX_SPEED = 10000;
			default:
				TROLL_MAX_SPEED = 1.79e+308; //no limit (until you eventually suffer the fate of crashing :trollface:)
		}

		if (ClientPrefs.voiidTrollMode) {
			playbackRate *= 1.05;
		} else {
			playbackRate += calculateTrollModeStuff(playbackRate);
		}

		if (playbackRate >= TROLL_MAX_SPEED && ClientPrefs.trollMaxSpeed != 'Disabled') { // Limit playback rate to the troll mode max speed
			playbackRate = TROLL_MAX_SPEED;
		}
	}

	function calculateTrollModeStuff(pb:Float):Float {
		// Peak Code 2
		if (pb >= 2 && pb < 4) return 0.1;
		if (pb >= 4 && pb < 8) return 0.2;
		if (pb >= 8 && pb < 16) return 0.4;
		if (pb >= 16 && pb < 32) return 0.8;
		if (pb >= 32 && pb < 64) return 1.6;
		if (pb >= 64 && pb < 128) return 3.2;
		if (pb >= 128 && pb < 256) return 6.4;
		if (pb >= 256 && pb < 512) return 12.8;
		if (pb >= 512) return 25.6;
		return 0.05;
	}

	function calculateResetTime():Float {
		if (ClientPrefs.strumLitStyle == 'BPM Based') return (Conductor.stepCrochet * 1.5 / 1000) / playbackRate;
		return 0.15 / playbackRate;
	}

	public var transitioning = false;
	public function endSong():Void
	{
		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		startedCountdown = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
		checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);
		#end

		var ret:Dynamic = callOnLuas('onEndSong', [], true);
		if(ret != FunkinLua.Function_Stop && !transitioning) {
			if (!cpuControlled && !playerIsCheating && ClientPrefs.safeFrames <= 10)
			{
				#if !switch
				var percent:Float = ratingPercent;
				if(Math.isNaN(percent)) percent = 0;
				Highscore.saveScore(SONG.song, Std.int(songScore), storyDifficulty, percent);
				#end
			}
			playbackRate = 1;

			if (chartingMode)
			{
				if (!ffmpegMode) openChartEditor();
				else
				{
					endingTime = haxe.Timer.stamp();
					FlxG.switchState(new RenderingDoneSubState(endingTime - startingTime));
					chartingMode = true;
				}
				return;
			}

			if (isStoryMode && !wasOriginallyFreeplay)
			{
				campaignScore += songScore;
				campaignMisses += Std.int(songMisses);

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					WeekData.loadTheFirstEnabledMod();
					FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

					canResync = false;
					FlxG.switchState(new StoryMenuState());

					if(!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false)) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);

						Highscore.saveWeekScore(WeekData.getWeekFileName(), Std.int(campaignScore), storyDifficulty);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);

					canResync = false;
					FlxG.sound.music.stop();
					LoadingState.loadAndSwitchState(new PlayState());
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				WeekData.loadTheFirstEnabledMod();
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

				canResync = false;
				if (!ffmpegMode) FlxG.switchState(new FreeplayState());
				else
				{
					endingTime = haxe.Timer.stamp();
					FlxG.switchState(new RenderingDoneSubState(endingTime - startingTime));
				}
				FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
				changedDifficulty = false;
			}
			transitioning = true;
		}
	}

	public function KillNotes() {
		for (group in [notes, sustainNotes])
		while (group.length > 0) {
			group.remove(group.members[0], true);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public function restartSong(noTrans:Bool = true)
	{
		if (process != null) stopRender();
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		vocals.volume = opponentVocals.volume = 0;

		if(noTrans)
		{
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
		}
		else
		{
			FlxG.resetState();
		}
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
		if (isPixelStage)
		{
			pixelShitPart1 = 'pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		var normalRating:String = 'ratings/' + ClientPrefs.ratingType.toLowerCase().replace(' ', '-').trim() + '/';

		pixelShitPart1 += normalRating;

		Paths.image(pixelShitPart1 + "perfect" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "sick" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "good" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "bad" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "shit" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "miss" + pixelShitPart2);

		for (i in 0...10) Paths.image(pixelShitPart1 + 'num' + i + pixelShitPart2);
		if (Paths.fileExists('images/${normalRating}' + 'hitStrings.txt', TEXT))
			hitStrings = Paths.mergeAllTextsNamed('images/${normalRating}' + 'hitStrings.txt', null, false);

		if (Paths.fileExists('images/${normalRating}' + 'fcStrings.txt', TEXT))
			fcStrings = Paths.mergeAllTextsNamed('images/${normalRating}' + 'fcStrings.txt', null, false);

		if (Paths.fileExists('images/${normalRating}' + 'judgeCountStrings.txt', TEXT))
			judgeCountStrings = Paths.mergeAllTextsNamed('images/${normalRating}' + 'judgeCountStrings.txt', null, false);
	}

	var rating:Popup = null;
	var numScore:Popup = null;
	var daRating:Rating = null;
	var noteDiff = 0.0;

	function judgeNote(note:Note = null, ?miss:Bool = false)
	{
		if (note == null) return;
		if (daRating == null) daRating = ratingsData[0]; //because it likes being stupid
		if (!cpuControlled)
		{
			noteDiff = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset) / playbackRate;
			final wife:Float = EtternaFunctions.wife3(noteDiff, Conductor.timeScale);

			daRating = Conductor.judgeNote(note, noteDiff, cpuControlled, miss);
			if (sickOnly && (noteDiff > ClientPrefs.sickWindow || noteDiff < -ClientPrefs.sickWindow))
				doDeathCheck(true);

			if (miss) daRating.image = 'miss';
				else if (ratingsData[0].image == 'miss') ratingsData[0].image = !ClientPrefs.noMarvJudge ? 'perfect' : 'sick';

			if (!miss)
			{
				if (!ClientPrefs.complexAccuracy) totalNotesHit += daRating.ratingMod;
				if (ClientPrefs.complexAccuracy) totalNotesHit += wife;
				note.ratingMod = daRating.ratingMod;
				if(!note.ratingDisabled) daRating.increase();
			}
			note.rating = daRating.name;
		}

		if(daRating.noteSplash && !note.noteSplashDisabled && !miss && splashesPerFrame[1] <= 4)
			spawnNoteSplashOnNote(false, note);

		if(!practiceMode && !miss) {
			songScore += daRating.score * (opponentChart ? polyphonyOppo : polyphonyBF);
			if(!cpuControlled && !note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				if(!cpuControlled || cpuControlled) {
					RecalculateRating(false);
				}
			}
		}
	}

	var separatedScore:Array<Dynamic> = [];
	private function popUpScore(note:Note = null, ?miss:Bool = false):Void
	{
		popUpsFrame += 1;

		if(ClientPrefs.scoreZoom && scoreTxt != null && !cpuControlled && !miss)
		{
			if(scoreTxtTween != null) {
				scoreTxtTween.cancel();
			}
			scoreTxt.scale.x = 1.075;
			scoreTxt.scale.y = 1.075;
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween) {
					scoreTxtTween = null;
				}
			});
		}

		if (!miss && !ffmpegMode) (opponentChart ? opponentVocals : vocals).volume = 1;

		judgeNote(note, miss);

		if (popUpsFrame <= 3)
		{
			if (!ClientPrefs.comboStacking) while (popUpGroup.members.length > 0)
			{
				var spr = popUpGroup.members[0];
				if (spr == null) continue;

				FlxTween.cancelTweensOf(spr);
				popUpGroup.remove(spr, true);
				spr.kill();
			}

			if (showRating && ClientPrefs.ratingPopups && !ClientPrefs.simplePopups) {
				rating = popUpGroup.recycle(Popup);
				rating.setupRating(pixelShitPart1 + daRating.image + pixelShitPart2);
				rating.alphaTween();
				popUpGroup.insert(0, rating);
			}

			if (showComboNum && ClientPrefs.comboPopups && !ClientPrefs.simplePopups)
			{
				var tempCombo:Float = (combo > 0 ? combo : -combo);
				var tempComboAlt:Float = tempCombo;

				separatedScore = [];
				while(tempCombo >= 10)
				{
					separatedScore.unshift(Math.ffloor(tempCombo / 10) % 10);
					tempCombo = Math.ffloor(tempCombo / 10);
				}
				separatedScore.push(tempComboAlt % 10);

				if (combo < 0) separatedScore.unshift("neg");

				for (daLoop=>i in separatedScore)
				{
					numScore = popUpGroup.recycle(Popup);
					numScore.setupNumber(pixelShitPart1 + 'num' + i + pixelShitPart2, daLoop, tempComboAlt);
					if (miss) numScore.color = FlxColor.fromRGB(204, 66, 66);
					numScore.alphaTween(true);
					popUpGroup.insert(0, numScore);
				}
			}

			if (ClientPrefs.showMS && !ClientPrefs.hideHud) {
				FlxTween.cancelTweensOf(msTxt);
				msTxt.cameras = [camHUD];
				msTxt.visible = true;
				msTxt.screenCenter();
				msTxt.x = (FlxG.width * 0.35) + 80;
				msTxt.alpha = 1;
				msTxt.text = FlxMath.roundDecimal(-noteDiff, 3) + " MS";
				if (cpuControlled) msTxt.text = "0 MS (Bot)";
				msTxt.x += ClientPrefs.comboOffset[0];
				msTxt.y -= ClientPrefs.comboOffset[1];
				if (combo >= 10000) msTxt.x += 30 * (Std.string(combo).length - 4);
				FlxTween.tween(msTxt,
					{y: msTxt.y + 8},
					0.1 / playbackRate,
					{onComplete: function(_){

							FlxTween.tween(msTxt, {alpha: 0}, 0.2 / playbackRate, {
								// ease: FlxEase.circOut,
								onComplete: function(_){msTxt.visible = false;},
								startDelay: 1.4 / playbackRate
							});
						}
					});
				switch (daRating.name) //This is so stupid, but it works
				{
					case 'perfect': msTxt.color = FlxColor.YELLOW;
					case 'sick':  msTxt.color = FlxColor.CYAN;
					case 'good': msTxt.color = FlxColor.LIME;
					case 'bad': msTxt.color = FlxColor.ORANGE;
					case 'shit': msTxt.color = FlxColor.RED;
					default: msTxt.color = FlxColor.WHITE;
				}
				if (miss) msTxt.color = FlxColor.fromRGB(204, 66, 66);
			}

			if (ClientPrefs.ratingPopups && ClientPrefs.simplePopups && !ClientPrefs.hideHud) {
				FlxTween.cancelTweensOf(judgeTxt);
				FlxTween.cancelTweensOf(judgeTxt.scale);
				judgeTxt.cameras = [camHUD];
				judgeTxt.visible = true;
				judgeTxt.screenCenter(X);
				if (botplayTxt != null) judgeTxt.y = !ClientPrefs.downScroll ? botplayTxt.y + 60 : botplayTxt.y - 60;
				judgeTxt.alpha = 1;
				if (!miss) switch (daRating.name)
				{
					case 'perfect':
						judgeTxt.color = FlxColor.YELLOW;
						judgeTxt.text = hitStrings[0] + '\n' + formatNumber(combo);
					case 'sick':
						judgeTxt.color = FlxColor.CYAN;
						judgeTxt.text = hitStrings[1] + '\n' + formatNumber(combo);
					case 'good':
						judgeTxt.color = FlxColor.LIME;
						judgeTxt.text = hitStrings[2] + '\n' + formatNumber(combo);
					case 'bad':
						judgeTxt.color = FlxColor.ORANGE;
						judgeTxt.text = hitStrings[3] + '\n' + formatNumber(combo);
					case 'shit':
						judgeTxt.color = FlxColor.RED;
						judgeTxt.text = hitStrings[4] + '\n' + formatNumber(combo);
					default: judgeTxt.color = FlxColor.WHITE;
				}
				else
				{
					judgeTxt.color = FlxColor.fromRGB(204, 66, 66);
					judgeTxt.text = hitStrings[5] + '\n' + formatNumber(combo);
				}
				judgeTxt.scale.x = 1.075;
				judgeTxt.scale.y = 1.075;
				FlxTween.tween(judgeTxt.scale,
					{x: 1, y: 1},
				0.1 / playbackRate,
					{onComplete: function(_){
							FlxTween.tween(judgeTxt.scale, {x: 0, y: 0}, 0.1 / playbackRate, {
								onComplete: function(_){judgeTxt.visible = false;},
								startDelay: 1.0 / playbackRate
							});
						}
					});
			}
			if (ClientPrefs.ratingPopups && !ClientPrefs.simplePopups) popUpGroup.sort((o, a, b) ->
				{
					return FlxSort.byValues(FlxSort.ASCENDING, a.popTime, b.popTime);
				}
			);
		}
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);

		if (!ClientPrefs.controllerMode && FlxG.keys.checkStatus(eventKey, JUST_PRESSED))
			keyPressed(key);
	}

	public var strumsBlocked:Array<Bool> = [];
	private function keyPressed(key:Int):Void
	{
		if(cpuControlled || paused || key < 0) return;
		if(!generatedMusic || endingSong || boyfriend.stunned) return;

		//more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		Conductor.songPosition = FlxG.sound.music.time;

		var canMiss:Bool = !ClientPrefs.ghostTapping;

		// obtain notes that the player can hit
		var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool {
			var canHit:Bool = !usingBotEnergy && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			// trace('[keyPressed] Note? ${n != null}, noteData=${n.noteData}, strumTime=${n.strumTime}, canHit=$canHit, mustPress=${n.mustPress}, tooLate=${n.tooLate}, wasGoodHit=${n.wasGoodHit}, Conductor=${Conductor.songPosition}');
			return n != null && canHit && !n.isSustainNote && n.noteData == key;
		});
		plrInputNotes.sort(sortHitNotes);

		if (plrInputNotes.length != 0) {
			var funnyNote:Note = plrInputNotes[0]; // front note

			if (plrInputNotes.length > 1) {
				var doubleNote:Note = plrInputNotes[1];

				//if the note has the same notedata and doOppStuff indicator as funnynote, then do the check
				if (doubleNote.noteData == funnyNote.noteData && doubleNote.doOppStuff == funnyNote.doOppStuff) {
					// if the note has a 0ms distance (is on top of the current note), kill it
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
						invalidateNote(doubleNote);
					else if (doubleNote.strumTime < funnyNote.strumTime)
					{
						// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
						funnyNote = doubleNote;
					}
				}
				else goodNoteHit(doubleNote); //otherwise, hit doubleNote instead of killing it
			}
			goodNoteHit(funnyNote);
			if (plrInputNotes.length > 2 && ClientPrefs.ezSpam) {
				for (i in 1...plrInputNotes.length) goodNoteHit(plrInputNotes[i]);
			}
		}
		else {
			callOnLuas('onGhostTap', [key]);
			if (!opponentChart && ClientPrefs.ghostTapAnim && ClientPrefs.charsAndBG)
			{
				boyfriend.playAnim(singAnimations[Std.int(Math.abs(key))], true);
				if (ClientPrefs.cameraPanning) camPanRoutine(singAnimations[Std.int(Math.abs(key))], 'bf');
				boyfriend.holdTimer = 0;
			}
			if (opponentChart && ClientPrefs.ghostTapAnim && ClientPrefs.charsAndBG)
			{
				dad.playAnim(singAnimations[Std.int(Math.abs(key))], true);
				if (ClientPrefs.cameraPanning) camPanRoutine(singAnimations[Std.int(Math.abs(key))], 'dad');
				dad.holdTimer = 0;
			}
			if (canMiss) {
				noteMissPress(key);
			}
		}

		keysPressed[key] = true;

		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;

		var spr:StrumNote = playerStrums.members[key];
		if(strumsBlocked[key] != true && spr != null && spr.animation != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}
		callOnLuas('onKeyPress', [key]);
	}

	function sortHitNotes(a:Dynamic, b:Dynamic):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		// trace('Pressed: ' + eventKey);

		if (!ClientPrefs.controllerMode && key > -1)
			keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if (cpuControlled || !startedCountdown || paused)
			return;

		var spr:StrumNote = playerStrums.members[key];
		if (spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
		callOnLuas('onKeyRelease', [key]);
	}

	public function getKeyFromEvent(key:FlxKey):Int
	{
		if (key != NONE)
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if (key == keysArray[i][j])
						return i;
				}
			}

		return -1;
	}

	// Hold notes
	private function keyShit():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = parseKeys();
		var pressArray:Array<Bool> = parseKeys('_P');
		var releaseArray:Array<Bool> = parseKeys('_R');
		strumsHeld = holdArray;
		strumHeldAmount = strumsHeld.filter(function(value) return value).length;

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			if(pressArray.contains(true))
			{
				for (i in 0...pressArray.length)
				{
					if(pressArray[i] && strumsBlocked[i] != true)
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}

		var char:Character = boyfriend;
		if (opponentChart) char = dad;
		if (startedCountdown && !char.stunned && generatedMusic)
		{
			// rewritten inputs???
			/*
			for (group in [notes, sustainNotes]) group.forEachAlive(function(daNote:Note)
			{
				// hold note functions
				if (!usingBotEnergy && strumsBlocked[daNote.noteData] != true && daNote.isSustainNote && holdArray[daNote.noteData] && daNote.canBeHit
				&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit) {
					goodNoteHit(daNote);
				}
			});
			*/
			for (group in [notes, sustainNotes]){
				if (group.length > 0)
				{
					for (n in group.members)
					{ // I can't do a filter here, that's kinda awesome
						var canHit:Bool = (n != null && !usingBotEnergy && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

						if (canHit && n.isSustainNote)
						{
							var released:Bool = !holdArray[n.noteData];

							if (!released)
								goodNoteHit(n);
						}
					}
				}
			}

			if(ClientPrefs.charsAndBG && FlxG.keys.anyJustPressed(tauntKey) && !char.animation.curAnim.name.endsWith('miss') && char.specialAnim == false && ClientPrefs.spaceVPose){
				if (char.animOffsets.exists('hey'))
				{
					char.playAnim('hey', true);
					char.specialAnim = true;
					char.heyTimer = 0.59;
					FlxG.sound.play(Paths.sound('hey'));
					trace("HEY!!");
				}
				else trace ('Character doesnt have a hey animation!');
			}

			if (!holdArray.contains(true) || endingSong) {
				if (ClientPrefs.charsAndBG) playerDance();
			}

			#if ACHIEVEMENTS_ALLOWED
			else checkForAchievement(['oversinging']);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode || strumsBlocked.contains(true))
		{
			if(releaseArray.contains(true))
			{
				for (i in 0...releaseArray.length)
				{
					if(releaseArray[i] || strumsBlocked[i] == true)
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}
	}

	public function parseKeys(?suffix:String = ''):Array<Bool>
	{
		var ret:Array<Bool> = [];
		for (i in 0...controlArray.length)
		{
			ret[i] = Reflect.getProperty(controls, controlArray[i] + suffix);
		}
		return ret;
	}

	function noteMiss(daNote:Note = null, daNoteAlt:PreloadedChartNote = null):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		if (daNote != null)
		{
			if (combo > 0)
				combo = 0;
			else combo -= 1 * (opponentChart ? polyphonyOppo : polyphonyBF);
			if (health > 0 && !usingBotEnergy)
			{
				health -= daNote.missHealth * healthLoss;
			}

			if(instakillOnMiss || sickOnly)
			{
				vocals.volume = opponentVocals.volume = 0;
				doDeathCheck(true);
			}

			songMisses += 1 * (opponentChart ? polyphonyOppo : polyphonyBF);
			if (SONG.needsVoices && !ffmpegMode)
				if (opponentChart && opponentVocals != null && opponentVocals.volume != 0) opponentVocals.volume = 0;
				else if (!opponentChart && vocals.volume != 0 || vocals.volume != 0) vocals.volume = 0;
			if (!practiceMode)
				songScore -= 10 * Std.int((opponentChart ? polyphonyOppo : polyphonyBF));

			totalPlayed++;
			if (missRecalcsPerFrame <= 3) RecalculateRating(true);

			final char:Character = !daNote.gfNote ? !opponentChart ? boyfriend : dad : gf;

			if(char != null && !daNote.noMissAnimation && char.hasMissAnimations && ClientPrefs.charsAndBG)
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + 'miss' + daNote.animSuffix;
				char.playAnim(animToPlay, true);
			}
			if (scoreTxtUpdateFrame <= 4 && scoreTxt != null) updateScore();
			if (ClientPrefs.ratingCounter && judgeCountUpdateFrame <= 4) updateRatingCounter();

			daNote.tooLate = true;

			if (usingBotEnergy)
			{
				if (missResetTimer <= 0.1)
				{
					if (!notesBeingMissed) notesBeingMissed = true;
					missResetTimer += 0.01 / playbackRate;
				}
			}

			if (daNote.noteHoldSplash != null) {
				daNote.noteHoldSplash.kill();
			}

			stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
			callOnLuas('noteMiss', [(daNote.isSustainNote ? sustainNotes : notes).members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
			if (ClientPrefs.missRating && ClientPrefs.ratingPopups) popUpScore(daNote, true);
		}
		if (daNoteAlt != null)
		{
			if (combo > 0)
				combo = 0;
			else combo -= 1 * (opponentChart ? polyphonyOppo : polyphonyBF);
			if (health > 0)
			{
				health -= daNoteAlt.missHealth * healthLoss;
			}

			if(instakillOnMiss)
			{
				(opponentChart ? opponentVocals : vocals).volume = 0;
				doDeathCheck(true);
			}

			songMisses += 1 * (opponentChart ? polyphonyOppo : polyphonyBF);
			(opponentChart ? opponentVocals : vocals).volume = 0;
			if (!practiceMode)
				songScore -= 10 * Std.int((opponentChart ? polyphonyOppo : polyphonyBF));

			totalPlayed++;
			if (missRecalcsPerFrame <= 3) RecalculateRating(true);

			final char:Character = !daNoteAlt.gfNote ? !opponentChart ? boyfriend : dad : gf;

			if(char != null && !daNoteAlt.noMissAnimation && char.hasMissAnimations && ClientPrefs.charsAndBG)
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(daNoteAlt.noteData))] + 'miss' + daNoteAlt.animSuffix;
				char.playAnim(animToPlay, true);
			}
			if (scoreTxtUpdateFrame <= 4 && scoreTxt != null) updateScore();
			if (ClientPrefs.ratingCounter && judgeCountUpdateFrame <= 4) updateRatingCounter();

			callOnLuas('noteMiss', [null, daNoteAlt.noteData, daNoteAlt.noteType, daNoteAlt.isSustainNote]);
		}
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.ghostTapping) return; //fuck it

		if (!boyfriend.stunned)
		{
			health -= 0.05 * healthLoss;
			if(instakillOnMiss)
			{
				(opponentChart ? opponentVocals : vocals).volume = 0;
				doDeathCheck(true);
			}

			if (combo > 5 && gf != null && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;

			if(!practiceMode) songScore -= 10;
			if(!endingSong) {
				songMisses++;
			}
			totalPlayed++;
			RecalculateRating(true);

			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));

			var char:Character = boyfriend;
			if (opponentChart) char = dad;
			if(char.hasMissAnimations) {
				char.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
			}
			(opponentChart ? opponentVocals : vocals).volume = 0;
		}
		if (scoreTxtUpdateFrame <= 4 && scoreTxt != null) updateScore();
		if (ClientPrefs.ratingCounter && judgeCountUpdateFrame <= 4) updateRatingCounter();

		stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		callOnLuas('noteMissPress', [direction]);
	}

	//This function handles note spawning.
	var NOTE_SPAWN_TIME:Float = 0;
	var targetNote:PreloadedChartNote = null;
	var spawnedNote:Note;
	function spawnNotes()
	{
		if (unspawnNotes[0] != null)
		{
			notesAddedCount = 0;
			NOTE_SPAWN_TIME = (ClientPrefs.dynamicSpawnTime ? (1600 / songSpeed) : 1600 * ClientPrefs.noteSpawnTime);
			targetNote = unspawnNotes[notesAddedCount];

			if (!targetNote.wasHit)
			{
				while (targetNote != null && targetNote.strumTime <= Conductor.songPosition - ClientPrefs.noteOffset) {
					targetNote.wasHit = true;
					targetNote.mustPress ? goodNoteHit(null, targetNote) : opponentNoteHit(null, targetNote);
					notesAddedCount++;
					if (unspawnNotes[notesAddedCount] != null) targetNote = unspawnNotes[notesAddedCount];
					else break;
					skippedCount++;
					if (skippedCount > maxSkipped) maxSkipped = skippedCount;
				}
			}
			if (ClientPrefs.showNotes || !ClientPrefs.showNotes && !cpuControlled)
			{
				while (targetNote.strumTime - Conductor.songPosition < (NOTE_SPAWN_TIME / targetNote.multSpeed)) {
					spawnedNote = new Note();
					(targetNote.isSustainNote ? sustainNotes : notes).add(spawnedNote);
					spawnedNote.setupNoteData(targetNote);

					if (!ClientPrefs.noSpawnFunc) callOnLuas('onSpawnNote', [(!spawnedNote.isSustainNote ? notes.members.indexOf(spawnedNote) : sustainNotes.members.indexOf(spawnedNote)), targetNote.noteData, targetNote.noteType, targetNote.isSustainNote]);
					notesAddedCount++;
					if (unspawnNotes[notesAddedCount] != null) targetNote = unspawnNotes[notesAddedCount];
					else break;
				}
			}
			if (notesAddedCount > 0)
				unspawnNotes.splice(0, notesAddedCount);
		}
	}

	function updateNote(daNote:Note):Void
	{
		if (daNote != null && daNote.exists)
		{
			//first, process whether or not the note should be hit. this prevents pointless strum following
			if (!daNote.mustPress && !daNote.hitByOpponent && !daNote.ignoreNote && daNote.strumTime <= Conductor.songPosition)
				opponentNoteHit(daNote);

			if(daNote.mustPress) {
				if((cpuControlled || usingBotEnergy && strumsHeld[daNote.noteData]) && !daNote.wasGoodHit && daNote.strumTime <= Conductor.songPosition && !daNote.ignoreNote)
					goodNoteHit(daNote);
			}
			if (!daNote.exists) return;

			amountOfRenderedNotes += daNote.noteDensity;
			if (maxRenderedNotes < amountOfRenderedNotes) maxRenderedNotes = amountOfRenderedNotes;
			daNote.followStrum((daNote.mustPress ? playerStrums : opponentStrums).members[daNote.noteData], songSpeed);
			if (daNote.isSustainNote)
			{
				final strum = (daNote.mustPress ? playerStrums : opponentStrums).members[daNote.noteData];
				if (strum != null && strum.sustainReduce) daNote.clipToStrumNote(strum);
			}

			if (Conductor.songPosition > noteKillOffset + daNote.strumTime)
			{
				if (daNote.mustPress && (!(cpuControlled || usingBotEnergy && strumsHeld[daNote.noteData]) || cpuControlled) && !daNote.ignoreNote && !endingSong && !daNote.wasGoodHit) {
					noteMiss(daNote);
					if (ClientPrefs.missSoundShit)
					{
						FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
					}
				}
				invalidateNote(daNote);
			}
		}
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
		if (note != null)
		{
			if (opponentChart || bothSides && note.doOppStuff) {
				if (songName != 'tutorial' && !camZooming)
					camZooming = true;
			}
			if(!ffmpegMode && (note.wasGoodHit || cpuControlled && note.ignoreNote)) return;

			if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled && !note.isSustainNote)
			{
				hitsound.play(true);
				hitsound.pitch = playbackRate;
				if (FileSystem.exists('assets/shared/images/' + hitsoundImageToLoad + '.png') || FileSystem.exists(Paths.modFolders('images/' + hitsoundImageToLoad + '.png')) && hitImagesFrame < 4)
				{
					hitImagesFrame++;
					hitsoundImage = new FlxSprite().loadGraphic(Paths.image(hitsoundImageToLoad));
					hitsoundImage.antialiasing = ClientPrefs.globalAntialiasing;
					hitsoundImage.scrollFactor.set();
					hitsoundImage.setGraphicSize(Std.int(hitsoundImage.width / FlxG.camera.zoom));
					hitsoundImage.updateHitbox();
					hitsoundImage.screenCenter();
					hitsoundImage.alpha = 1;
					hitsoundImage.cameras = [camGame];
					add(hitsoundImage);
					FlxTween.tween(hitsoundImage, {alpha: 0}, 1 / (SONG.bpm/100) / playbackRate, {
						onComplete: function(tween:FlxTween)
						{
							hitsoundImage.destroy();
						}
					});
				}
			}

			if(!note.hitCausesMiss) {
				if (!note.isSustainNote)
				{
					if (combo < 0) combo = 0;
					if ((opponentChart ? polyphonyOppo : polyphonyBF) > 1 && !note.isSustainNote) totalNotes += polyphonyBF - 1;
					missCombo = 0;
					combo += 1 * (opponentChart ? polyphonyOppo : polyphonyBF);
					totalNotesPlayed += 1 * (opponentChart ? polyphonyOppo : polyphonyBF);
					if (ClientPrefs.showNPS) { //i dont think we should be pushing to 2 arrays at the same time but oh well
						notesHitArray.push(1 * (opponentChart ? polyphonyOppo : polyphonyBF));
						notesHitDateArray.push(Conductor.songPosition);
					}
					if (!ClientPrefs.lessBotLag) popUpScore(note);
					else judgeNote(note);
					maxCombo = Math.max(maxCombo, combo);
				}

				if (!usingBotEnergy) health += note.hitHealth * healthGain * (opponentChart ? polyphonyOppo : polyphonyBF);

				if (bothSides) oppTrigger = bothSides && note.doOppStuff;
				else if (opponentChart && !oppTrigger) oppTrigger = true;
				doGf = note.gfNote;

				if(!note.noAnimation && ClientPrefs.charsAndBG) {
					animToPlay = singAnimations[Std.int(Math.abs(note.noteData))];

					playerChar = (doGf ? gf : (!oppTrigger ? boyfriend : dad));
					animCheck = (playerChar != gf ? 'hey' : 'cheer');
					if (note.animSuffix.length > 0 && playerChar.hasAnimation(animToPlay + note.animSuffix))
						animToPlay = singAnimations[Std.int(Math.abs(note.noteData))] + note.animSuffix;

					if (ClientPrefs.cameraPanning) camPanRoutine(animToPlay, (!oppTrigger ? 'bf' : 'oppt'));
					if (playerChar != null)
					{
						canPlay = (!note.isSustainNote || ClientPrefs.oldSusStyle && note.isSustainNote);
						if(note.isSustainNote)
						{
							holdAnim = animToPlay + '-hold';
							if(playerChar.animation.exists(holdAnim)) animToPlay = holdAnim;
							if(playerChar.getAnimationName() == holdAnim || playerChar.getAnimationName() == holdAnim + '-loop')
								canPlay = false;
						}

						if(canPlay) playerChar.playAnim(animToPlay, true);
						playerChar.holdTimer = 0;

						if(note.noteType == 'Hey!')
						{
							if(playerChar.hasAnimation(animCheck))
							{
								playerChar.playAnim(animCheck, true);
								playerChar.specialAnim = true;
								playerChar.heyTimer = 0.6;
							}
						}
					}
				}

				if((cpuControlled || usingBotEnergy && strumsHeld[note.noteData]) && ClientPrefs.botLightStrum && !strumsHit[(note.noteData % 4) + 4]) {
					strumsHit[(note.noteData % 4) + 4] = true;

					if(playerStrums.members[note.noteData] != null) {
						if (ClientPrefs.noteColorStyle != 'Normal' && ClientPrefs.showNotes && ClientPrefs.enableColorShader)
							playerStrums.members[note.noteData].playAnim('confirm', true, note.rgbShader.r, note.rgbShader.g, note.rgbShader.b);
						else
							playerStrums.members[note.noteData].playAnim('confirm', true);

						playerStrums.members[note.noteData].resetAnim = calculateResetTime();
					}
				} else if (ClientPrefs.playerLightStrum && !cpuControlled) {
					final spr = playerStrums.members[note.noteData];
					if(spr != null)
					{
						if (ClientPrefs.noteColorStyle != 'Normal' && ClientPrefs.showNotes && ClientPrefs.enableColorShader)
							spr.playAnim('confirm', true, note.rgbShader.r, note.rgbShader.g, note.rgbShader.b);
						else
							spr.playAnim('confirm', true);
					}
				}
			}
			else
			{
				if(!note.noMissAnimation)
				{
					playerChar = boyfriend;
					switch(note.noteType)
					{
						case 'Hurt Note':
							if(playerChar.hasAnimation('hurt'))
							{
								playerChar.playAnim('hurt', true);
								playerChar.specialAnim = true;
							}
					}
				}

				noteMiss(note);
				if(!note.noteSplashData.disabled && !note.isSustainNote) spawnNoteSplashOnNote(false, note);
			}

			if (playerChar != null && playerChar.shakeScreen)
			{
				camGame.shake(playerChar.shakeIntensity, playerChar.shakeDuration / playbackRate);
				camHUD.shake(playerChar.shakeIntensity / 2, playerChar.shakeDuration / playbackRate);
			}
			note.wasGoodHit = true;
			if (!ClientPrefs.lessBotLag && ClientPrefs.noteSplashes && note.isSustainNote && splashesPerFrame[3] <= 4) spawnHoldSplashOnNote(note);
			if (SONG.needsVoices && !ffmpegMode)
				if (opponentChart && opponentVocals != null && opponentVocals.volume != 1) opponentVocals.volume = 1;
				else if (!opponentChart && vocals.volume != 1 || vocals.volume != 1) vocals.volume = 1;

			if (!notesBeingHit && usingBotEnergy)
			{
				notesBeingHit = true;
				hitResetTimer = 0.3 / playbackRate;
			}

			if (!ClientPrefs.noHitFuncs)
			{
				callOnLuas((oppTrigger ? 'opponentNoteHit' : 'goodNoteHit'), [(note.isSustainNote ? sustainNotes : notes).members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
				stagesFunc(function(stage:BaseStage) (oppTrigger ? stage.opponentNoteHit(note) : stage.goodNoteHit(note)));
			}

			if (!note.isSustainNote) invalidateNote(note);

			if (ClientPrefs.ratingCounter && judgeCountUpdateFrame <= 4) updateRatingCounter();
			if (scoreTxtUpdateFrame <= 4) updateScore();
			if (ClientPrefs.iconBopWhen == 'Every Note Hit' && (iconBopsThisFrame <= 2 || ClientPrefs.noBopLimit) && !note.isSustainNote && iconP1.visible) bopIcons(!oppTrigger);
			return;
		}
		if (noteAlt != null)
		{
			oppTrigger = opponentChart || bothSides && noteAlt.oppNote;
			if(noteAlt.noteType == 'Hey!')
			{
				playerChar = !noteAlt.gfNote ? oppTrigger ? dad : boyfriend : gf;
				if (playerChar.hasAnimation('hey')) {
					playerChar.playAnim('hey', true);
					playerChar.specialAnim = true;
					playerChar.heyTimer = 0.6;
				}
			}
			if(!noteAlt.noAnimation && ClientPrefs.charsAndBG) {
				playerChar = !noteAlt.gfNote ? oppTrigger ? dad : boyfriend : gf;
				if (playerChar != null)
				{
					playerChar.playAnim(singAnimations[(noteAlt.noteData)] + noteAlt.animSuffix, true);
					playerChar.holdTimer = 0;
				}
			}
			if(cpuControlled && !ClientPrefs.showNotes) {
				if (ClientPrefs.botLightStrum && !strumsHit[(noteAlt.noteData % 4) + 4])
				{
					strumsHit[(noteAlt.noteData % 4) + 4] = true;
					playerStrums.members[noteAlt.noteData].playAnim('confirm', true);
					playerStrums.members[noteAlt.noteData].resetAnim = calculateResetTime();
				}
			}
			if (!noteAlt.isSustainNote && cpuControlled)
			{
				combo += 1 * (opponentChart ? polyphonyOppo : polyphonyBF);
				songScore += (ClientPrefs.noMarvJudge ? 350 : 500) * (opponentChart ? polyphonyOppo : polyphonyBF);
				totalNotesPlayed += 1 * (opponentChart ? polyphonyOppo : polyphonyBF);
				if (ClientPrefs.showNPS) { //i dont think we should be pushing to 2 arrays at the same time but oh well
					notesHitArray.push(1 * (opponentChart ? polyphonyOppo : polyphonyBF));
					notesHitDateArray.push(Conductor.songPosition);
				}
				if ((opponentChart ? polyphonyOppo : polyphonyBF) > 1) totalNotes += (opponentChart ? polyphonyOppo : polyphonyBF) - 1;
			}
			if (!ClientPrefs.noSkipFuncs) callOnLuas((oppTrigger ? 'opponentNoteSkip' : 'goodNoteSkip'), [null, Math.abs(noteAlt.noteData), noteAlt.noteType, noteAlt.isSustainNote]);
			health += noteAlt.hitHealth * healthGain * (opponentChart ? polyphonyOppo : polyphonyBF);
			if (!ffmpegMode) (opponentChart ? opponentVocals : vocals).volume = 1;
		}
		return;
	}

	var oppChar = null;
	var gfTrigger:Bool = false;
	function opponentNoteHit(daNote:Note, noteAlt:PreloadedChartNote = null):Void
	{
		if (daNote != null)
		{
			if (!opponentChart && songName != 'tutorial' && !camZooming)
				camZooming = true;

			if(daNote.noteType == 'Hey!')
			{
				oppChar = !daNote.gfNote ? !opponentChart ? dad : boyfriend : gf;
				if (oppChar.hasAnimation('hey')) {
					oppChar.playAnim('hey', true);
					oppChar.specialAnim = true;
					oppChar.heyTimer = 0.6;
				}
			} else if(!daNote.noAnimation && ClientPrefs.charsAndBG) {
				oppChar = !daNote.gfNote ? !opponentChart ? dad : boyfriend : gf;
				animToPlay = singAnimations[Std.int(Math.abs(daNote.noteData))];

				if (daNote.animSuffix.length > 0 && oppChar.hasAnimation(animToPlay + daNote.animSuffix))
					animToPlay = singAnimations[Std.int(Math.abs(daNote.noteData))] + daNote.animSuffix;

				if (ClientPrefs.cameraPanning) camPanRoutine(animToPlay, (!opponentChart ? 'dad' : 'bf'));

				if (oppChar != null)
				{
					canPlay = (!daNote.isSustainNote || ClientPrefs.oldSusStyle && daNote.isSustainNote);
					if(daNote.isSustainNote)
					{
						holdAnim = animToPlay + '-hold';
						if(oppChar.animation.exists(holdAnim)) animToPlay = holdAnim;
						if(oppChar.getAnimationName() == holdAnim || oppChar.getAnimationName() == holdAnim + '-loop')
							canPlay = false;
					}

					if(canPlay) oppChar.playAnim(animToPlay, true);
					oppChar.holdTimer = 0;
				}
			}

			if (!daNote.isSustainNote)
			{
				if (ClientPrefs.showNPS) { //i dont think we should be pushing to 2 arrays at the same time but oh well
					oppNotesHitArray.push(1 * polyphonyOppo);
					oppNotesHitDateArray.push(Conductor.songPosition);
				}
				enemyHits += 1 * polyphonyOppo;
				invalidateNote(daNote);
			}

			if(ClientPrefs.oppNoteSplashes && !daNote.isSustainNote && splashesPerFrame[0] <= 4)
				spawnNoteSplashOnNote(true, daNote);

			if (SONG.needsVoices && !ffmpegMode)
				if (!opponentChart && opponentVocals != null && opponentVocals.volume != 1) opponentVocals.volume = 1;
				else if (opponentChart && vocals.volume != 1 || vocals.volume != 1) vocals.volume = 1;

			if (polyphonyOppo > 1 && !daNote.isSustainNote) opponentNoteTotal += polyphonyOppo - 1;

			if (ClientPrefs.opponentLightStrum && !strumsHit[daNote.noteData % 4])
			{
				strumsHit[daNote.noteData % 4] = true;

				if (ClientPrefs.noteColorStyle != 'Normal' && ClientPrefs.showNotes && ClientPrefs.enableColorShader)
					opponentStrums.members[daNote.noteData].playAnim('confirm', true, daNote.rgbShader.r, daNote.rgbShader.g, daNote.rgbShader.b);
				else
					opponentStrums.members[daNote.noteData].playAnim('confirm', true);

				opponentStrums.members[daNote.noteData].resetAnim = calculateResetTime();
			}
			daNote.hitByOpponent = true;

			if (ClientPrefs.oppNoteSplashes && daNote.isSustainNote && splashesPerFrame[2] <= 4) spawnHoldSplashOnNote(daNote, true);

			if (!ClientPrefs.noHitFuncs)
			{
				callOnLuas((!opponentChart ? 'opponentNoteHit' : 'goodNoteHit'), [(daNote.isSustainNote ? sustainNotes : notes).members.indexOf(daNote), Math.abs(daNote.noteData), daNote.noteType, daNote.isSustainNote]);
				stagesFunc(function(stage:BaseStage) (!opponentChart ? stage.opponentNoteHit(daNote) : stage.goodNoteHit(daNote)));
			}

			if (shouldDrainHealth && health > (healthDrainFloor * polyphonyOppo) && !practiceMode || opponentDrain && practiceMode)
				health -= (opponentDrain ? daNote.hitHealth : healthDrainAmount) * hpDrainLevel * polyphonyOppo;

			if (oppChar != null && oppChar.shakeScreen)
			{
				camGame.shake(oppChar.shakeIntensity, oppChar.shakeDuration / playbackRate);
				camHUD.shake(oppChar.shakeIntensity / 2, oppChar.shakeDuration / playbackRate);
			}
			if (ClientPrefs.ratingCounter && judgeCountUpdateFrame <= 4) updateRatingCounter();
			if (scoreTxtUpdateFrame <= 4) updateScore();
			if (ClientPrefs.iconBopWhen == 'Every Note Hit' && (iconBopsThisFrame <= 2 || ClientPrefs.noBopLimit) && !daNote.isSustainNote && iconP2.visible) bopIcons(opponentChart);
			return;
		}
		if (noteAlt != null)
		{
			if(noteAlt.noteType == 'Hey!')
			{
				oppChar = !noteAlt.gfNote ? !opponentChart ? dad : boyfriend : gf;
				if (oppChar.animOffsets.exists('hey')) {
					oppChar.playAnim('hey', true);
					oppChar.specialAnim = true;
					oppChar.heyTimer = 0.6;
				}
			}
			if(!noteAlt.noAnimation && ClientPrefs.charsAndBG) {
				oppChar = !noteAlt.gfNote ? !opponentChart ? dad : boyfriend : gf;
				animToPlay = singAnimations[Std.int(Math.abs(noteAlt.noteData))] + noteAlt.animSuffix;
				if (oppChar != null)
				{
					oppChar.playAnim(animToPlay, true);
					oppChar.holdTimer = 0;
				}
			}
			if (ClientPrefs.opponentLightStrum && !strumsHit[noteAlt.noteData % 4] && !ClientPrefs.showNotes)
			{
				strumsHit[noteAlt.noteData % 4] = true;
				opponentStrums.members[noteAlt.noteData].playAnim('confirm', true);
				opponentStrums.members[noteAlt.noteData].resetAnim = calculateResetTime();
			}
			if (!noteAlt.isSustainNote)
			{
				if (ClientPrefs.showNPS) { //i dont think we should be pushing to 2 arrays at the same time but oh well
					oppNotesHitArray.push(1 * polyphonyOppo);
					oppNotesHitDateArray.push(Conductor.songPosition);
				}
				enemyHits += 1 * polyphonyOppo;

				if (ClientPrefs.ratingCounter && judgeCountUpdateFrame <= 4) updateRatingCounter();
				if (scoreTxtUpdateFrame <= 4) updateScore();

				if (shouldDrainHealth && health > healthDrainFloor && !practiceMode || opponentDrain && practiceMode)
					health -= (opponentDrain ? noteAlt.hitHealth : healthDrainAmount) * hpDrainLevel * polyphonyOppo;
			}
			if ((!noteAlt.gfNote ? !opponentChart ? dad : boyfriend : gf) != null && (!noteAlt.gfNote ? !opponentChart ? dad : boyfriend : gf).shakeScreen)
			{
				oppChar = !noteAlt.gfNote ? !opponentChart ? dad : boyfriend : gf;
				camGame.shake(oppChar.shakeIntensity, oppChar.shakeDuration / playbackRate);
				camHUD.shake(oppChar.shakeIntensity / 2, oppChar.shakeDuration / playbackRate);
			}
			if (!ClientPrefs.noSkipFuncs) callOnLuas((!opponentChart ? 'opponentNoteSkip' : 'goodNoteSkip'), [null, Math.abs(noteAlt.noteData), noteAlt.noteType, noteAlt.isSustainNote]);
			if (SONG.needsVoices && !ffmpegMode)
				if (!opponentChart && opponentVocals != null && opponentVocals.volume != 1) opponentVocals.volume = 1;
				else if (opponentChart && vocals.volume != 1 || vocals.volume != 1) vocals.volume = 1;
		}
		return;
	}

	public function invalidateNote(note:Note):Void {
		if (!killNotes.contains(note))
			killNotes.push(note);
	}

	public function destroyNotes():Void
	{
		final iterator:Iterator<Note> = killNotes.iterator();

		while (iterator.hasNext())
		{
			final note:Note = iterator.next();
			note.active = note.visible = false;
			if (!ClientPrefs.lowQuality || !cpuControlled)
				note.kill();
			notes.remove(note, true);
			note.destroy();
		}
		killNotes = [];
	}

	public function spawnHoldSplashOnNote(note:Note, ?isDad:Bool = false) {
		if (!ClientPrefs.noteSplashes || note == null)
			return;

		splashesPerFrame[(isDad ? 2 : 3)] += 1;

		if (note != null) {
			var strum:StrumNote = (isDad ? playerStrums : opponentStrums).members[note.noteData];
			final susLength:Float = (!note.isSustainNote ? note.sustainLength : note.parentSL);
			final tailLength:Int = Math.floor(susLength / Conductor.stepCrochet);

			if(strum != null && tailLength != 0)
				spawnHoldSplash(note);
		}
	}

	public function spawnHoldSplash(note:Note) {
		var end:Note = note;
		var splash:SustainSplash = grpHoldSplashes.recycle(SustainSplash);
		splash.setupSusSplash((note.mustPress ? playerStrums : opponentStrums).members[note.noteData], note, playbackRate);
		grpHoldSplashes.add(end.noteHoldSplash = splash);
	}

	public function spawnNoteSplashOnNote(isDad:Bool, note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			splashesPerFrame[(isDad ? 0 : 1)] += 1;
			final strum:StrumNote = !isDad ? playerStrums.members[note.noteData] : opponentStrums.members[note.noteData];
			if(strum != null)
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		grpNoteSplashes.add(splash);
	}

	override function destroy() {
		for (lua in luaArray) {
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = [];

		if (camFollow != null) camFollow.put();

		#if hscript
		if(FunkinLua.hscript != null) FunkinLua.hscript = null;
		#end

		stagesFunc(function(stage:BaseStage) stage.destroy());

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		FlxG.animationTimeScale = 1;
		FlxG.sound.music.pitch = 1;
		cpp.vm.Gc.enable(true);
		KillNotes();
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

		if (tankmanAscend)
		{
			if (curStep >= 896 && curStep <= 1152) moveCameraSection();
			switch (curStep)
			{
				case 896:
					{
						if (!opponentChart) {
						opponentStrums.forEachAlive(function(daNote:FlxSprite)
						{
							FlxTween.tween(daNote, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						});
						}
						if (EngineWatermark != null) FlxTween.tween(EngineWatermark, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(timeBar, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(judgementCounter, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(scoreTxt, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(healthBar, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(healthBarBG, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(iconP1, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(iconP2, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(timeTxt, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						dad.velocity.y = -35;
					}
				case 906:
					{
						if (!opponentChart) {
						playerStrums.forEachAlive(function(daNote:FlxSprite)
						{
							FlxTween.tween(daNote, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						});
						} else {
						opponentStrums.forEachAlive(function(daNote:FlxSprite)
						{
							FlxTween.tween(daNote, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						});
						}
					}
				case 1020:
					{
						if (!opponentChart) {
						playerStrums.forEachAlive(function(daNote:FlxSprite)
						{
							FlxTween.tween(daNote, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						});
						}
					}
				case 1024:
						if (opponentChart) {
						playerStrums.forEachAlive(function(daNote:FlxSprite)
						{
							FlxTween.tween(daNote, {alpha: 0}, 0.5, {ease: FlxEase.expoOut,});
						});
						}
					dad.velocity.y = 0;
					boyfriend.velocity.y = -33.5;
				case 1148:
					{
						if (opponentChart) {
						playerStrums.forEachAlive(function(daNote:FlxSprite)
						{
							FlxTween.tween(daNote, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						});
						}
					}
				case 1151:
					cameraSpeed = 100;
				case 1152:
					{
						FlxG.camera.flash(FlxColor.WHITE, 1);
						opponentStrums.forEachAlive(function(daNote:FlxSprite)
						{
							FlxTween.tween(daNote, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						});
						if (EngineWatermark != null) FlxTween.tween(EngineWatermark, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(judgementCounter, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(healthBar, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(healthBarBG, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(scoreTxt, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(iconP1, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(iconP2, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.expoOut,});
						dad.x = 100;
						dad.y = 280;
						boyfriend.x = 810;
						boyfriend.y = 450;
						dad.velocity.y = 0;
						boyfriend.velocity.y = 0;
					}
				case 1153:
					cameraSpeed = 1;
			}
		}

		setOnLuas('curStep', curStep);
		callOnLuas('onStepHit');
	}

	var lastBeatHit:Int = -1;
	var twisted = false;

	override function beatHit()
	{
		super.beatHit();

		if (lastBeatHit == curBeat) return;

		if(ClientPrefs.timeBounce)
		{
			if(timeTxtTween != null) {
				timeTxtTween.cancel();
			}
			timeTxt.scale.x = 1.075;
			timeTxt.scale.y = 1.075;
			timeTxtTween = FlxTween.tween(timeTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween) {
					timeTxtTween = null;
				}
			});
		}

		if (curBeat % 32 == 0 && randomSpeedThing)
		{
			var randomShit = FlxMath.roundDecimal(FlxG.random.float(minSpeed, maxSpeed), 2);
			lerpSongSpeed(randomShit, 1);
		}
		if (camZooming && !endingSong && !startingSong && FlxG.camera.zoom < 1.35 && usingBopIntervalEvent && ClientPrefs.camZooms && (curBeat % camBopInterval == 0))
		{
			FlxG.camera.zoom += 0.015 * camBopIntensity;
			camHUD.zoom += 0.03 * camBopIntensity;
		} /// WOOO YOU CAN NOW MAKE IT AWESOME

		if (camTwist && curBeat % gfSpeed == 0)
		{
			doTwist();
		}

		if (ClientPrefs.iconBopWhen == 'Every Beat' && (iconP1.visible || iconP2.visible))
			bopIcons();

		if (ClientPrefs.charsAndBG) characterBopper(curBeat);
		lastBeatHit = curBeat;

		setOnLuas('curBeat', curBeat); //DAWGG?????
		callOnLuas('onBeatHit');
	}
	public function characterBopper(beat:Int):Void
	{
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && !gf.getAnimationName().startsWith('sing') && !gf.stunned)
			gf.dance();
		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0 && !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
			boyfriend.dance();
		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
			dad.dance();
	}

	public function playerDance():Void
	{
		var char = (opponentChart ? dad : boyfriend);
		var anim:String = char.getAnimationName();
		if(char.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end) * char.singDuration * singDurMult && anim.startsWith('sing') && !anim.endsWith('miss'))
			char.dance();
	}

	public function doTwist()
	{
		twistShit = twistAmount * camTwistIntensity * (!twisted ? 1 : -1);
		twisted = !twisted;

		for (i in [camHUD, camGame])
		{
			FlxTween.cancelTweensOf(i);
			i.angle = twistShit;
			FlxTween.tween(i, {angle: 0}, 45 / Conductor.bpm * gfSpeed / playbackRate, {ease: FlxEase.circOut});
		}
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
			if (camZooming && !endingSong && !startingSong && FlxG.camera.zoom < 1.35 && !usingBopIntervalEvent && ClientPrefs.camZooms)
			{
				FlxG.camera.zoom += 0.015 * camBopIntensity;
				camHUD.zoom += 0.03 * camBopIntensity;
			}
		}

		setOnLuas('curSection', curSection);
		callOnLuas('onSectionHit');
	}

	public function bopIcons(?bopBF:Bool = false)
	{
		iconBopsThisFrame++;
		if (ClientPrefs.iconBopWhen == 'Every Beat')
		{
			if (ClientPrefs.iconBounceType == 'Dave and Bambi') {
				final funny:Float = Math.max(Math.min(healthBar.value,(maxHealth/0.95)),0.1);

				//health icon bounce but epic
				if (!opponentChart)
				{
					iconP1.setGraphicSize(Std.int(iconP1.width + (50 * (funny + 0.1))),Std.int(iconP1.height - (25 * funny)));
					iconP2.setGraphicSize(Std.int(iconP2.width + (50 * ((2 - funny) + 0.1))),Std.int(iconP2.height - (25 * ((2 - funny) + 0.1))));
				} else {
					iconP2.setGraphicSize(Std.int(iconP2.width + (50 * funny)),Std.int(iconP2.height - (25 * funny)));
					iconP1.setGraphicSize(Std.int(iconP1.width + (50 * ((2 - funny) + 0.1))),Std.int(iconP1.height - (25 * ((2 - funny) + 0.1))));
				}
			}
			if (ClientPrefs.iconBounceType == 'Old Psych') {
				iconP1.setGraphicSize(Std.int(iconP1.width + 30));
				iconP2.setGraphicSize(Std.int(iconP2.width + 30));
			}
			if (ClientPrefs.iconBounceType == 'Strident Crisis') {
				final funny:Float = (healthBar.percent * 0.01) + 0.01;

				//health icon bounce but epic
				iconP1.setGraphicSize(Std.int(iconP1.width + (50 * (2 + funny))),Std.int(iconP2.height - (25 * (2 + funny))));
				iconP2.setGraphicSize(Std.int(iconP2.width + (50 * (2 - funny))),Std.int(iconP2.height - (25 * (2 - funny))));

				iconP1.scale.set(1.1, 0.8);
				iconP2.scale.set(1.1, 0.8);

				FlxTween.angle(iconP1, -15, 0, Conductor.crochet / 1300 * gfSpeed, {ease: FlxEase.quadOut});
				FlxTween.angle(iconP2, 15, 0, Conductor.crochet / 1300 * gfSpeed, {ease: FlxEase.quadOut});

				FlxTween.tween(iconP1, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
				FlxTween.tween(iconP2, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
			}
			if (ClientPrefs.iconBounceType == 'Plank Engine') {
				iconP1.scale.x = 1.3;
				iconP1.scale.y = 0.75;
				iconP2.scale.x = 1.3;
				iconP2.scale.y = 0.75;
				FlxTween.cancelTweensOf(iconP1);
				FlxTween.cancelTweensOf(iconP2);
				FlxTween.tween(iconP1, {"scale.x": 1, "scale.y": 1}, Conductor.crochet / 1000 / playbackRate, {ease: FlxEase.backOut});
				FlxTween.tween(iconP2, {"scale.x": 1, "scale.y": 1}, Conductor.crochet / 1000 / playbackRate, {ease: FlxEase.backOut});
				if (curBeat % 4 == 0) {
					iconP1.offset.x = 10;
					iconP2.offset.x = -10;
					iconP1.angle = -15;
					iconP2.angle = 15;
					FlxTween.tween(iconP1, {"offset.x": 0, angle: 0}, Conductor.crochet / 1000 / playbackRate, {ease: FlxEase.expoOut});
					FlxTween.tween(iconP2, {"offset.x": 0, angle: 0}, Conductor.crochet / 1000 / playbackRate, {ease: FlxEase.expoOut});
				}
			}
			if (ClientPrefs.iconBounceType == 'New Psych') {
				iconP1.scale.set(1.2, 1.2);
				iconP2.scale.set(1.2, 1.2);
			}

			if (curBeat % gfSpeed == 0 && ClientPrefs.iconBounceType == 'Golden Apple') {
				curBeat % (gfSpeed * 2) == 0 * playbackRate ? {
				iconP1.scale.set(1.1, 0.8);
				iconP2.scale.set(1.1, 1.3);

				FlxTween.angle(iconP1, -15, 0, Conductor.crochet / 1300 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
				FlxTween.angle(iconP2, 15, 0, Conductor.crochet / 1300 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
				} : {
					iconP1.scale.set(1.1, 1.3);
					iconP2.scale.set(1.1, 0.8);

					FlxTween.angle(iconP2, -15, 0, Conductor.crochet / 1300 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
					FlxTween.angle(iconP1, 15, 0, Conductor.crochet / 1300 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
				}

				FlxTween.tween(iconP1, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
				FlxTween.tween(iconP2, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
			}
			if (ClientPrefs.iconBounceType == 'VS Steve') {
				if (curBeat % gfSpeed == 0)
				{
					curBeat % (gfSpeed * 2) == 0 ?
					{
						iconP1.scale.set(1.1, 0.8);
						iconP2.scale.set(1.1, 1.3);
					} : {
						iconP1.scale.set(1.1, 1.3);
						iconP2.scale.set(1.1, 0.8);
						FlxTween.angle(iconP1, -15, 0, Conductor.crochet / 1300 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
						FlxTween.angle(iconP2, 15, 0, Conductor.crochet / 1300 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});

					}

					FlxTween.tween(iconP1, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
					FlxTween.tween(iconP2, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
				}
			}
		}
		else if (ClientPrefs.iconBopWhen == 'Every Note Hit')
		{
			iconBopsTotal++;
			if (ClientPrefs.iconBounceType == 'Dave and Bambi') {
				final funny:Float = Math.max(Math.min(healthBar.value,(maxHealth/0.95)),0.1);

				//health icon bounce but epic
				if (!opponentChart)
				{
					if (bopBF) iconP1.setGraphicSize(Std.int(iconP1.width + (50 * (funny + 0.1))),Std.int(iconP1.height - (25 * funny)));
					iconP2.setGraphicSize(Std.int(iconP2.width + (50 * ((2 - funny) + 0.1))),Std.int(iconP2.height - (25 * ((2 - funny) + 0.1))));
				} else {
					if (!bopBF) iconP2.setGraphicSize(Std.int(iconP2.width + (50 * funny)),Std.int(iconP2.height - (25 * funny)));
					else iconP1.setGraphicSize(Std.int(iconP1.width + (50 * ((2 - funny) + 0.1))),Std.int(iconP1.height - (25 * ((2 - funny) + 0.1))));
				}
			}
			if (ClientPrefs.iconBounceType == 'Old Psych') {
				if (bopBF) iconP1.setGraphicSize(Std.int(iconP1.width + 30), Std.int(iconP1.height + 30));
				else iconP2.setGraphicSize(Std.int(iconP2.width + 30), Std.int(iconP2.height + 30));
			}
			if (ClientPrefs.iconBounceType == 'Strident Crisis') {
				final funny:Float = (healthBar.percent * 0.01) + 0.01;

				iconP1.setGraphicSize(Std.int(iconP1.width + (50 * (2 + funny))),Std.int(iconP2.height - (25 * (2 + funny))));
				iconP2.setGraphicSize(Std.int(iconP2.width + (50 * (2 - funny))),Std.int(iconP2.height - (25 * (2 - funny))));

				FlxTween.cancelTweensOf(iconP1);
				FlxTween.cancelTweensOf(iconP2);

				FlxTween.angle(iconP1, -15, 0, Conductor.crochet / 1300 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
				FlxTween.angle(iconP2, 15, 0, Conductor.crochet / 1300 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});

				FlxTween.tween(iconP1, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
				FlxTween.tween(iconP2, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
			}
			if (ClientPrefs.iconBounceType == 'Plank Engine') {
				iconP1.scale.x = 1.3;
				iconP1.scale.y = 0.75;
				FlxTween.cancelTweensOf(iconP1);
				FlxTween.tween(iconP1, {"scale.x": 1, "scale.y": 1}, Conductor.crochet / 1000 / playbackRate, {ease: FlxEase.backOut});
				iconP2.scale.x = 1.3;
				iconP2.scale.y = 0.75;
				FlxTween.cancelTweensOf(iconP2);
				FlxTween.tween(iconP2, {"scale.x": 1, "scale.y": 1}, Conductor.crochet / 1000 / playbackRate, {ease: FlxEase.backOut});
				if (iconBopsTotal % 4 == 0) {
					iconP1.offset.x = 10;
					iconP1.angle = -15;
					FlxTween.tween(iconP1, {"offset.x": 0, angle: 0}, Conductor.crochet / 1000 / playbackRate, {ease: FlxEase.expoOut});
					iconP2.offset.x = -10;
					iconP2.angle = 15;
					FlxTween.tween(iconP2, {"offset.x": 0, angle: 0}, Conductor.crochet / 1000 / playbackRate, {ease: FlxEase.expoOut});
				}
			}
			if (ClientPrefs.iconBounceType == 'New Psych') {
				if (bopBF) iconP1.scale.set(1.2, 1.2);
				else iconP2.scale.set(1.2, 1.2);
			}
			if (ClientPrefs.iconBounceType == 'Golden Apple') {
				FlxTween.cancelTweensOf(iconP1);
				FlxTween.cancelTweensOf(iconP2);
				iconBopsTotal % 2 == 0 * playbackRate ? {
					iconP1.scale.set(1.1, 0.8);
					iconP2.scale.set(1.1, 1.3);

					FlxTween.angle(iconP1, -15, 0, Conductor.crochet / 1300 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
					FlxTween.angle(iconP2, 15, 0, Conductor.crochet / 1300 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
				} : {
					iconP1.scale.set(1.1, 1.3);
					iconP2.scale.set(1.1, 0.8);

					FlxTween.angle(iconP2, -15, 0, Conductor.crochet / 1300 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
					FlxTween.angle(iconP1, 15, 0, Conductor.crochet / 1300 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
				}

				FlxTween.tween(iconP1, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
				FlxTween.tween(iconP2, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 / playbackRate * gfSpeed, {ease: FlxEase.quadOut});
			}
			if (ClientPrefs.iconBounceType == 'VS Steve') {
				FlxTween.cancelTweensOf(iconP1);
				FlxTween.cancelTweensOf(iconP2);
				if (iconBopsTotal % 2 == 0)
					{
					iconBopsTotal % 2 == 0 ?
					{
						iconP1.scale.set(1.1, 0.8);
						iconP2.scale.set(1.1, 1.3);
					} : {
						iconP1.scale.set(1.1, 1.3);
						iconP2.scale.set(1.1, 0.8);
						FlxTween.angle(iconP1, -15, 0, Conductor.crochet / 1300 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
						FlxTween.angle(iconP2, 15, 0, Conductor.crochet / 1300 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});

					}

					FlxTween.tween(iconP1, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
					FlxTween.tween(iconP2, {'scale.x': 1, 'scale.y': 1}, Conductor.crochet / 1250 * gfSpeed / playbackRate, {ease: FlxEase.quadOut});
				}
			}
		}
		iconP1.updateHitbox();
		iconP2.updateHitbox();
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
			luaArray.push(new FunkinLua(luaToLoad));
			return true;
		}
		else
		{
			luaToLoad = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
				return true;
			}
		}
		#elseif sys
		var luaToLoad:String = Paths.getPreloadPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		{
			luaArray.push(new FunkinLua(luaToLoad));
			return true;
		}
		#end
		return false;
	}
	#end

	public function callOnLuas(event:String, args:Array<Dynamic> = null, ignoreStops = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal = FunkinLua.Function_Continue;
		#if LUA_ALLOWED
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [];

		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			final myValue = script.call(event, args);
			if(myValue == FunkinLua.Function_StopLua && !ignoreStops)
				break;

			if(myValue != null && myValue != FunkinLua.Function_Continue) {
				returnVal = myValue;
			}
		}
		#end
		return returnVal;
	}

	public function setOnLuas(variable:String, arg:Dynamic) {
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			luaArray[i].set(variable, arg);
		}
		#end
	}

	function StrumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = isDad ? opponentStrums.members[id] : playerStrums.members[id];

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public function updateRatingCounter() {
		judgeCountUpdateFrame++;
		if (!judgementCounter.visible) return;

		formattedSongMisses = formatNumber(songMisses);
		formattedCombo = formatNumber(combo);
		formattedMaxCombo = formatNumber(maxCombo);
		formattedNPS = formatNumber(nps);
		formattedMaxNPS = formatNumber(maxNPS);
		formattedOppNPS = formatNumber(oppNPS);
		formattedMaxOppNPS = formatNumber(maxOppNPS);
		formattedEnemyHits = formatNumber(enemyHits);

		final hittingStuff = (!ClientPrefs.lessBotLag && ClientPrefs.showComboInfo && !cpuControlled ? 'Combo: $formattedCombo/${formattedMaxCombo}\n' : '') + 'Hits: ' + formatNumber(totalNotesPlayed) + ' / ' + formatNumber(totalNotes) + ' (' + FlxMath.roundDecimal((totalNotesPlayed/totalNotes) * 100, 2) + '%)';
		final ratingCountString = (!cpuControlled || cpuControlled && !ClientPrefs.lessBotLag ? '\n' + (!ClientPrefs.noMarvJudge ? judgeCountStrings[0] + ': $perfects \n' : '') + judgeCountStrings[1] + ': $sicks \n' + judgeCountStrings[2] + ': $goods \n' + judgeCountStrings[3] + ': $bads \n' + judgeCountStrings[4] + ': $shits \n' + judgeCountStrings[5] + ': $formattedSongMisses ' : '');
		judgementCounter.text = hittingStuff + ratingCountString;
		judgementCounter.text += (ClientPrefs.showNPS ? '\nNPS: ' + formattedNPS + '/' + formattedMaxNPS : '');
		if (ClientPrefs.opponentRateCount) judgementCounter.text += '\n\nOpponent Hits: ' + formattedEnemyHits + ' / ' + formatNumber(opponentNoteTotal) + ' (' + FlxMath.roundDecimal((enemyHits / opponentNoteTotal) * 100, 2) + '%)'
		+ (ClientPrefs.showNPS ? '\nOpponent NPS: ' + formattedOppNPS + '/' + formattedMaxOppNPS : '');
	}

	public var ratingName:String = '?';
	public var ratingString:String;
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating(badHit:Bool = false) {
		setOnLuas('score', songScore);
		setOnLuas('misses', songMisses);
		setOnLuas('hits', songHits);
		setOnLuas('combo', combo);
		if (badHit) missRecalcsPerFrame += 1;

		var ret:Dynamic = callOnLuas('onRecalculateRating');
		if(ret != FunkinLua.Function_Stop)
		{
			if(totalPlayed < 1) //Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));

			if (Math.isNaN(ratingPercent))
				ratingString = '?';

				// Rating Name

				if (ratingStuff.length <= 0) // NOW it should fall back to this as a safe guard
				{
					ratingName = 'Error!';
					return;
				}
				if(ratingPercent >= 1)
				{
					ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				}
				else
				{
					for (i in 0...ratingStuff.length-1)
					{
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			/**
			 * - Rating FC and other stuff -
			 *
			 * > Now with better evaluation instead of using regular spaghetti code
			 *
			 * # @Equinoxtic was here, hi :3
			 */

			final fcConditions:Array<Bool> = [
				(totalPlayed == 0), // 'No Play'
				(perfects > 0), // 'PFC'
				(sicks > 0), // 'SFC'
				(goods > 0), // 'GFC'
				(bads > 0), // 'BFC'
				(shits > 0), // 'FC'
				(songMisses > 0 && songMisses < 10), // 'SDCB'
				(songMisses >= 10), // 'Clear'
				(songMisses >= 100), // 'TDCB'
				(songMisses >= 1000) // 'QDCB'
			];

			var cond:Int = fcConditions.length - 1;
			ratingFC = "";
			while (cond >= 0)
			{
				if (fcConditions[cond]) {
					ratingFC = fcStrings[cond];
					break;
				}
				cond--;
			}

			// basically same stuff, doesn't update every frame but it also means no memory leaks during botplay
			if (ClientPrefs.ratingCounter && judgementCounter != null)
				updateRatingCounter();
			if (scoreTxt != null)
				updateScore(badHit);
		}

		setOnLuas('rating', ratingPercent);
		setOnLuas('ratingName', ratingName);
		setOnLuas('ratingFC', ratingFC);
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		if(chartingMode || trollingMode) return;

		var usedPractice:Bool = (practiceMode || cpuControlled);
		if(cpuControlled) return;

		for (name in achievesToCheck) {
			if(!Achievements.exists(name)) continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (ratingPercent < 0.2 && !practiceMode);

					case 'ur_good':
						unlock = (ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.cacheOnGPU && !ClientPrefs.shaders && ClientPrefs.lowQuality && !ClientPrefs.globalAntialiasing);

					case 'debugger':
						unlock = (songName == 'test' && !usedPractice);
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if(isStoryMode && campaignMisses + songMisses < 1 && CoolUtil.currentDifficulty.toUpperCase() == 'HARD'
					&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
					unlock = true;
			}

			if(unlock) Achievements.unlock(name);
		}
	}
	#end

	var curLight:Int = -1;
	var curLightEvent:Int = -1;

	public static var process:Process;
	var ffmpegExists:Bool = false;

	private function initRender():Void
	{
		if (!FileSystem.exists(#if linux 'ffmpeg' #else 'ffmpeg.exe' #end))
		{
			trace("\"FFmpeg\" not found! (Is it in the same folder as JSEngine?)");
			return;
		}

		if(!FileSystem.exists('assets/gameRenders/')) { //In case you delete the gameRenders folder
			trace ('gameRenders folder not found! Creating the gameRenders folder...');
            FileSystem.createDirectory('assets/gameRenders');
        }
		else
		if(!FileSystem.isDirectory('assets/gameRenders/')) {
			FileSystem.deleteFile('assets/gameRenders/');
			FileSystem.createDirectory('assets/gameRenders/');
		}

		ffmpegExists = true;

		var fileName = 'assets/gameRenders/' + Paths.formatToSongPath(SONG.song);
		if(FileSystem.exists(fileName + '.mp4')) {
			trace ('Duplicate video found! Adding anti-dupe...');
			var dateNow:String = Date.now().toString();
				dateNow = dateNow.replace(" ", "_");
				dateNow = dateNow.replace(":", "'");
            fileName += '-' + dateNow;
        }

		process = new Process('ffmpeg', ['-v', 'quiet', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', lime.app.Application.current.window.width + 'x' + lime.app.Application.current.window.height, '-r', Std.string(targetFPS), '-i', '-', '-c:v', ClientPrefs.vidEncoder, '-b', Std.string(ClientPrefs.renderBitrate * 1000000), fileName + '.mp4']);
		FlxG.autoPause = false;
	}

	var img = null;
	var bytes = null;
	private function pipeFrame():Void
	{
		if (!ffmpegExists || process == null)
		return;

		img = lime.app.Application.current.window.readPixels(new lime.math.Rectangle(FlxG.scaleMode.offset.x, FlxG.scaleMode.offset.y, FlxG.scaleMode.gameSize.x, FlxG.scaleMode.gameSize.y));
		bytes = img.getPixels(new lime.math.Rectangle(0, 0, img.width, img.height));
		process.stdin.writeBytes(bytes, 0, bytes.length);
	}

	public static function stopRender():Void
	{
		if (!ClientPrefs.ffmpegMode)
			return;

		if (process != null){
			if (process.stdin != null)
				process.stdin.close();

			process.close();
			process.kill();
		}

		FlxG.autoPause = ClientPrefs.autoPause;
	}
}
