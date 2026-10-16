package editors.helpers;

// REFACTOR: imports for types used by the extracted helpers
import backend.CoolUtil;
#if MODS_ALLOWED
#end
import backend.Paths;
import editors.CharacterEditorState;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import objects.Character.AnimArray;
import objects.FlxUIDropDownMenuCustom;
import openfl.utils.AssetType;

// REFACTOR: character list / positioning logic extracted from editors.CharacterEditorState
@:access(editors.CharacterEditorState)
class CharacterEditorHelpers
{
	// ===== characterList group =====

	public static function reloadCharacterDropDown(state:CharacterEditorState)
	{
		state.characterList = Mods.mergeAllTextsNamed('data/characterList.txt', Paths.getSharedPath());
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'characters/');
		#if sys
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var charToCheck:String = file.substr(0, file.length - 5);
					if(!state.characterList.contains(charToCheck))
						state.characterList.push(charToCheck);
				}
		#end

		if(state.characterList.length < 1) state.characterList.push('');
		state.charDropDown.setData(FlxUIDropDownMenuCustom.makeStrIdLabelArray(state.characterList, true));
		state.charDropDown.selectedLabel = state._char;
	}

	public static function predictCharacterIsNotPlayer(state:CharacterEditorState, name:String)
	{
		return (name != 'bf' && !name.startsWith('bf-') && !name.endsWith('-player') && !name.endsWith('-playable') && !name.endsWith('-dead')) ||
				name.endsWith('-opponent') || name.startsWith('gf-') || name.endsWith('-gf') || name == 'gf';
	}

	public static function updateCharacterPositions(state:CharacterEditorState)
	{
		state.char.setPosition(state.char.positionArray[0] + state.OFFSET_X + 100, state.char.positionArray[1]);
		updatePointerPos(state);
	}

	public static function resetHealthBarColor(state:CharacterEditorState)
	{
		state.healthColorStepperR.value = state.char.healthColorArray[0];
		state.healthColorStepperG.value = state.char.healthColorArray[1];
		state.healthColorStepperB.value = state.char.healthColorArray[2];

		state.healthBarBG.color = FlxColor.fromRGB(state.char.healthColorArray[0], state.char.healthColorArray[1], state.char.healthColorArray[2]);
	}

	// ===== characterPreview group =====

	public static function reloadCharacterImage(state:CharacterEditorState)
	{
		var lastAnim:String = state.char.getAnimationName();
		var anims:Array<AnimArray> = state.char.animationsArray.copy();

		#if flxanimate
		state.char.atlas = FlxDestroyUtil.destroy(state.char.atlas);
		#end
		state.char.isAnimateAtlas = false;
		state.char.color = FlxColor.WHITE;
		state.char.alpha = 1;

		#if flxanimate
		if(Paths.fileExists('images/' + state.char.imageFile + '/Animation.json', TEXT))
		{
			state.char.atlas = new FlxAnimate();
			state.char.atlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(state.char.atlas, state.char.imageFile);
			}
			catch(e:Dynamic)
			{
				FlxG.log.warn('Could not load atlas ${state.char.imageFile}: $e');
			}
			state.char.isAnimateAtlas = true;
		}
		else
		#end
		if (Paths.fileExists('images/' + state.char.imageFile + '.png', IMAGE))
		{
			var split:Array<String> = state.char.imageFile.split(',');
			var charFrames:FlxAtlasFrames = Paths.getAtlas(split[0].trim());

			if(split.length > 1)
			{
				var original:FlxAtlasFrames = charFrames;
				charFrames = new FlxAtlasFrames(charFrames.parent);
				charFrames.addAtlas(original, true);
				for (i in 1...split.length)
				{
					var extraFrames:FlxAtlasFrames = Paths.getAtlas(split[i].trim());
					if(extraFrames != null)
						charFrames.addAtlas(extraFrames, true);
				}
			}
			state.char.frames = charFrames;
		} else {
			trace ("The png file the game looked for wasn't found!");
			CoolUtil.coolError("The image/XML/Atlas files you tried to load couldn't be found!\nEither it doesn't exist, or the name doesn't match with the one you're putting?", "JS Engine Anti-Crash Tool");
		}

		for (anim in anims) {
			var animAnim:String = '' + anim.anim;
			var animName:String = '' + anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = !!anim.loop; //Bruh
			var animIndices:Array<Int> = anim.indices;
			addAnimation(state, animAnim, animName, animFps, animLoop, animIndices);
		}

		if(anims.length > 0)
		{
			if(lastAnim != '') state.char.playAnim(lastAnim, true);
			else state.char.dance();
		}
	}

	public static function reloadAnimList(state:CharacterEditorState)
	{
		state.animList = state.char.animationsArray;
		if(state.animList.length > 0) state.char.playAnim(state.animList[0].anim, true);
		state.curAnim = 0;

		updateText(state);
		if(state.animationDropDown != null) reloadAnimationDropDown(state);
	}

	public static function reloadAnimationDropDown(state:CharacterEditorState)
	{
		var animationList:Array<String> = [];
		for (anim in state.animList) animationList.push(anim.anim);
		if(animationList.length < 1) animationList.push('NO ANIMATIONS'); //Prevents crash

		state.animationDropDown.setData(FlxUIDropDownMenuCustom.makeStrIdLabelArray(animationList, true));
	}

	public static function updateText(state:CharacterEditorState)
	{
		state.animsTxt.removeFormat(state.selectedFormat);

		var intendText:String = '';
		for (num => anim in state.animList)
		{
			if(num > 0) intendText += '\n';

			if(num == state.curAnim)
			{
				var n:Int = intendText.length;
				intendText += anim.anim + ": " + anim.offsets;
				state.animsTxt.addFormat(state.selectedFormat, n, intendText.length);
			}
			else intendText += anim.anim + ": " + anim.offsets;
		}
		state.animsTxt.text = intendText;
	}

	public static function addAnimation(state:CharacterEditorState, anim:String, name:String, fps:Float, loop:Bool, indices:Array<Int>)
	{
		if(!state.char.isAnimateAtlas)
		{
			if(indices != null && indices.length > 0)
				state.char.animation.addByIndices(anim, name, indices, "", fps, loop);
			else
				state.char.animation.addByPrefix(anim, name, fps, loop);
		}
		#if flxanimate
		else
		{
			if(indices != null && indices.length > 0)
				state.char.atlas.anim.addBySymbolIndices(anim, name, indices, fps, loop);
			else
				state.char.atlas.anim.addBySymbol(anim, name, fps, loop);
		}
		#end

		if(!state.char.animOffsets.exists(anim))
			state.char.addOffset(anim, 0, 0);
	}

	public static function newAnim(state:CharacterEditorState, anim:String, name:String):AnimArray
	{
		return {
			offsets: [0, 0],
			loop: false,
			fps: 24,
			anim: anim,
			indices: [],
			name: name
		};
	}

	public static function findAnimationByName(state:CharacterEditorState, name:String):AnimArray
	{
		for (anim in state.char.animationsArray) {
			if(anim.anim == name) {
				return anim;
			}
		}
		return null;
	}

	public static function updatePointerPos(state:CharacterEditorState)
	{
		if(state.char == null || state.cameraFollowPointer == null) return;

		var offX:Float = 0;
		var offY:Float = 0;
		if(!state.char.isPlayer)
		{
			offX = state.char.getMidpoint().x + 150 + state.char.cameraPosition[0];
			offY = state.char.getMidpoint().y - 100 + state.char.cameraPosition[1];
		}
		else
		{
			offX = state.char.getMidpoint().x - 100 - state.char.cameraPosition[0];
			offY = state.char.getMidpoint().y - 100 + state.char.cameraPosition[1];
		}
		state.cameraFollowPointer.setPosition(offX, offY);
	}
}
