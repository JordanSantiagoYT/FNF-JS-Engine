package;

import flixel.FlxState;

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

		trace('save status: ${FlxG.save.status}');

		FlxG.fixedTimestep = false;

		PlayerSettings.init();

        // ClientPrefs.loadDefaultKeys();
		ClientPrefs.loadPrefs();

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

        FlxG.switchState(Main.getFirstState());
    }
}
