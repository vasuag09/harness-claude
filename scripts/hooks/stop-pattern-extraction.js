#!/usr/bin/env node
// Stop: lightweight continuous-learning SEED. After a substantial session, drop a
// candidate note into .claude/skills-staging/ suggesting a reusable skill might be
// worth extracting. It NEVER writes a skill automatically — extraction stays a
// human-approved step (the full mechanism is a roadmap phase-2 item).
'use strict';
const { readInput, cwdOf, stateDir, fileExists, path, fs } = require('./_lib.js');

const input = readInput();
const cwd = cwdOf(input);

// Estimate session activity from the transcript size (cheap, deterministic).
let toolCalls = 0;
try {
  const tp = input.transcript_path;
  if (tp && fileExists(tp)) {
    const txt = fs.readFileSync(tp, 'utf8');
    toolCalls = (txt.match(/"type"\s*:\s*"tool_use"/g) || []).length;
  }
} catch {}

// Only nudge for clearly substantial sessions to avoid noise.
if (toolCalls < 40) process.exit(0);

const dir = stateDir(cwd, 'skills-staging');
const stamp = new Date().toISOString();
const note = [
  ``,
  `## Candidate pattern — ${stamp}`,
  `- This session ran ~${toolCalls} tool calls. If part of it was a repeatable workflow`,
  `  or a non-obvious fix, consider extracting it into a reusable skill.`,
  `- Review here, then create the skill manually (continuous-learning automation is a`,
  `  planned roadmap phase). Nothing was written to your skills automatically.`,
  ``,
].join('\n');

try { fs.appendFileSync(path.join(dir, 'candidates.md'), note); } catch {}
process.exit(0);
