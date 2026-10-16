---
title: Project configuration
sidebar_position: 3
description: How project.hxp drives the build — metadata, feature flags, compile defines, asset libraries and platform callbacks.
---

# Project configuration (`project.hxp`)

Phoenix Engine has **no `project.xml`**. The Lime project is a Haxe program —
`project.hxp`, a `Project extends HXProject` class executed by the `hxp` library. Writing
it in Haxe makes feature-flag logic expressible as real code instead of nested XML
conditionals.

The constructor runs the configuration pipeline in order:

```haxe
flair();                   // print branch/commit banner
configureApp();            // metadata + window
displayTarget();
configureCompileDefines(); // non-feature haxedefs
configureFeatureFlags();   // the *_ALLOWED flags
configureOutputDir();
configureAndroidRuntime(); // pre-build callback for libc++_shared.so
configureHaxelibs();       // -lib entries, conditional on flags
configureAssets();         // asset libraries
configureIcons();
```

## Metadata

| Constant | Value |
|---|---|
| `VERSION` | `"0.3.2"` — the single source of truth; the game queries it at runtime |
| `TITLE` | `Friday Night Funkin' - Phoenix Engine` |
| `EXECUTABLE_NAME` | `FNF-Phoenix-Engine` |
| `PACKAGE_NAME` | `quack.fnf.phoenix` |
| `COMPANY` | `JordanSantiago` |
| `MAIN_CLASS` | `Main` |
| `PRELOADER` | `flixel.system.FlxPreloader` |
| `SOURCE_DIR` | `source` |

:::tip[Bumping the version]

