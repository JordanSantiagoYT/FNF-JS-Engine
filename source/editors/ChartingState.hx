package editors;

import Character.CharacterFile;
import Conductor.BPMChangeEvent;
import Section.SwagSection;
import Song.SwagSong;
import backend.ui.PsychUIEventHandler.PsychUIEvent;
import backend.ui.*;
import flixel.group.FlxGroup;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSort;
import haxe.format.JsonParser;
import haxe.io.Bytes;
import lime.media.AudioBuffer;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.events.UncaughtErrorEvent;
import openfl.geom.Rectangle;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
import shaders.RGBPalette.RGBShaderReference;
import shaders.RGBPalette;

typedef SelectedNoteData = {note:Note, group:FlxTypedGroup<Note>}

typedef UndoStruct =
{
	var action:UndoAction;
	var data:Dynamic;
}

enum abstract UndoAction(String)
{
	var ADD_NOTE = 'Add Note';
	var DELETE_NOTE = 'Delete Note';
	var MOVE_NOTE = 'Move Note';
	var SELECT_NOTE = 'Select Note';
}

enum abstract ChartingTheme(String)
{
	var LIGHT = 'light';
	var DARK = 'dark';
	var DEFAULT = 'default';
	var VSLICE = 'vslice';
	var CUSTOM = 'custom';
}

enum abstract WaveformTarget(String)
{
	var INST = 'inst';
	var PLAYER = 'voc';
	var OPPONENT = 'opp';
}

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)
class ChartingState extends MusicBeatState implements PsychUIEvent
{
  public static var noteTypeList:Array<String> = // Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
  [
    '',
    'Alt Animation',
    'Hey!',
    'Hurt Note',
    'GF Sing',
    'No Animation',
	  'Cross Fade',
	  'GF Cross Fade'
  ];

  private var noteTypeIntMap:Map<Int, String> = new Map<Int, String>();
  private var noteTypeMap:Map<String, Null<Int>> = new Map<String, Null<Int>>();

  public var ignoreWarnings = false;
  public var showTheGrid = false;
  public var undos = [];
  public var redos = [];
  var lastUndoShit:String = null;

  var eventStuff:Array<Dynamic> = [
    ['', "Nothing. Yep, that's right."],
    ['Nothing', "Nothing 2: Electric Boogaloo"],
    [
      'Dadbattle Spotlight',
      "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"
    ],
    [
      'Hey!',
      "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"
    ],
    [
      'Set GF Speed',
      "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"
    ],
    [
      'Set Camera Zoom',
      "Sets the camera zoom. Used in the Erect Remixes\nValue 1: New zoom value"
    ],
    [
      'Philly Glow',
      "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."
    ],
    ['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
    [
      'Add Camera Zoom',
      "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."
    ],
    ['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
    ['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
    [
      'Play Animation',
      "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"
    ],
    [
      'Camera Follow Pos',
      "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."
    ],
    [
      'Alt Idle Animation',
      "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"
    ],
    [
      'Enable Camera Bop',
      "Enables camera bopping. Useful if you don't want the\nopponent to hit a note, but you want camera bouncing."
    ],
    [
      'Disable Camera Bop',
      "Same thing as 'Enable Camera Bopping', but disables it\ninstead."
    ],
    ['Enable Bot Energy', "Enables Bot Energy. It's useful for spamcharts!"],
    [
      'Disable Bot Energy',
      "Same thing as 'Enable Bot Energy', but disables it\ninstead."
    ],
    [
      'Set Bot Energy Speeds',
      "Sets the speeds of Bot Energy draining and refilling.\n\nValue 1: Drain speed.\nValue 2: Refill speed"
    ],
    [
      'Change Song Name',
      "Changes the song name to whatever value 1 is set to.\nIf value 1 is empty, the name will reset back to the original song name."
    ],
    [
      'Rainbow Eyesore',
      "Flashing lights that might hurt your eyes,\nhence the name.\n\nValue 1: Step to end at\nValue 2: Speed"
    ],
    [
      'Popup',
      "Value 1: Title\nValue 2: Message\nMakes a window popup with a message in it."
    ],
    [
      'Popup (No Pause)',
      "Value 1: Title\nValue 2: Message\nSame as popup but without a pause."
    ],
    [
      'Credits Popup',
      "Makes some credits pop up. \n\nValue 1: The title. \nValue 2: The composer(s)"
    ],
    [
      'Screen Shake',
      "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."
    ],
    [
      'Tween Camera Zoom',
      "Cool Camera Zoom Tween\n\nValue 1: Zoom level(leave empty OR put 'default' for default)\nValue 2: Duration\nValue 3 (split value 2 with a ','): Ease"
    ],
    [
      'Camera Bopping',
      "Makes the camera do funny bopping\n\nValue 1: Bopping Speed (how many beats you want before it bops)\nValue 2: Bopping Intensity (how hard you want it to bop, default is 1)\n\nTo reset camera bopping, place a new event and put both values as '4' and '1' respectively."
    ],
    [
      'Camera Twist',
      "Makes the camera spin!! or twist ig\nValue 1: Twist intensity\nValue 2: Twist intensity 2"
    ],
    [
      'Change Note Multiplier',
      "Changes the amount of notes played every time you hit a note.\n\nValue 1 for NM\nValue 2 for Which (1 = Oppo, 2 = BF)\nLeave V2 empty for both."
    ], // nael revamped this!
    [
      'Fake Song Length',
      "Shows a fake song length on the time bar.\n\nValue 1: The fake length (in seconds)\nValue 2: Should it tween? (true = yes, anything else = no)\nTo reset the song length to normal, make Value 1 null."
    ],
    [
      'Change Character',
      "Value 1: Character to change (Dad, BF, GF)\nValue 2: New character's name"
    ],
    [
      'Change Scroll Speed',
      "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."
    ],
    ['Set Property', "Value 1: Variable name\nValue 2: New value"],
    [
      'Windows Notification',
      "Value 1: Notification title\n    - Defaults to \"JS Engine\" if empty.\n\nValue 2: Notification message / info\n    - Defaults to \"Are you doing that one bambi song?\" if empty."
    ]
  ];

  var _file:FileReference;
  var UI_box:PsychUIBox;

  /**
   * Array of notes showing when each section STARTS in STEPS
   * Usually rounded up??
   */
  public static var curSec:Int = 0;

  public static var lastSection:Int = 0;
  private static var lastSong:String = '';

  var difficulty:String = 'normal';
  var specialAudioName:String = '';
  var specialEventsName:String = '';

  var bpmTxt:FlxText;
  var songSlider:PsychUISlider;

  var camPos:FlxObject;
  var strumLine:FlxSprite;
  var quant:AttachedSprite;
  var strumLineNotes:FlxTypedGroup<StrumNote>;
  var curSong:String = 'Test';
  var amountSteps:Int = 0;

  public static inline var GRID_SIZE:Int = 40;

  var CAM_OFFSET:Int = 360;

  var selectionNote:SelectionNote;
  var selectionEvent:FlxSprite;

  var curRenderedSustains:FlxTypedGroup<FlxSprite>;
  var curRenderedNotes:FlxTypedGroup<Note>;
  var curRenderedNoteType:FlxTypedGroup<AttachedFlxText>;
  var curRenderedEventText:FlxTypedGroup<AttachedFlxText>;

  var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
  var nextRenderedNotes:FlxTypedGroup<Note>;

  var gridBG:FlxSprite;
  var nextGridBG:FlxSprite;

  var daquantspot = 0;
  var curEventSelected:Int = 0;
  var curUndoIndex = 0;
  var curRedoIndex = 0;
  var _song:SwagSong;
  /*
   * WILL BE THE CURRENT / LAST PLACED NOTE
  **/
  var curSelectedNote:Array<Dynamic> = null;

  var playbackSpeed:Float = 1;

  var vocals:FlxSound = null;
  var opponentVocals:FlxSound = null;

  var idleMusic:EditingMusic;

  var leftIcon:HealthIcon;
  var rightIcon:HealthIcon;

  var lilStage:FlxSprite;
  var lilBf:FlxSprite;
  var lilOpp:FlxSprite;

  var value1InputText:PsychUIInputText;
  var value2InputText:PsychUIInputText;
  var currentSongName:String;
  var autosaveIndicator:FlxSprite;
  var hitsound:FlxSound = null;

  var zoomTxt:FlxText;

  var zoomList:Array<Float> = [0.0625, 0.125, 0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192];
  var curZoom:Int = 4;

  private var blockPressWhileTypingOn:Array<PsychUIInputText> = [];
  private var blockPressWhileTypingOnStepper:Array<PsychUINumericStepper> = [];
  private var blockPressWhileScrolling:Array<PsychUIDropDownMenu> = [];

  var waveformSprite:FlxSprite;
  var gridLayer:FlxTypedGroup<FlxSprite>;

  public static var quantization:Int = 16;
  public static var curQuant = 3;

  public var quantizations:Array<Int> = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192, 384, 768];

  public static var idleMusicAllow:Bool = false;
  public static var unsavedChanges:Bool = false;

  var tipBg:FlxSprite;
  var fullTipText:FlxText;

  public static var vortex:Bool = false;

  public var mouseQuant:Bool = false;
  public var hitsoundVol:Float = 1;

  var autoSaveTimer:FlxTimer;

  public var autoSaveLength:Int = 240; // 4 minutes (DEFAULT), probably long but less lag

  override function create()
  {
    idleMusic = new EditingMusic();
    undos = [];
    redos = [];
    if (PlayState.SONG != null) _song = PlayState.SONG;
    else
    {
      CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();

      _song =
        {
          song: 'Test',
          notes: [],
          events: [],
          bpm: 150.0,
          needsVoices: true,
          arrowSkin: '',
          splashSkin: 'noteSplashes', // idk it would crash if i didn't
          player1: 'bf',
          player2: 'dad',
          gfVersion: 'gf',
          songCredit: '',
          songCreditBarPath: '',
          songCreditIcon: '',
          windowName: '',
          specialAudioName: '',
          specialEventsName: '',
          event7: '',
          event7Value: '',
          speed: 1,
          stage: 'stage'
        };
      addSection();
      PlayState.SONG = _song;
    }
    difficulty = CoolUtil.currentDifficulty;
    specialAudioName = _song.specialAudioName;
    specialEventsName = _song.specialEventsName;
    hitsound = FlxG.sound.load(Paths.sound("hitsounds/osu!mania"));
    hitsound.volume = 1;

    if (Note.globalRgbShaders.length > 0) Note.globalRgbShaders = [];
    RGBPalettePool.clear();
    Paths.initDefaultSkin(_song.arrowSkin);

    #if DISCORD_ALLOWED
    // Updating Discord Rich Presence
    DiscordClient.changePresence("Chart Editor - Charting " + StringTools.replace(_song.song, '-', ' '),
      '${FlxStringUtil.formatMoney(CoolUtil.getNoteAmount(_song), false)} Notes');
    #end

    FlxG.autoPause = true; // this might help with some issues

    vortex = FlxG.save.data.chart_vortex;
    showTheGrid = FlxG.save.data.showGrid;
    idleMusicAllow = FlxG.save.data.idleMusicAllowed;

    ignoreWarnings = FlxG.save.data.ignoreWarnings;
    final bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.scrollFactor.set();
    bg.color = 0xFF222222;
    add(bg);

    lilStage = new FlxSprite(32, 432).loadGraphic(Paths.image("chartEditor/lilStage"));
    lilStage.scrollFactor.set();
    add(lilStage);

    lilBf = new FlxSprite(32, 432).loadGraphic(Paths.image("chartEditor/lilBf"), true, 300, 256);
    lilBf.animation.add("idle", [0, 1], 12, true);
    lilBf.animation.add("0", [3, 4, 5], 12, false);
    lilBf.animation.add("1", [6, 7, 8], 12, false);
    lilBf.animation.add("2", [9, 10, 11], 12, false);
    lilBf.animation.add("3", [12, 13, 14], 12, false);
    lilBf.animation.add("yeah", [17, 20, 23], 12, false);
    lilBf.animation.play("idle");
    lilBf.animation.finishCallback = function(name:String) {
      lilBf.animation.play(name, true, false, lilBf.animation.getByName(name).numFrames - 2);
    }
    lilBf.scrollFactor.set();
    add(lilBf);

    lilOpp = new FlxSprite(32, 432).loadGraphic(Paths.image("chartEditor/lilOpp"), true, 300, 256);
    lilOpp.animation.add("idle", [0, 1], 12, true);
    lilOpp.animation.add("0", [3, 4, 5], 12, false);
    lilOpp.animation.add("1", [6, 7, 8], 12, false);
    lilOpp.animation.add("2", [9, 10, 11], 12, false);
    lilOpp.animation.add("3", [12, 13, 14], 12, false);
    lilOpp.animation.play("idle");
    lilOpp.animation.finishCallback = function(name:String) {
      lilOpp.animation.play(name, true, false, lilOpp.animation.getByName(name).numFrames - 2);
    }
    lilOpp.scrollFactor.set();
    add(lilOpp);
    lilBf.visible = FlxG.save.data.lilBuddies;
    lilOpp.visible = FlxG.save.data.lilBuddies;
    lilStage.visible = FlxG.save.data.lilBuddies;

    gridLayer = new FlxTypedGroup<FlxSprite>();
    add(gridLayer);

    waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
    add(waveformSprite);

    var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90).loadGraphic(Paths.image('eventArrow'));
    leftIcon = new HealthIcon('bf');
    rightIcon = new HealthIcon('dad');
    eventIcon.scrollFactor.set(1, 1);
    leftIcon.scrollFactor.set(1, 1);
    rightIcon.scrollFactor.set(1, 1);

    eventIcon.setGraphicSize(30, 30);
    leftIcon.setGraphicSize(0, 45);
    rightIcon.setGraphicSize(0, 45);

    add(eventIcon);
    add(leftIcon);
    add(rightIcon);

    leftIcon.setPosition(GRID_SIZE + 10, -100);
    rightIcon.setPosition(GRID_SIZE * 5.2, -100);

    selectionNote = new SelectionNote(0, 0, 0);
    selectionNote.visible = false;
    var skin:String = Note.defaultNoteSkin + Note.getNoteSkinPostfix();
    if (_song.arrowSkin != null && _song.arrowSkin.length > 1) skin = _song.arrowSkin;
    selectionNote.texture = skin;
    selectionNote.setGraphicSize(GRID_SIZE, GRID_SIZE);
    selectionNote.updateHitbox();
    selectionNote.playAnim('static', true);
    selectionNote.alpha = 0.75;
    add(selectionNote);

    selectionEvent = new FlxSprite().loadGraphic(Paths.image('eventArrow'));
    selectionEvent.setGraphicSize(GRID_SIZE, GRID_SIZE);
    selectionEvent.updateHitbox();
    selectionEvent.active = selectionEvent.visible = false;
    selectionEvent.alpha = 0.5;
    add(selectionEvent);

    curRenderedSustains = new FlxTypedGroup<FlxSprite>();
    curRenderedNotes = new FlxTypedGroup<Note>();
    curRenderedNoteType = new FlxTypedGroup<AttachedFlxText>();
    curRenderedEventText = new FlxTypedGroup<AttachedFlxText>();

    nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
    nextRenderedNotes = new FlxTypedGroup<Note>();

    if (curSec >= _song.notes.length) curSec = _song.notes.length - 1;

    FlxG.mouse.visible = true;

    addSection();

    updateJsonData();
    currentSongName = Paths.formatToSongPath(_song.song);
    loadSong();
    reloadGridLayer();
    Conductor.changeBPM(_song.bpm);
    Conductor.mapBPMChanges(_song);

    bpmTxt = new FlxText(1000, 50, 0, "", 16);
    bpmTxt.scrollFactor.set();
    add(bpmTxt);

    strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
    add(strumLine);

    quant = new AttachedSprite('chart_quant', 'chart_quant');
    quant.animation.addByPrefix('q', 'chart_quant', 0, false);
    quant.animation.play('q', true, false, curQuant);
    quant.sprTracker = strumLine;
    quant.xAdd = -32;
    quant.yAdd = 8;
    add(quant);

    strumLineNotes = new FlxTypedGroup<StrumNote>();
    for (i in 0...8)
    {
      final note:StrumNote = new StrumNote(GRID_SIZE * (i + 1), strumLine.y, i % 4, 0, true);
      note.setGraphicSize(GRID_SIZE, GRID_SIZE);
      note.updateHitbox();
      note.playAnim('static', true);
      strumLineNotes.add(note);
      note.scrollFactor.set(1, 1);
    }
    add(strumLineNotes);

    camPos = new FlxObject(0, 0, 1, 1);
    camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);

	UI_box = new PsychUIBox(640 + GRID_SIZE / 2 - 50, 25, 450, 450, ['Charting', 'Data', 'Events', 'Note', 'Section', 'Song', 'Note Spamming']);
	UI_box.canMove = false;
	UI_box.scrollFactor.set();
	add(UI_box);

	autoSaveLength = ClientPrefs.autosaveTime ?? 240;

    autosaveIndicator = new FlxSprite(-30, FlxG.height - 90).loadGraphic(Paths.image('autosaveIndicator'));
    autosaveIndicator.setGraphicSize(200, 70);
    autosaveIndicator.alpha = 0;
    autosaveIndicator.scrollFactor.set();
    autosaveIndicator.antialiasing = ClientPrefs.globalAntialiasing;
    add(autosaveIndicator);
    if (autoSaveTimer != null)
    {
      autoSaveTimer.cancel();
      autoSaveTimer = null;
      autosaveIndicator.alpha = 0;
    }
    // TODO: expand this more & maybe port the 1.0 system to here
    autoSaveTimer = new FlxTimer().start(autoSaveLength, function(tmr:FlxTimer) {
      if (!ClientPrefs.autosaveCharts) return;
      FlxTween.tween(autosaveIndicator, {alpha: 1}, 1,
        {
          ease: FlxEase.quadInOut,
          onComplete: function(twn:FlxTween) {
            FlxTween.tween(autosaveIndicator, {alpha: 0}, 1,
              {
                startDelay: 0.1,
                ease: FlxEase.quadInOut
              });
          }
        });
      saveLevel(true, true);
    }, 0);

    addSongUI();
    addSectionUI();
    addNoteUI();
    addEventsUI();
    addChartingUI();
    addNoteStackingUI();
    addSongDataUI();
    updateHeads();
    updateWaveform();

    add(curRenderedSustains);
    add(curRenderedNotes);
    add(curRenderedNoteType);
    add(curRenderedEventText);
    add(nextRenderedSustains);
    add(nextRenderedNotes);

    songSlider = new PsychUISlider(1000, 15, function(v:Float)
    {
      var t:Float = v;
      if (FlxG.sound.music != null)
        FlxG.sound.music.time = t;
      if (vocals != null) vocals.time = t;
      if (opponentVocals != null) opponentVocals.time = t;
      Conductor.songPosition = t;

      var sec:Int = getSectionAtTime(t);
      if (sec != curSec) changeSection(sec, false); // false = don't re-seek to the section start
      updateCurStep();
    }, FlxG.sound.music != null ? FlxG.sound.music.time : 0, 0, FlxG.sound.music != null ? FlxG.sound.music.length : 0, 250);

    songSlider.minText.visible = false;
    songSlider.maxText.visible = false;
    songSlider.valueText.visible = false;

    add(songSlider);
    songSlider.scrollFactor.set();

    if (lastSong != currentSongName)
    {
      changeSection();
    }
    lastSong = currentSongName;

    zoomTxt = new FlxText(10, 10, 0, "Zoom: 1 / 1", 16);
    zoomTxt.scrollFactor.set();
    add(zoomTxt);

    if (idleMusicAllow) 
      idleMusic.playMusic();
    else
      idleMusic.pauseMusic();
	  
	tipBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
	tipBg.scale.set(FlxG.width, FlxG.height);
	tipBg.updateHitbox();
	tipBg.scrollFactor.set();
	tipBg.visible = tipBg.active = false;
	tipBg.alpha = 0.6;
	add(tipBg);

    fullTipText = new FlxText(0, 0, FlxG.width - 200);
    fullTipText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER);
    fullTipText.scrollFactor.set();
    fullTipText.visible = fullTipText.active = false;
    fullTipText.text = [
    "W/S or Mouse Wheel - Change Conductor's strum time",
    "A/D - Go to the previous/next section",
    "Left/Right - Change Snap",
    "Up/Down - Change Conductor's Strum Time with Snapping",
    #if FLX_PITCH
    "Left Bracket / Right Bracket - Change Song Playback Rate (SHIFT to go Faster)",
    "ALT + Left Bracket / Right Bracket - Reset Song Playback Rate",
    #end
    "Hold Shift to move 4x faster",
    "Hold CTRL to move 4x slower",
    "Hold CTRL and click on an arrow to select it",
    "Hold Alt and click on a note to change it to the selected note type",
    "Hold CTRL and use the Mouse Wheel to decrease/increase the note's sustain length",
    "Z/X - Zoom in/out",
    "CTRL + Z - Undo",
    "",
    "(Hold) CTRL + Left/Right - Shift the currently selected note",
    "Esc - Test your chart inside Chart Editor",
    "Enter - Play your chart",
    "Shift + Enter - Play your chart at the current section",
    "Q/E - Decrease/Increase Note Sustain Length",
    "Space - Stop/Resume song",
    ].join('\n');
    fullTipText.screenCenter();
    add(fullTipText);

