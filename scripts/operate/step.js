#!/usr/bin/env node
// step.js — one checkpoint step of a long-running agent run (Phase 4 / v0.10.0). This is what the
// platform /loop (or /schedule) invokes each firing. It does NOT loop itself — the platform is the
// engine; this is the discipline layer: load durable state, run the reused Phase-2 eval skills as
// the drift check, update + persist state, evaluate the guardrails, and signal continue/halt.
//
// Reuse (AC-4): the drift check is the existing eval runners, shelled and read by exit code — NO
// new detector. /health = ../eval/continuous.js (test/lint pulse); /eval = ../eval/checkpoint.js
// (acceptance-criteria gate, only when the run has a --spec). Their output streams to the tty and
// is never captured (capture-nothing), so no check output can reach the state file.
//
// State is the sole source of truth across firings (AC-5): on first invocation a run is created
// and persisted; on every later firing the prior state is loaded and config flags are IGNORED
// (the file wins) so iteration / budget / consecutive-fails accumulate rather than reset.
//
// Exit contract (small-integer space, like the sibling runners):
//   0 = continue (no guardrail tripped this step)
//   1 = halt     (a guardrail stopped the run — reason printed: drift | budget | iteration-cap)
//   2 = usage / unrecoverable error (missing --id, unwritable state)
//
// Usage:
//   node scripts/operate/step.js --id <id> [--objective <s>] [--max-iterations <n>]
//        [--max-fails <n>] [--budget-ms <n>] [--spec <path>] [--cmd '<shell>' ...]
//   --cmd is repeatable and forwarded to /health (replaces its auto-detect), for deterministic runs.
'use strict';

const { spawnSync } = require('child_process');
const { path } = require('../hooks/_lib.js');
const state = require('./state.js');
const { evaluateGuardrails } = require('./guardrails.js');

const HEALTH = path.join(__dirname, '..', 'eval', 'continuous.js');
const EVAL = path.join(__dirname, '..', 'eval', 'checkpoint.js');

function parseArgs(argv) {
  const a = argv.slice(2);
  const out = { id: null, objective: '', maxIterations: null, maxFails: null, budgetMs: null, spec: null, cmds: [] };
  for (let i = 0; i < a.length; i++) {
    const k = a[i];
    if (k === '--id') out.id = a[++i];
    else if (k === '--objective') out.objective = a[++i];
    else if (k === '--max-iterations') out.maxIterations = intArg(a[++i], '--max-iterations');
    else if (k === '--max-fails') out.maxFails = intArg(a[++i], '--max-fails');
    else if (k === '--budget-ms') out.budgetMs = intArg(a[++i], '--budget-ms');
    else if (k === '--spec') out.spec = a[++i];
    else if (k === '--cmd') {
      if (i + 1 >= a.length) {
        process.stderr.write('[operate] --cmd requires a value\n');
        process.exit(2);
      }
      out.cmds.push(a[++i]);
    }
  }
  return out;
}

// Parse a non-negative integer arg; reject garbage (exit 2) rather than silently defaulting —
// a mistyped cap is a safety bug, not something to swallow.
function intArg(raw, name) {
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 0) {
    process.stderr.write(`[operate] ${name} must be a non-negative integer (got "${raw}")\n`);
    process.exit(2);
  }
  return n;
}

// Run a sibling Node runner with output streamed to the tty and nothing captured; return its exit
// code (a killed/never-started child counts as FAIL=1, never a silent pass).
function runNode(scriptPath, extraArgs, cwd) {
  const r = spawnSync('node', [scriptPath, ...extraArgs], { cwd, stdio: 'inherit' });
  return r.status == null ? 1 : r.status;
}

// Map the eval runners' 0/1/2 exit codes to a single verdict.
//   any FAIL (1)            -> 'fail'   (counts toward drift)
//   all ran and PASSed (0)  -> 'pass'   (resets the drift counter)
//   otherwise (a 2 present) -> 'none'   (nothing to check / manual remaining — not a drift signal)
function verdictFrom(codes) {
  if (codes.some((c) => c === 1)) return 'fail';
  if (codes.length && codes.every((c) => c === 0)) return 'pass';
  return 'none';
}

function main() {
  const opts = parseArgs(process.argv);
  if (!opts.id) {
    process.stderr.write('[operate] --id <run-id> is required\n');
    process.exit(2);
  }
  const cwd = process.cwd();

  // Load or create the run. A present-but-unreadable state file (corrupt write, foreign file) must
  // NOT silently restart from zero — that would lose accumulated progress (AC-5). Distinguish it
  // from a genuinely-absent file via runExists, and refuse rather than reset.
  const existed = state.runExists(cwd, opts.id);
  let s = state.loadState(cwd, opts.id);
  if (existed && !s) {
    process.stderr.write(
      `[operate] run state for "${opts.id}" exists but is unreadable/corrupt — refusing to `
      + `restart from zero (would lose progress). Inspect or remove .claude/runs/ and retry.\n`
    );
    process.exit(2);
  }
  // On creation, stamp the wall-clock start so elapsed survives firings.
  if (!s) {
    s = state.defaultState(opts.id, {
      objective: opts.objective,
      maxIterations: opts.maxIterations,
      maxConsecutiveFails: opts.maxFails != null ? opts.maxFails : 2,
      spec: opts.spec,
      budget: { maxWallClockMs: opts.budgetMs, startedAtMs: Date.now() },
    });
    if (!state.saveState(cwd, s)) {
      process.stderr.write('[operate] could not write run state — aborting\n');
      process.exit(2);
    }
  }

  // Already halted: idempotent — report and signal halt without running another checkpoint.
  if (s.halted) {
    process.stdout.write(state.formatSummary(s) + '\n');
    process.exit(1);
  }

  // Drift check = the reused eval runners (AC-4).
  const healthArgs = opts.cmds.flatMap((c) => ['--cmd', c]);
  const codes = [runNode(HEALTH, healthArgs, cwd)];
  if (s.spec) codes.push(runNode(EVAL, [s.spec], cwd));
  const verdict = verdictFrom(codes);

  // Update durable state immutably. consecutiveFails: +1 on fail, reset on pass, unchanged on none.
  const startedAtMs = (s.budget && s.budget.startedAtMs) || Date.now();
  const consecutiveFails =
    verdict === 'fail' ? (s.consecutiveFails || 0) + 1 : verdict === 'pass' ? 0 : (s.consecutiveFails || 0);
  s = state.mergeState(s, {
    iteration: (s.iteration || 0) + 1,
    consecutiveFails,
    lastVerdict: verdict,
    budget: { spentWallClockMs: Date.now() - startedAtMs },
  });

  // Evaluate guardrails against the freshly-updated state; record a halt if any tripped.
  const g = evaluateGuardrails(s);
  if (g.halt) s = state.mergeState(s, { halted: true, haltReason: g.reason });

  if (!state.saveState(cwd, s)) {
    process.stderr.write('[operate] could not persist run state\n');
    process.exit(2);
  }

  process.stdout.write('\n' + state.formatSummary(s) + '\n');
  process.exit(g.halt ? 1 : 0);
}

main();
