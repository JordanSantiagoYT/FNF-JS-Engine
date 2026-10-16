#ifndef PHOENIX_SYSTEM_H
#define PHOENIX_SYSTEM_H

#include <stddef.h>

#if defined(_WIN32)
#include <windows.h>
#elif defined(__unix__) || defined(__APPLE__)
#include <unistd.h>
#include <sys/resource.h>
#include <time.h>
#if defined(__APPLE__)
#include <mach/mach_time.h>
#include <sys/sysctl.h>
#endif
#endif

/* Header-only: internal linkage is required by hxcpp's multiple translation units.
 * Queries return zero on failure/unsupported platforms, except CPU count (one).
 * These functions observe the host; they do not change scheduling or allocate RAM.
 */

/** Monotonic seconds from an unspecified origin; use differences, not dates. */
static inline double phoenixMonotonicSeconds(void)
{
#if defined(_WIN32)
  LARGE_INTEGER counter, frequency;
  if (!QueryPerformanceFrequency(&frequency) || frequency.QuadPart <= 0 ||
      !QueryPerformanceCounter(&counter))
    return 0.0;
  return (double)counter.QuadPart / (double)frequency.QuadPart;
#elif defined(__APPLE__)
  mach_timebase_info_data_t scale;
  if (mach_timebase_info(&scale) != KERN_SUCCESS || scale.denom == 0)
    return 0.0;
  return (double)mach_absolute_time() * ((double)scale.numer / scale.denom) / 1e9;
#elif defined(CLOCK_MONOTONIC)
  struct timespec value;
  if (clock_gettime(CLOCK_MONOTONIC, &value) != 0)
    return 0.0;
  return (double)value.tv_sec + (double)value.tv_nsec / 1e9;
#else
  return 0.0;
#endif
}

/** Cumulative user + kernel CPU seconds for this process (all threads). */
static inline double phoenixProcessCPUSeconds(void)
{
#if defined(_WIN32)
  FILETIME creation, exitTime, kernel, user;
  ULARGE_INTEGER kernelTicks, userTicks;
  if (!GetProcessTimes(GetCurrentProcess(), &creation, &exitTime, &kernel, &user))
    return 0.0;
  kernelTicks.LowPart = kernel.dwLowDateTime;
  kernelTicks.HighPart = kernel.dwHighDateTime;
  userTicks.LowPart = user.dwLowDateTime;
  userTicks.HighPart = user.dwHighDateTime;
  return ((double)kernelTicks.QuadPart + (double)userTicks.QuadPart) / 1e7;
#elif defined(__unix__) || defined(__APPLE__)
  struct rusage usage;
  if (getrusage(RUSAGE_SELF, &usage) != 0)
    return 0.0;
  return (double)usage.ru_utime.tv_sec + (double)usage.ru_stime.tv_sec +
    ((double)usage.ru_utime.tv_usec + (double)usage.ru_stime.tv_usec) / 1e6;
#else
  return 0.0;
#endif
}

/** Online logical CPUs; not necessarily the process affinity/container limit. */
static inline int phoenixLogicalCPUCount(void)
{
#if defined(_WIN32)
  SYSTEM_INFO info;
  GetNativeSystemInfo(&info);
  return info.dwNumberOfProcessors > 0 ? (int)info.dwNumberOfProcessors : 1;
#elif defined(_SC_NPROCESSORS_ONLN)
  long count = sysconf(_SC_NPROCESSORS_ONLN);
  return count > 0 ? (int)count : 1;
#else
  return 1;
#endif
}

/** OS memory page size in bytes, or zero when unavailable. */
static inline size_t phoenixPageSize(void)
{
#if defined(_WIN32)
  SYSTEM_INFO info;
  GetNativeSystemInfo(&info);
  return (size_t)info.dwPageSize;
#elif defined(_SC_PAGESIZE)
  long size = sysconf(_SC_PAGESIZE);
  return size > 0 ? (size_t)size : 0;
#else
  return 0;
#endif
}

/** Host physical RAM in bytes, not free memory or a container allocation limit.
 * A double avoids truncating machines with >4 GiB RAM on 32-bit targets.
 */
static inline double phoenixTotalPhysicalMemory(void)
{
#if defined(_WIN32)
  MEMORYSTATUSEX info;
  info.dwLength = sizeof(info);
  if (!GlobalMemoryStatusEx(&info))
    return 0.0;
  return (double)info.ullTotalPhys;
#elif defined(__APPLE__)
  unsigned long long bytes = 0;
  size_t size = sizeof(bytes);
  if (sysctlbyname("hw.memsize", &bytes, &size, NULL, 0) != 0)
    return 0.0;
  return (double)bytes;
#elif defined(_SC_PHYS_PAGES)
  long pages = sysconf(_SC_PHYS_PAGES);
  size_t pageSize = phoenixPageSize();
  return pages > 0 ? (double)pages * (double)pageSize : 0.0;
#else
  return 0.0;
#endif
}

#endif
