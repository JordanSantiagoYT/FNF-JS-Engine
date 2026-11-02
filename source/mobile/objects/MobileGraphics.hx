package mobile.objects;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;

/**
 * Procedurally draws every touch-control graphic.
 *
 * Nothing here needs an image file, so the touch layer can never fail because of a missing asset,
 * adds no size to the APK, and every shape is anti-aliased at the exact size it is shown at.
 * Graphics are cached by key (see `cached`).
 */
@:access(flixel.system.frontEnds.BitmapFrontEnd)
class MobileGraphics
{
	// -- public API ---------------------------------------------------------------------------

	/** A rounded square with an arrow inside. `dir`: 0 = up, 1 = down, 2 = left, 3 = right */
	public static function arrowButton(size:Int, dir:Int):FlxGraphic
	{
		return cached('mobile_arrow_${size}_$dir', () ->
		{
			final bmp = new BitmapData(size, size, true, 0);
			final px = new Canvas(size, size);
			final s = size;
			px.roundRect(s * .06, s * .06, s * .88, s * .88, s * .2, 0xFFFFFFFF, 0.55);
			// arrow pointing up, then rotated by swapping coordinates
			final c = s * .5;
			final a = s * .24;
			var p:Array<Float> = [c, c - a, c - a, c + a * .7, c + a, c + a * .7];
			p = rotate(p, c, c, dir);
			px.triangle(p[0], p[1], p[2], p[3], p[4], p[5], 0xFF202020, 0.9);
			px.flush(bmp);
			return bmp;
		});
	}

	/** A round button with a letter glyph. */
	public static function letterButton(size:Int, letter:String, color:Int):FlxGraphic
	{
		return cached('mobile_letter_${size}_${letter}_$color', () ->
		{
			final bmp = new BitmapData(size, size, true, 0);
			final px = new Canvas(size, size);
			final c = size * .5;
			px.circle(c, c, size * .46, color, 0.6);
			px.ring(c, c, size * .46, size * .035, 0xFFFFFFFF, 0.55);
			glyph(px, letter, c, c, size * .24, size * .07);
			px.flush(bmp);
			return bmp;
		});
	}

	/** Small rounded "II" pause button. */
	public static function pauseButton(size:Int):FlxGraphic
	{
		return cached('mobile_pause_$size', () ->
		{
			final bmp = new BitmapData(size, size, true, 0);
			final px = new Canvas(size, size);
			final s = size;
			px.roundRect(s * .08, s * .08, s * .84, s * .84, s * .22, 0xFF000000, 0.45);
			px.roundRect(s * .33, s * .27, s * .12, s * .46, s * .04, 0xFFFFFFFF, 0.9);
			px.roundRect(s * .55, s * .27, s * .12, s * .46, s * .04, 0xFFFFFFFF, 0.9);
			px.flush(bmp);
			return bmp;
		});
	}

	/**
	 * One hitbox lane.
	 * @param style 0 = gradient (default), 1 = flat, 2 = outline only
	 */
	public static function hitboxLane(w:Int, h:Int, color:Int, style:Int):FlxGraphic
	{
		return cached('mobile_lane_${w}_${h}_${color}_$style', () ->
		{
			final bmp = new BitmapData(w, h, true, 0);
			final r = (color >> 16) & 0xFF;
			final g = (color >> 8) & 0xFF;
			final b = color & 0xFF;
			final rect = new openfl.geom.Rectangle(0, 0, w, 1);

			if (style != 2)
			{
				bmp.lock();
				for (y in 0...h)
				{
					// style 0: transparent at the top, solid at the bottom
					final t = style == 0 ? (y / h) : 1.0;
					final a = Std.int(255 * (style == 0 ? (0.15 + 0.85 * t * t) : 0.7));
					rect.y = y;
					bmp.fillRect(rect, (a << 24) | (r << 16) | (g << 8) | b);
				}
				bmp.unlock();
			}

			// border (always drawn, keeps lanes readable even when almost transparent)
			final border = (0xFF << 24) | (r << 16) | (g << 8) | b;
			final t = 3;
			bmp.fillRect(new openfl.geom.Rectangle(0, 0, t, h), border);
			bmp.fillRect(new openfl.geom.Rectangle(w - t, 0, t, h), border);
			bmp.fillRect(new openfl.geom.Rectangle(0, 0, w, t), border);
			bmp.fillRect(new openfl.geom.Rectangle(0, h - t, w, t), border);
			return bmp;
		});
	}

