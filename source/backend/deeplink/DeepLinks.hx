package backend.deeplink;

import flixel.FlxG;
import states.MainMenuState;
import states.LoadingState;
import options.OptionsState;

/** Native callbacks only queue requests; safe menu update hooks perform navigation. */
class DeepLinks
{
  static var initialized:Bool = false;
  static var pending:Null<String>;

  public static function init():Void
  {
    if (initialized) return;
    initialized = true;
    #if android
    android.platform.AndroidIntents.subscribeDeepLink(receive);
    #elseif ios
    // Lime's SDL UIKit delegate delivers both launch and later URLs as drop events.
    lime.app.Application.current.window.onDropFile.add(receive);
    #elseif windows
    ensureWindowsProtocolRegistration();
    for (argument in Sys.args()) receive(argument);
    // Protocol launches need not inherit the executable's working directory.
    if (pending != null) Sys.setCwd(haxe.io.Path.directory(Sys.programPath()));
    #end
  }

  public static function receive(uri:String):Void
  {
    var route = PhoenixURI.parse(uri);
    if (route != null) pending = route;
  }

  /** Called only from a fully initialized, idle Title or Main Menu. */
  public static function dispatch():Bool
  {
    if (pending == null || FlxG.state.subState != null) return false;
    var route = pending;
    pending = null;
    OptionsState.onPlayState = false;
    states.substates.PauseSubState.inPause = false;
    switch (route)
    {
      case "mods":
        #if MODS_ALLOWED
        FlxG.switchState(() -> new states.ModsMenuState());
        #else
        FlxG.switchState(MainMenuState.new);
        #end
      case "options", "misc":
        LoadingState.loadAndSwitchState(() -> new OptionsState(route == "misc"));
      case "story": FlxG.switchState(states.StoryMenuState.new);
      case "freeplay": FlxG.switchState(states.FreeplayState.new);
      case "credits": FlxG.switchState(states.CreditsState.new);
      default: FlxG.switchState(MainMenuState.new);
    }
    return true;
  }

  #if windows
  /** Best-effort per-user registration of the phoenix:// scheme. Checks the
      registry first and never overwrites another copy's handler. */
  static function ensureWindowsProtocolRegistration():Void
  {
    try
    {
      var exe = Sys.programPath();
      var expectedCommand = '"' + exe + '" "%1"';
      var alreadyOurs = false;
      var otherOwner = false;
      try
      {
        var process = new sys.io.Process('reg', ['query', 'HKCU\\Software\\Classes\\phoenix\\shell\\open\\command', '/ve']);
        var output = process.stdout.readAll().toString();
        try process.close() catch (e:Dynamic) {}
        alreadyOurs = output.indexOf(expectedCommand) >= 0;
        if (output.indexOf('.exe') >= 0 && !alreadyOurs)
          otherOwner = true;
      }
      catch (e:Dynamic) {}

      if (alreadyOurs || otherOwner) return;

      var script = haxe.io.Path.directory(exe) + '\\uri\\Register-PhoenixURI.ps1';
      if (sys.FileSystem.exists(script))
        Sys.command('powershell -NoProfile -ExecutionPolicy Bypass -File "' + script + '"');
    }
    catch (e:Dynamic) {}
  }
  #end
}