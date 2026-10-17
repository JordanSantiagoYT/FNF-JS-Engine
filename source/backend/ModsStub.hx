package backend;

// No-op stub for non-MODS_ALLOWED targets (#52). This class has its own
// type path (backend.ModsStub); import.hx aliases it as `Mods` when
// MODS_ALLOWED is off, so exactly one `Mods` implementation is ever bound
// and the two classes can no longer collide on the backend.Mods type path.
class ModsStub
{
	static public var currentModDirectory:String = '';
	public static var ignoreModFolders:Array<String> = [];
	public static var invalidMods:Array<String> = [];
	public static function markInvalidMod(?folder:String = null):Void {}
	inline public static function getGlobalMods():Array<String>
		return [];
	inline public static function pushGlobalMods():Array<String>
		return [];
	inline public static function getModDirectories():Array<String>
		return [];
	inline public static function mergeAllTextsNamed(path:String, defaultDirectory:String = null, allowDuplicates:Bool = false):Array<String>
		return [];
	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true):Array<String>
		return [];
	inline public static function getPack(?folder:String = null):Dynamic
		return null;
	public static var updatedOnState:Bool = false;
	inline public static function parseList():ModsList
		return {enabled: [], disabled: [], all: []};
	inline public static function loadTopMod():Void {}
}

