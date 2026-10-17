"""Behavioral, statistical, security, and overhead benchmark tests for the Haxe + C/C++ frame profiler."""
from __future__ import annotations

import csv
import io
import json
import math
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
INCLUDE = ROOT / "source/debug/profiler/include"


def reference_percentile_r7(sorted_values: list[float], q: float) -> float:
    """Hyndman-Fan Type 7 linear interpolation quantile matching phoenixProfilerPercentileFromSorted."""
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1 or q <= 0.0:
        return sorted_values[0]
    if q >= 1.0:
        return sorted_values[-1]
    pos = q * (len(sorted_values) - 1)
    lo = int(math.floor(pos))
    hi = min(len(sorted_values) - 1, lo + 1)
    weight = pos - lo
    return sorted_values[lo] * (1.0 - weight) + sorted_values[hi] * weight


def reference_slowest_tail_mean_fps(sorted_values: list[float], tail_fraction: float) -> float:
    """Harmonic mean FPS (1000 / mean_ms) of the slowest ceil(tail_fraction * N) frames."""
    if not sorted_values or tail_fraction <= 0.0:
        return 0.0
    tail_count = max(1, min(len(sorted_values), int(math.ceil(tail_fraction * len(sorted_values)))))
    slowest = sorted_values[-tail_count:]
    avg_ms = sum(slowest) / len(slowest)
    return (1000.0 / avg_ms) if avg_ms > 0.0 else 0.0


class FrameProfilerNativeTests(unittest.TestCase):
    def run_native_suite(self, compiler: str, standard: str) -> None:
        if not shutil.which(compiler):
            self.skipTest(f"{compiler} is not installed")

        with tempfile.TemporaryDirectory(prefix="phoenix-frame-profiler-") as directory:
            root = pathlib.Path(directory)
            # Second translation unit verifies header-only ODR safety across hxcpp TUs.
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
#include <stdio.h>
#include <string.h>

extern double secondTuClock(void);

static int approx(double a, double b, double eps)
{
  return (a > b ? (a - b) : (b - a)) <= eps;
}

