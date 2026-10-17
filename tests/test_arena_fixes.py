#!/usr/bin/env python3
"""Static regression tests for the Arena audit fixes.

No Haxe toolchain is required: these assert the exact invariants that the
issues (#42-#55, #57-#60) were filed about, so the defects cannot silently
return (a hard-coded version string, an unpinned dependency, a hook whose
argument list drifts from its documentation, ...).

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_arena_fixes.py
"""
from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import check_dependencies  # noqa: E402


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def count_call_args(source: str, hook: str) -> int:
    """Number of elements in the [...] passed to callOnLuas('hook', [...])."""
    start = source.index(f"'{hook}'")
    open_bracket = source.index("[", start)
    depth = 0
    for i in range(open_bracket, len(source)):
        if source[i] == "[":
            depth += 1
        elif source[i] == "]":
            depth -= 1
            if depth == 0:
                inner = source[open_bracket + 1 : i]
                break
    else:  # pragma: no cover
        raise AssertionError(f"unterminated arg list for {hook}")
    # count top-level commas
    depth = 0
    count = 1 if inner.strip() else 0
    for ch in inner:
        if ch in "[(":
            depth += 1
        elif ch in "])":
            depth -= 1
        elif ch == "," and depth == 0:
            count += 1
    return count


def documented_params(text: str, hook: str) -> int:
    match = re.search(rf"{hook}\(([^)]*)\)", text)
    assert match, f"{hook} not documented"
    params = [p for p in match.group(1).split(",") if p.strip()]
    return len(params)


class TestDependencies(unittest.TestCase):
    def test_manifests_agree_and_pinned(self):  # #42, #58
        self.assertEqual(check_dependencies.check(ROOT), [])

    def test_hxcpp_is_the_funkincrew_fork_everywhere(self):  # #42
        deps = check_dependencies.from_hmm(ROOT)
        self.assertIn("FunkinCrew/hxcpp", deps["hxcpp"][0])
        for script in ("setup/unix.sh", "setup/windows.bat"):
            self.assertIn("FunkinCrew/hxcpp", read(script))
            self.assertNotIn("JS-Engine-things/hxcpp", read(script))


class TestCIWorkflows(unittest.TestCase):
    def test_haxe_version_single_value(self):  # #60
        versions = set()
        for wf in ("main.yml", "mobile.yml"):
            text = read(f".github/workflows/{wf}")
            versions.update(re.findall(r'HAXE_VERSION:\s*"([\d.]+)"', text))
            self.assertNotIn("haxe-version: 4.3.6", text)
            self.assertNotRegex(text, r"haxe-version:\s*\d")  # must use env
        self.assertEqual(versions, {"4.3.7"})
        self.assertFalse((ROOT / "UPDATE HAXE TO 4.3.7.txt").exists())

    def test_cache_key_pins_dependency_set_per_job(self):  # #57
        main = read(".github/workflows/main.yml")
        self.assertIn("haxelib-${{ runner.os }}-${{ matrix.setup }}", main)
        self.assertIn("hashFiles('hmm.json')", main)
        self.assertNotIn("windows-msvc-fix.ps1') }}", main.split("Restore haxelib")[1].split("\n")[3])
        self.assertIn("Report resolved dependency revisions", main)

    def test_nightly_trigger_names_a_real_workflow(self):  # #59
        names = set()
        for path in (ROOT / ".github/workflows").glob("*.yml"):
            m = re.search(r"^name:\s*(.+)$", path.read_text(), re.M)
            if m:
                names.add(m.group(1).strip())
        nightly = read(".github/workflows/nightly.yml")
        triggered = re.search(r"workflows:\s*\[([^\]]+)\]", nightly).group(1)
        for entry in triggered.split(","):
            self.assertIn(entry.strip().strip("'\""), names)

    def test_no_jekyll_workflow_can_overwrite_pages(self):  # #49
        self.assertFalse((ROOT / ".github/workflows/jekyll-gh-pages.yml").exists())

    def test_triage_labels_are_self_healing(self):  # #48
        self.assertIn("createLabel", read(".github/workflows/autotriage.yml"))
        autolock = read(".github/workflows/autolock.yml")
        self.assertIn("createLabel", autolock)
        self.assertIn('stale-issue-label: "stale"', autolock)

    def test_bug_templates_point_at_this_repo(self):  # #47
        for path in (ROOT / ".github/ISSUE_TEMPLATE").glob("*.yml"):
            text = path.read_text()
            self.assertNotIn("JordanSantiagoYT/FNF-JS-Engine", text, path.name)
            self.assertNotIn("automatically be rejected", text, path.name)
        self.assertIn("havaianasdestruido/FNF-Phoenix-Engine/issues",
                      read(".github/ISSUE_TEMPLATE/bugs.yml"))


