#!/usr/bin/env node
/**
 * Generates the "Code reference" section of the documentation site straight
 * from the Haxe sources in `source/`.
 *
 *   node scripts/generate-api-docs.mjs
 *
 * Output: website/docs/reference/** (fully regenerated on every run).
 * Never edit the generated files by hand — edit the Haxe doc comments instead.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseHaxeFile, formatSignature } from './haxe-parser.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEBSITE_DIR = path.resolve(__dirname, '..');
const REPO_ROOT = path.resolve(WEBSITE_DIR, '..');
const SOURCE_DIR = path.join(REPO_ROOT, 'source');
const OUT_DIR = path.join(WEBSITE_DIR, 'docs', 'reference');
const GITHUB_BLOB = 'https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main';

/** Human descriptions for every package in `source/`. */
const PACKAGE_INFO = {
  '(root)': {
    label: 'Root',
    position: 1,
    description:
      'Entry point of the application. `Main` builds the OpenFL sprite tree, installs the crash handler and FPS counter, and boots `FunkinGame`. `import.hx` is the implicit import list applied to every other module in the project.',
  },
  backend: {
    label: 'backend',
    position: 2,
    description:
      'Engine infrastructure: asset resolution (`Paths`), preferences (`ClientPrefs`), the beat/step clock (`Conductor`), input mapping (`Controls`), mod discovery (`Mods`), the Flixel state bases (`MusicBeatState`, `MusicBeatSubstate`) and assorted services such as Discord RPC, achievements and the crash handler.',
  },
  'backend.deeplink': {
    label: 'backend.deeplink',
    position: 3,
    description:
      'Parsing and routing for the custom `phoenix://` URI scheme, used to deep-link into menus from a browser or another app.',
  },
  data: {
    label: 'data',
    position: 4,
    description:
      'Chart and stage data models: the `SwagSong`/`SwagSection` JSON shapes, chart loading and migration, and the stage metadata registry.',
  },
  debug: {
    label: 'debug',
    position: 5,
    description: 'On-screen developer overlays — the FPS/memory counter and memory sampling helpers.',
  },
  editors: {
    label: 'editors',
    position: 6,
    description:
      'In-game authoring tools: the chart editor, character editor, dialogue editors, week editor, note-splash debugger and the editor hub (`MasterEditorMenu`).',
  },
  'editors.charting': {
    label: 'editors.charting',
    position: 7,
    description: 'Pieces extracted out of `ChartingState`: grid rendering, selection, undo history and chart I/O.',
  },
  'editors.helpers': {
    label: 'editors.helpers',
    position: 8,
    description: 'Stateless helper modules backing the editors, kept separate so the editor states stay small.',
  },
  states: {
    label: 'states',
    position: 9,
    description:
      'Menu and flow states: title, main menu, story mode, freeplay, options entry, mods menu, credits, achievements, loading and the crash/error screen.',
  },
  'states.helpers': {
    label: 'states.helpers',
    position: 10,
    description: 'Logic extracted from the larger menu states (freeplay, mods menu, gameplay changers).',
  },
  'states.substates': {
    label: 'states.substates',
    position: 11,
    description: 'Substates layered over a running state — pause menu, game over screen, gameplay changers.',
  },
  play: {
    label: 'play',
    position: 12,
    description:
      'Gameplay core. `PlayState` owns the song, the notes, the characters and the script host; `BaseStage` is the base class for hardcoded stages; `CutsceneHandler` sequences video/dialogue cutscenes.',
  },
  'play.helpers': {
    label: 'play.helpers',
    position: 13,
    description:
      'The split-out halves of `PlayState`. Each helper is a static module that receives the `PlayState` instance and owns one concern (input, notes, camera, rating, playback, scripts, …).',
  },
  'play.objects': {
    label: 'play.objects',
    position: 14,
    description: 'Gameplay-only display objects such as rating popups and combo sprites.',
  },
  objects: {
    label: 'objects',
    position: 15,
    description:
      'Reusable display objects: `Note`, `Character`, `Alphabet`, health icons, dialogue boxes, menu items and the note splashes.',
  },
  options: {
    label: 'options',
    position: 16,
    description:
      'The options menu, its category substates (gameplay, graphics, visuals, controls, optimization, renderer) and the `Option` model that drives them.',
  },
  'options.helpers': {
    label: 'options.helpers',
    position: 17,
    description: 'Helpers for the options menus — note colour previews and shared menu plumbing.',
  },
  psychlua: {
    label: 'psychlua',
    position: 18,
    description:
      'The scripting host: `FunkinLua` (Lua/Luau), `PythonScript` (Hython), `HScript`, the `Convert` bridge that marshals values between Haxe and the script VMs, and the modchart sprite types scripts manipulate.',
  },
  'psychlua.callbacks': {
    label: 'psychlua.callbacks',
    position: 19,
    description:
      'The Lua standard library, split by topic. Each module exposes `register(funk:FunkinLua)` and installs a group of callbacks.',
  },
  'psychlua.pystdlib': {
    label: 'psychlua.pystdlib',
    position: 20,
    description:
      'The Python standard library, mirroring `psychlua.callbacks`. Each module exposes `register(py:PythonScript)`.',
  },
  stages: {
    label: 'stages',
    position: 21,
    description: 'Hardcoded stages for the base game weeks, each extending `play.BaseStage`.',
  },
  'stages.objects': {
    label: 'stages.objects',
    position: 22,
    description: 'Props and actors used by the hardcoded stages (tank cutscene characters, the A-Bot speaker, …).',
  },
  shaders: {
    label: 'shaders',
    position: 23,
    description:
      'GLSL effects shipped with the engine. Most come in pairs: a `*Shader` holding the fragment source and a `*Effect` wrapper exposing animatable parameters.',
  },
  music: {
    label: 'music',
    position: 24,
    description: 'The freeplay music player overlay and its playback state.',
  },
  mobile: {
    label: 'mobile',
    position: 25,
    description: 'Touch controls, mobile storage permissions and the first-run asset copy state for Android/iOS.',
  },
  'mobile.flixel': {
    label: 'mobile.flixel',
    position: 26,
    description: 'Touch widgets: the virtual pad, the four-lane hitbox and the mobile-friendly button.',
  },
  'mobile.files': {
    label: 'mobile.files',
    position: 27,
    description: 'Native file-picker bridge for mobile targets.',
  },
  'mobile.options': {
    label: 'mobile.options',
    position: 28,
    description: 'Mobile-only options substate (control layout, haptics, extra toggles).',
  },
  android: {
    label: 'android',
    position: 29,
    description: 'JNI bridges into the Java code under `android/src/quack/fnf/phoenix/android/`.',
  },
  'android.platform': {
    label: 'android.platform',
    position: 30,
    description: 'Android platform services exposed to the engine (media session, display, storage, input).',
  },
  utils: {
    label: 'utils',
    position: 31,
    description:
      'Cross-cutting utilities: platform detection, native desktop calls, memory reporting, date formatting and process helpers.',
  },
  headers: {
    label: 'headers',
    position: 32,
    description:
      'Categorisation headers. These modules contain nothing but `typedef` re-exports so a single import pulls in a whole group of related types.',
  },
  flixel: {
    label: 'flixel (overrides)',
    position: 33,
    description:
      'Engine copies of Flixel modules that shadow the haxelib versions through the class path. See *Haxelib patches* for how the override works.',
  },
  'flixel.addons.ui': {
    label: 'flixel.addons.ui (overrides)',
    position: 34,
    description: 'Overridden flixel-addons UI widgets used by the editors.',
  },
  flxanimate: {
    label: 'flxanimate (overrides)',
    position: 35,
    description: 'Engine subclass of `FlxAnimate` used for Adobe Animate texture atlases.',
  },
};

