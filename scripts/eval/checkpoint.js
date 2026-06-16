#!/usr/bin/env node
// checkpoint.js — read a spec's acceptance criteria and gate the work against them.
// Each AC bullet may carry an inline ```eval fenced shell command; the runner executes
// it and records PASS (exit 0) / FAIL (exit ≠0). ACs without a fence are MANUAL —
// the deterministic script never auto-passes prose; the /eval skill adjudicates those.
//
// Secret-safety (hard invariant): a check's output is NEVER printed. On FAIL the report
// shows only the exit code + the command (author text already committed in the spec), so
// you re-run it yourself to see output. This mirrors the v0.3 trace hook's capture-nothing
// rule and removes any chance of a secret in check output reaching stdout/logs/CI.
//
// TRUST BOUNDARY: ```eval fences are shell-executed (via _lib.sh → execSync) with your
// privileges. They are author-authored, committed markdown — same trust as the repo's own
// test scripts / build hooks. Review specs from untrusted branches before running /eval.
//
// Usage:
//   node scripts/eval/checkpoint.js [spec.md]            # run checks, print gate
//   node scripts/eval/checkpoint.js --list [spec.md]     # parse only: AC id + CHECK/MANUAL
//   With no file, the latest docs/specs/*.md is used.
//
// Exit contract (mirrors trace-report.js): 0 = all PASS & no MANUAL · 1 = any FAIL ·
// 2 = no FAIL but unresolved (MANUAL remaining / no ACs / missing file).
'use strict';
const { sh, fileExists, path, fs } = require('../hooks/_lib.js');

const CHECK_TIMEOUT_MS = 60000;

function parseArgs(argv) {
  const args = argv.slice(2);
  const list = args.includes('--list');
  const file = args.find((a) => !a.startsWith('--'));
  return { list, file };
}

// Latest docs/specs/*.md under cwd (mirrors trace-report's latestTrace).
function latestSpec() {
  const dir = path.join(process.cwd(), 'docs', 'specs');
  let names = [];
  try { names = fs.readdirSync(dir).filter((n) => n.endsWith('.md')); } catch { return ''; }
  if (!names.length) return '';
  names.sort();
  return path.join(dir, names[names.length - 1]);
}

// Parse AC bullets + their optional inline ```eval fence.
// Grammar (pinned to the existing spec format):
//   - [ ] **AC-<id> (<label>):** prose...
//   [continuation lines, optionally containing] ```eval\n<cmd>\n```
// Rules a spec author can rely on:
//   - The label runs up to the LAST ")" before ":**", so it may contain nested parens.
//   - The eval fence closes only on a bare ``` line; it must be the last code block in
//     the bullet's span. An unclosed fence (EOF / next bullet first) → the AC is MANUAL.
//   - A bullet's span runs until the next AC bullet or a heading line.
//   - Only one eval fence per AC is honored; a later one overrides an earlier one.
const AC_RE = /^\s*-\s+\[([ xX])\]\s+\*\*(AC-[^\s(]+)\s*\((.*)\)\s*:\*\*/;

function parseSpec(text) {
  const lines = text.split('\n');
  const acs = [];
  let cur = null;
  let fence = null; // { buf: [] } while inside a ```eval block

  const close = () => {
    if (cur) acs.push(cur);
    cur = null;
    fence = null;
  };

  for (const line of lines) {
    const m = line.match(AC_RE);
    if (m) {
      close();
      cur = { id: m[2], label: m[3].trim(), checked: m[1].toLowerCase() === 'x', check: null };
      continue;
    }
    if (cur && fence) {
      if (/^\s*```\s*$/.test(line)) {
        cur.check = fence.buf.join('\n').trim();
        fence = null;
      } else {
        fence.buf.push(line);
      }
      continue;
    }
    if (cur && /^\s*```eval\s*$/.test(line)) { fence = { buf: [] }; continue; }
    // A heading ends the current bullet's span.
    if (cur && /^#{1,6}\s/.test(line)) close();
  }
  close();
  return acs;
}

function runChecks(acs) {
  return acs.map((ac) => {
    if (!ac.check) return { ...ac, status: 'MANUAL' };
    const r = sh(ac.check, { cwd: process.cwd(), timeout: CHECK_TIMEOUT_MS });
    // Secret-safety: the check's output (r.out) is intentionally discarded — never
    // surfaced. On FAIL we keep only the exit code; the command is re-runnable by hand.
    return r.code === 0
      ? { ...ac, status: 'PASS' }
      : { ...ac, status: 'FAIL', code: r.code };
  });
}

function report(results) {
  const lines = [];
  for (const r of results) {
    lines.push(`  ${r.id.padEnd(8)} ${r.status.padEnd(6)} ${r.label}`);
    if (r.status === 'FAIL') {
      // Show the command (committed author text, not a secret) + exit code so the
      // user can re-run it. Output is deliberately not captured/printed.
      lines.push(`    exit ${r.code} — re-run: ${r.check}`);
    }
  }
  const n = (s) => results.filter((r) => r.status === s).length;
  lines.push(
    `\ncheckpoint: ${results.length} criteria — ` +
    `PASS=${n('PASS')} FAIL=${n('FAIL')} MANUAL=${n('MANUAL')}`
  );
  return lines.join('\n');
}

// 0 = all PASS & none MANUAL · 1 = any FAIL · 2 = unresolved (MANUAL / none).
function gateCode(results) {
  if (results.some((r) => r.status === 'FAIL')) return 1;
  if (results.some((r) => r.status === 'MANUAL') || results.length === 0) return 2;
  return 0;
}

function main() {
  const { list, file } = parseArgs(process.argv);
  const target = file || latestSpec();
  if (!target || !fileExists(target)) {
    process.stderr.write('[checkpoint] no spec file found\n');
    process.exit(2);
  }
  let text = '';
  try { text = fs.readFileSync(target, 'utf8'); } catch {
    process.stderr.write(`[checkpoint] cannot read ${target}\n`);
    process.exit(2);
  }
  const acs = parseSpec(text);

  if (list) {
    for (const ac of acs) {
      process.stdout.write(`${ac.id}\t${ac.check ? 'CHECK' : 'MANUAL'}\t${ac.label}\n`);
    }
    if (!acs.length) process.stderr.write('[checkpoint] no acceptance criteria found\n');
    process.exit(0);
  }

  const results = runChecks(acs);
  process.stdout.write(report(results) + '\n');
  if (results.some((r) => r.status === 'MANUAL')) {
    process.stderr.write('[checkpoint] MANUAL criteria need adjudication (run /eval to close).\n');
  }
  process.exit(gateCode(results));
}

main();
