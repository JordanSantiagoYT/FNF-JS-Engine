package play.helpers;

import objects.Character;
import objects.Character.Boyfriend;

import play.PlayState;

// REFACTOR: character list/pos/lua logic extracted from play.PlayState
class PlayStateCharacters
{
	public static function addCharacterToList(state:PlayState, newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!state.boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Boyfriend = new Boyfriend(0, 0, newCharacter);
					state.boyfriendMap.set(newCharacter, newBoyfriend);
					state.boyfriendGroup.add(newBoyfriend);
					startCharacterPos(state, newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterLua(state, newBoyfriend.curCharacter);
				}

			case 1:
				if(!state.dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					state.dadMap.set(newCharacter, newDad);
					state.dadGroup.add(newDad);
					startCharacterPos(state, newDad, true);
					newDad.alpha = 0.00001;
					startCharacterLua(state, newDad.curCharacter);
				}

			case 2:
				if(state.gf != null && !state.gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					state.gfMap.set(newCharacter, newGf);
					state.gfGroup.add(newGf);
					startCharacterPos(state, newGf);
					newGf.alpha = 0.00001;
					startCharacterLua(state, newGf.curCharacter);
				}
		}
	}

	public static function startCharacterLua(state:PlayState, name:String)
	{
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		if(FileSystem.exists(Paths.modFolders(luaFile))) {
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		} else {
			luaFile = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaFile)) {
				doPush = true;
			}
		}
		#else
		luaFile = Paths.getPreloadPath(luaFile);
		if(Assets.exists(luaFile)) {
			doPush = true;
		}
		#end

		if(doPush)
		{
			var alreadyLoaded:Bool = false;
			for (script in state.luaArray)
			{
				if(script.scriptName == luaFile) {
					alreadyLoaded = true;
					break;
				}
			}
			if(!alreadyLoaded) new FunkinLua(luaFile);
		}
		#end

		#if PYTHON_ALLOWED
		var doPushPy:Bool = false;
		var pyFile:String = 'characters/$name.py';
		#if MODS_ALLOWED
		if(FileSystem.exists(Paths.modFolders(pyFile))) {
			pyFile = Paths.modFolders(pyFile);
			doPushPy = true;
		} else {
			pyFile = Paths.getPreloadPath(pyFile);
			if(FileSystem.exists(pyFile)) {
				doPushPy = true;
			}
		}
		#else
		pyFile = Paths.getPreloadPath(pyFile);
		if(Assets.exists(pyFile)) {
			doPushPy = true;
		}
		#end

		if(doPushPy)
		{
			var alreadyLoadedPy:Bool = false;
			for (script in state.pythonArray)
			{
				if(script.scriptName == pyFile) {
					alreadyLoadedPy = true;
					break;
				}
			}
			if(!alreadyLoadedPy) new PythonScript(pyFile);
		}
		#end
	}

	public static function startCharacterPos(state:PlayState, char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(state.GF_X, state.GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}
}
