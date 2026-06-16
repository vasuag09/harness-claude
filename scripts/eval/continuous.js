#!/usr/bin/env node
// continuous.js — take the target repo's health pulse: run its test/lint/typecheck (and any
// extra) checks on demand and emit a single pass/fail summary. Part of the v0.7 continuous-eval
// slice (Phase 2, AC-E2) — the last open Phase-2 criterion.
//
// Secret-safety (hard invariant): a check's output is NEVER captured. Each child runs with
// stdio:'inherit', so its output streams straight to YOUR terminal (same trust as running the
// command yourself) and never enters a JS string — so it cannot reach the summary, the JSON
// artifact, or any log. The artifact records only name/command/pass/durationMs + the gate.
// This mirrors the v0.3 trace hook + v0.4 checkpoint capture-nothing rule.
//
// TRUST BOUNDARY: detected or --cmd commands are shell-executed (execSync) with your
// privileges — same trust as the repo's own `npm test` / build scripts. Don't point this at a
// repo whose package.json scripts / Makefile you don't trust.
//
// Discovery: with no --cmd, auto-detects checks (package.json test/lint/typecheck scripts, else
// a Makefile test/lint target). --cmd '<shell>' (repeatable) REPLACES the detected set.
//
// Usage:
//   node scripts/eval/continuous.js                      # auto-detect, run, gate
//   node scripts/eval/continuous.js --cmd 'pytest -q' --cmd 'ruff check .'
//   node scripts/eval/continuous.js --list               # resolve + print checks, run nothing
//   [--timeout-ms <n>]                                   # per-check timeout (default 300000)
//
// Exit contract (mirrors checkpoint.js / trace-report.js):
//   0 = all checks PASS · 1 = any check FAIL · 2 = nothing to run (no checks resolved).
'use strict';
const { stateDir, fileExists, path, fs } = require('../hooks/_lib.js');
const { execSync } = require('child_process');

const DEFAULT_TIMEOUT_MS = 300000;

// --cmd '<shell>' is repeatable; when any --cmd is present it REPLACES (not merges with) the
// auto-detected set. --list resolves+prints checks without running them. --timeout-ms must be a
// positive integer; an invalid value is rejected (exit 2) rather than silently ignored.
function parseArgs(argv) {
  const args = argv.slice(2);
  const cmds = [];
  let list = false;
  let timeoutMs = DEFAULT_TIMEOUT_MS;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--list') list = true;
    else if (a === '--cmd' && i + 1 < args.length) cmds.push(args[++i]);
    else if (a === '--timeout-ms' && i + 1 < args.length) {
      const raw = args[++i];
      const n = Number(raw);
      if (!Number.isInteger(n) || n <= 0) {
        process.stderr.write(`[continuous] --timeout-ms must be a positive integer (got "${raw}")\n`);
        process.exit(2);
      }
      timeoutMs = n;
    }
  }
  return { cmds, list, timeoutMs };
}

// Which package manager runs the scripts: lockfile wins, default npm. `<pm> run <script>`
// is universal across npm/yarn/pnpm.
function detectPm(cwd) {
  if (fileExists(path.join(cwd, 'pnpm-lock.yaml'))) return 'pnpm';
  if (fileExists(path.join(cwd, 'yarn.lock'))) return 'yarn';
  return 'npm';
}

// Auto-detected checks for the repo at cwd. package.json scripts first (test/lint/typecheck in
// that order), else Makefile test/lint targets. Returns [] when nothing is detectable — the
// caller turns that into the "nothing to run" exit-2 case.
function detectChecks(cwd) {
  const pkgPath = path.join(cwd, 'package.json');
  if (fileExists(pkgPath)) {
    let scripts = {};
    try { scripts = JSON.parse(fs.readFileSync(pkgPath, 'utf8')).scripts || {}; } catch { scripts = {}; }
    const pm = detectPm(cwd);
    const checks = [];
    for (const name of ['test', 'lint', 'typecheck']) {
      if (typeof scripts[name] === 'string' && scripts[name].trim()) {
        checks.push({ name, command: `${pm} run ${name}` });
      }
    }
    if (checks.length) return checks;
  }
  const mkPath = path.join(cwd, 'Makefile');
  if (fileExists(mkPath)) {
    let body = '';
    try { body = fs.readFileSync(mkPath, 'utf8'); } catch { body = ''; }
    const checks = [];
    for (const name of ['test', 'lint']) {
      if (new RegExp(`^${name}:`, 'm').test(body)) {
        checks.push({ name, command: `make ${name}` });
      }
    }
    if (checks.length) return checks;
  }
  return [];
}

