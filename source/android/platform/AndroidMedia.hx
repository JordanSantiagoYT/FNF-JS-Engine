/*
 * Copyright (C) 2026 Phoenix Engine Contributors
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

package android.platform;

import flixel.util.FlxSignal;
import haxe.Json;
#if android
import lime.system.JNI;
#end

/**
 * Android media integration: Jetpack Media3 MediaSession / MediaSessionService
 * (system media controls, lock screen, Bluetooth and Android Auto), MediaStyle
 * notifications, audio focus and native audio output information.
 *
 * Media actions from the system fire the signals below; the engine (see
 * PlayState) maps them back onto gameplay/audio.
 */
class AndroidMedia
{
	// Playback states accepted by setPlaybackState.
	public static inline final STATE_STOPPED:Int = 0;
	public static inline final STATE_PLAYING:Int = 1;
	public static inline final STATE_PAUSED:Int = 2;
	public static inline final STATE_BUFFERING:Int = 3;

	// ------------------------------------------------------------------
	// Media action signals (from system media controls / Bluetooth / etc.)
	// ------------------------------------------------------------------

	public static var onPlay(get, never):FlxSignal;
	public static var onPause(get, never):FlxSignal;
	public static var onStop(get, never):FlxSignal;
	public static var onNext(get, never):FlxSignal;
	public static var onPrevious(get, never):FlxSignal;

	/** Seek request, position in milliseconds. */
	public static var onSeek(get, never):FlxTypedSignal<Float->Void>;

	/**
	 * Audio focus changes: "gain", "loss", "lossTransient", "duck".
	 * Engines should pause on loss/lossTransient, lower volume on duck and
	 * restore on gain.
	 */
	public static var onAudioFocusChanged(get, never):FlxTypedSignal<String->Void>;

	static inline function get_onPlay():FlxSignal
		return AndroidBridge.onMediaPlay;

	static inline function get_onPause():FlxSignal
		return AndroidBridge.onMediaPause;

	static inline function get_onStop():FlxSignal
		return AndroidBridge.onMediaStop;

	static inline function get_onNext():FlxSignal
		return AndroidBridge.onMediaNext;

	static inline function get_onPrevious():FlxSignal
		return AndroidBridge.onMediaPrevious;

	static inline function get_onSeek():FlxTypedSignal<Float->Void>
		return AndroidBridge.onMediaSeek;

	static inline function get_onAudioFocusChanged():FlxTypedSignal<String->Void>
		return AndroidBridge.onFocusChanged;

	// ------------------------------------------------------------------
	// Session / metadata / playback state
	// ------------------------------------------------------------------

	/**
	 * Publishes the currently playing song to Android's Media3 session.
	 *
	 * `artworkPath` may be null, an Android asset path, a local file path or a
	 * content/file URI. The native bridge embeds small local artwork in the
	 * metadata so system clients can render it without private-file access.
	 * No-op outside of Android.
	 */
	public static function updateNowPlaying(title:String, artist:String, durationMs:Float = -1, ?album:String, ?artworkPath:String):Void
	{
		#if android
		AndroidBridge.ensureRegistered();
		createSession_jni();
		setMetadata_jni(title ?? "", artist ?? "", album ?? "", Std.int(durationMs), artworkPath ?? "");
		setActive_jni(true);
		#end
	}

	/** Updates the playback state exposed to the media system. */
	public static function setPlaybackState(state:Int, positionMs:Float, playbackSpeed:Float = 1.0):Void
	{
		#if android
		setPlaybackState_jni(state, Std.int(positionMs), playbackSpeed);
		#end
	}

	/**
	 * Compatibility helper for older callers. Media3 derives its notification
	 * from `updateNowPlaying` and `setPlaybackState`; it requests its service
	 * only if the native bridge already mirrors ready playback.
	 */
	public static function updateNotification(title:String, artist:String, playing:Bool):Void
	{
		#if android
		notifyMedia_jni(title ?? "", artist ?? "", playing);
		#end
	}

	/**
	 * Compatibility request for the Media3 MediaSessionService. It is ignored
	 * until the native bridge already mirrors ready playback; Media3 owns the
	 * foreground MediaStyle notification thereafter. Requires
	 * FOREGROUND_SERVICE_MEDIA_PLAYBACK (declared by the engine's manifest
	 * template). The Haxe audio player remains the audio owner.
	 */
	public static function startForegroundService(title:String, artist:String, playing:Bool = true):Void
	{
		#if android
		startForegroundService_jni(title ?? "", artist ?? "", playing);
		#end
	}

	public static function stopForegroundService():Void
	{
		#if android
		stopForegroundService_jni();
		#end
	}

	/** Ends the media session entirely (playback fully over). */
	public static function stop():Void
	{
		#if android
		releaseSession_jni();
		#end
	}