Change `VERSION` in `project.hxp` — every in-game reader (main menu, FPS
counter, crash reports, the Lua `phoenixVersion` global) derives the Phoenix
version from the application metadata it sets, and `project.hxp` also
exposes it as the `ENGINE_VERSION` compile-time define. One manual step
remains: make the first entry of `THECHANGELOG.md` the same version, because
the update checker polls that file from this repository and compares its
first entry against the running Phoenix version (#53, #54).
`tests/test_arena_fixes.py` asserts the two stay equal.

:::

## Window

Set in `configureApp()`:

| Property | Desktop | Mobile |
|---|---|---|
| Size | 1280 × 720 | `0 × 0` (native resolution) |
| FPS | 60 | 60 |
| Background | `0x000000` | `0x000000` |
| Hardware | `true` | `true` |
| VSync | `false` | `false` |
| Resizable | `true` | Android `true`, iOS `false` |
| Orientation | — | `LANDSCAPE` |

## Feature flags

A `FeatureFlag` is a string wrapper with `enable`/`disable`/`apply`/`isEnabled` helpers.
`apply(project, condition)` sets the define unless the user already overrode it on the
command line, so **`-DVIDEOS_ALLOWED` or `-DMODS_ALLOWED` always wins**.

| Flag | Default condition | Guards |
|---|---|---|
| `MODS_ALLOWED` | desktop or mobile, not web/flash/air | the whole `mods/` pipeline (`backend.Mods`; otherwise `backend.ModsStub`) |
| `LUA_ALLOWED` | desktop/mobile C++ targets (or forced by `MODDING_LEVEL`) | `psychlua.FunkinLua` and all Lua callbacks |
| `PYTHON_ALLOWED` | same as Lua, level `2` only | `psychlua.PythonScript` and `pystdlib` |
| `HSCRIPT_ALLOWED` | desktop, mobile, web (not flash/air) | `psychlua.HScript`; also sets `hscriptPos` |
| `VIDEOS_ALLOWED` | desktop/mobile C++, not 32-bit web | hxvlc playback, cutscenes |
| `SHADERS_ALLOWED` | everything except flash/air | runtime shaders and the `shaders/` package |
| `DISCORD_ALLOWED` | desktop/mobile C++ | `backend.DiscordClient` |
| `GAMEMODE_ALLOWED` | Linux desktop | Feral GameMode integration |
| `ACHIEVEMENTS_ALLOWED` | always | `backend.Achievements` |
| `CRASH_HANDLER` | always | `backend.CrashHandler` and the crash report writer |
| `CHECK_FOR_UPDATES` | always | the outdated-version screen |
| `FEATURE_FILE_DROP` | everything except macOS/flash/air | drag-and-drop in the editors |
| `FEATURE_DEBUG_FUNCTIONS` | opt-in | extra debug menus |
| `FUNNY_ALLOWED` | desktop | easter eggs |
| `EMBED_ASSETS` | web only | embeds assets into the output |
| `PRELOAD_ALL` | always | preloads asset libraries |
| `NO_PRELOAD_ALL` | manual `-DNO_PRELOAD_ALL` switch | inverse of `PRELOAD_ALL`; assets are loaded on demand via `states.LoadingState` instead of preloaded (#55) |
| `FLASH_ALLOWED` | flash target | SWF-specific code paths |
| `TITLE_SCREEN_EASTER_EGG` | currently commented out | title screen easter egg |
| `officialBuild` | `-Dofficial` | marks release builds |

### `MODDING_LEVEL`

`getModdingLevel()` reads `-DMODDING_LEVEL` (checking both `haxedefs` and `defines`) and
returns `-1` when unset. When it *is* set it overrides the automatic conditions:

| Level | `LUA_ALLOWED` | `PYTHON_ALLOWED` |
|---|---|---|
| `0` | disabled | disabled |
| `1` | enabled | disabled |
| `2` (default on desktop) | enabled | enabled |

## Compile defines

`configureCompileDefines()` sets haxedefs that are not feature flags:

| Define | Why |
|---|---|
| `openfl-enable-handle-error` | required by the crash logger |
| `HXCPP_CHECK_POINTER`, `HXCPP_STACK_LINE`, `HXCPP_STACK_TRACE`, `HXCPP_CATCH_SEGV` | readable native stack traces in crash reports |
| `hscriptPos` | line numbers in HScript errors (when `HSCRIPT_ALLOWED`) |
| `no-deprecation-warnings` | quieter builds |
| `FLX_NO_FOCUS_LOST_SCREEN` | the engine draws its own |
| `FLX_NO_PITCH`, `FLX_NO_SOUND_TRAY` | Flash/AIR only — those backends cannot pitch-shift |
| `disable-version-check` | suppresses OpenFL's Lime compatibility abort on SWF targets |

## Asset libraries

`configureAssets()` registers Lime asset libraries. Each is embedded and/or preloaded
depending on the target (web embeds, native streams):

| Library | Source | Notes |
|---|---|---|
| `default` | `assets/preload` | always loaded; menus, UI, base characters/charts |
| `shared` | `assets/shared` | shared between weeks |
| `songs` | `assets/songs` | instrumentals and voices |
| `videos` | `assets/videos` | only when `VIDEOS_ALLOWED` |
| `week2` … `week7`, `weekend1` | `assets/week*` | per-week content |

Global exclusions: `.*`, `cvs`, `thumbs.db`, `desktop.ini`, `*.hash`, `*.md`.
Web builds additionally exclude `*.ogg`, native builds exclude `*.mp3` — the engine picks
the right extension at runtime through `Paths.SOUND_EXT`.

With `-DNO_BUILTIN_CONTENT`, the content libraries are stripped; see
[Building](./building.md#content-stripped-builds).

## Class paths

```haxe
this.sources.push(SOURCE_DIR);                 // source/
this.sources.push("source/source-haxelib-patches");   // overrides, pushed LAST
```

Lime turns each entry into a `-cp` line *after* the library class paths, and the compiler
takes a module from the **last** matching class path. That is the whole mechanism behind
[Haxelib patches](../architecture/haxelib-patches.md) — precedence is
`source/source-haxelib-patches/` > `source/` > haxelib.

## Build callbacks

- **`configureAndroidRuntime()`** registers a pre-build callback that runs
  `setup/android-copy-stl.sh` / `.bat`, copying `libc++_shared.so` from the NDK into
  `build/<type>/android/bin/app/src/main/jniLibs/<abi>/`. Lime runs pre-build callbacks
  after generating the Gradle project and before copying NDLLs — the only point where the
  file can still be added.
- **`configureIcons()`** wires up `art/icon16.png`, `icon32.png`, `icon64.png`.
- **`flair()`** prints the git branch, commit and dirty state into the build log, which is
  how `backend.HaxeCommit` can display the commit hash in-game.

## Related runtime configuration

| File | Purpose |
|---|---|
| `gamemode.ini` | Feral GameMode profile for Linux |
| `modsList.txt` | which mods are enabled (`<folder>\|1` = enabled, `0` = disabled) |
| `checkstyle.json` | Haxe Checkstyle rules |
| `hxformat.json` | Haxe formatter rules |
| `hmm.json` | pinned haxelib dependency list |
