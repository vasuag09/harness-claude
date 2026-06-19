# Phase 3 Research — Retrieval / Context Efficiency

> Reuse-first research artifact (per `rules/workflow.md`). Feeds `/spec`.
> Date: 2026-06-17. Status: research complete, direction recommended, build not yet started.

## Question

Phase 3 on the roadmap is "Retrieval systems" (codemaps + semantic search + RAG to cut
exploration tokens). Before building, establish what already exists, what the evidence says
about whether it works, and whether there is a **genuinely unbuilt** thing the harness is
uniquely positioned to build that **optimizes Claude's token usage**.

## Method

14 web searches (mgrep) + 3 deep source reads (Anthropic context-engineering doctrine;
Cao et al. 2026 file-system long-context; ContextBench 2026). 2026-current framing.

## Landscape — three paradigms

| Paradigm | Examples | Verdict (2026) |
|----------|----------|----------------|
| Vector/embedding RAG | old Cody, Continue `@Codebase` | **Abandoned** — drift, security, brittleness |
| Structural graph (tree-sitter + PageRank) | aider repo-map, **vexp**, code-review-graph, Graphify | Token-budgeted capsule; mature, crowded |
| Agentic search (grep/glob JIT) | Claude Code native, Sourcegraph Amp, SWE-grep | **Winning default** — "ripgrep just works", no drift |

The field has moved **away from pre-built indexes** toward just-in-time agentic search.

## The decisive empirical finding

On **real** coding tasks, context/retrieval scaffolding barely moves *capability* but
reliably cuts *cost*:

- **WarpGrep v2** (RL search subagent, SWE-bench Pro, Mar 2026): **+2.1–2.2 pp** resolve
  rate, but **−15.6% cost, −28% time** (fewer tokens spent on search).
- **SWE-grep** (Cognition): matches frontier retrieval, **20× faster**.
- **Oracle retrieval** (exact files handed in): large jump — but an unreachable upper bound.
- Task lists: ~+2%.

**Conclusion: capability is a dead end (bitter lesson, confirmed 4×); efficiency is the
only honest target — and it is exactly the harness's stated goal (token optimization).**

## Supporting evidence (verbatim, load-bearing)

- **ContextBench 2026** — "Sophisticated agent scaffolding does not necessarily improve
  context retrieval performance, revealing potential over-engineering… echoes 'The Bitter
  Lesson'." Agents favor recall over precision (line-level F1 ~0.40–0.53). **Usage Drop**
  (retrieved-but-unused gold context): GPT-5 17.9%, Claude Sonnet 4.5 19.6%, Gemini 43.1%.
  The gap is **measured, not closed**; "consolidation as a key bottleneck."
- **Cao et al. 2026** — file-system + native grep beats RAG on 4/5 long-context benchmarks.
  Warning: "Equipping coding agents with retrieval tools does not consistently improve
  performance and can even degrade it" (a bolted-on retriever **suppresses native
  exploration**). No trajectory-learning / caching across runs — stateless (their gap).
- **Anthropic doctrine** — endorses **hybrid** (some up-front for speed + JIT exploration);
  endorses note-taking to external memory; objective = "find the smallest set of high-signal
  tokens." Open problem: "the right level of curation is task-dependent" (no universal formula).
- **ETH Zurich 2026** — **human-curated** context files (CLAUDE.md/AGENTS.md) give +4%;
  **auto-generated** ones often **increase noise and reduce success**.

## Three failure modes any "auto-built context" must dodge

1. **Bitter lesson** — marginal accuracy gains (~2pp).
2. **Cao suppression** — a retriever the agent calls *instead of* grep can degrade results.
3. **ETH auto-gen noise** — machine-written context files hurt unless human-curated.

## Where the harness is actually differentiated

Not a mechanism (all taken: Provence pruning −80%, zerank rerank −72%, MACRO trajectory→tools,
Fang trajectory→tips, `/extract` trajectory→skills, LLMLingua/dreaming consolidation,
WarpGrep/SWE-grep RL search). The differentiation is an **integration the literature lacks**:
**trace-learned + benchmark-proven + human-gated**, wired into an SDLC pipeline. The harness
already owns all three primitives — run-traces, the benchmark apparatus (stashed v0.8 work),
and the stage-for-approval gate (`/extract`) that ETH says is required to avoid auto-gen noise.

## Recommended direction for Phase 3

Reframe from "Retrieval systems" → **"Token-efficient orientation (efficiency, not capability)."**

> A cheaper orientation step: a scoped Explore subagent seeded with a **human-gated
> starter-pack of file *paths*** (not content — dodges Cao + ETH), whose **only** success
> metric is **tokens-per-task down at held-constant pass^k**, proven by the benchmark, and
> **killed if it can't beat bare agentic grep**.

## Decision gate before building — cheap falsification first

Use the **stashed v0.8 benchmark apparatus** (not a fresh build) with the **corrected metric**
(tokens at held pass^k) and **correct strong baseline** (bare agentic grep) on 2–3 **real
multi-file** tasks:

- **If** a paths-only, human-gated starter-pack cuts tokens at equal quality → spec + build.
- **If not** → Phase 3 as "retrieval" is dead; pivot to pure efficiency plumbing
  (compaction / context-editing tuning) or skip to Phase 4.

## Realistic efficiency envelope (what to expect, honestly)

