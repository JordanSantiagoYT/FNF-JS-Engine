# Low-level diagnostic utilities

`debug.mem.GetTotalMemory` provides current/peak process resident memory.
`debug.system.SystemInfo` adds read-only, header-only native queries on C++
targets (Windows, Linux/Android, macOS/iOS):

| Method | Unit / meaning |
| --- | --- |
| `monotonicSeconds()` | Seconds from an unspecified origin; subtract two readings for elapsed time |
| `processCPUSeconds()` | Cumulative user + kernel CPU seconds, summed over all process threads |
| `logicalCPUCount()` | Online logical processors, at least one |
| `pageSize()` | OS memory page size in bytes |
| `totalPhysicalMemory()` | Host physical RAM in bytes, returned as Float to avoid 32-bit truncation |

```haxe
import debug.system.SystemInfo;

final start = SystemInfo.monotonicSeconds();
final cpuStart = SystemInfo.processCPUSeconds();
// Work to measure...
final elapsed = SystemInfo.monotonicSeconds() - start;
final cpu = SystemInfo.processCPUSeconds() - cpuStart;
// cpu / elapsed measures CPU cores occupied on average, and may exceed 1.
```

Failed/unsupported native queries return zero, except CPU count, which returns
one. Do not divide by an elapsed reading of zero. RAM/CPU count describe the
host, not process affinity, container quotas, free memory, or GC usage. Windows
CPU count reflects the current processor group on very large hosts.

Non-C++ targets use `haxe.Timer.stamp()` for elapsed timing and return zero for
native-only metrics (one for CPU count). No extra libraries are required.
These utilities are opt-in; they do not change the FPS display or sample in the
background.

Standalone Linux C/C++ smoke tests (no engine dependencies):

```sh
python3 -m unittest discover -s tests -p 'test_native_system.py' -v
```

The tests compile and link two translation units to verify header-only linkage,
then check sane query results and nondecreasing time readings. Native branches
for other operating systems should also be validated with their engine builds.
