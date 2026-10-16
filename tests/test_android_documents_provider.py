"""Static checks for the Android SAF document provider.

The Android SDK is not required to verify that the manifest registers the
provider securely and that the implementation keeps its exposed roots scoped.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]


class TestAndroidDocumentsProvider(unittest.TestCase):
    def setUp(self):
        self.manifest = (ROOT / "templates/android/template/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
        self.provider = (ROOT / "android/src/quack/fnf/phoenix/android/PhoenixDocumentsProvider.java").read_text(encoding="utf-8")

    def test_manifest_registers_system_protected_provider(self):
        match = re.search(
            r'<provider\s+android:name="quack\.fnf\.phoenix\.android\.PhoenixDocumentsProvider".*?</provider>',
            self.manifest,
            re.S,
        )
        self.assertIsNotNone(match, "PhoenixDocumentsProvider must be registered in the Android manifest")

        xml = match.group(0).replace(
            "<provider", '<provider xmlns:android="http://schemas.android.com/apk/res/android"', 1
        )
        element = ElementTree.fromstring(xml)
        android = "{http://schemas.android.com/apk/res/android}"
        self.assertEqual(element.attrib[android + "authorities"], "::APP_PACKAGE::.documentsprovider")
        self.assertEqual(element.attrib[android + "exported"], "true")
        self.assertEqual(element.attrib[android + "grantUriPermissions"], "true")
        self.assertEqual(element.attrib[android + "permission"], "android.permission.MANAGE_DOCUMENTS")
        self.assertIn("android.content.action.DOCUMENTS_PROVIDER", xml)
        self.assertNotIn("org.haxe.lime.StorageProvider", self.manifest)

    def test_only_crash_reports_and_mods_are_exposed(self):
        self.assertIn("extends DocumentsProvider", self.provider)
        self.assertIn('new RootInfo(ROOT_MODS, new File(storageDirectory, ROOT_MODS), "Mods"', self.provider)
        self.assertIn('new RootInfo(ROOT_CRASH, new File(storageDirectory, ROOT_CRASH), "Crash Logs"', self.provider)
        self.assertIn('getExternalFilesDir(null)', self.provider)
        self.assertIn('new File(storageDirectory, ROOT_MODS)', self.provider)
        self.assertIn('new File(storageDirectory, ROOT_CRASH)', self.provider)

    def test_mods_are_writable_but_crash_reports_are_read_only(self):
        self.assertIn('"Phoenix Engine crash reports", false)', self.provider)
        self.assertIn('"User mods", true)', self.provider)
        self.assertIn("FLAG_SUPPORTS_WRITE", self.provider)
        self.assertIn("FLAG_DIR_SUPPORTS_CREATE", self.provider)

    def test_document_ids_and_files_are_confined_to_roots(self):
        self.assertIn("isSafeRelativePath(relativePath)", self.provider)
        self.assertIn("isSafeFile(root, file)", self.provider)
        self.assertIn("absolutePath.equals(canonicalPath)", self.provider)
        self.assertIn('"..".equals(segment)', self.provider)


if __name__ == "__main__":
    unittest.main()
