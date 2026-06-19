# Phase 3 · Layer 1 — Observation / Tool-Output Compression

**Status:** 🔴 KILLED (evidence-based, 2026-06-17) — Headroom proxy compression nets a dollar LOSS
in BOTH modes on the probe corpus (token: cache-break → 3×; cache: 0% compression → 1.2×). See §8c
for the verdict; §7 (Phase 1 install/discovery) and §8/§8b (Phase 2 pilots) for the evidence.
**Owner:** Vasu · ships nothing · apparatus retained as the reproducible record.
> KILL RETRACTED. The findings in §4 kill only the **build-it-as-a-hook** path; they do NOT kill
> Layer 1. **Reuse-first (rules/workflow.md) points at Headroom** (`chopratejas/headroom`, 30k★,
> Apache-2.0) — a proxy/MCP/library compression layer that solves the injection point hooks lack
> (it intercepts the wire / serves an MCP tool, not a PostToolUse payload). Layer 1 is reframed
> from "build a compressor" to "**evaluate + integrate Headroom, benchmark-gated on dollars at held
> pass^k**." Open decision: which integration mode to evaluate first (proxy/`wrap` vs MCP).
**Builds on:** [Phase 3 Research](./phase-3-research.md) (decision: 2 benchmark-gated layers;
this is Layer 1) and the existing `post-edit-strategic-compact` hook + `_lib.js` hook lib.
**Gated by:** the v0.8 benchmark apparatus (`bench-suite.js` / `probe-claude.sh`) — **killed if
it doesn't net positive on "cost down at held pass^k vs bare baseline."**

---

## 1. Problem

Tool results — file reads, bash/test output, grep dumps, MCP payloads, diffs — are the largest
**recurring** consumer of the context window. Unlike orientation (a one-time cost), an observation
is **re-sent every subsequent turn** until the conversation compacts (the "re-send multiplier").
A single 400-line failing-test log or a verbose JSON dump rides along in context for the rest of
the session, inflating both token cost and **context rot** (signal buried in stale noise).

The harness has no mechanism to curate observations at the point they enter context. The research
(`phase-3-research.md`) identifies this as Layer 1: the biggest recurring pool, the simplest to
attack (a hook + a reversible store, **not** an index), and the **lowest quality risk** — because
compression here is *reversible* (the agent can retrieve the original on demand) and *reduces
context rot*, so quality can go **up**, not down.

**Honest cost framing (load-bearing):** much re-sent history is **cached** (~10% price), so the
dollar win is **modest** and concentrated in **uncached big outputs compressed at capture**. We do
**not** claim a large cost cut. The headline is **quality / context-rot reduction at neutral-or-
better cost**, with cost-per-success at held pass^k as the kill-gate. Same discipline that stashed
v0.8: over-claiming gets the project debunked.

## 2. In scope / Out of scope

**In scope**
- A **PostToolUse compression hook** that, for tool outputs exceeding a size threshold, replaces
  the in-context payload with a **compact, lossless-where-it-matters summary** + a stable handle.
  Strategy is tool-type aware: failures-only for test/lint, dedup/minify for JSON, head/tail +
  elision marker for logs.
- A **reversible local store**: the full original is written to `.claude/observations/<id>` so the
  agent can recover it. A documented **`retrieve` affordance** (skill or convention) returns the
  original by handle on demand.
- **Stale-result hygiene**: superseded observations (re-read of the same file, re-run of the same
  command) are marked stale so compaction/curation can drop them first.
- **Offline, dependency-free tests** for every compressor (canned inputs → asserted compact form
  → asserted exact round-trip via the store). Zero model cost. Mirrors the existing eval-test style.
- **Benchmark gate**: a run on the probe corpus showing cost-per-success at **held pass^k** vs the
  bare baseline, recorded honestly (including no-change/regression).

**Out of scope**
- Layer 2 (CodeGraph structural orientation) — separate, later, conditional spec.
- Output/reasoning-side cost levers (model routing, fewer turns) — deferred per research.
- Any embedding/vector index, or a retriever the agent calls *instead of* grep (Cao suppression).
- Auto-generated context files injected without a human gate (ETH noise).
- Compressing Edit/Write tool results (those are already small / structured) — focus is read/exec
  observations.

## 3. Acceptance criteria

