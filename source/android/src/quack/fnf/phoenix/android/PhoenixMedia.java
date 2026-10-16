package quack.fnf.phoenix.android;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.haxe.extension.Extension;
import org.json.JSONObject;

/**
 * Android media integration for Phoenix Engine: framework MediaSession
 * (works with system media controls, lock screen, Bluetooth and Android
 * Auto), MediaStyle notifications and audio focus handling.
 *
 * Deliberately built on framework APIs only (android.media.session) so the
 * engine needs no extra Gradle dependencies; Media3 could replace this
 * later without touching the Haxe API surface.
 *
 * Playback events from the system arrive in Haxe as
 * ("media", "play" | "pause" | "stop" | "next" | "previous" | "seek:<ms>").
 * Audio focus changes arrive as
 * ("focus", "gain" | "loss" | "lossTransient" | "duck").
 *
 * Part of the Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.
 */
public class PhoenixMedia extends Extension
{
	public static final String LOG_TAG = "PhoenixMedia";

	public static final String MEDIA_CHANNEL_ID = "phoenix_media";
	public static final String GENERAL_CHANNEL_ID = "phoenix_general";
	public static final int MEDIA_NOTIFICATION_ID = 9001;

	public static final String ACTION_PLAY = "quack.fnf.phoenix.android.media.PLAY";
	public static final String ACTION_PAUSE = "quack.fnf.phoenix.android.media.PAUSE";
	public static final String ACTION_STOP = "quack.fnf.phoenix.android.media.STOP";

	private static MediaSession session = null;
	private static AudioManager audioManager = null;
	private static AudioFocusRequest audioFocusRequest = null;
	private static AudioManager.OnAudioFocusChangeListener focusListener = null;
	private static boolean foregroundServiceRunning = false;

	// ------------------------------------------------------------------
	// Media session
	// ------------------------------------------------------------------

