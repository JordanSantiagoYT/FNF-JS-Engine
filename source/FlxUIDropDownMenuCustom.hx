package;

import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIAssets;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUIGroup;
import flixel.addons.ui.FlxUISpriteButton;
import flixel.addons.ui.FlxUIText;
import flixel.addons.ui.StrNameLabel;
import flixel.addons.ui.interfaces.IFlxUIClickable;
import flixel.addons.ui.interfaces.IFlxUIWidget;
import flixel.addons.ui.interfaces.IHasParams;
import flixel.ui.FlxButton;


/*

THIS IS AN EDIT OF FlxUIDropDownMenu I'VE MADE BECAUSE I'M TIRED OF IT NOT SUPPORTING SCROLLING UP/DOWN
BAH!

The differences are the following:
* Support to scrolling up/down with mouse wheel or arrow keys
* THe default drop direction is "Down" instead of "Automatic"

*/



/**
 * @author larsiusprime
 */
class FlxUIDropDownMenuCustom extends FlxUIGroup implements IFlxUIWidget implements IFlxUIClickable implements IHasParams
{
	public var skipButtonUpdate(default, set):Bool;

	private function set_skipButtonUpdate(b:Bool):Bool
	{
		skipButtonUpdate = b;
		header.button.skipButtonUpdate = b;
		return b;
	}

	public var selectedId(get, set):String;
	public var selectedLabel(get, set):String;

	private var _selectedId:String;
	private var _selectedLabel:String;

	private var dataList:Array<StrNameLabel> = [];
	private var visibleCount:Int = 10;

	private var currentScroll:Int = 0; //Handles the scrolling
	public var canScroll:Bool = true;

	private function get_selectedId():String
	{
		return _selectedId;
	}

	private function set_selectedId(str:String):String
	{
		for (data in dataList)
		{
			if (data.name == str)
			{
				_selectedId = str;
				_selectedLabel = data.label;
				header.text.text = data.label;
				break;
			}
		}

		return str;
	}

	private function get_selectedLabel():String
	{
		return _selectedLabel;
	}

	private function set_selectedLabel(str:String):String
	{
		for (data in dataList)
		{
			if (data.label == str)
			{
				_selectedId = data.name;
				_selectedLabel = str;
				header.text.text = str;
				break;
			}
		}

		return str;
	}

	/**
	 * The header of this dropdown menu.
	 */
	public var header:FlxUIDropDownHeader;

	/**
	 * The list of items that is shown when the toggle button is clicked.
	 */
	public var list:Array<FlxUIButton> = [];

	/**
	 * The background for the list.
	 */
	public var dropPanel:FlxUI9SliceSprite;

	public var params(default, set):Array<Dynamic>;

	private function set_params(p:Array<Dynamic>):Array<Dynamic>
	{
		return params = p;
	}

	public var dropDirection(default, set):FlxUIDropDownMenuDropDirection = Down;

	private function set_dropDirection(dropDirection):FlxUIDropDownMenuDropDirection
	{
		this.dropDirection = dropDirection;
		updateButtonPositions();
		return dropDirection;
	}

	public static inline var CLICK_EVENT:String = "click_dropdown";

	public var callback:String->Void;

	// private var _ui_control_callback:Bool->FlxUIDropDownMenuCustom->Void;

