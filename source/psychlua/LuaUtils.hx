package psychlua;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import play.PlayState;
import states.substates.GameOverSubstate;

import openfl.display.BlendMode;

#if LUA_ALLOWED
import psychlua.FunkinLua.State;
#end

using StringTools;

@:allow(psychlua.FunkinLua)
class LuaUtils {
	// REFACTOR: root classes moved into packages; resolve legacy bare class names from scripts
	public static function resolveClassCompat(className:String):Class<Dynamic>
	{
		if (className == null || className.length < 1) return null;
		var cls:Class<Dynamic> = Type.resolveClass(className);
		if (cls != null) return cls;
		var prefixes:Array<String> = ['backend', 'states', 'states.substates', 'objects', 'play', 'play.helpers',
			'data', 'shaders', 'editors', 'editors.charting', 'stages', 'stages.objects', 'options', 'psychlua',
			'psychlua.callbacks', 'psychlua.pystdlib'];
		for (p in prefixes)
		{
			cls = Type.resolveClass(p + '.' + className);
			if (cls != null) return cls;
		}
		return null;
	}

	public static function getLuaTween(options:Dynamic)
	{
		return (options != null) ? {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getFlxEaseByString(options.ease)
		} : null;
	}

	//buncho string stuffs
	public static function getTweenTypeByString(?type:String = '') {
		switch(type.toLowerCase().trim())
		{
			case 'backward': return FlxTweenType.BACKWARD;
			case 'looping'|'loop': return FlxTweenType.LOOPING;
			case 'persist': return FlxTweenType.PERSIST;
			case 'pingpong': return FlxTweenType.PINGPONG;
		}
		return FlxTweenType.ONESHOT;
	}

    //Better optimized than using some getProperty shit or idk
	public static inline function getFlxEaseByString(?ease:String = '') {
		return switch(ease.toLowerCase().trim()) {
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepInOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
			case _: return FlxEase.linear;
		}
	}

	public static inline function blendModeFromString(blend:String):BlendMode {
		return switch(blend.toLowerCase().trim()) {
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
			case _: return NORMAL;
		}
	}

	public static inline function cameraFromString(cam:String):FlxCamera {
		return switch(cam.toLowerCase()) {
			case 'camhud' | 'hud': return PlayState.instance.camHUD;
			case 'camother' | 'other': return PlayState.instance.camOther;
			case _: PlayState.instance.camGame;
		}
	}
	
	// alias for above, helper function basically
	public static function getCam(obj:String):Dynamic {
        if (obj.toLowerCase().trim() == "global")
		    return FlxG.game;
	    return cameraFromString(obj);
    }

	public static function luaTrace(lua: #if LUA_ALLOWED State #else Dynamic #end, text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		#if LUA_ALLOWED
		if(ignoreCheck || getBool(lua, 'luaDebugMode')) {
			if(deprecated && !getBool(lua, 'luaDeprecatedWarnings')) {
				return;
			}
			PlayState.instance.addTextToDebug(text, color);
			trace(text);
		}
		#end
	}

	public static function getErrorMessage(lua: #if LUA_ALLOWED State #else Dynamic #end, status:Int):String {
		#if LUA_ALLOWED
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null) v = v.trim();
		if (v == null || v == "")
		{
			switch (status)
			{
				case type if (type == Lua.ERRRUN):
					return "Runtime Error";
				case type if (type == Lua.ERRMEM):
					return "Memory Allocation Error";
				case type if (type == Lua.ERRERR):
					return "Critical Error";
			}
			return "Unknown Error";
		}

