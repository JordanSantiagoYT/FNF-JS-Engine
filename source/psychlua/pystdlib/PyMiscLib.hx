package psychlua.pystdlib;

import flixel.FlxG;
import flixel.math.FlxMath;
import psychlua.PythonScript;
import play.PlayState;
import backend.Conductor;
import backend.Paths;
import headers.PsychLua;
import states.substates.PauseSubState;
#if DISCORD_ALLOWED
import backend.DiscordClient;
#end

// REFACTOR: extracted from psychlua.PythonScript (misc/debug/print utils)
class PyMiscLib
{
	public static function register(py:PythonScript):Void {
		@:privateAccess {
		// ---------------------------------------------------------------- //
		//                           MISC                                   //
		// ---------------------------------------------------------------- //
		PythonScript.registerFunction("getSongPosition", function() {
			return Conductor.songPosition;
		});
		PythonScript.registerFunction("precacheImage", function(name:String) {
			Paths.image(name);
		});
		PythonScript.registerFunction("precacheSound", function(name:String) {
			Paths.sound(name);
		});
		PythonScript.registerFunction("precacheMusic", function(name:String) {
			Paths.music(name);
		});
		PythonScript.registerFunction("triggerEvent", function(name:String, arg1:Dynamic, arg2:Dynamic, strumTime:Float) {
			var value1:String = arg1;
			var value2:String = arg2;
			PlayState.instance.triggerEventNote(name, value1, value2, strumTime);
			return true;
		});
		PythonScript.registerFunction("startCountdown", function() {
			PlayState.instance.startCountdown();
			return true;
		});
		PythonScript.registerFunction("endSong", function() {
			PlayState.instance.KillNotes();
			PlayState.instance.endSong();
			return true;
		});
		PythonScript.registerFunction("restartSong", function(?skipTransition:Bool = false) {
			PlayState.instance.persistentUpdate = false;
			PauseSubState.restartSong(skipTransition);
			return true;
		});
		PythonScript.registerFunction("getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Int> = [];
			for (i in 0...excludeArray.length) {
				toExclude.push(Std.parseInt(excludeArray[i].trim()));
			}
			return FlxG.random.int(min, max, toExclude);
		});
		PythonScript.registerFunction("getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Float> = [];
			for (i in 0...excludeArray.length) {
				toExclude.push(Std.parseFloat(excludeArray[i].trim()));
			}
			return FlxG.random.float(min, max, toExclude);
		});
		PythonScript.registerFunction("getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});
		PythonScript.registerFunction("getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false) {
			return Paths.getTextFromFile(path, ignoreModFolders);
		});
		// Flush the engine-wide save used by scripts that write FlxG.save.data.
		PythonScript.registerFunction("flushGlobalSave", function() {
			if (FlxG.save != null) FlxG.save.flush();
		});
		PythonScript.registerFunction("flushSaveData", function(name:String) {
			var save = Reflect.getProperty(FlxG.save, name);
			if (save != null) save.flush();
		});
		PythonScript.registerFunction("debugPrint", function(text1:Dynamic = '', text2:Dynamic = '', text3:Dynamic = '', text4:Dynamic = '', text5:Dynamic = '') {
			if (text1 == null) text1 = '';
			if (text2 == null) text2 = '';
			if (text3 == null) text3 = '';
			if (text4 == null) text4 = '';
			if (text5 == null) text5 = '';
			py.pyTrace('' + text1 + text2 + text3 + text4 + text5, true, false);
		});
		PythonScript.registerFunction("close", function() {
			py.closed = true;
			return py.closed;
		});
		PythonScript.registerFunction("changePresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
			#if DISCORD_ALLOWED
			DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
			#end
		});
		}
	}
}
