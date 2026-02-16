package utils;

/*
    VS DAVE WINDOWS/LINUX/MACOS UTIL
    You can use this code while you give credit to it.
    65% of the code written by chromasen
    35% of the code written by Erizur (cross-platform and extra windows utils)

    Windows: You need the Windows SDK (any version) to compile.
    Linux: TODO
    macOS: TODO

    credits to the vs dave team right here uh yeah i love ya guys
*/
class PlatformUtil
{
	#if cpp
	static public function getWindowsTransparent(res:Int = 0)   // Only works on windows, otherwise returns 0!
	{
		return PlatformUtilNative.getWindowsTransparentNative(res);
	}

    static public function sendFakeMsgBox(desc:String = "", res:Int = 0)    // TODO: Linux and macOS (will do soon)
    {
        return PlatformUtilNative.sendFakeMsgBoxNative(desc, res);
    }

	static public function getWindowsBackward(res:Int = 0)  // Only works on windows, otherwise returns 0!
	{
		return PlatformUtilNative.getWindowsBackwardNative(res);
	}

    static public function updateWallpaper() {  // Only works on windows, otherwise returns 0!
        return PlatformUtilNative.updateWallpaperNative();
    }

	public static function detectWine():Bool {
		return PlatformUtilNative.detectWineNative();
	}
	
	public static function getArch():String {
		return PlatformUtilNative.getArchNative();
	}
	#end
}
