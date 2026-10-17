"""Regression coverage for Phoenix's Android Media3 bridge.

The lifecycle/artwork state and controller action protocol run as real host-JVM
code when a JDK is available. Android compilation and merged-manifest/package
validation remain the responsibility of the Android CI workflow.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


class AndroidMedia3IntegrationTests(unittest.TestCase):
    def test_media3_is_an_android_only_local_gradle_dependency(self) -> None:
        project = read("project.hxp")
        gradle = read("source/android/media3/build.gradle")

        self.assertIn('new Dependency("phoenix-media3", "source/android/media3")', project)
        self.assertIn('api "androidx.media3:media3-session:1.6.1"', gradle)
        self.assertIn('minSdkVersion Integer.parseInt(project.ANDROID_BUILD_MIN_SDK_VERSION)', gradle)

    def test_manifest_exports_the_media_session_service_discovery_endpoint(self) -> None:
        manifest = read("source/templates/android/template/app/src/main/AndroidManifest.xml")
        project = read("project.hxp")

        self.assertIn('android:name="quack.fnf.phoenix.android.PhoenixMediaService"', manifest)
        self.assertIn('android:exported="true"', manifest)
        self.assertIn('android:foregroundServiceType="mediaPlayback"', manifest)
        self.assertIn('androidx.media3.session.MediaSessionService', manifest)
        self.assertIn('android.media.browse.MediaBrowserService', manifest)
        self.assertIn('"android.permission.FOREGROUND_SERVICE"', project)
        self.assertIn('"android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"', project)

    def test_native_bridge_wires_media3_to_the_tested_lifecycle_and_action_helpers(self) -> None:
        media = read("source/android/src/quack/fnf/phoenix/android/PhoenixMedia.java")
        service = read("source/android/src/quack/fnf/phoenix/android/PhoenixMediaService.java")

        self.assertIn("import androidx.media3.session.MediaSession;", media)
        self.assertNotIn("android.media.session.", media)
        self.assertIn("extends SimpleBasePlayer", media)
        self.assertIn("PhoenixMediaBridgeState", media)
        self.assertIn("startMediaServiceForReadyPlayback", media)
        self.assertIn("ARTWORK_EXECUTOR", media)
        self.assertIn("BitmapFactory.Options", media)
        self.assertIn("scheduleArtworkLoad", media)
        self.assertIn("PhoenixMediaAction.playWhenReady", media)
        self.assertIn("PhoenixMediaAction.seek", media)
        self.assertIn("PhoenixMediaAction.next", media)
        self.assertIn("PhoenixMediaAction.previous", media)
        self.assertIn("extends MediaSessionService", service)
        self.assertIn("addSession(session)", service)
        self.assertIn("Do not call startForeground here", service)
        self.assertNotIn("startForeground(", service)

    def test_gameplay_waits_for_real_playback_before_service_start(self) -> None:
        helper = read("source/play/helpers/PlayStateAndroidMedia.hx")

        self.assertIn("getSongArtist()", helper)
        self.assertIn("getSongArtworkPath()", helper)
        self.assertIn("Friday Night Funkin' - Phoenix Engine", helper)
        self.assertIn("playState.playbackRate", helper)
        self.assertIn("state.playbackRate", helper)
        self.assertIn("AndroidMedia.STATE_PAUSED", helper)
        self.assertNotIn("AndroidMedia.startForegroundService(title, artist, initiallyPlaying)", helper)
        self.assertNotIn("AndroidMedia.updateNotification(title, artist, initiallyPlaying)", helper)

    def test_host_jvm_lifecycle_artwork_and_command_regressions(self) -> None:
        javac = shutil.which("javac")
        java = shutil.which("java")
        if not javac or not java:
            self.skipTest("JDK is unavailable; Android/host-JVM coverage runs in CI")

        sources = [
            ROOT / "source/android/src/quack/fnf/phoenix/android/PhoenixMediaBridgeState.java",
            ROOT / "source/android/src/quack/fnf/phoenix/android/PhoenixMediaAction.java",
            ROOT / "tests/java/quack/fnf/phoenix/android/PhoenixMediaBridgeStateTest.java",
        ]
        with tempfile.TemporaryDirectory(prefix="phoenix-media-bridge-jvm-") as directory:
            classes = Path(directory) / "classes"
            compiled = subprocess.run(
                [javac, "-d", str(classes), *(str(source) for source in sources)],
                cwd=ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

            ran = subprocess.run(
                [java, "-cp", str(classes), "quack.fnf.phoenix.android.PhoenixMediaBridgeStateTest"],
                cwd=ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(ran.returncode, 0, ran.stdout + ran.stderr)
            self.assertIn("assertions passed", ran.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
