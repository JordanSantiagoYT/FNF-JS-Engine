package editors;

import Character;
import flixel.FlxState;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.animation.FlxAnimation;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import lime.system.Clipboard;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

#if MODS_ALLOWED
#end


/**
	*DEBUG MODE
 */
class CharacterEditorState extends MusicBeatState
{
	var music:EditingMusic;
	var char:Character;
	var ghostChar:FlxSprite;
	var animateGhost:FlxAnimate;
	var animateGhostImage:String;
	var bgLayer:FlxTypedGroup<FlxSprite>;
	var charLayer:FlxTypedGroup<Character>;
	var ghostLayer:FlxTypedGroup<FlxSprite>;
	var animsTxt:FlxText;
	var frameAdvanceText:FlxText;
	var animList:Array<Dynamic> = null;
	var curAnim:Int = 0;
	var _char:String = 'spooky';
	var goToPlayState:Bool = true;
	var camFollow:FlxObject;

	// counts when you last saved
	/*
	var lastSaved:Int = 0;
	var isDirty:Bool = false;

	var currentCharacter:Character = null;
	var savedFile:Dynamic = null;
	*/
	var checkifChanged:Array<CharacterChange> = [];

	public function new(_char:String = 'spooky', goToPlayState:Bool = true)
	{
		super();
		this._char = _char;
		this.goToPlayState = goToPlayState;
	}

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;

	var UI_box:FlxUITabMenu;
	var UI_characterbox:FlxUITabMenu;

	var selectedFormat:FlxTextFormat = new FlxTextFormat(FlxColor.LIME);

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;
	private var camMenu:FlxCamera;

	var changeBGbutton:FlxButton;
	var leHealthIcon:HealthIcon;
	var characterList:Array<String> = [];

	var cameraFollowPointer:FlxSprite;
	var healthBarBG:FlxSprite;

	override function create()
	{
		music = new EditingMusic();

		camEditor = initPsychCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camMenu = new FlxCamera();
		camMenu.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camMenu, false);

		bgLayer = new FlxTypedGroup<FlxSprite>();
		add(bgLayer);
		charLayer = new FlxTypedGroup<Character>();
		add(charLayer);
		ghostLayer = new FlxTypedGroup<FlxSprite>();
		add(ghostLayer);

		cameraFollowPointer = new FlxSprite().loadGraphic(FlxGraphic.fromClass(GraphicCursorCross));
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		add(cameraFollowPointer);

		changeBGbutton = new FlxButton(FlxG.width - 360, 25, "", function()
		{
			onPixelBG = !onPixelBG;
			reloadBGs();
		});
		changeBGbutton.cameras = [camMenu];

		addCharacter();
		reloadBGs();

		healthBarBG = new FlxSprite(30, FlxG.height - 75).loadGraphic(Paths.image('editorHealthBar'));
		healthBarBG.scrollFactor.set();
		add(healthBarBG);
		healthBarBG.cameras = [camHUD];

		leHealthIcon = new HealthIcon(char.healthIcon, false);
		leHealthIcon.y = FlxG.height - 150;
		add(leHealthIcon);
		leHealthIcon.cameras = [camHUD];

		ghostChar = new FlxSprite();
		ghostChar.visible = false;
		ghostChar.alpha = ghostAlpha;
		ghostLayer.add(ghostChar);

		animsTxt = new FlxText(10, 32, 400, '');
		animsTxt.setFormat(null, 16, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		animsTxt.scrollFactor.set();
		animsTxt.borderSize = 1;
		animsTxt.cameras = [camHUD];
		add(animsTxt);

		updateText();

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);

		var tipText:FlxText = new FlxText(FlxG.width - 300, FlxG.height - 24, 300, "Press F1 for Help", 20);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;
		add(tipText);

		FlxG.camera.follow(camFollow, null, 999);

		var tabs = [
			{name: 'Ghost', label: 'Ghost'},
			{name: 'Settings', label: 'Settings'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camMenu];

		UI_box.resize(250, 120);
		UI_box.x = FlxG.width - 275;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		var tabs = [
			{name: 'Character', label: 'Character'},
			{name: 'Animations', label: 'Animations'},
			{name: 'Misc', label: 'Misc'},
		];
		UI_characterbox = new FlxUITabMenu(null, tabs, true);
		UI_characterbox.cameras = [camMenu];

		UI_characterbox.resize(350, 340);
		UI_characterbox.x = UI_box.x - 100;
		UI_characterbox.y = UI_box.y + UI_box.height;
		UI_characterbox.scrollFactor.set();
		add(UI_characterbox);
		add(UI_box);
		add(changeBGbutton);

		addSettingsUI();
		addGhostUI();
		addCharacterUI();
		addAnimationsUI();
		addMiscUI();

		UI_box.selected_tab_id = 'Settings';
		UI_characterbox.selected_tab_id = 'Character';

		frameAdvanceText = new FlxText(0, 75, 350, '');
		frameAdvanceText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		frameAdvanceText.scrollFactor.set();
		frameAdvanceText.borderSize = 1;
		frameAdvanceText.screenCenter(X);
		frameAdvanceText.cameras = [camHUD];
		add(frameAdvanceText);

		addHelpScreen();
		FlxG.mouse.visible = true;
		reloadCharacterOptions();

		super.create();
	}

