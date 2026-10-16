package editors;
import backend.ClientPrefs;
import backend.DiscordClient;
import backend.MusicBeatState;
import backend.Paths;
import states.TitleState;
import objects.Alphabet;
import objects.HealthIcon;
import objects.MenuCharacter;
import objects.MenuItem;

import backend.WeekData;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.ui.FlxButton;
import lime.system.Clipboard;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

// REFACTOR: imports for relocated root classes
import backend.Controls;
import data.Song;
import objects.BGSprite;

// REFACTOR: helper delegation
import headers.Editors;

class WeekEditorState extends MusicBeatState
{
	var txtWeekTitle:FlxText;
	var bgSprite:FlxSprite;
	var lock:FlxSprite;
	var txtTracklist:FlxText;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var weekThing:MenuItem;
	var missingFileText:FlxText;
	var music:EditingMusic;

	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
		else weekFileName = 'week1';
	}

	override function create() {
		music = new EditingMusic();
		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = ClientPrefs.globalAntialiasing;

		weekThing = new MenuItem(0, bgSprite.y + 396, weekFileName);
		weekThing.y += weekThing.height + 20;
		weekThing.antialiasing = ClientPrefs.globalAntialiasing;
		add(weekThing);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		lock = new FlxSprite();
		lock.frames = ui_tex;
		lock.animation.addByPrefix('lock', 'lock');
		lock.animation.play('lock');
		lock.antialiasing = ClientPrefs.globalAntialiasing;
		add(lock);

		missingFileText = new FlxText(0, 0, FlxG.width, "");
		missingFileText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingFileText.borderSize = 2;
		missingFileText.visible = false;
		add(missingFileText);

		var charArray:Array<String> = weekFile.weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07, bgSprite.y + 435).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.globalAntialiasing;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font("vcr.ttf");
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);
		add(txtWeekTitle);

		addEditorBox();
		reloadAll();

		FlxG.mouse.visible = true;

		super.create();
	}

	var UI_box:FlxUITabMenu;
	var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	function addEditorBox() {
		var tabs = [
			{name: 'Week', label: 'Week'},
			{name: 'Other', label: 'Other'},
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 375);
		UI_box.x = FlxG.width - UI_box.width;
		UI_box.y = FlxG.height - UI_box.height;
		UI_box.scrollFactor.set();
		addWeekUI();
		addOtherUI();

		UI_box.selected_tab_id = 'Week';
		add(UI_box);

		var loadWeekButton:FlxButton = new FlxButton(0, 650, "Load Week", function() {
			loadWeek();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);

		var freeplayButton:FlxButton = new FlxButton(0, 650, "Freeplay", function() {
			FlxG.switchState(() -> new WeekEditorFreeplayState(weekFile));
			if (music != null && music.music != null) music.destroy();

		});
		freeplayButton.screenCenter(X);
		add(freeplayButton);

		var saveWeekButton:FlxButton = new FlxButton(0, 650, "Save Week", function() {
			saveWeek(weekFile);
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}

	var songsInputText:FlxUIInputText;
	var backgroundInputText:FlxUIInputText;
	var displayNameInputText:FlxUIInputText;
	var weekNameInputText:FlxUIInputText;
	var weekFileInputText:FlxUIInputText;

	var opponentInputText:FlxUIInputText;
	var boyfriendInputText:FlxUIInputText;
	var girlfriendInputText:FlxUIInputText;

	var hideCheckbox:FlxUICheckBox;

	public static var weekFileName:String = 'week1';

	function addWeekUI() {
		WeekEditorHelpers.addWeekUI(this);
	}

	var weekBeforeInputText:FlxUIInputText;
	var difficultiesInputText:FlxUIInputText;
	var lockedCheckbox:FlxUICheckBox;
	var hiddenUntilUnlockCheckbox:FlxUICheckBox;

	function addOtherUI() {
		WeekEditorHelpers.addOtherUI(this);
	}

	//Used on onCreate and when you load a week
	function reloadAll() {
		WeekEditorHelpers.reloadAll(this);
	}

	function updateText()
	{
		WeekEditorHelpers.updateText(this);
	}

	function reloadBG() {
		WeekEditorHelpers.reloadBG(this);
	}

	function reloadWeekThing() {
		WeekEditorHelpers.reloadWeekThing(this);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			if(sender == weekFileInputText) {
				weekFileName = weekFileInputText.text.trim();
				reloadWeekThing();
			} else if(sender == opponentInputText || sender == boyfriendInputText || sender == girlfriendInputText) {
				weekFile.weekCharacters[0] = opponentInputText.text.trim();
				weekFile.weekCharacters[1] = boyfriendInputText.text.trim();
				weekFile.weekCharacters[2] = girlfriendInputText.text.trim();
				updateText();
			} else if(sender == backgroundInputText) {
				weekFile.weekBackground = backgroundInputText.text.trim();
				reloadBG();
			} else if(sender == displayNameInputText) {
				weekFile.storyName = displayNameInputText.text.trim();
				updateText();
			} else if(sender == weekNameInputText) {
				weekFile.weekName = weekNameInputText.text.trim();
			} else if(sender == songsInputText) {
				var splittedText:Array<String> = songsInputText.text.trim().split(',');
				for (i in 0...splittedText.length) {
					splittedText[i] = splittedText[i].trim();
				}

				while(splittedText.length < weekFile.songs.length) {
					weekFile.songs.pop();
				}

				for (i in 0...splittedText.length) {
					if(i >= weekFile.songs.length) { //Add new song
						weekFile.songs.push([splittedText[i], 'dad', [146, 113, 253]]);
					} else { //Edit song
						weekFile.songs[i][0] = splittedText[i];
						if(weekFile.songs[i][1] == null || weekFile.songs[i][1]) {
							weekFile.songs[i][1] = 'dad';
							weekFile.songs[i][2] = [146, 113, 253];
						}
					}
				}
				updateText();
			} else if(sender == weekBeforeInputText) {
				weekFile.weekBefore = weekBeforeInputText.text.trim();
			} else if(sender == difficultiesInputText) {
				weekFile.difficulties = difficultiesInputText.text.trim();
			}
		}
	}

	override function update(elapsed:Float)
	{
		if (FlxG.mouse.justPressed) FlxG.sound.play(Paths.sound('click'));
		if(loadedWeek != null) {
			weekFile = loadedWeek;
			loadedWeek = null;

			reloadAll();
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if(inputText.hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;

				if(FlxG.keys.justPressed.ENTER) inputText.hasFocus = false;
				break;
			}
		}

		if(!blockInput) {
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			if(FlxG.keys.justPressed.ESCAPE) {
				FlxG.switchState(editors.MasterEditorMenu.new);
				FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
				if (music != null && music.music != null) music.destroy();
			}
		}

		super.update(elapsed);
		music.update(elapsed);

		lock.y = weekThing.y;
		missingFileText.y = weekThing.y + 36;
	}

	function recalculateStuffPosition() {
		WeekEditorHelpers.recalculateStuffPosition(this);
	}

	private static var _file:FileReference;
	public static function loadWeek() {
		WeekEditorHelpers.loadWeek();
	}

	public static var loadedWeek:WeekFile = null;
	public static var loadError:Bool = false;
	private static function onLoadComplete(_):Void
	{
		WeekEditorHelpers.onLoadComplete(_);
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
		private static function onLoadCancel(_):Void
	{
		WeekEditorHelpers.onLoadCancel(_);
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private static function onLoadError(_):Void
	{
		WeekEditorHelpers.onLoadError(_);
	}

	public static function saveWeek(weekFile:WeekFile) {
		WeekEditorHelpers.saveWeek(weekFile);
	}

	private static function onSaveComplete(_):Void
	{
		WeekEditorHelpers.onSaveComplete(_);
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
		private static function onSaveCancel(_):Void
	{
		WeekEditorHelpers.onSaveCancel(_);
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private static function onSaveError(_):Void
	{
		WeekEditorHelpers.onSaveError(_);
	}
	override public function onFocusLost():Void
	    {
		    if (music != null && music.music != null) music.pauseMusic();

		    super.onFocusLost();
	    }
	override public function onFocus():Void
	    {
		    if (music != null && music.music != null) music.unpauseMusic();

		    super.onFocus();
	    }
}

class WeekEditorFreeplayState extends MusicBeatState
{
	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
	}

	var bg:FlxSprite;
	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<HealthIcon> = [];
	var music:EditingMusic;

	var curSelected = 0;

	override function create() {
		music = new EditingMusic();
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;

		bg.color = FlxColor.WHITE;
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...weekFile.songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, weekFile.songs[i][0], true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);
			songText.snapToPosition();

			var icon:HealthIcon = new HealthIcon(weekFile.songs[i][1]);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}

		addEditorBox();
		changeSelection();

		super.create();
	}

	var UI_box:FlxUITabMenu;
	var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	function addEditorBox() {
		var tabs = [
			{name: 'Freeplay', label: 'Freeplay'},
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 200);
		UI_box.x = FlxG.width - UI_box.width - 100;
		UI_box.y = FlxG.height - UI_box.height - 60;
		UI_box.scrollFactor.set();

		UI_box.selected_tab_id = 'Week';
		addFreeplayUI();
		add(UI_box);

		var blackBlack:FlxSprite = new FlxSprite(0, 670).makeGraphic(FlxG.width, 50, FlxColor.BLACK);
		blackBlack.alpha = 0.6;
		add(blackBlack);

		var loadWeekButton:FlxButton = new FlxButton(0, 685, "Load Week", function() {
			WeekEditorState.loadWeek();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);

		var storyModeButton:FlxButton = new FlxButton(0, 685, "Story Mode", function() {
			FlxG.switchState(() -> new WeekEditorState(weekFile));
			if (music != null && music.music != null) music.destroy();
		});
		storyModeButton.screenCenter(X);
		add(storyModeButton);

		var saveWeekButton:FlxButton = new FlxButton(0, 685, "Save Week", function() {
			WeekEditorState.saveWeek(weekFile);
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			weekFile.songs[curSelected][1] = iconInputText.text;
			iconArray[curSelected].changeIcon(iconInputText.text);
		} else if(id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper)) {
			if(sender == bgColorStepperR || sender == bgColorStepperG || sender == bgColorStepperB) {
				updateBG();
			}
		}
	}

	var bgColorStepperR:FlxUINumericStepper;
	var bgColorStepperG:FlxUINumericStepper;
	var bgColorStepperB:FlxUINumericStepper;
	var iconInputText:FlxUIInputText;
	function addFreeplayUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Freeplay";

		bgColorStepperR = new FlxUINumericStepper(10, 40, 20, 255, 0, 255, 0);
		bgColorStepperG = new FlxUINumericStepper(80, 40, 20, 255, 0, 255, 0);
		bgColorStepperB = new FlxUINumericStepper(150, 40, 20, 255, 0, 255, 0);

		var copyColor:FlxButton = new FlxButton(10, bgColorStepperR.y + 25, "Copy Color", function() {
			Clipboard.text = bg.color.red + ',' + bg.color.green + ',' + bg.color.blue;
		});
		var pasteColor:FlxButton = new FlxButton(140, copyColor.y, "Paste Color", function() {
			if(Clipboard.text != null) {
				var leColor:Array<Int> = [];
				var splitted:Array<String> = Clipboard.text.trim().split(',');
				for (i in 0...splitted.length) {
					var toPush:Int = Std.parseInt(splitted[i]);
					if(!Math.isNaN(toPush)) {
						if(toPush > 255) toPush = 255;
						else if(toPush < 0) toPush *= -1;
						leColor.push(toPush);
					}
				}

				if(leColor.length > 2) {
					bgColorStepperR.value = leColor[0];
					bgColorStepperG.value = leColor[1];
					bgColorStepperB.value = leColor[2];
					updateBG();
				}
			}
		});

		iconInputText = new FlxUIInputText(10, bgColorStepperR.y + 70, 100, '', 8);
		iconInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;

		var hideFreeplayCheckbox:FlxUICheckBox = new FlxUICheckBox(10, iconInputText.y + 30, null, null, "Hide Week from Freeplay?", 100);
		hideFreeplayCheckbox.checked = weekFile.hideFreeplay;
		hideFreeplayCheckbox.callback = function()
		{
			weekFile.hideFreeplay = hideFreeplayCheckbox.checked;
		};

		tab_group.add(new FlxText(10, bgColorStepperR.y - 18, 0, 'Selected background Color R/G/B:'));
		tab_group.add(new FlxText(10, iconInputText.y - 18, 0, 'Selected icon:'));
		tab_group.add(bgColorStepperR);
		tab_group.add(bgColorStepperG);
		tab_group.add(bgColorStepperB);
		tab_group.add(copyColor);
		tab_group.add(pasteColor);
		tab_group.add(iconInputText);
		tab_group.add(hideFreeplayCheckbox);
		UI_box.addGroup(tab_group);
	}

	function updateBG() {
		weekFile.songs[curSelected][2][0] = Math.round(bgColorStepperR.value);
		weekFile.songs[curSelected][2][1] = Math.round(bgColorStepperG.value);
		weekFile.songs[curSelected][2][2] = Math.round(bgColorStepperB.value);
		bg.color = FlxColor.fromRGB(weekFile.songs[curSelected][2][0], weekFile.songs[curSelected][2][1], weekFile.songs[curSelected][2][2]);
	}

	function changeSelection(change:Int = 0) {
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = weekFile.songs.length - 1;
		if (curSelected >= weekFile.songs.length)
			curSelected = 0;

		var selectionIndex:Int = 0;
		for (i in 0...iconArray.length)
		{
			iconArray[i].alpha = 0.6;
		}

		iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members)
		{
			item.targetY = selectionIndex - curSelected;
			selectionIndex++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
		iconInputText.text = weekFile.songs[curSelected][1];
		bgColorStepperR.value = Math.round(weekFile.songs[curSelected][2][0]);
		bgColorStepperG.value = Math.round(weekFile.songs[curSelected][2][1]);
		bgColorStepperB.value = Math.round(weekFile.songs[curSelected][2][2]);
		updateBG();
	}

	override function update(elapsed:Float) {
		if (FlxG.mouse.justPressed) FlxG.sound.play(Paths.sound('click'));
		if(WeekEditorState.loadedWeek != null) {
			super.update(elapsed);
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(() -> new WeekEditorFreeplayState(WeekEditorState.loadedWeek));
			if (music != null && music.music != null) music.destroy();
			WeekEditorState.loadedWeek = null;
			return;
		}

		if(iconInputText.hasFocus) {
			FlxG.sound.muteKeys = [];
			FlxG.sound.volumeDownKeys = [];
			FlxG.sound.volumeUpKeys = [];
			if(FlxG.keys.justPressed.ENTER) {
				iconInputText.hasFocus = false;
			}
		} else {
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			if(FlxG.keys.justPressed.ESCAPE) {
				FlxG.switchState(editors.MasterEditorMenu.new);
				FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
				if (music != null && music.music != null) music.destroy();
			}

			if(controls.UI_UP_P) changeSelection(-1);
			if(controls.UI_DOWN_P) changeSelection(1);
		}
		super.update(elapsed);
	}
	override public function onFocusLost():Void
	    {
		    if (music != null && music.music != null) music.pauseMusic();

		    super.onFocusLost();
	    }
	override public function onFocus():Void
	    {
		    if (music != null && music.music != null) music.unpauseMusic();

		    super.onFocus();
	    }
}

