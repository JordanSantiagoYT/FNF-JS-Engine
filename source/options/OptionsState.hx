package options;

import backend.Controls;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;

import backend.ClientPrefs;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.DiscordClient;
import backend.MusicBeatState;
import data.StageData;
import objects.Alphabet;
import objects.Note;
import play.PlayState;
import states.LoadingState;
import states.MainMenuState;
import states.substates.PauseSubState;

class OptionsState extends MusicBeatState
{
  final openMiscOnCreate:Bool;

  public function new(openMisc:Bool = false)
  {
    super();
    openMiscOnCreate = openMisc;
  }

    var kId = 0;
    var keys:Array<FlxKey> = [D, E, B, U, G, SEVEN]; // lol
	var konamiIndex:Int = 0; // Track the progress in the Konami code sequence
	var konamiCode = [];
	var isEnteringKonamiCode:Bool = false;
	var options:Array<String> = ['Note Colors', 'Controls', 'Adjust Delay and Combo', 'Graphics', 'Optimization' #if (desktop || android), 'Game Rendering' #end, 'Visuals and UI', 'Gameplay', 'Misc' #if (android || ios), 'Mobile Options' #end];
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite; // retained for source/mod compatibility
	private var optionsBackground:FlxSprite;
	public static var onPlayState:Bool = false;
	public var enteringDebugMenu:Bool = false;
	private var mainCamera:FlxCamera;
	private var subCamera:FlxCamera;
	private var otherCamera:FlxCamera;

	function openSelectedSubstate(label:String) {
		if (label != "Adjust Delay and Combo"){
			removeVirtualPad();
			persistentUpdate = false;
		}
		switch(label) {
			case 'Note Colors':
				if (!ClientPrefs.enableColorShader)
					CoolUtil.coolError("It appears that you don't have the 'Enable Note Colors' option enabled!\nTo prevent a crash, you cannot access this menu unless you turn the option on.\nYou can find it in the Visuals & UI menu.", "JS Engine Anti-Crash Tool");
				else
					openSubState(new options.NotesSubState());
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
			#if (android || ios)
			case 'Mobile Options':
				openSubState(new mobile.options.MobileOptionsSubState());
			#end
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(optionsBackground);
		if (optionsBackground != null) optionsBackground.y -= 5;
		if (grpOptions != null)
		{
			grpOptions.forEach(item -> item.screenCenter(X));
			final selected = grpOptions.members[curSelected];
			if (selected != null && selectorLeft != null && selectorRight != null)
			{
				selectorLeft.x = selected.x - 63;
				selectorRight.x = selected.x + selected.width + 15;
			}
		}
		if (camFollow != null) camFollow.x = FlxG.width / 2;
		if (camFollowPos != null) camFollowPos.x = FlxG.width / 2;
	}

	override function create() {
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		mainCamera = initPsychCamera();
		subCamera = new FlxCamera();
		otherCamera = new FlxCamera();
		subCamera.bgColor.alpha = 0;
		otherCamera.bgColor.alpha = 0;
		// proper fix
		if (onPlayState && PlayState.SONG.disableNoteRGB)
			options.remove('Note Colors');

		FlxG.cameras.add(subCamera, false);
		FlxG.cameras.add(otherCamera, false);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);
		FlxG.cameras.list[FlxG.cameras.list.indexOf(subCamera)].follow(camFollowPos);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var yScroll:Float = Math.max(0.25 - (0.05 * (options.length - options.length)), 0.1);
		optionsBackground = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		optionsBackground.color = 0xFFea71fd;
		optionsBackground.scrollFactor.set(0, 0);
		ViewportVisuals.cover(optionsBackground);
		optionsBackground.y -= 5;
		optionsBackground.antialiasing = ClientPrefs.globalAntialiasing;
		add(optionsBackground);

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

		changeSelection();
		ClientPrefs.saveSettings();

		addVirtualPad(LEFT_FULL, ClientPrefs.mobileCPlayStateVpad ? A_B_C : A_B);
		virtualPad.camera = otherCamera;

		super.create();
    if (openMiscOnCreate)
    {
      curSelected = options.indexOf('Misc');
      changeSelection();
      openSelectedSubstate('Misc');
    }
	}

	override function closeSubState() {
		super.closeSubState();
		if (FlxG.sound.music != null && FlxG.sound.music.volume == 0)
			FlxTween.tween(FlxG.sound.music, {pitch: 1, volume: 1}, 2.5, {ease: FlxEase.cubeOut});
		ClientPrefs.saveSettings();
		removeVirtualPad();
		addVirtualPad(LEFT_FULL, ClientPrefs.mobileCPlayStateVpad ? A_B_C : A_B);
		virtualPad.camera = otherCamera;
		persistentUpdate = true;
		FlxG.mouse.visible = false;
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

        if (virtualPad.buttonUp.justPressed || virtualPad.buttonDown.justPressed || virtualPad.buttonLeft.justPressed || virtualPad.buttonRight.justPressed || virtualPad.buttonB.justPressed || virtualPad.buttonA.justPressed) {
			konamiCode = [virtualPad.buttonUp, virtualPad.buttonUp, virtualPad.buttonDown, virtualPad.buttonDown, virtualPad.buttonLeft, virtualPad.buttonRight, virtualPad.buttonLeft, virtualPad.buttonRight, virtualPad.buttonB, virtualPad.buttonA];
            if (!enteringDebugMenu && checkKonamiCode()) {
                if (konamiIndex >= konamiCode.length) enterSuperSecretDebugMenu();
            }
        }

        if (FlxG.keys.justPressed.ANY) {
            var k = keys[kId];

            if (FlxG.keys.anyJustPressed([k])) {
                #if desktop kId++; #end
                if (kId >= keys.length) {
                    enterSuperSecretDebugMenu();
                }
            }
        }

		if (ClientPrefs.mobileCPlayStateVpad && virtualPad.buttonC.justPressed) {
			persistentUpdate = false;
			openSubState(new mobile.MobileControlsSelectSubState());
		}
	}

	function enterSuperSecretDebugMenu():Void
	{
		enteringDebugMenu = true;
		konamiIndex = kId = 0;
		FlxTween.tween(FlxG.camera, {alpha: 0}, 1.5, {startDelay: 1, ease: FlxEase.cubeOut});
		if (virtualPad != null && virtualPad.camera != null)
		{
			FlxTween.tween(virtualPad.camera, {alpha: 0}, 1.5, {startDelay: 1, ease: FlxEase.cubeOut});
			FlxTween.tween(virtualPad.camera, {zoom: 0.1, angle: -15}, 2.5, {ease: FlxEase.cubeIn});
		}
		if (FlxG.sound.music != null)
			FlxTween.tween(FlxG.sound.music, {pitch: 0, volume: 0}, 2.5, {ease: FlxEase.cubeOut});
		FlxTween.tween(FlxG.camera, {zoom: 0.1, angle: -15}, 2.5, {ease: FlxEase.cubeIn, onComplete: function(t) {
			FlxG.camera.angle = 0;
			if (virtualPad != null && virtualPad.camera != null) virtualPad.camera.angle = 0;
			openSubState(new options.SuperSecretDebugMenu());
			removeVirtualPad();
			persistentUpdate = false;
		}});
	}

	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;

		var selectionIndex:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = selectionIndex - curSelected;
			selectionIndex++;

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
			}
		}
		camFollow.setPosition(FlxG.width / 2, (curSelected * (grpOptions.members.length * 10)));

		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
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
