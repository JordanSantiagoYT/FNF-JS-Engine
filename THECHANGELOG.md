1.50.1;

Fixed a bug where the opponent/bf's camera would be incredibly offset.
Fixed a crash in 2hot related to its special notes.

1.50.0;

The crash handler now has summarized reasoning that tells you WHY your engine crashed specifically. there are a few summarized reasons right now, but there'll be more added in the future!
The cameraSetTarget function can now target GF! to do it, put "gf" as the target instead!
Added FPS Border option: Allows you to add a border around the FPS counter. Increases readability.
Added Autosave Time Option (Misc): Change the amount of time in seconds that it takes to autosave a chart.

Removed Render Info and Random Botplay Text as they've been recreated in LUA.

"Exit To Your Mother" no longer softlocks the game.
The "Windows Notification" event now detects if you're using Wine.
The MS and Judge text popups have been refactored into separate classes (Not fully tested!)
"qt_taunt" keybind has been renamed to "taunt".
Tabbing out of the game with auto pause inactive will no longer inaccurately change the Discord RPC to say "BRB!"

Fixed the Update State failing to download an update. (Only applies to 1.50.0 and newer!)
Fixed Classic Rendering Mode crashing on Linux devices
After MONTHS of not seeing it, fixed a bug with Bot Energy if it wasn't binded to CTRL.
Fixed the Golden Apple icon bounce looking.. off.
Tried to add failsafes when using the section copy buttons in the Chart Editor.
Fixed some functions being null in LUA (hopefully)
Hurt Notes have been fixed.. again.
Added hitCausesMiss null safety, fixing a bug where not having this value on a note would crash the game.
Fixed 'Clear Left/Right Section' clearing notes from a different section than the one you're on. (probably)
