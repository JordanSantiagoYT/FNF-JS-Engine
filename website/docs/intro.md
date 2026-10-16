---
title: Introduction
sidebar_label: Introduction
sidebar_position: 1
slug: /intro
description: What Phoenix Engine is, how the codebase is laid out and where to start reading.
---

# Phoenix Engine

**Phoenix Engine** is a *Friday Night Funkin'* engine written in **Haxe**, built on
**OpenFL / Lime / HaxeFlixel**. It is a fork of
[JS Engine](https://github.com/JordanSantiagoYT/FNF-JS-Engine) (Jordan Santiago Engine),
which is itself a performance-oriented fork of *Psych Engine*.

Two goals drive every decision in the codebase:

1. **Performance on weak devices** — fewer allocations per frame, cached atlases and
   shaders, batched note iteration, and compile-time feature flags that remove whole
   subsystems from a build.
2. **Easy modding** — both *soft*modding (drop a folder in `mods/`, write Lua or Python)
   and *hard*modding (fork the repo and write Haxe), while staying compatible with
   existing Psych / JS Engine mods.

| | |
|---|---|
| Window title | `Friday Night Funkin' - Phoenix Engine` |
| Executable | `FNF-Phoenix-Engine` |
| Mobile package | `quack.fnf.phoenix` |
| Version | `0.3.2` (defined by `VERSION` in `project.hxp`) |
| Language | Haxe 4.2.5+ (CI builds with 4.3.x) |
| Framework | HaxeFlixel on OpenFL / Lime |
| Targets | Windows, Linux, macOS, Android, iOS, HTML5, Neko, Flash/AIR |

## How this documentation is organised

| Section | Read it when you want to… |
|---|---|
| [Getting started](./getting-started/requirements.md) | install the toolchain, compile the game, understand the build flags |
| [Architecture](./architecture/overview.md) | understand how the engine is wired together before changing it |
| [Subsystems](./subsystems/playstate.md) | work on one specific area — gameplay, charts, shaders, editors, mobile |
| [Modding](./modding/overview.md) | build a mod with Lua, Python or HScript without touching the engine |
| [Contributing](./contributing/workflow.md) | send a pull request that gets merged |
| [Code reference](./reference/index.md) | look up a class, field or method — generated from the Haxe sources |

:::tip Pick your entry point

- *"I just want to compile it."* → [Requirements](./getting-started/requirements.md) then [Building](./getting-started/building.md).
- *"I'm making a mod."* → [Modding overview](./modding/overview.md) and the
  [Lua API reference](./modding/lua-api-reference.md).
- *"I'm changing engine code."* → [Architecture overview](./architecture/overview.md) and
  [Source tree](./architecture/source-tree.md).

:::

## The codebase in one page

```text
FNF-Phoenix-Engine/
├── source/                    # all engine Haxe code (284 modules, 36 packages)
├── source/source-haxelib-patches/    # whole-file overrides of flixel/openfl/funkin.vis
├── assets/                    # preload/shared/embed asset libraries, fonts, songs
├── mods/                      # user mods (soft modding); ships with bf-clicker
├── example_mods/              # mod template zip + script templates
├── android/src/…              # Java sources injected into Android builds
├── setup/                     # per-platform haxelib bootstrap scripts
├── templates/                 # Lime project templates (manifests, html, plists)
├── tools/                     # repo tooling
├── project.hxp                # the build script: flags, targets, asset libraries
└── website/                   # this documentation site
```

The two files that explain the most, fastest, are **`project.hxp`** (what gets compiled,
with which flags, for which target) and **`source/play/PlayState.hx`** (what happens during
a song).

## Relationship to Psych and JS Engine

Phoenix keeps the Psych Engine *mod contract* — `mods/<name>/` with `characters/`,
`songs/`, `scripts/`, `custom_events/`, `custom_notetypes/`, `stages/`, `weeks/` — so most
Psych and JS Engine mods load unchanged. What Phoenix adds on top:

- **Python scripting** via Hython, mirroring the Lua API.
- A **split source tree** (`backend/`, `play/`, `states/`, `objects/`, `psychlua/`, …)
  instead of one flat folder; `PlayState`, `ChartingState` and `FunkinLua` were each cut to
  roughly half their original size by moving logic into helper modules.
- **Compile-time modding levels** (`-DMODDING_LEVEL=0|1|2`) that strip the script VMs out
  entirely for lean builds.
- **Native platform bridges** — Android MediaSession, Win32 window tweaks, Linux GameMode,
  a `phoenix://` URI scheme.
- **Haxelib patches committed to the repo** so library fixes survive a fresh clone and CI.

Everything beyond that is documented in the sections above — and the
[Code reference](./reference/index.md) is regenerated from the sources, so it never drifts
from what the compiler actually sees.
