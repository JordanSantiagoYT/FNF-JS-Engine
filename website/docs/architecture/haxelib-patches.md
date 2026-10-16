---
title: Haxelib patches
sidebar_position: 9
description: How source/source-haxelib-patches/ shadows library modules, what each patch fixes, and how to add or remove one.
---

# Haxelib patches

`source/source-haxelib-patches/` holds **complete copies of library files** (`flixel`, `openfl`,
`funkin.vis`) with a few lines changed, committed to the repository instead of being
applied by hand into the haxelib install folder.

## Why they exist

- Some bugs are **not in `source/`** — they are in the libraries the engine builds on, so
  no `#if` inside game code can reach them.
- The libraries are already forks (`JS-Engine-things/flixel-JS-Engine`,
  `JS-Engine-things/openfl`, `JS-Engine-things/funkVis-FrequencyFixed`). Landing a fix in a
  fork means everyone must re-run setup, and an unrelated `haxelib install` can flip the
  active version back.
- Editing `~/.haxelib/...` directly is machine-local: invisible to CI, gone on a fresh
  clone, absent from the PR diff.

Committing them as a class-path override makes the patch part of the project: it applies
on every machine and every target, needs no install step or copy script, and is reviewable
as plain Haxe.

## How the override works

`project.hxp` adds exactly one extra class path, after the game's own:

```haxe
this.sources.push(SOURCE_DIR);                 // -> source/
this.sources.push("source/source-haxelib-patches");   // -> source/source-haxelib-patches/
```

Lime writes each entry as a `-cp` line in the generated hxml *after* the `-lib` class
paths, and a module present in more than one class path is taken from the **last** one
declared. So `source/source-haxelib-patches/flixel/sound/FlxSound.hx` shadows the haxelib's
`flixel/sound/FlxSound.hx` — the library copy is never opened by the compiler.

Precedence: **`source/source-haxelib-patches/` > `source/` > haxelib.**

Two consequences:

- **A patch is a whole file, not a diff.** The folder mirrors the library's package layout
  exactly (path, letter case and file name must match) and the file must compile on its own.
