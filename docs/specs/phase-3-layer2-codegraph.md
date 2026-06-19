# Spec: Phase 3 · Layer 2 — CodeGraph Structural Orientation

**Status:** 🔴 KILLED (evidence-based, 2026-06-18) — two paid pilots show CodeGraph cannot net positive at this
repo's scale (24 files). multi-1 (graph used): **6.4× cost, no turn-reduction**; multi-2 (graph available):
**not invoked even when steered, ~$0.9/session MCP context tax alone > 5× the entire baseline task cost → 6×
cost.** The **$12 full benchmark is NOT run.** See §"P2 re-pilot result + VERDICT". P1 stays done (CodeGraph
installed + graph built, AC-G2 ✓; fairness via `--mcp-fairness`, AC-G4 ✓). Apparatus retained (codegraph-pilot
**55/0**), reusable if a large-repo corpus is ever built.
**Owner:** Vasu · killed at the P2 human gate; nothing committed (HEAD 1fcc383).
**Builds on:** [Phase 3 Research](./phase-3-research.md) (decision: 2 benchmark-gated layers; this is
Layer 2, conditional on Layer 1's outcome) and the v0.8 benchmark apparatus
(`scripts/eval/probe-claude.sh`, `bench-suite.js`, `benchmarks/probe/`).
**Context:** [Layer 1](./phase-3-layer1-observation-compression.md) is 🔴 KILLED — wire-level *input
compression* (Headroom proxy) nets a dollar LOSS on Claude Code's cache-dominated economics. Layer 2
attacks a **different lever — turn-reduction** (fewer tool calls → fewer expensive output/reasoning
cycles) — the one path that can bite cost where input compression structurally could not.
**Gated by:** the same kill-rule that stashed v0.8 and killed Layer 1 — **cost-per-success at held
pass^k vs the bare agentic-grep baseline.** Killed if it doesn't net positive (incl. the cost of
wrong hints).

---

## Problem

Orientation — finding the right files/symbols before editing — is a recurring exploration cost.
Bare agentic grep works but spends turns: each `Grep`/`Glob`/`Read` is an expensive output+reasoning
cycle. The research measured an **oracle ceiling of ~14% cost / ~26% tokens** on orientation-heavy
tasks when exact paths are handed in for free, with quality held (pass^3 in both cohorts). That
ceiling is the prize; the question is whether a **structural code graph** (tree-sitter → SQLite/FTS5,
**no embeddings**) can *predict* enough of that orientation to net positive **after** paying for its
own index complexity and the cost of imperfect/wrong hints.

The honest framing: real delivery is a **fraction** of the ~14% oracle ceiling, and a wrong hint can
*hurt* (Cao suppression). We do **not** claim the 49×/65× self-reported headlines. We measure
**dollars at held pass^k**, and we kill on a null/negative result.

## Reuse decision (research outcome — 2026-06-17)

