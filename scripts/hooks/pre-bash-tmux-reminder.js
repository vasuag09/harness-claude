#!/usr/bin/env node
// PreToolUse(Bash): nudge to run long-running commands inside tmux so they
// survive and stream. Non-blocking — just a reminder.
'use strict';
const { readInput, note } = require('./_lib.js');

const input = readInput();
const cmd = (input.tool_input && input.tool_input.command) || '';

const LONG = /\b(npm (run )?(test|build|dev|start)|pnpm (test|build|dev|start)|yarn (test|build|dev|start)|cargo (build|test|run)|pytest|vitest|jest|next (build|dev|start)|go test|docker (build|run|compose)|uvicorn|gunicorn)\b/;

// Already in tmux, or the command already invokes tmux → stay quiet.
if (process.env.TMUX || /\btmux\b/.test(cmd)) process.exit(0);

if (LONG.test(cmd)) {
  note('long-running command — consider running it inside tmux (e.g. `tmux new -s dev`) so it survives detach and streams logs.');
}
process.exit(0);
