package;

import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.ui.FlxBar;
import flixel.util.FlxSort;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import Achievements;

using StringTools;

#if ACHIEVEMENTS_ALLOWED
class AchievementsMenuState extends MusicBeatState
{
	public var curSelected:Int = 0;

	public var options:Array<Dynamic> = [];
	public var grpOptions:FlxSpriteGroup;
	public var nameText:FlxText;
	public var descText:FlxText;
	public var progressTxt:FlxText;
	private var progressBarBG:AttachedSprite; //The image used for the health bar.
	public var progressBar:FlxBar;

	var camFollow:FlxObject;

	var MAX_PER_ROW:Int = 4;

	public var progressValue:Float = 0;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		#if desktop
		DiscordClient.changePresence("Achievements Menu", null);
		#end

		// prepare achievement list
		for (achievement => data in Achievements.achievements)
		{
			var unlocked:Bool = Achievements.isUnlocked(achievement);
			if(data.hidden != true || unlocked)
				options.push(makeAchievement(achievement, data, unlocked, data.mod));
		}

		// TO DO: check for mods

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		FlxG.camera.follow(camFollow, null, 0);
		FlxG.camera.scroll.y = -FlxG.height;

		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBGBlue'));
		menuBG.antialiasing = ClientPrefs.globalAntialiasing;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.scrollFactor.set();
		add(menuBG);

		grpOptions = new FlxSpriteGroup();
		grpOptions.scrollFactor.x = 0;

		options.sort(sortByID);
		for (option in options)
		{
			var hasAntialias:Bool = ClientPrefs.globalAntialiasing;
			var graphic = null;
			if(option.unlocked)
			{
				#if MODS_ALLOWED Paths.currentModDirectory = option.mod; #end
				var image:String = 'achievements/' + option.name;
				if(Paths.fileExists('images/$image-pixel.png', IMAGE))
				{
					graphic = Paths.image('$image-pixel');
					hasAntialias = false;
				}
				else graphic = Paths.image(image);

				if(graphic == null) graphic = Paths.image('unknownMod');
			}
			else graphic = Paths.image('achievements/lockedachievement');

			var spr:FlxSprite = new FlxSprite(0, Math.floor(grpOptions.members.length / MAX_PER_ROW) * 180).loadGraphic(graphic);
			spr.scrollFactor.x = 0;
			spr.screenCenter(X);
			spr.x += 180 * ((grpOptions.members.length % MAX_PER_ROW) - MAX_PER_ROW/2) + spr.width / 2 + 15;
			spr.ID = grpOptions.members.length;
			spr.antialiasing = hasAntialias;
			grpOptions.add(spr);
		}
		#if MODS_ALLOWED Paths.loadTopMod(); #end

		var box:FlxSprite = new FlxSprite(0, -30).makeGraphic(1, 1, FlxColor.BLACK);
		box.scale.set(grpOptions.width + 60, grpOptions.height + 60);
		box.updateHitbox();
		box.alpha = 0.6;
		box.scrollFactor.x = 0;
		box.screenCenter(X);
		add(box);
		add(grpOptions);

		var box:FlxSprite = new FlxSprite(0, 570).makeGraphic(1, 1, FlxColor.BLACK);
		box.scale.set(FlxG.width, FlxG.height - box.y);
		box.updateHitbox();
		box.alpha = 0.6;
		box.scrollFactor.set();
		add(box);
		
		nameText = new FlxText(50, box.y + 10, FlxG.width - 100, "", 32);
		nameText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		nameText.scrollFactor.set();

		descText = new FlxText(50, nameText.y + 38, FlxG.width - 100, "", 24);
		descText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
		descText.scrollFactor.set();

		progressBarBG = new AttachedSprite('healthBar');
		progressBarBG.screenCenter(X);
		progressBarBG.y = descText.y + 52;
		progressBarBG.xAdd = -4;
		progressBarBG.yAdd = -4;

