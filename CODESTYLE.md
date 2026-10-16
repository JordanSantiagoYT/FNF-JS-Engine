# Code Style Guide

Code style is enforced using Visual Studio Code extensions. (specifically for JSONs)

### Rules that apply to every language
* LF line endings, no trailing whitespace, exactly one final newline. (`.vscode/settings.json` sets `files.eol`, `files.trimTrailingWhitespace` and `files.insertFinalNewline` for all files.)
* **Generated code is not repo code.** Everything under `export/` and `build/` is produced by Haxe, hxcpp and Lime and is gitignored. Never hand-edit or reformat it; change the `.hx`/`.hxp` source (or add a `source/source-haxelib-patches/` override) and rebuild.
* Naming is consistent across languages: types `UpperCamelCase`, members/functions `lowerCamelCase`, true constants `UPPER_SNAKE_CASE`.
* Comments: `//` for implementation notes, `/** ... */` doc comments on every public member worth documenting. Commented-out code gets deleted — Git history is the archive.
* No orphan debug output (`trace()`, `Log.d`, `NSLog`, `console.log`, `printf`) in committed code; gate diagnostics behind a define.
* Adding a formatter/linter for a language that doesn't have one yet: commit its config at the repo root, keep it non-blocking in CI, and clean the tree up incrementally — the same staged approach as the Haxe Checkstyle TODOs below.

## .hx
Formatting is handled by the `nadako.vshaxe` extension, which includes the Haxe Formatter.
Haxe Formatter resolves issues such as indentation style and line breaks, and can be configured in `hxformat.json`.

Code Quality is handled by the `vshaxe.haxe-checkstyle` extension, which includes Haxe Checkstyle.

### Haxe Checkstyle Notes
* Checks can be escalated to display as different severities in the Problems window.
  * Checks can be disabled by setting the severity to `IGNORE`.
* `IndentationCharacter` checks what is used to indent, `Indentation` checks how deep the indentation is.
* `CommentedOutCode` check is in place because old code should be retrieved via Git history.
* TODO items: Enable these one-by-one and fix them to improve the overall code quality.
  - Re-configure `MethodLength`
  - Re-configure `CyclomaticComplexity`
  - Re-enable `MagicNumber`
  - Re-configure `NestedControlFlow`
  - Re-configure `NestedIfDepth`
  - Figure out something for `Trace`
  - Fix bug and enable `DocCommentStyle`

## .json
Formatting is handled by the `esbenp.prettier-vscode` extension, which includes Prettier.
Prettier automatically handles formatting of JSON files, and can be configured in `.prettierrc.js`.

### Prettier Notes
* Prettier will automatically attempt to place expressions on a single line if they fit, but will keep them multi-line if they are manually made multi-line.
  * This means that long single-line objects are automatically expanded, and short multi-line objects aren't automatically collapsed.
  * You may want to use regex replacement to manually remove the first newline in short multi-line objects to convince Prettier to collapse them.

## .java (Android)
Hand-written and part of the build. Two places only:
* `android/src/quack/fnf/phoenix/android/*.java` — the Lime extensions registered by `configureAndroidRuntime()` in `project.hxp` (`PhoenixCore`, `PhoenixDisplay`, `PhoenixInput`, `PhoenixMedia`, `PhoenixStorage`) plus the `PhoenixMediaService` foreground service declared in the manifest template.
* `templates/android/MainActivity.java` — a Lime template override (deep-link intents, hardware key interception).

No Java formatter or linter runs in CI, and `.vscode/settings.json` has no `[java]` block, so **copy the formatting of the file you are editing** rather than trusting editor defaults.

