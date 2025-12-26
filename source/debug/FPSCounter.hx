package debug;

import debug.mem.GetTotalMemory;
import lime.system.System as LimeSystem;
import openfl.display.Bitmap;
import openfl.text.TextField;
import openfl.text.TextFormat;

#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:headerInclude('sys/utsname.h')
#end
#end
class FPSCounter extends TextField
{
	public var currentFPS(default, null):Float;

	public var bitmap:Bitmap;
	var lastText:String = "";
	var outlineDirty:Bool = true;

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
		defaultTextFormat = new TextFormat("VCR OSD Mono", 14, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		FlxG.signals.gameResized.add(rescale);

		times = [];
	}

	function rescale(width:Int, height:Int):Void {
		var scale:Float = height / 720;

    this.scaleX = scale;
    this.scaleY = scale;
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

		var newText = text;

		if (ClientPrefs.fpsBorder)
		{
			visible = true;

			if (outlineDirty || newText != lastText)
			{
				if (bitmap != null && Main.instance.contains(bitmap))
					Main.instance.removeChild(bitmap);

				bitmap = ImageOutline.renderImage(this, 2, 0x000000, 1);
				Main.instance.addChild(bitmap);

				lastText = newText;
				outlineDirty = false;
			}

			visible = false;
		}
		else
		{
			visible = true;
			if (bitmap != null && Main.instance.contains(bitmap))
				Main.instance.removeChild(bitmap);
		}

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
				if (LimeSystem.platformName == LimeSystem.platformVersion || LimeSystem.platformVersion == null)
					text += '\nOS: ${LimeSystem.platformName}' #if cpp + ' ${getArch()}' #end;
				else
					text += '\nOS: ${LimeSystem.platformName}' #if cpp + ' ${getArch()}' #end + ' - ${LimeSystem.platformVersion}';


			text += '\nVersion: ${MainMenuState.psychEngineJSVersion}' #if commit + '(Commit ${MainMenuState.gitCommit})' #end;
		}
	}
	#if cpp
	#if windows
	@:functionCode('
		SYSTEM_INFO osInfo;

		GetSystemInfo(&osInfo);

		switch(osInfo.wProcessorArchitecture)
		{
			case 9:
				return ::String("x86_64");
			case 5:
				return ::String("ARM");
			case 12:
				return ::String("ARM64");
			case 6:
				return ::String("IA-64");
			case 0:
				return ::String("x86");
			default:
				return ::String("Unknown");
		}
	')
	#elseif (ios || mac)
	@:functionCode('
		const NXArchInfo *archInfo = NXGetLocalArchInfo();
    	return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
	')
	#else
	@:functionCode('
		struct utsname osInfo{};
		uname(&osInfo);
		return ::String(osInfo.machine);
	')
	#end
	@:noCompletion
	private function getArch():String
	{
		return null;
	}
	#end
}
