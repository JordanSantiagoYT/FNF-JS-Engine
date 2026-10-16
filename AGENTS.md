# AGENTS.md — FNF-JS-Engine-Light (Phoenix Engine)

Documento canônico de instruções para agentes de IA que trabalham neste repositório.
**Esta é a única fonte de verdade.** CL  AUDE.md, AI.md e qualquer outro ponteiro
apenas redirecionam para cá — não duplique instruções em outros arquivos.

> Se um futuro nurture/discrepância aparecer entre este arquivo e outro, **este arquivo vence**.

---

## 1. O que é este projeto

**Phoenix Engine** — um Friday Night Funkin’ engine em **Haxe → OpenFL/Lime/Flixel**,
fork do *JS Engine* (Jordan Santiago), que por sua vez é um fork otimizado do
*Psych Engine*. Nome de janela: *“Friday Night Funkin' - Phoenix Engine”*;
executável: `FNF-Phoenix-Engine`; package mobile: `quack.fnf.phoenix`; versão `0.3.2`
(definida em `project.hxp`, `VERSION`).

Propósito: **performance em devices fracos + modding fácil** (Lua, e extensão
própria: **Python/Hython**), mantendo compatibilidade com mods Psych/JS Engine.

---

## 2. Stack & requisitos (segundo BUILDING.md — real)

- **Haxe 4.2.5+** (CI usa 4.3.x). `haxelib setup` / `mkdir ~/haxelib && haxelib setup ~/haxelib`.
- **git**, e (Windows) **Visual Studio Community** — instalação recomendada:
  `curl -# -O <url vs_Community.exe>` + `vs_Community.exe --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 -p`.
- (Linux) VLC/libvlc; (Win) opcional MSVC fix (ver §9 gotchas).
- Engine usa `setup/windows.bat` + `setup/windows-msvc-fix.ps1` para montar haxelibs.

**Build (raiz):**
```
haxelib run lime build windows -Dofficial
haxelib run lime build neko -Dofficial
haxelib run lime build html5 -Dofficial
haxelib run lime build flash -Dofficial -D disable-version-check
haxelib run lime build air -Dofficial -D disable-version-check -DAIR_SDK=C:\AIR\AIRSDK_51.2.2
lime test <platform>        # roda o teste
```
`<platform>` ∈ {`windows`, `linux`, `mac`}. Para limpar: `lime test cpp -clean` ou
apagar `export/`/`build/`. Mobile tá no CI (`mobile.yml`): Android `lime build android`,
iOS `lime build ios -nosign`.

Defines úteis: `-DofficialBuild`, `-Dofficial`, `-DULTRA_OPTIMIZED` (build velocidade máxima, WIP),
`-DULTRA_HTML5` (WIP), `-DDEBUG_TRACY`/`FEATURE_DEBUG_TRACY`, **`-DMODDING_LEVEL=0|1|2`**
(0 nenhum, 1 Lua, 2 Lua+Python — desktop default 2), `-Ddisable-version-check` (flash/air obrigatório).

---

## 3. Estrutura do repositório (top-level)

```
FNF-JS-Engine-Light/
├── project.hxp            # build Haxe-lime (config principal; NÃO é XML)
├── hmm.json               # declarative haxelibs
├── setup/                 # setup por SO + msvc-fix
├── source/                # TODO o código-fonte Haxe (pasta classpath principal)
├── assets/                # jogos assets (preload/shared/week*/songs/...)
├── mods/                  # mods carregáveis em runtime
├── modsList.txt           # mods embutidos no build
├── docs/                  # guias (TemplateScript.py/.lua, PDF de como usar)
├── .github/workflows/     # CI: main, mobile, release, nightly, autotriage...
├── BUILDING.md            # guia de build
├── CODESTYLE.md           # guia de estilo
├── checkstyle.json        # config Haxe-Checkstyle
├── hxformat.json          # config Haxe Formatter
├── .vscode/               # tasks/lint/launch (Lime, HaxeCheckstyle)
└── build/                 # saída de builds (ignorada no git — build/release/android etc.)
```

> Fonte vive em `source/`, **não** em `src/`. Assets em `assets/` (libraries: `preload`,
> `shared`, `preload` + `week*`, `songs`). Código `Main.hx` na raiz de `source/`.

---

## 4. Arquitetura e fluxo de inicialização

