package states;

import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;
import backend.Paths;
import backend.PlayerSettings;
import flixel.FlxState;

import backend.Achievements;
#if ACHIEVEMENTS_ALLOWED
import backend.PlaytimeTracker;
#end

/**
 * Handles initialization of variables when first opening the game.
**/
class InitState extends FlxState {
    override function create():Void {
        super.create();

        // -- FLIXEL STUFF -- //

        FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = TitleState.muteKeys;
		FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

        FlxTransitionableState.skipNextTransIn = true;

        // -- SETTINGS -- //

		FlxG.save.bind('funkin', CoolUtil.getSavePath());

		#if (flixel >= "5.0.0")
		trace('save status: ${FlxG.save.status}');
		#end

		FlxG.fixedTimestep = false;

		PlayerSettings.init();

        // ClientPrefs.loadDefaultKeys();
		ClientPrefs.loadPrefs();
		Conductor.recalculateTimings(); // #43: apply the saved safeFrames before any song starts

		#if ACHIEVEMENTS_ALLOWED
		FlxG.plugins.addIfUniqueType(new PlaytimeTracker());
		#end

        /*
        #if ACHIEVEMNTS_ALLOWED
        Achievements.init();
        #end
        */

        // -- MODS -- //

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		// Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		Mods.loadTopMod();

        // -- -- -- //

        Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

        final state:Class<FlxState> = (ClientPrefs.disableSplash) ? TitleState : StartupState;

        FlxG.switchState(Type.createInstance(state, []));
    }
}