	/**
	 * This creates a new dropdown menu.
	 *
	 * @param	X					x position of the dropdown menu
	 * @param	Y					y position of the dropdown menu
	 * @param	DataList			The data to be displayed
	 * @param	Callback			Optional Callback
	 * @param	Header				The header of this dropdown menu
	 * @param	DropPanel			Optional 9-slice-background for actual drop down menu
	 * @param	ButtonList			Optional list of buttons to be used for the corresponding entry in DataList
	 * @param	UIControlCallback	Used internally by FlxUI
	 */
	public function new(X:Float = 0, Y:Float = 0, DataList:Array<StrNameLabel>, ?Callback:String->Void, ?Header:FlxUIDropDownHeader,
			?DropPanel:FlxUI9SliceSprite, ?ButtonList:Array<FlxUIButton>, ?UIControlCallback:Bool->FlxUIDropDownMenuCustom->Void)
	{
		super(X, Y);
		callback = Callback;
		header = Header;
		dropPanel = DropPanel;

		if (header == null)
			header = new FlxUIDropDownHeader();

		if (dropPanel == null)
		{
			var rect = new Rectangle(0, 0, header.background.width, header.background.height);
			dropPanel = new FlxUI9SliceSprite(0, 0, FlxUIAssets.IMG_BOX, rect, [1, 1, 14, 14]);
		}

		if (DataList != null)
		{
			dataList = DataList;

			var count = Std.int(Math.min(visibleCount, dataList.length));
			for (i in 0...count)
			{
				var data = dataList[i];
				list.push(makeListButton(i, data.label, data.name));
			}

			if (dataList.length > 0)
				selectSomething(dataList[0].name, dataList[0].label);
		}
		else if (ButtonList != null)
		{
			dataList = [];
			for (btn in ButtonList)
			{
				list.push(btn);
				btn.resize(header.background.width, header.background.height);
				btn.x = 1;
			}
		}
		updateButtonPositions();

		dropPanel.resize(header.background.width, getPanelHeight());
		dropPanel.visible = false;
		add(dropPanel);

		for (btn in list)
		{
			add(btn);
			btn.visible = false;
		}

		// _ui_control_callback = UIControlCallback;
		header.button.onUp.callback = onDropdown;
		add(header);
	}

	private function updateButtonPositions():Void
	{
		var buttonHeight = header.background.height;
		dropPanel.y = header.background.y;

		if (dropsUp())
			dropPanel.y -= getPanelHeight();
		else
			dropPanel.y += buttonHeight;

		for (i in 0...list.length)
		{
			var button = list[i];

			if (button != null)
			{
				if (i < dataList.length && i < visibleCount)
				{
					button.y = dropPanel.y + i * buttonHeight;
					button.visible = dropPanel.visible;
					button.active = dropPanel.visible;
				}
				else
				{
					button.y = -99999;
					button.visible = false;
					button.active = false;
				}
			}
		}
	}

	private function refreshVisibleButtons():Void
	{
		for (i in 0...list.length)
		{
			var button = list[i];
			var dataIndex = currentScroll + i;

			if (button != null && dataIndex < dataList.length)
			{
				var data = dataList[dataIndex];

				button.name = data.name;
				button.label.text = data.label;
				button.visible = dropPanel.visible;
				button.active = dropPanel.visible;
			}
			else if (button != null)
			{
				button.visible = false;
				button.active = false;
			}
		}

		updateButtonPositions();
	}

	override function set_visible(Value:Bool):Bool
	{
		var vDropPanel = dropPanel.visible;
		var vButtons = [];
		for (i in 0...list.length)
		{
			if (list[i] != null)
			{
				vButtons.push(list[i].visible);
			}
			else
			{
				vButtons.push(false);
			}
		}
		super.set_visible(Value);
		dropPanel.visible = vDropPanel;
		for (i in 0...list.length)
		{
			if (list[i] != null)
			{
				list[i].visible = vButtons[i];
			}
		}
		return Value;
	}

	private function dropsUp():Bool
	{
		return dropDirection == Up || (dropDirection == Automatic && exceedsHeight());
	}

	private function exceedsHeight():Bool
	{
		return y + getPanelHeight() + header.background.height > FlxG.height;
	}

	private function getPanelHeight():Float
	{
		var count = Std.int(Math.min(visibleCount, dataList.length));
		return count * header.background.height;
	}

	/**
	 * Change the contents with a new data list
	 * Replaces the old content with the new content
	 */
	public function setData(DataList:Array<StrNameLabel>):Void
	{
		dataList = DataList == null ? [] : DataList;
		currentScroll = 0;

		var count = Std.int(Math.min(visibleCount, dataList.length));

		while (list.length > count)
		{
			var button = list.pop();
			remove(button, true);
			button.destroy();
		}

		while (list.length < count)
		{
			var i = list.length;
			var data = dataList[i];
			var button = makeListButton(i, data.label, data.name);

			list.push(button);
			add(button);
			button.visible = false;
		}

		if (dataList.length > 0)
			selectSomething(dataList[0].name, dataList[0].label);
		else
		{
			_selectedId = "";
			_selectedLabel = "";
			header.text.text = "";
		}

		dropPanel.resize(header.background.width, getPanelHeight());
		refreshVisibleButtons();
	}