static void testComplexNestedPhasesAndHonestGC(void)
{
  static PhoenixProfilerState state;
  PhoenixFrameSample sample;
  PhoenixProfilerSummary summary;

  phoenixProfilerInit(&state, 60.0);
  assert(phoenixProfilerIsEnabled(&state) == 1);
  phoenixProfilerSetStateName(&state, "play.PlayState");

  /*
   * Frame 1: Complex 3-level nesting + sibling child phases inside UPDATE:
   * - Frame begins at t=1000.0, heap=1,000,000
   * - UPDATE begins at t=1001.0 (heap=1,000,000)
   *   - Re-entrant UPDATE begins at t=1001.5 and ends at t=1001.8 (must coalesce)
   *   - AUDIO begins at t=1002.0 (heap=1,020,000 -> +20,000 alloc)
   *     - Explicit GC begins at t=1002.5 (heap=1,030,000 -> +10,000 alloc)
   *     - Explicit GC ends at t=1004.0 (1.5ms GC pause, heap=830,000 -> 200,000 reclaimed)
   *   - AUDIO ends at t=1005.0 (raw 3.0ms - 1.5ms GC = 1.5ms exclusive audio; heap=840,000 -> +10,000 alloc)
   *   - RENDER (e.g. FFmpeg pipeFrame inside PlayState.update) begins at t=1005.5 (heap=840,000)
   *   - RENDER ends at t=1007.5 (2.0ms exclusive render; heap=860,000 -> +20,000 alloc)
   * - UPDATE ends at t=1010.0 (raw 9.0ms - 3.0ms audio_raw - 2.0ms render_raw = 4.0ms exclusive update; heap=900,000 -> +40,000 alloc)
   * - Unmatched endPhase calls outside active phases must return 0.0 and not corrupt state
   * - Main RENDER begins at t=1010.5 (heap=900,000) and ends at t=1013.5 (3.0ms; heap=920,000 -> +20,000 alloc)
   * - Frame ends at t=1016.0 (work=16.0ms, frameTime=16.0ms, heap=920,000)
   */
  phoenixProfilerBeginFrameAt(&state, 1000.0, 1000000, 4000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1001.0, 1000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1001.5, 1000000);
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1001.8, 1000000), 0.0, 1e-6));

  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_AUDIO, 1002.0, 1020000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_GC, 1002.5, 1030000);
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_GC, 1004.0, 830000), 1.5, 1e-4));
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_AUDIO, 1005.0, 840000), 1.5, 1e-4));

  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_RENDER, 1005.5, 840000);
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_RENDER, 1007.5, 860000), 2.0, 1e-4));

  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1010.0, 900000), 4.0, 1e-4));

  /* Unmatched phase ends must be safe no-ops */
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1010.2, 900000), 0.0, 1e-6));
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_AUDIO, 1010.2, 900000), 0.0, 1e-6));
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_RENDER, 1010.2, 900000), 0.0, 1e-6));
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_GC, 1010.2, 900000), 0.0, 1e-6));

  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_RENDER, 1010.5, 900000);
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_RENDER, 1013.5, 920000), 3.0, 1e-4));

  assert(phoenixProfilerEndFrameAt(&state, 1016.0, 16.0, 920000, 4000000, 42) != NULL);
  assert(phoenixProfilerGetLastFrame(&state, &sample) == 1);

  assert(sample.frameIndex == 1);
  assert(approx(sample.frameTimeMs, 16.0, 1e-4));
  assert(approx(sample.workTimeMs, 16.0, 1e-4));
  assert(approx(sample.updateTimeMs, 4.0, 1e-4));
  assert(approx(sample.audioTimeMs, 1.5, 1e-4));
  assert(approx(sample.renderTimeMs, 5.0, 1e-4)); /* 2.0ms nested + 3.0ms main */
  assert(approx(sample.gcPauseMs, 1.5, 1e-4));
  assert(approx(sample.otherTimeMs, 4.0, 1e-4)); /* 16.0 - (4.0 + 1.5 + 5.0 + 1.5) */
  assert(sample.allocBytes == 120000);
  assert(sample.gcReclaimedBytes == 200000);
  assert(sample.netHeapDeltaBytes == -80000);
  assert(sample.allocBytes - sample.gcReclaimedBytes == sample.netHeapDeltaBytes);
  assert(sample.gcCount == 1);
  assert(sample.explicitGcCount == 1);
  assert(sample.implicitGcCount == 0);
  assert(sample.updateSteps == 1);
  assert(sample.drawCalls == 42);

  /*
   * Frame 2: Inter-frame heap growth + negative heap delta WITHOUT explicit beginGC:
   * - Heap grew from 920,000 (end of Frame 1) to 950,000 at start of Frame 2 (+30,000 inter-frame)
   * - During UPDATE (1017.0 -> 1025.0 = 8.0ms), heap drops from 950,000 to 750,000 (-200,000)
   * - Honest GC requirement:
   *   * implicitGcCount increments by 1 (observed heap contraction)
   *   * gcCount MUST remain 0 (no measured GC pause event!)
   *   * gcPauseMs MUST remain 0.0 (no fabricated pause duration!)
   *   * updateTimeMs MUST remain the full 8.0ms (nothing subtracted!)
   *   * allocBytes - gcReclaimedBytes == netHeapDeltaBytes (30,000 - 200,000 == -170,000 == 750,000 - 920,000)
   */
  phoenixProfilerBeginFrameAt(&state, 1016.5, 950000, 4000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1017.0, 950000);
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1025.0, 750000), 8.0, 1e-4));
  assert(phoenixProfilerEndFrameAt(&state, 1036.0, 0.0, 750000, 4000000, 30) != NULL);

  assert(phoenixProfilerGetLastFrame(&state, &sample) == 1);
  assert(sample.frameIndex == 2);
  /* Frame 2 end-to-end wall time is 1036.0 - 1016.0 (lastFrameEndMs) = 20.0ms */
  assert(approx(sample.frameTimeMs, 20.0, 1e-4));
  assert(approx(sample.workTimeMs, 19.5, 1e-4));
  assert(approx(sample.updateTimeMs, 8.0, 1e-4));
  assert(approx(sample.gcPauseMs, 0.0, 1e-6));
  assert(sample.gcCount == 0);
  assert(sample.explicitGcCount == 0);
  assert(sample.implicitGcCount == 1);
  assert(sample.allocBytes == 30000);
  assert(sample.gcReclaimedBytes == 200000);
  assert(sample.netHeapDeltaBytes == -170000);
  assert(sample.allocBytes - sample.gcReclaimedBytes == sample.netHeapDeltaBytes);

  /*
   * Frame 3: Unclosed child phase inside UPDATE + unclosed RENDER at endFrame:
   * - UPDATE starts at 1037.0
   * - AUDIO starts at 1038.0 and is NOT explicitly closed before UPDATE ends at 1041.0
   *   -> AUDIO auto-closes at 1041.0 (3.0ms), leaving UPDATE with 1.0ms exclusive time!
   * - RENDER starts at 1042.0 and is left open until endFrame at 1046.0
   *   -> RENDER auto-closes at 1046.0 (4.0ms)!
   */
  phoenixProfilerBeginFrameAt(&state, 1036.5, 750000, 4000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1037.0, 750000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_AUDIO, 1038.0, 750000);
  assert(approx(phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_UPDATE, 1041.0, 750000), 1.0, 1e-4));
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_RENDER, 1042.0, 750000);
  assert(phoenixProfilerEndFrameAt(&state, 1046.0, 0.0, 750000, 4000000, 15) != NULL);

  assert(phoenixProfilerGetLastFrame(&state, &sample) == 1);
  assert(approx(sample.updateTimeMs, 1.0, 1e-4));
  assert(approx(sample.audioTimeMs, 3.0, 1e-4));
  assert(approx(sample.renderTimeMs, 4.0, 1e-4));

  /* Verify summary avgGcPauseMs is NOT diluted by Frame 2's implicit heap contraction */
  phoenixProfilerComputeSummary(&state, &summary);
  assert(summary.totalFrames == 3);
  assert(summary.totalGcCount == 1);
  assert(summary.totalExplicitGcCount == 1);
  assert(summary.totalImplicitGcCount == 1);
  assert(approx(summary.totalGcPauseMs, 1.5, 1e-4));
  assert(approx(summary.avgGcPauseMs, 1.5, 1e-4));
}

