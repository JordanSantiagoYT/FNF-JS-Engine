package mobile.backend;

import haxe.io.Path;
import lime.utils.AssetLibrary;
import lime.utils.Assets as LimeAssets;
import sys.FileSystem;
import sys.io.File;

/**
 * Copies every file of the APK's asset bundle into the game folder, a few files per frame,
 * so the engine's `FileSystem` based code (Paths, Mods, Lua, charts...) finds them like on desktop.
 *
 * Runs on first launch and again whenever a new build is installed (`BuildStamp`). Files whose size
 * did not change are skipped, so an update only rewrites what is different. Mods are never deleted.
 */
@:access(lime.utils.Assets)
class AssetExtractor
{
	static inline var STAMP_FILE:String = '.assets_stamp';

	public var total(default, null):Int = 0;
	public var done(default, null):Int = 0;
	public var finished(default, null):Bool = false;
	public var error(default, null):Null<String> = null;
	public var currentFile(default, null):String = '';

	final queue:Array<{library:AssetLibrary, id:String}> = [];

	public function new()
	{
		for (name => library in LimeAssets.libraries)
			for (id in library.list(null))
				if (shouldExtract(id))
					queue.push({library: library, id: id});
		total = queue.length;
	}

	static function shouldExtract(id:String):Bool
		return id.startsWith('assets/') || id.startsWith('mods/') || id.startsWith('plugins/');

	/** true when this build has not been extracted yet */
	public static function needed():Bool
	{
		try
		{
			if (FileSystem.exists(STAMP_FILE) && File.getContent(STAMP_FILE) == BuildStamp.ID)
				return false;
		}
		catch (e) {}
		return true;
	}

	/** Extracts files until `budget` seconds have passed. Call every frame. */
	public function step(budget:Float = 0.025):Void
	{
		if (finished || error != null)
			return;

		final start = haxe.Timer.stamp();
		while (queue.length > 0 && haxe.Timer.stamp() - start < budget)
		{
			final item = queue.pop();
			currentFile = item.id;
			try
			{
				copy(item.library, item.id);
			}
			catch (e)
			{
				error = 'Could not write "${item.id}":\n${e.message}\n\nIs the phone storage full?';
				return;
			}
			done++;
		}

		if (queue.length == 0)
		{
			try
			{
				File.saveContent(STAMP_FILE, BuildStamp.ID);
			}
			catch (e)
			{
				error = 'Could not finish setup:\n${e.message}';
				return;
			}
			finished = true;
		}
	}

	static function copy(library:AssetLibrary, id:String):Void
	{
		final bytes = library.getBytes(id);
		if (bytes == null)
			return;

		// unchanged file: nothing to do
		if (FileSystem.exists(id) && FileSystem.stat(id).size == bytes.length)
			return;

		final folder = Path.directory(id);
		if (folder != '' && !FileSystem.exists(folder))
			FileSystem.createDirectory(folder);
		File.saveBytes(id, bytes);
	}
}
