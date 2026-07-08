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

## Phase 5 — Multi-agent orchestration  ✅ (complete, v0.11.0)
- ✅ `/orchestrate`: the third orchestration mode (parallel fan-out) alongside sequential and
  iterative-retrieval — decomposes a task spanning 3+ independent files and runs the pieces in
  parallel. Thin discipline layer over the platform Workflow tool (the engine), no new runtime.
- ✅ One writer per file by **assignment-by-plan**: the lead assigns disjoint write-sets and
  verifies pairwise disjointness before every parallel batch (refuses + names the conflict
  otherwise). `isolation:'worktree'` kept only as a documented escape hatch.
- ✅ Explicit worker contracts (one input, scoped tools, ownership boundary, structured-summary
  output) + reconciliation that surfaces failed/dropped workers rather than swallowing them.
- **Adds (v0.11.0):** `skills/orchestrate/{SKILL.md,worker-contract.md}`. No new agent (the
  skill is the lead), no new dependency, no new MCP server. Opt-in, off by default.
- **Wired in (v0.11.1):** `/implement` + `/harness-implement` now run a parallel-fan-out check —
  when a plan phase spans 3+ independent files with disjoint write-sets, they *offer*
  `/orchestrate` (opt-in; never auto-start a multi-agent run).

## Bug-fix fast lane (`/fix`)  ✅ (complete, v0.12.0)
- ✅ `/fix`: the parallel entry for fixing something **already broken** (a red test, a prod error,
  a reported defect) — the pipeline's front door is greenfield-shaped, so bugs get their own
  disciplined entry instead of being over-ceremonied through `/spec`.
- ✅ Discipline: **reproduce as a failing test FIRST** (capture the bug RED), name the **root
  cause** (not the symptom), write a **minimal** fix-plan (no refactor-while-you're-in-there).
- ✅ Reuse, don't rebuild: hands off to the existing pipeline (`/implement` → `/review` +
  `/security-review` → `/verify` → `/ship`); regression test via `tdd-guide`. Distinct from
  `/build-fix` (build/type errors, not behavioral bugs).
- **Adds (v0.12.0):** `skills/fix/SKILL.md`. No new agent (the skill is the lead), no new
  dependency, no new MCP server. Opt-in, off by default; git boundary holds.

## Release & feedback loop (`/deploy` + `/observe`)  ✅ (complete, v0.13.0)
- ✅ Closes the pipeline into a **loop** — it stopped at the repo edge (`/ship` prepares a commit/PR);
  these two opt-in skills bracket the live environment: `/ship → /deploy → (prod) → /observe → /fix → …`.
- ✅ `/deploy`: orchestrates the project's **own existing** deploy mechanism (detect `vercel.json` /
  `Dockerfile` / `Makefile` / CI / `package.json` scripts — never prescribe a stack; delegate to a
  matching platform skill like `vercel:deploy` when present), names the rollback path, runs pre-deploy
  smoke, then **arm-to-fire HALTs** — no real outward action until an explicit `arm deploy`. On arm it
  deploys in tmux, smoke-tests the **deployed** artifact (reusing `/health`), and guards a rollback
  (`arm rollback`) when that smoke fails. Deploy is more outward-facing than `git push`, so it extends
  the harness's boundary discipline rather than bypassing it.
- ✅ `/observe`: **bring-a-signal** triage — take a pasted stack trace / log / error / issue URL (no
  polling, no credentials, no new MCP), locate the failing area in code (mgrep/graph), shape a repro
  **seed**, and route to `/fix`. It does **not** write the finished failing test — that stays `/fix`'s
  reproduce-first step. Active monitoring (poll Sentry/Datadog) is a noted seam, deferred (YAGNI).
- **Adds (v0.13.0):** `skills/deploy/SKILL.md` + `skills/observe/SKILL.md`. No new agent (both skills
  are leads), no new dependency, no new MCP server, no new runtime. Opt-in, off by default; the git
  boundary and the new arm-to-fire boundary both hold.

## Discovery phase (`/discover`)  ✅ (complete, v0.14.0)
- ✅ Closes the one altitude the pipeline had nothing for — the step *above* `/spec`. The front door
  assumed you could already state *what* you want; `/discover` serves the vague itch where you don't yet
  know the shape of the answer ("make this better", "what would make the best use of X?").
- ✅ **Divergent→convergent** discipline: interrogate the real goal (Socratic, via focused questions) →
  map a **bounded** set of ≤5 grounded options → **force convergence to exactly one** recommended
  direction → hand a one-screen *intent statement* to `/spec`. The convergence is the point — it ends in
  a **decision, not a brainstorm**; an unranked option dump is an invalid exit.
