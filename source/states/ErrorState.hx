package states;

import backend.ClientPrefs;
import backend.ViewportVisuals;
import backend.MusicBeatState;
import backend.Paths;

import backend.Controls;

class ErrorState extends MusicBeatState
{
	public var acceptCallback:Void->Void;
	public var backCallback:Void->Void;
	public var errorMsg:String;

	public function new(error:String, accept:Void->Void = null, back:Void->Void = null)
	{
		this.errorMsg = error;
		this.acceptCallback = accept;
		this.backCallback = back;

		super();
	}

	public var errorSine:Float = 0;
	public var errorText:FlxText;
	private var background:FlxSprite;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(background);
		if (errorText != null)
		{
			errorText.fieldWidth = FlxG.width - 300;
			errorText.screenCenter();
		}
	}

	override function create()
	{
		background = new FlxSprite().loadGraphic(Paths.image('menuDesat', 'preload'));
		background.color = FlxColor.GRAY;
		background.antialiasing = ClientPrefs.globalAntialiasing;
		ViewportVisuals.cover(background);
		add(background);

		errorText = new FlxText(0, 0, FlxG.width - 300, errorMsg, 32);
		errorText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorText.scrollFactor.set();
		errorText.borderSize = 2;
		errorText.screenCenter();
		add(errorText);

		addVirtualPad(NONE, A_B);

		super.create();
	}

	override function update(elapsed:Float)
	{
		errorSine += 180 * elapsed;
		errorText.alpha = 1 - Math.sin((Math.PI * errorSine) / 180);

		if(controls.ACCEPT && acceptCallback != null)
			acceptCallback();
		else if(controls.BACK && backCallback != null)
			backCallback();

		super.update(elapsed);
	}
}
