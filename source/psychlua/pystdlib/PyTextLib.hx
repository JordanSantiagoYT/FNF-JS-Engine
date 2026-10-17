package psychlua.pystdlib;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import psychlua.PythonScript;
import play.PlayState;
import backend.Paths;
import headers.PsychLua;

// REFACTOR: extracted from psychlua.PythonScript (text object API)
class PyTextLib
{
	public static function register(py:PythonScript):Void {
		@:privateAccess {
		// Lua texts
		PythonScript.registerFunction("makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float) {
			tag = tag.replace('.', '');
			py.resetTextTag(tag);
			var leText:FlxText = new FlxText(x, y, width, text, 16);
			leText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			leText.cameras = [PlayState.instance.camHUD];
			leText.scrollFactor.set();
			leText.borderSize = 2;
			PlayState.instance.modchartTexts.set(tag, leText);
		});
		PythonScript.registerFunction("setTextString", function(tag:String, text:String) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				obj.text = text;
				return true;
			}
			py.pyTrace("setTextString | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		PythonScript.registerFunction("setTextSize", function(tag:String, size:Int) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				obj.size = size;
				return true;
			}
			py.pyTrace("setTextSize | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		PythonScript.registerFunction("setTextWidth", function(tag:String, width:Float) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				obj.fieldWidth = width;
				return true;
			}
			py.pyTrace("setTextWidth | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		PythonScript.registerFunction("setTextColor", function(tag:String, color:String) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
				obj.color = colorNum;
				return true;
			}
			py.pyTrace("setTextColor | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		PythonScript.registerFunction("setTextFont", function(tag:String, newFont:String) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				obj.font = Paths.font(newFont);
				return true;
			}
			py.pyTrace("setTextFont | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		PythonScript.registerFunction("setTextItalic", function(tag:String, italic:Bool) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				obj.italic = italic;
				return true;
			}
			py.pyTrace("setTextItalic | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		PythonScript.registerFunction("setTextAlignment", function(tag:String, alignment:String = 'left') {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				switch(alignment.toLowerCase().trim()) {
					case 'right': obj.alignment = RIGHT;
					case 'center': obj.alignment = CENTER;
					default: obj.alignment = LEFT;
				}
				return true;
			}
			py.pyTrace("setTextAlignment | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		PythonScript.registerFunction("getTextString", function(tag:String) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null && obj.text != null) {
				return obj.text;
			}
			py.pyTrace("getTextString | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});
		PythonScript.registerFunction("getTextSize", function(tag:String) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				return obj.size;
			}
			py.pyTrace("getTextSize | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return -1;
		});
		PythonScript.registerFunction("getTextFont", function(tag:String) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				return obj.font;
			}
			py.pyTrace("getTextFont | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});
		PythonScript.registerFunction("getTextWidth", function(tag:String) {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				return obj.fieldWidth;
			}
			py.pyTrace("getTextWidth | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return 0;
		});
		PythonScript.registerFunction("setTextBorder", function(tag:String, size:Int, color:String, ?quality:String = 'quality') {
			var obj:FlxText = py.getTextObject(tag);
			if(obj != null) {
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
				obj.borderStyle = OUTLINE;
				obj.borderSize = size;
				obj.borderColor = colorNum;
				return true;
			}
			py.pyTrace("setTextBorder | Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		PythonScript.registerFunction("addLuaText", function(tag:String) {
			if(PlayState.instance.modchartTexts.exists(tag)) {
				var textObject:FlxText = PlayState.instance.modchartTexts.get(tag);
				if(textObject != null) py.getInstance().add(textObject);
			}
		});
		PythonScript.registerFunction("removeLuaText", function(tag:String, destroy:Bool = true) {
			if(!PlayState.instance.modchartTexts.exists(tag)) {
				return;
			}

			var textObject:FlxText = PlayState.instance.modchartTexts.get(tag);
			if(textObject != null)
				py.getInstance().remove(textObject, true);

			if(destroy) {
				if(textObject != null) textObject.destroy();
				PlayState.instance.modchartTexts.remove(tag);
			}
		});
		}
	}
}
