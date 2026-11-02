package mobile.options;

import mobile.MobileControls;
import mobile.objects.Hitbox;
import options.BaseOptionsMenu;
import options.Option;

/**
 * "Mobile Options": everything about the touch controls.
 * The hitbox preview at the back redraws live while you change the options.
 */
class MobileOptionsSubState extends BaseOptionsMenu
{
	var preview:Hitbox;

	public function new()
	{
		title = 'Mobile Options';
		rpcTitle = 'Mobile Options Menu';

		var option:Option = new Option('Pad Opacity', 'How visible the menu buttons (D-pad, A, B) are.', 'mobilePadAlpha', 'percent', 0.6);
		option.scrollSpeed = 1;
		option.minValue = 0.1;
		option.maxValue = 1;
		option.changeValue = 0.05;
		option.decimals = 2;
		option.onChange = refresh;
		addOption(option);

		option = new Option('Hitbox Opacity', 'How visible the four lanes are while playing.\nAt 0% they are invisible but still work.', 'hitboxAlpha', 'percent', 0.35);
		option.scrollSpeed = 1;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.05;
		option.decimals = 2;
		option.onChange = refresh;
		addOption(option);

		option = new Option('Hitbox Style:', 'Gradient fades the lanes from the bottom,\nFlat is a solid color, Outline only draws the borders.', 'hitboxStyle',
			'string', 'Gradient', ['Gradient', 'Flat', 'Outline']);
		option.onChange = refresh;
		addOption(option);

		option = new Option('Hitbox Position:', 'Full uses the whole screen height,\nBottom only the lower part (fewer accidental taps).', 'hitboxPosition',
			'string', 'Full', ['Full', 'Bottom']);
		option.onChange = refresh;
		addOption(option);

		option = new Option('Extra Button', 'Shows a Bot Energy button in the top-left corner during songs.', 'mobileExtraButtons', 'bool', false);
		option.onChange = refresh;
		addOption(option);

		option = new Option('Vibration', 'Short vibration every time you press a button.', 'mobileVibration', 'bool', false);
		option.onChange = refresh;
		addOption(option);

		option = new Option('Screen:', 'Ratio keeps the game 16:9 (black bars on wide phones),\nFill stretches it over the whole display.', 'mobileScaleMode', 'string',
			'Ratio', ['Ratio', 'Fill']);
		option.onChange = function()
		{
			MobileControls.applyScaleMode();
			refresh();
		};
		addOption(option);

		super();
		rebuildPreview();
	}

	function refresh():Void
	{
		if (MobileControls.instance != null)
			MobileControls.instance.refresh();
		rebuildPreview();
	}

	function rebuildPreview():Void
	{
		final controls = MobileControls.instance;
		if (controls == null)
			return;

		if (preview != null)
		{
			remove(preview, true);
			preview.destroy();
		}

		preview = new Hitbox(ClientPrefs.hitboxAlpha, switch (ClientPrefs.hitboxStyle)
		{
			case 'Flat': 1;
			case 'Outline': 2;
			default: 0;
		}, ClientPrefs.hitboxPosition == 'Bottom', ClientPrefs.mobileExtraButtons);

		// look only: touches must keep scrolling the menu, not "hit" lanes
		for (button in preview.members)
			if (button != null)
				button.touchEnabled = false;
		preview.assignCamera(controls.camera);
		// behind the menu text but above the background
		insert(1, preview);
	}

	override function destroy():Void
	{
		preview = null;
		super.destroy();
	}
}
