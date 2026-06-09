# harness-claude — Evolution Roadmap

The base harness is **phase 1**. It is deliberately built to extend toward the later
phases without rework. Each phase builds on the previous one's primitives.

## Phase 1 — Subagents  ✅ (this release)
- Scoped subagents (planner, architect, reviewers, tdd-guide, resolvers, cleaner).
- Two orchestration modes: sequential phases (default) + iterative retrieval (≤3 cycles).
- Token optimization via cheapest-sufficient-model delegation + summary returns.
- Memory persistence (session files + PreCompact/Stop/SessionStart hooks).
- **Exit criteria:** a real task runs end-to-end through the pipeline and produces
  production-grade output in isolation.

## Phase 2 — Evaluation loops
- Checkpoint evals (verify against criteria, fix before proceeding) and continuous evals
  (full suite + lint on an interval / after major changes).
- Benchmarking harness: fork + worktree + diff, with vs. without a component; report
  pass@k (need it to work once) and pass^k (need consistency).
- Turn the Stop "candidate pattern" seed into a real extract-and-evaluate flow.
- **Adds:** an `eval/` module + `/eval` skill + a benchmark agent.

## Phase 3 — Retrieval systems
- Codemaps + semantic search over the codebase (graph-backed) to cut exploration tokens.
- RAG over docs/specs/ADRs; retrieval feeds the planner and reviewers.
- **Adds:** retrieval skills/agents + an index the pipeline consults before exploring.

## Phase 4 — Long-running agents
- Autonomous loops (`/loop`-style), background tasks, scheduled runs.
- Self-checkpointing against the eval loops from phase 2 so a long run can't silently drift.
- **Adds:** loop-operator agent + durable state + guardrails.

## Phase 5 — Multi-agent orchestration
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
