# Android Platform Layer

This document describes the Phoenix Engine Android platform integration:
the native Java extensions, the Haxe API modules that wrap them, and how
the engine is wired to both.

Everything described here is **Android-only**. On every other target the
Haxe modules compile to no-ops (empty bodies behind `#if android`), so
gameplay code never needs to know about the platform layer.

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│ Gameplay code (PlayState, editors, options...)             │
│   talks only to: android.platform.* + MobileFilePicker     │
├────────────────────────────────────────────────────────────┤
│ Haxe API modules            source/android/platform/*.hx   │
│   AndroidMedia / AndroidSystem / AndroidDisplay / ...      │
│   (cached JNI method handles, signal fan-out, no-ops       │
│    off-Android)                                            │
├────────────────────────────────────────────────────────────┤
│ Bridge                  source/android/platform/           │
│   AndroidBridge.hx — JNI helpers + event dispatcher        │
├────────────────────────────────────────────────────────────┤
│ Java services               android/src/quack/fnf/phoenix/ │
│   PhoenixCore / PhoenixMedia / PhoenixMediaService /       │
│   PhoenixDisplay / PhoenixStorage / PhoenixInput /         │
│   PhoenixDocumentsProvider                                 │
│   (extensions use `android.extension`; DocumentsProvider   │
│    is registered directly in the manifest)                │
└────────────────────────────────────────────────────────────┘
```

- **Haxe → Java**: lazily cached `JNI.createStaticMethod` handles.
  Arrays cross the boundary as CSV strings; byte buffers via
  `haxe.io.Bytes.ofData`.
- **Java → Haxe**: extensions call `PhoenixCore.dispatch(event, arg)`
  which routes through a registered `HaxeObject` to
  `AndroidBridge.onAndroidEvent(event, arg)`. The bridge fans events out
  to the module signals (`lifecycle`, `media_*`, `focus`, `memory`,
  `gamepad_*`, `hwkey`, `display`, `deeplink`, `intent`, `permissions`,
  `recovery`).
- The boot hook lives in `Main.hx`:
  `android.platform.AndroidPlatform.init()` (Android only) initializes the
  bridge, lifecycle handling, gamepad tracking and display watching.

### Build integration (`project.hxp`)

The Android pieces are injected **only for the Android target**
(`configureAndroidRuntime()`):

- `javaPaths.push("android/src")` — Lime copies the Java extensions into
  the generated Gradle project's java source set.
- `templatePaths.push("templates")` — engine templates override Lime's:
  - `templates/android/MainActivity.java` — deep-link intents
    (`onNewIntent`) and hardware-key interception.
  - `templates/android/template/app/src/main/AndroidManifest.xml` —
    `phoenix://` intent filter, `PhoenixMediaService`
    (`foregroundServiceType="mediaPlayback"`), FileProvider, and the
    `PhoenixDocumentsProvider` SAF provider. Its registration remains behind
    Lime's `SHARE_FILES` template condition (derived from `SHARE_MOBILE_FILES`).
- `config.set("android.extension", [...])` — registers the five
  `Extension` subclasses (`PhoenixCore`, `PhoenixDisplay`,
  `PhoenixInput`, `PhoenixMedia`, `PhoenixStorage`) with Lime's
  GameActivity. `PhoenixMediaService` is an Android `Service` and
  `PhoenixDocumentsProvider` is a framework `DocumentsProvider`; both
  are declared directly in the manifest template.
- `config.set("android.permission", [...])` — Lime's defaults plus
  `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
- Signing: `PHOENIX_KEYSTORE`, `PHOENIX_KEYSTORE_PASSWORD`,
  `PHOENIX_KEYSTORE_ALIAS`, `PHOENIX_KEYSTORE_ALIAS_PASSWORD` env vars,
  falling back to a local `key.keystore` for development. No credentials
  are stored in source.
- Native desktop-only haxelibs (`hxdiscord_rpc`, `hxvlc`, `hxluajit`,
  `hxnativefiledialog`) are gated to desktop builds so Android never
  links them.

### Android SDK and Java compatibility

The Android SDK values are pinned in `project.hxp` and match the defaults from
the exact Lime revision pinned in `hmm.json` (`lime-8.1.2`, commit
`45816ca456764761cbea8d3cc57701a592f892f1`):

| Setting | Effective value | Source |
| --- | ---: | --- |
| Minimum Android API | 21 | `project.hxp`; matches Lime's default |
| Target Android API | 36 | `project.hxp`; matches Lime's default |
| Compile SDK | 36 | Lime passes the target SDK through as `ANDROID_BUILD_SDK_VERSION` |
| Android Build Tools | 36.0.0 | `project.hxp`; installed by Android CI |
| Android NDK | 27.0.12077973 (r27) | Installed and selected by both Android workflows |
| Android Gradle Plugin / Gradle | 8.9.2 / 8.11.1 | Lime's Android template defaults |
| Java build JDK | 17 | Android CI toolchain |

The generated Gradle template does not set Java `sourceCompatibility` or
`targetCompatibility`; the provider uses Java language constructs supported by
the Android toolchain. `DocumentsProvider`/`DocumentsContract` are available
before the app's API-21 floor. Rename support, root `IS_CHILD`, and grant
revocation are API-21 behaviors and are guarded where applicable; the per-path
external-storage state check also uses an API-21 method and fails closed below
the floor. The CI build installs
API 36 and Build Tools 36.0.0 to match Lime's generated project.

### System-visible app directories (`PhoenixDocumentsProvider`)

Lime's Android template only registers its generic `StorageProvider` when
`SHARE_FILES` is true; Lime derives that value from the
`SHARE_MOBILE_FILES` Haxe define. Phoenix keeps the same condition around its
replacement provider. `project.hxp` sets `SHARE_MOBILE_FILES` for mobile builds,
so normal Android builds continue to expose the SAF provider; builds without
the define omit it rather than silently enabling a new exported component.

The provider roots resolve from the same `Context.getExternalFilesDir(null)`
directory that `mobile.StorageUtil.getStorageDirectory()` returns. `Main` sets
that directory as the working directory, where `Paths.mods()` resolves to
`mods/` and `CrashHandler` writes reports under `crash/`:

| SAF root | Relative directory | Access |
| --- | --- | --- |
| **Mods** | `mods/` | Read/write; create folders/files, rename files, delete files/subfolders |
| **Crash Logs** | `crash/` | Read-only; copying reports out of the game |

Only these two roots are exposed. A missing `mods/` or `crash/` directory
remains visible as an empty SAF root and is not created just by browsing; the
mods directory is created on its first SAF write, while `CrashHandler` creates
`crash/` when it writes a report. If `getExternalFilesDir(null)` returns no
directory, or Android reports its volume as unavailable, no roots are returned.
Mounted read-only storage remains browsable but cannot be written. If storage
becomes unavailable later, document operations fail with
`FileNotFoundException`. Static traversal and symlink escapes are rejected,
and each path is revalidated near filesystem operations. The Android
`java.io.File` API does not make the check/use pair atomic, so this is not a
defense against a concurrent
filesystem writer with independent access to the same directories. The
provider is protected by `MANAGE_DOCUMENTS` and is intended for Android's
system DocumentsUI through SAF grants.

---

## Haxe API modules (`source/android/platform/`)

All modules are safe to reference from cross-platform code: every call is
a no-op outside `#if android` unless noted.

| Module | Purpose | Highlights |
| --- | --- | --- |
| `AndroidPlatform` | One-shot boot | `init(autoPauseAudio, watchDisplay)` |
| `AndroidBridge` | JNI plumbing | Event dispatch, `ensureRegistered()` |
| `AndroidLifecycle` | Activity lifecycle | `onCreate/onResume/onPause/onStop/onDestroy` signals, optional auto-pause of `FlxG.sound.music` |
| `AndroidMedia` | MediaSession/audio focus | `updateNowPlaying(title, artist, ?durationMs)`, `setPlaybackState(state, positionMs, speed)`, `updateNotification`, foreground service start/stop, `requestAudioFocus()`/`abandonAudioFocus()`, `getAudioInfo()`, signals `onPlay/onPause/onStop/onNext/onPrevious/onSeek/onAudioFocusChanged` |
| `AndroidSystem` | Device state | `onLowMemory`/`onTrimMemory`, `getBatteryInfo()`, `acquireWakeLock()`/`releaseWakeLock()`, `setRecoveryState(blob)`/`consumeRecoveryState()` |
| `AndroidDisplay` | Screen info | `getInfo()` (size, DPI, orientation, refresh), `getCutoutInsets()`, `getRefreshRate()`, `setImmersive()`, `setCutoutMode()`, `setPreferredRefreshRate()`, `onChanged` |
| `AndroidGamepad` | Controllers | `getDevices()`/`getDevice(id)` with Xbox/PlayStation/Switch/HID identification, `onConnected`/`onDisconnected`, rumble via `vibrate(deviceId, ms)` |
| `AndroidHardwareInput` | Physical keys | Volume-key interception (`enableVolumeKeys()`/`disableVolumeKeys()`), `onKey(keyCode, down)` signal |
| `AndroidHaptics` | Vibration | `vibrate(ms)`, `vibratePattern(pattern, repeat)`, `cancel()` |
| `AndroidIntents` | System intents | `openUrl`, `openSettings`, `openFile`, `shareFile`, `shareText`, `viewContentUri`, `onDeepLink` signal (`phoenix://...`) — subscribe via `subscribeDeepLink(cb)` so a buffered cold-start link is confirmed delivered |
| `AndroidNotification` | Notifications | `notify(id, title, text)`, `cancel(id)`, `requestPermission()` (API 33+) |
| `AndroidStorage` | SAF / content URIs | `openDocument`, `createDocument`, `openDocumentTree`, `readUriBytes/Text`, `writeUriBytes/Text`, `importUri`, `exportFileToUri`, `persistUriPermission`, `extensionToMime` |
| `AndroidDiscord` | Presence stand-in | No-op on Android: keeps `DiscordClient` platform-agnostic without ever touching the media session, which is owned by `PlayStateAndroidMedia` (Discord RPC is desktop-only) |

Common Android SDK classes (`android.Permissions`, `android.Settings`,
`android.content.Context`, `android.os.Build`, `android.os.Environment`)
are provided by the Lime fork itself — the engine uses those externs
directly instead of shipping its own copies, which would shadow Lime's
and break `lime.system.System` on Android.

### Gameplay integration (`play.helpers.PlayStateAndroidMedia`)

`PlayState.create()` starts and `PlayState.destroy()` stops the Android
media integration:

- The current song is published to the MediaSession
  (title/duration at create; state + position refreshed once per second).
- Audio focus is requested on start and abandoned on stop; focus **loss
  pauses the game**, **duck** lowers music volume, **gain** restores it.
- The screen is kept on for the duration of gameplay via
  `FLAG_KEEP_SCREEN_ON` on the activity window.
- A MediaStyle notification is kept in sync via `PhoenixMediaService`.
- A recovery blob (`{type:"song", song, difficulty, difficulties, mod}`) is persisted while
  playing and cleared on a clean exit, so a process kill mid-song can be
  recovered (see below).

Media buttons: **play** resumes from the pause menu, **pause/stop** open
it. `seek` is exposed as a signal (`AndroidMedia.onSeek`) rather than
applied automatically, because seeking mid-song would desync the chart.

### Process-death recovery

`PlayStateAndroidMedia.start()` writes the recovery blob via
`AndroidSystem.setRecoveryState()`. `TitleState.checkRecoveryState()`
(Android only) consumes it on boot: if it describes a song whose chart
still exists, the player gets a prompt to jump straight back into it.
A clean exit clears the blob, so the prompt never appears after quitting
normally.

---

## Files & user data (`mobile.files.MobileFilePicker`)

`source/mobile/files/MobileFilePicker.hx` is the cross-platform facade:

- **Android**: Android SAF via `AndroidStorage`
  (`ACTION_OPEN_DOCUMENT` / `ACTION_CREATE_DOCUMENT` /
  `ACTION_OPEN_DOCUMENT_TREE`), full byte transfer through the Java
  layer. `PickedFile` carries `name`, `uri`, `path` and `data`.
- **Desktop/sys**: `lime.ui.FileDialog` open/save dialogs.

API: `openFile(onResult, ?extensions, ?title)`,
`saveFile(data, suggestedName, ?mime, ?title, ?onDone)`, `saveText`,
`openFolder(onResult, ?title)`.

Wired into: chart import (`ChartingSaveLoad.promptBackup`), chart &
event export (`saveLevel`/`saveEvents`), character import (the
**Import Char** button in `CharacterEditorState`) and character export.
Desktop keeps the traditional `FileReference` download flow.

### System-visible app directories (`PhoenixDocumentsProvider`)

When Lime's `SHARE_FILES` condition is enabled (the normal Android project
build sets `SHARE_MOBILE_FILES`), the manifest registers
`quack.fnf.phoenix.android.PhoenixDocumentsProvider` under
`<application-id>.documentsprovider`, protected by
`android.permission.MANAGE_DOCUMENTS`. It replaces Lime's generic provider and
exposes only these roots from `Context.getExternalFilesDir(null)`:

| SAF root | Backing path | Access |
| --- | --- | --- |
| **Crash Logs** | `crash/` | Read-only, for copying reports out of the game |
| **Mods** | `mods/` | Read/write; create folders/files, rename files, and delete files or subfolders |

Document IDs are opaque, root-scoped path IDs. Decoded traversal, unsafe names,
and static symlink escapes are rejected; stale or unavailable storage fails
closed. `java.io.File` checks cannot atomically prevent a race with an
independent concurrent filesystem writer. The system Files picker uses the
provider through SAF grants without exposing saves or other app-private roots.

---

## Editor virtual pads

All editor states now create touch pads (`#if mobile`) with action
buttons mirroring their keyboard shortcuts:

- `ChartingState` — `BOTH_FULL` pad + `CHART_EDITOR` layout; dpad up/down
  next/previous section, A = playtest (Enter), B = exit (Backspace,
  with unsaved-changes prompt), X = play/pause audio (Space),
  Y = test song (Esc).
- `CharacterEditorState` — `BOTH_FULL` + `CHARACTER_EDITOR`.
- `DialogueCharacterEditorState`, `MenuCharacterEditorState`,
  `NoteSplashDebugState` — pads with their matching layouts.

---

## Known follow-ups

- `phoenix://` deep links reach Haxe (`AndroidIntents.onDeepLink`) but
  per-screen routing UI is not implemented yet (roadmap P3).
- In-game keybind menu for hardware triggers (volume keys) is deferred
  per the roadmap; `AndroidHardwareInput` is the intended backend.
- Media `seek` is intentionally not applied mid-song.
- Low-latency audio relies on Lime/SDL's Android backend (AAudio/OpenSL);
  no custom backend is provided.
