package;

import Achievements;
import backend.HaxeCommit;
import editors.MasterEditorMenu;
import flixel.effects.FlxFlicker;
import flixel.input.keyboard.FlxKey;
import lime.app.Application;
#if FUNNY_ALLOWED
import openfl.display.BlendMode;
import flixel.addons.plugin.screengrab.FlxScreenGrab;
#end

class MainMenuState extends MusicBeatState
{
  public static final gitCommit:String = HaxeCommit.getGitCommitHash();

  public static var psychEngineJSVersion:String = '1.50.0'; // This is also used for Discord RPC
  public static var psychEngineVersion:String = '0.6.3'; // This is also used for Discord RPC
  public static var curSelected:Int = 0;

  var menuItems:FlxTypedGroup<FlxSprite>;
  private var camGame:FlxCamera;
  private var camAchievement:FlxCamera;

  var optionShit:Array<String> = [
    'story_mode',
    'freeplay',
    #if MODS_ALLOWED 'mods', #end
    #if ACHIEVEMENTS_ALLOWED 'awards', #end
    'credits',
    'donate',
    'options'
  ];

  var magenta:FlxSprite;
  var camFollow:FlxObject;
  var camFollowPos:FlxObject;
  var debugKeys:Array<FlxKey>;

  // tips thing
  var tipTextMargin:Float = 10;
  var tipTextScrolling:Bool = false;
  var tipBackground:FlxSprite;
  var tipText:FlxText;
  var tipTimer:FlxTimer = new FlxTimer();
  var isTweening:Bool = false;
  var lastString:String = '';

  var tipsArray:Array<String> = [];
  var canDoTips:Bool = true; // in case the tips don't exist lol

  var funnycatperson:FlxSprite;

  override function create()
  {
    MusicBeatState.windowNameSuffix = " - Main Menu";
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();

    tipsArray = CoolUtil.coolTextFile(Paths.txt('funnyTips'));
    if (tipsArray == null)
    {
      canDoTips = false;
      trace('The tips don\'t exist!');
    }

    #if FUNNY_ALLOWED
    if ((FlxG.random.bool(1) && DateUtils.date.getHours() == 3))
    {
      funnycatperson = new FlxSprite().loadGraphic(Paths.image('catto', 'embed'));
      funnycatperson.setPosition(-60, FlxG.height - funnycatperson.height + 850); // I wanna die
      funnycatperson.scale.set(0.2, 0.2);
      funnycatperson.updateHitbox();
      funnycatperson.moves = false;
      funnycatperson.scrollFactor.set(0, 0);
      // funnycatperson.screenCenter(X);
      funnycatperson.alpha = 0.8;

      FlxG.mouse.visible = true;
    }
    #end

    #if MODS_ALLOWED
    Paths.pushGlobalMods();
    #end
    WeekData.loadTheFirstEnabledMod();

    #if desktop
    // Updating Discord Rich Presence
    DiscordClient.changePresence("In the Menus", null);
    #end
    debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

    camGame = initPsychCamera();
    camAchievement = new FlxCamera();
    camAchievement.bgColor.alpha = 0;

    FlxG.cameras.add(camAchievement, false);

    transIn = FlxTransitionableState.defaultTransIn;
    transOut = FlxTransitionableState.defaultTransOut;

    persistentUpdate = persistentDraw = true;

    var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
    var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
    bg.scrollFactor.set(0, yScroll);
    bg.setGraphicSize(Std.int(bg.width * 1.175));
    bg.updateHitbox();
    bg.screenCenter();
    bg.antialiasing = ClientPrefs.globalAntialiasing;
    add(bg);

    camFollow = new FlxObject(0, 0, 1, 1);
    camFollowPos = new FlxObject(0, 0, 1, 1);
    add(camFollow);
    add(camFollowPos);

    magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
    magenta.scrollFactor.set(0, yScroll);
    magenta.setGraphicSize(Std.int(magenta.width * 1.175));
    magenta.updateHitbox();
    magenta.screenCenter();
    magenta.visible = false;
    magenta.antialiasing = ClientPrefs.globalAntialiasing;
    magenta.color = 0xFFfd719b;
    add(magenta);

    menuItems = new FlxTypedGroup<FlxSprite>();
    add(menuItems);

    if (funnycatperson != null) add(funnycatperson);

    var scale:Float = 1;

    for (i in 0...optionShit.length)
    {
      var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
      var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);
      menuItem.scale.x = scale;
      menuItem.scale.y = scale;
      menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
      menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
      menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
      menuItem.animation.play('idle');
      menuItem.ID = i;
      menuItem.screenCenter(X);
      menuItems.add(menuItem);
      var scr:Float = (optionShit.length - 4) * 0.135;
      if (optionShit.length < 6) scr = 0;
      menuItem.scrollFactor.set(0, scr);
      menuItem.antialiasing = ClientPrefs.globalAntialiasing;
      // menuItem.setGraphicSize(Std.int(menuItem.width * 0.58));
      menuItem.updateHitbox();
    }

