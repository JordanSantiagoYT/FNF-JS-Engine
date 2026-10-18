import backend.ScreenLayout;
import mobile.flixel.HitboxTouchLogic;

/** Renderer-free contract tests. Run with:
 * bash tests/haxe/run-layout.sh
 */
class LayoutSpec
{
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	static function main():Void
	{
		for (size in [
			{w: 1280, h: 720, expected: 1280},
			{w: 1920, h: 1080, expected: 1280},
			{w: 2560, h: 1080, expected: 1707},
			{w: 3440, h: 1440, expected: 1720},
			{w: 3840, h: 1080, expected: 2560},
			{w: 5120, h: 1440, expected: 2560},
			{w: 1024, h: 768, expected: 1280},
			{w: 800, h: 1280, expected: 1280}
		])
		{
			final width:Int = ScreenLayout.viewportWidth(size.w, size.h, true);
			equal(width, size.expected, 'viewport ${size.w}x${size.h}');
			equal(ScreenLayout.viewportWidth(size.w, size.h, false), 1280, '16:9 toggle off');
			check(width >= 1280, 'logical viewport must never shrink');
			if (size.w / size.h >= 1280 / 720)
			{
				check(width / 720 >= size.w / size.h, 'viewport must cover the display');
				check(width / 720 - size.w / size.h < 1 / 720, 'no more than one pixel of rounding');
			}
		}
		equal(ScreenLayout.viewportWidth(0, 0, true), 1280, 'minimized window');
		equal(ScreenLayout.viewportWidth(-1, 720, true), 1280, 'invalid window');
		equal(ScreenLayout.contentLeft(1280), 0.0, 'original content origin');
		equal(ScreenLayout.contentLeft(1720), 220.0, 'centered content origin');
		equal(ScreenLayout.contentLeft(2560), 640.0, '32:9 content origin');

		// Touch lanes exactly partition the width (no uncovered last pixel,
		// overlapping lane, or zero-size lane at odd widths).
		for (width in [1280, 1707, 1720, 2560, 2561])
			for (lanes in [4, 6, 8])
			{
				equal(ScreenLayout.laneStart(0, lanes, width), 0, 'first lane');
				equal(ScreenLayout.laneStart(lanes, lanes, width), width, 'last lane');
				for (index in 0...lanes)
				{
					final start = ScreenLayout.laneStart(index, lanes, width);
					final end = ScreenLayout.laneStart(index + 1, lanes, width);
					check(end > start, 'each lane receives pixels');
					check(end - start == Math.floor(width / lanes) || end - start == Math.ceil(width / lanes), 'lanes differ by at most one pixel');
				}
			}

		// The extra-control strip and four lanes partition every pixel of
		// either orientation, even when the logical height is odd or tiny.
		for (height in [0, 1, 2, 3, 5, 719, 720, 721])
		{
			equal(ScreenLayout.hitboxExtraHeight(height, false), 0, 'extra option off');
			final extra = ScreenLayout.hitboxExtraHeight(height, true);
			if (height < 2)
				equal(extra, 0, 'no zero-height main lane');
			else
			{
				check(extra > 0 && height - extra > 0, 'positive heights for both regions');
				for (bottom in [true, false])
				{
					final mainY = bottom ? 0 : extra;
					final extraY = bottom ? height - extra : 0;
					check((mainY == 0 && extraY == height - extra)
						|| (extraY == 0 && mainY == extra), 'no vertical gap or overlap');
				}
			}
		}
		equal(ScreenLayout.hitboxExtraHeight(720, true), 180, 'normal extra-control strip');
		equal(ScreenLayout.hitboxExtraHeight(721, true), 180, 'odd-height extra-control strip');

		// One lane's action must stay down while any of its fingers is held.
		// A second touch or the release of the first may not synthesize a
		// second press or prematurely release a sustain note.
		var held = false;
		function contact(anyPressed:Bool, releasedOver:Bool, expected:Int, label:String):Void
		{
			final action = HitboxTouchLogic.transition(held, anyPressed, releasedOver);
			equal(action, expected, label);
			if (action == HitboxTouchLogic.PRESS) held = true;
			if (action == HitboxTouchLogic.RELEASE || action == HitboxTouchLogic.CANCEL) held = false;
		}
		contact(false, false, HitboxTouchLogic.NONE, 'idle');
		contact(true, false, HitboxTouchLogic.PRESS, 'first finger');
		contact(true, false, HitboxTouchLogic.NONE, 'second finger');
		contact(true, true, HitboxTouchLogic.NONE, 'release first, keep second');
		contact(true, false, HitboxTouchLogic.NONE, 'sustain the remaining finger');
		contact(false, true, HitboxTouchLogic.RELEASE, 'release last finger');
		contact(false, false, HitboxTouchLogic.NONE, 'released state');
		contact(true, false, HitboxTouchLogic.PRESS, 'swipe into the lane');
		contact(false, false, HitboxTouchLogic.CANCEL, 'swipe out of the lane');
		contact(true, false, HitboxTouchLogic.PRESS, 'press again after cancellation');
		contact(false, true, HitboxTouchLogic.RELEASE, 'release after re-entry');

		// A button remains touchable and stable through resize and rollback.
		equal(ScreenLayout.anchoredPosition(1148, 1280, 1720, 132), 1588.0, 'right edge');
		equal(ScreenLayout.anchoredPosition(1588, 1720, 1280, 132), 1148.0, 'right edge rollback');
		equal(ScreenLayout.anchoredPosition(105, 1280, 1720, 132), 105.0, 'left edge');
		equal(ScreenLayout.anchoredPosition(628, 1280, 1720, 132), 1068.0, 'right button straddles midpoint');
		equal(ScreenLayout.anchoredPosition(2000, 2560, 1280, 132), 720.0, 'right edge shift');
		equal(ScreenLayout.anchoredPosition(3000, 2560, 1280, 132), 1148.0, 'clamped to screen');
		trace('LayoutSpec passed');
	}
}
