package quack.fnf.phoenix.android;

import android.app.Notification;
import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

/**
 * Foreground service backing the MediaStyle notification so playback state
 * can legitimately survive the Activity moving to the background.
 *
 * Playback itself stays in the Haxe/Flixel layer; this service only keeps
 * the process (and the notification) alive and forwards its action buttons
 * to Haxe through PhoenixCore's event channel.
 *
 * Part of the Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.
 */
public class PhoenixMediaService extends Service
{
	private static final int SERVICE_NOTIFICATION_ID = PhoenixMedia.MEDIA_NOTIFICATION_ID;

	@Override public int onStartCommand(Intent intent, int flags, int startId)
	{
		String action = intent != null ? intent.getAction() : null;

		if (PhoenixMedia.ACTION_STOP.equals(action))
		{
			PhoenixCore.dispatch("media", "stop");
			stopForeground(true);
			stopSelf();
			PhoenixMedia.setForegroundServiceRunningInternal(false);
			return START_NOT_STICKY;
		}

		if (PhoenixMedia.ACTION_PLAY.equals(action) || PhoenixMedia.ACTION_PAUSE.equals(action))
		{
			PhoenixCore.dispatch("media", PhoenixMedia.ACTION_PLAY.equals(action) ? "play" : "pause");

			// Notification-button intents carry no extras: only forward the
			// event and let the engine refresh the notification itself.
			// Rebuilding it here would wipe the metadata. Only intents
			// started by the engine (which attach title/artist) promote or
			// update the notification below.
			if (intent == null || !intent.hasExtra("title"))
				return START_NOT_STICKY;
		}

		String title = intent != null ? intent.getStringExtra("title") : null;
		String artist = intent != null ? intent.getStringExtra("artist") : null;
		boolean playing = intent == null || intent.getBooleanExtra("playing", true);

		Notification notification = PhoenixMedia.buildMediaNotification(
			title != null ? title : "", artist != null ? artist : "", playing);

		if (notification != null)
		{
			try
			{
				startForeground(SERVICE_NOTIFICATION_ID, notification);
				// Foreground promotion really happened: make sure cleanup can
				// stop the foreground service later.
				PhoenixMedia.setForegroundServiceRunningInternal(true);
				return START_STICKY;
			}
			catch (Exception e)
			{
				// Foreground service constraints (e.g. started from the
				// background) can reject startForeground; fall back to a
				// regular notification rather than crashing.
				PhoenixMedia.notify(SERVICE_NOTIFICATION_ID, notification);
			}
		}

		return START_NOT_STICKY;
	}

	@Override public void onDestroy()
	{
		PhoenixMedia.setForegroundServiceRunningInternal(false);
		super.onDestroy();
	}

	@Override public IBinder onBind(Intent intent)
	{
		return null;
	}
}
