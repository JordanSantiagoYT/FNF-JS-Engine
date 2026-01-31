package play.objects;

typedef JudgeTextProperties =
{
  combo:Float,
  rating:String,
  miss:Bool,
  playbackRate:Float
}

class JudgeText extends FlxText
{
  public static var instance:JudgeText = null;

  private var camHUD:FlxCamera = null;

  public function new(camHUD:FlxCamera)
  {
    super(0, 0, 0, "");

    if (instance != null) throw "Cannot initiate another JudgeText with one already existing!";

    this.camHUD = camHUD;

    cameras = [camHUD ??= FlxG.camera];
    scrollFactor.set();
    active = false;
    visible = false;

    instance = this;

    applyStyle();
    applyPosition();
  }

  function applyStyle()
  {
    final font = switch (ClientPrefs.scoreStyle)
    {
      case 'Tails Gets Trolled V4': Paths.font('calibri.ttf');
      case 'Dave and Bambi': Paths.font('comic.ttf');
      case 'Doki Doki+': Paths.font('Aller_rg.ttf');
      default: Paths.font('vcr.ttf');
    }

    setFormat(font, 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
  }

  function applyPosition()
  {
    x = 408 + 250;
    y = 290 - 25;

    if (PlayState.isPixelStage)
    {
      x = 408 + 260;
      y = 290 + 20;
    }

    x += ClientPrefs.comboOffset[0];
    y -= ClientPrefs.comboOffset[1];
  }

  public function showHit(p:Null<JudgeTextProperties>)
  {
    if (!ClientPrefs.ratingPopups || !ClientPrefs.simplePopups || ClientPrefs.hideHud)
      return;

    FlxTween.cancelTweensOf(this);
    FlxTween.cancelTweensOf(scale);

    visible = true;
    alpha = 1;

    screenCenter(X);

    y = !ClientPrefs.downScroll ? PlayState?.instance?.botplayTxt?.y + 60 : PlayState?.instance?.botplayTxt?.y - 60;

    applyRatingText(p.rating, p.combo, p.miss);

    scale.set(1.075, 1.075);

    FlxTween.tween(scale, {x: 1, y: 1}, 0.1 / p.playbackRate, {
      onComplete: function(_) {
        FlxTween.tween(scale, {x: 0, y: 0}, 0.1 / p.playbackRate, {
          startDelay: 1.0 / p.playbackRate,
          onComplete: function(_) visible = false
        });
      }
    });
  }

  function applyRatingText(rating:String, combo:Float, miss:Bool)
  {
    if (miss)
    {
      color = FlxColor.fromRGB(204, 66, 66);
      text = PlayState.instance.hitStrings[5] + '\n' + PlayState.formatNumber(combo);
      return;
    }

    switch (rating)
    {
      case 'perfect':
        color = FlxColor.YELLOW;
        text = PlayState.instance.hitStrings[0] + '\n' + PlayState.formatNumber(combo);
      case 'sick':
        color = FlxColor.CYAN;
        text = PlayState.instance.hitStrings[1] + '\n' + PlayState.formatNumber(combo);
      case 'good':
        color = FlxColor.LIME;
        text = PlayState.instance.hitStrings[2] + '\n' + PlayState.formatNumber(combo);
      case 'bad':
        color = FlxColor.ORANGE;
        text = PlayState.instance.hitStrings[3] + '\n' + PlayState.formatNumber(combo);
      case 'crap':
        color = FlxColor.RED;
        text = PlayState.instance.hitStrings[4] + '\n' + PlayState.formatNumber(combo);
      default:
        color = FlxColor.WHITE;
    }
  }

  override function destroy()
  {
    super.destroy();
    if (instance == this) instance = null;
  }
}
