# Bolt's Journal

## 2026-10-10 - updateScore() runs every frame; the per-frame callback is Psych-compatible
**Learning:** `PlayState.update()` calls `updateScore()` every frame in the `else` branch of the score-lerp block, which rebuilds ~6 `formatNumber` strings and fires `callOnLuas('onUpdateScore')` even when nothing changed. `FlxText.set_text` already skips regeneration when the string is identical, so the text assignment is not the cost. The per-frame callback is inherited from Psych Engine, so mods may depend on it. Skipping the call would change mod-visible behaviour, and skipping only the string work saves microseconds per frame, which is not measurable against a 16 ms frame budget.
**Action:** Before optimizing a per-frame path, check whether a Lua/Python callback fires from it (`callOnLuas`) and whether mods depend on that cadence. Measure first. Hot-path candidates with real cost are the per-spawn `members.indexOf(...)` in `PlayStateNotes.spawnNotes` (O(n) per spawned note) and the eager `indexOf` arguments built for `callOnLuas` in hit/miss handlers, which run even with no scripts loaded. Both need a profiler to confirm.
## 2024-05-24 - Array Splice vs Pop
**Learning:** In Haxe, standard looping and iteration works best. I am searching for a quick optimization opportunity.

**Action:** Looking for simple array iterations or repeated object constructions.

## 2024-10-10 - O(N) array loop in updateNps
**Learning:** `notesHitDateArray` iterates over all items instead of breaking early when chronological order allows O(1) early exit.
**Action:** Always add early exits to loops traversing sorted arrays!
## 2026-10-10 - O(N) Array.indexOf overhead in callOnLuas invocations
**Learning:** In `PlayStateNotes.hx`, callbacks to scripts (`callOnLuas('noteMiss')`, `onSpawnNote`, etc.) build argument lists that evaluate `Array.indexOf(daNote)` directly in the function arguments. Because the arguments are eagerly evaluated before `callOnLuas` is executed, these O(N) array scans occur for every note spawned, hit, and missed during gameplay—even when no Lua or Python scripts are active. This scales poorly with massive charts (100k+ notes).
**Action:** Always wrap event dispatches that execute expensive argument evaluations in a gate check (e.g., `if (state.hasActiveScripts())`) to short-circuit the execution when the feature is completely inactive, saving O(N) operations per frame.
