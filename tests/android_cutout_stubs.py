"""Minimal host-JVM API doubles, not Android layout/surface emulation."""
STUBS = {
    'android/content/Context.java': '''package android.content; public class Context {
        public static final String WINDOW_SERVICE="window", DISPLAY_SERVICE="display";
        public Object getSystemService(String name){return null;}
        public android.content.res.Resources getResources(){return new android.content.res.Resources();}}''',
    'android/content/res/Resources.java': '''package android.content.res; public class Resources {
        public android.util.DisplayMetrics getDisplayMetrics(){return new android.util.DisplayMetrics();}}''',
    'android/content/pm/ApplicationInfo.java': '''package android.content.pm; public class ApplicationInfo {public int targetSdkVersion=36;}''',
    'android/app/Activity.java': '''package android.app; public class Activity extends android.content.Context {
        public boolean destroyed, finishing; public Runnable queued; public boolean defer;
        public android.view.Window window=new android.view.Window();
        public boolean isDestroyed(){return destroyed;} public boolean isFinishing(){return finishing;}
        public android.view.Window getWindow(){return window;}
        public android.content.pm.ApplicationInfo getApplicationInfo(){return new android.content.pm.ApplicationInfo();}
        public android.view.Display getDisplay(){return null;}
        public void runOnUiThread(Runnable r){if(defer)queued=r;else r.run();}}''',
    'android/util/DisplayMetrics.java': '''package android.util; public class DisplayMetrics {
        public int widthPixels,heightPixels,densityDpi; public float xdpi,ydpi;}''',
    'android/util/Log.java': '''package android.util; public class Log {
        public static int errors,warnings;
        public static int w(String t,String m){warnings++;return 0;}
        public static int e(String t,String m){errors++;return 0;}
        public static int e(String t,String m,Throwable e){errors++;return 0;}}''',
    'android/graphics/Point.java': 'package android.graphics; public class Point {public int x,y;}',
    'android/view/Surface.java': 'package android.view; public class Surface {}',
    'android/view/Display.java': '''package android.view; public class Display {
        public void getRealSize(android.graphics.Point p){} public int getRotation(){return 0;}
        public float getRefreshRate(){return 60;} public Mode[] getSupportedModes(){return new Mode[0];}
        public static class Mode {public float getRefreshRate(){return 60;} public int getModeId(){return 0;}}}''',
    'android/view/View.java': '''package android.view; public class View {
        public static final int SYSTEM_UI_FLAG_VISIBLE=0,SYSTEM_UI_FLAG_IMMERSIVE=1,SYSTEM_UI_FLAG_LAYOUT_STABLE=2,
        SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION=4,SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN=8,SYSTEM_UI_FLAG_HIDE_NAVIGATION=16,
        SYSTEM_UI_FLAG_FULLSCREEN=32,SYSTEM_UI_FLAG_IMMERSIVE_STICKY=64;
        public void setSystemUiVisibility(int flags){} public WindowInsets getRootWindowInsets(){return null;}
        public void requestApplyInsets(){} public void requestLayout(){}}''',
    'android/view/Window.java': '''package android.view; public class Window {
        public int updates; public boolean fail; public WindowManager.LayoutParams attrs=new WindowManager.LayoutParams();
        public WindowManager.LayoutParams getAttributes(){return attrs;}
        public void setAttributes(WindowManager.LayoutParams a){if(fail)throw new IllegalStateException("test");updates++;attrs=a;}
        public View getDecorView(){return new View();} public WindowInsetsController getInsetsController(){return null;}}''',
    'android/view/WindowManager.java': '''package android.view; public class WindowManager {
        public Display getDefaultDisplay(){return null;} public static class LayoutParams {
        public static final int LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS=3;
        public int layoutInDisplayCutoutMode,preferredDisplayModeId;}}''',
    'android/view/WindowInsetsController.java': '''package android.view; public class WindowInsetsController {
        public static final int BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE=2,BEHAVIOR_SHOW_BARS_BY_SWIPE=1;
        public void show(int t){} public void hide(int t){} public void setSystemBarsBehavior(int b){}}''',
    'android/hardware/display/DisplayManager.java': '''package android.hardware.display; public class DisplayManager {
        public interface DisplayListener {void onDisplayAdded(int i);void onDisplayRemoved(int i);void onDisplayChanged(int i);}
        public void registerDisplayListener(DisplayListener l,Object h){} public void unregisterDisplayListener(DisplayListener l){}}''',
    'org/haxe/extension/Extension.java': '''package org.haxe.extension; public class Extension {
        public static android.app.Activity mainActivity; public static android.content.Context mainContext;
        public void onDestroy(){}}''',
    'org/json/JSONArray.java': '''package org.json; public class JSONArray {
        public void put(Object o){} public int length(){return 0;} public double getDouble(int i){return 0;}
        public Object get(int i){return 0;}}''',
    'org/json/JSONObject.java': '''package org.json; public class JSONObject {
        public void put(String n,Object o){} public double optDouble(String n,double d){return d;}}''',
    'quack/fnf/phoenix/android/PhoenixCore.java': '''package quack.fnf.phoenix.android; public class PhoenixCore {
        public static void dispatch(String e,String d){}}''',
}
STUBS.update({
    'android/os/Bundle.java': 'package android.os; public class Bundle {}',
    'android/content/Intent.java': 'package android.content; public class Intent {}',
    'android/view/KeyEvent.java': 'package android.view; public class KeyEvent {}',
    'android/view/ViewGroup.java': '''package android.view; public class ViewGroup extends View {
        public static class LayoutParams {public static final int MATCH_PARENT=-1;
        public LayoutParams(int w,int h){}}}''',
    'quack/fnf/phoenix/android/PhoenixInput.java': '''package quack.fnf.phoenix.android; public class PhoenixInput {
        public static boolean interceptKey(int code,boolean down){return false;}}''',
    'org/haxe/lime/GameActivity.java': '''package org.haxe.lime; public class GameActivity extends android.app.Activity {
        public android.view.View content;
        protected void onCreate(android.os.Bundle b){org.haxe.extension.Extension.mainActivity=this;setContentView(new android.view.View());}
        protected void onResume(){} public void onWindowFocusChanged(boolean f){}
        protected void onDestroy(){destroyed=true;}
        public void setContentView(android.view.View v){content=v;}
        public android.content.Intent getIntent(){return null;} public void setIntent(android.content.Intent i){}
        protected void onNewIntent(android.content.Intent i){}
        public boolean onKeyDown(int c,android.view.KeyEvent e){return false;}
        public boolean onKeyUp(int c,android.view.KeyEvent e){return false;}}''',
})
STUBS['quack/fnf/phoenix/android/PhoenixCore.java'] = STUBS['quack/fnf/phoenix/android/PhoenixCore.java'].replace(
    'public static void dispatch', 'public static void handleNewIntent(android.content.Intent i){} public static void dispatch')

