1.49.1;

Kinda fixed some beginning scripts (startCallBack() now runs after cacheCountdown() & cachePopUpScore() -JordanSantiagoYT
Added " ?? 'bf'", " ?? 'dad'" & " ?? 'gf' to fix ghost bugging on characters (dad and mom might still not work at the same time and return a NULL after first run) -JordanSantiagoYT
Refactor noteskin and texture to nullable strings -moxie-coder
Fixed entering the playtest state crashing the engine -JordanSatiagoYT
Remove win/lose bar colors & "OG HP Colors" options because recreatable in lua -JordanSantiagoYT
Dave & Bambi/Strident Crisis icon bops are now framerate-independent & uses volume 1 (not bf because ulgy + no winning sprite) -JordanSantiagoYT

1.49.0;

Changes from the Pre-release version:

Removals:

YT Watermark option, and Ratings counter (can both be recreated in Lua)

Bug-fixes:

Fixed an issue when attempting to loading an backup JSON in the chart editor (by not re-saving it, an oversight on my end whoops)
Fix Rendering mode paths on Mac And Linux(?)
Fix an crash in Weekend 1 from Nenes knife (that little devil)
Fixed runHaxeCode not working, along with possibly many other functions (it was literally an ONE LINE FIX)
Fixed "ShaderHandler" not working, because the required functions were private. (But requires to use 0.7 code currently)

	

