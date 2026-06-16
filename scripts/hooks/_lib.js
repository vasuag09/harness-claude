// _lib.js — shared helpers for harness-claude hook scripts.
// Hooks receive a JSON object on stdin and communicate via exit code + stderr.
// Everything here is defensive: a hook must never crash the tool call.

'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

function readInput() {
  try {
    const raw = fs.readFileSync(0, 'utf8');
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

// Path of the file an Edit/Write/MultiEdit touched, if any.
function editedFile(input) {
  const ti = input.tool_input || {};
  return ti.file_path || ti.path || (ti.edits && ti.notebook_path) || '';
}

function cwdOf(input) {
  return input.cwd || process.cwd();
}

// Run a command; never throw. Returns { ok, out, code }.
function sh(cmd, opts = {}) {
  try {
    const out = execSync(cmd, {
      stdio: ['ignore', 'pipe', 'pipe'],
      encoding: 'utf8',
      timeout: opts.timeout || 20000,
      cwd: opts.cwd || process.cwd(),
    });
    return { ok: true, out: out || '', code: 0 };
  } catch (e) {
    return { ok: false, out: (e.stdout || '') + (e.stderr || ''), code: e.status || 1 };
  }
}

function has(bin) {
  return sh(process.platform === 'win32' ? `where ${bin}` : `command -v ${bin}`).ok;
}

// Resolve a runnable command for a JS tool: prefer the project's local
// node_modules/.bin/<bin> (walking up from cwd), else a global binary, else null.
// Returns a quoted, runnable command prefix or null if the tool isn't available —
// so hooks can skip silently instead of leaking "not installed" noise.
function toolCmd(cwd, bin) {
  let dir = cwd;
  for (let i = 0; i < 8; i++) {
    const cand = path.join(dir, 'node_modules', '.bin', bin);
    if (fileExists(cand)) return `"${cand}"`;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return has(bin) ? bin : null;
}

function fileExists(p) {
  try { return fs.existsSync(p); } catch { return false; }
}

// Resolve where session/staging state lives: project .claude when in a git repo,
// else a harness dir under the user's home.
function stateDir(cwd, sub) {
  // cwd is supplied by the Claude Code hook payload. Require an absolute path so a
  // relative value (e.g. "../../tmp") can't redirect state writes outside the project
  // via "../" traversal; fall back to the real process cwd otherwise.
  const root = cwd && path.isAbsolute(cwd) ? cwd : process.cwd();
  const inRepo = sh('git rev-parse --is-inside-work-tree', { cwd: root }).ok;
  const base = inRepo
    ? path.join(root, '.claude')
    : path.join(os.homedir(), '.claude', 'harness-claude');
  const dir = path.join(base, sub);
  try { fs.mkdirSync(dir, { recursive: true }); } catch {}
  return dir;
}

function todayFile(cwd) {
  const d = new Date().toISOString().slice(0, 10);
  return path.join(stateDir(cwd, 'sessions'), `${d}.md`);
}

function appendFile(p, text) {
  try { fs.appendFileSync(p, text); return true; } catch { return false; }
}

// Emit a non-blocking note to the user/Claude (shown via stderr) and exit 0.
function note(msg) {
  if (msg) process.stderr.write(`[harness] ${msg}\n`);
  process.exit(0);
}

// Block a PreToolUse call: stderr is fed back to Claude.
function block(msg) {
  process.stderr.write(`[harness] BLOCKED: ${msg}\n`);
  process.exit(2);
}

module.exports = {
  readInput, editedFile, cwdOf, sh, has, toolCmd, fileExists,
  stateDir, todayFile, appendFile, note, block, path, fs, os,
};
