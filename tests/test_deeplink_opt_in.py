#!/usr/bin/env python3
"""Static regression tests for the opt-in `phoenix://` registration.

Registering the URI scheme used to happen inside `DeepLinks.init()`, so every game
launch touched the per-user registry. It is now a player choice: Options -> Misc ->
"Toggle Deeplink". These tests pin that boundary (no Haxe toolchain needed, same
style as test_arena_fixes.py): the launch path may only queue links, the checkbox is
the single writer, and the preference is never re-applied on a later startup.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_deeplink_opt_in.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

DEEPLINKS = "source/backend/deeplink/DeepLinks.hx"
MISC = "source/options/MiscSettingsSubState.hx"
PREFS = "source/backend/ClientPrefs.hx"
WINDOWS_ONLY = re.compile(r"#if \(windows && sys\)(.*?)#end", re.S)

# Anything that would mean "this code talks to the OS about the scheme".
REGISTRATION_MARKERS = ("Register-PhoenixURI", "powershell", "sys.io.Process", "Sys.command")


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def body(source: str, signature: str) -> str:
    """The brace-delimited body of the first definition matching `signature`."""
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 0
    for i in range(brace, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return source[brace:i + 1]
    raise AssertionError(f"unterminated body for {signature}")


class DeepLinkOptInTests(unittest.TestCase):
    def test_startup_queues_links_but_never_registers(self):
        source = read(DEEPLINKS)
        init = body(source, "public static function init(")
        for marker in REGISTRATION_MARKERS:
            self.assertNotIn(marker, init,
                             f"DeepLinks.init() must not {marker!r}: startup only queues links")
        self.assertNotIn("ensureWindowsProtocolRegistration", source,
                         "the launch-time registration helper must be gone")
        # Startup is the only caller that runs unattended, and Main must not gain one.
        self.assertIn("backend.deeplink.DeepLinks.init();", read("source/Main.hx"))
        self.assertNotIn("DeepLinks.applyRegistration", read("source/Main.hx"))

    def test_registry_access_stays_behind_sys_capable_windows(self):
        source = read(DEEPLINKS)
        self.assertNotRegex(source, r"#(elseif|if) windows\b",
                            "Sys/registry calls need the sys guard, not bare #if windows")
        self.assertGreaterEqual(source.count("#if (windows && sys)"), 2,
                               "init() and the registration entry point both guard themselves")

    def test_misc_option_is_a_persisted_bool_wired_to_the_entry_point(self):
        misc = read(MISC)
        blocks = WINDOWS_ONLY.findall(misc)
        self.assertEqual(len(blocks), 1, "exactly one Windows-only block is expected")
        block = blocks[0]
        self.assertIn("'Toggle Deeplink'", block)
        self.assertRegex(block, r"new Option\(\s*'Toggle Deeplink'")
        self.assertIn("'deeplinkEnabled'", block)
        self.assertIn("'bool'", block)
        self.assertIn("false); //Default value", block)
        self.assertIn("option.onChange = backend.deeplink.DeepLinks.applyRegistration;", block)
        self.assertIn("addOption(option);", block)
        # Every other Misc option stays outside the guard.
        self.assertEqual(block.count("new Option("), 1)

    def test_preference_is_declared_and_saved(self):
        prefs = read(PREFS)
        self.assertIn("public static var deeplinkEnabled:Bool = false;", prefs,
                      "the checkbox must remember the handler this copy claimed")
        blacklisted = re.search(r'"saveBlackList" => \[([^\]]*)\]', prefs).group(1)
        self.assertNotIn("deeplinkEnabled", blacklisted)

    def test_toggle_is_the_only_writer_and_keeps_the_checkbox_honest(self):
        source = read(DEEPLINKS)
        apply_ = body(source, "public static function applyRegistration(")
        self.assertIn("ClientPrefs.deeplinkEnabled && !registerWindowsProtocol()", apply_)
        self.assertIn("unregisterWindowsProtocol()", apply_)
        self.assertIn("ClientPrefs.deeplinkEnabled = false;", apply_,
                       "a failed registration has to roll the preference back")
        self.assertIn("CoolUtil.coolError", apply_)
        self.assertIn("ClientPrefs.saveSettings()", apply_,
                       "the registry and the save file must not drift apart")
        # The option is the only caller: no state in the startup path may invoke it.
        for rel in ("source/Main.hx", "source/states/TitleState.hx",
                    "source/states/MainMenuState.hx", "source/states/InitState.hx"):
            self.assertNotIn("applyRegistration", read(rel), f"{rel} must not register on launch")

    def test_registration_is_verified_and_removal_is_unconditional(self):
        source = read(DEEPLINKS)
        register = body(source, "static function registerWindowsProtocol(")
        self.assertIn("Register-PhoenixURI.ps1", register)
        self.assertIn("sys.FileSystem.exists(script)", register)
        self.assertIn('-Executable "', register,
                       "a renamed build must register the executable that is running")
        self.assertIn("sameCommand(windowsProtocolCommand(), expected)", register,
                      "verify the written value instead of trusting the script exit code")
        self.assertIn("if (current != null) return false;", register,
                      "another copy's handler must not be silently overwritten")
        unregister = body(source, "static function unregisterWindowsProtocol(")
        self.assertIn("'delete'", unregister)
        self.assertIn("'/f'", unregister)
        self.assertNotIn("query", unregister, "opting out asks no questions")

    def test_docs_describe_the_opt_in(self):
        uri = read("URI.MD")
        self.assertIn("Toggle Deeplink", uri)
        self.assertNotRegex(uri, r"[Ee]ngine (also )?(performs|registers)[^\n]*startup",
                            "URI.MD must no longer promise a registration during startup")
        site = read("website/docs/subsystems/deep-links.md")
        self.assertIn("Toggle Deeplink", site)
        self.assertIn("DeepLinks.applyRegistration()", site)
        bootstrap = read("website/docs/architecture/bootstrap.md")
        self.assertNotIn("registers the `phoenix://` handler", bootstrap)


if __name__ == "__main__":
    unittest.main(verbosity=2)
