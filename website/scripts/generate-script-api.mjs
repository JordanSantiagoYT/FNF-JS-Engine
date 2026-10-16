#!/usr/bin/env node
/**
 * Generates the Lua and Python scripting API reference from the callback
 * registrations in `source/psychlua/`.
 *
 *   node scripts/generate-script-api.mjs
 *
 * Output:
 *   website/docs/modding/lua-api-reference.md
 *   website/docs/modding/python-api-reference.md
 *
 * Both files are fully regenerated; edit the Haxe sources, not the markdown.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseParams } from './haxe-parser.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEBSITE_DIR = path.resolve(__dirname, '..');
const REPO_ROOT = path.resolve(WEBSITE_DIR, '..');
const PSYCHLUA_DIR = path.join(REPO_ROOT, 'source', 'psychlua');
const OUT_DIR = path.join(WEBSITE_DIR, 'docs', 'modding');
const GITHUB_BLOB = 'https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main';

/** Friendly names and blurbs for each callback module. */
const GROUPS = {
  CameraCallbacks: ['Cameras', 'Creating, registering and removing extra `FlxCamera`s from script.'],
  DeprecatedCallbacks: ['Deprecated', 'Kept for Psych/JS Engine mod compatibility. Avoid in new scripts.'],
  EffectCallbacks: ['Screen effects', 'Post-processing effects applied to cameras (glitch, bloom, VCR, grain, …).'],
  FileCallbacks: ['Files', 'Reading, writing and listing files relative to the mod folder.'],
  GameCallbacks: ['Game state', 'Score, health, combo, song flow and the values shown on the HUD.'],
  InputCallbacks: ['Input', 'Keyboard, mouse and gamepad polling.'],
  MiscCallbacks: ['Misc', 'String helpers, random numbers, debug printing and odds and ends.'],
  PropertyCallbacks: ['Properties', 'Reflective get/set of fields on any object, class or group.'],
  SaveDataCallbacks: ['Save data', 'Per-mod persistent key/value storage.'],
  ScriptCallbacks: ['Scripts', 'Loading other scripts, calling across scripts and sharing globals.'],
  ShaderCallbacks: ['Shaders', 'Runtime GLSL shaders and their uniforms.'],
  SoundCallbacks: ['Sound', 'Music and sound effect playback, fading and seeking.'],
  SpriteCallbacks: ['Sprites', 'Creating and manipulating sprites, animations and groups.'],
  TextCallbacks: ['Text', 'Creating and styling on-screen text objects.'],
  TweenCallbacks: ['Tweens & timers', 'Tweening object properties and scheduling timers.'],
  FunkinLua: ['Core', 'Callbacks registered directly by the Lua host.'],
  PythonScript: ['Core', 'Callbacks registered directly by the Python host.'],
  PyCameraLib: ['Cameras', 'Camera control.'],
  PyCharacterLib: ['Characters', 'Boyfriend / dad / girlfriend positioning and animation.'],
  PyKeyLib: ['Input', 'Keyboard and gamepad polling.'],
  PyMiscLib: ['Misc', 'Strings, randomness, debug output and helpers.'],
  PyPropertyLib: ['Properties', 'Reflective get/set of object fields.'],
  PyScoreLib: ['Score & health', 'Score, misses, hits, health and rating values.'],
  PySoundLib: ['Sound', 'Music and sound effects.'],
  PySpriteLib: ['Sprites', 'Sprites, animations and graphics.'],
  PyTextLib: ['Text', 'On-screen text objects.'],
  PyTimerLib: ['Timers', 'Scheduling and cancelling timers.'],
  PyTweenLib: ['Tweens', 'Tweening object properties.'],
};

/** Haxe type -> script-side type name. */
function scriptType(haxeType, lang) {
  if (!haxeType) return 'any';
  const t = haxeType.replace(/^Null<(.*)>$/, '$1').trim();
  const map = {
    String: 'string',
    Int: lang === 'lua' ? 'number (int)' : 'int',
    Float: lang === 'lua' ? 'number' : 'float',
    Bool: lang === 'lua' ? 'boolean' : 'bool',
    Dynamic: 'any',
    Void: 'nil',
  };
  if (map[t]) return map[t];
  if (/^Array<(.*)>$/.test(t)) return lang === 'lua' ? 'table (array)' : 'list';
  return `\`${t}\``;
}

