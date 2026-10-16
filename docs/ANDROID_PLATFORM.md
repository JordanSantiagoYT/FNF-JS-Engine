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
    `PhoenixDocumentsProvider` SAF provider.
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

The manifest registers `quack.fnf.phoenix.android.PhoenixDocumentsProvider`
under `<application-id>.documentsprovider`, protected by
`android.permission.MANAGE_DOCUMENTS`. Android's system document UI can use
it through SAF; ordinary apps cannot call the provider directly. The provider
exposes only these roots from `Context.getExternalFilesDir(null)`:

| SAF root | Backing path | Access |
| --- | --- | --- |
| **Crash Logs** | `crash/` | Read-only, for copying reports out of the game |
| **Mods** | `mods/` | Read/write; create folders/files, rename files, and delete files or subfolders |

Document IDs are opaque, root-scoped path IDs, and requests are checked to stay
inside the matching root (including rejecting symlink/traversal paths). This
makes the game’s crash reports and runtime mods discoverable in Android’s Files
picker without exposing saves or other app data.

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
