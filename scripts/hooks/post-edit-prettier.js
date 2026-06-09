#!/usr/bin/env node
// PostToolUse(Edit): auto-format edited JS/TS files with the project's Prettier.
// Best-effort and non-blocking — skips silently if Prettier isn't available.
'use strict';
const { readInput, editedFile, cwdOf, sh, toolCmd, fileExists } = require('./_lib.js');

const input = readInput();
const file = editedFile(input);
const cwd = cwdOf(input);

if (!file || !fileExists(file)) process.exit(0);
if (!/\.(js|jsx|ts|tsx|mjs|cjs|json|css|scss|md)$/.test(file)) process.exit(0);

// Use the project's prettier; skip silently if it isn't installed.
const prettier = toolCmd(cwd, 'prettier');
if (!prettier) process.exit(0);
const r = sh(`${prettier} --write "${file}"`, { cwd, timeout: 30000 });
if (r.ok) process.stderr.write(`[harness] prettier formatted ${file}\n`);
// Non-blocking regardless of outcome.
process.exit(0);
