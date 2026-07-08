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

// Resolve where session/staging state lives: repo-root .claude when in a git repo,
// else a harness dir under the user's home.
function stateDir(cwd, sub) {
  // cwd is supplied by the Claude Code hook payload. Require an absolute path so a
  // relative value (e.g. "../../tmp") can't redirect state writes outside the project
  // via "../" traversal; fall back to the real process cwd otherwise.
  const start = cwd && path.isAbsolute(cwd) ? cwd : process.cwd();
  // Anchor state at the git repo ROOT — not whatever subdir the shell cd'd into — so a
  // hook running from e.g. skills/ can't create a stray skills/.claude/. Fall back to a
  // home dir when not in a repo. (--show-toplevel prints stderr on failure, so gate on ok.)
  const top = sh('git rev-parse --show-toplevel', { cwd: start });
  const base = top.ok && top.out.trim()
    ? path.join(top.out.trim(), '.claude')
    : path.join(os.homedir(), '.claude', 'harness-claude');
  const dir = path.join(base, sub);
  try { fs.mkdirSync(dir, { recursive: true }); } catch {}
  return dir;
}

function todayFile(cwd) {
  const d = new Date().toISOString().slice(0, 10);
  return path.join(stateDir(cwd, 'sessions'), `${d}.md`);
}

// Path to the STATE.md spine — repo-root .claude/STATE.md (or the home fallback).
function stateFile(cwd) {
  // stateDir already mkdir's .claude/sessions; STATE.md sits one level up in .claude/.
  return path.join(path.dirname(stateDir(cwd, 'sessions')), 'STATE.md');
}

// Parse the leading `--- ... ---` YAML frontmatter of a markdown string into a flat
// { key: value } map. Deliberately minimal (no YAML dep): top-level `key: value` lines
// only, quotes stripped, `null`/empty → undefined. Never throws; returns {} on anything
// unexpected so a malformed STATE.md degrades gracefully instead of breaking a hook.
function parseFrontmatter(text) {
  try {
    const m = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text || '');
    if (!m) return {};
    const out = {};
    for (const line of m[1].split(/\r?\n/)) {
      const kv = /^([A-Za-z0-9_]+):\s*(.*)$/.exec(line);
      if (!kv) continue;
      let v = kv[2].trim().replace(/^["']|["']$/g, '');
      if (v === '' || v === 'null' || v === '~') continue;
      out[kv[1]] = v;
    }
    return out;
  } catch { return {}; }
}

// Read + parse STATE.md frontmatter, or {} if absent/unreadable.
function readState(cwd) {
  try {
    const p = stateFile(cwd);
    return fileExists(p) ? parseFrontmatter(fs.readFileSync(p, 'utf8')) : {};
  } catch { return {}; }
}

function appendFile(p, text) {
  try { fs.appendFileSync(p, text); return true; } catch { return false; }
}

// The request→skill routing instruction hooks inject so pipeline discipline survives
// on installed projects (where rules/*.md never load). One line; keep it terse.
const ROUTING_TABLE =
  'Route the request through the harness, not ad-hoc edits: new feature/build → /spec (or /harness-plan) · bug/defect/red test → /fix · vague intent → /discover · build/type/compile error → /build-fix · resuming prior work → /resume-session.';

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
  stateFile, parseFrontmatter, readState, ROUTING_TABLE,
};
