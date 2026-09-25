1.51.0;

- A generic Game Over will now show if the game can't find one.
- Fullscreen can now be enabled with F11 in addition to the legacy Alt+Enter method.
- Characters can now have CrossFade data applied to them, similarly to how Denpa Engine previously had this feature.
- Shift-stepping (holding SHIFT while changing a Gameplay Modifier) is now possible.
- The engine now handles charts made with Psych Engine 1.0. (Sustain notes must still be fixed!)

- Stage loading has been refactored
- FlxSprites' `defaultAntialiasing` value now instantly update when Anti-Aliasing is toggled via the Graphics menu.
- camZoomingDecay now defaults to 2.5, matching the behavior of NightmareVision.
- The camera zooming system has been overhauled to work similarly to V-Slice. If you were using `doTweenZoom` with camGame before (in LUA), use `triggerEvent` to trigger a "Tween Camera Zoom" event instead!
- Mods Menu updated to the 0.7 design (no mod settings stuff yet!)
- Various health bar icons have been updated to be more centered.
- Performing a search using the Freeplay Search Menu now preserves what song you previously had selected, if it was on the song list before that.

- Removed the Nonsense V2 menu track as I personally don't like that mod anymore, and never saw myself using it.
- Removed the "Angel Note" notetype as it did nothing
- Removed the ingame updater, as it had too many issues in its current state, and it only worked on Windows.
- Removed Showcase Mode, [due to a lua recreation being made.](https://github.com/JordanSantiagoYT/FNF-JS-Engine/discussions/429)
- Removed Enable Taunt Key, Ghost Tapping Plays Anim, and Enable Miss Sound also for LUA recreations of said features existing. (also because some of them conflicted with mods if you had them turned on)
- Removed the FPS Counter border option, because it was poorly implemented. (moxie's words, not mine)

- Fixed a minor bug where scripts initialized from `startLuasOnFolder` (like event scripts and such) would call their functions twice.
- Fixed a long-running bug where the initSplash functions apparently still used your set splash skin even if it fell back to the default skin (due to a missing config file), which SHOULD in theory finally fix the infamous "Note Splash Crash."
- Fixed a bug in the Keybinds menu where if you waited too long to update a keybind with no value set, the game would crash instead of not setting the bind.
- Fixed a bug in gameplay/playtesting where sustain notes would go under the strums if Downscroll was enabled.
- Fixed a bug where if a strum's downScroll was enabled, sustain note logic would be incorrect.
- The Blocked Glitch Effect no longer randomly causes the game to shit itself.
- Fixed a bug where the Game Over events would be repeatedly triggered every frame.
- Fixed hitCausesMiss causing a hxSehException.
- Fixed Dialogue Editor buttons being on the wrong camera.
- Fixed a bug where opening the Note Colors menu with Disable Note RGB (song-specific toggle) enabled would crash the engine.
- Fixed a bug in the Note Colors menu where trying to click one of the color pixels to assign a preset color with GPU Caching enabled would crash the engine.
