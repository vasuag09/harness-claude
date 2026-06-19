#!/usr/bin/env node
// benchmark.js — measure whether a harness COMPONENT (a skill, agent, or rule) earns its
// keep. Part of the v0.6 benchmark slice (Phase 2, AC-E3) — it fills the R5 benchmark seam
// that v0.5's extract-rubric.js left inert.
//
// Method: run the same task k times WITH the component enabled and k times WITHOUT it, each
// trial in its own throwaway `git worktree` (isolated checkout, shared object store), then
// score each trial. Report, per cohort:
//   pass@k    = the task passed in >=1 of the k trials   ("can it work")
//   pass^k    = the task passed in ALL k trials          ("does it work reliably")
//   successRate = successes / k
// and a verdict: the component earns its keep iff the `with` cohort strictly improves
// reliability without regressing —
//   pass = with.successRate > without.successRate || (with.passCaret && !without.passCaret)
//
// The harness is GENERIC: it knows nothing about any specific component. It toggles the
// component purely through an env contract the task command honors:
//   HARNESS_COMPONENT          the component name (label)
//   HARNESS_COMPONENT_ENABLED  "1" (with) | "0" (without)
//   HARNESS_TRIAL              the 0-based trial index
//   HARNESS_TRIAL_OUT          path to a per-trial cost sidecar the task MAY write (v0.8, AC-V1):
//                              the task may write `{ "cost_usd": <n>, "usage": {...} }` there; this
//                              reads ONLY those numbers (capture-nothing) to aggregate cohort cost.
// A trial passes iff its score command exits 0 (default score = the task's own exit code;
// recommended: `node scripts/eval/checkpoint.js <spec>` so a trial is scored against a spec's
// acceptance criteria).
//
// Result-driven R5 (AC-B5): this writes `.claude/eval/benchmarks/<slug>.json`; extract-rubric.js
// READS that artifact (it never invokes a live benchmark inside the deterministic gate).
//
// Git boundary: worktrees are an isolated sandbox. This NEVER runs commit/push/branch against
// the working tree — only `git worktree add/remove`, and it always cleans up (even on failure).
//
// Usage:
//   node scripts/eval/benchmark.js --component <name> --task '<cmd>' [--score '<cmd>'] [--k 5] [--out <name>]
//
// Exit contract: 0 = pass verdict (component earns its keep) · 1 = fail verdict (it does not)
//   · 2 = usage/setup error (no --task, not a git repo, no HEAD commit).
'use strict';
const { stateDir, sh, path, fs } = require('../hooks/_lib.js');
const { execSync } = require('child_process');
const os = require('os');

const DEFAULT_K = 5;

function parseArgs(argv) {
  const args = argv.slice(2);
  const get = (flag) => {
    const i = args.indexOf(flag);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : undefined;
  };
  const kRaw = get('--k');
  const k = kRaw !== undefined && Number.isInteger(+kRaw) && +kRaw > 0 ? +kRaw : DEFAULT_K;
  return {
    component: get('--component') || '',
    task: get('--task') || '',
    score: get('--score') || '',
    out: get('--out') || '',
    k,
  };
}