- **Entry point:** `Main.hx` → `backend.BootState`/`InitState` → `TitleState` → `MainMenuState`/
  `StoryMenuState`/`FreeplayState`/`PlayState`. Todos os estados extendem
  `MusicBeatState`/`MusicBeatSubState` (`backend/MusicBeatState.hx`).
- **`Main.hx`**: cria `FunkinGame`, registra `FlxFix`, carrega `ClientPrefs`, `Achievements`,
  `Paths`, `Achievements`, `PlayerSettings`, splash, inicializa estados.
- **`backend/`**: núcleo não-jogável
  - `Paths.hx` — localização de assets/mod paths; `Paths.mods/`, `Paths.stage`, `Paths.char` etc.
  - `Paths.currentModDirectory`, `Paths.currMod` — decidi o dir de mod ativo.
  - `ClientPrefs.hx` — todos os pref do jogador (data/options; persistidos).
  - `Conductor.hx` — tempo de música + BPM (crochet, stepCrochet, beat/step).
  - `Highscore.hx` — scores/saves; `WeekData.hx` — semanas; `Song.hx`/`SwagSong` — charts;
    `Section` — seções; `Mods.hx` — carregamento de mods; `Paths.getPath`.
  - `CoolUtil.hx` (este é um fork modificado) — helpers genéricos (número compacto,
     dificuldade, arquivos).
- **`play/PlayState.hx`** — o coração do gameplay (jogo, notas, personagens, câmera, eventos).
  **Decomposto em helpers:** `play/helpers/` — `PlayStateNotes/Notes/Input/Camera/Countdown/
  Characters/Events/Playback/PlayStateScripts/...` + `play/` — `PlayState.hx`, `Conductor`,
  `SpawnedNote`... & `play/helpers/*` = lógica delegada.
- **`states/`**: menus (`MainMenuState`, `FreeplayState`, `StoryMenuState`, `CreditState`,
  `OptionsMenuState`...), substates (`PauseSubState`, `GameOverSubstate`, `ResetScoreSubState`,
  `GameplayChangersSubstate`, `CharacterSelector...`).
- **`objects/`**: `Note.hx`, `NoteSplash.hx`, `StrumNote.hx`, `HealthIcon.hx`, `Alphabet.hx`,
  `Character.hx`, `Boyfriend.hx`, `FlxText`, `BG`, `BGSprite`...
- **`stages/`**: `StageData.hx` + implementações de stage por semana (`StageWeek1` etc.).
- **`options/`**: menu de opções + toggles (via `options/helpers`).
- **`editors/`**: ChartEditor, WeekEditor, CharacterEditor, StageEditor, DialogueEditor.
- **`psychlua/`**: **scripting** — FUNKINLUA (Lua), PythonScript (Hython) + HScript (hscript-improved).
- **`shaders/`**: efeitos (Grain, VHS, ChromaticAberration, Glitch, etc.).
- **`utils/`**, **`mobile/`** (controles mobile + hitbox), **`backend/states`** etc.

---

## 5. Sistemas de scripting (Lua / Python / HScript)

- **Lua**: arquivos `.lua` em `mods/scripts/`, `mods/data/<song>/`, `mods/stages/`,
  `mods/custom_notetypes/`, `mods/custom_events/`; via `psychlua/*.hx`.
  `modding/psychlua/LuaUtils`/`FunkinLua` — engine de callbacks.
- **Python**: igual a Lua, arquivos `.py` com `def onCreate()`, `def onUpdate(elapsed):` etc.
  Interprete **Hython** (pure-Haxe), compilado apenas quando `-DMODDING_LEVEL=2`.
- **HScript**: arquivos `*.hscript`/blocos `-- HSCRIPT` nos scripts Lua; via `hscript-improved`.
- Callbacks principais (o que mods podem usar): `onCreate/onCreatePost`, `onUpdatePost`,
  `onCountdownTick`, `onStartCountdown`, `onSongStart`, `onNoteHit`, `onNoteMiss`,
  `onGoodNoteHit`, `onStepHit`, `onBeatHit`, `onSectionHit`, `onRecalculateAllScores`,
  `onGameOver`, `onPause`, `onResume`, `onEndSong`, `onTweenCompleted`, `onCameraMove`
  (ver `docs/TemplateScript.py` e `.lua` para a lista canônica). Publicados via `PsychLua`/
  `LuaUtils`; chamados em `PlayState.hx`/helpers — se você VAI adicionar um callback novo,
  siga o padrão: registrar no helper de scripts + `callOnScripts(...)` + documentar no template.