STUBS.update({
            'android/os/Build.java': 'package android.os; public class Build { public static class VERSION { public static int SDK_INT; } public static class VERSION_CODES {public static final int P=28,R=30,M=23;}}',
            'android/view/DisplayCutout.java': '''package android.view; public class DisplayCutout {
                int l,t,r,b; public DisplayCutout(int l,int t,int r,int b) {this.l=l;this.t=t;this.r=r;this.b=b;}
                public int getSafeInsetLeft(){return l;} public int getSafeInsetTop(){return t;}
                public int getSafeInsetRight(){return r;} public int getSafeInsetBottom(){return b;}}''',
            'android/view/WindowInsets.java': '''package android.view; public class WindowInsets {
                DisplayCutout c; public WindowInsets(DisplayCutout c){this.c=c;}
                public static class Type {public static int statusBars(){return 1;} public static int navigationBars(){return 2;}}
                public DisplayCutout getDisplayCutout(){if(android.os.Build.VERSION.SDK_INT<28) throw new AssertionError(); return c;}}''',
            'android/widget/FrameLayout.java': '''package android.widget; public class FrameLayout extends android.view.View {
                int l,t,r,b; public FrameLayout(android.content.Context c){}
                public void setPadding(int l,int t,int r,int b){this.l=l;this.t=t;this.r=r;this.b=b;}
                public int getPaddingLeft(){return l;} public int getPaddingTop(){return t;}
                public int getPaddingRight(){return r;} public int getPaddingBottom(){return b;}
                public void addView(android.view.View view,android.view.ViewGroup.LayoutParams params){}
                public void requestApplyInsets(){} public android.view.WindowInsets onApplyWindowInsets(android.view.WindowInsets i){return i;}}''',
        })
