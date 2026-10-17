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

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.BitmapFactory;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.KeyEvent;

import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MediaMetadata;
import androidx.media3.common.PlaybackParameters;
import androidx.media3.common.Player;
import androidx.media3.common.SimpleBasePlayer;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.session.MediaSession;

import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;

import org.haxe.extension.Extension;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.Collections;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

/**
 * Android media bridge for Phoenix Engine.
 *
 * A lightweight Media3 Player mirrors the audio that Haxe/Flixel owns. It
 * deliberately does not decode a second copy of the instrumental; instead it
 * publishes the engine's metadata, playback state, speed and timeline through
 * a Media3 MediaSession. System controllers call the mirrored Player and are
 * routed back to Haxe through PhoenixCore.
 *
 * PhoenixMediaService hosts this session as a MediaSessionService, which makes
 * it discoverable by lock-screen controls, Bluetooth clients, Android Auto and
 * other media browsers while gameplay is in the background.
 *
 * Part of the Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.
 */
public class PhoenixMedia extends Extension
{
	public static final String LOG_TAG = "PhoenixMedia";

	// Media3 owns its media-notification channel. This bridge only owns the
	// channel used by AndroidNotification's non-media notifications.
	public static final String GENERAL_CHANNEL_ID = "phoenix_general";

	private static final String SESSION_ID = "PhoenixEngineMedia";
	private static final int MAX_ARTWORK_BYTES = 2 * 1024 * 1024;
	private static final long MAX_ARTWORK_PIXELS = 4L * 1024L * 1024L;