const CODE_FENCE = '```';

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.isFile() && entry.name.endsWith('.hx')) out.push(full);
  }
  return out;
}

function escapeCell(text) {
  return String(text ?? '')
    .replace(/\|/g, '\\|')
    .replace(/\n+/g, ' ')
    .trim();
}

function inlineCode(text) {
  if (text === null || text === undefined || text === '') return '';
  const flat = String(text).replace(/\s+/g, ' ').trim();
  return `\`${flat.replace(/\|/g, '\\|')}\``;
}

/** Doc comments may contain MDX-hostile characters; keep them literal. */
function safeProse(text) {
  if (!text) return '';
  return text
    .split('\n')
    .map((line) =>
      line
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/\{/g, '&#123;')
        .replace(/\}/g, '&#125;'),
    )
    .join('\n');
}

function conditionBadge(conditions) {
  if (!conditions || conditions.length === 0) return '';
  return conditions.map((c) => `#if ${c}`).join(' + ');
}

function packageOf(parsed) {
  return parsed.package && parsed.package.length ? parsed.package : '(root)';
}

function docIdFor(pkg, typeName) {
  const dir = pkg === '(root)' ? 'root' : pkg.replace(/\./g, '-');
  return `reference/${dir}/${typeName}`;
}

function renderType(type, parsed, allTypes) {
  const pkg = packageOf(parsed);
  const fqn = pkg === '(root)' ? type.name : `${pkg}.${type.name}`;
  const lines = [];

  lines.push('---');
  lines.push(`title: ${type.name}`);
  lines.push(`sidebar_label: ${type.name}`);
  lines.push(`description: ${JSON.stringify(
    (type.doc ? type.doc.split('\n')[0] : `${type.kind} ${fqn}`).slice(0, 180),
  )}`);
  lines.push('---');
  lines.push('');
  lines.push(`# ${type.name}`);
  lines.push('');

  const facts = [
    ['Kind', inlineCode(type.kind)],
    ['Package', inlineCode(pkg === '(root)' ? '(root)' : pkg)],
    ['Full name', inlineCode(fqn)],
    ['Source', `[\`${type.path}\`](${GITHUB_BLOB}/${type.path}#L${type.line})`],
  ];
  if (type.extends) facts.push(['Extends', inlineCode(type.extends)]);
  if (type.implements && type.implements.length)
    facts.push(['Implements', type.implements.map(inlineCode).join(', ')]);
  if (type.conditions.length) facts.push(['Compiled when', inlineCode(conditionBadge(type.conditions))]);
  if (type.meta && type.meta.length) facts.push(['Metadata', type.meta.map((m) => inlineCode(m)).join(' ')]);
  if (type.aliasOf) facts.push(['Alias of', inlineCode(type.aliasOf)]);

  lines.push('| | |');
  lines.push('|---|---|');
  for (const [k, v] of facts) lines.push(`| **${k}** | ${escapeCell(v)} |`);
  lines.push('');

  if (type.doc) {
    lines.push(safeProse(type.doc));
    lines.push('');
  }

  const subclasses = allTypes.filter((t) => {
    if (!t.extends) return false;
    const base = t.extends.split('<')[0].trim();
    return base === type.name || base === fqn;
  });
  if (subclasses.length) {
    lines.push('**Known subclasses:** ' + subclasses.map((t) => inlineCode(t.name)).join(', '));
    lines.push('');
  }

  if (type.structureFields.length) {
    lines.push('## Structure fields');
    lines.push('');
    lines.push('| Field | Type | Optional |');
    lines.push('|---|---|---|');
    for (const f of type.structureFields)
      lines.push(`| ${inlineCode(f.name)} | ${inlineCode(f.type)} | ${f.optional ? 'yes' : 'no'} |`);
    lines.push('');
  }

  if (type.enumValues.length) {
    lines.push('## Values');
    lines.push('');
    for (const v of type.enumValues) {
      const params = v.params.length
        ? `(${v.params.map((p) => `${p.name}:${p.type ?? 'Dynamic'}`).join(', ')})`
        : '';
      lines.push(`- ${inlineCode(v.name + params)}${v.doc ? ` — ${safeProse(v.doc.split('\n')[0])}` : ''}`);
    }
    lines.push('');
  }

  const publicFields = type.fields.filter((f) => f.isPublic);
  const privateFields = type.fields.filter((f) => !f.isPublic);
  const publicMethods = type.methods.filter((m) => m.isPublic || m.name === 'new');
  const privateMethods = type.methods.filter((m) => !(m.isPublic || m.name === 'new'));

  const renderFieldTable = (title, fields) => {
    if (!fields.length) return;
    lines.push(`## ${title}`);
    lines.push('');
    lines.push('| Name | Type | Static | Default | Notes |');
    lines.push('|---|---|---|---|---|');
    for (const f of fields) {
      const notes = [];
      if (f.isFinal) notes.push('final');
      if (f.accessors) notes.push(`property (${f.accessors.get}, ${f.accessors.set})`);
      if (f.conditions.length) notes.push(inlineCode(conditionBadge(f.conditions)));
      if (f.doc) notes.push(safeProse(f.doc.split('\n').join(' ')));
      lines.push(
        `| ${inlineCode(f.name)} | ${inlineCode(f.type ?? '—')} | ${f.isStatic ? 'yes' : 'no'} | ${
          f.defaultValue ? inlineCode(f.defaultValue) : '—'
        } | ${escapeCell(notes.join(' · ')) || '—'} |`,
      );
    }
    lines.push('');
  };

  renderFieldTable('Public fields', publicFields);

  const renderMethods = (title, methods) => {
    if (!methods.length) return;
    lines.push(`## ${title}`);
    lines.push('');
    for (const m of methods) {
      const heading = m.name === 'new' ? 'new (constructor)' : m.name;
      lines.push(`### ${heading}`);
      lines.push('');
      lines.push(CODE_FENCE + 'haxe');
      lines.push(formatSignature(m));
      lines.push(CODE_FENCE);
      lines.push('');
      if (m.conditions.length) {
        lines.push(`Only compiled when \`${conditionBadge(m.conditions)}\`.`);
        lines.push('');
      }
      if (m.doc) {
        lines.push(safeProse(m.doc));
        lines.push('');
      }
      if (m.params.length) {
        lines.push('| Parameter | Type | Default |');
        lines.push('|---|---|---|');
        for (const p of m.params)
          lines.push(
            `| ${inlineCode(p.name)}${p.optional ? ' *(optional)*' : ''} | ${inlineCode(p.type ?? 'Dynamic')} | ${
              p.defaultValue ? inlineCode(p.defaultValue) : '—'
            } |`,
          );
        lines.push('');
      }
      lines.push(`[View source](${GITHUB_BLOB}/${type.path}#L${m.line})`);
      lines.push('');
    }
  };

  renderMethods('Public methods', publicMethods);

  if (privateFields.length || privateMethods.length) {
    lines.push('## Internals');
    lines.push('');
    lines.push('<details>');
    lines.push('<summary>Private / internal members</summary>');
    lines.push('');
    if (privateFields.length) {
      lines.push('| Field | Type | Static |');
      lines.push('|---|---|---|');
      for (const f of privateFields)
        lines.push(`| ${inlineCode(f.name)} | ${inlineCode(f.type ?? '—')} | ${f.isStatic ? 'yes' : 'no'} |`);
      lines.push('');
    }
    if (privateMethods.length) {
      lines.push('| Method |');
      lines.push('|---|');
      for (const m of privateMethods) lines.push(`| ${inlineCode(formatSignature(m))} |`);
      lines.push('');
    }
    lines.push('</details>');
    lines.push('');
  }

  return lines.join('\n');
}

