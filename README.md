<h1 align="center">
  <br>
  <a href="https://github.com/havaianasdestruido/FNF-JS-Engine-Light"><img src="/art/iconOG.png" alt="PHOENIXengine" width="150"></a>
  <br>
  <b>FNF Phoenix Engine</b>
  <br>
  <i>(Jordan Santiago Engine, with a bunch of new stuff)</i>
  <br>
</h1>
<h3 align="center">
  <b>Phoenix Engine is an enhanced fork of JSE, which in turn is a fork of Psych but with performance-related additions.</b>
</h3>

<p align="center">
<img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/havaianasdestruido/FNF-Phoenix-Engine">
<img alt="GitHub commit activity" src="https://img.shields.io/github/commit-activity/w/havaianasdestruido/FNF-Phoenix-Engine">
<img alt="GitHub contributors" src="https://img.shields.io/github/contributors/havaianasdestruido/FNF-Phoenix-Engine">
</p>

## Documentation

Full codebase documentation lives in [`website/`](website/) and is published with Docusaurus to
**https://havaianasdestruido.github.io/FNF-Phoenix-Engine/**:

- **Getting started** — requirements, building, `project.hxp` flags, troubleshooting
- **Architecture** — boot sequence, state flow, `Paths`, `Conductor`, haxelib patches, platform layer
- **Subsystems** — gameplay, charts, characters/stages, shaders, options, editors, audio, mobile, deep links
- **Modding** — mod folder layout, Lua/Python/HScript, every script hook, custom events and notetypes
- **Code reference** — every type in `source/`, generated from the Haxe sources on each build

Run it locally with `cd website && npm install && npm start`.

---

**IMPORTANT: You are in the `bleeding` branch, where you'll find bleeding-edge updates that may be experimental, unstable, or not fully tested yet. If you prefer a stable experience with changes that are 100% (okay, maybe 99.9%) guaranteed to work, stick to the `main` branch.** _Keep in mind that small patches CAN go directly to main if i think its good enough..._

Phoenix Engine focuses on making both Hardmodding (Hardcoded mods, using `Haxe`) *AND* Softmodding (mods you place on `mods/` folder, made with `Lua`/`Luau` or `Python`) easier.

---

I also want to focus on platform-specific code from now on (mainly Android-related), including platform-specific patches:

For example:

- Inject custom Java/Kotlin code into Android builds to provide features such as Discord RPC, Android intents, notifications, permissions, or other Android APIs.
  - Expose the currently playing song (title, artist/creator, album, artwork, playback state, position, etc.) to Android through "MediaSession" / Jetpack Media3, allowing integration with system media controls, Now Playing, the lock screen, Bluetooth devices, Android Auto, and other Android media clients.
  - Integrate with Android's "MediaSessionService" to keep media controls and playback metadata available while the application is running in the background.
  - Synchronize platform-level playback actions ("play", "pause", "stop", "next", "previous", "seek", etc.) with the engine's internal audio player through a native Android bridge.
  - Update "MediaMetadata" dynamically whenever the currently playing track changes, including its title, artist, album, and album artwork.
  - Expose the current playback state and timeline/position through "PlaybackState"/Media3 so Android can display accurate playback controls and progress.
  - Support Android media intents and external media clients where applicable.
- Provide platform-specific native bridges between Haxe/engine code and Android Java/Kotlin APIs, allowing engine-side code to access Android functionality without requiring platform-specific logic throughout the entire codebase.
- Add Android-specific patches when required to work around platform limitations, device-specific issues, or missing functionality in the underlying engine/framework.
- Keep platform-specific implementations isolated from the cross-platform codebase whenever possible, while exposing clean, engine-level APIs for features that need to be available across platforms.
- Inject custom Objective-C/Objective-C++/Swift code into iOS builds to fix fullscreen, orientation, lifecycle, input, or rendering issues.
- Apply custom C/C++ patches for native desktop functionality.
- Modify Android Gradle files, manifests, resources, and project configuration as part of the build process.
- Modify iOS Xcode project settings, Info.plist, frameworks, and native source files automatically.
- Provide Windows-specific native integrations through Win32 APIs.
- Provide Linux-specific patches for windowing, input, filesystem, or audio behavior.
- Use compile-time platform detection to include only the native code required by the target platform.

Haxe already provides `#if`s that can be useful on making small patches, but it becames a problem when theres issues that can only be solved using non-Haxe code. (e.g.: `C`/`C++` low-level patches)

