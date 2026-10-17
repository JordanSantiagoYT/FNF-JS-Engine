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

package quack.fnf.phoenix.android;

import android.util.Log;

import androidx.media3.session.MediaSession;
import androidx.media3.session.MediaSessionService;

/**
 * Hosts Phoenix's Media3 session while gameplay is backgrounded.
 *
 * MediaSessionService supplies the synchronized MediaStyle notification and
 * makes the session discoverable to system media clients. The actual audio
 * remains in the Haxe/Flixel layer; PhoenixMedia's mirrored Player forwards
 * controller actions back to that layer.
 *
 * Part of the Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.
 */
public class PhoenixMediaService extends MediaSessionService
{
	@Override public void onCreate()
	{
		super.onCreate();

		try
		{
			MediaSession session = PhoenixMedia.getSessionForService(getApplicationContext());
			if (session != null)
				addSession(session);
			PhoenixMedia.onMediaServiceCreated();
		}
		catch (Exception e)
		{
			Log.e(PhoenixMedia.LOG_TAG, "MediaSessionService setup failed: " + e);
		}
	}

	@Override public MediaSession onGetSession(MediaSession.ControllerInfo controllerInfo)
	{
		return PhoenixMedia.getSessionForService(getApplicationContext());
	}

	@Override public void onDestroy()
	{
		PhoenixMedia.onMediaServiceDestroyed();
		super.onDestroy();
	}
}