### Java Formatting Notes
* Indent with **tabs**, like `project.hxp` and the `setup/` scripts. (`hxformat.json` declares 2 spaces for `.hx`; the tabs here are deliberate and consistent across every file in `android/src/`.) Braces go on their own line (Allman), same as Haxe.
* Keep lines under ~120 characters; the existing files never exceed it.
* One public class per file, named after the file. Package `quack.fnf.phoenix.android`, and the directory layout must mirror the package exactly — Lime copies `javaPaths` verbatim into the generated Gradle source set.
* `lowerCamelCase` methods and fields, `UPPER_SNAKE_CASE` `private static final` constants. Every class that logs declares `public static final String LOG_TAG = "<ClassName>"` and logs only through `Log.d/i/w/e(LOG_TAG, ...)`.
* Annotations sit on the same line as the signature they modify: `@Override public void onResume()`.
* Imports are grouped alphabetically with a blank line between groups, in this order: `android.*`, `androidx.*`, `org.*` (Haxe/Lime runtime, `org.json`), `java.*`, then project (`quack.fnf.phoenix.*`). No wildcard imports.
* Javadoc `/** ... */` on every class, public method and non-obvious field. Class docs say what the class is for and end with: `Part of the Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.`
* Split long files with the ASCII banner comments used in `PhoenixCore.java`:
  ```java
  // ------------------------------------------------------------------
  // Callback registration / event dispatch
  // ------------------------------------------------------------------
  ```

