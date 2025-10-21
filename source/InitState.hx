package;

import flixel.FlxState;

/**
 * Handles initialization of variables when first opening the game.
**/
class InitState extends FlxState {
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

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
		
		Controls.instance = new Controls();

		#if (flixel >= "5.0.0")
		trace('save status: ${FlxG.save.status}');
		#end

		FlxG.fixedTimestep = false;

        ClientPrefs.loadDefaultStuff();
		ClientPrefs.loadPrefs();

        /*
        #if ACHIEVEMNTS_ALLOWED
        Achievements.init();
        #end
        */
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

        // -- MODS -- //

		#if LUA_ALLOWED
		Paths.pushGlobalMods();
		#end
		// Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		WeekData.loadTheFirstEnabledMod();

        // -- -- -- //

        Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

        final state:Class<FlxState> = (ClientPrefs.disableSplash) ? TitleState : StartupState;

        FlxG.switchState(Type.createInstance(state, []));
    }
}
