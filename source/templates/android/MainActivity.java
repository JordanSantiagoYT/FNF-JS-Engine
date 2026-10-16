package ::APP_PACKAGE::;

import android.content.Intent;
import android.os.Bundle;
import android.view.KeyEvent;

import quack.fnf.phoenix.android.PhoenixCore;
import quack.fnf.phoenix.android.PhoenixInput;

/**
 * Phoenix Engine Android activity.
 *
 * Extends Lime's GameActivity with the small bits of behavior that cannot
 * live in Extension subclasses: fresh intents (deep links / shares) and
 * hardware key interception (volume buttons as game input).
 */
public class MainActivity extends org.haxe.lime.GameActivity
{
	@Override protected void onCreate(Bundle state)
	{
		super.onCreate(state);

		// Surface the launch intent too, so a phoenix:// deep link that
		// started the app cold reaches the Haxe side.
		PhoenixCore.handleNewIntent(getIntent());
	}

	@Override protected void onNewIntent(Intent intent)
	{
		setIntent(intent);
		PhoenixCore.handleNewIntent(intent);
		super.onNewIntent(intent);
	}

	@Override public boolean onKeyDown(int keyCode, KeyEvent event)
	{
		if (PhoenixInput.interceptKey(keyCode, true))
			return true;
		return super.onKeyDown(keyCode, event);
	}

	@Override public boolean onKeyUp(int keyCode, KeyEvent event)
	{
		if (PhoenixInput.interceptKey(keyCode, false))
			return true;
		return super.onKeyUp(keyCode, event);
	}
}
