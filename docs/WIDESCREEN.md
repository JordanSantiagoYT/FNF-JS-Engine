# Widescreen rendering and resize audit

## Player behavior

**Options → Graphics → Widescreen** is disabled by default and saved with the
other `ClientPrefs`. It takes effect immediately, including while the Graphics
substate is open. With the default setting, the logical game stays **1280×720**
and Flixel letterboxes wider windows as before. When enabled, the logical height remains
720 and the width grows to cover the physical aspect ratio (21:9, 32:9, etc.);
narrow windows continue to letterbox. Minimizing a window does not divide by
zero or discard the last valid viewport.

Changing a desktop resolution uses `FlxG.resizeWindow`, so the window, scale
mode, full-viewport cameras, touch input and state/substate layouts are updated
together. On Android, the current surface/insets determine the effective aspect
ratio; the preference does not force an orientation or override cutout policy.

## Visual rendering audit

| Path | Widescreen rule |
| --- | --- |
| Scale mode, game camera, HUD/overlay cameras | Recalculate a fixed-height logical viewport; resize cameras that filled the old viewport, not intentional split/editor cameras; retain the world camera center. |
| Receptors, notes, splashes, ratings, health/time/energy HUD, editor playtest | Keep Psych/JS-Engine's 1280-wide gameplay/HUD area centered; shift existing on-screen objects when the logical width changes and preserve scripted offsets. World-space stage and character coordinates remain unchanged. |
| Main menu, title, options, freeplay, story, achievements, credits, mods, warnings | Cover large menu artwork without non-uniform scaling; fill solid backgrounds/bars; re-center menu entries and reflow their `Alphabet.startPosition` animation targets. Keep freeplay search controls at the right edge and story character/art arrangements within the centered 1280-wide area. |
| Pause, options, gameplay changes, score reset, mobile-controls selector, fade transition | Reflow the open substate on resize, including solid overlay coverage, text, virtual pads and button hitboxes. |
| Mobile hitboxes and custom virtual pad | Use contiguous integer lane boundaries that reach the rightmost pixel even at odd widths; rebuild graphics *and* button bounds on resize. Keep the optional fifth control adjacent, even if its preference changes before a resize. Aggregate fingers on the same lane so releasing one cannot interrupt a held note; keep right-side buttons at the right edge and saved custom positions relative to their original viewport width. Dispose resize listeners with their owner. |
| Stage spotlight, lightning, cutscene and full-screen flashes | Use a scalable solid overscan region for camera zoom and live resize. World animations keep their 1280-based timings/positions; rain shaders already receive the current camera/view dimensions every frame. Weekend Philly skies extend tiled geometry to both wide edges without stretching the artwork. |
| Dialogue, cutscene video, skip affordances | Reflow portraits, text and cover sprites. Video preserves its source aspect ratio, crops to cover rather than stretching; the skip control stays at the screen edge. |
| Fragment shaders | The 3D projection reads OpenFL's live texture dimensions instead of hard-coding 16:9. Other active shaders use their source texture or the per-frame screen resolution; the unused fixed VFD size is removed. |
| Screenshot and FFmpeg frame capture | Screenshot flash/preview track **physical** surface pixels. FFmpeg's raw RGBA frames and declared `-s` both use physical window pixels, including optional letterboxing. An in-progress recording is finalized if the physical window/frame size changes, rather than writing malformed frames; odd output dimensions are padded for encoders requiring even sizes. |

Mod stages still control their own world-space artwork and camera settings;
they can override the new `BaseStage.onViewportResize()` hook for custom
full-screen effects. Source assets smaller than an ultrawide view are not
stretched to fill a world camera: use art/parallax that covers the newly visible
world area, or use a solid/tiling background behind it.

## Regression checks

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tests/haxe/run-layout.sh
```

The Python tests guard rendering/resize and mobile-input integration paths;
the Haxe interpreter test executes the production viewport, touch-lane and
same-lane multitouch transition math for 16:9, 21:9, 32:9, narrow, invalid,
odd-width and toggle/resize-rollback cases.
Both run in the Checks workflow (which installs Haxe 4.3.7 for the latter).
The interpreter runner copies the production math/input modules to an isolated
classpath, since the application's global `source/import.hx` needs the full
Flixel/OpenFL dependency graph. Windows and Android builds are selected in
the normal `main`-targeted PR workflow; extra targets can be requested
separately from the Build/Mobile workflows.

The pure geometry tests and integration guards **cannot prove pixel-perfect
rendering**. For release validation, compare screenshots at 1280×720,
2560×1080 and 3840×1080 while switching Widescreen on/off and dragging the
window during gameplay, menus, dialogue, a pause/options substate and a
full-screen flash. On a mobile build, repeat with the four-lane hitbox (including
the last pixel at an odd-width surface), two fingers holding the same lane while
one lifts, the optional extra control at both top and bottom, a right-side
virtual pad, custom pad positions and Android cutout/inset modes. Check both
a widescreen capture and a recording that is resized mid-song; recording
should finalize, not corrupt.
Mod-provided stage art requires its own coverage review at ultrawide widths.