	function addHelpScreen()
	{
		var str:Array<String> = ["CAMERA",
		"E/Q - Camera Zoom In/Out",
		"J/K/L/I - Move Camera",
		"R - Reset Camera Zoom",
		"",
		"CHARACTER",
		"T - Reset Current Offset",
		"W/S - Previous/Next Animation",
		"Space - Replay Animation",
		"Arrow Keys/Mouse & Right Click - Move Offset",
		"A/D - Frame Advance (Back/Forward)",
		"",
		"OTHER",
		"Hold Shift - Move Offsets 10x faster and Camera 4x faster"];

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.6;
		helpBg.cameras = [camMenu];
		helpBg.active = helpBg.visible = false;
		add(helpBg);

		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camMenu];
		for (i => txt in str)
		{
			if(txt.length < 1) continue;

			var helpText:FlxText = new FlxText(0, 0, 600, txt, 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			add(helpText);
			helpText.y += ((i - str.length/2) * 32) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	var barToUse:Int = 1;
	var onPixelBG:Bool = false;
	var OFFSET_X:Float = 300;
	function reloadBGs() {
		var i:Int = bgLayer.members.length-1;
		while(i >= 0) {
			var memb:FlxSprite = bgLayer.members[i];
			if(memb != null) {
				memb.kill();
				bgLayer.remove(memb);
				memb.destroy();
			}
			--i;
		}
		bgLayer.clear();
		var playerXDifference = 0;
		if(char.isPlayer) playerXDifference = 670;

		if(onPixelBG) {
			var playerYDifference:Float = 0;
			if(char.isPlayer) {
				playerXDifference += 200;
				playerYDifference = 220;
			}

			var bgSky:BGSprite = new BGSprite('weeb/weebSky', OFFSET_X - (playerXDifference / 2) - 300, 0 - playerYDifference, 0.1, 0.1);
			bgLayer.add(bgSky);
			bgSky.antialiasing = false;

			var repositionShit = -200 + OFFSET_X - playerXDifference;

			var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', repositionShit, -playerYDifference + 6, 0.6, 0.90);
			bgLayer.add(bgSchool);
			bgSchool.antialiasing = false;

			var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', repositionShit, -playerYDifference, 0.95, 0.95);
			bgLayer.add(bgStreet);
			bgStreet.antialiasing = false;

			var widShit = Std.int(bgSky.width * 6);
			var bgTrees:FlxSprite = new FlxSprite(repositionShit - 380, -800 - playerYDifference);
			bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
			bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
			bgTrees.animation.play('treeLoop');
			bgTrees.scrollFactor.set(0.85, 0.85);
			bgLayer.add(bgTrees);
			bgTrees.antialiasing = false;

			bgSky.setGraphicSize(widShit);
			bgSchool.setGraphicSize(widShit);
			bgStreet.setGraphicSize(widShit);
			bgTrees.setGraphicSize(Std.int(widShit * 1.4));

			bgSky.updateHitbox();
			bgSchool.updateHitbox();
			bgStreet.updateHitbox();
			bgTrees.updateHitbox();
			changeBGbutton.text = "Regular BG";
		} else {
			var bg:BGSprite = new BGSprite('stageback', -600 + OFFSET_X - playerXDifference, -300, 0.9, 0.9);
			bgLayer.add(bg);

			var stageFront:BGSprite = new BGSprite('stagefront', -650 + OFFSET_X - playerXDifference, 500, 0.9, 0.9);
			stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
			stageFront.updateHitbox();
			bgLayer.add(stageFront);
			changeBGbutton.text = "Pixel BG";
		}
	}

	var TemplateCharacter:String = '{
			"animations": [
				{
					"loop": false,
					"offsets": [
						0,
						0
					],
					"fps": 24,
					"anim": "idle",
					"indices": [],
					"name": "Dad idle dance"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singLEFT",
					"loop": false,
					"name": "Dad Sing Note LEFT"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singDOWN",
					"loop": false,
					"name": "Dad Sing Note DOWN"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singUP",
					"loop": false,
					"name": "Dad Sing Note UP"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singRIGHT",
					"loop": false,
					"name": "Dad Sing Note RIGHT"
				}
			],
			"no_antialiasing": false,
			"image": "characters/DADDY_DEAREST",
			"position": [
				0,
				0
			],
			"healthicon": "face",
			"flip_x": false,
			"healthbar_colors": [
				161,
				161,
				161
			],
			"camera_position": [
				0,
				0
			],
			"sing_duration": 6.1,
			"scale": 1,
			"vocals_file": null
		}';

	function addCharacter(reload:Bool = false)
	{
		var pos:Int = -1;
		if(char != null)
		{
			pos = members.indexOf(char);
			remove(char);
			char.destroy();
		}

		var isPlayer = (reload ? char.isPlayer : !predictCharacterIsNotPlayer(_char));
		char = new Character(0, 0, _char, isPlayer);
		if(!reload && char.editorIsPlayer != null && isPlayer != char.editorIsPlayer)
		{
			char.isPlayer = !char.isPlayer;
			char.flipX = (char.originalFlipX != char.isPlayer);
			if(check_player != null) check_player.checked = char.isPlayer;
		}
		char.debugMode = true;

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);

		if(pos > -1) charLayer.insert(pos, char);
		else charLayer.add(char);
		updateCharacterPositions();
		reloadCharacterOptions();
		try { reloadAnimList(); } catch(e) {}
		if(healthBarBG != null && leHealthIcon != null) resetHealthBarColor();
	}

