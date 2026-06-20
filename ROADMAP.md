# harness-claude — Evolution Roadmap

The base harness is **phase 1**. It is deliberately built to extend toward the later
phases without rework. Each phase builds on the previous one's primitives.

## Phase 1 — Subagents  ✅ (complete)
- Scoped subagents (planner, architect, reviewers, tdd-guide, resolvers, cleaner).
- Two orchestration modes: sequential phases (default) + iterative retrieval (≤3 cycles).
- Token optimization via cheapest-sufficient-model delegation + summary returns.
- Memory persistence (session files + PreCompact/Stop/SessionStart hooks).
- **Exit criteria:** a real task runs end-to-end through the pipeline and produces
  production-grade output in isolation.

## Phase 2 — Evaluation loops  ✅ (complete)
- ✅ Run-tracing slice (v0.3.0) — logbook of what actually fired; proves host-isolation at runtime.
- ✅ Checkpoint evals (v0.4.0) — `/eval` verifies a change against its spec's acceptance criteria.
- ✅ Extract-and-evaluate (v0.5.0) — the Stop "candidate pattern" seed is now a real flow:
  trace-driven detector → `/extract` skill → rubric gate, staging proposals for human approval.
- ✅ Benchmarking harness (v0.6.0) — `/benchmark`: fork + worktree, with vs. without a
  component; reports pass@k (need it to work once) and pass^k (need consistency). Result-driven,
  filling the extract rubric's R5 seam. *(AC-E3)*
- ✅ Continuous evals (v0.7.0) — `/health`: runs a repo's test/lint/typecheck on demand
  (auto-detected or `--cmd`), streams output live but captures nothing, emits a pass/fail
  summary + secret-free artifact. *(AC-E2)*
- **Adds:** an `eval/` module + `/eval` + `/extract` + `/benchmark` + `/health` skills.

## Phase 3 — Cost & token optimization (no accuracy loss)  ✅ (complete, v0.8.0)
Reframed from "retrieval systems": retrieval gives only ~+2pp capability on real coding tasks
(the bitter lesson, confirmed across the literature), so the honest, achievable target is
**token efficiency at held accuracy**. Three independent levers on agent cost, each its own
spec, each **benchmark-gated** on cost-per-success at held pass^k vs the harness's own baseline —
**killed if it can't beat that baseline** (the discipline is the point; two of four were killed):

| Lever | What | Status (v0.8.0) |
|-------|------|-----------------|
| Input tokens | Wire-level input-compression proxy (Headroom) | 🔴 killed — broke Claude Code's cache economics ($↑) |
| Orientation turns | Structural code-graph orientation | 🔴 codegraph killed (MCP context tax) → 🟢 `codebase-memory-mcp` CLI-path integrated as an always-on Grep hook (no tax); large-repo win is a stated, unproven bet |
| Output tokens + turns | Generation reduction — the `/lazy` "build the minimum that works" reflex | 🟢 integrated (always-on SessionStart hook, reversible); measured −35% output / −23% LOC at held accuracy on an over-build task |

- **Adds (v0.8.0):** `/lazy` skill + two always-on hooks (`session-start:lazy-activate`,
  `pre:search:cbm-orient`), a reusable benchmark apparatus + corpus under `benchmarks/` and
  `scripts/eval/`, and kill-record specs under `docs/specs/`.
- **Outcome:** phase complete — the lever space was explored, the two that beat the baseline shipped
  (always-on, reversible), the two that didn't were killed on cost evidence and recorded. The
  benchmark-gated discipline is itself the deliverable: features earn their place or get cut.
- **Deferred (not a blocker):** the large-repo / output-heavy validation where these levers pay in
  real dollars (the small self-test repo can't show it). Honest framing carried in `docs/HOOKS.md`
  and the specs; revisit if/when a large-repo corpus exists.

## Design altitude (v0.9.0) — cross-cutting PLAN + VERIFY enhancement  ✅
Not a numbered phase — a leveling-up of the pipeline's *design* altitude, both product/UX and
system. Adds two conditional skills that fire only on relevant work (a change needs one, both,
or neither; internal/CLI work skips them):
- **`/design`** (PLAN) — a product/UX/UI **design brief** before code, routing by surface to the
  harness's own craft rubrics under `skills/design/references/` (product-UI · aesthetic-direction)
  and always overlaying the cross-cutting a11y/UX floor. Fully self-contained — no external plugin.
- **`/design-review`** (VERIFY) — a craft + a11y/UX gate parallel to `/security-review`;
  blocks on Blockers, judges by default.
- **Strengthened `/architect`** — mandatory do-nothing/simplest alternative, explicit NFR
  trade-offs, failure-degradation; reads the in-repo architecture-domain cues, grounds via context7.
- **Adds:** `/design` + `/design-review` skills (25→27), the self-contained design rubric set,
  design-gate wiring in `harness-plan` / `harness-verify` / `workflow.md`. **Zero new MCP servers**
  (skill + knowledge wiring only — consistent with the Phase-3 anti-MCP-tax discipline).
- **Dogfooding caveat (honest):** this harness has no UI, so `/design` / `/design-review` can't
  be proven on the repo itself — shipped as an *enable, don't-prove-on-self* module (mirrors the
  deferred large-repo benchmark). Validate on a small frontend project when one exists.

## Phase 4 — Long-running agents  ✅ (complete, v0.10.0)
- ✅ `/operate`: supervises an unattended run on the platform's `/loop` + `/schedule` (thin
  discipline layer — no new runtime), self-checkpointing against the Phase-2 eval skills.
- ✅ Drift can't pass silently: each checkpoint reuses `/health` (test/lint pulse) + `/eval`
  (acceptance-criteria gate); N consecutive failures halt the run and surface the criterion.
- ✅ Halting guardrails — drift > budget (wall-clock) > iteration-cap — and durable run state
  (`.claude/runs/<id>.json`) as the source of truth across firings (survives fresh contexts).
- **Adds (v0.10.0):** `loop-operator` agent + `/operate` skill + `scripts/operate/{step,state,
  guardrails}.js`. Opt-in, no new dependency, no new MCP server. *(Token/cost budget is
  best-effort in v1 — a plain `/loop` doesn't expose token spend; wall-clock + iteration cap
  carry the budget guarantee.)*

## Phase 5 — Multi-agent orchestration  ⬅ next
- Lead / worker fan-out with file-ownership locking (one writer per file).
- Task decomposition by file / module / pipeline stage; parallel where independent.
- **Adds:** an orchestrator skill coordinating multiple agents with explicit contracts.

## Phase 6 — Computer-use agents
- Browser / GUI automation (Playwright/Chrome) folded into `/verify` and beyond.
- Agents that operate real interfaces, not just code.
- **Adds:** computer-use tooling + safety scoping.

---

**Principle:** prove each phase in isolation before promoting it to default, and keep the
base lean — each new phase is a module you can enable, not a rewrite.
