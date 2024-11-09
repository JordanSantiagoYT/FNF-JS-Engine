package stages;

import openfl.filters.ShaderFilter;
import shaders.RainShader;

import flixel.addons.display.FlxTiledSprite;
import flixel.graphics.frames.FlxAtlasFrames;

import GameOverSubstate;
import stages.objects.*;

using StringTools;

class PhillyStreetsBF extends BaseStage
{
	final MIN_BLINK_DELAY:Int = 3;
	final MAX_BLINK_DELAY:Int = 7;
	final VULTURE_THRESHOLD:Float = 0.5;
	var blinkCountdown:Int = 3;

	var rainShader:RainShader;
	var rainShaderStartIntensity:Float = 0;
	var rainShaderEndIntensity:Float = 0;
	
	var scrollingSky:FlxTiledSprite;
	var phillyTraffic:BGSprite;

	var phillyCars:BGSprite;
	var phillyCars2:BGSprite;

	var picoFade:FlxSprite;
	var spraycan:SpraycanAtlasSprite;
	var spraycanPile:BGSprite;

	var darkenable:Array<FlxSprite> = [];
	var abot:ABotSpeaker;
	override function create()
	{
		if(!ClientPrefs.lowQuality)
		{
			var skyImage = Paths.image('phillyStreets/phillySkybox');
			scrollingSky = new FlxTiledSprite(skyImage, skyImage.width + 400, skyImage.height, true, false);
			scrollingSky.antialiasing = ClientPrefs.globalAntialiasing;
			scrollingSky.setPosition(-650, -375);
			scrollingSky.scrollFactor.set(0.1, 0.1);
			scrollingSky.scale.set(0.65, 0.65);
			add(scrollingSky);
		
			var phillySkyline:BGSprite = new BGSprite('phillyStreets/phillySkyline', -545, -273, 0.2, 0.2);
			add(phillySkyline);

			var phillyForegroundCity:BGSprite = new BGSprite('phillyStreets/phillyForegroundCity', 625, 94, 0.3, 0.3);
			add(phillyForegroundCity);
		}

		var phillyConstruction:BGSprite = new BGSprite('phillyStreets/phillyConstruction', 1800, 364, 0.7, 1);
		add(phillyConstruction);

		var phillyHighwayLights:BGSprite = new BGSprite('phillyStreets/phillyHighwayLights', 284, 305, 1, 1);
		add(phillyHighwayLights);

		if(!ClientPrefs.lowQuality)
		{
			var phillyHighwayLightsLightmap:BGSprite = new BGSprite('phillyStreets/phillyHighwayLights_lightmap', 284, 305, 1, 1);
			phillyHighwayLightsLightmap.blend = ADD;
			phillyHighwayLightsLightmap.alpha = 0.6;
			add(phillyHighwayLightsLightmap);
		}

		var phillyHighway:BGSprite = new BGSprite('phillyStreets/phillyHighway', 139, 209, 1, 1);
		add(phillyHighway);

		if(!ClientPrefs.lowQuality)
		{
			var phillySmog:BGSprite = new BGSprite('phillyStreets/phillySmog', -6, 245, 0.8, 1);
			add(phillySmog);

			for (i in 0...2)
			{
				var car:BGSprite = new BGSprite('phillyStreets/phillyCars', 1200, 818, 0.9, 1, ['car1', 'car2', 'car3', 'car4'], false);
				add(car);
				switch(i)
				{
					case 0: phillyCars = car;
					case 1: phillyCars2 = car;
				}
			}
			phillyCars2.flipX = true;

			phillyTraffic = new BGSprite('phillyStreets/phillyTraffic', 1840, 608, 0.9, 1, ['redtogreen', 'greentored'], false);
			add(phillyTraffic);

			var phillyTrafficLightmap:BGSprite = new BGSprite('phillyStreets/phillyTraffic_lightmap', 1840, 608, 0.9, 1);
			phillyTrafficLightmap.blend = ADD;
			phillyTrafficLightmap.alpha = 0.6;
			add(phillyTrafficLightmap);
		}

		var phillyForeground:BGSprite = new BGSprite('phillyStreets/phillyForeground', 88, 317, 1, 1);
		add(phillyForeground);
		
		if(ClientPrefs.shaders)
			setupRainShader();
	}