function readAll(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) readAll(full, out);
    else if (entry.name.endsWith('.hx')) out.push(full);
  }
  return out;
}

/** Find `X.registerFunction("name", function(params)` occurrences. */
function extractFunctions(text, relPath) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const found = [];
  const re = /registerFunction\(\s*["']([A-Za-z_][\w]*)["']\s*,\s*function\s*\(/g;

  // Pre-compute a line index for character offsets.
  const offsets = [];
  let acc = 0;
  for (const line of lines) { offsets.push(acc); acc += line.length + 1; }
  const joined = lines.join('\n');
  const lineOf = (offset) => {
    let lo = 0;
    let hi = offsets.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (offsets[mid] <= offset) lo = mid;
      else hi = mid - 1;
    }
    return lo;
  };

  let m;
  while ((m = re.exec(joined)) !== null) {
    const name = m[1];
    const parenStart = joined.indexOf('(', m.index + m[0].length - 1);
    // read the balanced parameter list
    let depth = 0;
    let end = parenStart;
    for (let i = parenStart; i < joined.length; i++) {
      if (joined[i] === '(') depth++;
      else if (joined[i] === ')') {
        depth--;
        if (depth === 0) { end = i; break; }
      }
    }
    const params = parseParams(joined.slice(parenStart + 1, end));
    const lineIdx = lineOf(m.index);

    // Harvest the `//` comment block directly above the registration.
    const comment = [];
    for (let i = lineIdx - 1; i >= 0; i--) {
      const t = lines[i].trim();
      if (t.startsWith('//')) {
        const body = t.replace(/^\/\/+ ?/, '').trim();
        if (/^-+$/.test(body) || /^[-=/ ]+$/.test(body) || body === '') break;
        comment.unshift(body);
      } else if (t === '') {
        if (comment.length) break;
      } else break;
    }

    found.push({
      name,
      params,
      doc: comment.join(' ').trim(),
      file: relPath,
      line: lineIdx + 1,
      module: path.basename(relPath, '.hx'),
    });
  }
  return found;
}

