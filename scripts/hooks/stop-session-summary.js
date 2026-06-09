#!/usr/bin/env node
// Stop: persist a mechanical end-of-turn snapshot when there is real activity
// (a dirty working tree). Keeps a breadcrumb even if /save-session wasn't run.
// Always exits 0 — never blocks or re-triggers the stop.
'use strict';
const { readInput, cwdOf, sh, todayFile, appendFile } = require('./_lib.js');

const input = readInput();
const cwd = cwdOf(input);

const status = sh('git status --short', { cwd }).out.trim();
if (!status) process.exit(0); // nothing changed → no noise

const branch = sh('git rev-parse --abbrev-ref HEAD', { cwd }).out.trim() || '(no git)';
const files = status.split('\n').slice(0, 30).join('\n');
const stamp = new Date().toISOString();

const snapshot = [
  ``,
  `## Session-end snapshot — ${stamp}`,
  `- branch: ${branch}`,
  `- uncommitted changes:`,
  '```',
  files,
  '```',
  ``,
].join('\n');

appendFile(todayFile(cwd), snapshot);
process.exit(0);
