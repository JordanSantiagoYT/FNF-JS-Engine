"""Regression tests for the cumulative playtime achievement."""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class PlaytimeAchievementTests(unittest.TestCase):
    def test_get_a_job_definition_uses_the_lol_icon_and_50_hour_goal(self):
        achievements = read("source/backend/Achievements.hx")
        self.assertIn("createAchievement('lol'", achievements)
        self.assertIn('name: "Get a Job!"', achievements)
        self.assertIn('description: "Play the game for 50 hours."', achievements)
        self.assertIn("maxScore: 50, maxDecimals: 2", achievements)
        self.assertTrue((ROOT / "assets/preload/images/achievements/lol.png").is_file())

    def test_global_tracker_accumulates_and_saves_playtime(self):
        tracker = read("source/backend/PlaytimeTracker.hx")
        self.assertIn("class PlaytimeTracker extends FlxBasic", tracker)
        self.assertIn("pendingSeconds += elapsed", tracker)
        self.assertIn("pendingSeconds / 3600 >= TARGET_HOURS", tracker)
        self.assertIn("pendingSeconds >= SAVE_INTERVAL_SECONDS", tracker)
        self.assertIn("Achievements.addScore(ACHIEVEMENT_ID, elapsedHours, false)", tracker)
        self.assertIn("Application.current.onExit.add(onApplicationExit)", tracker)
        self.assertIn("FlxG.save.flush()", tracker)

    def test_tracker_is_registered_after_saved_achievements_load(self):
        init_state = read("source/states/InitState.hx")
        self.assertLess(
            init_state.index("ClientPrefs.loadPrefs();"),
            init_state.index("FlxG.plugins.addIfUniqueType(new PlaytimeTracker());"),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
