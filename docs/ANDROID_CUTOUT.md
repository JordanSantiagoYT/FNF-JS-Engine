# Cutout / real fullscreen

Android: **Options → Visuals and UI → Respect cut-out**. Checked (default)
keeps the game clear of the camera/notch; unchecked selects **Real Fullscreen**.
The preference uses ClientPrefs persistence, is flushed when changed, and is
applied after preferences load. No activity restart is requested.

Implementation lives in `source/android/src/quack/fnf/phoenix/android/PhoenixDisplay.java`;
Haxe only supplies the preference/menu and calls the existing JNI bridge.

- API <28: no cutout API, so no-op.
- API 28–29: NEVER versus SHORT_EDGES (ALWAYS was added in API 30).
- API 30–34: NEVER versus ALWAYS.
- API 35+: this project targets SDK 36. Edge-to-edge enforcement can interpret
  NEVER/DEFAULT/SHORT_EDGES as ALWAYS for non-floating windows. Use ALWAYS and
  apply physical cutout safe insets as padding on the native content container
  only in respect mode. The inset listener recalculates after rotation and
  layout changes, preserves original padding, and does not accumulate insets.
  The SDL surface resizes with its container; this is not a Haxe camera offset.

Window attributes change on the UI thread and request layout and fresh insets.
Physical cutout reporting through AndroidDisplay remains unchanged (even when
Real Fullscreen is selected). No cached safe-inset values are used.
This option does not change the logical game aspect ratio or stretch gameplay;
aspect-ratio bars can still exist on ultrawide displays. System navigation and
transient bars remain controlled by the existing immersive-mode API.

## Other platforms reviewed

- iOS: the repository has an Info.plist template, but no native UIKit safe-area
  layout implementation or cutout preference bridge. Rendering is delegated to
  Lime/SDL. Android window flags cannot affect iOS; a corresponding iOS option
  would require a UIKit/Lime implementation and on-device verification. The
  Android-only menu entry is deliberately not offered as a nonfunctional iOS toggle.
- Desktop: window decorations are outside the client drawable area, managed by
  Lime/SDL/the window manager. WindowBackend changes Windows decoration colors,
  not safe-area insets. This option does not remove desktop decorations or alter
  existing fullscreen behavior. macOS notched-display behavior is likewise left
  to the native backend; no cross-platform notch support is claimed.

## Validation

Source integration checks: `python3 -m unittest discover -s tests -p 'test_android_cutout.py'`.
These do not replace Android builds or device testing.

Device acceptance checklist (API 28/29, 30–34, and 35/36):

1. Launch on a notched/hole-punch device in landscape. Checked must keep game
   content clear of the cutout. Uncheck: the native surface must expand into that
   area without restarting. Touch targets must still align with rendered controls.
2. Toggle repeatedly: no cumulative padding. Rotate to both landscape directions
   (and portrait if supported): safe padding follows the physical cutout.
3. Background/resume and show/dismiss transient system bars: selection remains
   effective. Force-stop/relaunch: saved selection is reapplied.
4. Reset options to defaults: respect mode returns. Repeat on a device without
   a cutout: neither choice should introduce safe padding.
5. Check JNI/logcat errors and verify old Android versions do not access ALWAYS.

This workspace has no Haxe/Lime toolchain, Android SDK, emulator or attached
cutout device. Full build and visual acceptance remain unverified here.
