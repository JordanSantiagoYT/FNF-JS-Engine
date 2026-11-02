package mobile.backend;

import haxe.io.Path;
#if sys
import sys.FileSystem;
#end

/**
 * Where the game keeps its files on a phone.
 *
 * The APK is read-only and `assets/` inside it cannot be opened with `sys.FileSystem`, which the engine
 * (and every mod) uses everywhere. So the game works from a normal folder instead:
 *
 *   Android/data/<package>/files/        <- the working directory
 *     assets/   copied out of the APK on first launch (see AssetExtractor)
 *     mods/     put your mods here
 *
 * This folder belongs to the app, so no storage permission is needed (works on Android 5 to 15),
 * and it is easy to reach with any file manager or by plugging the phone into a computer.
 */
class StorageUtil
{
	public static var directory(default, null):String = '';

	/** Call first thing at startup, before anything touches the file system. */
	public static function init():Void
	{
		#if android
		directory = resolve();
		for (folder in [directory, directory + 'mods', directory + 'crash'])
			if (!FileSystem.exists(folder))
				try FileSystem.createDirectory(folder) catch (e) {}
		try Sys.setCwd(directory) catch (e) {}
		#end
	}

	#if android
	static function resolve():String
	{
		var dir:String = null;
		try
		{
			dir = android.content.Context.getExternalFilesDir(null);
		}
		catch (e) {}

		// no external storage (very rare): use the private internal folder
		if (dir == null || dir == '')
		{
			try
			{
				dir = android.content.Context.getFilesDir();
			}
			catch (e) {}
		}
		if (dir == null || dir == '')
			dir = lime.system.System.applicationStorageDirectory;

		return Path.addTrailingSlash(dir);
	}
	#end
}
