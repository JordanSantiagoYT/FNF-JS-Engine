package;

// an fully working crash handler on ALL platforms

import openfl.events.UncaughtErrorEvent;
import openfl.events.ErrorEvent;
import openfl.errors.Error;
import haxe.CallStack;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;
using CoolUtil;

/**
 * Crash Handler.
 * @author YoshiCrafter29, Ne_Eo. MAJigsaw77 and mcagabe19
 */

class CrashHandler
{
	public static function init():Void
	{
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onError);
		#elseif hl
		hl.Api.setErrorHandler(onError);
		#end
	}

	private static function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		e.preventDefault();
		e.stopPropagation();
		e.stopImmediatePropagation();

		var m:String = e.error;
		if (Std.isOfType(e.error, Error)) {
			var err = cast(e.error, Error);
			m = '${err.message}';
		} else if (Std.isOfType(e.error, ErrorEvent)) {
			var err = cast(e.error, ErrorEvent);
			m = '${err.text}';
		}
		final stack = CallStack.exceptionStack();
		final stackLabelArr:Array<String> = [];
		var stackLabel:String = "";
		// legacy code below for the messages
		var errorMessage:String = "";
		var path:String;
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "crash/" + "PatoEngine_" + dateNow + ".log";

		for(stackItem in stack) {
			switch(stackItem) {
				case CFunction: stackLabelArr.push("Non-Haxe (C) Function");
				case Module(c): stackLabelArr.push('Module ${c}');
				case FilePos(parent, file, line, col):
					switch(parent) {
						case Method(cla, func):
							stackLabelArr.push('${file.replace('.hx', '')}.$func() [line $line]');
						case _:
							stackLabelArr.push('${file.replace('.hx', '')} [line $line]');
					}
				case LocalFunction(v):
					stackLabelArr.push('Local Function ${v}');
				case Method(cl, m):
					stackLabelArr.push('${cl} - ${m}');
			}
		}
		stackLabel = stackLabelArr.join('\r\n');

		errorMessage += "Uncaught Error: " 
			+ '$m\n$stackLabel'
			+ "\nPlease report this error to the GitHub page: https://github.com/JordanSantiagoYT/FNF-JS-Engine"
			+ "\nThe engine has saved a crash log inside the crash folder, If you're making a GitHub issue you might want to send that!";

		#if sys
		try
		{
			if (!FileSystem.exists("crash/"))
				FileSystem.createDirectory("crash/");
	
			File.saveContent(path, errorMessage + "\n");
		}
		catch(e)
			trace('Couldn\'t save error message. (${e.message})');

		Sys.println(errorMessage);
		Sys.println("Crash dump saved in " + Path.normalize(path));
		#end

		CoolUtil.showPopUp(errorMessage, "Error! Patos Engine v" + MainMenuState.psychEngineJSVersion + " (" + Main.__superCoolErrorMessagesArray[FlxG.random.int(0, Main.__superCoolErrorMessagesArray.length)] + ")");

		#if html5
		if (flixel.FlxG.sound.music != null)
			flixel.FlxG.sound.music.stop();

		js.Browser.window.location.reload(true);
		#else
		lime.system.System.exit(1);
		#end
	}

	#if (cpp || hl)
	private static function onError(message:Dynamic):Void
	{
		throw Std.string(message);
	}
	#end
}
