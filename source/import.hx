#if !macro
// REFACTOR: root classes relocated; Paths -> backend, BaseStage -> play
import backend.Paths;

// REFACTOR: imports for relocated root classes
import play.BaseStage;

#if sys
import sys.*;
import sys.io.*;
#end

#if LUA_ALLOWED
import hxluajit.*;
import hxluajit.Types;
import psychlua.*;
#end

#if flxanimate
import flxanimate.*;
import flxanimate.PsychFlxAnimate as FlxAnimate;
#end

import backend.ModsList;
#if MODS_ALLOWED
import backend.Mods;
#else
import backend.ModsStub as Mods; // #52: distinct type path, aliased for callers
#end

//so that it doesn't bring up a "Type not found: Countdown"
import play.BaseStage.Countdown;

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
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.FlxObject;
import flixel.util.FlxSave;
import flixel.util.FlxStringUtil;

//others
import openfl.display.BitmapData;
import openfl.net.FileFilter;
import openfl.geom.Rectangle;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import haxe.Json;

// utils
import utils.*;

using StringTools;
#end
