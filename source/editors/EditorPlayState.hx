package editors;
import backend.Conductor;
import backend.ClientPrefs;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.MusicBeatState;
import backend.Paths;
import states.LoadingState;
import play.PlayState;
import data.Section;
import data.Song;
import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;

import objects.Character.CharacterFile;
import objects.Note.PreloadedChartNote;
import data.Section.SwagSection;
import data.Song.SwagSong;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSort;
import openfl.events.KeyboardEvent;
import play.objects.SustainSplash;

// REFACTOR: imports for relocated root classes
import backend.Controls;
import objects.Character;

// REFACTOR: helper for relocated static logic
import headers.Editors;

class EditorPlayState extends MusicBeatState
{
	// Yes, this is mostly a copy of PlayState, it's kinda dumb to make a direct copy of it but... ehhh
	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpHoldSplashes:FlxTypedGroup<SustainSplash>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var sustainNotes:FlxTypedGroup<Note>;
	public var notes:FlxTypedGroup<Note>;
	public var killNotes:Array<Note> = [];
	public var unspawnNotes:Array<PreloadedChartNote> = [];

	var generatedMusic:Bool = false;
	var vocals:FlxSound;
	var opponentVocals:FlxSound;
	var inst:FlxSound;

	var startOffset:Float = 0;
	var startPos:Float = 0;

	var pixelRatingPrefix:String = "";
	var pixelRatingSuffix:String = '';

	public function new(startPos:Float) {
		this.startPos = startPos;
		Conductor.songPosition = startPos - startOffset;

		startOffset = Conductor.crochet;
		timerToStart = startOffset;
		super();
	}

	var scoreTxt:FlxText;
	var stepTxt:FlxText;
	var beatTxt:FlxText;
	var sectionTxt:FlxText;
	var botplayTxt:FlxText;

	var timerToStart:Float = 0;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;

	public static var instance:EditorPlayState;
	private var layoutWidth:Int = 0;
	private var background:FlxSprite;
	private var tipText:FlxText;

