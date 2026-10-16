#!/bin/sh
# SETUP FOR MAC AND LINUX SYSTEMS!!!
# REMINDER THAT YOU NEED HAXE INSTALLED PRIOR TO USING THIS
# https://haxe.org/download
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
if [ "${SKIP_SYSTEM_DEPENDENCIES:-0}" != "1" ]; then
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Skipping system dependencies: install the required development packages with your platform's package manager."
  else
    sudo apt update
    sudo apt install libgtk-3-dev libgl-dev libx11-dev libxi-dev libxpm-dev libxrandr-dev libncurses-dev
  fi
fi
haxelib git lime https://github.com/JS-Engine-things/lime-8.1.2 45816ca456764761cbea8d3cc57701a592f892f1 --quiet
haxelib git openfl https://github.com/JS-Engine-things/openfl f2158f144bd77c950fb965939ea9bece48e45962 --quiet
haxelib git flixel https://github.com/JS-Engine-things/flixel-JS-Engine baa47998542eab29f4a9cc02a0283d6120d6b1ef --quiet
haxelib install flixel-addons 3.2.3 --quiet
haxelib install flixel-tools 1.5.1 --quiet
haxelib install flixel-ui 2.6.0 --quiet
haxelib git hscript https://github.com/CodenameCrew/hscript-improved 48ec0f4b013a4e5e18d6ce1456be7b3c3f12a1fa --quiet
haxelib install hxcpp-debug-server --quiet
haxelib install hxgamemode --quiet
haxelib git tjson https://github.com/moxie-coder/tjson 7e2b6540bee6c3d94cd3b957453ffb1e3e438c59 --quiet
haxelib git hxcpp https://github.com/FunkinCrew/hxcpp d5bda40ac13f2823fe1bdcb5476e0eb027f1e7e9 --quiet
# The FunkinCrew hxcpp checkout is a source/development version, so its
# command-line tools must be built before they can drive the C++ compiler.
HXCMP_PATH=$(haxelib path hxcpp 2>/dev/null | head -n 1)
if [ -n "$HXCMP_PATH" ] && [ -d "$HXCMP_PATH/git/tools" ]; then
  (cd "$HXCMP_PATH/git/tools/run" && haxe compile.hxml)
  (cd "$HXCMP_PATH/git/tools/hxcpp" && haxe compile.hxml)
fi
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e --quiet
haxelib install hython 0.0.352-beta --quiet
haxelib git hxluajit https://github.com/ShadowEngineTeam/hxluajit a4b2a0a14a371dc404f3062854b8d0d6b404a0ed --quiet
haxelib git funkin.vis https://github.com/JS-Engine-things/funkVis-FrequencyFixed badf0368f0035d0d7bab6529fcbc1ca22e47d31a --quiet
haxelib git grig.audio https://github.com/JS-Engine-things/grig.audio eb5cad389e6110af6767457a62b9a80af2507826 --quiet
haxelib git hxdiscord_rpc https://github.com/MAJigsaw77/hxdiscord_rpc 2ca5930e9647c5de8c220f98427b5c50ddd244dd --quiet --skip-dependencies
haxelib git hxvlc https://github.com/JS-Engine-things/hxvlc 2bb1cb4d1e9277f2a64b7bcebf3622f05eddfaa2 --quiet --skip-dependencies
haxelib git hxnativefiledialog https://github.com/MAJigsaw77/hxnativefiledialog 7f2353172bd3d0e3b8324ad5de4eeb9bc9c44af9 --quiet --skip-dependencies
haxelib install hxp
echo Finished!