	var ghostAlpha:Float = 0.6;
	function addGhostUI()
	{
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Ghost";

		//var hideGhostButton:FlxButton = null;
		var makeGhostButton:FlxButton = new FlxButton(25, 15, "Make Ghost", function() {
			var anim = animList[curAnim];
			if(!char.isAnimationNull())
			{
				var myAnim = animList[curAnim];
				if(!char.isAnimateAtlas)
				{
					ghostChar.loadGraphic(char.graphic);
					ghostChar.frames.frames = char.frames.frames;
					ghostChar.animation.copyFrom(char.animation);
					ghostChar.animation.play(char.animation.curAnim.name, true, false, char.animation.curAnim.curFrame);
					ghostChar.animation.pause();
				}
				else if(myAnim != null) //This is VERY unoptimized and bad, I hope to find a better replacement that loads only a specific frame as bitmap in the future.
				{
					if(animateGhost == null) //If I created the animateGhost on create() and you didn't load an atlas, it would crash the game on destroy, so we create it here
					{
						animateGhost = new FlxAnimate(ghostChar.x, ghostChar.y);
						animateGhost.showPivot = false;
						insert(members.indexOf(ghostChar), animateGhost);
						animateGhost.active = false;
					}

					if(animateGhost == null || animateGhostImage != char.imageFile)
						Paths.loadAnimateAtlas(animateGhost, char.imageFile);

					if(myAnim.indices != null && myAnim.indices.length > 0)
						animateGhost.anim.addBySymbolIndices('anim', myAnim.name, myAnim.indices, 0, false);
					else
						animateGhost.anim.addBySymbol('anim', myAnim.name, 0, false);

					animateGhost.anim.play('anim', true, false, char.atlas.anim.curFrame);
					animateGhost.anim.pause();

					animateGhostImage = char.imageFile;
				}

				var spr:FlxSprite = !char.isAnimateAtlas ? ghostChar : animateGhost;
				if(spr != null)
				{
					spr.setPosition(char.x, char.y);
					spr.antialiasing = char.antialiasing;
					spr.flipX = char.flipX;
					spr.alpha = ghostAlpha;

					spr.scale.set(char.scale.x, char.scale.y);
					spr.updateHitbox();

					spr.offset.set(char.offset.x, char.offset.y);
					spr.visible = true;

					var otherSpr:FlxSprite = (spr == animateGhost) ? ghostChar : animateGhost;
					if(otherSpr != null) otherSpr.visible = false;
				}
				/*hideGhostButton.active = true;
				hideGhostButton.alpha = 1;*/
				trace('created ghost image');
			}
		});

		var highlightGhost:FlxUICheckBox = new FlxUICheckBox(20 + makeGhostButton.x + makeGhostButton.width, makeGhostButton.y, null, null, "Highlight Ghost", 100);
		highlightGhost.callback = function()
		{
			var value = highlightGhost.checked ? 125 : 0;
			ghostChar.colorTransform.redOffset = value;
			ghostChar.colorTransform.greenOffset = value;
			ghostChar.colorTransform.blueOffset = value;
			if(animateGhost != null)
			{
				animateGhost.colorTransform.redOffset = value;
				animateGhost.colorTransform.greenOffset = value;
				animateGhost.colorTransform.blueOffset = value;
			}
		};

		var ghostAlphaSlider:FlxUISlider = new FlxUISlider(this, 'ghostAlpha', 10, makeGhostButton.y + 25, 0, 1, 210, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		ghostAlphaSlider.nameLabel.text = 'Opacity:';
		ghostAlphaSlider.decimals = 2;
		ghostAlphaSlider.callback = function(relativePos:Float) {
			ghostChar.alpha = ghostAlpha;
			if(animateGhost != null) animateGhost.alpha = ghostAlpha;
		};
		ghostAlphaSlider.value = ghostAlpha;

		tab_group.add(makeGhostButton);
		//tab_group.add(hideGhostButton);
		tab_group.add(highlightGhost);
		tab_group.add(ghostAlphaSlider);

		for (i in tab_group.members)
			i.cameras = [camMenu];
		
		UI_box.addGroup(tab_group);
	}

	var charDropDown:FlxUIDropDownMenuCustom;
	var check_player:FlxUICheckBox;
	function addSettingsUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Settings";

		check_player = new FlxUICheckBox(10, 60, null, null, "Playable Character", 100);
		check_player.checked = _char.startsWith('bf');
		check_player.callback = function()
		{
			char.isPlayer = !char.isPlayer;
			char.flipX = !char.flipX;
			updatePointerPos();
			reloadBGs();
			ghostChar.flipX = char.flipX;
		};

		charDropDown = new FlxUIDropDownMenuCustom(10, 30, FlxUIDropDownMenuCustom.makeStrIdLabelArray([''], true), function(character:String)
		{
			_char = characterList[Std.parseInt(character)];
			check_player.checked = _char.startsWith('bf');
			addCharacter(true);
			updatePresence();
			reloadCharacterDropDown();
		});
		charDropDown.selectedLabel = _char;
		reloadCharacterDropDown();
  		charDropDown.header.cameras = [camMenu]; //haxe is stupid, i have to set the header manually or it renders behind the menu

		var reloadCharacter:FlxButton = new FlxButton(140, 20, "Reload Char", function()
		{
			addCharacter(true);
			reloadCharacterDropDown();
		});

		var templateCharacter:FlxButton = new FlxButton(140, 50, "Load Template", function()
		{
			final _template:CharacterFile =
			{
				animations: [
					newAnim('idle', 'BF idle dance'),
					newAnim('singLEFT', 'BF NOTE LEFT0'),
					newAnim('singDOWN', 'BF NOTE DOWN0'),
					newAnim('singUP', 'BF NOTE UP0'),
					newAnim('singRIGHT', 'BF NOTE RIGHT0')
				],
				no_antialiasing: false,
				flip_x: false,
				healthicon: 'face',
				image: 'characters/BOYFRIEND',
				sing_duration: 4,
				scale: 1,
				healthbar_colors: [161, 161, 161],
				camera_position: [0, 0],
				position: [0, 0],
				vocals_file: null,
				noteskin: null,
				shake_screen: false,
				shake_intensity: 0,
				shake_duration: 0,
				health_drain: false,
				drain_floor: 0.05,
				drain_amount: 0.01
			};

			char.loadCharacterFile(_template);
			char.debugMode = true;
			char.color = FlxColor.WHITE;
			char.alpha = 1;
			reloadAnimList();
			reloadCharacterOptions();
			updateCharacterPositions();
			updatePointerPos();
			reloadCharacterDropDown();
			resetHealthBarColor();
		});
		templateCharacter.color = FlxColor.RED;
		templateCharacter.label.color = FlxColor.WHITE;

		tab_group.add(new FlxText(charDropDown.x, charDropDown.y - 18, 0, 'Character:'));
		tab_group.add(check_player);
		tab_group.add(reloadCharacter);
		tab_group.add(charDropDown);
		tab_group.add(reloadCharacter);
		tab_group.add(templateCharacter);

		for (i in tab_group.members)
			i.cameras = [camMenu];

		UI_box.addGroup(tab_group);
	}

	var changeBar:Bool = false;

	var imageInputText:FlxUIInputText;
	var noteskinText:FlxUIInputText;
	var healthIconInputText:FlxUIInputText;
	var vocalsInputText:FlxUIInputText;

	var singDurationStepper:FlxUINumericStepper;
	var scaleStepper:FlxUINumericStepper;
	var positionXStepper:FlxUINumericStepper;
	var positionYStepper:FlxUINumericStepper;
	var positionCameraXStepper:FlxUINumericStepper;
	var positionCameraYStepper:FlxUINumericStepper;

	var flipXCheckBox:FlxUICheckBox;
	var noAntialiasingCheckBox:FlxUICheckBox;

	var healthColorStepperR:FlxUINumericStepper;
	var healthColorStepperG:FlxUINumericStepper;
	var healthColorStepperB:FlxUINumericStepper;

