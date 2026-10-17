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

/**
 * The action protocol sent by the Media3 bridge to PhoenixCore/Haxe.
 *
 * Keeping it Android-free lets host-JVM tests cover the commands produced by
 * real controller callbacks without pretending to emulate a MediaSession.
 */
final class PhoenixMediaAction
{
	private PhoenixMediaAction() {}

	static String playWhenReady(boolean playWhenReady)
	{
		return playWhenReady ? "play" : "pause";
	}

	static String stop()
	{
		return "stop";
	}

	static String next()
	{
		return "next";
	}

	static String previous()
	{
		return "previous";
	}

	/**
	 * Formats a seek request after constraining it to the mirrored timeline.
	 * durationKnown distinguishes Media3's TIME_UNSET from a valid duration.
	 */
	static String seek(long requestedPositionMs, long durationMs, boolean durationKnown,
		boolean seekToDefaultPosition)
	{
		long position = seekToDefaultPosition ? 0 : Math.max(0, requestedPositionMs);
		if (durationKnown)
			position = Math.min(position, Math.max(0, durationMs));
		return "seek:" + position;
	}
}