The Haxe-level patches (the ones that fix files *inside* haxelibs like `flixel`, `openfl`, `funkin.vis`) live in `source/source-haxelib-patches/` and get compiled in as class-path overrides — what they fix, why they exist and how the compiler picks them up is explained in [Source patches](#source-patches-source/source-haxelib-patches).

# KNOW MOBILE (Android) ISSUES

- "It appears that [song] doesn't actually have a JSON, nor does it actually have voices/instrumental files!" appearing even if the song HAS a valid instrumental/JSON, can be ignored by accepting and the game works flawlessly, visual glitch. (MED-LOW)
- Asking for image and sound access even with "manage all files" acess (LOW)

Phoenix Engine currently has those additions (and more!) that vanilla JSE (Jordan Santiago Engine) doesn't:

## **Major Categories of Changes:**

### **1. Performance Optimizations**
- **HScript AST Caching**: Cache parsed AST to avoid re-parsing (bottleneck)
- **FunkinLua Optimization**: Cache missing calls and fast-path variable splitting
- **Convert Function**: Direct-call bridge for 0-8 args
- **PlayState Note Iteration**: Batch note iteration and inline key arrays
- **Alphabet Caching**: Cache sparrow atlases and skip duplicate animations
- **ChartingState**: Cache grid layer/waveform buffers, dedupe undo
- **Options Performance**: Throttle option text updates and guard score redraw
- **FPS Counter**: Cache PlayState check and throttle outline redraw

### **2. Code Refactoring & Architecture**
- **Modding System Rewrite**: Switched to cleaner Mods backend (0.7 style)
- **Source Tree Reorganization**: Split into packages (`backend/`, `states/`, `play/`, `objects/`, `data/`, `shaders/`, `psychlua/`)
- **Large File Splits**:
  - PlayState: 6448 → 3313 lines
  - ChartingState: 4821 → 2367 lines
  - FunkinLua: 3455 → 807 lines
- **GameOverSubstate Refactor**: Generic fallback + safer null handling
- **Stage Loading Centralization**: Created StageData.vanillaSongStage mapping
- **MS/Judge Text Popups**: Refactored into separate classes

### **3. Python Scripting Support**
- **Hython Integration**: Pure-Haxe Python interpreter
- **Mirrors Lua System**: Same callbacks/API as Lua scripts
- Supports `-DMODDING_LEVEL` flag for enable/disable

### **4. Build System & Compilation**
- **Windows MSVC Fixes**: Assembler support, C++17 flag handling
- **GitHub Actions Cache**: Proper `HXCPP_COMPILE_CACHE` detection
- **Platform-Specific Code**: Centralized in PlatformUtilNative.hx

### **5. Platform Support Improvements**
- **Linux GameMode**: Proper support with feature flags
- **Windows Console**: SetProcessDPIAware, DisableProcessWindowsGhosting
- **Fullscreen Handling**: Centralized F11 toggle in FunkinGame backend
- **Mac/iOS Headers**: Proper sys/utsname.h includes

### **6. Asset Management**
- **Audio Compression**: OGG/MP3 files (~50% size reduction)
- **JSON Minification**: Across entire codebase
- **Image Compression**: Lossy but invisible optimization
- **Character Icon Refresh**: Updated multiple icon PNGs
- **BF Clicker _(WIP Python testing  sample)_ Mod**: Shipped as example mod
- **Shader Embedding**: Runtime shaders (pulseEffect.frag → RuntimeShaders.hx)

### **7. Bug Fixes**
- **UTF-8 BOM Handling**: Strip BOM from JSON reads
- **defaultCamZoom Crashes**: More fixes for camera zoom behavior
- **Sustain Note Issues**: Fixed missing sustain notes if no BPM changes
- **GameOver Music Loop**: Fixed repeated triggering every frame
- **ControlsSubstate Crash**: Alt fix for crash issues
- **Scared Animations**: Fix Week 2 animation forcing
- **Time Bar Updating**: Proper time position calculation

### **8. Feature Additions**
- **Camera Zoom System**: V-Slice compatible (separate from bopping)
- **Zoom Tweening Event**: New event system for camera zoom
- **CrossFades Feature**: Character-specific and generic crossfades
- **Rain FX Toggle**: New option with shader optimization
- **Decimal Hit Windows**: Merged from Psych 1.0
- **Shift-Step Multiplier**: 5x step for int options
- **FPS Counter Border**: Outline rendering with visibility option
- **Discord RPC**: Centralized with DISCORD_ALLOWED flag

### **9. Lua Scripting Improvements**
- **Lua 1.0 Chart Support**: Now handles Psych 1.0 format
- **StartTween Function**: New tweening utility
- **moveCamera Update**: Now uses string names for global access
- **Script Initialization Fix**: Lua scripts no longer called twice

### **10. UI & Visual Polish**
- **Menu Track Modding**: Support for modified freakyMenu names
- **GF Limo Layering**: Fixed visual layering issues
- **Rainbow Eyesore Shader**: Validation and waveSpeed fixes
- **Visual Options**: FPS display updates on setting changes

### **11. Code Cleanup**
- **Removed Features**:
  - FLX_RECORD (replay/record system)
  - Showcase Mode
  - Angel Note type (did nothing)
  - In-game updater (broken/Windows-only)
  - PSYCH_WATERMARKS conditionals
  - Mod installation UI (dead code)
  - Neko GC support
- **Deduplicated Code**: formatCompatNumber moved to CoolUtil
- **Unused Variables**: Removed songTime field, stale precompiled headers
- **Trace Cleanup**: Debug traces wrapped with #if debug

### **12. Dependency Updates**
- hxluajit → hxluau
- hxcpp configuration updates
- flixel and lime updates
- hxvlc CPU rendering optimizations

## Source patches (`source/source-haxelib-patches/`)

`source/source-haxelib-patches/` holds the engine's **haxelib overrides**: complete copies of library files
(`flixel`, `openfl`, `funkin.vis`) with a few lines changed, kept in the repo instead of being applied by hand
into the haxelib install folder. They are the Haxe-level counterpart of the platform patches listed above.

### Why they exist

- Some bugs are simply **not in `source/`** — they are in the libraries the engine is built on top of, so no
  `#if` inside the game code can reach them.
- The libraries used here are already **forks** (`JS-Engine-things/flixel-JS-Engine`, `JS-Engine-things/openfl`,
  `JS-Engine-things/funkVis-FrequencyFixed` — see `hmm.json` and `setup/unix.sh` / `setup/windows.bat`). Landing a
  fix in a fork means *everyone* has to re-run setup before they get it, and a plain `haxelib install` of some
  unrelated lib can flip the active version back (that's the `hxcpp` problem described in `BUILDING.md`).
- Editing `~/.haxelib/...` directly — which is how these 7 files started — is **machine-local**: it fixes your
  build, it is invisible to CI, it vanishes on a fresh clone, and reviewers can't see it in the PR diff.
- Committing them as a class-path override makes the patch part of the project: it applies on every machine and
  every target, needs no install step, no hook, no `sed`, no copy script, and it is reviewable as plain Haxe.

### How they are used when compiling

`project.hxp` adds exactly one extra class path, right after the game's own:

```haxe
// Tell Lime where to look for the game's source code.
this.sources.push(SOURCE_DIR);                 // -> source/
// Haxelib classpath overrides (shadow machine-local haxelib edits for CI/fresh builds).
this.sources.push("source/source-haxelib-patches");   // -> source/source-haxelib-patches/
```

Lime writes each entry of `sources` as a `-cp` line in the generated hxml, after the `-lib` class paths, and a
module that exists in more than one class path is taken from the *last* one declared. So
`source/source-haxelib-patches/flixel/sound/FlxSound.hx` **shadows** `flixel/sound/FlxSound.hx` from the haxelib: the
library copy is never even opened by the compiler. That is the same mechanism that already lets
`source/source-haxelib-patches/flixel/FlxGame.hx` and `source/source-haxelib-patches/flixel/addons/ui/*` replace the library files — it just lives in its own folder
so library fixes stay visible and diffable. Two consequences:

- **A patch is a whole file, not a `.patch`/diff.** The folder mirrors the library's package layout
  (`flixel/util/FlxSave.hx` *is* module `flixel.util.FlxSave`); the path, the case of every letter and the file
  name must match exactly, and the file has to compile on its own.
- **Precedence is `source/source-haxelib-patches/` > `source/` > haxelib** (it is pushed last). A module patched in both
  places would be silently taken from this folder, so keep the two lists disjoint — today they are.

Because the substitution happens at Haxe compile time, the patch applies to *every* target (`cpp` desktop, neko,
html5, flash, air). That is exactly why each patch below is wrapped in platform conditionals: on the native
desktop/mobile builds the code must behave precisely like upstream.

### What each patch fixes

All 7 current patches exist so the **non-C++ targets (Flash / AIR)** build at all: they gate out API that the
JS-Engine library forks added for the Lime/OpenFL renderers and that doesn't exist on the SWF backends.

| Patch file | Library | What breaks without it | What the patch does |
|---|---|---|---|
| `flixel/sound/FlxSound.hx` | flixel | `FLX_PITCH` is undefined on Flash/AIR, so `FlxSound` has no `pitch` field — and the engine sets it everywhere (`play/PlayState.hx`, `play/helpers/PlayStatePlayback.hx`, `play/helpers/PlayStateChartLoader.hx`, `music/MusicPlayer.hx`, `editors/ChartingState.hx`), which is a `Type not found : pitch` compile error | Adds a store-only `pitch` property under `#if (flash || air)`. Code compiles and runs; changing pitch has no audible effect there, because the SWF audio backend can't pitch-shift |
| `flixel/graphics/tile/FlxDrawQuadsItem.hx` | flixel | The fork draws tile batches by pushing the batch bitmap through a shader fill (`graphics.shader`, `shader.bitmap.input`, `canvas.graphics.beginShaderFill`/`overrideBlendMode`) — none of that exists on Flash, so the module fails to compile | Wraps the whole shader-blit block (and its `try/catch`) in `#if !flash`. On Flash/AIR quads rendering is skipped instead of breaking the build; desktop/web are untouched |
| `flixel/graphics/tile/FlxDrawTrianglesItem.hx` | flixel | Same shader-blit path in the triangle batch item (`drawTriangles` + shader bitmap plumbing) | Same treatment: `#if !flash` around the shader + `drawTriangles` + `endFill` block, keeping the `FLX_DEBUG` draw-debug outline code |
| `flixel/util/FlxGradient.hx` | flixel | Flash's `beginGradientFill()` extern demands different element types than OpenFL's (it wants `UInt` colors and plain integers for the alphas), while flixel passes `Array<FlxColor>` / `Array<Float>` — hits `options/NotesSubState.hx` (note-color preview) and `shaders/CustomFadeTransition.hx` | Converts the color array to `UInt` and floors the alphas **only** under `#if flash`; every other target keeps OpenFL's types and the original call |
| `flixel/util/FlxSave.hx` | flixel | flixel's `FlxSharedObject` re-implements per-app save directories using `sys.FileSystem` / `sys.io.File`, which the SWF targets don't have — `FlxG.save`, and with it `ClientPrefs`, can't be built | Adds `flash \|\| air` to the `#if (android \|\| ios)` branch, so those targets use plain `SharedObject.getLocal()` (classic `.sol` save behavior) instead of the `sys`-based path |
| `openfl/utils/Assets.hx` | openfl | `Assets.getBitmapData()` probes for `.astc` / `.ktx` / `.dds` sidecars and loads them via `stage.context3D.createASTCTexture()` / `createETC2Texture()` / `createS3TCTexture()`; there is no Context3D path on SWF, so essentially every asset lookup is affected | Wraps the compressed-texture probe in `#if (!flash && !air)`, so Flash/AIR fall through to the normal `LimeAssets.getImage()` route |
| `funkin/vis/dsp/SpectralAnalyzer.hx` | funkin.vis | `#if web` also matches the SWF targets, pulling the Web-Audio `funkin.vis._internal.html5.AnalyzerNode` extern into Flash/AIR builds, while the `#else` branch needs a Lime `AudioSource` (`grig.audio.FFT`) that SWF can't provide. Used by `stages/objects/ABotSpeaker.hx` (the speaker visualizer) | Rewrites the guards as `#if (web && !flash)` / `#elseif !flash`, so neither backend is referenced on Flash/AIR (no analyzer there) while web and native keep their original code paths |

Notes:

- AIR compiles as a SWF target and Lime defines `flash` for it too, so `#if flash` already covers AIR; the
  explicit `#if (flash || air)` form is used where the property being stubbed is the only difference.
- No patch here changes gameplay, rendering or saving on the native desktop/mobile builds (or neko/html5) — they
  only *remove or retype* code that cannot compile on the SWF targets.

### How the game source uses them

Nothing imports from this folder and there is no API to call — `source/` keeps talking to
`flixel.sound.FlxSound`, `openfl.utils.Assets`, `flixel.util.FlxSave`, `funkin.vis.dsp.SpectralAnalyzer`, and the
patched copy of those modules is what gets compiled. In practice:

- Write code against the **patched** API without extra guards when the patch guarantees it exists everywhere:
  `state.vocals.pitch = state.playbackRate` in `play/helpers/PlayStateChartLoader.hx` needs no `#if`, because
  `FlxSound.pitch` now exists on Flash/AIR as well.
- Keep `#if FLX_PITCH` where *real* pitch shifting matters (see `play/helpers/PlayStateCamera.hx`), since the
  stub only stores a value.
- A patch is a promise to every target: if you add `FlxSound.foo()`, `foo()` becomes usable unguarded from
  `source/`; if you delete a patch, grep for the usages it was covering first.

### Adding, updating, removing a patch

```sh
# 1. find the active copy of the library
haxelib libpath flixel

# 2. mirror the exact package path and copy the file (never hand-write one)
mkdir -p source/source-haxelib-patches/flixel/sound
cp "$(haxelib libpath flixel)/flixel/sound/FlxSound.hx" source/source-haxelib-patches/flixel/sound/FlxSound.hx

# 3. edit only what is needed, keep upstream formatting/tabs, guard with #if,
#    and leave a comment above the block saying WHICH TARGET needs WHY

# 4. review the delta the way a reviewer will
diff -u "$(haxelib libpath flixel)/flixel/sound/FlxSound.hx" source/source-haxelib-patches/flixel/sound/FlxSound.hx
```

- Patch here only for **library** fixes. Engine behavior belongs in `source/` (or, better, in a PR to the fork).
- The smaller the diff in step 4, the easier the patch is to keep alive. Never reformat a patched file.
- When a library is bumped (re-running `setup/unix.sh` / `setup/windows.bat`, or a new ref in `hmm.json`),
  re-diff **every** patch: the copy is frozen at the moment it was taken, so a stale patch silently reverts the
  upstream fixes that came after it.
- Un-applying a patch is just `git rm source/source-haxelib-patches/<path>` — nothing was written into the haxelib, so
  there is nothing to restore (build with `-clean` if you still see old output).
- When the set of patched files changes, update the list in `BUILDING.md`
  ("Machine-local haxelib patches") too — it is the same 7 files, still worded as if they were local edits.

Not sure whether a patch is being picked up? Check the hxml Lime generates and/or break the file on purpose:

```sh
haxelib run lime build windows -Dofficial
grep -rn "source/source-haxelib-patches" build/release/haxe/*.hxml   # must appear after the -cp for source/
# brute-force proof: put a syntax error in the patch file and rebuild — the compiler should
# stop inside source/source-haxelib-patches/, not inside ~/.haxelib
```

Anything that cannot be expressed in Haxe (C/C++, Java/Kotlin, Objective-C, Win32) does **not** go here: those go
through `project.hxp` build callbacks and `setup/` scripts (e.g. `configureAndroidRuntime` +
`setup/android-copy-stl.sh`, `setup/windows-msvc-fix.ps1`).

## About AI usage

Yes, I used AI for some changes, mostly related to fixing building issues that were a pain on my ass to fix manually.

You can freely check the git commits and see what I modified by hand and where I used AI.

<a href="https://github.com/havaianasdestruido/FNF-Phoenix-Engine/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=havaianasdestruido/FNF-Phoenix-Engine" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

<details>
  <summary><h2>OG FNF JS Engine README and Stuff</h2></summary>
<!-- this is an secret -->
<h1 align="center">
  <br>
  <a href="https://github.com/JordanSantiagoYT/FNF-JS-Engine"><img src="/art/iconOG.png" alt="JSengine" width="150"></a>
  <br>
  <b>JS Engine</b>
  <br>
  <i>(Jordan Santiago Engine)</i>
  <br>
</h1>
<h3 align="center">
  <b>JS Engine is a heavily modified Psych Engine fork, with lower-end devices and more customization in mind.</b>
</h3>

README.md revamped by [Nael2xd](https://youtube.com/@nael2xd?si=axwJrY_8jdlXUwSm)

<!-- _If you're looking for the Mobile port, [go here](https://github.com/JordanSantiagoYT/FNF-JS-Engine/tree/mobile)._ -->

## Welcome

Welcome to JS Engine's github repo, where you can download the engine and make spammy charts or have fun with the engine.

This contains lots and lots of customizable and features built in to JS Engine, if you wanna see most of them listed, you can see it below this text

# Features/Performances in JS ENGINE

**This fork has tons of features and performances features, most will be listed:**

- No BotPlay lag!
- Faster Song Loading!
- Loading songs longer than 20 minutes!
- Note Performance!
- Loading 100k+ notes without closing the window!
- Basic Shader Support! (for a full list, it can be seen in [here](https://github.com/JordanSantiagoYT/FNF-JS-Engine/wiki#q-what-are-all-the-basic-shaders-that-come-with-this-engine))
- Rendering mode! (Originally used for lua and gamerenderer-engine)
- Built in Song Credits! (on chart editor)
- Spam modules! (for the DnB fans)
- Cool customizable UI!
- Multiple Chart Backups!
- Custom Crash UI (Instead of Regular Psych Engine Crash)!
- A nifty button in your Discord Profile!

There is like lots and lots of stuff i've missed, but at least you would like those features built in **JS ENGINE**

# Screenshots and Gameplays

![Screenshot 2024-07-07 14-00-00](https://github.com/JordanSantiagoYT/FNF-JS-Engine/assets/108278470/d4e89995-fa14-40bf-a5d6-d1647548fd93)

![Screenshot 2024-07-07 14-01-15](https://github.com/JordanSantiagoYT/FNF-JS-Engine/assets/108278470/b6d7d5ef-196d-4c39-9055-97815d63cdf0)

![Screenshot 2024-07-07 13-58-45](https://github.com/JordanSantiagoYT/FNF-JS-Engine/assets/108278470/a65ea8b5-8b0d-4643-b7e0-cddd3972422b)

![image](https://github.com/user-attachments/assets/aea20297-1695-4b83-b17e-342685490414)
- Gameplay from @TheStinkern

![0203(1)](https://github.com/user-attachments/assets/15620fa6-52a9-4090-996f-80a80bda32ef)
- Gameplay from @TheStinkern
  - See the full gameplay [here](https://www.youtube.com/watch?v=Z2iXD1FbX1I)

# FAQs

Frequently Asked Questions (FAQs) are found in [here](https://github.com/JordanSantiagoYT/FNF-JS-Engine/wiki) or you can simply see it below.

**Q: Can I use this engine for my mod(s)?**

A: Yes, you can! just be sure to credit me ([@JordanSantiago on YouTube](https://www.youtube.com/@JordanSantiago)) and give a link to the Engine's github/gamebanana, or [the link to download the latest release.](https://github.com/JordanSantiagoYT/FNF-JS-Engine/releases/latest)

**Q: How do I change and add things?**

A: You do it here the [same way you'd do it in Psych Engine.](https://github.com/ShadowMario/FNF-PsychEngine/wiki)

**Q: I found a bug!**

A: Report [here.](https://github.com/JordanSantiagoYT/FNF-JS-Engine/issues) Also, **please check if there are already posts about the same issue.**

**Q: I found a *WAY* to fix a bug!**

A: Send [here.](https://github.com/JordanSantiagoYT/FNF-JS-Engine/pulls)

# Compiling JS Engine

Refer to [the Build Instructions](./BUILDING.md)

If you get an error while Compiling, go [here](https://github.com/JordanSantiagoYT/FNF-JS-Engine/issues/359) to see if the issue is on there, if not, make an issue

## Customization:

if you wish to disable things like *Lua Scripts* or *Video Cutscenes*, you can read over to `Project.hxp`

inside `Project.hxp`, you will find several variables to customize JS Engine to your liking

to start you off, disabling Videos should be simple, simply Delete the line `VIDEOS_ALLOWED.apply(this, true);` or comment it out by adding `//` behind the code block, like this: `// VIDEOS_ALLOWED.apply(this, true);`

same goes for *Lua Scripts*, comment out or delete the line with `LUA_ALLOWED.apply(this, true);`, this and other customization options are all available within the `Project.hxp` file.

# Contributors

@JordanSantiagoYT (of course)
- He's the owner... What do you think?

@TheStinkern
- Small coder

@moxie-coder
- Codes part of the engine

@NAEL2XD
- Does pull requests

@PatoFlamejanteTV
- Small coding, also made a PDF guide for JS Engine.

### The rest of the lovely contributors on GitHub! (Psych and JS Engine)
<a href="https://github.com/JordanSantiagoYT/FNF-JS-Engine/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=JordanSantiagoYT/FNF-JS-Engine" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

<details>
  <summary><h2>OG Psych Engine Credits and Stuff</h2></summary>

* Shadow Mario - Programmer
* RiverOaken - Artist

### Special Thanks
* bbpanzu - Ex-Programmer
* SqirraRNG - Crash Handler and Base code for Chart Editor's Waveform
* KadeDev - Fixed some cool stuff on Chart Editor and other PRs
* iFlicky - Composer of Psync and Tea Time, also made the Dialogue Sounds
* PolybiusProxy - Former .MP4 Video Loader Library (hxCodec)
* MAJigsaw77 - .MP4 Video Loader Library (hxVLC)
* Keoiki - Note Splash Animations
* Smokey - Sprite Atlas Support
* Nebula the Zorua - LUA JIT Fork and some Lua reworks
_____________________________________

# Features

## Attractive animated dialogue boxes:

![](https://user-images.githubusercontent.com/44785097/127706669-71cd5cdb-5c2a-4ecc-871b-98a276ae8070.gif)


## Mod Support
* Probably one of the main points of this engine, you can code in .lua files outside of the source code, making your own weeks without even messing with the source!
* Comes with a Mod Organizing/Disabling Menu.


## Atleast one change to every week:
### Week 1:
  * New Dad Left sing sprite
  * Unused stage lights are now used
### Week 2:
  * Both BF and Skid & Pump does "Hey!" animations
  * Thunders does a quick light flash and zooms the camera in slightly
  * Added a quick transition/cutscene to Monster
### Week 3:
  * BF does "Hey!" during Philly Nice
  * Blammed has a cool new colors flash during that sick part of the song
### Week 4:
  * Better hair physics for Mom/Boyfriend (Maybe even slightly better than Week 7's :eyes:)
  * Henchmen die during all songs. Yeah :(
### Week 5:
  * Bottom Boppers and GF does "Hey!" animations during Cocoa and Eggnog
  * On Winter Horrorland, GF bops her head slower in some parts of the song.
### Week 6:
  * On Thorns, the HUD is hidden during the cutscene
  * Also there's the Background girls being spooky during the "Hey!" parts of the Instrumental

## Cool new Chart Editor changes and countless bug fixes
![](https://github.com/ShadowMario/FNF-PsychEngine/blob/main/docs/img/chart.png?raw=true)
* You can now chart "Event" notes, which are bookmarks that trigger specific actions that usually were hardcoded on the vanilla version of the game.
* Your song's BPM can now have decimal values
* You can manually adjust a Note's strum time if you're really going for milisecond precision
* You can change a note's type on the Editor, it comes with two example types:
  * Alt Animation: Forces an alt animation to play, useful for songs like Ugh/Stress
  * Hey: Forces a "Hey" animation instead of the base Sing animation, if Boyfriend hits this note, Girlfriend will do a "Hey!" too.

## Multiple editors to assist you in making your own Mod
![Screenshot_3](https://user-images.githubusercontent.com/44785097/144629914-1fe55999-2f18-4cc1-bc70-afe616d74ae5.png)
* Working both for Source code modding and Downloaded builds!

## Story mode menu rework:
![](https://i.imgur.com/UB2EKpV.png)
* Added a different BG to every song (less Tutorial)
* All menu characters are now in individual spritesheets, makes modding it easier.

## Credits menu
![Screenshot_1](https://user-images.githubusercontent.com/44785097/144632635-f263fb22-b879-4d6b-96d6-865e9562b907.png)
* You can add a head icon, name, description and a Redirect link for when the player presses Enter while the item is currently selected.

## Awards/Achievements
* The engine comes with 21 example achievements that you can mess with and learn how it works (Check Achievements.hx and search for "checkForAchievement" on play/helpers/PlayStatePlayback.hx)

## Options menu:
* You can change Note colors, Delay and Combo Offset, Controls and Preferences there.
 * On Preferences you can toggle Downscroll, Middlescroll, Anti-Aliasing, Framerate, Low Quality, Note Splashes, Flashing Lights, etc.

## Other gameplay features:
* When the enemy hits a note, their strum note also glows.
* Lag doesn't impact the camera movement and player icon scaling anymore.
* Some stuff based on Week 7's changes has been put in (Background colors on Freeplay, Note splashes)
* You can reset your Score on Freeplay/Story Mode by pressing Reset button.
* You can listen to a song or adjust Scroll Speed/Damage taken/etc. on Freeplay by pressing Space.
