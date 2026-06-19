# Hooks — What Runs on Your Machine

Transparency matters for a tool you let run commands automatically. This page lists
**every** hook the plugin ships, what it does, what it needs, and how to turn it off.

## TL;DR

- Hooks activate **only while the plugin is enabled** in `/plugin`. Toggle it off → they stop.
- They are **not** written into your `~/.claude/settings.json`. They load from the plugin
  definition; removing the plugin removes them. Your personal config is never modified.
- Every hook is a **Node.js** script under `scripts/hooks/`, invoked via
  `${CLAUDE_PLUGIN_ROOT}` so paths work on any machine/username.
- Hooks are **non-blocking nudges and gates** — they print guidance; they do not fail your
  tool calls or modify code without going through the normal edit flow.
- The only hard dependency is **Node.js**. Hooks that call project tools (prettier, tsc,
  eslint, ruff) **skip silently** if those tools aren't installed.

You can read every script yourself in [`scripts/hooks/`](../scripts/hooks/) — they're short
and dependency-free.

---

## Every hook

| ID | Event | Trigger | What it does | Needs |
|----|-------|---------|--------------|-------|
| `pre:tool:trace` | PreToolUse | every tool call | Logs which skills/subagents/MCP tools fire to `.claude/traces/<date>.jsonl` (only `{ts, tool_name, kind, subagent_type?}` — never args/secrets) | — |
| `pre:bash:tmux-reminder` | PreToolUse | `Bash` | Reminds you to run long commands (npm/cargo/pytest/docker) inside tmux | — |
| `pre:search:mgrep-nudge` | PreToolUse | `Grep`, `Bash` | Nudges you toward `mgrep` instead of `grep`/`rg` | — |
| `pre:search:cbm-orient` | PreToolUse | `Grep` | Augments a Grep with structural orientation hits (symbol → file) from a local code-structure index | `codebase-memory-mcp` installed + repo indexed (else **silently skips**); see note below |
| `post:edit:prettier` | PostToolUse | `Edit` | Auto-formats edited JS/TS files | Prettier in project (else skips) |
| `post:edit:tsc` | PostToolUse | `Edit` | Runs `tsc --noEmit` after `.ts/.tsx` edits | TypeScript in project (else skips) |
| `post:edit:quality-gate` | PostToolUse | `Edit`/`Write`/`MultiEdit` | Fast checks: lint, stray-debug scan, lightweight secret scan | eslint/ruff optional |
| `post:edit:design-quality` | PostToolUse | `Edit`/`Write`/`MultiEdit` | Warns when frontend edits drift toward generic template UI | — |
| `post:edit:strategic-compact` | PostToolUse | `Edit`/`Write`/`MultiEdit` | Suggests `/compact` at logical intervals (~every 50 edits) | — |
| `post:bash:build-analysis` | PostToolUse | `Bash` | Background, non-blocking analysis after build commands | — |
| `session-start:load-context` | SessionStart | session start | Surfaces the previous-session pointer; detects package manager | — |
| `session-start:lazy-activate` | SessionStart | session start | Activates `/lazy` generation-reduction — injects the "build the minimum that works" ladder as `additionalContext` (reversible: `LAZY_DISABLE=1` / `LAZY_MODE=off`); see note below | — |
| `pre-compact:save-state` | PreCompact | before compaction | Saves a state snapshot so context isn't lost | — |
| `stop:session-summary` | Stop | session end (tree changed) | Persists a session-end snapshot | git |
| `stop:pattern-extraction` | Stop | session end (substantial) | Reads the day's run-trace; stages a candidate note when a tool/skill sequence recurred (run `/extract` to act on it) | trace present |

---

## Structural orientation (`pre:search:cbm-orient`) — honest framing