- **Keep the two source folders disjoint.** A module patched in both would silently be
  taken from `source/source-haxelib-patches/`. Today they are disjoint, and `tests/test_arena_fixes.py` fails if a library package (`flixel/`, `openfl/`, `funkin/`) reappears under `source/` (#46).

Because the substitution happens at Haxe compile time, a patch applies to *every* target —
which is why each one is wrapped in platform conditionals, so native builds behave exactly
like upstream.

## The current patches

The first seven exist so the **non-C++ targets (Flash / AIR)** build at all.
The last five were previously vendored under `source/flixel/…`, where they
shadowed the libraries invisibly; they were moved here in #46 so this table
is the complete patch inventory. They are based on the pinned `flixel`
revision recorded in `hmm.json` (see #58); re-diff them whenever that pin
changes.

| Patch file | Library | What breaks without it | What the patch does |
|---|---|---|---|
| `flixel/sound/FlxSound.hx` | flixel | `FLX_PITCH` is undefined on Flash/AIR, so `FlxSound` has no `pitch` — and the engine sets it in `PlayState`, `PlayStatePlayback`, `PlayStateChartLoader`, `MusicPlayer`, `ChartingState` | adds a store-only `pitch` property under `#if (flash \|\| air)`; the value is kept but nothing pitch-shifts |
| `flixel/graphics/tile/FlxDrawQuadsItem.hx` | flixel | the fork draws tile batches through a shader fill (`graphics.shader`, `beginShaderFill`, `overrideBlendMode`) which does not exist on Flash | wraps the shader-blit block in `#if !flash`; quad rendering is skipped there instead of failing the build |
| `flixel/graphics/tile/FlxDrawTrianglesItem.hx` | flixel | same shader-blit path in the triangle batch item | same `#if !flash` treatment, keeping the `FLX_DEBUG` outline code |
| `flixel/util/FlxGradient.hx` | flixel | Flash's `beginGradientFill()` wants `UInt` colors and integer alphas; flixel passes `Array<FlxColor>` / `Array<Float>`. Hits `options/NotesSubState.hx` and `shaders/CustomFadeTransition.hx` | converts colors to `UInt` and floors alphas **only** under `#if flash` |
| `flixel/util/FlxSave.hx` | flixel | `FlxSharedObject` re-implements save directories with `sys.FileSystem`/`sys.io.File`, absent on SWF — so `FlxG.save` and `ClientPrefs` cannot build | adds `flash \|\| air` to the `#if (android \|\| ios)` branch so those targets use `SharedObject.getLocal()` |
| `openfl/utils/Assets.hx` | openfl | `getBitmapData()` probes `.astc`/`.ktx`/`.dds` sidecars via `Context3D`, which SWF has no path for — affects essentially every asset lookup | wraps the compressed-texture probe in `#if (!flash && !air)` so SWF falls through to `LimeAssets.getImage()` |
| `funkin/vis/dsp/SpectralAnalyzer.hx` | funkin.vis | `#if web` also matches SWF, pulling in the Web-Audio analyzer, while the `#else` branch needs a Lime `AudioSource`. Used by `stages/objects/ABotSpeaker.hx` | rewrites the guards as `#if (web && !flash)` / `#elseif !flash`, so neither backend is referenced on Flash/AIR |

| `flixel/FlxGame.hx` | flixel | upstream `FlxGame` has no engine hooks: the game loop needs the cached `_isPlayState` flag, the `ClientPrefs.ffmpegMode` fixed-step branch and Flash focus-event guards | imports `backend.ClientPrefs`/`data.Section`/`objects.Note`/`play.PlayState`, caches whether the current state is `PlayState`, adds the `FLX_POST_PROCESS` blocks and the `ffmpegMode` fixed-step branch (#46) |
| `flixel/addons/ui/FlxInputText.hx` | flixel-addons | the text field needs engine-specific character handling | vendored copy with `objects.Character` integration (#46) |
| `flixel/addons/ui/FlxSlider.hx` | flixel-addons | the slider needs the engine's `backend.Controls` bindings | vendored copy importing `backend.Controls` (#46) |
| `flixel/addons/ui/FlxUIDropDownMenu.hx` | flixel-addons | dropdown behaviour patched for the editors | vendored copy; no game-package imports, kept with the other UI patches so the set is inventoried together (#46) |
| `flixel/addons/ui/FlxUIInputText.hx` | flixel-addons | `FlxUI` wrapper over the patched `FlxInputText` | vendored copy matching the patched `FlxInputText` above (#46) |

Notes:

- AIR compiles as a SWF target and Lime defines `flash` for it too, so `#if flash` already
  covers AIR; the explicit `#if (flash || air)` form is used where the stubbed property is
  the only difference.
- No patch changes gameplay, rendering or saving on native desktop/mobile builds, nor on
  neko/html5 — they only remove or retype code that cannot compile on SWF.

## How game code uses them

Nothing imports from this folder and there is no API to call. `source/` keeps referencing
`flixel.sound.FlxSound`, `openfl.utils.Assets`, `flixel.util.FlxSave` and
`funkin.vis.dsp.SpectralAnalyzer`; the patched copy is what gets compiled.

- Write against the **patched** API without extra guards when the patch guarantees it
  exists everywhere: `state.vocals.pitch = state.playbackRate` in
  `play/helpers/PlayStateChartLoader.hx` needs no `#if`.
- Keep `#if FLX_PITCH` where *real* pitch shifting matters (`play/helpers/PlayStateCamera.hx`) —
  the stub only stores a value.
- A patch is a promise to every target. If you add `FlxSound.foo()`, `foo()` becomes
  usable unguarded from `source/`; if you delete a patch, grep for the usages it covered.

## Adding, updating, removing a patch

```bash
# 1. find the active copy of the library
haxelib libpath flixel

# 2. mirror the exact package path and copy the file (never hand-write one)
mkdir -p source/source-haxelib-patches/flixel/sound
cp "$(haxelib libpath flixel)/flixel/sound/FlxSound.hx" source/source-haxelib-patches/flixel/sound/FlxSound.hx

# 3. edit only what is needed, keep upstream formatting/tabs, guard with #if,
#    and leave a comment saying WHICH TARGET needs it and WHY

# 4. review the delta the way a reviewer will
diff -u "$(haxelib libpath flixel)/flixel/sound/FlxSound.hx" source/source-haxelib-patches/flixel/sound/FlxSound.hx
```

- Patch here only for **library** fixes. Engine behaviour belongs in `source/` (or,
  better, in a PR to the fork).
- The smaller the diff in step 4, the easier the patch is to keep alive. **Never reformat
  a patched file.**
- When a library is bumped (re-running `setup/unix.sh` / `setup/windows.bat`, or a new ref
  in `hmm.json`), re-diff **every** patch: the copy is frozen at the moment it was taken,
  so a stale patch silently reverts upstream fixes.
- Un-applying a patch is `git rm source/source-haxelib-patches/<path>` — nothing was written into
  the haxelib, so there is nothing to restore (build with `-clean` if you still see old
  output).
- When the set of patched files changes, update the list in `BUILDING.md`
  ("Machine-local haxelib patches") and on this page.

## Verifying a patch is picked up

```bash
haxelib run lime build windows -Dofficial
grep -rn "source/source-haxelib-patches" build/release/haxe/*.hxml   # must appear after -cp source/
```

Brute-force proof: introduce a syntax error in the patch file and rebuild — the compiler
should stop inside `source/source-haxelib-patches/`, not inside `~/.haxelib`.

:::warning Not everything belongs here
Anything that cannot be expressed in Haxe (C/C++, Java/Kotlin, Objective-C, Win32) goes
through `project.hxp` build callbacks and `setup/` scripts instead — for example
`configureAndroidRuntime` + `setup/android-copy-stl.sh`, or `setup/windows-msvc-fix.ps1`.
:::
