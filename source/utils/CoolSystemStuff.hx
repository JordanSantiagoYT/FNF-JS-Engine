package utils;

/*
    This is some cool system shit!
	lordRyan wrote this :D
    Shoutout to him :D
*/

import haxe.io.Bytes;

class CoolSystemStuff
{
	public static function getUsername():String
	{
		// uhh this one is self explanatory
		#if windows
		return Sys.getEnv("USERNAME");
		#else
		return Sys.getEnv("USER");
		#end
	}

	public static function getUserPath():String
	{
		// this one is also self explantory
		#if windows
		return Sys.getEnv("USERPROFILE");
		#else
		return Sys.getEnv("HOME");
		#end
	}

	public static function getTempPath():String
	{
		// gets appdata temp folder lol
		#if windows
		return Sys.getEnv("TEMP");
		#else
		// most non-windows os dont have a temp path, or if they do its not 100% compatible, so the user folder will be a fallback
		return Sys.getEnv("HOME");
		#end
	}
}
