package;

// STOLEN FROM HAXEFLIXEL DEMO LOL
import WiggleEffect.WiggleEffectType;
import WiggleEffect.WiggleShader;
import flixel.system.FlxAssets.FlxShader;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.ShaderInput;
import shaders.ErrorHandledShader;

typedef ShaderEffect =
{
  var shader:Dynamic;
}

class BuildingEffect
{
  public var shader:BuildingShader = new BuildingShader();

  public function new()
  {
    shader.alphaShit.value = [0.0];
  }

  public function addAlpha(alpha:Float)
  {
    trace(shader.alphaShit.value[0]);
    shader.alphaShit.value[0] += alpha;
  }

  public function setAlpha(alpha:Float)
  {
    shader.alphaShit.value[0] = alpha;
  }
}

class BuildingShader extends FlxShader
{
  @:glFragmentSource('
    #pragma header
    uniform float alphaShit;
    void main()
    {

      vec4 color = flixel_texture2D(bitmap,openfl_TextureCoordv);
      if (color.a > 0.0)
        color-=alphaShit;

      gl_FragColor = color;
    }
  ')
  public function new()
  {
    super();
  }
}

class ChromaticAberrationShader extends FlxShader
{
  @:glFragmentSource('
		#pragma header

		uniform float rOffset;
		uniform float gOffset;
		uniform float bOffset;

		void main()
		{
			vec4 col1 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(rOffset, 0.0));
			vec4 col2 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(gOffset, 0.0));
			vec4 col3 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(bOffset, 0.0));
			vec4 toUse = texture2D(bitmap, openfl_TextureCoordv);
			toUse.r = col1.r;
			toUse.g = col2.g;
			toUse.b = col3.b;

			gl_FragColor = toUse;
		}')
  public function new()
  {
    super();
  }
}

class ChromaticAberrationEffect extends Effect
{
  public var shader:ChromaticAberrationShader;

  public function new(offset:Float = 0.00)
  {
    shader = new ChromaticAberrationShader();
    shader.rOffset.value = [offset];
    shader.gOffset.value = [0.0];
    shader.bOffset.value = [-offset];
  }

  public function setChrome(chromeOffset:Float):Void
  {
    shader.rOffset.value = [chromeOffset];
    shader.gOffset.value = [0.0];
    shader.bOffset.value = [chromeOffset * -1];
  }
}

class ScanlineEffect extends Effect
{
  public var shader:Scanline;

  public function new(lockAlpha)
  {
    shader = new Scanline();
    shader.lockAlpha.value = [lockAlpha];
  }
}

class Scanline extends FlxShader
{
  @:glFragmentSource('
		#pragma header
		const float scale = 1.0;
	uniform bool lockAlpha;
		void main()
		{
			if (mod(floor(openfl_TextureCoordv.y * openfl_TextureSize.y / scale), 2.0) == 0.0 ){
				float bitch = 1.0;

				vec4 texColor = texture2D(bitmap, openfl_TextureCoordv);
				if (lockAlpha) bitch = texColor.a;
				gl_FragColor = vec4(0.0, 0.0, 0.0, bitch);
			}else{
				gl_FragColor = texture2D(bitmap, openfl_TextureCoordv);
			}
		}')
  public function new()
  {
    super();
    lockAlpha.value = [false];
  }
}

class TiltshiftEffect extends Effect
{
  public var shader:Tiltshift;

  public function new(blurAmount:Float, center:Float)
  {
    shader = new Tiltshift();
    shader.bluramount.value = [blurAmount];
    shader.center.value = [center];
  }
}

class Tiltshift extends FlxShader
{
  @:glFragmentSource('
		#pragma header

		// Modified version of a tilt shift shader from Martin Jonasson (http://grapefrukt.com/)
		// Read http://notes.underscorediscovery.com/ for context on shaders and this file
		// License : MIT

			/*
				Take note that blurring in a single pass (the two for loops below) is more expensive than separating
				the x and the y blur into different passes. This was used where bleeding edge performance
				was not crucial and is to illustrate a point.

				The reason two passes is cheaper?
				   texture2D is a fairly high cost call, sampling a texture.

				   So, in a single pass, like below, there are 3 steps, per x and y.

				   That means a total of 9 "taps", it touches the texture to sample 9 times.

				   Now imagine we apply this to some geometry, that is equal to 16 pixels on screen (tiny)
				   (16 * 16) * 9 = 2304 samples taken, for width * height number of pixels, * 9 taps
				   Now, if you split them up, it becomes 3 for x, and 3 for y, a total of 6 taps
				   (16 * 16) * 6 = 1536 samples

				   That\'s on a *tiny* sprite, let\'s scale that up to 128x128 sprite...
				   (128 * 128) * 9 = 147,456
				   (128 * 128) * 6 =  98,304

				   That\'s 33.33..% cheaper for splitting them up.
				   That\'s with 3 steps, with higher steps (more taps per pass...)

				   A really smooth, 6 steps, 6*6 = 36 taps for one pass, 12 taps for two pass
				   You will notice, the curve is not linear, at 12 steps it\'s 144 vs 24 taps
				   It becomes orders of magnitude slower to do single pass!
				   Therefore, you split them up into two passes, one for x, one for y.
			*/

		// I am hardcoding the constants like a jerk

		uniform float bluramount;
		uniform float center;
		const float stepSize    = 0.004;
		const float steps       = 3.0;

		const float minOffs     = (float(steps-1.0)) / -2.0;
		const float maxOffs     = (float(steps-1.0)) / +2.0;

		void main() {
			float amount;
			vec4 blurred;

			// Work out how much to blur based on the mid point
			amount = pow((openfl_TextureCoordv.y * center) * 2.0 - 1.0, 2.0) * bluramount;

			// This is the accumulation of color from the surrounding pixels in the texture
			blurred = vec4(0.0, 0.0, 0.0, 1.0);

			// From minimum offset to maximum offset
			for (float offsX = minOffs; offsX <= maxOffs; ++offsX) {
				for (float offsY = minOffs; offsY <= maxOffs; ++offsY) {

					// copy the coord so we can mess with it
					vec2 temp_tcoord = openfl_TextureCoordv.xy;

					//work out which uv we want to sample now
					temp_tcoord.x += offsX * amount * stepSize;
					temp_tcoord.y += offsY * amount * stepSize;

					// accumulate the sample
					blurred += texture2D(bitmap, temp_tcoord);
				}
			}

			// because we are doing an average, we divide by the amount (x AND y, hence steps * steps)
			blurred /= float(steps * steps);

			// return the final blurred color
			gl_FragColor = blurred;
		}')
  public function new()
  {
    super();
    bluramount.value = [1.0];
    center.value = [1.0];
  }
}

class GreyscaleEffect extends Effect
{
  public var shader:GreyscaleShader = new GreyscaleShader();