- [ ] **AC-L1 (capture + threshold):** a PostToolUse hook fires on read/exec-class tools (Read,
  Bash, Grep, MCP dumps) and acts **only** when output exceeds a configurable size threshold;
  small outputs pass through byte-identical (no behavior change on the common case).
- [ ] **AC-L2 (tool-aware compaction):** at least three compressors exist and are unit-tested —
  (a) test/lint → failures + summary line only; (b) structured/JSON → deduped/minified;
  (c) generic log → head/tail with an explicit elision marker stating how many lines/bytes were
  cut. Each states the original size and the handle.
- [ ] **AC-L3 (reversible store + retrieve):** every compressed observation writes its full
  original to a content-addressed path under `.claude/observations/`; a documented `retrieve`
  affordance returns the **byte-exact** original by handle. Round-trip proven by test.
- [ ] **AC-L4 (secret-safety):** the store and any summary carry **only** tool output already
  destined for context — the hook copies nothing from `tool_input` (args/commands), consistent
  with `pre-tool-trace.js`. No new secret-exposure surface; store lives under gitignored `.claude/`.
- [ ] **AC-L5 (stale hygiene):** re-reading a file or re-running a command marks the prior
  observation stale; staleness is queryable so curation drops stale-first. Unit-tested.
- [ ] **AC-L6 (failure isolation):** the hook never blocks, slows, or corrupts a tool call — on any
  internal error it falls back to passing the original output through unchanged (defensive like the
  rest of `scripts/hooks/`). Tested with a forced-error input.
- [ ] **AC-L7 (benchmark gate, honest):** a probe-corpus run reports cost-per-success and pass^k
  ON vs OFF. **Ship only if** pass^k is held (no quality regression) **and** cost is neutral-or-
  better. A null/negative result is recorded in the spec and the layer is **killed**, not shipped.
- [ ] **AC-L8 (docs):** `docs/HOOKS.md` documents the new hook + the `retrieve` affordance; the
  honest cost framing (cached-history caveat) is stated, not buried.

## 4. Reuse decision / research findings

**★ Feasibility (Q1) — RESOLVED, 2026-06-17, authoritative (context7 `/anthropics/claude-code`
hook-development SKILL):** a **PostToolUse hook CANNOT rewrite the tool result that enters
context.** The hook schema is asymmetric:
- **PreToolUse** exposes `hookSpecificOutput.updatedInput` → it can modify a tool's **input**
  before execution.