static void testDisableEnableAndInterruptedFrame(void)
{
  static PhoenixProfilerState state;
  PhoenixFrameSample sample;

  phoenixProfilerInit(&state, 60.0);
  phoenixProfilerBeginFrameAt(&state, 100.0, 500000, 2000000);
  phoenixProfilerEndFrameAt(&state, 116.0, 16.0, 510000, 2000000, 10);

  /* Start an interrupted frame that grows heap to 900,000, then disable mid-frame */
  phoenixProfilerBeginFrameAt(&state, 116.5, 510000, 2000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 117.0, 900000);
  phoenixProfilerSetEnabled(&state, 0);
  assert(phoenixProfilerIsEnabled(&state) == 0);

  /* Calls while disabled must be ignored */
  phoenixProfilerBeginFrameAt(&state, 2000.0, 900000, 2000000);
  assert(phoenixProfilerEndFrameAt(&state, 2016.0, 16.0, 900000, 2000000, 10) == NULL);

  /* Re-enable 5 seconds later at t=6000.0: first frame must NOT include the 5s disabled gap */
  phoenixProfilerSetEnabled(&state, 1);
  phoenixProfilerBeginFrameAt(&state, 6000.0, 600000, 2000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 6001.0, 610000);
  phoenixProfilerEndPhaseAt(&state, PHOENIX_PHASE_UPDATE, 6005.0, 620000);
  assert(phoenixProfilerEndFrameAt(&state, 6015.0, 0.0, 620000, 2000000, 20) != NULL);

  assert(phoenixProfilerGetLastFrame(&state, &sample) == 1);
  assert(sample.frameIndex == 2);
  assert(approx(sample.frameTimeMs, 15.0, 1e-4));
  assert(approx(sample.workTimeMs, 15.0, 1e-4));
  assert(sample.allocBytes == 20000);
  assert(sample.netHeapDeltaBytes == 20000);
}

