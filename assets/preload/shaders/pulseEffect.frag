#pragma header
uniform float uAmplitude;

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

uniform bool uEnabled;

/**
	* How much the pixels are going to stretch over the waves
*/
uniform float uWaveAmplitude;

vec4 sineWave(vec4 pt)
{
	if (uWaveAmplitude > 0.0)
	{
		float offsetX = sin(pt.y * uFrequency + uTime * uSpeed);
		float offsetY = sin(pt.x * (uFrequency * 2.0) - (uTime / 2.0) * uSpeed);
		float offsetZ = sin(pt.z * (uFrequency / 2.0) + (uTime / 3.0) * uSpeed);
		pt.x = mix(pt.x,sin(pt.x / 2.0 * pt.y + (5.0 * offsetX) * pt.z), uWaveAmplitude * uWaveAmplitude);
		pt.y = mix(pt.y,sin(pt.y / 3.0 * pt.z + (2.0 * offsetZ) - pt.x), uWaveAmplitude * uWaveAmplitude);
		pt.z = mix(pt.z,sin(pt.z / 6.0 * (pt.x * offsetY) - (50.0 * offsetZ) * (pt.z * offsetX)), uWaveAmplitude * uWaveAmplitude);
	}
	return vec4(pt.x, pt.y, pt.z, pt.w);
}

void main()
{
	vec2 uv = openfl_TextureCoordv;
	gl_FragColor = sineWave(flixel_texture2D(bitmap, uv), uv);
}
