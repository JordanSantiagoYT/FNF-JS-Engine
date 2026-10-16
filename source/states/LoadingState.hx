package states;

import backend.MusicBeatState;
import backend.Paths;
import data.StageData;
import flixel.util.typeLimit.NextState;
import haxe.io.Path;
import play.PlayState;

class LoadingState extends MusicBeatState {
	// TO DO: Make this easier

	#if NO_PRELOAD_ALL
	private var targetState:NextState;
	private var stopMusicOnLoad:Bool;
	private var directory:String = 'shared';

	/**
	 * On-demand loading state used only by `-DNO_PRELOAD_ALL` builds (#55).
	 * Without `PRELOAD_ALL` the asset libraries are not loaded up front, so
	 * `getNextState` defers to this state; it paints one loading frame and
	 * then hands off, letting OpenFL fetch the song/library assets on first
	 * use instead of at startup.
	 */
	public function new(target:NextState, stopMusic:Bool = false, directory:String = 'shared')
	{
		super();
		targetState = target;
		stopMusicOnLoad = stopMusic;
		this.directory = directory;
	}

	override public function create():Void
	{
		super.create();
		if (stopMusicOnLoad && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		FlxG.switchState(targetState);
	}
	#end

	public static function loadAndSwitchState(target:NextState, stopMusic = false) {
		FlxG.switchState(getNextState(target, stopMusic));
	}

	static function getNextState(target:NextState, stopMusic = false):NextState {
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if(weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);

		#if NO_PRELOAD_ALL
		var loaded:Bool = false;
		if (PlayState.SONG != null) {
			loaded = isSoundLoaded(Paths.inst(PlayState.SONG.song)) && (!PlayState.SONG.needsVoices || isSoundLoaded(Paths.voices(PlayState.SONG.song))) && isLibraryLoaded("shared") && isLibraryLoaded(directory);
		}

		if (!loaded)
			return new LoadingState(target, stopMusic, directory);
		#end
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		return target;
	}

	#if NO_PRELOAD_ALL
	static function isSoundLoaded(path:String):Bool {
		// OpenFL's cache has hasSound(); lime.utils.AssetCache (the unaliased
		// `Assets` import) does not -- it only offers exists(id, type) (#55).
		return OpenFlAssets.cache.hasSound(path);
	}

	static function isLibraryLoaded(library:String):Bool {
		return OpenFlAssets.getLibrary(library) != null;
	}
	#end
}
