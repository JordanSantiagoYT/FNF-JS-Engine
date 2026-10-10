## 2024-05-24 - Array Splice vs Pop
**Learning:** In Haxe, standard looping and iteration works best. I am searching for a quick optimization opportunity.

**Action:** Looking for simple array iterations or repeated object constructions.

## 2024-10-10 - O(N) array loop in updateNps
**Learning:** `notesHitDateArray` iterates over all items instead of breaking early when chronological order allows O(1) early exit.
**Action:** Always add early exits to loops traversing sorted arrays!