### Java / JNI Behavior Notes
* Extensions subclass `org.haxe.extension.Extension` and expose **static** entry points. The Haxe side caches them with `JNI.createStaticMethod` (`source/android/platform/AndroidBridge.hx`) — changing a Java signature means updating the JNI descriptor string (`"(Ljava/lang/String;)V"`) in the same PR.
* Java → Haxe uses exactly one channel: `PhoenixCore.dispatch(event, arg)` → `AndroidBridge.onAndroidEvent(event, arg)`. Don't register new `HaxeObject` callbacks; add a new `event` string and fan it out in the bridge.
* Never let an exception cross the JNI boundary. Wrap Haxe calls and system APIs in `try { ... } catch (Exception e) { Log.e(LOG_TAG, ...); }` and return a safe default (`""`, `0`, `false`, `null`).
* Anything touching the window/view hierarchy goes through `activity.runOnUiThread(...)`; `dispatch()` may be called from any thread (the Haxe side uses `JNISafety` to marshal back onto the main thread).
* Gate API-level-dependent code on `Build.VERSION.SDK_INT` and return a no-op below the required level.
* Write **plain Java**: no lambdas, streams, `var`, records, `java.time`, `List.of`. CI builds with JDK 17 (Temurin) but the code runs on old Android runtimes; anonymous inner classes (`new Runnable() { @Override public void run() { ... } }`) are the house style.
* Null-check everything that comes from the framework (`intent`, extras, cursors, `mainActivity`) before use.
* No secrets in source. Keystore material comes from the `PHOENIX_KEYSTORE*` environment variables (see `docs/ANDROID_PLATFORM.md`).
* New permissions and new extensions are declared in `project.hxp` (`config.push("android.permission", ...)` / `config.push("android.extension", ...)` — note these *replace* Lime's defaults, so repeat them), and any manifest entry goes in `templates/android/template/app/src/main/AndroidManifest.xml`.
* Lime templates use `::APP_PACKAGE::`, `::foreach::` and `::if::` macro syntax and are tab-indented like the rest of Lime's templates. Do **not** run the XML formatter over them; it doesn't understand the macros.
* Adding a whole extension means three pieces: the Java class here, a Haxe wrapper in `source/android/platform/` that no-ops outside `#if android`, and a row in the module table in `docs/ANDROID_PLATFORM.md`.

## .c/.h
One hand-written header today: `source/debug/mem/include/memory.h`, pulled into the hxcpp build by `source/debug/mem/GetTotalMemory.hx` (`@:buildXml` + `@:include` + `@:native`), with include paths and link libraries coming from `source/debug/mem/build.xml`.
No C formatter or linter is configured; match `memory.h`.

### C Formatting Notes
* 2 spaces, Allman braces, lines kept around 100 characters. Long `#if`/`#elif` preprocessor conditionals stay on one line instead of being wrapped (as in `memory.h`).
* Include guards (`#ifndef MEMCOUNTER_H` / `#define` / `#endif`), not `#pragma once` — headers in an `include/` directory get merged into generated hxcpp C++ and can be included more than once.
* `/** ... */` doc comment above every exported function, stating units and failure values ("returns zero if the value cannot be determined on this OS").
* Exported function names are `lowerCamelCase` and map 1:1 onto the Haxe `@:native("...")` name (`getPeakRSS`, `getCurrentRSS`). Renaming one silently breaks the extern, so treat these as public API.
* Keep `.h` files valid **C** even though hxcpp compiles them as C++ — no C++-only syntax, no templates, no exceptions.
* No globals, no allocation without a matching free, no `printf`/`fprintf` logging. Return the value and let the Haxe side decide what to do with it.
* Use portable types (`size_t`, `int64_t`) and let Haxe map them (`cpp.SizeT`, `cpp.Int64`).
* Vendored code keeps its original attribution header (see the David Robert Nadeau / CC-BY 3.0 block at the top of `memory.h`). Verify the license is permissive (MIT/BSD/Apache/CC-BY) and record the source URL; never paste in GPL/AGPL code.

### C Portability & Build Notes
* Platform-specific code goes behind `#if defined(_WIN32)` / `#elif defined(__APPLE__) && defined(__MACH__)` / `#elif defined(__linux__)`, always with a final `#else` that either returns a safe value or `#error`s — the skeleton `memory.h` already uses. Never assume a platform header exists on all targets.
* The hxcpp build file lives next to the sources and is referenced from Haxe via `@:buildXml('<include name=".../build.xml" />')`. Compiler flags go in `<files id="haxe">` (`<compilervalue name="-I" value="${PROJECT_DIR}/include/" />`), link libraries in `<target id="haxe">` inside a `<section if="linux">` (or `windows`/`mac`/`iphoneos`) block. Additional native sources register under the same `haxe` files id:
  ```xml
  <files id="haxe">
    <compilervalue name="-I" value="${PROJECT_DIR}/include/" />
    <file name="src/native_glue.c" />
  </files>
  ```
* Format `build.xml` (and any other XML) with the Red Hat XML extension settings already in `.vscode/settings.json` — 2 spaces, double quotes, collapsed empty elements.
* Any Haxe class touching native C must keep a non-`cpp` branch (`#if cpp ... #else ... #end` in `GetTotalMemory.hx`) so html5, neko and flash still compile.
* Small helpers extend this pattern. Anything larger (several sources, third-party dependencies, its own toolchain) becomes an **NDLL/haxelib** added to `hmm.json` and `setup/`, not a new directory under `source/`.

## .cpp/.hpp (currently unused)
No `.cpp`/`.hpp` files are committed. Every C++ file under `export/` or `build/*/obj/` is generated by hxcpp from `source/*.hx`. All of the `.c/.h` rules above apply, plus:

### C++ Notes
* hxcpp compiles with `HXCPP_CPP17` (set in `project.hxp`), so C++17 is available — but the same sources must build with MSVC (Windows), clang (Android/macOS/iOS) and gcc (Linux). No compiler-specific extensions, no GCC-only attributes, no assumptions about `<filesystem>` behaviour.
* The `HXCPP_*` defines (`HXCPP_GC_GENERATIONAL`, `HXCPP_GC_DYNAMIC_SIZE`, `HXCPP_GC_BIG_BLOCKS`, `HXCPP_FAST_LINK`, `HXCPP_CHECK_POINTER`, `HXCPP_STACK_TRACE`, `HXCPP_TRACY_MEMORY`, ...) are owned by `project.hxp`. Don't set or unset them from a module `build.xml`.
* Never let a C++ exception cross into Haxe: catch at the boundary and return an error value or empty result. `hx::Throw` is for Haxe code, not for native glue.
* Don't `new`/`delete` Haxe-visible objects. Return plain data (`int`, `float`, `const char*`, byte buffers) and let Haxe allocate and own objects; if native code must own memory, expose an explicit `createX`/`destroyX` pair.
* Class names `UpperCamelCase`, members and free functions `lowerCamelCase` to match the Haxe names they're exposed as. Don't import a foreign convention (`snake_case`, Hungarian notation, `m_` prefixes).
* Headers in `include/`, sources next to the module's `build.xml`. Keep the include-guard convention from the `.c/.h` section; `#pragma once` is acceptable only for headers that are C++-exclusive.
* Performance instrumentation belongs behind a feature define (the way `HXCPP_TELEMETRY`/`HXCPP_TRACY`/`HXCPP_TRACY_MEMORY` are gated on `-DFEATURE_DEBUG_TRACY` in `project.hxp`) so release builds don't pay for it.

## .js (Web)
No hand-written JavaScript is committed. `lime build html5` compiles the same `source/*.hx` tree to JS in `export/html5/` and `build/*/html5/` (both gitignored), using Lime's HTML5 template for `index.html` and the generated bundle.

### Web / JS Notes
* Express web glue in Haxe: `js.Syntax.code(...)`, `js.Browser`, `js.lib.*` externs, behind `#if js`/`#if html5`, rather than committing a `.js` file.
* Respect the web build settings from `project.hxp`: `-DULTRA_HTML5` turns on `analyzer-optimize` and `js-es=6` (with `-dce std` still commented out pending mod-safety testing), `-dce no` applies otherwise so mods can still `Reflect` into engine code, assets are embedded on web (`EMBED_ASSETS`), and `*.ogg` is excluded (`EXCLUDE_ASSETS_WEB`) — ship `.mp3` for anything the web target has to play.
* Check the `*_ALLOWED` feature gating in `project.hxp` before adding a platform branch: Lua/Python scripting, videos, Discord RPC and native file dialogs are off on web, HScript is on.
* If a `.js` file is ever committed (a template hook, a loader snippet): format with **Prettier**, 2 spaces, double quotes, semicolons, Prettier defaults otherwise. Prettier is currently only wired up for `[json]`/`[jsonc]` in `.vscode/settings.json` (there is no committed `.prettierrc.js` yet), so add a `[javascript]` block and/or a root `.prettierrc.js` instead of scattering inline options.
* ES6 is the floor (`js-es=6`), but there is **no npm toolchain in this repo** (no `package.json`, no bundler): no third-party JS dependencies, no CDN `<script>` tags, no build step. If a dependency is genuinely required, raise it first — it has to be vendored into a Lime template and kept in sync with `project.hxp`.
* No `console.log` left in committed glue (the JS equivalent of the no-orphan-`trace()` rule); gate diagnostics behind a define.

## .as (Flash)
No hand-written ActionScript 3. `lime build flash` and `lime build air` compile the same `source/*.hx` tree into a self-contained `.swf` (see `BUILDING.md`), so any `.as` or generated code under `export/flash/` or `build/*/flash/` is toolchain output — gitignored, regenerate instead of editing.

### Flash Notes
* The real style work for flash happens in Haxe: keep target differences behind `#if flash` / `#if air` (see `isFlash()`/`isAir()` and `FLASH_ALLOWED` in `project.hxp`), and respect what the target disables — `FLX_NO_PITCH`, `FLX_NO_SOUND_TRAY`, no shaders, no Lua/Python, no video, no Discord, embedded assets.
* flash and air builds require `-D disable-version-check`; air additionally requires `-DAIR_SDK=<path>` as a **single token** (an `AIR_SDK` environment variable does not work). Both gotchas are documented in `BUILDING.md`; don't add the define again if `project.hxp` already sets it.
* The flash toolchain is stricter than the others: `Int`/`UInt` comparisons and missing non-optional default arguments are hard errors. Pass arguments explicitly instead of relying on defaults.
* If AS3 glue ever becomes unavoidable (e.g. an AIR Native Extension): tabs and Allman braces to match the `.java` files, `lowercase.dotted` package names, `UpperCamelCase` classes, `UPPER_SNAKE_CASE` constants, ASDoc `/** ... */` with `@param`/`@return` on public members, and expose it to Haxe through an `extern` class with `@:native` rather than by embedding code strings. Keep it in its own directory with a README explaining how to build the ANE, since nothing else in this repo compiles AS3.

## .m/.mm/.h (Objective-C; iOS)
No Objective-C is committed. `lime build ios` (CI: `macos-latest`, `-nosign`, then `ldid` signs against `FNF-Phoenix-Engine.entitlements` and the app is zipped into an `.ipa`) generates the entire Xcode project — Objective-C++ entry point, Info.plist and entitlements included — into `build/release/ios/`, which is gitignored. Never patch generated files; change `project.hxp` and rebuild.

### Objective-C Notes
* There is no iOS-specific block in `project.hxp` today, so Lime's defaults apply. Deployment target, plist keys, linked frameworks and entitlements belong there (or in a Lime template override), never in generated output.
* Hand-written native iOS code follows the C pattern: `<module>/include/*.h` plus sources next to a hxcpp `build.xml`, bridged to Haxe with an `extern class` using `@:buildXml`/`@:include`/`@:native`, gated `#if (ios && cpp)`, with a no-op fallback branch for every other target — exactly the shape of `source/debug/mem/GetTotalMemory.hx`.
* `.mm` for anything touching Cocoa; keep the `.h` valid Objective-C so both C++ and ObjC++ translation units can import it. Use `#import` for Cocoa headers, include guards for our own.
* ARC on: add `<compilervalue name="-fobjc-arc" />` in the module `build.xml`; never call `retain`/`release`/`autorelease` by hand.
* Link frameworks from `build.xml`: `<section if="iphoneos"><lib name="-framework UIKit" /></section>`, plus the matching `iphonesim` section where the simulator needs it.
* Naming: `Phoenix`-prefixed classes (`PhoenixFoo`), `lowerCamelCase` selectors and properties with named parameters, `static NSString * const`/`extern` constants in `UPPER_SNAKE_CASE`.
* UI and window work on the main thread (`dispatch_async(dispatch_get_main_queue(), ^{ ... })`); wrap off-main-thread work in `@autoreleasepool`.
* Errors must not escape: use `NSError **` out-parameters or nil/NO returns, never throw `NSException` across the hxcpp boundary. Log with a class-name prefix (`NSLog(@"PhoenixFoo: ...")`), mirroring the Java `LOG_TAG` convention.
* Gate version-dependent APIs with `@available(iOS 15.0, *)` or `respondsToSelector:` and keep the fallback path, mirroring the Java `Build.VERSION.SDK_INT` rule.
* Where a matching Android feature exists, mirror its contract: one event channel back into Haxe, static/free functions as entry points, safe no-ops when the backing object is unavailable.

## .swift (iOS)
No Swift is committed and nothing in the build compiles it: hxcpp generates C++/Objective-C++ that Xcode builds. Swift only enters the picture if we add a Swift-based iOS platform layer (the analogue of `android/src/`) or pull in a Swift-only dependency.

### Swift Notes
* Swift can't be called from the generated C++ directly, so bridge it: `@objc`-exposed Swift types → a thin Objective-C++ shim (`.mm` + `.h`) → a Haxe `extern class` with `@:include`/`@:native`, gated `#if (ios && cpp)`. Keep the shim dumb — marshalling only, no logic.
* Mixing Swift into the Xcode project changes the build (Swift runtime, generated `-Swift.h`, `SWIFT_VERSION`). That configuration belongs in `project.hxp` / Lime template overrides, never hand-edited into `build/release/ios/`.
* Formatting: 4 spaces (Xcode default), LF endings, `UpperCamelCase` types, `lowerCamelCase` members, namespaced `static let` constants instead of global `UPPER_SNAKE_CASE`, `// MARK: -` section banners (the Swift equivalent of the Java `// ---` banners), `///` doc comments with `- Parameter:` / `- Returns:` on public API.
* No force-unwraps (`!`) or `try!` in shipped code; `guard let ... else { return }` for early exits; prefer value types and `final class`.
* UI on the main actor (`@MainActor` or `DispatchQueue.main.async`); never block the game/render loop on `Task.detached` plus semaphores.
* Annotate OS-dependent API with `@available(iOS X, *)` and keep the older-OS fallback, same as the Objective-C rule.
* No SwiftPM/CocoaPods dependencies without discussion: they have to be added to the generated Xcode project, to the iOS job in `.github/workflows/mobile.yml`, and still produce a signable `.ipa`.
* If `swift-format` or `swiftformat` is adopted, commit its config at the repo root and keep it non-blocking in CI until the tree is clean.
