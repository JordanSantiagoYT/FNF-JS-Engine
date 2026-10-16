---
title: Custom events & notetypes
sidebar_position: 60
description: Chart-driven scripting — defining your own event notes and note types.
---

# Custom events & notetypes

Both features work the same way: the chart names something, and the engine automatically
loads a matching script file from the mod.

## Custom events

### 1. Add the event in the chart editor

Place an event note and type a name the engine does not already handle (the built-in list
is on the [Charts & songs](../subsystems/charts-and-songs.md#events) page), plus up to two
string values.

### 2. Create the script

```text
mods/MyMod/custom_events/My Cool Event.lua
```

The file name must match the event name exactly. It is loaded automatically when the chart
contains that event.

```lua
-- mods/MyMod/custom_events/My Cool Event.lua
function onEvent(name, value1, value2)
    if name == 'My Cool Event' then
        cameraFlash('camGame', value2, tonumber(value1))
    end
end

function eventEarlyTrigger(name)
    if name == 'My Cool Event' then
        return 150   -- fire 150 ms early
    end
end
```

Python works identically with `custom_events/My Cool Event.py`.

:::note

`onEvent` fires for **every** event in the song, not only yours — always check `name`.
Events triggered from a script with `triggerEvent()` do **not** call `onEvent`.

:::

## Custom notetypes

### 1. Set the notetype in the chart

Select a note in the chart editor and set its type to a name of your choosing, for example
`Hurt Note Plus`. The value is stored as index 3 of the note entry in `sectionNotes`.

### 2. Create the script

```text
mods/MyMod/custom_notetypes/Hurt Note Plus.lua
```

Loaded automatically when the chart contains at least one note of that type.

```lua
function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
    if noteType == 'Hurt Note Plus' then
        setPropertyFromGroup('unspawnNotes', id, 'texture', 'HURTNOTE_assets')
        setPropertyFromGroup('unspawnNotes', id, 'hitHealth', 0)
        setPropertyFromGroup('unspawnNotes', id, 'missHealth', 0.5)
        setPropertyFromGroup('unspawnNotes', id, 'hitCausesMiss', true)
    end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType == 'Hurt Note Plus' then
        setProperty('health', getProperty('health') - 0.3)
    end
end
```

### Note fields worth knowing

| Field | Meaning |
|---|---|
| `texture` | note graphic override |
| `noteskin` | per-note skin |
| `hitHealth` / `missHealth` | health change on hit / miss |
| `hitCausesMiss` | hitting it counts as a miss (hurt notes) |
| `noAnimation` / `noMissAnimation` | suppress the sing / miss animation |
| `gfNote` | girlfriend sings this note |
| `ignoreNote` | not counted for score or accuracy |
| `blockHit` | cannot be hit at all |
| `lowPriority` | deprioritised when several notes overlap |
| `multSpeed` / `multAlpha` | per-note speed and transparency multipliers |
| `animSuffix` | suffix appended to the sing animation |

The complete list is on the [`objects.Note`](../reference/objects/Note.md) reference page.

Engine-side configuration for shipped notetypes lives in `backend.NoteTypesConfig`.

## Patterns

**Shared helper for several events** — put the logic in `scripts/` (global) and keep the
`custom_events/` file as a thin trigger, or call across scripts with
`callScript('scripts/helper.lua', 'doThing', {value1})`.

**Visual-only events** — create your sprites in `onCreatePost` and only toggle them in
`onEvent`, so the event handler stays cheap.

**Early triggering** — anything with an audible attack (a sound effect, a zoom that must
land on a beat) should use `eventEarlyTrigger` rather than being placed early in the
chart; the chart stays readable and the offset stays explicit.

## Testing

1. Enable the mod in `modsList.txt` or the Mods menu.
2. Open the song in the chart editor and place the event / notetype.
3. Play it. Script errors appear on-screen through the debug text.
4. `debugPrint(...)` is your friend — it prints into the same overlay.
