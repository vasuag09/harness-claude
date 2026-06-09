#!/usr/bin/env node
// PostToolUse(Edit|Write|MultiEdit): count edits per session and suggest a manual
// /compact at logical intervals (~every 50 edits) to keep context healthy.
// Non-blocking. State lives in a per-session counter in the temp dir.
'use strict';
const { readInput, os, path, fs } = require('./_lib.js');

const INTERVAL = 50;
const input = readInput();
const session = input.session_id || 'default';
const counterFile = path.join(os.tmpdir(), `harness-compact-${session}.count`);

let n = 0;
try { n = parseInt(fs.readFileSync(counterFile, 'utf8'), 10) || 0; } catch {}
n += 1;
try { fs.writeFileSync(counterFile, String(n)); } catch {}

if (n % INTERVAL === 0) {
  process.stderr.write(
    `[harness] ${n} edits this session — good moment to /save-session then /compact ` +
    `at this phase boundary to keep context lean (disable auto-compact for control).\n`
  );
}
process.exit(0);
