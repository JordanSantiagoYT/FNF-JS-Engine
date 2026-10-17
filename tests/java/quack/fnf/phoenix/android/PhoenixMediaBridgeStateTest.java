package quack.fnf.phoenix.android;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Host-JVM regression tests for the real Media3 bridge lifecycle/artwork state
 * and the action protocol emitted by PhoenixMedia controller callbacks.
 */
public final class PhoenixMediaBridgeStateTest
{
	private static int assertions;

	public static void main(String[] args) throws Exception
	{
		testServiceStartsOnlyForReadyPlaybackAndOnlyOnce();
		testServiceFailureStopAndRecreationResetLifecycle();
		testArtworkGenerationsRejectStaleResults();
		testWorkerCompletionCannotApplySupersededArtwork();
		testControllerActionProtocol();
		System.out.println("PhoenixMediaBridgeState: " + assertions + " assertions passed");
	}

	private static void testServiceStartsOnlyForReadyPlaybackAndOnlyOnce()
	{
		PhoenixMediaBridgeState state = new PhoenixMediaBridgeState();
		check(!state.requestMediaServiceStart(false), "paused/buffering setup never starts the service");
		check(state.requestMediaServiceStart(true), "first ready playback requests the service");
		check(!state.requestMediaServiceStart(true), "repeated ready playback is deduplicated before onCreate");

		state.onMediaServiceCreated();
		check(state.isMediaServiceCreated(), "successful service setup is recorded");
		check(!state.requestMediaServiceStart(true), "an existing Media3 service is not restarted");
	}

	private static void testServiceFailureStopAndRecreationResetLifecycle()
	{
		PhoenixMediaBridgeState state = new PhoenixMediaBridgeState();
		check(state.requestMediaServiceStart(true), "initial service request succeeds");
		state.onMediaServiceStartFailed();
		check(state.requestMediaServiceStart(true), "synchronous start failure allows a later playback retry");
		check(state.requestMediaServiceStop(), "a pending start can be cancelled before service creation");
		check(!state.requestMediaServiceStop(), "stop is idempotent after pending lifecycle flags clear");

		state.onMediaServiceCreated();
		check(!state.requestMediaServiceStart(true), "controller-created service does not get a duplicate start request");
		state.onMediaServiceDestroyed();
		check(!state.isMediaServiceCreated(), "system destruction clears stale running state");
		check(state.requestMediaServiceStart(true), "ready playback recreates a destroyed service");
		state.onMediaServiceCreated();
		check(state.requestMediaServiceStop(), "release/stop requests teardown of a created service");
		check(!state.isMediaServiceCreated(), "teardown immediately clears the local created flag");
	}

	private static void testArtworkGenerationsRejectStaleResults()
	{
		PhoenixMediaBridgeState state = new PhoenixMediaBridgeState();
		long firstSong = state.beginArtworkUpdate();
		check(state.acceptsArtwork(firstSong), "current artwork generation is accepted");

		long secondSong = state.beginArtworkUpdate();
		check(!state.acceptsArtwork(firstSong), "new metadata rejects old artwork");
		check(state.acceptsArtwork(secondSong), "new metadata accepts its own artwork");

		state.invalidateArtworkUpdates();
		check(!state.acceptsArtwork(secondSong), "session release rejects queued artwork callbacks");
	}

	private static void testWorkerCompletionCannotApplySupersededArtwork() throws Exception
	{
		final PhoenixMediaBridgeState state = new PhoenixMediaBridgeState();
		final long firstSong = state.beginArtworkUpdate();
		final CountDownLatch workerReady = new CountDownLatch(1);
		final CountDownLatch allowCompletion = new CountDownLatch(1);
		final AtomicBoolean staleResultAccepted = new AtomicBoolean(true);

		Thread worker = new Thread(new Runnable()
		{
			@Override public void run()
			{
				workerReady.countDown();
				try
				{
					allowCompletion.await();
				}
				catch (InterruptedException exception)
				{
					Thread.currentThread().interrupt();
					throw new AssertionError("artwork worker was interrupted", exception);
				}
				staleResultAccepted.set(state.acceptsArtwork(firstSong));
			}
		}, "PhoenixMediaBridgeStateTest-worker");
		worker.start();
		workerReady.await();

		long secondSong = state.beginArtworkUpdate();
		check(state.acceptsArtwork(secondSong), "replacement metadata is current before worker resumes");
		allowCompletion.countDown();
		worker.join();
		check(!staleResultAccepted.get(), "background completion cannot apply artwork for an older song");
	}

	private static void testControllerActionProtocol()
	{
		check("play".equals(PhoenixMediaAction.playWhenReady(true)), "play command reaches Haxe unchanged");
		check("pause".equals(PhoenixMediaAction.playWhenReady(false)), "pause command reaches Haxe unchanged");
		check("stop".equals(PhoenixMediaAction.stop()), "stop command reaches Haxe unchanged");
		check("next".equals(PhoenixMediaAction.next()), "next media button reaches Haxe unchanged");
		check("previous".equals(PhoenixMediaAction.previous()), "previous media button reaches Haxe unchanged");
		check("seek:0".equals(PhoenixMediaAction.seek(-500, 10_000, true, false)),
			"negative seek is clamped to the start of the mirrored item");
		check("seek:10000".equals(PhoenixMediaAction.seek(15_000, 10_000, true, false)),
			"seek is clamped to the known mirrored duration");
		check("seek:15000".equals(PhoenixMediaAction.seek(15_000, 0, false, false)),
			"unknown-duration seek preserves the requested position");
		check("seek:0".equals(PhoenixMediaAction.seek(15_000, 10_000, true, true)),
			"default-position seek maps to the start of the item");
	}

	private static void check(boolean condition, String message)
	{
		assertions++;
		if (!condition)
			throw new AssertionError(message);
	}
}
