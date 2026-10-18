package play.helpers;

import backend.ClientPrefs;
import backend.ScreenLayout;
import objects.Note;
import objects.Popup;
import objects.StrumNote;
import play.PlayState;

/** Reflow only screen-space gameplay objects; stage/world positions stay put. */
@:access(play.PlayState)
class PlayStateLayout
{
	public static function resize(state:PlayState, oldWidth:Int):Void
	{
		if (oldWidth == FlxG.width) return;
		final shift:Float = ScreenLayout.contentLeft(FlxG.width) - ScreenLayout.contentLeft(oldWidth);

		if (shift != 0)
		{
			if (state.strumLineNotes != null)
				state.strumLineNotes.forEachAlive((strum:StrumNote) -> strum.x += shift);
			// Notes normally follow strums every update. Move the current frame as
			// well so a resize between update and draw cannot flash old positions.
			for (group in [state.notes, state.sustainNotes])
				if (group != null) group.forEachAlive((note:Note) -> { if (note.copyX) note.x += shift; });
			if (state.grpNoteSplashes != null)
				state.grpNoteSplashes.forEachAlive(splash -> splash.x += shift);
			if (state.popUpGroup != null)
				state.popUpGroup.forEachAlive((popup:Popup) -> popup.x += shift);

			if (state.timeTxt != null) state.timeTxt.x += shift;
			if (state.timeBar != null && state.timeBar.exists) state.timeBar.x += shift;
			if (state.timeBarBG != null && state.timeBarBG.exists) state.timeBarBG.x += shift;
			if (state.healthBar != null) state.healthBar.x += shift;
			if (state.healthBarBG != null) state.healthBarBG.x += shift;
			if (state.energyBar != null) state.energyBar.x += shift;
			if (state.energyBarBG != null) state.energyBarBG.x += shift;
			if (state.energyTxt != null) state.energyTxt.x += shift;
			if (state.botplayTxt != null) state.botplayTxt.x += shift;
			if (state.EngineWatermark != null) state.EngineWatermark.x += shift;
			if (state.msTxt != null && state.msTxt.visible) state.msTxt.x += shift;
			if (state.healthBar != null && state.iconP1 != null && state.iconP2 != null)
				PlayStateCamera.updateIconsPosition(state);
		}

		if (state.scoreTxt != null) state.scoreTxt.fieldWidth = FlxG.width;
		if (state.renderedTxt != null) state.renderedTxt.fieldWidth = FlxG.width;
		if (state.botplayTxt != null) state.botplayTxt.fieldWidth = ScreenLayout.BASE_WIDTH - 800;
		if (state.stages != null)
			for (stage in state.stages) if (stage != null) stage.onViewportResize();
	}
}
