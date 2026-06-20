#!/usr/bin/env node
// state.js — durable run-state for a long-running agent (Phase 4 / v0.10.0). Reads/merges/writes
// .claude/runs/<id>.json via _lib.js stateDir. The state file is the SOLE source of truth across
// /loop firings: each firing may be a fresh context, so iteration / budget-spent / consecutive-fail
// must persist here and be restored on the next firing (spec AC-5). Updates are immutable — every
// helper returns a new object, never mutates its input.
//
// Secret-safety (hard invariant, mirrors continuous.js / checkpoint.js): the state records only
// metrics / verdicts / reasons — iteration counts, budgets, pass/fail verdict, halt reason. It
// NEVER stores a check's captured output. The eval runners already stream output to the tty and
// capture nothing; this file keeps that boundary.
//
// Schema of .claude/runs/<id>.json (folded into Phase 1 per plan):
//   id                  string    run identifier (sanitised for the filename)
//   objective           string    one-line goal of the run
//   spec                string?   path to the spec the run is checked against (or null)
//   createdAt/updatedAt string    ISO timestamps
//   iteration           number    completed iterations so far
//   maxIterations       number?   hard ceiling (null = inert)
//   consecutiveFails    number    consecutive failing checkpoints (resets to 0 on a pass)
//   maxConsecutiveFails number?   drift threshold N (null = inert; spec default 2)
//   budget              object    { maxWallClockMs?, spentWallClockMs, maxTokens?, spentTokens }
//   lastVerdict         string?   'pass' | 'fail' | 'none' | null  (last checkpoint result)
//   lastAction          string?   short note on the last action taken (no output)
//   halted              boolean   true once a guardrail stopped the run
//   haltReason          string?   'drift' | 'budget' | 'iteration-cap' | 'done' | null
'use strict';

const { stateDir, fileExists, path, fs } = require('../hooks/_lib.js');

// Sanitise a run id for safe use as a filename: allow [A-Za-z0-9._-], collapse everything else to
// '_', strip any leading dots so traversal/hidden-file ids ("../../evil", ".x") can't escape the
// runs dir. Trust boundary — the id may be user/agent supplied.
function sanitizeId(id) {
  const raw = String(id == null ? '' : id);
  const cleaned = raw
    .replace(/[^A-Za-z0-9._-]/g, '_') // only filename-safe chars survive
    .replace(/\.{2,}/g, '_')          // collapse any '..' run — never a traversal-shaped name
    .replace(/^\.+/, '');             // no leading dot — never a hidden file
  return cleaned || 'run';
}

// Absolute path of the state file for <id> inside the target repo's .claude/runs.
function runPath(cwd, id) {
  return path.join(stateDir(cwd, 'runs'), `${sanitizeId(id)}.json`);
}

// True if a state file already exists for <id> — lets the caller distinguish "first firing"
// (no file) from "present but unreadable" (corrupt) so it never silently restarts from zero.
function runExists(cwd, id) {
  return fileExists(runPath(cwd, id));
}

// A fresh run-state. opts overrides defaults (objective, caps, budget). budget is deep-merged so a
// caller can set only maxWallClockMs and still get spent counters initialised to 0.
function defaultState(id, opts = {}) {
  const o = opts || {};
  const now = new Date().toISOString();
  const base = {
    id: String(id == null ? 'run' : id),
    objective: o.objective || '',
    spec: o.spec || null,
    createdAt: now,
    updatedAt: now,
    iteration: 0,
    maxIterations: o.maxIterations != null ? o.maxIterations : null,
    consecutiveFails: 0,
    maxConsecutiveFails: o.maxConsecutiveFails != null ? o.maxConsecutiveFails : 2,
    budget: {
      maxWallClockMs: null,
      spentWallClockMs: 0,
      maxTokens: null,
      spentTokens: 0,
    },
    lastVerdict: null,
    lastAction: null,
    halted: false,
    haltReason: null,
  };
  return mergeState(base, o.budget ? { budget: o.budget } : {});
}

// Immutable merge: returns a new state with patch applied. budget is deep-merged (patch.budget
// fields override, others preserved) so partial budget updates don't wipe sibling counters.
// updatedAt is refreshed on every merge.
function mergeState(prev, patch = {}) {
  const p = patch || {};
  const next = { ...prev, ...p, updatedAt: new Date().toISOString() };
  if (p.budget) {
    next.budget = { ...(prev.budget || {}), ...p.budget };
  } else {
    next.budget = { ...(prev.budget || {}) };
  }
  return next;
}

// Load <id>'s state, or null if absent/unreadable/not-a-run-state. A real run-state has a string
// id and a numeric iteration; anything else at this path (corrupt write, legacy/foreign file)
// returns null so the caller can refuse to proceed on garbage counts. Pair with runExists() to
// tell "missing" (safe to create) from "present but null" (corrupt — must not restart; AC-5).
function loadState(cwd, id) {
  const p = runPath(cwd, id);
  if (!fileExists(p)) return null;
  try {
    const s = JSON.parse(fs.readFileSync(p, 'utf8'));
    if (!s || typeof s !== 'object' || typeof s.id !== 'string' || typeof s.iteration !== 'number') {
      return null;
    }
    return s;
  } catch {
    return null;
  }
}

// Persist state to .claude/runs/<id>.json. Returns the path written, or null on failure (never
// throws — a failed state write must not crash the run loop). Pretty-printed for human review.
function saveState(cwd, state) {
  const p = runPath(cwd, state && state.id);
  try {
    fs.writeFileSync(p, JSON.stringify(state, null, 2) + '\n');
    return p;
  } catch {
    return null;
  }
}

// Structured summary of a run — metrics/verdict/reason only (AC-6). No output, ever.
function summarize(state) {
  const s = state || {};
  const b = s.budget || {};
  return {
    id: s.id,
    iterations: s.iteration || 0,
    budgetSpentMs: b.spentWallClockMs || 0,
    lastVerdict: s.lastVerdict || null,
    halted: !!s.halted,
    haltReason: s.haltReason || null,
  };
}

// One-line human summary for the operator's final report.
function formatSummary(state) {
  const s = summarize(state);
  const reason = s.haltReason ? `halt=${s.haltReason}` : 'running';
  return `run ${s.id}: ${s.iterations} iteration(s), ${s.budgetSpentMs}ms spent, `
    + `last verdict ${s.lastVerdict || 'n/a'}, ${reason}`;
}

module.exports = {
  sanitizeId, runPath, runExists, defaultState, mergeState, loadState, saveState, summarize, formatSummary,
};