  public function new() {}
}

class GreyscaleShader extends FlxShader
{
  @:glFragmentSource('
	#pragma header
	void main() {
		vec4 color = texture2D(bitmap, openfl_TextureCoordv);
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		gl_FragColor = vec4(vec3(gray), color.a);
	}


	')
  public function new()
  {
    super();
  }
}

class GrainEffect extends Effect
{
  public var shader:Grain;

  public function new(grainsize, lumamount, lockAlpha)
  {
    shader = new Grain();
    shader.lumamount.value = [lumamount];
    shader.grainsize.value = [grainsize];
    shader.lockAlpha.value = [lockAlpha];
    shader.uTime.value = [FlxG.random.float(0, 8)];
    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed)
  {
    shader.uTime.value[0] += elapsed;
  }
}

class Grain extends FlxShader
{
  @:glFragmentSource('
		#pragma header

		/*
		Film Grain post-process shader v1.1
		Martins Upitis (martinsh) devlog-martinsh.blogspot.com
		2013

		--------------------------
		This work is licensed under a Creative Commons Attribution 3.0 Unported License.
		So you are free to share, modify and adapt it for your needs, and even use it for commercial use.
		I would also love to hear about a project you are using it.

		Have fun,
		Martins
		--------------------------

		Perlin noise shader by toneburst:
		http://machinesdontcare.wordpress.com/2009/06/25/3d-perlin-noise-sphere-vertex-shader-sourcecode/
		*/
		uniform float uTime;

		const float permTexUnit = 1.0/256.0;        // Perm texture texel-size
		const float permTexUnitHalf = 0.5/256.0;    // Half perm texture texel-size

		float width = openfl_TextureSize.x;
		float height = openfl_TextureSize.y;

		const float grainamount = 0.05; //grain amount
		bool colored = false; //colored noise?
		uniform float coloramount;
		uniform float grainsize; //grain particle size (1.5 - 2.5)
		uniform float lumamount; //
	uniform bool lockAlpha;

		//a random texture generator, but you can also use a pre-computed perturbation texture

		vec4 rnm(in vec2 tc)
		{
			float noise =  sin(dot(tc + vec2(uTime,uTime),vec2(12.9898,78.233))) * 43758.5453;

			float noiseR =  fract(noise)*2.0-1.0;
			float noiseG =  fract(noise*1.2154)*2.0-1.0;
			float noiseB =  fract(noise * 1.3453) * 2.0 - 1.0;

			float noiseA =  (fract(noise * 1.3647) * 2.0 - 1.0);

			return vec4(noiseR,noiseG,noiseB,noiseA);
		}

		float fade(in float t) {
			return t*t*t*(t*(t*6.0-15.0)+10.0);
		}

		float pnoise3D(in vec3 p)
		{
			vec3 pi = permTexUnit*floor(p)+permTexUnitHalf; // Integer part, scaled so +1 moves permTexUnit texel
			// and offset 1/2 texel to sample texel centers
			vec3 pf = fract(p);     // Fractional part for interpolation

			// Noise contributions from (x=0, y=0), z=0 and z=1
			float perm00 = rnm(pi.xy).a ;
			vec3  grad000 = rnm(vec2(perm00, pi.z)).rgb * 4.0 - 1.0;
			float n000 = dot(grad000, pf);
			vec3  grad001 = rnm(vec2(perm00, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
			float n001 = dot(grad001, pf - vec3(0.0, 0.0, 1.0));

			// Noise contributions from (x=0, y=1), z=0 and z=1
			float perm01 = rnm(pi.xy + vec2(0.0, permTexUnit)).a ;
			vec3  grad010 = rnm(vec2(perm01, pi.z)).rgb * 4.0 - 1.0;
			float n010 = dot(grad010, pf - vec3(0.0, 1.0, 0.0));
			vec3  grad011 = rnm(vec2(perm01, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
			float n011 = dot(grad011, pf - vec3(0.0, 1.0, 1.0));

			// Noise contributions from (x=1, y=0), z=0 and z=1
			float perm10 = rnm(pi.xy + vec2(permTexUnit, 0.0)).a ;
			vec3  grad100 = rnm(vec2(perm10, pi.z)).rgb * 4.0 - 1.0;
			float n100 = dot(grad100, pf - vec3(1.0, 0.0, 0.0));
			vec3  grad101 = rnm(vec2(perm10, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
			float n101 = dot(grad101, pf - vec3(1.0, 0.0, 1.0));

			// Noise contributions from (x=1, y=1), z=0 and z=1
			float perm11 = rnm(pi.xy + vec2(permTexUnit, permTexUnit)).a ;
			vec3  grad110 = rnm(vec2(perm11, pi.z)).rgb * 4.0 - 1.0;
			float n110 = dot(grad110, pf - vec3(1.0, 1.0, 0.0));
			vec3  grad111 = rnm(vec2(perm11, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
			float n111 = dot(grad111, pf - vec3(1.0, 1.0, 1.0));

			// Blend contributions along x
			vec4 n_x = mix(vec4(n000, n001, n010, n011), vec4(n100, n101, n110, n111), fade(pf.x));

			// Blend contributions along y
			vec2 n_xy = mix(n_x.xy, n_x.zw, fade(pf.y));

			// Blend contributions along z
			float n_xyz = mix(n_xy.x, n_xy.y, fade(pf.z));

			// We are done, return the final noise value.
			return n_xyz;
		}

		//2d coordinate orientation thing
		vec2 coordRot(in vec2 tc, in float angle)
		{
			float aspect = width/height;
			float rotX = ((tc.x*2.0-1.0)*aspect*cos(angle)) - ((tc.y*2.0-1.0)*sin(angle));
			float rotY = ((tc.y*2.0-1.0)*cos(angle)) + ((tc.x*2.0-1.0)*aspect*sin(angle));
			rotX = ((rotX/aspect)*0.5+0.5);
			rotY = rotY*0.5+0.5;
			return vec2(rotX,rotY);
		}

		void main()
		{
			vec2 texCoord = openfl_TextureCoordv.st;

			vec3 rotOffset = vec3(1.425,3.892,5.835); //rotation offset values
			vec2 rotCoordsR = coordRot(texCoord, uTime + rotOffset.x);
			vec3 noise = vec3(pnoise3D(vec3(rotCoordsR*vec2(width/grainsize,height/grainsize),0.0)));

			if (colored)
			{
				vec2 rotCoordsG = coordRot(texCoord, uTime + rotOffset.y);
				vec2 rotCoordsB = coordRot(texCoord, uTime + rotOffset.z);
				noise.g = mix(noise.r,pnoise3D(vec3(rotCoordsG*vec2(width/grainsize,height/grainsize),1.0)),coloramount);
				noise.b = mix(noise.r,pnoise3D(vec3(rotCoordsB*vec2(width/grainsize,height/grainsize),2.0)),coloramount);
			}

			vec3 col = texture2D(bitmap, openfl_TextureCoordv).rgb;

			//noisiness response curve based on scene luminance
			vec3 lumcoeff = vec3(0.299,0.587,0.114);
			float luminance = mix(0.0,dot(col, lumcoeff),lumamount);
			float lum = smoothstep(0.2,0.0,luminance);
			lum += luminance;

			noise = mix(noise,vec3(0.0),pow(lum,4.0));
			col = col+noise*grainamount;

				float bitch = 1.0;
			vec4 texColor = texture2D(bitmap, openfl_TextureCoordv);
				if (lockAlpha) bitch = texColor.a;
			gl_FragColor =  vec4(col,bitch);
		}')
  public function new()
  {
    super();
    coloramount.value = [0.6];
    lockAlpha.value = [false];
  }
}

class VCRDistortionEffect extends Effect
{
  public var shader:VCRDistortionShader = new VCRDistortionShader();

  public function new(glitchFactor:Float, distortion:Bool = true, perspectiveOn:Bool = true, vignetteMoving:Bool = true)
  {
    shader.iTime.value = [0.0];
    shader.vignetteOn.value = [true];
    shader.perspectiveOn.value = [perspectiveOn];
    shader.distortionOn.value = [distortion];
    shader.scanlinesOn.value = [true];
    shader.vignetteMoving.value = [vignetteMoving];
    shader.glitchModifier.value = [glitchFactor];
    shader.iResolution.value = [Lib.current.stage.stageWidth, Lib.current.stage.stageHeight];
    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed:Float)
  {
    shader.iTime.value[0] += elapsed;
    shader.iResolution.value = [Lib.current.stage.stageWidth, Lib.current.stage.stageHeight];
  }

  public function setVignette(state:Bool)
  {
    shader.vignetteOn.value[0] = state;
  }

  public function setPerspective(state:Bool)
  {
    shader.perspectiveOn.value[0] = state;
  }

  public function setGlitchModifier(modifier:Float)
  {
    shader.glitchModifier.value[0] = modifier;
  }

  public function setDistortion(state:Bool)
  {
    shader.distortionOn.value[0] = state;
  }

  public function setScanlines(state:Bool)
  {
    shader.scanlinesOn.value[0] = state;
  }

  public function setVignetteMoving(state:Bool)
  {
    shader.vignetteMoving.value[0] = state;
  }
}

class VCRDistortionShader extends FlxShader // https://www.shadertoy.com/view/ldjGzV and https://www.shadertoy.com/view/Ms23DR and https://www.shadertoy.com/view/MsXGD4 and https://www.shadertoy.com/view/Xtccz4
{
  @:glFragmentSource('
    #pragma header

    uniform float iTime;
    uniform bool vignetteOn;
    uniform bool perspectiveOn;
    uniform bool distortionOn;
    uniform bool scanlinesOn;
    uniform bool vignetteMoving;
    uniform float glitchModifier;
    uniform vec3 iResolution;

    float onOff(float a, float b, float c)
    {
    	return step(c, sin(iTime + a*cos(iTime*b)));
    }

    float ramp(float y, float start, float end)
    {
    	float inside = step(start,y) - step(end,y);
    	float fact = (y-start)/(end-start)*inside;
    	// FIX: 1. -> 1.0
    	return (1.0-fact) * inside;
    }

    vec4 getVideo(vec2 uv)
    {
    	vec2 look = uv;
        if(distortionOn){
        	// FIX: 1./(1.+20.*... -> 1.0/(1.0+20.0*..., mod(iTime/4.,1.) -> mod(iTime/4.0,1.0)
        	float window = 1.0/(1.0+20.0*(look.y-mod(iTime/4.0,1.0))*(look.y-mod(iTime/4.0,1.0)));
        	// FIX: 10. -> 10.0, /50. -> /50.0, onOff(4.,4.,.3) -> onOff(4.0,4.0,0.3), 1.+ -> 1.0+, *2) -> *2.0)
        	look.x = look.x + (sin(look.y*10.0 + iTime)/50.0*onOff(4.0,4.0,0.3)*(1.0+cos(iTime*80.0))*window)*(glitchModifier*2.0);
        	// FIX: onOff(2.,3.,.9) -> onOff(2.0,3.0,0.9)
        	float vShift = 0.4*onOff(2.0,3.0,0.9)*(sin(iTime)*sin(iTime*20.0) +
        									 (0.5 + 0.1*sin(iTime*200.0)*cos(iTime)));
        	// FIX: mod(..., 1.) -> mod(..., 1.0)
        	look.y = mod(look.y + vShift*glitchModifier, 1.0);
        }
    	vec4 video = flixel_texture2D(bitmap,look);
    	return video;
    }

    vec2 screenDistort(vec2 uv)
    {
      if(perspectiveOn){
        uv = (uv - 0.5) * 2.0;
      	uv *= 1.1;
      	uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
      	uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
      	uv  = (uv / 2.0) + 0.5;
      	uv =  uv *0.92 + 0.04;
      	return uv;
      }
    	return uv;
    }

    float random(vec2 uv)
    {
     	return fract(sin(dot(uv, vec2(15.5151, 42.2561))) * 12341.14122 * sin(iTime * 0.03));
    }

    float noise(vec2 uv)
    {
     	vec2 i = floor(uv);
        vec2 f = fract(uv);

        float a = random(i);
        // FIX: vec2(1.,0.) -> vec2(1.0,0.0), vec2(0.,1.) -> vec2(0.0,1.0), vec2(1.) -> vec2(1.0)
        float b = random(i + vec2(1.0, 0.0));
    	float c = random(i + vec2(0.0, 1.0));
        float d = random(i + vec2(1.0));

        // FIX: smoothstep(0.,1.,f) -> smoothstep(0.0,1.0,f)
        vec2 u = smoothstep(0.0, 1.0, f);

        return mix(a,b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    }

    vec2 scandistort(vec2 uv) {
    	float scan1 = clamp(cos(uv.y * 2.0 + iTime), 0.0, 1.0);
    	float scan2 = clamp(cos(uv.y * 2.0 + iTime + 4.0) * 10.0, 0.0, 1.0);
    	float amount = scan1 * scan2 * uv.x;
    	return uv;
    }

    void main()
    {
    	vec2 uv = openfl_TextureCoordv;
      vec2 curUV = screenDistort(uv);
    	uv = scandistort(curUV);
    	vec4 video = getVideo(uv);
      float vigAmt = 1.0;
      // FIX: 0. -> 0.0
      float x = 0.0;

      video.r = getVideo(vec2(x+uv.x+0.001,uv.y+0.001)).x+0.05;
      video.g = getVideo(vec2(x+uv.x+0.000,uv.y-0.002)).y+0.05;
      video.b = getVideo(vec2(x+uv.x-0.002,uv.y+0.000)).z+0.05;
      video.r += 0.08*getVideo(0.75*vec2(x+0.025, -0.027)+vec2(uv.x+0.001,uv.y+0.001)).x;
      // FIX: x+-0.022 -> x-0.022 (invalid operator combination)
      video.g += 0.05*getVideo(0.75*vec2(x-0.022, -0.02)+vec2(uv.x+0.000,uv.y-0.002)).y;
      // FIX: x+-0.02 -> x-0.02 (invalid operator combination)
      video.b += 0.08*getVideo(0.75*vec2(x-0.02, -0.018)+vec2(uv.x-0.002,uv.y+0.000)).z;

      video = clamp(video*0.6+0.4*video*video*1.0,0.0,1.0);
      if(vignetteMoving)
    	  // FIX: 3.+ -> 3.0+, .3* -> 0.3*, 5.* -> 5.0*, iTime*5. -> iTime*5.0
    	  vigAmt = 3.0+0.3*sin(iTime + 5.0*cos(iTime*5.0));

    	// FIX: 1.- -> 1.0-, .5 -> 0.5
    	float vignette = (1.0-vigAmt*(uv.y-0.5)*(uv.y-0.5))*(1.0-vigAmt*(uv.x-0.5)*(uv.x-0.5));

      if(vignetteOn)
    	 video *= vignette;

      // FIX: 75. -> 75.0, .05 -> 0.05
      gl_FragColor = mix(video, vec4(noise(uv * 75.0)), 0.05);

      // FIX: <0 -> <0.0, >1 -> >1.0 (integer comparisons with float)
      if(curUV.x<0.0 || curUV.x>1.0 || curUV.y<0.0 || curUV.y>1.0){
        // FIX: vec4(0,0,0,0) -> vec4(0.0,0.0,0.0,0.0) (integer args in vector constructor)
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
      }
    }
  ')
  public function new()
  {
    super();
  }
}

/*class VHSFilterAccurate extends FlxShader {
  @:glFragmentSource('// Automatically converted with https://github.com/TheLeerName/ShadertoyToFlixel
  // https://www.shadertoy.com/view/NdccR2

  #pragma header

  #define iResolution vec3(openfl_TextureSize, 0.)
  #define iChannel0 bitmap
  #define texture flixel_texture2D

  // end of ShadertoyToFlixel header

  #define PI 3.141592654f

  vec3 RGB_to_YIQ(vec3 RGB)
  {
    return mat3
    (
        0.299f, 0.587f, 0.114f,
        0.596f, -0.275f, -0.321f,
        0.212f, -0.523f, 0.311f
    ) * RGB;
  }

  vec3 YIQ_to_RGB(vec3 YIQ)
  {
    return mat3
    (
        1.f, 0.956f, 0.619f,
        1.f, -0.272f, -0.647f,
        1.f, -1.106f, 1.703f
    ) * YIQ;
  }

  // Converts color from RGB to YIQ, blur the I and Q, then apply a dot crawl effect
  vec3 VHS_effect(vec2 fragCoord, float color_fuckery)
  {
    vec2    IQ = vec2(0,0),
            blur_size = vec2(16, 4),
            focal_point = blur_size * 0.5f;

    float   smear_factor = blur_size.x * blur_size.y;

    vec2    UV_Y = fragCoord / iResolution.xy;

    // IQ blur
    for (int i = 0; i < int(smear_factor); i++)
    {
        vec2 uv_prime = vec2
        (
            (fragCoord.x + float(i % int(blur_size.x)) - focal_point.x) / iResolution.x,
            (fragCoord.y + float(i / int(blur_size.y)) - focal_point.y) / iResolution.y
        );
        IQ += RGB_to_YIQ(texture(iChannel0, uv_prime).xyz).yz;
    }
    IQ /= smear_factor;

    vec3 color = vec3
    (
        RGB_to_YIQ(texture(iChannel0, UV_Y).xyz).r,
        IQ * (1.f + color_fuckery)
    );

    // NTSC Dot Crawl
    color.x += (IQ.x*sin((fragCoord.x))) *
               (IQ.y*sin( fragCoord.y * PI * 0.5f));

    color = YIQ_to_RGB(color);

    return color;
  }



  void mainImage( out vec4 fragColor, in vec2 fragCoord )
  {
    //fragColor = vec4(vec3(sin(fragCoord.x)), texture(iChannel0, fragCoord / iResolution.xy).a);
    fragColor = vec4(VHS_effect(fragCoord, 0.2f),1.0);
    //fragColor = texture(iChannel0, fragCoord / iResolution.xy);
  }

  void main() {
  mainImage(gl_FragColor, openfl_TextureCoordv*openfl_TextureSize);
  }')
  public function new(lockAlpha:Bool)
  {
    super();
  }
}*/

class ThreeDEffect extends Effect
{
  public var shader:ThreeDShader = new ThreeDShader();

  public function new(xrotation:Float = 0, yrotation:Float = 0, zrotation:Float = 0, depth:Float = 0)
  {
    shader.xrot.value = [xrotation];
    shader.yrot.value = [yrotation];
    shader.zrot.value = [zrotation];
    shader.dept.value = [depth];
  }
}

// coding is like hitting on women, you never start with the number
//               -naether

class ThreeDShader extends FlxShader
{
  @:glFragmentSource('
	#pragma header
	uniform float xrot;
	uniform float yrot;
	uniform float zrot;
	uniform float dept;
	// FIX: float alph = 0 -> float alph = 0.0 (integer init for float)
	float alph = 0.0;

float plane( in vec3 norm, in vec3 po, in vec3 ro, in vec3 rd ) {
    float de = dot(norm, rd);
    de = sign(de)*max( abs(de), 0.001);
    return dot(norm, po-ro)/de;
}

vec2 raytraceTexturedQuad(in vec3 rayOrigin, in vec3 rayDirection, in vec3 quadCenter, in vec3 quadRotation, in vec2 quadDimensions) {
    //Rotations ------------------
    float a = sin(quadRotation.x); float b = cos(quadRotation.x);
    float c = sin(quadRotation.y); float d = cos(quadRotation.y);
    float e = sin(quadRotation.z); float f = cos(quadRotation.z);
    float ac = a*c;   float bc = b*c;

	mat3 RotationMatrix  =
			mat3(	  d*f,      d*e,  -c,
                 ac*f-b*e, ac*e+b*f, a*d,
                 bc*f+a*e, bc*e-a*f, b*d );
    //--------------------------------------

    vec3 right = RotationMatrix * vec3(quadDimensions.x, 0.0, 0.0);
    // FIX: vec3(0, quadDimensions.y, 0) -> vec3(0.0, quadDimensions.y, 0.0) (integer args in vector constructor)
    vec3 up = RotationMatrix * vec3(0.0, quadDimensions.y, 0.0);
    vec3 normal = cross(right, up);
    normal /= length(normal);

    //Find the plane hit point in space
    vec3 pos = (rayDirection * plane(normal, quadCenter, rayOrigin, rayDirection)) - quadCenter;

    //Find the texture UV by projecting the hit point along the plane dirs
    return vec2(dot(pos, right) / dot(right, right),
                dot(pos, up)    / dot(up,    up)) + 0.5;
}

void main() {
	vec4 texColor = texture2D(bitmap, openfl_TextureCoordv);
    //Screen UV goes from 0 - 1 along each axis
    vec2 screenUV = openfl_TextureCoordv;
    vec2 p = (2.0 * screenUV) - 1.0;
    // FIX: 1280/720 -> 1280.0/720.0 (integer division would give wrong result)
    float screenAspect = 1280.0/720.0;
    p.x *= screenAspect;

    //Normalized Ray Dir
    vec3 dir = vec3(p.x, p.y, 1.0);
    dir /= length(dir);

    //Define the plane
    vec3 planePosition = vec3(0.0, 0.0, dept);
    vec3 planeRotation = vec3(xrot, yrot, zrot);//this the shit you needa change
    vec2 planeDimension = vec2(-screenAspect, 1.0);

    // FIX: vec3(0) -> vec3(0.0, 0.0, 0.0) (integer arg in vector constructor)
    vec2 uv = raytraceTexturedQuad(vec3(0.0, 0.0, 0.0), dir, planePosition, planeRotation, planeDimension);

    //If we hit the rectangle, sample the texture
    if (abs(uv.x - 0.5) < 0.5 && abs(uv.y - 0.5) < 0.5) {

		vec3 tex = flixel_texture2D(bitmap, uv).xyz;
		float bitch = 1.0;
		if (tex.z == 0.0){
			bitch = 0.0;
		}

	  gl_FragColor = vec4(flixel_texture2D(bitmap, uv).xyz, bitch);
    }
}


	')
  public function new()
  {
    super();
    xrot.value = [0.0];
    yrot.value = [0.0];
    zrot.value = [0.0];
    dept.value = [0.0];
  }
}

// Boing! by ThaeHan

class FuckingTriangleEffect extends Effect
{
  public var shader:FuckingTriangle = new FuckingTriangle();

  public function new(rotx:Float, roty:Float)
  {
    shader.rotX.value = [rotx];
    shader.rotY.value = [roty];
  }
}

class FuckingTriangle extends FlxShader
{
  // FIX: removed const arrays (arrays unsupported on some platforms)
  // FIX: removed default values from uniforms
  // FIX: replaced arrays with getVertex/getTexCoord lookup functions using if-else
  // FIX: unrolled the for loop (used arrays internally, now gone)
  // FIX: fixed many half-float literals
  @:glFragmentSource('

			#pragma header

			// FIX: replaced vec3 vertices[18] and vec2 texCoords[18] arrays with lookup functions
			vec3 getVertex(int idx) {
				if (idx == 0)  return vec3(-0.5, 0.0, -0.5);
				if (idx == 1)  return vec3( 0.5, 0.0, -0.5);
				if (idx == 2)  return vec3(-0.5, 0.0,  0.5);
				if (idx == 3)  return vec3(-0.5, 0.0,  0.5);
				if (idx == 4)  return vec3( 0.5, 0.0, -0.5);
				if (idx == 5)  return vec3( 0.5, 0.0,  0.5);
				if (idx == 6)  return vec3(-0.5, 0.0, -0.5);
				if (idx == 7)  return vec3( 0.5, 0.0, -0.5);
				if (idx == 8)  return vec3( 0.0, 1.0,  0.0);
				if (idx == 9)  return vec3(-0.5, 0.0,  0.5);
				if (idx == 10) return vec3( 0.5, 0.0,  0.5);
				if (idx == 11) return vec3( 0.0, 1.0,  0.0);
				if (idx == 12) return vec3(-0.5, 0.0, -0.5);
				if (idx == 13) return vec3(-0.5, 0.0,  0.5);
				if (idx == 14) return vec3( 0.0, 1.0,  0.0);
				if (idx == 15) return vec3( 0.5, 0.0, -0.5);
				if (idx == 16) return vec3( 0.5, 0.0,  0.5);
				if (idx == 17) return vec3( 0.0, 1.0,  0.0);
				return vec3(0.0, 0.0, 0.0);
			}

			// FIX: all half-float literals in texCoords expanded (e.g. 0. -> 0.0, 1. -> 1.0, .5 -> 0.5)
			vec2 getTexCoord(int idx) {
				if (idx == 0)  return vec2(0.0, 1.0);
				if (idx == 1)  return vec2(1.0, 1.0);
				if (idx == 2)  return vec2(0.0, 0.0);
				if (idx == 3)  return vec2(0.0, 0.0);
				if (idx == 4)  return vec2(1.0, 1.0);
				if (idx == 5)  return vec2(1.0, 0.0);
				if (idx == 6)  return vec2(0.0, 1.0);
				if (idx == 7)  return vec2(1.0, 1.0);
				if (idx == 8)  return vec2(0.5, 0.0);
				if (idx == 9)  return vec2(0.0, 1.0);
				if (idx == 10) return vec2(1.0, 1.0);
				if (idx == 11) return vec2(0.5, 0.0);
				if (idx == 12) return vec2(0.0, 1.0);
				if (idx == 13) return vec2(1.0, 1.0);
				if (idx == 14) return vec2(0.5, 0.0);
				if (idx == 15) return vec2(0.0, 1.0);
				if (idx == 16) return vec2(1.0, 1.0);
				if (idx == 17) return vec2(0.5, 0.0);
				return vec2(0.0, 0.0);
			}

			vec4 vertexShader(in vec3 vertex, in mat4 transform) {
				// FIX: 1. -> 1.0
				return transform * vec4(vertex, 1.0);
			}

			vec4 fragmentShader(in vec2 uv) {
				return flixel_texture2D(bitmap, uv);
			}

			const float fov  = 70.0;
			const float near = 0.1;
			// FIX: 10. -> 10.0
			const float far  = 10.0;

			// FIX: vec3(0., 0.3, 2.) -> vec3(0.0, 0.3, 2.0)
			const vec3 cameraPos = vec3(0.0, 0.3, 2.0);

			// FIX: removed default values from uniforms, removed -25. -> will be set in constructor
			uniform float rotX;
			uniform float rotY;

			vec4 pixel(in vec2 ndc, in float aspect, inout float depth, in int vertexIndex) {
				mat4 proj  = perspective(fov, aspect, near, far);
				mat4 view  = translate(-cameraPos);
				mat4 model = rotateX(rotX) * rotateY(rotY);
				mat4 mvp  = proj * view * model;

				// FIX: use getVertex/getTexCoord instead of array indexing
				vec4 v0 = vertexShader(getVertex(vertexIndex  ), mvp);
				vec4 v1 = vertexShader(getVertex(vertexIndex+1), mvp);
				vec4 v2 = vertexShader(getVertex(vertexIndex+2), mvp);

				// FIX: 1. / v0.w -> 1.0 / v0.w
				vec2 t0 = getTexCoord(vertexIndex  ) / v0.w; float oow0 = 1.0 / v0.w;
				vec2 t1 = getTexCoord(vertexIndex+1) / v1.w; float oow1 = 1.0 / v1.w;
				vec2 t2 = getTexCoord(vertexIndex+2) / v2.w; float oow2 = 1.0 / v2.w;

				v0 /= v0.w;
				v1 /= v1.w;
				v2 /= v2.w;

				vec3 tri = bary(v0.xy, v1.xy, v2.xy, ndc);

				// FIX: 0. -> 0.0, 1. -> 1.0
				if(tri.x < 0.0 || tri.x > 1.0 || tri.y < 0.0 || tri.y > 1.0 || tri.z < 0.0 || tri.z > 1.0) {
					// FIX: vec4(0.) -> vec4(0.0)
					return vec4(0.0);
				}

				float triDepth = baryLerp(v0.z, v1.z, v2.z, tri);
				// FIX: -1. -> -1.0, 1. -> 1.0
				if(triDepth > depth || triDepth < -1.0 || triDepth > 1.0) {
					return vec4(0.0);
				}

				depth = triDepth;

				float oneOverW = baryLerp(oow0, oow1, oow2, tri);
				vec2 uv        = uvLerp(t0, t1, t2, tri) / oneOverW;
				return fragmentShader(uv);
			}

void main()
{
    // FIX: 2. -> 2.0, vec2(1.) -> vec2(1.0)
    vec2 ndc = ((gl_FragCoord.xy * 2.0) / openfl_TextureSize.xy) - vec2(1.0);
    float aspect = openfl_TextureSize.x / openfl_TextureSize.y;
    // FIX: vec3(.4,.6,.9) -> vec3(0.4, 0.6, 0.9)
    vec3 outColor = vec3(0.4, 0.6, 0.9);

    float depth = 1.0;

    // FIX: replaced for(int i = 0; i < 18; i += 3) loop with unrolled calls
    // (loop used array indexing which is now replaced with getVertex/getTexCoord)
    vec4 triResult0 = pixel(ndc, aspect, depth, 0);
    outColor = mix(outColor.rgb, triResult0.rgb, triResult0.a);
    vec4 triResult1 = pixel(ndc, aspect, depth, 3);
    outColor = mix(outColor.rgb, triResult1.rgb, triResult1.a);
    vec4 triResult2 = pixel(ndc, aspect, depth, 6);
    outColor = mix(outColor.rgb, triResult2.rgb, triResult2.a);
    vec4 triResult3 = pixel(ndc, aspect, depth, 9);
    outColor = mix(outColor.rgb, triResult3.rgb, triResult3.a);
    vec4 triResult4 = pixel(ndc, aspect, depth, 12);
    outColor = mix(outColor.rgb, triResult4.rgb, triResult4.a);
    vec4 triResult5 = pixel(ndc, aspect, depth, 15);
    outColor = mix(outColor.rgb, triResult5.rgb, triResult5.a);

    // FIX: 1. -> 1.0
    gl_FragColor = vec4(outColor, 1.0);
}



	')
  public function new()
  {
    super();
    rotX.value = [-25.0];
    rotY.value = [45.0];
  }
}

class BloomEffect extends Effect
{
  public var shader:BloomShader = new BloomShader();

  public function new(blurSize:Float, intensity:Float)
  {
    shader.blurSize.value = [blurSize];
    shader.intensity.value = [intensity];
  }
}

class BloomShader extends FlxShader
{
  @:glFragmentSource('

	#pragma header

	uniform float intensity;
	uniform float blurSize;

void main()
{
   // FIX: vec4(0) -> vec4(0.0) (integer arg in vector constructor)
   vec4 sum = vec4(0.0);
   vec2 texcoord = openfl_TextureCoordv;
   // FIX: removed unused int j; int i; declarations

   //thank you! http://www.gamerendering.com/2008/10/11/gaussian-blur-filter-shader/ for the
   //blur tutorial
   // blur in y (vertical)
   // take nine samples, with the distance blurSize between them
   sum += flixel_texture2D(bitmap, vec2(texcoord.x - 4.0*blurSize, texcoord.y)) * 0.05;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x - 3.0*blurSize, texcoord.y)) * 0.09;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x - 2.0*blurSize, texcoord.y)) * 0.12;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x - blurSize, texcoord.y)) * 0.15;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y)) * 0.16;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x + blurSize, texcoord.y)) * 0.15;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x + 2.0*blurSize, texcoord.y)) * 0.12;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x + 3.0*blurSize, texcoord.y)) * 0.09;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x + 4.0*blurSize, texcoord.y)) * 0.05;

