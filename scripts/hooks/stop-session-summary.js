#!/usr/bin/env node
// Stop: persist a mechanical end-of-turn snapshot when there is real activity
// (a dirty working tree). Keeps a breadcrumb even if /save-session wasn't run.
// Always exits 0 — never blocks or re-triggers the stop.
'use strict';
const { readInput, cwdOf, sh, todayFile, appendFile, stateFile, fileExists, fs } = require('./_lib.js');

const input = readInput();
const cwd = cwdOf(input);

const status = sh('git status --short', { cwd }).out.trim();
if (!status) process.exit(0); // nothing changed → no noise

// Refresh the STATE.md spine's `updated:` timestamp so it reflects recent activity.
// Timestamp only — status/phase/next_skill are owned by the skills, not this hook.
// No-op cleanly when STATE.md is absent or has no `updated:` line.
try {
  const sp = stateFile(cwd);
  if (fileExists(sp)) {
    const text = fs.readFileSync(sp, 'utf8');
    if (/^updated:/m.test(text)) {
      fs.writeFileSync(sp, text.replace(/^updated:.*$/m, `updated: ${new Date().toISOString()}`));
    }
  }
} catch {}

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
