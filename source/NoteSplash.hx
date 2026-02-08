package;

import backend.FlxFixedShader;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import shaders.RGBPalette.RGBShaderReference;
import shaders.RGBPalette;

typedef NoteSplashConfig = {
	anim:String,
	minFps:Int,
	maxFps:Int,
	offsets:Array<Array<Float>>
}

class NoteSplash extends FlxSprite
{
	public var rgbShader:PixelSplashShaderRef;
	private var idleAnim:String;
	private var textureLoaded:String = null;
	var texture:String = null;

	public static var defaultNoteSplash(default, never):String = 'noteSplashes/noteSplashes';

	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0) {
		super(x, y);

		if(PlayState.SONG.splashSkin.length > 0 && Paths.fileExists('images/' + PlayState.SONG.splashSkin + '.png', IMAGE)) texture = PlayState.SONG.splashSkin;
		else texture = defaultNoteSplash + getSplashSkinPostfix();

		rgbShader = new PixelSplashShaderRef();
		shader = rgbShader.shader;

		if (!Paths.splashConfigs.exists(texture)) config = Paths.initSplashConfig(texture);
		config = Paths.splashConfigs.get(texture);

		setupNoteSplash(x, y, note);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	var maxAnims:Int = 2;
	var config:NoteSplashConfig = null;
	public function setupNoteSplash(x:Float, y:Float, direction:Int = 0, ?note:Note = null) {
		setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
		alpha = 0.6;
		shader = (ClientPrefs.enableColorShader ? rgbShader.shader : null);

		if(note != null && note.noteSplashData.texture.length > 0 && Paths.fileExists('images/' + note.noteSplashData.texture + '.png', IMAGE)) texture = note.noteSplashData.texture;

		if(textureLoaded != texture) {
			loadAnims(texture);
		}

		if (note != null && note.rgbShader != null)
		{
			var tempShader:RGBPalette = null;
			if((note == null || note.noteSplashData.useRGBShader) && (PlayState.SONG == null || !PlayState.SONG.disableNoteRGB))
			{
				// If Note RGB is enabled:
				if(note != null && !note.noteSplashData.useGlobalShader)
				{
					if(note.noteSplashData.r != -1) note.rgbShader.r = note.noteSplashData.r;
					if(note.noteSplashData.g != -1) note.rgbShader.g = note.noteSplashData.g;
					if(note.noteSplashData.b != -1) note.rgbShader.b = note.noteSplashData.b;
					tempShader = note.rgbShader.parent;
				}
				else tempShader = Note.globalRgbShaders[direction];
			}
			rgbShader.copyValues(tempShader);
		}
		textureLoaded = texture;
		offset.set(10, 10);

		var animNum:Int = FlxG.random.int(1, Paths.splashAnimCountMap.get(texture));
		var minFps:Int = 22;
		var maxFps:Int = 26;
		if(config != null)
		{
			var animID:Int = direction + ((animNum - 1) * Note.colArray.length);
			var offs:Array<Float> = config.offsets[FlxMath.wrap(animID, 0, config.offsets.length-1)];
			offset.x += offs[0];
			offset.y += offs[1];
			minFps = config.minFps;
			maxFps = config.maxFps;
		}

		var splashToPlay:Int = direction;

		animation.play('note' + splashToPlay + '-' + (animNum), true);

		if(animation.curAnim != null)animation.curAnim.frameRate = FlxG.random.int(config.minFps, config.maxFps);
	}

	public static function getSplashSkinPostfix()
	{
		var skin:String = '';
		if(ClientPrefs.splashType != 'Default')
			skin = '-' + ClientPrefs.splashType.trim().toLowerCase().replace(' ', '_');
		return skin;
	}

	function loadAnims(skin:String) {
		maxAnims = 0;
		if (!Paths.splashSkinFramesMap.exists(skin)) Paths.initSplash(skin);
		frames = Paths.splashSkinFramesMap.get(skin);
		animation.copyFrom(Paths.splashSkinAnimsMap.get(skin));
	}

	static var aliveTime:Float = 0;
	static var buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float) {
		aliveTime += elapsed;
		if((animation.curAnim != null && animation.curAnim.finished) ||
			(animation.curAnim == null && aliveTime >= buggedKillTime)) kill();

		super.update(elapsed);
	}
}

class PixelSplashShaderRef {
	public var shader:PixelSplashShader = new PixelSplashShader();

	public function copyValues(tempShader:RGBPalette)
	{
		var enabled:Bool = false;
		if(tempShader != null)
			enabled = true;

		if(enabled)
		{
			for (i in 0...3)
			{
				shader.r.value[i] = tempShader.shader.r.value[i];
				shader.g.value[i] = tempShader.shader.g.value[i];
				shader.b.value[i] = tempShader.shader.b.value[i];
			}
			shader.mult.value[0] = tempShader.shader.mult.value[0];
		}
		else shader.mult.value[0] = 0.0;
	}

	public function new()
	{
		shader.r.value = [0, 0, 0];
		shader.g.value = [0, 0, 0];
		shader.b.value = [0, 0, 0];
		shader.mult.value = [1];

		var pixel:Float = 1;
		if(PlayState.isPixelStage) pixel = PlayState.daPixelZoom;
		shader.uBlocksize.value = [pixel, pixel];
		//trace('Created shader ' + Conductor.songPosition);
	}
}

class PixelSplashShader extends FlxFixedShader
{
	@:glFragmentHeader('
		#pragma header

		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;
		uniform vec2 uBlocksize;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec2 blocks = openfl_TextureSize / uBlocksize;
			vec4 color = flixel_texture2D(bitmap, floor(coord * blocks) / blocks);
			if (!hasTransform) {
				return color;
			}

			if(color.a == 0.0 || mult == 0.0) {
				return color * openfl_Alphav;
			}

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;

			color = mix(color, newColor, mult);

			if(color.a > 0.0) {
				return vec4(color.rgb, color.a);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
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
