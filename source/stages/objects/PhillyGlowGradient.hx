package stages.objects;
import backend.ClientPrefs;
import backend.Paths;

class PhillyGlowGradient extends FlxSprite
{
	public var originalY:Float;
	public var originalHeight:Int = 400;
	public var intendedAlpha:Float = 1;

	private function viewportWidth():Int
		return Std.int(Math.max(2000, FlxG.width + 800));

	public function onViewportResize():Void
	{
		setGraphicSize(viewportWidth(), Std.int(height));
		updateHitbox();
	}

	public function new(x:Float, y:Float)
	{
		super(x, y);
		originalY = y;

		loadGraphic(Paths.image('philly/gradient'));
		scrollFactor.set(0, 0.75);
		setGraphicSize(viewportWidth(), originalHeight);
		updateHitbox();
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	override function update(elapsed:Float)
	{
		var newHeight:Int = Math.round(height - 1000 * elapsed);
		if(newHeight > 0)
		{
			alpha = intendedAlpha;
			setGraphicSize(viewportWidth(), newHeight);
			updateHitbox();
			y = originalY + (originalHeight - height);
		}
		else
		{
			alpha = 0;
			y = -5000;
		}

		super.update(elapsed);
	}

	public function bop()
	{
		setGraphicSize(viewportWidth(), originalHeight);
		updateHitbox();
		y = originalY;
		alpha = intendedAlpha;
	}
}