	// blur in y (vertical)
   // take nine samples, with the distance blurSize between them
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y - 4.0*blurSize)) * 0.05;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y - 3.0*blurSize)) * 0.09;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y - 2.0*blurSize)) * 0.12;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y - blurSize)) * 0.15;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y)) * 0.16;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y + blurSize)) * 0.15;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y + 2.0*blurSize)) * 0.12;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y + 3.0*blurSize)) * 0.09;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y + 4.0*blurSize)) * 0.05;

   //increase blur with intensity!
  gl_FragColor = sum*intensity + flixel_texture2D(bitmap, texcoord);
}


	')
  public function new()
  {
    super();
    intensity.value = [0.35];
    blurSize.value = [1.0 / 512.0];
  }
}

/*STOLE FROM DAVE AND BAMBI

  I LOVE BANUUU I LOVE BANUUU
    ________
   /        \
  _/__________\_
  ||  o||  o||
  |//--  --//|
   \____O___/
    |      |
    |______|
    |   |  |
    |___|__|


 */
class GlitchEffect extends Effect
{
  public var shader:GlitchShader = new GlitchShader();

  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;

  public function new(waveSpeed:Float, waveFrequency:Float, waveAmplitude:Float):Void
  {
    shader.uTime.value = [0.0];
    this.waveSpeed = waveSpeed;
    this.waveFrequency = waveFrequency;
    this.waveAmplitude = waveAmplitude;
    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed:Float):Void
  {
    shader.uTime.value[0] += elapsed;
  }

