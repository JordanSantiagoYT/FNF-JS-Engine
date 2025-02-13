package;

import flixel.FlxG;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;

class ClientPrefs { //default settings if it can't find a save file containing your current settings
	//Gameplay Settings
	public static var controllerMode:Bool = false;
	public static var downScroll:Bool = false;
	public static var middleScroll:Bool = false;
	public static var opponentStrums:Bool = true;
	public static var ghostTapping:Bool = true;
	public static var autoPause:Bool = true;
	public static var complexAccuracy:Bool = false;
	public static var startingSync:Bool = false;
	public static var noMarvJudge:Bool = false;
	public static var noReset:Bool = false;
	public static var antiCheatEnable:Bool = false;
	public static var instaRestart:Bool = false;
	public static var ezSpam:Bool = false;
	public static var shitGivesMiss:Bool = false;
	public static var ratingIntensity:String = 'Normal';
	public static var spaceVPose:Bool = true;
	public static var ghostTapAnim:Bool = true;
	public static var hitsoundVolume:Float = 0;
	public static var hitsoundType:String = 'osu!mania';
	public static var voiidTrollMode:Bool = false;
	public static var trollMaxSpeed:String = 'Medium';
	public static var missSoundShit:Bool = false;

	//Visuals & UI
	public static var noteSkin:String = 'Default';
	public static var splashType:String = 'Default';
	public static var noteSplashes:Bool = true;
	public static var oppNoteSplashes:Bool = true;
	public static var showNPS:Bool = true;
	public static var showComboInfo:Bool = true;
	public static var maxSplashLimit:Int = 16;
	public static var oppNoteAlpha:Float = 0.65;
	public static var hideHud:Bool = false;
	public static var tauntOnGo:Bool = true;
	public static var oldSusStyle:Bool = false;
	public static var showRendered:Bool = false;
	public static var showcaseMode:Bool = false;
	public static var showcaseST:String = 'JS';
	public static var timeBounce:Bool = true;
	public static var lengthIntro:Bool = true;
	public static var timebarShowSpeed:Bool = false;
	public static var botWatermark:Bool = true;
	public static var missRating:Bool = false;
	public static var scoreTxtSize:Int = 0;
	public static var noteColorStyle:String = 'Normal';
	public static var enableColorShader:Bool = true;
	public static var iconBopWhen:String = 'Every Beat';
	public static var cameraPanning:Bool = true;
	public static var panIntensity:Float = 1;
	public static var rateNameStuff:String = 'Quotes';
	public static var timeBarType:String = 'Time Left';
	public static var scoreStyle:String = 'Psych Engine';
	public static var timeBarStyle:String = 'Vanilla';
	public static var healthBarStyle:String = 'Vanilla';
	public static var watermarkStyle:String = 'Vanilla';
	public static var botTxtStyle:String = 'Vanilla';
	public static var ytWatermarkPosition:String = 'Hidden';
	public static var strumLitStyle:String = 'Full Anim';
	public static var bfIconStyle:String = 'Default';
	public static var ratingType:String = 'Base FNF';
	public static var simplePopups:Bool = false;
	public static var iconBounceType:String = 'Golden Apple';
	public static var colorRatingHit:Bool = true;
	public static var smoothHealth:Bool = true;
	public static var smoothHPBug:Bool = false;
	public static var noBopLimit:Bool = false;
	public static var ogHPColor:Bool = false;
	public static var opponentRateCount:Bool = true;
	public static var flashing:Bool = true;
	public static var camZooms:Bool = true;
	public static var ratingCounter:Bool = false;
	public static var showNotes:Bool = true;
	public static var scoreZoom:Bool = true;
	public static var healthBarAlpha:Float = 1;
	public static var laneUnderlay:Bool = false;
	public static var laneUnderlayAlpha:Float = 1;
	public static var showFPS:Bool = true;
	public static var randomBotplayText:Bool = true;
	public static var botTxtFade:Bool = true;
	public static var pauseMusic:String = 'Tea Time';
	public static var daMenuMusic:String = 'Default';
	public static var checkForUpdates:Bool = true;
	public static var comboStacking = true;
	public static var showRamUsage:Bool = true;
	public static var showMaxRamUsage:Bool = true;
	public static var debugInfo:Bool = false;
	public static var tipTexts:Bool = true;
	public static var discordRPC:Bool = true;