    updateGrid();

    super.create();
  }

  var check_mute_inst:PsychUICheckBox = null;
  var check_mute_vocals:PsychUICheckBox = null;
  var check_mute_vocals_opponent:PsychUICheckBox = null;
  var check_vortex:PsychUICheckBox = null;
  var check_showGrid:PsychUICheckBox = null;
  var check_warnings:PsychUICheckBox = null;
  var playSoundBf:PsychUICheckBox = null;
  var playSoundDad:PsychUICheckBox = null;
  var UI_songTitle:PsychUIInputText;
  var UI_songDiff:PsychUIInputText;
  var UI_specAudio:PsychUIInputText;
  var UI_specEvents:PsychUIInputText;
  var noteSkinInputText:PsychUIInputText;
  var noteSplashesInputText:PsychUIInputText;
  var stageDropDown:PsychUIDropDownMenu;
  #if FLX_PITCH
  var sliderRate:PsychUISlider;
  #end
  var stepperSpeed:PsychUINumericStepper;
  var stepperBPM:PsychUINumericStepper;

  function addSongUI():Void
  {
    UI_songTitle = new PsychUIInputText(10, 10, 120, _song.song, 8);
    blockPressWhileTypingOn.push(UI_songTitle);

    var check_voices = new PsychUICheckBox(10, 25, "Has voice track");
    check_voices.checked = _song.needsVoices;
    check_voices.onClick = function()
    {
      _song.needsVoices = check_voices.checked;
      //trace('CHECKED!');
    };

    var saveButton:PsychUIButton = new PsychUIButton(110, 8, "Save", function() {
      saveLevel();
    });

    var reloadSong:PsychUIButton = new PsychUIButton(saveButton.x + 90, saveButton.y, "Reload Audio", function() {
      currentSongName = Paths.formatToSongPath(UI_songTitle.text);
      updateJsonData();
      loadSong();
      updateWaveform();
    });

    var reloadSongJson:PsychUIButton = new PsychUIButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function() {
      openSubState(new Prompt('This action will clear current progress.\n\nProceed?', function() {
        loadJson(_song.song.toLowerCase(), difficulty);
      }, null, ignoreWarnings));
    });

    var loadAutosaveBtn:PsychUIButton = new PsychUIButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Backup From File', function() {
      promptBackup(); // this is so assssssssssssssssssssssss
    });

    var loadEventJson:PsychUIButton = new PsychUIButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Load Events', function() {
      var diff:String = (specialEventsName.length > 1 ? specialEventsName : difficulty).toLowerCase();
      var songName:String = Paths.formatToSongPath(_song.song);
      var file:String = Paths.songEvents(songName, diff);
      #if sys
      if (FileSystem.exists(Paths.json(file)) || FileSystem.exists(Paths.modsJson(file)))
      #else
      if (OpenFlAssets.exists(file))
      #end
      {
        clearEvents();
        var events:SwagSong = Song.loadFromJson(Paths.songEvents(songName, diff, true), songName);
        _song.events = events.events;
        changeSection(curSec);
      }
    });

    var saveEvents:PsychUIButton = new PsychUIButton(110, reloadSongJson.y, 'Save Events', function() {
      saveEvents();
    });
    var saveCompressed:PsychUIButton = new PsychUIButton(110, reloadSongJson.y + 30, 'Save Compressed', function() {
      saveLevel(true);
    });
    var autosaveButton:PsychUIButton = new PsychUIButton(saveEvents.x, reloadSongJson.y + 60, "Save to Backups", function() {
      if (autoSaveTimer != null) autoSaveTimer.reset(autoSaveLength);

      saveLevel(true, true);
    });

    var clear_events:PsychUIButton = new PsychUIButton(320, 310, 'Clear events', function() {
      openSubState(new Prompt('This action will clear current progress.\n\nProceed?', clearEvents, null, ignoreWarnings));
    });
    clear_events.normalStyle.bgColor = 0xFF210707;
    clear_events.normalStyle.textColor = FlxColor.WHITE;

    var clear_notes:PsychUIButton = new PsychUIButton(320, clear_events.y + 30, 'Clear notes', function() {
      openSubState(new Prompt('This action will clear current progress.\n\nProceed?', function() {
        for (sec in 0..._song.notes.length)
        {
          _song.notes[sec].sectionNotes = [];
        }
        updateGrid();
      }, null, ignoreWarnings));
    });
    clear_notes.normalStyle.bgColor = 0xFF210707;
    clear_notes.normalStyle.textColor = FlxColor.WHITE;

    stepperBPM = new PsychUINumericStepper(10, 70, 1, 1, 1, 999999, 3);
    stepperBPM.value = Conductor.bpm;
    blockPressWhileTypingOnStepper.push(stepperBPM);

    stepperSpeed = new PsychUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 100, 2);
    stepperSpeed.value = _song.speed;
    blockPressWhileTypingOnStepper.push(stepperSpeed);
    #if MODS_ALLOWED
    var directories:Array<String> = [
      Paths.mods('characters/'),
      Paths.mods(Mods.currentModDirectory + '/characters/'),
      Paths.getPreloadPath('characters/')
    ];
    for (mod in Mods.getGlobalMods())
      directories.push(Paths.mods(mod + '/characters/'));
    #else
    var directories:Array<String> = [Paths.getPreloadPath('characters/')];
    #end

    var tempMap:Map<String, Bool> = new Map<String, Bool>();
    var characters:Array<String> = CoolUtil.coolTextFile(Paths.txt('characterList'));
    for (i in 0...characters.length)
    {
      tempMap.set(characters[i], true);
    }

    #if MODS_ALLOWED
    for (i in 0...directories.length)
    {
      var directory:String = directories[i];
      if (FileSystem.exists(directory))
      {
        for (file in FileSystem.readDirectory(directory))
        {
          var path = haxe.io.Path.join([directory, file]);
          if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
          {
            var charToCheck:String = file.substr(0, file.length - 5);
            if (!charToCheck.endsWith('-dead') && !tempMap.exists(charToCheck))
            {
              tempMap.set(charToCheck, true);
              characters.push(charToCheck);
            }
          }
        }
      }
    }
    #end

    var player1DropDown = new PsychUIDropDownMenu(10, stepperSpeed.y + 45, characters, function(id:Int, character:String)
    {
      _song.player1 = characters[id];
      updateJsonData();
      updateHeads();
    });
    player1DropDown.selectedLabel = _song.player1;
    blockPressWhileScrolling.push(player1DropDown);

    var gfVersionDropDown = new PsychUIDropDownMenu(player1DropDown.x, player1DropDown.y + 40, characters, function(id:Int, character:String)
    {
      _song.gfVersion = characters[id];
      updateJsonData();
      updateHeads();
    });
    gfVersionDropDown.selectedLabel = _song.gfVersion;
    blockPressWhileScrolling.push(gfVersionDropDown);

    var player2DropDown = new PsychUIDropDownMenu(player1DropDown.x, gfVersionDropDown.y + 40, characters, function(id:Int, character:String)
    {
      _song.player2 = characters[id];
      updateJsonData();
      updateHeads();
    });
    player2DropDown.selectedLabel = _song.player2;
    blockPressWhileScrolling.push(player2DropDown);

    #if MODS_ALLOWED
    var directories:Array<String> = [
      Paths.mods('stages/'),
      Paths.mods(Mods.currentModDirectory + '/stages/'),
      Paths.getPreloadPath('stages/')
    ];
    for (mod in Mods.getGlobalMods())
      directories.push(Paths.mods(mod + '/stages/'));
    #else
    var directories:Array<String> = [Paths.getPreloadPath('stages/')];
    #end

    tempMap.clear();
    var stageFile:Array<String> = CoolUtil.coolTextFile(Paths.txt('stageList'));
    var stages:Array<String> = [];
    for (i in 0...stageFile.length)
    { // Prevent duplicates
      var stageToCheck:String = stageFile[i];
      if (!tempMap.exists(stageToCheck))
      {
        stages.push(stageToCheck);
      }
      tempMap.set(stageToCheck, true);
    }
    #if MODS_ALLOWED
    for (i in 0...directories.length)
    {
      var directory:String = directories[i];
      if (FileSystem.exists(directory))
      {
        for (file in FileSystem.readDirectory(directory))
        {
          var path = haxe.io.Path.join([directory, file]);
          if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
          {
            var stageToCheck:String = file.substr(0, file.length - 5);
            if (!tempMap.exists(stageToCheck))
            {
              tempMap.set(stageToCheck, true);
              stages.push(stageToCheck);
            }
          }
        }
      }
    }
    #end

    if(stages.length < 1) stages.push('stage');

    stageDropDown = new PsychUIDropDownMenu(player1DropDown.x, player2DropDown.y + 40, stages, function(id:Int, character:String)
    {
      _song.stage = stages[id];
    });
    stageDropDown.selectedLabel = _song.stage;
    blockPressWhileScrolling.push(stageDropDown);

    UI_songDiff = new PsychUIInputText(stageDropDown.x, stageDropDown.y + 40, 70, CoolUtil.currentDifficulty, 8);
    blockPressWhileTypingOn.push(UI_songDiff);

    UI_specAudio = new PsychUIInputText(stageDropDown.x, stageDropDown.y + 70, 70, specialAudioName, 8);
    blockPressWhileTypingOn.push(UI_specAudio);

    UI_specEvents = new PsychUIInputText(stageDropDown.x, stageDropDown.y + 100, 70, specialEventsName, 8);
    blockPressWhileTypingOn.push(UI_specEvents);

    var skin = PlayState.SONG.arrowSkin;
    if (skin == null) skin = '';
    noteSkinInputText = new PsychUIInputText(player2DropDown.x, player2DropDown.y + 50, 150, skin, 8);
    blockPressWhileTypingOn.push(noteSkinInputText);

    noteSplashesInputText = new PsychUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, _song.splashSkin, 8);
    blockPressWhileTypingOn.push(noteSplashesInputText);

    var reloadNotesButton:PsychUIButton = new PsychUIButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', function() {
      _song.arrowSkin = noteSkinInputText.text;
      selectionNote.texture = noteSkinInputText.text;
      Paths.initDefaultSkin(noteSkinInputText.text);
      updateGrid();
    });

    final tab_group_song = UI_box.getTab('Song').menu;
    tab_group_song.add(UI_songTitle);
    tab_group_song.add(UI_songDiff);
    tab_group_song.add(UI_specAudio);
    tab_group_song.add(UI_specEvents);

    tab_group_song.add(check_voices);
    tab_group_song.add(clear_events);
    tab_group_song.add(clear_notes);
    tab_group_song.add(saveButton);
    tab_group_song.add(saveEvents);
    tab_group_song.add(saveCompressed);
    tab_group_song.add(reloadSong);
    tab_group_song.add(reloadSongJson);
    tab_group_song.add(loadAutosaveBtn);
    tab_group_song.add(autosaveButton);
    tab_group_song.add(loadEventJson);
    tab_group_song.add(stepperBPM);
    tab_group_song.add(stepperSpeed);
    tab_group_song.add(reloadNotesButton);
    tab_group_song.add(noteSkinInputText);
    tab_group_song.add(noteSplashesInputText);
    tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
    tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
    tab_group_song.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
    tab_group_song.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
    tab_group_song.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Boyfriend:'));
    tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
    tab_group_song.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
    tab_group_song.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
    tab_group_song.add(new FlxText(UI_songDiff.x, UI_songDiff.y - 15, 0, "Difficulty:"));
    tab_group_song.add(new FlxText(UI_specAudio.x, UI_specAudio.y - 15, 0, "Special Audio Name:"));
    tab_group_song.add(new FlxText(UI_specEvents.x, UI_specEvents.y - 15, 0, "Special Events File:"));
    tab_group_song.add(player2DropDown);
    tab_group_song.add(gfVersionDropDown);
    tab_group_song.add(player1DropDown);
    tab_group_song.add(stageDropDown);

    initPsychCamera().follow(camPos, null, 999);
  }

  function songJsonPopup() // you tried reloading the json, but it doesn't exist
  {
    CoolUtil.coolError("The engine failed to load the JSON! \nEither it doesn't exist, or the name doesn't match with the one you're putting?", "JS Engine Anti-Crash Tool");
  }

  function promptBackup()
  {
    var fD:FileDialog = new FileDialog();

    fD.onOpen.add(f -> {
      // Kinda stupid but it works
      openSubState(new Prompt('This action will clear current progress.\n\nProceed?', function() {
        try
        {
          var wrapper:SwagSong = Song.parseJSON(f);
          if (wrapper.song == null)
          {
            CoolUtil.coolError("Failed to load JSON – not a valid chart.json.", "JS Engine Anti-Crash Tool");
            return;
          }

          PlayState.SONG = wrapper;
          CoolUtil.currentDifficulty = "backup";

          FlxG.resetState();
        }
        catch (e)
        {
          CoolUtil.coolError('Failed to load JSON, is it a character.json or a stage.json instead of a chart.json?\nError: $e', "JS Engine Anti-Crash Tool");
        };
      }, null, ignoreWarnings));
    });

    fD.open("json", null, "Choose a Psych Engine Compatible Chart JSON to load as.");
  }

  var gameOverCharacterInputText:PsychUIInputText;
  var gameOverSoundInputText:PsychUIInputText;
  var gameOverLoopInputText:PsychUIInputText;
  var gameOverEndInputText:PsychUIInputText;
  var creditInputText:PsychUIInputText;
  var creditPathInputText:PsychUIInputText;
  var creditIconInputText:PsychUIInputText;
  var winNameInputText:PsychUIInputText;

  function addSongDataUI():Void // therell be more added here later
  {
	final tab_group_data = UI_box.getTab('Data').menu;

    creditInputText = new PsychUIInputText(10, 30, 100, _song.songCredit, 8);
    blockPressWhileTypingOn.push(creditInputText);

    creditPathInputText = new PsychUIInputText(10, 60, 100, _song.songCreditBarPath, 8);
    blockPressWhileTypingOn.push(creditPathInputText);

    creditIconInputText = new PsychUIInputText(10, 90, 100, _song.songCreditIcon, 8);
    blockPressWhileTypingOn.push(creditIconInputText);

    winNameInputText = new PsychUIInputText(10, 120, 100, _song.windowName, 8);
    blockPressWhileTypingOn.push(winNameInputText);

    gameOverCharacterInputText = new PsychUIInputText(10, winNameInputText.y + 30, 150, _song.gameOverChar != null ? _song.gameOverChar : '', 8);
    blockPressWhileTypingOn.push(gameOverCharacterInputText);

    gameOverSoundInputText = new PsychUIInputText(10, gameOverCharacterInputText.y + 35, 150, _song.gameOverSound != null ? _song.gameOverSound : '', 8);
    blockPressWhileTypingOn.push(gameOverSoundInputText);

    gameOverLoopInputText = new PsychUIInputText(10, gameOverSoundInputText.y + 35, 150, _song.gameOverLoop != null ? _song.gameOverLoop : '', 8);
    blockPressWhileTypingOn.push(gameOverLoopInputText);

    gameOverEndInputText = new PsychUIInputText(10, gameOverLoopInputText.y + 35, 150, _song.gameOverEnd != null ? _song.gameOverEnd : '', 8);
    blockPressWhileTypingOn.push(gameOverEndInputText);

	var check_disableNoteRGB:PsychUICheckBox = new PsychUICheckBox(10, 170, "Disable Note RGB", 100);
	check_disableNoteRGB.checked = (_song.disableNoteRGB == true);
	check_disableNoteRGB.onClick = function()
	{
		_song.disableNoteRGB = check_disableNoteRGB.checked;
		updateGrid();
		//trace('CHECKED!');
	};

    tab_group_data.add(gameOverCharacterInputText);
    tab_group_data.add(gameOverSoundInputText);
    tab_group_data.add(gameOverLoopInputText);
    tab_group_data.add(gameOverEndInputText);

    tab_group_data.add(check_disableNoteRGB);

    tab_group_data.add(new FlxText(gameOverCharacterInputText.x, gameOverCharacterInputText.y - 15, 0, 'Game Over Character Name:'));
    tab_group_data.add(new FlxText(gameOverSoundInputText.x, gameOverSoundInputText.y - 15, 0, 'Game Over Death Sound (sounds/):'));
    tab_group_data.add(new FlxText(gameOverLoopInputText.x, gameOverLoopInputText.y - 15, 0, 'Game Over Loop Music (music/):'));
    tab_group_data.add(new FlxText(gameOverEndInputText.x, gameOverEndInputText.y - 15, 0, 'Game Over Retry Music (music/):'));

    tab_group_data.add(creditInputText);
    tab_group_data.add(creditPathInputText);
    tab_group_data.add(creditIconInputText);
    tab_group_data.add(new FlxText(creditInputText.x, creditInputText.y - 15, 0, 'Song Credit:'));
    tab_group_data.add(new FlxText(creditPathInputText.x, creditPathInputText.y - 15, 0, 'Credit Bar Path:'));
    tab_group_data.add(new FlxText(creditIconInputText.x, creditIconInputText.y - 15, 0, 'Credit Icon:'));
    tab_group_data.add(winNameInputText);
    tab_group_data.add(new FlxText(winNameInputText.x, winNameInputText.y - 15, 0, 'Window Name:'));
  }

  var stepperBeats:PsychUINumericStepper;
  var check_mustHitSection:PsychUICheckBox;
  var check_gfSection:PsychUICheckBox;
  var check_changeBPM:PsychUICheckBox;
  var stepperSectionBPM:PsychUINumericStepper;
  var check_altAnim:PsychUICheckBox;
  var check_crossFade:PsychUICheckBox;

  var notesCopied:Array<Dynamic>;
  var CopyLastSectionCount:PsychUINumericStepper;
  var CopyFutureSectionCount:PsychUINumericStepper;
  var CopyLoopCount:PsychUINumericStepper;
  var copyMultiSectButton:PsychUIButton;

  var deleteSecStart:PsychUINumericStepper;
  var deleteSecEnd:PsychUINumericStepper;
  var deleteSections:PsychUIButton;

  function addSectionUI():Void
  {
	final tab_group_section = UI_box.getTab('Section').menu;

	var check_mustHitSection = new PsychUICheckBox(10, 15, "Must hit section", 100, function() {
		_song.notes[curSec] != null ? _song.notes[curSec].mustHitSection : true;
	});

    check_gfSection = new PsychUICheckBox(10, check_mustHitSection.y + 22, "GF section", 100);
    check_gfSection.name = 'check_gf';
    check_gfSection.checked = (_song.notes[curSec] != null ? _song.notes[curSec].gfSection : false);

    check_altAnim = new PsychUICheckBox(check_gfSection.x + 120, check_gfSection.y, "Alt Animation", 100);
    check_altAnim.checked = (_song.notes[curSec] != null ? _song.notes[curSec].altAnim : false);

    stepperBeats = new PsychUINumericStepper(10, 100, 1, 4, 1, 8192, 2); // idk why youd need 8k beats in a single section but ok i guess??
    stepperBeats.value = getSectionBeats();
    stepperBeats.name = 'section_beats';
    blockPressWhileTypingOnStepper.push(stepperBeats);
    check_altAnim.name = 'check_altAnim';

    check_crossFade = new PsychUICheckBox(130, 60, "Cross Fade", 100);
	check_crossFade.checked = _song.notes[curSec].crossFade;
	check_crossFade.name = 'check_crossFade';

    check_changeBPM = new PsychUICheckBox(10, stepperBeats.y + 30, 'Change BPM', 100);
    check_changeBPM.checked = (_song.notes[curSec] != null ? _song.notes[curSec].changeBPM : false);
    check_changeBPM.name = 'check_changeBPM';

    stepperSectionBPM = new PsychUINumericStepper(10, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999999, 3);
    if (check_changeBPM.checked)
    {
      stepperSectionBPM.value = _song.notes[curSec].bpm;
    } 
	else
    {
      stepperSectionBPM.value = Conductor.bpm;
    }
    stepperSectionBPM.name = 'section_bpm';
    blockPressWhileTypingOnStepper.push(stepperSectionBPM);

    var check_eventsSec:PsychUICheckBox = null;
    var check_notesSec:PsychUICheckBox = null;
    var copyButton:PsychUIButton = new PsychUIButton(10, 190, "Copy Section", function() {
      notesCopied = [];
      var srcStart:Float = secStartAbs(curSec);
      var srcEnd:Float = secStartAbs(curSec + 1);
      var msPerBeat:Float = 60000 / secBPM(curSec);

      for (note in _song.notes[curSec].sectionNotes)
      {
        var c:Array<Dynamic> = note.copy();
        c[0] = (note[0] - srcStart) / msPerBeat; // beats from section start
        if (c[2] != null) c[2] = note[2] / msPerBeat; // sustain in beats
        notesCopied.push(c);
      }

      for (event in _song.events)
      {
        if (event[0] >= srcStart && event[0] < srcEnd)
        {
          var arr:Array<Dynamic> = [];
          for (e in cast(event[1], Array<Dynamic>)) arr.push([e[0], e[1], e[2]]);
          notesCopied.push([(event[0] - srcStart) / msPerBeat, -1, arr]);
        }
      }
    });

    var pasteButton:PsychUIButton = new PsychUIButton(copyButton.x + 100, copyButton.y, "Paste Section", function() {
      if (notesCopied == null || notesCopied.length < 1) return;
      saveUndo(_song);

      var dstStart:Float = secStartAbs(curSec);
      var msPerBeat:Float = 60000 / secBPM(curSec);

      for (note in notesCopied)
      {
        var newStrumTime:Float = dstStart + note[0] * msPerBeat;
        if (note[1] < 0)
        {
          if (check_eventsSec.checked)
          {
            var arr:Array<Dynamic> = [];
            for (e in cast(note[2], Array<Dynamic>)) arr.push([e[0], e[1], e[2]]);
            _song.events.push([newStrumTime, arr]);
          }
        }
        else if (check_notesSec.checked)
        {
          var c:Array<Dynamic> = note.copy();
          c[0] = newStrumTime;
          if (c[2] != null) c[2] = note[2] * msPerBeat;
          _song.notes[curSec].sectionNotes.push(c);
        }
      }
      updateGrid(false);
    });

    var clearSectionButton:PsychUIButton = new PsychUIButton(pasteButton.x + 100, pasteButton.y, "Clear", function() {
      if (check_notesSec.checked)
      {
        _song.notes[curSec].sectionNotes = [];
      }

      if (check_eventsSec.checked)
      {
        var i:Int = _song.events.length - 1;
        var startThing:Float = sectionStartTime();
        var endThing:Float = sectionStartTime(1);
        while (i > -1)
        {
          var event:Array<Dynamic> = _song.events[i];
          if (event != null && endThing > event[0] && event[0] >= startThing)
          {
            _song.events.remove(event);
          }
          --i;
        }
      }
      updateGrid(false);
      updateNoteUI();
    });
	clearSectionButton.normalStyle.bgColor = 0xFF210707;
	clearSectionButton.normalStyle.textColor = FlxColor.WHITE;

    check_notesSec = new PsychUICheckBox(10, clearSectionButton.y + 25, "Notes", 60);
    check_notesSec.checked = true;
    check_eventsSec = new PsychUICheckBox(check_notesSec.x + 100, check_notesSec.y, "Events", 60);
    check_eventsSec.checked = true;

    var swapSection:PsychUIButton = new PsychUIButton(10, check_notesSec.y + 40, "Swap section", function() {
      for (i in 0..._song.notes[curSec].sectionNotes.length)
      {
        var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
        note[1] = (note[1] + 4) % 8;
        _song.notes[curSec].sectionNotes[i] = note;
      }
      updateGrid(false);
    });

    var stepperCopy:PsychUINumericStepper = null;
    var copyLastButton:PsychUIButton = new PsychUIButton(10, swapSection.y + 30, "Copy last section", function() {
      saveUndo(_song); // in case you copy from the wrong section and want to easily undo it
      var value:Int = Std.int(stepperCopy.value);
      if (value == 0) return;

      var daSec = FlxMath.maxInt(curSec, value);
      if (_song.notes[daSec - value] == null || _song.notes[daSec] == null) return;

      var srcSec:Int = daSec - value;
      var srcStart:Float = secStartAbs(srcSec);
      var srcEnd:Float = secStartAbs(srcSec + 1);
      var dstStart:Float = secStartAbs(daSec);
      var ratio:Float = secBPM(srcSec) / secBPM(daSec);

      if (check_notesSec.checked)
      {
        for (note in _song.notes[srcSec].sectionNotes)
        {
          var c:Array<Dynamic> = note.copy();
          c[0] = dstStart + (note[0] - srcStart) * ratio;
          if (c[2] != null) c[2] = note[2] * ratio;
          _song.notes[daSec].sectionNotes.push(c);
        }
      }

      if (check_eventsSec.checked)
      {
        var newEvents:Array<Dynamic> = []; // collect first so we don't iterate a list we're pushing into
        for (event in _song.events)
        {
          if (event[0] >= srcStart && event[0] < srcEnd)
          {
            var arr:Array<Dynamic> = [];
            for (e in cast(event[1], Array<Dynamic>)) arr.push([e[0], e[1], e[2]]);
            newEvents.push([dstStart + (event[0] - srcStart) * ratio, arr]);
          }
        }
        for (ev in newEvents) _song.events.push(ev);
      }
      updateGrid(false);
    });
    copyLastButton.setGraphicSize(80, 30);
    copyLastButton.updateHitbox();

    stepperCopy = new PsychUINumericStepper(copyLastButton.x + 100, copyLastButton.y, 1, 1, -999, 999, 0);
    blockPressWhileTypingOnStepper.push(stepperCopy);

    var duetButton:PsychUIButton = new PsychUIButton(10, copyLastButton.y + 45, "Duet Notes", function() {
      var duetNotes:Array<Array<Dynamic>> = [];
      for (note in _song.notes[curSec].sectionNotes)
      {
        var boob = note[1];
        if (boob > 3)
        {
          boob -= 4;
        } else
        {
          boob += 4;
        }

        var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
        duetNotes.push(copiedNote);
      }

      for (i in duetNotes)
      {
        _song.notes[curSec].sectionNotes.push(i);
      }

      updateGrid(false);
    });
    var mirrorButton:PsychUIButton = new PsychUIButton(duetButton.x + 100, duetButton.y, "Mirror Notes", function() {
      var duetNotes:Array<Array<Dynamic>> = [];
      for (note in _song.notes[curSec].sectionNotes)
      {
        var boob = note[1] % 4;
        boob = 3 - boob;
        if (note[1] > 3) boob += 4;

        note[1] = boob;
        var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
        // duetNotes.push(copiedNote);
      }

      updateGrid(false);
    });
    var clearLeftSectionButton:PsychUIButton = new PsychUIButton(duetButton.x, duetButton.y + 30, "Clear Left Side", function() {
      if (_song.notes[curSec] == null || _song.notes[curSec] != null && _song.notes[curSec].sectionNotes == null) return;
      saveUndo(_song); // this is really weird so im saving it as an undoable action just in case it does the wrong section
      var removeThese = [];
      for (noteIndex in 0..._song.notes[curSec].sectionNotes.length)
      {
        if (_song.notes[curSec].sectionNotes[noteIndex][1] < 4)
        {
          removeThese.push(_song.notes[curSec].sectionNotes[noteIndex]);
        }
      }
      if (removeThese != [])
      {
        for (x in removeThese)
        {
          _song.notes[curSec].sectionNotes.remove(x);
        }
      }

      updateGrid(false);
      updateNoteUI();
    });
    var clearRightSectionButton:PsychUIButton = new PsychUIButton(clearLeftSectionButton.x + 100, clearLeftSectionButton.y, "Clear Right Side", function() {
      if (_song.notes[curSec] == null || _song.notes[curSec] != null && _song.notes[curSec].sectionNotes == null) return;
      saveUndo(_song); // this is really weird so im saving it as an undoable action just in case it does the wrong section
      var removeThese = [];
      for (noteIndex in 0..._song.notes[curSec].sectionNotes.length)
      {
        if (_song.notes[curSec].sectionNotes[noteIndex][1] >= 4)
        {
          removeThese.push(_song.notes[curSec].sectionNotes[noteIndex]);
        }
      }
      if (removeThese != [])
      {
        for (x in removeThese)
        {
          _song.notes[curSec].sectionNotes.remove(x);
        }
      }

      updateGrid(false);
      updateNoteUI();
    });
    clearLeftSectionButton.normalStyle.bgColor = 0xFF210707;
    clearLeftSectionButton.normalStyle.textColor = FlxColor.WHITE;
    clearRightSectionButton.normalStyle.bgColor = 0xFF210707;
    clearRightSectionButton.normalStyle.textColor = FlxColor.WHITE;

    var stepperSectionJump:PsychUINumericStepper = new PsychUINumericStepper(clearSectionButton.x, clearSectionButton.y + 30, 1, 0, 0, 999999, 0);
    blockPressWhileTypingOnStepper.push(stepperSectionJump);

    var jumpSection:PsychUIButton = new PsychUIButton(clearSectionButton.x, stepperSectionJump.y + 20, "Jump Section", function() {
      var value:Int = Std.int(stepperSectionJump.value);
      changeSection(value);
    });

    var CopyNextSectionCount:PsychUINumericStepper = new PsychUINumericStepper(jumpSection.x, jumpSection.y + 60, 1, 1, -16384, 16384, 0);
    blockPressWhileTypingOnStepper.push(CopyNextSectionCount);

    CopyLastSectionCount = new PsychUINumericStepper(CopyNextSectionCount.x + 100, CopyNextSectionCount.y, 1, 1, -16384, 16384, 0);
    blockPressWhileTypingOnStepper.push(CopyLastSectionCount);

    CopyFutureSectionCount = new PsychUINumericStepper(CopyLastSectionCount.x + 70, CopyLastSectionCount.y, 1, 1, -16384, 16384, 0);
    blockPressWhileTypingOnStepper.push(CopyFutureSectionCount);

    CopyLoopCount = new PsychUINumericStepper(CopyFutureSectionCount.x - 60, CopyLastSectionCount.y + 40, 1, 1, -16384, 16384, 0);
    blockPressWhileTypingOnStepper.push(CopyLoopCount);

    copyMultiSectButton = new PsychUIButton(CopyFutureSectionCount.x, CopyLastSectionCount.y + 40,
    "Copy from the last " + Std.int(CopyLastSectionCount.value)
    + " to the next " + Std.int(CopyFutureSectionCount.value)
    + " sections, " + Std.int(CopyLoopCount.value) + " times",
    function() {
      var swapNotes:Bool = FlxG.keys.pressed.CONTROL;
      var value1:Int = Std.int(CopyLastSectionCount.value);
      var value2:Int = Std.int(CopyFutureSectionCount.value) * Std.int(CopyLoopCount.value);
      if (value1 == 0 || !check_notesSec.checked) return;

      saveUndo(_song);

      for (i in 0...value2)
      {
        // Source/destination are always relative to the section we're currently in
        var srcSec:Int = curSec - value1;
        if (srcSec < 0 || _song.notes[srcSec] == null)
        {
          trace("The section obtained from value 1 would cause the game to copy notes from a section that doesn't exist.");
          break;
        }

        var srcStart:Float = secStartAbs(srcSec);
        var dstStart:Float = secStartAbs(curSec);
        var ratio:Float = secBPM(srcSec) / secBPM(curSec);

        for (note in _song.notes[srcSec].sectionNotes)
        {
          var data = note[1];
          if (swapNotes) data = Std.int(note[1] + 4) % 8;
          var sus:Dynamic = (note[2] != null) ? note[2] * ratio : note[2];
          _song.notes[curSec].sectionNotes.push([dstStart + (note[0] - srcStart) * ratio, data, sus, note[3], note[4]]);
        }

        if (sectionStartTime(1) > FlxG.sound.music.length)
        {
          trace('Last possible section reached!');
          break;
        }
        if (_song.notes[curSec + 1] == null)
        {
          addSection(getSectionBeats());
        }
        changeSection(curSec + 1, true, false);

        // Feel free to comment this out.
        trace('Loops Remaining: ' + (value2 - i) + ', current note count: '
          + FlxStringUtil.formatMoney(CoolUtil.getNoteAmount(_song), false) + ' Notes');
      }
      changeSection(curSec); //refresh the grid
    });
    copyMultiSectButton.color = FlxColor.BLUE;
    copyMultiSectButton.normalStyle.textColor = FlxColor.WHITE;
    copyMultiSectButton.setGraphicSize(Std.int(copyMultiSectButton.width), Std.int(copyMultiSectButton.height));
    copyMultiSectButton.updateHitbox();

    var copyNextButton:PsychUIButton = new PsychUIButton(CopyNextSectionCount.x, CopyNextSectionCount.y + 20, "Copy to the next..", function() {
      var swapNotes:Bool = FlxG.keys.pressed.CONTROL;
      var value:Int = Std.int(CopyNextSectionCount.value);
      if (value == 0)
      {
        return;
      }
      if (_song.notes[curSec] == null
        || _song.notes[curSec] != null
        && _song.notes[curSec].sectionNotes.length < 1
        || Math.isNaN(_song.notes[curSec].sectionNotes.length)
        || _song.notes[curSec].sectionNotes == null)
      {
        trace("HEY! your section doesn't have any notes! please place at least 1 note then try using this.");
        return; // prevent a crash if the section doesn't have any notes
      }
      saveUndo(_song); // I don't even know why.

      for (i in 0...value)
      {
        if (sectionStartTime(1) > FlxG.sound.music.length)
        {
          trace('Last possible section reached!');
          break;
        }
        if (_song.notes[curSec + 1] == null) addSection(getSectionBeats());
        changeSection(curSec + 1);
        var srcSec:Int = curSec - 1;
        var srcStart:Float = secStartAbs(srcSec);
        var dstStart:Float = secStartAbs(curSec);
        var ratio:Float = secBPM(srcSec) / secBPM(curSec);

        for (note in _song.notes[srcSec].sectionNotes)
        {
          var data = note[1];
          if (swapNotes) data = Std.int(note[1] + 4) % 8;
          var sus:Dynamic = (note[2] != null) ? note[2] * ratio : note[2];
          _song.notes[curSec].sectionNotes.push([dstStart + (note[0] - srcStart) * ratio, data, sus, note[3], note[4]]);
        }
      }
      updateGrid(false);
    });
    copyNextButton.color = FlxColor.CYAN;
    copyNextButton.normalStyle.textColor = FlxColor.WHITE;

    deleteSecStart = new PsychUINumericStepper(copyMultiSectButton.x + 80, CopyLastSectionCount.y, 1, 1, -16384, 16384, 0);
    blockPressWhileTypingOnStepper.push(deleteSecStart);

    deleteSecEnd = new PsychUINumericStepper(deleteSecStart.x + 60, CopyLastSectionCount.y, 1, 1, -16384, 16384, 0);
    blockPressWhileTypingOnStepper.push(deleteSecEnd);

    deleteSections = new PsychUIButton(deleteSecStart.x
      + 30, CopyLastSectionCount.y
      + 40,
      "Delete sections "
      + Std.int(deleteSecStart.value)
      + " to "
      + Std.int(deleteSecEnd.value), function() {
        var startSec:Int = Std.int(deleteSecStart.value);
        var endSec:Int = Std.int(deleteSecEnd.value);
        var sectionsToDelete:Int = endSec - startSec;
        if (sectionsToDelete < 0)
        {
          return;
        }
        saveUndo(_song); // I don't even know why.

        var deleteBfNotes:Bool = FlxG.keys.pressed.SHIFT;
        var deleteOppNotes:Bool = FlxG.keys.pressed.CONTROL;

        for (i in 0...sectionsToDelete)
        {
          if (_song.notes[startSec + i] != null
            && _song.notes[startSec + i].sectionNotes != null) if (!deleteBfNotes && !deleteOppNotes) _song.notes[startSec + i].sectionNotes = [];
            else
            {
              var b = _song.notes[startSec + i].sectionNotes.length - 1;
              while (b >= 0)
              {
                var note = _song.notes[startSec + i].sectionNotes[b];
                if (note != null
                  && deleteBfNotes
                  && (note[1] < 4 ? _song.notes[startSec + i].mustHitSection : !_song.notes[startSec + i].mustHitSection))
                  _song.notes[startSec + i].sectionNotes.remove(note);
                if (note != null
                  && deleteOppNotes
                  && (note[1] < 4 ? !_song.notes[startSec + i].mustHitSection : _song.notes[startSec + i].mustHitSection))
                  _song.notes[startSec + i].sectionNotes.remove(note);
                b--;
              }
            }
        }
    });
    deleteSections.normalStyle.bgColor = FlxColor.YELLOW;
    deleteSections.normalStyle.textColor = FlxColor.WHITE;

    tab_group_section.add(stepperSectionJump);
    tab_group_section.add(jumpSection);
    tab_group_section.add(new FlxText(stepperBeats.x, stepperBeats.y - 15, 0, 'Beats per Section:'));
    tab_group_section.add(stepperBeats);
    tab_group_section.add(stepperSectionBPM);
    tab_group_section.add(check_mustHitSection);
    tab_group_section.add(check_gfSection);
    tab_group_section.add(check_altAnim);
    tab_group_section.add(check_crossFade);
    tab_group_section.add(check_changeBPM);
    tab_group_section.add(copyButton);
    tab_group_section.add(pasteButton);
    tab_group_section.add(clearRightSectionButton);
    tab_group_section.add(clearLeftSectionButton);
    tab_group_section.add(copyNextButton);
    tab_group_section.add(CopyNextSectionCount);
    tab_group_section.add(CopyLastSectionCount);
    tab_group_section.add(CopyFutureSectionCount);
    tab_group_section.add(CopyLoopCount);
    tab_group_section.add(deleteSecStart);
    tab_group_section.add(deleteSecEnd);
    tab_group_section.add(clearSectionButton);
    tab_group_section.add(check_notesSec);
    tab_group_section.add(check_eventsSec);
    tab_group_section.add(swapSection);
    tab_group_section.add(stepperCopy);
    tab_group_section.add(copyLastButton);
    tab_group_section.add(duetButton);
    tab_group_section.add(mirrorButton);
    tab_group_section.add(copyMultiSectButton);
    tab_group_section.add(deleteSections);
  }

  var stepperSusLength:PsychUINumericStepper;
  var strumTimeInputText:PsychUIInputText; // I wanted to use a stepper but we can't scale these as far as i know :(
  var noteTypeDropDown:PsychUIDropDownMenu;
  var currentType:Int = 0;

  function addNoteUI():Void
  {
	final tab_group_note = UI_box.getTab('Note').menu;

    stepperSusLength = new PsychUINumericStepper(10, 25, 0.5, 0, 0, 1024, 3);
    stepperSusLength.value = 0;
    stepperSusLength.name = 'note_susLength';
    blockPressWhileTypingOnStepper.push(stepperSusLength);

    strumTimeInputText = new PsychUIInputText(10, 65, 180, "0");
    tab_group_note.add(strumTimeInputText);
    blockPressWhileTypingOn.push(strumTimeInputText);

    var key:Int = 0;
    var displayNameList:Array<String> = [];
    while (key < noteTypeList.length)
    {
      displayNameList.push(noteTypeList[key]);
      noteTypeMap.set(noteTypeList[key], key);
      noteTypeIntMap.set(key, noteTypeList[key]);
      key++;
    }
    var notetypeFiles:Array<String> = Mods.mergeAllTextsNamed('data/' + Paths.formatToSongPath(_song.song) + '/notetypes.txt', '', true);
    if (notetypeFiles.length > 0)
    {
      for (ntTyp in notetypeFiles)
      {
        var name:String = ntTyp.trim();
        if (!displayNameList.contains(name))
        {
          displayNameList.push(name);
          noteTypeMap.set(name, key);
          noteTypeIntMap.set(key, name);
          key++;
        }
      }
    }

    #if LUA_ALLOWED
    var directories:Array<String> = [];

    #if MODS_ALLOWED
    directories.push(Paths.mods('custom_notetypes/'));
    directories.push(Paths.mods(Mods.currentModDirectory + '/custom_notetypes/'));
    for (mod in Mods.getGlobalMods())
      directories.push(Paths.mods(mod + '/custom_notetypes/'));
    #end

    for (i in 0...directories.length)
    {
      var directory:String = directories[i];
      if (FileSystem.exists(directory))
      {
        for (file in FileSystem.readDirectory(directory))
        {
          var path = haxe.io.Path.join([directory, file]);
          if (!FileSystem.isDirectory(path) && file.endsWith('.lua'))
          {
            var fileToCheck:String = file.substr(0, file.length - 4);
            if (!noteTypeMap.exists(fileToCheck))
            {
              displayNameList.push(fileToCheck);
              noteTypeMap.set(fileToCheck, key);
              noteTypeIntMap.set(key, fileToCheck);
              key++;
            }
          }
        }
      }
    }
    #end

    for (i in 1...displayNameList.length)
    {
      displayNameList[i] = i + '. ' + displayNameList[i];
    }

	noteTypeDropDown = new PsychUIDropDownMenu(10, 105, displayNameList, function(id:Int, character:String)
	{
      currentType = Std.parseInt(character);
      if (curSelectedNote != null && curSelectedNote[1] > -1)
      {
        curSelectedNote[3] = noteTypeIntMap.get(currentType);
        updateGrid(false);
      }
	});
	blockPressWhileScrolling.push(noteTypeDropDown);

    var leftSectionNotetype:PsychUIButton = new PsychUIButton(noteTypeDropDown.x, noteTypeDropDown.y + 40, "Left Side to Notetype", function() {
      for (i in 0..._song.notes[curSec].sectionNotes.length)
      {
        var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
        if (note[1] < 4)
        {
          note[3] = noteTypeIntMap.get(currentType);
        }
        _song.notes[curSec].sectionNotes[i] = note;
      }
      updateGrid(false);
    });
    var rightSectionNotetype:PsychUIButton = new PsychUIButton(leftSectionNotetype.x + 90, leftSectionNotetype.y, "Right Side to Notetype", function() {
      for (i in 0..._song.notes[curSec].sectionNotes.length)
      {
        var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
        if (note[1] > 3)
        {
          note[3] = noteTypeIntMap.get(currentType);
        }
        _song.notes[curSec].sectionNotes[i] = note;
      }
      updateGrid(false);
    });

    tab_group_note.add(new FlxText(10, 10, 0, 'Sustain length (in steps):'));
    tab_group_note.add(new FlxText(10, 50, 0, 'Strum time (in miliseconds):'));
    tab_group_note.add(new FlxText(10, 90, 0, 'Note type:'));
    tab_group_note.add(leftSectionNotetype);
    tab_group_note.add(rightSectionNotetype);
    tab_group_note.add(stepperSusLength);
    tab_group_note.add(strumTimeInputText);
    tab_group_note.add(noteTypeDropDown);
  }

  var check_stackActive:PsychUICheckBox;
  var stepperStackNum:PsychUINumericStepper;
  var stepperStackOffset:PsychUINumericStepper;
  var stepperStackSideOffset:PsychUINumericStepper;
  var stepperShrinkAmount:PsychUINumericStepper;

  function addNoteStackingUI():Void
  {
    final tab_group_stacking = UI_box.getTab('Note Spamming').menu;

    check_stackActive = new PsychUICheckBox(10, 10, "Enable EZ Spam Mode", 100);
    check_stackActive.name = 'check_stackActive';

    stepperStackNum = new PsychUINumericStepper(10, 30, 1, 1, 0, 999999, 4);
    stepperStackNum.name = 'stack_count';
    blockPressWhileTypingOnStepper.push(stepperStackNum);

    var doubleSpamNum:PsychUIButton = new PsychUIButton(stepperStackNum.x, stepperStackNum.y + 20, 'x2 Amount', function() {
      stepperStackNum.value *= 2;
    });
    doubleSpamNum.setGraphicSize(Std.int(doubleSpamNum.width), Std.int(doubleSpamNum.height));
    doubleSpamNum.color = FlxColor.GREEN;
    doubleSpamNum.normalStyle.textColor = FlxColor.WHITE;

    var halfSpamNum:PsychUIButton = new PsychUIButton(doubleSpamNum.x + doubleSpamNum.width + 20, doubleSpamNum.y, 'x0.5 Amount', function() {
      stepperStackNum.value /= 2;
    });
    halfSpamNum.setGraphicSize(Std.int(halfSpamNum.width), Std.int(halfSpamNum.height));
    halfSpamNum.normalStyle.bgColor = 0xFF210707;
    halfSpamNum.normalStyle.textColor = FlxColor.WHITE;

    stepperStackOffset = new PsychUINumericStepper(10, 80, 1, 1, 0, 999999, 4);
    stepperStackOffset.name = 'stack_offset';
    blockPressWhileTypingOnStepper.push(stepperStackOffset);

    var doubleSpamMult:PsychUIButton = new PsychUIButton(stepperStackOffset.x, stepperStackOffset.y + 20, 'x2 SM', function() {
      stepperStackOffset.value *= 2;
    });
    doubleSpamMult.color = FlxColor.GREEN;
    doubleSpamMult.normalStyle.textColor = FlxColor.WHITE;

    var halfSpamMult:PsychUIButton = new PsychUIButton(doubleSpamMult.x + doubleSpamMult.width + 20, doubleSpamMult.y, 'x0.5 SM', function() {
      stepperStackOffset.value /= 2;
    });
    halfSpamMult.setGraphicSize(Std.int(halfSpamMult.width), Std.int(halfSpamMult.height));
    halfSpamMult.normalStyle.bgColor = 0xFF210707;
    halfSpamMult.normalStyle.textColor = FlxColor.WHITE;

    stepperStackSideOffset = new PsychUINumericStepper(10, 140, 1, 0, -9999, 9999);
    stepperStackSideOffset.name = 'stack_sideways';
    blockPressWhileTypingOnStepper.push(stepperStackSideOffset);

    stepperShrinkAmount = new PsychUINumericStepper(10, stepperStackSideOffset.y + 30, 1, 1, 0, 8192, 4);
    stepperShrinkAmount.name = 'shrinker_amount';
    blockPressWhileTypingOnStepper.push(stepperShrinkAmount);

    var doubleShrinker:PsychUIButton = new PsychUIButton(stepperShrinkAmount.x, stepperShrinkAmount.y + 20, 'x2 SH', function() {
      stepperShrinkAmount.value *= 2;
    });
    doubleShrinker.color = FlxColor.GREEN;
    doubleShrinker.normalStyle.textColor = FlxColor.WHITE;

    var halfShrinker:PsychUIButton = new PsychUIButton(doubleShrinker.x + doubleShrinker.width + 20, doubleShrinker.y, 'x0.5 SH', function() {
      stepperShrinkAmount.value /= 2;
    });
    halfShrinker.setGraphicSize(Std.int(halfShrinker.width), Std.int(halfShrinker.height));
    halfShrinker.normalStyle.bgColor = 0xFF210707;
    halfShrinker.normalStyle.textColor = FlxColor.WHITE;

    var shrinkNotesButton:PsychUIButton = new PsychUIButton(10, doubleShrinker.y + 30, "Stretch Notes", function() {
      var minimumTime:Float = sectionStartTime();
      var sectionEndTime:Float = sectionStartTime(1);
      for (i in 0..._song.notes[curSec].sectionNotes.length)
      {
        var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
        if (note[2] > 0) note[2] *= stepperShrinkAmount.value;
        var originalStartTime:Float = note[0]; // Original start time (in seconds)
        originalStartTime = originalStartTime - sectionStartTime();

        var stretchedStartTime:Float = originalStartTime * stepperShrinkAmount.value;

        var newStartTime:Float = sectionStartTime() + stretchedStartTime;

        note[0] = Math.max(newStartTime, minimumTime);
        if (note[0] < minimumTime) note[0] = minimumTime;
        _song.notes[curSec].sectionNotes[i] = note;
      }
      updateGrid(false);
    });

    var stepperShiftSteps:PsychUINumericStepper = new PsychUINumericStepper(10, shrinkNotesButton.y + 30, 1, 1, -8192, 8192, 4);
    stepperShiftSteps.name = 'shifter_amount';
    blockPressWhileTypingOnStepper.push(stepperShiftSteps);

    var shiftNotesButton:PsychUIButton = new PsychUIButton(10, stepperShiftSteps.y + 20, "Shift Notes", function() {
      for (i in 0..._song.notes[curSec].sectionNotes.length)
      {
        _song.notes[curSec].sectionNotes[i][0] += (stepperShiftSteps.value) * (15000 / secBPM(curSec));
      }
      updateGrid(false);
    });
    shiftNotesButton.setGraphicSize(Std.int(shiftNotesButton.width), Std.int(shiftNotesButton.height));

    // ok im adding way too many spamcharting features LOL

    var stepperDuplicateAmount:PsychUINumericStepper = new PsychUINumericStepper(10, shiftNotesButton.y + 30, 1, 1, 0, 32, 4);
    stepperDuplicateAmount.name = 'duplicater_amount';
    blockPressWhileTypingOnStepper.push(stepperDuplicateAmount);

    var dupeNotesButton:PsychUIButton = new PsychUIButton(10, stepperDuplicateAmount.y + 20, "Duplicate Notes", function() {
      var copiedNotes:Array<Dynamic> = [];
      for (i in 0..._song.notes[curSec].sectionNotes.length)
      {
        var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
        copiedNotes.push(note);
      }
      for (_i in 1...Std.int(stepperDuplicateAmount.value) + 1)
      {
        for (i in 0...copiedNotes.length)
        {
          final copiedNote:Array<Dynamic> = [copiedNotes[i][0], copiedNotes[i][1], copiedNotes[i][2], copiedNotes[i][3]];
          copiedNote[0] += (stepperShiftSteps.value * _i) * (15000 / secBPM(curSec));
          // yeah.. unfortunately this relies on the value of the Shift Notes stepper.. stupid but it works, so im gonna keep it this way until i find a better solution
          _song.notes[curSec].sectionNotes.push(copiedNote);
        }
      }
      _song.notes[curSec].sectionNotes.length <= 30000 ? updateGrid(false) : changeSection(curSec +
        1); // if there's now more than 30,000 notes in the same section then uh.. change to the next section so you don't suffer a crash
    });
    dupeNotesButton.setGraphicSize(Std.int(dupeNotesButton.width), Std.int(dupeNotesButton.height));

    tab_group_stacking.add(check_stackActive);
    tab_group_stacking.add(stepperStackNum);
    tab_group_stacking.add(stepperStackOffset);
    tab_group_stacking.add(stepperStackSideOffset);
    tab_group_stacking.add(stepperShrinkAmount);
    tab_group_stacking.add(stepperShiftSteps);
    tab_group_stacking.add(stepperDuplicateAmount);
    tab_group_stacking.add(doubleSpamNum);
    tab_group_stacking.add(halfSpamNum);
    tab_group_stacking.add(doubleSpamMult);
    tab_group_stacking.add(halfSpamMult);
    tab_group_stacking.add(doubleShrinker);
    tab_group_stacking.add(halfShrinker);
    tab_group_stacking.add(shrinkNotesButton);
    tab_group_stacking.add(shiftNotesButton);
    tab_group_stacking.add(dupeNotesButton);

    tab_group_stacking.add(new FlxText(100, 30, 0, "Spam Count"));
    tab_group_stacking.add(new FlxText(100, 80, 0, "Spam Multiplier"));
    tab_group_stacking.add(new FlxText(100, 140, 0, "Spam Scroll Amount"));
    tab_group_stacking.add(new FlxText(100, stepperShrinkAmount.y, 0, "Stretch Amount"));
    tab_group_stacking.add(new FlxText(100, stepperShiftSteps.y, 0, "Steps to Shift By"));
    tab_group_stacking.add(new FlxText(100, stepperDuplicateAmount.y, 0, "Amount of Duplicates"));
  }

  var eventDropDown:PsychUIDropDownMenu;
  var descText:FlxText;
  var selectedEventText:FlxText;
  var event7DropDown:PsychUIDropDownMenu;
  var event7InputText:PsychUIInputText;

  function addEventsUI():Void
  {
	final tab_group_event = UI_box.getTab('Events').menu;

    #if LUA_ALLOWED
    var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
    var directories:Array<String> = [];

    #if MODS_ALLOWED
    directories.push(Paths.mods('custom_events/'));
    directories.push(Paths.mods(Mods.currentModDirectory + '/custom_events/'));
    for (mod in Mods.getGlobalMods())
      directories.push(Paths.mods(mod + '/custom_events/'));
    #end

    for (i in 0...directories.length)
    {
      var directory:String = directories[i];
      if (FileSystem.exists(directory))
      {
        for (file in FileSystem.readDirectory(directory))
        {
          var path = haxe.io.Path.join([directory, file]);
          if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt'))
          {
            var fileToCheck:String = file.substr(0, file.length - 4);
            if (!eventPushedMap.exists(fileToCheck))
            {
              eventPushedMap.set(fileToCheck, true);
              eventStuff.push([fileToCheck, File.getContent(path)]);
            }
          }
        }
      }
    }
    eventPushedMap.clear();
    eventPushedMap = null;
    #end

    descText = new FlxText(20, 200, 0, eventStuff[0][0]);

    var leEvents:Array<String> = [];
    for (i in 0...eventStuff.length)
    {
      leEvents.push(eventStuff[i][0]);
    }

    var text:FlxText = new FlxText(20, 30, 0, "Event:");
    tab_group_event.add(text);
	eventDropDown = new PsychUIDropDownMenu(20, 50, leEvents, function(id:Int, pressed:String) {
		var selectedEvent:Int = id;
		descText.text = eventStuff[selectedEvent][1];
			if (curSelectedNote != null && eventStuff != null) {
			if (curSelectedNote != null && curSelectedNote[2] == null){
			curSelectedNote[1][curEventSelected][0] = eventStuff[selectedEvent][0];

			}
			updateGrid();
		}
	});
	blockPressWhileScrolling.push(eventDropDown);

    var text:FlxText = new FlxText(20, 90, 0, "Value 1:");
    tab_group_event.add(text);
    value1InputText = new PsychUIInputText(20, 110, 100, "");
    blockPressWhileTypingOn.push(value1InputText);

    var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
    tab_group_event.add(text);
    value2InputText = new PsychUIInputText(20, 150, 100, "");
    blockPressWhileTypingOn.push(value2InputText);

    var pressing7Events:Array<String> = ['---', 'None', 'Game Over', 'Go to Song', 'Close Game', 'Play Video'];

    event7DropDown = new PsychUIDropDownMenu(160, 300, pressing7Events, function(id:Int, pressed:String) {
      trace('event pressed 1');
      var arraySelectedShit:String = pressing7Events[id];
      _song.event7 = arraySelectedShit;
    });
    event7DropDown.selectedLabel = _song.event7;
    var text:FlxText = new FlxText(160, 280, 0, "7 Event:");
    tab_group_event.add(text);

    // New event buttons
    var removeButton:PsychUIButton = new PsychUIButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function() {
      if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
      {
        if (curSelectedNote[1].length < 2)
        {
          _song.events.remove(curSelectedNote);
          curSelectedNote = null;
        } else
        {
          curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
        }

        var eventsGroup:Array<Dynamic>;
        --curEventSelected;
        if (curEventSelected < 0) curEventSelected = 0;
        else if (curSelectedNote != null
          && curEventSelected >= (eventsGroup = curSelectedNote[1]).length) curEventSelected = eventsGroup.length - 1;

        changeEventSelected();
        updateGrid();
      }
    });
    removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
    removeButton.updateHitbox();
    removeButton.normalStyle.bgColor = 0xFF210707;
    removeButton.normalStyle.textColor = FlxColor.WHITE;
    removeButton.text.size = 12;
    setAllLabelsOffset(removeButton, -30, 0);
    tab_group_event.add(removeButton);

    var addButton:PsychUIButton = new PsychUIButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function() {
      if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
      {
        var eventsGroup:Array<Dynamic> = curSelectedNote[1];
        eventsGroup.push(['', '', '']);

        changeEventSelected(1);
        updateGrid();
      }
    });
    addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
    addButton.updateHitbox();
    addButton.color = FlxColor.GREEN;
    addButton.normalStyle.textColor = FlxColor.WHITE;
    addButton.text.size = 12;
    setAllLabelsOffset(addButton, -30, 0);
    tab_group_event.add(addButton);

    var moveLeftButton:PsychUIButton = new PsychUIButton(addButton.x + addButton.width + 20, addButton.y, '<', function() {
      changeEventSelected(-1);
    });
    moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
    moveLeftButton.updateHitbox();
    moveLeftButton.text.size = 12;
    setAllLabelsOffset(moveLeftButton, -30, 0);
    tab_group_event.add(moveLeftButton);

    var moveRightButton:PsychUIButton = new PsychUIButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', function() {
      changeEventSelected(1);
    });
    moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
    moveRightButton.updateHitbox();
    moveRightButton.text.size = 12;
    setAllLabelsOffset(moveRightButton, -30, 0);
    tab_group_event.add(moveRightButton);

    selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
    selectedEventText.alignment = CENTER;
    tab_group_event.add(selectedEventText);

    event7InputText = new PsychUIInputText(160, event7DropDown.y + 40, 100, _song.event7Value);
    blockPressWhileTypingOn.push(event7InputText);
    blockPressWhileScrolling.push(event7DropDown);

    tab_group_event.add(event7DropDown);
    tab_group_event.add(event7InputText);
    tab_group_event.add(descText);
    tab_group_event.add(value1InputText);
    tab_group_event.add(value2InputText);
    tab_group_event.add(eventDropDown);
  }

  function changeEventSelected(change:Int = 0)
  {
    if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
    {
      curEventSelected += change;
      if (curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
      else if (curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
      selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
    } else
    {
      curEventSelected = 0;
      selectedEventText.text = 'Selected Event: None';
    }
    updateNoteUI();
  }

	function setAllLabelsOffset(button:PsychUIButton, x:Float, y:Float)
	{
		if (button.text != null)
		{
			button.text.x = button.bg.x + x;
			button.text.y = button.bg.y + y;
		}
	}

  var metronome:PsychUICheckBox;
  var metronomeStepper:PsychUINumericStepper;
  var metronomeOffsetStepper:PsychUINumericStepper;
  var mouseScrollingQuant:PsychUICheckBox;
  var disableAutoScrolling:PsychUICheckBox;
  var lilBuddiesBox:PsychUICheckBox;
  var saveUndoCheck:PsychUICheckBox;
  var soundEffectsCheck:PsychUICheckBox;
  var idleMusicCheck:PsychUICheckBox;
  var instVolume:PsychUINumericStepper;
  var voicesVolume:PsychUINumericStepper;
  var voicesOppVolume:PsychUINumericStepper;
  var hitsoundVolume:PsychUINumericStepper;

  function addChartingUI()
  {
	final tab_group_chart = UI_box.getTab('Charting').menu;

    #if desktop
    if (FlxG.save.data.chart_waveformInst == null) FlxG.save.data.chart_waveformInst = false;
    if (FlxG.save.data.chart_waveformVoices == null) FlxG.save.data.chart_waveformVoices = false;
    if (FlxG.save.data.chart_waveformOppVoices == null) FlxG.save.data.chart_waveformOppVoices = false;

    var waveformUseInstrumental:PsychUICheckBox = null;
    var waveformUseVoices:PsychUICheckBox = null;
    var waveformUseOppVoices:PsychUICheckBox = null;

    waveformUseInstrumental = new PsychUICheckBox(10, 90, "Waveform\n(Instrumental)", 85);
    waveformUseInstrumental.checked = FlxG.save.data.chart_waveformInst;
    waveformUseInstrumental.onClick = function() {
      waveformUseVoices.checked = false;
      waveformUseOppVoices.checked = false;
      FlxG.save.data.chart_waveformVoices = false;
      FlxG.save.data.chart_waveformOppVoices = false;
      FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked;
      updateWaveform();
    };

    waveformUseVoices = new PsychUICheckBox(waveformUseInstrumental.x + 100, waveformUseInstrumental.y, "Waveform\n(Main Vocals)", 85);
    waveformUseVoices.checked = FlxG.save.data.chart_waveformVoices && !waveformUseInstrumental.checked;
    waveformUseVoices.onClick = function() {
      waveformUseInstrumental.checked = false;
      waveformUseOppVoices.checked = false;
      FlxG.save.data.chart_waveformInst = false;
      FlxG.save.data.chart_waveformOppVoices = false;
      FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked;
      updateWaveform();
    };

    waveformUseOppVoices = new PsychUICheckBox(waveformUseInstrumental.x + 200, waveformUseInstrumental.y, "Waveform\n(Opp. Vocals)", 85);
    waveformUseOppVoices.checked = FlxG.save.data.chart_waveformOppVoices && !waveformUseVoices.checked;
    waveformUseOppVoices.onClick = function() {
      waveformUseInstrumental.checked = false;
      waveformUseVoices.checked = false;
      FlxG.save.data.chart_waveformInst = false;
      FlxG.save.data.chart_waveformVoices = false;
      FlxG.save.data.chart_waveformOppVoices = waveformUseOppVoices.checked;
      updateWaveform();
    };
    #end

    check_mute_inst = new PsychUICheckBox(10, 280, "Mute Instrumental (in editor)", 100);
    check_mute_inst.checked = false;
    check_mute_inst.onClick = function() {
      var vol:Float = instVolume.value;
      if (check_mute_inst.checked) vol = 0;

      FlxG.sound.music.volume = vol;
    };
    mouseScrollingQuant = new PsychUICheckBox(10, 180, "Mouse Scrolling Quantization", 100);
    if (FlxG.save.data.mouseScrollingQuant == null) FlxG.save.data.mouseScrollingQuant = false;
    mouseScrollingQuant.checked = FlxG.save.data.mouseScrollingQuant;

    mouseScrollingQuant.onClick = function() {
      FlxG.save.data.mouseScrollingQuant = mouseScrollingQuant.checked;
      mouseQuant = FlxG.save.data.mouseScrollingQuant;
    };

    lilBuddiesBox = new PsychUICheckBox(mouseScrollingQuant.x + 150, mouseScrollingQuant.y, "Lil' Buddies", 100);
    if (FlxG.save.data.lilBuddies == null) FlxG.save.data.lilBuddies = false;
    lilBuddiesBox.checked = FlxG.save.data.lilBuddies;
    lilBuddiesBox.onClick = function() {
      FlxG.save.data.lilBuddies = lilBuddiesBox.checked;
      lilBf.visible = lilBuddiesBox.checked;
      lilOpp.visible = lilBuddiesBox.checked;
      lilStage.visible = lilBuddiesBox.checked;
    };

    saveUndoCheck = new PsychUICheckBox(mouseScrollingQuant.x + 150, mouseScrollingQuant.y + 25, "Save Undos", 100);
    if (FlxG.save.data.allowUndo == null) FlxG.save.data.allowUndo = true;
    saveUndoCheck.checked = FlxG.save.data.allowUndo;
    saveUndoCheck.onClick = function() {
      FlxG.save.data.allowUndo = saveUndoCheck.checked;
    };

    check_vortex = new PsychUICheckBox(10, 140, "Vortex Editor (BETA)", 100);
    if (FlxG.save.data.chart_vortex == null) FlxG.save.data.chart_vortex = false;
    check_vortex.checked = FlxG.save.data.chart_vortex;

    check_vortex.onClick = function() {
      FlxG.save.data.chart_vortex = check_vortex.checked;
      vortex = FlxG.save.data.chart_vortex;
      reloadGridLayer();
    };

    check_showGrid = new PsychUICheckBox(10, 205, "Show Grid", 100);
    if (FlxG.save.data.showGrid == null) FlxG.save.data.showGrid = false;
    check_showGrid.checked = FlxG.save.data.showGrid;

    check_showGrid.onClick = function() {
      FlxG.save.data.showGrid = check_showGrid.checked;
      showTheGrid = FlxG.save.data.showGrid;
      reloadGridLayer();
    };

    check_warnings = new PsychUICheckBox(10, 120, "Ignore Progress Warnings", 100);
    if (FlxG.save.data.ignoreWarnings == null) FlxG.save.data.ignoreWarnings = false;
    check_warnings.checked = FlxG.save.data.ignoreWarnings;

    check_warnings.onClick = function() {
      FlxG.save.data.ignoreWarnings = check_warnings.checked;
      ignoreWarnings = FlxG.save.data.ignoreWarnings;
    };

    check_mute_vocals = new PsychUICheckBox(check_mute_inst.x, check_mute_inst.y + 30, "Mute Main Vocals (in editor)", 100);
    check_mute_vocals.checked = false;
    check_mute_vocals.onClick = function() {
      var vol:Float = voicesVolume.value;
      if (check_mute_vocals.checked) vol = 0;

      if (vocals != null) vocals.volume = vol;
    };
    check_mute_vocals_opponent = new PsychUICheckBox(check_mute_vocals.x + 120, check_mute_vocals.y, "Mute Opp. Vocals (in editor)", 100);
    check_mute_vocals_opponent.checked = false;
    check_mute_vocals_opponent.onClick = function() {
      var vol:Float = voicesOppVolume.value;
      if (check_mute_vocals_opponent.checked) vol = 0;

      if (opponentVocals != null) opponentVocals.volume = vol;
    };

    playSoundBf = new PsychUICheckBox(check_mute_inst.x, check_mute_vocals.y + 30, 'Play Sound (Boyfriend notes)', 100, function() {
      FlxG.save.data.chart_playSoundBf = playSoundBf.checked;
    });
    if (FlxG.save.data.chart_playSoundBf == null) FlxG.save.data.chart_playSoundBf = false;
    playSoundBf.checked = FlxG.save.data.chart_playSoundBf;

    playSoundDad = new PsychUICheckBox(check_mute_inst.x + 120, playSoundBf.y, 'Play Sound (Opponent notes)', 100, function() {
      FlxG.save.data.chart_playSoundDad = playSoundDad.checked;
    });
    if (FlxG.save.data.chart_playSoundDad == null) FlxG.save.data.chart_playSoundDad = false;
    playSoundDad.checked = FlxG.save.data.chart_playSoundDad;

    metronome = new PsychUICheckBox(10, 15, "Metronome Enabled", 100, function() {
      FlxG.save.data.chart_metronome = metronome.checked;
    });
	if (FlxG.save.data.chart_metronome == null) FlxG.save.data.chart_metronome = false;
	metronome.checked = FlxG.save.data.chart_metronome;

	metronomeStepper = new PsychUINumericStepper(12, 55, 5, _song.bpm, 1, 1500, 1);
	metronomeOffsetStepper = new PsychUINumericStepper(metronomeStepper.x + 68, metronomeStepper.y, 25, 0, 0, 1000, 1);
	blockPressWhileTypingOnStepper.push(metronomeStepper);
	blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

    disableAutoScrolling = new PsychUICheckBox(metronome.x + 120, metronome.y, "Disable Autoscroll (Not Recommended)", 120, function() {
      FlxG.save.data.chart_noAutoScroll = disableAutoScrolling.checked;
    });
    if (FlxG.save.data.chart_noAutoScroll == null) FlxG.save.data.chart_noAutoScroll = false;
    disableAutoScrolling.checked = FlxG.save.data.chart_noAutoScroll;

    instVolume = new PsychUINumericStepper(metronomeOffsetStepper.x, 250, 0.1, 1, 0, 1, 1);
    instVolume.value = FlxG.sound.music.volume;
    instVolume.name = 'inst_volume';
    blockPressWhileTypingOnStepper.push(instVolume);

    voicesVolume = new PsychUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
    voicesVolume.value = vocals.volume;
    voicesVolume.name = 'voices_volume';
    blockPressWhileTypingOnStepper.push(voicesVolume);

    voicesOppVolume = new PsychUINumericStepper(instVolume.x + 200, instVolume.y, 0.1, 1, 0, 1, 1);
    voicesOppVolume.value = vocals.volume;
    voicesOppVolume.name = 'voices_opp_volume';
    blockPressWhileTypingOnStepper.push(voicesOppVolume);

    if (FlxG.save.data.chart_hitsoundVolume == null) FlxG.save.data.chart_hitsoundVolume = 1;

    hitsoundVol = FlxG.save.data.chart_hitsoundVolume;

    hitsoundVolume = new PsychUINumericStepper(voicesVolume.x + 100, voicesVolume.y + 30, 0.1, hitsoundVol, 0, 1, 1);
    hitsoundVolume.name = 'hitsound_volume';
    blockPressWhileTypingOnStepper.push(hitsoundVolume);

    #if FLX_PITCH
	sliderRate = new PsychUISlider(metronomeOffsetStepper.x + 160, metronomeStepper.y - 30, function(v:Float) {
		playbackSpeed = v;
	}, 1, 0.5, 3, 150);
	for (i in [sliderRate.labelText, sliderRate.minText, sliderRate.maxText, sliderRate.valueText])
		i.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.WHITE);
	sliderRate.label = 'Playback Rate';
	tab_group_chart.add(sliderRate);
    #end

    soundEffectsCheck = new PsychUICheckBox(metronomeOffsetStepper.x + 90, metronomeOffsetStepper.y, "Sound Effects", 100);
    if (FlxG.save.data.soundEffects == null) FlxG.save.data.soundEffects = true;
    soundEffectsCheck.checked = FlxG.save.data.soundEffects;
    soundEffectsCheck.onClick = function() {
      FlxG.save.data.soundEffects = soundEffectsCheck.checked;
    };

    idleMusicCheck = new PsychUICheckBox(metronomeOffsetStepper.x + 90, metronomeOffsetStepper.y - 20, "Idle Music", 100);
    if (FlxG.save.data.idleMusicAllowed == null) FlxG.save.data.idleMusicAllowed = true;
    idleMusicCheck.checked = FlxG.save.data.idleMusicAllowed;
    idleMusicCheck.onClick = function() {
      FlxG.save.data.idleMusicAllowed = idleMusicCheck.checked;
      idleMusicAllow = FlxG.save.data.idleMusicAllowed;
      if (!FlxG.sound.music.playing)
      {
        if (idleMusicAllow)
        {
          if (!idleMusic.musicPaused) idleMusic.playMusic();
          else
            idleMusic.unpauseMusic(0.3);
        } else
          idleMusic.pauseMusic();
      }
    };
	var metrononeS:FlxText = new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'BPM:');
	var metrononeO:FlxText = new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Offset (ms):');

	for (format in [metrononeS, metrononeO])
		format.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE);

	tab_group_chart.add(metrononeS);
	tab_group_chart.add(metrononeO);
	tab_group_chart.add(metronome);
	tab_group_chart.add(metronomeStepper);
	tab_group_chart.add(metronomeOffsetStepper);
	tab_group_chart.add(disableAutoScrolling);
    #if desktop
    tab_group_chart.add(waveformUseInstrumental);
    tab_group_chart.add(waveformUseVoices);
    tab_group_chart.add(waveformUseOppVoices);
    #end
    tab_group_chart.add(lilBuddiesBox);
    tab_group_chart.add(soundEffectsCheck);
    tab_group_chart.add(saveUndoCheck);
    tab_group_chart.add(idleMusicCheck);
    tab_group_chart.add(instVolume);
    tab_group_chart.add(voicesVolume);
    tab_group_chart.add(voicesOppVolume);
    tab_group_chart.add(check_mute_inst);
    tab_group_chart.add(check_mute_vocals);
    tab_group_chart.add(check_mute_vocals_opponent);
    tab_group_chart.add(hitsoundVolume);
    tab_group_chart.add(check_vortex);
    tab_group_chart.add(mouseScrollingQuant);
    tab_group_chart.add(check_warnings);
    tab_group_chart.add(check_showGrid);
    tab_group_chart.add(playSoundBf);
    tab_group_chart.add(playSoundDad);
  }

  function pauseVocals()
  {
    if (vocals != null) vocals.pause();
    if (opponentVocals != null) opponentVocals.pause();
  }

  function pauseAndSetVocalsTime()
  {
    pauseVocals();
    if (vocals != null) vocals.time = FlxG.sound.music.time;

    if (opponentVocals != null) opponentVocals.time = FlxG.sound.music.time;
  }

  function loadSong():Void
  {
    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.stop();
    }
    if (vocals != null)
    {
      vocals.stop();
      vocals.destroy();
    }
    if (opponentVocals != null)
    {
      opponentVocals.stop();
      opponentVocals.destroy();
    }

    waveformCacheSound = null;
    waveformCacheBytes = null;
    waveformCacheBuffer = null;

    var diff:String = (specialAudioName.length > 1 ? specialAudioName : difficulty).toLowerCase();
    vocals = new FlxSound();
    opponentVocals = new FlxSound();
    try
    {
      var playerVocals = Paths.voices(currentSongName, diff,
        (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1);
      vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(currentSongName, diff));
    }
    vocals.autoDestroy = false;
    FlxG.sound.list.add(vocals);

    opponentVocals = new FlxSound();
    try
    {
      var oppVocals = Paths.voices(currentSongName, diff,
        (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Opponent' : characterData.vocalsP2);
      if (oppVocals != null) opponentVocals.loadEmbedded(oppVocals);
    }
    opponentVocals.autoDestroy = false;
    FlxG.sound.list.add(opponentVocals);

    generateSong(diff);
    FlxG.sound.music.pause();
    FlxG.sound.music.onComplete = function() {
      pauseVocals();
      vocals.time = opponentVocals.time = 0;
      FlxG.sound.music.pause();
      FlxG.sound.music.time = 0;
      changeSection();
    };
    Conductor.songPosition = sectionStartTime();
    FlxG.sound.music.time = Conductor.songPosition;
    if (songSlider != null && !songSlider.movingHandle && FlxG.sound.music != null)
      songSlider.value = FlxG.sound.music.time;
  }

  function generateSong(?diff:String = '')
  {
    FlxG.sound.playMusic(Paths.inst(currentSongName, diff), 0.6 /*, false*/);
    if (instVolume != null) FlxG.sound.music.volume = instVolume.value;
    if (check_mute_inst != null && check_mute_inst.checked) FlxG.sound.music.volume = 0;

    FlxG.sound.music.onComplete = function() {
      FlxG.sound.music.pause();
      Conductor.songPosition = 0;
      if (vocals != null)
      {
        vocals.pause();
        vocals.time = 0;
      }
      if (opponentVocals != null)
      {
        opponentVocals.pause();
        opponentVocals.time = 0;
      }
      changeSection();
      curSec = 0;
      updateGrid();
      updateSectionUI();
      if (vocals != null) vocals.play();
      if (opponentVocals != null) opponentVocals.play();
    };
  }

  //Helpers for the section time functions.
  var sectionStarts:Array<Float> = null;
  var sectionBPMs:Array<Float> = null;

  function invalidateSectionTimes():Void
  {
    sectionStarts = null;
    sectionBPMs = null;
  }

  function rebuildSectionTimes():Void
  {
    sectionStarts = [0.0];
    sectionBPMs = [];
    var daBPM:Float = _song.bpm;
    for (i in 0..._song.notes.length)
    {
      var section = _song.notes[i];
      if (section != null)
      {
        if (section.changeBPM) daBPM = section.bpm;
        sectionStarts.push(sectionStarts[i] + getSectionBeats(i) * (60000 / daBPM));
      } else
        sectionStarts.push(sectionStarts[i]);
      sectionBPMs.push(daBPM);
    }
  }

  /**
    * Converts a time in one section to the same position in another one.
    * Keeps the same offset from the start of the section, but rescales it to the destination's BPM.
    * Used for copying notes and events between sections with different BPMs.
    * Sustain lengths aren't touched, so multiply them by secBPM(srcSec) / secBPM(dstSec) yourself.
    * @param t The time (in ms) to convert, which should be inside srcSec.
    * @param srcSec The section the time currently belongs to.
    * @param dstSec The section to move the time to.
    */
  function remapTime(t:Float, srcSec:Int, dstSec:Int):Float
    return secStartAbs(dstSec) + (t - secStartAbs(srcSec)) * (secBPM(srcSec) / secBPM(dstSec));

  /**
    * Gets the start time of a certain section.
    * Works like sectionStartTime, but is absolute and doesn't depend on what section you're in.
    * @param sec The section to get the start time from.
    */
  function secStartAbs(sec:Int):Float
  {
    if (sectionStarts == null) rebuildSectionTimes();
    if (sec <= 0) return 0;
    return sectionStarts[FlxMath.minInt(sec, sectionStarts.length - 1)];
  }

  /**
    * Gets the BPM at a specific section.
    * A section's own bpm change applies to that section itself
    * @param sec The section to get the BPM from.
    */
  function secBPM(sec:Int):Float
  {
    if (sectionBPMs == null) rebuildSectionTimes();
    if (sec < 0 || sectionBPMs.length == 0) return _song.bpm;
    return sectionBPMs[FlxMath.minInt(sec, sectionBPMs.length - 1)];
  }

  /**
    * Gets the section that a certain song time falls inside of, taking BPM changes and section lengths into account.
    * If it goes past the end of the last section, the last section is returned.
    * @param time The song time (in ms) to look up, e.g. FlxG.sound.music.time.
    */
  function getSectionAtTime(time:Float):Int
  {
    if (sectionStarts == null) rebuildSectionTimes();
    var low:Int = 0;
    var high:Int = sectionStarts.length - 2;
    while (low < high)
    {
      var mid:Int = (low + high) >> 1;
      if (time < sectionStarts[mid + 1]) high = mid;
      else
        low = mid + 1;
    }
    return high;
  }

  var updatedSection:Bool = false;

  function sectionStartTime(add:Int = 0):Float
    return secStartAbs(curSec + add);

  var lastConductorPos:Float;
  var colorSine:Float = 0;

  override function update(elapsed:Float)
  {
    if (FlxG.sound.music.time < 0)
    {
      if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.unpauseMusic(2);
      FlxG.sound.music.pause();
      FlxG.sound.music.time = 0;
    } else if (FlxG.sound.music.time > FlxG.sound.music.length)
    {
      if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.unpauseMusic(2);
      FlxG.sound.music.pause();
      FlxG.sound.music.time = 0;
      changeSection();
    }
    Conductor.songPosition = FlxG.sound.music.time;
    _song.song = UI_songTitle.text;
    difficulty = UI_songDiff.text.toLowerCase();
    specialAudioName = _song.specialAudioName = UI_specAudio.text.toLowerCase();
    specialEventsName = _song.specialEventsName = UI_specEvents.text.toLowerCase();

    if (idleMusic != null && idleMusic.music != null && idleMusic.music.playing && !idleMusicAllow) idleMusic.pauseMusic();

    _song.songCredit = creditInputText.text;
    _song.songCreditIcon = creditIconInputText.text;
    _song.songCreditBarPath = creditPathInputText.text;

    _song.windowName = winNameInputText.text;

    if (event7InputText.text == null || event7InputText.text == '')
    {
      _song.event7Value = null;
    } 
	else
    {
      _song.event7Value = event7InputText.text;
    }

    copyMultiSectButton.label = "Copy from the last " + Std.int(CopyLastSectionCount.value) + " to the next " + Std.int(CopyFutureSectionCount.value)
      + " sections, " + Std.int(CopyLoopCount.value) + " times";
    deleteSections.label = "Delete sections " + Std.int(deleteSecStart.value) + " to " + Std.int(deleteSecEnd.value);

    strumLineUpdateY();
    for (i in 0...8)
    {
      strumLineNotes.members[i].y = strumLine.y;
    }

    FlxG.mouse.visible = true; // cause reasons. trust me
    camPos.y = strumLine.y;
    if (!disableAutoScrolling.checked)
    {
      if (Math.ceil(strumLine.y) >= gridBG.height)
      {
        if (_song.notes[curSec + 1] == null)
        {
          addSection(getSectionBeats());
        }

        changeSection(curSec + 1, false);
      } else if (strumLine.y < -10)
      {
        changeSection(curSec - 1, false);
      }
    }

    selectionEvent.visible = false;
    if (FlxG.mouse.x > gridBG.x
      && FlxG.mouse.x < gridBG.x + gridBG.width
      && FlxG.mouse.y > gridBG.y
      && FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
    {
      selectionNote.visible = true;
      selectionNote.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
      if (FlxG.keys.pressed.SHIFT) selectionNote.y = FlxG.mouse.y;
      else
      {
        var gridmult = GRID_SIZE / (quantization / 16);
        selectionNote.y = Math.floor(FlxG.mouse.y / gridmult) * gridmult;
      }
      selectionNote.noteData = Math.floor(FlxG.mouse.x / GRID_SIZE - 1) % 4;
      if (selectionNote.noteData < 0)
      {
        selectionNote.noteData = 0;
        selectionNote.visible = false;
        selectionEvent.visible = true;
        selectionEvent.setGraphicSize(GRID_SIZE, GRID_SIZE);
        selectionEvent.x = selectionNote.x;
        selectionEvent.y = selectionNote.y;
      }
      if (selectionNote.animation.curAnim == null) selectionNote.playAnim('static' + selectionNote.noteData, false);
      else if (!selectionNote.animation.curAnim.name.endsWith(Std.string(selectionNote.noteData))) selectionNote.playAnim('static' + selectionNote.noteData,
        false);
    } else
    {
      selectionNote.visible = false;
    }

    if (FlxG.mouse.justPressed)
    {
      if (FlxG.mouse.overlaps(curRenderedNotes))
      {
        if (!FlxG.keys.pressed.CONTROL && !FlxG.keys.pressed.ALT)
        {
          saveUndo(_song);
          if (soundEffectsCheck.checked) FlxG.sound.play(Paths.sound('removeNote'), 0.7);
        }
        if (FlxG.keys.pressed.CONTROL || FlxG.keys.pressed.ALT)
        {
          if (soundEffectsCheck.checked) FlxG.sound.play(Paths.sound('selectNote'), 0.7);
        }
        curRenderedNotes.forEachAlive(function(note:Note) {
          if (FlxG.mouse.overlaps(note))
          {
            if (FlxG.keys.pressed.CONTROL)
            {
              deselectNote();
              selectNote(note);
            } else if (FlxG.keys.pressed.ALT)
            {
              deselectNote();
              selectNote(note);
              curSelectedNote[3] = noteTypeIntMap.get(currentType);
              updateGrid(false);
            } else
            {
              selectionNote.playAnim('pressed' + selectionNote.noteData, true);
              // trace('tryin to delete note...');
              deleteNote(note);
            }
          }
        });
      } else
      {
        if (FlxG.mouse.x > gridBG.x
          && FlxG.mouse.x < gridBG.x + gridBG.width
          && FlxG.mouse.y > gridBG.y
          && FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
        {
          deselectNote();
          saveUndo(_song);
          // FlxG.log.add('added note');
          addNote();
          if (check_stackActive.checked)
          {
            var addCount:Float = stepperStackNum.value * stepperStackOffset.value - 1;
            for (i in 0...Std.int(addCount))
            {
              addNote(curSelectedNote[0] + (15000 / Conductor.bpm) / stepperStackOffset.value, curSelectedNote[1] + Math.floor(stepperStackSideOffset.value),
                currentType);
            }
          }
          selectionNote.playAnim('confirm' + selectionNote.noteData, true);
          if (soundEffectsCheck.checked) FlxG.sound.play(Paths.sound('addedNote'), 0.7);

          updateNoteUI();
        } else if (soundEffectsCheck.checked) FlxG.sound.play(Paths.sound('click'));
      }
    }

    var blockInput:Bool = false;
	if (PsychUIInputText.focusOn != null)
		blockInput = true;
	else
		blockInput = false;
		
	if (PsychUIInputText.focusOn == null) // If not typing anything
	{
		if (FlxG.keys.justPressed.F1)
		{
			final vis:Bool = !fullTipText.visible;
			tipBg.visible = tipBg.active = fullTipText.visible = fullTipText.active = vis;
		}
	}

    if (!blockInput)
    {
      if (FlxG.keys.justPressed.ESCAPE)
      {
        saveLevel(true, true);
        FlxG.sound.music.pause();
        pauseVocals();
        LoadingState.loadAndSwitchState(() -> new editors.EditorPlayState(sectionStartTime()));
        if (idleMusic != null && idleMusic.music != null) idleMusic.destroy();
        FlxG.sound.music.onComplete = null; // So that it doesn't crash when you reach the end
      }
      if (FlxG.keys.justPressed.ENTER)
      {
        if (CoolUtil.getNoteAmount(_song) <= 1000000) saveLevel(true, true);
        FlxG.mouse.visible = false;
        PlayState.SONG = _song;
        FlxG.sound.music.stop();
        if (vocals != null) vocals.stop();
        if (opponentVocals != null) opponentVocals.stop();
        if (FlxG.keys.pressed.SHIFT)
        {
          PlayState.startOnTime = sectionStartTime();
        }
        CoolUtil.currentDifficulty = difficulty;
        StageData.loadDirectory(_song);
        LoadingState.loadAndSwitchState(PlayState.new);
        if (idleMusic != null && idleMusic.music != null) idleMusic.destroy();
      }

      if (curSelectedNote != null && curSelectedNote[1] > -1)
      {
        if (FlxG.keys.justPressed.E || FlxG.keys.pressed.CONTROL && FlxG.mouse.wheel < 0)
        {
          changeNoteSustain(1);
        }
        if (FlxG.keys.justPressed.Q || FlxG.keys.pressed.CONTROL && FlxG.mouse.wheel > 0)
        {
          changeNoteSustain(-1);
        }
      }

      if (FlxG.keys.justPressed.BACKSPACE)
      {
        if (!unsavedChanges)
        {
          // Protect against lost data when quickly leaving the chart editor.
          saveLevel(true, true);

          CoolUtil.currentDifficulty = difficulty;
          PlayState.chartingMode = false;
          FlxG.switchState(editors.MasterEditorMenu.new);
          FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
          FlxG.mouse.visible = false;
          if (idleMusic != null && idleMusic.music != null) idleMusic.destroy();
          return;
        } else
          openSubState(new Prompt('WARNING! This action will clear unsaved progress.\n\nProceed?', function() FlxG.switchState(editors.MasterEditorMenu.new), null, ignoreWarnings));
      }

      if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z)
        undo();

      if (FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL)
      {
        --curZoom;
        updateZoom();
      }
      if (FlxG.keys.justPressed.X && curZoom < zoomList.length - 1)
      {
        curZoom++;
        updateZoom();
      }

      if (FlxG.keys.pressed.C && !FlxG.keys.pressed.CONTROL)
        if (!FlxG.mouse.overlaps(curRenderedNotes)) // lmao cant place notes when your cursor already overlaps one
        if (FlxG.mouse.x > gridBG.x
          && FlxG.mouse.x < gridBG.x + gridBG.width
          && FlxG.mouse.y > gridBG.y
          && FlxG.mouse.y < gridBG.y + gridBG.height) if (!FlxG.keys.pressed.CONTROL) // stop crashing
          {
            addNote(); // allows you to draw notes by holding C
            if (check_stackActive.checked)
            {
              var addCount:Float = stepperStackNum.value * stepperStackOffset.value - 1;
              for (i in 0...Std.int(addCount))
              {
                addNote(curSelectedNote[0] + (15000 / Conductor.bpm) / stepperStackOffset.value, curSelectedNote[1] + Math.floor(stepperStackSideOffset.value),
                  currentType);
              }
            }
            updateNoteUI();
          }
      if (FlxG.keys.pressed.C && FlxG.keys.pressed.CONTROL) if (FlxG.mouse.overlaps(curRenderedNotes)) if (FlxG.mouse.x > gridBG.x
        && FlxG.mouse.x < gridBG.x + gridBG.width
        && FlxG.mouse.y > gridBG.y
        && FlxG.mouse.y < gridBG.y + gridBG.height) curRenderedNotes.forEach(function(note:Note) {
          if (FlxG.mouse.overlaps(note)) deleteNote(note); // mass deletion of notes
        });

	if (FlxG.keys.justPressed.TAB)
	{
		if (FlxG.keys.pressed.SHIFT)
		{
			UI_box.selectedIndex -= 1;
			if (UI_box.selectedIndex < 0)
				UI_box.selectedIndex = 2;
		}
		else
		{
			UI_box.selectedIndex += 1;
			if (UI_box.selectedIndex >= 3)
				UI_box.selectedIndex = 0;
		}
	}

      if (FlxG.keys.justPressed.SPACE)
      {
        if (FlxG.sound.music.playing)
        {
          FlxG.sound.music.pause();
          pauseVocals();
          resetBuddies();
          lilBf.color = lilOpp.color = FlxColor.WHITE;
          if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.unpauseMusic(2);
        } else
        {
          pauseAndSetVocalsTime();
          if (!FlxG.sound.music.playing)
          {
            FlxG.sound.music.play();
            if (vocals != null) vocals.play();
            if (opponentVocals != null) opponentVocals.play();
          }
          if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.pauseMusic();
          resetBuddies();
          lilBf.color = lilOpp.color = FlxColor.WHITE;
        }
      }

      if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
      {
        if (FlxG.keys.pressed.SHIFT) resetSection(true);
        else
          resetSection();
      }
      if (FlxG.keys.pressed.CONTROL && curSelectedNote != null && curSelectedNote[1] > -1 && curSelectedNote[2] != null)
      {
        if (FlxG.keys.justPressed.RIGHT)
        {
          if (curSelectedNote[1] < 6 + 1)
          {
            curSelectedNote[1] += 1;
          } else if (curSelectedNote[1] == 6 + 1)
          {
            curSelectedNote[1] = 0;
          }
          updateGrid(false);
        }
        if (FlxG.keys.justPressed.LEFT)
        {
          if (curSelectedNote[1] > 0)
          {
            curSelectedNote[1] -= 1;
          } else if (curSelectedNote[1] == 0)
          {
            curSelectedNote[1] = 7;
          }
          updateGrid(false);
        }
      }

      if (FlxG.mouse.wheel != 0 && !FlxG.keys.pressed.CONTROL)
      {
        if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.unpauseMusic(2);
        FlxG.sound.music.pause();
        resetBuddies();
        lilBf.color = lilOpp.color = FlxColor.WHITE;
        
        if (!mouseQuant)
        {
          FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet * 0.8);
          pauseAndSetVocalsTime();
        }
        else scrollQuantized(FlxG.mouse.wheel > 0);
      }

      if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
      {
        if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.unpauseMusic(2);
        resetBuddies();
        lilBf.color = lilOpp.color = FlxColor.WHITE;
        FlxG.sound.music.pause();

        var holdingShift:Float = 1;
        if (FlxG.keys.pressed.CONTROL) holdingShift = 0.25;
        else if (FlxG.keys.pressed.SHIFT) holdingShift = 4;

        var daTime:Float = 700 * FlxG.elapsed * holdingShift;
        if (FlxG.keys.pressed.W) daTime *= -1;

        FlxG.sound.music.time += daTime;
        pauseAndSetVocalsTime();
      }

      if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN) scrollQuantized(FlxG.keys.justPressed.UP, vortex);

      var style = FlxG.keys.pressed.SHIFT ? currentType : 3;
      var conductorTime = Conductor.songPosition;

      // AWW YOU MADE IT SEXY <3333 THX SHADMAR

      if (!blockInput && !FlxG.keys.pressed.CONTROL)
      {
        if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.LEFT)
        {
          (FlxG.keys.justPressed.RIGHT) ? curQuant++ : curQuant--;

          curQuant = FlxMath.wrap(curQuant, 0, quantizations.length - 1);
          quantization = quantizations[curQuant];
          quant.animation.play('q', true, false, curQuant);
        }
        if (vortex)
        {
          var controlArray:Array<Bool> = [
            FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
            FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT
          ];

          if (controlArray.contains(true))
          {
            for (i in 0...controlArray.length)
            {
              if (controlArray[i]) doANoteThing(conductorTime, i, style);
            }
          }
        }
      }
      var shiftThing:Int = 1;
      if (FlxG.keys.pressed.SHIFT) shiftThing = 4;

      if (FlxG.keys.justPressed.D)
      {
        if (_song.notes[curSec + shiftThing] == null)
        {
          addSection(getSectionBeats());
        }

        changeSection(curSec + shiftThing);
      }
      if (FlxG.keys.justPressed.A)
      {
        if (curSec <= 0)
        {
          changeSection(_song.notes.length - 1);
        } else
        {
          changeSection(curSec - shiftThing);
        }
      }
    }

    strumLineNotes.visible = quant.visible = vortex;

    if (FlxG.sound.music.time < 0)
    {
      if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.unpauseMusic(2);
      FlxG.sound.music.pause();
      FlxG.sound.music.time = 0;
    } else if (FlxG.sound.music.time > FlxG.sound.music.length)
    {
      if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.unpauseMusic(2);
      FlxG.sound.music.pause();
      FlxG.sound.music.time = 0;
      changeSection();
    }

    Conductor.songPosition = FlxG.sound.music.time;
    strumLineUpdateY();
    camPos.y = strumLine.y;
    for (i in 0...8)
    {
      strumLineNotes.members[i].y = strumLine.y;
      strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
    }

    #if FLX_PITCH
    // PLAYBACK SPEED CONTROLS //
    var holdingShift = FlxG.keys.pressed.SHIFT;
    var holdingLB = FlxG.keys.pressed.LBRACKET;
    var holdingRB = FlxG.keys.pressed.RBRACKET;
    var pressedLB = FlxG.keys.justPressed.LBRACKET;
    var pressedRB = FlxG.keys.justPressed.RBRACKET;

    if (!holdingShift && pressedLB || holdingShift && holdingLB) playbackSpeed -= 0.01;
    if (!holdingShift && pressedRB || holdingShift && holdingRB) playbackSpeed += 0.01;
    if (FlxG.keys.pressed.ALT && (pressedLB || pressedRB || holdingLB || holdingRB)) playbackSpeed = 1;
    
    playbackSpeed = FlxMath.bound(playbackSpeed, 0.25, 4);

    FlxG.sound.music.pitch = playbackSpeed;
    vocals.pitch = playbackSpeed;
    opponentVocals.pitch = playbackSpeed;
    #end

    if (bpmTxt != null)
    {
      bpmTxt.text = CoolUtil.formatTime(Conductor.songPosition, 2)
        + ' / '
        + CoolUtil.formatTime(FlxG.sound.music.length, 2)
        + "\nSection: "
        + curSec
        + "\n\nBeat: "
        + FlxMath.roundDecimal(curDecBeat, 2)
        + "\nStep: "
        + curStep
        + "\nBeat Snap: "
        + quantization
        + "th"
        + "\n\n"
        + FlxStringUtil.formatMoney(CoolUtil.getNoteAmount(_song), false)
        + ' Notes'
        + "\n\nRendered Notes: "
        + FlxStringUtil.formatMoney(Math.abs(curRenderedNotes.length + nextRenderedNotes.length), false);

      if (_song.notes[curSec] != null) bpmTxt.text += "\n\nSection Notes: " + FlxStringUtil.formatMoney(_song.notes[curSec].sectionNotes.length, false);
    }

    var playedSound:Array<Bool> = [false, false, false, false];
    curRenderedNotes.forEachAlive(function(note:Note) {
      note.alpha = 1;
      if (curSelectedNote != null)
      {
        var noteDataToCheck:Int = note.noteData;
        if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;

        if (curSelectedNote[0] == note.strumTime
          && ((curSelectedNote[2] == null && noteDataToCheck < 0)
            || (curSelectedNote[2] != null && curSelectedNote[1] == noteDataToCheck)))
        {
          colorSine += elapsed;
          var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
          note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal,
            0.999); // Alpha can't be 100% or the color won't be updated for some reason, guess i will die
        }
      }

      if (note.strumTime <= Conductor.songPosition)
      {
        note.alpha = 0.4;
        if (note.strumTime >= lastConductorPos && FlxG.sound.music.playing && note.noteData > -1)
        {
          var data:Int = note.noteData % 4;
          var noteDataToCheck:Int = note.noteData;
          if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;
          if (vortex)
          {
            if (ClientPrefs.showNotes && ClientPrefs.enableColorShader)
              strumLineNotes.members[noteDataToCheck].playAnim('confirm', true, note.rgbShader.r, note.rgbShader.g, note.rgbShader.b);
            else
              strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);

            strumLineNotes.members[noteDataToCheck].resetAnim = ((note.sustainLength / 1000) + 0.15) / playbackSpeed;
          }
          if (lilBuddiesBox.checked)
          {
            var buddy = (note.mustPress ? lilBf : lilOpp);
            if (ClientPrefs.showNotes && ClientPrefs.enableColorShader)
              buddy.color = note.rgbShader.r;

            buddy.animation.play("" + note.noteData % 4, true);
          }

          if (!playedSound[data])
          {
            if ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress))
            {
              hitsound.play(true);
              hitsound.volume = hitsoundVolume.value;
              hitsound.pan = note.noteData < 4 ? -0.3 : 0.3; // would be coolio
              playedSound[data] = true;
            }
          }
        }
      }
    });

	if(metronome.checked && lastConductorPos != Conductor.songPosition) {
		var metroInterval:Float = 60 / metronomeStepper.value;
		var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
		var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
		if(metroStep != lastMetroStep) {
			FlxG.sound.play(Paths.sound('Metronome_Tick'));
			//trace('Ticked');
		}
	}

    lastConductorPos = Conductor.songPosition;
    refreshPresence();
    super.update(elapsed);
    idleMusic.update(elapsed);
  }
  
  public function UIEvent(id:String, sender:Dynamic):Void
  {
    if(id == PsychUIInputText.CHANGE_EVENT) {
      if(curSelectedNote != null)
      {
        if(sender == value1InputText) {
          if(curSelectedNote[1][curEventSelected] != null)
          {
            curSelectedNote[1][curEventSelected][1] = value1InputText.text;
            updateGrid();
          }
        }
        else if(sender == value2InputText) {
          if(curSelectedNote[1][curEventSelected] != null)
          {
            curSelectedNote[1][curEventSelected][2] = value2InputText.text;
            updateGrid();
          }
        }
        else if(sender == strumTimeInputText) {
          var value:Float = Std.parseFloat(strumTimeInputText.text);
          if(Math.isNaN(value)) value = 0;
          curSelectedNote[0] = value;
          updateGrid();
        }
      }
    }
    else if (id == PsychUINumericStepper.CHANGE_EVENT)
    {
      if (sender == stepperBeats)
      {
        _song.notes[curSec].sectionBeats = stepperBeats.value;
        reloadGridLayer();
      }
      else if (sender == stepperSpeed)
        _song.speed = stepperSpeed.value;
      else if (sender == stepperBPM)
      {
        _song.bpm = stepperBPM.value;
        Conductor.mapBPMChanges(_song);
        Conductor.bpm = stepperBPM.value;
        stepperSusLength.step = Math.ceil(Conductor.stepCrochet / 2);
        updateGrid();
      }
      else if (sender == stepperSectionBPM)
      {
        _song.notes[curSec].bpm = stepperSectionBPM.value;
        updateGrid();
      }
	  /*
      else if (sender == trackVolumeStepper)
      {
        if (waveformTrack != null)
        {
          waveformTrack.volume = trackVolumeStepper.value;
          if (waveformTrack.volume == 0) muteTrackCheck.checked = true; else muteTrackCheck.checked = false;
        }
        else
          trace("No track selected.");
      }
	  */
    }
    else if(id == PsychUISlider.CHANGE_EVENT)
    {
      if (sender == sliderRate)
        playbackSpeed = #if FLX_PITCH Std.int(sliderRate.value) #else 1.0 #end;
    }
    else if (id == PsychUICheckBox.CLICK_EVENT)
    {
      if (sender == check_mustHitSection)
      {
        _song.notes[curSec].mustHitSection = check_mustHitSection.checked;

        updateGrid();
        updateHeads();
      }
      else if (sender == check_gfSection)
      {
        _song.notes[curSec].gfSection = check_gfSection.checked;

        updateGrid();
        updateHeads();
      }
      else if (sender == check_changeBPM)
      {
        _song.notes[curSec].changeBPM = check_changeBPM.checked;
        // FlxG.log.add('changed bpm shit');
      }
      else if (sender == check_altAnim)
        _song.notes[curSec].altAnim = check_altAnim.checked;
    }
  }

  function scrollQuantized(up:Bool, tween:Bool = false)
  {
    // leniency point, to help snap it exactly
    final leniency:Float = 1.25;
    
    if (idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.unpauseMusic(2);
    FlxG.sound.music.pause();
    updateCurStep();
    resetBuddies();
    lilBf.color = lilOpp.color = FlxColor.WHITE;

    var beat:Float = curDecStep / 4;
    var snap:Float = quantization / 4;

    var targetBeat:Float = (up ? Math.ceil : Math.floor)(beat * snap + (up ? -1 : 1) * leniency) / snap;
    var time = Conductor.beatToSeconds(targetBeat);
    if (!tween)
      FlxG.sound.music.time = time;
    else
    {
      FlxTween.cancelTweensOf(FlxG.sound.music, ['time']);
      FlxTween.tween(FlxG.sound.music, {time: time}, 0.1, {ease: FlxEase.circOut});
    }
    pauseAndSetVocalsTime();
  }

  function resetBuddies()
  {
    lilBf.animation.play("idle");
    lilOpp.animation.play("idle");
  }

  function updateZoom()
  {
    var daZoom:Float = zoomList[curZoom];
    var zoomThing:String = '1 / ' + daZoom;
    if (daZoom < 1) zoomThing = Math.round(1 / daZoom) + ' / 1';
    zoomTxt.text = 'Zoom: ' + zoomThing;
    reloadGridLayer();

    //Repositions every note that's already there, instead of rebuilding the entire notes array.
    var beats:Float = getSectionBeats();
    var nextBeats:Float = getSectionBeats(curSec + 1);

    for (i in curRenderedNotes)
      i.y = getYfromStrumNotes(i.strumTime - sectionStartTime(), beats);
    for (i in nextRenderedNotes)
      i.y = getYfromStrumNotes(i.strumTime - sectionStartTime(), nextBeats);

    //Even though the notes can just be repositioned, the sustains can't.
    //So only those need to be rebuilt.

    curRenderedSustains.clear();
    susMap.clear();
    for (note in curRenderedNotes.members)
    {
      if (note == null || note.sustainLength <= 0) continue;

      var sustain:FlxSprite = setupSusNote(note, beats);
      curRenderedSustains.add(sustain);
      susMap.set(note, sustain);
    }

    nextRenderedSustains.clear();
    for (note in nextRenderedNotes.members)
    {
      if (note == null || note.sustainLength <= 0) continue;

      var sustain:FlxSprite = setupSusNote(note, nextBeats);
      nextRenderedSustains.add(sustain);
      susMap.set(note, sustain);
    }
  }

  //Helper function. Makes a 1x1 graphic that scales to the specified width and height.
  //It's memory-efficient.
  function makeSolid(x:Float, y:Float, width:Float, height:Float, color:FlxColor):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y).makeGraphic(1, 1, FlxColor.WHITE);
    sprite.color = color;
    sprite.alpha = color.alphaFloat;
    sprite.scale.set(width, height);
    sprite.updateHitbox();
    sprite.active = false;
    return sprite;
  }

  function getCheckerTile():flixel.graphics.FlxGraphic
  {
    var key:String = 'chart_editor_grid_tile';
    var cached:flixel.graphics.FlxGraphic = FlxG.bitmap.get(key);
    if (cached != null) return cached;

    var tile:openfl.display.BitmapData = new openfl.display.BitmapData(GRID_SIZE * 2, GRID_SIZE * 2, true, 0xffe7e6e6);
    tile.fillRect(new Rectangle(GRID_SIZE, 0, GRID_SIZE, GRID_SIZE), 0xffd9d5d5);
    tile.fillRect(new Rectangle(0, GRID_SIZE, GRID_SIZE, GRID_SIZE), 0xffd9d5d5);
    return FlxG.bitmap.add(tile, false, key);
  }

  static inline var CHECKER_SEGMENT:Int = GRID_SIZE * 100;

  function addCheckerboard(top:Float, height:Float):Void
  {
    var offset:Float = 0;
    while (offset < height)
    {
      var segment:FlxTiledSprite = new FlxTiledSprite(getCheckerTile(), GRID_SIZE * 9, Math.min(CHECKER_SEGMENT, height - offset));
      segment.y = top + offset;
      segment.active = false;
      gridLayer.add(segment);
      offset += CHECKER_SEGMENT;
    }
  }

  function makeGridBackground(top:Float, height:Float):FlxSprite
  {
    var background:FlxSprite = makeSolid(0, top, GRID_SIZE * 9, height, 0xffe7e6e6);
    if (showTheGrid)
    {
      background.visible = false;
      addCheckerboard(top, height);
    }
    return background;
  }

  var lastSecBeats:Float = 0;
  var lastSecBeatsNext:Float = 0;
  var lastGridZoom:Int = -1;
  var lastGridBeats:Float = -1;
  var lastGridBeatsNext:Float = -1;
  var lastGridShow:Bool = false;
  var lastGridVortex:Bool = false;
  var lastGridHasNext:Bool = false;
  var lastGridBGHeight:Int = -1;

  function reloadGridLayer()
  {
    var curBeats:Float = getSectionBeats();
    var hasNextSec:Bool = sectionStartTime(1) <= FlxG.sound.music.length;
    var nextBeats:Float = hasNextSec ? getSectionBeats(curSec + 1) : 0;

    if (gridBG != null && gridLayer != null && curZoom == lastGridZoom && curBeats == lastGridBeats && nextBeats == lastGridBeatsNext
      && showTheGrid == lastGridShow && vortex == lastGridVortex && hasNextSec == lastGridHasNext && Std.int(gridBG.height) == lastGridBGHeight)
    {
      lastSecBeats = curBeats;
      lastSecBeatsNext = nextBeats;
      return;
    }

    var previousGridSprites:Array<FlxSprite> = gridLayer.members.copy();
    gridLayer.clear();
    gridBG = makeGridBackground(0, Std.int(GRID_SIZE * curBeats * 4 * zoomList[curZoom]));

    #if desktop
    if (FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices || FlxG.save.data.chart_waveformOppVoices)
    {
      updateWaveform();
    }
    #end

    var leHeight:Int = Std.int(gridBG.height);
    nextGridBG = null;
    if (hasNextSec)
    {
      nextGridBG = makeGridBackground(gridBG.height, Std.int(GRID_SIZE * nextBeats * 4 * zoomList[curZoom]));
      nextGridBG.y = gridBG.height;
      leHeight = Std.int(gridBG.height + nextGridBG.height);
    }

    if (nextGridBG != null) gridLayer.add(nextGridBG);
    gridLayer.add(gridBG);

    if (nextGridBG != null)
    {
      var gridBlack:FlxSprite = makeSolid(0, gridBG.height, GRID_SIZE * 9, nextGridBG.height, FlxColor.BLACK);
      gridBlack.alpha = 0.4;
      gridLayer.add(gridBlack);
    }

    var gridBlackLine:FlxSprite = makeSolid(gridBG.x + gridBG.width - (GRID_SIZE * 4), 0, 2, leHeight, FlxColor.BLACK);
    gridLayer.add(gridBlackLine);

    if (vortex)
    {
      for (i in 1...4)
        gridLayer.add(makeSolid(gridBG.x, (GRID_SIZE * (4 * curZoom)) * i, gridBG.width, 1, 0x44FF0000));
    }

    var gridBlackLine:FlxSprite = makeSolid(gridBG.x + GRID_SIZE, 0, 2, leHeight, FlxColor.BLACK);
    gridLayer.add(gridBlackLine);

    for (sprite in previousGridSprites)
      if (sprite != null) sprite.destroy();

    lastSecBeats = curBeats;
    lastSecBeatsNext = nextBeats;
    lastGridZoom = curZoom;
    lastGridBeats = curBeats;
    lastGridBeatsNext = nextBeats;
    lastGridShow = showTheGrid;
    lastGridVortex = vortex;
    lastGridHasNext = hasNextSec;
    lastGridBGHeight = Std.int(gridBG.height);
  }

  function strumLineUpdateY()
  {
    strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (getSectionBeats() / 4);
  }

  var waveformPrinted:Bool = true;
  var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];

  var lastWaveformHeight:Int = 0;
  var waveformCacheSound:FlxSound = null;
  var waveformCacheBuffer:AudioBuffer = null;
  var waveformCacheBytes:Bytes = null;

  function updateWaveform()
  {
    //If it gets over this zoom it becomes a black sprite and can end up taking up hundreds of MBs of RAM.
    if (zoomList[curZoom] > 24) return;

    #if desktop
    if (waveformPrinted)
    {
      var width:Int = Std.int(GRID_SIZE * 8);
      var height:Int = Std.int(gridBG.height);
      if (lastWaveformHeight != height && waveformSprite.pixels != null)
      {
        waveformSprite.pixels.dispose();
        waveformSprite.pixels.disposeImage();
        waveformSprite.makeGraphic(width, height, 0x00FFFFFF);
        lastWaveformHeight = height;
      }
      waveformSprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);
    }
    waveformPrinted = false;

    if (!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices && !FlxG.save.data.chart_waveformOppVoices)
    {
      // trace('Epic fail on the waveform lol');
      return;
    }

    wavData[0][0] = [];
    wavData[0][1] = [];
    wavData[1][0] = [];
    wavData[1][1] = [];

    var steps:Int = Math.round(getSectionBeats() * 4);
    var st:Float = sectionStartTime();
    var et:Float = st + (Conductor.stepCrochet * steps);

    var sound:FlxSound = FlxG.sound.music;
    if (FlxG.save.data.chart_waveformVoices) sound = vocals;
    else if (FlxG.save.data.chart_waveformOppVoices) sound = opponentVocals;
    if (sound._sound != null && sound._sound.__buffer != null)
    {
      if (waveformCacheBytes == null || waveformCacheSound != sound || waveformCacheBuffer != sound._sound.__buffer)
      {
        waveformCacheBytes = sound._sound.__buffer.data.toBytes();
        waveformCacheSound = sound;
        waveformCacheBuffer = sound._sound.__buffer;
      }

      wavData = waveformData(sound._sound.__buffer, waveformCacheBytes, st, et, 1, wavData, Std.int(gridBG.height));
    }

    // Draws
    var gSize:Int = Std.int(GRID_SIZE * 8);
    var hSize:Int = Std.int(gSize / 2);

    var lmin:Float = 0;
    var lmax:Float = 0;

    var rmin:Float = 0;
    var rmax:Float = 0;

    var size:Float = 1;

    var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);

    var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);

    var length:Int = leftLength > rightLength ? leftLength : rightLength;

    var index:Int;
    for (i in 0...length)
    {
      index = i;

      lmin = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
      lmax = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

      rmin = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
      rmax = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

      waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), i * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
    }

    waveformPrinted = true;
    #end
  }

  function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>,
      ?steps:Float):Array<Array<Array<Float>>>
  {
    #if (lime_cffi && !macro)
    if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

    var khz:Float = (buffer.sampleRate / 1000);
    var channels:Int = buffer.channels;

    var index:Int = Std.int(time * khz);

    var samples:Float = ((endTime - time) * khz);

    if (steps == null) steps = 1280;

    var samplesPerRow:Float = samples / steps;
    var samplesPerRowI:Int = Std.int(samplesPerRow);

    var gotIndex:Int = 0;

    var lmin:Float = 0;
    var lmax:Float = 0;

    var rmin:Float = 0;
    var rmax:Float = 0;

    var rows:Float = 0;

    var simpleSample:Bool = true; // samples > 17200;
    var v1:Bool = false;

    if (array == null) array = [[[0], [0]], [[0], [0]]];

    while (index < (bytes.length - 1))
    {
      if (index >= 0)
      {
        var byte:Int = bytes.getUInt16(index * channels * 2);

        if (byte > 65535 / 2) byte -= 65535;

        var sample:Float = (byte / 65535);

        if (sample > 0)
        {
          if (sample > lmax) lmax = sample;
        } else if (sample < 0)
        {
          if (sample < lmin) lmin = sample;
        }

        if (channels >= 2)
        {
          byte = bytes.getUInt16((index * channels * 2) + 2);

          if (byte > 65535 / 2) byte -= 65535;

          sample = (byte / 65535);

          if (sample > 0)
          {
            if (sample > rmax) rmax = sample;
          } else if (sample < 0)
          {
            if (sample < rmin) rmin = sample;
          }
        }
      }

      v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
      while (simpleSample ? v1 : rows >= samplesPerRow)
      {
        v1 = false;
        rows -= samplesPerRow;

        gotIndex++;

        var lRMin:Float = Math.abs(lmin) * multiply;
        var lRMax:Float = lmax * multiply;

        var rRMin:Float = Math.abs(rmin) * multiply;
        var rRMax:Float = rmax * multiply;

        if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
        else
          array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

        if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
        else
          array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

        if (channels >= 2)
        {
          if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
          else
            array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

          if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
          else
            array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
        } else
        {
          if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
          else
            array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

          if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
          else
            array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
        }

        lmin = 0;
        lmax = 0;

        rmin = 0;
        rmax = 0;
      }

      index++;
      rows++;
      if (gotIndex > steps) break;
    }

    return array;
    #else
    return [[[0], [0]], [[0], [0]]];
    #end
  }

  function changeNoteSustain(steps:Float):Void
  {
    if (curSelectedNote != null && curSelectedNote[2] != null)
    {
      var stepCrochet:Float = 15000 / secBPM(getSectionAtTime(curSelectedNote[0]));
      curSelectedNote[2] += steps * stepCrochet;

      if (Math.abs(curSelectedNote[2]) < 0.000001)
        curSelectedNote[2] = 0;

      curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
    }
    
    refreshSelectedSustain();
    updateNoteUI();
  }

  function resetSection(songBeginning:Bool = false):Void
  {
    resetBuddies();

    if (FlxG.sound.music.playing && idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.pauseMusic();

    FlxG.sound.music.pause();
    // Basically old shit from changeSection???
    FlxG.sound.music.time = sectionStartTime();

    if (songBeginning)
    {
      FlxG.sound.music.time = 0;
      curSec = 0;
    }

    if (songBeginning) updateGrid();

    pauseAndSetVocalsTime();
    updateCurStep();
    updateSectionUI();
    updateWaveform();
  }

  function changeSection(sec:Int = 0, ?updateMusic:Bool = true, ?updateTheGrid:Bool = true):Void
  {
    if (_song.notes[sec] != null)
    {
      if (FlxG.sound.music.playing && idleMusic != null && idleMusic.music != null && idleMusicAllow) idleMusic.pauseMusic();
      resetBuddies();
      lilBf.color = lilOpp.color = FlxColor.WHITE;
      curSec = sec;
      if (updateMusic)
      {
        FlxG.sound.music.pause();

        FlxG.sound.music.time = sectionStartTime();
        pauseAndSetVocalsTime();
        updateCurStep();
      }

      var blah1:Float = getSectionBeats();
      var blah2:Float = getSectionBeats(curSec + 1);
      if (sectionStartTime(1) > FlxG.sound.music.length) blah2 = 0;

      if (blah1 != lastSecBeats || blah2 != lastSecBeatsNext)
        reloadGridLayer();

      updateSectionUI();
    } else
    {
      changeSection();
    }
    Conductor.songPosition = FlxG.sound.music.time;
    updateWaveform();
    if (updateTheGrid) updateGrid(true);
  }

  function updateSectionUI():Void
  {
    var sec = _song.notes[curSec];

    stepperBeats.value = getSectionBeats();
    check_mustHitSection.checked = sec.mustHitSection;
    check_gfSection.checked = sec.gfSection;
    check_altAnim.checked = sec.altAnim;
    check_crossFade.checked = sec.crossFade;
    check_changeBPM.checked = sec.changeBPM;
    stepperSectionBPM.value = sec.bpm;

    updateHeads();
  }

  var characterData:Dynamic =
    {
      iconP1: null,
      iconP2: null,
      vocalsP1: null,
      vocalsP2: null
    };

  function updateJsonData():Void
  {
    for (i in 1...3)
    {
      var data:CharacterFile = loadCharacterFile(Reflect.field(_song, 'player$i'));
      Reflect.setField(characterData, 'iconP$i', !characterFailed ? data.healthicon : 'face');
      Reflect.setField(characterData, 'vocalsP$i', data.vocals_file != null ? data.vocals_file : '');
    }
  }

  function updateHeads():Void
  {
    if (_song.notes[curSec] != null)
    {
      if (_song.notes[curSec].mustHitSection)
      {
        leftIcon.changeIcon(characterData.iconP1);
        rightIcon.changeIcon(characterData.iconP2);
        if (_song.notes[curSec].gfSection) leftIcon.changeIcon('gf');
      } else
      {
        leftIcon.changeIcon(characterData.iconP2);
        rightIcon.changeIcon(characterData.iconP1);
        if (_song.notes[curSec].gfSection) leftIcon.changeIcon('gf');
      }
    }
  }

  var characterFailed:Bool = false;

  function loadCharacterFile(char:String):CharacterFile
  {
    characterFailed = false;
    var characterPath:String = 'characters/' + char + '.json';
    #if MODS_ALLOWED
    var path:String = Paths.modFolders(characterPath);
    if (!FileSystem.exists(path))
    {
      path = Paths.getPreloadPath(characterPath);
    }

    if (!FileSystem.exists(path))
    #else
    var path:String = Paths.getPreloadPath(characterPath);
    if (!OpenFlAssets.exists(path))
    #end
    {
      path = Paths.getPreloadPath('characters/' + Character.DEFAULT_CHARACTER +
        '.json'); // If a character couldn't be found, change him to BF just to prevent a crash
      characterFailed = true;
    }

    #if MODS_ALLOWED
    var rawJson = File.getContent(path);
    #else
    var rawJson = OpenFlAssets.getText(path);
    #end
    return cast Json.parse(rawJson);
  }

  function updateNoteUI():Void
  {
    if (curSelectedNote != null)
    {
      if (curSelectedNote[2] != null)
      {
        var noteStepCrochet:Float = 15000 / secBPM(getSectionAtTime(curSelectedNote[0]));
        stepperSusLength.value = curSelectedNote[2] / noteStepCrochet;

        if (curSelectedNote[3] != null)
        {
          currentType = noteTypeMap.get(curSelectedNote[3]);
          if (currentType <= 0)
          {
            noteTypeDropDown.selectedLabel = '';
          } else
          {
            noteTypeDropDown.selectedLabel = currentType + '. ' + curSelectedNote[3];
          }
        }
      } else
      {
        eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
        var selected:Int = eventDropDown.selectedIndex;
        if (selected > 0 && selected < eventStuff.length)
        {
          descText.text = eventStuff[selected][1];
        }
        value1InputText.text = curSelectedNote[1][curEventSelected][1];
        value2InputText.text = curSelectedNote[1][curEventSelected][2];
      }
      strumTimeInputText.text = '' + curSelectedNote[0];
    }
  }

  var susMap:Map<Note, FlxSprite> = new Map();
  var presenceDirty:Bool = false;
  var lastPresenceUpdate:Float = 0;

  function destroyAll<T:flixel.FlxBasic>(group:FlxTypedGroup<T>):Void
  {
    for (member in group.members)
      if (member != null) member.destroy();
    group.clear();
  }

  function removeEventNotes(group:FlxTypedGroup<Note>):Void
  {
    var index:Int = group.members.length;
    while (index-- > 0)
    {
      var member:Note = group.members[index];
      if (member == null || member.noteData != -1) continue;
      group.remove(member, true);
      member.destroy();
    }
  }

  function refreshPresence():Void
  {
    #if DISCORD_ALLOWED
    if (!presenceDirty || haxe.Timer.stamp() - lastPresenceUpdate < 5) return;
    presenceDirty = false;
    lastPresenceUpdate = haxe.Timer.stamp();
    DiscordClient.changePresence("Chart Editor - Charting " + StringTools.replace(_song.song, '-', ' '),
      '${FlxStringUtil.formatMoney(CoolUtil.getNoteAmount(_song), false)} Notes');
    #end
  }

  function addNoteTypeText(note:Note, noteTypeName:String):Void
  {
    var typeInt:Null<Int> = noteTypeMap.get(noteTypeName);
    var theType:String = '' + typeInt;
    if (typeInt == null) theType = '?';

    var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
    daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    daText.xAdd = -32;
    daText.yAdd = 6;
    daText.borderSize = 1;
    curRenderedNoteType.add(daText);
    daText.sprTracker = note;
  }

  function updateGrid(?andNext:Bool = true, ?onlyEvents:Bool = false):Void
  {
    invalidateSectionTimes();
    presenceDirty = true;

    destroyAll(curRenderedEventText);
    if (onlyEvents)
    {
      removeEventNotes(curRenderedNotes);
      if (andNext) removeEventNotes(nextRenderedNotes);
    }

    var sectionStart:Float = sectionStartTime();
    var nextSectionStart:Float = sectionStartTime(1);

    if (!onlyEvents)
    {
      destroyAll(curRenderedNotes);
      destroyAll(curRenderedSustains);
      susMap.clear();
      destroyAll(curRenderedNoteType);
      if (andNext)
      {
        destroyAll(nextRenderedNotes);
        destroyAll(nextRenderedSustains);
      }

      var section = _song.notes[curSec];
      if (section != null)
      {
        if (section.changeBPM && section.bpm > 0) Conductor.changeBPM(section.bpm);
        else
          Conductor.changeBPM(secBPM(curSec - 1));

        var beats:Float = getSectionBeats();
        for (i in section.sectionNotes)
        {
          var note:Note = setupNoteData(i, false, sectionStart);
          curRenderedNotes.add(note);
          if (note.sustainLength > 0)
          {
            var sustain:FlxSprite = setupSusNote(note, beats);
            curRenderedSustains.add(sustain);
            susMap.set(note, sustain);
          }

          if (i[3] != null && note.noteType != null && note.noteType.length > 0) addNoteTypeText(note, i[3]);
          note.mustPress = section.mustHitSection;
          if (i[1] > 3) note.mustPress = !note.mustPress;
        }
      }
    }

    for (i in _song.events)
    {
      if (nextSectionStart > i[0] && i[0] >= sectionStart)
      {
        var note:Note = setupNoteData(i, false, sectionStart);
        curRenderedNotes.add(note);

        var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: '
          + note.eventVal2;
        if (note.eventLength > 1) text = note.eventLength + ' Events:\n' + note.eventName;

        var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
        daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
        daText.xAdd = -410;
        daText.borderSize = 1;
        if (note.eventLength > 1) daText.yAdd += 8;
        curRenderedEventText.add(daText);
        daText.sprTracker = note;
      }
    }

    if (andNext)
    {
      if (!onlyEvents && curSec < _song.notes.length - 1)
      {
        var beats:Float = getSectionBeats(1);
        for (i in _song.notes[curSec + 1].sectionNotes)
        {
          var note:Note = setupNoteData(i, true, sectionStart);
          note.alpha = 0.6;
          nextRenderedNotes.add(note);
          if (note.sustainLength > 0)
          {
            var sustain:FlxSprite = setupSusNote(note, beats);
            nextRenderedSustains.add(sustain);
            susMap.set(note, sustain);
          }
          note.mustPress = _song.notes[curSec+1].mustHitSection;
          if (i[1] > 3) note.mustPress = !note.mustPress;
        }
      }

      var afterNextSectionStart:Float = sectionStartTime(2);
      for (i in _song.events)
      {
        if (afterNextSectionStart > i[0] && i[0] >= nextSectionStart)
        {
          var note:Note = setupNoteData(i, true, sectionStart);
          note.alpha = 0.6;
          nextRenderedNotes.add(note);
        }
      }
    }
  }

  inline function setupNoteData(i:Array<Dynamic>, isNextSection:Bool, sectionStart:Float):Note
  {
    var daNoteInfo = i[1];
    var daStrumTime = i[0];
    var daSus:Dynamic = i[2];

    var note:Note = new Note(daStrumTime, daNoteInfo % 4);
    note.strumTime = daStrumTime;
    note.noteData = daNoteInfo % 4;
    if (daSus != null)
    { // Common note
      if (!Std.isOfType(i[3], String)) // Convert old note type to new note type format
      {
        i[3] = noteTypeIntMap.get(i[3]);
      }
      if (i.length > 3 && (i[3] == null || i[3].length < 1))
      {
        i.remove(i[3]);
      }
      note.sustainLength = daSus;
      note.noteType = i[3];
      note.animation.play(Note.colArray[daNoteInfo % 4] + 'Scroll');
      if (ClientPrefs.enableColorShader) note.updateRGBColors();
    } else
    { // Event note
      note.loadGraphic(Paths.image('eventArrow'));
      note.eventName = getEventName(i[1]);
      note.eventLength = i[1].length;
      if (i[1].length < 2)
      {
        note.eventVal1 = i[1][0][1];
        note.eventVal2 = i[1][0][2];
      }
      note.noteData = -1;
      daNoteInfo = -1;
      note.useRGBShader = false;
    }

    note.setGraphicSize(GRID_SIZE, GRID_SIZE);
    note.updateHitbox();
    note.x = Math.floor(daNoteInfo * GRID_SIZE) + GRID_SIZE;
    if (isNextSection && _song.notes[curSec].mustHitSection != _song.notes[curSec + 1].mustHitSection)
    {
      if (daNoteInfo > 3)
      {
        note.x -= GRID_SIZE * 4;
      } else if (daSus != null)
      {
        note.x += GRID_SIZE * 4;
      }
    }

    var beats:Float = getSectionBeats(isNextSection ? curSec + 1 : 0);
    note.y = getYfromStrumNotes(daStrumTime - sectionStart, beats);
    // if(isNextSection) note.y += gridBG.height;
    if (note.y < -150) note.y = -150;
    note.active = false;
    return note;
  }

  function getEventName(names:Array<Dynamic>):String
  {
    var retStr:String = '';
    var addedOne:Bool = false;
    for (i in 0...names.length)
    {
      if (addedOne) retStr += ', ';
      retStr += names[i][0];
      addedOne = true;
    }
    return retStr;
  }

  function setupSusNote(note:Note, beats:Float):FlxSprite
  {
    var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * 16, 0, GRID_SIZE * 16 * zoomList[curZoom])
      + (GRID_SIZE * zoomList[curZoom])
      - GRID_SIZE / 2);
    var minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
    if (height < minHeight) height = minHeight;
    if (height < 1) height = 1; // Prevents error of invalid height

    var color:FlxColor = (!PlayState.isPixelStage) ? ClientPrefs.arrowRGB[note.noteData][0] : ClientPrefs.arrowRGBPixel[note.noteData][0];

    if (ClientPrefs.enableColorShader) color = note.rgbShader.r; // Change it to the note's highlight color

    var spr:FlxSprite = makeSolid(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2, 8, height, color);
    spr.active = false;
    return spr;
  }

  private function addSection(sectionBeats:Float = 4):Void
  {
    var sec:SwagSection =
      {
        sectionBeats: (_song.notes[curSec] != null ? getSectionBeats() : sectionBeats),
        bpm: _song.bpm,
        changeBPM: false,
        mustHitSection: (_song.notes[curSec] != null ? _song.notes[curSec].mustHitSection : true),
        gfSection: false,
        sectionNotes: [],
        typeOfSection: 0,
        altAnim: false
      };

    _song.notes.push(sec);
    invalidateSectionTimes();
  }

  function selectNote(note:Note, ?updateTheGrid:Bool = true):Void
  {
    var noteDataToCheck:Int = note.noteData;

    if (noteDataToCheck > -1)
    {
      if (note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;
      for (i in _song.notes[curSec].sectionNotes)
      {
        if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == noteDataToCheck)
        {
          curSelectedNote = i;
          break;
        }
      }
    } else
    {
      for (i in _song.events)
      {
        if (i != curSelectedNote && i[0] == note.strumTime)
        {
          curSelectedNote = i;
          curEventSelected = Std.int(curSelectedNote[1].length) - 1;
          break;
        }
      }
    }
    changeEventSelected();

    if (updateTheGrid)
    {
      updateGrid(false);
      updateNoteUI();
    }
  }

  inline function deselectNote()
  {
      var selected = getSelectedNote();
      if (selected != null && selected.note != null)
          selected.note.color = 0xFFFFFFFE; //it cant be fully white, otherwise it doesnt update. sorry chat
  }

  function deleteNote(note:Note, ?usingVortex:Bool = false):Void
  {
    var noteDataToCheck:Int = note.noteData;
    if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;

    if (note.noteData > -1) // Normal Notes
    {
      for (i in _song.notes[curSec].sectionNotes)
      {
        if (i[0] == note.strumTime && i[1] == noteDataToCheck)
        {
          if (i == curSelectedNote) curSelectedNote = null;
          // FlxG.log.add('FOUND EVIL NOTE');
          _song.notes[curSec].sectionNotes.remove(i);
          break;
        }
      }
    } else // Events
    {
      for (i in _song.events)
      {
        if (i[0] == note.strumTime)
        {
          if (i == curSelectedNote)
          {
            curSelectedNote = null;
            changeEventSelected();
          }
          // FlxG.log.add('FOUND EVIL EVENT');
          _song.events.remove(i);
          break;
        }
      }
    }
    curRenderedNoteType.forEach(txt -> {
      if (txt.sprTracker == note)
      {
        curRenderedNoteType.remove(txt, true);
        txt.destroy();
      }
    });
    curRenderedEventText.forEach(txt -> {
      if (txt.sprTracker == note)
      {
        curRenderedEventText.remove(txt, true);
        txt.destroy();
      }
    });
    var sustain:FlxSprite = susMap.get(note);
    if (sustain != null)
    {
      curRenderedSustains.remove(sustain, true);
      susMap.remove(note);
      sustain.destroy();
    }
    curRenderedNotes.remove(note, true);
    note.destroy();

    unsavedChanges = true;
  }

  public function doANoteThing(cs, d, style)
  {
    var delnote = false;
    if (strumLineNotes.members[d].overlaps(curRenderedNotes))
    {
      curRenderedNotes.forEachAlive(function(note:Note) {
        if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1, strumLine.y + 1)) && note.noteData == d % 4)
        {
          // trace('tryin to delete note...');
          saveUndo(_song);
          if (!delnote) deleteNote(note, true);
          delnote = true;
        }
      });
    }

    if (!delnote)
    {
      saveUndo(_song);
      addNote(cs, d, style);
      updateNoteUI();
    }
  }

  function clearSong():Void
  {
    for (daSection in 0..._song.notes.length)
    {
      _song.notes[daSection].sectionNotes = [];
    }

    unsavedChanges = true;
    updateGrid();
  }

  private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null, ?gridUpdate:Bool = true):Void
  {
    var noteStrum = getStrumTime(selectionNote.y * (getSectionBeats() / 4), false) + sectionStartTime();
    var noteData:Int = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
    var noteSus = 0;
    var daAlt = false;
    var daType = currentType;
    var section = _song.notes[curSec];
    var mustPress:Bool = section.mustHitSection;
    if (noteData > 3) mustPress = !mustPress;

    if (strum != null) noteStrum = strum;
    if (data != null) noteData = data;
    if (type != null) daType = type;

    if (noteData > -1)
    {
      section.sectionNotes.push([noteStrum, noteData, noteSus, noteTypeIntMap.get(daType)]);
      curSelectedNote = section.sectionNotes[section.sectionNotes.length - 1];
    } else
    {
      var event = eventStuff[eventDropDown.selectedIndex][0];
      var text1 = value1InputText.text;
      var text2 = value2InputText.text;
      _song.events.push([noteStrum, [[event, text1, text2]]]);
      curSelectedNote = _song.events[_song.events.length - 1];
      curEventSelected = 0;
      changeEventSelected();
    }

    if (FlxG.keys.pressed.CONTROL && noteData > -1)
    {
      section.sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus, noteTypeIntMap.get(daType)]);
      updateGrid(false);
      updateNoteUI();
      unsavedChanges = true;
      return;
    }

    if (gridUpdate)
    {
      switch (noteData)
      {
        case -1:
          var note:Note = setupNoteData(curSelectedNote, false, sectionStartTime());
          curRenderedNotes.add(note);

          var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: '
            + note.eventVal2;
          if (note.eventLength > 1) text = note.eventLength + ' Events:\n' + note.eventName;

          var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
          daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
          daText.xAdd = -410;
          daText.borderSize = 1;
          if (note.eventLength > 1) daText.yAdd += 8;
          curRenderedEventText.add(daText);
          daText.sprTracker = note;
        // trace('test: ' + i[0], 'startThing: ' + startThing, 'endThing: ' + endThing);
        default:
          var beats:Float = getSectionBeats();
          var note:Note = setupNoteData(curSelectedNote, false, sectionStartTime());
          curRenderedNotes.add(note);
          if (note.sustainLength > 0)
          {
            var sustain:FlxSprite = setupSusNote(note, getSectionBeats());
            curRenderedSustains.add(sustain);
            susMap.set(note, sustain);
          }

          if (curSelectedNote[3] != null && note.noteType != null && note.noteType.length > 0)
          {
            var typeInt:Null<Int> = noteTypeMap.get(curSelectedNote[3]);
            var theType:String = '' + typeInt;
            if (typeInt == null) theType = '?';

            var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
            daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            daText.xAdd = -32;
            daText.yAdd = 6;
            daText.borderSize = 1;
            curRenderedNoteType.add(daText);
            daText.sprTracker = note;
          }
          note.mustPress = mustPress;
      }
    }
    unsavedChanges = true;
  }

  function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
  {
    var leZoom:Float = zoomList[curZoom];
    if (!doZoomCalc) leZoom = 1;
    return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * leZoom, 0, 16 * Conductor.stepCrochet);
  }

  function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
  {
    var leZoom:Float = zoomList[curZoom];
    if (!doZoomCalc) leZoom = 1;
    return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * leZoom);
  }

  function getYfromStrumNotes(strumTime:Float, beats:Float):Float
  {
    var value:Float = strumTime / (beats * 4 * Conductor.stepCrochet);
    return GRID_SIZE * beats * 4 * zoomList[curZoom] * value + gridBG.y;
  }

  public function saveUndo(_song:SwagSong)
  {
    if (CoolUtil.getNoteAmount(_song) <= 50000 && FlxG.save.data.allowUndo)
    {
      var shit = Json.stringify(
        { // doin this so it doesnt act as a reference
          "song": _song
        });
      if (lastUndoShit == shit) return;
      lastUndoShit = shit;
      var song:SwagSong = Song.parseJSON(shit);

      undos.unshift(song.notes);
      redos = []; // Reset redos
      if (undos.length > 50) // keep at most 50 undos, drop the oldest (last element after unshift)
        undos.pop();
    }
  }

  public function undo()
  {
    if (undos.length > 0 && saveUndoCheck.checked)
    {
      _song.notes = undos[0];
      invalidateSectionTimes();
      redos.unshift(undos[0]);
      undos.splice(0, 1);
      lastUndoShit = null;
      trace("Performed an Undo! Undos remaining: " + undos.length);
      unsavedChanges = true;
      if (curSec > _song.notes.length) changeSection(_song.notes.length - 1);
      updateGrid();
    }
  }

  function getSelectedNote():SelectedNoteData
  {
    var section = _song.notes[curSec];
    if (curSelectedNote == null || section == null) return null;

    var isNote:Bool = curSelectedNote[2] != null;
    var time:Float = curSelectedNote[0];
    var data:Int = isNote ? curSelectedNote[1] : -1;

    var note = checkGroupForNote(curRenderedNotes, time, data, section.mustHitSection, isNote);
    if (note != null)
      return {note: note, group: curRenderedNotes};
    else if (_song.notes[curSec + 1] != null)
    {
      note = checkGroupForNote(nextRenderedNotes, time, data, _song.notes[curSec + 1].mustHitSection, isNote);
      if (note != null) return {note: note, group: nextRenderedNotes};
    }

    return null;
  }

  //Helper code to check if a group has a selected note.
  function checkGroupForNote(group:FlxTypedGroup<Note>, time:Float, data:Int, mustHit:Bool, isNote:Bool):Note
  {
    for (i in group.members)
    {
      if (i == null || !i.exists || i.strumTime != time) continue;

      var noteData:Int = i.noteData;
      if (noteData > -1 && i.mustPress != mustHit) noteData += 4;

      if (isNote ? noteData == data : noteData < 0) return i;
    }
    return null;
  }

  function refreshSelectedSustain():Void
  {
    if (curSelectedNote[2] == null) return;

    var selected = getSelectedNote();
    if (selected == null) return;

    var note = selected.note;
    var susGrp = selected.group == curRenderedNotes ? curRenderedSustains : nextRenderedSustains;

    var oldSustain:FlxSprite = susMap.get(note);
    if (oldSustain != null)
    {
      susGrp.remove(oldSustain, true);
      susMap.remove(note);
    }

    note.sustainLength = curSelectedNote[2];
    if (note.sustainLength > 0)
    {
      var sustain:FlxSprite = setupSusNote(note, getSectionBeats());
      susGrp.add(sustain);
      susMap.set(note, sustain);
    }
  }

  function loadJson(song:String, ?diff:String = ''):Void
  {
    // shitty null fix, i fucking hate it when this happens
    // make it look sexier if possible
    var songName:String = Paths.formatToSongPath(_song.song);
    var jsonExists = sys.FileSystem.exists(Paths.json(songName + '/' + songName))
      || sys.FileSystem.exists(Paths.modsJson(songName + '/' + songName));
    var diffJsonExists = sys.FileSystem.exists(Paths.json(songName + '/' + songName + '-$diff'))
      || sys.FileSystem.exists(Paths.modsJson(songName + '/' + songName + '-$diff'));
    if (jsonExists || diffJsonExists)
    {
      if (diff != CoolUtil.defaultDifficulty.toLowerCase())
      {
        if (CoolUtil.difficulties[PlayState.storyDifficulty] == null || !diffJsonExists)
        {
          PlayState.SONG = Song.loadFromJson(songName.toLowerCase(), songName.toLowerCase());
        } else
        {
          PlayState.SONG = Song.loadFromJson(songName.toLowerCase() + "-" + diff, songName.toLowerCase());
        }
      } else
      {
        PlayState.SONG = Song.loadFromJson(songName.toLowerCase(), songName.toLowerCase());
      }
      CoolUtil.currentDifficulty = diff;
      FlxG.resetState();
      if (idleMusic != null && idleMusic.music != null) idleMusic.destroy();
    } else
    {
      trace(songName + "'s JSON doesn't exist!");
      songJsonPopup(); // HAH, IT AINT CRASHING NOW
    }
  }

  function clearEvents()
  {
    _song.events = [];
    unsavedChanges = true;
    updateGrid();
  }

  private function saveLevel(?compressed:Bool = false, ?isAuto:Bool = false)
  {
    Paths.gc(true);
    if (CoolUtil.getNoteAmount(_song) > 1000000)
    {
      cpp.vm.Gc.enable(false);
    }
    if (_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);

    final json =
      {
        "song": _song
      };

    final data:String = !compressed ? Json.stringify(json, "\t") : Json.stringify(json);

    if ((data != null) && (data.length > 0))
    {
      var gamingName:String = Paths.formatToSongPath(_song.song);

      if (difficulty.toLowerCase() != 'normal') gamingName = gamingName + '-' + Paths.formatToSongPath(difficulty);

      if (!isAuto)
      {
        _file = new FileReference();
        _file.addEventListener(Event.COMPLETE, onSaveComplete);
        _file.addEventListener(Event.CANCEL, onSaveCancel);
        _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);

        _file.save(data.trim(), gamingName + ".json");
      } else
      {
        // create backups folder if it doesn't exist yet
        if (!FileSystem.exists('backups/'))
        {
          FileSystem.createDirectory("backups/");
          File.saveContent('backups/README.txt',
            "This is where your backups are stored.\nIf your engine freezes/crashes and you didn't save it, you will be happy that the backups are now stored in there instead of the single autosave so you can restore it whenever you want!");
        }

        // Get list of backup files
        var backups = FileSystem.readDirectory('backups/')
          .filter(f -> f.endsWith(".json"))
          .map(f -> 'backups/' + f)
          .filter(f -> FileSystem.exists(f) && !FileSystem.isDirectory(f));

        // Then, sort by modification time (oldest first)
        backups.sort((a, b) -> {
          return FlxSort.byValues(FlxSort.ASCENDING, FileSystem.stat(a).mtime.getTime(), FileSystem.stat(b).mtime.getTime());
        });

        // If the limit is exceeded, delete the oldest backups.
        while (backups.length >= 5)
          FileSystem.deleteFile(backups.shift());

        var dateNow:String = Date.now().toString();
        dateNow = dateNow.replace(" ", "_");
        dateNow = dateNow.replace(":", "'");

        File.saveContent('backups/${gamingName}_$dateNow.json', data.trim());
      }
    }

    cpp.vm.Gc.enable(true);
    unsavedChanges = false;
    if (autoSaveTimer != null) autoSaveTimer.reset(autoSaveLength);
  }

  function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
  {
    return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
  }

  private function saveEvents()
  {
    if (_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
    var eventsSong:Dynamic =
      {
        events: _song.events
      };
    var json =
      {
        "song": eventsSong
      }

    var data:String = Json.stringify(json, "\t");

    if ((data != null) && (data.length > 0))
    {
      _file = new FileReference();
      _file.addEventListener(Event.COMPLETE, onSaveComplete);
      _file.addEventListener(Event.CANCEL, onSaveCancel);
      _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
      _file.save(data.trim(), "events.json");
    }
  }

  function onSaveComplete(_):Void
  {
    _file.removeEventListener(Event.COMPLETE, onSaveComplete);
    _file.removeEventListener(Event.CANCEL, onSaveCancel);
    _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    _file = null;
    FlxG.log.notice("Successfully saved LEVEL DATA.");
  }

  /**
   * Called when the save file dialog is cancelled.
   */
  function onSaveCancel(_):Void
  {
    _file.removeEventListener(Event.COMPLETE, onSaveComplete);
    _file.removeEventListener(Event.CANCEL, onSaveCancel);
    _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    _file = null;
  }

  /**
   * Called if there is an error while saving the gameplay recording.
   */
  function onSaveError(_):Void
  {
    _file.removeEventListener(Event.COMPLETE, onSaveComplete);
    _file.removeEventListener(Event.CANCEL, onSaveCancel);
    _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    _file = null;
    FlxG.log.error("Problem saving Level data");
  }

  function getSectionBeats(?section:Null<Int> = null)
  {
    if (section == null) section = curSec;
    var val:Null<Float> = null;

    if (_song.notes[section] != null) val = _song.notes[section].sectionBeats;
    return val != null ? val : 4;
  }

  override public function onFocusLost():Void
  {
    if (idleMusic != null && idleMusic.music != null) idleMusic.pauseMusic();

    super.onFocusLost();
  }

  override public function onFocus():Void
  {
    if (idleMusic != null && idleMusic.music != null) idleMusic.unpauseMusic();

    super.onFocus();
  }

  override public function destroy():Void
  {
    Paths.noteSkinFramesMap.clear();
    Paths.noteSkinAnimsMap.clear();
    Paths.splashSkinFramesMap.clear();
    Paths.splashSkinAnimsMap.clear();
    Paths.splashConfigs.clear();
    Paths.splashAnimCountMap.clear();
    Note.globalRgbShaders = [];
    RGBPalettePool.clear();
    FlxG.autoPause = ClientPrefs.autoPause;

    super.destroy();
  }
}

