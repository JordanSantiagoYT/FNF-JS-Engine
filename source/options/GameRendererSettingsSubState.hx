package options;

import flash.text.TextField;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;
import openfl.Lib;

using StringTools;

class GameRendererSettingsSubState extends BaseOptionsMenu
{
	var fpsOption:Option;
	public function new()
	{
		title = 'Game Renderer';
		rpcTitle = 'Game Renderer Settings Menu'; //for Discord Rich Presence

		var option:Option = new Option('Video Rendering Mode', //Name
			#if windows 'If checked, the game will render songs you play to an MP4.\nThey will be located in a folder inside assets called gameRenders.' #else 'If checked, the game will render each frame as a screenshot into a folder. They can then be rendered into MP4s using FFmpeg.\nThey are located in a folder called gameRenders.' #end,
			'ffmpegMode',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Info Shown: ',
			"Choose what info it should show while rendering a song.",
			'ffmpegInfo',
			'string',
			'None',
			['None', 'Rendering Time', 'Time Remaining', 'Frame Time', 'ALL']);
		addOption(option);

        	var option:Option = new Option('Video Framerate',
			"How much FPS would you like for your videos?",
			'targetFPS',
			'float',
			60);
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 1;
		option.maxValue = 1000;
		option.scrollSpeed = 125;
		option.decimals = 0;
		option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		fpsOption = option;

		var option:Option = new Option('Unlock Framerate', //Name
			'If checked, the framerate will be uncapped while rendering a song.\nNOTE: This does not affect the video framerate!',
			'unlockFPS',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Video Bitrate: ',
			"Use this option to set your video's bitrate!",
			'renderBitrate',
			'float',
			5.00);
		addOption(option);

		option.minValue = 1.0;
		option.maxValue = 100.0;
		option.scrollSpeed = 5;
		option.changeValue = 0.01;
		option.decimals = 2;
		option.displayFormat = '%v Mbps';

		var option:Option = new Option('Video Encoder: ',
			"Which video encoder would you like?\nThey all have differences like rendering speed, quality, etc.",
			'vidEncoder',
			'string',
			'libx264',
			['libx264', 'libx264rgb', 'libx265', 'libxvid', 'libsvtav1', 'mpeg2video']);
		addOption(option);

		var option:Option = new Option('Classic Rendering Mode', //Name
			'If checked, the game will use the old Rendering Mode from 1.20.0.',
			'oldFFmpegMode',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Lossless Screenshots',
			"If checked, screenshots will save as PNGs.\nOtherwise, It uses JPEG.",
			'lossless',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('JPEG Quality',
			"Change the JPEG quality here.\nThe recommended value is 50.",
			'quality',
			'int',
			50);
		addOption(option);

		option.minValue = 1;
		option.maxValue = 100;
		option.scrollSpeed = 30;
		option.decimals = 0;

		var option:Option = new Option('Garbage Collection Rate',
			"After how many seconds rendered should a garbage collection be performed?\nIf it's set to 0, the game will not run GC at all.",
			'renderGCRate',
			'float',
			5.0);
		addOption(option);

		option.minValue = 0;
		option.maxValue = 60.0;
		option.scrollSpeed = 3;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.displayFormat = '%vs';

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
		
		super();
	}
	function onChangeFramerate()
	{
		fpsOption.scrollSpeed = fpsOption.getValue() / 2;
	}

	function resetTimeScale()
	{
		FlxG.timeScale = 1;
	}
}