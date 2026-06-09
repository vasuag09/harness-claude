#!/usr/bin/env node
// PreCompact: persist a mechanical snapshot before context is compacted, so no
// state is lost. The rich, semantic summary is the job of the /save-session skill;
// this is the always-on safety net. Non-blocking.
'use strict';
const { readInput, cwdOf, sh, todayFile, appendFile } = require('./_lib.js');

const input = readInput();
const cwd = cwdOf(input);

const branch = sh('git rev-parse --abbrev-ref HEAD', { cwd }).out.trim() || '(no git)';
const status = sh('git status --short', { cwd }).out.trim();
const files = status ? status.split('\n').slice(0, 30).join('\n') : '(clean)';
const stamp = new Date().toISOString();

const snapshot = [
  ``,
  `## PreCompact snapshot — ${stamp}`,
  `- branch: ${branch}`,
  `- working tree:`,
  '```',
  files,
  '```',
  `- reminder: run /save-session for a semantic summary if this work continues.`,
  ``,
].join('\n');

appendFile(todayFile(cwd), snapshot);
process.exit(0);
