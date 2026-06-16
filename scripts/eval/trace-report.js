#!/usr/bin/env node
// trace-report.js — read a run-trace JSONL and (a) summarize what fired, or
// (b) --assert-namespace: verify every spawned subagent carried the "harness-claude:"
// prefix. (b) is the live proof of the v0.2.0 host-isolation fix (spec AC-2 / AC-6).
//
// Usage:
//   node scripts/eval/trace-report.js [file]                 # summary
//   node scripts/eval/trace-report.js --assert-namespace [file]
// With no file, the latest .claude/traces/*.jsonl is used.
'use strict';
const { stateDir, fileExists, path, fs } = require('../hooks/_lib.js');

const NS = 'harness-claude:';

function parseArgs(argv) {
  const args = argv.slice(2);
  const assert = args.includes('--assert-namespace');
  const file = args.find((a) => !a.startsWith('--'));
  return { assert, file };
}

function latestTrace() {
  const dir = stateDir(process.cwd(), 'traces');
  let names = [];
  try { names = fs.readdirSync(dir).filter((n) => n.endsWith('.jsonl')); } catch { return ''; }
  if (!names.length) return '';
  names.sort();
  return path.join(dir, names[names.length - 1]);
}

function readEntries(file) {
  const out = [];
  let raw = '';
  try { raw = fs.readFileSync(file, 'utf8'); } catch { return out; }
  for (const line of raw.split('\n')) {
    const t = line.trim();
    if (!t) continue;
    try { out.push(JSON.parse(t)); } catch { /* skip malformed */ }
  }
  return out;
}

function summarize(entries) {
  const byKind = {};
  const skills = new Set();
  const agents = new Set();
  const mcps = new Set();
  for (const e of entries) {
    byKind[e.kind] = (byKind[e.kind] || 0) + 1;
    if (e.kind === 'skill') skills.add(e.tool_name);
    else if (e.kind === 'subagent') agents.add(e.subagent_type || '(unknown)');
    else if (e.kind === 'mcp') mcps.add(e.tool_name);
  }
  const fmt = (s) => (s.size ? [...s].sort().join(', ') : '—');
  const lines = [
    `trace: ${entries.length} tool calls`,
    `  by kind: ${Object.entries(byKind).map(([k, n]) => `${k}=${n}`).join(' ') || '—'}`,
    `  skills (${skills.size}): ${fmt(skills)}`,
    `  subagents (${agents.size}): ${fmt(agents)}`,
    `  mcp (${mcps.size}): ${fmt(mcps)}`,
  ];
  return lines.join('\n');
}

function assertNamespace(entries) {
  const subs = entries.filter((e) => e.kind === 'subagent');
  const offenders = subs
    .map((e) => e.subagent_type)
    .filter((st) => typeof st === 'string' && !st.startsWith(NS));
  if (!subs.length) {
    process.stderr.write('[trace] no subagent spawns in trace — nothing to verify\n');
    return 2;
  }
  if (offenders.length) {
    process.stderr.write(
      `[trace] FAIL: ${offenders.length} subagent spawn(s) missing "${NS}" prefix: ` +
      `${[...new Set(offenders)].join(', ')}\n`
    );
    return 1;
  }
  process.stdout.write(`[trace] OK: all ${subs.length} subagent spawn(s) namespaced "${NS}"\n`);
  return 0;
}

function main() {
  const { assert, file } = parseArgs(process.argv);
  const target = file || latestTrace();
  if (!target || !fileExists(target)) {
    process.stderr.write('[trace] no trace file found\n');
    process.exit(assert ? 2 : 0);
  }
  const entries = readEntries(target);
  if (assert) process.exit(assertNamespace(entries));
  process.stdout.write(summarize(entries) + '\n');
  process.exit(0);
}

main();
