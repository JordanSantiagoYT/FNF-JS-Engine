package;

import editors.ChartingState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import lime.utils.Assets;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import openfl.utils.Assets as OpenFlAssets;
import flixel.util.FlxTimer;
import flixel.util.FlxStringUtil; //for formatting the note count
import WeekData;
#if MODS_ALLOWED
import sys.FileSystem;
#end
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxUIInputText;
import haxe.Json;

import music.MusicPlayer;

using StringTools;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
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

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		Paths.gc();

		if (PlayState.process != null) PlayState.stopRender();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if desktop
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
		WeekData.loadTheFirstEnabledMod();

		#if PRELOAD_ALL
		if (!curPlaying) Conductor.changeBPM(TitleState.titleJSON.bpm);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);
		grpIcons = new FlxTypedGroup<HealthIcon>();
		add(grpIcons);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			grpSongs.add(songText);

			var maxWidth = 980;
			if (songText.width > maxWidth)
			{
				songText.scaleX = maxWidth / songText.width;
			}
			songText.snapToPosition();

			Paths.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;
			icon.ID = i;
			grpIcons.add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
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

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
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

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		#if PRELOAD_ALL
		var leText:String = "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		var size:Int = 16;
		#else
		var leText:String = "Press C to open the Gameplay Changers Menu / Press Y to Reset your Score and Accuracy.";
		var size:Int = 18;
		#end
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

		searchText = new FlxText(975, 110, 100, "Search", 24);
		searchText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK);
		add(searchText);

		player = new MusicPlayer(this);
		add(player);

		changeSelection();
		changeDiff();

		FlxG.mouse.visible = true;

		super.create();
	}

	function checkForSongsThatMatch(?start:String = '')
	{
		if (player.playingMusic) return;
		
		var foundSongs:Int = 0;
		final txt:FlxText = new FlxText(0, 0, 0, 'No songs found matching your query', 16);
		txt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.scrollFactor.set();
		txt.screenCenter(XY);
		for (i in 0...WeekData.weeksList.length) {
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			for (song in leWeek.songs)
			{
				if (start != null && start.length > 0) {
					var songName = song[0].toLowerCase();
					var s = start.toLowerCase();
					if (songName.indexOf(s) != -1) foundSongs++;
				}
			}
		}
		if (foundSongs > 0 || start == ''){
			if (txt != null)
				remove(txt); // don't do destroy/kill on this btw
			regenerateSongs(start);
		}
		else if (foundSongs <= 0){
			add(txt);
			new FlxTimer().start(5, function(timer) {
				if (txt != null)
					remove(txt);
			});
			return;
		}
	}

	function regenerateSongs(?start:String = '') {
		for (funnyIcon in grpIcons.members)
			funnyIcon.canBounce = false;
		curPlaying = false;

		songs = [];
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
				if (start != null && start.length > 0) {
					var songName = song[0].toLowerCase();
					var s = start.toLowerCase();
					if (songName.indexOf(s) != -1) addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
				} else addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2])); //??????????
			}
		}
		regenList();
	}

	override function closeSubState() {
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	function regenList() {
			grpSongs.forEach(song -> {
				grpSongs.remove(song, true);
				song.destroy();
			});
			grpIcons.forEach(icon -> {
				grpIcons.remove(icon, true);
				icon.destroy();
			});
			
			//we clear the remaining ones
			grpSongs.clear();
			grpIcons.clear();

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			grpSongs.add(songText);

			var maxWidth = 980;
			if (songText.width > maxWidth)
			{
				songText.scaleX = maxWidth / songText.width;
			}
			songText.snapToPosition();

			Paths.currentModDirectory = songs[i].folder;

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;
			icon.ID = i;
			grpIcons.add(icon);
		}
				
		changeSelection();
		changeDiff();
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

		scoreText.text = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		positionHighscore();

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;
		var space = FlxG.keys.justPressed.SPACE;
		var ctrl = FlxG.keys.justPressed.CONTROL;

		var shiftMult:Int = 1;
		if (FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if (!songSearchText.hasFocus)
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

					FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic), 0);
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
				openSubState(new GameplayChangersSubstate());
			}
			else if(space)
			{
				requiredRamLoad = 0;
				noteCount = 0;
					function playSong() {
					#if PRELOAD_ALL
					destroyFreeplayVocals();
					FlxG.sound.music.volume = 0;
					Paths.currentModDirectory = songs[curSelected].folder;
					var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
					PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());

					var diff:String = (PlayState.SONG.specialAudioName.length > 1 ? PlayState.SONG.specialAudioName : CoolUtil.difficulties[curDifficulty]).toLowerCase();

					if (PlayState.SONG.needsVoices)
					{
						vocals = new FlxSound();
						try
						{
							var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
							var loadedVocals:openfl.media.Sound = Paths.voices(PlayState.SONG.song, diff, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
							if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song, diff);
							
							if(loadedVocals != null && loadedVocals.length > 0)
							{
								vocals.loadEmbedded(loadedVocals);
								FlxG.sound.list.add(vocals);
								vocals.persist = vocals.looped = true;
								vocals.volume = 0.8;
								vocals.play();
								vocals.pause();
							}
							else vocals = FlxDestroyUtil.destroy(vocals);
						}
						catch(e:Dynamic)
						{
							vocals = FlxDestroyUtil.destroy(vocals);
						}
						
						opponentVocals = new FlxSound();
						try
						{
							//trace('please work...');
							var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
							var loadedVocals:openfl.media.Sound = Paths.voices(PlayState.SONG.song, diff, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
							
							if(loadedVocals != null && loadedVocals.length > 0)
							{
								opponentVocals.loadEmbedded(loadedVocals);
								FlxG.sound.list.add(opponentVocals);
								opponentVocals.persist = opponentVocals.looped = true;
								opponentVocals.volume = 0.8;
								opponentVocals.play();
								opponentVocals.pause();
								//trace('it worked yaaay!!');
							}
							else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
						}
						catch(e:Dynamic)
						{
							//trace('FUUUCK');
							opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
						}
					}
					FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song, diff), 0.7);
					if (vocals != null) 
					{
						vocals.play();
						vocals.persist = true;
						vocals.looped = true;
						vocals.volume = 0.7;
					}
					instPlaying = curSelected;
					Conductor.changeBPM(PlayState.SONG.bpm);
					for (funnyIcon in grpIcons.members)
						funnyIcon.canBounce = false;
					grpIcons.members[instPlaying].canBounce = true;
					curPlaying = true;
					#end

					if (FlxG.keys.pressed.SHIFT) {
						for (section in PlayState.SONG.notes) {
						noteCount += section.sectionNotes.length;
						requiredRamLoad += 72872 * section.sectionNotes.length;
						}
						CoolUtil.coolError("There are " + FlxStringUtil.formatMoney(noteCount, false) + " notes in this chart!\nWith Show Notes turned on, you'd need " + FlxStringUtil.formatBytes(requiredRamLoad / 2) + " of ram to load this.", "JS Engine Chart Diagnosis");
					}
					player.playingMusic = true;
					player.curTime = 0;
					player.switchPlayMusic();
					player.pauseOrResume(true);
				}
				function songJsonPopup() { //you pressed space, but the song's ogg files don't exist
					var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
					trace(poop + '\'s .ogg does not exist!');
					FlxG.sound.play(Paths.sound('invalidJSON'));
					FlxG.camera.shake(0.05, 0.05);
					var funnyText = new FlxText(12, FlxG.height - 24, 0, "Invalid Song!");
					funnyText.scrollFactor.set();
					funnyText.screenCenter();
					funnyText.x = 5;
					funnyText.y = FlxG.height/2 - 64;
					funnyText.setFormat("vcr.ttf", 64, FlxColor.RED, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
					add(funnyText);
					FlxTween.tween(funnyText, {alpha: 0}, 0.9, {
						onComplete: _ -> {
							remove(funnyText, true);
							funnyText.destroy();
						}
					});
				}
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
				#if MODS_ALLOWED
				if(instPlaying != curSelected && !player.playingMusic)
				{
					if(sys.FileSystem.exists(Paths.inst(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase())) || sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop)) || sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)))
						playSong();
					else
						songJsonPopup();
				}
				#else
				if(instPlaying != curSelected && !player.playingMusic)
				{
					if(OpenFlAssets.exists(Paths.inst(songLowercase + '/' + poop, CoolUtil.difficulties[curDifficulty].toLowerCase())) || OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop)))
						playSong();
					else
						songJsonPopup();
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

				if(sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)) || sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop)) || OpenFlAssets.exists(Paths.modsJson(songLowercase + '/' + poop)) || OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))) {
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

						} else {
						if(sys.FileSystem.exists(Paths.inst(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase())) && !sys.FileSystem.exists(Paths.json(poop + '/' + poop))) { //the json doesn't exist, but the song files do, or you put a typo in the name
								CoolUtil.coolError("The JSON's name does not match with  " + poop + "!\nTry making them match.", "JS Engine Anti-Crash Tool");
						} else if(sys.FileSystem.exists(Paths.json(poop + '/' + poop)) && !sys.FileSystem.exists(Paths.inst(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase())))  {//the json exists, but the song files don't
								CoolUtil.coolError("Your song seems to not have an Inst.ogg, check the folder name in 'songs'!", "JS Engine Anti-Crash Tool");
					} else if(!sys.FileSystem.exists(Paths.json(poop + '/' + poop)) && !sys.FileSystem.exists(Paths.inst(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase()))) { //neither the json nor the song files actually exist
						CoolUtil.coolError("It appears that " + poop + " doesn't actually have a JSON, nor does it actually have voices/instrumental files!\nMaybe try fixing its name in weeks/" + WeekData.getWeekFileName() + "?", "JS Engine Anti-Crash Tool");
					}
				}
			}
			else if (controls.RESET && !player.playingMusic) {
				persistentUpdate = false;
				openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
		}
		super.update(elapsed);
	}

	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic) return;

		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = CoolUtil.difficulties.length-1;
		if (curDifficulty >= CoolUtil.difficulties.length)
			curDifficulty = 0;

		lastDifficultyName = CoolUtil.difficulties[curDifficulty];

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		PlayState.storyDifficulty = curDifficulty;
		diffText.text = '< ' + CoolUtil.difficultyString() + ' >';
		positionHighscore();
	}

    public static function formatCompactNumber(number:Float):String //this entire function is ai generated LMAO
    {
        var suffixes:Array<String> = [' bytes', ' KB', ' MB', ' GB', 'TB'];
        var magnitude:Int = 0;
        var num:Float = number;

        while (num >= 1000.0 && magnitude < suffixes.length - 1)
        {
            num /= 1000.0;
            magnitude++;
        }

        // Use the floor value for the compact representation
        var compactValue:Float = Math.floor(num * 100) / 100;
	if (compactValue <= 0.001) {
		return "0"; //Return 0 if compactValue = null
	} else {
        	return compactValue + (magnitude == 0 ? "" : "") + suffixes[magnitude];
	}
    }

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic) return;

		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;
			
		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor) {
			if(colorTween != null) {
				colorTween.cancel();
			}
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: function(twn:FlxTween) {
					colorTween = null;
				}
			});
		}

		// selector.y = (70 * curSelected) + 30;

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		var bullShit:Int = 0;

		for (i in grpIcons.members) i.alpha = (i.ID == curSelected ? 1 : 0.6);

		for (item in grpSongs.members)
		{
			item.targetY = item.ID - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0) item.alpha = 1;
		}

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
		
		Paths.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var diffStr:String = WeekData.getCurrentWeek().difficulties;
		if(diffStr != null) diffStr = diffStr.trim(); //Fuck you HTML5

		if(diffStr != null && diffStr.length > 0)
		{
			var diffs:Array<String> = diffStr.split(',');
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				if(diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if(diffs[i].length < 1) diffs.remove(diffs[i]);
				}
				--i;
			}

			if(diffs.length > 0 && diffs[0].length > 0)
			{
				CoolUtil.difficulties = diffs;
			}
		}
		
		if(CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))
		{
			curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
		}
		else
		{
			curDifficulty = 0;
		}

		if (Song.hasDifficulty(songs[curSelected].songName.toLowerCase(), 'jshard') && ClientPrefs.JSEngineRecharts)
			CoolUtil.difficulties.push('jshard');

		if (CoolUtil.defaultSongs.contains(songs[curSelected].songName.toLowerCase()) && Song.hasDifficulty(songs[curSelected].songName.toLowerCase(), 'erect'))
		{
			CoolUtil.difficulties.push('erect');
			CoolUtil.difficulties.push('nightmare');
		}

		if (songs[curSelected].songName.toLowerCase() == 'darnell') 
		{
			CoolUtil.difficulties.push('bf'); 
			if (ClientPrefs.JSEngineRecharts) 
				CoolUtil.difficulties.push('jsbf');
		}

		var newPos:Int = CoolUtil.difficulties.indexOf(lastDifficultyName);
		//trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
		if(newPos > -1)
		{
			curDifficulty = newPos;
		}
	}

	private function positionHighscore() {
		scoreText.x = FlxG.width - scoreText.width - 6;

		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
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
		lerpSelected = FlxMath.lerp(lerpSelected, curSelected, FlxMath.bound(elapsed * 9.6, 0, 1));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			grpIcons.members[i].visible = grpIcons.members[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = grpIcons.members[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
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
		this.folder = Paths.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}