	function setupRainShader()
	{
		rainShader = new RainShader();
		rainShader.scale = FlxG.height / 200;
		switch (songName)
		{
			case 'darnell':
				rainShaderStartIntensity = 0;
				rainShaderEndIntensity = 0.1;
			case 'lit-up':
				rainShaderStartIntensity = 0.1;
				rainShaderEndIntensity = 0.2;
			case '2hot':
				rainShaderStartIntensity = 0.2;
				rainShaderEndIntensity = 0.4;
		}
		rainShader.intensity = rainShaderStartIntensity;
		FlxG.camera.setFilters([new ShaderFilter(rainShader)]);
	}
	
	override function update(elapsed:Float)
	{
		if(scrollingSky != null) scrollingSky.scrollX -= elapsed * 22;

		if(rainShader != null)
		{
			var remappedIntensityValue:Float = FlxMath.remapToRange(Conductor.songPosition, 0, (FlxG.sound.music != null ? FlxG.sound.music.length : 0), rainShaderStartIntensity, rainShaderEndIntensity);
			rainShader.intensity = remappedIntensityValue;
			rainShader.updateViewInfo(FlxG.width, FlxG.height, FlxG.camera);
			rainShader.update(elapsed);
		}
	}

	var lightsStop:Bool = false;
	var lastChange:Int = 0;
	var changeInterval:Int = 8;

	var carWaiting:Bool = false;
	var carInterruptable:Bool = true;
	var car2Interruptable:Bool = true;

	override function beatHit()
	{
		if(ClientPrefs.lowQuality) return;

		if (FlxG.random.bool(10) && curBeat != (lastChange + changeInterval) && carInterruptable == true)
		{
			if(lightsStop == false)
				driveCar(phillyCars);
			else
				driveCarLights(phillyCars);
		}

		if(FlxG.random.bool(10) && curBeat != (lastChange + changeInterval) && car2Interruptable == true && lightsStop == false)
			driveCarBack(phillyCars2);

		if (curBeat == (lastChange + changeInterval)) changeLights(curBeat);
	}
	
	function changeLights(beat:Int):Void
	{
		lastChange = beat;
		lightsStop = !lightsStop;

		if(lightsStop)
		{
			phillyTraffic.animation.play('greentored');
			changeInterval = 20;
		}
		else
		{
			phillyTraffic.animation.play('redtogreen');
			changeInterval = 30;

			if(carWaiting == true) finishCarLights(phillyCars);
		}
	}

	function finishCarLights(sprite:BGSprite):Void
	{
		carWaiting = false;
		var duration:Float = FlxG.random.float(1.8, 3);
		var rotations:Array<Int> = [-5, 18];
		var offset:Array<Float> = [306.6, 168.3];
		var startdelay:Float = FlxG.random.float(0.2, 1.2);

		var path:Array<FlxPoint> = [
			FlxPoint.get(1950 - offset[0] - 80, 980 - offset[1] + 15),
			FlxPoint.get(2400 - offset[0], 980 - offset[1] - 50),
			FlxPoint.get(3102 - offset[0], 1127 - offset[1] + 40)
		];

		FlxTween.angle(sprite, rotations[0], rotations[1], duration, {ease: FlxEase.sineIn, startDelay: startdelay});
		FlxTween.quadPath(sprite, path, duration, true, {ease: FlxEase.sineIn, startDelay: startdelay, onComplete: function(_) carInterruptable = true});
	}