- **PostToolUse** has **no `updatedOutput`/`updatedResult` analogue.** Its only outputs are
  `additionalContext` (appends to context), `permissionDecision: "deny"` / `decision: block`,
  `systemMessage`, `suppressOutput` (hides stdout from the **user transcript view only**, not from
  the model's context), and exit codes (exit 2 → stderr fed back to Claude).

**Consequence:** the spec's core premise — "compress big outputs **at capture**" — is **not
buildable as a PostToolUse hook.** The full tool output still enters the context window and costs
its tokens that turn. Per the user's Q1 contingency decision, **the Plan phase is PAUSED for
re-plan** rather than auto-pivoting.

**What IS still feasible (for the re-plan, not yet specced):**
- **Stale-history hygiene** maps onto Anthropic's **context-editing / tool-result-clearing API**
  (server-side removal of old tool results after N turns) — attacks the *re-send multiplier*, the
  bigger recurring pool. Real and reusable; does NOT require hook payload rewrite.
- **Append-a-pointer**: PostToolUse `additionalContext` can note "large output stored at handle X;
  retrieve on demand" while the full output still costs tokens this turn — navigation aid, **not**
  capture-time savings.
- **Tool-wrapper interception** (agent calls a compressing wrapper) — but this risks **Cao
  suppression** (a retriever called instead of native tools can degrade results); high caution.
- **PreToolUse `updatedInput`** can shape *inputs* (e.g. inject `head`/`tail`/`--quiet` into a
  Bash command) — narrow, command-only, not general output compression.

Headroom (Apache-2.0) CCR/SmartCrusher remain reusable for the *store/minify* mechanics IF a
viable injection point exists — but the injection point, not the compressor, is the blocker.

**★★ Second finding (2026-06-17, authoritative — `/anthropics/claude-code` CHANGELOG): the
platform ALREADY ships the valuable half.**
- **Native large-output persistence:** Claude Code persists tool results **>50K characters to
  disk** (down from 100K), saved as files Claude can reference — "preventing them from consuming
  precious context tokens." This **is** the reversible store + retrieve half of Layer 1, already
  built into the runtime. A harness reimplementation would **duplicate a native feature.**
- **Context-editing / tool-result-clearing is NOT plugin-reachable.** It is a raw **Messages API**
  parameter (`context_management`); a Claude Code plugin (hooks/skills/agents/settings) does not
  control the API call. Claude Code manages context itself (auto-compact / microcompact / native
  persistence). No plugin lever for it was found.

**Net feasibility of Layer 1 from a Claude Code plugin:**
| Sub-feature | Status |
|---|---|
| Compress big output at capture (hook rewrites payload) | ❌ impossible (no PostToolUse output rewrite) |
| Reversible store + retrieve for big outputs | ✅ **already native (>50K → disk)** — redundant to rebuild |
| Stale-history clearing via context-editing API | ❌ not plugin-reachable (raw API param) |
| Medium outputs (~5K–50K) that DO accumulate | only lever = PreToolUse `updatedInput` command-shaping (head/tail/--quiet on Bash) — narrow, exec-only |

**★★★ Third finding — MEASURED (2026-06-17, `scripts/eval/measure-observation-pool.js` over 21
real project transcripts, 1004 tool outputs, 2172 assistant turns, OFFLINE/free):**

| Band | Re-send-weighted (token-turns) | Note |
|---|---|---|
| `<5K` | 50.7% | below any useful compression threshold |
| `5K–50K` | **49.3%** | the targetable pool — large, NOT negligible |
| `>=50K` | **0.0%** | native disk-persist threshold **never fires** in normal harness work |

5K–50K band by tool kind: **Read 76.2% · subagent 14.6% · Bash 8.2% · WebFetch 1.0%.**

**Corrects an earlier claim:** native >50K persistence harvests **nothing** here (no output hit
50K). So the kill reason is NOT "already harvested." The real reason:
- The targetable pool is genuinely **large (~49% of re-sent token-turns)** — Layer 1 aimed true.
- **But only ~8% of it (Bash) is reachable** by the one available plugin lever (PreToolUse
  `updatedInput`), and that lever changes output semantics. → **plugin-reachable ceiling ≈ 4% of
  the total re-sent pool.** The 76% Read majority cannot be rewritten by any hook.
- That ~4% is also **mostly cache-discounted (~10% price)** → dollar-negligible.

**VERDICT — REUSE, don't build (kill retracted).** The "plugin has no lever" conclusion is true
**only for hand-building it as a hook.** Reuse-first changes the answer:

**★★★★ Fourth finding — Headroom (`chopratejas/headroom`, 30k★, Apache-2.0, `pip install
headroom-ai`).** "Compress tool outputs, logs, files, RAG chunks **before they reach the LLM** —
same answers, fraction of the tokens." It provides the injection point hooks lack, via FOUR modes:
- **Proxy / `headroom wrap claude`** — automatic, wire-level; intercepts ALL traffic incl. re-sent
  tool results (max coverage; reaches the 76% Read pool a hook can't). **Risk: auth-in-path** —
  unconfirmed whether it works with Claude *subscription* OAuth or forces an API key (the v0.8
  `--bare` wall). Also the mode most able to break/help KV cache (it ships CacheAligner for this).
- **MCP server** (`headroom_compress`/`_retrieve`/`_stats`) — agent-invoked; no auth interception
  (safer). **Risk: Cao suppression** (agent must call it instead of native tools) + doesn't touch
  automatic re-sends.
- Library / SDK middleware — not applicable (harness doesn't own the API call).

Reversible via **CCR** (originals retrievable on demand) — matches AC-L3 for free. CodeCompressor
(AST) + SmartCrusher (JSON) + Kompress-base cover AC-L2 compressors. **Even attacks output tokens**
(verbosity steering + effort routing) — the expensive uncached pool, a bonus beyond Layer 1's scope.

**Honest caveats that still bind (do NOT relax the gate):**
- Headroom's headline "60–95%" is **token** compression, mostly **input-side**. In Claude Code that
  pool is **cache-discounted (~10% $)**, and compression mutates the prefix → **can break cache
  hits** and *raise* cost. The defensible **dollar** number is the research doc's **~15–30%**, and
  only on uncached/orientation-heavy work. **We measure dollars, not tokens.**
- Heavy external Python dependency in the critical path vs the harness's 0-dep ethos — justifiable
  ONLY if it nets positive on the benchmark.

**★★★★★ Auth-pilot — PASSED (2026-06-17, ~$1.65, dependency-free Node passthrough proxy → no
Headroom install needed to settle the make-or-break risk):**
- Ran `ANTHROPIC_BASE_URL=http://127.0.0.1:8799 claude -p … --output-format json` through a tiny
  passthrough proxy to `api.anthropic.com`. Proxy log:
  `POST /v1/messages?beta=true auth=oauth-bearer bodyBytes=437400 → upstream 200`.
- ✅ **`ANTHROPIC_BASE_URL` is honored on Claude *subscription* auth** (dead-port control hung,
  confirming it isn't ignored).
- ✅ **Subscription OAuth bearer forwards through a proxy and Anthropic accepts it (200).** The
  v0.8 `--bare`/API-key wall does **NOT** recur here. **Proxy mode is viable on subscription.**
- 📌 Intercepted payload = **437 KB for a one-word reply** — the proxy sees the entire context incl.
  the 76% Read re-send pool a hook can't reach (reach advantage demonstrated). It also explains the
  $1.64 cost: this repo's CLAUDE.md+rules system prompt is large and uncached on first turn.

**NEXT (reframed plan, same kill-gate as v0.8):** benchmark `headroom wrap claude` (proxy mode,
now auth-cleared) vs bare on the probe corpus — **cost-per-success at held pass^k**. Watch the two
remaining honest risks: (1) **cache interaction** — compressing the cached system-prompt prefix may
*break* KV-cache hits and raise cost (Headroom's CacheAligner claims to mitigate; verify on the
artifact); (2) **dollars ≠ tokens** — report $ not token %. Adopt only if it nets positive dollars
at held quality. Apparatus (`bench-suite.js`/`probe-claude.sh`) already exists; add a Headroom
on/off toggle alongside the existing `--safe-mode` axis. Layer 2 (CodeGraph) remains the *other*
candidate; Headroom's `wrap claude --code-graph` flag suggests they may compose.

## 5. Open questions (LOAD-BEARING — resolve before `/plan`)

1. **★ Feasibility — can the hook actually compress *at capture*?** ❌ **RESOLVED: NO.** PostToolUse
   hooks cannot rewrite the tool result that enters context (see §4). The "compress at capture via
   hook" framing is dead. **Plan phase PAUSED for re-plan per user decision** — see §4 for the
   feasible alternatives to weigh.
2. **Trigger:** size threshold only, or also tool-type allow-list? What default threshold (bytes vs
   lines)? Should it be configurable via settings/env?
3. **Store shape:** content-addressed by hash, or sequential id? Location (`.claude/observations/`
   confirmed?), TTL / cleanup policy, and the exact `retrieve` interface (a skill `/retrieve <id>`,
   a convention the agent reads, or an MCP resource?).
4. **Acceptance gate detail:** "same answers" = held pass^k on the probe corpus **plus** a
   retrieve-fallback path that never loses information. Is held pass^k sufficient, or do we also
   require a manual spot-check that no compressor dropped load-bearing content?
5. **Capture-time vs stale-history split:** ✅ **RESOLVED — full Layer 1.** Both wins are in this
   slice: compress new big outputs at capture **and** clear stale results from existing history
   (AC-L5). The benchmark measures the complete mechanism at once.

**Contingency for Q1 (user decision):** if `/research` finds hooks **cannot** rewrite the tool
result before it enters context, **STOP the Plan phase and re-plan with the user** — do not
auto-pivot. (User call, 2026-06-17.)

## 6. Risks

- **Feasibility (★):** if hooks can't rewrite payloads, scope changes materially — see Q1.
- **Quality regression:** an over-aggressive compressor that elides load-bearing output → caught by
  AC-L7 pass^k gate + retrieve fallback; ship-gated, not assumed.
- **Marginal dollar win vs added complexity:** cached history means small $ upside — the benchmark
  gate (AC-L7) is the honest decider; we kill on null result.
- **Cao suppression analogue:** if `retrieve` is clumsy the agent may avoid it and lose info — the
  affordance must be cheap and obvious (AC-L3, AC-L8).

## 7. Phase 1 — install + CLI discovery (DONE, 2026-06-17, $0/offline-of-model)

Implement-phase, Phase 1 of the approved 4-phase reuse plan. Deliverables (all uncommitted, git
boundary): `scripts/eval/headroom-setup.sh` (+ `test-headroom-setup.sh`, 14 offline tests green),
`.gitignore` += `.claude/headroom-venv/`.

**GATE: PASS** — `headroom-setup.sh --check` → `GATE PASS: … headroom wrap --help exits 0`.

**Install reality:**
- `headroom-ai` is real (PyPI, repo `chopratejas/headroom` = 30,457★, Apache-2.0). Installed
  version **0.26.0** into isolated `.claude/headroom-venv/` (gitignored, imported by nothing in
  hooks/skills — eval-only).
- **★ Constraint:** every `headroom-ai` release **requires Python ≥3.10**; this box's default
  `python3` is 3.9.23 → bare `pip install` fails. `headroom-setup.sh` auto-probes for the newest
  ≥3.10 interpreter (selected `python3.12`); override via `HEADROOM_PYTHON`.
- **★ Constraint (found in P2 boot, fixed):** the base `headroom-ai` wheel ships the CLI but **NOT
  the proxy stack** — starting `headroom proxy` dies with `No module named 'fastapi'`. The proxy is
  the injection point, so the install **must use the `[proxy]` extra**: `pip install
  headroom-ai[proxy]`. `headroom-setup.sh` now installs that extra, and `--check` verifies
  `import fastapi` (not just `wrap --help`) so a CLI-looks-fine / proxy-broken state is caught at
  setup, not at spend time.

**Open questions resolved (the plan's 5):**
1. **wrap pass-through syntax — RESOLVED.** `headroom wrap claude [CLAUDE_ARGS]...`: "All unknown
   flags are passed through to claude." Use `--` to force ambiguous flags (docs example
   `headroom wrap claude -- -p`). So the benchmark runner invokes
   `headroom wrap claude -- --safe-mode -p --output-format json --permission-mode … "$PROMPT"`.
2. **multi-word `CLAUDE_BIN="headroom wrap claude"` — addressed for P3:** the proxy is `wrap claude`,
   the claude args go after `--`. bench-headroom.sh will model the wrapper explicitly (array/`--`
   split), not a single `CLAUDE_BIN` string. Not a Phase-1 blocker.
3. **CacheAligner / cache-break control — RESOLVED (from `headroom proxy --help`).** There is no
   flag named "CacheAligner"; the lever is **`--mode [token|cache]`** (env `HEADROOM_MODE`):
   - **`--mode token` (DEFAULT):** "prioritize compression; **prior turns may be rewritten for max
     savings**" → **cache-breaking** — rewriting the cached prefix busts provider prefix-cache.
   - **`--mode cache`:** "**freeze prior turns to maximise provider prefix-cache hit rate**" →
     cache-preserving (the mitigation the research called CacheAligner).
   **Implication:** the DEFAULT mode is exactly the top honest risk (§6) — in Claude Code, where
   most re-sent input is cache-discounted (~10% $), token-mode rewriting can *raise* dollar cost
   even as tokens drop. **P3 must benchmark BOTH modes** (or at least report `cache_read` per mode),
   not assume the default wins on dollars.
4. **keep-path always-on vs opt-in — `/architect`, deferred by design to P4** (post-verdict).
5. **version pin — RESOLVED: 0.26.0.**

**★ New benchmark-design findings (from `headroom wrap claude --help`) — load-bearing for fairness:**
- **`--tool-search MODE` (default `true`)** — without it, a custom `ANTHROPIC_BASE_URL` makes Claude
  Code eagerly load **every** tool schema (issue #746), inflating context. **Keep default ON**, else
  the ON cohort is unfairly penalized — the proxy itself would inflate context independent of
  compression. First-class to control in P3.
- **`--no-mcp` warns "compression markers will be unactionable"** → the reversible **retrieve
  affordance (AC-L3) depends on the Headroom MCP server being registered** (default on). The proxy
  compresses; the MCP `retrieve` tool reverses it. Both halves needed for "same answers."
- **`--memory` / `--learn` / `--code-graph` are extra capabilities** beyond compression → must stay
  **OFF** in the A/B, or we measure capability, not compression (would invalidate the gate).
  (`--code-graph` is the Layer-2 compose point the research foresaw — out of scope for Layer 1.)
- Modes available: `headroom wrap claude` (proxy, auth-cleared in pilot), standalone `headroom
  proxy` (set `ANTHROPIC_BASE_URL` yourself), and `headroom mcp` (MCP server). Proxy `wrap` mode is
  the Phase-2/3 candidate.

**★★ Proxy-level findings (from `headroom proxy --help`) — reshape the P2/P3 design:**
- **`--intercept-tool-results` is OFF by default** ("Opt in to tool_result interceptors (ast-grep
  Read outliner, etc.). Off by default while this feature ships."). **This is the literal Layer 1
  mechanism** — compressing tool outputs (incl. the 76% Read pool). The proxy does NOT compress tool
  results unless this is enabled. **P2/P3 must turn it ON** to test Layer 1's actual hypothesis; note
  it's flagged experimental ("while this feature ships") — a stability risk to watch in the pilot.
- **Reversible retrieve (AC-L3) is FREE + default-on:** the CCR `headroom_retrieve` tool is injected
  by default (toggle off via `--no-ccr-inject-tool`), with retrieval markers (`--no-ccr-marker`) and
  proactive re-expansion (`--no-ccr-proactive-expansion`). Reversibility ships; we don't build it.
- **Stale hygiene (AC-L5) is FREE + default-on:** `--no-read-lifecycle` ("stale/superseded Read
  compression") implies Read-lifecycle management is ON by default — Headroom already does AC-L5.
- **AST code compression is opt-in + needs an extra dep:** `--code-aware` (default disabled) needs
  `pip install headroom-ai[code]` (tree-sitter). Decide in P3 whether code-aware Read compression is
  worth the extra dep on this code-heavy corpus.
- **Run-hygiene flags for clean isolated benchmarks:** `--no-telemetry` (don't phone home),
  `--budget <usd> --budget-period` (hard spend cap — a safety net for the ~$12 run), `--no-optimize`
  (passthrough control cohort). **Keep `--log-messages` OFF** (it logs request/response content —
  would violate the capture-nothing invariant); `--log-file` (JSONL: tokens_before/after, latency)
  is numeric-only and safe for measurement.

**Net:** Headroom covers AC-L2 (compressors), AC-L3 (retrieve), AC-L5 (stale) largely out-of-the-box;
Layer 1 reduces to **enabling `--intercept-tool-results` + choosing `--mode`** and proving the
dollar/quality gate (AC-L7). The build surface is small; the *measurement* is the work.

## 8. Phase 2 — 1-task pilot (DONE, 2026-06-17, ~$0.81 spent) — ★ CACHE-BREAK CONFIRMED

Ran `orient-1-isblank` (locate `_lib.js` among ~91 files, add `isBlank`) at k=1 through
`headroom proxy --intercept-tool-results --mode token` (ON) vs direct `--safe-mode` (OFF), isolated
worktrees, scored by checkpoint.js. Apparatus: `bench-headroom.sh` (runner), `headroom-pilot.sh`
(orchestrator), `headroom-verdict.js` (analyzer; all offline-tested, 27 + 16 assertions green).

**Plumbing: ALL FOUR CHECKS PASS.** Auth survives the proxy (ON billed, no did-not-run); quality
held (ON pass^1, fence passed); interception fired (`read_lifecycle:stale` compressed a stale
re-read of `_lib.js`, **−3138 input tokens, 12.5%**); `cache_read` visible per cohort.

**★ But the cost went the WRONG way — the #1 risk (§6) confirmed empirically:**
| tokens | ON (mode=token) | OFF (direct) |
|---|---|---|
| input | 2221 | 2440 |
| cacheRead | 232520 | 145304 |
| **cacheCreation** | **43611** | **7844** (5.6× less) |
| **cost/success** | **$0.606** | **$0.204** (3.0× cheaper) |

`--mode token` **rewrites prior turns to compress** → mutates the cached prefix → **invalidates the
KV-cache → 5.6× more cache *creation*** (the priciest token type, 1.25× input). It cut 12.5% of
input tokens and lost **3×** on cache re-creation. **On Claude Code's cache-dominated economics,
token-mode input compression is a net dollar LOSS** — exactly what the research predicted (dollars
are floored by output + cache, not input volume).

**Caveats on this single trial (don't over-read magnitude; mechanism is solid):**
- **n=1** — the 3× magnitude has variance, but the *mechanism* (5.6× cacheCreation from prefix
  mutation) is structural, not noise.
- **Degraded run:** `difft` + `scc` failed to download (SSL `CERTIFICATE_VERIFY_FAILED`); PyTorch
  absent → Kompress ML compression OFF. So only structural + `read_lifecycle` transforms ran;
  `--code-aware` was off (needs `[code]` extra). A fuller install might compress more — but more
  compression in token-mode means MORE prefix mutation → likely WORSE cache-break, not better.
- **Tool results were `router:excluded:tool`** — `--intercept-tool-results` did NOT transform tool
  outputs in this run (the 12.5% came from `read_lifecycle`, which is default-on regardless). The
  experimental tool-result interceptor showed no effect here.

**Bug fixed this phase:** the verdict analyzer keyed on non-existent `tokens_before/after` and
falsely reported "NO interception"; now keys on `tokens_saved` (regression-guarded).

### 8b. `--mode cache` pilot (DONE, ~$0.23) — completes the picture: BOTH modes lose

Same task, `headroom proxy --mode cache` (freeze prior turns → preserve KV-cache):
| tokens | ON (mode=cache) | OFF (direct) |
|---|---|---|
| input | 2219 | 2438 |
| cacheRead | 227133 | 122383 |
| **cacheCreation** | **6710** | 7827 (no break — ON ≤ OFF) |
| input saved by proxy | **0 (0.0%, no transforms)** | — |
| **cost/success** | **$0.231** | **$0.190** (1.2× cheaper) |

Cache-mode **removes the cache-break** (cacheCreation back to baseline) exactly as hypothesized —
but by freezing prior turns it compresses **nothing** (0 tokens saved), and is **still 1.2× more
expensive**. The residual loss is pure **proxy overhead**: it injects the CCR `headroom_retrieve`
tool + machinery into every request, inflating cached context (ON cacheRead 227k vs OFF 122k) — more
than the zero compression saves.

### 8c. VERDICT — Layer 1 (Headroom proxy compression) KILLED on the probe corpus

Two real pilots (~$0.81 + ~$0.23) settle it, with a structural mechanism, not assumption:
- **token mode:** saves 12.5% input but **breaks cache → 3.0× cost.**
- **cache mode:** no break but **0% compression → 1.2× cost** (proxy overhead).
Either way **ON > OFF on dollars** at held pass^k → fails the AC-L7 "neutral-or-better" gate → **kill,
don't ship.** This confirms the research's honest prediction: on Claude Code's cache-dominated
economics, a wire-level input-compression proxy cannot net positive dollars — compressing the cheap
(cached) 76%-Read pool breaks the cache that made it cheap; not compressing it leaves the proxy as
dead weight. **The $12 full benchmark is NOT run** — it would only confirm a measured structural loss
at higher n. (Contrast with the twice-wrong earlier kills, which were assumption; this one is two
measured A/Bs.)

**One unexplored lever, explicitly OUT OF SCOPE here (not a reason to keep spending now):**
turn-gated compression of stale-*beyond-cache* turns (`HEADROOM_STALE_READ_COMPRESS_AFTER_TURNS` /
`HEADROOM_COMPRESSION_STABLE_AFTER_TURN`) could compress only turns old enough to have already
fallen out of cache — savings without breaking the *active* prefix. But it only bites on **long
multi-turn sessions**, which this short-orientation probe corpus cannot exercise. Revisiting would
need a separate **long-session benchmark** (new corpus) — a future, conditional spec, not this one.

**Status: 🔴 KILLED (evidence-based).** Apparatus (`headroom-setup.sh`, `bench-headroom.sh`,
`headroom-pilot.sh`, `headroom-verdict.js` + offline tests) is retained as the reproducible record
and is reusable if a long-session corpus is ever built. All uncommitted (git boundary).
