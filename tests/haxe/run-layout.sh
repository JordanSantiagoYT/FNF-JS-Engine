#!/usr/bin/env bash
# Isolate the production geometry module from source/import.hx's Flixel/OpenFL
# imports; the math test is intentionally runnable without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/mobile/flixel"
cp source/backend/ScreenLayout.hx "$test_source/backend/ScreenLayout.hx"
cp source/mobile/flixel/HitboxTouchLogic.hx "$test_source/mobile/flixel/HitboxTouchLogic.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main LayoutSpec --interp
