"""SAF-provider checks spanning the Lime template, Java policy, and runtime paths.

The Java path-policy test runs against real temporary directories when a JDK is
available. Python checks cover the template contract and source integration;
they are not a substitute for an Android manifest merge, emulator, or device
instrumentation test.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
ANDROID = "{http://schemas.android.com/apk/res/android}"
PROVIDER_BLOCK = re.compile(
    r"::if\s*\(SHARE_FILES\)::\s*(<provider\b(?=[^>]*android:name=\""
    r"quack\.fnf\.phoenix\.android\.PhoenixDocumentsProvider\")[\s\S]*?</provider>)"
    r"\s*::end::",
    re.MULTILINE,
)


def render_provider_branch(template: str, share_files: bool) -> str:
    """Select the provider branch for a focused template-condition test.

    This deliberately models only Lime's surrounding SHARE_FILES conditional;
    it is not a general Lime template renderer or Android manifest merger.
    """
    match = PROVIDER_BLOCK.search(template)
    if not match:
        raise AssertionError("PhoenixDocumentsProvider must be inside Lime's SHARE_FILES block")
    return match.group(1) if share_files else ""


def parse_provider(fragment: str):
    xml = fragment.replace(
        "<provider", '<provider xmlns:android="http://schemas.android.com/apk/res/android"', 1
    )
    return ElementTree.fromstring(xml)


class TestAndroidDocumentsProvider(unittest.TestCase):
    def setUp(self):
        self.manifest = (ROOT / "source/templates/android/template/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
        self.provider = (ROOT / "source/android/src/quack/fnf/phoenix/android/PhoenixDocumentsProvider.java").read_text(encoding="utf-8")

    def test_lime_share_files_gate_has_enabled_and_disabled_branches(self):
        disabled = render_provider_branch(self.manifest, share_files=False)
        self.assertEqual(disabled, "", "the disabled Lime feature branch must not register a provider")

        enabled = render_provider_branch(self.manifest, share_files=True)
        provider = parse_provider(enabled)
        self.assertEqual(
            provider.attrib[ANDROID + "name"],
            "quack.fnf.phoenix.android.PhoenixDocumentsProvider",
        )
        self.assertEqual(provider.attrib[ANDROID + "authorities"], "::APP_PACKAGE::.documentsprovider")
        self.assertEqual(provider.attrib[ANDROID + "exported"], "true")
        self.assertEqual(provider.attrib[ANDROID + "grantUriPermissions"], "true")
        self.assertEqual(provider.attrib[ANDROID + "permission"], "android.permission.MANAGE_DOCUMENTS")
        actions = [node.attrib.get(ANDROID + "name") for node in provider.findall("intent-filter/action")]
        self.assertIn("android.content.action.DOCUMENTS_PROVIDER", actions)
        self.assertNotIn("org.haxe.lime.StorageProvider", self.manifest)

    def test_merged_manifest_checker_covers_registered_and_unregistered_cases(self):
        checker = ROOT / "tools/check_android_documents_manifest.py"
        with tempfile.TemporaryDirectory(prefix="phoenix-merged-manifest-") as directory:
            manifest_path = Path(directory) / "AndroidManifest.xml"
            root = ElementTree.Element("manifest")
            ElementTree.SubElement(
                root,
                "uses-sdk",
                {ANDROID + "minSdkVersion": "21", ANDROID + "targetSdkVersion": "36"},
            )
            for permission_name in (
                "android.permission.FOREGROUND_SERVICE",
                "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
            ):
                ElementTree.SubElement(root, "uses-permission", {ANDROID + "name": permission_name})
            application = ElementTree.SubElement(root, "application")
            provider = ElementTree.SubElement(
                application,
                "provider",
                {
                    ANDROID + "name": "quack.fnf.phoenix.android.PhoenixDocumentsProvider",
                    ANDROID + "authorities": "quack.fnf.phoenix.documentsprovider",
                    ANDROID + "exported": "true",
                    ANDROID + "grantUriPermissions": "true",
                    ANDROID + "permission": "android.permission.MANAGE_DOCUMENTS",
                },
            )
            provider_intent = ElementTree.SubElement(provider, "intent-filter")
            ElementTree.SubElement(
                provider_intent,
                "action",
                {ANDROID + "name": "android.content.action.DOCUMENTS_PROVIDER"},
            )
            media_service = ElementTree.SubElement(
                application,
                "service",
                {
                    ANDROID + "name": "quack.fnf.phoenix.android.PhoenixMediaService",
                    ANDROID + "exported": "true",
                    ANDROID + "foregroundServiceType": "mediaPlayback",
                },
            )
            media_intent = ElementTree.SubElement(media_service, "intent-filter")
            for action_name in (
                "androidx.media3.session.MediaSessionService",
                "android.media.browse.MediaBrowserService",
            ):
                ElementTree.SubElement(media_intent, "action", {ANDROID + "name": action_name})
            ElementTree.register_namespace("android", "http://schemas.android.com/apk/res/android")
            ElementTree.ElementTree(root).write(manifest_path, encoding="utf-8", xml_declaration=True)

            enabled = subprocess.run(
                [
                    sys.executable,
                    str(checker),
                    str(manifest_path),
                    "--provider",
                    "present",
                    "--media-service",
                    "present",
                    "--minimum-sdk",
                    "21",
                    "--target-sdk",
                    "36",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(enabled.returncode, 0, enabled.stdout + enabled.stderr)

            application.remove(provider)
            ElementTree.ElementTree(root).write(manifest_path, encoding="utf-8", xml_declaration=True)
            disabled = subprocess.run(
                [
                    sys.executable,
                    str(checker),
                    str(manifest_path),
                    "--provider",
                    "absent",
                    "--media-service",
                    "present",
                    "--minimum-sdk",
                    "21",
                    "--target-sdk",
                    "36",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(disabled.returncode, 0, disabled.stdout + disabled.stderr)

            wrongly_expected_provider = subprocess.run(
                [
                    sys.executable,
                    str(checker),
                    str(manifest_path),
                    "--provider",
                    "present",
                    "--media-service",
                    "present",
                    "--minimum-sdk",
                    "21",
                    "--target-sdk",
                    "36",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(wrongly_expected_provider.returncode, 0)

            application.remove(media_service)
            ElementTree.ElementTree(root).write(manifest_path, encoding="utf-8", xml_declaration=True)
            media_disabled = subprocess.run(
                [
                    sys.executable,
                    str(checker),
                    str(manifest_path),
                    "--provider",
                    "absent",
                    "--media-service",
                    "absent",
                    "--minimum-sdk",
                    "21",
                    "--target-sdk",
                    "36",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(media_disabled.returncode, 0, media_disabled.stdout + media_disabled.stderr)

            wrongly_expected_media = subprocess.run(
                [
                    sys.executable,
                    str(checker),
                    str(manifest_path),
                    "--provider",
                    "absent",
                    "--media-service",
                    "present",
                    "--minimum-sdk",
                    "21",
                    "--target-sdk",
                    "36",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(wrongly_expected_media.returncode, 0)

    def test_project_keeps_share_mobile_files_enabled_for_mobile_builds(self):
        project = (ROOT / "project.hxp").read_text(encoding="utf-8")
        self.assertRegex(
            project,
            r'if\s*\(isMobile\(\)\)\s*\{\s*setHaxedef\("SHARE_MOBILE_FILES"\);\s*\}',
        )
        self.assertIn("::if (SHARE_FILES)::", self.manifest)
        # The pinned Lime 8.1.2 AndroidPlatform derives SHARE_FILES from this
        # haxedef and conditionally registers its generic StorageProvider.

    def test_pinned_lime_sdk_values_match_android_ci_inputs(self):
        dependencies = json.loads((ROOT / "hmm.json").read_text(encoding="utf-8"))["dependencies"]
        lime = next(dependency for dependency in dependencies if dependency["name"] == "lime")
        self.assertEqual(lime["ref"], "45816ca456764761cbea8d3cc57701a592f892f1")

        main_workflow = (ROOT / ".github/workflows/main.yml").read_text(encoding="utf-8")
        mobile_workflow = (ROOT / ".github/workflows/mobile.yml").read_text(encoding="utf-8")
        checks_workflow = (ROOT / ".github/workflows/checks.yml").read_text(encoding="utf-8")
        project = (ROOT / "project.hxp").read_text(encoding="utf-8")
        platform_docs = (ROOT / "docs/ANDROID_PLATFORM.md").read_text(encoding="utf-8")
        self.assertIn('this.config.set("android.minimum-sdk-version", 21)', project)
        self.assertIn('this.config.set("android.target-sdk-version", 36)', project)
        self.assertIn('this.config.set("android.build-tools-version", "36.0.0")', project)
        self.assertIn("platforms;android-36 build-tools;36.0.0 ndk;27.0.12077973", main_workflow)
        self.assertIn("platforms;android-36 build-tools;36.0.0 ndk;27.0.12077973", mobile_workflow)
        self.assertIn("/ndk/27.0.12077973", main_workflow)
        self.assertIn("/ndk/27.0.12077973", mobile_workflow)
        self.assertIn('java-version: "17"', checks_workflow)
        self.assertIn("--minimum-sdk 21 --target-sdk 36", main_workflow)
        self.assertIn("--media-service present", main_workflow)
        self.assertIn("--media-service present", mobile_workflow)
        self.assertIn("Minimum Android API | 21", platform_docs)
        self.assertIn("Target Android API | 36", platform_docs)
        self.assertIn("Compile SDK | 36", platform_docs)
        self.assertIn("Android Build Tools | 36.0.0", platform_docs)
        self.assertIn("Android NDK | 27.0.12077973 (r27)", platform_docs)

    def test_provider_roots_match_the_runtime_storage_paths(self):
        storage = (ROOT / "source/mobile/StorageUtil.hx").read_text(encoding="utf-8")
        main = (ROOT / "source/Main.hx").read_text(encoding="utf-8")
        paths = (ROOT / "source/backend/Paths.hx").read_text(encoding="utf-8")
        crashes = (ROOT / "source/backend/CrashHandler.hx").read_text(encoding="utf-8")

        self.assertIn("AndroidContext.getExternalFilesDir()", storage)
        self.assertIn("Sys.setCwd(mobile.StorageUtil.getStorageDirectory())", main)
        self.assertRegex(paths, r"inline static public function mods\([^\n]*\)\s*\{?\s*return 'mods/' \+")
        self.assertIn('path = "crash/FNF-Phoenix-Engine_"', crashes)
        self.assertIn('new File(storageDirectory, ROOT_MODS)', self.provider)
        self.assertIn('new File(storageDirectory, ROOT_CRASH)', self.provider)
        self.assertIn('"mods"', self.provider)
        self.assertIn('"crash"', self.provider)
        self.assertNotIn('new File(storageDirectory, "logs")', self.provider)

    def test_root_access_policy_and_failures_are_explicit(self):
        self.assertIn('"User mods", true)', self.provider)
        self.assertIn('"Phoenix Engine crash reports", false)', self.provider)
        self.assertIn('if (write && !canWriteToRoot(document.root))', self.provider)
        self.assertIn('if (document.rootDocument || !canWriteToRoot(document.root))', self.provider)
        self.assertIn('if (!canWriteToRoot(parent.root))', self.provider)
        self.assertIn('FLAG_SUPPORTS_WRITE', self.provider)
        self.assertIn('FLAG_DIR_SUPPORTS_CREATE', self.provider)
        self.assertIn('if (!isUsableRoot(root))', self.provider)
        self.assertIn('Environment.getExternalStorageState(path)', self.provider)
        self.assertIn('Environment.MEDIA_MOUNTED_READ_ONLY', self.provider)
        self.assertIn('return root.writable && isStorageWritable(root.directory)', self.provider)
        self.assertIn('Phoenix storage is unavailable', self.provider)
        self.assertIn('Could not list directory:', self.provider)

    def test_ids_and_operations_use_the_tested_filesystem_policy(self):
        self.assertIn("PhoenixDocumentPathPolicy.isSafeRelativePath(relativePath)", self.provider)
        self.assertIn("return PhoenixDocumentPathPolicy.isSafeFile(root.directory, file);", self.provider)
        self.assertIn("PhoenixDocumentPathPolicy.isWithin(rootPath, filePath)", self.provider)
        self.assertIn("MAX_ENCODED_RELATIVE_PATH_LENGTH", self.provider)
        self.assertIn("Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP", self.provider)
        self.assertIn("String renamedDocumentId = buildDocumentId(document.root, renamed)", self.provider)
        self.assertIn("java.io.File cannot make", self.provider)
        self.assertIn("refresh the parent view, including on partial failure", self.provider)
        self.assertIn("if (document.file.exists())\n\t\t\t\tnotifyDocumentChanged(documentId, null)", self.provider)
        self.assertIn("descendants.add(new PermissionTarget(documentId, document.file))", self.provider)
        self.assertIn("COLUMN_MIME_TYPE", self.provider)
        self.assertIn("COLUMN_SIZE", self.provider)
        self.assertIn("COLUMN_LAST_MODIFIED", self.provider)
        self.assertIn('"application/octet-stream"', self.provider)
        self.assertIn("setNotificationUri", self.provider)
        self.assertIn("resolver.notifyChange", self.provider)

    def test_android_21_api_floor_is_guarded_for_conditional_documents_features(self):
        # Lime 8.1.2 defaults minSdkVersion to 21. Methods/flags introduced in
        # API 21 remain explicitly guarded so downstream lower-min builds fail
        # closed rather than invoking unavailable behavior.
        self.assertIn("Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP", self.provider)
        self.assertIn("Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP", self.provider)
        self.assertIn("FLAG_SUPPORTS_RENAME", self.provider)
        self.assertIn("revokeDocumentPermission", self.provider)
        self.assertRegex(self.provider, r"private boolean isStorageAvailable\(File path\)\s*\{\s*if \(Build.VERSION.SDK_INT <")
        self.assertRegex(self.provider, r"private boolean isStorageWritable\(File path\)\s*\{\s*if \(Build.VERSION.SDK_INT <")

    def test_host_jvm_filesystem_tests_exercise_the_production_policy(self):
        javac = shutil.which("javac")
        java = shutil.which("java")
        if not javac or not java:
            self.skipTest("JDK is unavailable; CI installs Java 17 for this test")

        source = ROOT / "source/android/src/quack/fnf/phoenix/android/PhoenixDocumentPathPolicy.java"
        test_source = ROOT / "tests/java/quack/fnf/phoenix/android/PhoenixDocumentPathPolicyTest.java"
        class_name = "quack.fnf.phoenix.android.PhoenixDocumentPathPolicyTest"
        with tempfile.TemporaryDirectory(prefix="phoenix-path-policy-test-") as classes:
            compilation = subprocess.run(
                [javac, "-encoding", "UTF-8", "-d", classes, str(source), str(test_source)],
                check=False,
                capture_output=True,
                text=True,
                timeout=60,
            )
            self.assertEqual(compilation.returncode, 0, compilation.stdout + compilation.stderr)
            execution = subprocess.run(
                [java, "-cp", classes, class_name],
                check=False,
                capture_output=True,
                text=True,
                timeout=60,
            )
            self.assertEqual(execution.returncode, 0, execution.stdout + execution.stderr)
            self.assertIn("assertions passed", execution.stdout)


if __name__ == "__main__":
    unittest.main()
