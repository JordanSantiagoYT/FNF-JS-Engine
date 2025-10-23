package;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

typedef SongHeading = {
	var path:String;
	var antiAliasing:Bool;
	var iconOffset:Float;
}
class CreditsPopUp extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var bgHeading:FlxSprite;

	public var funnyText:FlxText;
	public var funnyIcon:FlxSprite;
	var curHeading:SongHeading;

	public function new(x:Float, y:Float, title:String = '', songCreator:String = '')
	{
		super(x, y);
		bg = new FlxSprite().makeGraphic(400, 50, FlxColor.WHITE);
		add(bg);
		var songCreatorIcon:String = '';
		var headingPath:SongHeading = null;

		headingPath = {path: PlayState.SONG.songCreditBarPath.length <= 0 ? 'JSEHeading' : 'songHeadings/' + PlayState.SONG.songCreditBarPath, antiAliasing: ClientPrefs.globalAntialiasing, iconOffset: 0};

		if (PlayState.SONG.songCreditIcon.length >= 1) songCreatorIcon = PlayState.SONG.songCreditIcon;
			else songCreatorIcon = 'ExampleIcon';

		if (headingPath != null)
		{
			if (!Paths.fileExists(headingPath.path, TEXT))
				bg.loadGraphic(Paths.image(headingPath.path));
			else
			{
				bg.frames = Paths.getSparrowAtlas(headingPath.path);
				bg.animation.addByPrefix('idle', 'idle', 24, true);
				bg.animation.play('idle');
			}
			bg.antialiasing = headingPath.antiAliasing;
			curHeading = headingPath;
		}
		createHeadingText(title + "\nComposed by" + ' ' + songCreator);
		funnyIcon = new FlxSprite(0, 0).loadGraphic(Paths.image('songCreators/$songCreatorIcon'));
		funnyIcon.visible = PlayState.SONG.songCreditIcon.length > 0;
		rescaleIcon();
		add(funnyIcon);

		if (PlayState.instance != null && headingPath.path == 'JSEHeading') bg.color = FlxColor.fromRGB(PlayState.instance.dad.healthColorArray[0], PlayState.instance.dad.healthColorArray[1], PlayState.instance.dad.healthColorArray[2]);

		rescaleBG();

		var yValues = CoolUtil.getMinAndMax(bg.height, funnyText.height);
		funnyText.y = funnyText.y + ((yValues[0] - yValues[1]) / 2);
	}
	public function switchHeading(newHeading:SongHeading)
	{
		if (bg != null)
		{
			remove(bg);
		}
		bg = new FlxSprite().makeGraphic(400, 50, FlxColor.WHITE);
		if (newHeading != null)
		{
				bg.loadGraphic(Paths.image(newHeading.path));
		}
		bg.antialiasing = newHeading.antiAliasing;
		curHeading = newHeading;
		add(bg);

		rescaleBG();
	}
	public function changeText(newText:String, newIcon:String, rescaleHeading:Bool = true)
	{
		createHeadingText(newText);
		if (funnyIcon != null)
		{
			remove(funnyIcon);
		}
			funnyIcon = new FlxSprite(0, 0).loadGraphic(Paths.image('songCreators/$newIcon'));
		rescaleIcon();
		add(funnyIcon);

		if (rescaleHeading)
		{
			rescaleBG();
		}
	}
	public function rescaleIcon()
	{
		var offset = (curHeading == null ? 0 : curHeading.iconOffset);

		var scaleValues = CoolUtil.getMinAndMax(funnyIcon.height, funnyText.height);
		funnyIcon.setGraphicSize(Std.int(funnyIcon.height / (scaleValues[1] / scaleValues[0])));
		funnyIcon.updateHitbox();

		var heightValues = CoolUtil.getMinAndMax(funnyIcon.height, funnyText.height);
		funnyIcon.setPosition(funnyText.textField.textWidth + offset, (heightValues[0] - heightValues[1]) / 2);
	}
	function createHeadingText(text:String)
	{
		if (funnyText != null)
		{
			remove(funnyText);
		}
		funnyText = new FlxText(1, 0, 650, text, 16);
		funnyText.setFormat('vcr.ttf', 30, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		funnyText.borderSize = 2;
		funnyText.antialiasing = true;
		add(funnyText);
	}
	function rescaleBG()
	{
		bg.setGraphicSize(Std.int((funnyText.textField.textWidth + 0.5)), Std.int(funnyText.height + 0.5));
		bg.updateHitbox();
	}
}