		return v;
		#else
		return null;
		#end
	}
	
	public static function isOfTypes(value:Any, types:Array<Dynamic>)
	{
		for (type in types)
		{
			if(Std.isOfType(value, type)) return true;
		}
		return false;
	}

	public static function getBool(lua: #if LUA_ALLOWED State #else Dynamic #end, variable:String) {
		#if LUA_ALLOWED
		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) {
			return false;
		}
		return (result == 'true');
		#else
		return false;
		#end
	}

	// REFACTOR: moved from FunkinLua; pure/stateless helpers
	public static function typeToString(type:Int):String
	{
		#if LUA_ALLOWED
		switch (type)
		{
			case type if (type == Lua.TBOOLEAN):
				return "boolean";
			case type if (type == Lua.TNUMBER):
				return "number";
			case type if (type == Lua.TSTRING):
				return "string";
			case type if (type == Lua.TTABLE):
				return "table";
			case type if (type == Lua.TFUNCTION):
				return "function";
			case type if (type <= Lua.TNIL):
				return "nil";
		}
		#end
		return "unknown";
	}

	public static inline function getInstance()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
	{
		if(variable.indexOf('[') == -1)
		{
			if(PlayState.instance.variables.exists(variable))
			{
				PlayState.instance.variables.set(variable, value);
				return true;
			}

			if(instance == null || Std.isOfType(instance, String) || Std.isOfType(instance, Int) || Std.isOfType(instance, Float) || Std.isOfType(instance, Bool))
				return false;

			Reflect.setProperty(instance, variable, value);
			return true;
		}

		var pathParts:Array<String> = variable.split('[');
		if(pathParts.length > 1)
		{
			var blah:Dynamic = null;
			if(PlayState.instance.variables.exists(pathParts[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(pathParts[0]);
				if(retVal != null)
					blah = retVal;
			}
			else if(instance != null && !Std.isOfType(instance, String) && !Std.isOfType(instance, Int) && !Std.isOfType(instance, Float) && !Std.isOfType(instance, Bool))
				blah = Reflect.getProperty(instance, pathParts[0]);

			if(blah == null) return null;

			for (i in 1...pathParts.length)
			{
				var leNum:Dynamic = pathParts[i].substr(0, pathParts[i].length - 1);
				if(i >= pathParts.length-1) //Last array
					blah[leNum] = value;
				else //Anything else
					blah = blah[leNum];
			}
			return blah;
		}
		/*if(Std.isOfType(instance, Map))
			instance.set(variable,value);
		else*/

		if(PlayState.instance.variables.exists(variable))
		{
			PlayState.instance.variables.set(variable, value);
			return true;
		}

		if(instance == null || Std.isOfType(instance, String) || Std.isOfType(instance, Int) || Std.isOfType(instance, Float) || Std.isOfType(instance, Bool))
			return false;

		Reflect.setProperty(instance, variable, value);
		return true;
	}
	public static function getVarInArray(instance:Dynamic, variable:String):Any
	{
		if(variable.indexOf('[') == -1)
		{
			if(PlayState.instance.variables.exists(variable))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(variable);
				if(retVal != null)
					return retVal;
			}

			if(instance == null || Std.isOfType(instance, String) || Std.isOfType(instance, Int) || Std.isOfType(instance, Float) || Std.isOfType(instance, Bool))
				return null;

			return Reflect.getProperty(instance, variable);
		}

		var pathParts:Array<String> = variable.split('[');
		if(pathParts.length > 1)
		{
			var blah:Dynamic = null;
			if(PlayState.instance.variables.exists(pathParts[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(pathParts[0]);
				if(retVal != null)
					blah = retVal;
			}
			else if(instance != null && !Std.isOfType(instance, String) && !Std.isOfType(instance, Int) && !Std.isOfType(instance, Float) && !Std.isOfType(instance, Bool))
				blah = Reflect.getProperty(instance, pathParts[0]);

			if(blah == null) return null;

			for (i in 1...pathParts.length)
			{
				var leNum:Dynamic = pathParts[i].substr(0, pathParts[i].length - 1);
				blah = blah[leNum];
			}
			return blah;
		}

		if(PlayState.instance.variables.exists(variable))
		{
			var retVal:Dynamic = PlayState.instance.variables.get(variable);
			if(retVal != null)
				return retVal;
		}

		if(instance == null || Std.isOfType(instance, String) || Std.isOfType(instance, Int) || Std.isOfType(instance, Float) || Std.isOfType(instance, Bool))
			return null;

		return Reflect.getProperty(instance, variable);
	}

	public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true):Dynamic
	{
		var coverMeInPiss:Dynamic = PlayState.instance.getLuaObject(objectName, checkForTextsToo);
		if(coverMeInPiss==null)
			coverMeInPiss = getVarInArray(getInstance(), objectName);

		return coverMeInPiss;
	}

	public static function getPropertyLoopThingWhatever(killMe:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool=true):Dynamic
	{
		var coverMeInPiss:Dynamic = getObjectDirectly(killMe[0], checkForTextsToo);
		var end = killMe.length;
		if(getProperty)end=killMe.length-1;

		for (i in 1...end) {
			coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
		}
		return coverMeInPiss;
	}

	public static function addAnimByIndices(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false)
	{
		var strIndices:Array<String> = indices.trim().split(',');
		var die:Array<Int> = [];
		for (i in 0...strIndices.length) {
			die.push(Std.parseInt(strIndices[i]));
		}

		if(PlayState.instance.getLuaObject(obj, false)!=null) {
			var pussy:FlxSprite = PlayState.instance.getLuaObject(obj, false);
			pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
			if(pussy.animation.curAnim == null) {
				pussy.animation.play(name, true);
			}
			return true;
		}

		var pussy:FlxSprite = Reflect.getProperty(getInstance(), obj);
		if(pussy != null) {
			pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
			if(pussy.animation.curAnim == null) {
				pussy.animation.play(name, true);
			}
			return true;
		}
		return false;
	}
}