  function set_waveSpeed(v:Float):Float
  {
    waveSpeed = v;
    shader.uSpeed.value = [waveSpeed];
    return v;
  }

  function set_waveFrequency(v:Float):Float
  {
    waveFrequency = v;
    shader.uFrequency.value = [waveFrequency];
    return v;
  }

  function set_waveAmplitude(v:Float):Float
  {
    waveAmplitude = v;
    shader.uWaveAmplitude.value = [waveAmplitude];
    return v;
  }
}

class DistortBGEffect extends Effect
{
  public var shader:DistortBGShader = new DistortBGShader();

  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;

  public function new(waveSpeed:Float, waveFrequency:Float, waveAmplitude:Float):Void
  {
    this.waveSpeed = waveSpeed;
    this.waveFrequency = waveFrequency;
    this.waveAmplitude = waveAmplitude;
    shader.uTime.value = [0.0];
    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed:Float):Void
  {
    shader.uTime.value[0] += elapsed;
  }

  function set_waveSpeed(v:Float):Float
  {
    waveSpeed = v;
    shader.uSpeed.value = [waveSpeed];
    return v;
  }

  function set_waveFrequency(v:Float):Float
  {
    waveFrequency = v;
    shader.uFrequency.value = [waveFrequency];
    return v;
  }

