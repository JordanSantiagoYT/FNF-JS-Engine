package options;

import Controls;
import Note;
import StrumNote;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;

class VisualsUISubState extends BaseOptionsMenu
{
	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var notesTween:Array<FlxTween> = [];
	var noteY:Float = 90;
	public function new()
	{
		title = 'Visuals and UI';
		rpcTitle = 'Visuals & UI Settings Menu'; //for Discord Rich Presence

		// for note skins
		notes = new FlxTypedGroup<StrumNote>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			note.centerOffsets();
			note.centerOrigin();
			note.playAnim('static');
			notes.add(note);
		}

		var noteSkins:Array<String> = Paths.mergeAllTextsNamed('images/noteskins/list.txt');
		if(noteSkins.length > 0)
		{
			noteSkins.insert(0, 'Default'); //Default skin always comes first
			if(!noteSkins.contains(ClientPrefs.noteSkin))
				ClientPrefs.noteSkin = noteSkins[0]; //Reset to default if saved noteskin couldnt be found

			var option:Option = new Option('Note Skins:',
				"Select your prefered Note skin.",
				'noteSkin',
				'string',
				noteSkins[0],
				noteSkins);
			addOption(option);
			option.onChange = onChangeNoteSkin;
			noteOptionID = optionsArray.length - 1;
		}

		var noteSplashList:Array<String> = Paths.mergeAllTextsNamed('images/noteSplashes/list.txt');
		if (noteSplashList.length > 0)
		{
			noteSplashList.insert(0, 'Default'); //Default skin always comes first
			if (!noteSplashList.contains(ClientPrefs.splashType))
				ClientPrefs.splashType = noteSplashList[0];

			var option:Option = new Option('Note Splash Type:',
				"Which note splash would you like?",
				'splashType',
				'string',
				'Default',
				noteSplashList);
			addOption(option);
		}

		var option:Option = new Option('Note Splashes',
			"If unchecked, hitting \"Sick!\" notes won't show particles.",
			'noteSplashes',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Opponent Note Splashes',
			"If checked, opponent note hits will show particles.",
			'oppNoteSplashes',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show NPS',
			'If checked, the game will show your current NPS.',
			'showNPS',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Combo',
			'If checked, the game will show your current combo.',
			'showComboInfo',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Max Splashes: ',
			"How many note splashes should be allowed on screen at the same time?\n(0 means no limit)",
			'maxSplashLimit',
			'int',
			16);

		option.minValue = 0;
		option.maxValue = 50;
		option.displayFormat = '%v Splashes';
		addOption(option);

		var option:Option = new Option('Opponent Note Alpha:',
			"How visible do you want the opponent's notes to be when Middlescroll is enabled? \n(0% = invisible, 100% = fully visible)",
			'oppNoteAlpha',
			'percent',
			0.65);
		option.scrollSpeed = 1.8;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.01;
		option.decimals = 2;
		addOption(option);