    FlxG.camera.follow(camFollow, null, 1);

    var JSVersion:FlxText = new FlxText(12, FlxG.height - 64, 0, "JS Engine v" + psychEngineJSVersion, 12);
    JSVersion.scrollFactor.set();
    JSVersion.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(JSVersion);
    var PsychVersion:FlxText = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + psychEngineVersion, 12);
    PsychVersion.scrollFactor.set();
    PsychVersion.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(PsychVersion);
    var FNFVersion:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
    FNFVersion.scrollFactor.set();
    FNFVersion.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(FNFVersion);

    tipBackground = new FlxSprite();
    tipBackground.scrollFactor.set();
    tipBackground.alpha = 0.7;
    tipBackground.visible = ClientPrefs.tipTexts;
    add(tipBackground);

    tipText = new FlxText(0, 0, 0, "");
    tipText.scrollFactor.set();
    tipText.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, CENTER);
    tipText.updateHitbox();
    tipText.visible = ClientPrefs.tipTexts;
    add(tipText);

    if (canDoTips) tipBackground.makeGraphic(FlxG.width, Std.int((tipTextMargin * 2) + tipText.height), FlxColor.BLACK);
    else if (tipBackground != null)
    {
      tipBackground.destroy();
      tipBackground = null;
    }

    changeItem();

    #if ACHIEVEMENTS_ALLOWED
    // Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
    if (DateUtils.isFunkin()) Achievements.unlock('friday_night_play');

    #if MODS_ALLOWED
    Achievements.reloadList();
    #end
    #end

    changeItem();
    tipTextStartScrolling();

    super.create();
  }

  var selectedSomethin:Bool = false;

  // credit to stefan2008 and sb engine for this code
  function tipTextStartScrolling()
  {
    if (!canDoTips) return;

    tipText.x = tipTextMargin;
    tipText.y = -tipText.height;

    tipTimer.start(1.0, function(timer:FlxTimer) {
      FlxTween.tween(tipText, {y: tipTextMargin}, 0.3);
      tipTimer.start(2.25, function(timer:FlxTimer) {
        tipTextScrolling = true;
      });
    });
  }

  override function beatHit()
  {
    if (curBeat % 2 == 0)
    {
      super.beatHit();

      FlxG.camera.zoom += 0.025;

      FlxTween.cancelTweensOf(FlxG.camera);
      FlxTween.tween(FlxG.camera, {zoom: 1}, Conductor.crochet / 1200, {ease: FlxEase.quadOut});
    }
  }

  function changeTipText()
  {
    if (!canDoTips) return;
    var selectedText = tipsArray[FlxG.random.int(0, tipsArray.length - 1)].replace('--', '\n');
    while (selectedText == lastString && tipsArray.length > 1)
    {
      selectedText = tipsArray[FlxG.random.int(0, tipsArray.length - 1)].replace('--', '\n');
    }

    lastString = selectedText;

    tipText.alpha = 1;
    isTweening = true;
    FlxTween.cancelTweensOf(tipText);
    FlxTween.tween(tipText, {alpha: 0}, 1,
      {
        ease: FlxEase.linear,
        onComplete: function(freak:FlxTween) {
          tipText.text = selectedText;
          tipText.alpha = 0;

          FlxTween.tween(tipText, {alpha: 1}, 1,
            {
              ease: FlxEase.linear,
              onComplete: function(freak:FlxTween) {
                isTweening = false;
              }
            });
        }
      });
  }

  override function update(elapsed:Float)
  {
    FlxG.camera.followLerp = 7.5;
    if (tipTextScrolling)
    {
      tipText.x -= elapsed * 130;
      if (tipText.x < -tipText.width)
      {
        tipTextScrolling = false;
        tipTextStartScrolling();
        changeTipText();
      }
    }
    if (FlxG.sound != null && FlxG.sound?.music?.volume < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
      if (FreeplayState.vocals != null) FreeplayState.vocals.volume += 0.5 * elapsed;
    }

    if (!selectedSomethin)
    {
      if (controls.UI_UP_P)
      {
        FlxG.sound.play(Paths.sound('scrollMenu'));
        changeItem(-1);
      }

      if (controls.UI_DOWN_P)
      {
        FlxG.sound.play(Paths.sound('scrollMenu'));
        changeItem(1);
      }

      if (controls.BACK)
      {
        selectedSomethin = true;
        FlxG.sound.play(Paths.sound('cancelMenu'));
        FlxG.switchState(TitleState.new);
      }

      if (controls.ACCEPT)
      {
        if (optionShit[curSelected] == 'donate')
        {
          CoolUtil.browserLoad('https://github.com/JordanSantiagoYT/FNF-JS-Engine');
        } else
        {
          selectedSomethin = true;
          FlxG.sound.play(Paths.sound('confirmMenu'));

          if (ClientPrefs.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false);

          menuItems.forEach(function(spr:FlxSprite) {
            if (curSelected != spr.ID)
            {
              FlxTween.tween(spr, {alpha: 0}, 0.4,
                {
                  ease: FlxEase.quadOut,
                  onComplete: function(twn:FlxTween) {
                    spr.kill();
                  }
                });
            } else
            {
              FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker) {
                var daChoice:String = optionShit[curSelected];

                switch (daChoice)
                {
                  case 'story_mode':
                    FlxG.switchState(StoryMenuState.new);
                  case 'freeplay':
                    FlxG.switchState(FreeplayState.new);
                  #if MODS_ALLOWED
                  case 'mods':
                    FlxG.switchState(ModsMenuState.new);
                  #end
                  #if ACHIEVEMENTS_ALLOWED
                  case 'awards':
                    LoadingState.loadAndSwitchState(AchievementsMenuState.new);
                  #end
                  case 'credits':
                    FlxG.switchState(CreditsState.new);
                  case 'options':
                    LoadingState.loadAndSwitchState(options.OptionsState.new);
                }
              });
            }
          });
        }
      }
      #if (desktop) else if (FlxG.keys.anyJustPressed(debugKeys))
      {
        FlxG.switchState(MasterEditorMenu.new);
      }
      #end
    }
    // Something because someone wanted it
    #if FUNNY_ALLOWED
    if (funnycatperson != null && FlxG.mouse.overlaps(funnycatperson) && FlxG.mouse.justPressed)
    {
      final screencap = new FlxSprite(0, 0, FlxScreenGrab.grab().bitmapData);
      screencap.screenCenter(XY);
      screencap.scrollFactor.set(0, 0);
      add(screencap);
      final red:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.RED);
      red.screenCenter(XY);
      red.scrollFactor.set(0, 0);
      red.blend = BlendMode.MULTIPLY;
      add(red);

      FlxG.sound.music.stop();

      final theCrash = FlxG.sound.play(Paths.sound('crash', 'shared'), 1);
      theCrash.onComplete = function() {
        CoolUtil.showPopUp('YOU JUST MADE AN BIG MISTAKE', 'HELLO');
        openfl.system.System.exit(0);
      }
    }
    #end

    super.update(elapsed);

    menuItems.forEach(function(spr:FlxSprite) {
      spr.screenCenter(X);
    });
  }

  function changeItem(huh:Int = 0)
  {
    curSelected += huh;

    if (curSelected >= menuItems.length) curSelected = 0;
    if (curSelected < 0) curSelected = menuItems.length - 1;

    menuItems.forEach(function(spr:FlxSprite) {
      spr.animation.play('idle');
      spr.updateHitbox();

      if (spr.ID == curSelected)
      {
        spr.animation.play('selected');
        var add:Float = 0;
        if (menuItems.length > 4)
        {
          add = menuItems.length * 8;
        }
        camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - add);
        spr.centerOffsets();
      }
    });
  }
}