  function set_waveAmplitude(v:Float):Float
  {
    waveAmplitude = v;
    shader.uWaveAmplitude.value = [waveAmplitude];
    return v;
  }
}

class PulseEffectAlt
{
  public var shader(default, null):PulseShader;

  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;
  public var enabled(default, set):Bool = false;

  public function new():Void
  {
    shader = new PulseShader();
    shader.speed = 0;
    shader.frequency = 0;
    shader.waveAmplitude = 0;
    shader.enabled = false;
  }

  public function update(elapsed:Float):Void
  {
    shader.update(elapsed);
  }

  function set_waveSpeed(v:Float):Float
  {
    waveSpeed = v;
    shader.speed = v;
    return v;
  }

  function set_enabled(v:Bool):Bool
  {
    enabled = v;
    shader.enabled = v;
    return v;
  }

  function set_waveFrequency(v:Float):Float
  {
    waveFrequency = v;
    shader.frequency = v;
    return v;
  }

  function set_waveAmplitude(v:Float):Float
  {
    waveAmplitude = v;
    shader.waveAmplitude = v;
    return v;
  }
}

class PulseEffect extends Effect
{
  public var shader:PulseShader;

  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;
  public var enabled(default, set):Bool = false;

  public function new(waveSpeed:Float, waveFrequency:Float, waveAmplitude:Float):Void
  {
    shader = new PulseShader();

    this.waveSpeed = waveSpeed;
    this.waveFrequency = waveFrequency;
    this.waveAmplitude = waveAmplitude;
    this.enabled = false;

    // PulseShader constructor already sets defaults,
    // but we override with our specific values
    shader.speed = waveSpeed;
    shader.frequency = waveFrequency;
    shader.waveAmplitude = waveAmplitude;
    shader.enabled = false;
    shader.time = 0;

    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed:Float):Void
  {
    shader.update(elapsed);
  }

