"""Static wiring checks for the Android Media3 bridge.

These checks deliberately do not need an Android SDK. Android compilation still
runs in the mobile CI workflow; this test makes sure future template changes do
not silently drop the Gradle dependency or the service discovery declaration.
"""
from __future__ import annotations

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

        self.assertIn('android:name="quack.fnf.phoenix.android.PhoenixMediaService"', manifest)
        self.assertIn('android:exported="true"', manifest)
        self.assertIn('android:foregroundServiceType="mediaPlayback"', manifest)
        self.assertIn('androidx.media3.session.MediaSessionService', manifest)
        self.assertIn('android.media.browse.MediaBrowserService', manifest)

    def test_native_bridge_uses_media3_session_and_mirrored_player(self) -> None:
        media = read("source/android/src/quack/fnf/phoenix/android/PhoenixMedia.java")
        service = read("source/android/src/quack/fnf/phoenix/android/PhoenixMediaService.java")

        self.assertIn("import androidx.media3.session.MediaSession;", media)
        self.assertNotIn("android.media.session.", media)
        self.assertIn("extends SimpleBasePlayer", media)
        self.assertIn("setArtworkData", media)
        self.assertIn("setMetadata(final String title, final String artist, final String album,", media)
        self.assertIn('PhoenixCore.dispatch("media", requestedPlayWhenReady ? "play" : "pause")', media)
        self.assertIn('PhoenixCore.dispatch("media", "seek:" + safePosition)', media)
        self.assertIn("extends MediaSessionService", service)
        self.assertIn("addSession(session)", service)

    def test_gameplay_publishes_creator_album_artwork_and_real_playback_rate(self) -> None:
        helper = read("source/play/helpers/PlayStateAndroidMedia.hx")

        self.assertIn("getSongArtist()", helper)
        self.assertIn("getSongArtworkPath()", helper)
        self.assertIn("Friday Night Funkin' - Phoenix Engine", helper)
        self.assertIn("playState.playbackRate", helper)
        self.assertIn("state.playbackRate", helper)
        self.assertIn("AndroidMedia.startForegroundService", helper)


if __name__ == "__main__":
    unittest.main(verbosity=2)
