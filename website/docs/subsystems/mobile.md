---
title: Mobile
sidebar_position: 8
description: Touch controls, storage and permissions, the first-run copy state, and the Android platform services.
---

# Mobile

Mobile support (Android + iOS) is isolated in `source/mobile/` and
`source/android/`, so desktop code paths stay untouched.

## First run — `mobile.CopyState`

Lime ships assets inside the APK, but mods, saves and editor output need a writable
location. On launch `Main` checks `mobile.CopyState.checkExistingFiles()`; if assets have
not been copied yet, `CopyState` becomes the initial state and copies them into app
storage with a progress screen. Files listed in `CopyState-Ignore.txt` are skipped.

After that, `Sys.setCwd(mobile.StorageUtil.getStorageDirectory())` makes every relative
path — including `mods/` — resolve inside storage.

## Storage & permissions

`mobile.StorageUtil`:

- `requestPermissions()` — called from `Main` before anything else on Android,
- `getStorageDirectory()` — the writable root,
- helpers for external/internal paths and for creating directories.

`android.platform.AndroidStorage` wraps the Java side (scoped storage, MANAGE_ALL_FILES).

:::note Known issue
Android may still ask for image/sound access even with "manage all files" granted
(low severity), and a song with valid files can show the "no JSON/voices/instrumental"
dialog — accepting it works fine.
:::

## Touch controls

| Module | Role |
|---|---|
| `mobile.MobileControls` | chooses and owns the active control scheme |
| `mobile.flixel.FlxVirtualPad` | directional + action pad for menus |
| `mobile.flixel.FlxHitbox` | the four-lane gameplay hitbox |
| `mobile.flixel.FlxButton` | touch-friendly button base |
| `mobile.MobileControlsSelectSubState` | layout picker |
| `mobile.options.MobileOptionsSubState` | mobile-only settings |

Opacity and extra toggles come from `ClientPrefs.mobileCAlpha` and `mobileCEx`.
Menus add a virtual pad; `PlayState` adds the hitbox. Both route into the same
`backend.Controls` actions as keyboard input, so gameplay code never checks for touch.

## File picking and app files

`mobile.files.MobileFilePicker` bridges to the platform picker, used by the editors for
loading and saving charts and characters on device.

On Android, `PhoenixDocumentsProvider` adds two roots to the system Files picker:

- **Crash Logs** — read-only access to crash reports written in `crash/`.
- **Mods** — browse and manage the runtime `mods/` directory; the provider supports
  creating folders/files, reading and writing files, renaming files, and deleting files
  or subfolders.

Both roots are backed by the app's external-files storage directory, where the game keeps
its writable runtime data. Only these two folders are exposed; each requesting app gets
access through the narrow URI grants issued by Android's Storage Access Framework.

## The Android platform layer

Full detail lives in `docs/ANDROID_PLATFORM.md` and
[Platform layer](../architecture/platform-layer.md). In short:

```text
gameplay → android.platform.*  →  AndroidBridge (JNI)  →  quack.fnf.phoenix.android.*
```

| Service | What it provides |
|---|---|
| `AndroidPlatform` | boots everything from `Main` |
| `AndroidLifecycle` | pause/resume/focus events |
| `AndroidMedia` + `PhoenixMedia`/`PhoenixMediaService` | MediaSession / Media3 metadata, lock-screen and Bluetooth controls, background playback |
| `AndroidDisplay` | cutouts, insets, refresh rate, immersive mode |
| `AndroidStorage` | permissions and scoped storage |
| `AndroidHardwareInput`, `AndroidGamepad`, `AndroidHaptics` | keys, controllers, vibration |
| `AndroidIntents`, `AndroidNotification` | intents (including `phoenix://` deep links) and notifications |
| `AndroidDiscord`, `AndroidSystem` | RPC and device info |

Off Android, every one of these modules compiles to an empty body, so calling them from
shared code is safe.

## Building for mobile

```bash
lime build android          # runs setup/android-copy-stl.sh via project.hxp
lime build ios -nosign      # as CI does
```

The Android build **must** include `libc++_shared.so`; see
[Troubleshooting](../getting-started/troubleshooting.md#android-dlopen-failed-libc_sharedso-not-found).
CI (`.github/workflows/mobile.yml`) builds both platforms and verifies the APK's native
libraries; `mobile-release.yml` publishes them.

## Window and orientation

`project.hxp` sets mobile windows to `0 × 0` (native resolution), `LANDSCAPE`, not
fullscreen, resizable on Android and fixed on iOS.