  function set_waveSpeed(v:Float):Float
  {
    waveSpeed = v;
    shader.speed = v;
    return v;
  }

  function set_enabled(v:Bool):Bool
  {
    enabled = v;
    shader.enabled = v;
    return v;
  }

  function set_waveFrequency(v:Float):Float
  {
    waveFrequency = v;
    shader.frequency = v;
    return v;
  }

  function set_waveAmplitude(v:Float):Float
  {
    waveAmplitude = v;
    shader.waveAmplitude = v;
    return v;
  }
}

class InvertColorsEffect extends Effect
{
  public var shader:InvertShader = new InvertShader();

  public function new(lockAlpha)
  {
    //	shader.lockAlpha.value = [lockAlpha];
  }
}

class GlitchShader extends FlxShader
{
  @:glFragmentSource('
    #pragma header
    //uniform float tx, ty; // x,y waves phase

    //modified version of the wave shader to create weird garbled corruption like messes
    uniform float uTime;

    /**
     * How fast the waves move over time
     */
    uniform float uSpeed;

    /**
     * Number of waves over time
     */
    uniform float uFrequency;

    /**
     * How much the pixels are going to stretch over the waves
     */
    uniform float uWaveAmplitude;

    vec2 sineWave(vec2 pt)
    {
        float x = 0.0;
        float y = 0.0;

        float offsetX = sin(pt.y * uFrequency + uTime * uSpeed) * (uWaveAmplitude / pt.x * pt.y);
        float offsetY = sin(pt.x * uFrequency - uTime * uSpeed) * (uWaveAmplitude / pt.y * pt.x);
        pt.x += offsetX; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
        pt.y += offsetY;

        return vec2(pt.x + x, pt.y + y);
    }

    void main()
    {
        vec2 uv = sineWave(openfl_TextureCoordv);
        gl_FragColor = texture2D(bitmap, uv);
    }')
  public function new()
  {
    super();
  }
}

class InvertShader extends FlxShader
{
  @:glFragmentSource('
    #pragma header

    vec4 sineWave(vec4 pt)
    {

	return vec4(1.0 - pt.x, 1.0 - pt.y, 1.0 - pt.z, pt.w);
    }

    void main()
    {
        vec2 uv = openfl_TextureCoordv;
        gl_FragColor = sineWave(texture2D(bitmap, uv));
		gl_FragColor.a = 1.0 - gl_FragColor.a;
    }')
  public function new()
  {
    super();
  }
}

class DistortBGShader extends FlxShader
{
  @:glFragmentSource('
    #pragma header
    //uniform float tx, ty; // x,y waves phase

    //gives the character a glitchy, distorted outline
    uniform float uTime;

    /**
     * How fast the waves move over time
     */
    uniform float uSpeed;

    /**
     * Number of waves over time
     */
    uniform float uFrequency;

    /**
     * How much the pixels are going to stretch over the waves
     */
    uniform float uWaveAmplitude;

    vec2 sineWave(vec2 pt)
    {
        float x = 0.0;
        float y = 0.0;

        float offsetX = sin(pt.x * uFrequency + uTime * uSpeed) * (uWaveAmplitude / pt.x * pt.y);
        float offsetY = sin(pt.y * uFrequency - uTime * uSpeed) * (uWaveAmplitude);
        pt.x += offsetX; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
        pt.y += offsetY;

        return vec2(pt.x + x, pt.y + y);
    }

    vec4 makeBlack(vec4 pt)
    {
        // FIX: vec4(0, 0, 0, pt.w) -> vec4(0.0, 0.0, 0.0, pt.w) (integer args in vector constructor)
        return vec4(0.0, 0.0, 0.0, pt.w);
    }

    void main()
    {
        vec2 uv = sineWave(openfl_TextureCoordv);
        gl_FragColor = makeBlack(texture2D(bitmap, uv)) + texture2D(bitmap,openfl_TextureCoordv);
    }')
  public function new()
  {
    super();
  }
}

class PulseShader extends ErrorHandledRuntimeShader
{
  public var waveAmplitude(default, set):Float = 0;
  public var frequency(default, set):Float = 1;
  public var speed(default, set):Float = 1;
  public var time(default, set):Float = 0;
  public var enabled(default, set):Bool = false;

