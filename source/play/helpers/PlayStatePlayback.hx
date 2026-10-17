package play.helpers;

import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;
import backend.DiscordClient;
import backend.Highscore;
import backend.MusicBeatState;
#if MODS_ALLOWED
#end
import backend.WeekData;

import data.Song;

import objects.Character;

import play.BaseStage;

import play.PlayState;

import play.helpers.PlayStateCamera;
import play.helpers.PlayStateNoteHelpers;

import states.FreeplayState;
import states.LoadingState;
import states.RenderingDoneSubState;
import states.StoryMenuState;

// REFACTOR: imports for relocated root classes
import objects.Note;

// REFACTOR: song playback control extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStatePlayback
{
	public static function setSongTime(state:PlayState, time:Float)
	{
		if(time < 0) time = 0;

		FlxG.sound.music.pause();
		pauseVocals(state);

		FlxG.sound.music.time = time;
		FlxG.sound.music.play();
		FlxG.sound.music.pitch = state.playbackRate;
		if (state.ffmpegMode) FlxG.sound.music.volume = 0;

		if (Conductor.songPosition <= state.vocals.length)
		{
			setVocalsTime(state, time);
			#if FLX_PITCH
			state.vocals.pitch = state.playbackRate;
			state.opponentVocals.pitch = state.playbackRate;
			#end
		}
		state.vocals.play();
		state.opponentVocals.play();
		if (state.ffmpegMode) state.vocals.volume = state.opponentVocals.volume = 0;
		Conductor.songPosition = time;
		if (time > 0) PlayStateNoteHelpers.clearNotesBefore(state, time);
	}

	public static function startSong(state:PlayState):Void
	{
		state.startingSong = false;

		var diff:String = (PlayState.SONG.specialAudioName.length > 1 ? PlayState.SONG.specialAudioName : CoolUtil.difficultyString()).toLowerCase();
		@:privateAccess
		if (!state.ffmpegMode) {
			FlxG.sound.playMusic(state.inst._sound, 1, false);
			FlxG.sound.music.onComplete = PlayStatePlayback.finishSong.bind(state);
			state.vocals.play();
			state.opponentVocals.play();
		} else {
			FlxG.sound.playMusic(state.inst._sound, 0, false);
			state.vocals.play(); state.vocals.volume = 0;
			state.opponentVocals.play(); state.opponentVocals.volume = 0;
		}
		if (!state.ffmpegMode && (!state.trollingMode || PlayState.SONG.song.toLowerCase() != 'anti-cheat-song'))
			FlxG.sound.music.onComplete = PlayStatePlayback.finishSong.bind(state);

		FlxG.sound.music.pitch = state.playbackRate;
		state.vocals.pitch = state.opponentVocals.pitch = state.playbackRate;

		setSongTime(state, Math.max(0, PlayState.startOnTime - 500) + Conductor.offset);
		PlayState.startOnTime = 0;

		if(state.paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			pauseVocals(state);
		}
		state.curTime = Conductor.songPosition - ClientPrefs.noteOffset;
		state.songPercent = (state.curTime / state.songLength);

		state.stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		state.songLength = FlxG.sound.music.length; //so that the timer won't just appear as 0

		if (ClientPrefs.timeBarType != 'Disabled') {
			state.timeBar.scale.x = 0.01;
			state.timeBarBG.scale.x = 0.01;
			FlxTween.tween(state.timeBar, {alpha: 1, "scale.x": 1}, 1, {ease: FlxEase.expoOut});
			FlxTween.tween(state.timeBarBG, {alpha: 1, "scale.x": 1}, 1, {ease: FlxEase.expoOut});
			FlxTween.tween(state.timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		}

		if (state.scoreTxtUpdateFrame <= 4 && state.scoreTxt != null) state.updateScore();

		// TODO: Lock other note inputs
		if (state.oneK)
		{
			state.playerStrums.forEachAlive(function(daNote:FlxSprite)
			{
				if (daNote != state.playerStrums.members[state.firstNoteData])
				{
					FlxTween.cancelTweensOf(daNote);
					FlxTween.tween(daNote, {alpha: 0}, 0.7, {ease: FlxEase.expoOut});
				}
			});
			state.opponentStrums.forEachAlive(function(daNote:FlxSprite)
			{
				if (daNote != state.opponentStrums.members[state.firstNoteData])
				{
					FlxTween.cancelTweensOf(daNote);
					FlxTween.tween(daNote, {alpha: 0}, 0.7, {ease: FlxEase.expoOut});
				}
			});
			FlxG.sound.play(Paths.sound('FunnyVanish'));
		}

		#if DISCORD_ALLOWED
		if(state.autoUpdateRPC) {
			if (state.cpuControlled) state.detailsText = state.detailsText + ' (using a bot)';
			// Updating Discord Rich Presence (with Time Left)
			DiscordClient.changePresence(state.detailsText, PlayState.SONG.song + " (" + state.storyDifficultyText + ")", state.iconP2.getCharacter(), true, state.songLength);
			if (state.ffmpegMode) {
				state.detailsText = 'Rendering a Song';
				DiscordClient.changePresence(state.detailsText, PlayState.SONG.song + " (" + state.storyDifficultyText + ")", state.iconP2.getCharacter(), true, state.songLength);
			}
		}
		#end
		state.setOnLuas('songLength', state.songLength);
		state.callOnLuas('onSongStart');
	}

	public static function lerpSongSpeed(state:PlayState, num:Float, time:Float):Void
	{
		FlxTween.num(state.playbackRate, num, time, {onUpdate: function(tween:FlxTween){
			var ting = FlxMath.lerp(state.playbackRate, num, tween.percent);
			var ting2 = FlxMath.lerp(state.songSpeed, state.ogSongSpeed / state.playbackRate, tween.percent);
			if (ting != 0) //divide by 0 is a verry bad
				state.playbackRate = ting; //why cant i just tween a variable

			if (ting2 != 0)
				state.songSpeed = state.ogSongSpeed / state.playbackRate;

			setVocalsTime(state, Conductor.songPosition);
			if (!state.ffmpegMode) resyncVocals(state);
		}});
	}

	public static function changeTheSettingsBitch(state:PlayState) {
		state.healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		state.healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		state.hpDrainLevel = ClientPrefs.getGameplaySetting('drainlevel', 1);
		state.instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		state.sickOnly = ClientPrefs.getGameplaySetting('onlySicks', false);
		state.practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		state.cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);
		PlayState.opponentChart = ClientPrefs.getGameplaySetting('opponentplay', false);
		state.trollingMode = ClientPrefs.getGameplaySetting('thetrollingever', false);
		state.opponentDrain = ClientPrefs.getGameplaySetting('opponentdrain', false);
		state.randomMode = ClientPrefs.getGameplaySetting('randommode', false);
		state.flip = ClientPrefs.getGameplaySetting('flip', false);
		state.stairs = ClientPrefs.getGameplaySetting('stairmode', false);
		state.waves = ClientPrefs.getGameplaySetting('wavemode', false);
		state.oneK = ClientPrefs.getGameplaySetting('onekey', false);
		state.randomSpeedThing = ClientPrefs.getGameplaySetting('randomspeed', false);
		state.jackingtime = ClientPrefs.getGameplaySetting('jacks', 0);
		state.playbackRate = ClientPrefs.getGameplaySetting('songspeed', 1);
		state.songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(state.songSpeedType)
		{
			case "multiplicative":
				state.songSpeed = PlayState.SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				state.songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		state.ogSongSpeed = state.songSpeed;

		PlayState.shouldDrainHealth = (state.opponentDrain || (PlayState.opponentChart ? state.boyfriend.healthDrain : state.dad.healthDrain));
		if (!state.opponentDrain && !Math.isNaN((PlayState.opponentChart ? state.boyfriend : state.dad).drainAmount)) state.healthDrainAmount = PlayState.opponentChart ? state.boyfriend.drainAmount : state.dad.drainAmount;
		if (!state.opponentDrain && !Math.isNaN((PlayState.opponentChart ? state.boyfriend : state.dad).drainFloor)) state.healthDrainFloor = PlayState.opponentChart ? state.boyfriend.drainFloor : state.dad.drainFloor;
	}

	public static function resyncVocals(state:PlayState):Void
	{
		if(state.finishTimer != null || state.ffmpegMode) return;

		debug.FrameProfiler.beginAudio();
		FlxG.sound.music.pitch = state.playbackRate;
		state.vocals.pitch = state.opponentVocals.pitch = state.playbackRate;
		if(!(Conductor.songPosition > 20 && FlxG.sound.music.time < 20))
		{
			pauseVocals(state);
			FlxG.sound.music.pause();

			if(FlxG.sound.music.time >= FlxG.sound.music.length)
				Conductor.songPosition = FlxG.sound.music.length;
			else
				Conductor.songPosition = FlxG.sound.music.time;

			setVocalsTime(state, Conductor.songPosition);

			FlxG.sound.music.play();
			for (i in [state.vocals, state.opponentVocals])
				if (i != null && i.time <= i.length) i.play();
		}
		else
		{
			while(Conductor.songPosition > 20 && FlxG.sound.music.time < 20)
			{
				FlxG.sound.music.time = Conductor.songPosition;
				setVocalsTime(state, Conductor.songPosition);

				FlxG.sound.music.play();
				for (i in [state.vocals, state.opponentVocals])
					if (i != null && i.time <= i.length) i.play();
			}
		}
		debug.FrameProfiler.endAudio();
	}

	public static function unpauseVocals(state:PlayState)
	{
		for (i in [state.vocals, state.opponentVocals])
			if (i != null && i.time <= FlxG.sound.music.length)
				i.resume();
	}
	public static function pauseVocals(state:PlayState)
	{
		for (i in [state.vocals, state.opponentVocals])
			if (i != null && i.time <= FlxG.sound.music.length)
				i.pause();
	}
	public static function setVocalsTime(state:PlayState, time:Float)
	{
		for (i in [state.vocals, state.opponentVocals])
			if (i != null && i.time < state.vocals.length)
				i.time = time;
	}

	public static function finishSong(state:PlayState, ?ignoreNoteOffset:Bool = false):Void
	{
		if (!state.trollingMode && PlayState.SONG.song.toLowerCase() != 'anti-cheat-song') {
			state.updateTime = false;
			FlxG.sound.music.volume = 0;
			state.vocals.volume = state.opponentVocals.volume = 0;
			FlxG.mouse.unload(); // just in case you changed it beforehand
			pauseVocals(state);
			if(!state.ffmpegMode){
				if(ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
					state.endCallback();
				} else {
					state.finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
						state.endCallback();
					});
				}
			} else state.endCallback();
		}
	}

	public static function loopSongLol(state:PlayState)
	{
		state.stepsToDo = /* You need stepsToDo to change, otherwise the sections break. */ state.curStep = state.curBeat = state.curSection = 0; // Wow.
		state.oldStep  = -1;

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
			state.playbackRate *= 1.05;
		} else {
			state.playbackRate += calculateTrollModeStuff(state, state.playbackRate);
		}

		if (state.playbackRate >= TROLL_MAX_SPEED && ClientPrefs.trollMaxSpeed != 'Disabled') { // Limit playback rate to the troll mode max speed
			state.playbackRate = TROLL_MAX_SPEED;
		}
	}

	public static function calculateTrollModeStuff(state:PlayState, pb:Float):Float {
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

	public static function calculateResetTime(state:PlayState):Float {
		if (ClientPrefs.strumLitStyle == 'BPM Based') return (Conductor.stepCrochet * 1.5 / 1000) / state.playbackRate;
		return 0.15 / state.playbackRate;
	}

	public static function loopCallback(state:PlayState, startingPoint:Float = 0)
	{
		PlayStateNoteHelpers.KillNotes(state); //kill any existing notes
		FlxG.sound.music.time = startingPoint;
		if (PlayState.SONG.needsVoices) setVocalsTime(state, startingPoint);
		state.lastUpdateTime = startingPoint;
		Conductor.songPosition = startingPoint;
		state.notesAddedCount = state.eventIndex = 0;

		for (n in state.unspawnNotes)
			if (n.strumTime <= startingPoint)
				state.notesAddedCount++;

		for (e in state.eventNotes)
			if (e.strumTime <= startingPoint)
				state.eventIndex++;

		if (!ClientPrefs.showNotes)
		{
			var noteIndex:Int = 0;
			while (state.unspawnNotes.length > 0 && state.unspawnNotes[noteIndex] != null)
			{
				state.unspawnNotes[noteIndex].wasHit = false;
				noteIndex++;
			}
		}
	}

	public static function endSong(state:PlayState):Void
	{
		if (state.mobileControls != null) state.mobileControls.visible = false;
		if (state.virtualPad != null) state.virtualPad.visible = false;
		state.timeBarBG.visible = false;
		state.timeBar.visible = false;
		state.timeTxt.visible = false;
		state.canPause = false;
		state.endingSong = true;
		state.inCutscene = false;
		state.updateTime = false;

		state.startedCountdown = false;

		PlayState.deathCounter = 0;
		PlayState.seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
		state.checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);
		#end

		var ret:Dynamic = state.callOnLuas('onEndSong', [], true);
		#if LUA_ALLOWED
		if(ret != FunkinLua.Function_Stop && !state.transitioning) {
		#else
		if(!state.transitioning) {
		#end
			if (!state.cpuControlled && !PlayState.playerIsCheating && ClientPrefs.safeFrames <= 10)
			{
				var percent:Float = state.ratingPercent;
				if(Math.isNaN(percent)) percent = 0;
				Highscore.saveScore(PlayState.SONG.song, Std.int(state.songScore), PlayState.storyDifficulty, percent);
			}
			state.playbackRate = 1;

			if (PlayState.chartingMode)
			{
				if (!state.ffmpegMode) state.openChartEditor();
				else
				{
					state.endingTime = haxe.Timer.stamp();
					FlxG.switchState(new RenderingDoneSubState(state.endingTime - state.startingTime));
					PlayState.chartingMode = true;
				}
				return;
			}

			if (PlayState.isStoryMode && !PlayState.wasOriginallyFreeplay)
			{
				PlayState.campaignScore += state.songScore;
				PlayState.campaignMisses += Std.int(state.songMisses);

				PlayState.storyPlaylist.remove(PlayState.storyPlaylist[0]);

				if (PlayState.storyPlaylist.length <= 0)
				{
					Mods.loadTopMod();
					Paths.playMenuMusic(true);
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

					state.canResync = false;
					FlxG.switchState(new StoryMenuState());

					if(!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false)) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[PlayState.storyWeek], true);

						Highscore.saveWeekScore(WeekData.getWeekFileName(), Std.int(PlayState.campaignScore), PlayState.storyDifficulty);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					PlayState.changedDifficulty = false;
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					PlayState.prevCamFollow = state.camFollow;
					PlayState.prevCamFollowPos = state.camFollowPos;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);

					state.canResync = false;
					FlxG.sound.music.stop();
					LoadingState.loadAndSwitchState(new PlayState());
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				Mods.loadTopMod();
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

				state.canResync = false;
				if (!state.ffmpegMode) FlxG.switchState(new FreeplayState());
				else
				{
					state.endingTime = haxe.Timer.stamp();
					FlxG.switchState(new RenderingDoneSubState(state.endingTime - state.startingTime));
				}
				Paths.playMenuMusic(true);
				PlayState.changedDifficulty = false;
			}
			state.transitioning = true;
		}
	}

	public static function restartSong(state:PlayState, noTrans:Bool = true)
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		state.vocals.volume = state.opponentVocals.volume = 0;

		FlxTransitionableState.skipNextTransOut = noTrans;
		FlxG.resetState();
	}
}
