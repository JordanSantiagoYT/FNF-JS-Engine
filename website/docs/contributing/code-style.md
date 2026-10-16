---
title: Code style
sidebar_position: 2
description: Formatting and quality rules per language, and the tooling that enforces them.
---

# Code style

Full rules live in [`CODESTYLE.md`](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/CODESTYLE.md);
this page is the working summary.

## Rules for every language

- **LF line endings, no trailing whitespace, exactly one final newline.**
  `.vscode/settings.json` sets `files.eol`, `files.trimTrailingWhitespace` and
  `files.insertFinalNewline` for all files.
- **Generated code is not repo code.** Everything under `export/` and `build/` is produced
  by Haxe, hxcpp and Lime, and is git-ignored. Never hand-edit or reformat it — change the
  `.hx`/`.hxp` source (or add a `source/source-haxelib-patches/` override) and rebuild.
- **Naming**: types `UpperCamelCase`, members and functions `lowerCamelCase`, true
  constants `UPPER_SNAKE_CASE`.
- **Comments**: `//` for implementation notes, `/** ... */` doc comments on every public
  member worth documenting. Commented-out code gets deleted — git history is the archive.
- **No orphan debug output** (`trace()`, `Log.d`, `NSLog`, `console.log`, `printf`) in
  committed code; gate diagnostics behind a define.
- Adding a formatter/linter for a language that does not have one yet: commit its config
  at the repo root, keep it non-blocking in CI, and clean the tree incrementally.

## Haxe (`.hx`)

| Tool | Config | Extension |
|---|---|---|
| Haxe Formatter | `hxformat.json` | `nadako.vshaxe` |
| Haxe Checkstyle | `checkstyle.json` | `vshaxe.haxe-checkstyle` |

Checkstyle notes:

- Severities are configurable; `IGNORE` disables a check.
- `IndentationCharacter` checks *what* indents, `Indentation` checks *how deep*.
- `CommentedOutCode` is enabled on purpose — old code belongs in git history.
- Known TODOs, to be enabled one at a time: re-configure `MethodLength`,
  `CyclomaticComplexity`, `NestedControlFlow`, `NestedIfDepth`; re-enable `MagicNumber`;
  decide on `Trace`; fix and enable `DocCommentStyle`.

### Engine-specific Haxe conventions

- One public type per module, named after the file.
- Guard optional subsystems with `#if` — never rely on a runtime check for something a
  build may not contain.
- Keep state classes thin; new logic goes into the matching `helpers/` package as static
  functions taking the state.
- Prefer `inline` and `final` for hot-path helpers and constants; the engine targets
  low-end devices.
- Avoid `Reflect` and allocations inside per-frame loops (note iteration, rendering,
  script dispatch).
- `REFACTOR:` comments mark relocated code; keep them accurate if you move things again.

## JSON

Prettier (`esbenp.prettier-vscode`). Prettier collapses short objects onto one line and
keeps manually multi-line objects expanded. Shipped game JSON (charts, characters) is
**minified** on purpose — do not reformat `assets/**` JSON in a PR.

## Java (Android)

Standard Java conventions, documented in `CODESTYLE.md` along with JNI behaviour notes:
keep method handles cached, never block the UI thread, and return primitives or strings
across the boundary (arrays cross as CSV).

## C / C++

Formatting and portability rules are in `CODESTYLE.md`. The engine only uses C/C++ for
small native additions (`debug/mem/include`, inline `@:cppFileCode`); prefer Haxe where
possible.

## Objective-C / Swift / JS / ActionScript

Sections exist in `CODESTYLE.md` for each; they follow the same naming and
no-debug-output rules.

## Editor setup

Install the recommended extensions from `.vscode/extensions.json` and the shared settings
will apply formatting, checkstyle and the build tasks automatically. Those four `.vscode`
files are intentionally committed (see the `!` rules in `.gitignore`).
