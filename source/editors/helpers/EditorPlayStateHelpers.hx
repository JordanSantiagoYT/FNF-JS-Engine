package editors.helpers;

// REFACTOR: explicit imports for relocated static helpers
import backend.ClientPrefs;
import backend.ScreenLayout;
import backend.Conductor;
import backend.CoolUtil;
import backend.MusicBeatState;
import backend.Paths;

import editors.EditorPlayState;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;

import objects.Note;
import objects.Note.PreloadedChartNote;
import objects.StrumNote;

import openfl.events.KeyboardEvent;

import play.PlayState;
import play.objects.SustainSplash;

import states.LoadingState;

// REFACTOR: chart/input/note/popup/gameplay helpers extracted from editors.EditorPlayState (behavior-preserving)
@:access(editors.EditorPlayState)
@:access(backend.MusicBeatState)
class EditorPlayStateHelpers
{
	public static function generateSong(state:EditorPlayState, ?startingPoint:Float = 0):Void
	{
		#if sys
	   	final startTime = Sys.time();
		#else
		final startTime = haxe.Timer.stamp();
		#end

		Conductor.changeBPM(PlayState.SONG.bpm);

		if (PlayState.SONG.windowName != null && PlayState.SONG.windowName != '')
			MusicBeatState.windowNamePrefix = PlayState.SONG.windowName;

		var songData = PlayState.SONG;

		var diff:String = (songData.specialAudioName.length > 1 ? songData.specialAudioName : CoolUtil.difficultyString()).toLowerCase();

		Conductor.bpm = songData.bpm;

		var boyfriendVocals:String = state.loadCharacterFile(PlayState.SONG.player1).vocals_file;
		var dadVocals:String = state.loadCharacterFile(PlayState.SONG.player2).vocals_file;

		state.vocals = new FlxSound();
		state.opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.voices(songData.song, diff, (boyfriendVocals == null || boyfriendVocals.length < 1) ? 'Player' : boyfriendVocals);
				state.vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(songData.song, diff));

				var oppVocals = Paths.voices(songData.song, diff, (dadVocals == null || dadVocals.length < 1) ? 'Opponent' : dadVocals);
				if(oppVocals != null) state.opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch(e:Dynamic) {}

		state.vocals.volume = 0;
		state.opponentVocals.volume = 0;

		FlxG.sound.list.add(state.vocals);
		FlxG.sound.list.add(state.opponentVocals);
		state.inst = new FlxSound().loadEmbedded(Paths.inst(songData.song, diff));
		FlxG.sound.list.add(state.inst);
		FlxG.sound.music.volume = 0;

		var currentBPMLol:Float = Conductor.bpm;
		for (section in songData.notes) {
			if (section.changeBPM) currentBPMLol = section.bpm;

			for (songNotes in section.sectionNotes) {
				if (songNotes[0] >= startingPoint) {
					final daStrumTime:Float = songNotes[0];
					var daNoteData:Int = Std.int(songNotes[1] % 4);

					final gottaHitNote:Bool = (songNotes[1] < 4 ? section.mustHitSection : !section.mustHitSection);

					final swagNote:PreloadedChartNote = {
						strumTime: daStrumTime,
						noteData: daNoteData,
						mustPress: gottaHitNote,
						oppNote: !gottaHitNote,
						noteType: songNotes[3],
						animSuffix: (songNotes[3] == 'Alt Animation' || section.altAnim ? '-alt' : ''),
						noteskin: null,
						gfNote: songNotes[3] == 'GF Sing' || (section.gfSection && songNotes[1] < 4),
						noAnimation: songNotes[3] == 'No Animation',
						noMissAnimation: songNotes[3] == 'No Animation',
						sustainLength: songNotes[2],
						hitHealth: 0.023,
						missHealth: songNotes[3] != 'Hurt Note' ? 0.0475 : 0.3,
						wasHit: false,
						hitCausesMiss: songNotes[3] == 'Hurt Note',
						multSpeed: 1,
						multAlpha: 1,
						noteDensity: 1,
						ignoreNote: songNotes[3] == 'Hurt Note' && gottaHitNote
					};
					if (swagNote.noteskin?.length > 0 && !Paths.noteSkinFramesMap.exists(swagNote.noteskin)) Paths.initNote(swagNote.noteskin);

					if(!Std.isOfType(songNotes[3], String)) swagNote.noteType = editors.ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts

					inline state.unspawnNotes.push(swagNote);

					var ratio:Float = Conductor.bpm / currentBPMLol;

					final floorSus:Int = Math.floor(swagNote.sustainLength / Conductor.stepCrochet);
					if (floorSus > 0) {
						for (susNote in 0...floorSus + 1) {
							final sustainNote:PreloadedChartNote = {
								strumTime: daStrumTime + (Conductor.stepCrochet * susNote),
								noteData: daNoteData,
								mustPress: gottaHitNote,
								noteType: songNotes[3],
								animSuffix: (songNotes[3] == 'Alt Animation' || section.altAnim ? '-alt' : ''),
								noteskin: '',
								gfNote: songNotes[3] == 'GF Sing' || (section.gfSection && songNotes[1] < 4),
								noAnimation: songNotes[3] == 'No Animation',
								isSustainNote: true,
								isSustainEnd: susNote == floorSus,
								sustainLength: 0,
								parentST: swagNote.strumTime,
								parentSL: swagNote.sustainLength,
								hitHealth: 0.023,
								missHealth: 0.0475,
								wasHit: false,
								multSpeed: 1,
								multAlpha: 1,
								noteDensity: 1,
								hitCausesMiss: songNotes[3] == 'Hurt Note',
								ignoreNote: songNotes[3] == 'Hurt Note' && swagNote.mustPress
							};
							inline state.unspawnNotes.push(sustainNote);
							//Sys.sleep(0.0001);
						}
					}
				}
			}
		}

