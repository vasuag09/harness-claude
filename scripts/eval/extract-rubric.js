#!/usr/bin/env node
// extract-rubric.js — evaluate a PROPOSED skill draft (a staged SKILL.md) against a
// lightweight, deterministic rubric and gate it. Part of the v0.5 extract-and-evaluate
// flow (AC-E4): the Stop hook detects a repeatable workflow, the /extract skill drafts a
// candidate skill, and THIS gates the draft before a human promotes it. It never writes
// or promotes anything — it only scores.
//
// Rubric (each criterion -> PASS / FAIL / MANUAL, mirroring checkpoint.js):
//   R1 frontmatter — draft has YAML frontmatter with `name` + `description`   (FAIL if not)
//   R2 steps       — draft has >=2 numbered procedure steps                   (FAIL if not)
//   R3 uniqueness  — draft `name` is not an exact dup of an existing skill    (FAIL if dup)
//   R4 reusable    — "is this genuinely a repeatable workflow worth a skill?" (always MANUAL)
//   R5 benchmark   — empirical value from a benchmark result artifact         (MANUAL if none)
//
// AC-E3 SEAM (AC-X5): benchmark(draft) is the documented insertion point for the AC-E3
// benchmark agent. It is now RESULT-DRIVEN (v0.6): it reads the artifact that
// `scripts/eval/benchmark.js` writes at `.claude/eval/benchmarks/<draft-slug>.json` and
// returns { pass } when present; absent/unparseable -> null, so R5 degrades to MANUAL and
// never blocks. The gate stays deterministic, fast, and offline — the heavy, model-cost-
// bearing k-trial run lives in the explicit `/benchmark` step, not in this gate.
//
// A valid draft therefore lands on exit 2 (R4/R5 MANUAL) by design: the deterministic gate
// can REJECT (FAIL) a draft but never AUTO-APPROVE one — promotion stays a human decision
// (prove-then-promote; preserves the v0.1 staging rule).
//
// Secret-safety: this runner executes NO shell and never runs the draft's body (an ```eval
// fence inside a draft is inert text here) — so there is no check output to leak. It reads
// the draft + existing skill names only.
//
// Usage:
//   node scripts/eval/extract-rubric.js [draft.md]          # score + gate
//   node scripts/eval/extract-rubric.js --list [draft.md]   # parse only: name/desc + criteria
//   With no file, the latest .claude/skills-staging/*/SKILL.md is used.
//
// Exit contract (mirrors checkpoint.js): 0 = all PASS & none MANUAL · 1 = any FAIL ·
// 2 = no FAIL but unresolved (MANUAL remaining / missing / unparseable).
'use strict';
const { stateDir, fileExists, path, fs } = require('../hooks/_lib.js');

function parseArgs(argv) {
  const args = argv.slice(2);
  const list = args.includes('--list');
  const file = args.find((a) => !a.startsWith('--'));
  return { list, file };
}

// Latest staged proposal draft, mirroring checkpoint.latestSpec / trace.latestTrace.
// Symlink-safe: an entry whose real path escapes the staging dir (e.g. a planted symlink
// to /etc/...) is skipped, so a hostile .claude/skills-staging/ can't redirect the read.
function latestDraft() {
  const dir = stateDir(process.cwd(), 'skills-staging');
  let dirReal = '';
  try { dirReal = fs.realpathSync(dir); } catch { return ''; }
  let drafts = [];
  try {
    for (const name of fs.readdirSync(dir)) {
      const p = path.join(dir, name, 'SKILL.md');
      if (!fileExists(p)) continue;
      let real = '';
      try { real = fs.realpathSync(p); } catch { continue; }
      if (!real.startsWith(dirReal + path.sep)) continue; // no symlink escape
      drafts.push(p);
    }
  } catch { return ''; }
  if (!drafts.length) return '';
  drafts.sort();
  return drafts[drafts.length - 1];
}

// Pull a single `key: value` out of a frontmatter block; strip surrounding quotes.
function fmValue(fmBlock, key) {
  const m = fmBlock.match(new RegExp(`^${key}\\s*:\\s*(.+)$`, 'm'));
  if (!m) return '';
  return m[1].trim().replace(/^['"]|['"]$/g, '').trim();
}

// Parse a SKILL.md draft into { name, description, steps }.
function parseDraft(text) {
  const fm = text.match(/^---\s*\n([\s\S]*?)\n---/);
  const block = fm ? fm[1] : '';
  const name = fmValue(block, 'name');
  const description = fmValue(block, 'description');
  const steps = (text.match(/^\s*\d+\.\s+\S/gm) || []).length;
  return { hasFrontmatter: Boolean(fm), name, description, steps };
}

function normalizeName(s) {
  return String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '');
}

// Existing live skill names (skills/*/SKILL.md) — the dedupe target. Staging is excluded.
function existingSkillNames() {
  const dir = path.join(process.cwd(), 'skills');
  const names = new Set();
  let entries = [];
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return names; }
  for (const e of entries) {
    if (!e.isDirectory()) continue;
    const p = path.join(dir, e.name, 'SKILL.md');
    if (!fileExists(p)) continue;
    let txt = '';
    try { txt = fs.readFileSync(p, 'utf8'); } catch { continue; }
    const fm = txt.match(/^---\s*\n([\s\S]*?)\n---/);
    const nm = fm ? fmValue(fm[1], 'name') : '';
    if (nm) names.add(normalizeName(nm));
  }
  return names;
}