- ✅ **Conditional & upstream:** an already-clear request is detected and routed straight to `/spec` with
  no interview (anti-ceremony, like the design gate). Strictly upstream of `/spec`/`/research`/`/design` —
  it produces the request; it does **not** write acceptance criteria (that stays `/spec`'s job).
- ✅ **Reuse, don't rebuild:** ports `prompt-optimizer`'s intake gate (clarify-if-vague) and `shape`'s
  interview→brief shape; the divergent→convergent core is the genuine new part nothing else covered.
- **Adds (v0.14.0):** `skills/discover/SKILL.md` (32→33 skills). No new agent (the skill is the lead),
  no new dependency, no new MCP server, no new runtime. Opt-in/conditional, off by default; read-only,
  git boundary holds. *(Wiring `/discover` into `/harness-plan` as a pre-step is a noted follow-up seam —
  shipped standalone first, mirroring how `/orchestrate` preceded its `/implement` wiring.)*

## Refinements (v0.14.1)  ✅
Ports from an external-review sweep (`msitarzewski/agency-agents`, SDLC subset) — technique only,
no agent files imported. Edits to existing prompts; **no new skill/agent/dependency/runtime**.
- **Tier-1 ports:** `/verify` adversarial default (NEEDS-WORK until evidence) · `/architect`
  design-time threat model (4 abuse Qs + trust boundaries, conditional) · `/security-review`
  regression-test-per-vuln · `/design-review` manual-AT protocol + WCAG-SC numbering · `/ship`
  Divio doc-types + run-every-example · `/research` build-vs-buy tie-breaker. (Agent mirrors:
  `architect.md`, `security-reviewer.md`.)
- **Tier-2 #2:** `rules/agents.md` gains a delegation **failure-mode table** (null/partial/
  contradiction/off-target/runaway/oversized) + a 3-rung fallback ladder; `/orchestrate` reconcile
  routes bad workers by mode. *Deliberately refused as over-engineering at our scale:* per-agent
  trace_id infra, context-budget math model, topology catalog, circuit-breaker code (already covered
  by Workflow ids / `/operate` guardrails / summaries-not-dumps).