// Filesystem-safe slug: lowercase, non-alnum runs -> '-', trimmed. The SAME transform
// extract-rubric.js applies to a draft name when it looks up the result artifact, so a
// benchmark for component "<draft-name>" lands where R5 expects it.
function slugify(s) {
  return String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

// Run a command in `cwd` with the component env contract applied; never throws.
// Returns the exit code (0 = success).
function runCmd(cmd, cwd, env) {
  try {
    execSync(cmd, {
      cwd,
      env: { ...process.env, ...env },
      stdio: ['ignore', 'ignore', 'ignore'],
      timeout: 120000,
    });
    return 0;
  } catch (e) {
    return typeof e.status === 'number' ? e.status : 1;
  }
}

// Read a per-trial cost sidecar the task wrote to HARNESS_TRIAL_OUT. We extract ONLY numeric
// cost/usage fields — never any string the task may have included (e.g. raw model output) — so
// the capture-nothing invariant holds: nothing but numbers can reach the artifact. A missing or
// malformed sidecar -> { cost: null, tokens: null } (the trial is still scored on pass/fail).
function readSidecar(p) {
  let raw;
  try { raw = fs.readFileSync(p, 'utf8'); } catch { return { cost: null, tokens: null }; }
  let obj;
  try { obj = JSON.parse(raw); } catch { return { cost: null, tokens: null }; }
  const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
  const cost = num(obj.cost_usd) ?? num(obj.total_cost_usd);
  const u = obj.usage && typeof obj.usage === 'object' ? obj.usage : null;
  const tokens = u
    ? {
        input: num(u.input_tokens) ?? 0,
        output: num(u.output_tokens) ?? 0,
        cacheRead: num(u.cache_read_input_tokens) ?? 0,
        cacheCreation: num(u.cache_creation_input_tokens) ?? 0,
      }
    : null;
  return { cost, tokens };
}

// Aggregate per-trial cost into cohort economics. If ANY trial's cost is unknown (no sidecar),
// we refuse to partial-sum and report nulls — an honest "unmeasured" beats a misleading total.
// cost_per_success = total spent across ALL k trials / successes; null when no successes.
function aggregateCost(trials, successes, k) {
  const haveAllCost = trials.length > 0 && trials.every((t) => typeof t.cost === 'number');
  const totalCostUsd = haveAllCost ? trials.reduce((s, t) => s + t.cost, 0) : null;
  const meanCostPerTrial = totalCostUsd !== null && k ? totalCostUsd / k : null;
  const costPerSuccess = totalCostUsd !== null && successes > 0 ? totalCostUsd / successes : null;
  const haveAllTokens = trials.length > 0 && trials.every((t) => t.tokens);
  const tokens = haveAllTokens
    ? trials.reduce(
        (a, t) => ({
          input: a.input + t.tokens.input,
          output: a.output + t.tokens.output,
          cacheRead: a.cacheRead + t.tokens.cacheRead,
          cacheCreation: a.cacheCreation + t.tokens.cacheCreation,
        }),
        { input: 0, output: 0, cacheRead: 0, cacheCreation: 0 }
      )
    : null;
  return { totalCostUsd, meanCostPerTrial, costPerSuccess, tokens };
}

// One trial in an isolated worktree. Always removes the worktree (and the cost sidecar), even if
// the task or score command throws. Returns { pass, cost, tokens } for the trial.
function runTrial(repo, i, enabled, opts) {
  const fail = { pass: false, cost: null, tokens: null };
  let wt = '';
  try {
    wt = fs.mkdtempSync(path.join(os.tmpdir(), 'hc-bench-'));
  } catch {
    return fail;
  }
  // Sidecar lives OUTSIDE the worktree so it survives worktree removal and never leaks into the
  // repo; absolute path is handed to the task via HARNESS_TRIAL_OUT.
  const sidecar = path.join(
    os.tmpdir(),
    `hc-bench-out-${process.pid}-${enabled ? 1 : 0}-${i}-${Date.now()}.json`
  );
  const added = sh(`git worktree add --detach --quiet "${wt}" HEAD`, { cwd: repo }).ok;
  try {
    if (!added) return fail;
    const env = {
      HARNESS_COMPONENT: opts.component,
      HARNESS_COMPONENT_ENABLED: enabled ? '1' : '0',
      HARNESS_TRIAL: String(i),
      HARNESS_TRIAL_OUT: sidecar,
    };
    const taskCode = runCmd(opts.task, wt, env);
    // No score command -> the task's own exit code is the pass signal.
    const passed = !opts.score ? taskCode === 0 : runCmd(opts.score, wt, env) === 0;
    const { cost, tokens } = readSidecar(sidecar);
    return { pass: passed, cost, tokens };
  } finally {
    if (added) sh(`git worktree remove --force "${wt}"`, { cwd: repo });
    try { fs.rmSync(wt, { recursive: true, force: true }); } catch {}
    try { fs.rmSync(sidecar, { force: true }); } catch {}
  }
}

// Run k trials for one cohort; aggregate into the pass@k / pass^k + cost metrics.
function runCohort(repo, enabled, opts) {
  const trials = [];
  for (let i = 0; i < opts.k; i++) {
    trials.push(runTrial(repo, i, enabled, opts));
  }
  const successes = trials.reduce((n, t) => n + (t.pass ? 1 : 0), 0);
  return {
    k: opts.k,
    successes,
    passAt: successes >= 1, // pass@k: works at least once
    passCaret: successes === opts.k, // pass^k: works on all k trials
    successRate: opts.k ? successes / opts.k : 0,
    ...aggregateCost(trials, successes, opts.k),
  };
}

function verdict(withC, withoutC) {
  const pass =
    withC.successRate > withoutC.successRate ||
    (withC.passCaret && !withoutC.passCaret);
  const reason = pass
    ? `component improves reliability (rate ${withC.successRate.toFixed(2)} vs ${withoutC.successRate.toFixed(2)})`
    : `component shows no reliability gain (rate ${withC.successRate.toFixed(2)} vs ${withoutC.successRate.toFixed(2)})`;
  return { pass, reason };
}

function report(result) {
  const money = (v) => (v == null ? 'n/a' : `$${v.toFixed(4)}`);
  const row = (label, c) =>
    `  ${label.padEnd(8)} pass@k=${c.passAt} pass^k=${c.passCaret} ` +
    `(${c.successes}/${c.k}, rate ${c.successRate.toFixed(2)}) ` +
    `cost/success=${money(c.costPerSuccess)} total=${money(c.totalCostUsd)}`;
  return [
    `benchmark: component "${result.component}" over k=${result.k} trials`,
    row('with', result.with),
    row('without', result.without),
    `verdict: ${result.pass ? 'PASS' : 'FAIL'} — ${result.reason}`,
  ].join('\n');
}

function main() {
  const opts = parseArgs(process.argv);
  if (!opts.task) {
    process.stderr.write('[benchmark] --task <cmd> is required\n');
    process.exit(2);
  }
  const repo = process.cwd();
  if (!sh('git rev-parse --is-inside-work-tree', { cwd: repo }).ok) {
    process.stderr.write('[benchmark] not inside a git work tree\n');
    process.exit(2);
  }
  if (!sh('git rev-parse --verify HEAD', { cwd: repo }).ok) {
    process.stderr.write('[benchmark] repo has no HEAD commit to fork a worktree from\n');
    process.exit(2);
  }

  const withC = runCohort(repo, true, opts);
  const withoutC = runCohort(repo, false, opts);
  const v = verdict(withC, withoutC);

  const slug = slugify(opts.out || opts.component || 'benchmark');
  const result = {
    component: opts.component,
    k: opts.k,
    task: opts.task,
    score: opts.score || null,
    with: withC,
    without: withoutC,
    pass: v.pass,
    reason: v.reason,
    ts: new Date().toISOString(),
  };

  const dir = stateDir(repo, path.join('eval', 'benchmarks'));
  const outPath = path.join(dir, `${slug}.json`);
  try {
    fs.writeFileSync(outPath, JSON.stringify(result, null, 2) + '\n');
  } catch (e) {
    process.stderr.write(`[benchmark] could not write ${outPath}: ${e.message}\n`);
    process.exit(2);
  }

  process.stdout.write(report(result) + '\n');
  process.stdout.write(`result: ${outPath}\n`);
  process.exit(v.pass ? 0 : 1);
}

main();
