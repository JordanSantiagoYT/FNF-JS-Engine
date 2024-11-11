package options;

import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;

using StringTools;

class OptionsState extends MusicBeatState
{

    var kId = 0;
    var keys:Array<FlxKey> = [D, E, B, U, G, SEVEN]; // lol
	var konamiIndex:Int = 0; // Track the progress in the Konami code sequence
	var konamiCode = [];
	var isEnteringKonamiCode:Bool = false;
	var options:Array<String> = ['Note Colors', 'Controls', 'Adjust Delay and Combo', 'Graphics', 'Optimization', 'Game Rendering', 'Visuals and UI', 'Gameplay', 'Misc'];
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	public var enteringDebugMenu:Bool = false;
	private var mainCamera:FlxCamera;
	private var subCamera:FlxCamera;
	private var otherCamera:FlxCamera;

	function openSelectedSubstate(label:String) {
		switch(label) {
			case 'Note Colors':
				if (!ClientPrefs.enableColorShader) CoolUtil.coolError("It appears that you don't have the 'Enable Note Colors' option enabled!\nTo prevent a crash, you cannot access this menu unless you turn the option on.\nYou can find it in the Visuals & UI menu.", "Patos Engine Anti-Crash Tool");
				else openSubState(new options.NotesSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals and UI':
				openSubState(new options.VisualsUISubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Optimization':
				openSubState(new options.OptimizationSubState());
			case 'Game Rendering':
				openSubState(new options.GameRendererSettingsSubState());
			case 'Adjust Delay and Combo':
				LoadingState.loadAndSwitchState(() -> new options.NoteOffsetState());
			case 'Misc':
				openSubState(new options.MiscSettingsSubState());
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;

	override function create() {
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		mainCamera = initPsychCamera();
		subCamera = new FlxCamera();
		otherCamera = new FlxCamera();
		subCamera.bgColor.alpha = 0;
		otherCamera.bgColor.alpha = 0;

		FlxG.cameras.add(subCamera, false);
		FlxG.cameras.add(otherCamera, false);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);
		FlxG.cameras.list[FlxG.cameras.list.indexOf(subCamera)].follow(camFollowPos);

		#if desktop
		DiscordClient.changePresence("Options Menu", null);
		#end

		var yScroll:Float = Math.max(0.25 - (0.05 * (options.length - options.length)), 0.1);
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.updateHitbox();
		bg.scrollFactor.set(0, 0);

		bg.screenCenter();
		bg.y -= 5;
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...options.length)
		{
			var optionText:Alphabet = new Alphabet(0, 0, options[i], true);
			optionText.screenCenter();
			optionText.y += (100 * (i - (options.length / 2))) + 50;
			optionText.scrollFactor.set(0, yScroll*1.5);
			optionText.cameras = [subCamera];
			grpOptions.add(optionText);
		}
		//I TOOK THIS FROM THE MAIN MENU STATE, NOT FROM DENPA ENGINE
		selectorLeft = new Alphabet(0, 0, '>', true);
		selectorLeft.scrollFactor.set(0, yScroll*1.5);
		selectorLeft.cameras = [subCamera];
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		selectorRight.scrollFactor.set(0, yScroll*1.5);
		selectorRight.cameras = [subCamera];
		add(selectorRight);

		#if android
		var tipText:FlxText = new FlxText(10, FlxG.height - 24, 0, 'Press C to Go In Android Controls Menu', 16);
		tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 2;
		tipText.scrollFactor.set();
		add(tipText);
		#end

		changeSelection();
		ClientPrefs.saveSettings();

                #if android
		addVirtualPad(UP_DOWN, A_B_C);
                #end

		super.create();
	}

	override function closeSubState() {
		super.closeSubState();
		ClientPrefs.saveSettings();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (controls.UI_UP_P) {
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P) {
			changeSelection(1);
		}

		var lerpVal:Float = CoolUtil.clamp(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

<<<<<<< HEAD
		if (controls.BACK && !isEnteringKonamiCode) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(PauseSubState.inPause)
			{
				PauseSubState.inPause = false;
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(PlayState.new);
				FlxG.sound.music.volume = 0;
			}
			else FlxG.switchState(MainMenuState.new);
		}
		if (controls.ACCEPT && !isEnteringKonamiCode) {
			if (isEnteringKonamiCode) return;
			openSelectedSubstate(options[curSelected]);
		}

        if (FlxG.keys.justPressed.ANY) {
            var k = keys[kId];

            if (FlxG.keys.anyJustPressed([k])) {
                #if desktop kId++; #end
                if (kId >= keys.length) {
					enteringDebugMenu = true;
					kId = 0;
                    FlxTween.tween(FlxG.camera, {alpha: 0}, 1.5, {startDelay: 1, ease: FlxEase.cubeOut});
                    if (FlxG.sound.music != null)
                        FlxTween.tween(FlxG.sound.music, {pitch: 0, volume: 0}, 2.5, {ease: FlxEase.cubeOut});
                    FlxTween.tween(FlxG.camera, {zoom: 0.1, angle: -15}, 2.5, {ease: FlxEase.cubeIn, onComplete: function(t) {
					FlxG.camera.angle = 0;
                        openSubState(new options.SuperSecretDebugMenu());
                    }});
                }
            }
        }
=======
		if (controls.ACCEPT) {
			#if android
			removeVirtualPad();
			#end
			openSelectedSubstate(options[curSelected]);
		}

		#if android
		if (_virtualpad.buttonC.justPressed) {
			#if android
			removeVirtualPad();
			#end
			MusicBeatState.switchState(new android.AndroidControlsMenu());
		}
		#end
>>>>>>> 56408d79b62ab5eeb99ee5ff647a960e5afe1f12
	}
	
	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			var thing:Float = 0;
			if (item.targetY == 0) {
				item.alpha = 1;
				if(grpOptions.members.length > 4) {
					thing = grpOptions.members.length * 8;
				}
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
				camFollow.setPosition(item.getGraphicMidpoint().x, item.getGraphicMidpoint().y - thing);
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
<<<<<<< HEAD
function checkKonamiCode():Bool {
    if (konamiCode[konamiIndex].justPressed) {
        konamiIndex++;
	if (konamiIndex > 6) isEnteringKonamiCode = true;
        if (konamiIndex >= konamiCode.length) {
            return true;
	    konamiIndex = 0;
        }
    } else { //you messed up the code
        konamiIndex = 0;
	isEnteringKonamiCode = false;
    }
    return false;
}
}
=======
}
>>>>>>> 56408d79b62ab5eeb99ee5ff647a960e5afe1f12
