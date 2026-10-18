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

		state.ffmpegExists = false;
		state.renderWidth = lime.app.Application.current.window.width;
		state.renderHeight = lime.app.Application.current.window.height;
		if (state.renderWidth <= 0 || state.renderHeight <= 0) return;

		var fileName = '$renderPath$prefixName';
		if(FileSystem.exists(fileName + '.mp4')) {
			trace ('Duplicate video found! Adding anti-dupe...');
			fileName += '-' + DateUtils.cleanedDate;
		}

		try{
			PlayState.process = new Process('ffmpeg', ['-v', 'quiet', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', state.renderWidth + 'x' + state.renderHeight, '-r', Std.string(state.targetFPS), '-i', '-', '-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2', '-c:v', ClientPrefs.vidEncoder, '-b', Std.string(ClientPrefs.renderBitrate * 1000000), fileName + '.mp4']);
			state.ffmpegExists = true;
			FlxG.autoPause = false;
		}catch(e:Dynamic){
			trace("Error initializing FFmpeg process: " + e);
			PlayState.process = null;
			state.ffmpegExists = false;
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

		final window = lime.app.Application.current.window;
		// FFmpeg's rawvideo stride is fixed at startup. The scale-mode game
		// dimensions are logical, NOT physical: capture the whole window at
		// exactly the -s dimensions, including 16:9 letterboxing when disabled.
		// Stop cleanly on a physical resize rather than feeding corrupt frames.
		if (window.width != state.renderWidth || window.height != state.renderHeight)
		{
			FlxG.log.warn('Window resized while recording; closing the current video to avoid corrupted frames.');
			state.ffmpegExists = false;
			stopRender();
			return;
		}

		debug.FrameProfiler.beginRender();
		state.img = window.readPixels();
		if (state.img == null || state.img.width != state.renderWidth || state.img.height != state.renderHeight)
		{
			debug.FrameProfiler.endRender();
			FlxG.log.warn('Unexpected video frame dimensions; stopping the render to avoid corrupted frames.');
			state.ffmpegExists = false;
			stopRender();
			return;
		}
		state.bytes = state.img.getPixels(new lime.math.Rectangle(0, 0, state.img.width, state.img.height));
		if (state.bytes.length != state.renderWidth * state.renderHeight * 4)
		{
			debug.FrameProfiler.endRender();
			FlxG.log.warn('Invalid RGBA frame size; stopping the render.');
			state.ffmpegExists = false;
			stopRender();
			return;
		}
		try
		{
			PlayState.process.stdin.writeBytes(state.bytes, 0, state.bytes.length);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('FFmpeg could not write the video frame: ' + e);
			state.ffmpegExists = false;
			stopRender();
		}
		debug.FrameProfiler.endRender();
		#end
	}

	public static function stopRender():Void
	{
		#if sys
		if (PlayState.process == null)
			return;

		final process = PlayState.process;
		PlayState.process = null;
		try
		{
			process.stdin.close(); // EOF lets FFmpeg finalize its MP4 index.
			process.exitCode();
		}
		catch (e:Dynamic) FlxG.log.warn('FFmpeg closed with an error: ' + e);
		process.close();
		FlxG.autoPause = ClientPrefs.autoPause;
		#end
	}
}