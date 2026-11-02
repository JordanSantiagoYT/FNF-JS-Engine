# JS Engine – Android (Mobile Port)

## Install
1. Download `FNF-JS-Engine-Mobile-Port.apk` from the **Releases** page.
2. Install it (allow "install unknown apps" for your browser/file manager if Android asks).
3. First launch: the game copies its files out of the APK ("Preparing game files"). This only happens the first time and after an update.

One APK works on every phone: it contains 32-bit (armeabi-v7a) and 64-bit (arm64-v8a) code, Android 5.0 or newer.

## Where are my files?
`Android/data/com.JordanSantiago.JSEngine/files/`

- `mods/` – drop your mods here (same folders as the desktop version)
- `crash/` – crash logs
- `assets/` – game files (extracted automatically, do not edit)

On Android 11+ the `Android/data` folder is hidden from some file managers; use the one that comes with the system ("Files"), or plug the phone into a PC.

## Controls
- **Menus:** D-pad (move), **A** (accept), **B** (back). Some menus add **X / Y / C** (Freeplay: X = gameplay changers, Y = reset score, C = song preview; Main Menu: X = editors).
- **Songs:** the screen is split into four lanes (the hitbox). Hold a lane for sustain notes, slide a finger between lanes, use as many fingers as you want. Top-right button = pause.
- The Android **Back** button/gesture goes back in menus and pauses in songs.
- Opening the pause menu, game over, or any cutscene swaps the lanes for the menu buttons automatically.

## Mobile Options (Options → Mobile Options)
| Option | What it does |
|---|---|
| Pad Opacity | how visible the menu buttons are |
| Hitbox Opacity | how visible the lanes are (0% = invisible but still working) |
| Hitbox Style | Gradient / Flat / Outline |
| Hitbox Position | Full height or Bottom only |
| Extra Button | Bot Energy button during songs |
| Vibration | short vibration on every press |
| Screen | Ratio (keeps 16:9) or Fill (stretch to the display) |

A live preview of the hitbox is drawn behind the menu.

## Building it yourself
Run the **Android Build** workflow (Actions tab → *Run workflow*). It builds the APK with both CPU types and, if "publish" is ticked, creates the GitHub Release with only the APK attached.

To keep the same signature between releases (so an installed copy can be *updated* instead of reinstalled) add these repository secrets:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`.

Local build (needs Android SDK + NDK r27 and JDK 17 configured with `lime config`):
```
haxelib run lime build android -armv7 -arm64 -release
```

## Known limits (V1)
- The chart/character/other editors open and respond to touch, but many of their shortcuts are keyboard-only.
- Text boxes use the on-screen keyboard.
- Discord Rich Presence and native file dialogs are desktop-only.
