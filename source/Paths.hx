package;

import flixel.animation.FlxAnimationController;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFramesCollection;
import haxe.io.Bytes;
import haxe.io.Path;
import lime.media.AudioBuffer;
import lime.media.vorbis.VorbisFile;
import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.geom.Rectangle;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.AssetType;
#if cpp
import cpp.vm.Gc;
#end

@:access(openfl.display.BitmapData)
// @:nullSafety // not yet
class Paths
{
  inline public static var SOUND_EXT = "ogg";
  inline public static var VIDEO_EXT = "mp4";
  inline public static var IMAGE_EXT = "png";

  public static var defaultNoteSprite:FlxSprite;

  public static var noteSkinFramesMap:Map<String, FlxFramesCollection> = new Map();
  public static var noteSkinAnimsMap:Map<String, FlxAnimationController> = new Map();

  private static var splashFrames:FlxFramesCollection;
  private static var splashAnimation:FlxAnimationController;

  public static var splashSkinFramesMap:Map<String, FlxFramesCollection> = new Map();
  public static var splashSkinAnimsMap:Map<String, FlxAnimationController> = new Map();

  public static var splashConfigs:Map<String, NoteSplash.NoteSplashConfig> = new Map();
  public static var splashAnimCountMap:Map<String, Int> = new Map();

  public static var defaultSkin = 'noteskins/NOTE_assets' + Note.getNoteSkinPostfix();

  // Function that initializes the first note. This way, we can recycle the notes
  public static function initDefaultSkin(?noteSkin:String, ?inEditor:Bool = false)
  {
    if (noteSkin.length > 0) defaultSkin = noteSkin;
    else if (!PlayState.isPixelStage) defaultSkin = 'noteskins/NOTE_assets' + Note.getNoteSkinPostfix();
    else
      defaultSkin = 'noteskins/NOTE_assets';
    trace(defaultSkin);
  }

  public static function initNote(?noteSkin:String)
  {
    // Do this to be able to just copy over the note animations and not reallocate it
    if (noteSkin.length < 1) noteSkin = defaultSkin;
    var spr:FlxSprite = new FlxSprite();
    spr.frames = getSparrowAtlas(noteSkin.length > 1 ? noteSkin : defaultSkin);

    // Use a for loop for adding all of the animations in the note spritesheet, otherwise it won't find the animations for the next recycle
    for (d in 0...Note.colArray.length)
    {
      if (d == 0) spr.animation.addByPrefix('purpleholdend', 'pruple end hold'); // ?????
      spr.animation.addByPrefix(Note.colArray[d] + 'holdend', Note.colArray[d] + ' hold end');
      spr.animation.addByPrefix(Note.colArray[d] + 'hold', Note.colArray[d] + ' hold piece');
      spr.animation.addByPrefix(Note.colArray[d] + 'Scroll', Note.colArray[d] + '0');
    }
    noteSkinFramesMap.set(noteSkin, spr.frames);
    noteSkinAnimsMap.set(noteSkin, spr.animation);
  }

  // Note Splash initialization
  public static function initSplash(?splashSkin:String)
  {
    var skin:String = (splashSkin != null && splashSkin.length > 0) ? splashSkin : 'noteSplashes/noteSplashes' + NoteSplash.getSplashSkinPostfix();
    splashFrames = getSparrowAtlas(skin);
    if (splashFrames == null) splashFrames = getSparrowAtlas('noteSplashes/noteSplashes' + NoteSplash.getSplashSkinPostfix());

    // Do this to be able to just copy over the splash animations and not reallocate it

    var spr:FlxSprite = new FlxSprite();
    spr.frames = splashFrames;
    splashAnimation = new FlxAnimationController(spr);

    // Use a for loop for adding all of the animations in the splash spritesheet, otherwise it won't find the animations for the next recycle

    var config = splashConfigs.get(skin);
    if (config == null) config = initSplashConfig(skin);
    var maxAnims:Int = 0;
    var animName:String = (config != null && config.anim != null && config.anim.length > 0) ? config.anim : "note splash";

    var shouldBreakLoop = false;
    while (!shouldBreakLoop)
    {
      var animID:Int = maxAnims + 1;
      for (i in 0...Note.colArray.length)
      {
        if (!addAnimAndCheck('note$i-$animID', '$animName ${Note.colArray[i]} $animID', 24, false))
        {
          // Reached the maximum amount of anims, break the loop
          shouldBreakLoop = true;
          break;
        }
      }
      if (!shouldBreakLoop) maxAnims++;
      else
        break;
      // trace('currently: $maxAnims');
    }
    splashSkinFramesMap.set(splashSkin, splashFrames);
    splashSkinAnimsMap.set(splashSkin, splashAnimation);
    splashAnimCountMap.set(splashSkin, maxAnims);
  }

