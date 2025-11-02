package psychlua;

import haxe.ds.*;
import psychlua.FunkinLua.State;
import hxluajit.Types;


/**
 * Some borrowed code from hxluajit-wrapper.
 * @see https://github.com/MAJigsaw77/hxluajit-wrapper/blob/main/hxluajit/wrapper/LuaConverter.hx
 * 
 * We didn't use hxluajit-wrapper because we wanted to have our functions and methods as similar as possible to linc_luajit
 */
class Convert
{
	public static function addCallback(l:State, name:String, func:Dynamic)
	{
		// PsychLua expects the function to be null for local callbacks, too lazy to do something about that
		if (Type.typeof(func) != TFunction || func == null)
			return;

		callbacks.set(name, func);

        Lua.pushstring(l, name);
        Lua.pushcclosure(l, cpp.Callable.fromStaticFunction(handleCallback), 1);
        Lua.setglobal(l, name);
	}

	public static function removeCallback(l:State, name:String)
	{
		if (!callbacks.exists(name))
			return;

		callbacks.remove(name);

        Lua.pushnil(l);
        Lua.setglobal(l, name);
	}

	public static function toLua(l:State, v:Dynamic):Bool
	{
		switch (Type.typeof(v))
		{
			case TInt:
				Lua.pushinteger(l, cast(v, Int));
			case TFloat:
				Lua.pushnumber(l, cast(v, Float));
			case TBool:
				Lua.pushboolean(l, v == true ? 1 : 0);
			case TObject:
				final fields:Array<String> = Reflect.fields(v);

				Lua.createtable(l, fields.length, 0);

				for (field in fields)
				{
					Lua.pushstring(l, field);
					toLua(l, Reflect.field(v, field));
					Lua.settable(l, -3);
				}
			case TClass(String):
				Lua.pushstring(l, cast(v, String));
			case TClass(Array):
				final elements:Array<Dynamic> = v;

				Lua.createtable(l, elements.length, 0);

				for (i in 0...elements.length)
				{
					Lua.pushinteger(l, i + 1);
					toLua(l, elements[i]);
					Lua.settable(l, -3);
				}
			case TClass(IntMap) | TClass(StringMap) | TClass(ObjectMap):
				final values:Map<String, Dynamic> = v;

				Lua.createtable(l, Lambda.count(values), 0);

				for (key => value in values)
				{
					Lua.pushstring(l, key);
					toLua(l, value);
					Lua.settable(l, -3);
				}
			case TNull:
				Lua.pushnil(l);
			default:
				Lua.pushnil(l);
				return false;
		}
		return true;
	}

	public static function fromLua(l:State, idx:Int):Dynamic
	{
		var ret:Dynamic = null;

		switch (Lua.type(l, idx))
		{
			case type if (type == Lua.TNUMBER):
				ret = Lua.tonumber(l, idx);
			case type if (type == Lua.TSTRING):
				ret = Lua.tostring(l, idx).toString();
			case type if (type == Lua.TBOOLEAN):
				ret = Lua.toboolean(l, idx) == 1;
			case type if (type == Lua.TTABLE):
				ret = convertTable(l, idx);
			case type if (type == Lua.TFUNCTION):
				ret = new LuaFunction(cpp.Pointer.fromRaw(l), LuaL.ref(l, Lua.REGISTRYINDEX));
			case type if (type == Lua.TUSERDATA || type == Lua.TLIGHTUSERDATA):
				ret = cpp.Pointer.fromRaw(Lua.touserdata(l, idx));
			default:
				ret = null;
		}

		return ret;
	}

