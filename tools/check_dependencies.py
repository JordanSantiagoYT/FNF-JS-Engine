#!/usr/bin/env python3
"""Verify that hmm.json and the setup scripts describe the same git deps.

Regression guard for #42 (hxcpp fork divergence) and #58 (moving branch
heads). Every git dependency must be pinned to a full 40-hex commit SHA and
hmm.json, setup/unix.sh and setup/windows.bat must agree on name, URL and
revision. Haxelib-registry dependencies (type "haxelib") are out of scope:
they are versioned by the registry, not by a moving git branch.

The hmm manifest names the CodenameCrew library ``hscript-improved`` while
the setup scripts install the same URL under the haxelib name ``hscript``;
that single historical alias is normalised here.

Usage: python3 tools/check_dependencies.py [repo-root]
Exits 0 when the three manifests agree, 1 (with a report) otherwise.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SHA = re.compile(r"^[0-9a-f]{40}$")
GIT_LINE = re.compile(r"haxelib\s+git\s+(\S+)\s+(\S+)(?:\s+(\S+))?")
ALIASES = {"hscript-improved": "hscript"}


def normalise(name: str) -> str:
    return ALIASES.get(name, name)


def from_hmm(root: Path) -> dict[str, tuple[str, str]]:
    data = json.loads((root / "hmm.json").read_text(encoding="utf-8"))
    deps = {}
    for dep in data["dependencies"]:
        if dep.get("type") == "git":
            deps[normalise(dep["name"])] = (dep["url"], dep.get("ref") or "")
    return deps


def from_setup(path: Path) -> dict[str, tuple[str, str]]:
    deps = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = GIT_LINE.search(line)
        if match:
            name, url, ref = match.groups()
            deps[normalise(name)] = (url, ref or "")
    return deps


def check(root: Path) -> list[str]:
    errors: list[str] = []
    sources = {
        "hmm.json": from_hmm(root),
        "setup/unix.sh": from_setup(root / "setup/unix.sh"),
        "setup/windows.bat": from_setup(root / "setup/windows.bat"),
    }
    names: set[str] = set()
    for deps in sources.values():
        names.update(deps)
    for name in sorted(names):
        seen = {}
        for label, deps in sources.items():
            if name not in deps:
                errors.append(f"{name}: missing from {label}")
                continue
            url, ref = deps[name]
            seen[label] = (url, ref)
            if not SHA.match(ref):
                errors.append(
                    f"{name}: {label} ref {ref!r} is not a pinned 40-char commit SHA (#58)"
                )
        if len(set(seen.values())) > 1:
            errors.append(f"{name}: manifests disagree: {seen} (#42)")
    return errors


def main(argv: list[str]) -> int:
    root = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[1]
    errors = check(root)
    if errors:
        print("Dependency manifest drift detected:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("OK: hmm.json, setup/unix.sh and setup/windows.bat agree; all git deps pinned to commits.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
