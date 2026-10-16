---
title: Preferences & save data
sidebar_position: 7
description: ClientPrefs, keybinds, highscores, achievements and where the save file lives.
---

# Preferences & save data

## `backend.ClientPrefs`

A static class holding **every** user setting as a plain field. Options menus mutate the
fields directly; gameplay reads them directly. There is no settings object to pass around.

A sample of what lives there (see the
[generated reference](../reference/backend/ClientPrefs.md) for the complete list):

| Group | Fields |
|---|---|
| Gameplay | `downScroll`, `middleScroll`, `opponentStrums`, `ghostTapping`, `noReset`, `complexAccuracy`, `noMarvJudge`, `ezSpam`, `antiCheatEnable`, `safeFrames` |
| Visuals | `noteSkin`, `splashType`, `noteSplashes`, `oppNoteSplashes`, `maxSplashLimit`, `oppNoteAlpha`, `hideHud`, `timeBarType`, `scoreStyle`, `healthBarStyle`, `iconBounceType`, `simplePopups` |
| Feedback | `hitsoundVolume`, `hitsoundType`, `missSoundEnabled`, `showNPS`, `showComboInfo`, `botWatermark` |
| Performance | `camZooms`, `showNotes`, `smoothHealth`, `comboStacking`, `enableColorShader`, `charsAndBG` |
| System | `showFPS`, `showRamUsage`, `showMaxRamUsage`, `debugInfo`, `autoPause`, `checkForUpdates`, `discordRPC`, `peOGCrash` |
| Crossfades | `crossFadeMode`, `crossFadeLimit`, `boyfriendCrossFadeLimit` |
| Mobile | `mobileCAlpha`, `mobileCEx` |

### Persistence

| Function | What it does |
|---|---|
| `loadDefaultStuff()` | snapshots the default keybinds into `defaultKeys` (called from `Main.setupGame`) |
| `loadPrefs()` | copies values out of `FlxG.save.data` into the static fields (called from `InitState`) |
| `saveSettings()` | reflects the fields back into `FlxG.save.data` and flushes |

Both directions use `Reflect` over the class fields, with **blacklists** so derived or
structural data is not round-tripped:

```haxe
"saveBlackList" => ["keyBinds", "defaultKeys", "defaultArrowRGB", "defaultPixelRGB", "defaultQuantRGB"],
"loadBlackList" => ["keyBinds", "defaultKeys", "defaultArrowRGB", "defaultPixelRGB", "defaultQuantRGB"]
```

Keybinds are saved separately as `save.data.customControls`. Volume/mute keys are pushed
back into `TitleState.muteKeys` / `volumeDownKeys` / `volumeUpKeys` after loading so Flixel
picks them up.

:::tip[Adding a setting]

1. Add a `public static var` to `ClientPrefs` with a sensible default.
2. Add an `Option` to the right substate in `options/` (see [Options menu](../subsystems/options-menu.md)).
3. Read it where it matters. Nothing else is needed — save/load is reflective.
4. If the value affects timing or rendering globally, call the relevant
   `recalculate*()` (e.g. `Conductor.recalculateTimings()`) when it changes.

:::

## Where the save lives

`InitState` binds the save as:

```haxe
FlxG.save.bind('funkin', CoolUtil.getSavePath());
```

`CoolUtil.getSavePath()` returns the company/app path used by Flixel's `FlxSave`
(`ninjamuffin99/Funkin`-compatible on desktop so saves migrate from other engines).
On Android/iOS — and, thanks to the `FlxSave` haxelib patch, on Flash/AIR — the save is a
plain `SharedObject` instead of a `sys`-based file.

## Keybinds

- `ClientPrefs.keyBinds:Map<String, Array<FlxKey>>` maps a control name to its keys.
- `backend.Controls` exposes the named actions gameplay and menus check
  (`ACCEPT`, `BACK`, `NOTE_LEFT`, …).
- `backend.PlayerSettings` sets up the input device(s) at boot.
- `backend.InputFormatter` turns a key into the label the controls menu shows.
- `options.ControlsSubState` is the rebinding UI.

## Highscores

`backend.Highscore` stores per-song and per-week records (score, accuracy, misses, rating)
in the same `FlxG.save`, keyed by formatted song name and difficulty. `data.Song` and
`states.FreeplayState` read it to show the record on the song list.

## Achievements

`backend.Achievements` (flag `ACHIEVEMENTS_ALLOWED`) holds the unlock table, also saved via
`FlxG.save`. `Achievements.load()` runs during `Main.setupGame()`.
`objects.AchievementPopup` shows the toast, `states.AchievementsMenuState` lists them, and
mods can define their own in `mods/<mod>/achievements/`.

## Script-visible save data

Scripts get an isolated namespace rather than access to `FlxG.save`:
`initSaveData`, `setDataFromSave`, `getDataFromSave` and `flushSaveData`
(see the [Lua API reference](../modding/lua-api-reference.md#save-data)).

These saves are keyed **only by the `name` you pass to `initSaveData`** (stored in
`PlayState.instance.modchartSaves`, backed by `FlxSave` under
`CoolUtil.getSavePath()/<folder>`, default folder `psychenginemods`). There is no per-mod
namespacing: two mods that call `initSaveData('save')` share the same file and will
overwrite each other's keys. Prefix your save name with your mod's id
(`initSaveData('mymod_progress')`) to stay out of other mods' data.
