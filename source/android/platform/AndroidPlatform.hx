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

import flixel.FlxG;
import flixel.util.FlxTimer;

/**
 * Facade for the Phoenix Android platform layer.
 *
 * Call `AndroidPlatform.init()` once at startup (Main.hx does this) and the
 * whole native layer becomes available through the dedicated modules:
 *
 *   - AndroidMedia         Media3 session/service, MediaStyle notification, audio focus
 *   - AndroidDisplay       resolution/DPI/orientation/refresh rate/cutouts,
 *                          immersive fullscreen
 *   - AndroidSystem        memory pressure, battery, wake lock,
 *                          process-death recovery
 *   - AndroidGamepad       controller info + connection events
 *   - AndroidHardwareInput volume keys as bindable game input
 *   - AndroidHaptics       vibration
 *   - AndroidStorage       SAF document picker + content:// URIs
 *   - AndroidIntents       URLs, settings, file sharing
 *   - AndroidNotification  simple notifications
 *   - AndroidLifecycle     Activity lifecycle signals
 *   - AndroidDiscord       presence through the media session
 *
 * On non-Android targets every module compiles to safe no-ops, so none of
 * the desktop/web/Flash/HashLink/iOS builds depend on Android code.
 */
class AndroidPlatform
{
	static var initialized:Bool = false;
	static var deepLinkDrainTimer:FlxTimer = null;

	/** True once init() completed on Android; always false elsewhere. */
	public static var active(default, null):Bool = false;

	/**
	 * Boots the platform layer: registers the JNI bridge, starts lifecycle
	 * handling, controller watching and memory-pressure responses.
	 *
	 * @param autoPauseAudio pause/resume music when the Activity backgrounds
	 * @param watchDisplay   start receiving display change events
	 */
	public static function init(autoPauseAudio:Bool = true, watchDisplay:Bool = true):Void
	{
		#if android
		if (initialized)
			return;
		initialized = true;

		AndroidBridge.ensureRegistered();

		// A phoenix:// URI that launched the app cold is buffered natively
		// before any Haxe subscriber exists; keep retrying its delivery
		// until something listens (the buffer is only cleared after
		// confirmed delivery).
		deepLinkDrainTimer = new FlxTimer().start(1, function(tmr:FlxTimer)
		{
			if (AndroidBridge.drainPendingDeepLink())
				tmr.cancel();
		}, 0);

		// Lifecycle: keeps audio/gameplay state sane across focus changes.
		AndroidLifecycle.init(autoPauseAudio);

		// Controllers.
		AndroidGamepad.init();

		// Device-state watchers.
		if (watchDisplay)
			AndroidDisplay.watchDisplay();

		// Memory pressure: flush saves and release cached assets so Android
		// is less likely to kill the process.
		AndroidBridge.onLowMemory.add(releaseCaches);
		AndroidBridge.onTrimMemory.add(function(level:Int)
		{
			// TRIM_MEMORY_RUNNING_CRITICAL and anything >= TRIM_MEMORY_UI_HIDDEN (20).
			if (level >= 15)
				releaseCaches();
		});

		// Flush saves whenever we leave the foreground so process death
		// cannot eat progress.
		AndroidBridge.onLifecycleEvent.add(function(event:String)
		{
			if (event == 'onPause' || event == 'onStop')
				flushSave();
		});

		active = true;
		#else
		initialized = true;
		#end
	}

	static function releaseCaches():Void
	{
		#if android
		try
		{
			flushSave();
			backend.Paths.clearStoredMemory();
			backend.Paths.clearUnusedMemory();
		}
		catch (e:Dynamic) {}
		#end
	}

	static function flushSave():Void
	{
		#if android
		try
		{
			if (FlxG.save != null)
				FlxG.save.flush();
		}
		catch (e:Dynamic) {}
		#end
	}
}