	var barShowDropDown:FlxUIDropDownMenuCustom;

	function addCharacterUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Character";

		imageInputText = new FlxUIInputText(15, 30, 200, 'characters/BOYFRIEND', 8);
		imageInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		var reloadImage:FlxButton = new FlxButton(imageInputText.x + 210, imageInputText.y - 3, "Reload Image", function()
		{
			char.imageFile = imageInputText.text;
			reloadCharacterImage();
			if(char.animation.curAnim != null) {
				char.playAnim(char.animation.curAnim.name, true);
			}
		});

		var decideIconColor:FlxButton = new FlxButton(reloadImage.x, reloadImage.y + 30, "Get Icon Color", function()
			{
				var coolColor = FlxColor.fromInt(CoolUtil.dominantColor(leHealthIcon));
				healthColorStepperR.value = coolColor.red;
				healthColorStepperG.value = coolColor.green;
				healthColorStepperB.value = coolColor.blue;
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperR, null);
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperG, null);
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperB, null);
			});

		healthIconInputText = new FlxUIInputText(15, imageInputText.y + 35, 75, leHealthIcon.getCharacter(), 8);
		healthIconInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;

		vocalsInputText = new FlxUIInputText(15, healthIconInputText.y + 35, 75, char.vocalsFile != null ? char.vocalsFile : '', 8);
		vocalsInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;

		singDurationStepper = new FlxUINumericStepper(15, vocalsInputText.y + 45, 0.1, 4, 0, 999, 1);

		scaleStepper = new FlxUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 1);

		flipXCheckBox = new FlxUICheckBox(singDurationStepper.x + 80, singDurationStepper.y, null, null, "Flip X", 50);
		flipXCheckBox.checked = char.flipX;
		if(char.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.callback = function() {
			char.originalFlipX = !char.originalFlipX;
			char.flipX = char.originalFlipX;
			if(char.isPlayer) char.flipX = !char.flipX;

			ghostChar.flipX = char.flipX;
		};

		noAntialiasingCheckBox = new FlxUICheckBox(flipXCheckBox.x, flipXCheckBox.y + 40, null, null, "No Antialiasing", 80);
		noAntialiasingCheckBox.checked = char.noAntialiasing;
		noAntialiasingCheckBox.callback = function() {
			char.antialiasing = false;
			if(!noAntialiasingCheckBox.checked && ClientPrefs.globalAntialiasing) {
				char.antialiasing = true;
			}
			char.noAntialiasing = noAntialiasingCheckBox.checked;
			ghostChar.antialiasing = char.antialiasing;
		};

		positionXStepper = new FlxUINumericStepper(flipXCheckBox.x + 110, flipXCheckBox.y, 10, char.positionArray[0], -9000, 9000, 0);
		positionYStepper = new FlxUINumericStepper(positionXStepper.x + 60, positionXStepper.y, 10, char.positionArray[1], -9000, 9000, 0);

		positionCameraXStepper = new FlxUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, char.cameraPosition[0], -9000, 9000, 0);
		positionCameraYStepper = new FlxUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, char.cameraPosition[1], -9000, 9000, 0);

		var saveCharacterButton:FlxButton = new FlxButton(reloadImage.x, noAntialiasingCheckBox.y + 40, "Save Character", function() {
			saveCharacter();
		});

		healthColorStepperR = new FlxUINumericStepper(singDurationStepper.x, saveCharacterButton.y, 20, char.healthColorArray[0], 0, 255, 0);
		healthColorStepperG = new FlxUINumericStepper(singDurationStepper.x + 65, saveCharacterButton.y, 20, char.healthColorArray[1], 0, 255, 0);
		healthColorStepperB = new FlxUINumericStepper(singDurationStepper.x + 130, saveCharacterButton.y, 20, char.healthColorArray[2], 0, 255, 0);

		tab_group.add(new FlxText(15, healthColorStepperB.y + 20, 0, 'Noteskin:'));
		noteskinText = new FlxUIInputText(15, healthColorStepperB.y + 40, 200, '', 8);
		noteskinText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		tab_group.add(noteskinText);

		tab_group.add(new FlxText(15, imageInputText.y - 18, 0, 'Image file name:'));
		tab_group.add(new FlxText(15, healthIconInputText.y - 18, 0, 'Health icon name:'));
		tab_group.add(new FlxText(15, vocalsInputText.y - 18, 100, 'Vocals File Postfix:'));
		tab_group.add(new FlxText(15, singDurationStepper.y - 18, 0, 'Sing Animation length:'));
		tab_group.add(new FlxText(15, scaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(new FlxText(positionXStepper.x, positionXStepper.y - 18, 0, 'Character X/Y:'));
		tab_group.add(new FlxText(positionCameraXStepper.x, positionCameraXStepper.y - 18, 0, 'Camera X/Y:'));
		tab_group.add(new FlxText(healthColorStepperR.x, healthColorStepperR.y - 18, 0, 'Health bar R/G/B:'));
		tab_group.add(imageInputText);
		tab_group.add(reloadImage);
		tab_group.add(decideIconColor);
		tab_group.add(healthIconInputText);
		tab_group.add(vocalsInputText);
		tab_group.add(singDurationStepper);
		tab_group.add(scaleStepper);
		tab_group.add(flipXCheckBox);
		tab_group.add(noAntialiasingCheckBox);
		tab_group.add(positionXStepper);
		tab_group.add(positionYStepper);
		tab_group.add(positionCameraXStepper);
		tab_group.add(positionCameraYStepper);
		tab_group.add(healthColorStepperR);
		tab_group.add(healthColorStepperG);
		tab_group.add(healthColorStepperB);
		tab_group.add(saveCharacterButton);

		for (i in tab_group.members)
			i.cameras = [camMenu];

		UI_characterbox.addGroup(tab_group);
	}

	var minimumHealthStepper:FlxUINumericStepper;
	var drainAmountStepper:FlxUINumericStepper;
	var healthDrainCheckBox:FlxUICheckBox;

	var shakeIntensityStepper:FlxUINumericStepper;
	var shakeDurationStepper:FlxUINumericStepper;
	var shakeScreenBox:FlxUICheckBox;
	function addMiscUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Misc";

		healthDrainCheckBox = new FlxUICheckBox(15, 30, null, null, "Health Drain", 50);
		healthDrainCheckBox.checked = char.healthDrain;
		healthDrainCheckBox.callback = function() {
			char.healthDrain = healthDrainCheckBox.checked;
		};

		minimumHealthStepper = new FlxUINumericStepper(healthDrainCheckBox.x + 80, healthDrainCheckBox.y, 0.01, char.drainFloor, -1, 2, 3);
		minimumHealthStepper.name = 'minimumHealthStepper';

		drainAmountStepper = new FlxUINumericStepper(minimumHealthStepper.x + 90, healthDrainCheckBox.y, 0.005, char.drainAmount, 0, 2, 3);
		drainAmountStepper.name = 'drainAmountStepper';

		shakeScreenBox = new FlxUICheckBox(healthDrainCheckBox.x, healthDrainCheckBox.y + 40, null, null, "Shake Screen", 50);
		shakeScreenBox.checked = char.shakeScreen;
		shakeScreenBox.callback = function() {
			char.shakeScreen = shakeScreenBox.checked;
		};

		shakeIntensityStepper = new FlxUINumericStepper(shakeScreenBox.x + 80, shakeScreenBox.y, 0.0005, char.shakeIntensity, 0, 1, 4);
		shakeIntensityStepper.name = 'shakeIntensityStepper';

		shakeDurationStepper = new FlxUINumericStepper(shakeIntensityStepper.x + 90, shakeScreenBox.y, 0.01, char.shakeDuration, 0, 1, 4);
		shakeDurationStepper.name = 'shakeDurationStepper';

		tab_group.add(healthDrainCheckBox);
		tab_group.add(minimumHealthStepper);
		tab_group.add(drainAmountStepper);

		tab_group.add(shakeScreenBox);
		tab_group.add(shakeIntensityStepper);
		tab_group.add(shakeDurationStepper);

		tab_group.add(new FlxText(minimumHealthStepper.x, minimumHealthStepper.y - 18, 0, 'Minimum Health:'));
		tab_group.add(new FlxText(drainAmountStepper.x, drainAmountStepper.y - 18, 0, 'Drain Amount:'));

		tab_group.add(new FlxText(shakeIntensityStepper.x, shakeIntensityStepper.y - 18, 0, 'Shake Intensity:'));
		tab_group.add(new FlxText(shakeDurationStepper.x, shakeDurationStepper.y - 18, 0, 'Shake Duration:'));

		for (i in tab_group.members)
			i.cameras = [camMenu];

		UI_characterbox.addGroup(tab_group);
	}

	var animationDropDown:FlxUIDropDownMenuCustom;
	var animationInputText:FlxUIInputText;
	var animationNameInputText:FlxUIInputText;
	var animationIndicesInputText:FlxUIInputText;
	var animationFramerate:FlxUINumericStepper;
	var animationLoopCheckBox:FlxUICheckBox;
	function addAnimationsUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Animations";

		animationInputText = new FlxUIInputText(15, 85, 80, '', 8);
		animationInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		animationNameInputText = new FlxUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		animationNameInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		animationIndicesInputText = new FlxUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, '', 8);
		animationIndicesInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		animationFramerate = new FlxUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new FlxUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, null, null, "Should it Loop?", 100);

		animationDropDown = new FlxUIDropDownMenuCustom(15, animationInputText.y - 55, FlxUIDropDownMenuCustom.makeStrIdLabelArray([''], true), function(pressed:String) {
			var selectedAnimation:Int = Std.parseInt(pressed);
			var anim:AnimArray = char.animationsArray[selectedAnimation];
			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationFramerate.value = anim.fps;

			var indicesStr:String = anim.indices.toString();
			animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
		});
		animationDropDown.header.cameras = [camMenu];

		var addUpdateButton:FlxButton = new FlxButton(70, animationIndicesInputText.y + 30, "Add/Update", function() {
			var indices:Array<Int> = [];
			var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');
			if(indicesStr.length > 1) {
				for (i in 0...indicesStr.length) {
					var index:Int = Std.parseInt(indicesStr[i]);
					if(indicesStr[i] != null && indicesStr[i] != '' && !Math.isNaN(index) && index > -1) {
						indices.push(index);
					}
				}
			}

			var lastAnim:String = '';
			if(char.animationsArray[curAnim] != null) {
				lastAnim = char.animationsArray[curAnim].anim;
			}

			var lastOffsets:Array<Int> = [0, 0];
			for (anim in char.animationsArray) {
				if(animationInputText.text == anim.anim) {
					lastOffsets = anim.offsets;
					if(char.animOffsets.exists(animationInputText.text))
					{
						if(!char.isAnimateAtlas) char.animation.remove(animationInputText.text);
						else @:privateAccess char.atlas.anim.animsMap.remove(animationInputText.text);
					}
					char.animationsArray.remove(anim);
				}
			}

			var addedAnim:AnimArray = newAnim(animationInputText.text, animationNameInputText.text);
			addedAnim.fps = Math.round(animationFramerate.value);
			addedAnim.loop = animationLoopCheckBox.checked;
			addedAnim.indices = indices;
			addedAnim.offsets = lastOffsets;
			addAnimation(addedAnim.anim, addedAnim.name, addedAnim.fps, addedAnim.loop, addedAnim.indices);
			char.animationsArray.push(addedAnim);

			reloadAnimList();
			@:arrayAccess curAnim = Std.int(Math.max(0, char.animationsArray.indexOf(addedAnim)));
			char.playAnim(addedAnim.anim, true);
			trace('Added/Updated animation: ' + animationInputText.text);
		});

		var removeButton:FlxButton = new FlxButton(180, animationIndicesInputText.y + 30, "Remove", function() {
			for (anim in char.animationsArray) {
				if(animationInputText.text == anim.anim)
				{
					var resetAnim:Bool = false;
					if(anim.anim == char.getAnimationName()) resetAnim = true;
					if(char.hasAnimation(anim.anim))
					{
						if(!char.isAnimateAtlas) char.animation.remove(anim.anim);
						else @:privateAccess char.atlas.anim.animsMap.remove(anim.anim);
						char.animOffsets.remove(anim.anim);
						char.animationsArray.remove(anim);
					}

					if(resetAnim && char.animationsArray.length > 0) {
						curAnim = FlxMath.wrap(curAnim, 0, animList.length-1);
						char.playAnim(animList[curAnim].anim, true);
					}
					reloadAnimList();
					trace('Removed animation: ' + animationInputText.text);
					break;
				}
			}
		});
		reloadAnimList();

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tab_group.add(new FlxText(animationFramerate.x, animationFramerate.y - 18, 0, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, 'Animation on .XML/.TXT file:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, 'ADVANCED - Animation Indices:'));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationDropDown);

		for (i in tab_group.members)
			i.cameras = [camMenu];

		UI_characterbox.addGroup(tab_group);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			if(sender == healthIconInputText) {
				leHealthIcon.changeIcon(healthIconInputText.text);
				char.healthIcon = healthIconInputText.text;
				updatePresence();
			}
			else if(sender == vocalsInputText)
			{
				char.vocalsFile = vocalsInputText.text;
			}
			else if(sender == imageInputText) {
				char.imageFile = imageInputText.text;
			}
			else if(sender == noteskinText) {
				char.noteskin = noteskinText.text;
			}
		} else if(id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper)) {
			if (sender == scaleStepper)
			{
				reloadCharacterImage();
				char.jsonScale = sender.value;
				char.scale.set(char.jsonScale, char.jsonScale);
				char.updateHitbox();
				updatePointerPos();
			}
			else if(sender == positionXStepper)
			{
				char.positionArray[0] = positionXStepper.value;
				char.x = char.positionArray[0] + OFFSET_X + 100;
				updatePointerPos();
			}
			else if(sender == singDurationStepper)
			{
				char.singDuration = singDurationStepper.value;//ermm you forgot this??
			}
			else if(sender == positionYStepper)
			{
				char.positionArray[1] = positionYStepper.value;
				char.y = char.positionArray[1];
				updatePointerPos();
			}
			else if(sender == positionCameraXStepper)
			{
				char.cameraPosition[0] = positionCameraXStepper.value;
				updatePointerPos();
			}
			else if(sender == positionCameraYStepper)
			{
				char.cameraPosition[1] = positionCameraYStepper.value;
				updatePointerPos();
			}
			else if(sender == drainAmountStepper)
			{
				char.drainAmount = drainAmountStepper.value;
			}
			else if(sender == minimumHealthStepper)
			{
				char.drainFloor = minimumHealthStepper.value;
			}
			else if(sender == shakeIntensityStepper)
			{
				char.shakeIntensity = shakeIntensityStepper.value;
			}
			else if(sender == shakeDurationStepper)
			{
				char.shakeDuration = shakeDurationStepper.value;
			}
			else if(sender == healthColorStepperR)
			{
				char.healthColorArray[0] = Math.round(healthColorStepperR.value);
				if (barToUse == 1) healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
			else if(sender == healthColorStepperG)
			{
				char.healthColorArray[1] = Math.round(healthColorStepperG.value);
				if (barToUse == 1) healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
			else if(sender == healthColorStepperB)
			{
				char.healthColorArray[2] = Math.round(healthColorStepperB.value);
				if (barToUse == 1) healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
		}
	}

	function reloadCharacterImage()
	{
		var lastAnim:String = char.getAnimationName();
		var anims:Array<AnimArray> = char.animationsArray.copy();

		char.atlas = FlxDestroyUtil.destroy(char.atlas);
		char.isAnimateAtlas = false;
		char.color = FlxColor.WHITE;
		char.alpha = 1;

		if(Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT))
		{
			char.atlas = new FlxAnimate();
			char.atlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(char.atlas, char.imageFile);
			}
			catch(e:Dynamic)
			{
				FlxG.log.warn('Could not load atlas ${char.imageFile}: $e');
			}
			char.isAnimateAtlas = true;
		}
		else if (Paths.fileExists('images/' + char.imageFile + '.png', IMAGE))
		{
			var split:Array<String> = char.imageFile.split(',');
			var charFrames:FlxAtlasFrames = Paths.getAtlas(split[0].trim());

			if(split.length > 1)
			{
				var original:FlxAtlasFrames = charFrames;
				charFrames = new FlxAtlasFrames(charFrames.parent);
				charFrames.addAtlas(original, true);
				for (i in 1...split.length)
				{
					var extraFrames:FlxAtlasFrames = Paths.getAtlas(split[i].trim());
					if(extraFrames != null)
						charFrames.addAtlas(extraFrames, true);
				}
			}
			char.frames = charFrames;
		} else {
			trace ("The png file the game looked for wasn't found!");
			CoolUtil.coolError("The image/XML/Atlas files you tried to load couldn't be found!\nEither it doesn't exist, or the name doesn't match with the one you're putting?", "JS Engine Anti-Crash Tool");
		}

		for (anim in anims) {
			var animAnim:String = '' + anim.anim;
			var animName:String = '' + anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = !!anim.loop; //Bruh
			var animIndices:Array<Int> = anim.indices;
			addAnimation(animAnim, animName, animFps, animLoop, animIndices);
		}

		if(anims.length > 0)
		{
			if(lastAnim != '') char.playAnim(lastAnim, true);
			else char.dance();
		}
	}

	function updatePointerPos() {
		if(char == null || cameraFollowPointer == null) return;

		var offX:Float = 0;
		var offY:Float = 0;
		if(!char.isPlayer)
		{
			offX = char.getMidpoint().x + 150 + char.cameraPosition[0];
			offY = char.getMidpoint().y - 100 + char.cameraPosition[1];
		}
		else
		{
			offX = char.getMidpoint().x - 100 - char.cameraPosition[0];
			offY = char.getMidpoint().y - 100 + char.cameraPosition[1];
		}
		cameraFollowPointer.setPosition(offX, offY);
	}

	function findAnimationByName(name:String):AnimArray {
		for (anim in char.animationsArray) {
			if(anim.anim == name) {
				return anim;
			}
		}
		return null;
	}

	inline function updateCharacterPositions()
	{
		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);
		updatePointerPos();
	}

	inline function predictCharacterIsNotPlayer(name:String)
	{
		return (name != 'bf' && !name.startsWith('bf-') && !name.endsWith('-player') && !name.endsWith('-playable') && !name.endsWith('-dead')) ||
				name.endsWith('-opponent') || name.startsWith('gf-') || name.endsWith('-gf') || name == 'gf';
	}

	function addAnimation(anim:String, name:String, fps:Float, loop:Bool, indices:Array<Int>)
	{
		if(!char.isAnimateAtlas)
		{
			if(indices != null && indices.length > 0)
				char.animation.addByIndices(anim, name, indices, "", fps, loop);
			else
				char.animation.addByPrefix(anim, name, fps, loop);
		}
		else
		{
			if(indices != null && indices.length > 0)
				char.atlas.anim.addBySymbolIndices(anim, name, indices, fps, loop);
			else
				char.atlas.anim.addBySymbol(anim, name, fps, loop);
		}

		if(!char.animOffsets.exists(anim))
			char.addOffset(anim, 0, 0);
	}

	inline function newAnim(anim:String, name:String):AnimArray
	{
		return {
			offsets: [0, 0],
			loop: false,
			fps: 24,
			anim: anim,
			indices: [],
			name: name
		};
	}

	function reloadCharacterOptions() {
		if(UI_characterbox != null) {
			imageInputText.text = char.imageFile;
			if (char.noteskin != null) noteskinText.text = char.noteskin;
			healthIconInputText.text = char.healthIcon;
			vocalsInputText.text = char.vocalsFile != null ? char.vocalsFile : '';
			singDurationStepper.value = char.singDuration;
			scaleStepper.value = char.jsonScale;
			flipXCheckBox.checked = char.originalFlipX;
			noAntialiasingCheckBox.checked = char.noAntialiasing;
			resetHealthBarColor();
			leHealthIcon.changeIcon(healthIconInputText.text);
			positionXStepper.value = char.positionArray[0];
			positionYStepper.value = char.positionArray[1];
			positionCameraXStepper.value = char.cameraPosition[0];
			positionCameraYStepper.value = char.cameraPosition[1];
			reloadAnimationDropDown();
			updatePresence();
			shakeScreenBox.checked = char.shakeScreen;
			shakeIntensityStepper.value = char.shakeIntensity;
			shakeDurationStepper.value = char.shakeDuration;
			healthDrainCheckBox.checked = char.healthDrain;
			drainAmountStepper.value = char.drainAmount;
			minimumHealthStepper.value = char.drainFloor;
		}
	}

	inline function updateText()
	{
		animsTxt.removeFormat(selectedFormat);

		var intendText:String = '';
		for (num => anim in animList)
		{
			if(num > 0) intendText += '\n';

			if(num == curAnim)
			{
				var n:Int = intendText.length;
				intendText += anim.anim + ": " + anim.offsets;
				animsTxt.addFormat(selectedFormat, n, intendText.length);
			}
			else intendText += anim.anim + ": " + anim.offsets;
		}
		animsTxt.text = intendText;
	}

	inline function reloadAnimList()
	{
		animList = char.animationsArray;
		if(animList.length > 0) char.playAnim(animList[0].anim, true);
		curAnim = 0;

		updateText();
		if(animationDropDown != null) reloadAnimationDropDown();
	}

	function reloadAnimationDropDown() {
		var animationList:Array<String> = [];
		for (anim in animList) animationList.push(anim.anim);
		if(animationList.length < 1) animationList.push('NO ANIMATIONS'); //Prevents crash

		animationDropDown.setData(FlxUIDropDownMenuCustom.makeStrIdLabelArray(animationList, true));
	}

	function reloadCharacterDropDown() {
		var charsLoaded:Map<String, Bool> = new Map();

		#if MODS_ALLOWED
		characterList = [];
		var directories:Array<String> = [Paths.mods('characters/'), Paths.mods(Paths.currentModDirectory + '/characters/'), Paths.getPreloadPath('characters/')];
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/characters/'));
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!sys.FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var charToCheck:String = file.substr(0, file.length - 5);
						if(!charsLoaded.exists(charToCheck)) {
							characterList.push(charToCheck);
							charsLoaded.set(charToCheck, true);
						}
					}
				}
			}
		}
		#else
		characterList = CoolUtil.coolTextFile(Paths.txt('characterList'));
		#end

		charDropDown.setData(FlxUIDropDownMenuCustom.makeStrIdLabelArray(characterList, true));
		charDropDown.selectedLabel = _char;
	}

	function resetHealthBarColor() {
		healthColorStepperR.value = char.healthColorArray[0];
		healthColorStepperG.value = char.healthColorArray[1];
		healthColorStepperB.value = char.healthColorArray[2];

		healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
	}

	function updatePresence() {
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Character Editor", "Character: " + _char, leHealthIcon.getCharacter());
		#end
	}

	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.mouse.justPressed) FlxG.sound.play(Paths.sound('click'));
		MusicBeatState.camBeat = FlxG.camera;

		var inputTexts:Array<FlxUIInputText> = [animationInputText, imageInputText, healthIconInputText, animationNameInputText, animationIndicesInputText, noteskinText];
		for (i in 0...inputTexts.length) {
			if(inputTexts[i].hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				super.update(elapsed);
				return;
			}
		}
		FlxG.sound.muteKeys = TitleState.muteKeys;
		FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;

		if(FlxG.mouse.pressedRight && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0) && animList.length > 0)
		{
			char.animationsArray[curAnim].offsets[0] -= FlxG.mouse.deltaScreenX;
			char.animationsArray[curAnim].offsets[1] -= FlxG.mouse.deltaScreenY;
			char.offset.x -= FlxG.mouse.deltaScreenX;
			char.offset.y -= FlxG.mouse.deltaScreenY;

			char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
			updateText();
		}

		if(!charDropDown.dropPanel.visible) {
			if (FlxG.keys.justPressed.ESCAPE) {
				if(goToPlayState) {
					FlxG.switchState(PlayState.new);
				} else {
					FlxG.switchState(editors.MasterEditorMenu.new);
					FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
				}
				FlxG.mouse.visible = false;
				if (music != null && music.music != null) music.destroy();
				return;
			}

			if (FlxG.keys.justPressed.R) {
				FlxG.camera.zoom = 1;
			}

			var shiftMult:Float = 1;
			var ctrlMult:Float = 1;
			var shiftMultBig:Float = 1;
			if(FlxG.keys.pressed.SHIFT)
			{
				shiftMult = 4;
				shiftMultBig = 10;
			}

			if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
				FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult;
				if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
			}
			if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
				FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult;
				if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
			}

			if (FlxG.keys.pressed.I || FlxG.keys.pressed.J || FlxG.keys.pressed.K || FlxG.keys.pressed.L)
			{
				var addToCam:Float = 500 * elapsed * shiftMult;

				if (FlxG.keys.pressed.I)
					camFollow.y -= addToCam;
				else if (FlxG.keys.pressed.K)
					camFollow.y += addToCam;

				if (FlxG.keys.pressed.J)
					camFollow.x -= addToCam;
				else if (FlxG.keys.pressed.L)
					camFollow.x += addToCam;
			}

			var txt = 'ERROR: No Animation Found';
			var clr = FlxColor.RED;

			if(char.animationsArray.length > 0) {
				if(FlxG.keys.pressed.A || FlxG.keys.pressed.D)
				{
					holdingFrameTime += elapsed;
					if(holdingFrameTime > 0.5) holdingFrameElapsed += elapsed;
				}
				else holdingFrameTime = 0;

				if(FlxG.keys.justPressed.W) curAnim--;
				else if(FlxG.keys.justPressed.S) curAnim++;

				if (curAnim < 0)
					curAnim = char.animationsArray.length - 1;

				if (curAnim >= char.animationsArray.length)
					curAnim = 0;

				if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
				{
					char.playAnim(animList[curAnim].anim, true);
					updateText();
				}
				if (FlxG.keys.justPressed.T)
				{
					char.animationsArray[curAnim].offsets = [0, 0];

					char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
					updateText();
				}

				var controlArray:Array<Bool> = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];

				for (i in 0...controlArray.length) {
					if(controlArray[i]) {
						var holdShift = FlxG.keys.pressed.SHIFT;
						var multiplier = 1;
						if (holdShift)
							multiplier = 10;

						var arrayVal = 0;
						if(i > 1) arrayVal = 1;

						var negaMult:Int = 1;
						if(i % 2 == 1) negaMult = -1;
						char.animationsArray[curAnim].offsets[arrayVal] += negaMult * multiplier;

						char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);

						char.playAnim(char.animationsArray[curAnim].anim, false);
						updateText();
					}
				}
				var frames:Int = -1;
				var length:Int = -1;
				if(!char.isAnimateAtlas && char.animation.curAnim != null)
				{
					frames = char.animation.curAnim.curFrame;
					length = char.animation.curAnim.numFrames;
				}
				else if(char.isAnimateAtlas && char.atlas.anim != null)
				{
					frames = char.atlas.anim.curFrame;
					length = char.atlas.anim.length;
				}

				if(length >= 0)
				{
					if(FlxG.keys.justPressed.A || FlxG.keys.justPressed.D || holdingFrameTime > 0.5)
					{
						var isLeft = false;
						if((holdingFrameTime > 0.5 && FlxG.keys.pressed.A) || FlxG.keys.justPressed.A) isLeft = true;
						char.animPaused = true;

						if(holdingFrameTime <= 0.5 || holdingFrameElapsed > 0.1)
						{
							frames = FlxMath.wrap(frames + Std.int(isLeft ? -shiftMult : shiftMult), 0, length-1);
							if(!char.isAnimateAtlas) char.animation.curAnim.curFrame = frames;
							else char.atlas.anim.curFrame = frames;
							holdingFrameElapsed -= 0.1;
						}
					}

					txt = 'Frames: ( $frames / ${length-1} )';
					//if(character.animation.curAnim.paused) txt += ' - PAUSED';
					clr = FlxColor.WHITE;
				}
			}
			if(txt != frameAdvanceText.text) frameAdvanceText.text = txt;
			frameAdvanceText.color = clr;

			// OTHER CONTROLS
			if(FlxG.keys.justPressed.F1 || (helpBg.visible && FlxG.keys.justPressed.ESCAPE))
			{
				helpBg.visible = !helpBg.visible;
				helpTexts.visible = helpBg.visible;
			}
		}
		//camMenu.zoom = FlxG.camera.zoom;
		ghostChar.setPosition(char.x, char.y);
		super.update(elapsed);
		music.update(elapsed);
	}

	var _file:FileReference;
	/*private function saveOffsets()
	{
		var data:String = '';
		for (anim => offsets in char.animOffsets) {
			data += anim + ' ' + offsets[0] + ' ' + offsets[1] + '\n';
		}

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, _char + "Offsets.txt");
		}
	}*/

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved file.");
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}

	function saveCharacter() {
		var json = {
			"animations": char.animationsArray,
			"image": char.imageFile,
			"scale": char.jsonScale,
			"sing_duration": char.singDuration,
			"healthicon": char.healthIcon,
			"noteskin": char.noteskin,

			"position":	char.positionArray,
			"camera_position": char.cameraPosition,

			"flip_x": char.originalFlipX,
			"no_antialiasing": char.noAntialiasing,
			"healthbar_colors": char.healthColorArray,

			"vocals_file": char.vocalsFile,

			"health_drain": char.healthDrain,
			"drain_amount": char.drainAmount,
			"drain_floor": char.drainFloor,

			"shake_screen": char.shakeScreen,
			"shake_intensity": char.shakeIntensity,
			"shake_duration": char.shakeDuration
		};

		var data:String = Json.stringify(json, "\t");

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, _char + ".json");
		}
	}

	function ClipboardAdd(prefix:String = ''):String {
		if(prefix.toLowerCase().endsWith('v')) //probably copy paste attempt
		{
			prefix = prefix.substring(0, prefix.length-1);
		}

		var text:String = prefix + Clipboard.text.replace('\n', '');
		return text;
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

enum CharacterChange {
	CEditInfo(oldInfo:String, newInfo:String);
	CCreateAnim(animID:Int, animData:Dynamic);
	CEditAnim(name:String, oldData:Dynamic, animData:Dynamic);
	CDeleteAnim(animID:Int, animData:Dynamic);
	CChangeOffset(name:String, change:FlxPoint);
	CResetOffsets(oldOffsets:Map<String, FlxPoint>);
}
