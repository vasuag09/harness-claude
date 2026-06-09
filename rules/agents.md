# Subagent Strategy & Token Optimization

How the orchestrator (main Claude) delegates, and how this harness keeps token cost
and context rot low.

## Token optimization — primary lever: subagent architecture

Delegate sub-tasks to the **cheapest model sufficient** for the task, and have
subagents **return summaries, not raw dumps**. The orchestrator's context stays lean,
which cuts both token cost and context rot. This is the always-on strategy.

| Task type | Model |
|-----------|-------|
| Exploration / search / simple single-file edits | Haiku |
| Multi-file implementation, code review, most coding | Sonnet |
| Architecture, security analysis, debugging hard bugs, first attempt failed | Opus |

Default to Sonnet for ~90% of coding. Escalate to Opus when the task spans 5+ files,
is architecturally load-bearing, is security-critical, or the first attempt failed.

> **Benchmarking is a separate, complementary tool — not the day-one token strategy.**
> Use it to *measure* whether a skill/agent earns its keep (fork + worktree + diff,
> with vs. without the component, pass@k / pass^k). It belongs to the future
> "evaluation loops" phase, not to runtime token reduction. See ROADMAP.md.

## Two orchestration modes — choose by use case

### Sequential phases (default)
For linear, well-scoped work. The pipeline itself is the canonical example:

```
RESEARCH → PLAN → IMPLEMENT → REVIEW → VERIFY
```

Rules:
1. Each agent gets **one clear input**, produces **one clear output**.
2. Outputs become the next phase's input; store intermediates in files.
3. Don't skip phases. Compact/clear between heavy phases.

### Iterative retrieval (when a return is insufficient)
For exploratory/uncertain tasks where the first answer likely misses the *purpose*:

1. Orchestrator evaluates the subagent's return against the real objective.
2. If insufficient/ambiguous, ask a focused follow-up.
3. Subagent goes back to source, returns refined answer.
4. Loop **≤ 3 cycles**, then accept or escalate.

**Key:** pass the subagent the *objective/purpose*, not just the literal query — it
lacks the orchestrator's semantic context.

### Decision rule
- Linear, scope clear, output shape known → **sequential**.
- Open-ended research, ambiguous result, "find out X then decide" → **iterative**.
- A phase may use both: sequential overall, iterative within a research step.

## Scoping

Give each agent the minimum tool set it needs. Reviewers are read-only; resolvers may
edit. Never grant an agent more reach than its job requires.
