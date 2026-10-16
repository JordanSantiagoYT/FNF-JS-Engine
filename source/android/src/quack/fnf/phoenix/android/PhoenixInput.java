package quack.fnf.phoenix.android;

import android.content.Context;
import android.hardware.input.InputManager;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.util.Log;
import android.view.InputDevice;

import org.haxe.extension.Extension;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Native gamepad/controller support, hardware key bridging and haptic
 * feedback for the Phoenix Android platform layer.
 *
 * Controller connection changes arrive in Haxe as
 * ("gamepad", "added:<id>" | "removed:<id>").
 * Hardware key events (opt-in) arrive as ("hwkey", "down:<code>" | "up:<code>").
 *
 * Part of the Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.
 */
public class PhoenixInput extends Extension
{
	public static final String LOG_TAG = "PhoenixInput";

	private static InputManager.InputDeviceListener deviceListener = null;
	private static Vibrator vibrator = null;
	private static boolean interceptVolumeKeys = false;

	// ------------------------------------------------------------------
	// Gamepads / controllers
	// ------------------------------------------------------------------

	/** Starts watching for controller connect/disconnect events. */
	public static void registerGamepadListener()
	{
		if (mainContext == null)
			return;

		unregisterGamepadListener();
		try
		{
			InputManager manager = (InputManager) mainContext.getSystemService(Context.INPUT_SERVICE);
			if (manager == null)
				return;

			deviceListener = new InputManager.InputDeviceListener()
			{
				@Override public void onInputDeviceAdded(int deviceId)
				{
					InputDevice device = InputDevice.getDevice(deviceId);
					if (device != null && isGamepad(device))
						PhoenixCore.dispatch("gamepad", "added:" + deviceId);
				}

				@Override public void onInputDeviceRemoved(int deviceId)
				{
					// The device is already gone; always notify and let Haxe
					// drop it from its own list.
					PhoenixCore.dispatch("gamepad", "removed:" + deviceId);
				}

				@Override public void onInputDeviceChanged(int deviceId)
				{
					InputDevice device = InputDevice.getDevice(deviceId);
					if (device != null && isGamepad(device))
						PhoenixCore.dispatch("gamepad", "changed:" + deviceId);
				}
			};
			manager.registerInputDeviceListener(deviceListener, null);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "registerGamepadListener failed: " + e);
		}
	}

	public static void unregisterGamepadListener()
	{
		if (mainContext == null || deviceListener == null)
			return;

		try
		{
			InputManager manager = (InputManager) mainContext.getSystemService(Context.INPUT_SERVICE);
			if (manager != null)
				manager.unregisterInputDeviceListener(deviceListener);
		}
		catch (Exception ignored) {}
		deviceListener = null;
	}

	private static boolean isGamepad(InputDevice device)
	{
		int sources = device.getSources();
		return (sources & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
			|| (sources & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK;
	}

	/** Classifies a controller from its vendor/product ids and name. */
	private static String identifyController(InputDevice device)
	{
		int vendorId = 0, productId = 0;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT)
		{
			vendorId = device.getVendorId();
			productId = device.getProductId();
		}

		String name = device.getName() == null ? "" : device.getName().toLowerCase();

		if (vendorId == 0x045e || name.contains("xbox"))
			return "xbox";
		if (vendorId == 0x054c || name.contains("dualsense") || name.contains("dualshock") || name.contains("playstation"))
			return "playstation";
		if (vendorId == 0x057e || name.contains("nintendo") || name.contains("pro controller") || name.contains("joy-con"))
			return "nintendo";
		if (vendorId == 0x2dc8 || name.contains("8bitdo"))
			return "8bitdo";
		if (vendorId == 0x28de || name.contains("steam"))
			return "steam";
		if ((device.getSources() & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD)
			return "generic_gamepad";
		return "generic";
	}

	/** Returns a JSON array describing all connected gamepad-like devices. */
	public static String getGamepads()
	{
		try
		{
			JSONArray devices = new JSONArray();
			int[] ids = InputDevice.getDeviceIds();
			for (int id : ids)
			{
				InputDevice device = InputDevice.getDevice(id);
				if (device == null || !isGamepad(device))
					continue;
				devices.put(describeDevice(device));
			}
			return devices.toString();
		}
		catch (Exception e)
		{
			return "[]";
		}
	}

	/** Returns JSON describing a single device, or "{}" when unavailable. */
	public static String getDeviceInfo(int deviceId)
	{
		try
		{
			InputDevice device = InputDevice.getDevice(deviceId);
			if (device == null)
				return "{}";
			return describeDevice(device).toString();
		}
		catch (Exception e)
		{
			return "{}";
		}
	}

	private static JSONObject describeDevice(InputDevice device) throws Exception
	{
		JSONObject json = new JSONObject();
		json.put("id", device.getId());
		json.put("name", device.getName() == null ? "" : device.getName());
		json.put("descriptor", device.getDescriptor() == null ? "" : device.getDescriptor());
		json.put("sources", device.getSources());
		json.put("isVirtual", device.isVirtual());

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT)
		{
			json.put("vendorId", device.getVendorId());
			json.put("productId", device.getProductId());
			json.put("hasVibrator", device.getVibrator().hasVibrator());
		}

		json.put("type", identifyController(device));
		return json;
	}

	/**
	 * Vibrates a specific controller when it supports a vibrator
	 * (dualshock/dualsense etc.). Returns true when a rumble was issued.
	 */
	public static boolean vibrateGamepad(int deviceId, long durationMs)
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT)
			return false;

		try
		{
			InputDevice device = InputDevice.getDevice(deviceId);
			if (device == null)
				return false;

			android.os.Vibrator controllerVibrator = device.getVibrator();
			if (controllerVibrator == null || !controllerVibrator.hasVibrator())
				return false;

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				controllerVibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE));
			else
				controllerVibrator.vibrate(durationMs);
			return true;
		}
		catch (Exception e)
		{
			return false;
		}
	}

	// ------------------------------------------------------------------
	// Hardware keys (volume buttons as game input)
	// ------------------------------------------------------------------

	/**
	 * When enabled, MainActivity intercepts KEYCODE_VOLUME_UP/DOWN and
	 * forwards them to Haxe instead of changing the system volume.
	 */
	public static void setVolumeKeysIntercepted(boolean intercept)
	{
		interceptVolumeKeys = intercept;
	}

	public static boolean areVolumeKeysIntercepted()
	{
		return interceptVolumeKeys;
	}

	/**
	 * Called from MainActivity's key handlers. Returns true when the key was
	 * consumed by the bridge (the activity should not process it further).
	 */
	public static boolean interceptKey(int keyCode, boolean down)
	{
		if (!interceptVolumeKeys)
			return false;

		if (keyCode != android.view.KeyEvent.KEYCODE_VOLUME_UP && keyCode != android.view.KeyEvent.KEYCODE_VOLUME_DOWN)
			return false;

		PhoenixCore.dispatch("hwkey", (down ? "down:" : "up:") + keyCode);
		return true;
	}

	// ------------------------------------------------------------------
	// Haptics (device vibrator)
	// ------------------------------------------------------------------

	private static Vibrator getVibrator()
	{
		if (vibrator == null && mainContext != null)
		{
			try
			{
				vibrator = (Vibrator) mainContext.getSystemService(Context.VIBRATOR_SERVICE);
			}
			catch (Exception ignored) {}
		}
		return vibrator;
	}

	public static boolean hasVibrator()
	{
		Vibrator device = getVibrator();
		try
		{
			return device != null && device.hasVibrator();
		}
		catch (Exception e)
		{
			return false;
		}
	}

	public static void vibrate(long durationMs)
	{
		Vibrator device = getVibrator();
		if (device == null)
			return;

		try
		{
			if (!device.hasVibrator())
				return;

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				device.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE));
			else
				device.vibrate(durationMs);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "vibrate failed: " + e);
		}
	}

	/**
	 * @param patternCsv comma separated timings in ms
	 *                   (wait, vibrate, wait, vibrate, ...)
	 * @param repeat     index into pattern to repeat from, or -1 for no repeat
	 */
	public static void vibratePattern(String patternCsv, int repeat)
	{
		Vibrator device = getVibrator();
		if (device == null || patternCsv == null || patternCsv.length() == 0)
			return;

		try
		{
			if (!device.hasVibrator())
				return;

			String[] parts = patternCsv.split(",");
			long[] pattern = new long[parts.length];
			for (int i = 0; i < parts.length; i++)
				pattern[i] = Long.parseLong(parts[i].trim());

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				device.vibrate(VibrationEffect.createWaveform(pattern, repeat));
			else
				device.vibrate(pattern, repeat);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "vibratePattern failed: " + e);
		}
	}

	public static void cancelVibration()
	{
		Vibrator device = getVibrator();
		if (device == null)
			return;

		try
		{
			device.cancel();
		}
		catch (Exception ignored) {}
	}

	@Override public void onDestroy()
	{
		unregisterGamepadListener();
		cancelVibration();
	}
}