function main() {
  if (!fs.existsSync(SOURCE_DIR)) {
    console.error(`[api-docs] source directory not found: ${SOURCE_DIR}`);
    process.exit(1);
  }

  fs.rmSync(OUT_DIR, { recursive: true, force: true });
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const files = walk(SOURCE_DIR).sort();
  const modules = [];
  for (const file of files) {
    const rel = path.relative(REPO_ROOT, file).split(path.sep).join('/');
    const text = fs.readFileSync(file, 'utf8');
    try {
      const parsed = parseHaxeFile(text, rel);
      modules.push(parsed);
    } catch (err) {
      console.warn(`[api-docs] failed to parse ${rel}: ${err.message}`);
    }
  }

  const byPackage = new Map();
  const allTypes = [];
  for (const mod of modules) {
    const pkg = packageOf(mod);
    if (!byPackage.has(pkg)) byPackage.set(pkg, []);
    for (const type of mod.types) {
      const enriched = { ...type, path: mod.path, package: pkg };
      byPackage.get(pkg).push(enriched);
      allTypes.push(enriched);
    }
  }

  let fileCount = 0;
  const packages = [...byPackage.keys()].sort();

  for (const pkg of packages) {
    const info = PACKAGE_INFO[pkg] ?? { label: pkg, position: 90, description: '' };
    const dirName = pkg === '(root)' ? 'root' : pkg.replace(/\./g, '-');
    const dir = path.join(OUT_DIR, dirName);
    fs.mkdirSync(dir, { recursive: true });

    fs.writeFileSync(
      path.join(dir, '_category_.json'),
      JSON.stringify(
        {
          label: info.label,
          position: info.position,
          link: { type: 'doc', id: `${docIdFor(pkg, 'index')}` },
        },
        null,
        2,
      ) + '\n',
    );

    const types = byPackage.get(pkg).sort((a, b) => a.name.localeCompare(b.name));

    const indexLines = [
      '---',
      `title: ${info.label}`,
      'sidebar_label: Overview',
      'sidebar_position: 0',
      `description: ${JSON.stringify(`Types in the ${pkg} package.`)}`,
      '---',
      '',
      `# \`${pkg}\``,
      '',
      info.description,
      '',
      `${types.length} type${types.length === 1 ? '' : 's'} in this package.`,
      '',
      '| Type | Kind | Extends | Summary |',
      '|---|---|---|---|',
    ];
    for (const t of types) {
      const summary = t.doc ? t.doc.split('\n')[0] : '';
      indexLines.push(
        `| [${t.name}](./${t.name}.md) | ${t.kind} | ${inlineCode(t.extends ?? '—')} | ${escapeCell(
          safeProse(summary),
        ) || '—'} |`,
      );
    }
    indexLines.push('');
    fs.writeFileSync(path.join(dir, 'index.md'), indexLines.join('\n'));
    fileCount++;

    for (const type of types) {
      fs.writeFileSync(path.join(dir, `${type.name}.md`), renderType(type, { package: pkg }, allTypes));
      fileCount++;
    }
  }

  // Top-level reference landing page.
  const landing = [
    '---',
    'title: Code reference',
    'sidebar_label: Overview',
    'sidebar_position: 0',
    'description: Auto-generated reference for every Haxe type under source/.',
    '---',
    '',
    '# Code reference',
    '',
    // Admonition titles must use the `:::type[Title]` directive-label syntax:
    // `.md` files are parsed as CommonMark and the legacy `:::type Title` form
    // is not recognised (it would render as plain text).
    ':::info[Generated page]',
    '',
    'Everything in this section is generated from the Haxe sources by',
    '`website/scripts/generate-api-docs.mjs`. Do not edit these files — write a',
    '`/** ... */` doc comment above the type or field in `source/` and re-run',
    '`npm run gen:api` inside `website/`.',
    '',
    ':::',
    '',
    `Covering **${allTypes.length} types** across **${packages.length} packages**, parsed from`,
    `**${modules.length} modules** in \`source/\`.`,
    '',
    '## Packages',
    '',
    '| Package | Types | What lives here |',
    '|---|---|---|',
  ];
  for (const pkg of packages) {
    const info = PACKAGE_INFO[pkg] ?? { label: pkg, description: '' };
    const dirName = pkg === '(root)' ? 'root' : pkg.replace(/\./g, '-');
    landing.push(
      `| [\`${pkg}\`](./${dirName}/index.md) | ${byPackage.get(pkg).length} | ${escapeCell(info.description)} |`,
    );
  }
  landing.push('');
  landing.push('## Reading these pages');
  landing.push('');
  landing.push(
    '- **Compiled when** lists the `#if` flags that guard a type or member. A member with `#if LUA_ALLOWED` simply does not exist in a build made with `-DMODDING_LEVEL=0`.',
  );
  landing.push('- **Internals** collapses private fields and methods; they are listed for orientation, not as API.');
  landing.push('- Every heading links back to the exact line on GitHub.');
  landing.push('');
  fs.writeFileSync(path.join(OUT_DIR, 'index.md'), landing.join('\n'));
  fileCount++;

  fs.writeFileSync(
    path.join(OUT_DIR, '_category_.json'),
    JSON.stringify(
      {
        label: 'Code reference',
        position: 8,
        link: { type: 'doc', id: 'reference/index' },
      },
      null,
      2,
    ) + '\n',
  );

  console.log(
    `[api-docs] wrote ${fileCount} pages — ${allTypes.length} types, ${packages.length} packages, ${modules.length} modules.`,
  );
}

main();