class AttachedFlxText extends FlxText
{
  public var sprTracker:FlxSprite;
  public var xAdd:Float = 0;
  public var yAdd:Float = 0;

  public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true)
  {
    super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);

    if (sprTracker != null)
    {
      setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
      angle = sprTracker.angle;
      alpha = sprTracker.alpha;
    }
  }
}

class SelectionNote extends FlxSprite
{
  public var rgbShader:RGBShaderReference;
  public var resetAnim:Float = 0;
  public var noteData:Int = 0;
  public var size:Int = 40;
  public var useRGBShader:Bool = true;

  public var texture(default, set):String = null;

  private function set_texture(value:String):String
  {
    if (texture != value)
    {
      texture = (value != null ? value : "NOTE_assets");
      reloadNote();
    }
    return value;
  }

  public function new(x:Float, y:Float, leData:Int)
  {
    rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
    rgbShader.enabled = false;
    if (PlayState.SONG != null && PlayState.SONG.disableNoteRGB || !ClientPrefs.enableColorShader) useRGBShader = false;
    var arr:Array<FlxColor> = ClientPrefs.arrowRGB[leData];
    if (PlayState.isPixelStage) arr = ClientPrefs.arrowRGBPixel[leData];
    if (leData <= arr.length && useRGBShader)
    {
      @:bypassAccessor
      {
        rgbShader.r = arr[0];
        rgbShader.g = arr[1];
        rgbShader.b = arr[2];
      }
    }
    noteData = leData;
    super(x, y);

    scrollFactor.set(1, 1);
  }

