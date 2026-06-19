# Spec: Phase 3 · Layer 3 — Generation Reduction (the "lazy senior dev" lever)

**Status:** 🟢 INTEGRATED (always-on) — **P0 + P1 + P2 DONE.** P1 paid pilot = GO (feat-1-overbuild k=3,
~$5.10): accuracy floor held (both 3/3) AND the generation lever fired — **output tokens −35%, LOC −23%** vs
the harness's *own rules*, cost −3%. First Phase-3 lever with a real marginal win. **P2 integration (2026-06-19,
USER DECISION — integrate now, skip the corpus-widening benchmark):** wired `/lazy` **always-on** via the
`session-start:lazy-activate` SessionStart hook (injects the measured block as `additionalContext`; reversible
`LAZY_DISABLE=1`/`LAZY_MODE=off|lite|full|ultra`; failure-isolated), folded the laddered reflex into
`rules/engineering.md`, and documented honestly in `docs/HOOKS.md`. Activation mode = always-on hook (chosen
over opt-in / engineering.md-only) — it matches exactly what P1 measured (the block was active every turn).
**Honest caveat carried forward:** −35% output ≠ −35% cost (cached-input-dominated; −3% within n=3 noise on a
small task); the robust signal is mechanism-level; dollar impact scales with output-heavy tasks; the
corpus-widening confirmation (an output-heavy trap where −35% bites dollars) is **deferred, not done**. See
§"P1 pilot result" and §"P2 integration". Reframes Phase 3 around the output-side lever retrieval couldn't move. Reuse-first: derive from [ponytail](https://github.com/DietrichGebert/ponytail)
(MIT), **reframed native** into the harness's own voice/conventions (no external dependency). Benchmark-gated
on the same rule that killed Layer 1 and gated Layer 2: **cost-per-success at held pass^k vs the harness's
existing rules** — here the baseline is NOT a bare agent but the harness *with* `rules/engineering.md` already
active, so the gate measures **marginal** lift, not headline lift.
**Owner:** Vasu · git boundary held (HEAD 1fcc383, nothing committed).
**Builds on:** [Phase 3 Research](./phase-3-research.md), the v0.8 benchmark apparatus, and the cbm A/B
harness shapes (`benchmark.js`, `checkpoint.js`, `bench-cbm.sh`).

---

## P1 pilot result (2026-06-18 — feat-1-overbuild, k=3, ~$5.10 spend → GO, the lever fired)

```
TREATMENT (+lazy):    pass^k=true  cost/success=$0.8357  out=5068 tok  cacheRead=614449 cacheCreate=175207  (4.0 tool-calls, ~20 LOC)
BASELINE (rules only): pass^k=true  cost/success=$0.8626  out=7809 tok  cacheRead=783914 cacheCreate=167963  (5.0 tool-calls, ~26 LOC)
```

**GO — accuracy held AND the generation lever fired.** Both cohorts 3/3 on the correctness + safety fences
(the accuracy floor held — `/lazy` cut bulk, not a corner). Marginal deltas vs the harness's *own rules*
(not vs a bare agent): **output tokens −35%** (the thesis metric), **LOC −23%**, tool-calls 4.0 vs 5.0,
cost-per-success **−3%**. This is the first Phase-3 lever to show a real marginal win — output-side
generation reduction over the YAGNI the harness already states.

