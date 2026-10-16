# Phoenix Engine URI scheme

## Version 1: menu navigation

Phoenix registers the custom scheme **`phoenix`** on Android, iOS and Windows.
For example, a website can offer:

```html
<a href="phoenix://menu/misc">Open Phoenix Misc settings</a>
<a href="phoenix://mods">Open Phoenix Mods</a>
```

The app must be installed (and registered on Windows). Browsers may ask for
permission before opening it. This is a custom scheme, **not** an HTTPS Android
App Link or iOS Universal Link; there is no website ownership verification or
web fallback. Another installed app can claim the same scheme.

### Complete supported route table

| Canonical URI | Short alias | Destination |
| --- | --- | --- |
| `phoenix://menu/main` | `phoenix://main`, `phoenix://menu` | Main Menu |
| `phoenix://menu/mods` | `phoenix://mods` | Mods manager |
| `phoenix://menu/options` | `phoenix://options` | Options categories |
| `phoenix://menu/misc` | `phoenix://misc` | Options → Misc, opened immediately |
| `phoenix://menu/story` | `phoenix://story` | Story Mode |
| `phoenix://menu/freeplay` | `phoenix://freeplay` | Freeplay song selection |
| `phoenix://menu/credits` | `phoenix://credits` | Credits |

Misc is the existing settings substate, not a new standalone menu. Back closes
Misc into Options; Back from Options returns to Main Menu. In builds without
`MODS_ALLOWED`, the Mods route falls back to Main Menu.

### Grammar and validation

```text
URI      = "phoenix://" authority ["/" destination] ["/"]
authority = "menu" | destination
destination = "main" | "mods" | "options" | "misc" | "story" | "freeplay" | "credits"
```

A destination path is allowed **only** after authority `menu`; bare `menu`
means `main`. Scheme, authority and destination are ASCII case-insensitive.
One trailing slash is accepted. Maximum input length: 256 characters.

No query parameters, fragments, credentials, ports, whitespace, percent escapes,
backslashes, additional path segments or empty internal segments are accepted.
Inputs are not trimmed or URL-decoded. Unknown/malformed links are ignored,
without a popup or change to the pending valid destination. Examples rejected:

```text
phoenix:///mods
phoenix://menu/../mods
phoenix://menu/%6disc
phoenix://mods?enable=all
phoenix://mods#settings
phoenix://user@mods
phoenix://song/test
```

Links never install/enable mods, load a filesystem path, run scripts or commands,
change preferences, download content, or start a song. The parser returns only
an allowlisted internal route; it never resolves a class from external text.

## Startup and lifecycle behavior

- Native events queue a destination; they never switch Flixel states directly.
- A cold launch still performs storage permission/copy setup, preferences,
  saves, mods, splash, title initialization, and the first-run flashing warning.
  After the title intro objects/music have initialized, the link is dispatched
  automatically without requiring Enter. It does not bypass those prerequisites.
- A warm mobile link dispatches from an idle Title or Main Menu, after any
  substate/transition closes. **All other states defer navigation**: gameplay,
  pause, editors, Options, Mods, Story, Freeplay and Credits. Return to Main Menu
  to consume the request. This prevents destructive interruption or abandoned
  editing/settings sessions.
- One pending destination is kept in memory; the latest valid link wins. It is
  consumed once. Invalid links do not clear it. Pending links are not persisted
  across process death. A repeated link after consumption is a new request.
- Ordinary launches without a valid URI keep their existing startup flow.

## Platform implementation

### Android

The existing manifest template advertises a browsable `ACTION_VIEW` filter for
`phoenix`. Lime's activity defaults are exported and `singleTask`; retain these
when customizing the build. `MainActivity` forwards the cold intent in
`onCreate` and warm intents in `onNewIntent` (also updating `getIntent()`).
`PhoenixCore` buffers cold URLs; `DeepLinks` subscribes via
`AndroidIntents.subscribeDeepLink`, which uses the existing JNI delivery tracker
and startup drain. No additional Android library is required.

```sh
adb shell am force-stop quack.fnf.phoenix
adb shell am start -W -a android.intent.action.VIEW -d 'phoenix://menu/misc' quack.fnf.phoenix
adb shell am start -W -a android.intent.action.VIEW -d 'phoenix://mods' quack.fnf.phoenix
```

### iOS

`project.hxp` enables the repo's iOS templates. The Info.plist override adds
`CFBundleURLTypes` / `CFBundleURLSchemes` for `phoenix`, preserving the current
Lime template's other metadata. No associated-domains entitlement is needed.

