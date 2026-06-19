# Spec: Phase 3 · Layer 2 (successor) — codebase-memory-mcp, CLI-path orientation

**Status:** 🟢 INTEGRATED (always-on hook, user decision 2026-06-18) — **honest caveat: adopted on the tool's
design + a no-harm small-repo result, NOT on a measured win.** P0–P3 done: offline thesis confirmed (~52–369
tok/query vs CodeGraph's ~80k tax); A/B apparatus built (offline 60/0); P3 (k=3) showed **no net benefit at this
24-file scale** (P2's n=1 GO was noise) but **cacheCreation parity → no MCP context tax** (CodeGraph's killer is
structurally absent). User chose to **integrate as an always-on `Grep` hook** (`pre:search:cbm-orient`),
CLI-path only, failure-isolated, reversible (`CBM_DISABLE=1`), binary not bundled (no-ops until installed). The
large-repo win that justifies it is **still unmeasured** — the large-repo benchmark remains owed as the honest
validation. Tests 13/0; full eval suite 343/0. See §"Integration" + §"P3 result".
**Owner:** Vasu · git boundary held (HEAD 1fcc383, nothing committed).
**Supersedes:** [CodeGraph](./phase-3-layer2-codegraph.md) — 🔴 KILLED (fixed ~$0.9/session MCP context tax
exceeded the entire bare-grep task cost at this repo's 24-file scale; two paid pilots). That kill stands;
this spec re-opens Layer 2 with a different tool **and a different integration path** (CLI, not MCP server).
**Builds on:** [Phase 3 Research](./phase-3-research.md) and the v0.8 benchmark apparatus
(`scripts/eval/probe-claude.sh`, `bench-suite.js`, `benchmarks/probe/`). Reuses the CodeGraph eval
apparatus shapes (`*-setup.sh`, `*-pilot.sh`, `*-verdict.js`, `test-*.sh`).

---

## The lever (unchanged) and why CodeGraph couldn't pull it

Orientation — finding the right files/symbols before editing — spends turns; each `Grep`/`Glob`/`Read`
is an expensive output+reasoning cycle. Layer 2 attacks **turn-reduction**. CodeGraph (MCP-retriever)
was KILLED not because the lever is wrong but because its *delivery mechanism* imposed a **fixed
per-session context tax** (~80k cache-creation tokens ≈ **$0.9/session**: 14 tool schemas +
server-instructions + large tool results, loaded into the agent's context on every session). On a
24-file repo that tax alone is ~5× the entire baseline task cost, so it cannot net positive **regardless
of how well the graph answers** — even a perfectly-used graph still pays ≥ the tax. Two pilots confirmed
it (multi-1: graph used → 6.4× cost; multi-2: graph not even invoked under steering → still 6.0× from the
tax). Same core lesson as Layer 1: on Claude Code's cache-dominated economics, **added context cannot be
recovered.**

The successor's thesis: **don't put a graph in the agent's context at all.** Call the index
**out-of-band via the CLI**, deterministically, and feed back only a tiny bounded answer.

## Reuse decision (source + docs review — 2026-06-18; on-machine measurement PENDING)

**Adopt-candidate: [`DeusData/codebase-memory-mcp`](https://github.com/DeusData/codebase-memory-mcp)**
— evaluate via its **CLI subcommand**, not its MCP server. Verified facts:

- **License / health:** MIT · C · **6.6k★** · v0.8.1 (pushed 2026-06-13, active). Release assets are
  **signed** (sigstore `.bundle` per artifact) with `checksums.txt` + `sbom.json`.
- **Install verified, offline, this session:** `darwin-arm64` tarball downloaded, **SHA-256 matched** the
  published checksum (`fbd047…1c58`), extracted to gitignored `.claude/codebase-memory-install/` (269 MB
  binary — embeds vendored tree-sitter grammars + embedding model; **no Ollama/API/network at query time**
  per source review). `LICENSE` + `THIRD_PARTY_NOTICES.md` present.
- **CLI path confirmed in README (§"CLI Mode", lines 361–371):**
  `codebase-memory-mcp cli <tool> '{json}'` — one tool invocation per process, **no MCP server, no
  JSON-RPC session, no 14-tool schema loaded into any agent**. `--raw` emits bare JSON for `jq`. Examples:
  `cli index_repository '{"repo_path":"…"}'`, `cli trace_path '{"function_name":"…","direction":"both"}'`
  (caller/callee trace = the multi-1/multi-2 query shape), `cli search_graph`, `cli query_graph` (Cypher-ish),
  `cli list_projects`.
- **Binary-only install path exists:** `--skip-config` ("binary only, no agent setup"). The default
  installer otherwise runs `<bin> install -y`, which **mutates global agent config** (`~/.claude/.mcp.json`,
  per-agent hooks/skills) — we never run that. CLI-path adoption mutates **nothing** global.
- **Adoption is structurally solved (the additive hook), if we ever go MCP-path:** its PreToolUse hook on
  Grep/Glob injects ≤N graph hits as *additionalContext*, non-blocking, with a hard deadline — value lands
  even at zero voluntary tool-calling (the inverse of CodeGraph's adoption failure). We do **not** rely on
  this for the CLI path; noted as the keep-path option for `/architect`.

**Integration mode: CLI-path orientation (deterministic, out-of-band) — NOT MCP-retriever.**
A harness orientation step shells out to `<bin> cli trace_path|search_graph …`, parses the bounded JSON,
and hands the agent a short path/symbol list. This **dodges both CodeGraph killers by construction:**
no fixed context tax (nothing loaded into the agent's cached prefix), and adoption is moot (the harness
calls it, not the model). The residual cost is **only** the per-query result size injected into context —
which P0 measures directly.

## Why this beats CodeGraph (the two killers, head-to-head)

| Killer (sank CodeGraph) | CodeGraph (MCP) | codebase-memory-mcp (CLI-path) |
|---|---|---|
| **Fixed context tax** | ~80k cache-create tokens / ~$0.9 per session (14 tool schemas + server-instructions, always loaded) | **$0** — CLI invocation loads nothing into agent context; only the per-query answer (bounded) is injected |
| **Adoption** | Agent refused to call `codegraph_explore` even when steered (low-salience MCP instructions) | **N/A** — harness calls the binary deterministically; no reliance on the model choosing a tool |

Net: the cost that made CodeGraph un-winnable at this scale is **structurally removed**. What remains to
prove is that the per-query answer is (a) cheap enough and (b) *correct* enough to save more turns than
its injection + the cost of wrong hints — the standard kill-rule.

## TRUST flags (must resolve before any keep-path / public bundling)

- **"Leave a star" plug (MCP mode):** prior source review found every MCP `initialize` curls
  `api.github.com` and injects a star-request into the next tool result, no opt-out. **The CLI path avoids
  the MCP `initialize` entirely** — P0 must confirm the `cli` subcommand performs **no network call** (run
  offline / observe no egress) and emits no plug. If the CLI is clean, this flag is contained to the
  unused MCP path; if not, strip-or-reject before keep.
- **macOS gatekeeper:** the manually-extracted binary is quarantined + unsigned; running it needs
  `xattr -d com.apple.quarantine` + ad-hoc `codesign --sign - --force` (per the vendor `install.sh`).
  P0 does this locally on the gitignored copy only.
- **Headline claim is not our metric:** vendor "99% fewer tokens" rides a whole-file-read baseline, not
  agentic grep. We re-bench vs **bare agentic grep, cost-per-success, with cache accounting**, same as
  CodeGraph. Their in-repo benchmark docs report no dollars and contain unexecuted placeholders.

## Acceptance criteria

- [x] **AC-M1 (tool + mode resolved):** `codebase-memory-mcp`, mode = **CLI-path orientation** (out-of-band
  `cli` calls, no MCP server). Verified via README §CLI Mode + `--skip-config`. ✓
- [x] **AC-M2 (offline, deterministic — P0 ✓):** `cli index_repository` indexed 132 files → 1477 nodes /
  1845 edges in **<1s, offline** (no API key, no egress observed); store persists to `~/.cache/codebase-memory-mcp/
  <slug>.db` (~4.2 MB) **outside the repo working tree**. `cli trace_path` re-run twice → **byte-identical**
  (deterministic). Embedding model is vendored in-binary; no external service needed.
- [x] **AC-M3 (per-query cost measured — P0 ✓):** real orientation answers as injected into context:
  `trace_path {direction:both}` on `aggregateCost` = **435 chars (~108 tok)** and correctly traced the caller
  chain `runCohort → main → file` with hop numbers; `search_graph` name-pattern = 1477 chars (~369 tok) raw,
  **174 chars (~43 tok)** after a trivial `jq` projection. All ≪ the few-hundred-token target; **vs CodeGraph's
  ~80k-token fixed tax this is ~700× smaller and out-of-band (never enters the cached prefix).**
- [x] **AC-M4 (CLI network-clean / TRUST — P0 ✓):** no `api.github.com`, "leave a star", or sponsor text in
  any `cli` stdout/stderr (precise grep). The CLI path never runs the MCP `initialize` that carried the plug.
  *(A packet-level trace is deferred to P4 keep-path; the design + output evidence are consistent with clean.)*
  **README discrepancy found:** the documented `cli --raw` flag is **invalid in v0.8.1** ("unknown tool:
  --raw") — stdout is already clean JSON, so projection is done with `jq` directly.
- [x] **AC-M5 (fair A/B harness — BUILT + offline-proven at P1):** `bench-cbm.sh` runs BOTH cohorts with
  identical flags (`-p --output-format stream-json --safe-mode`); ON additionally prepends the bounded
  `<bin> cli <tool>` answer (from the task's `orient.json`, project slug merged at runtime) as an
  orientation block — so the **only** ON↔OFF delta is the injected hint (no MCP, no harness leak). Capture-
  nothing sidecar (cost/usage/tool-count/hint_tokens); per-trial toollog (hint_present, did_not_start);
  startup fast-fail + watchdog reused from the CodeGraph runner. `cbm-pilot.sh` (no daemon — CLI-path
  dividend), `cbm-verdict.js` (validity gate = HINT INJECTED; turn-reduction; cost; cache-parity;
  hint-mislead), `cbm-setup.sh` (download+checksum+sign+index, `--check`), `cbm-measure.js` (reproducible
  P0). Offline tests **60/0** (`test-cbm-setup` 12, `test-cbm-pilot` 48); full eval suite **328/0**.
- [~] **AC-M6 (benchmark gate, honest — P3 done at this scale; large-repo gate pending):** at k=3 the CLI
  path showed **no net benefit** on this 24-file repo (multi-1: ON ~5% more, turns 4=4; multi-2: both fail,
  ON ~13% more) — the P2 n=1 edge was noise. **No quality regression from the hint** (multi-1 held; multi-2
  both-failed). cacheCreation parity confirms **no tax**. Small-repo decision: **do not adopt (no win)**;
  Layer 2 not killed because the lever targets large repos. **Final gate = a large-repo corpus**; null/negative
  there → KILL.
- [x] **AC-M7 (keep-path integrated + documented — user decision 2026-06-18):** user chose **always-on hook**
  (over scale-gated opt-in / recommend-only), accepting that the large-repo win is a bet on the tool's design
  rather than our own measurement (small-repo result was null/no-harm). Built `scripts/hooks/pre-search-cbm-orient.js`
  + registered in `hooks/hooks.json` (matcher `Grep`, id `pre:search:cbm-orient`). SAFETY-GATED: CLI-path only
  (no MCP server → no api.github.com / no star-plug), failure-isolated (missing binary/index/timeout/error →
  silent no-op, never blocks), bounded (≤5 hits, 2s timeout), reversible (`CBM_DISABLE=1`). Documented honestly
  in `docs/HOOKS.md` (§"Structural orientation — honest framing": null small-repo result stated, large-repo
  benefit flagged as unmeasured). Offline tests `test-cbm-hook.sh` **13/0**; live injection verified against the
  real indexed binary. **Open:** binary is NOT bundled — the hook no-ops until a user installs via `cbm-setup.sh`
  (keeps the plugin lean; 0-dep ethos). The deciding **large-repo benchmark remains the honest validation** and
  is still owed before claiming the win.

## Plan (gated — mirrors the CodeGraph staging that caught both prior losses)

**P0 — offline measurement ($0, no model cost) — ✅ DONE (2026-06-18, PASSED).** De-quarantine + ad-hoc sign;
`--version` (0.8.1); `cli index_repository` (132 files → 1477 nodes/1845 edges, <1s); `cli trace_path
direction=both` + `cli search_graph` measured (~43–369 tok); offline + network-clean confirmed. See §"P0
result". Apparatus (`cbm-setup.sh`, `cbm-measure.js`) still to be written in P1 to make this reproducible.
**Gate PASSED:** binary runs offline; per-query answer ≪ a few hundred tokens; network-clean. **→ proceed to P1.**

**P1 — CLI-path A/B apparatus + offline tests ($0) — ✅ DONE (2026-06-18).** Built: `bench-cbm.sh` (both
cohorts identical `--safe-mode`; ON prepends the `cli` answer from the task's `orient.json`), `cbm-pilot.sh`
(index-ensure → cohort run → verdict; no daemon), `cbm-verdict.js` (HINT-INJECTED validity gate + turn-
reduction + cost + cache-parity + hint-mislead), `cbm-setup.sh` (download/checksum/sign/index + `--check`),
`cbm-measure.js` (reproducible P0). `benchmarks/probe/multi-1-callers/orient.json` = the `trace_path stateDir`
query. **Gate PASSED:** `--check` green; offline tests **60/0**; `cbm-measure` against the real binary green
(`trace_path stateDir` = 52 tok, deterministic); full eval suite **328/0**. **→ proceed to P2.**

**P1 note — injection mechanism chosen (Open Q1):** prepend the bounded `cli` answer to the **user turn** (not
`--append-system-prompt`), so the system prompt stays byte-identical across cohorts — the cleanest possible
fairness. The hint is labeled and explicitly tells the agent to verify against the real files (the hint can be
incomplete — that wrong-hint risk is what the pilot prices in). Both cohorts run `--safe-mode`; the ONLY delta
is that prepended block. An empty `cli` answer is recorded as `hint_present=false` → the verdict marks the run
INVALID rather than silently scoring a degraded-to-baseline cohort as a win.

**P2 — 1-task paid pilot (~$1, HUMAN GATE) — ✅ DONE (2026-06-18, ~$0.31): GO.** Ran `multi-1-callers` k=1
ON vs OFF. pass^k held both; ON $0.1498 vs OFF $0.1577 (~5% cheaper, within noise at n=1); cacheCreation
parity 6717≈6323 (**no tax** — the CodeGraph killer is absent); turn-reduction fired 3 vs 4 calls. No
disqualifier → P3 justified. See §"P2 pilot result".

**P3 — 2-task confirm + scale note — ✅ DONE (2026-06-18, ~$2.14): NO WIN at this scale, NO HARM.** multi-1
k=3: ON ~5% more, turns 4=4 (P2 edge was noise). multi-2 k=3: both fail 0/3 (didn't discriminate), ON ~13%
more. cacheCreation parity on both → no tax. No quality regression from the hint. **Decision: do not adopt at
small scale; Layer 2 NOT killed — the lever targets large repos.** See §"P3 result". → P4 / large-repo corpus.

**P4 — adopt-doc + scale-gating + /architect, OR kill-record ($0).** Keep: design repo-size gate (AC-M7),
`docs/HOOKS.md` reversible-opt-in, resolve the MCP-path star plug only if we'd ever bundle MCP mode, then
`/architect`. Kill: append §kill-record (verdict + per-task table), status → 🔴 KILLED.

## Integration (2026-06-18 — always-on `Grep` hook, user decision)

After P3, the user elected to **integrate now** as an always-on hook rather than gate further on a large-repo
benchmark. Recorded honestly: this **overrides the harness's benchmark-gated discipline** on a tool whose own
measured result here is *null* (no win, no harm) — the bet is that the large-repo win the design implies will
materialize. It is made safe-by-construction and reversible so the downside is bounded.

- **Hook:** `scripts/hooks/pre-search-cbm-orient.js`, registered in `hooks/hooks.json` (matcher `Grep`, id
  `pre:search:cbm-orient`). On a `Grep`, it runs `<bin> cli search_graph {name_pattern: <grep pattern>}` against
  the pre-built index and injects ≤5 `name → file` hits as PreToolUse `additionalContext`.
- **TRUST flag contained:** CLI-path only — it never starts the MCP server, so the `api.github.com` call + "star"
  plug that live in the MCP `initialize` path are never triggered. No global config mutation.
- **Failure-isolated:** missing binary / un-indexed repo / timeout / any error → exit 0, no output. Never blocks
  or slows a tool call (mirrors `pre-tool-trace.js`). Bounded: ≤5 hits, 2s `cli` timeout, pattern ≤200 chars.
- **Reversible:** `CBM_DISABLE=1` no-ops it without editing config; remove its `hooks.json` block; `rm -rf` the
  install. The 269 MB binary is **not bundled** — the hook no-ops until a user runs `cbm-setup.sh` (0-dep ethos).
- **Docs:** `docs/HOOKS.md` §"Structural orientation — honest framing" states the null small-repo result and
  flags the large-repo benefit as unmeasured. Tests: `scripts/eval/test-cbm-hook.sh` **13/0**; live injection
  verified against the real indexed binary; full eval suite **343/0**.
- **Still owed:** the large-repo benchmark is the honest validation of the bet. Until it lands, the integration
  is a no-harm augmentation, not a proven win — said plainly in the docs.

## P3 result (2026-06-18 — multi-1 + multi-2 at k=3, ~$2.14 spend → NO WIN at this scale, NO HARM)

```
multi-1-callers (k=3): ON pass^k=true  $0.1684/succ  (4.0 tool-calls/trial, cacheCreate 21681)
                       OFF pass^k=true  $0.1604/succ  (4.0 tool-calls/trial, cacheCreate 19542)
multi-2-impact  (k=3): ON  pass^k=FALSE (0/3) $0.2045/trial (4.3 tool-calls/trial, cacheCreate 26995, hint ~294 tok)
                       OFF pass^k=FALSE (0/3) $0.1801/trial (4.0 tool-calls/trial, cacheCreate 24710)
```

**The honest read — P2's n=1 favorable signal was noise.** At k=3:
- **multi-1 (clean):** ON ~5% MORE expensive ($0.1684 vs $0.1604); turn-reduction **did not fire** (4.0 = 4.0
  — the n=1 "3 vs 4" was noise). Quality held both. No win.
- **multi-2 (does not discriminate):** BOTH cohorts FAILED the rename 0/3 — the task is too hard for the model
  at this setting (same as CodeGraph's multi-2, where OFF also failed), so it is **not a clean test** of the
  hint's value. What it does show: the ~294-tok hint did **not** rescue quality and ON cost ~13% MORE.
- **Mechanism never fired** on either task; the injected hint added input tokens (the agent reads them) for
  **no offsetting turn/quality gain**, so ON is a slight net cost on both.
- **But NO HARM structurally:** cacheCreation parity on both (21681≈19542; 26995≈24710) — **no MCP context
  tax**, the killer that disqualified CodeGraph. The CLI-path advantage is real; there is simply nothing for
  orientation to save on a 24-file repo where bare grep already finds everything in ~4 calls.

**Verdict — small-repo case settled: do NOT adopt at this scale (no win), but NOT killed.** This is the same
*outcome* as CodeGraph (no net positive here) for the **opposite reason**: CodeGraph lost on a fixed tax that
made it un-winnable at any task; cbm has **no tax** and loses only because a small repo has no orientation cost
to recover. That distinction is exactly why Layer 2 stays open under the **scale-conditional** thesis: the
prize is LARGE repos where bare-grep orientation is genuinely turn-expensive. P3 proves cbm clears the "do no
harm" bar at small scale (cache parity) — the deciding test is now a **large-repo corpus**, and it is the sole
remaining justification path. If a large repo shows no win either → **KILL Layer 2** outright.

**Apparatus note:** multi-2's both-fail means the corpus needs a turn-heavy task that OFF passes at least
sometimes, else the hint's effect can't be measured. Task calibration carries into the large-repo corpus.

## P2 pilot result (2026-06-18 — multi-1-callers, k=1, ~$0.31 spend → GO at n=1, REVISED by P3)

> ⚠️ Superseded by P3: the favorable direction below did **not** survive k=3 (it was n=1 noise). Kept for the
> record. The durable P2 finding is the *structural* one — cache parity / no tax — which P3 confirmed.


```
ON  (cbm CLI):   pass^k=true cost/success=$0.1498  in=2434 out=1225 cacheRead=77671 cacheCreate=6717  (3 tool-calls, 4 turns, hint ~51 tok)
OFF (bare grep): pass^k=true cost/success=$0.1577  in=2436 out=1310 cacheRead=97405 cacheCreate=6323  (4 tool-calls, 5 turns)
```

All four validity gates passed (HINT INJECTED ~51 tok · QUALITY HELD · CACHE VISIBLE · AUTH SURVIVES). The
two findings that matter, contrasted with CodeGraph's two paid pilots on this same repo:

| | CodeGraph (MCP) | codebase-memory-mcp (CLI-path) |
|---|---|---|
| Fixed context tax | cacheCreate **7.3× OFF** (~$0.9/session) | cacheCreate **6717 ≈ 6323 OFF** — **PARITY, no tax** |
| Turn-reduction lever | never fired (4=4, or used more) | **fired: 3 vs 4 tool-calls (25% fewer)** |
| Cost vs bare grep | **6.0–6.4× MORE** | **~5% cheaper** ($0.1498 vs $0.1577), quality held |

The structural killer is gone (cache parity confirms the out-of-band CLI path adds nothing to the cached
prefix), and the mechanism the thesis rests on actually fired. This is the first retrieval candidate in
Phase 3 to clear the "do no harm" bar at small scale — Layer 1 and CodeGraph both failed it.

**Honest caveats (do not overclaim):**
- **n=1, k=1.** The ~$0.008 (5%) cost edge is **within noise** — this pilot does NOT establish "cheaper" with
  confidence. What it DOES establish at n=1 are the *mechanism-level* facts (cache parity; 3 vs 4 calls) and
  the *absence* of CodeGraph's disqualifier — those are structural, not statistical.
- **multi-1 is grep-favorable** (small repo; bare grep solved it in 4 calls). The turn-reduction headroom is
  small here by construction; the lever should matter more on larger/turn-expensive orientation.
- **The hint was a well-formed `trace_path` query** (the graph's real answer, not a hand-written oracle). It
  did not mislead (quality held), so wrong-hint cost was zero on this task — but that is one task.

**Verdict: GO past the P2 gate.** Unlike CodeGraph (killed at P2 because the tax made P3 pointless), here
there is **no disqualifier** and a favorable direction → P3 is justified to add statistical weight + a
turn-heavier task. Per the scale-conditional framing, this repo can only prove "do no harm + small favorable";
the *large-repo net win* (where orientation is genuinely turn-expensive) needs a separate large-repo corpus.

## P0 result (2026-06-18 — offline, $0, PASSED → proceed to P1)

Ran on the gitignored darwin-arm64 binary (v0.8.1, checksum-verified) after the macOS gatekeeper fix
(`xattr -d com.apple.quarantine` was a no-op; `codesign --sign - --force` replaced the signature).

| Probe | Result |
|---|---|
| `--version` | `codebase-memory-mcp 0.8.1` |
| `cli index_repository` (this repo) | 132 files → **1477 nodes / 1845 edges**, **<1s**, excluded `.git/.claude/.codegraph/.code-graph` |
| Index store | `~/.cache/codebase-memory-mcp/<slug>.db` = **4.2 MB, OUTSIDE the repo** (XDG cache) |
| `cli trace_path {fn:aggregateCost, direction:both}` | **435 chars ≈ 108 tok** — traced callers `runCohort → main → file` (hop 1/2/3); empty callees. Genuine multi-hop orientation. |
| Same, re-run | **byte-identical → deterministic** |
| `cli search_graph {name_pattern:".*ggregate.*"}` | 1477 chars ≈ 369 tok raw (bloated by a `fp` fingerprint field); **174 chars ≈ 43 tok** after `jq` projection to name/file/signature/degree |
| TRUST (star-plug / `api.github.com` / sponsor on CLI path) | **none** in any stdout/stderr (precise grep) |

**Verdict:** the CLI-path thesis holds on-machine. The per-query answer that lands in agent context is
**~43–369 tokens** — **~700× smaller than CodeGraph's ~80k-token / ~$0.9 fixed context tax**, and it is
**out-of-band** (the binary runs as a subprocess; nothing is loaded into the agent's cached prefix). The
fixed-tax killer that made CodeGraph un-winnable at this 24-file scale is **structurally absent here.** What
remains for the paid pilot (P2) is the *real* question the offline measurement can't answer: does injecting
that ~100-token hint actually save more turns/dollars than it costs (incl. wrong-hint cost) at held pass^k.

**Notes carried to P1/P2:** (1) the README's `cli --raw` flag does not exist in v0.8.1 — use `jq` on stdout;
(2) `index_repository` excludes `.claude` so the throwaway-worktree benchmark must index the **main** repo or
re-index per task (same pattern as CodeGraph's `CODEGRAPH_REPO`); (3) the trimmed projection (name + file +
signature + degree) is the right shape to inject — strip `fp` and the metric fields.

## Constraints

- **0-dep ethos:** the 269 MB binary is **eval-scoped** (gitignored, like the killed Headroom venv), never
  imported by hooks/skills at runtime unless a positive benchmark + `/architect` keep-decision justifies it.
- **CLI-path only for the eval:** no global `install`, no `.mcp.json` mutation, no PreToolUse hook wired.
- **Dollars, not tokens:** report cost-per-success; turn-count is the mechanism metric.
- **Git boundary:** no commits/branches unless the user explicitly asks.

## Open questions (with recommended defaults)

1. **Injection mechanism (P1):** prepend the `cli` result to the task prompt vs `--append-system-prompt`?
   *Default:* prepend to the user turn (closest to how a real harness orientation step would feed it; keeps
   the system prompt identical across cohorts for fairness).
2. **Which `cli` tool for orientation:** `trace_path` (caller/callee) vs `search_graph` (name pattern) vs
   `query_graph` (Cypher). *Default:* `trace_path direction=both` for caller-trace tasks; `search_graph` for
   name-pattern lookups. P2 calibrates which the corpus tasks actually need.
3. **Index freshness:** re-index per task vs once per pilot. *Default:* once per pilot over a clean checkout
   (the corpus tasks don't mutate before orientation); note that a real harness would use the drift watcher.
4. **Scale threshold (P4, keep-path only):** file-count or token-count gate. *Default:* defer until P3 data
   exists; CodeGraph's own data suggests wins begin well above this repo's 24 files.

## Exit criterion

Met for **starting P0**: tool + integration mode are resolved and grounded in the repo's own docs; the
binary is installed + checksum-verified offline; the two CodeGraph killers are shown to be structurally
removed by the CLI path; the kill-rule is inherited unchanged. The one gate before any spend is **P0's
offline measurement**, which needs **user authorization to execute the downloaded binary**.
