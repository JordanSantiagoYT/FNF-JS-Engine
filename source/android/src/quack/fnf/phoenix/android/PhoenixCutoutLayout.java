package quack.fnf.phoenix.android;

import android.content.Context;
import android.os.Build;
import android.util.Log;
import android.view.DisplayCutout;
import android.view.WindowInsets;
import android.widget.FrameLayout;

/** Owned container around SDL's layout. Never changes padding or listeners on
 * framework/SDL views. MATCH_PARENT children are measured inside our safe area.
 * Android dispatches pointer coordinates relative to the resized SDL surface.
 */
public final class PhoenixCutoutLayout extends FrameLayout
{
	private boolean respect;
	private int left, top, right, bottom;

	public PhoenixCutoutLayout(Context context)
	{
		super(context);
	}

	public void setRespectCutout(boolean value)
	{
		respect = value;
		applyPadding();
		requestApplyInsets();
	}

	@Override public WindowInsets onApplyWindowInsets(WindowInsets insets)
	{
		if (Build.VERSION.SDK_INT >= 28)
		{
			try
			{
				DisplayCutout cutout = insets.getDisplayCutout();
				left = cutout == null ? 0 : cutout.getSafeInsetLeft();
				top = cutout == null ? 0 : cutout.getSafeInsetTop();
				right = cutout == null ? 0 : cutout.getSafeInsetRight();
				bottom = cutout == null ? 0 : cutout.getSafeInsetBottom();
				applyPadding();
			}
			catch (RuntimeException error)
			{
				Log.e("PhoenixDisplay", "Unable to retrieve/apply cutout insets", error);
			}
		}
		// No consumption/replacement of downstream listeners or system-bar insets.
		return super.onApplyWindowInsets(insets);
	}

	private void applyPadding()
	{
		// This container's padding belongs exclusively to this class. SDL's and
		// android.R.id.content's original padding is never read or overwritten.
		setPadding(respect ? left : 0, respect ? top : 0,
			respect ? right : 0, respect ? bottom : 0);
	}
}
