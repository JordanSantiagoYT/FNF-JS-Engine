package quack.fnf.phoenix.android;

/** SDK-independent policy; values are Android LayoutParams cutout constants. */
public final class PhoenixCutoutPolicy
{
	private PhoenixCutoutPolicy() {}

	public static int windowMode(int sdk, String mode)
	{
		if (sdk < 28) return 0;
		if ("never".equals(mode)) return 2;
		if ("always".equals(mode)) return sdk >= 30 ? 3 : 1;
		if ("shortEdges".equals(mode)) return 1;
		return 0;
	}

	public static boolean needsSafeInsets(int sdk, int targetSdk, String mode)
	{
		return sdk >= 35 && targetSdk >= 35 && "never".equals(mode);
	}
}
