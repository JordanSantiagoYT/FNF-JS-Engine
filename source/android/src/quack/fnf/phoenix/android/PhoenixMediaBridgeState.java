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
 * Thread-safe bookkeeping for the bridge-owned edges of the Media3 lifecycle.
 *
 * MediaSessionService itself owns media notifications and foreground promotion.
 * This class only deduplicates the bridge's request to start that service after
 * the mirrored player is ready, and rejects artwork work completed for an old
 * song/session. It intentionally has no Android dependencies so lifecycle
 * invariants can be tested on the host JVM.
 */
final class PhoenixMediaBridgeState
{
	private boolean mediaServiceStartRequested;
	private boolean mediaServiceCreated;
	private long artworkGeneration;

	/**
	 * Returns true exactly once for a live, genuinely-playing bridge session.
	 * A service which Media3 already created does not need another start request.
	 */
	synchronized boolean requestMediaServiceStart(boolean playbackReady)
	{
		if (!playbackReady || mediaServiceCreated || mediaServiceStartRequested)
			return false;

		mediaServiceStartRequested = true;
		return true;
	}

	/** Marks that MediaSessionService successfully attached the shared session. */
	synchronized void onMediaServiceCreated()
	{
		mediaServiceCreated = true;
	}

	/** Allows a synchronous Context.startForegroundService failure to be retried. */
	synchronized void onMediaServiceStartFailed()
	{
		if (!mediaServiceCreated)
			mediaServiceStartRequested = false;
	}

	/**
	 * Clears all service lifecycle flags and returns whether stopService should
	 * be attempted. This covers both a fully-created service and a request which
	 * was accepted but has not reached onCreate yet.
	 */
	synchronized boolean requestMediaServiceStop()
	{
		boolean shouldStop = mediaServiceCreated || mediaServiceStartRequested;
		mediaServiceCreated = false;
		mediaServiceStartRequested = false;
		return shouldStop;
	}

	/** Clears lifecycle flags when Android destroys the service independently. */
	synchronized void onMediaServiceDestroyed()
	{
		mediaServiceCreated = false;
		mediaServiceStartRequested = false;
	}

	/** True when the MediaSessionService instance, not necessarily its FGS, is alive. */
	synchronized boolean isMediaServiceCreated()
	{
		return mediaServiceCreated;
	}

	/**
	 * Invalidates older artwork work and returns the monotonically incremented
	 * token owned by the new metadata update. Results are accepted only when
	 * their token still equals the current metadata generation.
	 */
	synchronized long beginArtworkUpdate()
	{
		return ++artworkGeneration;
	}

	/** Invalidates pending artwork when the session is released. */
	synchronized void invalidateArtworkUpdates()
	{
		++artworkGeneration;
	}

	/** Returns whether a background artwork result still belongs to current metadata. */
	synchronized boolean acceptsArtwork(long generation)
	{
		return generation == artworkGeneration;
	}
}
