package backend;

/**
 * Shared shape of the parsed `modsList.txt`, used by both the real
 * `backend.Mods` and the no-op `backend.ModsStub` (#52). Kept in its own
 * module so neither implementation has to duplicate (or shadow) it.
 */
typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	all:Array<String>
};