**Adopt: [CodeGraph](https://github.com/colbymchenry/codegraph) (`@colbymchenry/codegraph`)** — evaluate
and integrate as-is; do **not** build a graph engine. Evidence (gh API + repo files, verified this session):

- **License / health:** MIT · TypeScript · 51.2k★ · v1.0 released · pushed 2026-06-17 (actively maintained).
- **No embeddings (AC-G2 ✓):** deps are `web-tree-sitter` + `tree-sitter-wasms` only — **no vector/embedding
  library** (no onnxruntime, faiss, sqlite-vec, or model client). Pure tree-sitter structural parsing.
  *Spec correction:* the index is a custom local `.codegraph/` store, **not** literally SQLite/FTS5 — the
  "no embeddings, deterministic, local" requirement stands; the storage engine detail was an assumption.
- **100% local & self-contained:** bundles its own Node runtime (no Node required on host); no network deps.
  *Minor flag:* repo has `TELEMETRY.md` + `telemetry-worker/` — confirm telemetry is opt-out before any
  keep-path adoption (irrelevant to the benchmark itself; note for AC-G7).
- **Drift handling (AC-G2 ✓):** auto-sync watcher updates the graph on every file change ("index is never
  stale, nothing to re-run") — deterministic, native file events. Matches research's drift requirement.
- **Vendor benchmark (matches our envelope):** 7 repos × 7 languages, median of 4, **re-validated on Opus
  4.8 (2026-06-02)**: avg **16% cheaper · 47% fewer tokens · 22% faster · 58% fewer tool calls**. Largest $
  win on *small* repos (Alamofire 40%, OkHttp 25%); **break-even** on response-heavy repos (Excalidraw,
  Tokio). This repo is ~91 files (small) → plausibly favorable, but our corpus tasks are short — measure it.

**Integration mode: MCP-retriever (native), NOT predictor-injection (AC-G1 ✓).** CodeGraph ships *only* as
an MCP server (`codegraph install` wires it into Claude Code; primary tool **`codegraph_explore`**). There
is no built-in path-predictor mode; building one would mean wrapping CodeGraph's output to inject paths —
net-new code, against reuse-first. So mode = MCP-retriever. **Dominant risk = Cao-suppression** (the agent
calls `codegraph_explore` instead of native grep; if the graph misses, answers degrade) — measured, not
assumed (AC-G5). Suppression is *soft*: CodeGraph does not remove native Grep/Read, so the agent can still
fall back; the gate is whether pass^k holds ON vs OFF.

**Fair-A/B harness mechanism (the load-bearing integration fact — AC-G4).** `--safe-mode` **disables MCP
servers** (verified: installed claude `2.1.181 --help` — safe-mode disables "CLAUDE.md, skills, plugins,
hooks, MCP servers, …"; auth/model/built-in-tools/permissions still work). So the Layer-1 trick of
`--safe-mode` for both cohorts **cannot** carry CodeGraph. Resolution:
- **OFF (bare grep):** `--safe-mode` (strips harness **and** all MCP → pure baseline).
- **ON (CodeGraph only):** load *just* CodeGraph via **`--strict-mcp-config --mcp-config <codegraph.json>`**
  (`--strict-mcp-config` = "only use MCP servers from `--mcp-config`, ignoring all others" → no MCP leak →
  fairness), while stripping the harness via `--setting-sources` (omit project/local) and/or `--safe-mode`.
- **The one P1 verification ($0, offline):** does `--safe-mode` **+** explicit `--mcp-config` re-admit that
  single server? If safe-mode hard-disables MCP even with explicit `--mcp-config`, fall back to
  `--strict-mcp-config` + `--setting-sources user` (no project/local) as the harness-strip for **both**
  cohorts. Either way the only ON↔OFF delta is CodeGraph — verify by listing tools before spending.
- Mirrors the v0.8 `--safe-mode` fairness baseline and reuses the probe apparatus
  (`probe-claude.sh`, `bench-suite.js`, `benchmarks/probe/`).

## In scope / Out of scope

**In scope**
- **Reuse-first evaluation + integration** of an existing MIT/permissive structural-graph tool
  (CodeGraph-class: tree-sitter → SQLite/FTS5 → MCP, no embeddings, deterministic drift handling).
  The exact tool and the **integration mode are resolved in `/research`** (see Open questions).
- A **benchmark gate** on an **expanded probe corpus**: the existing 4 single-target orientation
  tasks **plus** new **multi-hop tasks** (caller-tracing / impact-radius across files) where the
  turn-reduction lever can actually move — run ON (graph) vs OFF (bare grep), both `--safe-mode`.
- **Offline, dependency-free tests** for any harness-owned glue (corpus fixtures, runner toggle,
  verdict analyzer) — mirrors the existing eval-test style; zero model cost.
- Honest reporting of **cost-per-success, pass^k, and tool-call count** ON vs OFF, including
  no-change/regression, recorded in this spec.

**Out of scope**
- Embedding/vector indexes (abandoned paradigm — research §"Do NOT").
- Auto-generated context files injected without a human gate (ETH auto-gen noise).
- Output/reasoning-side cost levers beyond turn-reduction (model routing) — deferred per research.
- Layer 1 re-attempt (input compression) — KILLED, closed.
- Shipping the integration if the gate is null/negative — record the kill, don't ship.
- Building a graph engine from scratch — reuse only; if no suitable tool exists, that's a research-
  phase kill, not a build.

## Acceptance criteria

- [x] **AC-G1 (tool + mode resolved):** **CodeGraph** (`@colbymchenry/codegraph`, MIT) · mode =
  **MCP-retriever** (native `codegraph_explore`) · dominant risk = **Cao-suppression** (soft; measured at
  the gate). See §Reuse decision. ✓ resolved.
- [x] **AC-G2 (no embeddings, deterministic — BUILD-PROVEN at P1):** CodeGraph v1.0.1 installed
  local-prefix; `codegraph init` built `.codegraph/` over this repo = **24 files, 209 nodes, 368 edges,
  SQLite (`node:sqlite`, WAL), no embeddings**. Graph is queryable ($0): `query aggregateCost` →
  `benchmark.js:117` with signature. Drift = auto-sync watcher. CLI also exposes `explore` + `impact
  <symbol>` (the latter ideal for P3 multi-hop). ✓ done.
- [~] **AC-G3 (expanded corpus — 1/3 multi-hop built at P2; 2 more at P3):** `benchmarks/probe/
  multi-1-callers/` (back-compat `create` flag on `stateDir` after tracing its 9+ callers) is built;
  its eval fence **discriminates** — FAILs on current code, PASSes on a correct impl (verified, then
  reverted). P3 adds `multi-2-impact` (impact-radius) + `multi-3-crossfile`. 4 single-hop probe tasks retained.
- [x] **AC-G4 (fair A/B harness — built, offline-proven, R1 empirically resolved):** `bench-codegraph.sh`
  toggles ON (`--strict-mcp-config --mcp-config codegraph.json --setting-sources user --append-system-prompt`
  steer) vs OFF (`--safe-mode`); captures cost/usage + `tool_call_count`/`codegraph_explore_count`/
  `num_turns` via stream-json (capture-nothing), with did-not-run guard + toollog. Offline tests 19/19 +
  17/17. **`--mcp-fairness` probe ran (~$0.01):** cohort (c) returned the **bare built-in tool set** (no
  harness leak → strip OK) and registered ONLY the codegraph server → flags are correct, `--safe-mode`
  NOT needed for ON. ✓ Fairness controls verified.
- [~] **AC-G5 (Cao-suppression guard — measured, not assumed):** `codegraph-verdict.js` makes
  interception (`codegraph_explore_count`>0) a **hard validity gate** (zero → run INVALID, exit 1) and
  flags **Cao-suppression** when ON used the graph but pass^k dropped vs OFF. Native Grep/Read stay
  available (soft fallback). Empirically read at the P2 pilot + P3 run, not assumed. (Confirmed at P3 run.)
- [ ] **AC-G6 (benchmark gate, honest):** a real run reports cost-per-success, pass^k, and tool-call
  count ON vs OFF on the expanded corpus. **Ship only if** pass^k is held (no quality regression)
  **and** cost-per-success is neutral-or-better **including the cost of wrong hints**. A null/
  negative result is recorded here and the layer is **KILLED**, not shipped.
- [ ] **AC-G7 (docs on keep-path):** if kept, `docs/HOOKS.md` (or equivalent) documents the
  orientation aid as a **reversible opt-in**, with the honest dollar framing (fraction of the ~14%
  oracle ceiling, not the vendor headline). `/architect` decides always-on vs opt-in at this gate.

## Plan (4 phases — each a gate; planner agent, 2026-06-17)

Reuse-first: **extend** the probe apparatus, don't rewrite. `benchmark.js`/`bench-suite.js` are already
component-agnostic (`HARNESS_COMPONENT_ENABLED`, `prompt.txt`+`spec.md` corpus layout) → no change.
New files mirror the Layer-1 Headroom shapes (`*-setup.sh`, `*-pilot.sh`, `*-verdict.js`, `test-*.sh`).

**P1 — install + MCP-fairness verify + harness-strip resolve ($0).** Install CodeGraph (prefer local
`--prefix .claude/codegraph-install/` to mirror the headroom-venv isolation; idempotent), `codegraph init`
over this repo (= AC-G2 build proof), confirm telemetry opt-out (R5/AC-G7). **Resolve R1** via a $0
`--mcp-fairness` probe: run `claude -p "list your MCP tools" --output-format json` under (a) bare,
(b) `--safe-mode`, (c) `--strict-mcp-config --mcp-config codegraph.json` → emit which flags give exactly
the ON/OFF delta. NEW: `codegraph-setup.sh`, `codegraph.json`, `bench-codegraph.sh` (ON =
strict-mcp-config+CodeGraph+harness-strip; OFF = `--safe-mode`; sidecar adds `tool_call_count` +
`codegraph_explore_count`), `test-codegraph-setup.sh`, `test-codegraph-pilot.sh` (cohort-toggle section).
EXTEND `.gitignore` (+`.codegraph/`). **Gate:** `--check` exits 0; fairness verdict printed; offline tests green. *(AC-G2, AC-G4)*

**P2 — 1-task multi-hop pilot (~$1, HUMAN GATE).** NEW task `benchmarks/probe/multi-1-callers/`
(caller-trace across ~6–10 files: add a back-compat arg to a shared helper + update all call sites;
`eval` fences runnable via `checkpoint.js`). NEW: `codegraph-pilot.sh` (no proxy lifecycle — MCP is
wired), `codegraph-verdict.js` (interception / quality-held / cost-direction / **Cao-suppression signal**
= native-tool count ON vs OFF). **Gate:** `codegraph_explore_count`>0 (interception real); verdict
GO/NO-GO; **human checks cacheCreation ON vs OFF — if ON≫OFF that's the Layer-1 cache-break → KILL
before $12.** *(AC-G3 partial, AC-G4, AC-G5)*

**P3 — full benchmark (~$12–$20).** +2 multi-hop tasks (`multi-2-impact` impact-radius, `multi-3-crossfile`
cross-module) → 7 tasks (4 single-hop retained + 3 multi-hop), k=3, ON/OFF via `codegraph-bench-full.sh`
(wraps `bench-suite.js`). Report cost-per-success + pass^k + tool-call count. **KILL if
costPerSuccess(ON) ≥ OFF OR passK(ON) < OFF** (incl. cost of wrong hints); null = kill. *(AC-G3, AC-G5, AC-G6)*

**P4 — adopt-doc + /architect OR kill-record ($0).** Keep-path: `docs/HOOKS.md` reversible-opt-in section
(honest dollar framing = fraction of ~14% oracle ceiling; `codegraph uninstall`; telemetry opt-out), then
**`/architect`** decides always-on vs opt-in vs recommend-only. Kill-path: append §kill-record like Layer 1
§8c (verdict + per-task table), status → 🔴 KILLED. *(AC-G7)*

**Open Qs carried into Implement (none block P1):** (1) R1 flag resolution — first thing P1 does;
(2) does `claude -p --output-format json` expose per-tool `tool_uses`? if not, interception/Cao falls back
to pass^k-only (still the kill metric); (3) multi-hop task calibration — P2 pilot calibrates difficulty
before P3.

## P1 implementation findings (2026-06-17 — from CodeGraph's own repo/eval notes)

Resolved while building P1; these change the runner design and are load-bearing for a *fair* A/B:

- **MCP server command:** `codegraph serve --mcp --path <repo>` (stdio). This is what `codegraph.json`
  (`--mcp-config`) launches for the ON cohort. CLI subcommands: `install/init/uninit/index/sync/status/
  query/files/context/affected/serve --mcp`.
- **Telemetry opt-out (AC-G7/R5):** `export CODEGRAPH_TELEMETRY=0` (per-shell/CI) or `codegraph telemetry
  off`. The `--check` gate sets+verifies it; benchmark runs export it.
- **Spec re-correction:** CodeGraph **does** use SQLite/FTS5 (`stores symbols/edges/files in SQLite
  (FTS5)`, deterministic AST extraction). The earlier "custom store, not SQLite" note was wrong — the
  original spec assumption was right. Still **no embeddings** (AC-G2 holds).
- **⚠️ FAIRNESS RISK 1 — MCP startup latency (NEW, load-bearing):** CodeGraph attaches in ~2–3s; on a
  multi-step task the agent starts Read/grep *before* it connects — "runs with no codegraph" — and it's
  **worse when the eval runs nested inside a Claude session under CPU contention** (our exact setup). If
  unmitigated, the ON cohort silently degrades to OFF and we measure noise. **Mitigation (their fix):**
  pre-warm a persistent daemon (`serve --mcp --path <repo> </dev/null &`, wait for
  `.codegraph/daemon.sock`, high `CODEGRAPH_DAEMON_IDLE_TIMEOUT_MS`, `CODEGRAPH_WASM_RELAUNCHED=1` to skip
  the startup re-exec) so claude connects before turn 1. The pilot orchestrator (P2) owns daemon
  lifecycle; the runner connects to it.
- **⚠️ FAIRNESS RISK 2 — steering is low-salience (NEW):** CodeGraph's author found server-instructions +
  tool descriptions "never reproduced what a CLI `--append-system-prompt` achieved," and new tools are
  "rarely chosen." In our **stripped** benchmark (no project CLAUDE.md), the agent may **under-pick**
  `codegraph_explore`. So the ON cohort adds a light `--append-system-prompt` telling the agent the tool
  exists — fair, because *adopting CodeGraph includes its steering*; the alternative measures a tool the
  agent never calls. This is the inverse of Cao-suppression and equally a measured quantity (interception
  count must be >0, else the run is invalid not just negative).
- **Self-contained ON cohort (R6):** we do **not** run global `codegraph install` (it mutates the user's
  global Claude config). Install to a local prefix; the ON cohort points `--mcp-config` at the local
  binary via `codegraph.json`. Reversible by `rm -rf`.
- **R1 RESOLVED empirically (`--mcp-fairness`, ~$0.01):** ON =
  `--strict-mcp-config --mcp-config codegraph.json --setting-sources user` (+ steer) correctly loads ONLY
  CodeGraph and strips the harness (probe cohort (c) showed the bare built-in tool set, no harness/other
  MCP). OFF = `--safe-mode` (no MCP). `--safe-mode` is NOT needed for ON. **Fairness Risk 1 CONFIRMED LIVE:**
  the probe's single-turn call finished while codegraph was *"still connecting"* — its tools had not
  attached. ⇒ **P2's pilot MUST pre-warm a daemon** (and the pilot's interception check — `codegraph_explore_count`>0
  — is the hard gate that a run is valid, not just positive). Verdict logic in `codegraph-setup.sh` fixed to
  be token-precise (don't match the "still connecting" note as a present tool).

## P2 pilot result (2026-06-17 — multi-1-callers, k=1, ~$1.28 spend)

```
ON  (codegraph): pass^k=true cost/success=$1.1117  in=18283 out=2159 cacheRead=193618 cacheCreate=86952  (4 tool-calls, 1 codegraph_explore, 5 turns)
OFF (bare grep): pass^k=true cost/success=$0.1725  in=2436  out=1461 cacheRead=99360  cacheCreate=7337   (4 tool-calls, 5 turns)
```
- **Quality held** (both pass^k) · **interception real** (codegraph_explore called 1×) · auth fine.
- **Turn-reduction lever did NOT fire:** ON 4 tool-calls = OFF 4 tool-calls. The thesis (fewer turns)
  did not materialize on this task — bare grep was already efficient (4 calls) on a 24-file repo.
- **Cost: ON 6.4× WORSE** ($1.11 vs $0.17), driven by **cache-break 11.9×** (cacheCreate 86952 vs 7337)
  + **7.5× input inflation** (18283 vs 2436). This is CodeGraph's MCP context tax: tool schemas +
  server-instructions + a large `codegraph_explore` result form a big new cached prefix (~80k
  cache-creation tokens ≈ **$0.9/session fixed**), which CodeGraph itself documents as "a few large,
  cache-heavy tool responses."
- **Structural read:** the fixed MCP overhead (~$0.9/session) **exceeds the entire bare-grep task
  cost ($0.17)** on this small repo. To net positive, turn-reduction must save > $0.9 — but a 24-file
  repo has no task that costs bare grep that much in orientation. CodeGraph monetizes orientation on
  LARGE repos (its own data: wins on VS Code ~10k files; break-even on small) — harness-claude is far
  too small. **Same lesson as Layer 1: on cache-dominated economics, added context can't be recovered.**
- **Confounds (stated honestly):** n=1; the daemon pre-warm FAILED ("daemon exited during startup" —
  `serve --mcp </dev/null` EOFs in ~1-2s) yet the per-session MCP still attached (interception=1); the
  pilot task was light for bare grep (4 calls). The pre-warm bug does NOT affect the token-overhead
  cost driver (startup latency ≠ token volume), so it would not flip the verdict.

## P2 re-pilot apparatus (2026-06-17 — ruling out the two confounds, $0 offline)

User chose "one more rigorous re-pilot" over an immediate kill. Two confounds from the first pilot are
addressed before re-spending:
- **Daemon pre-warm FIXED:** the first run monitored the `serve --mcp` front-end PID, which exits on EOF
  (`</dev/null`), so it declared the (working, detached) daemon dead. `codegraph-pilot.sh` now polls for
  `.codegraph/daemon.sock` only, and tears the daemon down by `pkill -f <install path>` (the front-end is
  already gone). NB: this fixes attach latency, NOT the token-overhead cost driver.
- **Per-trial TIMEOUT added:** `bench-codegraph.sh` wraps the claude call in a `CG_TIMEOUT` (default 600s)
  watchdog (macOS has no `timeout`) so a nested-under-Claude hang can never silently burn budget again.
- **Turn-heavy task built:** `benchmarks/probe/multi-2-impact/` — rename `fileExists`→`pathExists` across
  **12 `scripts/` files / 35 occurrences** (impact-radius). Fence verifies the new export + a completeness
  walk (no `fileExists` identifier left under `scripts/`). Fence **discriminates** (FAIL on current, PASS
  on full rename — verified via node-fs discovery, then reverted). Honest caveat: a flat rename is somewhat
  grep-favorable (one grep lists all sites), so it tests whether CodeGraph's breadth can overcome its fixed
  MCP overhead. The structural math predicts it still loses (fixed ~$0.9/session tax; edits dominate and are
  cohort-identical), but it removes the "task too light" objection.
- All offline tests green: **full eval suite 257/0** (codegraph-pilot 44).

**⚠️ Incident during this work:** a temporary rename-validation step used `git checkout -- scripts/`, which
destroyed the uncommitted v0.8 changes to `benchmark.js` + `test-benchmark.sh`. Both were reconstructed from
session context and verified against the intact `test-bench-suite.sh` (257/0). Lesson recorded in memory
`git-checkout-uncommitted-hazard`.

**Next = the PAID re-pilot (~$1, HUMAN GATE), run in a PLAIN terminal (not nested under Claude):**
`bash scripts/eval/codegraph-pilot.sh benchmarks/probe/multi-2-impact`. If ON still ≫ OFF on cost with no
turn-reduction → clean KILL.

## P2 re-pilot result + VERDICT — Layer 2 (CodeGraph) KILLED (2026-06-18 — multi-2-impact, k=1)

**Apparatus bug found + fixed before the valid run (2026-06-18).** The first two re-pilot attempts returned
empty output for BOTH cohorts (rate 0.00, 0 tool-calls) — **NOT a CodeGraph result.** Root cause: a relative
`task-dir` arg left the prompt/spec paths relative, but `benchmark.js` runs the `--task` with cwd = a clean
**HEAD worktree** that lacks untracked `benchmarks/`, so `cat prompt.txt` yielded an empty prompt and
`claude --print` errored. The absolute-default `multi-1` path had masked it. Fixes (all tested, **codegraph-pilot
55/0**): (a) `codegraph-pilot.sh` absolutizes a relative task-dir; (b) `bench-codegraph.sh` startup fast-fail now
keys on a real `assistant`/`result` event (the `init` line flushes even when claude then blocks on a rate limit,
so first-byte was a false "started" signal) and records `did_not_start`; (c) `codegraph-verdict.js` surfaces
`did_not_start` as a distinct INVALID cause. The two empty runs cost ≈$0 (nothing executed).

```
ON  (codegraph): pass^k=true  cost/success=$1.0676  in=18422 out=4191 cacheRead=502814 cacheCreate=61934  (9 tool-calls, 0 codegraph_explore, 10 turns)
OFF (bare grep): pass^k=false cost/success=n/a      in=2436  out=1109 cacheRead=104116 cacheCreate=8502   (4 tool-calls, 5 turns; total $0.1777)
```

A SECOND, independent disqualifier — distinct from multi-1's mechanism:
- **INTERCEPTION = NO (codegraph_explore = 0).** With the daemon pre-warmed ("daemon ready") AND an explicit
  steering prompt ("prefer codegraph_explore over grep"), the agent **never called the graph** — it used 9
  native grep/read calls across 10 turns. So the run is **INVALID for crediting CodeGraph** (the verdict gate
  correctly refuses to read a no-graph pass as a CodeGraph win): ON's pass came from doing *more native* work
  (10 turns vs OFF's 5), not from structural retrieval.
- **But you paid the full MCP context tax anyway.** ON cacheCreate 61934 vs OFF 8502 (**7.3×**, +53k tokens) =
  CodeGraph's tool schema + server-instructions loaded into context (~$0.9/session fixed — the same tax as
  multi-1). That fixed cost **alone exceeds OFF's entire task cost ($0.18) by ~5×** → ON 6.0× more expensive
  ($1.07 vs $0.18) for **zero graph benefit**.
- **Adoption is the new finding:** even on an impact-radius rename — the exact query shape CodeGraph's `explore`
  is built for — the agent prefers native grep despite steering. CodeGraph's author documents MCP
  server-instructions as low-salience; one steering line did not overcome it here.

**Two pilots settle it, structurally (not by assumption):**
1. **multi-1 (graph WAS used):** 6.4× more expensive, turn-reduction never fired.
2. **multi-2 (graph available, agent's choice):** not used even when steered, and the context tax alone is 5× the
   baseline.
Even a *perfectly-used* CodeGraph that eliminated every native call would still cost ≥ the ~$0.9 context tax vs
OFF's $0.18. **A fixed per-session cost that exceeds the entire baseline task cost cannot net positive at this
repo's scale (24 files).** The **$12 full benchmark is NOT run** — it would only re-confirm a cost structure
fixed by the tax. Same core lesson as Layer 1: on Claude Code's cache-dominated economics, *added context cannot
be recovered* by the lever it was meant to power.

**Boundary condition (recorded, not pursued):** on a *much larger* repo where bare-grep orientation is genuinely
turn-expensive (CodeGraph's own data: wins on ~10k-file VS Code, break-even on small), the math could flip.
Re-evaluation would need a **large-repo corpus** — a future, conditional spec, not this one.

**Status: 🔴 KILLED (evidence-based).** Apparatus (`codegraph-setup.sh`, `bench-codegraph.sh`, `codegraph.json`,
`codegraph-pilot.sh`, `codegraph-verdict.js` + offline tests, **55/0**) is retained as the reproducible record and
is reusable if a large-repo corpus is ever built. CodeGraph install (`.claude/codegraph-install/`) + index
(`.codegraph/`) are gitignored. Nothing committed (git boundary; HEAD 1fcc383).

**Successor (2026-06-18):** Layer 2 is re-opened with a different tool **and a different integration path** that
structurally removes both killers above — **CLI-path orientation** (out-of-band, no MCP server → no fixed context
tax, no tool-adoption dependency). See [`phase-3-layer2-codebase-memory.md`](./phase-3-layer2-codebase-memory.md)
(🟡 candidate, pre-pilot). The CodeGraph kill stands; the lever (turn-reduction) is unchanged.

## Constraints

- **0-dep ethos:** any heavy dependency must be eval-scoped (like the killed Headroom venv), never
  imported by hooks/skills at runtime, and justified only by a positive benchmark.
- **Cost discipline:** the full run is gated behind a cheap pilot (1 multi-hop task, human gate)
  before the ~$12-class spend — same staging that caught Layer 1's loss before the full run.
- **Dollars, not tokens:** report cost-per-success; token deltas are secondary. Turn-count is the
  mechanism metric (the lever is fewer expensive cycles).
- **Git boundary:** no commits/branches unless the user explicitly asks.

## Open questions (with recommended defaults)

1. **Integration mode — RESOLVED (research):** **MCP-retriever** — CodeGraph ships MCP-only, so
   predictor-injection would be net-new wrapper code (rejected, reuse-first). Cao-suppression is the
   accepted, *measured* risk (soft fallback to native grep remains). See §Reuse decision.
2. **Reuse target — RESOLVED (research):** **CodeGraph** (`@colbymchenry/codegraph`, MIT, tree-sitter,
   no embeddings, local, MCP). The `code-review-graph` MCP from `~/CLAUDE.md` is **not connected this
   session** and was superseded by the user's explicit pick of CodeGraph. `aider` repo-map not pursued
   (no MCP surface, weaker drift handling).
   **NEW open Q for P1 (harness mechanism):** does `--safe-mode` + explicit `--mcp-config` re-admit one
   server, or must we use `--strict-mcp-config` + `--setting-sources user` to strip the harness while
   keeping only CodeGraph? Verify offline ($0) before any spend. See §Reuse decision.
3. **Predictor source (if predictor-injection):** does the graph predict paths from the query alone,
   or seed from run-traces (`/extract` primitive) for trace-learned hints? *Default:* start
   query-only; trace-seeding is a later enhancement, not v1.
4. **Multi-hop task count:** 3 minimum (AC-G3); expand to 5–6 if the first run is noisy. *Default:* 3,
   then grow only if the verdict is ambiguous.

## Exit criterion

Met: acceptance criteria are concrete and testable; the two load-bearing forks are **resolved** —
tool = CodeGraph, mode = MCP-retriever, Cao guard = empirical pass^k (§Reuse decision). The only
carried-forward unknown (`--safe-mode` vs `--strict-mcp-config` harness-strip) is an offline $0 P1
check, not a blocker. **Next: `/plan`** (phase the build: P1 install+harness-strip verify → P2 1-task
pilot human-gate → P3 full benchmark on expanded multi-hop corpus → P4 adopt-doc/architect or kill-record).