| Source | Cost | Time / speed | Capability |
|--------|------|--------------|------------|
| WarpGrep v2 (real, SWE-bench Pro) | **−15.6%** | −28% | +2.1–2.2 pp |
| SWE-grep (real) | — | **20× faster** retrieval | matches frontier |
| vexp / code-review-graph (self-reported, single-task) | 65% / 49× | — | unverified |

**Plan on ~15–30% token/cost reduction on orientation-heavy tasks**, *not* the 49×/65×
self-reported headlines (those are cherry-picked single tasks). Tasks that are already cheap
(the v0.8 toy corpus) will show ~0 — the win only appears where orientation dominates.

## Falsification probe results (2026-06-17) — NOT falsified

Built a paths-vs-bare-grep probe on the v0.8 apparatus (new runner `scripts/eval/probe-claude.sh`;
tasks under `benchmarks/probe/`). Both cohorts run `--safe-mode`; ON prepends an **oracle** (hand-
curated, exact) paths starter-pack; OFF orients via native grep. 4 orientation-heavy edit tasks,
k=3, against THIS repo (91 files). Every task: both cohorts held **pass^3** (equal quality).

| Task | Target file (found by role) | Cost saved (ON vs OFF) | Tokens saved |
|------|------------------------------|------------------------|--------------|
| orient-1 | scripts/hooks/_lib.js | 16.6% | 30.4% |
| orient-2 | scripts/eval/continuous.js | 16.0% | 30.5% |
| orient-3 | scripts/eval/trace-report.js | 12.2% | 27.9% |
| orient-4 | scripts/eval/extract-rubric.js | 12.4% | 15.0% |
| **Aggregate** | | **14.3% cheaper** | **25.9% fewer** |

Also: cache-read −28.8%, output −21.9%. 4/4 same direction, tight 12–17% cost band — not n=1 noise.
Lands in the predicted envelope (WarpGrep −15.6%). **Cost headline ~14%** (cache-read is cheap so
cost delta < token delta); that is the honest number to plan around.

**Critical caveat — this is the ORACLE ceiling.** The hint here is the *exact correct path*, hand-
curated. A buildable Phase 3 must *predict* those paths from traces; it will be imperfect, so real
delivery is a *fraction* of ~14%, and a *wrong* hint can hurt (Cao suppression). So: ~14% is the
upper bound, not the expected yield. Build only if a path *predictor* nets positive on the benchmark
(including the cost of wrong hints) vs bare grep. Same kill-criterion stands.

## DECISION — Phase 3 build plan (2 layers, each benchmark-gated)

Reframed from "retrieval systems" to **token-efficient context**, built by reusing proven licensed
parts (CodeGraph MIT, Headroom Apache-2.0) + the harness's own benchmark/trace/human-gate. NOT a
from-scratch invention. Two build layers, in this order:

**Layer 1 — Observation / tool-output compression (FIRST).**
- Attacks the largest *recurring* pool: tool results (file reads, bash/test output, grep, MCP dumps,
  diffs) re-sent every turn (the re-send multiplier). Orientation is one-time; this compounds.
- Build: a PostToolUse hook that compresses big outputs **at capture** (failures-only for test/lint,
  dedup/minify for JSON, head/tail for logs) + a **reversible** local store so the agent can
  `retrieve` the original on demand + clear stale results from history.
- Reuses: Headroom's CCR (reversible retrieve) + SmartCrusher (dedup/minify) ideas, Anthropic
  context-editing; builds on the existing `strategic-compact` hook.
- Why first: biggest pool, simplest (a hook + store, NOT an index), lowest quality risk — reversible
  + it *reduces context rot* so quality can go UP.
- Honest cost note: much re-sent history is CACHED (~10% price), so the dollar win is MODEST and
  concentrated in **uncached big outputs compressed at capture**; the bigger prize here is quality.

**Re-measure on the probe corpus before Layer 2.**

**Layer 2 — CodeGraph orientation (SECOND, CONDITIONAL).**
- Structural code graph (tree-sitter → SQLite/FTS5 → MCP) to kill the grep/Explore loop. Reuse
  CodeGraph's MIT design + deterministic drift handling (native file events, staleness banners,
  content-hash reconcile). No embeddings (ethos + 2026-evidence aligned).
- Conditional: build only if, AFTER Layer 1, the benchmark still shows orientation headroom worth
  the index complexity. CodeGraph's real cost lever is **turn-reduction** (58% fewer tool calls →
  fewer expensive output/reasoning cycles), which is why it bites cost more than pure input compression.

**Cost ceiling (honest):** both layers are input-side → end-to-end **cost ~15–35%** (NOT the 60–95%
token headlines). The expensive *output/reasoning* layer is untouched by compression; attack it
separately via **model routing + fewer turns** (already in the harness) — deferred, not in these 2 layers.

**Discipline:** each layer is its own /spec, benchmark-gated on "cost down at held pass^k" against
bare-grep baseline, and KILLED if it doesn't net positive. Same rule that stashed v0.8.

## Do NOT

- Build a pre-computed vector/embedding index (abandoned paradigm).
- Build a retriever the agent calls *instead of* grep (Cao suppression).
- Auto-inject machine-generated context without a human gate (ETH noise).
- Claim 49×/65× — the defensible, real-task number is ~15–30%.