	//Graphics
	public static var lowQuality:Bool = false;
	public static var globalAntialiasing:Bool = true;
	public static var shaders:Bool = true;
	public static var cacheOnGPU:Bool = false;
	public static var dynamicSpawnTime:Bool = false;
	public static var noteSpawnTime:Float = 1;
	public static var resolution:String = '1280x720';
	public static var framerate:Int = 60;

	//Optimization
	public static var charsAndBG:Bool = true;
	public static var enableGC:Bool = true;
	public static var opponentLightStrum:Bool = true;
	public static var botLightStrum:Bool = true;
	public static var playerLightStrum:Bool = true;
	public static var ratingPopups:Bool = true;
	public static var comboPopups:Bool = true;
	public static var showMS:Bool = false;
	public static var noSpawnFunc:Bool = false;
	public static var noHitFuncs:Bool = false;
	public static var noSkipFuncs:Bool = false;
	public static var lessBotLag:Bool = false;
	public static var fastNoteSpawn:Bool = false;

	//Secret Debug
	public static var noGunsRNG:Bool = false;
	public static var pbRControls:Bool = false;
	public static var rainbowFPS:Bool = false;
	public static var noRenderGC:Bool = false;
	public static var wheatleySpace:Bool = true;

	//Unused
	public static var cursing:Bool = true;
	public static var autosaveCharts:Bool = true;
	public static var violence:Bool = true;
	public static var crossFadeData:Array<Dynamic> = ['Default', 'Healthbar', [255, 255, 255], 0.3, 0.35];
	public static var noPausing:Bool = false;

	//Note Colors
	public static var arrowRGB:Array<Array<FlxColor>> = [
		[0xFFC24B99, 0xFFFFFFFF, 0xFF3C1F56],
		[0xFF00FFFF, 0xFFFFFFFF, 0xFF1542B7],
		[0xFF12FA05, 0xFFFFFFFF, 0xFF0A4447],
		[0xFFF9393F, 0xFFFFFFFF, 0xFF651038]];

	//Pixel
	public static var arrowRGBPixel:Array<Array<FlxColor>> = [
		[0xFFE276FF, 0xFFFFF9FF, 0xFF60008D],
		[0xFF3DCAFF, 0xFFF4FFFF, 0xFF003060],
		[0xFF71E300, 0xFFF6FFE6, 0xFF003100],
		[0xFFFF884E, 0xFFFFFAF5, 0xFF6C0000]];

	//Quants
	public static var quantRGB:Array<Array<FlxColor>> = [
		[0xFFF9393F, 0xFFFFFFFF, 0xFF651038], //4th
		[0xFF3A48F5, 0xFFFFFFFF, 0xFF0C3D60], //8th
		[0xFFB200FF, 0xFFFFFFFF, 0xFF57007F], //12th
		[0xFFFFD800, 0xFFFFFFFF, 0xFF4D4100], //16th
		[0xFFFF00DC, 0xFFFFFFFF, 0xFF740066], //24th
		[0xFFFF6A00, 0xFFFFFFFF, 0xFF652800], //32nd
		[0xFF00FFFF, 0xFFFFFFFF, 0xFF004B5E], //48th
		[0xFF12FA05, 0xFFFFFFFF, 0xFF0A4447], //64th
		[0xFFFF7F7F, 0xFFFFFFFF, 0xFF592C2C], //96th
		[0xFFD67FFF, 0xFFFFFFFF, 0xFF5F3870], //128th
		[0xFF00FF90, 0xFFFFFFFF, 0xFF003921], //192nd
		[0xFF7F3300, 0xFFFFFFFF, 0xFF401800], //256th
		[0xFF007F0E, 0xFFFFFFFF, 0xFF003404], //384th
		[0xFF230093, 0xFFFFFFFF, 0xFF0F0043], //512th
		[0xFFE7E7E7, 0xFFFFFFFF, 0xFF2A2A2A], //768th
		[0xFF00AB64, 0xFFFFFFFF, 0xFF00321E], //1024th
		[0xFF000000, 0xFFFFFFFF, 0xFF000000], //1536th
		[0xFFA69C52, 0xFFFFFFFF, 0xFF2F2D17], //2048th
		[0xFFFFF9AB, 0xFFFFFFFF, 0xFF45442F], //3072nd
		[0xFFFF6A00, 0xFFFFFFFF, 0xFF652800]]; //6144th