		progressBar = new FlxBar(progressBarBG.x + 4, progressBarBG.y + 4, LEFT_TO_RIGHT, Std.int(progressBarBG.width - 8), Std.int(progressBarBG.height - 8), this, 'progressValue');
		progressBar.scrollFactor.set();
		insert(members.indexOf(progressBarBG), progressBar);
		progressBarBG.sprTracker = progressBar;
		progressBar.visible = progressBarBG.visible = false;
		progressBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);
		
		progressTxt = new FlxText(50, progressBar.y - 6, FlxG.width - 100, "", 32);
		progressTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		progressTxt.scrollFactor.set();
		progressTxt.borderSize = 2;

		for (i in [progressBarBG, progressBar, progressTxt, descText, nameText])
			add(i);
		
		_changeSelection();
		super.create();

		FlxG.camera.follow(camFollow, null, 9);
		FlxG.camera.scroll.y = -FlxG.height;
	}

	function makeAchievement(achievement:String, data:Achievement, unlocked:Bool, mod:String = null)
	{
		var unlocked:Bool = Achievements.isUnlocked(achievement);
		return {
			name: achievement,
			displayName: unlocked ? data.name : '???',
			description: data.description,
			curProgress: data.maxScore > 0 ? Achievements.getScore(achievement) : 0,
			maxProgress: data.maxScore > 0 ? data.maxScore : 0,
			decProgress: data.maxScore > 0 ? data.maxDecimals : 0,
			unlocked: unlocked,
			ID: data.ID,
			mod: mod
		};
	}

	public static function sortByID(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.ID, Obj2.ID);

	var goingBack:Bool = false;
	override function update(elapsed:Float) {
		if(!goingBack && options.length > 1)
		{
			var add:Int = 0;
			if (controls.UI_LEFT_P) add = -1;
			else if (controls.UI_RIGHT_P) add = 1;

			if(add != 0)
			{
				var oldRow:Int = Math.floor(curSelected / MAX_PER_ROW);
				var rowSize:Int = Std.int(Math.min(MAX_PER_ROW, options.length - oldRow * MAX_PER_ROW));
				
				curSelected += add;
				var curRow:Int = Math.floor(curSelected / MAX_PER_ROW);
				if(curSelected >= options.length) curRow++;

				if(curRow != oldRow)
				{
					if(curRow < oldRow) curSelected += rowSize;
					else curSelected = curSelected -= rowSize;
				}
				_changeSelection();
			}

			if(options.length > MAX_PER_ROW)
			{
				var add:Int = 0;
				if (controls.UI_UP_P) add = -1;
				else if (controls.UI_DOWN_P) add = 1;

				if(add != 0)
				{
					var diff:Int = curSelected - (Math.floor(curSelected / MAX_PER_ROW) * MAX_PER_ROW);
					curSelected += add * MAX_PER_ROW;
					//trace('Before correction: $curSelected');
					if(curSelected < 0)
					{
						curSelected += Math.ceil(options.length / MAX_PER_ROW) * MAX_PER_ROW;
						if(curSelected >= options.length) curSelected -= MAX_PER_ROW;
						//trace('Pass 1: $curSelected');
					}
					if(curSelected >= options.length)
					{
						curSelected = diff;
						//trace('Pass 2: $curSelected');
					}

					_changeSelection();
				}
			}
			
			if(controls.RESET && (options[curSelected].unlocked || options[curSelected].curProgress > 0))
			{
				openSubState(new ResetAchievementSubstate());
			}
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
			goingBack = true;
		}
		super.update(elapsed);
	}

	public var barTween:FlxTween = null;
	function _changeSelection()
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		var hasProgress = options[curSelected].maxProgress > 0;
		nameText.text = options[curSelected].displayName;
		descText.text = options[curSelected].description;
		progressTxt.visible = progressBarBG.visible = progressBar.visible = hasProgress;

		if(barTween != null) barTween.cancel();

		if(hasProgress)
		{
			var val1:Float = options[curSelected].curProgress;
			var val2:Float = options[curSelected].maxProgress;
			progressTxt.text = CoolUtil.floorDecimal(val1, options[curSelected].decProgress) + ' / ' + CoolUtil.floorDecimal(val2, options[curSelected].decProgress);

			barTween = FlxTween.num(progressValue, (val1 / val2) * 100, 0.5, {ease: FlxEase.quadOut,
				onUpdate: function(twn:FlxTween) {
					var barValue = FlxMath.lerp(progressValue, (val1 / val2) * 100, twn.percent);
					if (barValue != 0)
						progressValue = barValue;
				}
			});
		}
		else progressValue = 0;

		var maxRows = Math.floor(grpOptions.members.length / MAX_PER_ROW);
		if(maxRows > 0)
		{
			var camY:Float = FlxG.height / 2 + (Math.floor(curSelected / MAX_PER_ROW) / maxRows) * Math.max(0, grpOptions.height - FlxG.height / 2 - 50) - 100;
			camFollow.setPosition(0, camY);
		}
		else camFollow.setPosition(0, grpOptions.members[curSelected].getGraphicMidpoint().y - 100);

		grpOptions.forEach(function(spr:FlxSprite) {
			spr.alpha = 0.6;
			if(spr.ID == curSelected) spr.alpha = 1;
		});
	}
}