---

## 6. Mods & conteúdo

- Mods ficam em `mods/<mod>/` (structure: `mods/<mod>/data/`, `mods/<mod>/images/`,
  `mods/<mod>/songs/`, `mods/<mod>/weeks/`, `mods/<mod>/scripts/`). O formato segue Psych.
- Lista de mods habilitados: `modsList.txt` na raiz do mod armazenado (autogerado).
- `Project.hxp` (root): `addAssetPath` para semana/`songs`, `mods` embedded (`mods/*`),
  `assets embed` para flash/air.
- Conteúdo vanilla: `assets/preload/songs`, `assets/preload/data`, `assets/week*`, `assets/songs`.
- Se adicionar mod de exemplo: siga `mods/<mod>/{data,images,songs,weeks}` + `pack.json`.

---

## 7. Convenções de código (CODESTYLE.md + hxformat.json + checkstyle.json)

- **Haxe**: indentação **2 espaços** (não tabs) — `hxformat.json` (`"character":"  "`).
- Formatação via extensão **vshaxe**/Haxe Formatter (esta é a regra de ouro: rode o formatter,
  não formate na mão) + **Haxe Checkstyle** (`checkstyle.json`) para qualidade (severity
  configurável; vários checks ainda TODO/IGNORE — ver CODESTYLE.md).
- Nomes: classes em `UpperCamelCase`, métodos/vars em `lowerCamelCase`, constantes UPPER_SNAKE.
- Erros de build/file style citar: `Code Style Guide` (CODESTYLE.md).
- **JSON** (charts, weeks, prefs, checkstyle): formatado por **Prettier** (`esbenp.prettier-vscode`).
- Linhas ~160chars máx (checkstyle `LineLength`), sem tabs, sem trailing whitespace.
- **Comentários em Haxe**: `//` para linha, `/** */` para doc (doco sobre membros públicos importantes);
  bloco ASCII `/* */` para separar seções de código (padrão do repo).
- Favor documentar função pública nova com `/** @param ... */` quando tiver parâmetros não óbvios.

---

## 8. Regras de modificação (IMPORTANTE — siga SEMPRE)

1. **Não** quebre compatibilidade com mods Psych/JS Engine sem discutir antes: charts
   (`SwagSong`), semanas (`WeekData`), notas (`Note`), stages (`StageData`), callbacks Lua/Python.
2. Ao mudar `Paths.mods`/diretório de mod: garanta fallback para `assets/`.
3. Novos assets: coloque em `assets/<lib>/...` e registre no `project.hxp`
   (`addAssetPath`/`addAssetLibrary`) se precisar de embed/preload (flash/air = embed).
4. Ao editar `PlayState.hx`, prefira **usar os helpers** (`play/helpers/*`) já existentes;
   não re-injeite lógica monstruosa no arquivo núcleo.
5. Callbacks de script: manter Lua∩Python simétricos (mesma assinatura) sempre que fizer sentido.
6. **Teste o build** (`lime build <platform> -Dofficial` ou `lime test windows`) antes de declarar pronto.
7. Não adicione dependências sem atualizar `hmm.json`/`setup`. Temas de versão pinada: ver §9.
8. Código de produção sem `trace()` órfão; perf-sensíveis com `#if !debug` quando necessário.
9. Toda mudança de feature/flag pública deve atualizar `ClientPrefs`/`Options` se visível ao jogador.
10. **Não** commits de `build/` (ignorado) nem de `art/` não-necessários; manter tree limpa
    (`git status`) antes de PR.

---

## 9. Gotchas de build (todos do BUILDING.md — reais)

- **Flash/AIR**: obrigatório `-D disable-version-check`; flash usa `-D disable-version-check`
  e `-DAIR_SDK` DEVE ser **um único token** (`-DAIR_SDK=C:\AIR\...`), NÃO via env var.