  public function new()
  {
    var shaderSource:String = Assets.getText(Paths.shaderFragment('pulseEffect', 'preload'));

    if (shaderSource == null || shaderSource.length == 0) {
        trace("CRITICAL ERROR: Shader file 'pulseEffect' NOT FOUND or EMPTY!");
    } else {
        trace("Shader loaded successfully. Length: " + shaderSource.length);
    }

    super('Pulse Effect', shaderSource);

    // Initialize with default values
    this.setFloat('uWaveAmplitude', waveAmplitude);
    this.setFloat('uFrequency', frequency);
    this.setFloat('uSpeed', speed);
    this.setFloat('uTime', time);
    this.setBool('uEnabled', enabled);
  }

  // Setters to automatically update shader uniforms when properties change
  function set_waveAmplitude(value:Float):Float
  {
    waveAmplitude = value;
    setFloat('uWaveAmplitude', value);
    return value;
  }

  function set_frequency(value:Float):Float
  {
    frequency = value;
    setFloat('uFrequency', value);
    return value;
  }

  function set_speed(value:Float):Float
  {
    speed = value;
    setFloat('uSpeed', value);
    return value;
  }

  function set_time(value:Float):Float
  {
    time = value;
    setFloat('uTime', value);
    return value;
  }

  function set_enabled(value:Bool):Bool
  {
    enabled = value;
    setBool('uEnabled', value);
    return value;
  }

