#!/usr/bin/env node
// PostToolUse(Edit|Write|MultiEdit): fast quality checks on the edited file —
// lint (eslint/ruff), a stray-debug scan, and a lightweight secret scan.
// Non-blocking: surfaces findings to Claude via stderr.
'use strict';
const { readInput, editedFile, cwdOf, sh, toolCmd, has, fileExists, fs } = require('./_lib.js');

const input = readInput();
const file = editedFile(input);
const cwd = cwdOf(input);
if (!file || !fileExists(file)) process.exit(0);

const findings = [];

// --- lint (only if the linter is actually installed; skip silently otherwise) -
if (/\.(js|jsx|ts|tsx|mjs|cjs)$/.test(file)) {
  const eslint = toolCmd(cwd, 'eslint');
  if (eslint) {
    const r = sh(`${eslint} --fix "${file}"`, { cwd, timeout: 30000 });
    if (!r.ok && r.out.trim()) findings.push(`eslint:\n${r.out.split('\n').slice(0, 8).join('\n')}`);
  }
} else if (/\.py$/.test(file)) {
  if (has('ruff')) {
    const r = sh(`ruff check --fix "${file}"`, { cwd, timeout: 20000 });
    if (!r.ok && r.out.trim()) findings.push(`ruff:\n${r.out.split('\n').slice(0, 8).join('\n')}`);
  }
}

// --- content scans ----------------------------------------------------------
let content = '';
try { content = fs.readFileSync(file, 'utf8'); } catch {}

if (/\.(js|jsx|ts|tsx|mjs|cjs)$/.test(file) && /console\.(log|debug)\s*\(/.test(content)) {
  findings.push('stray console.log/debug — remove before commit.');
}
if (/\.py$/.test(file) && /(^|\s)print\s*\(/.test(content) && /\b(debug|TODO)\b/i.test(content)) {
  findings.push('possible debug print() left in code.');
}

// Lightweight secret heuristics (high-signal patterns only, to avoid noise).
const SECRET = [
  /\b(sk-[A-Za-z0-9]{20,})/,                         // OpenAI-style
  /\bAKIA[0-9A-Z]{16}\b/,                            // AWS access key id
  /\bghp_[A-Za-z0-9]{36}\b/,                         // GitHub PAT
  /-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----/, // private key
  /(api[_-]?key|secret|password|token)\s*[:=]\s*["'][A-Za-z0-9_\-]{16,}["']/i,
];
if (SECRET.some((re) => re.test(content))) {
  findings.push('POSSIBLE HARDCODED SECRET — move it to env/secret manager and rotate if real.');
}

if (findings.length) {
  process.stderr.write(`[harness] quality gate on ${file}:\n- ${findings.join('\n- ')}\n`);
}
process.exit(0);