  public function reloadNote()
  {
    var lastAnim:String = null;
    if (animation.curAnim != null) lastAnim = animation.curAnim.name;

    if (PlayState.isPixelStage)
    {
      loadGraphic(Paths.image('pixelUI/' + texture));
      width = width / 4;
      height = height / 5;
      loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

      antialiasing = false;
      setGraphicSize(size, size);

      animation.add('static0', [0]);
      animation.add('pressed0', [4, 8], 12, false);
      animation.add('confirm0', [12, 16], 24, false);
      animation.add('static1', [1]);
      animation.add('pressed1', [5, 9], 12, false);
      animation.add('confirm1', [13, 17], 24, false);
      animation.add('static2', [2]);
      animation.add('pressed2', [6, 10], 12, false);
      animation.add('confirm2', [14, 18], 12, false);
      animation.add('static3', [3]);
      animation.add('pressed3', [7, 11], 12, false);
      animation.add('confirm3', [15, 19], 24, false);
    } else
    {
      frames = Paths.getSparrowAtlas(texture);

      antialiasing = ClientPrefs.globalAntialiasing;
      setGraphicSize(size, size);

      animation.addByPrefix('static0', 'arrowLEFT');
      animation.addByPrefix('pressed0', 'left press', 24, false);
      animation.addByPrefix('confirm0', 'left confirm', 24, false);
      animation.addByPrefix('static1', 'arrowDOWN');
      animation.addByPrefix('pressed1', 'down press', 24, false);
      animation.addByPrefix('confirm1', 'down confirm', 24, false);
      animation.addByPrefix('static2', 'arrowUP');
      animation.addByPrefix('pressed2', 'up press', 24, false);
      animation.addByPrefix('confirm2', 'up confirm', 24, false);
      animation.addByPrefix('static3', 'arrowRIGHT');
      animation.addByPrefix('pressed3', 'right press', 24, false);
      animation.addByPrefix('confirm3', 'right confirm', 24, false);
    }
    updateHitbox();

    if (lastAnim != null)
    {
      playAnim(lastAnim, true);
    }
    animation.callback = function(name:String, frameNumber:Int, frameIndex:Int) {
      if (name != 'confirm' + noteData) return;
      centerOrigin();
    }
  }

  override function update(elapsed:Float)
  {
    if (ClientPrefs.ffmpegMode) elapsed = 1 / ClientPrefs.targetFPS;
    if (resetAnim > 0)
    {
      resetAnim -= elapsed;
      if (resetAnim <= 0)
      {
        playAnim('static' + noteData);
        resetAnim = 0;
      }
    }
    super.update(elapsed);
  }

  public function playAnim(anim:String, ?force:Bool = false)
  {
    animation.play(anim, force);
    if (animation.curAnim != null)
    {
      centerOffsets();
      centerOrigin();
    }
    resetAnim = 0.15;
    if (rgbShader != null && useRGBShader)
    {
      rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != 'static');
      updateRGBColors();
    }
  }

  public function updateRGBColors()
  {
    if (rgbShader == null || rgbShader != null && !rgbShader.enabled) return;

    var arr:Array<FlxColor> = ClientPrefs.arrowRGB[noteData];
    if (PlayState.isPixelStage) arr = ClientPrefs.arrowRGBPixel[noteData];
    if (noteData <= arr.length)
    {
      @:bypassAccessor
      {
        rgbShader.r = arr[0];
        rgbShader.g = arr[1];
        rgbShader.b = arr[2];
      }
    }
  }
}