/** Stable anchor slug for a group heading. */
function anchorOf(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function renderCall(fn, lang) {
  const args = fn.params
    .map((p) => (p.defaultValue ? `${p.name}=${p.defaultValue.replace(/'/g, "'")}` : p.name))
    .join(', ');
  return `${fn.name}(${args})`;
}

function renderPage({ lang, title, sidebarLabel, position, intro, functions }) {
  const byGroup = new Map();
  for (const fn of functions) {
    const [groupName] = GROUPS[fn.module] ?? [fn.module, ''];
    if (!byGroup.has(groupName)) byGroup.set(groupName, { blurb: (GROUPS[fn.module] ?? [, ''])[1], items: [] });
    byGroup.get(groupName).items.push(fn);
  }

  const out = [];
  out.push('---');
  out.push(`title: ${title}`);
  out.push(`sidebar_label: ${sidebarLabel}`);
  out.push(`sidebar_position: ${position}`);
  out.push(`description: ${JSON.stringify(`Every ${lang === 'lua' ? 'Lua' : 'Python'} function exposed by Phoenix Engine, generated from the engine sources.`)}`);
  out.push('---');
  out.push('');
  out.push(`# ${title}`);
  out.push('');
  // `:::type[Title]` (not `:::type Title`): `.md` files are parsed as
  // CommonMark, where only the directive-label syntax becomes an admonition.
  out.push(':::info[Generated page]');
  out.push('');
  out.push('This list is extracted from the `registerFunction(...)` calls in');
  out.push('`source/psychlua/` by `website/scripts/generate-script-api.mjs`. If a function');
  out.push('is missing here, it is missing from the engine too.');
  out.push('');
  out.push(':::');
  out.push('');
  out.push(intro);
  out.push('');
  out.push(`**${functions.length} functions** in ${byGroup.size} groups.`);
  out.push('');

  const groupNames = [...byGroup.keys()].sort((a, b) => {
    if (a === 'Deprecated') return 1;
    if (b === 'Deprecated') return -1;
    return a.localeCompare(b);
  });

  out.push('## Index');
  out.push('');
  for (const g of groupNames) {
    out.push(`- [${g}](#${anchorOf(g)}) — ${byGroup.get(g).items.length} functions`);
  }
  out.push('');

  for (const g of groupNames) {
    const group = byGroup.get(g);
    // Explicit heading id so the index links above always resolve.
    out.push(`## ${g} {#${anchorOf(g)}}`);
    out.push('');
    if (group.blurb) {
      out.push(group.blurb);
      out.push('');
    }
    if (g === 'Deprecated') {
      out.push(':::warning');
      out.push('');
      out.push('These exist only so older Psych / JS Engine mods keep running. They may be');
      out.push('removed in a future release — prefer the replacements noted in the engine source.');
      out.push('');
      out.push(':::');
      out.push('');
    }
    const items = group.items.sort((a, b) => a.name.localeCompare(b.name));
    out.push('| Function | Arguments | Notes |');
    out.push('|---|---|---|');
    for (const fn of items) {
      const args = fn.params.length
        ? fn.params
            .map(
              (p) =>
                `\`${p.name}\`: ${scriptType(p.type, lang).replace(/\|/g, '\\|')}${
                  p.defaultValue ? ` = \`${p.defaultValue.replace(/\|/g, '\\|')}\`` : p.optional ? ' *(optional)*' : ''
                }`,
            )
            .join('<br/>')
        : '*none*';
      const notes = [];
      if (fn.doc) notes.push(fn.doc.replace(/\|/g, '\\|').replace(/</g, '&lt;'));
      notes.push(`[source](${GITHUB_BLOB}/${fn.file}#L${fn.line})`);
      out.push(`| \`${renderCall(fn, lang).replace(/\|/g, '\\|')}\` | ${args} | ${notes.join(' · ')} |`);
    }
    out.push('');
  }

  return out.join('\n');
}

function main() {
  const files = readAll(PSYCHLUA_DIR);
  const lua = [];
  const python = [];

  for (const file of files) {
    const rel = path.relative(REPO_ROOT, file).split(path.sep).join('/');
    const text = fs.readFileSync(file, 'utf8');
    const isPython = rel.includes('/pystdlib/') || rel.endsWith('PythonScript.hx');
    const fns = extractFunctions(text, rel);
    (isPython ? python : lua).push(...fns);
  }

  const dedupe = (list) => {
    const seen = new Map();
    for (const fn of list) if (!seen.has(fn.name)) seen.set(fn.name, fn);
    return [...seen.values()];
  };

  fs.mkdirSync(OUT_DIR, { recursive: true });

  fs.writeFileSync(
    path.join(OUT_DIR, 'lua-api-reference.md'),
    renderPage({
      lang: 'lua',
      title: 'Lua API reference',
      sidebarLabel: 'Lua API reference',
      position: 31,
      intro: [
        'Every function below is callable from any `.lua` script loaded by the engine',
        '(song scripts, global scripts, stage scripts, custom notetypes and events).',
        'Arguments marked *(optional)* may be omitted; a shown default is the value the',
        'engine falls back to.',
        '',
        'Lua is only available in builds compiled with `LUA_ALLOWED`',
        '(`-DMODDING_LEVEL=1` or `2`; desktop defaults to `2`).',
      ].join('\n'),
      functions: dedupe(lua),
    }),
  );

  fs.writeFileSync(
    path.join(OUT_DIR, 'python-api-reference.md'),
    renderPage({
      lang: 'python',
      title: 'Python API reference',
      sidebarLabel: 'Python API reference',
      position: 41,
      intro: [
        'Phoenix Engine embeds **Hython**, a pure-Haxe Python interpreter, and exposes a',
        'subset of the Lua API to `.py` scripts under the same names, so a script can be',
        'ported between the two languages mostly by changing its syntax.',
        '',
        'Python scripting requires a build with `PYTHON_ALLOWED` (`-DMODDING_LEVEL=2`,',
        'the desktop default).',
      ].join('\n'),
      functions: dedupe(python),
    }),
  );

  console.log(
    `[script-api] wrote lua-api-reference.md (${dedupe(lua).length} functions) and python-api-reference.md (${
      dedupe(python).length
    } functions).`,
  );
}

main();
