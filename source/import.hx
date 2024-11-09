#if !macro
import Paths;
import haxe.ds.Vector as HaxeVector; //apparently denpa uses vectors, which is required for camera panning i guess

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
#end

#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if flxanimate
import flxanimate.*;
import flxanimate.PsychFlxAnimate as FlxAnimate;
#end

//so that it doesn't bring up a "Type not found: Countdown"
import BaseStage.Countdown;

//Flixel
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxDestroyUtil;
import flixel.addons.transition.FlxTransitionableState;
#end