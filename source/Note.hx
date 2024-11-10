package;

import backend.NoteTypesConfig;
import flixel.util.FlxColor;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

import objects.SustainSplash;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

typedef PreloadedChartNote = {
	strumTime:Float,
	noteData:Int,
	mustPress:Bool,
	oppNote:Bool,
	noteType:String,
	animSuffix:String,
	noteskin:String,
	texture:String,
	noAnimation:Bool,
	noMissAnimation:Bool,
	gfNote:Bool,
	isSustainNote:Bool,
	isSustainEnd:Bool,
	sustainLength:Float,
	sustainScale:Float,
	parentST:Float,
	parentSL:Float,
	hitHealth:Float,
	missHealth:Float,
	hitCausesMiss:Null<Bool>,
	wasHit:Bool,
	multSpeed:Float,
	noteDensity:Float,
	ignoreNote:Bool,
	blockHit:Bool,
	lowPriority:Bool
}

typedef NoteSplashData = {
	disabled:Bool,
	texture:String,
	useGlobalShader:Bool, //breaks r/g/b/a but makes it copy default colors for your custom note
	useRGBShader:Bool,
	antialiasing:Bool,
	r:FlxColor,
	g:FlxColor,
	b:FlxColor,
	a:Float
}

/**
 * The note object used as a data structure to spawn and manage notes during gameplay.
 * 
 * If you want to make a custom note type, you should search for: "function set_noteType"
**/

class Note extends FlxSprite
{
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var parentST:Float = 0;
	public var parentSL:Float = 0;
	public var strumTime:Float = 0;
	public var mustPress:Bool = false;
	public var doOppStuff:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false; //For Opponent notes

	public var blockHit:Bool = false; // only works for player

	public var noteDensity:Float = 1;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var isSustainEnd:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var rgbShader:RGBShaderReference;
	public static var globalRgbShaders:Array<RGBPalette> = [];
	public var inEditor:Bool = Type.getClassName(Type.getClass(FlxG.state)) == 'editors.ChartingState';

	public var animSuffix:String = '';
	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 0.5;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;

	public static final swagWidth:Float = 160 * 0.7;
	
	public static final colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
	public static var defaultNoteSkin(default, never):String = 'noteskins/NOTE_assets';

	public var noteSplashData:NoteSplashData = {
		disabled: false,
		texture: null,
		antialiasing: !PlayState.isPixelStage,
		useGlobalShader: false,
		useRGBShader: (PlayState.SONG != null) ? !(PlayState.SONG.disableNoteRGB == true) : true,
		r: -1,
		g: -1,
		b: -1,
		a: 1
	};
	public var noteHoldSplash:SustainSplash;

	// Lua shit
	public var noteSplashDisabled:Bool = false;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed:Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var sustainScale:Float = 1;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; //plan on doing scroll directions soon -bb

	public var hitsoundDisabled:Bool = false;

	public var pixelNote:Bool = false;
	public var useRGBShader(default, set):Bool = true;

	private function set_useRGBShader(value:Bool):Bool {
		if (useRGBShader != value) 
		{
			useRGBShader = value;
			if (rgbShader != null) rgbShader.enabled = value;
		}
		return value;
	}

	var changeSize:Bool = false;
	private function set_texture(value:String):String {
		if (!pixelNote && texture != value)
		{
			changeSize = false;
			if (!Paths.noteSkinFramesMap.exists(value)) Paths.initNote(4, value);
			try {
				if (frames != @:privateAccess Paths.noteSkinFramesMap.get(value)) frames = @:privateAccess Paths.noteSkinFramesMap.get(value);
				if (animation != @:privateAccess Paths.noteSkinAnimsMap.get(value)) inline animation.copyFrom(@:privateAccess Paths.noteSkinAnimsMap.get(value));
			}
			catch (e) {
				frames = @:privateAccess Paths.noteSkinFramesMap.get(Paths.defaultSkin);
				animation.copyFrom(@:privateAccess Paths.noteSkinAnimsMap.get(Paths.defaultSkin));
			}
			if (!changeSize) 
			{
				changeSize = true;
				setGraphicSize(Std.int(width * 0.7));
				updateHitbox();
			}
			offsetX = 0;
		}
		else if (!pixelNote) return value;
		else if (pixelNote && inEditor) reloadNote(value);
		texture = value;
		return value;
	}