The Lime fork's SDL UIKit application delegate forwards `openURL` to
`SDL_DROPFILE`; Lime exposes this as `Application.current.window.onDropFile`.
The listener is installed in `Main` before game initialization, and queues only
validated Phoenix links. Ordinary file drops are ignored. This uses the current
SDL app-delegate lifecycle, not a UIScene delegate. When upgrading Lime or adding
scene support, revalidate cold/warm URL delivery and merge upstream plist changes.

With an installed simulator build (a device IPA cannot run in the simulator):

```sh
xcrun simctl terminate booted quack.fnf.phoenix
xcrun simctl openurl booted 'phoenix://menu/misc'
xcrun simctl openurl booted 'phoenix://mods'
```

On a signed device build, open the example links from Safari/Notes and repeat
with the game foregrounded, backgrounded and terminated.

### Windows

Registration is per-user. Windows builds include `uri/Register-PhoenixURI.ps1` and
`uri/Unregister-PhoenixURI.ps1` alongside the executable. The engine also
performs a best-effort registration on startup: it checks the registry first and
only writes when the scheme is missing or already points at this executable, so
it never overwrites another copy's handler. Manual registration still works and
is required when PowerShell/registry access is restricted. From the game directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uri\Register-PhoenixURI.ps1
Start-Process 'phoenix://menu/misc'
Start-Process 'phoenix://mods'
```

From a source checkout, pass the built executable explicitly:

```powershell
.\setup\uri\Register-PhoenixURI.ps1 -Executable 'C:\Games\Phoenix\FNF-Phoenix-Engine.exe'
```

The script writes `HKCU\Software\Classes\phoenix`, the empty `URL Protocol`
value, icon and `shell\open\command`. The command is exactly:

```text
"C:\Games\Phoenix\FNF-Phoenix-Engine.exe" "%1"
```

Both arguments are quoted; no command shell is involved. The engine parses
`Sys.args()` and, on a valid protocol launch, sets its working directory to the
executable directory before loading relative assets. All arguments use the same
strict validator; when several valid URIs are supplied, the last wins.

**Each Windows activation starts a new process.** There is no single-instance
IPC or forwarding to an already-running game. Avoid concurrent sessions that
write the same save. This differs from mobile warm delivery.

Re-register after moving the folder. Registering another copy replaces the
per-user handler; only one copy can own this scheme. To uninstall, run the
unregister script before deleting the game (or supply its old executable path).
It refuses to remove a registration pointing to a different copy. No elevation
is required; enterprise policy may restrict protocol handlers or PowerShell.

## Validation and release checklist

Dependency-free parser tests (Haxe required; no engine haxelibs):

```sh
python3 tests/uri/run.py
```

The runner isolates the parser from `source/import.hx`. Tests cover every route
and alias, case, slashes, malformed input, injection-shaped input and size limits.

Build with the normal SDK/toolchains:

```sh
haxelib run lime build android -Dofficial
haxelib run lime build ios -nosign -Dofficial
haxelib run lime build windows -Dofficial
```

Before release, test on **each platform**:

1. Both example links from a stopped app; Misc must actually be open, not just
   highlighted. Back must return to Options, then Main Menu.
2. First-run storage setup and flashing warning; destination survives both.
3. Warm mobile links in Main Menu, then gameplay/editor/Options: unsafe states
   stay intact and the latest valid link opens after returning to Main Menu.
4. Invalid links, duplicate delivery, multiple rapid valid links, and normal
   icon launch. Check no unexpected state changes or repeated startup navigation.
5. Mods route with and without `MODS_ALLOWED`.
6. Inspect the packaged Android manifest and generated iOS Info.plist. Exercise
   foreground, background and terminated mobile launches on actual devices.
7. Windows executable path containing spaces; launch from an unrelated working
   directory; move/re-register/unregister; confirm another copy's registration
   cannot be inadvertently removed.

Implementation environment: native builds and Haxe parser execution could not
be run in the editing sandbox (Haxe/haxelib and platform SDKs unavailable;
compiler downloads were blocked). The above runtime checks remain required.

## Evolution plan

Version 1 is deliberately menu-only and has no version query parameter. Keep
these routes compatible. New safe destinations must be added to the parser,
router, tests and this table together. Song launches, mod installation, remote
content and editor/file targets are **not implemented** or silently accepted;
any future design needs explicit user confirmation, resource validation and a
separate security review. Windows single-instance handoff is a future enhancement,
not part of the current delivery contract.
