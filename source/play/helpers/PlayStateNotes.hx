package play.helpers;

import backend.ClientPrefs;
import backend.Conductor;

import objects.Character;
import objects.Note;
import objects.Note.PreloadedChartNote;

import play.BaseStage;

import play.PlayState;

import play.helpers.PlayStateNoteHelpers;
import play.helpers.PlayStatePlayback;
import play.helpers.PlayStateRating;

import shaders.CrossFade;

// REFACTOR: note hit/miss/spawn logic extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateNotes
{
	public static function noteMiss(state:PlayState, daNote:Note = null, daNoteAlt:PreloadedChartNote = null):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		if (daNote != null)
		{
			// trace(daNote.toString());

			if (state.combo > 0)
				state.combo = 0;
			else state.combo -= 1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
			if (state.health > 0 && !state.usingBotEnergy)
			{
				state.health -= daNote.missHealth * state.healthLoss;
			}

			if(state.instakillOnMiss || state.sickOnly)
			{
				state.vocals.volume = state.opponentVocals.volume = 0;
				state.doDeathCheck(true);
			}

			state.songMisses += 1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
			if (PlayState.SONG.needsVoices && !state.ffmpegMode)
				if (PlayState.opponentChart && state.opponentVocals != null && state.opponentVocals.volume != 0) state.opponentVocals.volume = 0;
				else if (!PlayState.opponentChart && state.vocals.volume != 0 || state.vocals.volume != 0) state.vocals.volume = 0;
			if (!state.practiceMode)
				state.songScore -= 10 * Std.int((PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF));

			state.totalPlayed++;
			if (state.missRecalcsPerFrame <= 3) PlayStateRating.RecalculateRating(state, true);

			final char:Character = !daNote.gfNote ? !PlayState.opponentChart ? state.boyfriend : state.dad : state.gf;

			if(char != null && !daNote.noMissAnimation && char.hasMissAnimations && ClientPrefs.charsAndBG)
			{
				var animToPlay:String = state.singAnimations[Std.int(Math.abs(daNote.noteData))] + 'miss' + daNote.animSuffix;
				char.playAnim(animToPlay, true);
			}
			if (state.scoreTxtUpdateFrame <= 4 && state.scoreTxt != null) state.updateScore();

			daNote.tooLate = true;

			if (state.usingBotEnergy)
			{
				if (state.missResetTimer <= 0.1)
				{
					if (!state.notesBeingMissed) state.notesBeingMissed = true;
					state.missResetTimer += 0.01 / state.playbackRate;
				}
			}

			if (daNote.noteHoldSplash != null) {
				daNote.noteHoldSplash.kill();
			}

			state.stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
			if (state.hasActiveScripts())
				state.callOnLuas('noteMiss', [(daNote.isSustainNote ? state.sustainNotes : state.notes).members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
			if (ClientPrefs.missRating && ClientPrefs.ratingPopups) PlayStateRating.popUpScore(state, daNote, true);
		}
		if (daNoteAlt != null)
		{
			if (state.combo > 0)
				state.combo = 0;
			else state.combo -= 1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
			if (state.health > 0)
			{
				state.health -= daNoteAlt.missHealth * state.healthLoss;
			}

			if(state.instakillOnMiss)
			{
				(PlayState.opponentChart ? state.opponentVocals : state.vocals).volume = 0;
				state.doDeathCheck(true);
			}

			state.songMisses += 1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
			(PlayState.opponentChart ? state.opponentVocals : state.vocals).volume = 0;
			if (!state.practiceMode)
				state.songScore -= 10 * Std.int((PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF));

			state.totalPlayed++;
			if (state.missRecalcsPerFrame <= 3) PlayStateRating.RecalculateRating(state, true);

			final char:Character = !daNoteAlt.gfNote ? !PlayState.opponentChart ? state.boyfriend : state.dad : state.gf;

			if(char != null && !daNoteAlt.noMissAnimation && char.hasMissAnimations && ClientPrefs.charsAndBG)
			{
				var animToPlay:String = state.singAnimations[Std.int(Math.abs(daNoteAlt.noteData))] + 'miss' + daNoteAlt.animSuffix;
				char.playAnim(animToPlay, true);
			}
			if (state.scoreTxtUpdateFrame <= 4 && state.scoreTxt != null) state.updateScore();

			state.callOnLuas('noteMiss', [null, daNoteAlt.noteData, daNoteAlt.noteType, daNoteAlt.isSustainNote]);
		}
	}

	public static function noteMissPress(state:PlayState, direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.ghostTapping) return; //fuck it

		if (!state.boyfriend.stunned)
		{
			state.health -= 0.05 * state.healthLoss;
			if(state.instakillOnMiss)
			{
				(PlayState.opponentChart ? state.opponentVocals : state.vocals).volume = 0;
				state.doDeathCheck(true);
			}

			if (state.combo > 5 && state.gf != null && state.gf.animOffsets.exists('sad'))
			{
				state.gf.playAnim('sad');
			}
			state.combo = 0;

			if(!state.practiceMode) state.songScore -= 10;
			if(!state.endingSong) {
				state.songMisses++;
			}
			state.totalPlayed++;
			PlayStateRating.RecalculateRating(state, true);

			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));

			var char:Character = state.boyfriend;
			if (PlayState.opponentChart) char = state.dad;
			if(char.hasMissAnimations) {
				char.playAnim(state.singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
			}
			(PlayState.opponentChart ? state.opponentVocals : state.vocals).volume = 0;
		}
		if (state.scoreTxtUpdateFrame <= 4 && state.scoreTxt != null) state.updateScore();

		state.stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		state.callOnLuas('noteMissPress', [direction]);
	}

	public static function spawnNotes(state:PlayState)
	{
		if (state.unspawnNotes[state.notesAddedCount] != null)
		{
			//notesAddedCount = 0;
			state.NOTE_SPAWN_TIME = (ClientPrefs.dynamicSpawnTime ? (1600 / state.songSpeed) : 1600 * ClientPrefs.noteSpawnTime);
			state.targetNote = state.unspawnNotes[state.notesAddedCount];
			state.limitNC = (state.notes.countLiving() + state.sustainNotes.countLiving());

			if (state.targetNote != null && !state.targetNote.wasHit)
			{
				while (state.targetNote.strumTime <= Conductor.songPosition - ClientPrefs.noteOffset) {
					state.targetNote.wasHit = true;
					state.targetNote.mustPress ? goodNoteHit(state, null, state.targetNote) : opponentNoteHit(state, null, state.targetNote);
					state.notesAddedCount++;
					if (state.unspawnNotes[state.notesAddedCount+1] != null) state.targetNote = state.unspawnNotes[state.notesAddedCount];
					else break;
					state.skippedCount++;
					if (state.skippedCount > state.maxSkipped) state.maxSkipped = state.skippedCount;
				}
			}
			if (ClientPrefs.showNotes || !ClientPrefs.showNotes && !state.cpuControlled)
			{
				while (state.limitNC < state.noteLimit && state.targetNote.strumTime - Conductor.songPosition < (state.NOTE_SPAWN_TIME / state.targetNote.multSpeed)) {
					state.spawnedNote = (state.targetNote.isSustainNote ? state.sustainNotes : state.notes).recycle(Note);
					state.spawnedNote.setupNoteData(state.targetNote);

					if (!ClientPrefs.noSpawnFunc && state.hasActiveScripts()) state.callOnLuas('onSpawnNote', [(!state.spawnedNote.isSustainNote ? state.notes.members.indexOf(state.spawnedNote) : state.sustainNotes.members.indexOf(state.spawnedNote)), state.targetNote.noteData, state.targetNote.noteType, state.targetNote.isSustainNote]);
					state.notesAddedCount++; state.limitNC++;
					if (state.unspawnNotes[state.notesAddedCount+1] != null) state.targetNote = state.unspawnNotes[state.notesAddedCount];
					else break;
				}
			}
		}
	}

	public static function updateNote(state:PlayState, daNote:Note):Void
	{
		if (daNote != null && daNote.exists)
		{
			//first, process whether or not the note should be hit. this prevents pointless strum following
			if (!daNote.mustPress && !daNote.hitByOpponent && !daNote.ignoreNote && daNote.strumTime <= Conductor.songPosition)
				opponentNoteHit(state, daNote);

			if(daNote.mustPress) {
				if((state.cpuControlled || state.usingBotEnergy && state.strumsHeld[daNote.noteData]) && !daNote.wasGoodHit && daNote.strumTime <= Conductor.songPosition && !daNote.ignoreNote)
					goodNoteHit(state, daNote);
			}
			if (!daNote.exists) return;

			state.amountOfRenderedNotes += daNote.noteDensity;
			if (state.maxRenderedNotes < state.amountOfRenderedNotes) state.maxRenderedNotes = state.amountOfRenderedNotes;
			daNote.followStrum((daNote.mustPress ? state.playerStrums : state.opponentStrums).members[daNote.noteData], state.songSpeed);
			if (daNote.isSustainNote)
			{
				final strum = (daNote.mustPress ? state.playerStrums : state.opponentStrums).members[daNote.noteData];
				if (strum != null && strum.sustainReduce) daNote.clipToStrumNote(strum);
			}

			if (Conductor.songPosition > state.noteKillOffset + daNote.strumTime)
			{
				if (daNote.mustPress && (!(state.cpuControlled || state.usingBotEnergy && state.strumsHeld[daNote.noteData]) || state.cpuControlled) && !daNote.ignoreNote && !state.endingSong && !daNote.wasGoodHit) {
					noteMiss(state, daNote);
					if (ClientPrefs.missSoundEnabled)
					{
						FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
					}
				}
				PlayStateNoteHelpers.invalidateNote(state, daNote);
			}
		}
	}

	public static function goodNoteHit(state:PlayState, note:Note, noteAlt:PreloadedChartNote = null):Void
	{
		if (note != null)
		{
			if (PlayState.opponentChart || PlayState.bothSides && note.doOppStuff) {
				if (state.songName != 'tutorial' && !state.camZooming)
					state.camZooming = true;
			}
			if(!state.ffmpegMode && (note.wasGoodHit || state.cpuControlled && note.ignoreNote)) return;

			if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled && !note.isSustainNote)
			{
				state.hitsound.play(true);
				state.hitsound.pitch = state.playbackRate;
				#if sys
				var hitsoundImageExists = FileSystem.exists('assets/shared/images/' + state.hitsoundImageToLoad + '.png') || (#if MODS_ALLOWED FileSystem.exists(Paths.modFolders('images/' + state.hitsoundImageToLoad + '.png')) #else false #end);
				#else
				var hitsoundImageExists = OpenFlAssets.exists('assets/shared/images/' + state.hitsoundImageToLoad + '.png');
				#end
				if (hitsoundImageExists && state.hitImagesFrame < 4)
				{
					state.hitImagesFrame++;
					state.hitsoundImage = new FlxSprite().loadGraphic(Paths.image(state.hitsoundImageToLoad));
					state.hitsoundImage.antialiasing = ClientPrefs.globalAntialiasing;
					state.hitsoundImage.scrollFactor.set();
					state.hitsoundImage.setGraphicSize(Std.int(state.hitsoundImage.width / FlxG.camera.zoom));
					state.hitsoundImage.updateHitbox();
					state.hitsoundImage.screenCenter();
					state.hitsoundImage.alpha = 1;
					state.hitsoundImage.cameras = [state.camGame];
					state.add(state.hitsoundImage);
					FlxTween.tween(state.hitsoundImage, {alpha: 0}, 1 / (PlayState.SONG.bpm/100) / state.playbackRate, {
						onComplete: function(tween:FlxTween)
						{
							state.hitsoundImage.destroy();
						}
					});
				}
			}

			if(!note.hitCausesMiss) {
				if (!note.isSustainNote)
				{
					if (state.combo < 0) state.combo = 0;
					if ((PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF) > 1 && !note.isSustainNote) state.totalNotes += state.polyphonyBF - 1;
					state.missCombo = 0;
					state.combo += 1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
					state.totalNotesPlayed += 1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
					if (ClientPrefs.showNPS) { //i dont think we should be pushing to 2 arrays at the same time but oh well
						state.notesHitArray.push(1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF));
						state.notesHitDateArray.push(Conductor.songPosition);
					}
					if (!ClientPrefs.lessBotLag) PlayStateRating.popUpScore(state, note);
					else PlayStateRating.judgeNote(state, note);
					state.maxCombo = Math.max(state.maxCombo, state.combo);
				}

				if (!state.usingBotEnergy) state.health += note.hitHealth * state.healthGain * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);

				if (PlayState.bothSides) state.oppTrigger = PlayState.bothSides && note.doOppStuff;
				else if (PlayState.opponentChart && !state.oppTrigger) state.oppTrigger = true;
				state.doGf = note.gfNote;

				if(!note.noAnimation && ClientPrefs.charsAndBG) {
					state.animToPlay = state.singAnimations[Std.int(Math.abs(note.noteData))];

					state.playerChar = (state.doGf ? state.gf : (!state.oppTrigger ? state.boyfriend : state.dad));
					state.animCheck = (state.playerChar != state.gf ? 'hey' : 'cheer');
					if (note.animSuffix.length > 0 && state.playerChar.hasAnimation(state.animToPlay + note.animSuffix))
						state.animToPlay = state.singAnimations[Std.int(Math.abs(note.noteData))] + note.animSuffix;

					if (state.playerChar != null)
					{
						state.canPlay = (!note.isSustainNote || ClientPrefs.oldSusStyle && note.isSustainNote);
						if(note.isSustainNote)
						{
							state.holdAnim = state.animToPlay + '-hold';
							if(state.playerChar.animation.exists(state.holdAnim)) state.animToPlay = state.holdAnim;
							if(state.playerChar.getAnimationName() == state.holdAnim || state.playerChar.getAnimationName() == state.holdAnim + '-loop')
								state.canPlay = false;
						}

						if(state.canPlay) state.playerChar.playAnim(state.animToPlay, true);
						state.playerChar.holdTimer = 0;

						switch (note.noteType)
						{
							case 'Hey!':
								if(state.playerChar.hasAnimation(state.animCheck))
								{
									state.playerChar.playAnim(state.animCheck, true);
									state.playerChar.specialAnim = true;
									state.playerChar.heyTimer = 0.6;
								}
							case 'Cross Fade': // CF note
								if (ClientPrefs.crossFadeMode != 'Off')
								{
									new CrossFade(state.boyfriend, state.grpBFCrossFade, false);
								}
							case 'GF Cross Fade': // GFCF note
								if (ClientPrefs.crossFadeMode != 'Off')
								{
									new CrossFade(state.gf, state.grpGFCrossFade, false);
								}
						}
					}
				}

				var curSection:Int = Math.floor(state.curStep / 16);
				if (PlayState.SONG.notes[curSection] != null)
				{
					if (PlayState.SONG.notes[curSection].crossFade)
					{
						if (ClientPrefs.crossFadeMode != 'Off')
						{
							new CrossFade(state.boyfriend, state.grpBFCrossFade, false);
						}
					}
				}

				if((state.cpuControlled || state.usingBotEnergy && state.strumsHeld[note.noteData]) && ClientPrefs.botLightStrum && !state.strumsHit[(note.noteData % 4) + 4]) {
					state.strumsHit[(note.noteData % 4) + 4] = true;

					if(state.playerStrums.members[note.noteData] != null) {
						if (ClientPrefs.noteColorStyle != 'Normal' && ClientPrefs.showNotes && ClientPrefs.enableColorShader)
							state.playerStrums.members[note.noteData].playAnim('confirm', true, note.rgbShader.r, note.rgbShader.g, note.rgbShader.b);
						else
							state.playerStrums.members[note.noteData].playAnim('confirm', true);

						state.playerStrums.members[note.noteData].resetAnim = PlayStatePlayback.calculateResetTime(state);
					}
				} else if (ClientPrefs.playerLightStrum && !state.cpuControlled) {
					final spr = state.playerStrums.members[note.noteData];
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
					state.playerChar = state.boyfriend;
					switch(note.noteType)
					{
						case 'Hurt Note':
							if(state.playerChar.hasAnimation('hurt'))
							{
								state.playerChar.playAnim('hurt', true);
								state.playerChar.specialAnim = true;
							}
					}
				}

				noteMiss(state, note);
				if(!note.noteSplashData.disabled && !note.isSustainNote) PlayStateNoteHelpers.spawnNoteSplashOnNote(state, false, note);
			}

			if (state.playerChar != null && state.playerChar.shakeScreen)
			{
				state.camGame.shake(state.playerChar.shakeIntensity, state.playerChar.shakeDuration / state.playbackRate);
				state.camHUD.shake(state.playerChar.shakeIntensity / 2, state.playerChar.shakeDuration / state.playbackRate);
			}
			note.wasGoodHit = true;
			if (!ClientPrefs.lessBotLag && ClientPrefs.noteSplashes && note.isSustainNote && state.splashesPerFrame[3] <= 4) PlayStateNoteHelpers.spawnHoldSplashOnNote(state, note);
			if (PlayState.SONG.needsVoices && !state.ffmpegMode)
				if (PlayState.opponentChart && state.opponentVocals != null && state.opponentVocals.volume != 1) state.opponentVocals.volume = 1;
				else if (!PlayState.opponentChart && state.vocals.volume != 1 || state.vocals.volume != 1) state.vocals.volume = 1;

			if (!state.notesBeingHit && state.usingBotEnergy)
			{
				state.notesBeingHit = true;
				state.hitResetTimer = 0.3 / state.playbackRate;
			}

			if (!ClientPrefs.noHitFuncs)
			{
				if (state.hasActiveScripts())
					state.callOnLuas((state.oppTrigger ? 'opponentNoteHit' : 'goodNoteHit'), [(note.isSustainNote ? state.sustainNotes : state.notes).members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
				state.stagesFunc(function(stage:BaseStage) (state.oppTrigger ? stage.opponentNoteHit(note) : stage.goodNoteHit(note)));
			}

			if (!note.isSustainNote) PlayStateNoteHelpers.invalidateNote(state, note);
			if (state.scoreTxtUpdateFrame <= 4) state.updateScore();
			return;
		}
		if (noteAlt != null)
		{
			state.oppTrigger = PlayState.opponentChart || PlayState.bothSides && noteAlt.oppNote;
			if(noteAlt.noteType == 'Hey!')
			{
				state.playerChar = !noteAlt.gfNote ? state.oppTrigger ? state.dad : state.boyfriend : state.gf;
				if (state.playerChar.hasAnimation('hey')) {
					state.playerChar.playAnim('hey', true);
					state.playerChar.specialAnim = true;
					state.playerChar.heyTimer = 0.6;
				}
			}
			if(!noteAlt.noAnimation && ClientPrefs.charsAndBG) {
				state.playerChar = !noteAlt.gfNote ? state.oppTrigger ? state.dad : state.boyfriend : state.gf;
				if (state.playerChar != null)
				{
					state.playerChar.playAnim(state.singAnimations[(noteAlt.noteData)] + noteAlt.animSuffix, true);
					state.playerChar.holdTimer = 0;
				}
			}
			if(state.cpuControlled && !ClientPrefs.showNotes) {
				if (ClientPrefs.botLightStrum && !state.strumsHit[(noteAlt.noteData % 4) + 4])
				{
					state.strumsHit[(noteAlt.noteData % 4) + 4] = true;
					state.playerStrums.members[noteAlt.noteData].playAnim('confirm', true);
					state.playerStrums.members[noteAlt.noteData].resetAnim = PlayStatePlayback.calculateResetTime(state);
				}
			}
			if (!noteAlt.isSustainNote && state.cpuControlled)
			{
				state.combo += 1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
				state.songScore += (ClientPrefs.noMarvJudge ? 350 : 500) * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
				state.totalNotesPlayed += 1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
				if (ClientPrefs.showNPS) { //i dont think we should be pushing to 2 arrays at the same time but oh well
					state.notesHitArray.push(1 * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF));
					state.notesHitDateArray.push(Conductor.songPosition);
				}
				if ((PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF) > 1) state.totalNotes += (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF) - 1;
			}
			if (!ClientPrefs.noSkipFuncs) state.callOnLuas((state.oppTrigger ? 'opponentNoteSkip' : 'goodNoteSkip'), [null, Math.abs(noteAlt.noteData), noteAlt.noteType, noteAlt.isSustainNote]);
			state.health += noteAlt.hitHealth * state.healthGain * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
			if (!state.ffmpegMode) (PlayState.opponentChart ? state.opponentVocals : state.vocals).volume = 1;
		}
		return;
	}

	public static function opponentNoteHit(state:PlayState, daNote:Note, noteAlt:PreloadedChartNote = null):Void
	{
		if (daNote != null)
		{
			if (!PlayState.opponentChart && state.songName != 'tutorial' && !state.camZooming)
				state.camZooming = true;

			if(daNote.noteType == 'Hey!')
			{
				state.oppChar = !daNote.gfNote ? !PlayState.opponentChart ? state.dad : state.boyfriend : state.gf;
				if (state.oppChar.hasAnimation('hey')) {
					state.oppChar.playAnim('hey', true);
					state.oppChar.specialAnim = true;
					state.oppChar.heyTimer = 0.6;
				}
			} else if(!daNote.noAnimation && ClientPrefs.charsAndBG) {
				if (PlayState.SONG.notes[state.curSection] != null)
				{
					if (PlayState.SONG.notes[state.curSection].crossFade)
					{
						if (ClientPrefs.crossFadeMode != 'Off')
						{
							new CrossFade(state.dad, state.grpCrossFade);
						}
					}
				}

				if (daNote.noteType == 'Cross Fade')
				{
					if (ClientPrefs.crossFadeMode != 'Off')
					{
						new CrossFade(state.dad, state.grpCrossFade);
					}
				}

				if (daNote.noteType == 'GF Cross Fade')
				{
					if (ClientPrefs.crossFadeMode != 'Off')
					{
						new CrossFade(state.gf, state.grpGFCrossFade, false);
					}
				}
				state.oppChar = !daNote.gfNote ? !PlayState.opponentChart ? state.dad : state.boyfriend : state.gf;
				state.animToPlay = state.singAnimations[Std.int(Math.abs(daNote.noteData))];

				if (daNote.animSuffix.length > 0 && state.oppChar.hasAnimation(state.animToPlay + daNote.animSuffix))
					state.animToPlay = state.singAnimations[Std.int(Math.abs(daNote.noteData))] + daNote.animSuffix;

				if (state.oppChar != null)
				{
					state.canPlay = (!daNote.isSustainNote || ClientPrefs.oldSusStyle && daNote.isSustainNote);
					if(daNote.isSustainNote)
					{
						state.holdAnim = state.animToPlay + '-hold';
						if(state.oppChar.animation.exists(state.holdAnim)) state.animToPlay = state.holdAnim;
						if(state.oppChar.getAnimationName() == state.holdAnim || state.oppChar.getAnimationName() == state.holdAnim + '-loop')
							state.canPlay = false;
					}

					if(state.canPlay) state.oppChar.playAnim(state.animToPlay, true);
					state.oppChar.holdTimer = 0;
				}
			}

			if (!daNote.isSustainNote)
			{
				if (ClientPrefs.showNPS) { //i dont think we should be pushing to 2 arrays at the same time but oh well
					state.oppNotesHitArray.push(1 * state.polyphonyOppo);
					state.oppNotesHitDateArray.push(Conductor.songPosition);
				}
				state.enemyHits += 1 * state.polyphonyOppo;
				PlayStateNoteHelpers.invalidateNote(state, daNote);
			}

			if(ClientPrefs.oppNoteSplashes && !daNote.isSustainNote && state.splashesPerFrame[0] <= 4)
				PlayStateNoteHelpers.spawnNoteSplashOnNote(state, true, daNote);

			if (PlayState.SONG.needsVoices && !state.ffmpegMode)
				if (!PlayState.opponentChart && state.opponentVocals != null && state.opponentVocals.volume != 1) state.opponentVocals.volume = 1;
				else if (PlayState.opponentChart && state.vocals.volume != 1 || state.vocals.volume != 1) state.vocals.volume = 1;

			if (state.polyphonyOppo > 1 && !daNote.isSustainNote) state.opponentNoteTotal += state.polyphonyOppo - 1;

			if (ClientPrefs.opponentLightStrum && !state.strumsHit[daNote.noteData % 4])
			{
				state.strumsHit[daNote.noteData % 4] = true;

				if (ClientPrefs.noteColorStyle != 'Normal' && ClientPrefs.showNotes && ClientPrefs.enableColorShader)
					state.opponentStrums.members[daNote.noteData].playAnim('confirm', true, daNote.rgbShader.r, daNote.rgbShader.g, daNote.rgbShader.b);
				else
					state.opponentStrums.members[daNote.noteData].playAnim('confirm', true);

				state.opponentStrums.members[daNote.noteData].resetAnim = PlayStatePlayback.calculateResetTime(state);
			}
			daNote.hitByOpponent = true;

			if (ClientPrefs.oppNoteSplashes && daNote.isSustainNote && state.splashesPerFrame[2] <= 4) PlayStateNoteHelpers.spawnHoldSplashOnNote(state, daNote, true);

			if (!ClientPrefs.noHitFuncs)
			{
				if (state.hasActiveScripts())
					state.callOnLuas((!PlayState.opponentChart ? 'opponentNoteHit' : 'goodNoteHit'), [(daNote.isSustainNote ? state.sustainNotes : state.notes).members.indexOf(daNote), Math.abs(daNote.noteData), daNote.noteType, daNote.isSustainNote]);
				state.stagesFunc(function(stage:BaseStage) (!PlayState.opponentChart ? stage.opponentNoteHit(daNote) : stage.goodNoteHit(daNote)));
			}

			if (PlayState.shouldDrainHealth && state.health > (state.healthDrainFloor * state.polyphonyOppo) && !state.practiceMode || state.opponentDrain && state.practiceMode)
				state.health -= (state.opponentDrain ? daNote.hitHealth : state.healthDrainAmount) * state.hpDrainLevel * state.polyphonyOppo;

			if (state.oppChar != null && state.oppChar.shakeScreen)
			{
				state.camGame.shake(state.oppChar.shakeIntensity, state.oppChar.shakeDuration / state.playbackRate);
				state.camHUD.shake(state.oppChar.shakeIntensity / 2, state.oppChar.shakeDuration / state.playbackRate);
			}
			if (state.scoreTxtUpdateFrame <= 4) state.updateScore();
			return;
		}
		if (noteAlt != null)
		{
			if(noteAlt.noteType == 'Hey!')
			{
				state.oppChar = !noteAlt.gfNote ? !PlayState.opponentChart ? state.dad : state.boyfriend : state.gf;
				if (state.oppChar.animOffsets.exists('hey')) {
					state.oppChar.playAnim('hey', true);
					state.oppChar.specialAnim = true;
					state.oppChar.heyTimer = 0.6;
				}
			}
			if(!noteAlt.noAnimation && ClientPrefs.charsAndBG) {
				state.oppChar = !noteAlt.gfNote ? !PlayState.opponentChart ? state.dad : state.boyfriend : state.gf;
				state.animToPlay = state.singAnimations[Std.int(Math.abs(noteAlt.noteData))] + noteAlt.animSuffix;
				if (state.oppChar != null)
				{
					state.oppChar.playAnim(state.animToPlay, true);
					state.oppChar.holdTimer = 0;
				}
			}
			if (ClientPrefs.opponentLightStrum && !state.strumsHit[noteAlt.noteData % 4] && !ClientPrefs.showNotes)
			{
				state.strumsHit[noteAlt.noteData % 4] = true;
				state.opponentStrums.members[noteAlt.noteData].playAnim('confirm', true);
				state.opponentStrums.members[noteAlt.noteData].resetAnim = PlayStatePlayback.calculateResetTime(state);
			}
			if (!noteAlt.isSustainNote)
			{
				if (ClientPrefs.showNPS) { //i dont think we should be pushing to 2 arrays at the same time but oh well
					state.oppNotesHitArray.push(1 * state.polyphonyOppo);
					state.oppNotesHitDateArray.push(Conductor.songPosition);
				}
				state.enemyHits += 1 * state.polyphonyOppo;

				if (state.scoreTxtUpdateFrame <= 4) state.updateScore();

				if (PlayState.shouldDrainHealth && state.health > state.healthDrainFloor && !state.practiceMode || state.opponentDrain && state.practiceMode)
					state.health -= (state.opponentDrain ? noteAlt.hitHealth : state.healthDrainAmount) * state.hpDrainLevel * state.polyphonyOppo;
			}
			if ((!noteAlt.gfNote ? !PlayState.opponentChart ? state.dad : state.boyfriend : state.gf) != null && (!noteAlt.gfNote ? !PlayState.opponentChart ? state.dad : state.boyfriend : state.gf).shakeScreen)
			{
				state.oppChar = !noteAlt.gfNote ? !PlayState.opponentChart ? state.dad : state.boyfriend : state.gf;
				state.camGame.shake(state.oppChar.shakeIntensity, state.oppChar.shakeDuration / state.playbackRate);
				state.camHUD.shake(state.oppChar.shakeIntensity / 2, state.oppChar.shakeDuration / state.playbackRate);
			}
			if (!ClientPrefs.noSkipFuncs) state.callOnLuas((!PlayState.opponentChart ? 'opponentNoteSkip' : 'goodNoteSkip'), [null, Math.abs(noteAlt.noteData), noteAlt.noteType, noteAlt.isSustainNote]);
			if (PlayState.SONG.needsVoices && !state.ffmpegMode)
				if (!PlayState.opponentChart && state.opponentVocals != null && state.opponentVocals.volume != 1) state.opponentVocals.volume = 1;
				else if (PlayState.opponentChart && state.vocals.volume != 1 || state.vocals.volume != 1) state.vocals.volume = 1;
		}
		return;
	}
}
