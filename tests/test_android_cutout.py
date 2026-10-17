"""Source integration checks; device acceptance steps are in docs/ANDROID_CUTOUT.md."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CutoutIntegration(unittest.TestCase):
    def test_preference_is_saved_by_existing_reflection_and_applied_on_load(self):
        prefs = (ROOT / 'source/backend/ClientPrefs.hx').read_text()
        self.assertIn('public static var respectCutout:Bool = true;', prefs)
        self.assertIn('Reflect.setField(FlxG.save.data, field', prefs)
        load = prefs.split('public static function loadPrefs()', 1)[1]
        self.assertIn('applyCutoutPreference();', load)
        self.assertIn('respectCutout ? "never" : "always"', prefs)

    def test_menu_applies_and_flushes_immediately(self):
        menu = (ROOT / 'source/options/VisualsUISubState.hx').read_text()
        block = menu.split('var cutoutOption', 1)[1].split('#end', 1)[0]
        self.assertIn("'respectCutout', 'bool', true", block)
        self.assertIn('ClientPrefs.applyCutoutPreference();', block)
        self.assertIn('ClientPrefs.saveSettings();', block)

    def test_native_version_fallback_and_relayout(self):
        java = (ROOT / 'source/android/src/quack/fnf/phoenix/android/PhoenixDisplay.java').read_text()
        setter = java.split('public static void setCutoutMode', 1)[1].split('public static void setPreferredRefreshRate', 1)[0]
        self.assertIn('Build.VERSION_CODES.P', setter)
        self.assertIn('"always".equals(mode) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R', setter)
        self.assertIn('"shortEdges".equals(mode) || "always".equals(mode)', setter)
        self.assertIn('Build.VERSION.SDK_INT >= 35', setter)
        self.assertIn('updateCutoutPadding(activity, "never".equals(mode))', setter)
        self.assertIn('requestApplyInsets()', setter)
        self.assertIn('setOnApplyWindowInsetsListener', java)
        for edge in ('Left', 'Top', 'Right', 'Bottom'):
            self.assertIn(f'cutout.getSafeInset{edge}()', java)


if __name__ == '__main__':
    unittest.main()
