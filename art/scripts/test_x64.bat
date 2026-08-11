@echo off
color 0a
cd ..
echo BUILDING GAME
haxelib run lime test windows 
echo.
echo done.
pause