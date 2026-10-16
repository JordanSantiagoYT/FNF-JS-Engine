---
title: Python scripting
sidebar_position: 40
description: Hython-based Python scripting — setup, differences from Lua, and examples.
---

# Python scripting

Python scripting is a Phoenix Engine addition. It mirrors the Lua system: the same file
locations, the same callback names, and a subset of the same functions, so a script can be
ported between the two languages mostly by changing syntax.

## Requirements

- A build with `PYTHON_ALLOWED` — `-DMODDING_LEVEL=2`, which is the **default** on desktop
  and mobile.
- Nothing else. The interpreter is [Hython](https://github.com/Paopun20/Hython)
  (haxelib `hython`), a pure-Haxe Python implementation, so no CPython runtime is
  installed or bundled.

```bash
lime test windows -DMODDING_LEVEL=2   # Lua + Python (default)
lime test windows -DMODDING_LEVEL=1   # Lua only — .py files are ignored
```

## Where scripts go

Exactly where Lua scripts go, with a `.py` extension:

| Location | Loaded |
|---|---|
| `mods/<mod>/scripts/*.py` | every song |
| `mods/<mod>/data/<song>/<song>.py` | that song |
| `mods/<mod>/stages/<stage>.py` | that stage |
| `mods/<mod>/custom_notetypes/<type>.py` | that notetype |
| `mods/<mod>/custom_events/<event>.py` | that event |

Lua and Python scripts coexist; both are loaded and both receive every hook.

## A minimal script

```python
def onCreate():
    # some variables don't exist yet
    pass

def onCreatePost():
    makeLuaSprite('myBg', 'myImage', 0, 0)
    setObjectCamera('myBg', 'camGame')
    addLuaSprite('myBg', False)

def onUpdate(elapsed):
    pass

def onBeatHit():
    if curBeat % 4 == 0:
        cameraShake('camGame', 0.005, 0.1)

def onDestroy():
    pass
```

`docs/TemplateScript.py` is the commented template with every hook; the shipped
`mods/bf-clicker/` mod is a complete working example.

## Differences from Lua

| | Lua | Python |
|---|---|---|
| Hook definition | `function onCreate()` | `def onCreate():` |
| Booleans | `true` / `false` | `True` / `False` |
| Nil | `nil` | `None` |
| Tables as arguments | `{1, 2, 3}` | `[1, 2, 3]` |
| Function count | 233 | 128 |
| Comments | `--` | `#` |

The Python library covers sprites, text, cameras, characters, properties, sound, score,
timers and tweens. Where a Lua function has no Python twin yet, use Lua for that part — or
add the twin in `psychlua/pystdlib/` and send a PR
([how](../subsystems/scripting-runtime.md#adding-a-callback)).

Function names are intentionally **identical** to Lua, including the `luaX` prefixes
(`makeLuaSprite`, `addLuaText`, …), so that porting is mechanical.

## Control flow

The same sentinels exist, as globals:

```python
def onStartCountdown():
    return Function_Stop     # suppress the countdown

def onEndSong():
    return Function_Continue
```

`PythonScript` names the third sentinel `Function_StopAll` internally; from a script both
that name and the Lua-compatible `Function_StopLua` global are available (they are the
same sentinel value, #51).

## Debug output

```python
debugPrint('health is', getProperty('health'))
```

Output goes to the on-screen `pythonDebugGroup`, the Python counterpart of the Lua debug
text. Errors are caught per call — a raised exception prints and the song keeps playing.

## Performance

Hython is an interpreter written in Haxe; it is slower than LuaJIT. For per-frame work in
a demanding chart, prefer Lua. For setup, event reactions and beat-synced logic, the
difference is irrelevant.

## Next

- [Python API reference](./python-api-reference.md) — all 128 functions.
- [Script hooks](./script-hooks.md) — the callbacks, shared with Lua.
