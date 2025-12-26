package;

import backend.SSPlugin as ScreenShotPlugin;
import debug.FPSCounter;
import flixel.FlxGame;
import lime.app.Application;
import openfl.Lib;
import openfl.display.Sprite;
#if (linux && !debug)
import hxgamemode.GamemodeClient;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

#if windows
@:buildXml('
<target id="haxe">
	<lib name="wininet.lib" if="windows" />
	<lib name="dwmapi.lib" if="windows" />
</target>
')
@:cppFileCode('
#include <windows.h>
#include <winuser.h>
')
#end

class Main extends Sprite {
	final game = {
		width: 1280,
		height: 720,
		initialState: InitState.new,
		zoom: -1.0,
		framerate: 60,
		skipSplash: true,
		startFullscreen: false
	};

	public static var fpsVar:FPSCounter;
	public static var instance:Main;

	public static final superDangerMode:Bool = Sys.args().contains("-troll");

	// You can pretty much ignore everything from here on - your code should go in your states.

	@:noCompletion
	private static function __init__():Void {
		#if (linux && !debug)
		// Request we start game mode
		if (GamemodeClient.request_start() != 0) {
			Sys.println('Failed to request gamemode start: ${GamemodeClient.error_string()}...');
			openfl.system.System.exit(1);
		} else {
			Sys.println('Succesfully requested gamemode to start...');
		}
		#end
	}

	public static function main():Void {
		Lib.current.addChild(new Main());
	}

	public function new() {
		super();
		instance = this;
		#if (cpp && windows)
		untyped __cpp__("
				SetProcessDPIAware(); // allows for more crisp visuals
				SetConsoleOutputCP(CP_UTF8);
				DisableProcessWindowsGhosting() // lets you move the window and such if it's not responding
		");
		#end
		CrashHandler.init();
		setupGame();
	}

	public static var askedToUpdate:Bool = false;

	public static function isPlayState():Bool
		return Type.getClassName(Type.getClass(FlxG.state)) == 'PlayState';

	private function setupGame():Void {
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (game.zoom == -1.0) {
			var ratioX:Float = stageWidth / game.width;
			var ratioY:Float = stageHeight / game.height;
			game.zoom = Math.min(ratioX, ratioY);
			game.width = Math.ceil(stageWidth / game.zoom);
			game.height = Math.ceil(stageHeight / game.zoom);
		};

		ClientPrefs.loadDefaultStuff();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		final funkinGame:FlxGame = new FlxGame(game.width, game.height, game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate, game.skipSplash, game.startFullscreen);
		// Literally just from Vanilla FNF but I implemented it my own way. -Torch
		// torch is my friend btw :3 -moxie
		@:privateAccess {
			final soundFrontEnd:flixel.system.frontEnds.SoundFrontEnd = new objects.CustomSoundTray.CustomSoundFrontEnd();
			FlxG.sound = soundFrontEnd;
			funkinGame._customSoundTray = objects.CustomSoundTray.CustomSoundTray;
		}

		addChild(funkinGame);

		fpsVar = new FPSCounter(3, 3, 0x00FFFFFF);
		addChild(fpsVar);

		if (fpsVar != null) {
			fpsVar.visible = ClientPrefs.showFPS;
		}

		#if !web
		FlxG.plugins.addIfUniqueType(new ScreenShotPlugin());
		#end

		FlxG.autoPause = false;

		#if (linux || mac)
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if windows
		WindowColorMode.setDarkMode();
		if (CoolUtil.hasVersion("Windows 10"))
			WindowColorMode.redrawWindowHeader();
		#end

		#if DISCORD_ALLOWED DiscordClient.prepare(); #end

		// shader coords fix
		FlxG.signals.gameResized.add(function(w, h) {
			if (FlxG.cameras != null) {
			  	for (cam in FlxG.cameras.list) {
			   		if (cam != null && cam.filters != null)
				   		resetSpriteCache(cam.flashSprite);
			  	}
		   	}

		   if (FlxG.game != null) resetSpriteCache(FlxG.game);
	   });
	}

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		  sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	public static function changeFPSColor(color:FlxColor) {
		fpsVar.textColor = color;
	}
}