		var option:Option = new Option('Hide HUD',
			'If checked, hides most HUD elements.',
			'hideHud',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option("Taunt on 'GO'",
			"If checked, the characters will taunt on GO when you play.",
			'tauntOnGo',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Old Sustain Note Style',
			'If checked, sustain notes will react like how they did before 0.3.X.',
			'oldSusStyle',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Show Rendered Notes',
			'If checked, the game will show how many notes are currently rendered on screen.',
			'showRendered',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Showcase Mode',
			'If checked, hides all the UI elements except for the time bar and notes\nand enables Botplay.',
			'showcaseMode',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Showcase Style: ',
			"In what format would you like your showcase?",
			'showcaseST',
			'string',
			'JS',
			['JS', 'AMZ']);
		addOption(option);

		var option:Option = new Option('Botplay Watermark',
			'If checked, some texts will have a watermark if Botplay is enabled.',
			'botWatermark',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Miss Rating',
			"If unchecked, a Miss rating won't popup when you miss a note.",
			'missRating',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Note Color Style: ',
			"How would you like your notes colored?",
			'noteColorStyle',
			'string',
			'Normal',
			['Normal', 'Quant-Based', 'Char-Based', 'Grayscale', 'Rainbow']);
		addOption(option);

		var option:Option = new Option('Enable Note Colors',
			'If unchecked, notes won\'t be able to use your currently set colors.',
			'enableColorShader',
			'bool',
			true);
		addOption(option);

		var ratingQuoteList:Array<String> = Paths.mergeAllTextsNamed('data/ratingQuotes/list.txt', '', true);
		if (ratingQuoteList.length > 0)
		{
			if (!ratingQuoteList.contains(ClientPrefs.rateNameStuff))
				ClientPrefs.rateNameStuff = ratingQuoteList[0];
			var option:Option = new Option('Rating Quotes',
				"What should the rating names display?",
				'rateNameStuff',
				'string',
				'Quotes',
				ratingQuoteList);
			addOption(option);
		}

		var option:Option = new Option('Time Bar:',
			"What should the Time Bar display?",
			'timeBarType',
			'string',
			'Time Left',
			['Time Left', 'Time Elapsed', 'Song Name', 'Modern Time', 'Song Name + Time', 'Time Left (No Bar)', 'Time Elapsed (No Bar)', 'Modern Time (No Bar)', 'Disabled']);
		addOption(option);

		var option:Option = new Option('ScoreTxt Style:',
			"How would you like your scoreTxt to look like?",
			'scoreStyle',
			'string',
			'Psych Engine',
			['Psych Engine', 'VS Impostor', 'Kade Engine', 'Forever Engine', 'TGT V4', 'Dave Engine', 'Doki Doki+', 'Leather Engine', 'JS Engine', 'Vanilla']);
		addOption(option);

		var option:Option = new Option('Time Bar Style:',
			"How would you like the Time Bar to look like?",
			'timeBarStyle',
			'string',
			'Vanilla',
			['Vanilla', 'Kade Engine', 'VS Impostor', 'TGT V4', 'Dave Engine', 'Doki Doki+', 'Leather Engine', 'JS Engine']);
		addOption(option);

		var option:Option = new Option('Health Bar Style:',
			"How would you like your Health Bar to look?",
			'healthBarStyle',
			'string',
			'Vanilla',
			['Vanilla', 'Dave Engine', 'Doki Doki+']);
		addOption(option);

		var option:Option = new Option('Watermark Style:',
			"How would you like your Watermark to look?",
			'watermarkStyle',
			'string',
			'Vanilla',
			['Vanilla', 'Dave Engine', 'JS Engine', 'Forever Engine', 'Hide']);
		addOption(option);

		var option:Option = new Option('Bot Txt Style:',
			"How would you like your Botplay text to look?",
			'botTxtStyle',
			'string',
			'Vanilla',
			['Vanilla', 'JS Engine', 'Dave Engine', 'Doki Doki+', 'TGT V4', 'VS Impostor', 'Hide']);
		addOption(option);

		var option:Option = new Option('Strum Light Up Style:',
			"How would you like the strum animations to play when lit up? \nNote: Turn on 'Light Opponent/Botplay Strums' to see this in action!",
			'strumLitStyle',
			'string',
			'Full Anim',
			['Full Anim', 'BPM Based']);
		addOption(option);

		var option:Option = new Option('BF Icon Style:',
			"How would you like your BF Icon to look like?",
			'bfIconStyle',
			'string',
			'Default',
			['Default', 'VS Nonsense V2', 'Leather Engine', 'Doki Doki+', "Mic'd Up", 'FPS Plus', "OS 'Engine'"]);
		addOption(option);

		var ratingSpriteList:Array<String> = Paths.mergeAllTextsNamed('images/ratings/list.txt', null, true);
		if (ratingSpriteList.length > 0)
		{
			ratingSpriteList.insert(0, 'Default'); //Default skin always comes first
			if (!ratingSpriteList.contains(ClientPrefs.ratingType))
				ClientPrefs.ratingType = ratingSpriteList[0];
			var option:Option = new Option('Rating Style:',
				"Which style for the rating popups would you like?",
				'ratingType',
				'string',
				'Default',
				ratingSpriteList);
			addOption(option);
		}

		var option:Option = new Option('Simple Rating Popups',
			"If checked, the rating popup will be a much simpler popup.\nEasy on the eyes, and less clutter for the HUD!",
			'simplePopups',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Icon Bounce:',
			"Which icon bounce would you like?",
			'iconBounceType',
			'string',
			'Golden Apple',
			['Golden Apple', 'Dave and Bambi', 'Old Psych', 'New Psych', 'VS Steve', 'Plank Engine', 'Strident Crisis', 'None']);
		addOption(option);

		var option:Option = new Option('Health Tweening',
			"If checked, the health will adjust smoothly.",
			'smoothHealth',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Smooth Health Bug',
			'This was too cool to be removed, apparently.\nIf checked the icons will be able to go past the normal boundaries of the health bar.',
			'smoothHPBug',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('OG HP Colors',
			'If checked, the health bar will globally use Red/Green as the colors.',
			'ogHPColor',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Notes',
			"If unchecked, the notes will be invisible. You can still play them though!",
			'showNotes',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Score Text Zoom on Hit',
			"If unchecked, disables the Score text zooming\neverytime you hit a note.",
			'scoreZoom',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Health Bar Transparency',
			'How transparent should the health bar and icons be?\n(0% = fully opaque, 100% = fully visible!)',
			'healthBarAlpha',
			'percent',
			1);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		#if !mobile
		var option:Option = new Option('FPS Counter',
			'If unchecked, hides FPS Counter.',
			'showFPS',
			'bool',
			true);
		addOption(option);
		option.onChange = onChangeFPSCounter;
		#end

		var option:Option = new Option('Random Botplay Text',
			"Uncheck this if you don't want to be insulted when\nyou use Botplay.",
			'randomBotplayText',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Botplay Text Fading',
			"If checked, the botplay text will do cool fading.",
			'botTxtFade',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Pause Screen Song:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			'string',
			'Tea Time',
			['None', 'Breakfast', 'Tea Time']);
		addOption(option);
		option.onChange = onChangePauseMusic;

		if (!DateUtils.isAprilFools()) {
			var option:Option = new Option('Menu Song:',
				"What song do you prefer when you're in menus?",
				'daMenuMusic',
				'string',
				'Default',
				['Default', 'Anniversary', 'Mashup', 'Base Game', 'DDTO+', 'Dave & Bambi', 'Dave & Bambi (Old)', 'VS Impostor', 'VS Nonsense V2']);
			addOption(option);
			option.onChange = onChangeMenuMusic;
		}

		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			'bool',
			true);
		addOption(option);
		#end

		var option:Option = new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read",
			'comboStacking',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show RAM Usage',
			"If checked, the game will show your RAM usage.",
			'showRamUsage',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Peak RAM Usage',
			"If checked, the game will show your maximum RAM usage.",
			'showMaxRamUsage',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Debug Info',
			"If checked, the game will show additional debug info.\nNote: Turn on FPS Counter before using this!",
			'debugInfo',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Main Menu Tips',
			"If unchecked, hides those tips at the top in the main menu!",
			'tipTexts',
			'bool',
			true);
		addOption(option);