	private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());
	private static final PhoenixMediaBridgeState BRIDGE_STATE = new PhoenixMediaBridgeState();
	private static final ThreadPoolExecutor ARTWORK_EXECUTOR = createArtworkExecutor();

	private static volatile HaxeMediaPlayer player = null;
	private static volatile MediaSession session = null;
	private static volatile boolean sessionActive = false;

	private static AudioManager audioManager = null;
	private static AudioFocusRequest audioFocusRequest = null;
	private static AudioManager.OnAudioFocusChangeListener focusListener = null;

	// ------------------------------------------------------------------
	// Media3 session lifecycle
	// ------------------------------------------------------------------

	/** Creates the Media3 player/session. Safe to call repeatedly. */
	public static void createSession()
	{
		final Context context = getApplicationContext();
		if (context == null)
			return;

		runOnMainThread(new Runnable()
		{
			@Override public void run()
			{
				ensureSessionInternal(context);
			}
		});
	}

	/**
	 * Publishes the currently playing song metadata. artworkPath can be an
	 * app asset path, a file path, file:// URI, content:// URI or a regular
	 * media artwork URI. Local image data is embedded when it is small enough,
	 * so external media clients do not need permission to read app-private
	 * files.
	 */
	public static void setMetadata(final String title, final String artist, final String album,
		final long durationMs, final String artworkPath)
	{
		final Context context = getApplicationContext();
		if (context == null)
			return;

		runOnMainThread(new Runnable()
		{
			@Override public void run()
			{
				if (ensureSessionInternal(context) == null)
				{
					BRIDGE_STATE.invalidateArtworkUpdates();
					sessionActive = false;
					return;
				}

				String safeArtworkPath = safeString(artworkPath);
				long artworkGeneration = BRIDGE_STATE.beginArtworkUpdate();
				HaxeMediaPlayer mediaPlayer = ensurePlayerInternal();
				mediaPlayer.updateMetadata(safeString(title), safeString(artist), safeString(album), durationMs,
					getRemoteArtworkUri(safeArtworkPath), artworkGeneration);
				sessionActive = true;

				// File/content/asset I/O and image-header validation must never run
				// on Media3's application/main looper. The bounded worker posts only
				// a current result back to the mirrored player.
				scheduleArtworkLoad(context, safeArtworkPath, artworkGeneration);
			}
		});
	}

	/**
	 * Updates the state mirrored to Media3.
	 *
	 * @param state 0 = stopped, 1 = playing, 2 = paused, 3 = buffering.
	 */
	public static void setPlaybackState(final int state, final long positionMs, final float speed)
	{
		final Context context = getApplicationContext();
		if (context == null)
			return;

		runOnMainThread(new Runnable()
		{
			@Override public void run()
			{
				if (ensureSessionInternal(context) == null)
					return;

				HaxeMediaPlayer mediaPlayer = ensurePlayerInternal();
				mediaPlayer.updatePlaybackState(state, positionMs, speed);

				// Do not start a service merely because a song was selected or is
				// paused. Once Haxe has mirrored real ready playback, Media3 owns
				// notification posting and foreground promotion from its service.
				if (state == 1)
					startMediaServiceForReadyPlayback(context, mediaPlayer);
			}
		});
	}

	/**
	 * Media3 sessions do not have a separate setActive flag. Kept for the
	 * existing Haxe API: true makes sure a session exists; false only removes
	 * it from media-button ownership after playback has been stopped/released.
	 */
	public static void setActive(final boolean active)
	{
		final Context context = getApplicationContext();
		if (context == null)
			return;

		runOnMainThread(new Runnable()
		{
			@Override public void run()
			{
				sessionActive = active && ensureSessionInternal(context) != null;
			}
		});
	}

	/** Returns whether the engine currently owns a live Media3 session. */
	public static boolean isActive()
	{
		return sessionActive && session != null;
	}

	/** Releases the player/session after a song or gameplay state ends. */
	public static void releaseSession()
	{
		final Context context = getApplicationContext();

		runOnMainThread(new Runnable()
		{
			@Override public void run()
			{
				// Invalidate before releasing the player so a queued artwork result
				// can never update a new session with old song art.
				BRIDGE_STATE.invalidateArtworkUpdates();
				ARTWORK_EXECUTOR.getQueue().clear();

				MediaSession oldSession = session;
				HaxeMediaPlayer oldPlayer = player;
				session = null;
				player = null;
				sessionActive = false;

				if (oldSession != null)
				{
					try
					{
						oldSession.release();
					}
					catch (Exception e)
					{
						Log.e(LOG_TAG, "MediaSession release failed: " + e);
					}
				}

				if (oldPlayer != null)
				{
					try
					{
						oldPlayer.release();
					}
					catch (Exception e)
					{
						Log.e(LOG_TAG, "Media3 player release failed: " + e);
					}
				}

				stopMediaServiceInternal(context);
			}
		});
	}

	/**
	 * Returns the session already created by the bridge. A controller cannot
	 * recreate an empty session after gameplay released it; no Haxe audio exists
	 * to back such a session after process/session teardown.
	 */
	static MediaSession getSessionForService(Context context)
	{
		return context == null ? null : session;
	}

	/** Marks the MediaSessionService as created after it attached the shared session. */
	static void onMediaServiceCreated()
	{
		BRIDGE_STATE.onMediaServiceCreated();
	}

	/** Resets a requested start when service setup cannot attach a session. */
	static void onMediaServiceCreationFailed()
	{
		BRIDGE_STATE.onMediaServiceStartFailed();
	}

	/** Marks the MediaSessionService as gone so a later song can restart it. */
	static void onMediaServiceDestroyed()
	{
		BRIDGE_STATE.onMediaServiceDestroyed();
	}

	private static Context getApplicationContext()
	{
		Context context = mainContext;
		return context == null ? null : context.getApplicationContext();
	}

	private static void runOnMainThread(Runnable runnable)
	{
		if (Looper.myLooper() == Looper.getMainLooper())
			runnable.run();
		else
			MAIN_HANDLER.post(runnable);
	}

	private static HaxeMediaPlayer ensurePlayerInternal()
	{
		if (player == null)
			player = new HaxeMediaPlayer();
		return player;
	}

	private static MediaSession ensureSessionInternal(Context context)
	{
		if (context == null)
			return null;

		HaxeMediaPlayer mediaPlayer = ensurePlayerInternal();
		if (session != null)
			return session;

		try
		{
			MediaSession.Builder builder = new MediaSession.Builder(context, mediaPlayer)
				.setId(SESSION_ID)
				.setCallback(new PhoenixMediaSessionCallback());

			PendingIntent sessionActivity = createSessionActivity(context);
			if (sessionActivity != null)
				builder.setSessionActivity(sessionActivity);

			session = builder.build();
			return session;
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "createSession failed: " + e);
			session = null;
			return null;
		}
	}

	private static PendingIntent createSessionActivity(Context context)
	{
		try
		{
			Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
			if (launchIntent == null)
				return null;

			int flags = PendingIntent.FLAG_UPDATE_CURRENT;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
				flags |= PendingIntent.FLAG_IMMUTABLE;
			return PendingIntent.getActivity(context, 0, launchIntent, flags);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "createSessionActivity failed: " + e);
			return null;
		}
	}

	private static String safeString(String value)
	{
		return value == null ? "" : value;
	}

	// ------------------------------------------------------------------
	// MediaSessionService / notifications
	// ------------------------------------------------------------------

	/**
	 * Compatibility entry point for callers that previously started the service
	 * directly. It only requests the service after the mirrored player already
	 * reports ready playback; Media3 itself posts/promotes its notification.
	 */
	public static void startForegroundService(String title, String artist, final boolean playing)
	{
		final Context context = getApplicationContext();
		if (context == null || !playing)
			return;

		runOnMainThread(new Runnable()
		{
			@Override public void run()
			{
				MediaSession mediaSession = ensureSessionInternal(context);
				if (mediaSession != null)
					startMediaServiceForReadyPlayback(context, ensurePlayerInternal());
			}
		});
	}

	/** Stops the Media3 service without discarding the current session metadata. */
	public static void stopForegroundService()
	{
		final Context context = getApplicationContext();
		runOnMainThread(new Runnable()
		{
			@Override public void run()
			{
				stopMediaServiceInternal(context);
			}
		});
	}

	/**
	 * Compatibility entry point for the Haxe API. Media3 builds its MediaStyle
	 * notification from metadata and player state; this must not pre-start a
	 * service while the mirrored player is inactive.
	 */
	public static void notifyMedia(String title, String artist, final boolean playing)
	{
		final Context context = getApplicationContext();
		if (context == null || !playing)
			return;

		runOnMainThread(new Runnable()
		{
			@Override public void run()
			{
				MediaSession mediaSession = ensureSessionInternal(context);
				if (mediaSession != null)
					startMediaServiceForReadyPlayback(context, ensurePlayerInternal());
			}
		});
	}

	/**
	 * Starts the service only after a READY, playWhenReady mirrored player has
	 * been published. Media3's MediaNotificationManager then owns notification
	 * updates, startForeground and its post-playback foreground timeout.
	 */
	private static void startMediaServiceForReadyPlayback(Context context, HaxeMediaPlayer mediaPlayer)
	{
		if (context == null || mediaPlayer == null || !mediaPlayer.isReadyPlayback()
			|| !BRIDGE_STATE.requestMediaServiceStart(true))
			return;

		try
		{
			Intent intent = new Intent(context, PhoenixMediaService.class);
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				context.startForegroundService(intent);
			else
				context.startService(intent);
		}
		catch (Exception e)
		{
			// Android 12+ can reject a foreground-service start from the
			// background. The MediaSession remains usable in the foreground
			// activity, so do not let that policy error crash gameplay and allow
			// the next genuine playback update to retry.
			BRIDGE_STATE.onMediaServiceStartFailed();
			Log.e(LOG_TAG, "startMediaService failed: " + e);
		}
	}

	private static void stopMediaServiceInternal(Context context)
	{
		if (!BRIDGE_STATE.requestMediaServiceStop() || context == null)
			return;

		try
		{
			context.stopService(new Intent(context, PhoenixMediaService.class));
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "stopMediaService failed: " + e);
		}
	}

	/**
	 * Returns whether a MediaSessionService instance is alive. This deliberately
	 * does not claim foreground status: Media3 owns that state and may retain it
	 * during its post-playback timeout.
	 */
	public static boolean isForegroundServiceRunning()
	{
		return BRIDGE_STATE.isMediaServiceCreated();
	}

	/** Creates the notification channels used by simple engine notifications. */
	public static void ensureChannels()
	{
		Context context = getApplicationContext();
		if (context == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
			return;

		try
		{
			NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
			if (manager == null || manager.getNotificationChannel(GENERAL_CHANNEL_ID) != null)
				return;

			NotificationChannel channel = new NotificationChannel(GENERAL_CHANNEL_ID, "General",
				NotificationManager.IMPORTANCE_DEFAULT);
			channel.setDescription("Phoenix Engine notifications");
			manager.createNotificationChannel(channel);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "ensureChannels failed: " + e);
		}
	}

	/** Generic simple notification (title/text), posted on the general channel. */
	public static void notifySimple(int id, String title, String text)
	{
		Context context = getApplicationContext();
		if (context == null)
			return;

		try
		{
			ensureChannels();

			Notification.Builder builder;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				builder = new Notification.Builder(context, GENERAL_CHANNEL_ID);
			else
				builder = new Notification.Builder(context);

			builder.setContentTitle(safeString(title))
				.setContentText(safeString(text))
				.setSmallIcon(android.R.drawable.stat_notify_more)
				.setAutoCancel(true);

			notify(id, builder.build());
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "notifySimple failed: " + e);
		}
	}

	static void notify(int id, Notification notification)
	{
		Context context = getApplicationContext();
		if (context == null || notification == null)
			return;

		try
		{
			NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
			if (manager != null)
				manager.notify(id, notification);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "notify failed: " + e);
		}
	}

	public static void cancelNotification(int id)
	{
		Context context = getApplicationContext();
		if (context == null)
			return;

		try
		{
			NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
			if (manager != null)
				manager.cancel(id);
		}
		catch (Exception ignored) {}
	}

	// ------------------------------------------------------------------
	// Media3 Player implementation and controller callbacks
	// ------------------------------------------------------------------

	/**
	 * Minimal Media3 player that reflects the Haxe audio engine. No sound is
	 * decoded here: Player commands are dispatched to Haxe and Haxe pushes the
	 * resulting state back through setPlaybackState.
	 */
	@UnstableApi
	private static final class HaxeMediaPlayer extends SimpleBasePlayer
	{
		private static final Player.Commands AVAILABLE_COMMANDS = new Player.Commands.Builder()
			.addAll(Player.COMMAND_PLAY_PAUSE, Player.COMMAND_STOP,
				Player.COMMAND_SEEK_TO_DEFAULT_POSITION, Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM,
				Player.COMMAND_SEEK_BACK, Player.COMMAND_SEEK_FORWARD,
				Player.COMMAND_GET_CURRENT_MEDIA_ITEM, Player.COMMAND_GET_TIMELINE,
				Player.COMMAND_GET_METADATA, Player.COMMAND_RELEASE)
			.build();

		private String title = "";
		private String artist = "";
		private String album = "";
		private byte[] artworkData = null;
		private Uri artworkUri = null;
		private long durationMs = C.TIME_UNSET;
		private long positionMs = 0;
		private float speed = 1.0f;
		private int playbackState = Player.STATE_IDLE;
		private boolean playWhenReady = false;
		private boolean hasTrack = false;
		private long trackId = 0;
		private Object mediaItemUid = new Object();

		HaxeMediaPlayer()
		{
			super(Looper.getMainLooper());
		}

		private long artworkGeneration = 0;

		void updateMetadata(String title, String artist, String album, long durationMs, Uri artworkUri,
			long artworkGeneration)
		{
			verifyApplicationThread();

			this.title = title;
			this.artist = artist;
			this.album = album;
			this.durationMs = durationMs > 0 ? durationMs : C.TIME_UNSET;
			this.artworkData = null;
			this.artworkUri = artworkUri;
			this.artworkGeneration = artworkGeneration;
			this.hasTrack = true;
			this.trackId++;
			this.mediaItemUid = new Object();

			if (playbackState == Player.STATE_IDLE)
				playbackState = Player.STATE_READY;

			invalidateState();
		}

		/** Applies a validated worker result only to the metadata that requested it. */
		void updateArtwork(long artworkGeneration, byte[] artworkData)
		{
			verifyApplicationThread();
			if (artworkData == null || artworkGeneration != this.artworkGeneration)
				return;

			this.artworkData = artworkData;
			this.artworkUri = null;
			invalidateState();
		}

		void updatePlaybackState(int engineState, long positionMs, float speed)
		{
			verifyApplicationThread();

			this.positionMs = Math.max(0, positionMs);
			if (durationMs != C.TIME_UNSET)
				this.positionMs = Math.min(this.positionMs, durationMs);
			this.speed = isUsableSpeed(speed) ? speed : 1.0f;

			switch (engineState)
			{
				case 1:
					playbackState = Player.STATE_READY;
					playWhenReady = true;
					break;
				case 2:
					playbackState = Player.STATE_READY;
					playWhenReady = false;
					break;
				case 3:
					playbackState = Player.STATE_BUFFERING;
					playWhenReady = true;
					break;
				default:
					playbackState = Player.STATE_IDLE;
					playWhenReady = false;
					break;
			}

			invalidateState();
		}

		/** True only for the user-engaged state which may start a Media3 service. */
		boolean isReadyPlayback()
		{
			return hasTrack && playWhenReady && playbackState == Player.STATE_READY;
		}

		@Override protected State getState()
		{
			State.Builder state = new State.Builder()
				.setAvailableCommands(AVAILABLE_COMMANDS)
				.setPlaybackParameters(new PlaybackParameters(speed))
				.setPlayWhenReady(playWhenReady, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
				.setPlaybackState(hasTrack ? playbackState : Player.STATE_IDLE)
				.setSeekBackIncrementMs(10_000)
				.setSeekForwardIncrementMs(10_000);

			if (hasTrack)
			{
				MediaMetadata metadataBuilderResult = buildMetadata();
				MediaItem mediaItem = new MediaItem.Builder()
					.setMediaId("phoenix-song-" + trackId)
					.setMediaMetadata(metadataBuilderResult)
					.build();

				MediaItemData item = new MediaItemData.Builder(mediaItemUid)
					.setMediaItem(mediaItem)
					.setMediaMetadata(metadataBuilderResult)
					.setDurationUs(durationMs == C.TIME_UNSET ? C.TIME_UNSET : durationMs * 1000L)
					.setIsSeekable(durationMs != C.TIME_UNSET)
					.build();

				state.setPlaylist(Collections.singletonList(item))
					.setCurrentMediaItemIndex(0)
					.setContentPositionMs(positionMs);
			}

			return state.build();
		}

		private MediaMetadata buildMetadata()
		{
			MediaMetadata.Builder metadata = new MediaMetadata.Builder()
				.setTitle(title)
				.setArtist(artist)
				.setAlbumTitle(album);

			if (artworkData != null)
				metadata.setArtworkData(artworkData, MediaMetadata.PICTURE_TYPE_FRONT_COVER);
			else if (artworkUri != null)
				metadata.setArtworkUri(artworkUri);

			return metadata.build();
		}

		@Override protected ListenableFuture<?> handleSetPlayWhenReady(boolean requestedPlayWhenReady)
		{
			PhoenixCore.dispatch("media", PhoenixMediaAction.playWhenReady(requestedPlayWhenReady));
			return Futures.immediateVoidFuture();
		}

		@Override protected ListenableFuture<?> handleStop()
		{
			PhoenixCore.dispatch("media", PhoenixMediaAction.stop());
			return Futures.immediateVoidFuture();
		}

		@Override protected ListenableFuture<?> handleSeek(int mediaItemIndex, long requestedPositionMs,
			@Player.Command int seekCommand)
		{
			PhoenixCore.dispatch("media", PhoenixMediaAction.seek(requestedPositionMs, durationMs,
				durationMs != C.TIME_UNSET, requestedPositionMs == C.TIME_UNSET));
			return Futures.immediateVoidFuture();
		}

		@Override protected ListenableFuture<?> handleRelease()
		{
			return Futures.immediateVoidFuture();
		}

		private static boolean isUsableSpeed(float speed)
		{
			return speed > 0.0f && !Float.isNaN(speed) && !Float.isInfinite(speed);
		}
	}

	/** Handles media-button next/previous keys, which have no song queue in FNF. */
	@UnstableApi
	private static final class PhoenixMediaSessionCallback implements MediaSession.Callback
	{
		@Override public boolean onMediaButtonEvent(MediaSession mediaSession,
			MediaSession.ControllerInfo controller, Intent intent)
		{
			if (intent == null)
				return false;

			try
			{
				KeyEvent event = intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
				if (event == null || event.getAction() != KeyEvent.ACTION_DOWN)
					return false;

				switch (event.getKeyCode())
				{
					case KeyEvent.KEYCODE_MEDIA_NEXT:
						PhoenixCore.dispatch("media", PhoenixMediaAction.next());
						return true;
					case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
						PhoenixCore.dispatch("media", PhoenixMediaAction.previous());
						return true;
					default:
						return false;
				}
			}
			catch (Exception e)
			{
				Log.e(LOG_TAG, "onMediaButtonEvent failed: " + e);
				return false;
			}
		}
	}

	private static ThreadPoolExecutor createArtworkExecutor()
	{
		ThreadPoolExecutor executor = new ThreadPoolExecutor(1, 1, 15, TimeUnit.SECONDS,
			new ArrayBlockingQueue<Runnable>(1), new ThreadFactory()
			{
				@Override public Thread newThread(Runnable runnable)
				{
					Thread thread = new Thread(runnable, "PhoenixMediaArtwork");
					thread.setPriority(Thread.NORM_PRIORITY - 1);
					return thread;
				}
			}, new ThreadPoolExecutor.DiscardOldestPolicy());
		executor.allowCoreThreadTimeOut(true);
		return executor;
	}

	private static void scheduleArtworkLoad(final Context context, final String artworkPath,
		final long artworkGeneration)
	{
		if (!shouldLoadArtworkData(artworkPath))
			return;

		try
		{
			ARTWORK_EXECUTOR.execute(new Runnable()
			{
				@Override public void run()
				{
					final byte[] artworkData = loadArtworkData(context, artworkPath);
					if (artworkData == null)
						return;

					runOnMainThread(new Runnable()
					{
						@Override public void run()
						{
							if (!BRIDGE_STATE.acceptsArtwork(artworkGeneration))
								return;

							HaxeMediaPlayer mediaPlayer = player;
							if (mediaPlayer != null)
								mediaPlayer.updateArtwork(artworkGeneration, artworkData);
						}
					});
				}
			});
		}
		catch (RuntimeException e)
		{
			// Metadata is still useful without artwork. A bounded executor should
			// not reject normally, but never let an artwork scheduling issue affect
			// playback or MediaSession publication.
			Log.w(LOG_TAG, "scheduleArtworkLoad failed: " + e);
		}
	}

	private static boolean shouldLoadArtworkData(String artworkPath)
	{
		if (artworkPath == null || artworkPath.trim().length() == 0)
			return false;

		try
		{
			String scheme = Uri.parse(artworkPath.trim()).getScheme();
			return scheme == null || "file".equalsIgnoreCase(scheme)
				|| "content".equalsIgnoreCase(scheme) || "android.resource".equalsIgnoreCase(scheme);
		}
		catch (Exception ignored)
		{
			return false;
		}
	}

	/** Allows only public network artwork URIs to be sent directly to controllers. */
	private static Uri getRemoteArtworkUri(String artworkPath)
	{
		if (artworkPath == null || artworkPath.trim().length() == 0)
			return null;

		try
		{
			Uri uri = Uri.parse(artworkPath.trim());
			String scheme = uri.getScheme();
			if ("https".equalsIgnoreCase(scheme) || "http".equalsIgnoreCase(scheme))
				return uri;
		}
		catch (Exception ignored) {}
		return null;
	}

	/**
	 * Runs only on ARTWORK_EXECUTOR. Reads a bounded byte stream and performs a
	 * bounds-only decode so corrupt, oversized, or decompression-bomb artwork is
	 * discarded before it reaches Media3 metadata.
	 */
	private static byte[] loadArtworkData(Context context, String artworkPath)
	{
		if (context == null || artworkPath == null || artworkPath.trim().length() == 0)
			return null;

		InputStream input = null;
		try
		{
			input = openArtworkStream(context, artworkPath.trim());
			if (input == null)
				return null;

			ByteArrayOutputStream output = new ByteArrayOutputStream();
			byte[] buffer = new byte[16 * 1024];
			int total = 0;
			int read;
			while ((read = input.read(buffer)) != -1)
			{
				total += read;
				if (total > MAX_ARTWORK_BYTES)
					return null;
				output.write(buffer, 0, read);
			}

			if (total == 0)
				return null;
			byte[] artworkData = output.toByteArray();
			return isSafeArtworkData(artworkData) ? artworkData : null;
		}
		catch (Exception ignored)
		{
			return null;
		}
		finally
		{
			if (input != null)
			{
				try
				{
					input.close();
				}
				catch (Exception ignored) {}
			}
		}
	}

	private static boolean isSafeArtworkData(byte[] artworkData)
	{
		try
		{
			BitmapFactory.Options options = new BitmapFactory.Options();
			options.inJustDecodeBounds = true;
			BitmapFactory.decodeByteArray(artworkData, 0, artworkData.length, options);
			if (options.outWidth <= 0 || options.outHeight <= 0)
				return false;

			long pixels = (long) options.outWidth * (long) options.outHeight;
			return pixels <= MAX_ARTWORK_PIXELS;
		}
		catch (Exception ignored)
		{
			return false;
		}
	}

	private static InputStream openArtworkStream(Context context, String artworkPath) throws Exception
	{
		Uri uri = Uri.parse(artworkPath);
		String scheme = uri.getScheme();
		if ("content".equalsIgnoreCase(scheme) || "android.resource".equalsIgnoreCase(scheme))
			return context.getContentResolver().openInputStream(uri);
		if ("file".equalsIgnoreCase(scheme))
			return new FileInputStream(new File(uri.getPath()));

		File file = new File(artworkPath);
		if (file.isFile())
			return new FileInputStream(file);

		// Lime places non-embedded assets in Android's AssetManager. Depending
		// on the asset library prefix, the path can include "assets/" or not.
		try
		{
			return context.getAssets().open(artworkPath);
		}
		catch (Exception ignored)
		{
			if (artworkPath.startsWith("assets/"))
				return context.getAssets().open(artworkPath.substring("assets/".length()));
			throw ignored;
		}
	}

	// ------------------------------------------------------------------
	// Audio focus
	// ------------------------------------------------------------------

	/**
	 * Requests audio focus with a listener that forwards focus changes to
	 * Haxe. Returns 1 when focus is granted immediately, otherwise 0.
	 */
	public static int requestAudioFocus()
	{
		Context context = getApplicationContext();
		if (context == null)
			return 0;

		try
		{
			audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
			if (audioManager == null)
				return 0;

			if (focusListener == null)
			{
				focusListener = new AudioManager.OnAudioFocusChangeListener()
				{
					@Override public void onAudioFocusChange(int focusChange)
					{
						switch (focusChange)
						{
							case AudioManager.AUDIOFOCUS_GAIN:
								PhoenixCore.dispatch("focus", "gain");
								break;
							case AudioManager.AUDIOFOCUS_LOSS:
								PhoenixCore.dispatch("focus", "loss");
								break;
							case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
								PhoenixCore.dispatch("focus", "lossTransient");
								break;
							case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK:
								PhoenixCore.dispatch("focus", "duck");
								break;
							default:
								break;
						}
					}
				};
			}

			int result;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
			{
				AudioAttributes attributes = new AudioAttributes.Builder()
					.setUsage(AudioAttributes.USAGE_GAME)
					.setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
					.build();

				audioFocusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
					.setAudioAttributes(attributes)
					.setOnAudioFocusChangeListener(focusListener)
					.setAcceptsDelayedFocusGain(true)
					.setWillPauseWhenDucked(false)
					.build();
				result = audioManager.requestAudioFocus(audioFocusRequest);
			}
			else
			{
				result = audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC,
					AudioManager.AUDIOFOCUS_GAIN);
			}

			return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED ? 1 : 0;
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "requestAudioFocus failed: " + e);
			return 0;
		}
	}

	public static void abandonAudioFocus()
	{
		if (audioManager == null)
			return;

		try
		{
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null)
				audioManager.abandonAudioFocusRequest(audioFocusRequest);
			else if (focusListener != null)
				audioManager.abandonAudioFocus(focusListener);
		}
		catch (Exception ignored) {}
	}

	// ------------------------------------------------------------------
	// Audio output information (latency calibration helpers)
	// ------------------------------------------------------------------

	/**
	 * Returns native audio output information as JSON:
	 * { sampleRate, framesPerBuffer, minBufferSizeBytes, estimatedLatencyMs }
	 */
	public static String getAudioInfo()
	{
		try
		{
			JSONObject info = new JSONObject();
			int sampleRate = 44100;
			int framesPerBuffer = 512;
			Context context = getApplicationContext();

			if (context != null)
			{
				audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
				if (audioManager != null)
				{
					String rateProperty = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE);
					String framesProperty = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER);
					if (rateProperty != null && rateProperty.length() > 0)
						sampleRate = Integer.parseInt(rateProperty);
					if (framesProperty != null && framesProperty.length() > 0)
						framesPerBuffer = Integer.parseInt(framesProperty);
				}
			}

			int minBufferBytes = 0;
			try
			{
				minBufferBytes = AudioTrack.getMinBufferSize(sampleRate,
					android.media.AudioFormat.CHANNEL_OUT_STEREO,
					android.media.AudioFormat.ENCODING_PCM_16BIT);
			}
			catch (Exception ignored) {}

			info.put("sampleRate", sampleRate);
			info.put("framesPerBuffer", framesPerBuffer);
			info.put("minBufferSizeBytes", minBufferBytes);
			info.put("estimatedLatencyMs", (framesPerBuffer * 1000.0) / sampleRate);
			return info.toString();
		}
		catch (Exception e)
		{
			return "{}";
		}
	}

	@Override public void onDestroy()
	{
		releaseSession();
		abandonAudioFocus();
	}
}