	public static var cpuControlled:Bool = false;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		if (layoutWidth != 0 && layoutWidth != FlxG.width)
		{
			final shift:Float = ScreenLayout.contentLeft(FlxG.width) - ScreenLayout.contentLeft(layoutWidth);
			if (strumLineNotes != null) strumLineNotes.forEachAlive(strum -> strum.x += shift);
			for (group in [notes, sustainNotes])
				if (group != null) group.forEachAlive(note -> { if (note.copyX) note.x += shift; });
			for (text in [scoreTxt, stepTxt, beatTxt, sectionTxt, botplayTxt, tipText])
				if (text != null) text.x += shift;
		}
		layoutWidth = FlxG.width;
		ViewportVisuals.cover(background);
		if (stages != null) for (stage in stages) if (stage != null) stage.onViewportResize();
	}

	override function create()
	{
		layoutWidth = FlxG.width;
		instance = this;

		background = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		background.scrollFactor.set();
		background.color = FlxColor.fromHSB(FlxG.random.int(0, 359), FlxG.random.float(0, 0.8), FlxG.random.float(0.3, 1));
		ViewportVisuals.cover(background);
		add(background);

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		sustainNotes = new FlxTypedGroup<Note>();
		add(sustainNotes);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);

		generateStaticArrows(0);
		generateStaticArrows(1);

		notes = new FlxTypedGroup<Note>();
		add(notes);

		grpHoldSplashes = new FlxTypedGroup<SustainSplash>((ClientPrefs.maxSplashLimit != 0 ? ClientPrefs.maxSplashLimit : 10000));
		add(grpHoldSplashes);

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		add(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		SustainSplash.startCrochet = Conductor.stepCrochet;
		SustainSplash.frameRate = Math.floor(24 / 100 * PlayState.SONG.bpm);
		var splash:SustainSplash = new SustainSplash();
		grpHoldSplashes.add(splash);
		splash.visible = true;
		splash.alpha = 0.0001;

		Paths.initDefaultSkin(PlayState.SONG.arrowSkin);

		generateSong(startPos);

		scoreTxt = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, FlxG.height - 50, ScreenLayout.BASE_WIDTH - 20, "Hits: 0 | Misses: 0", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.hideHud;
		add(scoreTxt);

		sectionTxt = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, 550, ScreenLayout.BASE_WIDTH - 20, "Section: 0", 20);
		sectionTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		sectionTxt.scrollFactor.set();
		sectionTxt.borderSize = 1.25;
		add(sectionTxt);

		beatTxt = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, sectionTxt.y + 30, ScreenLayout.BASE_WIDTH - 20, "Beat: 0", 20);
		beatTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		beatTxt.scrollFactor.set();
		beatTxt.borderSize = 1.25;
		add(beatTxt);

		stepTxt = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, beatTxt.y + 30, ScreenLayout.BASE_WIDTH - 20, "Step: 0", 20);
		stepTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		stepTxt.scrollFactor.set();
		stepTxt.borderSize = 1.25;
		add(stepTxt);

		botplayTxt = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, stepTxt.y + 30, ScreenLayout.BASE_WIDTH - 20, "Botplay: OFF", 20);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		add(botplayTxt);

		tipText = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 10, FlxG.height - 44, 0, 'Press ESC to Go Back to Chart Editor\nPress SIX to turn on Botplay', 16);
		tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 2;
		tipText.scrollFactor.set();
		add(tipText);
		FlxG.mouse.visible = false;

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		Paths.initNote(PlayState.SONG.arrowSkin);
		Paths.initDefaultSkin(PlayState.SONG.arrowSkin);
		cachePopUpScore();

		super.create();
	}

	var songHits:Int = 0;
	var songMisses:Int = 0;
	var startingSong:Bool = true;
	private function generateSong(?startingPoint:Float = 0):Void
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.generateSong(this, startingPoint);
	}

	function startSong():Void
	{
		startingSong = false;
		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		FlxG.sound.music.time = startPos;
		vocals.volume = 1;
		vocals.time = startPos;
		vocals.play();
		opponentVocals.volume = 1;
		opponentVocals.time = startPos;
		opponentVocals.play();
	}

	function sortNotesByTime(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	private function endSong() {
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.endSong(this);
	}

	public var noteKillOffset:Float = 350;
	public var spawnTime:Float = 2000;
	public var notesAddedCount:Int = 0;
	override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
			LoadingState.loadAndSwitchState(editors.ChartingState.new);
		}
		if (FlxG.keys.justPressed.SIX)
		{
			cpuControlled = !cpuControlled;
		}

		if (startingSong) {
			timerToStart -= elapsed * 1000;
			Conductor.songPosition = startPos - timerToStart;
			if(timerToStart < 0) {
				startSong();
			}
		} else {
			Conductor.songPosition += elapsed * 1000;
		}

		if (unspawnNotes.length > 0 && (unspawnNotes[0] != null))
		{
			notesAddedCount = 0;

			if (notesAddedCount > unspawnNotes.length)
				notesAddedCount -= (notesAddedCount - unspawnNotes.length);

			while (unspawnNotes[notesAddedCount] != null && unspawnNotes[notesAddedCount].strumTime - Conductor.songPosition < (1500 / PlayState.SONG.speed / unspawnNotes[notesAddedCount].multSpeed)) {
				var newNote:Note = new Note();
				newNote.setupNoteData(unspawnNotes[notesAddedCount]);
				(unspawnNotes[notesAddedCount].isSustainNote ? sustainNotes : notes).add(newNote);

				notesAddedCount++;
			}
			if (notesAddedCount > 0)
				unspawnNotes.splice(0, notesAddedCount);
		}

		if (generatedMusic)
		{
			for (group in [notes, sustainNotes])
			{
				group.forEach(function(daNote)
				{
					updateNote(daNote);
				});

				destroyNotes();
				group.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
			}
			if (Conductor.songPosition >= FlxG.sound.music.length) endSong();
		}

		if (!cpuControlled) handleKeyInput();
		scoreTxt.text = 'Hits: ' + songHits + ' | Misses: ' + songMisses;
		sectionTxt.text = 'Section: ' + curSection;
		beatTxt.text = 'Beat: ' + curBeat;
		stepTxt.text = 'Step: ' + curStep;
		botplayTxt.text = 'Botplay: ' + (cpuControlled ? 'ON' : 'OFF');
		super.update(elapsed);
	}

	override public function onFocus():Void
	{
		for (i in [vocals, opponentVocals])
			if (i != null) i.play();

		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		for (i in [vocals, opponentVocals])
			if (i != null) i.pause();

		super.onFocusLost();
	}

	override function beatHit()
	{
		super.beatHit();

		if (generatedMusic)
		{
			for (group in [notes, sustainNotes])
				group.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}
	}

	override function stepHit()
	{
		if (FlxG.sound.music.time >= -ClientPrefs.noteOffset)
		{
			var timeSub:Float = Conductor.songPosition - Conductor.offset;
			var syncTime:Float = 20;
			if (Math.abs(FlxG.sound.music.time - timeSub) > syncTime ||
			(vocals.length > 0 && Math.abs(vocals.time - timeSub) > syncTime) ||
			(opponentVocals.length > 0 && Math.abs(opponentVocals.time - timeSub) > syncTime))
			{
				resyncVocals();
			}
		}
		super.stepHit();
	}

	function resyncVocals():Void
	{
		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = Conductor.songPosition;
		}

		if (Conductor.songPosition <= opponentVocals.length)
		{
			opponentVocals.time = Conductor.songPosition;
		}
		vocals.play();
		opponentVocals.play();
	}
	private function onKeyPress(event:KeyboardEvent):Void
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.onKeyPress(this, event);
	}

	function sortHitNotes(a:Note, b:Note):Int
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		return EditorPlayStateHelpers.sortHitNotes(a, b);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.onKeyRelease(this, event);
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		return EditorPlayStateHelpers.getKeyFromEvent(this, key);
	}

	private function handleKeyInput():Void
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.handleKeyInput(this);
	}

	function updateNote(daNote:Note):Void
	{
		if (daNote != null && daNote.exists)
		{
			inline daNote.followStrum((daNote.mustPress ? playerStrums : opponentStrums).members[daNote.noteData], PlayState.SONG.speed);
			final strum = (daNote.mustPress ? playerStrums : opponentStrums).members[daNote.noteData];
			if(daNote.isSustainNote && strum != null && strum.sustainReduce) inline daNote.clipToStrumNote(strum);

			if (!daNote.mustPress && daNote.strumTime <= Conductor.songPosition)
			{
				if (PlayState.SONG.needsVoices && opponentVocals.length <= 0)
					opponentVocals.volume = 1;

				var time:Float = 0.15;
				if(daNote.isSustainNote && !daNote.animation.curAnim.name.endsWith('end')) {
					time += 0.15;
				}
				if (ClientPrefs.noteColorStyle != 'Normal' && ClientPrefs.showNotes && ClientPrefs.enableColorShader) {
					inline opponentStrums.members[daNote.noteData].playAnim('confirm', true, daNote.rgbShader.r, daNote.rgbShader.g, daNote.rgbShader.b);
				} else {
					inline opponentStrums.members[daNote.noteData].playAnim('confirm', true);
				}
				opponentStrums.members[daNote.noteData].resetAnim = calculateResetTime(daNote.isSustainNote);
				daNote.hitByOpponent = true;

				if (!daNote.isSustainNote) invalidateNote(daNote);
			}

			if (daNote.mustPress && cpuControlled && daNote.strumTime <= Conductor.songPosition)
			{
				if (PlayState.SONG.needsVoices)
					vocals.volume = 1;
				goodNoteHit(daNote);
			}
			if (!daNote.exists) return;

			if (Conductor.songPosition > (noteKillOffset / PlayState.SONG.speed) + daNote.strumTime)
			{
				if (daNote.mustPress)
				{
					if (daNote.tooLate || !daNote.wasGoodHit)
					{
						//Dupe note remove
						for (group in [notes, sustainNotes]) group.forEachAlive(function(note:Note) {
							if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 10) {
								invalidateNote(daNote);
							}
						});

						if(!daNote.ignoreNote) {
							songMisses++;
							vocals.volume = 0;
						}
					}
				}
				invalidateNote(daNote);
			}
		}
	}

	var combo:Int = 0;
	function goodNoteHit(?note:Note):Void
	{
		if (note != null && !note.wasGoodHit)
		{
			switch(note.noteType) {
				case 'Hurt Note': //Hurt note
					noteMiss();
					--songMisses;
					if(!note.isSustainNote) {
						if(!note.noteSplashDisabled) {
							spawnNoteSplashOnNote(note);
						}
					}

					note.wasGoodHit = true;
					vocals.volume = 0;
					return;
			}

			if (!note.isSustainNote)
			{
				combo += 1;
				if (!cpuControlled) popUpScore(note);
				songHits++;
			}

			if (cpuControlled)
			{
				if(playerStrums.members[note.noteData] != null) {
					if (ClientPrefs.noteColorStyle != 'Normal' && ClientPrefs.showNotes && ClientPrefs.enableColorShader) {
						inline playerStrums.members[note.noteData].playAnim('confirm', true, note.rgbShader.r, note.rgbShader.g, note.rgbShader.b);
					} else {
						inline playerStrums.members[note.noteData].playAnim('confirm', true);
					}
					playerStrums.members[note.noteData].resetAnim = calculateResetTime(note.isSustainNote);
				}
			}
			else
			{
				final spr = playerStrums.members[note.noteData];
				if(spr != null)
				{
					if (ClientPrefs.noteColorStyle != 'Normal' && ClientPrefs.showNotes && ClientPrefs.enableColorShader) {
						inline spr.playAnim('confirm', true, note.rgbShader.r, note.rgbShader.g, note.rgbShader.b);
					} else {
						inline spr.playAnim('confirm', true);
					}
				}
			}

			if (ClientPrefs.noteSplashes && note.isSustainNote) spawnHoldSplashOnNote(note);

			if (!note.isSustainNote) invalidateNote(note);

			note.wasGoodHit = true;
			vocals.volume = 1;
		}
	}

	function noteMiss():Void
	{
		combo = 0;

		songMisses++;

		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		vocals.volume = 0;
	}

	public function invalidateNote(note:Note):Void {
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.invalidateNote(this, note);
	}

	public function destroyNotes():Void
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.destroyNotes(this);
	}

	function calculateResetTime(?sustainNote:Bool = false):Float {
		if (ClientPrefs.strumLitStyle == 'BPM Based') return (Conductor.stepCrochet * 1.5 / 1000) * (!sustainNote ? 1 : 2);
		return 0.15 * (!sustainNote ? 1 : 2);
	}

		private function cachePopUpScore()
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.cachePopUpScore(this);
	}

	var COMBO_X:Float = 400;
	var COMBO_Y:Float = 340;
	private function popUpScore(note:Note = null):Void
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.popUpScore(this, note);
	}

	private function generateStaticArrows(player:Int):Void
	{
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.generateStaticArrows(this, player);
	}


	// For Opponent's notes glow
	function StrumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = strumLineNotes.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public function spawnHoldSplashOnNote(note:Note, ?isDad:Bool = false) {
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.spawnHoldSplashOnNote(this, note, isDad);
	}

	public function spawnHoldSplash(note:Note) {
		// REFACTOR: delegated to editors.helpers.EditorPlayStateHelpers
		EditorPlayStateHelpers.spawnHoldSplash(this, note);
	}

	// Note splash shit, duh
	function spawnNoteSplashOnNote(note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		grpNoteSplashes.add(splash);
	}

	function loadCharacterFile(char:String):CharacterFile {
		var characterPath:String = 'characters/' + char + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) {
			path = Paths.getPreloadPath(characterPath);
		}

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!OpenFlAssets.exists(path))
		#end
		{
			path = Paths.getPreloadPath('characters/' + Character.DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = OpenFlAssets.getText(path);
		#end
		return cast Json.parse(rawJson);
	}

	override function destroy() {
		FlxG.sound.music.stop();
		vocals.stop();
		vocals.destroy();

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		super.destroy();
	}
}

