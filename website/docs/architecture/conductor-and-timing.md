---
title: Conductor & timing
sidebar_position: 6
description: Song position, beats, steps, sections, BPM changes and hit windows.
---

# Conductor & timing

**`backend.Conductor`** is the clock everything musical reads from. It is entirely static:
there is one song playing at a time, so there is one conductor.

## Core values

| Field | Meaning |
|---|---|
| `songPosition:Float` | current playback position in **milliseconds** |
| `bpm:Float` | current BPM (changes as the song crosses BPM-change sections) |
| `crochet:Float` | milliseconds per beat — `(60 / bpm) * 1000` |
| `stepCrochet:Float` | milliseconds per step — `crochet / 4` |
| `offset:Float` | global audio offset |
| `safeZoneOffset:Float` | hit window in ms — `(ClientPrefs.safeFrames / 60) * 1000` |
| `timeScale:Float` | `safeZoneOffset / 180`, scales every judgement window |
| `bpmChangeMap:Array<BPMChangeEvent>` | precomputed BPM changes for the loaded chart |

Stepmania-derived row constants are used by the chart editor and some conversions:
`ROWS_PER_BEAT = 48`, `BEATS_PER_MEASURE = 4`, `ROWS_PER_MEASURE = 192`,
`MAX_NOTE_ROW = 1 << 30`.

## The units

```text
section = 4 beats (by default; charts may set sectionBeats)
beat    = 4 steps
step    = stepCrochet milliseconds
```

| Conversion | Function |
|---|---|
| time → step | `getStep(time)`, `getStepRounded(time)` |
| time → beat | `getBeat(time)`, `getBeatRounded(time)` |
| beat → seconds | `beatToSeconds(beat)` |
| beat ↔ row | `beatToRow(beat)`, `rowToBeat(row)` |
| time → row | `secsToRow(time)` |
| time → BPM | `getBPMFromSeconds(time)`, `getBPMFromStep(step)`, `getCrotchetAtTime(time)` |

## BPM changes

`Conductor.mapBPMChanges(song)` walks the chart's sections once, and records every section
where `changeBPM` is set into `bpmChangeMap` with its step time and BPM. Everything after
that — step/beat conversion, the chart editor grid, note spawn times — reads from the map
instead of re-scanning the chart.

`Conductor.changeBPM(newBpm)` updates `bpm`, `crochet` and `stepCrochet` together;
`calculateCrochet(bpm)` is the inline helper.

:::note Sustain notes and BPM
A historical bug dropped sustain notes in charts with no BPM changes at all. The engine
now always seeds the map with the song's base BPM.
:::

## Beat callbacks

`backend.MusicBeatState` (and `MusicBeatSubstate`) turn `songPosition` into callbacks every
state can override:

```haxe
override function stepHit():Void {
  super.stepHit();
  // runs 16× per section with the default 4-beat section
}

override function beatHit():Void { ... }     // 4× per section by default
override function sectionHit():Void { ... }  // once per section
```

The 16/4 figures are the defaults for a four-beat section. `curBeat` is always
`Math.floor(curStep / 4)`, but the step count of a section comes from
`Math.round(getBeatsOnSection() * 4)`, so charts that change `sectionBeats` change how many
steps and beats each section produces.

Internally `update()` recomputes `curStep` from the BPM map, then:

- fires `stepHit()` for every step boundary crossed,
- fires `beatHit()` when `curStep % 4 == 0` (`curBeat = curStep >> 2`),
- advances `curSection` using each section's `sectionBeats` and fires `sectionHit()`.

When a stage is active, the state forwards `curStep`/`curBeat`/`curSection` to it and calls
the stage's own `stepHit()`/`beatHit()`/`sectionHit()` — that is how hardcoded stages in
`stages/` animate on beat.

In gameplay, the same three callbacks are broadcast to scripts as
[`onStepHit`, `onBeatHit`, `onSectionHit`](../modding/script-hooks.md).

## Judgements

`Conductor.judgeNote(note, diff, botplay, missedNote)` returns the `Rating` for a hit:
it walks `PlayState.instance.ratingsData` (loaded by `Rating.loadDefault()`) and returns
the first window the absolute timing difference fits into; botplay and misses short-circuit
to the first entry.

Hit windows are **decimal** (merged from Psych 1.0) and are read verbatim from
`ClientPrefs.<rating>Window` when each `Rating` is built; they do **not** scale
with `timeScale`. `timeScale` scales only the accuracy ("wife3") calculation.
`Conductor.recalculateTimings()` recomputes `safeZoneOffset` and `timeScale`
from `ClientPrefs.safeFrames`; it runs after `ClientPrefs.loadPrefs()` and
whenever the Safe Frames option changes (#43), so changing *safe frames* in
the options takes effect immediately for note spawning and accuracy.

Ratings themselves (`Rating` class in the same module) hold a name, score, accuracy weight
and hit counter, with `increase(n)` used by the rating code in
`play.helpers.PlayStateRating`.

## Playback rate

`PlayState.playbackRate` scales both audio pitch (`FlxSound.pitch`, where supported) and
the conductor's advance. On Flash/AIR there is no real pitch shifting — the
[haxelib patch](./haxelib-patches.md) adds a store-only `pitch` property so the code
compiles, and `#if FLX_PITCH` guards the places where actual pitch shifting matters.
