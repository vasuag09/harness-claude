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

// One trial in an isolated worktree. Always removes the worktree, even if the task or score
// command throws. Returns true iff the trial passed.
function runTrial(repo, i, enabled, opts) {
  let wt = '';
  try {
    wt = fs.mkdtempSync(path.join(os.tmpdir(), 'hc-bench-'));
  } catch {
    return false;
  }
  const added = sh(`git worktree add --detach --quiet "${wt}" HEAD`, { cwd: repo }).ok;
  try {
    if (!added) return false;
    const env = {
      HARNESS_COMPONENT: opts.component,
      HARNESS_COMPONENT_ENABLED: enabled ? '1' : '0',
      HARNESS_TRIAL: String(i),
    };
    const taskCode = runCmd(opts.task, wt, env);
    // No score command -> the task's own exit code is the pass signal.
    if (!opts.score) return taskCode === 0;
    return runCmd(opts.score, wt, env) === 0;
  } finally {
    if (added) sh(`git worktree remove --force "${wt}"`, { cwd: repo });
    try { fs.rmSync(wt, { recursive: true, force: true }); } catch {}
  }
}

// Run k trials for one cohort; aggregate into the pass@k / pass^k metrics.
function runCohort(repo, enabled, opts) {
  let successes = 0;
  for (let i = 0; i < opts.k; i++) {
    if (runTrial(repo, i, enabled, opts)) successes++;
  }
  return {
    k: opts.k,
    successes,
    passAt: successes >= 1, // pass@k: works at least once
    passCaret: successes === opts.k, // pass^k: works on all k trials
    successRate: opts.k ? successes / opts.k : 0,
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
  const row = (label, c) =>
    `  ${label.padEnd(8)} pass@k=${c.passAt} pass^k=${c.passCaret} ` +
    `(${c.successes}/${c.k}, rate ${c.successRate.toFixed(2)})`;
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