	// -- internals ----------------------------------------------------------------------------

	/**
	 * Touch graphics are NOT put in `FlxG.bitmap`: the engine's `Paths.clearStoredMemory()` destroys every
	 * graphic it does not know about, which would blank the buttons in the middle of a song.
	 * They live in this private cache instead and are never freed (a few small bitmaps).
	 */
	static final store:Map<String, FlxGraphic> = [];

	static function cached(key:String, make:Void->BitmapData):FlxGraphic
	{
		final existing = store.get(key);
		if (existing != null && !existing.isDestroyed)
			return existing;

		final graphic = FlxGraphic.fromBitmapData(make(), false, key, true);
		graphic.persist = true;
		FlxG.bitmap.removeKey(key); // keep it only in our own store (removeKey does not destroy it)
		store.set(key, graphic);
		return graphic;
	}

	/** rotates a flat [x0, y0, x1, y1...] point list in 90 degree steps. 0 = up, 1 = down, 2 = left, 3 = right */
	static function rotate(p:Array<Float>, cx:Float, cy:Float, dir:Int):Array<Float>
	{
		if (dir == 0)
			return p;
		final out:Array<Float> = [];
		var i = 0;
		while (i < p.length)
		{
			final dx = p[i] - cx;
			final dy = p[i + 1] - cy;
			switch (dir)
			{
				case 1: // down
					out.push(cx - dx);
					out.push(cy - dy);
				case 2: // left
					out.push(cx + dy);
					out.push(cy - dx);
				default: // right
					out.push(cx - dy);
					out.push(cy + dx);
			}
			i += 2;
		}
		return out;
	}

	/** Strokes a letter with line segments. Only the glyphs the buttons need are defined. */
	static function glyph(px:Canvas, letter:String, cx:Float, cy:Float, r:Float, w:Float):Void
	{
		// every glyph is a list of polylines in a -1..1 box
		final lines:Array<Array<Float>> = switch (letter)
		{
			case 'A': [[-.8, 1, 0, -1, .8, 1], [-.45, .3, .45, .3]];
			case 'B': [[-.6, -1, -.6, 1], [-.6, -1, .3, -1, .7, -.65, .7, -.35, .3, 0, -.6, 0], [.3, 0, .8, .35, .8, .7, .4, 1, -.6, 1]];
			case 'X': [[-.8, -1, .8, 1], [.8, -1, -.8, 1]];
			case 'Y': [[-.8, -1, 0, 0, .8, -1], [0, 0, 0, 1]];
			case 'C': [[.8, -.7, .4, -1, -.4, -1, -.8, -.6, -.8, .6, -.4, 1, .4, 1, .8, .7]];
			case 'E': [[.6, -1, -.6, -1, -.6, 1, .6, 1], [-.6, 0, .4, 0]];
			default: [];
		}
		for (line in lines)
		{
			var i = 0;
			while (i + 3 < line.length)
			{
				px.line(cx + line[i] * r, cy + line[i + 1] * r, cx + line[i + 2] * r, cy + line[i + 3] * r, w, 0xFFFFFFFF, 0.95);
				i += 2;
			}
		}
	}
}

/**
 * A tiny signed-distance-field rasteriser: each shape is a distance function that is turned into
 * anti-aliased coverage and blended into an ARGB float buffer, then written once to the bitmap.
 */
private class Canvas
{
	final w:Int;
	final h:Int;
	final buf:Array<Float>; // premultiplied r, g, b, a per pixel

	public function new(w:Int, h:Int)
	{
		this.w = w;
		this.h = h;
		buf = [for (i in 0...(w * h * 4)) 0.0];
	}

	inline function blend(x:Int, y:Int, color:Int, alpha:Float):Void
	{
		if (alpha <= 0)
			return;
		final i = (y * w + x) * 4;
		final a = alpha;
		final inv = 1 - a;
		buf[i] = buf[i] * inv + ((color >> 16) & 0xFF) / 255 * a;
		buf[i + 1] = buf[i + 1] * inv + ((color >> 8) & 0xFF) / 255 * a;
		buf[i + 2] = buf[i + 2] * inv + (color & 0xFF) / 255 * a;
		buf[i + 3] = buf[i + 3] * inv + a;
	}

