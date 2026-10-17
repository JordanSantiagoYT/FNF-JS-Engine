package play.helpers;

// REFACTOR: explicit imports for shader subtypes
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

import backend.ClientPrefs;
import backend.Paths;
#if MODS_ALLOWED
#end

import play.PlayState;

// REFACTOR: script/shader plumbing extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateScripts
{
	#if SHADERS_ALLOWED
	public static function createRuntimeShader(state:PlayState, shaderName:String):ErrorHandledRuntimeShader
	{
		if(!ClientPrefs.shaders) return new ErrorHandledRuntimeShader(shaderName);

		#if (MODS_ALLOWED && SHADERS_ALLOWED)
		if(!state.runtimeShaders.exists(shaderName) && !initLuaShader(state, shaderName))
		{
			FlxG.log.warn('Shader $shaderName is missing!');
			return new ErrorHandledRuntimeShader(shaderName);
		}

		var arr:Array<String> = state.runtimeShaders.get(shaderName);
		return new ErrorHandledRuntimeShader(shaderName, arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public static function initLuaShader(state:PlayState, name:String)
	{
		if(!ClientPrefs.shaders) return false;

		if(state.runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		#if MODS_ALLOWED
		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		#else
		var foldersToCheck:Array<String> = [];
		#end

		for (folder in foldersToCheck)
		{
			#if sys
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if (FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					state.runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
			#end
		}
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		return false;
	}
	#end

	public static function addTextToDebug(state:PlayState, text:String, color:FlxColor) {
		#if LUA_ALLOWED
		var newText:DebugLuaText = state.luaDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);
   		newText.setFormat(Paths.font("old_windows.ttf"));
		state.luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		state.luaDebugGroup.add(newText);

		#if sys
		Sys.println(text);
		#end
		#elseif PYTHON_ALLOWED
		var newText:DebugLuaText = state.pythonDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);
		newText.setFormat(Paths.font("old_windows.ttf"));
		state.pythonDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		state.pythonDebugGroup.add(newText);

		#if sys
		Sys.println(text);
		#end
		#end
	}

	public static function addShaderToCamera(state:PlayState, cam:String,effect:Dynamic){//STOLE FROM ANDROMEDA	// actually i got it from old psych engine
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				state.camHUD.addShader(effect.shader);
			case 'camother' | 'other':
				state.camOther.addShader(effect.shader);
			case 'camgame' | 'game':
				state.camGame.addShader(effect.shader);
			default:
				#if (LUA_ALLOWED || PYTHON_ALLOWED)
				if(state.modchartSprites.exists(cam)) {
					Reflect.setProperty(state.modchartSprites.get(cam),"shader",effect.shader);
				} else if(state.modchartTexts.exists(cam)) {
					Reflect.setProperty(state.modchartTexts.get(cam),"shader",effect.shader);
				} else
				#end
				{
					var OBJ = Reflect.getProperty(PlayState.instance,cam);
					Reflect.setProperty(OBJ,"shader", effect.shader);
				}
		}
 	}

	public static function removeShaderFromCamera(state:PlayState, cam:String,effect:Dynamic){
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				if(state.camHUD.removeShader(effect.shader))
				{
					trace("Removed shader successfully");
				}
				else
				{
					trace("Shader wasn't found");
				}
			case 'camother' | 'other':
				if(state.camOther.removeShader(effect.shader))
				{
					trace("Removed shader successfully");
				}
				else
				{
					trace("Shader wasn't found");
				}
			case 'camgame' | 'game':
				if(state.camGame.removeShader(effect.shader))
				{
					trace("Removed shader successfully");
				}
				else
				{
					trace("Shader wasn't found");
				}
			default:
				#if (LUA_ALLOWED || PYTHON_ALLOWED)
				if(state.modchartSprites.exists(cam)) {
					Reflect.setProperty(state.modchartSprites.get(cam),"shader",null);
				} else if(state.modchartTexts.exists(cam)) {
					Reflect.setProperty(state.modchartTexts.get(cam),"shader",null);
				} else
				#end
				{
					var OBJ = Reflect.getProperty(PlayState.instance,cam);
					Reflect.setProperty(OBJ,"shader", null);
				}
			}
	}

	public static function clearShaderFromCamera(state:PlayState, cam:String){
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				state.camHUD.filters = [];
			case 'camother' | 'other':
				state.camOther.filters = [];
			case 'camgame' | 'game':
				state.camGame.filters = [];
			default:
				state.camGame.filters = [];
		}
	}

	public static function getLuaObject(state:PlayState, tag:String, text:Bool=true):FlxSprite {
		#if (LUA_ALLOWED || PYTHON_ALLOWED)
		if(state.modchartSprites.exists(tag)) return state.modchartSprites.get(tag);
		if(text && state.modchartTexts.exists(tag)) return state.modchartTexts.get(tag);
		if(state.variables.exists(tag)) return state.variables.get(tag);
		#end
		return null;
	}

	#if LUA_ALLOWED
	public static function startLuasOnFolder(state:PlayState, luaFile:String)
	{
		for (script in state.luaArray)
		{
			if(script.scriptName == luaFile) return false;
		}

		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(luaToLoad))
		{
			new FunkinLua(luaToLoad);
			return true;
		}
		else
		{
			luaToLoad = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaToLoad))
			{
				new FunkinLua(luaToLoad);
				return true;
			}
		}
		#elseif sys
		var luaToLoad:String = Paths.getPreloadPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		{
			new FunkinLua(luaToLoad);
			return true;
		}
		#end
		return false;
	}
	#end

	#if PYTHON_ALLOWED
	public static function startPythonScriptOnFolder(state:PlayState, pyFile:String)
	{
		for (script in state.pythonArray)
		{
			if(script.scriptName == pyFile) return false;
		}

		#if MODS_ALLOWED
		var pyToLoad:String = Paths.modFolders(pyFile);
		if(FileSystem.exists(pyToLoad))
		{
			new PythonScript(pyToLoad);
			return true;
		}
		else
		{
			pyToLoad = Paths.getPreloadPath(pyFile);
			if(FileSystem.exists(pyToLoad))
			{
				new PythonScript(pyToLoad);
				return true;
			}
		}
		#elseif sys
		var pyToLoad:String = Paths.getPreloadPath(pyFile);
		if(OpenFlAssets.exists(pyToLoad))
		{
			new PythonScript(pyToLoad);
			return true;
		}
		#end
		return false;
	}
	#end
}
