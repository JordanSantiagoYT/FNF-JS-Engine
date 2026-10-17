package options.helpers;

// REFACTOR: option-row building extracted from options.BaseOptionsMenu
import options.BaseOptionsMenu;
import options.Option;
import backend.ScreenLayout;
import flixel.FlxG;

import objects.Alphabet;
import objects.AttachedText;
import objects.CheckboxThingie;

// REFACTOR: option-row building extracted from source/options/BaseOptionsMenu.hx
// (duplicated in new() and regenList() -> now delegated here)
@:access(options.BaseOptionsMenu)
class OptionsMenuHelpers
{
	public static function createOptionRow(state:BaseOptionsMenu, optionsArray:Array<Option>)
	{
		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(ScreenLayout.contentLeft(FlxG.width) + 290, 260, optionsArray[i].name, false);
			optionText.isMenuItem = true;
			/*optionText.forceX = 300;
			optionText.yMult = 90;*/
			optionText.targetY = i;
			state.grpOptions.add(optionText);

			if(optionsArray[i].type == 'bool') {
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				state.checkboxGroup.add(checkbox);
			} else if (optionsArray[i].type != 'link') {
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
				//optionText.xAdd -= 80;
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), optionText.width + 80);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				state.grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}
			//optionText.snapToPosition(); //Don't ignore me when i ask for not making a fucking pull request to uncomment this line ok

			if(optionsArray[i].showBoyfriend && state.boyfriend == null)
			{
				state.reloadBoyfriend();
			}
			state.updateTextFrom(optionsArray[i]);
		}
	}
}
