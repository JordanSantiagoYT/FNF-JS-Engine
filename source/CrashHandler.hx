package;

// an fully working crash handler on ALL platforms
import flixel.FlxState;
import haxe.CallStack;
import haxe.io.Path;
import openfl.Lib;
import openfl.errors.Error;
import openfl.events.ErrorEvent;
import openfl.events.UncaughtErrorEvent;

/**
 * Crash Handler.
 * @author YoshiCrafter29 and MAJigsaw77
 */
class CrashHandler
{
	public static var errorMessage:String = "";

	static final __superCoolErrorMessagesArray:Array<String> = [
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
		"ARK: Survival Evolved",
		"my names JS Engine, and I'm an crashaholic",
		"JS, more like buggy engine lol"
	];

	// this is a map containing common crash sources mapped to a summarized reason, use to add an extra line on the crash screen.
	static final commonCrashers:Map<String, String> = [
		'SuperSecretDebugMenu.crashDaEngine()' => 'You intentionally caused this.',
		'Paths.addAnimAndCheck()' => "You're missing a config file for your note splash skin.",
		'JsonParser.invalidChar()' => "Your json is either formatted incorrectly or corrupted.",
		'Song.onLoadJson()' => "You attempted to load a chart that was made in Psych Engine 1.0."
	];

	public static var extraLines:Array<String> = ['\n\n'];

	public static function init():Void
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
		untyped __global__.__hxcpp_set_critical_error_handler(onError);
	}

	private static function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		try
		{
			e.preventDefault();
			e.stopPropagation();
			e.stopImmediatePropagation();

			errorMessage = "";

			var m:String = e.error;
			if (Std.isOfType(e.error, Error))
			{
				var err = cast(e.error, Error);
				m = '${err.message}';
			}
			else if (Std.isOfType(e.error, ErrorEvent))
			{
				var err = cast(e.error, ErrorEvent);
				m = '${err.text}';
			}
			final stack = CallStack.exceptionStack();
			final stackLabelArr:Array<String> = [];
			var stackLabel:String = "";
			// legacy code below for the messages
			var path:String;
			var dateNow:String = Date.now().toString();
			dateNow = dateNow.replace(" ", "_");
			dateNow = dateNow.replace(":", "'");

			path = "crash/JSEngine_" + dateNow + ".log";

			for (stackItem in stack)
			{
				switch (stackItem)
				{
					case CFunction:
						stackLabelArr.push("Non-Haxe (C) Function");
					case Module(c):
						stackLabelArr.push('Module ${c}');
					case FilePos(parent, file, line, col):
						switch (parent)
						{
							case Method(cla, func): stackLabelArr.push('${file.replace('.hx', '')}.$func() [line $line]');
							case _: stackLabelArr.push('${file.replace('.hx', '')} [line $line]');
						}
					case LocalFunction(v):
						stackLabelArr.push('Local Function ${v}');
					case Method(cl, m):
						stackLabelArr.push('${cl} - ${m}');
				}
			}
			stackLabel = stackLabelArr.join('\r\n');

			var crashReason = '';
			for (source => reason in commonCrashers) {
				if (stackLabel.contains(source)) {
					crashReason = reason;
					if (!extraLines.contains(crashReason)) extraLines.push(crashReason);
				}
			}
			
			if (stackLabel != null)
				for (line in extraLines)
					stackLabel += line;

			errorMessage += 'Uncaught Error: $m\n\n$stackLabel';

			try
			{
				if (!FileSystem.exists("crash/"))
					FileSystem.createDirectory("crash/");
				File.saveContent(path, '$errorMessage\n\nCrash Happened on JS Engine v${MainMenuState.psychEngineJSVersion}!');
			}
			catch (e)
				trace('Couldn\'t save error message. (${e.message})');

			Sys.println(errorMessage);
			Sys.println("Crash dump saved in " + Path.normalize(path));
		}
		catch (e:Dynamic)
			trace(e);

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = false;

		if (ClientPrefs.peOGCrash)
		{
			errorMessage += "\n\nPlease report this error to the GitHub page: https://github.com/JordanSantiagoYT/FNF-JS-Engine"
				+ "\nThe engine has saved a crash log inside the crash folder, If you're making a GitHub issue you might want to send that!";

			CoolUtil.showPopUp(errorMessage,
				"Error! JS Engine v"
				+ MainMenuState.psychEngineJSVersion
				+ " ("
				+ __superCoolErrorMessagesArray[FlxG.random.int(0, __superCoolErrorMessagesArray.length)]
				+ ")");

			lime.system.System.exit(1);
		}
		else
			FlxG.switchState(Crash.new);
	}

	private static function onError(message:Dynamic):Void
		throw Std.string(message);
}

@:access(CrashHandler)
class Crash extends MusicBeatState
{
	override public function create()
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF232323;
		add(bg);