class ResetAchievementSubstate extends MusicBeatSubstate
{
	var onYes:Bool = false;
	var yesText:Alphabet;
	var noText:Alphabet;

	public function new()
	{
		super();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);
		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});

		var text:Alphabet = new Alphabet(0, 180, "Reset Achievement:", true);
		text.screenCenter(X);
		text.scrollFactor.set();
		add(text);
		
		var state:AchievementsMenuState = cast FlxG.state;
		var text:FlxText = new FlxText(50, text.y + 90, FlxG.width - 100, state.options[state.curSelected].displayName, 40);
		text.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.scrollFactor.set();
		text.borderSize = 2;
		add(text);
		
		yesText = new Alphabet(0, text.y + 120, 'Yes', true);
		yesText.screenCenter(X);
		yesText.x -= 200;
		yesText.scrollFactor.set();
		for(letter in yesText.letters) letter.color = FlxColor.RED;
		add(yesText);
		noText = new Alphabet(0, text.y + 120, 'No', true);
		noText.screenCenter(X);
		noText.x += 200;
		noText.scrollFactor.set();
		add(noText);
		updateOptions();
	}

	override function update(elapsed:Float)
	{
		if(controls.BACK)
		{
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		super.update(elapsed);

		if(controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			onYes = !onYes;
			updateOptions();
		}

		if(controls.ACCEPT)
		{
			if(onYes)
			{
				var state:AchievementsMenuState = cast FlxG.state;
				var option:Dynamic = state.options[state.curSelected];

				Achievements.variables.remove(option.name);
				Achievements.achievementsUnlocked.remove(option.name);
				option.unlocked = false;
				option.curProgress = 0;
				option.name = state.nameText.text = '???';
				if(option.maxProgress > 0) state.progressTxt.text = '0 / ' + option.maxProgress;
				state.grpOptions.members[state.curSelected].loadGraphic(Paths.image('achievements/lockedachievement'));
				state.grpOptions.members[state.curSelected].antialiasing = ClientPrefs.globalAntialiasing;

				if(state.progressBar.visible)
				{
					if(state.barTween != null) state.barTween.cancel();
					state.barTween = FlxTween.num(state.progressValue, 0, 0.5, {ease: FlxEase.quadOut,
					onUpdate: function(twn:FlxTween) {
						var barValue = FlxMath.lerp(state.progressValue, 0, twn.percent);
						if (barValue != 0)
							state.progressValue = barValue;
					}
					});
				}
				Achievements.save();
				FlxG.save.flush();

				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
			close();
			return;
		}
	}

	function updateOptions() {
		var scales:Array<Float> = [0.75, 1];
		var alphas:Array<Float> = [0.6, 1.25];
		var confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
}
#end