class TestEngineCode(unittest.TestCase):
    def test_safe_frames_wires_recalculate_timings(self):  # #43
        self.assertRegex(read("source/options/GameplaySettingsSubState.hx"),
                         r"option\.onChange = \(\) -> Conductor\.recalculateTimings\(\)")
        self.assertIn("Conductor.recalculateTimings();", read("source/states/InitState.hx"))
        self.assertIn("import backend.Conductor;", read("source/states/InitState.hx"))
        self.assertIn("import backend.Conductor;", read("source/options/GameplaySettingsSubState.hx"))

    def test_hook_argument_lists_match_docs_and_templates(self):  # #44
        notes = read("source/play/helpers/PlayStateNotes.hx")
        events = read("source/play/helpers/PlayStateEvents.hx")
        hooks = read("website/docs/modding/script-hooks.md")
        self.assertEqual(count_call_args(notes, "onSpawnNote"),
                         documented_params(hooks, "onSpawnNote"))
        self.assertEqual(count_call_args(events, "onEvent"),
                         documented_params(hooks, "onEvent"))
        self.assertEqual(count_call_args(events, "eventEarlyTrigger"),
                         documented_params(hooks, "eventEarlyTrigger"))
        for template, pattern in (("docs/TemplateScript.py", r"def {h}\(([^)]*)\)"),
                                  ("docs/TemplateScript.lua", r"function {h}\(([^)]*)\)")):
            text = read(template)
            for hook in ("onEvent", "eventEarlyTrigger"):
                match = re.search(pattern.format(h=hook), text)
                params = [p for p in match.group(1).split(",") if p.strip()]
                self.assertEqual(len(params), documented_params(hooks, hook),
                                 f"{template}:{hook}")

    def test_wowza_badge_unlocks_with_ten_enabled_mods(self):
        achievements = read("source/backend/Achievements.hx")
        main_menu = read("source/states/MainMenuState.hx")
        self.assertIn("createAchievement('wowza'", achievements)
        self.assertIn('name: "Wowza!!"', achievements)
        self.assertTrue((ROOT / "assets/preload/images/achievements/wowza.png").is_file())
        self.assertRegex(main_menu, r"Mods\.parseList\(\)\.enabled\.length\s*>=\s*10")
        self.assertIn("Achievements.unlock('wowza')", main_menu)

    def test_link_options_round_trip(self):  # #45
        option = read("source/options/Option.hx")
        self.assertIn("case 'link': newValue = 'link';", option)
        self.assertIn("if(type != 'link' && getValue() == null)", option)
        self.assertIn("curOption.type == 'link'", read("source/options/BaseOptionsMenu.hx"))

    def test_no_vendored_library_files_under_source(self):  # #46
        for package in ("flixel", "openfl", "funkin"):
            self.assertFalse((ROOT / "source" / package).exists(), package)
        for patch in ("flixel/FlxGame.hx", "flixel/addons/ui/FlxInputText.hx",
                      "flixel/addons/ui/FlxSlider.hx",
                      "flixel/addons/ui/FlxUIDropDownMenu.hx",
                      "flixel/addons/ui/FlxUIInputText.hx"):
            self.assertTrue((ROOT / "source" / "source-haxelib-patches" / patch).exists(), patch)

    def test_no_dead_prebuild_hooks(self):  # #50
        self.assertNotIn("PREBUILD_HX", read("project.hxp"))
        self.assertNotIn("Prebuild.hx", read("website/docs/getting-started/project-configuration.md"))

    def test_python_exposes_function_stoplua(self):  # #51
        python = read("source/psychlua/PythonScript.hx")
        self.assertIn("Function_StopLua:Dynamic", python)
        self.assertIn("set('Function_StopLua', Function_StopLua);", python)
        # same sentinel as Function_StopAll, so the PlayState dispatcher matches
        self.assertIn('Function_StopAll:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA"', python)
        self.assertIn('Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA"', python)

    def test_mods_and_stub_have_distinct_type_paths(self):  # #52
        self.assertRegex(read("source/backend/ModsStub.hx"), r"(?m)^class ModsStub\b")
        self.assertNotRegex(read("source/backend/ModsStub.hx"), r"(?m)^class Mods\b")
        typedefs = re.findall(r"typedef ModsList", "\n".join(
            p.read_text(errors="ignore") for p in (ROOT / "source").rglob("*.hx")))
        self.assertEqual(len(typedefs), 1)
        self.assertTrue((ROOT / "source/backend/ModsList.hx").exists())
        self.assertIn("import backend.ModsStub as Mods;", read("source/import.hx"))

    def test_update_checker_uses_this_repo_and_phoenix_version(self):  # #53
        title = read("source/states/TitleState.hx")
        self.assertIn("havaianasdestruido/FNF-Phoenix-Engine/main/THECHANGELOG.md", title)
        self.assertIn("MainMenuState.phoenixEngineVersion", title)
        self.assertNotIn("JordanSantiagoYT/FNF-JS-Engine/main/THECHANGELOG.md",
                         title + read("source/options/SuperSecretDebugMenu.hx"))

    def test_version_comes_from_project_metadata(self):  # #54
        project = read("project.hxp")
        version = re.search(r'static final VERSION:String = "([^"]+)"', project).group(1)
        menu = read("source/states/MainMenuState.hx")
        self.assertNotIn("'pre-alpha'", menu)
        self.assertIn("Application.current.meta.get('version')", menu)
        self.assertIn(f"return '{version}';", menu)  # enforced fallback literal
        changelog_top = next(line for line in read("THECHANGELOG.md").splitlines() if line.strip())
        self.assertEqual(changelog_top, f"{version};")
        self.assertIn('setHaxedef("ENGINE_VERSION", VERSION)', project)

    def test_no_preload_all_branch_compiles_statically(self):  # #55
        loading = read("source/states/LoadingState.hx")
        self.assertIn("public function new(target:NextState", loading)
        self.assertIn("OpenFlAssets.cache.hasSound(path)", loading)
        self.assertNotRegex(loading, r"(?<![A-Za-z])Assets\.cache\.hasSound")
        self.assertIn("OpenFlAssets.getLibrary(library)", loading)

    def test_python_script_binds_registered_functions_before_execute(self):
        py_script = read("source/psychlua/PythonScript.hx")
        self.assertIn("for (name => func in registeredFunctions)", py_script)
        self.assertIn("preprocessHythonCode", py_script)
        bind_pos = py_script.index("for (name => func in registeredFunctions)")
        exec_pos = py_script.index("interp.execute(parser.parseString(code))")
        on_create_pos = py_script.index("call('onCreate', [])")
        self.assertLess(bind_pos, exec_pos,
                        "registeredFunctions must be bound before interp.execute")
        self.assertLess(exec_pos, on_create_pos,
                        "onCreate must be dispatched after interp.execute")

    def test_py_text_lib_and_bf_clicker_add_hud_texts(self):
        py_text = read("source/psychlua/pystdlib/PyTextLib.hx")
        self.assertIn('PythonScript.registerFunction("addLuaText"', py_text)
        self.assertIn('PythonScript.registerFunction("removeLuaText"', py_text)

        bf_clicker = read("mods/bf-clicker/data/bf-clicker/bf-clicker.py")
        compile(bf_clicker, "bf-clicker.py", "exec")
        self.assertNotRegex(bf_clicker, r"(?m)^\s*global\s+",
                            "Hython 0.0.352-beta Parser does not support global statements")
        for tag in ("clicksTxt", "timeTxt2", "bestTxt", "missTxt", "helpTxt"):
            self.assertIn(f"makeLuaText('{tag}'", bf_clicker)
            self.assertIn(f"addLuaText('{tag}')", bf_clicker)


if __name__ == "__main__":
    unittest.main(verbosity=2)