This hook augments a `Grep` with a few **structural hits** (symbol name → file path) from a local
code-structure index built by [`codebase-memory-mcp`](https://github.com/DeusData/codebase-memory-mcp)
(MIT). The intent: on a large codebase, handing the agent the right files up front can save grep/read
turns. It is injected as `additionalContext`, never blocks, and is capped to a few hits.

**What we actually measured (be honest with yourself):**
- On **small repos**, our own benchmark showed **no net win** — bare grep already finds everything in
  a few turns, so the hint adds a little input cost for no turn saving. It does **no harm** (the cost is
  tiny and the index adds **no** persistent context tax), but it doesn't help either.
- The hypothesized benefit is on **large repos** where orientation is genuinely turn-expensive. That
  large-repo win is **not yet measured here** — it rests on the tool's design + structural reasoning,
  not on our own numbers. Treat it as a bet, not a proven gain.
- We use the **CLI path only** (`<bin> cli …` as a subprocess). We do **not** run its MCP server, so it
  makes no network call and injects no vendor "star" plug. No global config is mutated.

**Requirements / cost:** the hook **silently does nothing** unless the `codebase-memory-mcp` binary is
present (the harness keeps it under gitignored `.claude/codebase-memory-install/`) **and** the repo has
been indexed. With no binary it costs `$0` and zero latency. Install + index are reversible (`rm -rf`).

**Turn it off** without touching `hooks.json`: set `CBM_DISABLE=1` in the environment. Or remove its
block from `hooks.json` (id `pre:search:cbm-orient`), or point `CBM_BIN` at a specific binary.

## Generation reduction (`session-start:lazy-activate`) — honest framing

This hook injects the `/lazy` ruleset (`skills/lazy/SKILL.md`) as SessionStart `additionalContext` so
the **lazy senior dev** reflex is active by default: before writing code, take the first rung that holds
(does it need to exist → stdlib → native platform feature → installed dependency → one line → minimum
code). It's the output-side cost lever — the harness already carries YAGNI/KISS in `rules/engineering.md`;
this hook makes the laddered, persistent framing *salient* every response. Derived from
[ponytail](https://github.com/DietrichGebert/ponytail) (MIT), reframed native — no external dependency.

**What we actually measured (be honest with yourself):**
- On an **over-build-prone** task (k=3, Opus/Sonnet), the lazy block produced **−35% generated output
  tokens** and **−23% LOC** at **held accuracy** vs the harness's *own* YAGNI rules (not vs a bare agent).
  Both cohorts passed the correctness + safety fences 3/3 — `/lazy` cut bulk, not a corner.
- The **dollar** win was only **−3%** on that small task and within n=3 noise: cost is dominated by cached
  input, so a big generation cut barely moves dollars *there*. The robust signal is mechanism-level
  (output/LOC/turns down, every trial); the dollar win **scales with how output-heavy the task is**.
- It is **model-dependent** — gated on Opus 4.8 / Sonnet (the harness defaults). A terse reasoning model
  can regress (thinking tokens deliberating the ladder). Not measured on Haiku here.
- The **accuracy floor is non-negotiable**: input validation at trust boundaries, data-loss-preventing
  error handling, security, accessibility, and one runnable check behind non-trivial logic are never
  simplified away. Laziness governs *quantity*, never *correctness*.

**Cost:** the injected block is ~250 tokens per session and runs no subprocess/network — it just reads a
local text block (or a built-in fallback) and emits it. No persistent context tax.

**Turn it off / tune it** without touching `hooks.json`: `LAZY_DISABLE=1` (off entirely) or `LAZY_MODE=off`;
`LAZY_MODE=lite|full|ultra` selects intensity (default `full`). Or remove its block from `hooks.json`
(id `session-start:lazy-activate`). The `/lazy` skill switches intensity mid-session; "stop lazy" reverts.

## Performance note

`post:edit:tsc` runs a **project-wide** `tsc --noEmit` on every `.ts/.tsx` edit. On large
codebases this can make the edit loop feel sluggish. If so, disable just that hook (below).

---

## Disabling a hook

Hooks are defined in [`hooks/hooks.json`](../hooks/hooks.json). To disable one, remove its
block (match by `id`). Example — drop the slow tsc hook:

```jsonc
// delete this object from hooks.json → PostToolUse
{
  "matcher": "Edit",
  "hooks": [
    { "type": "command", "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/post-edit-tsc.js\"" }
  ],
  "description": "Run tsc --noEmit after editing .ts/.tsx files",
  "id": "post:edit:tsc"
}
```

To disable **all** hooks at once, just toggle the plugin off in `/plugin`.

---

## What hooks write to disk

Only the memory/session hooks write files, and only inside your project (or `~/.claude`
when outside a repo):

- `.claude/sessions/<date>.md` — session snapshots (`save-session`, Stop, PreCompact)
- `.claude/skills-staging/` — staged candidate patterns + `/extract` proposals (a draft
  `SKILL.md` + `eval.md` per `<slug>/`). Never auto-applied; promotion into `skills/` is
  always your explicit decision. Candidate notes carry only tool/skill names (from the
  trace), never session content.
- `.claude/traces/<date>.jsonl` — run-trace: one minimal line per tool call
  (`{ts, tool_name, kind, subagent_type?}`). No tool arguments, commands, or content are
  recorded, so secrets can't leak. Audit a run with
  `node scripts/eval/trace-report.js` (summary) or
  `node scripts/eval/trace-report.js --assert-namespace` (verify subagents are host-isolated).

All three paths are in `.gitignore` so they don't pollute your repo. No hook sends data off
your machine.