		var ohNo:FlxText = new FlxText(0, 0, 1280, 'JS Engine v${MainMenuState.psychEngineJSVersion} has crashed!');
		ohNo.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, FlxTextAlign.CENTER);
		ohNo.alpha = 0;
		ohNo.screenCenter();
		ohNo.y = 14;
		add(ohNo);

		var ohNo2:FlxText = new FlxText(0, 0, 1280, CrashHandler.__superCoolErrorMessagesArray[FlxG.random.int(0, CrashHandler.__superCoolErrorMessagesArray.length)]);
		ohNo2.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, FlxTextAlign.CENTER);
		ohNo2.alpha = 0;
		ohNo2.screenCenter();
		ohNo2.y = 64;
		add(ohNo2);

		var ohNo3:FlxText = new FlxText(0, 0, 1280, "Crash Handler by YoshiCrafter29 and MAJigsaw77\nCrash UI State by Nael2xd");
		ohNo3.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE);
		ohNo3.alpha = 0;
		ohNo3.screenCenter();
		ohNo3.y = 580;
		ohNo3.x = 30;
		add(ohNo3);

		var ohNo4:FlxText = new FlxText(0, 0, 1280,
			"If you are reporting this bug, Press [F2] to screenshot that error or\nGo to crash/ folder and copy the contents from the recent file.");
		ohNo4.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, FlxTextAlign.CENTER);
		ohNo4.alpha = 0;
		ohNo4.screenCenter();
		ohNo4.y = 620;
		add(ohNo4);

		var stripClub:Array<String> = CrashHandler.errorMessage.split("\n");
		var i:Int = -1;
		var crash:Array<FlxText> = [];

		for (line in stripClub)
		{
			i++;
			crash.push(new FlxText(180, 0, 1280, line));
			crash[i].setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, FlxTextAlign.LEFT);
			crash[i].alpha = 0;
			crash[i].screenCenter();
			crash[i].x = 70;
			crash[i].y = 110 + (20 * i);
			add(crash[i]);
		}

		var tip:FlxText = new FlxText(180, 0, 1280, "Press any key to restart." + (CrashHandler.extraLines.length > 0 ? " (Press ENTER to Report This Bug)" : " You cannot report this issue."));
		tip.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, FlxTextAlign.CENTER);
		tip.alpha = 0;
		tip.screenCenter();
		tip.y = 670;
		add(tip);

		FlxTween.tween(ohNo, {alpha: 1}, 0.5);
		FlxTween.tween(ohNo2, {alpha: 1}, 0.5);
		FlxTween.tween(ohNo3, {alpha: 0.25}, 0.5);
		FlxTween.tween(ohNo4, {alpha: 1}, 0.5);
		FlxTween.tween(tip, {alpha: 1}, 0.5);
		for (spr in crash)
			FlxTween.tween(spr, {alpha: 1}, 0.5);

		var error:FlxSound = FlxG.sound.load(Paths.sound('error'));
		error.play();

		super.create();
	}

	// Do note that if you use "resetGame" js engine will be in a crash loop because music is missing.
	// Even with my coding skills and trying to make it work it just doesn't, i'm probably stupid.
	// Also yes i tried FlxG.sound.playMusic and yet it doesn't do what it's suppose to do.
	// -nael2xd
	var countDown:Int = 10;
	var clicked:Bool = false;

	override public function update(elapsed:Float)
		if (FlxG.keys.justPressed.ANY && !clicked)
		{
			FlxTransitionableState.skipNextTransIn = false;
			if (FlxG.keys.justPressed.ENTER && CrashHandler.extraLines.length < 1)
			{
				clicked = true;
				for (sprite in members)
					if (sprite is FlxSprite || sprite is FlxText)
						FlxTween.tween(sprite, {alpha: 0.5}, 0.5);
				var coolBg:FlxSprite = new FlxSprite().makeGraphic(840, 260, 0xFF404040);
				coolBg.screenCenter();
				add(coolBg);
				var coolInfo:FlxSprite = new FlxSprite().makeGraphic(830, 250, 0xFF636363);
				coolInfo.screenCenter();
				add(coolInfo);
				var heyText:FlxText = new FlxText(0, 0, 820,
					"Before you report the crash, Please check if one of those crash exists. If it does exist yet you make the issue, it will be marked as duplicate!");
				heyText.setFormat(Paths.font('vcr.ttf'), 34, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				heyText.screenCenter();
				heyText.y -= 50;
				add(heyText);
				var countText:FlxText = new FlxText(0, 0, 640, "" + countDown);
				countText.setFormat(Paths.font('vcr.ttf'), 90, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				countText.screenCenter();
				countText.y += 73;
				add(countText);
				new FlxTimer().start(1, e ->
				{
					countDown--;
					countText.text = countDown + "";
					if (countDown == 0)
					{
						CoolUtil.browserLoad("https://github.com/JordanSantiagoYT/FNF-JS-Engine/issues/new?template=bugs.yml");
						FlxG.switchState(MainMenuState.new);
					}
				}, 10);
			}
			else if (!FlxG.keys.justPressed.F2) {
				Paths.playMenuMusic(true, 0);
				FlxG.switchState(MainMenuState.new);
			}
		}
}