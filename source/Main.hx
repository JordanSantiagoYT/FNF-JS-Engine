package;

import backend.SSPlugin as ScreenShotPlugin;
import debug.FPSCounter;
import flixel.FlxGame;
import lime.app.Application;
import openfl.Lib;
import openfl.display.Sprite;

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig; // Just to make sure DCE doesn't remove this, since it's not directly referenced anywhere else.
#end


#if linux
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('
	#define GAMEMODE_AUTO
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

	public static final superDangerMode:Bool = Sys.args().contains("-troll");

    public static final __superCoolErrorMessagesArray:Array<String> = [
        "A fatal error has occ- wait what?",
        "missigno.",
        "oopsie daisies!! you did a fucky wucky!!",
        "i think you fogot a semicolon",
        "null balls reference",
        "get friday night funkd'",
        "engine skipped a heartbeat",
        "Impossible...",
        "Patience is key for success... Don't give up.",
        "It's no longer in its early stages... is it?",
        "It took me half a day to code that in",
        "You should make an issue... NOW!!",
        "> Crash Handler written by: yoshicrafter29",
        "broken ch-... wait what are we talking about",
        "could not access variable you.dad",
        "What have you done...",
        "THERE ARENT COUGARS IN SCRIPTING!!! I HEARD IT!!",
        "no, thats not from system.windows.forms",
        "you better link a screenshot if you make an issue, or at least the crash.txt",
    	"stack trace more like dunno i dont have any jokes",
        "oh the misery. everybody wants to be my enemy",
        "have you heard of soulles dx",
        "i thought it was invincible",
        "did you deleted coconut.png",
        "have you heard of missing json's cousin null function reference",
        "sad that linux users wont see this banger of a crash handler",
		"woopsie",
        "oopsie",
        "woops",
        "silly me",
        "my bad",
        "first time, huh?",
        "did somebody say yoga",
        "we forget a thousand things everyday... make sure this is one of them.",
        "SAY GOODBYE TO YOUR KNEECAPS, CHUCKLEHEAD",
        "motherfucking ordinal 344 (TaskDialog) forcing me to create a even fancier window",
        "Died due to missing a sawblade. (Press Space to dodge!)",
        "yes rico, kaboom.",
        "hey, while in freeplay, press shift while pressing space",
        "goofy ahh engine",
        "pssst, try typing debug7 in the options menu",
        "this crash handler is sponsored by rai-",
        "",
        "did you know a jiffy is an actual measurement of time",
        "how many hurt notes did you put",
        "FPS: 0",
        "\r\ni am a secret message",
        "this is garnet",
        "Error: Sorry i already have a girlfriend",
        "did you know theres a total of 51 silly messages",
        "whoopsies looks like i forgot to fix this",
        "Game used Crash. It's super effective!",
		"What in the fucking shit fuck dick!",
		"The engine got constipated. Sad.",
		"shit.",
		"NULL",
		"Five big booms. BOOM, BOOM, BOOM, BOOM, BOOM!!!!!!!!!!",
		"uhhhhhhhhhhhhhhhh... i dont think this is normal...",
		"lobotomy moment",
		"ARK: Survival Evolved"
    ];

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void {
		Lib.current.addChild(new Main());
	}

	public function new() {
		super();
		#if windows //DPI AWARENESS BABY
		@:functionCode('
		#include <Windows.h>
		SetProcessDPIAware()
		')
		#end
		CrashHandler.init();
		setupGame();
	}

	public static var askedToUpdate:Bool = false;

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

		// #if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
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
		// turns out I forgot this, I'm a bit dumb for that
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end

		addChild(funkinGame);

		fpsVar = new FPSCounter(3, 3, 0x00FFFFFF);
		addChild(fpsVar);

		if (fpsVar != null) {
			fpsVar.visible = ClientPrefs.showFPS;
		}

		#if (!web && flixel < "5.5.0")
		FlxG.plugins.add(new ScreenShotPlugin());
		#elseif (flixel >= "5.6.0")
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
