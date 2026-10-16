---
title: Script hooks
sidebar_position: 20
description: Every callback the engine fires into Lua, Python and HScript, with arguments and return semantics.
---

# Script hooks

Hooks are plain functions you define in a script. The engine calls the ones it finds and
caches the absence of the rest, so unused hooks cost nothing.

Syntax below is Lua; Python is identical with `def name(args):`.

## Return values

| Return | Effect |
|---|---|
| nothing / `Function_Continue` | the engine proceeds normally |
| `Function_Stop` | cancels the engine's default behaviour for that hook |
| `Function_StopLua` (Python: also `Function_StopAll`) | stops the hook propagating to further scripts |

Only hooks documented as cancellable react to `Function_Stop`.

## Lifecycle

| Hook | When | Cancellable |
|---|---|---|
| `onCreate()` | script created; many `PlayState` variables do not exist yet | |
| `onCreatePost()` | end of `create()` — **the recommended setup point** | |
| `onDestroy()` | script ending (song fade-out finished) | |
| `onUpdate(elapsed)` | start of the frame, before engine updates | |
| `onUpdatePost(elapsed)` | end of the frame | |

## Song flow

| Hook | When | Cancellable |
|---|---|---|
| `onStartCountdown()` | before the countdown — stop it to run a dialogue, then call `startCountdown()` | ✓ |
| `onCountdownStarted()` | the countdown actually began | |
| `onCountdownTick(counter)` | `0`=Three, `1`=Two, `2`=One, `3`=Go!, `4`=none | |
| `onSongStart()` | inst + vocals start, `songPosition = 0` | |
| `onEndSong()` | song finished / transition starting | ✓ |
| `onStepHit()` | 16× per section | |
| `onBeatHit()` | 4× per section | |
| `onSectionHit()` | once per section | |

## Notes and input

| Hook | Arguments | Notes |
|---|---|---|
| `onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)` | | fired as a note enters play |
| `goodNoteHit(id, direction, noteType, isSustainNote)` | | player hit a note |
| `opponentNoteHit(id, direction, noteType, isSustainNote)` | | opponent hit a note |
| `noteMiss(id, direction, noteType, isSustainNote)` | | note missed by letting it pass |
| `noteMissPress(direction)` | | ghost miss — pressed with no note |
| `onGhostTap(key)` | | a tap that hit nothing, with ghost tapping on |
| `onKeyPress(key)` / `onKeyRelease(key)` | | raw lane input |

`id` is the note's member index — read more with
`getPropertyFromGroup('notes', id, 'strumTime')`. Direction: `0` left, `1` down,
`2` up, `3` right.

## Events

| Hook | Arguments | Notes |
|---|---|---|
| `onEvent(name, value1, value2, strumTime)` | | an event note fired (**not** fired by `triggerEvent()`) |
| `eventEarlyTrigger(name, value1, value2, strumTime)` | | return a millisecond offset to fire the event earlier; overrides the engine's hardcoded values |

```lua
function eventEarlyTrigger(name, value1, value2, strumTime)
    if name == 'Kill Henchmen' then
        return 280   -- fire 280ms early so the sound lands on the beat
    end
end
```

## Pause, game over, dialogue

| Hook | Arguments | Cancellable |
|---|---|---|
| `onPause()` | | ✓ (block pausing) |
| `onResume()` | | |
| `onGameOver()` | called every frame health ≤ 0 | ✓ (block the game over) |
| `onGameOverStart()` | the game over screen opened | |
| `onGameOverConfirm(retry)` | `retry` is `false` when the player pressed Esc | |
| `onNextDialogue(line)` | dialogue line index, starting at 1 | |
| `onSkipDialogue(line)` | a line was skipped while typing | |

## Camera, rating, score

| Hook | Arguments | Cancellable |
|---|---|---|
| `onMoveCamera(focus)` | `'boyfriend'`, `'dad'` (or `'gf'`) | |
| `onRecalculateRating()` | fired **before** the calculation; stop it and use `setRatingPercent()` / `setRatingName()` / `setRatingFC()` for your own | ✓ |
| `onUpdateScore(miss)` | the score text is about to update | |

## Tweens, timers, sound

| Hook | Arguments |
|---|---|
| `onTweenCompleted(tag)` | a tween you started finished |
| `onTimerCompleted(tag, loops, loopsLeft)` | a timer loop finished |
| `onSoundFinished(tag)` | a sound you started finished |

## Custom substates

Scripts can open their own substate with `openCustomSubstate(name, pauseGame)`:

| Hook |
|---|
| `onCustomSubstateCreate(name)` / `onCustomSubstateCreatePost(name)` |
| `onCustomSubstateUpdate(name, elapsed)` / `onCustomSubstateUpdatePost(name, elapsed)` |
| `onCustomSubstateDestroy(name)` |

## Full engine list

These are the hook names `PlayState` and its helpers broadcast:

```text
onCreate            onCreatePost        onUpdate            onUpdatePost
onStartCountdown    onCountdownStarted  onCountdownTick     onSongStart
onStepHit           onBeatHit           onSectionHit        onEndSong
onSpawnNote         noteMiss            noteMissPress       onGhostTap
onKeyPress          onKeyRelease        onEvent             eventEarlyTrigger
onPause             onResume            onGameOver          onGameOverStart
onGameOverConfirm   onNextDialogue      onSkipDialogue      onMoveCamera
onRecalculateRating onUpdateScore       onSoundFinished     onTweenCompleted
onTimerCompleted    onCustomSubstateCreate      onCustomSubstateCreatePost
onCustomSubstateUpdate  onCustomSubstateUpdatePost  onCustomSubstateDestroy
```

Plus `goodNoteHit` / `opponentNoteHit`, which are dispatched from the note-hit path.

:::tip[Keep it cheap]

`onUpdate` and `onUpdatePost` run every frame for *every* loaded script. Move work into
beat hooks, timers or event handlers whenever the timing allows.

:::
