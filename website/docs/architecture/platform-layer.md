---
title: Platform layer
sidebar_position: 8
description: How platform-specific code is isolated — desktop natives, the Android Java bridge, iOS and web.
---

# Platform layer

A core rule of the codebase: **gameplay code should not contain platform conditionals.**
Platform differences are pushed into a small number of modules that expose a clean
cross-platform API and compile to no-ops elsewhere.

| Layer | Where |
|---|---|
| Platform detection | `utils.PlatformUtil` |
| Desktop natives (Win32, POSIX) | `utils.PlatformUtilNative`, `utils.CoolSystemStuff`, `utils.HiddenProcess` |
| Memory reporting | `utils.MemoryUtil`, `debug.Memory`, `debug/mem/` (C++ include) |
| Mobile storage, permissions, touch | `mobile/` |
| Android services | `android/platform/*.hx` + `android/src/quack/fnf/phoenix/android/*.java` |
| Window behaviour | `backend.WindowBackend`, `backend.WindowColorMode`, `backend.FunkinGame` |
| Library-level fixes | `source/source-haxelib-patches/` ([details](./haxelib-patches.md)) |

## Desktop

- **Windows.** `Main` runs `SetProcessDPIAware()`, `SetConsoleOutputCP(CP_UTF8)` and
  `DisableProcessWindowsGhosting()` through inline C++, linking `wininet.lib` and
  `dwmapi.lib` via `@:buildXml`. `WindowColorMode` applies the dark title bar through
  DWM. `utils.PlatformUtil.detectWine()` reports whether the Windows build is running
  under Wine.
- **Linux.** `hxgamemode` is requested in `Main.__init__()` behind `GAMEMODE_ALLOWED`
  and released in `shutdownGameMode()`; both paths tolerate `gamemoded` being absent.
  `gamemode.ini` is the shipped profile. Video decoding is libvlc through `hxvlc`.
- **macOS.** `FEATURE_FILE_DROP` is disabled (drag-and-drop does not work there);
  `sys/utsname.h` is included for the arch query in `utils.PlatformUtil.getArch()`.

## Android

The Android integration is the largest platform-specific surface. It is documented in
depth in `docs/ANDROID_PLATFORM.md`; the structure is:

```text
Gameplay code
  └─ android.platform.*          (Haxe API, no-ops off Android)
       └─ AndroidBridge.hx       (cached JNI handles + event dispatch)
            └─ android/src/quack/fnf/phoenix/android/*.java
```

| Haxe module | Responsibility |
|---|---|
| `AndroidPlatform` | boots the whole layer from `Main` |
| `AndroidBridge` | JNI helpers and the Java → Haxe event dispatcher |
| `AndroidLifecycle` | pause/resume/stop, focus |
| `AndroidMedia` | MediaSession / Media3 metadata, playback state, lock-screen controls |
| `AndroidDisplay` | insets, cutouts, refresh rate, immersive mode |
| `AndroidStorage` | scoped storage and permissions |
| `AndroidHardwareInput`, `AndroidGamepad`, `AndroidHaptics` | physical keys, controllers, vibration |
| `AndroidIntents`, `AndroidNotification`, `AndroidDiscord`, `AndroidSystem` | intents, notifications, RPC, system info |

Java side: `PhoenixCore` (registration + `dispatch(event, arg)`), `PhoenixMedia` and
`PhoenixMediaService` (media session, background playback), `PhoenixDisplay`,
`PhoenixStorage`, `PhoenixInput`. They are registered through
`config.set("android.extension", ...)` in `project.hxp`, and Lime's `GameActivity`
instantiates them.

Data crossing the boundary: arrays become CSV strings, byte buffers go through
`haxe.io.Bytes.ofData`, and JNI method handles are created lazily and cached.

Build-time Android work also lives in `project.hxp`: `configureAndroidRuntime()` copies
`libc++_shared.so` from the NDK into the Gradle project
([why](../getting-started/troubleshooting.md#android-dlopen-failed-libc_sharedso-not-found)).

## iOS

`lime build ios -nosign` in CI. Native tweaks (fullscreen, orientation, lifecycle) go
through `templates/` plist/Xcode settings and the shared `mobile/` modules. Objective-C /
Swift injections are applied by the project script, not scattered through `source/`.

## Web, Flash and AIR

These targets lose whole feature flags: no `MODS_ALLOWED`, no `LUA_ALLOWED` /
`PYTHON_ALLOWED`, no `VIDEOS_ALLOWED`, and on SWF no `SHADERS_ALLOWED`. HTML5 embeds
assets (`EMBED_ASSETS`) and uses `mp3` rather than `ogg`.

Flash/AIR additionally rely on the seven files in `source/source-haxelib-patches/`, which gate out
library APIs that only exist on the Lime/OpenFL renderers.

## Adding platform-specific behaviour

1. If it can be expressed in Haxe against an existing library API → write it in the
   relevant `utils/`, `mobile/` or `android/platform/` module, behind `#if`.
2. If it needs *library* changes → add a patch in `source/source-haxelib-patches/`.
3. If it needs C/C++, Java/Kotlin, Objective-C or Win32 → put the native source under
   `android/src/`, `templates/` or an inline `@:cppFileCode` block, and wire it up from
   `project.hxp` (build callbacks, `setup/` scripts).

Expose the result as a cross-platform function with a no-op fallback, so callers never
need their own `#if`.