- **HTML5**: usa definições `-D analyzer-optimize` + `-D js-es=6`; exclui `.ogg`→`.mp3` (web usa mp3? não — web usa `*.mp3` na lista de exclude web: `addAssetPath ... exclude`).
- **Linux**: instalar `libvlc` (hxvlc/hxCodec) — erro típico `libvlc.so.5 ... syntax error` → usar hxCodec 3.0.2 ou instalar VLC.
- **MSVC Windows (LNK1181/LNK1120)**: rodar `setup/windows-msvc-fix.ps1` (ativa fork hxcpp com
  suporte `<assembler>` + J17); ou `lime test cpp -clean`/apagar `export/obj`.
- **Android (`dlopen failed: library "libc++_shared.so" not found ... needed by ... liblime.so`)**:
  o `liblime.so` pré-compilado do fork do lime linka contra o `libc++_shared` e nada no
  Lime/Gradle copia esse runtime pro APK. O `project.hxp` (`configureAndroidRuntime`) registra
  um pre-build callback que roda `setup/android-copy-stl.sh` (ou `.bat` no Windows) e copia o
  `libc++_shared.so` do NDK para `build/<tipo>/android/bin/app/src/main/jniLibs/<abi>/`.
  Confira com `unzip -Z1 <apk> | grep libc++_shared` — o CI checa isso no step
  `Verify Android APK native libs`. Detalhes em `BUILDING.md`.
- Runtime `lime.hdll` (HashLink) **bloqueado neste fork** — use windows/neko/linux/mac/html5.
- Estado do build local: **só `build/release/android/` presente** (build release Android antigo,
  Haxe 4.3.7, NDK 27.2.12479018, versão 0.3.2) — não é a fonte de build atual; a versionName vem
  do `VERSION` em `project.hxp` (via `meta.version`/`::APP_VERSION::`) e o versionCode do
  build number do Lime (`::APP_BUILD_NUMBER::` no template Android), não do `project.hxp`.
- **`build/release/android`** mostrou completa artefatos `.so` + `.obj` mas **sem `.apk` final** —
  o pipeline Gradle/APK não chegou a rodar no último build local. Use CI (`mobile.yml`) para APK.

---

## 10. CI / GitHub Actions

- `.github/workflows/main.yml` — build principal: Windows/neko/html5/flash/air (+linux/mac no mobile).
- `mobile.yml` — Android (ubuntu-24.04, Haxe 4.3.7, NDK 27.0.12077973, versionCode 2988/0.3.2)
  e iOS (macos, `-nosign` + ldid → IPA). Trigger: `workflow_dispatch`/`push`.
- `release.yml` — faz release com APK/IPA via `mobile-release.yml` (tag).
- `nightly.yml`, `autotriage.yml`, `autolock.yml` — housekeeping.
- Para rodar android localmente (Windows): configurar Android SDK/NDK via `haxelib run lime config`
  (ver BUILDING.md / workflows).

---

## 11. Checklist antes de finalizar uma tarefa

- [ ] `git status` limpo (só os arquivos intencionais) e nada em `build/`.
- [ ] Código formatado (Haxe Formatter) + sem warnings/errors de Haxe-Checkstyle novos.
- [ ] Build compila: `haxelib run lime build <platform> -Dofficial` (ou o target do seu trabalho).
- [ ] Se mexeu em scripts/callbacks: testou com um mod de exemplo (`.lua` e `.py`).
- [ ] Se mexeu em assets: registrou no `project.hxp` quando necessário.
- [ ] Sem `trace()` de debug esquecido; sem segredos/chaves commitadas.
- [ ] Mensagem de commit curta no estilo do repo (Conventional-ish, tipo “fix: ...”, “feat: ...”).

---

## 12. Comandos mais úteis (resumo rápido)

```
haxelib run lime build windows -Dofficial
haxelib run lime test windows
lime test <platform> -clean
setup\windows.bat                    # prepara haxelibs no Windows
setup\windows-msvc-fix.ps1           # fix hxcpp p/ MSVC
haxelib run lime build android -Dofficial   # (CI usa isto p/ mobile)
```
Depois de `setup\windows.bat`, **sempre rode também** `windows-msvc-fix.ps1` no Windows.

---

*Se uma instrução aqui conflitar com um arquivo recém-adicionado, **AGENTS.md permanece a fonte*. 
Documentos citados e verificados: `README.md`, `BUILDING.md`, `CODESTYLE.md`, `project.hxp`,
`hmm.json`, `.github/workflows/*`.
