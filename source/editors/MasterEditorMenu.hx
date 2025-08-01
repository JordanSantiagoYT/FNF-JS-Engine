package editors;

#if MODS_ALLOWED
#end


class MasterEditorMenu extends MusicBeatState
{
	var options:Array<String> = [
		'Week Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Character Editor',
		'Chart Editor',
		'Note Splash Debug',
		'3D Benchmark'
	];
	private var grpTexts:FlxTypedGroup<Alphabet>;
	private var directories:Array<String> = [null];

	private var curSelected = 0;
	private var curDirectory = 0;
	private var directoryTxt:FlxText;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		for (i in 0...options.length)
		{
			var leText:Alphabet = new Alphabet(90, 320, options[i], true);
			leText.isMenuItem = true;
			leText.targetY = i;
			grpTexts.add(leText);
			leText.snapToPosition();
		}

		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);

		for (folder in Paths.getModDirectories())
		{
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Paths.currentModDirectory);
		if (found > -1)
			curDirectory = found;
		changeDirectory();
		#end
		changeSelection();

		FlxG.mouse.visible = false;

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}
		#if MODS_ALLOWED
		if (controls.UI_LEFT_P)
		{
			changeDirectory(-1);
		}
		if (controls.UI_RIGHT_P)
		{
			changeDirectory(1);
		}
		#end

		if (controls.BACK)
			FlxG.switchState(MainMenuState.new);

		if (controls.ACCEPT)
		{
			switch (options[curSelected])
			{
				case 'Character Editor':
					LoadingState.loadAndSwitchState(() -> new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
				case 'Week Editor':
					FlxG.switchState(() -> new WeekEditorState());
				case 'Menu Character Editor':
					FlxG.switchState(MenuCharacterEditorState.new);
				case 'Dialogue Portrait Editor':
					LoadingState.loadAndSwitchState(DialogueCharacterEditorState.new, false);
				case 'Dialogue Editor':
					LoadingState.loadAndSwitchState(DialogueEditorState.new, false);
				case 'Chart Editor': // felt it would be cool maybe
					LoadingState.loadAndSwitchState(ChartingState.new, false);
				case 'Note Splash Debug':
					LoadingState.loadAndSwitchState(NoteSplashDebugState.new, false);
				case '3D Benchmark':
					LoadingState.loadAndSwitchState(BenchmarkState.new, false);
			}
			FlxG.sound.music.volume = 0;
			#if PRELOAD_ALL
			FreeplayState.destroyFreeplayVocals();
			#end
		}

		if (FlxG.keys.justPressed.SEVEN)
		{
			for (i in 1...100)
			{
				var peep:FlxSprite = new FlxSprite();
				var x:Float = FlxG.random.float(-32, 1316);
				peep.makeGraphic(32, 32, FlxColor.RED);
				peep.x = x;
				peep.y = FlxG.random.float(-200, -800);
				FlxTween.tween(peep, {x: x + FlxG.random.float(-250, 250), y: 760, angle: FlxG.random.float(-180, 180)}, FlxG.random.float(1.5, 2), {
					onComplete: function(e)
					{
						peep.destroy();
					},
					ease: FlxEase.expoIn
				});
				add(peep);
			}

			var murder:FlxSprite = new FlxSprite();
			murder.loadGraphic(Paths.image('troll'));
			murder.screenCenter();
			new FlxTimer().start(1.5, function(f)
			{
				FlxTween.tween(murder, {alpha: 0}, 0.5, {
					onComplete: function(e)
					{
						murder.destroy();
					}
				});
			});
			add(murder);

			FlxG.sound.play(Paths.sound('troll'));
		}

		var bullShit:Int = 0;
		for (item in grpTexts.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory += change;

		if (curDirectory < 0)
			curDirectory = directories.length - 1;
		if (curDirectory >= directories.length)
			curDirectory = 0;

		WeekData.setDirectoryFromWeek();
		if (directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Paths.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ' + Paths.currentModDirectory + ' >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
	}
	#end
}