	static inline function coverage(dist:Float):Float
		return dist <= -0.5 ? 1.0 : (dist >= 0.5 ? 0.0 : 0.5 - dist);

	public function circle(cx:Float, cy:Float, r:Float, color:Int, opacity:Float):Void
	{
		for (y in 0...h)
			for (x in 0...w)
			{
				final d = Math.sqrt((x + .5 - cx) * (x + .5 - cx) + (y + .5 - cy) * (y + .5 - cy)) - r;
				blend(x, y, color, coverage(d) * opacity);
			}
	}

	public function ring(cx:Float, cy:Float, r:Float, thickness:Float, color:Int, opacity:Float):Void
	{
		for (y in 0...h)
			for (x in 0...w)
			{
				final d = Math.abs(Math.sqrt((x + .5 - cx) * (x + .5 - cx) + (y + .5 - cy) * (y + .5 - cy)) - r) - thickness * .5;
				blend(x, y, color, coverage(d) * opacity);
			}
	}

	public function roundRect(x0:Float, y0:Float, rw:Float, rh:Float, radius:Float, color:Int, opacity:Float):Void
	{
		final cx = x0 + rw * .5;
		final cy = y0 + rh * .5;
		final hx = rw * .5 - radius;
		final hy = rh * .5 - radius;
		for (y in 0...h)
			for (x in 0...w)
			{
				final qx = Math.abs(x + .5 - cx) - hx;
				final qy = Math.abs(y + .5 - cy) - hy;
				final outside = Math.sqrt(Math.max(qx, 0) * Math.max(qx, 0) + Math.max(qy, 0) * Math.max(qy, 0));
				final d = outside + Math.min(Math.max(qx, qy), 0) - radius;
				blend(x, y, color, coverage(d) * opacity);
			}
	}

	public function line(x0:Float, y0:Float, x1:Float, y1:Float, width:Float, color:Int, opacity:Float):Void
	{
		final dx = x1 - x0;
		final dy = y1 - y0;
		final len2 = dx * dx + dy * dy;
		for (y in 0...h)
			for (x in 0...w)
			{
				final px = x + .5 - x0;
				final py = y + .5 - y0;
				final t = len2 == 0 ? 0 : Math.max(0, Math.min(1, (px * dx + py * dy) / len2));
				final ex = px - dx * t;
				final ey = py - dy * t;
				final d = Math.sqrt(ex * ex + ey * ey) - width * .5;
				blend(x, y, color, coverage(d) * opacity);
			}
	}

	public function triangle(ax:Float, ay:Float, bx:Float, by:Float, cx:Float, cy:Float, color:Int, opacity:Float):Void
	{
		// signed distance to the three edges (inside = negative); small round corners keep it friendly
		final pts = [ax, ay, bx, by, cx, cy];
		final sign = ((bx - ax) * (cy - ay) - (by - ay) * (cx - ax)) > 0 ? 1.0 : -1.0;
		for (y in 0...h)
			for (x in 0...w)
			{
				var d = -1e9;
				for (e in 0...3)
				{
					final x0 = pts[e * 2];
					final y0 = pts[e * 2 + 1];
					final x1 = pts[((e + 1) % 3) * 2];
					final y1 = pts[((e + 1) % 3) * 2 + 1];
					final ex = x1 - x0;
					final ey = y1 - y0;
					final len = Math.sqrt(ex * ex + ey * ey);
					// distance from the edge line, positive on the outside
					final dist = -sign * (ex * (y + .5 - y0) - ey * (x + .5 - x0)) / len;
					if (dist > d)
						d = dist;
				}
				blend(x, y, color, coverage(d) * opacity);
			}
	}

	/** Writes the buffer into the bitmap (as non-premultiplied ARGB). */
	public function flush(bmp:BitmapData):Void
	{
		bmp.lock();
		for (y in 0...h)
			for (x in 0...w)
			{
				final i = (y * w + x) * 4;
				final a = buf[i + 3];
				if (a <= 0)
					continue;
				final r = Std.int(Math.min(255, buf[i] / a * 255));
				final g = Std.int(Math.min(255, buf[i + 1] / a * 255));
				final b = Std.int(Math.min(255, buf[i + 2] / a * 255));
				bmp.setPixel32(x, y, (Std.int(Math.min(255, a * 255)) << 24) | (r << 16) | (g << 8) | b);
			}
		bmp.unlock();
	}
}