- **Parked:** self-eval of skill/agent prompts (Tier-2 #1 — strongest structural gap, needs its own
  spec); perf-verification (Tier-2 #3 — irrelevant until a web project is dogfooded).

## Fix (v0.14.2)  ✅
Hook state-path bug. `scripts/hooks/_lib.js:stateDir` anchored `.claude/` to the hook's incoming
`cwd`; a hook running from a subdir (e.g. shell had `cd`'d into `skills/`) wrote a stray
`skills/.claude/`. Now resolves the git **repo root** (`git rev-parse --show-toplevel`) so all
state (sessions/traces/staging/eval/runs) lands at repo-root `.claude/` regardless of cwd.
Non-repo fallback to `~/.claude/harness-claude/` preserved. One function; no surface change.

## Fix (v0.14.3)  ✅
The parallel fan-out (`/orchestrate`) offer never fired. It was written as an optional aside
(*"offer"*) in `/implement` and `/harness-implement`, and the trigger (3+ independent files,
disjoint write-sets) was never actually evaluated — the main loop went straight to serial editing.
Prompt-only fix, scoped to the multi-agent offer (single-agent delegation left as-is):
- **`/plan`** now **detects and flags** parallelizable phases as `/orchestrate` candidates and
  carries the flag into its output, so the opportunity isn't forgotten downstream.
- **`/implement`** + **`/harness-implement`** turn the soft offer into a **mandatory pre-edit
  checkpoint**: when the trigger fires the fan-out option *must* be surfaced (with the file split).
- **Opt-in guardrail preserved:** surfacing the offer is mandatory-when-triggered, but *acting* on
  it stays opt-in — never a silent multi-agent run. No new skill/agent/dependency.

## Durable-state structural bones (v0.15.0)  ✅
Five structural additions that make the pipeline resumable and delegation-ready — kept prompt-only
+ light hooks, no engine. The unifying idea: durable file-system state is what lets a fresh-context
subagent work from a file instead of an accumulating conversation (the harness's answer to context
rot). **Also closes the parked Tier-2 #1** (self-eval of plans) as `/plan-check`.
- ✅ **STATE.md spine** — `.claude/STATE.md`: a small (<100-line) machine-navigable position file
  (frontmatter `phase`/`status`/`slug`/`next_skill`/`updated` over Verified/Blocked/Next). Read
  first on orient; patched on phase exit. The *index* above the freeform session narrative, not a
  replacement. `session-start` surfaces `next_skill`; the Stop hook refreshes `updated`;
  `/resume-session` reads it first and flags drift vs. the narrative.
- ✅ **Per-phase disk artifacts** — `.claude/planning/<slug>/`: `/spec`→`SPEC.md`, `/plan`→`PLAN.md`,
  `/verify`→`VERIFICATION.md`. Downstream steps (and subagents) read the file, not the chat. Trivial
  work skips them (lazy reflex).
- ✅ **`/plan-check` gate** — new 34th skill: adversarially reviews `PLAN.md` vs. `SPEC.md` (criteria
  coverage · scope creep · parallel-task write-set disjointness), delegates to the `planner` agent
  read-only, loops ≤3, non-blocking except Critical. Wired between `/plan` and `/implement` (incl.
  `/harness-plan`). Surfaced-mandatory, act-opt-in.
- ✅ **Dependency waves in `/orchestrate`** — tasks declare `depends_on`; the lead topologically groups
  them into waves (parallel within, sequential across), checks write-set disjointness per wave, and
  refuses a dependency cycle. Fully-independent sets collapse to one wave — backward compatible.
- ✅ **Coverage-matrix `/verify`** — acceptance criteria carry stable `AC-n` IDs (`/spec`); `/verify`
  emits an `AC-n` × evidence × pass/fail matrix and blocks the exit on any unaddressed/failing
  criterion.
- **Adds (v0.15.0):** `skills/plan-check/SKILL.md` (33→34 skills) + `docs/state-and-artifacts.md`;
  edits to `spec`/`plan`/`implement`/`verify`/`orchestrate`/`resume-session`/`harness-plan` skills and
  the `session-start`/`stop-session-summary` hooks + `_lib.js`. **No new agent, no new dependency, no
  new MCP server, no new runtime.** All additive — absent STATE/artifacts degrade to the old
  session-file behavior; the git boundary holds.

## Git conventions & pipeline routing (v0.16.0)  ✅
Field feedback from real multi-project use named two failures: feature work landed directly on
`main` (the blanket "never branch" boundary lumped cheap, reversible branch *creation* in with
commit/push), and pipeline discipline decayed after the first run (the routing lived in
`rules/*.md`, which never load on installed projects). Prompt-only + two small hooks:
- ✅ **`rules/git.md`** (8th rule) — researched policy: GitHub Flow, Conventional Branch v1.1.0
  naming (`claude/<type>-<slug>` agent prefix), Conventional Commits v1.0.0, ≲400-line
  draft-then-squash-merge PRs, and a **detect-and-follow heuristic** (the project's own
  conventions always win). Sources cited inline.
- ✅ **Boundary split** — reworded everywhere: `git commit`/`git push` stay absolutely gated
  behind an explicit user ask; **branch creation is expected** — `/implement` and `/fix` create
  `claude/feat|fix-<slug>` at first write; the `/orchestrate` lead makes one shared branch per
  fan-out (workers never branch). Read-only skills correctly still never branch.
- ✅ **Pipeline routing** — `session-start` now injects a request→skill routing *instruction*
  (feature→`/spec` · bug→`/fix` · vague→`/discover` · build error→`/build-fix` ·
  resume→`/resume-session`), and a new **`UserPromptSubmit` hook** re-injects it on every
  non-slash prompt so mid-session requests keep routing on any installed project
  (`ROUTING_DISABLE=1` to turn off; failure-isolated; never echoes user input).
- **Adds (v0.16.0):** `rules/git.md`, `scripts/hooks/user-prompt-routing.js`,
  `scripts/eval/test-user-prompt-routing-hook.sh` (32 assertions); edits to 10 skills/rules/docs +
  `_lib.js`/`session-start.js`/`hooks.json`. Also repaired 9 pre-existing bare skill refs that had
  broken `check-reference-integrity.sh` since v0.15.0. **No new agent, no new dependency.**

## Phase 6 — Computer-use agents  ⬅ next (re-scoped — see below)
**Scope correction.** The original framing — "browser/GUI automation (Playwright/Chrome) folded
into `/verify`" — does not earn its keep as written:
- The harness ships **no UI of its own** to verify; it's markdown + scripts. The only thing it
  could drive a browser *for* is a downstream project's UI — and that project brings its own
  Playwright/e2e tooling, so the harness would be duplicating what consumers already have.
- **Scripted browser automation is a solved, non-delta capability** (Playwright + an e2e-runner
  agent). The harness intentionally ships neither today; recommending Playwright in `rules/testing.md`
  is the right altitude for a distributable plugin.

**Genuine delta (the only part worth building).** Computer-use ≠ Playwright on two axes Playwright
can't reach: driving surfaces with **no DOM** (native desktop apps, Electron, canvas/WebGL, OS
dialogs) and **vision-based** targeting (click from a screenshot, no selectors). That is the slice
to reserve Phase 6 for — explicitly **not** re-implementing scripted browser automation.

- **Gate (YAGNI):** build only when a consuming project presents a real non-DOM / vision surface
  to verify. Until then this phase stays parked — no speculative tooling shipped.
- **Adds (if/when unblocked):** vision-based computer-use tooling + safety scoping, gated opt-in.

---

**Principle:** prove each phase in isolation before promoting it to default, and keep the
base lean — each new phase is a module you can enable, not a rewrite.
