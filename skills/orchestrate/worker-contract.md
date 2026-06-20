# Worker contract template

One filled instance **per subtask**. The lead (`/harness-claude:orchestrate`) writes these,
then dispatches each as one Workflow-tool `agent(prompt, {schema})` call. The contract is the
worker's entire brief — it must be complete enough to execute cold, with no shared context.

## Template

```
### Worker <n>: <one-line goal>

- Input:        <the task for this worker + any context to pass as Workflow `args` (real JSON, not a string)>
                <never put secrets/credentials in `args` (it may be logged/persisted) — pass references (env var names, paths), not values>
- Owned files:  <the ONLY files this worker may write — must be disjoint from every other concurrent worker>
- Read-only:    <files it may read but must not write>
- Tool scope:   Read (always); Write/Edit/Bash ONLY over Owned files; nothing else
- Output:       a structured summary (see schema below) — NOT a raw file dump
- Escalation:   if the goal cannot be met without writing a file outside Owned files,
                STOP and surface the conflict; never silently expand scope
```

## Output schema (force via the Workflow `agent` `schema` option)

Every worker returns the same shape so the lead can reconcile typed results:

```
{
  "subtask":        string,        // which worker this is
  "status":         "done" | "blocked" | "failed",
  "files_written":  string[],      // files actually changed
  "files_planned":  string[],      // files it was assigned (Owned files)
  "summary":        string,        // what changed, in 1-3 sentences
  "conflicts":      string[]       // ownership/scope conflicts hit (empty if none)
}
```

The lead reconciles by checking `files_written ⊆ files_planned` for each worker (a worker that
wrote outside its owned set is a contract violation), collecting summaries, and surfacing any
`status != "done"` or non-empty `conflicts` — never dropping a failed or `null` worker.

## Worked example — a 2-worker fan-out

*(Two workers shown for brevity; in practice reach for `/harness-claude:orchestrate` only when a
task genuinely spans 3+ independent files — below that, the fan-out overhead rarely pays off.)*

Task: *"Add a `summary` field to the front-matter of `skills/spec/SKILL.md` and
`skills/plan/SKILL.md`."* Two files, disjoint, no dependency → one parallel batch.

```
### Worker 1: add summary front-matter to the spec skill
- Input:        Add a `summary:` field to the YAML front-matter of skills/spec/SKILL.md,
                value derived from its existing description.
- Owned files:  [skills/spec/SKILL.md]
- Read-only:    []
- Tool scope:   Read, Edit (over skills/spec/SKILL.md only)
- Output:       structured summary per schema
- Escalation:   surface if the front-matter block is malformed; do not touch plan's file

### Worker 2: add summary front-matter to the plan skill
- Input:        Add a `summary:` field to the YAML front-matter of skills/plan/SKILL.md,
                value derived from its existing description.
- Owned files:  [skills/plan/SKILL.md]
- Read-only:    []
- Tool scope:   Read, Edit (over skills/plan/SKILL.md only)
- Output:       structured summary per schema
- Escalation:   surface if the front-matter block is malformed; do not touch spec's file
```

Disjointness check: write-sets `{skills/spec/SKILL.md}` and `{skills/plan/SKILL.md}` are
disjoint → safe to run as one `parallel()` batch.
