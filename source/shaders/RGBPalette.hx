package shaders;

import backend.FlxFixedShader;
import openfl.display.ShaderParameter;

class RGBPalette {
	public var shader(default, null):RGBPaletteShader = new RGBPaletteShader();
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;

	private function set_r(color:FlxColor) {
		if (r == color) return color;
		r = color;
		writeColor(shader.r, color);
		return color;
	}

	private function set_g(color:FlxColor) {
		if (g == color) return color;
		g = color;
		writeColor(shader.g, color);
		return color;
	}

	private function set_b(color:FlxColor) {
		if (b == color) return color;
		b = color;
		writeColor(shader.b, color);
		return color;
	}

	private function set_mult(value:Float) {
		value = FlxMath.bound(value, 0, 1);
		if (mult == value) return value;
		mult = value;
		if (shader != null)
			shader.mult.value = [mult];
		return mult;
	}

	inline function writeColor(param:ShaderParameter<Float>, color:FlxColor)
	{
		var v = param.value;
		if (v == null) param.value = v = [0.0, 0.0, 0.0];
		v[0] = color.redFloat;
		v[1] = color.greenFloat;
		v[2] = color.blueFloat;
	}

	public function new()
	{
		r = 0xFFFF0000;
		g = 0xFF00FF00;
		b = 0xFF0000FF;
		mult = 1.0;
	}
}

// automatic handler for easy usability
class RGBShaderReference
{
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;
	public var enabled(default, set):Bool = true;

	public var parent:RGBPalette;
	private var _owner:FlxSprite;
	private var _original:RGBPalette;
	public function new(owner:FlxSprite, ref:RGBPalette)
	{
		parent = ref;
		_owner = owner;
		_original = ref;
		owner.shader = ref.shader;

		@:bypassAccessor
		{
			r = parent.r;
			g = parent.g;
			b = parent.b;
			mult = parent.mult;
		}
	}

	public function assign(palette:RGBPalette)
	{
		parent = palette;
		_original = palette;
		allowNew = true;
		_owner.shader = enabled ? palette.shader : null;
		@:bypassAccessor
		{
			r = palette.r;
			g = palette.g;
			b = palette.b;
			mult = palette.mult;
		}
	}

	private function set_r(value:FlxColor)
	{
		if(allowNew && value != _original.r) cloneOriginal();
		return (r = parent.r = value);
	}
	private function set_g(value:FlxColor)
	{
		if(allowNew && value != _original.g) cloneOriginal();
		return (g = parent.g = value);
	}
	private function set_b(value:FlxColor)
	{
		if(allowNew && value != _original.b) cloneOriginal();
		return (b = parent.b = value);
	}
	private function set_mult(value:Float)
	{
		if(allowNew && value != _original.mult) cloneOriginal();
		return (mult = parent.mult = value);
	}
	private function set_enabled(value:Bool)
	{
		_owner.shader = value ? parent.shader : null;
		return (enabled = value);
	}

	public var allowNew = true;
	private function cloneOriginal()
	{
		if(allowNew)
		{
			allowNew = false;
			if(_original != parent) return;

			parent = new RGBPalette();
			parent.r = _original.r;
			parent.g = _original.g;
			parent.b = _original.b;
			parent.mult = _original.mult;
			_owner.shader = parent.shader;
			//trace('created new shader');
		}
	}
}

class RGBPaletteShader extends FlxFixedShader {
	@:glFragmentHeader('
		#pragma header

		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec4 color = flixel_texture2D(bitmap, coord);
			if (!hasTransform || color.a == 0.0 || mult == 0.0) {
				return color;
			}
			vec3 mapped = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			return vec4(mix(color.rgb, mapped, mult), color.a);
		}')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	public function new()
	{
		super();
	}
}

class RGBPalettePool
{
	static final cache:Map<String, RGBPalette> = new Map();
	static final normal:Array<RGBPalette> = [];
	static final normalPixel:Array<RGBPalette> = [];
	static final quant:Array<RGBPalette> = [];
	static final rainbow:Array<RGBPalette> = [];
	static final char:Map<Int, RGBPalette> = new Map();
	static inline final rainbowSteps:Int = 32;

	static var gray:RGBPalette;

	public static function get(r:FlxColor, g:FlxColor, b:FlxColor):RGBPalette
	{
		final key = '$r,$g,$b';
		var palette = cache.get(key);
		if (palette == null)
			cache.set(key, palette = build(r, g, b));
		return palette;
	}

	public static function getDefault(noteData:Int, pixel:Bool):RGBPalette
	{
		if (noteData < 0) return null;
		final table = pixel ? normalPixel : normal;
		var palette = table[noteData];
		if (palette == null)
		{
			final colors = pixel ? ClientPrefs.arrowRGBPixel[noteData] : ClientPrefs.arrowRGB[noteData];
			if (colors == null) return null;
			table[noteData] = palette = build(colors[0], colors[1], colors[2]);
		}
		return palette;
	}

	public static function getQuant(index:Int):RGBPalette
	{
		var palette = quant[index];
		if (palette == null)
		{
			final c = ClientPrefs.quantRGB[index];
			quant[index] = palette = build(c[0], c[1], c[2]);
		}
		return palette;
	}

	public static function getRainbow(hue:Float):RGBPalette
	{
		final index = (Math.floor(hue / 360 * rainbowSteps) % rainbowSteps + rainbowSteps) % rainbowSteps;
		var palette = rainbow[index];
		if (palette == null)
		{
			final main = FlxColor.fromHSB(index * 360 / rainbowSteps, 1, 1);
			rainbow[index] = palette = build(main, FlxColor.WHITE, main.getDarkened(0.7));
		}
		return palette;
	}

	public static function getGray():RGBPalette
	{
		if (gray == null) gray = build(0xFFA0A0A0, FlxColor.WHITE, 0xFF424242);
		return gray;
	}

	public static function getChar(health:Array<Int>):RGBPalette
	{
		final main = FlxColor.fromRGB(health[0], health[1], health[2]);
		var palette = char.get(main);
		if (palette == null)
			char.set(main, palette = build(main, FlxColor.WHITE, main.getDarkened(0.7)));
		return palette;
	}

	public static function clear()
	{
		cache.clear();
		char.clear();
		quant.resize(0);
		rainbow.resize(0);
		normal.resize(0);
		normalPixel.resize(0);
		gray = null;
	}

	static function build(r:FlxColor, g:FlxColor, b:FlxColor):RGBPalette
	{
		final palette = new RGBPalette();
		palette.r = r;
		palette.g = g;
		palette.b = b;
		return palette;
	}
}