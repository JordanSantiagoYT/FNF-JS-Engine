package objects;

import shaders.RGBPalette;

//This code was from Psych Online, so credit to NotMagniill and Snirozu for the code

using StringTools;

class SustainSplash extends FlxSprite {
    public var rgbShader:NoteSplash.PixelSplashShaderRef;
  public static var startCrochet:Float;
  public static var frameRate:Int;

    public var strumNote:StrumNote;

    var timer:FlxTimer;

  public static var defaultNoteHoldSplash(default, never):String = 'noteSplashes/holdSplashes/holdSplash';

  public function new():Void {
    super();
    rgbShader = new NoteSplash.PixelSplashShaderRef();
	shader = rgbShader.shader;
    var skin:String = defaultNoteHoldSplash + getSplashSkinPostfix();
    frames = Paths.getSparrowAtlas(skin);
    if (frames == null) {
        skin = defaultNoteHoldSplash;
        frames = Paths.getSparrowAtlas(skin);
    }
    animation.addByPrefix('hold', 'hold', 24, true);
    animation.addByPrefix('end', 'end', 24, false);
  }

    override function update(elapsed) {
        super.update(elapsed);

        if (strumNote != null) {
            setPosition(strumNote.x, strumNote.y);
            visible = strumNote.visible;
            alpha = 1 - (1 - strumNote.alpha);

            if (animation.curAnim.name == "hold" && strumNote.animation.curAnim.name == "static" || animation.curAnim.name == "end" && animation.curAnim.finished) {
                x = -50000;
                kill();
            }
        }
    }

  public function setupSusSplash(strum:StrumNote, daNote:Note, ?playbackRate:Float = 1):Void {
    final susLength:Float = (!daNote.isSustainNote ? daNote.sustainLength : daNote.parentSL);
    final lengthToGet:Int = Math.floor(susLength / Conductor.stepCrochet);
    final timeToGet:Float = !daNote.isSustainNote ? daNote.strumTime : daNote.parentST;
    final timeThingy:Float = (startCrochet * lengthToGet + (timeToGet - Conductor.songPosition + ClientPrefs.ratingOffset)) / playbackRate * .001;

    animation.play('hold', true, false, 0);
    animation.curAnim.frameRate = frameRate;
    animation.curAnim.looped = true;

    shader = (ClientPrefs.enableColorShader ? rgbShader.shader : null);

    clipRect = new flixel.math.FlxRect(0, !PlayState.isPixelStage ? 0 : -210, frameWidth, frameHeight);

    if (daNote != null && daNote.rgbShader != null)
		{
			var tempShader:RGBPalette = null;
			if((daNote == null || daNote.noteSplashData.useRGBShader) && (PlayState.SONG == null || !PlayState.SONG.disableNoteRGB))
			{
				// If Note RGB is enabled:
				if(daNote != null && !daNote.noteSplashData.useGlobalShader)
				{
					if(daNote.noteSplashData.r != -1) daNote.rgbShader.r = daNote.noteSplashData.r;
					if(daNote.noteSplashData.g != -1) daNote.rgbShader.g = daNote.noteSplashData.g;
					if(daNote.noteSplashData.b != -1) daNote.rgbShader.b = daNote.noteSplashData.b;
					tempShader = daNote.rgbShader.parent;
				}
				else tempShader = Note.globalRgbShaders[daNote.noteData];
			}
			rgbShader.copyValues(tempShader);
		}

    strumNote = strum;

    if (timer != null)
		timer.cancel();

    offset.set(PlayState.isPixelStage ? 112.5 : 106.25, 100);

    timer = new FlxTimer().start(timeThingy, (idk:FlxTimer) -> {
      if (daNote.isSustainEnd && daNote.mustPress && !daNote.noteSplashData.disabled && ClientPrefs.noteSplashes) {
        alpha = 1;
        animation.play('end', true, false, 0);
        animation.curAnim.looped = false;
        animation.curAnim.frameRate = 24;
        clipRect = null;
        animation.finishCallback = (idkEither:Dynamic) -> {
          kill();
        }
        return;
      }
      kill();
    });

  }
  
    public static function getSplashSkinPostfix()
    {
        var skin:String = '';
        if(ClientPrefs.splashType != 'Default')
            skin = '-' + ClientPrefs.splashType.trim().toLowerCase().replace(' ', '_');
        return skin;
    }

}