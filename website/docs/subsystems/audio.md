---
title: Audio & music
sidebar_position: 7
description: Song audio, the freeplay music player, the sound tray, hitsounds and video playback.
---

# Audio & music

## Formats

`Paths.SOUND_EXT` is `ogg` on native targets and `mp3` on web/Flash.
`project.hxp` excludes the unused format from each build, so only one copy ships.
Audio assets were re-encoded for roughly 50 % size reduction without a quality change
that matters at game volume.

| Kind | Path |
|---|---|
| Instrumental | `songs/<song>/Inst.<ext>` |
| Vocals | `songs/<song>/Voices.<ext>` (loaded only when `needsVoices`) |
| Music | `music/<key>.<ext>` |
| SFX | `sounds/<key>.<ext>` |

`Paths.inst(song, difficulty)` and `Paths.voices(song, difficulty, postfix)` handle
difficulty-specific and postfixed variants (used by per-character vocal tracks via the
character JSON's `vocals_file`).

## Playback during a song

`play.helpers.PlayStatePlayback` owns the song audio:

- starts instrumental and vocals together and keeps them in sync,
- resyncs when they drift (a dropped frame or a long GC pause),
- applies `playbackRate` to both audio and the conductor,
- handles pause/resume, including the vocals,
- stops everything cleanly on game over and at the end of the song.

`Conductor.songPosition` is driven from the instrumental's time, not from `elapsed`, so
rendering hitches cannot desync the chart.

:::note[Pitch on SWF targets]

Flash and AIR have no pitch shifting. A [haxelib patch](../architecture/haxelib-patches.md)
gives `FlxSound` a store-only `pitch` property so the code compiles there, and
`#if FLX_PITCH` guards the places where real pitch shifting is required.

:::

## Menu music

`Paths.playMenuMusic(force, volume)` plays the menu theme, and
`Paths.playModMusic(file, fallback, volume)` lets a mod replace it: it tries
`mods/<mod>/music/<file>.ogg`, then the legacy name, then the base theme, then the
default. This is what makes "modified `freakyMenu` names" work — a mod can ship its own
menu track without renaming engine assets. `ClientPrefs.daMenuMusic` and
`ClientPrefs.pauseMusic` choose between shipped variants.

## The freeplay music player

`music.MusicPlayer` is the overlay in `states.FreeplayState` that lets you listen to songs
from the song list: play/pause (`pauseOrResume`), seek, track time (`curTime`) and
`switchPlayMusic()` to toggle between browsing and listening. On Android it feeds
`android.platform.AndroidMedia`, so the song appears in the system media controls, the
lock screen, Bluetooth devices and Android Auto — the metadata (title, artist, artwork,
position, playback state) is pushed through the media session, and
`PhoenixMediaService` keeps it alive while the app is backgrounded.

## Sound tray

`objects.CustomSoundTray` replaces Flixel's volume overlay with the engine's styled
version (`CustomSoundFrontEnd` extends Flixel's `SoundFrontEnd`). Volume and mute keys
come from `ClientPrefs.keyBinds` and are pushed into `TitleState.muteKeys`,
`volumeUpKeys` and `volumeDownKeys` on load. The tray is disabled on Flash/AIR via
`FLX_NO_SOUND_TRAY`.

## Hitsounds and feedback

`ClientPrefs.hitsoundVolume` and `hitsoundType` (e.g. `osu!mania`) drive the per-note
click; `missSoundEnabled` plays the classic miss sound. Both are played through
`FlxG.sound.play(Paths.sound(...))` with the sound preloaded by the playstate so the first
hit does not stutter.

## Video

Video playback uses **hxvlc** behind `VIDEOS_ALLOWED` (desktop and mobile C++ targets
only). `play.CutsceneHandler` sequences cutscenes, and Lua's `startVideo(name)` plays one
from a script. On Linux this is why libvlc is a build requirement; the old `hxCodec`
instructions in `BUILDING.md` no longer apply.

## Spectrum analysis

`stages.objects.ABotSpeaker` visualises the instrumental through `funkin.vis`
(`SpectralAnalyzer`) and `grig.audio`. Both are forks, and the analyzer needed a
[patch](../architecture/haxelib-patches.md) so Flash/AIR builds compile without a
Web-Audio or Lime `AudioSource` backend.
