package states;

import backend.ClientPrefs;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.Conductor;
import backend.DiscordClient;
import backend.Highscore;
import backend.MusicBeatState;
import backend.Paths;
import backend.WeekData;
import data.Song;
import editors.ChartingState;
import flixel.addons.ui.FlxUIInputText;
import flixel.ui.FlxButton; // for formatting the note count
import music.MusicPlayer;
import objects.Alphabet;
import objects.HealthIcon;
import play.PlayState;
import states.substates.GameplayChangersSubstate;
import states.substates.ResetScoreSubState;

// REFACTOR: helpers for relocated logic
import headers.States;

// REFACTOR: imports for relocated root classes
import backend.Controls;
import data.Section;
import objects.Character;
import objects.Note;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	private static var curSelected:Int = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = '';

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var searchText:FlxText;
	var diffText:FlxText;
	var lerpScore:Float = 0;
	var lerpRating:Float = 0;
	var intendedScore:Float = 0;
	var intendedRating:Float = 0;
	var requiredRamLoad:Float = 0;
	var noteCount:Float = 0;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var grpIcons:FlxTypedGroup<HealthIcon>;

	public static var curPlaying:Bool = false;

	var lerpSelected:Float = 0;

	var bg:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;
	var missingTextBG:FlxSprite;
	var missingText:FlxText;
	var songSearchText:FlxUIInputText;
	var buttonTop:FlxButton;

	var player:MusicPlayer;
	private var layoutWidth:Int = 0;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(bg);
		ViewportVisuals.fill(missingTextBG);
		ViewportVisuals.fill(bottomBG, 26);
		if (missingText != null)
		{
			missingText.x = 50;
			missingText.fieldWidth = FlxG.width - 100;
		}
		if (bottomText != null) bottomText.fieldWidth = FlxG.width;
		if (songSearchText != null) songSearchText.x = FlxG.width - songSearchText.width;
		if (buttonTop != null) buttonTop.x = FlxG.width - buttonTop.width;
		if (searchText != null && buttonTop != null) searchText.x = buttonTop.x + 195;
		final shift:Float = ScreenLayout.contentLeft(FlxG.width) - ScreenLayout.contentLeft(layoutWidth);
		if (grpSongs != null)
			grpSongs.forEach(item -> { item.startPosition.x += shift; item.x += shift; });
		if (grpIcons != null) grpIcons.forEach(icon -> icon.x += shift);
		layoutWidth = FlxG.width;
		if (scoreText != null && player != null) positionHighscore();
		if (player != null) player.onViewportResize();
	}

	override function create()
	{
		layoutWidth = FlxG.width;
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		Paths.gc();

		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		final accept:String = "ACCEPT";
		final reject:String = "BACK";

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			var msg:String = "NO WEEKS ADDED FOR FREEPLAY\n\nPress " + accept + " to go to the Week Editor Menu.\nPress " + reject + " to return to Main Menu.";
			FlxG.switchState(new ErrorState(msg,
				function() FlxG.switchState(new editors.WeekEditorState()),
				function() FlxG.switchState(new MainMenuState())));
			return;
		}

		for (i in 0...WeekData.weeksList.length) {
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		#if PRELOAD_ALL
		if (!curPlaying) Conductor.changeBPM(TitleState.titleJSON.bpm);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		ViewportVisuals.cover(bg);
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);
		grpIcons = new FlxTypedGroup<HealthIcon>();
		add(grpIcons);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(ScreenLayout.contentLeft(FlxG.width) + 90, 320, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			grpSongs.add(songText);

			var maxWidth = 980;
			if (songText.width > maxWidth)
			{
				songText.scaleX = maxWidth / songText.width;
			}
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;
			icon.ID = i;
			grpIcons.add(icon);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		ViewportVisuals.fill(missingTextBG);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;

		if(lastDifficultyName == '')
		{
			lastDifficultyName = CoolUtil.defaultDifficulty;
		}
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));

		if(curPlaying)
		{
			grpIcons.members[instPlaying].canBounce = true;
		}

		MusicBeatState.windowNameSuffix = " - Freeplay Menu";

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(1, 1, 0xFF000000);
		ViewportVisuals.fill(bottomBG, 26);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		#if PRELOAD_ALL
		var leText:String = "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		var size:Int = 16;
		#else
		var leText:String = "Press C to open the Gameplay Changers Menu / Press Y to Reset your Score and Accuracy.";
		var size:Int = 18;
		#end
		if (mobile.MobileControls.enabled)
		{
			leText = "Press X to listen to the Song / Press C to open the Gameplay Changers Menu / Press Y to Reset your Score and Accuracy.";
			size = 16;
		}
		bottomString = leText;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);

		songSearchText = new FlxUIInputText(0, scoreBG.y + scoreBG.height + 5, 500, '', 16);
		songSearchText.x = FlxG.width - songSearchText.width;
		add(songSearchText);

		buttonTop = new FlxButton(0, songSearchText.y + songSearchText.height + 5, "", function() {
			checkForSongsThatMatch(songSearchText.text);
		});
		buttonTop.setGraphicSize(Std.int(songSearchText.width), 50);
		buttonTop.updateHitbox();
		buttonTop.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, RIGHT);
		buttonTop.x = FlxG.width - buttonTop.width;
		add(buttonTop);

		searchText = new FlxText(buttonTop.x + 195, 110, 100, "Search", 24);
		searchText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK);
		add(searchText);

		player = new MusicPlayer(this);
		add(player);

		changeSelection();
		changeDiff();

		FlxG.mouse.visible = true;

		addVirtualPad(LEFT_FULL, A_B_C_X_Y);

		super.create();
	}

	function checkForSongsThatMatch(?start:String = '')
	{
		FreeplayStateHelpers.checkForSongsThatMatch(this, start);
	}

	function regenerateSongs(?start:String = '') {
		FreeplayStateHelpers.regenerateSongs(this, start);
	}

	override function closeSubState() {
		changeSelection(0, false);
		persistentUpdate = true;
		if (virtualPad != null) virtualPad.visible = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		FreeplayStateHelpers.addSong(this, songName, weekNum, songCharacter, color);
	}

	function weekIsLocked(name:String):Bool {
		return FreeplayStateHelpers.weekIsLocked(this, name);
	}

	function regenList() {
		FreeplayStateHelpers.regenList(this);
	}

	public static var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		/*
		for (i in 0...iconArray.length)
		{
				iconArray[i].scale.set(FlxMath.lerp(iconArray[i].scale.x, 1, elapsed * 9),
				FlxMath.lerp(iconArray[i].scale.y, 1, elapsed * 9));
		}
		*/

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, CoolUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, CoolUtil.boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) { //No decimals, add an empty space
			ratingSplit.push('');
		}

		while(ratingSplit[1].length < 2) { //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';
		}

		try {
			var newScoreText:String = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit?.join('.') + '%)';
			if (scoreText.text != newScoreText) scoreText.text = newScoreText;
		}
		catch(e){}
		positionHighscore();

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;
		var space:Bool = FlxG.keys.justPressed.SPACE || virtualPad.buttonX.justPressed;
		var ctrl:Bool = FlxG.keys.justPressed.CONTROL || virtualPad.buttonC.justPressed;

		var shiftMult:Int = 1;
		if (FlxG.keys.pressed.SHIFT) shiftMult = 3;

		try {
			if (!songSearchText?.hasFocus)
			{
				if (!player.playingMusic)
				{
					if(songs.length > 1)
					{
						if (upP)
						{
							changeSelection(-shiftMult);
							holdTime = 0;
						}
						if (downP)
						{
							changeSelection(shiftMult);
							holdTime = 0;
						}

						if(controls.UI_DOWN || controls.UI_UP)
						{
							var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
							holdTime += elapsed;
							var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);
							if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
							{
								changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
								changeDiff();
							}
						}

						if(FlxG.mouse.wheel != 0)
						{
							FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
							changeSelection(-shiftMult * FlxG.mouse.wheel, false);
							changeDiff();
						}
					}


					if (controls.UI_LEFT_P)
						changeDiff(-1);
					else if (controls.UI_RIGHT_P)
						changeDiff(1);
					else if (upP || downP) changeDiff();
				}


				if (controls.BACK)
				{
					curPlaying = false;
					if (player.playingMusic)
					{
						FlxG.sound.music.stop();
						destroyFreeplayVocals();
						FlxG.sound.music.volume = 0;
						instPlaying = -1;

						player.playingMusic = false;
						player.switchPlayMusic();

						Paths.playMenuMusic(true);
						FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
					}
					else
					{
						persistentUpdate = false;
						if(colorTween != null) {
							colorTween.cancel();
						}
						FlxG.sound.play(Paths.sound('cancelMenu'));
						FlxG.switchState(MainMenuState.new);
						FlxG.mouse.visible = false;
					}
				}

				if(ctrl && !player.playingMusic)
				{
					persistentUpdate = false;
					if (virtualPad != null) virtualPad.visible = false;
					openSubState(new GameplayChangersSubstate());
				}
				else if(space)
				{
					requiredRamLoad = 0;
					noteCount = 0;

					var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
					var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
					#if MODS_ALLOWED
					if(instPlaying != curSelected && !player.playingMusic)
					{
						if(sys.FileSystem.exists(Paths.inst(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase())) || sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop)) || sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)))
							FreeplayStateHelpers.playSong(this);
						else
							FreeplayStateHelpers.songJsonPopup(this);
					}
					#else
					if(instPlaying != curSelected && !player.playingMusic)
					{
						if(OpenFlAssets.exists(Paths.inst(songLowercase + '/' + poop, CoolUtil.difficulties[curDifficulty].toLowerCase())) || OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop)))
							FreeplayStateHelpers.playSong(this);
						else
							FreeplayStateHelpers.songJsonPopup(this);
					}
					#end
					else if (instPlaying == curSelected && player.playingMusic)
					{
						player.pauseOrResume(!player.playing);
					}
				}

				else if (accepted && !player.playingMusic)
				{
					persistentUpdate = false;
					var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
					var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

					trace(poop);

					CoolUtil.currentDifficulty = CoolUtil.difficultyString();

					#if sys
					if(sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)) || sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop)) || OpenFlAssets.exists(Paths.modsJson(songLowercase + '/' + poop)) || OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))) {
					#else
					if(OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))) {
					#end
					PlayState.SONG = Song.loadFromJson(poop, songLowercase);
					PlayState.storyDifficulty = curDifficulty;

					PlayState.isStoryMode = PlayState.wasOriginallyFreeplay = ClientPrefs.alwaysTriggerCutscene;

					trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
					if(colorTween != null) {
						colorTween.cancel();
					}

					curPlaying = false;

					if (FlxG.keys.pressed.SHIFT) {
						LoadingState.loadAndSwitchState(ChartingState.new);
					}else{
						LoadingState.loadAndSwitchState(PlayState.new);
					}

					FlxG.sound.music.volume = 0;
					FlxG.mouse.visible = false;

					destroyFreeplayVocals();

							#if sys
							if(sys.FileSystem.exists(Paths.inst(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase())) && !sys.FileSystem.exists(Paths.json(poop + '/' + poop))) { //the json doesn't exist, but the song files do, or you put a typo in the name
									CoolUtil.coolError("The JSON's name does not match with  " + poop + "!\nTry making them match.", "JS Engine Anti-Crash Tool");
							} else if(sys.FileSystem.exists(Paths.json(poop + '/' + poop)) && !sys.FileSystem.exists(Paths.inst(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase())))  {//the json exists, but the song files don't
									CoolUtil.coolError("Your song seems to not have an Inst.ogg, check the folder name in 'songs'!", "JS Engine Anti-Crash Tool");
						} else if(!sys.FileSystem.exists(Paths.json(poop + '/' + poop)) && !sys.FileSystem.exists(Paths.inst(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase()))) { //neither the json nor the song files actually exist
							CoolUtil.coolError("It appears that " + poop + " doesn't actually have a JSON, nor does it actually have voices/instrumental files!\nMaybe try fixing its name in weeks/" + WeekData.getWeekFileName() + "?", "JS Engine Anti-Crash Tool");
						}
							#end
					}
				}
				else if ((controls.RESET || virtualPad.buttonY.justPressed) && !player.playingMusic) {
					persistentUpdate = false;
					if (virtualPad != null) virtualPad.visible = false;
					openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
			}
		}
		catch(e){}
		super.update(elapsed);
	}

	function getVocalFromCharacter(char:String)
	{
		return FreeplayStateHelpers.getVocalFromCharacter(this, char);
	}

	public static function destroyFreeplayVocals() {
		FreeplayStateHelpers.destroyFreeplayVocals();
	}

	function changeDiff(change:Int = 0)
	{
		FreeplayStateHelpers.changeDiff(this, change);
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		FreeplayStateHelpers.changeSelection(this, change, playSound);
	}

	private function positionHighscore() {
		FreeplayStateHelpers.positionHighscore(this);
	}
	override function beatHit() {
		super.beatHit();

		if (curPlaying)
			if (grpIcons.members[instPlaying] != null && grpIcons.members[instPlaying].canBounce) grpIcons.members[instPlaying].bounce();
	}
	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		FreeplayStateHelpers.updateTexts(this, elapsed);
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}