static void testNaNAndInvalidInputs(void)
{
  static PhoenixProfilerState state;
  PhoenixProfilerSummary summary;
  PhoenixFrameSample sample;
  double nanVal = 0.0 / 0.0;
  double infVal = 1.0 / 0.0;

  phoenixProfilerInit(&state, nanVal);
  phoenixProfilerComputeSummary(&state, &summary);
  assert(approx(summary.targetFps, 60.0, 1e-4));

  phoenixProfilerBeginFrameAt(&state, 500.0, 100000, 500000);
  phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_UPDATE, nanVal);
  phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_UPDATE, -50.0);
  phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_RENDER, infVal);
  phoenixProfilerRecordGCPause(&state, nanVal, -100, 1);
  phoenixProfilerEndFrameAt(&state, 510.0, nanVal, 100000, 500000, 5);

  assert(phoenixProfilerGetLastFrame(&state, &sample) == 1);
  assert(phoenixProfilerIsFinite(sample.frameTimeMs));
  assert(approx(sample.frameTimeMs, 10.0, 1e-4));
  assert(approx(sample.updateTimeMs, 0.0, 1e-6));
  assert(approx(sample.gcPauseMs, 0.0, 1e-6));
}

int main(void)
{
  static PhoenixProfilerState state;
  PhoenixProfilerSummary summary;
  PhoenixFrameSample sample;
  char resolvedPath[PHOENIX_PROFILER_PATH_MAX];
  int i;

  assert(secondTuClock() > 0.0);

  testComplexNestedPhasesAndHonestGC();
  testDisableEnableAndInterruptedFrame();
  testNaNAndInvalidInputs();

  /* Path confinement tests: block traversal, absolute paths, and nested subdirs */
  assert(phoenixProfilerResolveLogPath("../../../etc/evil", resolvedPath, sizeof(resolvedPath)) == 1);
  assert(strcmp(resolvedPath, "debug/log/evil.log") == 0);
  assert(phoenixProfilerResolveLogPath("/tmp/debug/log/escape.log", resolvedPath, sizeof(resolvedPath)) == 1);
  assert(strcmp(resolvedPath, "debug/log/escape.log") == 0);
  assert(phoenixProfilerResolveLogPath("debug/log/subdir/nested", resolvedPath, sizeof(resolvedPath)) == 1);
  assert(strcmp(resolvedPath, "debug/log/nested.log") == 0);
  assert(phoenixProfilerResolveLogPath("session_profile", resolvedPath, sizeof(resolvedPath)) == 1);
  assert(strcmp(resolvedPath, "debug/log/session_profile.log") == 0);

  /* Verify overlay formatting on empty vs populated state */
  phoenixProfilerInit(&state, 60.0);
  {
    char overlayBuf[512];
    assert(phoenixProfilerFormatOverlay(&state, overlayBuf, sizeof(overlayBuf)) == 0);
    assert(strcmp(overlayBuf, "") == 0);

    /* Empty-session log export (0 frames recorded) must succeed and write valid report */
    assert(phoenixProfilerExportLog(&state, "empty_session.log", "0.3.2", "TestPlatform", resolvedPath, sizeof(resolvedPath)) == 1);
    assert(strcmp(resolvedPath, "debug/log/empty_session.log") == 0);
  }

  /* Timing-only mode (collectMemoryMetrics = 0) must mark heap/RSS unavailable and print N/A */
  phoenixProfilerInit(&state, 60.0);
  phoenixProfilerSetCollectMemoryMetrics(&state, 0);
  phoenixProfilerBeginFrameAt(&state, 100.0, 500000, 2000000);
  phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_UPDATE, 4.0);
  phoenixProfilerEndFrameAt(&state, 116.0, 16.0, 550000, 2000000, 12);
  /* Start an interrupted frame and export mid-frame -> interrupted frame must be aborted cleanly */
  phoenixProfilerBeginFrameAt(&state, 120.0, 550000, 2000000);
  phoenixProfilerBeginPhaseAt(&state, PHOENIX_PHASE_UPDATE, 121.0, 600000);
  assert(phoenixProfilerExportLog(&state, "timing_only.log", "0.3.2", "TestPlatform", resolvedPath, sizeof(resolvedPath)) == 1);
  phoenixProfilerComputeSummary(&state, &summary);
  assert(summary.totalFrames == 1);
  assert(summary.heapStatsAvailable == 0);
  assert(summary.rssAvailable == 0);
  {
    char overlayBuf[512];
    assert(phoenixProfilerFormatOverlay(&state, overlayBuf, sizeof(overlayBuf)) == 1);
    assert(strstr(overlayBuf, "Frame:") != NULL);
    assert(strstr(overlayBuf, "F6 Export .log") != NULL);
  }

  /* Synthetic distribution & CSV escaping test */
  phoenixProfilerInit(&state, 60.0);
  phoenixProfilerSetRssSampleInterval(&state, 10);
  phoenixProfilerSetStateName(&state, "play.PlayState, \"Hard\"\nPhase 2");

  for (i = 0; i < 100; ++i)
  {
    /* 90 frames at 16.0ms, 9 frames at 25.0ms, 1 outlier frame at 50.0ms */
    double ft = (i == 99) ? 50.0 : ((i >= 90) ? 25.0 : 16.0);
    double t0 = 10000.0 + (double)i * 20.0;
    phoenixProfilerBeginFrameAt(&state, t0, 1000000 + i * 1000, 4000000);
    phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_UPDATE, ft * 0.4);
    phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_RENDER, ft * 0.4);
    phoenixProfilerRecordPhaseMs(&state, PHOENIX_PHASE_AUDIO, ft * 0.1);
    phoenixProfilerEndFrameAt(&state, t0 + ft, ft, 1000000 + (i + 1) * 1000, 4000000, 25);

    assert(phoenixProfilerGetLastFrame(&state, &sample) == 1);
    /* RSS must be freshly sampled on frame 1 and multiples of 10 */
    if ((i + 1) == 1 || ((i + 1) % 10) == 0)
      assert(sample.rssSampled == 1);
    else
      assert(sample.rssSampled == 0);
  }

  assert(phoenixProfilerExportLog(&state, "session_profile.log", "0.3.2", "TestPlatform", resolvedPath, sizeof(resolvedPath)) == 1);
  assert(strcmp(resolvedPath, "debug/log/session_profile.log") == 0);

  /* Write summary JSON so Python test can compare against independent reference formulas */
  phoenixProfilerComputeSummary(&state, &summary);
  {
    FILE *jf = fopen("summary.json", "wb");
    assert(jf != NULL);
    fprintf(jf,
      "{\"totalFrames\":%llu,\"avgFrameTimeMs\":%.8f,\"stdDevFrameTimeMs\":%.8f,"
      "\"minFrameTimeMs\":%.8f,\"maxFrameTimeMs\":%.8f,"
      "\"p50FrameTimeMs\":%.8f,\"p95FrameTimeMs\":%.8f,\"p99FrameTimeMs\":%.8f,\"p999FrameTimeMs\":%.8f,"
      "\"onePercentLowFps\":%.8f,\"pointOnePercentLowFps\":%.8f,"
      "\"slowest1PctAvgFps\":%.8f,\"slowest01PctAvgFps\":%.8f}\n",
      (unsigned long long)summary.totalFrames,
      summary.avgFrameTimeMs,
      summary.stdDevFrameTimeMs,
      summary.minFrameTimeMs,
      summary.maxFrameTimeMs,
      summary.p50FrameTimeMs,
      summary.p95FrameTimeMs,
      summary.p99FrameTimeMs,
      summary.p999FrameTimeMs,
      summary.onePercentLowFps,
      summary.pointOnePercentLowFps,
      summary.slowest1PctAvgFps,
      summary.slowest01PctAvgFps);
    fclose(jf);
  }

  /* Ring buffer wrap-around test (> PHOENIX_PROFILER_RING_CAPACITY frames) */
  phoenixProfilerReset(&state);
  for (i = 0; i < PHOENIX_PROFILER_RING_CAPACITY + 100; ++i)
  {
    double t0 = 50000.0 + (double)i * 16.0;
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
  assert(phoenixProfilerGetBufferedFrame(&state, PHOENIX_PROFILER_RING_CAPACITY - 1, &sample) == 1);
  assert(sample.frameIndex == (uint64_t)(PHOENIX_PROFILER_RING_CAPACITY + 100));

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

            # Compare C summary against independent Python reference implementation
            summary_data = json.loads((root / "summary.json").read_text(encoding="utf-8"))
            ref_ft = sorted([16.0] * 90 + [25.0] * 9 + [50.0])
            ref_mean = sum(ref_ft) / len(ref_ft)
            ref_var = (sum(x * x for x in ref_ft) / len(ref_ft)) - (ref_mean * ref_mean)
            ref_std = math.sqrt(max(0.0, ref_var))
            ref_p50 = reference_percentile_r7(ref_ft, 0.50)
            ref_p95 = reference_percentile_r7(ref_ft, 0.95)
            ref_p99 = reference_percentile_r7(ref_ft, 0.99)
            ref_p999 = reference_percentile_r7(ref_ft, 0.999)

            self.assertEqual(summary_data["totalFrames"], 100)
            self.assertAlmostEqual(summary_data["avgFrameTimeMs"], ref_mean, places=5)
            self.assertAlmostEqual(summary_data["stdDevFrameTimeMs"], ref_std, places=5)
            self.assertAlmostEqual(summary_data["minFrameTimeMs"], 16.0, places=5)
            self.assertAlmostEqual(summary_data["maxFrameTimeMs"], 50.0, places=5)
            self.assertAlmostEqual(summary_data["p50FrameTimeMs"], ref_p50, places=5)
            self.assertAlmostEqual(summary_data["p95FrameTimeMs"], ref_p95, places=5)
            self.assertAlmostEqual(summary_data["p99FrameTimeMs"], ref_p99, places=5)
            self.assertAlmostEqual(summary_data["p999FrameTimeMs"], ref_p999, places=5)
            self.assertAlmostEqual(summary_data["onePercentLowFps"], 1000.0 / ref_p99, places=5)
            self.assertAlmostEqual(summary_data["pointOnePercentLowFps"], 1000.0 / ref_p999, places=5)
            self.assertAlmostEqual(
                summary_data["slowest1PctAvgFps"],
                reference_slowest_tail_mean_fps(ref_ft, 0.01),
                places=5,
            )
            self.assertAlmostEqual(
                summary_data["slowest01PctAvgFps"],
                reference_slowest_tail_mean_fps(ref_ft, 0.001),
                places=5,
            )

            # Verify exported .log structure and RFC 4180 CSV parsing
            log_path = root / "debug/log/session_profile.log"
            self.assertTrue(log_path.is_file(), "Expected .log file in debug/log/ folder")
            content = log_path.read_text(encoding="utf-8")
            for expected in (
                "PHOENIX ENGINE - FRAME PROFILER LOG REPORT",
                "[1] FRAMETIME & FPS SUMMARY",
                "[2] SUBSYSTEM TIMINGS (UPDATES, RENDERING, AUDIO)",
                "[3] GARBAGE COLLECTION (GC PAUSES & HEAP CONTRACTIONS)",
                "[4] ALLOCATIONS & MEMORY USAGE",
                "[5] TOP SLOWEST FRAMES (BOTTLENECK ANALYSIS)",
                "[6] PER-FRAME TIMELINE (CSV)",
            ):
                self.assertIn(expected, content)

            csv_section = content.split("[6] PER-FRAME TIMELINE (CSV)\n")[1]
            csv_lines = [
                line
                for line in csv_section.splitlines()
                if line and not line.startswith("---")
            ]
            reader = list(csv.reader(io.StringIO("\n".join(csv_lines))))
            self.assertEqual(len(reader), 101)  # 1 header + 100 frame rows
            header = reader[0]
            self.assertEqual(len(header), 25)
            for row in reader[1:]:
                self.assertEqual(len(row), 25, "Every CSV row must preserve exact 25-column count")
                self.assertEqual(row[24], 'play.PlayState, "Hard" Phase 2')

            # Verify empty-session log and timing-only (unavailable memory) log
            empty_log = (root / "debug/log/empty_session.log").read_text(encoding="utf-8")
            self.assertIn("Total Frames Recorded  : 0", empty_log)
            self.assertIn("No frames recorded.", empty_log)

            timing_only_log = (root / "debug/log/timing_only.log").read_text(encoding="utf-8")
            self.assertIn("Total Frames Recorded  : 1", timing_only_log)
            self.assertIn("Managed Heap Metrics   : N/A", timing_only_log)
            self.assertIn("Process RSS Memory     : N/A", timing_only_log)

            # Verify export failure handling when debug/log cannot be created
            blocked_dir = root / "blocked_workspace"
            blocked_dir.mkdir()
            # Create a regular file named "debug" so mkdir("debug") / mkdir("debug/log") fails
            (blocked_dir / "debug").write_text("file blocking directory creation", encoding="utf-8")
            (blocked_dir / "fail_test.c").write_text(
                r'''
#include "phoenix_profiler.h"
#include <assert.h>
#include <string.h>

int main(void)
{
  static PhoenixProfilerState state;
  char outPath[PHOENIX_PROFILER_PATH_MAX];
  strcpy(outPath, "untouched");
  phoenixProfilerInit(&state, 60.0);
  assert(phoenixProfilerExportLog(&state, "should_fail.log", "0.3.2", "Test", outPath, sizeof(outPath)) == 0);
  assert(strcmp(outPath, "") == 0);
  return 0;
}
''',
                encoding="utf-8",
            )
            fail_exe = blocked_dir / "fail_test"
            subprocess.run(
                [compiler, f"-std={standard}", "-I", str(INCLUDE), str(blocked_dir / "fail_test.c"), "-o", str(fail_exe)],
                check=True,
            )
            subprocess.run([str(fail_exe)], cwd=str(blocked_dir), check=True)

    def test_c_gnu99(self) -> None:
        self.run_native_suite("cc", "gnu99")

    def test_cpp_11(self) -> None:
        self.run_native_suite("c++", "c++11")

    def test_cpp_17(self) -> None:
        self.run_native_suite("c++", "c++17")

    def test_reproducible_overhead_benchmark(self) -> None:
        """Measures profiler hot-path overhead across modes with warmup and multiple trials."""
        compiler = "cc"
        if not shutil.which(compiler):
            self.skipTest("cc is not installed")

        with tempfile.TemporaryDirectory(prefix="phoenix-profiler-bench-") as directory:
            root = pathlib.Path(directory)
            (root / "benchmark.c").write_text(
                r'''
#include "phoenix_profiler.h"
#include <stdio.h>

static volatile uint64_t gSink = 0;

static inline void simulatedFrameWorkload(int iter)
{
  uint64_t acc = (uint64_t)iter;
  int i;
  for (i = 0; i < 200; ++i)
    acc = acc * 6364136223846793005ULL + 1442695040888963407ULL;
  gSink ^= acc;
}

static double runBaselineTrial(int frames)
{
  int i;
  double t0 = phoenixProfilerNowMs();
  for (i = 0; i < frames; ++i)
    simulatedFrameWorkload(i);
  return phoenixProfilerNowMs() - t0;
}

static double runProfiledTrial(PhoenixProfilerState *state, int frames, int collectMem, uint32_t rssInterval)
{
  int i;
  double t0;
  phoenixProfilerInit(state, 60.0);
  phoenixProfilerSetStateName(state, "play.PlayState");
  phoenixProfilerSetCollectMemoryMetrics(state, collectMem);
  phoenixProfilerSetRssSampleInterval(state, rssInterval);

  t0 = phoenixProfilerNowMs();
  for (i = 0; i < frames; ++i)
  {
    int64_t heapBase = 1000000 + (int64_t)((i % 16) * 1024);
    phoenixProfilerBeginFrame(state, heapBase, 4000000);
    phoenixProfilerBeginUpdate(state, heapBase);
    simulatedFrameWorkload(i);
    phoenixProfilerBeginAudio(state, heapBase + 512);
    phoenixProfilerEndAudio(state, heapBase + 1024);
    phoenixProfilerEndUpdate(state, heapBase + 2048);
    phoenixProfilerBeginRender(state, heapBase + 2048);
    phoenixProfilerEndRender(state, heapBase + 4096);
    phoenixProfilerEndFrame(state, heapBase + 4096, 4000000, 32);
  }
  return phoenixProfilerNowMs() - t0;
}

int main(void)
{
  static PhoenixProfilerState state;
  const int warmupFrames = 500;
  const int trialFrames = 2000;
  const int trials = 7;
  double baseUs[7], timingOnlyUs[7], defaultFullUs[7], everyFrameRssUs[7];
  int t;

  (void)runBaselineTrial(warmupFrames);
  (void)runProfiledTrial(&state, warmupFrames, 1, 60);

  for (t = 0; t < trials; ++t)
  {
    baseUs[t] = (runBaselineTrial(trialFrames) * 1000.0) / (double)trialFrames;
    timingOnlyUs[t] = (runProfiledTrial(&state, trialFrames, 0, 0) * 1000.0) / (double)trialFrames;
    defaultFullUs[t] = (runProfiledTrial(&state, trialFrames, 1, 60) * 1000.0) / (double)trialFrames;
    everyFrameRssUs[t] = (runProfiledTrial(&state, trialFrames, 1, 1) * 1000.0) / (double)trialFrames;
  }

  phoenixProfilerSortDoubles(baseUs, trials);
  phoenixProfilerSortDoubles(timingOnlyUs, trials);
  phoenixProfilerSortDoubles(defaultFullUs, trials);
  phoenixProfilerSortDoubles(everyFrameRssUs, trials);

  printf(
    "{\"baseline_p50_us\":%.4f,\"timing_only_p50_us\":%.4f,\"default_full_p50_us\":%.4f,"
    "\"default_full_p95_us\":%.4f,\"every_frame_rss_p50_us\":%.4f}\n",
    phoenixProfilerPercentileFromSorted(baseUs, trials, 0.50),
    phoenixProfilerPercentileFromSorted(timingOnlyUs, trials, 0.50),
    phoenixProfilerPercentileFromSorted(defaultFullUs, trials, 0.50),
    phoenixProfilerPercentileFromSorted(defaultFullUs, trials, 0.95),
    phoenixProfilerPercentileFromSorted(everyFrameRssUs, trials, 0.50));
  return 0;
}
''',
                encoding="utf-8",
            )
            exe = root / "benchmark"
            subprocess.run(
                [compiler, "-O2", "-std=gnu99", "-Wall", "-Wextra", "-Werror", "-I", str(INCLUDE), str(root / "benchmark.c"), "-o", str(exe)],
                check=True,
            )
            proc = subprocess.run([str(exe)], cwd=str(root), check=True, capture_output=True, text=True)
            metrics = json.loads(proc.stdout.strip())
            default_overhead_us = metrics["default_full_p50_us"] - metrics["baseline_p50_us"]
            every_rss_overhead_us = metrics["every_frame_rss_p50_us"] - metrics["baseline_p50_us"]

            # Budget check: default mode overhead must be well below 25us/frame (<0.15% of 16.67ms frame)
            # and strictly cheaper than querying OS RSS every single frame.
            self.assertLess(default_overhead_us, 25.0)
            self.assertLess(metrics["default_full_p50_us"], metrics["every_frame_rss_p50_us"])
            self.assertLess(default_overhead_us, every_rss_overhead_us)


class FrameProfilerIntegrationTests(unittest.TestCase):
    def test_profiler_files_and_hooks_exist(self) -> None:
        profiler_hx = (ROOT / "source/debug/FrameProfiler.hx").read_text(encoding="utf-8")
        native_hx = (ROOT / "source/debug/profiler/NativeFrameProfiler.hx").read_text(encoding="utf-8")
        flx_game = (ROOT / "source/source-haxelib-patches/flixel/FlxGame.hx").read_text(encoding="utf-8")
        paths_hx = (ROOT / "source/backend/Paths.hx").read_text(encoding="utf-8")
        main_hx = (ROOT / "source/Main.hx").read_text(encoding="utf-8")
        funkin_game_hx = (ROOT / "source/backend/FunkinGame.hx").read_text(encoding="utf-8")
        fps_hx = (ROOT / "source/debug/FPSCounter.hx").read_text(encoding="utf-8")

        self.assertTrue((ROOT / "source/debug/profiler/build.xml").is_file())
        self.assertTrue((ROOT / "source/debug/profiler/include/phoenix_profiler.h").is_file())

        self.assertIn('LOG_DIR:String = "debug/log"', profiler_hx)
        self.assertIn("exportLog", profiler_hx)
        self.assertIn("handleApplicationExit", profiler_hx)
        self.assertIn("toggleOverlay", profiler_hx)
        self.assertIn("escapeCsvField", profiler_hx)
        self.assertIn("[5] TOP SLOWEST FRAMES (BOTTLENECK ANALYSIS)", profiler_hx)
        self.assertIn("[6] PER-FRAME TIMELINE (CSV)", profiler_hx)

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
        self.assertIn("FrameProfiler.handleApplicationExit()", main_hx)
        self.assertNotIn("ClientPrefs.frameProfiler)\n        FrameProfiler.exportLog()", main_hx)
        self.assertIn("FrameProfiler.toggleOverlay()", funkin_game_hx)
        self.assertIn("FrameProfiler.getOverlayText()", fps_hx)
        self.assertIn("_lastStateInstance", profiler_hx)
        self.assertIn("rssSampleIntervalFrames", profiler_hx)
        self.assertIn("collectMemoryMetrics", profiler_hx)
        self.assertIn("FrameProfiler.endFrame(FlxG.renderTile ? FlxDrawBaseItem.drawCalls : 0);", flx_game)


if __name__ == "__main__":
    unittest.main()
