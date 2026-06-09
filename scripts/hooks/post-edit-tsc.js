#!/usr/bin/env node
// PostToolUse(Edit): typecheck after editing .ts/.tsx with `tsc --noEmit`.
// Surfaces type errors to Claude (stderr) but never blocks. Guarded by tsconfig
// presence. NOTE: project-wide tsc can be slow; disable this hook in hooks.json
// if it makes your loop sluggish (see README "Tuning the hooks").
'use strict';
const { readInput, editedFile, cwdOf, sh, toolCmd, fileExists, path } = require('./_lib.js');

const input = readInput();
const file = editedFile(input);
const cwd = cwdOf(input);

if (!file || !/\.(ts|tsx)$/.test(file)) process.exit(0);

// Find the nearest tsconfig walking up from the edited file.
let dir = path.dirname(file);
let tsconfig = '';
for (let i = 0; i < 6; i++) {
  const c = path.join(dir, 'tsconfig.json');
  if (fileExists(c)) { tsconfig = c; break; }
  const parent = path.dirname(dir);
  if (parent === dir) break;
  dir = parent;
}
if (!tsconfig) process.exit(0);

const tsc = toolCmd(cwd, 'tsc');
if (!tsc) process.exit(0); // TypeScript not installed → skip silently
const r = sh(`${tsc} --noEmit -p "${tsconfig}" --pretty false`, { cwd, timeout: 120000 });
if (!r.ok && r.out.trim()) {
  // Show only the first few error lines to stay concise.
  const lines = r.out.split('\n').filter(Boolean).slice(0, 12).join('\n');
  process.stderr.write(`[harness] tsc reported type errors:\n${lines}\n`);
}
process.exit(0);
