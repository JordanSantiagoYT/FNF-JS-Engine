package debug;

import debug.Memory;
import lime.system.System;
import mem.GetTotalMemory;
import openfl.text.TextField;
import openfl.text.TextFormat;

class FPSCounter extends TextField
{
	public var currentFPS(default, null):Float;

	/*
	* The current memory usage (WARNING: This might NOT your total memory usage, rather it might show the garbage collector memory if you aren't running on a C++ platform.)
	*/
	public var memory(get, never):Float;
	inline function get_memory():Float
		return GetTotalMemory.getCurrentRSS();

	var mempeak(get, never):Float;
	inline function get_mempeak():Float
	        return GetTotalMemory.getPeakRSS();

	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x00000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("VCR OSD Mono", 12, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];
	}

	var timeColor:Float = 0.0;

	var fpsMultiplier:Float = 1.0;
	var deltaTimeout:Float = 0.0;
	public var timeoutDelay:Float = 50;
	var now:Float = 0;
	// Event Handlers
	override function __enterFrame(deltaTime:Float):Void
	{
		if (!ClientPrefs.showFPS) return;
		now = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000 / fpsMultiplier) times.shift();
		if (deltaTimeout <= timeoutDelay)
		{
			deltaTimeout += deltaTime;
			return;
		}

		if (Std.isOfType(FlxG.state, PlayState) && !PlayState.instance.trollingMode)
		{
			try { fpsMultiplier = PlayState.instance.playbackRate; }
			catch (e:Dynamic) { fpsMultiplier = 1.0; }
		}
		else fpsMultiplier = 1.0;

		currentFPS = Math.min(FlxG.drawFramerate, times.length) / fpsMultiplier;
		updateText();

		if (ClientPrefs.rainbowFPS)
		{
			timeColor = (timeColor % 360.0) + (1.0 / (ClientPrefs.framerate / 120));
			textColor = FlxColor.fromHSB(timeColor, 1, 1);
		}
		else if (!ClientPrefs.ffmpegMode)
		{
			textColor = 0xFFFFFFFF;
			if (currentFPS <= ClientPrefs.framerate / 2 && currentFPS >= ClientPrefs.framerate / 3)
				textColor = 0xFFFFFF00;

			if (currentFPS <= ClientPrefs.framerate / 3 && currentFPS >= ClientPrefs.framerate / 4)
				textColor = 0xFFFF8000;

			if (currentFPS <= ClientPrefs.framerate / 4)
				textColor = 0xFFFF0000;
		}
		// deltaTimeout = 0.0;
	}

	public dynamic function updateText():Void   // so people can override it in hscript
	{
		text = "FPS: " + (ClientPrefs.ffmpegMode ? ClientPrefs.targetFPS : Math.round(currentFPS));
		if (ClientPrefs.ffmpegMode)
			text += " (Rendering Mode)";

		if (ClientPrefs.showRamUsage) text += "\nMemory: " + FlxStringUtil.formatBytes(memory) + (ClientPrefs.showMaxRamUsage ? " / " + FlxStringUtil.formatBytes(mempeak) : "");
		if (ClientPrefs.debugInfo)
		{
			text += '\nCurrent state: ${Type.getClassName(Type.getClass(FlxG.state))}';
			if (FlxG.state.subState != null)
				text += '\nCurrent substate: ${Type.getClassName(Type.getClass(FlxG.state.subState))}';
			#if !linux text += "\nOS: " + '${System.platformLabel} ${System.platformVersion}'; #end
		}
	}
}
