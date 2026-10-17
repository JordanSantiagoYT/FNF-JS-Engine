package options;

import backend.Controls;
import flixel.addons.ui.FlxUIInputText; // These are both for the search bars
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import flixel.ui.FlxButton;

// REFACTOR: imports for relocated root classes
import backend.ClientPrefs;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import backend.DiscordClient;
import backend.MusicBeatSubstate;
import objects.Alphabet;
import objects.AttachedText;
import objects.Character;
import objects.CheckboxThingie;
import headers.Options;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var boyfriend:Character = null;
	private var descBox:FlxSprite;
	private var descText:FlxText;

	var optionSearchText:FlxUIInputText;
	var searchText:FlxText;
	private var buttonTop:FlxButton;
	private var background:FlxSprite;
	private var titleText:Alphabet;
	private var layoutWidth:Int = 0;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(background);
		final shift:Float = ScreenLayout.contentLeft(FlxG.width) - ScreenLayout.contentLeft(layoutWidth);
		if (grpOptions != null) grpOptions.forEach(item -> { item.startPosition.x += shift; item.x += shift; });
		if (grpTexts != null) grpTexts.forEach(item -> item.x += shift);
		if (checkboxGroup != null) checkboxGroup.forEach(item -> item.x += shift);
		if (titleText != null) titleText.x += shift;
		if (descText != null) descText.x += shift;
		if (descBox != null) descBox.x += shift;
		if (boyfriend != null) boyfriend.x += shift;
		if (optionSearchText != null) optionSearchText.x = FlxG.width - optionSearchText.width;
		if (buttonTop != null) buttonTop.x = FlxG.width - buttonTop.width;
		if (searchText != null && buttonTop != null) searchText.x = buttonTop.x + 195;
		layoutWidth = FlxG.width;
	}

	public var title:String;
	public var rpcTitle:String;

	public function new()
	{
		super();
		layoutWidth = FlxG.width;

		if(title == null) title = 'Options';
		if(rpcTitle == null) rpcTitle = 'Options Menu';

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end

		background = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		background.color = 0xFFea71fd;
		ViewportVisuals.cover(background);
		background.antialiasing = ClientPrefs.globalAntialiasing;
		add(background);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		titleText = new Alphabet(ScreenLayout.contentLeft(FlxG.width) + 75, 40, title, true);
		titleText.scaleX = 0.6;
		titleText.scaleY = 0.6;
		titleText.alpha = 0.4;
		add(titleText);

		descText = new FlxText(ScreenLayout.contentLeft(FlxG.width) + 50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		OptionsMenuHelpers.createOptionRow(this, optionsArray);

		changeSelection();
		reloadCheckboxes();

		originalOptionsArray = optionsArray.copy();

		optionSearchText = new FlxUIInputText(0, 0, 500, '', 16);
		optionSearchText.x = FlxG.width - optionSearchText.width;
		add(optionSearchText);

		buttonTop = new FlxButton(0, optionSearchText.y + optionSearchText.height + 5, "", function() {
			optionsSearch(optionSearchText.text);
		});
		buttonTop.setGraphicSize(Std.int(optionSearchText.width), 50);
		buttonTop.updateHitbox();
		buttonTop.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, RIGHT);
		buttonTop.x = FlxG.width - buttonTop.width;
		add(buttonTop);

		searchText = new FlxText(buttonTop.x + 195, buttonTop.y + 20, 100, "Search", 24);
		searchText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK);
		add(searchText);
		FlxG.mouse.visible = true;

		addVirtualPad(LEFT_FULL, A_B_C);
	}

	public function addOption(option:Option) {
		if(optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
	}

	var originalOptionsArray:Array<Option> = [];
	var optionsFound:Array<Option> = [];
	function optionsSearch(?query:String = '')
	{
		optionsFound = [];
		var foundOptions:Int = 0;
		final txt:FlxText = new FlxText(0, 0, 0, 'No options found matching your query', 16);
		txt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.scrollFactor.set();
		txt.screenCenter(XY);
		for (i in 0...originalOptionsArray.length) {
				if (query != null && query.length > 0) {
					var optionName = originalOptionsArray[i].name.toLowerCase();
					var q = query.toLowerCase();
					if (optionName.indexOf(q) != -1)
					{
						optionsFound.push(originalOptionsArray[i]);
						foundOptions++;
					}
				}
		}
		if (foundOptions > 0 || query.length <= 0){
			if (txt != null)
				remove(txt); // don't do destroy/kill on this btw
			regenerateOptions(query);
		}
		else if (foundOptions <= 0){
			add(txt);
			new FlxTimer().start(3, function(timer) {
				if (txt != null)
					remove(txt);
			});
			return;
		}
	}
	function regenerateOptions(?query:String = '') {
		if (query.length > 0) optionsArray = optionsFound;
		else if (optionsArray != originalOptionsArray) optionsArray = originalOptionsArray.copy();
		regenList();
	}

	function regenList() {
			grpOptions.forEach(option -> {
				grpOptions.remove(option, true);
				option.destroy();
			});
			grpTexts.forEach(text -> {
				grpTexts.remove(text, true);
				text.destroy();
			});
			checkboxGroup.forEach(check -> {
				checkboxGroup.remove(check, true);
				check.destroy();
			});

			//we clear the remaining ones
			grpOptions.clear();
			grpTexts.clear();
			checkboxGroup.clear();

		OptionsMenuHelpers.createOptionRow(this, optionsArray);

		changeSelection();
		reloadCheckboxes();
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	var _textThrottle:Float = 0;
	override function update(elapsed:Float)
	{
		if (!optionSearchText.hasFocus)
		{
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK) {
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept <= 0)
		{
			var usesCheckbox = true;
			if(curOption.type != 'bool')
			{
				usesCheckbox = false;
			}

			if(usesCheckbox || curOption.specialOption || curOption.type == 'link') // #45: link = press-to-run action
			{
				if(controls.ACCEPT && !curOption.specialOption)
				{
					FlxG.sound.play(Paths.sound((curOption.type == 'link' ? 'confirmMenu' : 'scrollMenu')));
					if (curOption.type == 'bool') curOption.setValue((curOption.getValue() == true) ? false : true);
					curOption.change();
					reloadCheckboxes();
				}
				else if (controls.ACCEPT && curOption.specialOption)
				{ // since it's not an checkbox
					FlxG.sound.play(Paths.sound('confirmMenu'));
					// curOption.setValue(curOption.getValue());
					curOption.change();
				}
			} else {
				if(controls.UI_LEFT || controls.UI_RIGHT) {
					var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
					if(holdTime > 0.5 || pressed) {
						if(pressed) {
							var add:Dynamic = null;
							if(curOption.type != 'string') {
								add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
							}

							switch(curOption.type)
							{
								case 'int' | 'float' | 'percent':
									holdValue = curOption.getValue() + add;
									if(holdValue < curOption.minValue) holdValue = curOption.minValue;
									else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

									switch(curOption.type)
									{
										case 'int':
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);

										case 'float' | 'percent':
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
									}

								case 'string':
									var num:Int = curOption.curOption; //lol
									if(controls.UI_LEFT_P) --num;
									else num++;

									if(num < 0) {
										num = curOption.options.length - 1;
									} else if(num >= curOption.options.length) {
										num = 0;
									}

									curOption.curOption = num;
									curOption.setValue(curOption.options[num]); //lol
									//trace(curOption.options[num]);
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.sound('scrollMenu'));
						} else if(curOption.type != 'string') {
							holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
							if(holdValue < curOption.minValue) holdValue = curOption.minValue;
							else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

							switch(curOption.type)
							{
								case 'int':
									curOption.setValue(Math.round(holdValue));

								case 'float' | 'percent':
									curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
							}
						_textThrottle += elapsed;
						if(_textThrottle >= 0.08) {
							_textThrottle = 0;
							updateTextFrom(curOption);
						}
						curOption.change();
						}
					}

					if(curOption.type != 'string') {
						holdTime += elapsed;
					}
				} else if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					clearHold();
				}
			}

			if(virtualPad.buttonC.justPressed || controls.RESET)
			{
				if (!FlxG.keys.pressed.SHIFT)
				{
					var leOption:Option = optionsArray[curSelected];
					leOption.setValue(leOption.defaultValue);
					if(leOption.type != 'bool')
					{
						if(leOption.type == 'string')
						{
							leOption.curOption = leOption.options.indexOf(leOption.getValue());
						}
						updateTextFrom(leOption);
					}
					leOption.change();
				}
				else
				for (i in 0...optionsArray.length)
				{
					var leOption:Option = optionsArray[i];
					leOption.setValue(leOption.defaultValue);
					if(leOption.type != 'bool')
					{
						if(leOption.type == 'string')
						{
							leOption.curOption = leOption.options.indexOf(leOption.getValue());
						}
						updateTextFrom(leOption);
					}
					leOption.change();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}
		}
		}

		if(boyfriend != null && boyfriend.animation.curAnim.finished) {
			boyfriend.dance();
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function updateTextFrom(option:Option) {
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == 'percent') val *= 100;
		var def:Dynamic = option.defaultValue;
		var newText:String = text.replace('%v', val).replace('%d', def);
		if(option.text != null && option.text == newText) return;
		option.text = newText;
	}

	function refreshDescription(option:Option)
	{
	    if (curOption == option)
	    {
	        descText.text = option.description;
					/*
	        descText.screenCenter(Y);
	        descText.y += 270;

	        descBox.setPosition(descText.x - 10, descText.y - 10);
	        descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
	        descBox.updateHitbox();
					*/
	    }
	}

	function clearHold()
	{
		if(holdTime > 0.5) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		holdTime = 0;
	}

	function changeSelection(change:Int = 0)
	{
		curSelected += change;
		if (curSelected < 0)
			curSelected = optionsArray.length - 1;
		if (curSelected >= optionsArray.length)
			curSelected = 0;

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;

		var selectionIndex:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = selectionIndex - curSelected;
			selectionIndex++;

			item.alpha = 0.6;
			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}
		for (text in grpTexts) {
			text.alpha = 0.6;
			if(text.ID == curSelected) {
				text.alpha = 1;
			}
		}

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		if(boyfriend != null)
		{
			boyfriend.visible = optionsArray[curSelected].showBoyfriend;
		}
		curOption = optionsArray[curSelected]; //shorter lol
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	public function reloadBoyfriend()
	{
		var wasVisible:Bool = false;
		if(boyfriend != null) {
			wasVisible = boyfriend.visible;
			boyfriend.kill();
			remove(boyfriend);
			boyfriend.destroy();
		}

		boyfriend = new Character(ScreenLayout.contentLeft(FlxG.width) + 840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		insert(1, boyfriend);
		boyfriend.visible = wasVisible;
	}

	function reloadCheckboxes() {
		for (checkbox in checkboxGroup) {
			checkbox.daValue = (optionsArray[checkbox.ID].getValue() == true);
		}
	}
}
