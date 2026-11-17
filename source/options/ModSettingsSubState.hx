package options;

import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import options.Option;

class ModSettingsSubState extends BaseOptionsMenu
{
	var save:Map<String, Dynamic> = new Map<String, Dynamic>();
	var folder:String;
	private var _crashed:Bool = false;

	public function new(options:Array<Dynamic>, folder:String, name:String)
	{
		this.folder = folder;
		title = name;
		rpcTitle = 'Mod Settings ($name)';

		if (FlxG.save.data.modSettings == null)
			FlxG.save.data.modSettings = new Map<String, Dynamic>();
		else
		{
			final saveMap:Map<String, Dynamic> = FlxG.save.data.modSettings;
			save = saveMap.exists(folder) && saveMap.get(folder) != null ? saveMap.get(folder) : new Map<String, Dynamic>();
		}

		try
		{
			for (option in options)
			{
				if (option == null || option.save == null) continue;

				final optType:String = convertType(option.type);
				var opts:Array<String> = option.options;
				if (optType == 'string' && opts == null) opts = [];

				var newOption = new Option(
					option.name != null ? option.name : option.save,
					option.description != null ? option.description : 'No description provided.',
					option.save,
					optType,
					option.value,
					opts
				);

				// just currently an stub
				/*
				if (optType == 'keybind' || optType == 'key')
				{
					final kb = option.keyboard != null ? option.keyboard : 'NONE';
					newOption.defaultValue = kb;
					newOption.setValue(kb);
					save.set(option.save, {
						keyboard: kb,
						gamepad: option.gamepad != null ? option.gamepad : 'NONE'
					});
				}
				else
				{
				*/
					@:privateAccess
					{
						newOption.getValue = function() {
							final data = save.get(newOption.variable);
							if (data == null) return newOption.defaultValue;
							return data;
						};

						newOption.setValue = function(value:Dynamic) {
							save.set(newOption.variable, value);
						};
					}
				//}

				// Optional extras
				if (option.format != null) newOption.displayFormat = option.format;
				if (option.min != null) newOption.minValue = option.min;
				if (option.max != null) newOption.maxValue = option.max;
				if (option.step != null) newOption.changeValue = option.step;
				if (option.scroll != null) newOption.scrollSpeed = option.scroll;
				if (option.decimals != null) newOption.decimals = option.decimals;

				// Load saved value or apply default
				var myValue:Dynamic = save.get(option.save);
				if (myValue == null)
					myValue = option.value != null ? option.value : newOption.defaultValue;

				newOption.setValue(myValue);
				save.set(option.save, myValue);

				if (optType == 'string' && option.options != null)
				{
					final num:Int = option.options.indexOf(myValue);
					if (num > -1) newOption.curOption = num;
				}

				addOption(newOption);
			}
		}
		catch (e:Dynamic)
		{
			trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
			CoolUtil.showPopUp('An error occurred: $e', 'Mod name: ' + folder);
			_crashed = true;
			close();
			return;
		}

		super();
	}

	private function convertType(str:String):String
	{
		if (str == null) return 'bool';
		switch (str.toLowerCase().trim())
		{
			case 'bool': return 'bool';
			case 'int', 'integer': return 'int';
			case 'float', 'fl': return 'float';
			case 'percent': return 'percent';
			case 'string', 'str': return 'string';
			case 'keybind', 'key':
				FlxG.log.warn('KEYBIND type is not fully supported – falling back to string');
				return 'string';
			default:
				FlxG.log.error('Unknown option type: ' + str);
				return 'bool';
		}
	}

	override public function update(elapsed:Float)
	{
		if (_crashed)
		{
			close();
			return;
		}
		super.update(elapsed);
	}

	override public function close()
	{
		if (FlxG.save.data.modSettings == null)
			FlxG.save.data.modSettings = new Map<String, Dynamic>();
		FlxG.save.data.modSettings.set(folder, save);
		FlxG.save.flush();
		super.close();
	}
}