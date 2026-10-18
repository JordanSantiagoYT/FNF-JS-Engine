"""Source-contract regressions for mobile note-action routing.

Run with the normal Python regression suite; no Haxe toolchain is required.
These checks do not replace testing native touch input on an Android/iOS build.
"""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class MobileHitboxInputTests(unittest.TestCase):
    def setUp(self):
        source = read("source/play/helpers/PlayStateInput.hx")
        self.handle_input = source.split("public static function handleKeyInput", 1)[1].split(
            "public static function parseKeys", 1
        )[0]
        self.parse_keys = source.split("public static function parseKeys", 1)[1]

    def test_mobile_presses_do_not_require_controller_mode(self):
        # Default mobile settings must reach the press loop, not just holds/releases.
        self.assertRegex(
            self.handle_input,
            r"if\s*\(ClientPrefs\.controllerMode\s*\|\|\s*mobile\.MobileControls\.enabled\)"
            r"\s*\{\s*for\s*\(i in 0\.\.\.state\.pressArray\.length\)",
        )
        self.assertRegex(
            self.handle_input,
            r"state\.pressArray\[i\]\s*&&\s*state\.strumsBlocked\[i\]\s*!=\s*true",
        )

    def test_polled_actions_use_lanes_not_synthetic_keyboard_events(self):
        # Touch/gamepad input must also work with NONE or empty keyboard bindings.
        self.assertRegex(self.handle_input, r"keyPressed\(state,\s*i\);")
        self.assertRegex(self.handle_input, r"keyReleased\(state,\s*i\);")
        self.assertNotIn("new KeyboardEvent", self.handle_input)
        self.assertNotRegex(self.handle_input, r"state\.keysArray\[i\]\[0\]")
        self.assertNotRegex(self.handle_input, r"onKey(?:Press|Release)\(state,")

    def test_mobile_polling_does_not_duplicate_physical_keyboard_callbacks(self):
        # Keyboard events already hit/release notes when controller mode is off.
        # Controller mode, by contrast, relies entirely on the polled actions.
        for status in ("Pressed", "Released"):
            with self.subTest(status=status):
                self.assertRegex(
                    self.handle_input,
                    r"ClientPrefs\.controllerMode\s*\|\|\s*!FlxG\.keys\.anyJust"
                    + status
                    + r"\(state\.keysArray\[i\]\)",
                )

    def test_same_lane_multitouch_uses_aggregate_contact_state(self):
        button = read("source/mobile/flixel/FlxButton.hx")
        touch_update = button.split("function updateMultiTouch():Void", 1)[1].split(
            "function checkTouchOverlap():Bool", 1
        )[0]
        self.assertIn("if (multiTouch)", button)
        self.assertIn("updateMultiTouch();", button)
        self.assertIn("if (!touch.pressed && !touch.justReleased) continue;", touch_update)
        self.assertIn("HitboxTouchLogic.transition(status == FlxButton.PRESSED", touch_update)
        self.assertIn("if (action == HitboxTouchLogic.PRESS)", touch_update)
        self.assertIn("else if (action == HitboxTouchLogic.RELEASE)", touch_update)
        self.assertIn("hint.multiTouch = true;", read("source/mobile/flixel/FlxHitbox.hx"))

    def test_extra_hint_keeps_the_full_height_touchable_on_resize(self):
        hitbox = read("source/mobile/flixel/FlxHitbox.hx")
        self.assertIn("ScreenLayout.hitboxExtraHeight(height, ClientPrefs.mobileCEx)", hitbox)
        self.assertIn("if (extraHeight > 0 && hints.length == laneCount)", hitbox)
        self.assertIn("else if (extraHeight == 0 && hints.length > laneCount)", hitbox)
        self.assertIn("extra.visible = hints[0].visible;", hitbox)
        self.assertIn("remove(extra, true);", hitbox)
        self.assertIn("hint.setPosition(start, mainY);", hitbox)
        self.assertIn("extra.setPosition(0, ClientPrefs.hitboxPos ? mainHeight : 0);", hitbox)

    def test_all_four_hitbox_lanes_keep_press_hold_and_release_bindings(self):
        controls = read("source/backend/Controls.hx")
        hitbox_bindings = controls.split("public function setHitBox", 1)[1].split(
            "public function setVirtualPadUI", 1
        )[0]
        for lane, direction in enumerate(("LEFT", "DOWN", "UP", "RIGHT")):
            with self.subTest(lane=lane):
                self.assertIn(f"Control.NOTE_{direction}", hitbox_bindings)
                self.assertIn(f"addButtonNOTES(action, Hitbox.hints[{lane}], state)", hitbox_bindings)
                for suffix in ("", "_P", "_R"):
                    self.assertIn(
                        f"ret[{lane}] = state.controls.NOTE_{direction}{suffix};", self.parse_keys
                    )
        self.assertIn("parseKeys(state, state.holdArray);", self.handle_input)
        self.assertIn("parseKeys(state, state.pressArray, '_P');", self.handle_input)
        self.assertIn("parseKeys(state, state.releaseArray, '_R');", self.handle_input)


if __name__ == "__main__":
    unittest.main(verbosity=2)