	public static function callFunctionWithoutName(l:State, args:Array<Dynamic>):Array<Dynamic>
	{
		for (arg in args)
			toLua(l, arg);

		final status:Int = Lua.pcall(l, args.length, Lua.MULTRET, 0);

		if (status != Lua.OK)
		{
    		var error = Lua.tostring(l, -1);
    		trace('Error calling a function without name: $error');
    		Lua.pop(l, 1);

			return [];
		}

		final args:Array<Dynamic> = [];

		{
			final count:Int = Lua.gettop(l);

			for (i in 0...count)
				args.push(fromLua(l, i + 1));

			Lua.pop(l, count);
		}

		return args;
	}

	@:noCompletion
	private static function convertTable(l:State, idx:Int):Dynamic
	{
		var isArray:Bool = true;

		var count:Int = 0;

		iterateTable(l, idx, function():Void
		{
			if (isArray)
			{
				if (Lua.type(l, -2) == Lua.TNUMBER)
				{
					final index:Lua_Integer = Lua.tointeger(l, -2);

					if (index < 0)
						isArray = false;
				}
				else
					isArray = false;
			}

			count++;
		});

		if (count == 0)
			return {};

		if (isArray)
		{
			final obj:Array<Dynamic> = [];

			iterateTable(l, idx, function():Void
			{
				obj[Lua.tointeger(l, -2) - 1] = fromLua(l, -1);
			});

			return obj;
		}
		else
		{
			final obj:haxe.DynamicAccess<Dynamic> = {};

			iterateTable(l, idx, function():Void
			{
				obj.set(Std.string(fromLua(l, -2)), fromLua(l, -1));
			});

			return obj;
		}
	}

	@:noCompletion
	private static function iterateTable(l:State, idx:Int, fn:Void->Void):Void
	{
		Lua.pushnil(l);

		while (Lua.next(l, idx < 0 ? idx - 1 : idx) != 0)
		{
			fn();

			Lua.pop(l, 1);
		}
	}

	@:noCompletion
	private static var funcs = [];

	@:noCompletion
	private static function handleMethod(l:State):Int
	{
		var argsLength:Int = Lua.gettop(l);
		var method = funcs[cast Lua.tonumber(l, Lua.upvalueindex(1))];
		var args = [];

		for (i in 0...argsLength)
			args[i] = fromLua(l, i + 1);

		try
		{
			var result = Reflect.callMethod(null, method, args);
			if (result != null)
				return toLua(l, result) ? 1 : 0;
			else
				return 0;
		}
		catch (e)
		{
			LuaL.error(l, 'METHOD ERROR!\n${e.stack}');
			return 0;
		}
	}

	@:noCompletion
	private static var callbacks:Map<String, Dynamic> = new Map();

	@:noCompletion
	private static function handleCallback(l:State):Int
	{
		try
		{
			var callbackName:String = Lua.tostring(l, Lua.upvalueindex(1));
			var callbackMethod:Dynamic = callbacks.get(callbackName);

			if (callbackMethod == null)
			{
				// trace('checking last script');
				var last:FunkinLua = FunkinLua.lastCalledScript;
				if (last == null || last.lua != l)
				{
					// trace('looping thru scripts');
					for (script in PlayState.instance.luaArray)
					{
						if (script != FunkinLua.lastCalledScript && script != null && script.lua == l)
						{
							// trace('found script');
							callbackMethod = script.callbacks.get(callbackName);
							break;
						}
					}
				}
				else
				{
					callbackMethod = last.callbacks.get(callbackName);
				}
			}

			if (callbackMethod == null)
				return 0;

			var nparams:Int = Lua.gettop(l);
			var args:Array<Dynamic> = [];

			for (i in 0...nparams)
			{
				args[i] = fromLua(l, i + 1);
			}

			var ret:Dynamic = null;
			/* return the number of results */

			ret = Reflect.callMethod(null, callbackMethod, args);

			if (ret != null)
			{
				toLua(l, ret);
				return 1;
			}
		}
		catch (e:Dynamic)
		{
			LuaL.error(l, 'CALLBACK ERROR! ${if (e.message != null) e.message else e}');
			return 0;
		}

		return 0;
	}
}
