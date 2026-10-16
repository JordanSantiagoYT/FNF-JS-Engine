"""Compile and execute the header independently of Haxe/Lime."""
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
INCLUDE = ROOT / "source/debug/system/include"


class NativeSystemTests(unittest.TestCase):
    def check_compiler(self, compiler, standard):
        if not shutil.which(compiler):
            self.skipTest(f"{compiler} is not installed")
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            # Two translation units catch header-only linkage regressions.
            (root / "other.c").write_text(
                '#include "phoenix_system.h"\n'
                'double other(void) { return phoenixMonotonicSeconds(); }\n'
            )
            (root / "main.c").write_text(r'''
#include "phoenix_system.h"
#include "phoenix_system.h"
#include <assert.h>
extern double other(void);
int main(void)
{
  double start = phoenixMonotonicSeconds();
  double cpu = phoenixProcessCPUSeconds();
  volatile unsigned long sum = 0;
  unsigned long i;
  assert(start > 0.0);
  assert(phoenixLogicalCPUCount() >= 1);
  assert(phoenixPageSize() > 0);
  assert(phoenixTotalPhysicalMemory() >= (double)phoenixPageSize());
  for (i = 0; i < 1000000; ++i) sum += i;
  assert(phoenixProcessCPUSeconds() >= cpu);
  assert(other() >= start);
  (void)sum;
  return 0;
}
''')
            executable = root / "test"
            subprocess.run([
                compiler, f"-std={standard}", "-Wall", "-Wextra", "-Werror",
                "-I", str(INCLUDE), str(root / "main.c"), str(root / "other.c"),
                "-o", str(executable),
            ], check=True, capture_output=True, text=True)
            subprocess.run([str(executable)], check=True)

    def test_c(self):
        self.check_compiler("cc", "gnu99")

    def test_cpp(self):
        self.check_compiler("c++", "c++11")


if __name__ == "__main__":
    unittest.main()
