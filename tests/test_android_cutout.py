"""Source contracts and host-JVM behavior; not Android rendering/input tests."""
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

    def test_native_lifecycle_and_listener_ownership_contract(self):
        java = (ROOT / 'source/android/src/quack/fnf/phoenix/android/PhoenixDisplay.java').read_text()
        setter = java.split('public static void setCutoutMode', 1)[1].split('public static void setPreferredRefreshRate', 1)[0]
        self.assertNotIn('catch (Exception ignored)', setter)
        self.assertIn('activity != mainActivity', java)
        self.assertIn('activity.isDestroyed()', java)
        self.assertNotIn('static View insetContent', java)
        activity = (ROOT / 'source/templates/android/MainActivity.java').read_text()
        self.assertIn('onWindowFocusChanged(boolean hasFocus)', activity)
        self.assertIn('onResume()', activity)
        self.assertIn('PhoenixDisplay.applyCutoutToActivity(this)', activity)
        layout = (ROOT / 'source/android/src/quack/fnf/phoenix/android/PhoenixCutoutLayout.java').read_text()
        self.assertNotIn('setOnApplyWindowInsetsListener', layout + java + activity)
        self.assertNotIn('android.R.id.content', java)
        self.assertIn('ViewGroup.LayoutParams.MATCH_PARENT', activity)

    def test_production_java_policy_and_layout(self):
        """Execute real production classes, not a Python copy of their logic."""
        import shutil
        import subprocess
        import tempfile
        javac, java = shutil.which('javac'), shutil.which('java')
        if not javac or not java:
            self.skipTest('JDK unavailable; Java behavior tests require javac and java')
        from android_cutout_stubs import STUBS
        stubs = STUBS
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            sources = []
            for name, text in stubs.items():
                path = temp / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
                sources.append(str(path))
            production = ROOT / 'source/android/src/quack/fnf/phoenix/android'
            sources += [str(production / name) for name in ('PhoenixCutoutPolicy.java', 'PhoenixCutoutLayout.java', 'PhoenixDisplay.java')]
            sources.append(str(ROOT / 'tests/java/quack/fnf/phoenix/android/PhoenixCutoutTest.java'))
            activity = temp / 'quack/fnf/phoenix/MainActivity.java'
            activity.parent.mkdir(parents=True, exist_ok=True)
            activity.write_text((ROOT / 'source/templates/android/MainActivity.java').read_text().replace('::APP_PACKAGE::', 'quack.fnf.phoenix'))
            sources.append(str(activity))
            compilation = subprocess.run([javac, '-d', str(temp), *sources], capture_output=True, text=True, timeout=60)
            self.assertEqual(compilation.returncode, 0, compilation.stdout + compilation.stderr)
            result = subprocess.run([java, '-cp', str(temp), 'quack.fnf.phoenix.android.PhoenixCutoutTest'], check=True, capture_output=True, text=True, timeout=60)
            self.assertIn('Cutout policy/layout tests passed', result.stdout)


if __name__ == '__main__':
    unittest.main()
