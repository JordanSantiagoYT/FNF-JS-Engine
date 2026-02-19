package;

import Song;

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	@:optional var isPixelStage:Null<Bool>;
	var stageUI:String;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	var hide_girlfriend:Bool;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;
}

class StageData {
	public static function dummy():StageFile
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			stageUI: "normal",

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1,
		};
	}

	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';
		if(SONG.stage != null)
			stage = SONG.stage;
		else if(Song.loadedSongName != null)
			stage = vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));
		else
			stage = 'stage';

		var stageFile:StageFile = getStageFile(stage);
		forceNextDirectory = (stageFile != null) ? stageFile.directory : ''; //preventing crashes
	}

	public static function vanillaSongStage(songName):String
	{
		// trace(songName);
		return switch (songName)
		{
			case 'spookeez' | 'south' | 'monster':
				'spooky';
			case 'pico' | 'blammed' | 'philly' | 'philly-nice':
				'philly';
			case 'milf' | 'satin-panties' | 'high':
				'limo';
			case 'cocoa' | 'eggnog':
				'mall';
			case 'winter-horrorland':
				'mallEvil';
			case 'senpai' | 'roses':
				'school';
			case 'thorns':
				'schoolEvil';
			case 'ugh' | 'guns' | 'stress':
				'tank';
			default:
				'stage';
		}
	}

	public static function getStageFile(stage:String):StageFile {
		var rawJson:String = null;
		var relativePath:String = 'stages/' + stage + '.json';

		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders(relativePath);
		if(FileSystem.exists(modPath)) {
			rawJson = File.getContent(modPath);
		}
		#end

		if(rawJson == null) {
			var path:String = Paths.getPath(relativePath, TEXT, null, true);

			#if MODS_ALLOWED
			if(FileSystem.exists(path))
				rawJson = File.getContent(path);
			#else
			if(Assets.exists(path))
				rawJson = Assets.getText(path);
			#end
		}

		if(rawJson == null)
			return dummy();

		return cast tjson.TJSON.parse(rawJson);
	}

}
