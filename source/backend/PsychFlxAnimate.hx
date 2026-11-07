package backend;

import animate.FlxAnimate;
import animate.FlxAnimateFrames;
import animate.FlxAnimateController.FlxAnimateAnimation;
import flixel.system.FlxAssets.FlxGraphicAsset;
#if sys
import sys.io.File;
#end

class PsychFlxAnimate extends FlxAnimate
{
	// Reused each frame to avoid allocating in draw().
	final _boundsOrigin:FlxPoint = new FlxPoint();

	override public function draw():Void {
		final a = anim.curAnim;
		if (a != null && (a is FlxAnimateAnimation)) {
			cast(a, FlxAnimateAnimation).timeline.getBoundsOrigin(_boundsOrigin);
			offset.set(-_boundsOrigin.x, -_boundsOrigin.y);
		}
		super.draw();
	}

	public function loadAtlasEx(img:FlxGraphicAsset, pathOrStr:String = null, myJson:Dynamic = null)
	{
		var animStr:String = null;
		if (myJson is String)
		{
			var s:String = cast myJson;
			animStr = s.trim().toLowerCase().endsWith('.json') ? File.getContent(s) : s;
		}
		else if (myJson != null)
			animStr = haxe.Json.stringify(myJson);

		var mapStr:String = pathOrStr;
		if (mapStr != null && mapStr.trim().toLowerCase().endsWith('.json'))
			mapStr = File.getContent(mapStr);

		var key:String = null;
		if (pathOrStr != null && pathOrStr.length > 0 && !pathOrStr.trim().toLowerCase().endsWith('.json'))
			key = pathOrStr;
		else if (img is String)
			key = cast(img, String);
		else
			key = 'psych_atlas_' + Std.string(img) + '_' + Std.string(pathOrStr); // fallback ID

		frames = FlxAnimateFrames.fromAnimate(
			animStr,
			[{source: img, json: mapStr}],
			null,
			key
		);
	}
	
	// make sure frames are *properly* destroyed
	override public function destroy():Void {
		if (anim != null) {
			anim.onFinish.removeAll();
			anim.onFrameLabel.removeAll();
		}
		if (frames != null) {
			frames.destroy();
			frames = null;
		}
		super.destroy();
	}

	public function pauseAnimation() anim.pause();
	public function resumeAnimation() anim.resume();
}