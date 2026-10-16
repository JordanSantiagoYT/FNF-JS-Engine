---
title: Building
sidebar_position: 2
description: Setup scripts, build commands per target, and the defines that change what gets compiled.
---

# Building

## 1. Install the libraries

From the repository root:

```bash
haxelib setup              # once per machine

# Windows
setup\windows.bat

# Linux / macOS
sh setup/unix.sh
```

The setup script installs everything in `hmm.json`, including the pinned Git forks of
`lime`, `openfl`, `flixel`, `hxcpp`, `hxvlc`, `funkin.vis` and `grig.audio`.

## 2. Build

```bash
haxelib run lime build windows -Dofficial
haxelib run lime build neko    -Dofficial
haxelib run lime build html5   -Dofficial
haxelib run lime build flash   -Dofficial -D disable-version-check
haxelib run lime build air     -Dofficial -D disable-version-check -DAIR_SDK=C:\AIR\AIRSDK_51.2.2
```

`lime test <platform>` builds **and launches** the result. `<platform>` is `windows`,
`linux`, `mac`, `android`, `ios`, `html5`, `neko`, `flash` or `air`.

:::note[First build takes a while]

A cold C++ build of a Flixel game takes roughly 5–10 minutes depending on your machine.
Subsequent builds reuse the hxcpp compile cache.

:::

## 3. Clean

```bash
lime test cpp -clean
# or simply remove the build output
rm -rf export build
```

## Targets

| Target | Command | Notes |
|---|---|---|
| Windows | `lime test windows` | primary target; MSVC toolchain |
| Linux | `lime test linux` | needs `g++` and libvlc |
| macOS | `lime test mac` | |
| Android | `lime build android` | runs `configureAndroidRuntime` to copy `libc++_shared.so` |
| iOS | `lime build ios -nosign` | the form CI uses |
| HTML5 | `lime build html5` | no Lua/Python/video |
| Neko | `lime build neko` | quick sanity target |
| Flash | `lime build flash -D disable-version-check` | relies on the haxelib patches |
| AIR | `lime build air -D disable-version-check -DAIR_SDK=<path>` | compiles as a SWF target |

## Build defines

Defines are passed as `-D<name>` (or `-D<name>=<value>`) on the `lime` command line.
The most relevant ones:

| Define | Effect |
|---|---|
| `-Dofficial` / `-DofficialBuild` | marks the build as an official release build |
| `-DMODDING_LEVEL=0\|1\|2` | script support: none / Lua / Lua + Python (desktop default `2`) |
| `-DNO_BUILTIN_CONTENT` | strips all base-game songs, weeks, characters and art — see below |
| `-DULTRA_OPTIMIZED` | maximum-speed build (work in progress) |
| `-DULTRA_HTML5` | HTML5-specific optimization pass (work in progress) |
| `-DDEBUG_TRACY` / `FEATURE_DEBUG_TRACY` | Tracy profiler instrumentation |
| `-Ddisable-version-check` | **required** for `flash` and `air` |
| `-DAIR_SDK=<path>` | location of the AIR SDK |

See [Project configuration](./project-configuration.md) for the full feature-flag list and
how `project.hxp` turns them into compiler defines.

### Script modding levels

```bash
lime test windows -DMODDING_LEVEL=1   # Lua only, no Python VM in the binary
```

| Value | Lua | Python | Typical use |
|---|---|---|---|
| `0` | ✗ | ✗ | smallest build, hardcoded mods only |
| `1` | ✓ | ✗ | Psych/JS Engine compatibility without the Hython cost |
| `2` | ✓ | ✓ | default on desktop and mobile |

The level is read by `project.hxp` and translated into the `LUA_ALLOWED` and
`PYTHON_ALLOWED` feature flags, which guard the corresponding code with `#if`. Code behind
a disabled flag is not merely skipped at runtime — it is not compiled at all.

### Content-stripped builds

```bash
lime test windows -DNO_BUILTIN_CONTENT
```

Builds the engine **without the base game's copyrighted content** — song audio, charts,
character/week/stage JSONs, cutscene videos and the related art are all excluded. What
stays: SFX, menu/pause/game-over music, the UI shell (fonts, sound tray, splash),
small runtime text files, and the bundled `mods/` folder.

The game still boots: characters, icons, stage art, week cards and dialogue portraits fall
back to code-generated placeholders, the title dancer is hidden, and story/freeplay show
their "no weeks" message until a mod supplies content. All editors remain usable.

## Build output

| Path | Contents |
|---|---|
| `export/<target>/bin/` | the runnable game |
| `build/<type>/haxe/*.hxml` | the generated Haxe command lines — useful for checking class-path order |
| `build/<type>/android/bin/` | the generated Gradle project for Android |

Both `build/` and `export/` are git-ignored.

## Convenience scripts

`art/scripts/` contains batch files used during development:

| Script | Purpose |
|---|---|
| `build_x64.bat`, `build_x32.bat` | release builds |
| `build_x64-debug.bat`, `test_x64-debug.bat` | debug build / run |
| `test_x64.bat` | release build and run |
| `compress.ps1` | packaging helper |
| `debugThingyMajiggy.bat` | debug launcher |

VS Code users get the same commands as tasks (`.vscode/tasks.json`) and a debug
configuration backed by `hxcpp-debug-server` (`.vscode/launch.json`).
