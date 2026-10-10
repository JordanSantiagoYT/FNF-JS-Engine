package play.helpers;

import flixel.util.FlxSort;
import backend.Achievements;
import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;
import backend.Highscore;
#if MODS_ALLOWED
import backend.Mods;
#end
import backend.WeekData;

import objects.Note;
import objects.Popup;

import play.PlayState;

import psychlua.EtternaFunctions; // REFACTOR: EtternaFunctions moved to psychlua package

import play.helpers.PlayStateNoteHelpers;

// REFACTOR: scoring / rating popup logic extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateRating
{
	public static function cachePopUpScore(state:PlayState)
	{
		if (PlayState.isPixelStage)
		{
			state.pixelRatingPrefix = 'pixelUI/';
			state.pixelRatingSuffix = '-pixel';
		}

		var normalRating:String = 'ratings/' + ClientPrefs.ratingType.toLowerCase().replace(' ', '-').trim() + '/';

		state.pixelRatingPrefix += normalRating;

		Paths.image(state.pixelRatingPrefix + "perfect" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "sick" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "good" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "bad" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "shit" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "miss" + state.pixelRatingSuffix);

		for (i in 0...10) Paths.image(state.pixelRatingPrefix + 'num' + i + state.pixelRatingSuffix);
		if (Paths.fileExists('images/${normalRating}' + 'hitStrings.txt', TEXT))
			state.hitStrings = Mods.mergeAllTextsNamed('images/${normalRating}' + 'hitStrings.txt', null, false);

		if (Paths.fileExists('images/${normalRating}' + 'fcStrings.txt', TEXT))
			state.fcStrings = Mods.mergeAllTextsNamed('images/${normalRating}' + 'fcStrings.txt', null, false);
	}

	public static function judgeNote(state:PlayState, note:Note = null, ?miss:Bool = false)
	{
		if (note == null || !note.alive) return;
		if (state.daRating == null) state.daRating = state.ratingsData[0]; //because it likes being stupid
		if (!state.cpuControlled)
		{
			state.noteDiff = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset) / state.playbackRate;
			final wife:Float = EtternaFunctions.wife3(state.noteDiff, Conductor.timeScale);

			state.daRating = Conductor.judgeNote(note, state.noteDiff, state.cpuControlled, miss);
			if (state.sickOnly && (state.noteDiff > ClientPrefs.sickWindow || state.noteDiff < -ClientPrefs.sickWindow))
				state.doDeathCheck(true);

			if (miss) state.daRating.image = 'miss';
				else if (state.ratingsData[0].image == 'miss') state.ratingsData[0].image = !ClientPrefs.noMarvJudge ? 'perfect' : 'sick';

			if (!miss)
			{
				if (!ClientPrefs.complexAccuracy) state.totalNotesHit += state.daRating.ratingMod;
				if (ClientPrefs.complexAccuracy) state.totalNotesHit += wife;
				note.ratingMod = state.daRating.ratingMod;
				if(!note.ratingDisabled) state.daRating.increase();
			}
			note.rating = state.daRating.name;
		}

		if(state.daRating.noteSplash && !note.noteSplashDisabled && !miss && state.splashesPerFrame[1] <= 4)
			PlayStateNoteHelpers.spawnNoteSplashOnNote(state, false, note);

		if(!state.practiceMode && !miss) {
			state.songScore += state.daRating.score * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
			if(!state.cpuControlled && !note.ratingDisabled)
			{
				state.songHits++;
				state.totalPlayed++;
				if(!state.cpuControlled || state.cpuControlled) {
					RecalculateRating(state, false);
				}
			}
		}
	}

	public static function popUpScore(state:PlayState, note:Note = null, ?miss:Bool = false):Void
	{
		state.popUpsFrame += 1;

		if(ClientPrefs.scoreZoom && state.scoreTxt != null && !state.cpuControlled && !miss)
		{
			if(state.scoreTxtTween != null) {
				state.scoreTxtTween.cancel();
			}
			state.scoreTxt.scale.x = 1.075;
			state.scoreTxt.scale.y = 1.075;
			state.scoreTxtTween = FlxTween.tween(state.scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween) {
					state.scoreTxtTween = null;
				}
			});
		}

		if (!miss && !state.ffmpegMode) (PlayState.opponentChart ? state.opponentVocals : state.vocals).volume = 1;

		judgeNote(state, note, miss);

		if (state.popUpsFrame <= 3)
		{
			if (!ClientPrefs.comboStacking) while (state.popUpGroup.members.length > 0)
			{
				var spr = state.popUpGroup.members[0];
				if (spr == null) continue;

				FlxTween.cancelTweensOf(spr);
				state.popUpGroup.remove(spr, true);
				spr.kill();
			}

			if (state.showRating && ClientPrefs.ratingPopups && !ClientPrefs.simplePopups) {
				state.rating = state.popUpGroup.recycle(Popup);
				state.rating.setupRating(state.pixelRatingPrefix + state.daRating.image + state.pixelRatingSuffix);
				state.rating.alphaTween();
				state.popUpGroup.insert(0, state.rating);
			}

			if (state.showComboNum && ClientPrefs.comboPopups && !ClientPrefs.simplePopups)
			{
				var tempCombo:Float = (state.combo > 0 ? state.combo : -state.combo);
				var tempComboAlt:Float = tempCombo;

				state.separatedScore = [];
				while(tempCombo >= 10)
				{
					state.separatedScore.unshift(Math.ffloor(tempCombo / 10) % 10);
					tempCombo = Math.ffloor(tempCombo / 10);
				}
				state.separatedScore.push(tempComboAlt % 10);

				if (state.combo < 0) state.separatedScore.unshift("neg");

				for (daLoop=>i in state.separatedScore)
				{
					state.numScore = state.popUpGroup.recycle(Popup);
					state.numScore.setupNumber(state.pixelRatingPrefix + 'num' + i + state.pixelRatingSuffix, daLoop, tempComboAlt);
					if (miss) state.numScore.color = FlxColor.fromRGB(204, 66, 66);
					state.numScore.alphaTween(true);
					state.popUpGroup.insert(0, state.numScore);
				}
			}

			if (ClientPrefs.showMS && !ClientPrefs.hideHud) {
				state.msTxt.showHit({
					noteDiff: state.noteDiff,
					combo: state.combo,
					rating: state.daRating.name,
					miss: miss,
					cpuControlled: state.cpuControlled,
					playbackRate: state.playbackRate
				});
			}

			if (ClientPrefs.ratingPopups && ClientPrefs.simplePopups && !ClientPrefs.hideHud) {
				state.judgeTxt.showHit({
					combo: state.combo,
					rating: state.daRating.name,
					miss: miss,
					playbackRate: state.playbackRate
				});
			}
			if (ClientPrefs.ratingPopups && !ClientPrefs.simplePopups) state.popUpGroup.sort((o, a, b) ->
				{
					return FlxSort.byValues(FlxSort.ASCENDING, a.popTime, b.popTime);
				}
			);
		}
	}

	public static function updateScore(state:PlayState, miss:Bool = false)
	{
		state.scoreTxtUpdateFrame++;
		if (!state.scoreTxt.visible || state.scoreTxt == null)
			return;
		//GAH DAYUM THIS IS MORE OPTIMIZED THAN BEFORE
		//No it's not
		var divider = switch (ClientPrefs.scoreStyle)
		{
			case 'Leather Engine': '~';
			case 'Forever Engine': '•';
			default: '|';
		}
		state.formattedScore = PlayState.formatNumber(state.songScore);
		if (ClientPrefs.scoreStyle == 'JS Engine') state.formattedScore = PlayState.formatNumber(state.shownScore);
		state.formattedSongMisses = PlayState.formatNumber(state.songMisses);
		state.formattedCombo = PlayState.formatNumber(state.combo);
		state.formattedNPS = PlayState.formatNumber(state.nps);
		state.formattedMaxNPS = PlayState.formatNumber(state.maxNPS);
		state.npsString = state.showNPS ? ' $divider ' + (state.cpuControlled && ClientPrefs.botWatermark ? 'Bot ' : '') + 'NPS/Max: ' + state.formattedNPS + '/' + state.formattedMaxNPS : '';
		state.accuracy = Highscore.floorDecimal(state.ratingPercent * 100, 2) + '%';
		state.fcString = state.ratingFC;
		state.missString = (!state.instakillOnMiss ? switch(ClientPrefs.scoreStyle)
		{
			case 'Kade Engine', 'VS Impostor': ' $divider Combo Breaks: ' + state.formattedSongMisses;
			case 'Doki Doki+': ' $divider Breaks: ' + state.formattedSongMisses;
			default:
				' $divider Misses: ' + state.formattedSongMisses;
		} : '');

		state.botText = state.cpuControlled && ClientPrefs.botWatermark ? ' $divider Botplay Mode' : '';

		if (state.cpuControlled && ClientPrefs.botWatermark)
			state.tempScore = 'Bot Score: ' + state.formattedScore + (state.comboInfo ? ' $divider Bot Combo: ' + state.formattedCombo : '') + state.npsString + state.botText;

		else switch (ClientPrefs.scoreStyle)
		{
			case 'Kade Engine', 'Doki Doki+':
				state.tempScore = 'Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Accuracy: ' + state.accuracy + ' $divider (' + state.fcString + ') ' + state.ratingName;

			case "Dave Engine":
				state.tempScore = 'Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Accuracy: ' + state.accuracy + ' $divider ' + state.fcString;

			case "Forever Engine":
				state.tempScore = 'Score: ' + state.formattedScore + ' $divider Accuracy: ${state.accuracy} ['  + state.fcString + ']' + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Rank: ' + state.ratingName;

			case "Psych Engine", "JS Engine", "TGT V4":
				state.tempScore = 'Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Rating: ' + state.ratingName + (state.ratingName != '?' ? ' (${state.accuracy}) - ${state.fcString}' : '');

			case "Leather Engine":
				state.tempScore = '< Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Rating: ' + state.ratingName + (state.ratingName != '?' ? ' (${state.accuracy}) - ${state.fcString}' : '');

			case 'VS Impostor':
				state.tempScore = 'Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Accuracy: ${state.accuracy} ['  + state.fcString + ']';

			case 'Vanilla':
				state.tempScore = 'Score: ' + state.formattedScore;
		}

		state.scoreTxt.text = '${state.tempScore}\n';

		state.callOnLuas('onUpdateScore', [miss]);
	}

	public static function RecalculateRating(state:PlayState, badHit:Bool = false) {
		state.setOnLuas('score', state.songScore);
		state.setOnLuas('misses', state.songMisses);
		state.setOnLuas('hits', state.songHits);
		state.setOnLuas('combo', state.combo);
		if (badHit) state.missRecalcsPerFrame += 1;

		var ret:Dynamic = state.callOnLuas('onRecalculateRating');
		#if LUA_ALLOWED
		if(ret != FunkinLua.Function_Stop)
		#else
		if(true)
		#end
		{
			if(state.totalPlayed < 1) //Prevent divide by 0
				state.ratingName = '?';
			else
			{
				// Rating Percent
				state.ratingPercent = Math.min(1, Math.max(0, state.totalNotesHit / state.totalPlayed));

			if (Math.isNaN(state.ratingPercent))
				state.ratingString = '?';

				// Rating Name

				if (PlayState.ratingStuff.length <= 0) {
					state.ratingName = 'Error!';
				}
				else {
					if(state.ratingPercent >= 1)
					{
						state.ratingName = PlayState.ratingStuff[PlayState.ratingStuff.length-1][0]; //Uses last string
					}
					else
					{
						for (i in 0...PlayState.ratingStuff.length-1)
						{
							if(state.ratingPercent < PlayState.ratingStuff[i][1])
							{
								state.ratingName = PlayState.ratingStuff[i][0];
								break;
							}
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
				(state.totalPlayed == 0), // 'No Play'
				(state.perfects > 0), // 'PFC'
				(state.sicks > 0), // 'SFC'
				(state.goods > 0), // 'GFC'
				(state.bads > 0), // 'BFC'
				(state.poorRatings > 0), // 'FC'
				(state.songMisses > 0 && state.songMisses < 10), // 'SDCB'
				(state.songMisses >= 10), // 'Clear'
				(state.songMisses >= 100), // 'TDCB'
				(state.songMisses >= 1000) // 'QDCB'
			];

			var cond:Int = fcConditions.length - 1;
			state.ratingFC = "";
			while (cond >= 0)
			{
				if (fcConditions[cond]) {
					state.ratingFC = state.fcStrings[cond];
					break;
				}
				cond--;
			}

			// basically same stuff, doesn't update every frame but it also means no memory leaks during botplay
			if (state.scoreTxt != null)
				updateScore(state, badHit);
		}

		state.setOnLuas('rating', state.ratingPercent);
		state.setOnLuas('ratingName', state.ratingName);
		state.setOnLuas('ratingFC', state.ratingFC);
	}

	// REFACTOR: NPS tracking block extracted from play.PlayState.update()
	public static function updateNps(state:PlayState)
	{
		if (ClientPrefs.showNPS && (state.notesHitDateArray.length > 0 || state.oppNotesHitDateArray.length > 0)) {
			var threshold = Conductor.songPosition - 1000 * state.npsSpeedMult;
			state.notesToRemoveCount = 0;
			var i = 0;

			while (i < state.notesHitDateArray.length) {
				if (Math.isNaN(state.notesHitDateArray[i])) {
					state.notesToRemoveCount++;
				} else if (state.notesHitDateArray[i] < threshold) {
					state.notesToRemoveCount++;
				} else {
					break;
				}
				i++;
			}

			if (state.notesToRemoveCount > 0) {
				state.notesHitDateArray.splice(0, state.notesToRemoveCount);
				state.notesHitArray.splice(0, state.notesToRemoveCount);
			}

			state.nps = 0;
			for (value in state.notesHitArray)
				state.nps += value;

			state.oppNotesToRemoveCount = 0;
			i = 0;

			while (i < state.oppNotesHitDateArray.length) {
				if (Math.isNaN(state.oppNotesHitDateArray[i])) {
					state.oppNotesToRemoveCount++;
				} else if (state.oppNotesHitDateArray[i] < threshold) {
					state.oppNotesToRemoveCount++;
				} else {
					break;
				}
				i++;
			}

			if (state.oppNotesToRemoveCount > 0) {
				state.oppNotesHitDateArray.splice(0, state.oppNotesToRemoveCount);
				state.oppNotesHitArray.splice(0, state.oppNotesToRemoveCount);
			}

			state.oppNPS = 0;
			for (value in state.oppNotesHitArray) {
				state.oppNPS += value;
			}

			if (state.oppNPS > state.maxOppNPS) {
				state.maxOppNPS = state.oppNPS;
			}
			if (state.nps > state.maxNPS) {
				state.maxNPS = state.nps;
			}

if (state.scoreTxtUpdateFrame <= 8 && state.scoreTxt != null) state.updateScore();
		}
	}

	#if ACHIEVEMENTS_ALLOWED
	// REFACTOR: achievement checking extracted from play.PlayState
	public static function checkForAchievement(state:PlayState, achievesToCheck:Array<String> = null)
	{
		if(PlayState.chartingMode || state.trollingMode) return;

		var usedPractice:Bool = (state.practiceMode || state.cpuControlled);
		if(state.cpuControlled) return;

		for (name in achievesToCheck) {
			if(!Achievements.exists(name)) continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (state.ratingPercent < 0.2 && !state.practiceMode);

					case 'ur_good':
						unlock = (state.ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (state.boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!state.boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && state.keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.cacheOnGPU && !ClientPrefs.shaders && ClientPrefs.lowQuality && !ClientPrefs.globalAntialiasing);

					case 'debugger':
						unlock = (state.songName == 'test' && !usedPractice);
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if(PlayState.isStoryMode && PlayState.campaignMisses + state.songMisses < 1 && CoolUtil.currentDifficulty.toUpperCase() == 'HARD'
					&& PlayState.storyPlaylist.length <= 1 && !PlayState.changedDifficulty && !usedPractice)
					unlock = true;
			}

			if(unlock) Achievements.unlock(name);
		}
	}
	#end
}
