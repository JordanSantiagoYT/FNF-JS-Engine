package backend.ui;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import flixel.ui.FlxButton;

class Prompt extends MusicBeatSubstate
{
  var selected = 0;

  public var okc:Void->Void;
  public var cancelc:Void->Void;

  var buttons:FlxSprite = new FlxSprite(473.3, 450);
  var theText:String = '';
  var goAnyway:Bool = false;
  var panel:FlxSprite;
  var panelbg:FlxSprite;
  var buttonAccept:FlxButton;
  var buttonNo:FlxButton;

  var textshit:FlxText;

  var buttonYesSpr:FlxSprite;
  var buttonNoSpr:FlxSprite;

  var cornerSize:Int = 10;

  public function new(promptText:String = '', ?defaultSelected:Int = 0, okCallback:Void->Void, cancelCallback:Void->Void, acceptOnDefault:Bool = false,
      ?camera:FlxCamera = null, ?option1:String = null, ?option2:String = null)
  {
    selected = defaultSelected; // make this optional because I'm not redoing this shit
    okc = okCallback;
    cancelc = cancelCallback;
    theText = promptText;
    goAnyway = acceptOnDefault;

    if (camera != null) cameras = [camera];

    var op1 = 'OK';
    var op2 = 'CANCEL';

    if (option1 != null) op1 = option1;
    if (option2 != null) op2 = option2;
    buttonAccept = new FlxButton(473.3, 450, op1, function() {
      if (okc != null) okc();
      close();
    });
    buttonNo = new FlxButton(633.3, 450, op2, function() {
      if (cancelc != null) cancelc();
      close();
    });
    super();
  }

  override public function create():Void
  {
    super.create();
    if (goAnyway)
    {
      if (okc != null) okc();
      close();
    }
    else
    {
      panel = new FlxSprite(0, 0).loadGraphic(Paths.image("Funkin_avi/editor/promptUI/promptCustom"));
      buttonYesSpr = new FlxSprite(0, 0).loadGraphic(Paths.image("Funkin_avi/editor/promptUI/confirm"));
      buttonNoSpr = new FlxSprite(0, 0).loadGraphic(Paths.image("Funkin_avi/editor/promptUI/cancel"));
      panelbg = new FlxSprite(0, 0);

      panel.scale.set(0.7, 0.7);
      buttonYesSpr.scale.set(0.4, 0.4);
      buttonNoSpr.scale.set(0.4, 0.4);

      panel.scrollFactor.set();
      panel.screenCenter();
      buttonYesSpr.scrollFactor.set();
      buttonYesSpr.screenCenter();
      buttonNoSpr.scrollFactor.set();
      buttonNoSpr.screenCenter();

      for (i in [buttonYesSpr, buttonNoSpr])
      {
        i.alpha = 0.001;
        i.updateHitbox();
      }

      buttonYesSpr.x += 49;
      buttonYesSpr.y += 182;
      buttonNoSpr.x += 256;
      buttonNoSpr.y += 182;

      // add(panelbg);
      add(panel);
      add(buttonYesSpr);
      add(buttonNoSpr);
      // add(buttons);
      textshit = new FlxText(buttonNo.width * 2, panel.y, 340, theText, 16);
      textshit.setFormat(Paths.font("disneyFreeplayFont.ttf"), 16);
      textshit.alignment = 'center';
      textshit.borderColor = FlxColor.BLACK;
      textshit.borderSize = 3;
      textshit.alpha = 0.001;
      add(textshit);
      textshit.screenCenter();
      textshit.scrollFactor.set();

      panel.y -= 750;
      FlxTween.tween(panel, {y: panel.y + 750}, 0.7,
        {
          ease: FlxEase.expoOut,
          onComplete: function(twn:FlxTween) {
            isDone = true;
            FlxTween.tween(textshit, {alpha: 1}, 0.45);
          }
        });
    }
  }

  var yesLerp:Float = 1;
  var noLerp:Float = 0.25;
  var isDone:Bool = false;

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (isDone)
    {
      buttonYesSpr.alpha = FlxMath.lerp(yesLerp, buttonYesSpr.alpha, CoolUtil.boundTo(1 - (elapsed * 8), 0, 1));
      buttonNoSpr.alpha = FlxMath.lerp(noLerp, buttonNoSpr.alpha, CoolUtil.boundTo(1 - (elapsed * 8), 0, 1));
    }

    if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
    {
      if (selected == 0)
      {
        selected = 1;
      }
      else
      {
        selected = 0;
      }
      FlxG.sound.play(Paths.sound('funkinAVI/menu/scrollSfx'));
      // buttons.animation.play('but' + selected);
    }

    if (selected == 0)
    {
      yesLerp = 1;
      noLerp = 0.25;
    }
    if (selected == 1)
    {
      yesLerp = 0.25;
      noLerp = 1;
    }

    if (controls.ACCEPT)
    {
      if (yesLerp == 1)
      {
        if (okc != null) okc();
      }
      else
      {
        if (cancelc != null) cancelc();
      }
      close();
    }
  }
}

class BasePrompt extends MusicBeatSubstate
{
  var _sizeX:Float = 0;
  var _sizeY:Float = 0;
  var _title:String;

  public var onCreate:BasePrompt->Void;
  public var onUpdate:BasePrompt->Float->Void;

  public function new(?sizeX:Float = 420, ?sizeY:Float = 160, title:String, ?onCreate:BasePrompt->Void, ?onUpdate:BasePrompt->Float->Void)
  {
    this._sizeX = sizeX;
    this._sizeY = sizeY;
    this._title = title;
    this.onCreate = onCreate;
    this.onUpdate = onUpdate;
    super();
  }

  public var bg:FlxSprite;
  public var titleText:FlxText;

  override function create()
  {
    cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
    bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    bg.alpha = 0.8;
    bg.scale.set(_sizeX, _sizeY);
    bg.updateHitbox();
    bg.screenCenter();
    bg.cameras = cameras;
    add(bg);

    titleText = new FlxText(0, bg.y + 30, 400, _title, 16);
    titleText.screenCenter(X);
    titleText.alignment = CENTER;
    titleText.cameras = cameras;
    add(titleText);

    if (onCreate != null) onCreate(this);
    super.create();
  }

  var _blockInput:Float = 0.1;

  override function update(elapsed:Float)
  {
    super.update(elapsed);

    _blockInput = Math.max(0, _blockInput - elapsed);
    if (_blockInput <= 0 && FlxG.keys.justPressed.ESCAPE)
    {
      close();
      return;
    }

    if (onUpdate != null) onUpdate(this, elapsed);
  }

  override function destroy()
  {
    for (member in members)
      FlxDestroyUtil.destroy(member);
    super.destroy();
  }
}
