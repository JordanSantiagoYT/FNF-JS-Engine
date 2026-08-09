# ==============================================
# ULTRA_OPTIMIZED build helper (WIP flag)
# ==============================================
# makes sure haxe + neko are on the PATH, then
# runs a max-speed build with -DULTRA_OPTIMIZED.
#
# NOTE: this flag is EXPERIMENTAL. it strips a
# bunch of debug instrumentation and forces the
# speed codegen. it might break stuff, so keep
# the normal build as a fallback:
#     haxelib run lime build windows
# ==============================================

$env:HAXEPATH = "C:\HaxeToolkit\haxe"
$env:NEKOPATH = "C:\HaxeToolkit\neko"
$env:PATH = "$env:HAXEPATH;$env:NEKOPATH;$env:PATH"

Write-Host ""
Write-Host "=============================================="
Write-Host " ULTRA_OPTIMIZED BUILD (WIP / experimental)"
Write-Host "=============================================="
Write-Host " strips debug stuff like pointer checks, stack"
Write-Host " traces and leak checks, forces speed codegen"
Write-Host " plus analyzer-optimize. expecting max speed."
Write-Host " if anything explodes, rebuild WITHOUT the"
Write-Host " flag (see ULTRA_BUILD.md)."
Write-Host "=============================================="
Write-Host ""

haxelib run lime build windows -DULTRA_OPTIMIZED $args
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD FAILED :("
    Write-Host "if you see LNK1136, another build was probably"
    Write-Host "running at the same time and corrupted the obj"
    Write-Host "dir. make sure only ONE build runs at a time,"
    Write-Host "then just run this again."
    Write-Host ""
    Read-Host "press Enter to close"
    exit 1
}

Write-Host ""
Write-Host "build done!"
Read-Host "press Enter to close"