	public function defaultRGB()
	{
		var arr:Array<FlxColor> = ClientPrefs.arrowRGB[noteData];
		if(pixelNote) arr = ClientPrefs.arrowRGBPixel[noteData];

		if (noteData > -1 && noteData <= arr.length)
		{
			rgbShader.r = arr[0];
			rgbShader.g = arr[1];
			rgbShader.b = arr[2];
		}
	}

	private function set_noteType(value:String):String {
		noteSplashData.texture = PlayState.SONG != null ? PlayState.SONG.splashSkin : 'noteSplashes';
		if (ClientPrefs.noteColorStyle == 'Normal' && rgbShader != null && useRGBShader) defaultRGB();

		if(noteData > -1 && noteType != value) {
			if (value != null && value.length > 1) NoteTypesConfig.applyNoteTypeData(this, value);
			noteType = value;
		}
		return value;
	}

	public function new(?newStrumTime:Float, ?newNoteData:Int)
	{
		super();

		pixelNote = PlayState.isPixelStage;

		if (!Math.isNaN(newNoteData) && pixelNote) noteData = newNoteData;
		if (!Math.isNaN(newStrumTime)) strumTime = newStrumTime;

		y -= 2000;
		antialiasing = ClientPrefs.globalAntialiasing && !pixelNote;

		if(noteData > -1) {
			if (ClientPrefs.showNotes)
			{
				texture = Paths.defaultSkin;
			}
			if (ClientPrefs.enableColorShader)
			{
				try{ rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData, this)); }
				catch(e) {};
				if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) rgbShader.enabled = useRGBShader = false;
			}
			else useRGBShader = false;
		}
	}

	public static function initializeGlobalRGBShader(noteData:Int, ?note:Note = null)
	{
		if (note == null)
		{
			if(globalRgbShaders[noteData] == null)
			{
				var newRGB:RGBPalette = new RGBPalette();
				globalRgbShaders[noteData] = newRGB;

				var arr:Array<FlxColor> = (!PlayState.isPixelStage) ? ClientPrefs.arrowRGB[noteData] : ClientPrefs.arrowRGBPixel[noteData];
				if (noteData > -1 && noteData <= arr.length)
				{
					newRGB.r = arr[0];
					newRGB.g = arr[1];
					newRGB.b = arr[2];
				}
			}
			return globalRgbShaders[noteData];
		}
		else switch(ClientPrefs.noteColorStyle)
		{
			case 'Quant-Based':
			if(globalRgbShaders[0] == null)
			{
				var newRGB:RGBPalette = new RGBPalette();
				globalRgbShaders[0] = newRGB;

				var arr:Array<FlxColor> = (!note.pixelNote) ? ClientPrefs.arrowRGB[3] : ClientPrefs.arrowRGBPixel[3];
				if (noteData > -1)
				{
					newRGB.r = arr[0];
					newRGB.g = arr[1];
					newRGB.b = arr[2];
				}
			}
			return globalRgbShaders[0];
			case 'Grayscale', 'Rainbow', 'Char-Based':
			if(globalRgbShaders[0] == null)
			{
				var newRGB:RGBPalette = new RGBPalette();
				globalRgbShaders[0] = newRGB;

				if (noteData > -1)
				{
					newRGB.r = 0xFFA0A0A0;
					newRGB.g = FlxColor.WHITE;
					newRGB.b = 0xFF424242;
				}
			}
			return globalRgbShaders[0];
			default:
			if(globalRgbShaders[noteData] == null)
			{
				var newRGB:RGBPalette = new RGBPalette();
				globalRgbShaders[noteData] = newRGB;

				var arr:Array<FlxColor> = (!note.pixelNote) ? ClientPrefs.arrowRGB[noteData] : ClientPrefs.arrowRGBPixel[noteData];
				if (noteData > -1 && noteData <= arr.length)
				{
					newRGB.r = arr[0];
					newRGB.g = arr[1];
					newRGB.b = arr[2];
				}
			}
			return globalRgbShaders[noteData];
		}
	}

	var _lastNoteOffX:Float = 0;
	static var _lastValidChecked:String; //optimization
	public var originalHeight:Float = 6;
	private function reloadNote(?texture:String = '', ?postfix:String = '') {
		if(texture == null) texture = '';
		if(postfix == null) postfix = '';

		var skin:String = texture + postfix;
		if(texture.length < 1) {
			skin = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
			if(skin == null || skin.length < 1)
				skin = defaultNoteSkin + postfix;
		}

		var animName:String = null;
		if(animation.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var skinPixel:String = skin;
		var lastScaleY:Float = scale.y;
		var skinPostfix:String = getNoteSkinPostfix();
		var customSkin:String = skin + skinPostfix;
		var path:String = pixelNote ? 'pixelUI/' : '';
		if(customSkin == _lastValidChecked || Paths.fileExists('images/' + path + customSkin + '.png', IMAGE))
		{
			skin = customSkin;
			_lastValidChecked = customSkin;
		}
		else skinPostfix = '';

		if(pixelNote) {
			if(isSustainNote) {
				var graphic = Paths.image('pixelUI/' + skinPixel + 'ENDS' + skinPostfix);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 2));
				originalHeight = graphic.height / 2;
			} else {
				var graphic = Paths.image('pixelUI/' + skinPixel + skinPostfix);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 5));
			}
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			if(isSustainNote)
			{
				animation.add(colArray[noteData] + 'holdend', [noteData + 4], 24, true);
				animation.add(colArray[noteData] + 'hold', [noteData], 24, true);
			} else animation.add(colArray[noteData] + 'Scroll', [noteData + 4], 24, true);
			antialiasing = false;

			if(isSustainNote) {
				offsetX += _lastNoteOffX;
				_lastNoteOffX = (width - 7) * (PlayState.daPixelZoom / 2);
				offsetX -= _lastNoteOffX;
			}
		} else {
			frames = Paths.getSparrowAtlas(skin);
			animation.addByPrefix(colArray[noteData] + 'Scroll', colArray[noteData] + '0');
			if (isSustainNote)
			{
				animation.addByPrefix('purpleholdend', 'pruple end hold'); // ?????
				animation.addByPrefix(colArray[noteData] + 'holdend', colArray[noteData] + ' hold end');
				animation.addByPrefix(colArray[noteData] + 'hold', colArray[noteData] + ' hold piece');
			}
			setGraphicSize(Std.int(width * 0.7));
			if(!isSustainNote)
			{
				centerOffsets();
				centerOrigin();
			}
			antialiasing = ClientPrefs.globalAntialiasing;
		}
		if(isSustainNote) {
			scale.y = lastScaleY;
		}
		updateHitbox();

		if(animName != null)
			animation.play(animName, true);
			
		if(inEditor) {
			setGraphicSize(editors.ChartingState.GRID_SIZE, editors.ChartingState.GRID_SIZE);
			updateHitbox();
		}
	}

	public static function getNoteSkinPostfix()
	{
		var skin:String = '';
		if(ClientPrefs.noteSkin != 'Default')
			skin = '-' + ClientPrefs.noteSkin.trim().toLowerCase().replace(' ', '_');
		return skin;
	}

	override function update(elapsed:Float)
	{
		if (Type.getClassName(Type.getClass(FlxG.state)) == 'PlayState' && PlayState.instance.cpuControlled) return;
		
		super.update(elapsed);

		if (mustPress)
		{
			canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult) &&
						strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult));

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit && !ignoreNote)
				tooLate = true;
			else tooLate = false;
		}
		else
		{
			canBeHit = false;

			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if(strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	inline public function followStrum(strum:StrumNote, songSpeed:Float = 1):Void
	{
		if (isSustainNote) 
		{
			flipY = ClientPrefs.downScroll;
			scale.y = (animation != null && animation.curAnim != null && animation.curAnim.name.endsWith('end') ? 1 : Conductor.stepCrochet * 0.0105 * (songSpeed * multSpeed) * sustainScale);

			if (PlayState.isPixelStage) 
			{
				scale.y *= PlayState.daPixelZoom * 1.20;
			}
			updateHitbox();
		}
			
		distance = (0.45 * (Conductor.songPosition - strumTime) * songSpeed * multSpeed);
		if (!ClientPrefs.downScroll) distance *= -1;

		if (copyAngle)
			angle = strum.direction - 90 + strum.angle + offsetAngle;

		if(copyAlpha)
			alpha = strum.alpha * multAlpha;

		if(copyX)
			x = strum.x + offsetX + Math.cos(strum.direction * Math.PI / 180) * distance;

		if(copyY)
		{
			y = strum.y + offsetY + (!isSustainNote || ClientPrefs.downScroll ? 0 : 55) + Math.sin(strum.direction * Math.PI / 180) * distance;
			if(strum.downScroll && isSustainNote)
			{
				if(PlayState.isPixelStage)
				{
					y -= PlayState.daPixelZoom * 9.5;
				}
				y -= (frameHeight * scale.y) - (Note.swagWidth / 2);
			}
		}
	}

	public function clipToStrumNote(myStrum:StrumNote)
	{
		final center:Float = myStrum.y + offsetY + Note.swagWidth / 2;
		if(isSustainNote && (mustPress || !ignoreNote) &&
			(!mustPress || (wasGoodHit || !canBeHit)))
		{
			final swagRect:FlxRect = clipRect != null ? clipRect : new FlxRect(0, 0, frameWidth, frameHeight);

			if (myStrum.downScroll)
			{
				if(y - offset.y * scale.y + height >= center)
				{
					swagRect.width = frameWidth;
					swagRect.height = (center - y) / scale.y;
					swagRect.y = frameHeight - swagRect.height;
				}
			}
			else if (y + offset.y * scale.y <= center)
			{
				swagRect.y = (center - y) / scale.y;
				swagRect.width = width / scale.x;
				swagRect.height = (height / scale.y) - swagRect.y;
			}
			clipRect = swagRect;
		}
	}
	
	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect
	{
		clipRect = rect;

		if (frames != null)
			frame = frames.frames[animation.frameIndex];

		return rect;
	}

	public override function destroy()
	{
		super.destroy();
		_lastValidChecked = '';
	}

	public function updateRGBColors()
	{
		if (rgbShader == null && useRGBShader) rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData, this));
		else switch(ClientPrefs.noteColorStyle)
		{
			case 'Rainbow':
			var superCoolColor = new FlxColor(0xFFFF0000);
			superCoolColor.hue = (strumTime / 5000 * 360) % 360;
			rgbShader.r = superCoolColor;
			rgbShader.g = FlxColor.WHITE;
			rgbShader.b = superCoolColor.getDarkened(0.7);
			
			case 'Quant-Based':
			CoolUtil.checkNoteQuant(this, (!isSustainNote ? strumTime : parentST), rgbShader);

			case 'Char-Based':
			if (PlayState.instance != null)
			{
				var arr:Array<Int> = CoolUtil.getHealthColors(doOppStuff ? PlayState.instance.dad : PlayState.instance.boyfriend);
				if (gfNote) arr = CoolUtil.getHealthColors(PlayState.instance.gf);
				if (noteData > -1)
				{
					rgbShader.r = FlxColor.fromRGB(arr[0], arr[1], arr[2]);
					rgbShader.g = FlxColor.WHITE;
					rgbShader.b = rgbShader.r;
					rgbShader.b = rgbShader.b.getDarkened(0.7);
				}
			}
			else defaultRGB();

			default:

		}
		if (noteType == 'Hurt Note' && rgbShader != null)
		{
				// note colors
				rgbShader.r = 0xFF101010;
				rgbShader.g = 0xFFFF0000;
				rgbShader.b = 0xFF990022;

				// splash data and colors
				noteSplashData.r = 0xFFFF0000;
				noteSplashData.g = 0xFF101010;
				noteSplashData.texture = 'noteSplashes/noteSplashes-electric';
		}
		else if (rgbShader != null)
		{
			noteSplashData.r = -1;
			noteSplashData.g = -1;
			noteSplashData.b = -1;
		}
	}

	// this is used for note recycling
	var firstOffX = false;
	var shouldCenterOffsets:Bool = true;
	public function setupNoteData(chartNoteData:PreloadedChartNote):Void 
	{
		wasGoodHit = hitByOpponent = tooLate = canBeHit = false; // Don't make an update call of this for the note group

		if (chartNoteData.noteskin.length > 0 && chartNoteData.noteskin != '' && chartNoteData.noteskin != texture) 
		{
			texture = 'noteskins/' + chartNoteData.noteskin;
			useRGBShader = false;
		}
		if (chartNoteData.texture.length > 0 && chartNoteData.texture != texture) 
		{
			texture = chartNoteData.texture;
			shouldCenterOffsets = false;
		}
		if ((chartNoteData.noteskin.length < 1 && chartNoteData.texture.length < 1) && chartNoteData.texture != Paths.defaultSkin)
		{
			texture = Paths.defaultSkin;
			useRGBShader = ClientPrefs.enableColorShader;
			shouldCenterOffsets = ClientPrefs.enableColorShader;
		}

		strumTime = chartNoteData.strumTime;
		if(!inEditor) strumTime += ClientPrefs.noteOffset;
		noteData = chartNoteData.noteData % 4;
		noteType = chartNoteData.noteType;
		animSuffix = chartNoteData.animSuffix;
		noAnimation = noMissAnimation = chartNoteData.noAnimation;
		mustPress = chartNoteData.mustPress;
		doOppStuff = chartNoteData.oppNote;
		gfNote = chartNoteData.gfNote;
		isSustainNote = chartNoteData.isSustainNote;
		isSustainEnd = chartNoteData.isSustainEnd;
		sustainScale = chartNoteData.sustainScale;
		lowPriority = chartNoteData.lowPriority;
		if (isSustainNote) {
			parentST = chartNoteData.parentST;
			parentSL = chartNoteData.parentSL;
		}
		
		hitHealth = chartNoteData.hitHealth;
		missHealth = chartNoteData.missHealth;
		hitCausesMiss = chartNoteData.hitCausesMiss;
		ignoreNote = chartNoteData.ignoreNote;
		blockHit = chartNoteData.blockHit;
		multSpeed = chartNoteData.multSpeed;
		noteDensity = chartNoteData.noteDensity;

		if (ClientPrefs.enableColorShader && useRGBShader)
		{
			if (rgbShader == null) rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData, this));
			else updateRGBColors();
		}

		if (noteType == 'Hurt Note' && !ClientPrefs.enableColorShader)
		{
			texture = 'HURTNOTE_assets';
			noteSplashData.texture = 'noteSplashes/HURTnoteSplashes';
		}

		if (PlayState.isPixelStage)
		{
			@:privateAccess reloadNote(texture);
			if (isSustainNote && !firstOffX) 
			{
				firstOffX = true;
				offsetX += 30;
			}
		}

		if (!PlayState.isPixelStage && !changeSize) 
		{
			changeSize = true;
			setGraphicSize(Std.int(width * 0.7));
			updateHitbox();
		}

		if (isSustainNote) {
			offsetX += width / 2;
			copyAngle = false;
			animation.play(colArray[noteData % 4] + (chartNoteData.isSustainEnd ? 'holdend' : 'hold'));
			updateHitbox();
			offsetX -= width / 2;
		}
		else {
			animation.play(colArray[noteData % 4] + 'Scroll');
			if (!copyAngle) copyAngle = true;
			offsetX = 0; //Juuuust in case we recycle a sustain note to a regular note
			if (useRGBShader && shouldCenterOffsets)
			{
				centerOffsets();
				centerOrigin();
			}
		}
		angle = 0;

		clipRect = null;
		if (!mustPress) 
		{
			visible = ClientPrefs.opponentStrums;
			alpha = ClientPrefs.middleScroll ? ClientPrefs.oppNoteAlpha : 1;
		}
		else
		{
			if (!visible) visible = true;
			if (alpha != 1) alpha = 1;
		}
		if (flipY) flipY = false;
	}
}