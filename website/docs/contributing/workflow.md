---
title: Workflow
sidebar_position: 1
description: Branching, issues, pull requests and what reviewers look for.
---

# Contributing workflow

## Before you start

- Clone only `main`: `git clone -b main --single-branch https://github.com/havaianasdestruido/FNF-Phoenix-Engine.git`.
  The other branches are experiments or very old.
- Get a build working first ([Building](../getting-started/building.md)). A PR that was
  never compiled is a PR that does not compile.
- Search existing issues and PRs — duplicates are the most common reason a PR stalls.

## Issues

The repository has structured templates under `.github/ISSUE_TEMPLATE/`:

| Template | Use for |
|---|---|
| `bugs.yml` | something is broken |
| `feature-request.yml` | a new feature |
| `question.yml` / `help.yml` | usage questions and build help |
| `missing-docs.yml` | something undocumented (including this site) |

Automation: `autotriage.yml` removes labels when an issue is closed or commented on, and
`autolock.yml` closes inactive issues.

## Pull requests

Two templates exist in `.github/PULL_REQUEST_TEMPLATE/`:

- **`bug.md`** — *Bug Fix*: link the issue(s), describe the problem and the fix.
- **`enhancement.md`** — *Enhancement*: describe the feature and why it belongs in the
  engine.

A good PR:

1. **Does one thing.** Separate refactors from behaviour changes.
2. **Builds on at least one target**, and says which one(s) you tested.
3. **Respects feature flags.** Anything touching Lua, Python, mods, videos, Discord or
   shaders must be inside the matching `#if`, and must still compile with the flag off.
   Checking `-DMODDING_LEVEL=0` catches most mistakes.
4. **Keeps the helper split.** New gameplay logic goes into `play/helpers/`, new menu
   logic into `states/helpers/` — not into `PlayState.update()`.
5. **Does not reformat untouched code.** Especially never reformat anything in
   `source/source-haxelib-patches/`.
6. **Has no stray `trace()`.** Gate diagnostics behind `#if debug`.
7. **Documents public API** with `/** ... */` — those comments end up in the
   [code reference](../reference/index.md) automatically.

## Changes that need extra care

| Change | Also do |
|---|---|
| New or removed haxelib patch | update `BUILDING.md` and [Haxelib patches](../architecture/haxelib-patches.md) |
| New feature flag | add it to `project.hxp` *and* [Project configuration](../getting-started/project-configuration.md) |
| New Lua callback | add the Python twin in `pystdlib/`, then run `npm run gen:scripts` in `website/` |
| New preference | add the `Option` entry and check the save/load blacklists |
| Dependency bump in `hmm.json` | re-diff every file in `source/source-haxelib-patches/` |
| Version bump | change `VERSION` in `project.hxp` only |

## Commit messages

Describe the change, not the file. `fix: sustain notes dropped when a chart has no BPM
changes` is useful; `update PlayState.hx` is not. Reference the issue number when there is
one.

## AI usage

The project is explicit about it: AI was used for parts of the work (mostly build fixes),
and the git history shows where. If you use AI assistance, review the output as you would
your own code — and `AGENTS.md` is the canonical instruction file for agents working in
this repository.

## Keeping docs in sync

Documentation lives next to the code it describes:

| Doc | Covers |
|---|---|
| `README.md` | feature overview, the patch system |
| `BUILDING.md` | build instructions and known build failures |
| `CODESTYLE.md` | per-language style rules |
| `URI.MD` | the `phoenix://` scheme |
| `docs/ANDROID_PLATFORM.md` | the Android platform layer |
| `AGENTS.md` | the canonical rules for AI agents |
| `website/` | this site |

If a change makes one of them wrong, fix it in the same PR. See
[Documentation](./documentation.md) for how this site is built and regenerated.
