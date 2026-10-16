---
title: Source tree
sidebar_position: 2
description: Every folder in the repository and the package layout of source/.
---

# Source tree

## Repository root

| Path | Contents |
|---|---|
| `source/` | all engine Haxe code — 284 modules in 36 packages |
| `source/source-haxelib-patches/` | whole-file overrides of `flixel`, `openfl`, `funkin.vis` ([details](./haxelib-patches.md)) |
| `assets/` | asset libraries: `preload/`, `shared/`, `songs/`, `week*/`, `videos/`, `fonts/`, `embed/` |
| `mods/` | user mods; ships with the `bf-clicker` example |
| `example_mods/` | `modTemplate.zip` and script templates |
| `android/src/quack/fnf/phoenix/android/` | Java injected into Android builds (`PhoenixCore`, `PhoenixDisplay`, `PhoenixInput`, `PhoenixMedia`, `PhoenixMediaService`, `PhoenixStorage`) |
| `art/` | icons and developer build scripts |
| `setup/` | haxelib bootstrap (`windows.bat`, `unix.sh`), MSVC fix, Android STL copy, URI registration |
| `templates/` | Lime project templates (manifests, HTML shell, plists) |
| `tools/` | repository tooling |
| `tests/` | test project |
| `docs/` | legacy docs: `ANDROID_PLATFORM.md`, script templates, the old JS Engine PDF |
| `website/` | this documentation site |
| `project.hxp` | the Lime project, written in Haxe ([details](../getting-started/project-configuration.md)) |
| `hmm.json` | pinned haxelib dependencies |
| `checkstyle.json` / `hxformat.json` | lint and formatter configuration |
| `modsList.txt` | enabled/disabled mods |
| `gamemode.ini` | Feral GameMode profile (Linux) |

Documentation files at the root: `README.md` (features and the patch system),
`BUILDING.md` (build instructions), `CODESTYLE.md` (per-language style rules),
`AGENTS.md` (canonical instructions for AI agents), `TODO.md`, `THECHANGELOG.md`,
`URI.MD` (the `phoenix://` scheme).

## Packages in `source/`

| Package | Modules | Role |
|---|---|---|
| *(root)* | 2 | `Main` (entry point), `import.hx` (implicit imports) |
| `backend` | 25 | engine services — paths, prefs, conductor, controls, mods, state bases |
| `backend.deeplink` | 2 | `phoenix://` URI parsing and routing |
| `data` | 3 | `Song`, `Section`, `StageData` — the chart/stage data model |
| `debug` | 2 (+1) | FPS counter, memory sampling (`debug.mem` has a C++ include) |
| `editors` | 10 | chart, character, dialogue, week, menu-character, note-splash editors |
| `editors.charting` | 7 | grid, sections, waveform, selection, save/load, events |
| `editors.helpers` | 4 | per-editor helper modules |
| `states` | 14 | title, main menu, story, freeplay, mods, credits, achievements, loading, error |
| `states.helpers` | 3 | freeplay, mods menu, gameplay changers |
| `states.substates` | 4 | pause, game over, gameplay changers, reset score |
| `play` | 3 | `PlayState`, `BaseStage`, `CutsceneHandler` |
| `play.helpers` | 14 | the split halves of `PlayState` |
| `play.objects` | 3 | rating/judge/MS popups, sustain splash |
| `objects` | 24 | `Note`, `Character`, `Alphabet`, icons, dialogue, menu items |
| `options` | 13 | options menus and the `Option` model |
| `options.helpers` | 2 | note-colour preview, shared menu logic |
| `psychlua` | 12 | Lua/Python/HScript hosts, `Convert`, modchart sprites |
| `psychlua.callbacks` | 15 | the Lua standard library, grouped by topic |
| `psychlua.pystdlib` | 11 | the Python standard library |
| `stages` | 13 | hardcoded base-game stages |
| `stages.objects` | 13 | stage props (train, tankmen, A-Bot speaker, …) |
| `shaders` | 42 | GLSL effects, mostly `*Shader` + `*Effect` pairs |
| `music` | 1 | the freeplay music player |
| `mobile` | 4 (+5) | touch controls, storage, first-run copy state |
| `android` | 1 (+13) | JNI bridges and the Android platform services |
| `utils` | 6 | platform detection, native calls, memory, dates |
| `headers` | 6 | `typedef` re-export modules |
| `flixel`, `flixel.addons.ui`, `flxanimate` | 2+ | engine overrides of library classes |

## Naming and layout conventions

- **One public type per module**, file name equal to the type name.
- **Helpers are static** and take the owning state as the first parameter.
- **`*Shader` / `*Effect` pairs**: the shader holds the GLSL, the effect wraps it with
  animatable parameters and an `update(elapsed)`.
- **`REFACTOR:` comments** mark code moved out of the old flat layout — they document where
  something came from, which is useful when porting a Psych patch.
- **Platform-specific code** lives in `utils/`, `mobile/`, `android/` rather than inside
  gameplay files; gameplay code should rarely contain `#if android`.

See the [code reference](../reference/index.md) for a per-package type listing generated
from the sources.
