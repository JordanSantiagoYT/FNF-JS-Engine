#!/usr/bin/env node
/**
 * Guards the markdown conventions the Docusaurus site needs to render correctly.
 *
 *   node scripts/check-doc-syntax.mjs
 *
 * The site sets `markdown.format: 'detect'`, so every `.md` file is parsed as
 * CommonMark and only CommonMark-compatible syntax renders. Two things break
 * silently (they build fine, they just look wrong):
 *
 *  - the legacy admonition title syntax `:::note Title`, which is only accepted
 *    while `markdown.mdx1Compat.admonitions` is on (it is off under `future.v4`)
 *    and renders the whole block as plain text;
 *  - markup inside a directive label (`:::note[`flag`]`), whose complex title
 *    leaks a raw <mdxAdmonitionTitle> element instead of a styled heading.
 *
 * Exits non-zero with a `file:line` list when either shows up outside a code fence.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DOCS_DIR = path.resolve(__dirname, '..', 'docs');

const KEYWORDS = new Set([
  'note',
  'secondary',
  'tip',
  'success',
  'info',
  'warning',
  'danger',
  'caution',
  'important',
]);

const LEGACY_TITLE = /^:{3,}([A-Za-z][\w-]*)[ \t]+(\S.*?) *$/;
const LABELLED = /^:{3,}([A-Za-z][\w-]*)\[([^\]]*)\]/;
const FENCE = /^\s*(```|~~~)/;

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.isFile() && /\.(md|mdx)$/.test(entry.name)) out.push(full);
  }
  return out;
}

function checkFile(file) {
  const problems = [];
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  let inFence = false;

  lines.forEach((line, index) => {
    if (FENCE.test(line)) {
      inFence = !inFence;
      return;
    }
    if (inFence) return;

    const trimmed = line.trim();
    const legacy = LEGACY_TITLE.exec(trimmed);
    if (legacy && KEYWORDS.has(legacy[1])) {
      problems.push({
        line: index + 1,
        message: `\`${trimmed}\` is the MDX-v1 admonition syntax and renders as plain text. `
          + `Write \`:::${legacy[1]}[${legacy[2].replace(/`/g, '')}]\` instead.`,
      });
      return;
    }

    const labelled = LABELLED.exec(trimmed);
    if (labelled && KEYWORDS.has(labelled[1])) {
      const title = labelled[2];
      if (/[`<>{]|https?:\/\//.test(title)) {
        problems.push({
          line: index + 1,
          message: `admonition titles are plain text in CommonMark — \`${trimmed}\` `
            + 'contains markup that would leak raw tags. Remove the backticks/braces.',
        });
      }
      if (title.length > 60) {
        problems.push({
          line: index + 1,
          message: 'admonition titles should be short labels (60 chars or less) — move the '
            + 'prose into the body.',
        });
      }
    }
  });

  return problems;
}

const files = fs.existsSync(DOCS_DIR) ? walk(DOCS_DIR).sort() : [];
const report = [];
for (const file of files) {
  for (const problem of checkFile(file)) {
    report.push(`${path.relative(path.resolve(DOCS_DIR, '..'), file)}:${problem.line}: ${problem.message}`);
  }
}

if (report.length) {
  console.error(`[doc-syntax] ${report.length} problem(s) in ${files.length} files:\n`);
  for (const entry of report) console.error(`  ${entry}`);
  console.error('\nAdmonitions must be written as `:::type[Title]` with a plain-text title.');
  process.exit(1);
}

console.log(`[doc-syntax] ${files.length} markdown files checked, no admonition problems.`);
