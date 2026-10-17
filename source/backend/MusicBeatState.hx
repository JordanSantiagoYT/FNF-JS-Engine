package backend;

import Main;
import play.BaseStage;
import play.PlayState;
import shaders.CustomFadeTransition;
import backend.PsychCamera;
import mobile.MobileControls;
import mobile.flixel.FlxVirtualPad;
import flixel.input.actions.FlxActionInput;
import flixel.util.FlxDestroyUtil;
import flixel.addons.ui.FlxUIState;
#if !flash
import lime.app.Application;
#end

import data.Section;

class MusicBeatState extends FlxUIState
{
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var oldStep:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	public static var camBeat:FlxCamera;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	var mobileControls:MobileControls;
	public var virtualPad:FlxVirtualPad;
	var mobileControlsCamera:FlxCamera;
	var virtualPadCamera:FlxCamera;
	var trackedInputsMobileControls:Array<FlxActionInput> = [];
	var trackedInputsVirtualPad:Array<FlxActionInput> = [];

	public function addVirtualPad(DPad:FlxDPadMode, Action:FlxActionMode):Void
	{
		if (virtualPad != null)
			removeVirtualPad();

		virtualPad = new FlxVirtualPad(DPad, Action);
		add(virtualPad);

		controls.setVirtualPadUI(virtualPad, DPad, Action);
		trackedInputsVirtualPad = controls.trackedInputsUI;
		controls.trackedInputsUI = [];
	}

	public function removeVirtualPad():Void
	{
		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);

		if (virtualPad != null)
		{
			remove(virtualPad);
			virtualPad = FlxDestroyUtil.destroy(virtualPad);
		}

		if (virtualPadCamera != null)
		{
			FlxG.cameras.remove(virtualPadCamera);
			virtualPadCamera = null;
		}
	}

	public function addMobileControls(DefaultDrawTarget:Bool = false):Void
	{
		if (mobileControls != null)
			removeMobileControls();

		mobileControls = new MobileControls();

		switch (MobileControls.mode)
		{
			case 'Hitbox':
				controls.setHitBox(mobileControls.hitbox);
			default:
				controls.setVirtualPadNOTES(mobileControls.virtualPad, RIGHT_FULL, NONE);
		}

		trackedInputsMobileControls = controls.trackedInputsNOTES;
		controls.trackedInputsNOTES = [];

		var camControls:FlxCamera = new FlxCamera();
		camControls.bgColor.alpha = 0;
		FlxG.cameras.add(camControls, DefaultDrawTarget);
		mobileControlsCamera = camControls;

		mobileControls.cameras = [camControls];
		mobileControls.visible = false;
		add(mobileControls);
	}

	public function removeMobileControls():Void
	{
		if (trackedInputsMobileControls.length > 0)
			controls.removeVirtualControlsInput(trackedInputsMobileControls);

		if (mobileControls != null)
		{
			remove(mobileControls);
			mobileControls = FlxDestroyUtil.destroy(mobileControls);
		}

		if (mobileControlsCamera != null)
		{
			FlxG.cameras.remove(mobileControlsCamera);
			mobileControlsCamera = null;
		}
	}

	public function addVirtualPadCamera(DefaultDrawTarget:Bool = false):Void
	{
		if (virtualPad != null)
		{
			if (virtualPadCamera != null)
			{
				FlxG.cameras.remove(virtualPadCamera);
				virtualPadCamera = null;
			}
			var camControls:FlxCamera = new FlxCamera();
			camControls.bgColor.alpha = 0;
			FlxG.cameras.add(camControls, DefaultDrawTarget);
			virtualPad.cameras = [camControls];
			virtualPadCamera = camControls;
		}
	}

	override function destroy():Void
	{
		if (trackedInputsMobileControls.length > 0)
			controls.removeVirtualControlsInput(trackedInputsMobileControls);

		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);

		if (mobileControlsCamera != null)
		{
			FlxG.cameras.remove(mobileControlsCamera);
			mobileControlsCamera = null;
		}

		if (virtualPadCamera != null)
		{
			FlxG.cameras.remove(virtualPadCamera);
			virtualPadCamera = null;
		}

		super.destroy(); // destroys pads still owned by this state exactly once
		virtualPad = null;
		mobileControls = null;
	}

	var _psychCameraInitialized:Bool = false;

	public static var windowNameSuffix(default, set):String = "";
	public static var windowNameSuffix2(default, set):String = ""; //changes to "Outdated!" if the version of the engine is outdated
	public static var windowNamePrefix:String = "Friday Night Funkin' - Phoenix Engine";

	// better then updating it all the time which can cause memory leaks
	static function set_windowNameSuffix(value:String){
		windowNameSuffix = value;
		#if !flash
		Application.current.window.title = windowNamePrefix + windowNameSuffix + windowNameSuffix2;
		#end
		return value;
	}
	static function set_windowNameSuffix2(value:String){
		windowNameSuffix2 = value;
		#if !flash
		Application.current.window.title = windowNamePrefix + windowNameSuffix + windowNameSuffix2;
		#end
		return value;
	}
	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static function getVariables()
		return getState().variables;
	
	// this is just because FlxUIState has arguments in it's constructor
	public function new() {
		super();
	}

	override function create() {
		camBeat = FlxG.camera;
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		super.create();

		if(!_psychCameraInitialized && !Main.isPlayState()) initPsychCamera();

		if(!skip) {
			openSubState(new CustomFadeTransition(0.7, true));
		}
		FlxTransitionableState.skipNextTransOut = false;

		try {windowNamePrefix = Assets.getText(Paths.txt("windowTitleBase", "preload"));}
		catch(e) {}

		#if !flash
		Application.current.window.title = windowNamePrefix + windowNameSuffix + windowNameSuffix2;
		#end
	}

	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		return camera;
	}

	override function update(elapsed:Float)
	{
		oldStep = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
		{
			stepHit();

			if(PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		FlxG.autoPause = ClientPrefs.autoPause;

		stagesFunc(function(stage:BaseStage) {
			stage.update(elapsed);
		});

		super.update(elapsed);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			final beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		final lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;

				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		final decimalStep = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + decimalStep;
		curStep = lastChange.stepTime + Math.floor(decimalStep);
		updateBeat();
	}

	override function startOutro(onOutroComplete:()->Void):Void
	{
		if (!FlxTransitionableState.skipNextTransIn)
		{
			openSubState(new CustomFadeTransition(0.6, false));
			CustomFadeTransition.finishCallback = onOutroComplete;
			return;
		}

		FlxTransitionableState.skipNextTransIn = false;

		onOutroComplete();
	}

	public var stages:Array<BaseStage> = [];
	//runs whenever the game hits a step
	public function stepHit():Void
	{
		//trace('Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

	//runs whenever the game hits a beat
	public function beatHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	//runs whenever the game hits a section
	public function sectionHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	public static function getState():MusicBeatState {
		return cast (FlxG.state, MusicBeatState);
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}
}
