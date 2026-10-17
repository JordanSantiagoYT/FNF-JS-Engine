package backend;

import debug.FrameProfiler;
import openfl.events.KeyboardEvent;
import flixel.FlxGame;
import flixel.FlxState;

class FunkinGame extends FlxGame {
	#if desktop
	var fullscreenListener:KeyboardEvent->Void;
	
	public function new(gameWidth:Int, gameHeight:Int, entryState:Class<FlxState>, updateFramerate:Int = 60, drawFramerate:Int = 60, skipSplash:Bool = false, startFullscreen:Bool = false) {
		super(gameWidth, gameHeight, entryState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		
		fullscreenListener = function(e:KeyboardEvent) {
			if (e.keyCode == 122) {
				FlxG.fullscreen = !FlxG.fullscreen;
			} else if (e.keyCode == 114) {
				ClientPrefs.frameProfiler = !ClientPrefs.frameProfiler;
				if (Main.fpsVar != null) Main.fpsVar.updateText();
			} else if (e.keyCode == 117) {
				FrameProfiler.exportLog();
			}
		};
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, fullscreenListener);
	}
	#end
}