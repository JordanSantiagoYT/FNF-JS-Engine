#pragma header

uniform float uAmplitude;
uniform float uTime;
uniform float uSpeed;
uniform float uFrequency;
uniform bool uEnabled;
uniform float uWaveAmplitude;

vec4 sineWave(vec4 pt)
{
    if (uWaveAmplitude > 0.0 && uEnabled)
    {
        // Calculate offsets
        float offsetX = sin(pt.y * uFrequency + uTime * uSpeed);
        float offsetY = sin(pt.x * (uFrequency * 2.0) - (uTime / 2.0) * uSpeed);
        float offsetZ = sin(pt.z * (uFrequency / 2.0) + (uTime / 3.0) * uSpeed);

        // Use (0.5 * sin + 0.5) to keep values between 0.0 and 1.0
        // This prevents negative colors (Black Screen)
        float weirdX = 0.5 * sin(pt.x / 2.0 * pt.y + (5.0 * offsetX) * pt.z) + 0.5;
        pt.x = mix(pt.x, weirdX, uWaveAmplitude * uWaveAmplitude);

        float weirdY = 0.5 * sin(pt.y / 3.0 * pt.z + (2.0 * offsetZ) - pt.x) + 0.5;
        pt.y = mix(pt.y, weirdY, uWaveAmplitude * uWaveAmplitude);

        float weirdZ = 0.5 * sin(pt.z / 6.0 * (pt.x * offsetY) - (50.0 * offsetZ) * (pt.z * offsetX)) + 0.5;
        pt.z = mix(pt.z, weirdZ, uWaveAmplitude * uWaveAmplitude);
    }

    return vec4(pt.x, pt.y, pt.z, pt.w);
}

void main()
{
    vec2 uv = openfl_TextureCoordv;
    gl_FragColor = sineWave(flixel_texture2D(bitmap, uv));
}
