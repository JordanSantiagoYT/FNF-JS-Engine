package play.helpers;

import flixel.util.FlxSort;
import backend.ClientPrefs;
import backend.Conductor;

import flixel.input.keyboard.FlxKey;

import openfl.events.KeyboardEvent;

import objects.Character;
import objects.Note;
import objects.StrumNote;

import play.PlayState;

import play.helpers.PlayStateCamera;
import play.helpers.PlayStateNoteHelpers;
import play.helpers.PlayStateNotes;

// REFACTOR: keyboard input logic extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateInput
{
	public static function onKeyPress(state:PlayState, event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(state, eventKey);

		if ((!ClientPrefs.controllerMode && FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) || (mobile.MobileControls.enabled && key > -1))
			keyPressed(state, key);
	}

	public static function keyPressed(state:PlayState, key:Int):Void
	{
		if(state.cpuControlled || state.paused || key < 0) return;
		if(!state.generatedMusic || state.endingSong || state.boyfriend.stunned) return;

		//more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if (Conductor.songPosition >= 0)
			Conductor.songPosition = FlxG.sound.music.time;

		var canMiss:Bool = !ClientPrefs.ghostTapping;

		// obtain notes that the player can hit
		var plrInputNotes:Array<Note> = state.notes.members.filter(function(n:Note):Bool {
			var canHit:Bool = !state.usingBotEnergy && !state.strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			// trace('[keyPressed] Note? ${n != null}, noteData=${n.noteData}, strumTime=${n.strumTime}, canHit=$canHit, mustPress=${n.mustPress}, tooLate=${n.tooLate}, wasGoodHit=${n.wasGoodHit}, Conductor=${Conductor.songPosition}');
			return n != null && n.exists && canHit && !n.isSustainNote && n.noteData == key;
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
						PlayStateNoteHelpers.invalidateNote(state, doubleNote);
					else if (doubleNote.strumTime < funnyNote.strumTime)
					{
						// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
						funnyNote = doubleNote;
					}
				}
				else PlayStateNotes.goodNoteHit(state, doubleNote); //otherwise, hit doubleNote instead of killing it
			}
			PlayStateNotes.goodNoteHit(state, funnyNote);
			if (plrInputNotes.length > 2 && ClientPrefs.ezSpam) {
				for (i in 1...plrInputNotes.length) PlayStateNotes.goodNoteHit(state, plrInputNotes[i]);
			}
		}
		else {
			state.callOnLuas('onGhostTap', [key]);
			if (!PlayState.opponentChart && ClientPrefs.ghostTapAnim && ClientPrefs.charsAndBG)
			{
				state.boyfriend.playAnim(state.singAnimations[Std.int(Math.abs(key))], true);
				state.boyfriend.holdTimer = 0;
			}
			if (PlayState.opponentChart && ClientPrefs.ghostTapAnim && ClientPrefs.charsAndBG)
			{
				state.dad.playAnim(state.singAnimations[Std.int(Math.abs(key))], true);
				state.dad.holdTimer = 0;
			}
			if (canMiss) {
				PlayStateNotes.noteMissPress(state, key);
			}
		}

		state.keysPressed[key] = true;

		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;

		var spr:StrumNote = state.playerStrums.members[key];
		if(state.strumsBlocked[key] != true && spr != null && spr.animation != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}
		state.callOnLuas('onKeyPress', [key]);
	}

	public static function sortHitNotes(a:Dynamic, b:Dynamic):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	public static function onKeyRelease(state:PlayState, event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(state, eventKey);
		// trace('Pressed: ' + eventKey);

		if (!ClientPrefs.controllerMode || mobile.MobileControls.enabled && key > -1)
			keyReleased(state, key);
	}

	public static function keyReleased(state:PlayState, key:Int)
	{
		if (state.cpuControlled || !state.startedCountdown || state.paused)
			return;

		var spr:StrumNote = state.playerStrums.members[key];
		if (spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
		state.callOnLuas('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(state:PlayState, key:FlxKey):Int
	{
		if (key != NONE)
			for (i in 0...state.keysArray.length)
			{
				for (j in 0...state.keysArray[i].length)
				{
					if (key == state.keysArray[i][j])
						return i;
				}
			}

		return -1;
	}

	// Hold notes
	public static function handleKeyInput(state:PlayState):Void
	{
		// HOLDING
		parseKeys(state, state.holdArray);
		parseKeys(state, state.pressArray, '_P');
		parseKeys(state, state.releaseArray, '_R');
		state.strumsHeld = state.holdArray;
		state.strumHeldAmount = 0;
		for (i in 0...state.strumsHeld.length)
		{
			if (state.strumsHeld[i]) state.strumHeldAmount++;
		}

		// Touch controls report NOTE_* actions without generating keyboard events.
		if (ClientPrefs.controllerMode || mobile.MobileControls.enabled)
		{
			for (i in 0...state.pressArray.length)
			{
				// Physical keyboard presses already reach onKeyPress outside controller mode.
				if (state.pressArray[i] && state.strumsBlocked[i] != true
					&& (ClientPrefs.controllerMode || !FlxG.keys.anyJustPressed(state.keysArray[i])))
					keyPressed(state, i);
			}
		}

		var char:Character = state.boyfriend;
		if (PlayState.opponentChart) char = state.dad;
		final mobileC:mobile.flixel.FlxButton = @:privateAccess {(PlayState.instance != null && PlayState.instance.mobileControls != null) ? ((mobile.MobileControls.mode == "Hitbox") ? (PlayState.instance.mobileControls.hitbox != null ? PlayState.instance.mobileControls.hitbox.hints[4] : null) : (PlayState.instance.mobileControls.virtualPad != null ? PlayState.instance.mobileControls.virtualPad.buttonEx : null)) : null;}
		if (state.startedCountdown && !char.stunned && state.generatedMusic)
		{
			for (group in [state.notes, state.sustainNotes]){
				if (group.length > 0)
				{
					for (n in group.members)
					{ // I can't do a filter here, that's kinda awesome
						var canHit:Bool = (n != null && n.exists && !state.usingBotEnergy && !state.strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

						if (canHit && n.isSustainNote)
						{
							var released:Bool = !state.holdArray[n.noteData];

							if (!released)
								PlayStateNotes.goodNoteHit(state, n, null);
						}
					}
				}
			}

			if(ClientPrefs.charsAndBG && ((ClientPrefs.mobileCEx && ClientPrefs.mobileCExTaunt && mobileC != null && mobileC.justPressed) || FlxG.keys.anyJustPressed(state.tauntKey)) && !char.animation.curAnim.name.endsWith('miss') && char.specialAnim == false && ClientPrefs.spaceVPose){
				if (char.animOffsets.exists('hey'))
				{
					char.playAnim('hey', true);
					char.specialAnim = true;
					char.heyTimer = 0.59;
					FlxG.sound.play(Paths.sound('hey'));
					// trace("HEY!!");
				}
				else
					trace('Character doesnt have a hey animation!');
			}

			if (!state.holdArray.contains(true) || state.endingSong) {
				if (ClientPrefs.charsAndBG) PlayStateCamera.playerDance(state);
			}

			#if ACHIEVEMENTS_ALLOWED
			else state.checkForAchievement(['oversinging']);
			#end
		}

		if ((ClientPrefs.controllerMode || mobile.MobileControls.enabled) || state.strumsBlocked.contains(true))
		{
			if (state.releaseArray.contains(true))
			{
				for (i in 0...state.releaseArray.length)
				{
					// Like presses, polled releases use the lane directly and must not duplicate keyboard callbacks.
					if (state.strumsBlocked[i] == true || (state.releaseArray[i]
						&& (ClientPrefs.controllerMode || !FlxG.keys.anyJustReleased(state.keysArray[i]))))
						keyReleased(state, i);
				}
			}
		}
	}

	public static function parseKeys(state:PlayState, ret:Array<Bool>, ?suffix:String = ''):Void
	{
		switch (suffix)
		{
			case '_P':
				ret[0] = state.controls.NOTE_LEFT_P;
				ret[1] = state.controls.NOTE_DOWN_P;
				ret[2] = state.controls.NOTE_UP_P;
				ret[3] = state.controls.NOTE_RIGHT_P;
			case '_R':
				ret[0] = state.controls.NOTE_LEFT_R;
				ret[1] = state.controls.NOTE_DOWN_R;
				ret[2] = state.controls.NOTE_UP_R;
				ret[3] = state.controls.NOTE_RIGHT_R;
			case '':
				ret[0] = state.controls.NOTE_LEFT;
				ret[1] = state.controls.NOTE_DOWN;
				ret[2] = state.controls.NOTE_UP;
				ret[3] = state.controls.NOTE_RIGHT;
			default:
				for (i in 0...state.controlArray.length)
					ret[i] = Reflect.getProperty(state.controls, state.controlArray[i] + suffix);
		}
	}
}
