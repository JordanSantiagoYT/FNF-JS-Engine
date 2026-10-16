package quack.fnf.phoenix.android;

import android.app.Activity;
import android.content.Context;
import android.graphics.Point;
import android.hardware.display.DisplayManager;
import android.os.Build;
import android.util.DisplayMetrics;
import android.view.Display;
import android.view.DisplayCutout;
import android.view.Surface;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;

import org.haxe.extension.Extension;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Native display information plus immersive/edge-to-edge handling for the
 * Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.
 */
public class PhoenixDisplay extends Extension
{
	private static DisplayManager.DisplayListener displayListener = null;

	/**
	 * Returns display information as a JSON object:
	 * { width, height, densityDpi, xdpi, ydpi, rotation, refreshRate,
	 *   supportedRefreshRates: [..], cutout: [left, top, right, bottom] }
	 */
	public static String getDisplayInfo()
	{
		try
		{
			JSONObject info = new JSONObject();
			Context context = mainContext;
			Activity activity = mainActivity;
			if (context == null)
				return "{}";

			DisplayMetrics metrics = context.getResources().getDisplayMetrics();
			Display display = null;

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && activity != null)
				display = activity.getDisplay();
			if (display == null)
			{
				WindowManager windowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
				if (windowManager != null)
					display = windowManager.getDefaultDisplay();
			}

			int width = metrics.widthPixels;
			int height = metrics.heightPixels;
			if (display != null)
			{
				Point size = new Point();
				display.getRealSize(size);
				width = size.x;
				height = size.y;
			}

			info.put("width", width);
			info.put("height", height);
			info.put("densityDpi", metrics.densityDpi);
			info.put("xdpi", metrics.xdpi);
			info.put("ydpi", metrics.ydpi);
			info.put("rotation", display == null ? 0 : display.getRotation());
			info.put("refreshRate", display == null ? 60.0 : display.getRefreshRate());

			JSONArray rates = new JSONArray();
			if (display != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
			{
				for (Display.Mode mode : display.getSupportedModes())
				{
					float rate = mode.getRefreshRate();
					boolean duplicate = false;
					for (int i = 0; i < rates.length(); i++)
					{
						if (Math.abs(rates.getDouble(i) - rate) < 0.01)
						{
							duplicate = true;
							break;
						}
					}
					if (!duplicate)
						rates.put(rate);
				}
			}
			if (rates.length() == 0)
				rates.put(info.optDouble("refreshRate", 60.0));
			info.put("supportedRefreshRates", rates);

			info.put("cutout", getCutoutInsetsArray());

			return info.toString();
		}
		catch (Exception e)
		{
			return "{}";
		}
	}

	/** @return cutout safe insets as [left, top, right, bottom]. */
	private static JSONArray getCutoutInsetsArray() throws Exception
	{
		JSONArray cutout = new JSONArray();
		int left = 0, top = 0, right = 0, bottom = 0;

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && mainActivity != null)
		{
			try
			{
				WindowInsets insets = mainActivity.getWindow().getDecorView().getRootWindowInsets();
				if (insets != null)
				{
					DisplayCutout displayCutout = insets.getDisplayCutout();
					if (displayCutout != null)
					{
						left = displayCutout.getSafeInsetLeft();
						top = displayCutout.getSafeInsetTop();
						right = displayCutout.getSafeInsetRight();
						bottom = displayCutout.getSafeInsetBottom();
					}
				}
			}
			catch (Exception ignored) {}
		}

