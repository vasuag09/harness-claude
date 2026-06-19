#!/usr/bin/env node
// PreToolUse(Grep): codebase-memory-mcp structural orientation (Phase 3 · Layer 2, always-on hook).
// When the agent runs a Grep, this augments it with structural hits from the pre-built code-structure
// index — names + file paths for symbols matching the query — injected as `additionalContext` so the
// agent can jump to the right files instead of spending extra grep/read turns.
//
// SAFETY (non-negotiable, even always-on):
//   * CLI-PATH ONLY — shells out to `<bin> cli search_graph` as a subprocess. It NEVER starts the MCP
//     server, so it makes NO api.github.com call and emits NO "leave a star" plug (those live only in
//     the MCP `initialize` path — confirmed clean at P0). No network, no global config mutation.
//   * FAILURE-ISOLATED — missing binary, un-indexed project, timeout, or ANY error → exit 0 with no
//     output. The hook must NEVER block or slow a real tool call (mirrors pre-tool-trace.js).
//   * BOUNDED — the cli query runs under a short timeout and the injected hint is capped to a few hits.
//   * REVERSIBLE — set CBM_DISABLE=1 to no-op without editing hooks.json; `rm -rf` the install to remove.
//
// HONEST FRAMING (see docs/specs/phase-3-layer2-codebase-memory.md): on small repos our own benchmark
// showed NO net win (bare grep is already turn-cheap); the hypothesized benefit is on LARGE repos where
// orientation is turn-expensive. This hook does no harm where it doesn't help (it only adds a small,
// bounded hint when the index has matching symbols), and it costs nothing when the binary isn't installed.
'use strict';
const { readInput, cwdOf, sh, fileExists, path, fs } = require('./_lib.js');

const MAX_HITS = 5;            // cap the injected hint (keep it tiny — the cache-parity advantage)
const CLI_TIMEOUT_MS = 2000;   // bounded; P0 showed cli answers in <1s

function emitContext(text) {
  // PreToolUse additionalContext (Claude Code CHANGELOG: feedback to the model within the same turn).
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'PreToolUse', additionalContext: text },
  }));
  process.exit(0);
}

try {
  if (process.env.CBM_DISABLE === '1') process.exit(0);          // reversible escape hatch

  const input = readInput();
  if ((input.tool_name || '') !== 'Grep') process.exit(0);
  const pattern = input.tool_input && input.tool_input.pattern;
  if (!pattern || typeof pattern !== 'string' || pattern.length > 200) process.exit(0);

  const cwd = cwdOf(input);
  // Resolve the indexed project = the git repo root (the slug the binary indexed under).
  const top = sh('git rev-parse --show-toplevel', { cwd, timeout: 1500 });
  if (!top.ok) process.exit(0);
  const root = top.out.trim();
  if (!root) process.exit(0);
  const project = root.replace(/^\//, '').replace(/\//g, '-');

  // Locate the binary: local eval prefix, env override, or PATH. Absent → silent no-op ($0, no install).
  const local = path.join(root, '.claude', 'codebase-memory-install', 'codebase-memory-mcp');
  const bin = process.env.CBM_BIN || (fileExists(local) ? local : null);
  if (!bin) process.exit(0);

  // Index must already be ready — a hook must not index synchronously (too slow). Not ready → no-op.
  const status = sh(`"${bin}" cli index_status '${JSON.stringify({ project }).replace(/'/g, "")}'`, { cwd: root, timeout: 1500 });
  if (!status.ok || !/"nodes"\s*:\s*[1-9]/.test(status.out)) process.exit(0);

  // Query the structure index by symbol-name regex = the grep pattern. Project to the useful fields.
  const args = JSON.stringify({ name_pattern: pattern, project }).replace(/'/g, '');
  const res = sh(`"${bin}" cli search_graph '${args}'`, { cwd: root, timeout: CLI_TIMEOUT_MS });
  if (!res.ok || !res.out.trim()) process.exit(0);

  let parsed;
  try { parsed = JSON.parse(res.out); } catch { process.exit(0); }
  const results = Array.isArray(parsed && parsed.results) ? parsed.results : [];
  if (!results.length) process.exit(0);

  const hits = results.slice(0, MAX_HITS).map((r) => {
    const sig = r.signature ? r.signature : '';
    return `- ${r.name}${sig}  ${r.file_path}`;
  });
  if (!hits.length) process.exit(0);

  emitContext(
    `Code-structure index hits for /${pattern}/ (from a local structural index; verify against the ` +
    `actual files before relying on these):\n${hits.join('\n')}`
  );
} catch {
  // Never surface a failure to the tool call.
}
process.exit(0);
