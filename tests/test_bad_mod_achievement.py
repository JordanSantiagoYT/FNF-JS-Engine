"""Regression tests for the invalid-mod achievement and achievement icon sizing."""
from __future__ import annotations

import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACHIEVEMENT_ICONS = ROOT / "assets/preload/images/achievements"

# Every award icon must use the same 150x150 canvas as the original set.
ICON_SIZE = (150, 150)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    assert header[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG"
    return struct.unpack(">II", header[16:24])


class BadModAchievementTests(unittest.TestCase):
    def test_bad_mod_definition_is_registered(self):
        achievements = read("source/backend/Achievements.hx")
        self.assertIn("createAchievement('bad_mod'", achievements)
        self.assertIn('name: "Bad Mod"', achievements)
        self.assertIn('description: "Add a mod with invalid data."', achievements)

    def test_bad_mod_icon_exists(self):
        self.assertTrue((ACHIEVEMENT_ICONS / "bad_mod.png").is_file())

    def test_invalid_mod_data_is_tracked_and_unlocks_the_badge(self):
        mods = read("source/backend/Mods.hx")
        self.assertIn("public static var invalidMods:Array<String> = [];", mods)
        self.assertIn("public static function markInvalidMod(", mods)
        self.assertIn("Achievements.unlock('bad_mod')", mods)
        # pack.json that cannot be parsed is the "invalid data" trigger
        catch_index = mods.index("markInvalidMod(folder);")
        self.assertGreater(catch_index, mods.index("tjson.TJSON.parse(rawJson)"))

    def test_invalid_modded_achievements_are_flagged(self):
        achievements = read("source/backend/Achievements.hx")
        self.assertGreaterEqual(achievements.count("Mods.markInvalidMod()"), 2)

    def test_badge_is_rechecked_when_the_main_menu_opens(self):
        main_menu = read("source/states/MainMenuState.hx")
        self.assertIn("if (Mods.invalidMods.length > 0) Achievements.unlock('bad_mod');", main_menu)


class AchievementIconSizeTests(unittest.TestCase):
    def test_every_award_icon_uses_the_150x150_canvas(self):
        icons = sorted(ACHIEVEMENT_ICONS.glob("*.png"))
        self.assertTrue(icons, "no achievement icons found")
        for icon in icons:
            with self.subTest(icon=icon.name):
                self.assertEqual(png_size(icon), ICON_SIZE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