		cutout.put(left);
		cutout.put(top);
		cutout.put(right);
		cutout.put(bottom);
		return cutout;
	}

	/** @return cutout insets as a CSV string "left,top,right,bottom". */
	public static String getCutoutInsets()
	{
		try
		{
			JSONArray array = getCutoutInsetsArray();
			return array.get(0) + "," + array.get(1) + "," + array.get(2) + "," + array.get(3);
		}
		catch (Exception e)
		{
			return "0,0,0,0";
		}
	}

	/**
	 * Applies an immersive mode:
	 *   "full"   - hide status + navigation bars, re-show on swipe (sticky)
	 *   "lean"   - hide bars, any swipe re-shows them
	 *   "off"    - show all system bars
	 */
	public static void setImmersive(final String mode)
	{
		final Activity activity = mainActivity;
		if (activity == null)
			return;

		activity.runOnUiThread(new Runnable()
		{
			@Override public void run()
			{
				try
				{
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
					{
						WindowInsetsController controller = activity.getWindow().getInsetsController();
						if (controller == null)
							return;

						if ("off".equals(mode))
						{
							controller.show(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
						}
						else
						{
							controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
							if ("full".equals(mode))
								controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
							else
								controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_BARS_BY_SWIPE);
						}
					}
					else
					{
						View decorView = activity.getWindow().getDecorView();
						if ("off".equals(mode))
						{
							decorView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
						}
						else
						{
							int flags = View.SYSTEM_UI_FLAG_IMMERSIVE
								| View.SYSTEM_UI_FLAG_LAYOUT_STABLE
								| View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
								| View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
								| View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
								| View.SYSTEM_UI_FLAG_FULLSCREEN;
							if ("full".equals(mode))
								flags |= View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
							decorView.setSystemUiVisibility(flags);
						}
					}
				}
				catch (Exception ignored) {}
			}
		});
	}

	/**
	 * Sets the display cutout behavior: "default", "shortEdges", "always" or
	 * "never" (mirrors android.layoutInDisplayCutoutMode values).
	 */
	public static void setCutoutMode(final String mode)
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P)
			return;

		final Activity activity = mainActivity;
		if (activity == null)
			return;

		activity.runOnUiThread(new Runnable()
		{
			@Override public void run()
			{
				try
				{
					WindowManager.LayoutParams attributes = activity.getWindow().getAttributes();
					if ("always".equals(mode))
						attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
					else if ("never".equals(mode))
						attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;
					else if ("shortEdges".equals(mode))
						attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
					else
						attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT;
					activity.getWindow().setAttributes(attributes);
				}
				catch (Exception ignored) {}
			}
		});
	}

	/**
	 * Requests a preferred refresh rate on API 23+ (best-effort; the system
	 * may ignore it). Pass 0 to clear the preference.
	 */
	public static void setPreferredRefreshRate(float rate)
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M)
			return;

		final Activity activity = mainActivity;
		if (activity == null)
			return;

		final float preferred = rate;
		activity.runOnUiThread(new Runnable()
		{
			@Override public void run()
			{
				try
				{
					WindowManager.LayoutParams attributes = activity.getWindow().getAttributes();
					attributes.preferredDisplayModeId = 0;

					if (preferred > 0 && mainActivity != null)
					{
						Display display = null;
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
							display = mainActivity.getDisplay();
						if (display == null)
						{
							WindowManager windowManager = (WindowManager) mainActivity.getSystemService(Context.WINDOW_SERVICE);
							if (windowManager != null)
								display = windowManager.getDefaultDisplay();
						}
						if (display != null)
						{
							int bestId = 0;
							float bestDelta = Float.MAX_VALUE;
							for (Display.Mode mode : display.getSupportedModes())
							{
								float delta = Math.abs(mode.getRefreshRate() - preferred);
								if (delta < bestDelta)
								{
									bestDelta = delta;
									bestId = mode.getModeId();
								}
							}
							attributes.preferredDisplayModeId = bestId;
						}
					}

					mainActivity.getWindow().setAttributes(attributes);
				}
				catch (Exception ignored) {}
			}
		});
	}

	/** Starts listening for display changes (rotation/refresh); events arrive as "display"/"changed". */
	public static void registerDisplayListener()
	{
		if (mainContext == null)
			return;

		unregisterDisplayListener();
		try
		{
			DisplayManager manager = (DisplayManager) mainContext.getSystemService(Context.DISPLAY_SERVICE);
			if (manager == null)
				return;

			displayListener = new DisplayManager.DisplayListener()
			{
				@Override public void onDisplayAdded(int displayId) {}

				@Override public void onDisplayRemoved(int displayId) {}

				@Override public void onDisplayChanged(int displayId)
				{
					PhoenixCore.dispatch("display", "changed");
				}
			};
			manager.registerDisplayListener(displayListener, null);
		}
		catch (Exception ignored) {}
	}

	public static void unregisterDisplayListener()
	{
		if (mainContext == null || displayListener == null)
			return;

		try
		{
			DisplayManager manager = (DisplayManager) mainContext.getSystemService(Context.DISPLAY_SERVICE);
			if (manager != null)
				manager.unregisterDisplayListener(displayListener);
		}
		catch (Exception ignored) {}
		displayListener = null;
	}

	@Override public void onDestroy()
	{
		unregisterDisplayListener();
	}
}
