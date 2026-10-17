# Cutout / real fullscreen

Android: **Options → Visuals and UI → Respect cut-out**. Checked (default)
keeps the game clear of the camera/notch; unchecked selects **Real Fullscreen**.
ClientPrefs saves the boolean through its existing reflection-based persistence,
flushes it when changed, and applies it after loading. No restart is requested.

## Native implementation

- API 21–27: no cutout window API calls or extra content wrapper.
- API 28–29: NEVER versus SHORT_EDGES (ALWAYS was added in API 30).
- API 30–34: NEVER versus ALWAYS.
- API 35–36 with target SDK >=35: respect mode uses ALWAYS plus safe-area
  padding on a **Phoenix-owned FrameLayout**, around SDL's existing layout.
  Fullscreen uses ALWAYS with zero wrapper padding. Current project min/target
  are 21/36 (`project.hxp`, `configureAndroidRuntime`).
- `default` and `shortEdges` bridge requests retain their native values and do
  not add safe padding. They are not silently rewritten to ALWAYS by our code;
  Android can still reinterpret them under platform edge-to-edge enforcement.

Only the owned wrapper's padding is changed. The framework content view and SDL
layout retain all original padding and listeners, including subsequent changes
by other owners. Insets are passed downstream without consumption. No listener
is installed on an existing view. Padding is assigned from the latest insets,
not added to prior values. Without a cutout it is zero.

`MainActivity.setContentView(View)` is called by the pinned SDLActivity with its
RelativeLayout. For enforced-edge-to-edge platforms we put that layout inside
our wrapper with MATCH_PARENT dimensions. We leave SDL's `mLayout`, `mSurface`,
SurfaceHolder, touch and mouse listeners intact. On older platforms the original
view hierarchy is unchanged. No status/navigation visibility or decor-fitting
flags are changed by this preference.

The pinned SDLSurface's `surfaceChanged` reports the resized surface dimensions
through `nativeSetScreenResolution` / `onNativeResize`. Touch handling uses
surface-local MotionEvent coordinates divided by those dimensions; mouse input
also uses local coordinates. This is architectural evidence for matching layout
and input, **not device verification**. FrameLayout measurement, SurfaceView
resizing, SDL native resize delivery, and actual edge touch alignment still need
Android runtime acceptance. No Haxe camera/input offset is introduced.

Window updates run on the UI thread. Queued updates check current Activity
identity, finishing/destroyed state and use the latest requested mode. Only the
mode is retained statically, not an Activity, View or padding. Creation, resume
and focus restoration reapply it after Lime's initialization/window setup.
Each Activity owns its wrapper and clears its reference on destruction. Android
inset dispatch updates safe padding after rotation/configuration changes. A
missing window/content is retried only at those lifecycle points, without loops.
Failures log contextual `PhoenixDisplay` diagnostics. Existing unrelated silent
catches in immersive/refresh-rate/display-watch code are outside this change.

Physical cutout reporting through AndroidDisplay is unchanged. The preference
neither stretches the logical game aspect ratio nor guarantees removal of
aspect-ratio letterboxing on ultrawide displays.

## Audit evidence

Inspected actual dependency revision from `hmm.json`:

- [Lime GameActivity, commit 45816ca](https://github.com/JS-Engine-things/lime-8.1.2/blob/45816ca456764761cbea8d3cc57701a592f892f1/templates/android/template/app/src/main/java/org/haxe/lime/GameActivity.java):
  sets Extension.mainActivity/mainView after SDL creation; applies its cutout
  template setting, then forwards extension lifecycle callbacks. Extension
  instances are retained in a static list. Destruction alone did not reapply the
  PR's cutout state to a newly created view.
- [Pinned SDLActivity / SDLSurface](https://github.com/JS-Engine-things/lime-8.1.2/blob/45816ca456764761cbea8d3cc57701a592f892f1/templates/android/template/app/src/main/java/org/libsdl/app/SDLActivity.java):
  owns the RelativeLayout/SurfaceView and resize/input handling described above.
  No existing content inset listener was found in these pinned Java templates
  or the project's original Java code. The old PR nonetheless replaced the
  framework content listener slot unconditionally; the owned wrapper removes
  that ownership risk rather than claiming a demonstrated listener collision.
- [Android 15 WindowManager SDK documentation in AOSP](https://github.com/aosp-mirror/platform_frameworks_base/blob/android-15.0.0_r1/core/java/android/view/WindowManager.java):
  DEFAULT, SHORT_EDGES, NEVER, ALWAYS semantics; ALWAYS permits all edges.
- [Android 15 ViewRootImpl](https://github.com/aosp-mirror/platform_frameworks_base/blob/android-15.0.0_r1/core/java/android/view/ViewRootImpl.java):
  `adjustLayoutInDisplayCutoutMode` rewrites to ALWAYS when edge-to-edge is
  enforced for a fullscreen window with no fit-inset types/sides. Our modern
  respect path explicitly uses ALWAYS to avoid native letterboxing plus padding.

## Other platforms

- iOS: only an Info.plist template is present, not a UIKit safe-area bridge.
  Lime/SDL owns rendering; Android flags cannot affect it. A corresponding iOS
  preference needs a native implementation and device testing, so the option
  is Android-only.
- Desktop: decorations are outside the client drawable, owned by Lime/SDL/the
  window manager. WindowBackend changes Windows decoration colors, not safe
  insets. No desktop fullscreen or macOS notch policy is changed or claimed.

## Regression coverage and validation

`python3 -m unittest discover -s tests -p 'test_android_cutout.py' -v`

Static checks cover the Haxe default, persistence wiring, startup application,
menu flush/application, lifecycle hooks and no shared-view listener replacement.
Host-JVM tests compile the production policy, layout, display bridge and rendered
MainActivity template against small Android API doubles. They exercise API groups,
repeat toggles, padding reset, changing inset edges/no cutout, Activity/view
recreation, resume/focus calls, stale queued work, latest-mode selection, missing
Activity/window, finishing/destroyed state and diagnostic error paths. They do
**not** emulate Android layout measurement, SurfaceView, SDL native code, event
dispatch, platform enforcement or actual Haxe save-file serialization.

Local audit environment: no Haxe/Lime, Android SDK/emulator or device. A temporary
Eclipse compiler 3.32.0 and Java 17 runtime allowed all 38 repository tests,
including the Java suites, to execute (no skips) after incorporating the PR
branch's concurrent merge of Media3 changes from main. CI uses actual javac 17 via
`checks.yml`; `main.yml` has the Android build with SDK 36 / NDK 27.0.12077973.
The full local Android build cannot run (`haxelib: command not found`). Haxe
Formatter/Checkstyle likewise require the missing toolchain.

## Device acceptance still required

On API 28/29, 30–34 and 35/36 cutout and non-cutout displays:

1. Toggle repeatedly: checked must avoid the cutout; unchecked must expand into
   it without restarting. No accumulating bars or padding.
2. Verify touch, clicks and dragging at all four surface edges and on mobile
   controls. Check resize events, native surface size and rendered coordinates.
3. Rotate both landscape directions (portrait if supported), background/resume,
   and show/dismiss transient bars. Padding must follow the current cutout.
4. Recreate Activity, force-stop/relaunch, reopen options and reset defaults:
   saved selection must reapply; default must respect the cutout.
5. Non-cutout devices must gain no cutout padding; unrelated bars/IME behavior
   and desktop/iOS behavior must remain unchanged. Inspect logcat diagnostics.
