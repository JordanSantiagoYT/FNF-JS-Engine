# ULTRA_* builds (WIP)

one-click helpers for the experimental `-DULTRA_OPTIMIZED` (native) and
`-DULTRA_HTML5` (web/JS) build flags.

## what they do

### `-DULTRA_OPTIMIZED` (native: windows / linux / mac / mobile)

max-speed build for native targets. strips a bunch of debug instrumentation
and forces the fast codegen, specifically:

- disables `HXCPP_CHECK_POINTER` (null pointer checks)
- disables `HXCPP_STACK_TRACE` / `HXCPP_STACK_LINE` (stack tracing)
- disables `HXCPP_GC_CHECK_LEAKS` (leak checks — was a no-op anyway)
- enables `HXCPP_OPTIMIZE_LINK` (`/GL` + `/LTCG` on MSVC, `-flto` elsewhere)
- unsets `HXCPP_FAST_LINK` so hxcpp uses full LTCG instead of incremental
- forces `analyzer-optimize` regardless of debug/release
- keeps `HXCPP_CATCH_SEGV` (CrashHandler relies on it)
- keeps `-dce no` (mod safety; the game uses heavy runtime reflection)

### `-DULTRA_HTML5` (web/JS target only)

the web target ignores the hxcpp defines above (it's pure JS). this flag
sets the JS-specific speed knobs:

- `analyzer-optimize`
- `js-es=6` (modern ES, smaller/faster output)
- leaves `-dce no` for mod safety (WIP: switch to `-dce std` once you've
  verified your mods don't rely on reflection-stripped symbols)

the two flags are independent — you can pass `-DULTRA_OPTIMIZED -DULTRA_HTML5`
together, but only one is active per build (ULTRA_OPTIMIZED on native,
ULTRA_HTML5 on web).

**WIP disclaimer: these flags are EXPERIMENTAL.** expect bugs, crashes
or weird behavior. if it explodes, rebuild without the flag.

## how to run it

one-click (Windows, has neko + haxe on the PATH for you):

```bat
build-ultra.bat
```

same thing as PowerShell:

```powershell
.\build-ultra.ps1
```

or raw:

```bat
haxelib run lime build windows -DULTRA_OPTIMIZED
haxelib run lime build html5   -DULTRA_HTML5
```

## how to build WITHOUT the flag (normal)

```bat
haxelib run lime build windows
```

or to build + run:

```bat
haxelib run lime test windows
```

## important notes

- **never run two builds at the same time.** concurrent builds share the
  obj dir and will corrupt it, which shows up as `LNK1136` at link time.
  if that happens, stop everything and rebuild (or clean the obj dir).
- `lime` is not a standalone command in this repo's toolchain; it's invoked
  through haxelib, so always run `haxelib run lime ...` (the .bat/.ps1
  helpers do this for you).
- the ultra flags require the **git fork** of hxcpp (not the official
  haxelib 4.3.2), because `HXCPP_OPTIMIZE_LINK` + the C++17 standard are
  defined by the git fork's BuildTool.hx. the project's `.current` file
  points to git. if you ever see `error C7525: inline variables require
  /std:c++17`, that means hxcpp fell back to the official release and you
  need to fix `.current` back to `git`.

