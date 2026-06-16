#!/usr/bin/env node
// PreToolUse(match-all): run-trace. Appends ONE minimal JSONL line per tool call to
// .claude/traces/<date>.jsonl so a run can be audited for which skills, subagents, and
// MCP tools actually fired. Deliberately records only {ts, tool_name, kind,
// subagent_type?} — never tool_input args/commands/content, so no secrets leak.
// Best-effort and failure-isolated: it must never block or slow a tool call.
'use strict';
const { readInput, cwdOf, stateDir, appendFile, path } = require('./_lib.js');

// Classify a tool call. The reliable subagent signal is a `subagent_type` in the
// arguments — the spawn tool is named "Task" in stock Claude Code but "Agent" in some
// runtimes, so we match on the payload first and the name only as a fallback.
// mcp__*->mcp; ":" marks a plugin-namespaced skill; everything else is a builtin tool.
function classify(toolName, toolInput) {
  if (toolInput && typeof toolInput.subagent_type === 'string') return 'subagent';
  if (toolName === 'Task' || toolName === 'Agent') return 'subagent';
  if (toolName.startsWith('mcp__')) return 'mcp';
  if (toolName.includes(':')) return 'skill';
  return 'tool';
}

try {
  const input = readInput();
  const toolName = input.tool_name;
  if (!toolName || typeof toolName !== 'string') process.exit(0);

  const kind = classify(toolName, input.tool_input);
  const entry = { ts: new Date().toISOString(), tool_name: toolName, kind };

  // Only field copied out of tool_input — the emitted subagent_type — which is exactly
  // what proves the v0.2.0 namespace fix. Nothing else from tool_input is recorded.
  if (kind === 'subagent') {
    const st = input.tool_input && input.tool_input.subagent_type;
    if (typeof st === 'string') entry.subagent_type = st;
  }

  const dir = stateDir(cwdOf(input), 'traces');
  const file = path.join(dir, `${new Date().toISOString().slice(0, 10)}.jsonl`);
  appendFile(file, JSON.stringify(entry) + '\n');
} catch {
  // never surface a tracing failure to the tool call
}
process.exit(0);
