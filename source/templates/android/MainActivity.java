package ::APP_PACKAGE::;

import android.content.Intent;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import quack.fnf.phoenix.android.PhoenixDisplay;
import quack.fnf.phoenix.android.PhoenixCutoutLayout;

import quack.fnf.phoenix.android.PhoenixCore;
import quack.fnf.phoenix.android.PhoenixInput;

/**
 * Phoenix Engine Android activity.
 *
 * Extends Lime's GameActivity with the small bits of behavior that cannot
 * live in Extension subclasses: fresh intents (deep links / shares) and
 * hardware key interception (volume buttons as game input).
 */
public class MainActivity extends org.haxe.lime.GameActivity implements PhoenixDisplay.CutoutHost
{
	private PhoenixCutoutLayout cutoutLayout;

	@Override public void setContentView(View view)
	{
		if (android.os.Build.VERSION.SDK_INT < 35 || getApplicationInfo().targetSdkVersion < 35)
		{
			cutoutLayout = null;
			super.setContentView(view);
			return;
		}
		// SDLActivity.onCreate calls this with its RelativeLayout. Keep SDL's
		// own mLayout/mSurface and input listeners intact, inside an owned host.
		cutoutLayout = new PhoenixCutoutLayout(this);
		cutoutLayout.addView(view, new ViewGroup.LayoutParams(
			ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
		super.setContentView(cutoutLayout);
		// Also handle content replacement while the Activity is already running.
		PhoenixDisplay.applyCutoutToActivity(this);
	}

	@Override public void setRespectCutoutInsets(boolean respect)
	{
		if (cutoutLayout != null)
			cutoutLayout.setRespectCutout(respect);
		else if (respect)
			android.util.Log.w("PhoenixDisplay", "SDL content unavailable; retry on resume/focus");
	}

	@Override protected void onResume()
	{
		super.onResume();
		PhoenixDisplay.applyCutoutToActivity(this);
	}

	@Override public void onWindowFocusChanged(boolean hasFocus)
	{
		super.onWindowFocusChanged(hasFocus);
		if (hasFocus)
			PhoenixDisplay.applyCutoutToActivity(this);
	}

	@Override protected void onDestroy()
	{
		super.onDestroy();
		cutoutLayout = null;
	}

	@Override protected void onCreate(Bundle state)
	{
		super.onCreate(state);
		PhoenixDisplay.applyCutoutToActivity(this);

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
