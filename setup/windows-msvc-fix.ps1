# Ensures the hxcpp haxelib is set to the git checkout (FunkinCrew fork)
# that setup\windows.bat installs. The git version is REQUIRED on Windows MSVC:
#
#   * It supports hxcpp's <assembler> element, so libffi's .asm files (used by
#     hxluau) get assembled with ml64.exe. hxcpp 4.3.2 lacks this -> the .asm
#     files are silently ignored -> linker error LNK1181 "win64.obj".
#   * It honors the HXCPP_CPP17 haxedef that hxluau's haxelib.json emits, so
#     Luau sources are compiled with /std:c++17. hxcpp 4.3.2 ignores that
#     define and uses MSVC's default (C++14) -> errors C7525 / C2039 on
#     std::string_view and inline variables.
#
# A later `haxelib install <something>` can flip the active hxcpp back to a
# release such as 4.3.2; this script restores the intended git checkout.
#
# Idempotent. Run AFTER setup\windows.bat, before building.
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File setup\windows-msvc-fix.ps1

$ErrorActionPreference = 'Stop'

# #42: a plain "[git]" marker is not enough -- the JS-Engine-things fork is
# also a git checkout but lacks the MSVC fixes this script exists to ensure.
# Verify the checked-out remote really is the pinned FunkinCrew fork.
$expectedRemote = 'https://github.com/FunkinCrew/hxcpp'
$hxcppPath = (& haxelib path hxcpp 2>&1 | Select-Object -First 1)
if ($hxcppPath -and (Test-Path (Join-Path $hxcppPath '.git'))) {
    $actualRemote = (& git -C $hxcppPath remote get-url origin 2>&1) -join ''
    if ($actualRemote -notmatch 'FunkinCrew/hxcpp') {
        Write-Error "hxcpp checkout at $hxcppPath points at '$actualRemote', expected '$expectedRemote' (see hmm.json). Re-run setup\windows.bat."
        exit 1
    }
    Write-Host "hxcpp remote verified: $actualRemote"
}

$out = (& haxelib list hxcpp 2>&1) -join "`n"
if ($out -match '\[git\]') {
    Write-Host "hxcpp already set to git. OK."
} elseif ($out -match 'git') {
    Write-Host "Setting hxcpp to git..."
    & haxelib set hxcpp git | Out-Null
    Write-Host "hxcpp set to git. OK."
} else {
    Write-Error "hxcpp git checkout not found in haxelib. Run setup\windows.bat first (it installs hxcpp from the FunkinCrew fork)."
    exit 1
}

Write-Host "`nDone. Build with: lime build windows -DMODDING_LEVEL=2"
