@echo off
color 0a

rem ==============================================
rem ULTRA_OPTIMIZED build helper (WIP flag)
rem ==============================================
rem makes sure haxe + neko are on the PATH, then
rem runs a max-speed build with -DULTRA_OPTIMIZED.
rem
rem NOTE: this flag is EXPERIMENTAL. it strips a
rem bunch of debug instrumentation and forces the
rem speed codegen. it might break stuff, so keep
rem the normal build as a fallback:
rem     haxelib run lime build windows
rem ==============================================

set HAXEPATH=C:\HaxeToolkit\haxe
set NEKOPATH=C:\HaxeToolkit\neko
set PATH=%HAXEPATH%;%NEKOPATH%;%PATH%

echo.
echo ==============================================
echo  ULTRA_OPTIMIZED BUILD (WIP / experimental)
echo ==============================================
echo  strips debug stuff like pointer checks, stack
echo  traces and leak checks, forces speed codegen
echo  plus analyzer-optimize. expecting max speed.
echo  if anything explodes, rebuild WITHOUT the
echo  flag (see ULTRA_BUILD.md).
echo ==============================================
echo.

haxelib run lime build windows -DULTRA_OPTIMIZED %*
if errorlevel 1 (
    echo.
    echo BUILD FAILED :(
    echo if you see LNK1136, another build was probably
    echo running at the same time and corrupted the obj
    echo dir. make sure only ONE build runs at a time,
    echo then just run this again.
    echo.
    pause
    exit /b 1
)

echo.
echo build done!
pause