  public static function addAnimAndCheck(name:String, anim:String, ?framerate:Int = 24, ?loop:Bool = false)
  {
    var animFrames = [];
    @:privateAccess
    splashAnimation.findByPrefix(animFrames, anim); // adds valid frames to animFrames

    if (animFrames.length < 1) return false;

    splashAnimation.addByPrefix(name, anim, framerate, loop);
    return true;
  }

  public static function initSplashConfig(skin:String)
  {
    var path:String = Paths.getSharedPath('images/' + skin + '.txt');
    if (!FileSystem.exists(path)) path = Paths.modsTxt(skin);
    if (!FileSystem.exists(path)) path = Paths.getSharedPath('images/noteSplashes/noteSplashes' + NoteSplash.getSplashSkinPostfix() + '.txt');

    var configFile:Array<String> = CoolUtil.coolTextFile(path);

    if (configFile.length < 1) return null;

    var framerates:Array<String> = configFile[1].split(' ');
    var offs:Array<Array<Float>> = [];
    for (i in 2...configFile.length)
    {
      var animOffs:Array<String> = configFile[i].split(' ');
      offs.push([Std.parseFloat(animOffs[0]), Std.parseFloat(animOffs[1])]);
    }
    var config:NoteSplash.NoteSplashConfig =
      {
        anim: configFile[0],
        minFps: Std.parseInt(framerates[0]),
        maxFps: Std.parseInt(framerates[1]),
        offsets: offs
      };
    splashConfigs.set(skin, config);
    return config;
  }

  public static function excludeAsset(key:String)
  {
    if (!dumpExclusions.contains(key)) dumpExclusions.push(key);
  }

  public static var dumpExclusions:Array<String> = [
    'assets/music/freakyMenu.$SOUND_EXT',
    'assets/shared/music/breakfast.$SOUND_EXT',
    'assets/shared/music/tea-time.$SOUND_EXT',
  ];
  
  public static var pixelReadExclusions:Array<String> = ['images/noteColorMenu/palette.png'];

  @:noCompletion private inline static function _gc(major:Bool)
  {
    #if cpp
    Gc.run(major);
    #end
  }

  @:noCompletion public inline static function compress()
  {
    #if cpp
    Gc.compact();
    #end
  }

  public inline static function gc(major:Bool = false, repeat:Int = 1)
  {
    while (repeat-- > 0)
      _gc(major);
  }

  /// haya I love you for the base cache dump I took to the max
  public static function clearUnusedMemory()
  {
    // clear non local assets in the tracked assets list
    for (key in currentTrackedAssets.keys())
    {
      // if it is not currently contained within the used local assets
      if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
      {
        destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
        currentTrackedAssets.remove(key); // and remove the key from local cache map
      }
    }
    // run the garbage collector for good measure lmfao
    compress();
    gc(true);
  }

  // define the locally tracked assets
  public static var localTrackedAssets:Array<String> = [];

