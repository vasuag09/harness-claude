#!/usr/bin/env node
// SessionStart: detect the package manager and surface a pointer to the most
// recent session file so context can be resumed. Output goes to stdout, which
// Claude Code adds to the session context.
'use strict';
const { readInput, cwdOf, stateDir, fileExists, readState, path, fs } = require('./_lib.js');

const input = readInput();
const cwd = cwdOf(input);

// --- package manager / stack detection -------------------------------------
const pm = [];
if (fileExists(path.join(cwd, 'pnpm-lock.yaml'))) pm.push('pnpm');
else if (fileExists(path.join(cwd, 'yarn.lock'))) pm.push('yarn');
else if (fileExists(path.join(cwd, 'bun.lockb'))) pm.push('bun');
else if (fileExists(path.join(cwd, 'package-lock.json'))) pm.push('npm');
if (fileExists(path.join(cwd, 'pyproject.toml')) || fileExists(path.join(cwd, 'requirements.txt'))) {
  pm.push(fileExists(path.join(cwd, 'uv.lock')) ? 'uv' : 'pip');
}

// --- latest session file ----------------------------------------------------
let resume = '';
try {
  const dir = stateDir(cwd, 'sessions');
  const files = fs.readdirSync(dir)
    .filter((f) => /^\d{4}-\d{2}-\d{2}\.md$/.test(f))
    .sort()
    .reverse();
  if (files.length) resume = path.join(dir, files[0]);
} catch {}

// --- STATE.md spine (machine-navigable position, if present) ----------------
const st = readState(cwd);

const lines = ['[harness-claude] session context:'];
if (pm.length) lines.push(`- package manager / stack: ${pm.join(', ')}`);
// The STATE spine is the fast path: surface where we are + the one command to run next.
if (st.phase || st.next_skill) {
  const pos = [st.phase && `phase ${st.phase}`, st.status].filter(Boolean).join(' · ');
  if (pos) lines.push(`- STATE: ${pos}${st.slug ? ` (${st.slug})` : ''}`);
  if (st.next_skill) lines.push(`- next: ${st.next_skill} — run /resume-session for the full restore.`);
} else if (resume) {
  lines.push(`- previous session notes: ${resume} — run /resume-session to load them.`);
}
if (st.phase && resume) lines.push(`- session narrative: ${resume}`);
lines.push('- pipeline: /spec → /research → /plan → /plan-check → /architect → /implement → /review → /security-review → /test → /verify → /ship → /refactor-clean');

process.stdout.write(lines.join('\n') + '\n');
process.exit(0);
