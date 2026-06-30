---
name: orchestrate
description: Decompose a multi-file task, fan out to parallel workers, and reconcile their results — with a one-writer-per-file guarantee. The third orchestration mode (parallel fan-out) alongside sequential and iterative-retrieval. Rides the platform Workflow tool as the engine; the skill is the lead — it splits the work, assigns disjoint file-ownership, dispatches workers under explicit contracts, and merges their summaries. Opt-in; not wired into the default pipeline. Use when a task spans 3+ independent files with no data dependency between them.
---

# /orchestrate — split the work, fan out, reconcile

Goal: take a task that spans many **independent** files and do it in parallel without two
workers ever clobbering the same file. This skill is the *discipline layer*: the platform
**Workflow tool** is the engine (`parallel()`/`pipeline()` + `agent(prompt, {schema})`); `/harness-claude:orchestrate`
is the **lead** — it decomposes the task, assigns one writer per file, dispatches workers
under explicit contracts, and reconciles their structured summaries into one result.

> **Opt-in.** No default-pipeline skill or hook fans out. Parallel orchestration is always
> explicit. **Git boundary:** a run never commits, pushes, or branches unless you explicitly
> arm it in the objective. **Token discipline:** workers return *summaries, not raw dumps*
> (per `rules/agents.md`).

This is the parallel-fan-out mode from `rules/agents.md`. Reach for it only when the work is
genuinely splittable: **3+ files, disjoint write-sets, no dependency between subtasks.** If
subtasks must read each other's output, that's sequential or iterative — not this.

## How it works
```
decompose  →  assign owners  →  verify disjointness  →  fan out (Workflow)  →  reconcile
```
1. **Decompose** the task into subtasks, each scoped to a set of files it will *write*.
2. **Assign owners** — every writable file belongs to exactly one subtask.
3. **Verify disjointness** — across any workers that run concurrently, the write-sets must be
   pairwise disjoint. If two would write the same file, **refuse to fan out** and name the file.
4. **Fan out** the independent subtasks via the Workflow tool; sequence the dependent ones.
5. **Reconcile** the workers' structured summaries into one result; surface conflicts/failures.

## Do this
1. **Write the decomposition plan** before dispatching. For each subtask: a one-line goal, its
   **owned files** (the only files it may write), its **read-only files**, and its tool scope
   (Read always; Write/Edit/Bash only over owned files). Brief each worker from
   `worker-contract.md` — one filled instance per subtask.
2. **Run the disjointness check.** List the union of all write-sets for the workers in a given
   parallel batch. If any file appears in two sets, stop and report the conflict; either
   re-partition so owners are disjoint, or sequence the conflicting workers into different
   batches. Only fan out once write-sets are pairwise disjoint.
3. **Dispatch via the Workflow tool.** Independent subtasks → one `parallel()` batch (a barrier:
   it awaits all workers and returns their results together). Use `pipeline()` only when items
   flow independently through stages — it has **no barrier** between stages (each item proceeds
   as it's ready), so don't expect it to synchronize all items before the next stage. Each worker
   is one `agent(prompt, {schema})` call: pass the contract as the prompt, force a structured
   summary via `schema`. Pass any context as real JSON in `args` (never a stringified blob). Size
   the batch to the task — concurrency caps at ~`min(16, cores−2)`; excess just queues, so don't
   fan out blindly. *(If a stage is an external script rather than an inline `agent()` call, it
   needs the platform's pure-literal `export const meta = {…}` header.)*
4. **Reconcile on completion.** The Workflow tool runs in the **background** and returns a task
   id; reconcile when it reports done — never assume a synchronous return. Collect every worker's
   summary, merge into one result, and **surface any failed or null worker** (a thrown stage
   resolves to `null`) — never silently drop one. Handle a bad return by its **failure mode**
   (`rules/agents.md` → "When a delegate comes back wrong"): retry the missing slice, escalate,
   or surface — don't treat a null, a partial, and a contradiction the same way. For each worker, verify
   `files_written ⊆ files_planned`; flag any worker that wrote outside its owned set as a
   contract violation (this is the enforcement arm of the one-writer guarantee). This audit is
   **detective, not preventive** — an escaped write has already landed by the time it's caught,
   so the remediation is to **revert the offending write**, not merely report it.

## The one-writer-per-file guarantee (assignment-by-plan)
Ownership is enforced **by the plan**, not by isolation: because each concurrent worker writes a
disjoint set of files, collisions are impossible by construction. The disjointness check ("Do
this" step 2) is the gate that makes this hold — it is mandatory before every `parallel()` batch,
and the reconcile-time `files_written ⊆ files_planned` audit (step 4) catches any worker that
escaped its owned set.

> **Escape hatch only:** if you genuinely cannot guarantee disjoint write-sets (e.g. workers must
> touch overlapping files), dispatch the colliding workers with the Workflow tool's
> `isolation:'worktree'` so each edits a private copy, then merge. **The lead merges sequentially
> and surfaces any conflicting hunk — never auto-resolve overlapping edits** (a blind merge of two
> private copies touching the same file silently loses one side). This is the exception, not the
> default — prefer re-partitioning into disjoint owners first.

## Worker contracts
Every worker is dispatched under an explicit contract (`worker-contract.md`): **one** clear input,
a minimum tool scope, an ownership boundary (its owned files — the *only* files it may write), and
a required **structured-summary** output (what changed, files written vs. planned, conflicts/
failures — not a raw dump). A worker that cannot finish without writing outside its owned set must
**surface the conflict, not silently expand scope**.

## Security & trust
- Workers run with your privileges and can edit files in their owned set — scope each to the
  minimum tools its subtask needs (read-only unless it owns a writable file).
- **Git boundary holds:** no worker and no reconcile step commits/pushes/branches unless the
  objective explicitly arms it.

## Notes
- Self-contained: a skill + the `worker-contract.md` template + the existing platform Workflow
  tool. **No new dependency, no new MCP server, no new runtime.**
- The skill *is* the lead — there is no separate orchestrator agent (the lead logic lives here,
  the same way `/harness-claude:operate` owns its own loop).
- Distinct from the `/harness-claude:harness*` orchestrators, which *sequence* SDLC phase skills;
  this decomposes one arbitrary task across parallel writers.

## Exit criterion
A decomposition was written, the disjointness check passed (or refused, naming the conflict),
independent subtasks ran in parallel, and every worker's summary was reconciled into one result
with failures surfaced — never a fan-out left with a silent collision or a dropped worker.
