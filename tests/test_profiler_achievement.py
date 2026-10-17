"""Regression tests for the first-use frame profiler achievement."""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ProfilerAchievementTests(unittest.TestCase):
    def test_mr_robot_achievement_and_art_are_registered(self):
        achievements = (ROOT / "source/backend/Achievements.hx").read_text(encoding="utf-8")
        self.assertIn("createAchievement('mr_robot'", achievements)
        self.assertTrue((ROOT / "assets/preload/images/achievements/mr_robot.png").is_file())

    def test_badge_unlocks_when_profiler_overlay_is_opened(self):
        profiler = (ROOT / "source/debug/FrameProfiler.hx").read_text(encoding="utf-8")
        self.assertIn("awardFirstUseAchievement();", profiler)
        self.assertIn('Achievements.unlock("mr_robot")', profiler)
        self.assertIn("if (overlayVisible)\n      awardFirstUseAchievement();", profiler)


if __name__ == "__main__":
    unittest.main(verbosity=2)
