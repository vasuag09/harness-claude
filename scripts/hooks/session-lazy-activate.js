#!/usr/bin/env node
// SessionStart: activate /lazy (generation reduction) — Phase 3 · Layer 3, always-on.
//
// Injects the /lazy ruleset as SessionStart `additionalContext` so the lazy ladder is active every
// session by default. This is the form that was MEASURED in P1 (the benchmark injected the same block
// via --append-system-prompt and produced output −35% / LOC −23% at held accuracy) — passive rules in
// engineering.md are lower-salience, so the hook is the load-bearing mechanism, not a footnote.
//
// HONEST FRAMING (docs/specs/phase-3-layer3-generation-reduction.md, docs/HOOKS.md): −35% generated
// output at held accuracy on an over-build-prone task; the DOLLAR win scales with how output-heavy the
// task is (only ~−3% on a small task whose cost is cached-input-dominated). Accuracy floor held (the
// safety carve-outs in the block are non-negotiable).
//
// REVERSIBLE: LAZY_DISABLE=1 → no-op; LAZY_MODE=off → no-op; LAZY_MODE=lite|full|ultra selects intensity
// (default full). FAILURE-ISOLATED: any error / missing arm file → exit 0 with no output (never blocks
// or slows session start). Reads the injectable block from benchmarks/arms/lazy-inject.txt (the same
// file the benchmark used), with a compact built-in fallback so it works even outside this repo.
'use strict';
const { readInput, cwdOf, fileExists, path, fs } = require('./_lib.js');

const FALLBACK =
  'LAZY MODE ACTIVE — generation reduction. Build the minimum that actually works; lazy means ' +
  'efficient, not careless. Before code, stop at the FIRST rung that holds: (1) does this need to ' +
  'exist? YAGNI → skip, say so in one line; (2) stdlib does it? use it; (3) native platform feature? ' +
  'use it; (4) already-installed dependency? use it, never add one for what a few lines do; (5) one ' +
  'line? one line; (6) only then the minimum that works. Shortest working diff wins; boring over ' +
  'clever. Code first, then ≤3 lines (what was skipped, when to add it). NEVER simplify away input ' +
  'validation at trust boundaries, error handling that prevents data loss, security, accessibility, ' +
  'or anything the user asked to keep — non-trivial logic leaves ONE runnable check behind. Switch: ' +
  '/lazy lite|full|ultra. Off: "stop lazy" / set LAZY_MODE=off.';

function emit(text) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext: text },
  }));
  process.exit(0);
}

try {
  if (process.env.LAZY_DISABLE === '1') process.exit(0);
  const mode = (process.env.LAZY_MODE || 'full').trim().toLowerCase();
  if (mode === 'off') process.exit(0);

  const input = readInput();
  const cwd = cwdOf(input);

  // Read the injectable block the benchmark used; fall back to the compact built-in if absent.
  let block = FALLBACK;
  const armPath = path.join(cwd, 'benchmarks', 'arms', 'lazy-inject.txt');
  if (fileExists(armPath)) {
    try {
      const t = fs.readFileSync(armPath, 'utf8').trim();
      if (t) block = t;
    } catch { /* keep fallback */ }
  }

  const header = mode === 'full'
    ? block
    : `LAZY MODE — level: ${mode}.\n\n${block}`;
  emit(header);
} catch {
  // Never surface a failure to session start.
}
process.exit(0);