	// ------------------------------------------------------------------
	// Audio focus
	// ------------------------------------------------------------------

	/**
	 * Requests audio focus with a listener forwarding interruptions to
	 * `onAudioFocusChanged`. Returns true when granted immediately.
	 */
	public static function requestAudioFocus():Bool
	{
		#if android
		return requestAudioFocus_jni() == 1;
		#else
		return true;
		#end
	}

	public static function abandonAudioFocus():Void
	{
		#if android
		abandonAudioFocus_jni();
		#end
	}

	// ------------------------------------------------------------------
	// Audio output information (latency calibration)
	// ------------------------------------------------------------------

	/**
	 * Native audio output information used for rhythm-game timing / offset
	 * calibration. Returns null on non-Android targets.
	 */
	public static function getAudioInfo():Null<AudioOutputInfo>
	{
		#if android
		var raw:String = getAudioInfo_jni();
		if (raw == null || raw.length == 0)
			return null;

		try
		{
			var data:Dynamic = Json.parse(raw);
			return {
				sampleRate: Std.parseInt(Std.string(data.sampleRate)) ?? 44100,
				framesPerBuffer: Std.parseInt(Std.string(data.framesPerBuffer)) ?? 0,
				minBufferSizeBytes: Std.parseInt(Std.string(data.minBufferSizeBytes)) ?? 0,
				estimatedLatencyMs: Std.parseFloat(Std.string(data.estimatedLatencyMs))
			};
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	// ------------------------------------------------------------------
	// JNI bindings
	// ------------------------------------------------------------------

	#if android
	static var _createSession:Dynamic = null;

	static function createSession_jni():Void
	{
		if (_createSession == null)
			_createSession = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'createSession', '()V');
		_createSession();
	}

	static var _setMetadata:Dynamic = null;

	static function setMetadata_jni(title:String, artist:String, album:String, durationMs:Int, artworkPath:String):Void
	{
		if (_setMetadata == null)
			_setMetadata = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'setMetadata',
				'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;JLjava/lang/String;)V');
		_setMetadata(title, artist, album, durationMs, artworkPath);
	}

	static var _setPlaybackState:Dynamic = null;

	static function setPlaybackState_jni(state:Int, positionMs:Int, speed:Float):Void
	{
		if (_setPlaybackState == null)
			_setPlaybackState = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'setPlaybackState', '(IJF)V');
		_setPlaybackState(state, positionMs, speed);
	}

	static var _setActive:Dynamic = null;

	static function setActive_jni(active:Bool):Void
	{
		if (_setActive == null)
			_setActive = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'setActive', '(Z)V');
		_setActive(active);
	}

	static var _releaseSession:Dynamic = null;

	static function releaseSession_jni():Void
	{
		if (_releaseSession == null)
			_releaseSession = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'releaseSession', '()V');
		_releaseSession();
	}

	static var _notifyMedia:Dynamic = null;

	static function notifyMedia_jni(title:String, artist:String, playing:Bool):Void
	{
		if (_notifyMedia == null)
			_notifyMedia = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'notifyMedia', '(Ljava/lang/String;Ljava/lang/String;Z)V');
		_notifyMedia(title, artist, playing);
	}

	static var _startForegroundService:Dynamic = null;

	static function startForegroundService_jni(title:String, artist:String, playing:Bool):Void
	{
		if (_startForegroundService == null)
			_startForegroundService = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'startForegroundService',
				'(Ljava/lang/String;Ljava/lang/String;Z)V');
		_startForegroundService(title, artist, playing);
	}

	static var _stopForegroundService:Dynamic = null;

	static function stopForegroundService_jni():Void
	{
		if (_stopForegroundService == null)
			_stopForegroundService = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'stopForegroundService', '()V');
		_stopForegroundService();
	}

	static var _requestAudioFocus:Dynamic = null;

	static function requestAudioFocus_jni():Int
	{
		if (_requestAudioFocus == null)
			_requestAudioFocus = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'requestAudioFocus', '()I');
		return _requestAudioFocus();
	}

	static var _abandonAudioFocus:Dynamic = null;

	static function abandonAudioFocus_jni():Void
	{
		if (_abandonAudioFocus == null)
			_abandonAudioFocus = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'abandonAudioFocus', '()V');
		_abandonAudioFocus();
	}

	static var _getAudioInfo:Dynamic = null;

	static function getAudioInfo_jni():String
	{
		if (_getAudioInfo == null)
			_getAudioInfo = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'getAudioInfo', '()Ljava/lang/String;');
		return _getAudioInfo();
	}
	#end
}

typedef AudioOutputInfo =
{
	var sampleRate:Int;
	var framesPerBuffer:Int;
	var minBufferSizeBytes:Int;
	var estimatedLatencyMs:Float;
}