  @:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
  public static function clearStoredMemory(?cleanUnused:Bool = false)
  {
    // clear anything not in the tracked assets list
    for (key in FlxG.bitmap._cache.keys())
    {
      if (!currentTrackedAssets.exists(key)) destroyGraphic(FlxG.bitmap.get(key));
    }
    // clear all sounds that are cached
    for (key in currentTrackedSounds.keys())
    {
      if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null)
      {
        // trace('test: ' + dumpExclusions, key);
        Assets.cache.clear(key);
        currentTrackedSounds.remove(key);
      }
    }
    // flags everything to be cleared out next unused memory clear
    localTrackedAssets = [];
    openfl.Assets.cache.clear("songs");
    gc(true);
    compress();
  }

  inline static function destroyGraphic(graphic:FlxGraphic)
  {
    // free some gpu memory
    if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null) graphic.bitmap.__texture.dispose();
    FlxG.bitmap.remove(graphic);
  }

  static public var currentLevel:String;

  static public function setCurrentLevel(name:String)
  {
    currentLevel = name.toLowerCase();
  }

  public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
  {
    #if MODS_ALLOWED
    if (modsAllowed)
    {
      var customFile:String = file;
      if (library != null) customFile = '$library/$file';

      var modded:String = modFolders(customFile);
      if (FileSystem.exists(modded)) return modded;
    }
    #end

    if (library != null)
    {
      // trace(getLibraryPath(file, library));
      return getLibraryPath(file, library);
    }

    if (currentLevel != null)
    {
      var levelPath:String = '';
      if (currentLevel != 'shared')
      {
        levelPath = getLibraryPathForce(file, currentLevel);
        if (OpenFlAssets.exists(levelPath, type))
        {
          // trace(levelPath);
          return levelPath;
        }
      }

      levelPath = getLibraryPathForce(file, "shared");
      if (OpenFlAssets.exists(levelPath, type))
      {
        // trace(levelPath);
        return levelPath;
      }
    }
    // trace(getPreloadPath(file));
    return getPreloadPath(file);
  }

  public static inline function readDirectory(path:String):Array<String>
  {
    #if sys
    return FileSystem.readDirectory(path);
    #else
    // original by Karim Akra
    var files:Array<String> = [];

    for (possibleFile in Assets.list().filter((f) -> f.contains(path)))
    {
      var file:String = possibleFile.replace('${path}/', "");
      if (file.contains("/")) file = file.replace(file.substring(file.indexOf("/"), file.length), "");

      if (!files.contains(file)) files.push(file);
    }

    files.sort((a, b) -> {
      a = a.toUpperCase();
      b = b.toUpperCase();
      return (a < b) ? -1 : (a > b) ? 1 : 0;
    });

    return files;
    #end
  }

  static public function getLibraryPath(file:String, library = "preload")
  {
    return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
  }

  inline static function getLibraryPathForce(file:String, library:String, ?level:String)
  {
    if (level == null) level = library;
    var returnPath = '$library:assets/$level/$file';
    if (OpenFlAssets.exists(returnPath))
    {
      return returnPath;
    } else
    {
      return 'assets/$level/$file';
    }
  }

  inline public static function getPreloadPath(file:String = '')
  {
    return 'assets/$file';
  }

  inline public static function getSharedPath(file:String = '')
  {
    return 'assets/shared/$file';
  }

  inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
  {
    return getPath(file, type, library);
  }

  inline static public function txt(key:String, ?library:String)
  {
    return getPath('data/$key.txt', TEXT, library);
  }

  inline static public function xml(key:String, ?library:String)
  {
    return getPath('data/$key.xml', TEXT, library);
  }

  inline static public function json(key:String, ?library:String)
  {
    return getPath('data/' + key + '.json', TEXT, library);
  }

  inline static public function shaderFragment(key:String, ?library:String)
  {
    return getPath('shaders/$key.frag', TEXT, library);
  }

  inline static public function shaderVertex(key:String, ?library:String)
  {
    return getPath('shaders/$key.vert', TEXT, library);
  }

  inline static public function lua(key:String, ?library:String)
  {
    return getPath('$key.lua', TEXT, library);
  }

  // Video loading (part of it)
  static public function video(key:String, ?library:String = null)
  {
    #if MODS_ALLOWED
    var file:String = modsVideo(key);
    if (FileSystem.exists(file))
    {
      return file;
    }
    #end
    final path:String = ('assets/${(library != null) ? '$library/' : ''}videos/$key.$VIDEO_EXT');
    // trace('Video Path before being passed to hxCodec: $path');
    return path;
  }

  // Sound loading.
  static public function sound(key:String, ?library:String):Sound
  {
    var sound:Sound = returnSound('sounds', key, library);
    return sound;
  }

  // Random sound loading.
  inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
  {
    return sound(key + FlxG.random.int(min, max), library);
  }

  // Music loading. Loads anything in assets/data/music, OR mods/data/music (if mods are allowed)
  inline static public function music(key:String, ?library:String):Sound
  {
    var file:Sound = returnSound('music', key, library);
    return file;
  }

  // Loads the Voices. Crucial for generateSong
  static public function voices(song:String, ?difficulty:String = '', ?postfix:String = null):Any
  {
    var formattedDifficulty:String = formatToSongPath(difficulty);
    if (difficulty.contains(' ')) difficulty = formattedDifficulty;
    if (difficulty != null)
    {
      var songKey:String = '${formatToSongPath(song)}/Voices';
      if (postfix != null) songKey += '-' + postfix;
      songKey += '-$difficulty';
      if (FileSystem.exists(Paths.modFolders('songs/' + songKey + '.$SOUND_EXT'))
        || FileSystem.exists('assets/songs/' + songKey + '.$SOUND_EXT'))
      {
        var voices = returnSound('songs', songKey);
        return voices;
      }
    }
    var songKey:String = '${formatToSongPath(song)}/Voices';
    if (postfix != null) songKey += '-' + postfix;
    var voices = returnSound('songs', songKey);
    return voices;
  }

  // Loads the instrumental. Crucial for generateSong
  static public function inst(song:String, ?difficulty:String = ''):Any
  {
    var formattedDifficulty:String = formatToSongPath(difficulty);
    if (difficulty.contains(' ')) difficulty = formattedDifficulty;
    if (difficulty != null)
    {
      var songKey:String = '${formatToSongPath(song)}/Inst-$difficulty';
      if (FileSystem.exists(Paths.modFolders('songs/' + songKey + '.$SOUND_EXT'))
        || FileSystem.exists('assets/songs/' + songKey + '.$SOUND_EXT'))
      {
        var inst = returnSound('songs', songKey);
        return inst;
      }
    }
    var songKey:String = '${formatToSongPath(song)}/Inst';
    var inst = returnSound('songs', songKey);
    return inst;
  }

  static public function playMenuMusic(force:Bool = false, volume:Float = 1):Void
  {
    if (FlxG.sound.music == null || force)
    {
      final playAprilFools:Bool = DateUtils.isAprilFools();

      if (playAprilFools)
      {
        FlxG.sound.playMusic(Paths.music('aprilFools'), volume);
      } 
	  else
      {
        final musicName = 'freakyMenu-' + ClientPrefs.daMenuMusic;
        // trace(musicName);

        #if MODS_ALLOWED
        playModMusic(musicName, 'freakyMenu', volume); // TODO: add HScript support here
        #else
        FlxG.sound.playMusic(music(musicName), volume);
        #end
      }
    }
  }

  // For song events.
  static public function songEvents(song:String, ?difficulty:String, ?onlyEventsString:Bool = false):String
  {
    if (difficulty != null)
    {
      var formattedDifficulty:String = formatToSongPath(difficulty);
      if (difficulty.contains(' ')) difficulty = formattedDifficulty;

      var eventsKey:String = formatToSongPath(song) + '/events-${difficulty.toLowerCase()}';
      if (FileSystem.exists(Paths.json(eventsKey))
        || FileSystem.exists(Paths.modsJson(eventsKey))) return (!onlyEventsString ? eventsKey : 'events-${difficulty.toLowerCase()}');
    }
    var eventsKey:String = formatToSongPath(song) + '/events';
    return (!onlyEventsString ? eventsKey : 'events');
  }

  inline public static function imagePath(key:String, ?folder:String):String
    return getPath('images/$key.$IMAGE_EXT', IMAGE, folder);

  inline public static function imageExists(key:String, ?folder:String):Bool
    return Paths.exists(imagePath(key, folder));

  // Loads images.
  public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
  // because the trace is so damn annoying sometimes
  public static var warnedMissingAssets:Map<String, Bool> = [];

  static public function image(key:String, ?parentFolder:String = null):FlxGraphic
  {
    key = 'images/$key' + '.png';
    var bitmap:BitmapData = null;
    if (currentTrackedAssets.exists(key))
    {
      localTrackedAssets.push(key);
      return currentTrackedAssets.get(key);
    }
    return cacheBitmap(key, parentFolder, bitmap);
  }

  public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData):FlxGraphic
  {
    if (bitmap == null)
    {
      final file:String = getPath(key, IMAGE, parentFolder, true);
      #if MODS_ALLOWED if (FileSystem.exists(file)) bitmap = BitmapData.fromFile(file);
      else #end if (OpenFlAssets.exists(file, IMAGE)) bitmap = OpenFlAssets.getBitmapData(file);

      if (bitmap == null)
      {
 		if (!warnedMissingAssets.exists(file))
		{
			warnedMissingAssets.set(file, true);
			trace('oh no its returning null NOOOO ($file)');
		}
		return null;
      }
    }

    if (ClientPrefs.cacheOnGPU && bitmap.image != null && !pixelReadExclusions.contains(key))
    {
      bitmap.lock();
      if (bitmap.__texture == null)
      {
        bitmap.image.premultiplied = true;
        bitmap.getTexture(FlxG.stage.context3D);
      }
      bitmap.getSurface();
      bitmap.disposeImage();
      bitmap.image.data = null;
      bitmap.image = null;
      bitmap.readable = true;
    }

    final graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
    graph.persist = true;
    graph.destroyOnNoUse = false;

    currentTrackedAssets.set(key, graph);
    localTrackedAssets.push(key);
    return graph;
  }

  static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
  {
    #if sys
    #if MODS_ALLOWED
    if (!ignoreMods && FileSystem.exists(modFolders(key))) return File.getContent(modFolders(key));
    #end

    if (FileSystem.exists(getPreloadPath(key))) return File.getContent(getPreloadPath(key));

    if (currentLevel != null)
    {
      var levelPath:String = '';
      if (currentLevel != 'shared')
      {
        levelPath = getLibraryPathForce(key, currentLevel);
        if (FileSystem.exists(levelPath)) return File.getContent(levelPath);
      }

      levelPath = getLibraryPathForce(key, 'shared');
      if (FileSystem.exists(levelPath)) return File.getContent(levelPath);
    }
    #end
    return Assets.getText(getPath(key, TEXT));
  }

  inline static public function font(key:String)
  {
    #if MODS_ALLOWED
    var file:String = modsFont(key);
    if (FileSystem.exists(file))
    {
      return file;
    }
    #end
    return 'assets/fonts/$key';
  }

  public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false)
  {
    #if MODS_ALLOWED
    if (!ignoreMods)
    {
      for (mod in Mods.getGlobalMods())
        if (FileSystem.exists(mods('$mod/$key'))) return true;

      if (FileSystem.exists(mods(Mods.currentModDirectory + '/' + key)) || FileSystem.exists(mods(key))) return true;

      if (FileSystem.exists(mods('$key'))) return true;
    }
    #end

    if (OpenFlAssets.exists(getPath(key, type)))
    {
      return true;
    }
    return false;
  }

  // temp shit lol
  inline static public function exists(key:String, type:AssetType = null, ?library:String)
  {
    #if sys
    if (FileSystem.exists(key))
    {
      return true;
    }
    #end

    if (OpenFlAssets.exists(key, type))
    {
      return true;
    }
    return false;
  }

  inline static public function existsPath(key:String, type:AssetType = null, ?library:String)
  {
    #if sys
    if (FileSystem.exists(getPath(key, type, library)))
    {
      return true;
    }
    #end

    if (OpenFlAssets.exists(getPath(key, type, library), type))
    {
      return true;
    }
    return false;
  }

  inline public static function getContent(path:String)
  {
    #if sys
    if (path.contains(':')) path = path.substring(path.indexOf(':') + 1);
    if (FileSystem.exists(path)) return File.getContent(path);
    return null;
    #else
    return OpenFlAssets.getText(path);
    #end
  }

  static public function getAtlas(key:String, ?parentFolder:String = null):FlxAtlasFrames
  {
    var useMod = false;
    var imageLoaded:FlxGraphic = image(key, parentFolder);

    var myXml:Dynamic = getPath('images/$key.xml', TEXT, parentFolder, true);
    if (OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end)
    {
      #if MODS_ALLOWED
      return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? File.getContent(myXml) : myXml));
      #else
      return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
      #end
    } else
    {
      var myJson:Dynamic = getPath('images/$key.json', TEXT, parentFolder, true);
      if (OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end)
      {
        #if MODS_ALLOWED
        return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? File.getContent(myJson) : myJson));
        #else
        return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
        #end
      }
    }
    return getPackerAtlas(key, parentFolder);
  }

  static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null):FlxAtlasFrames
  {
    var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim());
    if (keys.length > 1)
    {
      var original:FlxAtlasFrames = parentFrames;
      parentFrames = new FlxAtlasFrames(parentFrames.parent);
      parentFrames.addAtlas(original, true);
      for (i in 1...keys.length)
      {
        var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder);
        if (extraFrames != null) parentFrames.addAtlas(extraFrames, true);
      }
    }
    return parentFrames;
  }

  inline static public function getSparrowAtlas(key:String, ?parentFolder:String = null):FlxAtlasFrames
  {
    var imageLoaded:FlxGraphic = image(key, parentFolder);
    #if MODS_ALLOWED
    var xmlExists:Bool = false;

    var xml:String = modsXml(key);
    if (FileSystem.exists(xml)) xmlExists = true;

    return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? File.getContent(xml) : getPath('images/$key' + '.xml', TEXT, parentFolder)));
    #else
    return FlxAtlasFrames.fromSparrow(imageLoaded, getPath('images/$key' + '.xml', TEXT, parentFolder));
    #end
  }

  inline static public function getPackerAtlas(key:String, ?parentFolder:String = null):FlxAtlasFrames
  {
    var imageLoaded:FlxGraphic = image(key, parentFolder);
    #if MODS_ALLOWED
    var txtExists:Bool = false;

    var txt:String = modsTxt(key);
    if (FileSystem.exists(txt)) txtExists = true;

    return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? File.getContent(txt) : getPath('images/$key' + '.txt', TEXT, parentFolder)));
    #else
    return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath('images/$key' + '.txt', TEXT, parentFolder));
    #end
  }

  inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
  {
    var imageLoaded:FlxGraphic = image(key, parentFolder);
    #if MODS_ALLOWED
    var jsonExists:Bool = false;

    var json:String = modsImagesJson(key);
    if (FileSystem.exists(json)) jsonExists = true;

    return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (jsonExists ? File.getContent(json) : getPath('images/$key' + '.json', TEXT, parentFolder)));
    #else
    return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath('images/$key' + '.json', TEXT, parentFolder));
    #end
  }

  inline static public function formatToSongPath(path:String)
  {
    var invalidChars = ~/[~&\\;:<>#]/;
    var hideChars = ~/[.,'"%?!]/;

    var path = invalidChars.split(path.replace(' ', '-')).join("-");
    return hideChars.split(path).join("").toLowerCase();
  }

  // completely rewritten asset loading? fuck!
  public static var currentTrackedSounds:Map<String, Sound> = [];

  // Returns sounds which is useful for all the sfx
  public static function returnSound(path:String, key:String, ?library:String, stream:Bool = false)
  {
    var sound:Sound = null;
    var file:String = null;

    #if MODS_ALLOWED
    file = modsSounds(path, key);
    if (currentTrackedSounds.exists(file))
    {
      localTrackedAssets.push(file);
      return currentTrackedSounds.get(file);
    } else if (FileSystem.exists(file))
    {
      #if lime_vorbis
      if (stream) sound = Sound.fromAudioBuffer(AudioBuffer.fromVorbisFile(VorbisFile.fromFile(file)));
      else
      #end
      try
      {
        final header:Bytes = File.getBytes(file).sub(0, 4);
        if (header.toString() != "OggS" && file != null)
        {
          throw 'The file "$file" is not a valid OGG file (missing OggS header). It may have been renamed from another format like MP3.';
        }

        sound = Sound.fromFile(file);
      }
      catch (e)
      {
        throw 'Cannot load sound file: $file\nMake sure it is a properly encoded .ogg file.\nError: $e';
      }
    } else
    #end
    {
      // I hate this so god damn much
      var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
      file = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
      if (path == 'songs') gottenPath = 'songs:' + gottenPath;
      if (currentTrackedSounds.exists(file))
      {
        localTrackedAssets.push(file);
        return currentTrackedSounds.get(file);
      } else if (OpenFlAssets.exists(gottenPath, SOUND))
      {
        #if lime_vorbis
        if (stream) sound = OpenFlAssets.getMusic(gottenPath);
        else
        #end
        sound = OpenFlAssets.getSound(gottenPath);
      }
    }

    if (sound != null)
    {
      localTrackedAssets.push(file);
      currentTrackedSounds.set(file, sound);
      return sound;
    }

    trace('oh no its returning null NOOOO ($file)');
    return null;
  }

  #if MODS_ALLOWED
  // Loads mods.
  inline static public function mods(key:String = '')
  {
    return 'mods/' + key;
  }

  // Loads fonts in mods/fonts.
  inline static public function modsFont(key:String)
  {
    return modFolders('fonts/' + key);
  }

  // Loads jsons in mods/data.
  inline static public function modsJson(key:String)
  {
    return modFolders('data/' + key + '.json');
  }

  // Loads videos in mods/videos.
  inline static public function modsVideo(key:String)
  {
    return modFolders('videos/' + key + '.' + VIDEO_EXT);
  }

  // Loads sounds in mods/sounds.
  inline static public function modsSounds(path:String, key:String)
  {
    return modFolders(path + '/' + key + '.' + SOUND_EXT);
  }

  // Loads images in mods/images.
  inline static public function modsImages(key:String)
  {
    return modFolders('images/' + key + '.png');
  }

  // Loads xml files in mods/images.
  inline static public function modsXml(key:String)
  {
    return modFolders('images/' + key + '.xml');
  }

  // Loads txt files in mods/images.
  inline static public function modsTxt(key:String)
  {
    return modFolders('images/' + key + '.txt');
  }

  inline static public function modsImagesJson(key:String)
    return modFolders('images/' + key + '.json');

  public static function playModMusic(file:String, fallback:String, volume:Float = 1):Void
  {
    final moddedNew = Paths.modFolders('music/' + file + '.ogg');
    final moddedLegacy = Paths.modFolders('music/${fallback}.ogg');
    for (track in [moddedNew, moddedLegacy])
    {
      // trace('track: ' + track);
      if (FileSystem.exists(track))
      {
        FlxG.sound.playMusic(Sound.fromFile(track), volume, true);
        // trace('curTrack: ' + track);
        return;
      }
    }
    final basePath = Paths.getPath('music/' + file + '.ogg', SOUND);
    if (OpenFlAssets.exists(basePath))
    {
      FlxG.sound.playMusic(Paths.music(file), volume);
      trace('fallback to base selected theme: ' + file);
    } else
    {
      FlxG.sound.playMusic(Paths.music(fallback), volume);
      trace('fallback to default: ' + fallback);
    }
  }

  static public function modFolders(key:String)
  {
    if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
    {
      var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
      if (FileSystem.exists(fileToCheck))
      {
        return fileToCheck;
      }
    }

    for (mod in Mods.getGlobalMods())
    {
      var fileToCheck:String = mods(mod + '/' + key);
      if (FileSystem.exists(fileToCheck)) return fileToCheck;
    }
    return 'mods/' + key;
  }

  public static function getBackupFilePath(songPath:String, diff:String):String
  {
    final fileName = songPath + "-" + diff + ".json";
    return Paths.modsJson("$songPath/$fileName");
  }
  #end

	#if flixel_animate
	/**
	 * Loads a Texture Atlas (Animate) export onto the given sprite.
	 *
	 * Resolves all files (`Animation.json`, `metadata.json`, `spritemapN.json`,
	 * `spritemapN.png`) through Psych's mod-aware path system, then hands the
	 * parsed inputs to `animate.FlxAnimateFrames.fromAnimate(...)`.
	 *
	 * @param spr             Target `animate.FlxAnimate` sprite.
	 * @param folderOrImg     Either a folder path under `images/` (e.g. `'characters/bf'`)
	 *                        or a pre-resolved `FlxGraphic` of the spritemap when
	 *                        `spriteJson` is also supplied.
	 * @param spriteJson      Optional override path or raw JSON string for `spritemap0.json`.
	 * @param animationJson   Optional override path or raw JSON string for `Animation.json`.
	 */
	/**
	 * Loads an Adobe Animate texture atlas into `spr`.
	 *
	 * @param swfMode  When true, nested movieclip symbols advance their own
	 *                 timelines and bake every frame, rendering like a real SWF
	 *                 player. When false (default) movieclips render statically
	 *                 (first frame only). This is a *load-time* setting baked into
	 *                 the atlas, so changing it requires a fresh parse.
	 * @param unique   Force a fresh parse instead of returning the cached atlas.
	 *                 Needed when toggling `swfMode` on an already-cached atlas
	 *                 (e.g. the character editor). Leave false for gameplay so the
	 *                 atlas is loaded once and reused.
	 */
	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null,
			?swfMode:Bool = false, ?unique:Bool = false) {
		var settings:animate.FlxAnimateFrames.FlxAnimateSettings = {swfMode: swfMode};
		var animationContent:String = null;
		var spritemaps:Array<animate.FlxAnimateFrames.SpritemapInput> = [];
		var cacheKey:String = null;

		// Some Animate exports save JSON with a UTF-8 BOM (0xEF 0xBB 0xBF), which
		// haxe.format.JsonParser rejects with "Invalid char 65279 at position 0".
		inline function stripBom(str:String):String {
			if (str != null && str.length > 0 && str.charCodeAt(0) == 0xFEFF)
				return str.substr(1);
			return str;
		}
		
		// Returns null instead of throwing when the file isn't there
		inline function optionalText(path:String):String {
			return fileExists(path, TEXT, false) ? stripBom(getTextFromFile(path)) : null;
		}

		// Allow callers to pass already-loaded JSON text (or a path to a file).
		inline function resolveJson(value:Dynamic):String {
			if (value == null) return null;
			if (Std.isOfType(value, String)) {
				var str:String = cast value;
				// Treat as a filesystem path if it looks like one; otherwise assume raw JSON.
				if (str.length < 4096 && (str.indexOf('{') < 0 || #if sys FileSystem.exists(str) #else false #end))
					return stripBom(File.getContent(str));
				return stripBom(str);
			}
			return stripBom(Std.string(value));
		}

		if (animationJson != null)
			animationContent = resolveJson(animationJson);

		if (Std.isOfType(folderOrImg, String)) {
			var folder:String = cast folderOrImg;
			cacheKey = (Mods.currentModDirectory.length > 1) ? '${Mods.currentModDirectory}/images/$folder' : 'images/$folder';

			if (animationContent == null)
				animationContent = optionalText('$cacheKey/Animation.json');

			if (animationContent == null) {
				trace('Paths.loadAnimateAtlas: no Animation.json under "$cacheKey".');
				return;
			}

			// Optional, newer exports only
			var metadataContent:String = optionalText('$cacheKey/metadata.json');

			if (spriteJson != null) {
				spritemaps.push({source: image(folder), json: resolveJson(spriteJson)});
			} else {
				for (i in 0...10) {
					var st:String = (i == 0) ? '' : '$i';
					var json:String = optionalText('$cacheKey/spritemap$st.json');
					if (json == null) continue;
					var graphic = image('$folder/spritemap$st');
					if (graphic == null) {
						trace('Paths.loadAnimateAtlas: spritemap$st.json found but image is missing for "$cacheKey".');
						continue;
					}
					spritemaps.push({source: graphic, json: json});
				}
				if (spritemaps.length == 0) {
					trace('Paths.loadAnimateAtlas: no spritemap*.json found under "$cacheKey".');
					return;
				}
				
				spr.frames = animate.FlxAnimateFrames.fromAnimate(animationContent, spritemaps, metadataContent, cacheKey, unique, settings);
			}
		} 
		else 
		{
			// folderOrImg is a FlxGraphic/BitmapData – caller is supplying inputs directly.
			spritemaps.push({source: folderOrImg, json: resolveJson(spriteJson)});
			spr.frames = animate.FlxAnimateFrames.fromAnimate(animationContent, spritemaps, null, null, unique, settings);
		}
	}

	/**
	 * Evicts a cached Animate atlas so the next `loadAnimateAtlas` re-parses it
	 * from scratch (e.g. after changing a load-time setting like `swfMode`).
	 *
	 * IMPORTANT: this destroys the cached `FlxAnimateFrames` and its graphics, so
	 * every live `FlxAnimate` still pointing at this atlas must be reloaded right
	 * after — otherwise drawing a dangling reference throws "sprite was destroyed".
	 */
	public static function clearAnimateAtlasCache(folderOrImg:String):Void {
		if (folderOrImg == null) return;
		var key:String = 'images/$folderOrImg';
		@:privateAccess {
			var cached = animate.FlxAnimateFrames._cachedAtlases.get(key);
			if (cached != null) {
				animate.FlxAnimateFrames._cachedAtlases.remove(key);
				cached.destroy();
			}
		}
	}
	#end
}
