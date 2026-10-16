---
title: Shaders & effects
sidebar_position: 5
description: The shaders package, the Shader/Effect pair convention, runtime shaders and the script-facing API.
---

# Shaders & effects

All GLSL lives in `source/shaders/` (42 modules) and is gated by the
`SHADERS_ALLOWED` feature flag — Flash and AIR build without it.

## The `*Shader` / `*Effect` pair

Most effects come in two parts:

- **`XShader`** — a `FlxShader` subclass holding the fragment (and sometimes vertex)
  GLSL source and its uniforms.
- **`XEffect`** — a small wrapper implementing `shaders.Effect`, exposing animatable
  parameters and an `update(elapsed)` the state calls each frame.

```haxe
var effect = new GlitchEffect();
effect.waveAmplitude = 0.1;
camGame.setFilters([new ShaderFilter(effect.shader)]);
```

`shaders.ShaderEffect` and `shaders.Effect` are the shared bases;
`shaders.ErrorHandledShader` wraps compilation so a broken shader logs and is skipped
instead of taking the game down (important for mod-supplied shaders).

## What ships

| Effect | Module(s) |
|---|---|
| Glitch | `GlitchEffect` + `GlitchShader` |
| Blocked glitch | `BlockedGlitchEffect` + `BlockedGlitchShader` |
| VCR distortion | `VCRDistortionEffect` + `VCRDistortionShader` |
| Chromatic aberration | `ChromaticAberrationEffect` + `ChromaticAberrationShader` |
| Bloom | `BloomEffect` + `BloomShader` |
| Grain | `Grain`, `GrainEffect` |
| Scanlines | `Scanline`, `ScanlineEffect` |
| Tiltshift | `Tiltshift`, `TiltshiftEffect` |
| Greyscale / invert | `GreyscaleEffect` + `GreyscaleShader`, `InvertColorsEffect` + `InvertShader` |
| Pulse | `PulseEffect`, `PulseEffectAlt`, `PulseShader` |
| 3D | `ThreeDEffect` + `ThreeDShader` |
| Wiggle | `WiggleEffect`, `WiggleEffectLua` |
| Background distortion | `DistortBGEffect` + `DistortBGShader` |
| Buildings (Philly) | `BuildingEffect` + `BuildingShader` |
| Rain | `RainShader` (toggleable; optimized behind an option) |
| Triangle | `FuckingTriangle`, `FuckingTriangleEffect` |
| VFD overlay | `VFDOverlay` |
| Note colouring | `RGBPalette` |
| Transitions | `CustomFadeTransition`, `CrossFade` |
| Runtime loader | `RuntimeShaders` |

`backend.FlxFixedShader` is a corrected `FlxShader` base used where the stock one
misbehaves.

## Runtime shaders (mods)

`shaders.RuntimeShaders` loads GLSL from disk at runtime, so a mod can ship
`mods/<mod>/shaders/<name>.frag` (and `.vert`) and apply it from a script. Engine shaders
that used to be loose files were embedded into `RuntimeShaders` to avoid the file read
(for example `pulseEffect.frag`).

From Lua or Python:

```lua
initLuaShader('myShader')
setSpriteShader('boyfriend', 'myShader')
setShaderFloat('boyfriend', 'uTime', 0.0)
```

The full set — `initLuaShader`, `setSpriteShader`, `setCameraShader`,
`removeSpriteShader`, `removeCameraShader`, `clearShadersFromCamera`, and the
`get/setShader{Float,Int,Bool}[Array]` / `setShaderSampler2D` family — is listed in the
[Lua API reference](../modding/lua-api-reference.md#shaders).

Screen effects also have dedicated helpers (`addGlitchEffect`, `addVCREffect`,
`addBloomEffect`, `addGrainEffect`, `addScanlineEffect`, `addTiltshiftEffect`,
`addChromaticAbberationEffect`, `addPulseEffect`, `add3DEffect`, `addWiggleEffect`,
`addDistortionEffect`, `addInvertEffect`, `addGrayscaleEffect`, `clearEffects`).

## Writing a new engine effect

1. Add `MyShader.hx` with the GLSL in an `@:glFragmentSource` string.
2. Add `MyEffect.hx` implementing `Effect` with the parameters and `update(elapsed)`.
3. Guard everything with `#if SHADERS_ALLOWED`.
4. If scripts should reach it, register a callback in `psychlua/callbacks/EffectCallbacks.hx`
   (and `psychlua/pystdlib/` for Python parity).
5. Validate uniforms defensively — the *Rainbow Eyesore* shader is the cautionary tale
   (it needed validation and a `waveSpeed` fix after mods passed unexpected values).

:::warning[Performance]

Post-processing is per-pixel on the whole screen. On the low-end devices this engine
targets, a single full-screen filter can cost more than the entire note rendering. Prefer
sprite-level shaders, and keep effects behind options where possible (as the rain effect
is).

:::