// Filesystem-safe slug — MUST match benchmark.js slugify() so a benchmark run for component
// "<draft-name>" lands where this lookup expects it.
function benchSlug(s) {
  return String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

// AC-E3 SEAM — RESULT-DRIVEN (v0.6). Read the benchmark artifact for this draft, if one was
// produced by `/benchmark`. Returns { pass } when present & valid, else null ("not measured"
// -> R5 stays MANUAL). Symlink-safe: an artifact whose real path escapes the benchmarks dir
// is ignored, so a hostile .claude/eval/benchmarks/ can't redirect the read.
function benchmark(draft) {
  if (!draft || !draft.name) return null;
  const dir = stateDir(process.cwd(), path.join('eval', 'benchmarks'));
  let dirReal = '';
  try { dirReal = fs.realpathSync(dir); } catch { return null; }
  const p = path.join(dir, `${benchSlug(draft.name)}.json`);
  if (!fileExists(p)) return null;
  let real = '';
  try { real = fs.realpathSync(p); } catch { return null; }
  if (!real.startsWith(dirReal + path.sep)) return null; // no symlink escape
  try {
    const data = JSON.parse(fs.readFileSync(p, 'utf8'));
    return typeof data.pass === 'boolean' ? { pass: data.pass } : null;
  } catch { return null; }
}

function evaluate(draft) {
  const existing = existingSkillNames();
  const out = [];

  out.push(draft.hasFrontmatter && draft.name && draft.description
    ? { id: 'R1', status: 'PASS', label: 'frontmatter (name + description) present' }
    : { id: 'R1', status: 'FAIL', label: 'frontmatter (name + description) present' });

  out.push(draft.steps >= 2
    ? { id: 'R2', status: 'PASS', label: `numbered steps present (${draft.steps})` }
    : { id: 'R2', status: 'FAIL', label: 'numbered steps present (>=2)' });

  const dup = draft.name && existing.has(normalizeName(draft.name));
  out.push(dup
    ? { id: 'R3', status: 'FAIL', label: `name not a duplicate (collides: ${draft.name})` }
    : { id: 'R3', status: 'PASS', label: 'name not a duplicate of an existing skill' });

  out.push({ id: 'R4', status: 'MANUAL', label: 'genuinely a repeatable, reusable workflow' });

  const bench = benchmark(draft);
  out.push(bench == null
    ? { id: 'R5', status: 'MANUAL', label: 'empirical value (no benchmark artifact — run /benchmark)' }
    : { id: 'R5', status: bench.pass ? 'PASS' : 'FAIL', label: `empirical value (benchmark: ${bench.pass ? 'earns keep' : 'no gain'})` });

  return out;
}

function report(results) {
  const lines = results.map(
    (r) => `  ${r.id.padEnd(4)} ${r.status.padEnd(6)} ${r.label}`
  );
  const n = (s) => results.filter((r) => r.status === s).length;
  lines.push(
    `\nrubric: ${results.length} criteria — ` +
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
  const target = file || latestDraft();
  if (!target || !fileExists(target)) {
    process.stderr.write('[rubric] no draft SKILL.md found\n');
    process.exit(2);
  }
  let text = '';
  try { text = fs.readFileSync(target, 'utf8'); } catch {
    process.stderr.write(`[rubric] cannot read ${target}\n`);
    process.exit(2);
  }
  const draft = parseDraft(text);

  if (list) {
    process.stdout.write(`name: ${draft.name || '(none)'}\n`);
    process.stdout.write(`description: ${draft.description || '(none)'}\n`);
    for (const r of evaluate(draft)) {
      const kind = r.status === 'MANUAL' ? 'MANUAL' : 'CHECK';
      process.stdout.write(`${r.id}\t${kind}\t${r.label}\n`);
    }
    process.exit(0);
  }

  const results = evaluate(draft);
  process.stdout.write(report(results) + '\n');
  if (results.some((r) => r.status === 'MANUAL')) {
    process.stderr.write('[rubric] MANUAL criteria need adjudication (run /extract to close).\n');
  }
  process.exit(gateCode(results));
}

main();