		if (ClientPrefs.noteColorStyle == 'Char-Based')
		{
			for (note in state.notes){
				if (note == null)
					continue;
				note.updateRGBColors();
			}
		}

		state.unspawnNotes.sort((a, b) -> sortByTime(state, a, b));

		state.generatedMusic = true;

		#if sys
		var endTime = Sys.time();
		#else
		var endTime = haxe.Timer.stamp();
		#end

		openfl.system.System.gc();

		var elapsedTime = endTime - startTime;

		trace('Done! The chart was loaded in ' + elapsedTime + " seconds.");
	}

	static function sortByTime(state:EditorPlayState, Obj1:Dynamic, Obj2:Dynamic):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	public static function endSong(state:EditorPlayState) {
		Conductor.songPosition = 0;
		FlxG.sound.music.stop();
		state.vocals.pause();
		state.vocals.destroy();
		state.opponentVocals.pause();
		state.opponentVocals.destroy();
		LoadingState.loadAndSwitchState(editors.ChartingState.new);
	}

	public static function onKeyPress(state:EditorPlayState, event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(state, eventKey);
		//trace('Pressed: ' + eventKey);

		if (key > -1 && (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || ClientPrefs.controllerMode))
		{
			if(state.generatedMusic)
			{
				//more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.ghostTapping;

				// obtain notes that the player can hit
				var plrInputNotes:Array<Note> = state.notes.members.filter(function(n:Note):Bool {
					var canHit:Bool = n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
					// trace('[keyPressed] Note? ${n != null}, noteData=${n.noteData}, strumTime=${n.strumTime}, canHit=$canHit, mustPress=${n.mustPress}, tooLate=${n.tooLate}, wasGoodHit=${n.wasGoodHit}, Conductor=${Conductor.songPosition}');
					return n != null && canHit && !n.isSustainNote && n.noteData == key;
				});
				plrInputNotes.sort((a, b) -> sortHitNotes(a, b));

				if (plrInputNotes.length != 0) {
					var funnyNote:Note = plrInputNotes[0]; // front note

					if (plrInputNotes.length > 1) {
						var doubleNote:Note = plrInputNotes[1];

						//if the note has the same notedata and doOppStuff indicator as funnynote, then do the check
						if (doubleNote.noteData == funnyNote.noteData && doubleNote.doOppStuff == funnyNote.doOppStuff) {
							// if the note has a 0ms distance (is on top of the current note), kill it
							if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
								invalidateNote(state, doubleNote);
							else if (doubleNote.strumTime < funnyNote.strumTime)
							{
								// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
								funnyNote = doubleNote;
							}
						}
						else state.goodNoteHit(doubleNote); //otherwise, hit doubleNote instead of killing it
					}
					state.goodNoteHit(funnyNote);
					if (plrInputNotes.length > 2 && ClientPrefs.ezSpam) {
						for (i in 1...plrInputNotes.length) state.goodNoteHit(plrInputNotes[i]);
					}
				}
				else if (canMiss && ClientPrefs.ghostTapping) {
					state.noteMiss();
				}

				//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = state.playerStrums.members[key];
			if(spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
		}
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	public static function onKeyRelease(state:EditorPlayState, event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(state, eventKey);
		if(key > -1)
		{
			var spr:StrumNote = state.playerStrums.members[key];
			if(spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
		}
		//trace('released: ' + controlArray);
	}

	public static function getKeyFromEvent(state:EditorPlayState, key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...state.keysArray.length)
			{
				for (j in 0...state.keysArray[i].length)
				{
					if(key == state.keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	public static function handleKeyInput(state:EditorPlayState):Void
	{
		// HOLDING
		var up = state.controls.NOTE_UP;
		var right = state.controls.NOTE_RIGHT;
		var down = state.controls.NOTE_DOWN;
		var left = state.controls.NOTE_LEFT;
		var controlHoldArray:Array<Bool> = [left, down, up, right];

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [state.controls.NOTE_LEFT_P, state.controls.NOTE_DOWN_P, state.controls.NOTE_UP_P, state.controls.NOTE_RIGHT_P];
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyPress(state, new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, state.keysArray[i][0]));
				}
			}
		}

		// FlxG.watch.addQuick('asdfa', upP);
		if (state.generatedMusic)
		{
			// rewritten inputs???
			for (group in [state.notes, state.sustainNotes]) group.forEachAlive(function(daNote:Note)
			{
				// hold note functions
				if (daNote.isSustainNote && controlHoldArray[daNote.noteData] && daNote.canBeHit
				&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit) {
					state.goodNoteHit(daNote);
				}
			});
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [state.controls.NOTE_LEFT_R, state.controls.NOTE_DOWN_R, state.controls.NOTE_UP_R, state.controls.NOTE_RIGHT_R];
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyRelease(state, new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, state.keysArray[i][0]));
				}
			}
		}
	}

	public static function invalidateNote(state:EditorPlayState, note:Note):Void {
		if (!state.killNotes.contains(note))
			state.killNotes.push(note);
	}

	public static function destroyNotes(state:EditorPlayState):Void
	{
		final iterator:Iterator<Note> = state.killNotes.iterator();

		while (iterator.hasNext())
		{
			final note:Note = iterator.next();
			note.active = note.visible = false;
			if (!ClientPrefs.lowQuality || !EditorPlayState.cpuControlled)
				note.kill();
			(note.isSustainNote ? state.sustainNotes : state.notes).remove(note, true);
			note.destroy();
		}
		state.killNotes = [];
	}

	public static function cachePopUpScore(state:EditorPlayState)
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
	}

	public static function popUpScore(state:EditorPlayState, note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset);

		state.vocals.volume = 1;

		var rating:FlxSprite = new FlxSprite();

		var daRating:String = "sick";

		if (noteDiff > Conductor.safeZoneOffset * 0.75)
		{
			daRating = 'shit';
			//score = 50;
		}
		else if (noteDiff > Conductor.safeZoneOffset * 0.5)
		{
			daRating = 'bad';
			//score = 100;
		}
		else if (noteDiff > Conductor.safeZoneOffset * 0.25)
		{
			daRating = 'good';
			//score = 200;
		}

		if(daRating == 'sick' && !note.noteSplashDisabled)
		{
			state.spawnNoteSplashOnNote(note);
		}

		rating.loadGraphic(Paths.image(state.pixelRatingPrefix + daRating + state.pixelRatingSuffix));
		rating.screenCenter();
		rating.x = state.COMBO_X - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.visible = !ClientPrefs.hideHud;
		rating.x += ClientPrefs.comboOffset[0];
		rating.y -= ClientPrefs.comboOffset[1];

		state.add(rating);

		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = ClientPrefs.globalAntialiasing;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * PlayState.daPixelZoom * 0.85));
		}
		rating.updateHitbox();

		var seperatedScore:Array<String> = (state.combo + "").split('');

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(state.pixelRatingPrefix + 'num' + i + state.pixelRatingSuffix));
			numScore.screenCenter();
			numScore.x = state.COMBO_X + (43 * daLoop) - 90;
			numScore.y += 80;

			numScore.x += ClientPrefs.comboOffset[2];
			numScore.y -= ClientPrefs.comboOffset[3];

			if (!PlayState.isPixelStage)
			{
				numScore.antialiasing = ClientPrefs.globalAntialiasing;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * PlayState.daPixelZoom));
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);
			numScore.visible = !ClientPrefs.hideHud;

			state.insert(state.members.indexOf(state.strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002
			});

			daLoop++;
		}

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
	}

	public static function generateStaticArrows(state:EditorPlayState, player:Int):Void
	{
		final strumLine:FlxPoint = FlxPoint.get(ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X, (ClientPrefs.downScroll) ? FlxG.height - 150 : 50);
		for (i in 0...4)
		{
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if(!ClientPrefs.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLine.x, strumLine.y, i, player);
			babyArrow.alpha = targetAlpha;
			babyArrow.downScroll = ClientPrefs.downScroll;

			if (player == 1)
			{
				state.playerStrums.add(babyArrow);
			}
			else
			{
				if(ClientPrefs.middleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) { //Up and Right
						babyArrow.x += ScreenLayout.BASE_WIDTH / 2 + 25;
					}
				}
				state.opponentStrums.add(babyArrow);
			}

			state.strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
		strumLine.put();
	}

	public static function spawnHoldSplashOnNote(state:EditorPlayState, note:Note, ?isDad:Bool = false) {
		if (!ClientPrefs.noteSplashes || note == null)
			return;

		if (note != null) {
			var strum:StrumNote = (isDad ? state.playerStrums : state.opponentStrums).members[note.noteData];
			final susLength:Float = (!note.isSustainNote ? note.sustainLength : note.parentSL);
			final tailLength:Int = Math.floor(susLength / Conductor.stepCrochet);

			if(strum != null && tailLength != 0)
				spawnHoldSplash(state, note);
		}
	}

	public static function spawnHoldSplash(state:EditorPlayState, note:Note) {
		var end:Note = note;
		var splash:SustainSplash = state.grpHoldSplashes.recycle(SustainSplash);
		splash.setupSusSplash((note.mustPress ? state.playerStrums : state.opponentStrums).members[note.noteData], note, 1);
		state.grpHoldSplashes.add(end.noteHoldSplash = splash);
	}
}
