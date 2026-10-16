---
title: Requirements
sidebar_position: 1
description: Toolchain, libraries and per-platform prerequisites for compiling Phoenix Engine.
---

# Requirements

Phoenix Engine compiles with the standard Haxe/Lime toolchain. Everything below is
installed once per machine; after that, building is a single `lime test` command.

## Core toolchain

| Tool | Version | Notes |
|---|---|---|
| [Haxe](https://haxe.org/download/) | **4.2.5 or newer** | CI builds with 4.3.x. The repo contains an `UPDATE HAXE TO 4.3.7.txt` note — 4.3.7 is the recommended version. |
| Haxelib | ships with Haxe | Run `haxelib setup` once before anything else. |
| Git | any recent version | Several dependencies are installed straight from Git. |
| Node.js | 20+ | Only needed to build *this* documentation site. |

On macOS and Linux you usually have to create the haxelib folder yourself:

```bash
mkdir ~/haxelib && haxelib setup ~/haxelib
```

## Per-platform prerequisites

### Windows

- **Visual Studio Community** with the C++ desktop workload. The two components that
  matter are `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` and
  `Microsoft.VisualStudio.Component.Windows10SDK.19041`:

  ```powershell
  vs_Community.exe --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
                   --add Microsoft.VisualStudio.Component.Windows10SDK.19041 -p
  ```

- If `hxcpp` picks the wrong MSVC toolchain, the repo ships
  `setup/windows-msvc-fix.ps1` / `setup/windows-msvc.bat`; see
  [Troubleshooting](./troubleshooting.md).

### Linux

- `g++` (package name varies: `g++` on Debian/Ubuntu, `gcc-c++` on Fedora,
  `sys-devel/gcc` on Gentoo).
- **VLC / libvlc** development packages — video playback goes through `hxvlc`.
- Optional: `gamemode` (Feral GameMode) to benefit from the `GAMEMODE_ALLOWED` feature.

### macOS

- Xcode command line tools (`xcode-select --install`).

### Android

- Android SDK + NDK, configured through `lime setup android`.
- A JDK compatible with the Gradle version Lime generates.
- `project.hxp` registers a pre-build callback (`configureAndroidRuntime`) that runs
  `setup/android-copy-stl.sh` (`.bat` on Windows) to copy `libc++_shared.so` out of the
  NDK into the APK — this is required, see
  [Troubleshooting](./troubleshooting.md#android-dlopen-failed-libc_sharedso-not-found).

### iOS

- Xcode with a working toolchain. CI builds unsigned with `lime build ios -nosign`.

### Flash / AIR

- Flash and AIR targets require `-D disable-version-check`.
- AIR additionally needs `-DAIR_SDK=<path to the AIR SDK>`.

## Haxe libraries

Dependencies are declared in **`hmm.json`** and installed by the setup scripts
(`setup/windows.bat` or `setup/unix.sh`). Several of them are *forks* pinned to
`JS-Engine-things/*` repositories rather than the public haxelib releases:

| Library | Source | Role |
|---|---|---|
| `lime` | `JS-Engine-things/lime-8.1.2` | windowing, assets, native backend |
| `openfl` | `JS-Engine-things/openfl` | display list, rendering |
| `flixel` | `JS-Engine-things/flixel-JS-Engine` | game framework |
| `flixel-addons` 3.2.3, `flixel-ui` 2.6.0, `flixel-tools` | haxelib | effects and editor UI |
| `hxcpp` | `JS-Engine-things/hxcpp` (`main`) | C++ target backend |
| `hxp` | haxelib | runs `project.hxp` |
| `hxvlc` | `JS-Engine-things/hxvlc` | video playback |
| `hxluajit` | `ShadowEngineTeam/hxluajit` | Lua/LuaJIT VM |
| `hython` 0.0.352-beta | haxelib | pure-Haxe Python interpreter |
| `hscript-improved` | `CodenameCrew/hscript-improved` (`48ec0f4`) | HScript runtime |
| `flxanimate` | `Dot-Stuff/flxanimate` (pinned commit) | Adobe Animate atlases |
| `hxdiscord_rpc` | `MAJigsaw77/hxdiscord_rpc` | Discord Rich Presence |
| `funkin.vis` + `grig.audio` | `JS-Engine-things/*` forks | spectrum analyzer (A-Bot speaker) |
| `tjson` | `moxie-coder/tjson` | tolerant JSON parsing |
| `hxnativefiledialog` | `MAJigsaw77/hxnativefiledialog` | native file dialogs |
| `hxgamemode` | haxelib | Feral GameMode on Linux |
| `hxcpp-debug-server` | haxelib | VS Code debugging |

:::warning[Pinned versions matter]

Because several libraries are forks, a plain `haxelib install <lib>` can silently switch
the active version away from the fork (this is the classic `hxcpp` failure described in
`BUILDING.md`). If a build suddenly breaks after installing an unrelated library, check
`haxelib list` and re-run the setup script.

:::

## Cloning

Clone **only** the `main` branch — the other branches are experiments or very old:

```bash
git clone -b main --single-branch https://github.com/havaianasdestruido/FNF-Phoenix-Engine.git
```