	function driveCarLights(sprite:BGSprite):Void
	{
		carInterruptable = false;
		FlxTween.cancelTweensOf(sprite);
		var variant:Int = FlxG.random.int(1,4);
		sprite.animation.play('car' + variant);
		var extraOffset = [0, 0];
		var duration:Float = 2;

		switch(variant)
		{
			case 1:
				duration = FlxG.random.float(1, 1.7);
			case 2:
				extraOffset = [20, -15];
				duration = FlxG.random.float(0.9, 1.5);
			case 3:
				extraOffset = [30, 50];
				duration = FlxG.random.float(1.5, 2.5);
			case 4:
				extraOffset = [10, 60];
				duration = FlxG.random.float(1.5, 2.5);
		}
		var rotations:Array<Int> = [-7, -5];
		var offset:Array<Float> = [306.6, 168.3];
		sprite.offset.set(extraOffset[0], extraOffset[1]);

		var path:Array<FlxPoint> = [
			FlxPoint.get(1500 - offset[0] - 20, 1049 - offset[1] - 20),
			FlxPoint.get(1770 - offset[0] - 80, 994 - offset[1] + 10),
			FlxPoint.get(1950 - offset[0] - 80, 980 - offset[1] + 15)
		];

		FlxTween.angle(sprite, rotations[0], rotations[1], duration, {ease: FlxEase.cubeOut} );
		FlxTween.quadPath(sprite, path, duration, true, {ease: FlxEase.cubeOut, onComplete: function(_)
		{
			carWaiting = true;
			if(lightsStop == false) finishCarLights(phillyCars);
		}});
	}
	
	function driveCar(sprite:BGSprite):Void
	{
		carInterruptable = false;
		FlxTween.cancelTweensOf(sprite);
		var variant:Int = FlxG.random.int(1,4);
		sprite.animation.play('car' + variant);

		var extraOffset = [0, 0];
		var duration:Float = 2;
		switch(variant)
		{
			case 1:
				duration = FlxG.random.float(1, 1.7);
			case 2:
				extraOffset = [20, -15];
				duration = FlxG.random.float(0.6, 1.2);
			case 3:
				extraOffset = [30, 50];
				duration = FlxG.random.float(1.5, 2.5);
			case 4:
				extraOffset = [10, 60];
				duration = FlxG.random.float(1.5, 2.5);
		}

		var offset:Array<Float> = [306.6, 168.3];
		sprite.offset.set(extraOffset[0], extraOffset[1]);

		var rotations:Array<Int> = [-8, 18];
		var path:Array<FlxPoint> = [
				FlxPoint.get(1570 - offset[0], 1049 - offset[1] - 30),
				FlxPoint.get(2400 - offset[0], 980 - offset[1] - 50),
				FlxPoint.get(3102 - offset[0], 1127 - offset[1] + 40)
		];

		FlxTween.angle(sprite, rotations[0], rotations[1], duration);
		FlxTween.quadPath(sprite, path, duration, true, {onComplete: function(_) carInterruptable = true});
	}

	function driveCarBack(sprite:FlxSprite):Void
	{
		car2Interruptable = false;
		FlxTween.cancelTweensOf(sprite);
		var variant:Int = FlxG.random.int(1,4);
		sprite.animation.play('car' + variant);

		var extraOffset = [0, 0];
		var duration:Float = 2;
		switch(variant)
		{
			case 1:
				duration = FlxG.random.float(1, 1.7);
			case 2:
				extraOffset = [20, -15];
				duration = FlxG.random.float(0.6, 1.2);
			case 3:
				extraOffset = [30, 50];
				duration = FlxG.random.float(1.5, 2.5);
			case 4:
				extraOffset = [10, 60];
				duration = FlxG.random.float(1.5, 2.5);
		}

		var offset:Array<Float> = [306.6, 168.3];
		sprite.offset.set(extraOffset[0], extraOffset[1]);

		var rotations:Array<Int> = [18, -8];
		var path:Array<FlxPoint> = [
				FlxPoint.get(3102 - offset[0], 1127 - offset[1] + 60),
				FlxPoint.get(2400 - offset[0], 980 - offset[1] - 30),
				FlxPoint.get(1570 - offset[0], 1049 - offset[1] - 10)
		];

		FlxTween.angle(sprite, rotations[0], rotations[1], duration);
		FlxTween.quadPath(sprite, path, duration, true, {onComplete: function(_) car2Interruptable = true});
	}

	override function onGameOver()
	{
		if (rainShader != null) rainShader = null;
	}
}