// --cmd present -> replace the detected set; else auto-detect.
function resolveChecks(opts, cwd) {
  if (opts.cmds.length) {
    return opts.cmds.map((command, i) => ({ name: `cmd${i + 1}`, command }));
  }
  return detectChecks(cwd);
}

// Run one check with output streamed live to the tty and NOTHING captured. Never throws.
// Returns { name, command, pass, durationMs }.
function runCheck(check, cwd, timeoutMs) {
  const started = Date.now();
  let pass = true;
  try {
    execSync(check.command, { cwd, stdio: 'inherit', timeout: timeoutMs });
  } catch {
    pass = false; // non-zero exit OR timeout (SIGTERM) OR spawn error — all are FAIL
  }
  return { name: check.name, command: check.command, pass, durationMs: Date.now() - started };
}

function gateCode(results) {
  if (!results.length) return 2;
  return results.some((r) => !r.pass) ? 1 : 0;
}

function fmtDur(ms) {
  return ms >= 1000 ? `${(ms / 1000).toFixed(1)}s` : `${ms}ms`;
}

function report(results, exit) {
  const lines = results.map((r) => {
    const base = `  ${(r.pass ? 'PASS' : 'FAIL').padEnd(4)}  ${r.name.padEnd(10)} ${fmtDur(r.durationMs).padStart(7)}`;
    return r.pass ? base : `${base}   → re-run: ${r.command}`;
  });
  const passed = results.filter((r) => r.pass).length;
  const gate = exit === 0 ? 'PASS' : exit === 1 ? 'FAIL' : 'NONE';
  lines.push(`GATE: ${gate} (${passed} of ${results.length} passed)   exit ${exit}`);
  return lines.join('\n');
}

function main() {
  const opts = parseArgs(process.argv);
  const cwd = process.cwd();
  const checks = resolveChecks(opts, cwd);

  if (opts.list) {
    if (!checks.length) {
      process.stderr.write('[continuous] no checks resolved (no --cmd, no detectable test/lint)\n');
      process.exit(2);
    }
    process.stdout.write('resolved checks:\n');
    for (const c of checks) process.stdout.write(`  ${c.name.padEnd(10)} ${c.command}\n`);
    process.exit(0);
  }

  if (!checks.length) {
    process.stderr.write('[continuous] nothing to run: no --cmd and no detectable test/lint checks\n');
    process.exit(2);
  }

  const results = [];
  for (const c of checks) {
    process.stderr.write(`\n▶ ${c.name} — ${c.command}\n`);
    results.push(runCheck(c, cwd, opts.timeoutMs));
  }

  const exit = gateCode(results);
  const artifact = {
    ts: new Date().toISOString(),
    cwd,
    checks: results, // name/command/pass/durationMs only — never output
    gate: exit === 0 ? 'pass' : exit === 1 ? 'fail' : 'none',
    exit,
  };

  const dir = stateDir(cwd, path.join('eval', 'continuous'));
  const stamp = artifact.ts.replace(/[:.]/g, '-');
  const outPath = path.join(dir, `${stamp}.json`);
  const blob = JSON.stringify(artifact, null, 2) + '\n';
  try {
    fs.writeFileSync(outPath, blob);
    fs.writeFileSync(path.join(dir, 'latest.json'), blob);
  } catch (e) {
    process.stderr.write(`[continuous] could not write ${outPath}: ${e.message}\n`);
  }

  process.stdout.write('\n' + report(results, exit) + '\n');
  process.stdout.write(`result: ${outPath}\n`);
  process.exit(exit);
}

main();
