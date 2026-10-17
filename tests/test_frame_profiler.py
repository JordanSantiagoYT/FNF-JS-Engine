"""Compile and execute the native C/C++ frame profiler and verify Haxe engine integration."""
from __future__ import annotations

import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
INCLUDE = ROOT / "source/debug/profiler/include"


class FrameProfilerNativeTests(unittest.TestCase):
    def run_native_suite(self, compiler: str, standard: str) -> None:
        if not shutil.which(compiler):
            self.skipTest(f"{compiler} is not installed")

        with tempfile.TemporaryDirectory(prefix="phoenix-frame-profiler-") as directory:
            root = pathlib.Path(directory)
            # Second translation unit ensures header-only linkage works across hxcpp TUs.
            (root / "second_tu.c").write_text(
                '#include "phoenix_profiler.h"\n'
                "double secondTuClock(void) { return phoenixProfilerNowMs(); }\n",
                encoding="utf-8",
            )
            (root / "main.c").write_text(
                r'''
#include "phoenix_profiler.h"
#include "phoenix_profiler.h"
#include <assert.h>
#include <math.h>
#include <string.h>

extern double secondTuClock(void);

static int approx(double a, double b, double eps)
{
  return (a > b ? (a - b) : (b - a)) <= eps;
}

int main(void)
{
  static PhoenixProfilerState state;
  PhoenixProfilerSummary summary;
  PhoenixFrameSample sample;
  char resolvedPath[PHOENIX_PROFILER_PATH_MAX];
  int i;

  assert(secondTuClock() > 0.0);

  phoenixProfilerInit(&state, 60.0);
  assert(phoenixProfilerIsEnabled(&state) == 1);
  phoenixProfilerSetStateName(&state, "play.PlayState");

  /* Frame 1: normal 60 FPS frame with nested audio inside update + explicit GC */
  phoenixProfilerBeginFrameAt(&state, 1000.0, 1000000, 4000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1001.0, 1000000);
  /* Nested audio call inside update */
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_AUDIO, 1002.0, 1020000);
  phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_AUDIO, 1003.5, 1030000);
  phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1006.5, 1060000);

  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_RENDER, 1007.0, 1060000);
  phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_RENDER, 1012.0, 1100000);

  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_GC, 1012.5, 1100000);
  phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_GC, 1014.5, 850000);

  assert(phoenixProfilerEndFrameAt(&state, 1016.6667, 16.6667, 850000, 4000000, 55) != NULL);

  assert(phoenixProfilerGetLastFrame(&state, &sample) == 1);
  assert(sample.frameIndex == 1);
  assert(approx(sample.frameTimeMs, 16.6667, 1e-3));
  assert(approx(sample.fps, 60.0, 0.1));
  /* Update raw was 5.5ms, minus 1.5ms nested audio = 4.0ms net update */
  assert(approx(sample.updateTimeMs, 4.0, 1e-3));
  assert(approx(sample.audioTimeMs, 1.5, 1e-3));
  assert(approx(sample.renderTimeMs, 5.0, 1e-3));
  assert(approx(sample.gcPauseMs, 2.0, 1e-3));
  assert(sample.allocBytes == 100000);
  assert(sample.gcReclaimedBytes == 250000);
  assert(sample.netHeapDeltaBytes == -150000);
  assert(sample.gcCount == 1);
  assert(sample.explicitGcCount == 1);
  assert(sample.implicitGcCount == 0);
  assert(sample.drawCalls == 55);
  assert(sample.updateSteps == 1);
  assert(strcmp(sample.stateName, "play.PlayState") == 0);

  /* Frame 2: spike frame (35ms) with implicit GC detected during update */
  phoenixProfilerBeginFrameAt(&state, 1016.6667, 850000, 4000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1017.0, 900000);
  /* Heap drops from 900000 to 700000 without explicit beginGC -> implicit GC detected */
  phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1029.0, 700000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_RENDER, 1029.5, 720000);
  phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_RENDER, 1045.5, 750000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_AUDIO, 1046.0, 750000);
  phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_AUDIO, 1048.0, 760000);
  assert(phoenixProfilerEndFrameAt(&state, 1051.6667, 35.0, 760000, 4000000, 70) != NULL);

  assert(phoenixProfilerGetLastFrame(&state, &sample) == 1);
  assert(sample.frameIndex == 2);
  assert(sample.implicitGcCount == 1);
  assert(sample.gcCount == 1);
  assert(sample.gcReclaimedBytes == 200000);
  assert(sample.gcPauseMs > 0.0);
  assert(sample.allocBytes == 110000);

  phoenixProfilerComputeSummary(&state, &summary);
  assert(summary.totalFrames == 2);
  assert(summary.bufferedFrames == 2);
  assert(summary.spikeCount25Ms == 1);
  assert(summary.spikeCount33Ms == 1);
  assert(summary.totalGcCount == 2);
  assert(summary.totalExplicitGcCount == 1);
  assert(summary.totalImplicitGcCount == 1);
  assert(summary.totalGcReclaimedBytes == 450000);
  assert(summary.totalAllocBytes == 210000);
  assert(summary.peakFrameAllocBytes == 110000);
  assert(summary.peakFrameAllocFrame == 2);

  /* Path sanitization: block path traversal and enforce debug/log/ folder with .log suffix */
  assert(phoenixProfilerResolveLogPath("../../../etc/evil", resolvedPath, sizeof(resolvedPath)) == 1);
  assert(strcmp(resolvedPath, "debug/log/evil.log") == 0);
  assert(phoenixProfilerResolveLogPath("session_profile", resolvedPath, sizeof(resolvedPath)) == 1);
  assert(strcmp(resolvedPath, "debug/log/session_profile.log") == 0);

  /* Export report to debug/log/ */
  assert(phoenixProfilerExportLog(&state, "session_profile.log", "0.3.2", "TestPlatform", resolvedPath, sizeof(resolvedPath)) == 1);
  assert(strcmp(resolvedPath, "debug/log/session_profile.log") == 0);

  /* Ring buffer wrap-around test (> PHOENIX_PROFILER_RING_CAPACITY frames) */
  phoenixProfilerReset(&state);
  for (i = 0; i < PHOENIX_PROFILER_RING_CAPACITY + 100; ++i)
  {
    double t0 = 2000.0 + (double)i * 16.0;
    phoenixProfilerBeginFrameAt(&state, t0, 500000 + (i % 10) * 1024, 2000000);
    phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_UPDATE, 3.0);
    phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_RENDER, 4.0);
    phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_AUDIO, 1.0);
    phoenixProfilerEndFrameAt(&state, t0 + 16.0, 16.0, 500000 + ((i + 1) % 10) * 1024, 2000000, 10);
  }
  phoenixProfilerComputeSummary(&state, &summary);
  assert(summary.totalFrames == (uint64_t)(PHOENIX_PROFILER_RING_CAPACITY + 100));
  assert(summary.bufferedFrames == (size_t)PHOENIX_PROFILER_RING_CAPACITY);
  assert(phoenixProfilerGetBufferedFrame(&state, 0, &sample) == 1);
  assert(sample.frameIndex == 101);

  return 0;
}
''',
                encoding="utf-8",
            )
            executable = root / "test_profiler"
            subprocess.run(
                [
                    compiler,
                    f"-std={standard}",
                    "-Wall",
                    "-Wextra",
                    "-Werror",
                    "-I",
                    str(INCLUDE),
                    str(root / "main.c"),
                    str(root / "second_tu.c"),
                    "-o",
                    str(executable),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run([str(executable)], cwd=str(root), check=True)

            log_path = root / "debug/log/session_profile.log"
            self.assertTrue(log_path.is_file(), "Expected .log file in debug/log/ folder")
            content = log_path.read_text(encoding="utf-8")
            for expected in (
                "PHOENIX ENGINE - FRAME PROFILER LOG REPORT",
                "[1] FRAMETIME & FPS SUMMARY",
                "[2] SUBSYSTEM TIMINGS (UPDATES, RENDERING, AUDIO)",
                "[3] GARBAGE COLLECTION (GC PAUSES)",
                "[4] ALLOCATIONS & MEMORY USAGE",
                "[5] TOP SLOWEST FRAMES (BOTTLENECK ANALYSIS)",
                "[6] PER-FRAME TIMELINE (CSV)",
                "frame,timestamp_ms,frametime_ms,work_ms,fps,rolling_fps,update_ms,render_ms,audio_ms,gc_pause_ms,other_ms,alloc_bytes",
                "play.PlayState",
            ):
                self.assertIn(expected, content)

    def test_c_gnu99(self) -> None:
        self.run_native_suite("cc", "gnu99")

    def test_cpp_11(self) -> None:
        self.run_native_suite("c++", "c++11")

    def test_cpp_17(self) -> None:
        self.run_native_suite("c++", "c++17")


class FrameProfilerIntegrationTests(unittest.TestCase):
    def test_profiler_files_and_hooks_exist(self) -> None:
        profiler_hx = (ROOT / "source/debug/FrameProfiler.hx").read_text(encoding="utf-8")
        native_hx = (ROOT / "source/debug/profiler/NativeFrameProfiler.hx").read_text(encoding="utf-8")
        flx_game = (ROOT / "source/source-haxelib-patches/flixel/FlxGame.hx").read_text(encoding="utf-8")
        paths_hx = (ROOT / "source/backend/Paths.hx").read_text(encoding="utf-8")
        main_hx = (ROOT / "source/Main.hx").read_text(encoding="utf-8")
        fps_hx = (ROOT / "source/debug/FPSCounter.hx").read_text(encoding="utf-8")

        self.assertTrue((ROOT / "source/debug/profiler/build.xml").is_file())
        self.assertTrue((ROOT / "source/debug/profiler/include/phoenix_profiler.h").is_file())

        self.assertIn('LOG_DIR:String = "debug/log"', profiler_hx)
        self.assertIn("exportLog", profiler_hx)
        self.assertIn("beginUpdate", profiler_hx)
        self.assertIn("beginRender", profiler_hx)
        self.assertIn("beginAudio", profiler_hx)
        self.assertIn("beginGC", profiler_hx)

        self.assertIn("phoenix_profiler.h", native_hx)
        self.assertIn("FrameProfiler.beginFrame()", flx_game)
        self.assertIn("FrameProfiler.endFrame(", flx_game)
        self.assertIn("FrameProfiler.beginUpdate()", flx_game)
        self.assertIn("FrameProfiler.endUpdate()", flx_game)
        self.assertIn("FrameProfiler.beginRender()", flx_game)
        self.assertIn("FrameProfiler.endRender()", flx_game)
        self.assertIn("FrameProfiler.beginAudio()", flx_game)
        self.assertIn("FrameProfiler.endAudio()", flx_game)

        self.assertIn("FrameProfiler.beginGC(", paths_hx)
        self.assertIn("FrameProfiler.endGC()", paths_hx)
        self.assertIn("FrameProfiler.init(", main_hx)
        self.assertIn("FrameProfiler.getOverlayText()", fps_hx)


if __name__ == "__main__":
    unittest.main()