	private function selectSomething(name:String, label:String):Void
	{
		header.text.text = label;
		selectedId = name;
		selectedLabel = label;
	}

	private function makeListButton(i:Int, Label:String, Name:String):FlxUIButton
	{
		var t:FlxUIButton = new FlxUIButton(0, 0, Label);
		t.broadcastToFlxUI = false;
		t.onUp.callback = onClickItem.bind(i);

		t.name = Name;

		t.loadGraphicSlice9([FlxUIAssets.IMG_INVIS, FlxUIAssets.IMG_HILIGHT, FlxUIAssets.IMG_HILIGHT], Std.int(header.background.width),
			Std.int(header.background.height), [[1, 1, 3, 3], [1, 1, 3, 3], [1, 1, 3, 3]], FlxUI9SliceSprite.TILE_NONE);
		t.labelOffsets[FlxButton.PRESSED].y -= 1; // turn off the 1-pixel depress on click

		t.up_color = FlxColor.BLACK;
		t.over_color = FlxColor.WHITE;
		t.down_color = FlxColor.WHITE;

		t.resize(header.background.width - 2, header.background.height - 1);

		t.label.alignment = "left";
		t.autoCenterLabel();
		t.x = 1;

		for (offset in t.labelOffsets)
		{
			offset.x += 2;
		}

		return t;
	}

	/*public function setUIControlCallback(UIControlCallback:Bool->FlxUIDropDownMenuCustom->Void):Void {
		_ui_control_callback = UIControlCallback;
	}*/
	public function changeLabelByIndex(i:Int, NewLabel:String):Void
	{
		var btn:FlxUIButton = getBtnByIndex(i);
		if (btn != null && btn.label != null)
		{
			btn.label.text = NewLabel;
		}
	}

	public function changeLabelById(name:String, NewLabel:String):Void
	{
		var btn:FlxUIButton = getBtnById(name);
		if (btn != null && btn.label != null)
		{
			btn.label.text = NewLabel;
		}
	}

	public function getBtnByIndex(i:Int):FlxUIButton
	{
		if (i >= 0 && i < list.length)
		{
			return list[i];
		}
		return null;
	}

	public function getBtnById(name:String):FlxUIButton
	{
		for (btn in list)
		{
			if (btn.name == name)
			{
				return btn;
			}
		}
		return null;
	}

	public override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if FLX_MOUSE
		if (dropPanel.visible)
		{
			if(list.length > 0 && canScroll) {
				var maxScroll = Std.int(Math.max(0, dataList.length - visibleCount));
				var oldScroll = currentScroll;

				if (FlxG.mouse.wheel > 0 || FlxG.keys.justPressed.UP)
					currentScroll = Std.int(Math.max(0, currentScroll - 1));
				else if (FlxG.mouse.wheel < 0 || FlxG.keys.justPressed.DOWN)
					currentScroll = Std.int(Math.min(maxScroll, currentScroll + 1));

				if (currentScroll != oldScroll)
					refreshVisibleButtons();
			}

			if (FlxG.mouse.justPressed && !mouseOverlapping())
			{
				showList(false);
			}
		}
		#end
	}

	function mouseOverlapping()
	{
		var mousePoint = FlxG.mouse.getScreenPosition(camera);
		var objPoint = this.getScreenPosition(null, camera);
		if(mousePoint.x >= objPoint.x && mousePoint.y >= objPoint.y &&
			mousePoint.x < objPoint.x + this.width && mousePoint.y < objPoint.y + this.height)
		{
			return true;
		}
		return false;
	}

	override public function destroy():Void
	{
		super.destroy();

		dropPanel = FlxDestroyUtil.destroy(dropPanel);

		list = FlxDestroyUtil.destroyArray(list);
		// _ui_control_callback = null;
		callback = null;
	}

	private function showList(b:Bool):Void
	{
		if (b)
		{
			var maxScroll = Std.int(Math.max(0, dataList.length - visibleCount));
			currentScroll = Std.int(Math.min(currentScroll, maxScroll));
		}
		else currentScroll = 0;

		dropPanel.visible = b;

		refreshVisibleButtons();
		FlxUI.forceFocus(b, this); // avoid overlaps
	}

	private function onDropdown():Void
	{
		(dropPanel.visible) ? showList(false) : showList(true);
	}

	private function onClickItem(i:Int):Void
	{
		var dataIndex = currentScroll + i;

		if (dataIndex < 0 || dataIndex >= dataList.length) return;

		var data = dataList[dataIndex];
		selectSomething(data.name, data.label);
		showList(false);

		if (callback != null)
			callback(data.name);

		if (broadcastToFlxUI)
			FlxUI.event(CLICK_EVENT, this, data.name, params);
	}

	/**
	 * Helper function to easily create a data list for a dropdown menu from an array of strings.
	 *
	 * @param	StringArray		The strings to use as data - used for both label and string ID.
	 * @param	UseIndexID		Whether to use the integer index of the current string as ID.
	 * @return	The StrIDLabel array ready to be used in FlxUIDropDownMenuCustom's constructor
	 */
	public static function makeStrIdLabelArray(StringArray:Array<String>, UseIndexID:Bool = false):Array<StrNameLabel>
	{
		var strIdArray:Array<StrNameLabel> = [];
		for (i in 0...StringArray.length)
		{
			var ID:String = StringArray[i];
			if (UseIndexID)
			{
				ID = Std.string(i);
			}
			strIdArray[i] = new StrNameLabel(ID, StringArray[i]);
		}
		return strIdArray;
	}
}

