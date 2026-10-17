package quack.fnf.phoenix.android;

import android.content.Context;
import android.os.Build;
import android.view.DisplayCutout;
import android.view.WindowInsets;

/** Executes production policy/layout with deliberately minimal Android doubles.
 * Not an Android measurement, SurfaceView, event dispatch or device test.
 */
public final class PhoenixCutoutTest
{
	static void check(boolean condition) {
		if (!condition) throw new AssertionError();
	}
	static void padding(PhoenixCutoutLayout view, int l, int t, int r, int b) {
		check(view.getPaddingLeft() == l && view.getPaddingTop() == t
			&& view.getPaddingRight() == r && view.getPaddingBottom() == b);
	}
	static class ActivityHarness extends quack.fnf.phoenix.MainActivity {
		void create(){onCreate(null);} void resume(){onResume();} void destroy(){onDestroy();}
	}
	static void activityCallbacks() {
		Build.VERSION.SDK_INT = 36;
		PhoenixDisplay.setCutoutMode("never");
		ActivityHarness first = new ActivityHarness();
		first.create();
		check(first.content instanceof PhoenixCutoutLayout);
		PhoenixCutoutLayout oldContent = (PhoenixCutoutLayout) first.content;
		oldContent.onApplyWindowInsets(new WindowInsets(new DisplayCutout(55,0,0,0)));
		padding(oldContent,55,0,0,0);
		PhoenixDisplay.setCutoutMode("always");
		padding(oldContent,0,0,0,0);
		first.resume();
		first.onWindowFocusChanged(true);
		padding(oldContent,0,0,0,0);
		first.destroy();
		ActivityHarness second = new ActivityHarness();
		second.create();
		PhoenixCutoutLayout newContent = (PhoenixCutoutLayout) second.content;
		check(newContent != oldContent);
		newContent.onApplyWindowInsets(new WindowInsets(new DisplayCutout(0,0,55,0)));
		padding(newContent,0,0,0,0);
		PhoenixDisplay.setCutoutMode("never");
		padding(newContent,0,0,55,0);
		padding(oldContent,0,0,0,0);
		for (int sdk : new int[]{21,27,28,29,30,34}) {
			Build.VERSION.SDK_INT = sdk;
			ActivityHarness legacy = new ActivityHarness();
			legacy.create();
			check(!(legacy.content instanceof PhoenixCutoutLayout));
		}
	}
	static class Host extends android.app.Activity implements PhoenixDisplay.CutoutHost {
		boolean respect;
		public void setRespectCutoutInsets(boolean value){respect=value;}
	}
	static void lifecycle() {
		Build.VERSION.SDK_INT = 36;
		org.haxe.extension.Extension.mainActivity = null;
		PhoenixDisplay.setCutoutMode("never"); // Retain intent without an Activity.
		Host first = new Host();
		org.haxe.extension.Extension.mainActivity = first;
		PhoenixDisplay.applyCutoutToActivity(first);
		check(first.respect && first.window.attrs.layoutInDisplayCutoutMode == 3);
		PhoenixDisplay.setCutoutMode("always");
		check(!first.respect && first.window.attrs.layoutInDisplayCutoutMode == 3);
		// Queued work must not update an Activity that has been replaced.
		first.defer = true;
		PhoenixDisplay.setCutoutMode("never");
		int previousUpdates = first.window.updates;
		Host second = new Host();
		org.haxe.extension.Extension.mainActivity = second;
		first.destroyed = true;
		first.queued.run();
		check(first.window.updates == previousUpdates);
		PhoenixDisplay.applyCutoutToActivity(second); // Recreation/resume path.
		check(second.respect);
		PhoenixDisplay.applyCutoutToActivity(second); // Idempotent resume/focus.
		check(second.respect);
		second.defer = true;
		PhoenixDisplay.setCutoutMode("always");
		Runnable old = second.queued;
		PhoenixDisplay.setCutoutMode("never");
		old.run(); // Latest selection, not the stale queued mode.
		check(second.respect);
		second.finishing = true;
		int updates = second.window.updates;
		PhoenixDisplay.applyCutoutToActivity(second);
		check(updates == second.window.updates);
		second.finishing = false;
		second.window = null;
		PhoenixDisplay.applyCutoutToActivity(second); // Missing window, bounded retry.
		second.window = new android.view.Window();
		second.window.fail = true;
		int errors = android.util.Log.errors;
		PhoenixDisplay.applyCutoutToActivity(second);
		check(android.util.Log.errors == errors + 1); // Failure is diagnosed, not thrown.
		second.window.fail = false;
		for (int sdk : new int[]{27,28,29,30,34,35,36}) {
			Build.VERSION.SDK_INT = sdk;
			second.defer = false;
			PhoenixDisplay.setCutoutMode("never");
			if (sdk >= 28) check(second.window.attrs.layoutInDisplayCutoutMode == (sdk >= 35 ? 3 : 2));
			PhoenixDisplay.setCutoutMode("always");
			if (sdk >= 28) check(!second.respect && second.window.attrs.layoutInDisplayCutoutMode == (sdk >= 30 ? 3 : 1));
		}
		PhoenixDisplay.applyCutoutToActivity(null);
	}
	public static void main(String[] args) {
		lifecycle();
		activityCallbacks();
		for (int sdk : new int[] {21, 27, 28, 29, 30, 34, 35, 36}) {
			check(PhoenixCutoutPolicy.windowMode(sdk, "never") == (sdk < 28 ? 0 : 2));
			check(PhoenixCutoutPolicy.windowMode(sdk, "always") == (sdk < 28 ? 0 : sdk < 30 ? 1 : 3));
			check(PhoenixCutoutPolicy.windowMode(sdk, "shortEdges") == (sdk < 28 ? 0 : 1));
			check(PhoenixCutoutPolicy.windowMode(sdk, "default") == 0);
			check(PhoenixCutoutPolicy.windowMode(sdk, null) == 0);
			check(PhoenixCutoutPolicy.needsSafeInsets(sdk, 36, "never") == (sdk >= 35));
			check(!PhoenixCutoutPolicy.needsSafeInsets(sdk, 34, "never"));
			check(!PhoenixCutoutPolicy.needsSafeInsets(sdk, 36, "always"));
		}
		Build.VERSION.SDK_INT = 36;
		PhoenixCutoutLayout view = new PhoenixCutoutLayout(new Context());
		WindowInsets portrait = new WindowInsets(new DisplayCutout(0, 40, 0, 0));
		view.setRespectCutout(true);
		check(view.onApplyWindowInsets(portrait) == portrait); // No consumption.
		padding(view, 0, 40, 0, 0);
		for (int i = 0; i < 20; i++) {
			view.setRespectCutout(false);
			padding(view, 0, 0, 0, 0);
			view.setRespectCutout(true);
			view.onApplyWindowInsets(portrait);
			padding(view, 0, 40, 0, 0);
		}
		view.onApplyWindowInsets(new WindowInsets(new DisplayCutout(50, 0, 0, 0)));
		padding(view, 50, 0, 0, 0);
		view.onApplyWindowInsets(new WindowInsets(new DisplayCutout(0, 0, 50, 0)));
		padding(view, 0, 0, 50, 0);
		view.onApplyWindowInsets(new WindowInsets(null));
		padding(view, 0, 0, 0, 0);
		PhoenixCutoutLayout recreated = new PhoenixCutoutLayout(new Context());
		recreated.setRespectCutout(true);
		recreated.onApplyWindowInsets(portrait);
		padding(recreated, 0, 40, 0, 0);
		padding(view, 0, 0, 0, 0); // No static state crossing instances.
		recreated.setRespectCutout(false);
		recreated.onApplyWindowInsets(portrait);
		padding(recreated, 0, 0, 0, 0);
		// API <28 must not call the cutout API (double throws if it does).
		Build.VERSION.SDK_INT = 27;
		recreated.onApplyWindowInsets(portrait);
		System.out.println("Cutout policy/layout tests passed");
	}
}
