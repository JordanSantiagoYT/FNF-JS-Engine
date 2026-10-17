/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile;

import backend.CoolUtil;
import backend.ViewportVisuals;
import backend.MusicBeatState;

#if mobile
import lime.utils.Assets as LimeAssets;
import openfl.utils.Assets as OpenFLAssets;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.utils.ByteArray;
import haxe.io.Path;
import flixel.ui.FlxBar;
import flixel.ui.FlxBar.FlxBarFillDirection;
import lime.system.ThreadPool;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
using StringTools;

/**
 * ...
 * @author: Karim Akra
 */
class CopyState extends MusicBeatState
{
	private static final textFilesExtensions:Array<String> = ['ini', 'txt', 'xml', 'hxs', 'hx', 'lua', 'json', 'frag', 'vert'];
	public static final IGNORE_FOLDER_FILE_NAME:String = "CopyState-Ignore.txt";
	private static var directoriesToIgnore:Array<String> = [];
	public static var locatedFiles:Array<String> = [];
	public static var maxLoopTimes:Int = 0;

	public var loadingImage:FlxSprite;
	private var background:FlxSprite;
	public var loadingBar:FlxBar;
	public var loadedText:FlxText;
	public var thread:ThreadPool;

	var failedFilesStack:Array<String> = [];
	var failedFiles:Array<String> = [];
	var shouldCopy:Bool = false;
	var canUpdate:Bool = true;
	var loopTimes:Int = 0;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.fill(background);
		if (loadingImage != null) loadingImage.screenCenter();
		if (loadingBar != null && loadingBar.width != FlxG.width)
		{
			final index:Int = members.indexOf(loadingBar);
			final progress:Float = loadingBar.percent;
			remove(loadingBar, true);
			loadingBar.destroy();
			loadingBar = new FlxBar(0, FlxG.height - 26, FlxBarFillDirection.LEFT_TO_RIGHT, FlxG.width, 26);
			loadingBar.setRange(0, maxLoopTimes);
			loadingBar.percent = progress;
			insert(index, loadingBar);
		}
		if (loadedText != null)
		{
			loadedText.fieldWidth = FlxG.width;
			loadedText.y = FlxG.height - 22;
		}
	}

	override function create()
	{
		locatedFiles = [];
		maxLoopTimes = 0;
		checkExistingFiles();
		if (maxLoopTimes <= 0)
		{
			FlxG.switchState(states.InitState.new);
			return;
		}

		CoolUtil.showPopUp("Seems like you have some missing files that are necessary to run the game\nPress OK to begin the copy process", "Notice!");

		shouldCopy = true;

		background = new FlxSprite(0, 0).makeGraphic(1, 1, 0xffcaff4d);
		ViewportVisuals.fill(background);
		add(background);

		loadingImage = new FlxSprite(0, 0, Paths.image('funkay', 'shared'));
		loadingImage.setGraphicSize(0, FlxG.height);
		loadingImage.updateHitbox();
		loadingImage.screenCenter();
		add(loadingImage);

		loadingBar = new FlxBar(0, FlxG.height - 26, FlxBarFillDirection.LEFT_TO_RIGHT, FlxG.width, 26);
		loadingBar.setRange(0, maxLoopTimes);
		add(loadingBar);

		loadedText = new FlxText(loadingBar.x, loadingBar.y + 4, FlxG.width, '', 16);
		loadedText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		add(loadedText);

		thread = new ThreadPool(0, 4);
		thread.doWork.add(function(poop)
		{
			for (file in locatedFiles)
			{
				loopTimes++;
				copyAsset(file);
			}
		});
		new FlxTimer().start(0.5, (tmr) ->
		{
			thread.queue({});
		});

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (shouldCopy)
		{
			if (loopTimes >= maxLoopTimes && canUpdate)
			{
				if (failedFiles.length > 0)
				{
					CoolUtil.showPopUp(failedFiles.join('\n'), 'Failed To Copy ${failedFiles.length} File.');
					if (!FileSystem.exists('logs'))
						FileSystem.createDirectory('logs');
					File.saveContent('logs/' + Date.now().toString().replace(' ', '-').replace(':', "'") + '-CopyState' + '.txt', failedFilesStack.join('\n'));
				}

				FlxG.sound.play(Paths.sound('confirmMenu')).onComplete = () ->
				{
					FlxG.switchState(states.InitState.new);
				};

				canUpdate = false;
			}

			if (loopTimes >= maxLoopTimes)
				loadedText.text = "Completed!";
			else
				loadedText.text = '$loopTimes/$maxLoopTimes';

			loadingBar.percent = Math.min((loopTimes / maxLoopTimes) * 100, 100);
		}
		super.update(elapsed);
	}

	public function copyAsset(file:String)
	{
		if (!FileSystem.exists(file))
		{
			var directory = Path.directory(file);
			if (!FileSystem.exists(directory))
				FileSystem.createDirectory(directory);
			try
			{
				if (OpenFLAssets.exists(getFile(file)))
				{
					if (textFilesExtensions.contains(Path.extension(file)))
						createContentFromInternal(file);
					else
					{
						var bytes:ByteArray = getFileBytes(getFile(file));
						if (bytes == null)
						{
							if (isFontFile(file))
							{
								// Embedded fonts can't always be read back as raw bytes,
								// but they still load fine from the packaged assets at
								// runtime, so a storage copy isn't required for them.
								failedFilesStack.push('Asset ${getFile(file)} is embedded, skipped storage copy (loads from packaged assets).');
							}
							else
							{
								failedFiles.push(getFile(file) + ' (Could not read asset bytes)');
								failedFilesStack.push('Asset ${getFile(file)} returned null bytes.');
							}
						}
						else
							File.saveBytes(file, bytes);
					}
				}
				else
				{
					failedFiles.push(getFile(file) + " (File Dosen't Exist)");
					failedFilesStack.push('Asset ${getFile(file)} does not exist.');
				}
			}
			catch (e:haxe.Exception)
			{
				failedFiles.push('${getFile(file)} (${e.message})');
				failedFilesStack.push('${getFile(file)} (${e.stack})');
			}
		}
	}

	public function createContentFromInternal(file:String)
	{
		var fileName = Path.withoutDirectory(file);
		var directory = Path.directory(file);
		try
		{
			var fileData:String = OpenFLAssets.getText(getFile(file));
			if (fileData == null)
				fileData = '';
			if (!FileSystem.exists(directory))
				FileSystem.createDirectory(directory);
			File.saveContent(Path.join([directory, fileName]), fileData);
		}
		catch (e:haxe.Exception)
		{
			failedFiles.push('${getFile(file)} (${e.message})');
			failedFilesStack.push('${getFile(file)} (${e.stack})');
		}
	}

	public function getFileBytes(file:String):ByteArray
	{
		switch (Path.extension(file).toLowerCase())
		{
			case 'otf' | 'ttf':
				// Fonts are usually embedded into the executable, so on a first-run
				// mobile install they don't exist as files on the storage yet and
				// reading them from the filesystem fails. Pull the bytes through
				// the asset libraries first and only fall back to the filesystem.
				var bytes:ByteArray = null;
				try
				{
					bytes = OpenFLAssets.getBytes(file);
				}
				catch (e:Dynamic) {}
				if (bytes == null)
				{
					try
					{
						bytes = LimeAssets.getBytes(file);
					}
					catch (e:Dynamic) {}
				}
				if (bytes == null)
				{
					try
					{
						bytes = ByteArray.fromFile(file);
					}
					catch (e:Dynamic) {}
				}
				return bytes;
			default:
				return OpenFLAssets.getBytes(file);
		}
	}

	static inline function isFontFile(file:String):Bool
	{
		var ext:String = Path.extension(file).toLowerCase();
		return ext == 'ttf' || ext == 'otf';
	}

	// Internal fonts that resolve from the packaged assets never need a storage
	// copy: they load straight from the package at runtime. Mod fonts are NOT
	// covered here, the mod system reads those from the filesystem instead.
	static inline function isPackagedFont(file:String):Bool
	{
		return isFontFile(file) && !file.startsWith('mods/') && OpenFLAssets.exists(getFile(file));
	}

	public static function getFile(file:String):String
	{
		if (OpenFLAssets.exists(file))
			return file;

		@:privateAccess
		for (library in LimeAssets.libraries.keys())
		{
			if (OpenFLAssets.exists('$library:$file') && library != 'default')
				return '$library:$file';
		}

		return file;
	}

	public static function checkExistingFiles():Bool
	{
		locatedFiles = OpenFLAssets.list();

		// removes unwanted assets
		var assets = locatedFiles.filter(folder -> folder.startsWith('assets/'));
		var mods = locatedFiles.filter(folder -> folder.startsWith('mods/'));
		locatedFiles = assets.concat(mods);
		locatedFiles = locatedFiles.filter(file -> !FileSystem.exists(file));
		locatedFiles = locatedFiles.filter(file -> !isPackagedFont(file));

		var filesToRemove:Array<String> = [];

		for (file in locatedFiles)
		{
			if (filesToRemove.contains(file))
				continue;

			if(file.endsWith(IGNORE_FOLDER_FILE_NAME) && !directoriesToIgnore.contains(Path.directory(file)))
				directoriesToIgnore.push(Path.directory(file));

			if (directoriesToIgnore.length > 0)
			{
				for (directory in directoriesToIgnore)
				{
					if (file.startsWith(directory))
						filesToRemove.push(file);
				}
			}
		}

		locatedFiles = locatedFiles.filter(file -> !filesToRemove.contains(file));

		maxLoopTimes = locatedFiles.length;

		return (maxLoopTimes <= 0);
	}
}
#end
