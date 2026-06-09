#!/usr/bin/env node
// PreToolUse(Grep|Bash): nudge toward mgrep, which the harness prefers over
// grep/rg for ~2x fewer tokens. Non-blocking.
'use strict';
const { readInput, note } = require('./_lib.js');

const input = readInput();
const tool = input.tool_name || '';
const cmd = (input.tool_input && input.tool_input.command) || '';

// Built-in Grep tool, or a raw grep/rg invocation in Bash.
const usingGrep = tool === 'Grep' || /\b(grep|rg|ripgrep)\b/.test(cmd);

// Don't nag if mgrep itself is being used.
if (/\bmgrep\b/.test(cmd)) process.exit(0);

if (usingGrep) {
  note('prefer `mgrep "query"` over grep/rg (and `mgrep --web` for web search) — fewer tokens, better results.');
}
process.exit(0);