	// Game Renderer
	public static var ffmpegMode:Bool = false;
	public static var ffmpegInfo:String = 'None';
	public static var targetFPS:Float = 60;
	public static var unlockFPS:Bool = false;
	public static var renderBitrate:Float = 5.0;
	public static var vidEncoder:String = 'libx264';
	public static var oldFFmpegMode:Bool = false;
	public static var lossless:Bool = false;
	public static var quality:Int = 50;
	public static var renderGCRate:Float = 5.0;
	public static var showRemainingTime:Bool = false;

	//Misc
	public static var JSEngineRecharts:Bool = false;
	public static var alwaysTriggerCutscene:Bool = false;
	public static var disableSplash:Bool = false;

	//Gameplay Modifiers
	public static var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative', 
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'onlySicks' => false,
		'practice' => false,
		'botplay' => false,
		'randommode' => false,
		'opponentplay' => false,
		'bothSides' => false,
		'opponentdrain' => false,
		'drainlevel' => 1,
		'flip' => false,
		'stairmode' => false,
		'wavemode' => false,
		'onekey' => false,
		'jacks' => 0,
		'randomspeed' => false,
		'randomspeedmin' => 0.5,
		'randomspeedmax' => 2,
		'thetrollingever' => false
	];

	//Gameplay Offset and Window stuff
	public static var ratingOffset:Int = 0;
	public static var perfectWindow:Int = 15;
	public static var sickWindow:Int = 45;
	public static var goodWindow:Int = 90;
	public static var badWindow:Int = 135;
	public static var safeFrames:Float = 10;
	public static var comboOffset:Array<Int> = [0, 0, 0, 0];
	public static var noteOffset:Int = 0;

	//Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		//Key Bind, Name for ControlsSubState
		'note_left'		=> [A, LEFT],
		'note_down'		=> [S, DOWN],
		'note_up'		=> [W, UP],
		'note_right'	=> [D, RIGHT],
		'bot_energy'	=> [CONTROL, NONE],
		
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_up'			=> [W, UP],
		'ui_right'		=> [D, RIGHT],
		
		'accept'		=> [SPACE, ENTER],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [R, NONE],
		
		'volume_mute'	=> [ZERO, NONE],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN, NONE],
		'debug_2'		=> [EIGHT, NONE],
		'qt_taunt'		=> [SPACE, NONE]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;
	
	// i suck at naming things sorry
	private static var importantMap:Map<String, Array<String>> = [
		"saveBlackList" => ["keyBinds", "defaultKeys"],
		"flixelSound" => ["volume", "sound"],
		"loadBlackList" => ["keyBinds", "defaultKeys"],
	];

	public static var defaultArrowRGB:Array<Array<FlxColor>>;
	public static var defaultPixelRGB:Array<Array<FlxColor>>;
	public static var defaultQuantRGB:Array<Array<FlxColor>>;

	public static function loadDefaultStuff() {
		defaultKeys = keyBinds.copy();
		defaultArrowRGB = arrowRGB.copy();
		defaultPixelRGB = arrowRGBPixel.copy();
		defaultQuantRGB = quantRGB.copy();
	}

	public static function saveSettings() { //changes settings when you exit so that it doesn't reset every time you close the game
		// null code real, from my own mod
		// credits to my friend sanco
		for (field in Type.getClassFields(ClientPrefs))
		{
			if (Type.typeof(Reflect.field(ClientPrefs, field)) != TFunction)
			{
				if (!importantMap.get("saveBlackList").contains(field))
					Reflect.setField(FlxG.save.data, field, Reflect.field(ClientPrefs, field));
			}
		}

		for (flixelS in importantMap.get("flixelSound"))
			Reflect.setField(FlxG.save.data, flixelS, Reflect.field(FlxG.sound, flixelS));

		#if ACHIEVEMENTS_ALLOWED Achievements.save(); #end
		FlxG.save.flush();

		var save:FlxSave = new FlxSave();
		save.bind('controls_v2', CoolUtil.getSavePath()); // Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		save.data.customControls = keyBinds;
		save.flush();
		FlxG.log.add("Settings saved!");
	}

	public static function loadPrefs() { //loads settings if it finds a save file containing the settings
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		
		for (field in Type.getClassFields(ClientPrefs))
		{
			if (Type.typeof(Reflect.field(ClientPrefs, field)) != TFunction)
			{
				if (!importantMap.get("loadBlackList").contains(field))
				{
					var defaultValue:Dynamic = Reflect.field(ClientPrefs, field);
					var flxProp:Dynamic = Reflect.field(FlxG.save.data, field);
					Reflect.setField(ClientPrefs, field, (flxProp != null ? flxProp : defaultValue));

					if (field == "showFPS" && Main.fpsVar != null)
						Main.fpsVar.visible = showFPS;

					if (field == "framerate")
					{
						if (framerate > FlxG.drawFramerate)
						{
							FlxG.updateFramerate = framerate;
							FlxG.drawFramerate = framerate;
						}
						else
						{
							FlxG.drawFramerate = framerate;
							FlxG.updateFramerate = framerate;
						}
					}
				}
			}
		}

		for (flixelS in importantMap.get("flixelSound"))
		{
			var flxProp:Dynamic = Reflect.field(FlxG.save.data, flixelS);
			if (flxProp != null)
				Reflect.setField(FlxG.sound, flixelS, flxProp);
		}

		#if DISCORD_ALLOWED DiscordClient.check(); #end

		var save:FlxSave = new FlxSave();
		save.bind('controls_v2', CoolUtil.getSavePath());
		if (save != null && save.data.customControls != null)
		{
			var loadedControls:Map<String, Array<FlxKey>> = save.data.customControls;
			for (control => keys in loadedControls)
			{
				keyBinds.set(control, keys);
			}
			reloadControls();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic):Dynamic {
		return /*PlayState.isStoryMode ? defaultValue : */ (gameplaySettings.exists(name) ? gameplaySettings.get(name) : defaultValue);
	}

	public static function reloadControls() {
		PlayerSettings.player1.controls.setKeyboardScheme(KeyboardScheme.Solo);

		TitleState.muteKeys = copyKey(keyBinds.get('volume_mute'));
		TitleState.volumeDownKeys = copyKey(keyBinds.get('volume_down'));
		TitleState.volumeUpKeys = copyKey(keyBinds.get('volume_up'));
		FlxG.sound.muteKeys = TitleState.muteKeys;
		FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
	}
	public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey> {
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();
		var i:Int = 0;
		var len:Int = copiedArray.length;

		while (i < len) {
			if(copiedArray[i] == NONE) {
				copiedArray.remove(NONE);
				--i;
			}
			i++;
			len = copiedArray.length;
		}
		return copiedArray;
	}
}
