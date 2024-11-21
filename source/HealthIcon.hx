package;

using StringTools;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	public var canBounce:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';

	var initialWidth:Float = 0;
	var initialHeight:Float = 0;

	public function new(char:String = 'bf', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);

		if(canBounce) {
			var mult:Float = FlxMath.lerp(1, scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));
			scale.set(mult, mult);
			updateHitbox();
		}
	}

	public var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String) {
		if(this.char != char) {
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			var file:Dynamic = Paths.image(name);

			if (file == null)
				file == Paths.image('icons/icon-face');
			else if (!Paths.fileExists('images/icons/icon-face.png', IMAGE)){
				// throw "Don't delete the placeholder icon";
				trace("Warning: could not find the placeholder icon, expect crashes!");
			}

			//loadGraphic(file); //Load stupidly first for getting the file size // why we need to load file first to get file size while we can using 'file' instance to get it?
			initialWidth = file.width;
			initialHeight = file.height;
			final iSize:Float = Math.floor(file.width / file.height); // fastest way to get icon frame without using old shit condition thingy.
			loadGraphic(file, true, Math.floor(file.width / iSize), Math.floor(file.height)); //Then load it fr // winning icons go br
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;

			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			antialiasing = ClientPrefs.globalAntialiasing;
			if(char.endsWith('-pixel')) {
				antialiasing = false;
			}
		}
	}

	public function bounce() {
		if(canBounce) {
			var mult:Float = 1.2;
			scale.set(mult, mult);
			updateHitbox();
		}
	}

	override function updateHitbox()
	{
		if (ClientPrefs.iconBounceType != 'Golden Apple' && ClientPrefs.iconBounceType != 'Dave and Bambi' || !Std.isOfType(FlxG.state, PlayState))
		{
		super.updateHitbox();
		offset.x = iconOffsets[0];
		offset.y = iconOffsets[1];
		} else {
			super.updateHitbox();
			if (initialWidth != (150 * animation.numFrames) || initialHeight != 150) //Fixes weird icon offsets when they're HUMONGUS (sussy)
			{
				offset.x = iconOffsets[0];
				offset.y = iconOffsets[1];
			}
		}
	}

	public function getCharacter():String {
		return char;
	}
}
