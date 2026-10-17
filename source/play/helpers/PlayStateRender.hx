package play.helpers;

import backend.ClientPrefs;
import backend.Paths;

import play.PlayState;

import utils.DateUtils;

// REFACTOR: ffmpeg render pipeline extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateRender
{
	public static function initRender(state:PlayState, renderPath:String = "assets/gameRenders/", ?prefixName:String = null):Void
	{
		#if sys
		#if windows
		if (!FileSystem.exists('ffmpeg.exe'))
		{
			trace("\"FFmpeg\" not found! (Is it in the same folder as FNF-Phoenix-Engine?)");
			return;
		}
		#end
		// Maybe check if it isn't an directory?
		if (prefixName == null)
				prefixName = Paths.formatToSongPath(PlayState.SONG.song);
		else if (prefixName.startsWith('/'))
				prefixName = prefixName.substr(1);

		// TODO: make sure this *absolutely* checks if you input an proper path
		if (!renderPath.endsWith('/'))
				renderPath = haxe.io.Path.addTrailingSlash(renderPath);

		if(!FileSystem.exists(renderPath)) { //In case you delete the render folder/it doesn't exist
			trace ('$renderPath folder not found! Creating the $renderPath folder...');
			FileSystem.createDirectory(renderPath);
		}
		else if (!FileSystem.isDirectory(renderPath)){
				FileSystem.deleteFile(renderPath);
				FileSystem.createDirectory(renderPath);
		}

		state.ffmpegExists = true;

		var fileName = '$renderPath$prefixName';
		if(FileSystem.exists(fileName + '.mp4')) {
			trace ('Duplicate video found! Adding anti-dupe...');
			fileName += '-' + DateUtils.cleanedDate;
		}

		try{
			PlayState.process = new Process('ffmpeg', ['-v', 'quiet', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', lime.app.Application.current.window.width + 'x' + lime.app.Application.current.window.height, '-r', Std.string(state.targetFPS), '-i', '-', '-c:v', ClientPrefs.vidEncoder, '-b', Std.string(ClientPrefs.renderBitrate * 1000000), fileName + '.mp4']);
			FlxG.autoPause = false;
		}catch(e:Dynamic){
			trace("Error initializing FFmpeg process: " + e);
			PlayState.process = null;
		}
		#else
		trace('Video rendering is not supported on this platform.');
		#end
	}

	public static function pipeFrame(state:PlayState):Void
	{
		#if sys
		if (!state.ffmpegExists || PlayState.process == null)
			return;

		debug.FrameProfiler.beginRender();
		state.img = lime.app.Application.current.window.readPixels(new lime.math.Rectangle(FlxG.scaleMode.offset.x, FlxG.scaleMode.offset.y, FlxG.scaleMode.gameSize.x, FlxG.scaleMode.gameSize.y));
		state.bytes = state.img.getPixels(new lime.math.Rectangle(0, 0, state.img.width, state.img.height));
		PlayState.process.stdin.writeBytes(state.bytes, 0, state.bytes.length);
		debug.FrameProfiler.endRender();
		#end
	}

	public static function stopRender():Void
	{
		#if sys
		if (!ClientPrefs.ffmpegMode || PlayState.process == null)
			return;

		PlayState.process?.stdin?.close();

		PlayState.process?.close();

		PlayState.process?.kill();

		FlxG.autoPause = ClientPrefs.autoPause;
		#end
	}
}