	/** Creates (or recreates) the media session. Safe to call repeatedly. */
	public static void createSession()
	{
		if (mainContext == null)
			return;

		try
		{
			if (session != null)
				return;

			session = new MediaSession(mainContext, "PhoenixEngineMedia");
			session.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS | MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS);

			MediaSession.Callback mediaCallback = new MediaSession.Callback()
			{
				@Override public void onPlay()
				{
					PhoenixCore.dispatch("media", "play");
				}

				@Override public void onPause()
				{
					PhoenixCore.dispatch("media", "pause");
				}

				@Override public void onStop()
				{
					PhoenixCore.dispatch("media", "stop");
				}

				@Override public void onSeekTo(long positionMs)
				{
					PhoenixCore.dispatch("media", "seek:" + positionMs);
				}

				@Override public void onSkipToNext()
				{
					PhoenixCore.dispatch("media", "next");
				}

				@Override public void onSkipToPrevious()
				{
					PhoenixCore.dispatch("media", "previous");
				}
			};

			// Deliver callback events on the main thread regardless of which
			// thread created the session (the no-handler overload would use
			// the calling thread's Looper, which may not exist).
			session.setCallback(mediaCallback, new Handler(Looper.getMainLooper()));
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "createSession failed: " + e);
			session = null;
		}
	}

	/**
	 * Publishes the currently playing song metadata to the system media UI.
	 * artworkPath may be null/empty.
	 */
	public static void setMetadata(String title, String artist, String album, long durationMs, String artworkPath)
	{
		createSession();
		if (session == null)
			return;

		try
		{
			MediaMetadata.Builder builder = new MediaMetadata.Builder()
				.putString(MediaMetadata.METADATA_KEY_TITLE, title == null ? "" : title)
				.putString(MediaMetadata.METADATA_KEY_ARTIST, artist == null ? "" : artist)
				.putString(MediaMetadata.METADATA_KEY_ALBUM, album == null ? "" : album);

			if (durationMs > 0)
				builder.putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs);

			if (artworkPath != null && artworkPath.length() > 0)
			{
				Uri artworkUri = Uri.parse(artworkPath);
				builder.putString(MediaMetadata.METADATA_KEY_ART_URI, artworkUri.toString());
				builder.putString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI, artworkUri.toString());
			}

			session.setMetadata(builder.build());
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "setMetadata failed: " + e);
		}
	}

	/**
	 * @param state 0 = none/stopped, 1 = playing, 2 = paused, 3 = buffering
	 */
	public static void setPlaybackState(int state, long positionMs, float speed)
	{
		createSession();
		if (session == null)
			return;

		try
		{
			int playbackState;
			switch (state)
			{
				case 1:
					playbackState = PlaybackState.STATE_PLAYING;
					break;
				case 2:
					playbackState = PlaybackState.STATE_PAUSED;
					break;
				case 3:
					playbackState = PlaybackState.STATE_BUFFERING;
					break;
				default:
					playbackState = PlaybackState.STATE_STOPPED;
					break;
			}

			long actions = PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE | PlaybackState.ACTION_PLAY_PAUSE
				| PlaybackState.ACTION_STOP | PlaybackState.ACTION_SEEK_TO
				| PlaybackState.ACTION_SKIP_TO_NEXT | PlaybackState.ACTION_SKIP_TO_PREVIOUS;

			PlaybackState.Builder builder = new PlaybackState.Builder()
				.setState(playbackState, positionMs, speed)
				.setActions(actions);

			session.setPlaybackState(builder.build());
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "setPlaybackState failed: " + e);
		}
	}

	/** Activates/deactivates the session. Activation also claims media button routing. */
	public static void setActive(boolean active)
	{
		createSession();
		if (session == null)
			return;

		try
		{
			session.setActive(active);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "setActive failed: " + e);
		}
	}

	public static boolean isActive()
	{
		return session != null && session.isActive();
	}

	/** Releases the media session entirely (call when playback is fully over). */
	public static void releaseSession()
	{
		stopForegroundService();
		cancelNotification(MEDIA_NOTIFICATION_ID);

		if (session != null)
		{
			try
			{
				session.setActive(false);
				session.release();
			}
			catch (Exception ignored) {}
			session = null;
		}
	}

	// ------------------------------------------------------------------
	// MediaStyle notification
	// ------------------------------------------------------------------

	public static void ensureChannels()
	{
		if (mainContext == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
			return;

		try
		{
			NotificationManager manager = (NotificationManager) mainContext.getSystemService(Context.NOTIFICATION_SERVICE);
			if (manager == null)
				return;

			if (manager.getNotificationChannel(MEDIA_CHANNEL_ID) == null)
			{
				NotificationChannel channel = new NotificationChannel(MEDIA_CHANNEL_ID, "Media playback",
					NotificationManager.IMPORTANCE_LOW);
				channel.setDescription("Playback controls for Phoenix Engine");
				manager.createNotificationChannel(channel);
			}

			if (manager.getNotificationChannel(GENERAL_CHANNEL_ID) == null)
			{
				NotificationChannel channel = new NotificationChannel(GENERAL_CHANNEL_ID, "General",
					NotificationManager.IMPORTANCE_DEFAULT);
				channel.setDescription("Phoenix Engine notifications");
				manager.createNotificationChannel(channel);
			}
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "ensureChannels failed: " + e);
		}
	}

	private static PendingIntent serviceAction(String action)
	{
		Intent intent = new Intent(mainContext, PhoenixMediaService.class);
		intent.setAction(action);
		int flags = PendingIntent.FLAG_UPDATE_CURRENT;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
			flags |= PendingIntent.FLAG_IMMUTABLE;
		return PendingIntent.getService(mainContext, action.hashCode(), intent, flags);
	}

	/**
	 * Builds the MediaStyle notification bound to the current session.
	 * Exposed (non-private) so PhoenixMediaService can reuse it for
	 * startForeground.
	 */
	public static Notification buildMediaNotification(String title, String artist, boolean playing)
	{
		ensureChannels();
		if (mainContext == null)
			return null;

		try
		{
			Intent launchIntent = mainContext.getPackageManager().getLaunchIntentForPackage(mainContext.getPackageName());
			PendingIntent contentIntent = null;
			if (launchIntent != null)
			{
				int flags = PendingIntent.FLAG_UPDATE_CURRENT;
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
					flags |= PendingIntent.FLAG_IMMUTABLE;
				contentIntent = PendingIntent.getActivity(mainContext, 0, launchIntent, flags);
			}

			Notification.Builder builder;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				builder = new Notification.Builder(mainContext, MEDIA_CHANNEL_ID);
			else
				builder = new Notification.Builder(mainContext);

			builder.setContentTitle(title == null ? "" : title)
				.setContentText(artist == null ? "" : artist)
				.setSmallIcon(android.R.drawable.ic_media_play)
				.setOngoing(playing)
				.setShowWhen(false)
				.setVisibility(Notification.VISIBILITY_PUBLIC);

			if (contentIntent != null)
				builder.setContentIntent(contentIntent);

			builder.addAction(new Notification.Action.Builder(
					null, playing ? "Pause" : "Play",
					serviceAction(playing ? ACTION_PAUSE : ACTION_PLAY))
				.build());
			builder.addAction(new Notification.Action.Builder(
					null, "Stop", serviceAction(ACTION_STOP))
				.build());

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
			{
				Notification.MediaStyle style = new Notification.MediaStyle();
				if (session != null)
					style.setMediaSession(session.getSessionToken());
				style.setShowActionsInCompactView(0);
				builder.setStyle(style);
			}

			return builder.build();
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "buildMediaNotification failed: " + e);
			return null;
		}
	}

	/** Shows/updates the media notification (foreground use handled separately). */
	public static void notifyMedia(String title, String artist, boolean playing)
	{
		notify(MEDIA_NOTIFICATION_ID, buildMediaNotification(title, artist, playing));
	}

	/** Generic simple notification (title/text), posted on the general channel. */
	public static void notifySimple(int id, String title, String text)
	{
		if (mainContext == null)
			return;

		try
		{
			ensureChannels();

			Notification.Builder builder;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				builder = new Notification.Builder(mainContext, GENERAL_CHANNEL_ID);
			else
				builder = new Notification.Builder(mainContext);

			builder.setContentTitle(title == null ? "" : title)
				.setContentText(text == null ? "" : text)
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
		if (mainContext == null || notification == null)
			return;

		try
		{
			NotificationManager manager = (NotificationManager) mainContext.getSystemService(Context.NOTIFICATION_SERVICE);
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
		if (mainContext == null)
			return;

		try
		{
			NotificationManager manager = (NotificationManager) mainContext.getSystemService(Context.NOTIFICATION_SERVICE);
			if (manager != null)
				manager.cancel(id);
		}
		catch (Exception ignored) {}
	}

	// ------------------------------------------------------------------
	// Foreground service (keeps playback alive while backgrounded)
	// ------------------------------------------------------------------

	public static void startForegroundService(String title, String artist, boolean playing)
	{
		if (mainContext == null)
			return;

		try
		{
			Intent intent = new Intent(mainContext, PhoenixMediaService.class);
			intent.setAction(ACTION_PLAY);
			intent.putExtra("title", title == null ? "" : title);
			intent.putExtra("artist", artist == null ? "" : artist);
			intent.putExtra("playing", playing);

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				mainContext.startForegroundService(intent);
			else
				mainContext.startService(intent);

			foregroundServiceRunning = true;
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "startForegroundService failed: " + e);
		}
	}

	public static void stopForegroundService()
	{
		if (mainContext == null || !foregroundServiceRunning)
			return;

		try
		{
			Intent intent = new Intent(mainContext, PhoenixMediaService.class);
			mainContext.stopService(intent);
		}
		catch (Exception ignored) {}
		foregroundServiceRunning = false;
	}

	public static boolean isForegroundServiceRunning()
	{
		return foregroundServiceRunning;
	}

	static void setForegroundServiceRunningInternal(boolean running)
	{
		foregroundServiceRunning = running;
	}

	// ------------------------------------------------------------------
	// Audio focus
	// ------------------------------------------------------------------

	/**
	 * Requests audio focus with a listener that forwards focus changes to
	 * Haxe. Returns the AudioManager request result (1 = granted).
	 */
	public static int requestAudioFocus()
	{
		if (mainContext == null)
			return 0;

		try
		{
			audioManager = (AudioManager) mainContext.getSystemService(Context.AUDIO_SERVICE);
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
					.setWillPauseWhenDucked(false) // we duck ourselves via the "duck" event
					.build();

				result = audioManager.requestAudioFocus(audioFocusRequest);
			}
			else
			{
				result = audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
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

			if (mainContext != null)
			{
				audioManager = (AudioManager) mainContext.getSystemService(Context.AUDIO_SERVICE);
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
			// Rough estimate of the minimum achievable output latency.
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