  public function update(elapsed:Float):Void
  {
    if (enabled) time += elapsed * speed;
  }
}

class BlockedGlitchEffect
{
  public var shader(default, null):BlockedGlitchShader = new BlockedGlitchShader();

  public var time(default, set):Float = 0;
  public var resolution(default, set):Float = 0;
  public var colorMultiplier(default, set):Float = 0;
  public var hasColorTransform(default, set):Bool = false;

  public function new(res:Float, time:Float, colorMultiplier:Float, colorTransform:Bool):Void
  {
    set_time(time);
    set_resolution(res);
    set_colorMultiplier(colorMultiplier);
    set_hasColorTransform(colorTransform);
    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed:Float):Void
  {
    shader.time.value[0] += elapsed;
  }

  public function set_resolution(v:Float):Float
  {
    resolution = v;
    shader.screenSize.value = [resolution];
    return this.resolution;
  }

  function set_hasColorTransform(value:Bool):Bool
  {
    this.hasColorTransform = value;
    shader.hasColorTransform.value = [hasColorTransform];
    return hasColorTransform;
  }

  function set_colorMultiplier(value:Float):Float
  {
    this.colorMultiplier = value;
    shader.colorMultiplier.value = [value];
    return this.colorMultiplier;
  }

  function set_time(value:Float):Float
  {
    this.time = value;
    shader.time.value = [value];
    return this.time;
  }
}

class BlockedGlitchShader extends FlxShader
{
  // https://www.shadertoy.com/view/MlVSD3
  @:glFragmentSource('
    #pragma header

    // ---- gllock required fields -----------------------------------------------------------------------------------------
    #define RATE 0.75
    uniform float time;
    uniform float end;
    uniform sampler2D imageData;
    uniform vec2 screenSize;
    // ---------------------------------------------------------------------------------------------------------------------

    float rand(vec2 co){
      return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453) * 2.0 - 1.0;
    }

    float offset(float blocks, vec2 uv) {
      float shaderTime = time*RATE;
      return rand(vec2(shaderTime, floor(uv.y * blocks)));
    }

    void main(void) {
      vec2 uv = openfl_TextureCoordv;
      gl_FragColor = flixel_texture2D(bitmap, uv);
      gl_FragColor.r = flixel_texture2D(bitmap, uv + vec2(offset(64.0, uv) * 0.03, 0.0)).r;
      gl_FragColor.g = flixel_texture2D(bitmap, uv + vec2(offset(64.0, uv) * 0.03 * 0.16666666, 0.0)).g;
      gl_FragColor.b = flixel_texture2D(bitmap, uv + vec2(offset(64.0, uv) * 0.03, 0.0)).b;
    }
    ')
  public function new()
  {
    super();
  }
}

class WiggleEffectLua extends Effect
{
  public var shader(default, null):WiggleShader = new WiggleShader();
  public var effectType(default, set):WiggleEffectType = DREAMY;
  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;
  public var verticalStrength(default, set):Float = 1;
  public var horizontalStrength(default, set):Float = 1;

  public function new(typeOfEffect:String = 'DREAMY', waveSpeed:Float = 0, waveFrequency:Float = 0, waveAmplitude:Float = 0, ?verticalStrength:Float = 1,
      ?horizontalStrength:Float = 1):Void
  {
    shader.uTime.value = [0.0];
    this.waveSpeed = waveSpeed;
    this.waveFrequency = waveFrequency;
    this.waveAmplitude = waveAmplitude;
    this.verticalStrength = verticalStrength;
    this.horizontalStrength = horizontalStrength;
    this.effectType = effectTypeFromString(typeOfEffect);
    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed:Float):Void
  {
    shader.uTime.value[0] += elapsed;
  }

  // FIX: converted switch statement to if-else (switch cases unsupported on macOS/miscellaneous platforms)
  private function effectTypeFromString(effectType:String):WiggleEffectType
  {
    var normalized:String = effectType.trim().replace('_', '').replace('-', '').toLowerCase();
    if (normalized == 'dreamy') return DREAMY;
    if (normalized == 'wavy') return WAVY;
    if (normalized == 'horizontal' || normalized == 'heatwavehorizontal') return HEAT_WAVE_HORIZONTAL;
    if (normalized == 'vertical' || normalized == 'heatwavevertical') return HEAT_WAVE_VERTICAL;
    if (normalized == 'flag') return FLAG;
    if (normalized == 'both' || normalized == 'heatwaveboth') return HEAT_WAVE_BOTH;
    return DREAMY;
  }

  function set_effectType(v:WiggleEffectType):WiggleEffectType
  {
    effectType = v;
    shader.effectType.value = [WiggleEffectType.getConstructors().indexOf(Std.string(v))];
    return v;
  }

  function set_waveSpeed(v:Float):Float
  {
    waveSpeed = v;
    shader.uSpeed.value = [waveSpeed];
    return v;
  }

  function set_waveFrequency(v:Float):Float
  {
    waveFrequency = v;
    shader.uFrequency.value = [waveFrequency];
    return v;
  }

  function set_waveAmplitude(v:Float):Float
  {
    waveAmplitude = v;
    shader.uWaveAmplitude.value = [waveAmplitude];
    return v;
  }

  function set_verticalStrength(v:Float):Float
  {
    verticalStrength = v;
    shader.verticalStrength.value = [verticalStrength];
    return v;
  }

  function set_horizontalStrength(v:Float):Float
  {
    horizontalStrength = v;
    shader.horizontalStrength.value = [horizontalStrength];
    return v;
  }
}

class Effect
{
  public function setValue(shader:FlxShader, variable:String, value:Float)
  {
    Reflect.setProperty(Reflect.getProperty(shader, variable), 'value', [value]);
  }
}