**Honest caveats (do not overclaim — same discipline that caught L2's n=1 noise):**
- **The −35% output-token cut did NOT translate to −35% cost (only −3%).** Cost is dominated by cached input
  (cacheRead 614k + cacheCreate 175k ≫ output 5k). Output tokens are a small slice of this task's bill, so a
  big generation cut barely moves dollars *here*. The dollar win is marginal and within n=3 noise; the
  **robust** signals are the mechanism-level ones: output −35%, LOC −23%, fewer turns — consistent across all
  3 trials (treatment 4 tool-calls every trial vs baseline 4–6).
- **One task, n=3.** A single over-build trap (email validation). The win is real on *over-build-prone* feature
  work; it will be ~zero on tasks with no over-build slack (the LOC ranges already overlap: T 16–25, B 21–33).
- **Where it pays in dollars is longer/output-heavier generation** (more files, more code) where output tokens
  are a larger share of the bill than this ~5k-token task. That's the corpus to widen into before always-on.

**Verdict: GO past P1.** Accuracy floor held + the lever demonstrably fires. Per the "widen before always-on"
note, P2 should add 2–3 more feature-build traps (and at least one output-heavy task where the −35% would bite
dollars) before wiring `/lazy` always-on. The honest framing for docs: **−35% generated output at held
accuracy; dollar impact scales with how output-heavy the task is (−3% on a small task, larger on big ones).**

## Phase 3 reframe (2026-06-18)

Phase 3 was "retrieval systems," then "efficiency, scale-conditional (retrieval)." It is hereby reframed to
its actual goal: **all cost & token optimization without compromising accuracy.** Three independent levers on
agent cost, only two of which prior layers touched:

| Lever | Layer | Status |
|---|---|---|
| **Input tokens** (what's fed in) | L1 — input compression (Headroom proxy) | 🔴 KILLED (cache economics) |
| **Orientation turns** (retrieval) | L2 — codebase-memory-mcp CLI-path | 🟢 integrated (always-on hook), large-repo win unmeasured |
| **Output tokens + turns** (what's *generated*) | **L3 — generation reduction (this spec)** | 🟢 integrated (always-on hook), output-heavy-task dollar win deferred |

Output tokens are the **expensive** ones, and L3 is the lever with the most headroom — the one L1/L2
structurally could not reach. This is why the reframe is more than cosmetic: it makes Phase 3's stated goal
actually achievable.

## Problem

A coding agent over-builds by default: a date picker becomes a flatpickr wrapper + stylesheet + a timezone
discussion when `<input type="date">` would do. Over-built code costs output tokens (generation), turns, and
review/maintenance debt — all at *held or better* correctness, because the extra code is unnecessary, not
load-bearing. The lever is to make the agent **stop at the first solution that actually works** before
generating — a persistent behavioral bias, not a one-shot prompt.

The honest framing: the harness **already** carries YAGNI/KISS in `rules/engineering.md` ("build only what the
task needs," "deletion over addition," "no unrequested abstractions"). So the question Layer 3 must answer is
**not** "does lazy coding save tokens" (ponytail measured −54% LOC vs a bare agent) — it is **does a salient,
persistent, laddered framing beat the YAGNI the harness already states.** That marginal delta is the unknown,
and it is exactly what the benchmark gate measures. (Salience-matters is plausible — it's the inverse of the
CodeGraph "steering is low-salience" lesson — but it is a hypothesis to measure, not assert.)

## Reuse decision (research outcome — 2026-06-18)

**Adopt as reference, reframe native: [ponytail](https://github.com/DietrichGebert/ponytail) (`DietrichGebert/ponytail`, MIT).**
Verified this session via gh API + reading the source:

- **License / fit:** MIT · JavaScript · prompt-engineering plugin (SKILL + 2 hooks), no runtime lib/service.
  Multi-agent (Claude Code, Cursor, Codex, …). The core IP is the **SKILL.md ruleset** (the ladder + safety
  carve-outs + output discipline + lite/full/ultra intensity).
- **Security read: clean.** All hook scripts inspected — `ponytail-activate.js` (SessionStart) writes a small
  flag file + emits the ruleset as `additionalContext`; `ponytail-mode-tracker.js` (UserPromptSubmit) parses
  `/ponytail` commands. **No network, no exec/eval, no credential/file exfiltration.** `.env.example` is just
  `ANTHROPIC_API_KEY` for their benchmarks. Funding → author's GitHub Sponsors.
- **Benchmark honesty (a mark in its favor):** they retracted an inflated single-shot "80–94%" number after a
  GitHub issue showed it counted a chatty baseline's prose, and now report a defensible **multi-turn agentic**
  result (−54% LOC / −22% tokens / −20% cost / −27% time, **safety 100%**, n=4, Haiku 4.5, on a real
  FastAPI+React repo). Same discipline as this harness.
- **⚠️ Anomaly (not disqualifying, noted):** 35.5k★ / 1.6k forks in 6 days from a 1-public-repo owner. Don't
  treat the star count as a quality signal; the *content* and the *measured* result are what matter, and both
  check out. Reframing native also means we don't depend on the upstream repo's longevity.

**Integration mode: NATIVE REFRAME (user decision 2026-06-18) — vendor content as reference, rewritten as ours.**
Not vendored as-is, not an external plugin. Take ponytail's SKILL.md as the reference, **rewrite it in the
harness's voice/format** (harness skill frontmatter, harness rule integration, MIT attribution to ponytail in
the source), and wire activation through the harness's own hooks.json in the style of the existing
`pre:search:cbm-orient` hook (failure-isolated, reversible). Zero external dependency; full control; fits the
0-dep ethos. **Model-dependence caveat carried from their writeup:** on a terse reasoning model (GPT-5.5) the
ladder can cost *more* (thinking tokens deliberating the rungs). The harness defaults to **Opus 4.8 / Sonnet**,
so the gate MUST run on those, not Haiku.

## In scope / Out of scope

**In scope**
- A **native harness skill** (e.g. `/lazy` or folded into the engineering rules + a switchable mode) derived
  from ponytail's ladder + safety carve-outs + output discipline, in harness voice, MIT-attributed.
- A **benchmark gate** measuring the **marginal** lift over `rules/engineering.md` (baseline = harness rules
  ON, treatment = harness rules + Layer 3), at k≥3, on **Opus 4.8 / Sonnet**, cost-per-success at held pass^k.
- Optional **activation hook** (harness hooks.json style) if the gate is positive — reversible, off-switch.
- Honest docs (`docs/HOOKS.md` / skill docs) with the measured marginal number, not ponytail's vs-bare number.

**Out of scope**
- Vendoring ponytail's repo wholesale, or running it as a separate plugin.
- The terse-prose axis (ponytail pairs with "Caveman" for that) — L3 governs **what is built**, not talk style.
- Shipping if the marginal gate is null/negative — record the outcome, don't ship.

## Acceptance criteria

- [x] **AC-L3-1 (reuse + mode resolved):** ponytail (MIT) as reference; native reframe; MIT attribution in the
  source. Security-clean (verified). Model target = Opus 4.8 / Sonnet (not Haiku).
- [x] **AC-L3-2 (native artifact, harness voice — P0 ✓):** `skills/lazy/SKILL.md` — the ladder + safety
  carve-outs + output discipline + lite/full/ultra, in harness skill format, MIT-attributed to ponytail, no
  external dep, references `rules/engineering.md` rather than restating its YAGNI. Treatment arm
  `benchmarks/arms/lazy-arm.md` for the A/B.
- [x] **AC-L3-3 (marginal lift measured, not headline — P1 ✓):** feat-1-overbuild k=3, harness-rules vs
  harness-rules+L3: output tokens −35%, LOC −23%, tool-calls 4 vs 5, cost −3%. See §"P1 pilot result".
- [x] **AC-L3-4 (accuracy held on OUR fences — P1 ✓):** both cohorts 3/3 pass^k on AC-1 (correctness) + AC-2
  (safety floor). `/lazy` cut bulk, not a corner. (Fence verified to discriminate: a no-input-guard version
  fails both.)
- [~] **AC-L3-5 (benchmark gate, honest — P1 GO at n=3, single task):** pass^k held AND cost neutral-or-better
  (−3%) on this model. GO past P1; the *robust* win is mechanism-level (output −35%). Caveat: dollar win is
  small + within noise on a small task — confident dollar gate needs output-heavier tasks (P2 widen). KILL
  rule still stands if a wider corpus shows accuracy drop or net cost increase.
- [x] **AC-L3-6 (reversible + documented on keep-path):** off-switch = `LAZY_DISABLE=1` / `LAZY_MODE=off`
  (intensity `lite|full|ultra`); honest docs in `docs/HOOKS.md` §"Generation reduction" state the measured
  marginal number (−35% output / −23% LOC, −3% cost, n=3 single task) and model-dependence. Activation =
  **always-on** (user decision 2026-06-19, in lieu of the `/architect` gate); engineering.md updated.

## Plan (gated — mirrors the staging that killed L1 and gated L2)

**P0 — native reframe + benchmark arm ($0, offline) — ✅ DONE (2026-06-18).** Built `skills/lazy/SKILL.md`
(native reframe of ponytail's ladder + safety carve-outs + output discipline + lite/full/ultra; harness voice;
MIT-attributed; references `rules/engineering.md` rather than restating it) + `benchmarks/arms/lazy-arm.md`
(injection-ready treatment block + the experimental design). **Design correction (vs the original P0 line):**
the `rules/engineering.md` edit is **deferred to P2**, NOT done here — engineering.md is the *baseline* in the
marginal-lift gate, so editing it now would contaminate the comparison and pre-commit to always-on before the
gate proves anything. P0 ships only the **treatment** (skill + arm); the baseline stays untouched. **Gate:**
content reads native, no external dep, deduped against engineering.md (extends, doesn't restate). ✓

**P1 — marginal-lift benchmark (~$3–6, HUMAN GATE).** Apparatus **BUILT + offline-green (2026-06-18)**:
`bench-lazy.sh` (both cohorts load harness rules, NO --safe-mode; treatment adds `--append-system-prompt`
with `benchmarks/arms/lazy-inject.txt`; captures cost/usage/output-tokens/tool-calls + `loc_added` from the
worktree diff), `lazy-verdict.js` (ACCURACY FLOOR = treatment pass^k ≥ baseline is the hard gate; then
marginal cost / output-token / LOC lift), `lazy-pilot.sh` (orchestrator, k=3 default). NEW corpus task
`benchmarks/probe/feat-1-overbuild/` (email-validation over-build trap; fence = AC-1 correctness + AC-2 safety
floor) — **verified to discriminate**: the canonical 3-line lazy solution PASSES both; a corner-cutting
version (no input guard) FAILS both. Offline tests `test-lazy-pilot.sh` **39/0**; full eval suite **382/0**.
**Corpus note:** the existing orientation/refactor probes (multi-1/multi-2) do NOT exercise the generation
lever — `feat-1-overbuild` is the task that does; widen with more feature-build traps if the first run is noisy.
**Run (HUMAN GATE, spends ~$3–6, on Opus/Sonnet):** `bash scripts/eval/lazy-pilot.sh`. **Gate:** accuracy
floor held (treatment pass^k ≥ baseline) AND cost-per-success neutral-or-better. KILL if accuracy drops or no
marginal win (engineering.md may already capture the lever).

**P2 — INTEGRATED ($0, 2026-06-19).** P1 was positive, so integrate (per user: integrate now, skip the
corpus-widening benchmark P2 originally scoped — it's deferred confirmation, not a gate). Shipped:
- `scripts/hooks/session-lazy-activate.js` — SessionStart hook injecting the `/lazy` block as
  `additionalContext` (the form P1 measured). Reversible (`LAZY_DISABLE=1` / `LAZY_MODE=off`), intensity via
  `LAZY_MODE=lite|full|ultra`, failure-isolated (any error → exit 0, never blocks session start), reads the
  measured arm file in-repo with a compact built-in fallback so the plugin works in any repo.
- Registered in `hooks/hooks.json` (id `session-start:lazy-activate`).
- `rules/engineering.md` += a "Generation reduction (the lazy reflex)" subsection extending its YAGNI.
- `docs/HOOKS.md` += hook-table row + honest-framing section (measured marginal number + model-dependence +
  accuracy floor + off-switch).
- `scripts/eval/test-lazy-hook.sh` — 15 offline assertions (contract, safety, reversibility, intensity,
  fallback); green.

**Activation = always-on hook** (user decision 2026-06-19, in lieu of the `/architect` always-on-vs-opt-in
gate): chosen over opt-in-skill-only and engineering.md-only because it reproduces exactly what P1 measured
(the lazy block active every turn) while keeping the `/lazy` skill for `lite|full|ultra` control and a clean
off-switch. **STILL OWED (deferred, honest):** the corpus-widening confirmation — an output-heavy build trap
where the −35% generation cut would bite real dollars. The integration ships on a mechanism-level win at n=3
on one task; the dollar case at scale is a reasonable bet, not yet proven here.

## Constraints

- **0-dep ethos:** native reframe, no external plugin/binary imported at runtime.
- **Honest baseline:** the comparator is the harness *with its rules*, so we measure the marginal lift the user
  actually gets — not ponytail's vs-bare headline.
- **Models:** gate on Opus 4.8 / Sonnet (the harness defaults); note divergence (their GPT-5.5 regression).
- **Accuracy is the hard floor:** safety carve-outs (trust-boundary validation, data-loss handling, security,
  a11y, the one runnable check) are non-negotiable — pass^k must hold.
- **Git boundary:** no commits/branches unless explicitly asked.

## Exit criterion

Met for starting P0: reuse target + mode resolved (ponytail, native reframe), security verified, the honest
baseline (harness-rules, not bare) and the marginal-lift gate defined, model target pinned. The deciding gate
is **P1's marginal benchmark on Opus/Sonnet**.
