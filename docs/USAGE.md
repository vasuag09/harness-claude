# Usage Guide

How to actually use harness-claude — from zero to a merge-ready feature. If you
just want the command list, jump to [The full flow](#the-full-flow).

---

## 1. Prerequisites

| Requirement | Why | Notes |
|-------------|-----|-------|
| **Claude Code** ≥ 2.x | Host for the plugin | `claude --version` |
| **Node.js** ≥ 18 | All runtime hooks are Node scripts | Without it, hooks error out (the rest of the harness still works) |
| **git** | Phase gates, `/ship`, session snapshots | Optional outside a repo, but most value is in one |
| `bash` + `jq` *(optional)* | Status line only | Status line degrades gracefully without `jq` |

Project-level tools (`prettier`, `eslint`, `tsc`, `ruff`, `pytest`) are **not** required —
the hooks that use them skip silently when they're absent. Install them in your project
to get the matching quality gates.

---

## 2. Install (isolated, reversible)

```bash
# Add this repo as a marketplace — straight from GitHub
claude plugin marketplace add vasuag09/harness-claude
#   …or, if you've cloned it locally:
claude plugin marketplace add /path/to/harness-claude
```

Then in Claude Code:

```
/plugin     # find "harness-claude", enable it
/plugin     # confirm skills + agents + hooks registered
/mcp        # (optional) enable only the MCP servers you need
```

Toggling the plugin off in `/plugin` returns you to your previous setup — nothing in your
`~/.claude` is overwritten. See [HOOKS.md](./HOOKS.md) for exactly what runs on your machine.

---

## 3. The four phases

```
PLAN ─────────────► IMPLEMENT ─────► VERIFY ─────────────► MAINTAIN
/spec  /research          /implement     /review  /security-review   /refactor-clean
/plan  /architect         /build-fix     /test    /verify  /ship      /onboard
                  memory: /save-session · /resume-session (cross-cutting)
```

Each phase has **exit criteria** (see the [README](../README.md) and `rules/workflow.md`).
You move forward only when the current phase is genuinely done. The `/harness-*`
orchestrators pause at each gate for your input — they are **not** unattended runs.

---

## 4. The full flow

### Fast path — one command per phase

```bash
/harness-plan       # spec → research(reuse-first) → plan → architect*
/harness-implement  # TDD implement → build-fix
/harness-verify     # review → security-review → test → verify → ship-prep
/harness-maintain   # onboard* → refactor-clean
```

Or the whole pipeline with a checkpoint between every phase:

```bash
/harness            # full Plan → Implement → Verify → Maintain
```

### Granular path — atomic skills (one step at a time)

```bash
# PLAN
/spec               # vague request → written spec + acceptance criteria
/research           # reuse-first: find existing code/libs that solve ≥80%
/plan               # phased, risk-assessed task list
/architect          # design note (non-trivial work only)

# IMPLEMENT
/implement          # TDD: tests first (RED) → minimal code (GREEN) → refactor
/build-fix          # resolve build / type / lint errors to green

# VERIFY
/review             # code review (quality, patterns)
/security-review    # OWASP + secret scan; blocks on Critical/High
/test               # raise coverage to the floor (≥80%)
/verify             # run the app, confirm it observably works
/ship               # sync docs + prepare a clean commit/PR (does NOT push)

# MAINTAIN
/refactor-clean     # remove dead code / duplication (behavior-preserving)
/onboard            # refresh the codebase map / docs

# MEMORY (any time)
/save-session       # snapshot context to a dated file
/resume-session     # reload the latest session
```

See [SKILLS.md](./SKILLS.md) for what each skill does and which agent it delegates to.

---

## 5. Common scenarios

### A. Brand-new product / feature from a one-line idea

```bash
/harness            # walks all four phases, pausing at each gate
```

### B. New product that reuses an existing codebase

The reuse-first order matters — map what exists *before* you plan:

```bash
/onboard <existing-repo>   # harness learns the existing structure & reusable pieces
/spec                      # define the new product/feature
/research                  # reuse-first: "does X already solve this?" → records the decision
/plan → /architect → /implement → /review → /security-review → /test → /verify → /ship
```

`/research` is the gate that stops you hand-rolling what already exists; it documents the
reuse/adopt/port decision in the spec so `/implement` builds on top of existing code.

### C. Single targeted change / bugfix

```bash
/spec               # what's the bug + acceptance criteria (the fix is "done when…")
/implement          # TDD the fix
/review  /test  /verify
```

### D. Continuing multi-session work

```bash
/resume-session     # at the start — reloads the latest snapshot
# …work…
/save-session       # before you stop or /compact
```

---

## 6. Tooling defaults the harness assumes

- **Search:** the rules nudge you toward `mgrep` over `grep`/`rg` (a hook reminds you). It's
  optional — install it via the companion script if you want the speed/token win.
- **Long-running commands:** run dev servers, watchers, builds, and `docker` inside **tmux**
  so they survive and stream (a hook reminds you).
- **Live docs:** the rules prefer **context7** for current library docs over memory.
- **Context hygiene:** keep <10 plugins/MCPs enabled; a hook suggests `/compact` at logical
  intervals (~every 50 edits).

These are *nudges*, not hard requirements — the harness works without any of them.

---

## 7. Installing the extras (companion plugins — optional)

The companions are **global** Claude Code plugins (mgrep, context7, frontend-design, …) that
can't ship inside an isolated plugin, so they're installed separately. Two ways:

### Option A — the script (easiest)

The installer is a shell script, so you need a **local clone** of this repo (a plugin-only
install via `claude plugin marketplace add` does **not** give you the `.sh` file):

```bash
git clone https://github.com/vasuag09/harness-claude.git
cd harness-claude
./install-companions.sh          # prints the plan, asks before changing anything
#   …or skip the prompt:
./install-companions.sh --yes
```

It adds two marketplaces (`anthropics/claude-plugins-official`, `mixedbread-ai/mgrep`) and
installs all the companions. Errors are shown (not swallowed) so any failure is visible.

### Option B — manual (no clone needed)

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add mixedbread-ai/mgrep

claude plugin install frontend-design@claude-plugins-official
claude plugin install code-review@claude-plugins-official
claude plugin install feature-dev@claude-plugins-official
claude plugin install security-guidance@claude-plugins-official
claude plugin install explanatory-output-style@claude-plugins-official
claude plugin install typescript-lsp@claude-plugins-official
claude plugin install pyright-lsp@claude-plugins-official
claude plugin install code-simplifier@claude-plugins-official
claude plugin install context7@claude-plugins-official
claude plugin install ralph-loop@claude-plugins-official
claude plugin install mgrep@Mixedbread-Grep
```

### Either way

```
/plugin     # enable the companions you want — keep <10 enabled to protect your context window
```

| Companion | Gives you |
|-----------|-----------|
| `mgrep` | Faster/cheaper search the rules nudge toward |
| `context7` | Live library documentation |
| `frontend-design` | UI/UX patterns |
| `code-review`, `feature-dev`, `security-guidance` | Workflow helpers |
| `typescript-lsp`, `pyright-lsp` | Language intelligence |
| `code-simplifier`, `ralph-loop`, `explanatory-output-style` | Simplification / loop automation / output style |

### Status line + output style

Separately, merge the keys from [`settings.snippet.json`](../settings.snippet.json) into your
`~/.claude/settings.json` (fix the `/path/to/harness-claude` path) to enable the status line
and explanatory output style. See the
[README](../README.md#status-line--output-style--permissions).

---

## 8. Troubleshooting

Hitting friction? See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for the common issues
(hooks not firing, slow `tsc`, MCP servers, git boundary surprises) and fixes.
