#!/usr/bin/env node
// PostToolUse(Edit|Write|MultiEdit): warn when a frontend edit drifts toward
// generic, template-looking UI. Heuristic and non-blocking — a design nudge.
'use strict';
const { readInput, editedFile, fileExists, fs } = require('./_lib.js');

const input = readInput();
const file = editedFile(input);
if (!file || !fileExists(file)) process.exit(0);
if (!/\.(tsx|jsx|vue|svelte|html|css|scss)$/.test(file)) process.exit(0);

let c = '';
try { c = fs.readFileSync(file, 'utf8'); } catch { process.exit(0); }

const flags = [];

// Common "AI template" tells.
if (/from-(purple|violet|indigo)-\d00\s+(via-\S+\s+)?to-(pink|blue|purple)-\d00/.test(c)
    || /bg-gradient-to-\w+\s+from-(purple|indigo|violet)/.test(c)) {
  flags.push('generic purple/indigo gradient — pick an intentional palette (see design rules).');
}
if (/\brounded-(lg|xl|2xl)\b[\s\S]*\bshadow-(md|lg|xl)\b/.test(c) && /\bp-(4|6|8)\b/.test(c)
    && /\bgrid-cols-3\b/.test(c)) {
  flags.push('uniform card grid (rounded + shadow + even padding + 3-col) — add hierarchy/rhythm, avoid template-by-numbers.');
}
if (/min-h-screen[\s\S]*flex[\s\S]*items-center[\s\S]*justify-center[\s\S]*text-center/.test(c)) {
  flags.push('stock centered-hero pattern — give it a real point of view (typography, layering, motion).');
}

if (flags.length) {
  process.stderr.write(`[harness] design check on ${file}:\n- ${flags.join('\n- ')}\n`);
}
process.exit(0);
