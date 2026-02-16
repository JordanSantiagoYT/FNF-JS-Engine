package utils;

// basically PlatformUtil but where all the code glue goes
#if cpp
#if windows
@:cppFileCode('#include <stdlib.h>
#include <stdio.h>
#include <windows.h>
#include <winuser.h>
#include <dwmapi.h>
#include <strsafe.h>
#include <shellapi.h>
#include <iostream>
#include <string>

#pragma comment(lib, "Dwmapi")
#pragma comment(lib, "Shell32.lib")')
#elseif linux
@:cppFileCode('
#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <string>
')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:headerInclude('sys/utsname.h')
#end
@:allow(utils.PlatformUtil)
class PlatformUtilNative
{
  #if windows
  @:functionCode('
        HWND hWnd = GetActiveWindow();
        res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) | WS_EX_LAYERED);
        if (res)
        {
            SetLayeredWindowAttributes(hWnd, RGB(1, 1, 1), 0, LWA_COLORKEY);
        }
    ')
  #elseif linux
  /*
    REQUIRES IMPORTING X11 LIBRARIES (Xlib, Xutil, Xatom) to run, even tho it doesnt work
    @:functionCode('
        Display* display = XOpenDisplay(NULL);
        Window wnd;
        Atom property = XInternAtom(display, "_NET_WM_WINDOW_OPACITY", False);
        int revert;
        
        if(property != None)
        {
            XGetInputFocus(display, &wnd, &revert);
            unsigned long opacity = (0xff000000 / 0xffffffff) * 50;
            XChangeProperty(display, wnd, property, XA_CARDINAL, 32, PropModeReplace, (unsigned char*)&opacity, 1);
            XFlush(display);
        }
        XCloseDisplay(display);
    ')
   */
  #end
  static function getWindowsTransparentNative(res:Int = 0) // Only works on windows, otherwise returns 0!
  {
    return res;
  }

  #if windows
  @:functionCode('
        LPCSTR lwDesc = desc.c_str();

        res = MessageBox(
            NULL,
            lwDesc,
            NULL,
            MB_OK
        );
    ')
  #end
  static function sendFakeMsgBoxNative(desc:String = "", res:Int = 0) // TODO: Linux and macOS (will do soon)
  {
    return res;
  }

  #if windows
  @:functionCode('
        HWND hWnd = GetActiveWindow();
        res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) ^ WS_EX_LAYERED);
        if (res)
        {
            SetLayeredWindowAttributes(hWnd, RGB(1, 1, 1), 1, LWA_COLORKEY);
        }
    ')
  #end
  static function getWindowsBackwardNative(res:Int = 0) // Only works on windows, otherwise returns 0!
  {
    return res;
  }

  #if windows
  @:functionCode('
        std::string p(getenv("APPDATA"));
        p.append("\\\\Microsoft\\\\Windows\\\\Themes\\\\TranscodedWallpaper");

        SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, (PVOID)p.c_str(), SPIF_UPDATEINIFILE);
    ')
  #end
  static function updateWallpaperNative()
  { // Only works on windows, otherwise returns 0!
    return null;
  }

  #if (cpp && windows) // assuming Wine sets the "windows" macro to true
  @:functionCode('
		HMODULE ntdll = GetModuleHandleA("ntdll.dll");
		if (ntdll) {
			void* wine_get_version = GetProcAddress(ntdll, "wine_get_version");
			if (wine_get_version) return true;
		}
		return false;
	')
  #end
  static function detectWineNative():Bool
  {
    return false;
  }

  #if windows
  @:functionCode('
		SYSTEM_INFO osInfo;

		GetSystemInfo(&osInfo);

		switch(osInfo.wProcessorArchitecture)
		{
			case 9:
				return ::String("x86_64");
			case 5:
				return ::String("ARM");
			case 12:
				return ::String("ARM64");
			case 6:
				return ::String("IA-64");
			case 0:
				return ::String("x86");
			default:
				return ::String("Unknown");
		}
	')
  #elseif (ios || mac)
  @:functionCode('
		const NXArchInfo *archInfo = NXGetLocalArchInfo();
    	return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
	')
  #else
  @:functionCode('
		struct utsname osInfo{};
		uname(&osInfo);
		return ::String(osInfo.machine);
	')
  #end
  @:noCompletion
  static function getArchNative():String
  {
    return null;
  }
#end
}