		#if DISCORD_ALLOWED
		var option:Option = new Option('Discord Rich Presence',
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord",
			'discordRPC',
			'bool',
			true);
		addOption(option);
		#end

		var option:Option = new Option('Use Psych Engine\'s Crash Window',
			"If checked, it will use the Original Psych Engine's Crash Window instead of the UI Type.",
			'peOGCrash',
			'bool',
			false);
		addOption(option);

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];

		super();
		add(notes);
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);

		if(noteOptionID < 0) return;

		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = notes.members[i];
			if(notesTween[i] != null) notesTween[i].cancel();
			if(optionsArray[curSelected].name == 'Note Skins:')
				notesTween[i] = FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
			else
				notesTween[i] = FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
		}
	}

	function onChangeNoteSkin()
	{
		notes.forEachAlive(function(note:StrumNote) {
			changeNoteSkin(note);
			note.centerOffsets();
			note.centerOrigin();
		});
	}

	function changeNoteSkin(note:StrumNote)
	{
		var skin:String = Note.defaultNoteSkin;
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		note.texture = skin; //Load texture and anims
		note.reloadNote();
		note.playAnim('static');
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if(ClientPrefs.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.pauseMusic)));

		changedMusic = true;
	}

	var menuMusicChanged:Bool = false;
	function onChangeMenuMusic()
	{
			if (ClientPrefs.daMenuMusic != 'Default') FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
			else FlxG.sound.playMusic(Paths.music('freakyMenu'));
		menuMusicChanged = true;
	}

	override function destroy()
	{
		if(changedMusic) FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
		super.destroy();
	}

	#if !mobile
	function onChangeFPSCounter()
	{
		if(Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.showFPS;
	}
	#end
}
