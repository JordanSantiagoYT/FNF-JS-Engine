---
title: Mod folder structure
sidebar_position: 2
description: Every folder the engine recognises inside a mod, plus pack.json, modsList.txt and load order.
---

# Mod folder structure

A mod is a folder inside `mods/`. Nothing is registered or compiled — the engine
discovers folders at startup and resolves assets through them.

```text
mods/
├── modsList.txt is in the game root, not here
└── MyMod/
    ├── pack.json              # metadata (optional but recommended)
    ├── data/                  # charts, song JSON, per-song scripts
    │   └── mySong/
    │       ├── mySong.json
    │       ├── mySong-hard.json
    │       ├── events.json
    │       └── mySong.lua
    ├── songs/                 # audio
    │   └── mySong/
    │       ├── Inst.ogg
    │       └── Voices.ogg
    ├── weeks/                 # week definitions
    │   └── myWeek.json
    ├── characters/            # character JSON
    │   └── my-char.json
    ├── stages/                # stage JSON + stage scripts
    │   ├── myStage.json
    │   └── myStage.lua
    ├── images/                # PNG + XML/TXT/JSON atlas data
    ├── sounds/                # SFX
    ├── music/                 # music tracks (menu overrides included)
    ├── videos/                # cutscenes
    ├── fonts/                 # TTF/OTF
    ├── shaders/               # .frag / .vert for runtime shaders
    ├── scripts/               # global scripts (always loaded in gameplay)
    ├── custom_events/         # <eventName>.lua / .py
    ├── custom_notetypes/      # <noteType>.lua / .py
    └── achievements/          # custom achievements
```

Those folder names are exactly the list in `Mods.ignoreModFolders` — they are *content*
folders, so the mods manager never treats them as nested mods.

## `pack.json`

Read by `Mods.getPack(folder)`, parsed with the tolerant `tjson`:

```json
{
  "name": "My Mod",
  "description": "What it does.",
  "restart": false,
  "color": [255, 128, 0],
  "runsGlobally": false
}
```

| Field | Effect |
|---|---|
| `name`, `description` | shown in the mods menu |
| `color` | accent colour in the list |
| `restart` | ask for a restart when toggled |
| `runsGlobally` | **important** — see below |

### Global mods

A mod with `"runsGlobally": true` is collected by `Mods.pushGlobalMods()` at startup and
its assets and `scripts/` apply **even when another mod is the active one**. Use it for
things like a global HUD replacement or a universal script; use a normal mod for a song
pack.

## Enabling mods

`modsList.txt` in the game root, one entry per line:

```text
bf-clicker|1
MyMod|0
```

`1` = enabled, `0` = disabled. `Mods.parseList()` reads it and
`Mods.updateModList()` keeps it in sync with the folders actually present. The in-game
Mods menu (`states.ModsMenuState`) writes the same file, and ordering in the list is the
priority order.

## Resolution order

For any asset key, `Paths.modFolders(key)` checks:

1. `mods/<currentMod>/<key>` — the active mod,
2. `mods/<globalMod>/<key>` for each global mod, in list order,
3. `mods/<key>` — loose files directly in `mods/`,

and only then falls back to the engine's own `assets/` libraries. So a mod overrides a
base-game asset simply by using the same path:

```text
mods/MyMod/images/characters/BOYFRIEND.png   # replaces the default BF atlas
mods/MyMod/music/freakyMenu.ogg              # replaces the menu theme
```

`Mods.mergeAllTextsNamed(path, defaultDirectory, allowDuplicates)` merges list files
(like credits or achievement lists) across every enabled mod instead of letting one win,
and `Mods.directoriesWithFile(path, fileToFind)` finds every mod providing a given file.

## Scripts the engine loads automatically

| Path | When |
|---|---|
| `scripts/*.lua`, `scripts/*.py` | every song (global scripts) |
| `data/<song>/<song>.lua` / `.py` | that song |
| `stages/<stage>.lua` / `.py` | when that stage loads |
| `custom_notetypes/<type>.lua` / `.py` | when a note of that type exists in the chart |
| `custom_events/<event>.lua` / `.py` | when that event exists in the chart |

Global scripts are deduplicated by **file name** across folders, and the first match in
priority order wins. Global mods are checked *before* the active mod, so a global mod
shadows an active-mod script of the same name — the opposite of asset lookup, where
`mods/<currentMod>/` is searched first.

## Distributing

Zip the mod folder itself (so the zip contains `MyMod/`, not its contents), and tell users
to extract into `mods/`. `example_mods/modTemplate.zip` is a ready-made skeleton.

:::warning[Custom songs must live in a mod]

Songs added to `assets/` require recompiling the game. Put custom songs — chart **and**
audio **and** week JSON — inside a mod folder, or they will not be found.

:::
