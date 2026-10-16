---
title: Options menu
sidebar_position: 4
description: The Option model, the category substates and how to add a new setting.
---

# Options menu

The options tree is data-driven: each category substate builds a list of `Option` objects
that point at a field name in [`ClientPrefs`](../architecture/preferences-and-save-data.md),
and `BaseOptionsMenu` renders and edits them generically.

## `options.Option`

```haxe
new Option(name, description, variable, type, defaultValue, options)
```

| Field | Meaning |
|---|---|
| `name` / `description` | label and the help line shown under the list |
| `variable` | the `ClientPrefs` field this option reads and writes |
| `type` | `'bool'`, `'int'`, `'float'`, `'percent'`, `'string'` |
| `defaultValue` | falls back to `false` / `0` / `1` / `''` / `options[0]` per type |
| `options` | the allowed values for `'string'` type |
| `minValue`, `maxValue`, `changeValue`, `decimals` | numeric bounds and granularity |
| `scrollSpeed` | how fast the value changes while a direction is held |
| `displayFormat` | `%v` current value, `%d` default value |
| `onChange` | callback fired when the value changes |
| `showBoyfriend` | show the preview character next to the list |

`'bool'` options render as checkboxes (`objects.CheckboxThingie`); everything else renders
as text. Holding left/right on a numeric option ramps by `scrollSpeed`; holding **Shift**
multiplies the step by 5 for `int` options.

## `options.BaseOptionsMenu`

The shared substate: builds the `Alphabet` list, handles navigation, draws descriptions,
applies value changes, and owns `addOption(option)`. Every category extends it and only
supplies options in its constructor.

Performance details worth preserving: option text updates are throttled, and the score
redraw is guarded, because this menu used to re-layout every frame.

## Categories

`options.OptionsState` lists:

| Entry | Substate |
|---|---|
| Note Colors | `NotesSubState` (needs *Enable Note Colors*; the menu refuses to open otherwise) |
| Controls | `ControlsSubState` |
| Adjust Delay and Combo | `NoteOffsetState` |
| Graphics | `GraphicsSettingsSubState` |
| Optimization | `OptimizationSubState` |
| Game Rendering *(desktop/android)* | `GameRendererSettingsSubState` |
| Visuals and UI | `VisualsUISubState` |
| Gameplay | `GameplaySettingsSubState` |
| Misc | `MiscSettingsSubState` |
| Mobile Options | `mobile.options.MobileOptionsSubState` |

`options.SuperSecretDebugMenu` is the hidden debug menu behind `FEATURE_DEBUG_FUNCTIONS`.
Helpers live in `options/helpers/` (`NotesSubStateHelpers` for the colour previews,
`OptionsMenuHelpers` for shared plumbing).

Deep links can jump straight into a category — `phoenix://menu/misc` opens Options with
the Misc substate already open (see [Deep links](./deep-links.md)).

## Adding a setting

1. **Add the field** to `ClientPrefs`:

   ```haxe
   public static var myCoolToggle:Bool = true;
   ```

2. **Register the option** in the right substate's constructor:

   ```haxe
   var option = new Option(
     'My cool toggle',
     'Description shown at the bottom of the screen.',
     'myCoolToggle',
     'bool');
   addOption(option);
   ```

3. **React to changes** if needed:

   ```haxe
   option.onChange = () -> Conductor.recalculateTimings();
   ```

4. **Read it** where it matters (`ClientPrefs.myCoolToggle`).

Saving and loading are reflective, so nothing else is required — unless the field holds
structural data (maps, arrays of defaults), in which case add it to the save/load
blacklists in `ClientPrefs`.

:::tip[Gameplay modifiers]

Per-song modifiers (playback rate, instakill, practice mode…) are **not** `ClientPrefs`
options — they live in `states.substates.GameplayChangersSubstate` with
`states.helpers.GameplayChangersHelpers`, and reset when you leave gameplay.

:::
