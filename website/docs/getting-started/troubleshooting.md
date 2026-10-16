---
title: Troubleshooting
sidebar_position: 5
description: Known build and runtime failures, and the fix for each.
---

# Troubleshooting

## Build

### `g++` errors on Linux

Install the C++ compiler for your distribution: `g++` (Debian/Ubuntu), `gcc-c++` (Fedora),
`sys-devel/gcc` (Gentoo).

### `ApplicationMain.exe : fatal error LNK1120: 1 unresolved externals`

A stale object file. Rebuild clean:

```bash
lime test cpp -clean
# or delete export/obj and build again
```

### The build takes 5–10 minutes

Expected for a first C++ build. Later builds reuse the hxcpp compile cache
(`HXCPP_COMPILE_CACHE`); CI detects and restores it explicitly.

### A library "downgraded" itself

Several dependencies are pinned Git forks (`lime`, `openfl`, `flixel`, `hxcpp`, `hxvlc`,
`funkin.vis`, `grig.audio`). Running `haxelib install <something>` can flip the *active*
version of a transitive dependency back to a release build. Check `haxelib list`, then
re-run `setup/windows.bat` or `setup/unix.sh`.

### MSVC picks the wrong toolchain on Windows

Run `setup/windows-msvc-fix.ps1` (or `setup/windows-msvc.bat`). It patches the assembler
and C++17 flag handling that hxcpp otherwise gets wrong on recent Visual Studio installs.

### Flash / AIR aborts with a Lime version check

Both SWF targets require `-D disable-version-check`. AIR also needs
`-DAIR_SDK=<path to AIRSDK>`. The SWF builds additionally depend on the
[haxelib patches](../architecture/haxelib-patches.md) — if you delete one of those files,
Flash stops compiling.

### Android: `dlopen failed: library "libc++_shared.so" not found` {#android-dlopen-failed-libc_sharedso-not-found}

The APK installs but dies at launch with:

```text
dlopen failed: library "libc++_shared.so" not found: needed by
/data/app/.../quack.fnf.phoenix-.../lib/arm64/liblime.so in namespace clns-N
```

Lime's prebuilt `liblime.so` is linked against the *shared* C++ runtime, but nothing in
Lime's Android target copies that runtime into the app. `project.hxp` solves it with the
`configureAndroidRuntime` pre-build callback running `setup/android-copy-stl.sh`.

If you still hit it:

1. Rebuild (`lime build android`) so the callback runs. The NDK is taken from
   `ANDROID_NDK_ROOT`, falling back to `lime config ANDROID_NDK_ROOT` — make sure
   `lime setup android` has been run.
2. Verify the APK: `unzip -Z1 <apk> | grep 'lib/.*\.so'` must list `libc++_shared.so` for
   every ABI. CI does this in its *Verify Android APK native libs* step.
3. Run the script manually to see what it resolves:

   ```bash
   sh setup/android-copy-stl.sh --ndk "$ANDROID_NDK_ROOT" \
     build/release/android/bin/app/src/main/jniLibs arm64-v8a armeabi-v7a
   ```

### Is my haxelib patch actually being used?

```bash
haxelib run lime build windows -Dofficial
grep -rn "source/source-haxelib-patches" build/release/haxe/*.hxml   # must appear after -cp source/
```

Brute-force check: introduce a syntax error in the patch file and rebuild — the compiler
should stop inside `source/source-haxelib-patches/`, not inside `~/.haxelib`.

## Runtime

### Linux: `libvlc.so.5: file format not recognized`

That error comes from the old `hxCodec` instructions. Current builds use **hxvlc**;
install your distribution's VLC/libvlc development packages instead.

### Android: "doesn't actually have a JSON, nor voices/instrumental files" on a valid song

Known cosmetic issue (medium-low severity). Accept the dialog — playback works.

### Android: asks for image/sound permissions despite "manage all files"

Known low-severity issue with the scoped-storage permission flow in
`mobile.StorageUtil`.

### The game crashes instead of showing the crash screen

`CRASH_HANDLER` must be enabled (it is by default) **and** the build must define
`openfl-enable-handle-error`, which `project.hxp` sets in `configureCompileDefines()`.
Custom `project.hxp` edits that drop that define disable the whole crash UI.

### Scripts do nothing

Check the modding level the binary was built with: `-DMODDING_LEVEL=0` removes both VMs,
`=1` removes Python. Behind a disabled flag the callbacks do not exist at all, so a `.py`
file is simply never read. See [Project configuration](./project-configuration.md).
