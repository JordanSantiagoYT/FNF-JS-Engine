"""Widescreen rendering/resize integration guards (no Haxe SDK required).

The Haxe math itself is exercised by tests/haxe/LayoutSpec.hx in the CI job.
These tests protect the camera, HUD, mobile, menu, shader and capture call
sites, so a future refactor cannot accidentally restore 16:9-only paths.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(name: str) -> str:
    return (ROOT / "source" / name).read_text(encoding="utf-8-sig")


class WidescreenIntegration(unittest.TestCase):
    def test_preference_is_persistent_and_applies_at_startup_and_live(self):
        prefs = source("backend/ClientPrefs.hx")
        scale = source("source-haxelib-patches/flixel/system/scaleModes/PhoenixScaleMode.hx")
        main = source("Main.hx")
        graphics = source("options/GraphicsSettingsSubState.hx")
        self.assertIn("public static var widescreen:Bool = false;", prefs)
        self.assertIn("applyWidescreenPreference();", prefs)
        self.assertIn("FlxG.game.onResize(null)", prefs)
        self.assertIn("ScreenLayout.viewportWidth(Width, Height, ClientPrefs.widescreen)", scale)
        self.assertIn("FlxG.height = ScreenLayout.BASE_HEIGHT", scale)
        self.assertIn("gameSize.set(Width, Height)", scale)  # no one-pixel bar from aspect rounding
        self.assertIn("else updateGameSize(Width, Height)", scale)  # 16:9 fallback
        self.assertIn("FlxG.scaleMode = new PhoenixScaleMode()", main)
        self.assertLess(main.index("addChild(funkinGame);"), main.index("FlxG.scaleMode = new PhoenixScaleMode()"))
        self.assertIn("'widescreen', 'bool', false", graphics)
        self.assertIn("ClientPrefs.applyWidescreenPreference()", graphics)
        self.assertIn("ClientPrefs.saveSettings()", graphics)

    def test_resize_updates_cameras_and_notifies_open_substate(self):
        game = source("source-haxelib-patches/flixel/FlxGame.hx")
        self.assertIn("if (width <= 0 || height <= 0) return", game)
        self.assertIn("camera.width == oldWidth && camera.height == oldHeight", game)
        self.assertIn("camera.setSize(FlxG.width, FlxG.height)", game)
        self.assertIn("camera.scroll.x -= (FlxG.width - oldWidth) * 0.5", game)
        self.assertIn("_state.subState.onResize(width, height)", game)
        self.assertLess(game.index("camera.setSize(FlxG.width, FlxG.height)"),
                        game.index("FlxG.signals.gameResized.dispatch(width, height)"))
        self.assertIn("FlxG.worldBounds.width == oldWidth + 20", game)
        self.assertIn("FlxG.worldBounds.set(-10, -10, FlxG.width + 20, FlxG.height + 20)", game)

    def test_gameplay_reflow_tracks_strums_and_existing_notes(self):
        strums = source("objects/StrumNote.hx")
        notes = source("play/helpers/PlayStateNoteHelpers.hx")
        layout = source("play/helpers/PlayStateLayout.hx")
        state = source("play/PlayState.hx")
        self.assertIn("ScreenLayout.contentLeft(FlxG.width)", strums)
        self.assertIn("ScreenLayout.BASE_WIDTH / 2", strums)
        self.assertNotIn("(FlxG.width / 2) * player", strums)
        self.assertIn("ScreenLayout.BASE_WIDTH / 2 + 25", notes)
        self.assertIn("strum.x += shift", layout)
        self.assertIn("note.x += shift", layout)
        self.assertIn("popup.x += shift", layout)
        self.assertIn("state.stages", layout)
        self.assertIn("PlayStateLayout.resize(this, layoutWidth)", state)
        self.assertIn("layoutWidth = FlxG.width", state)
        self.assertIn("ScreenLayout.contentLeft(FlxG.width)", source("objects/Popup.hx"))
        self.assertIn("ScreenLayout.contentLeft(FlxG.width)", source("play/objects/MSText.hx"))

    def test_touch_boundaries_survive_odd_widths_and_resizes(self):
        hitbox = source("mobile/flixel/FlxHitbox.hx")
        pad = source("mobile/flixel/FlxVirtualPad.hx")
        controls = source("mobile/MobileControls.hx")
        self.assertIn("ScreenLayout.laneStart(i + 1, laneCount, width)", hitbox)
        self.assertIn("hint.loadGraphic(createHintGraphic(end - start, mainHeight", hitbox)
        self.assertIn("FlxG.signals.gameResized.add(onGameResized)", hitbox)
        self.assertIn("FlxG.signals.gameResized.remove(onGameResized)", hitbox)
        self.assertIn("ScreenLayout.anchoredPosition(button.x, layoutWidth, FlxG.width, button.width)", pad)
        self.assertIn("layoutWidth = FlxG.width", pad)
        self.assertIn("(DPad == LEFT_FULL) ? FlxG.width - 131 : 0", pad)
        self.assertIn("createButton(FlxG.width - 135", pad)
        self.assertIn("FlxG.signals.gameResized.remove(onGameResized)", pad)
        self.assertIn("buttonsWidth", controls)
        self.assertIn("ScreenLayout.anchoredPosition(", controls)

    def test_menus_reflow_art_and_menu_item_targets(self):
        for name in ("states/MainMenuState.hx", "states/FreeplayState.hx",
                     "options/OptionsState.hx", "options/BaseOptionsMenu.hx",
                     "states/TitleState.hx", "editors/EditorPlayState.hx"):
            with self.subTest(name=name):
                text = source(name)
                self.assertIn("ViewportVisuals.cover(", text)
                self.assertRegex(text, r"function onResize\(width:Int, height:Int\)")
        for name in ("states/FreeplayState.hx", "options/BaseOptionsMenu.hx",
                     "states/substates/PauseSubState.hx",
                     "states/substates/GameplayChangersSubstate.hx"):
            with self.subTest(name=name):
                self.assertIn("item.startPosition.x += shift", source(name))
        for name in ("states/AchievementsMenuState.hx", "states/CreditsState.hx",
                     "states/ModsMenuState.hx", "states/ErrorState.hx",
                     "states/OutdatedState.hx", "options/NotesSubState.hx"):
            with self.subTest(name=name):
                self.assertIn("ViewportVisuals.cover(", source(name))
                self.assertIn("function onResize(width:Int, height:Int)", source(name))
        self.assertIn("ViewportVisuals.fill(bgYellow, 386)", source("states/StoryMenuState.hx"))
        self.assertIn("ViewportVisuals.fill(background)", source("states/substates/PauseSubState.hx"))
        self.assertIn("ViewportVisuals.fill(background)", source("states/FlashingState.hx"))
        self.assertIn("ViewportVisuals.fill(blackBox, 40)", source("options/NoteOffsetState.hx"))
        self.assertIn("ScreenLayout.BASE_WIDTH * 0.65", source("objects/Alphabet.hx"))

    def test_effects_and_raw_capture_follow_real_viewport(self):
        shader = source("shaders/ThreeDShader.hx")
        self.assertIn("openfl_TextureSize.x / max(openfl_TextureSize.y, 1.0)", shader)
        self.assertNotIn("1280.0/720.0", shader)
        video = source("objects/VideoSprite.hx")
        self.assertIn("Math.max(FlxG.width / width, FlxG.height / height)", video)
        self.assertIn("FlxG.signals.gameResized.remove(onGameResized)", video)
        for name in ("stages/StageWeek1.hx", "stages/Spooky.hx", "stages/Philly.hx",
                     "stages/Mall.hx", "stages/School.hx", "stages/SchoolEvil.hx"):
            with self.subTest(name=name):
                self.assertIn("ViewportVisuals.overscan(", source(name))
        for name in ("stages/PhillyBlazin.hx", "stages/PhillyStreets.hx",
                     "stages/PhillyStreetsBF.hx"):
            with self.subTest(name=name):
                self.assertIn("override public function onViewportResize()", source(name))
                self.assertIn("scrollingSky.width = Math.max(", source(name))
                self.assertIn("onViewportResize();", source(name))
        render = source("play/helpers/PlayStateRender.hx")
        self.assertIn("state.img = window.readPixels()", render)
        self.assertIn("state.img.width != state.renderWidth", render)
        self.assertNotIn("FlxG.scaleMode.gameSize", render)
        screenshot = source("backend/SSPlugin.hx")
        self.assertIn("FlxG.signals.gameResized.add(resizeBitmap)", screenshot)
        self.assertIn("lastWidth = FlxG.stage.stageWidth", screenshot)
        self.assertNotIn("window.onResize.add(", screenshot)


if __name__ == "__main__":
    unittest.main()
