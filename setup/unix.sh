#!/bin/sh
# SETUP FOR MAC AND LINUX SYSTEMS!!!
# REMINDER THAT YOU NEED HAXE INSTALLED PRIOR TO USING THIS
# https://haxe.org/download
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
sudo apt update
sudo apt install libgtk-3-dev libgl-dev libx11-dev libxi-dev libxpm-dev libxrandr-dev libncurses-dev
haxelib git lime https://github.com/JS-Engine-things/lime --quiet
haxelib git openfl https://github.com/JS-Engine-things/openfl --quiet
haxelib git flixel https://github.com/JS-Engine-things/flixel-JS-Engine --quiet
haxelib install flixel-addons 3.2.3 --quiet
haxelib install flixel-tools 1.5.1 --quiet
haxelib install flixel-ui 2.6.0 --quiet
haxelib git hscript-improved https://github.com/CodenameCrew/hscript-improved --quiet
haxelib install hxcpp-debug-server --quiet
haxelib install hxgamemode --quiet
haxelib git tjson https://github.com/moxie-coder/tjson --quiet
haxelib git hxcpp https://github.com/FunkinCrew/hxcpp --quiet
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e --quiet
haxelib git hxluajit https://github.com/JS-Engine-things/hxluajit --quiet
haxelib git funkin.vis https://github.com/JS-Engine-things/funkVis-FrequencyFixed --quiet
haxelib git grig.audio https://github.com/JS-Engine-things/grig.audio --quiet
haxelib git hxdiscord_rpc https://github.com/MAJigsaw77/hxdiscord_rpc --quiet --skip-dependencies
haxelib git hxvlc https://github.com/JS-Engine-things/hxvlc --quiet --skip-dependencies
haxelib git hxnativefiledialog https://github.com/MAJigsaw77/hxnativefiledialog --quiet --skip-dependencies
haxelib install hxp
echo Finished!
