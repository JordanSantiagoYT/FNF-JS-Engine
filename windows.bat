@echo off
color 0a
cd ..
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
@echo on
haxelib git lime https://github.com/th2l-devs/lime --quiet
haxelib git openfl https://github.com/th2l-devs/openfl --quiet
haxelib git flixel https://github.com/JS-Engine-things/flixel-JS-Engine --quiet
haxelib install flixel-addons 3.2.3 --quiet
haxelib install flixel-tools 1.5.1 --quiet
haxelib install flixel-ui 2.6.0 --quiet
haxelib install hscript --quiet
haxelib install hxcpp-debug-server --quiet
haxelib install hxp --quiet
haxelib git away3d https://github.com/moxie-coder/away3d --quiet
haxelib git tjson https://github.com/moxie-coder/tjson --quiet
haxelib git hxcpp https://github.com/FunkinCrew/hxcpp --quiet
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e --quiet
haxelib git linc_luajit https://github.com/JS-Engine-things/linc_luajit --quiet
haxelib git funkin.vis https://github.com/JS-Engine-things/funkVis-FrequencyFixed --quiet
haxelib git grig.audio https://github.com/JS-Engine-things/grig.audio --quiet
haxelib git hxdiscord_rpc https://github.com/MAJigsaw77/hxdiscord_rpc --quiet --skip-dependencies
haxelib git hxvlc https://github.com/JS-Engine-things/hxvlc --quiet --skip-dependencies
haxelib git hxnativefiledialog https://github.com/MAJigsaw77/hxnativefiledialog --quiet --skip-dependencies
@echo off
echo Finished!
pause