/**
 * Header for a FlxUIDropDownMenuCustom
 */
class FlxUIDropDownHeader extends FlxUIGroup
{
	/**
	 * The background of the header.
	 */
	public var background:FlxSprite;

	/**
	 * The text that displays the currently selected item.
	 */
	public var text:FlxUIText;

	/**
	 * The button that toggles the visibility of the dropdown panel.
	 */
	public var button:FlxUISpriteButton;

	/**
	 * Creates a new dropdown header to be used in a FlxUIDropDownMenuCustom.
	 *
	 * @param	Width	Width of the dropdown - only relevant when no back sprite was specified
	 * @param	Back	Optional sprite to be placed in the background
	 * @param 	Text	Optional text that displays the current value
	 * @param	Button	Optional button that toggles the dropdown list
	 */
	public function new(Width:Int = 120, ?Background:FlxSprite, ?Text:FlxUIText, ?Button:FlxUISpriteButton)
	{
		super();

		background = Background;
		text = Text;
		button = Button;

		// Background
		if (background == null)
		{
			background = new FlxUI9SliceSprite(0, 0, FlxUIAssets.IMG_BOX, new Rectangle(0, 0, Width, 20), [1, 1, 14, 14]);
		}

		// Button
		if (button == null)
		{
			button = new FlxUISpriteButton(0, 0, new FlxSprite(0, 0, FlxUIAssets.IMG_DROPDOWN));
			button.loadGraphicSlice9([FlxUIAssets.IMG_BUTTON_THIN], 80, 20, [FlxStringUtil.toIntArray(FlxUIAssets.SLICE9_BUTTON)],
				FlxUI9SliceSprite.TILE_NONE, -1, false, FlxUIAssets.IMG_BUTTON_SIZE, FlxUIAssets.IMG_BUTTON_SIZE);
		}
		button.resize(background.height, background.height);
		button.x = background.x + background.width - button.width;

		// Reposition and resize the button hitbox so the whole header is clickable
		button.width = Width;
		button.offset.x -= (Width - button.frameWidth);
		button.x = offset.x;
		button.label.offset.x += button.offset.x;

		// Text
		if (text == null)
		{
			text = new FlxUIText(0, 0, Std.int(background.width));
		}
		text.setPosition(2, 4);
		text.color = FlxColor.BLACK;

		add(background);
		add(button);
		add(text);
	}

	override public function destroy():Void
	{
		super.destroy();

		background = FlxDestroyUtil.destroy(background);
		text = FlxDestroyUtil.destroy(text);
		button = FlxDestroyUtil.destroy(button);
	}
}

enum FlxUIDropDownMenuDropDirection
{
	Automatic;
	Down;
	Up;
}
