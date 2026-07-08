<!--
  Evidence doc for humans evaluating the project. Not a skill; not loaded into agent context.
-->

# Benchmarks — what shipped, what got killed, and the receipts

Most agent-workflow repos ship features because they *seem* useful. This harness ships an
optimization only if it **beats a measured baseline on cost-per-successful-task at held
consistency (pass^k)** — and records the kill honestly when it doesn't. Four experiments
have run through that gate. Two died. This page is the summary; each links to the full
spec with the raw numbers.

## The gate

- **Metric:** cost per *successful* task — a cheap failure is not a win.
- **Consistency:** pass^k (all k trials must pass), k ≥ 3, so a lucky run can't ship a feature.
- **Baseline:** the harness *without* the candidate component — for later experiments the
  baseline already includes the harness's own rules, so the number is the **marginal** lift,
  not an inflated vs-bare-agent number.
- **Apparatus:** fork + isolated worktree + identical prompts, with vs. without the
  component; verdict scripts are offline-tested and retained even for killed features, so
  every verdict is reproducible.

## Results

| # | Candidate | Verdict | Why |
|---|-----------|---------|-----|
| 1 | **Input-compression proxy** (wire-level, compresses what's fed to the model) | 🔴 **KILLED** | Compressing the prompt broke Claude Code's cache economics — invalidating the cached prefix cost more than the compression saved. Cache-mode confirmed the mechanism: removing the cache-break returned cacheCreation to baseline. Net dollar **loss**. |
| 2 | **Code-graph MCP** (a popular ~51k★ structural-index server) | 🔴 **KILLED** | A fixed per-session context tax (~80k cache-creation tokens ≈ $0.9/session from tool schemas alone). On a normal-sized repo that tax is ~5× the entire task cost — it cannot net positive regardless of retrieval quality. A near-zero-tax hook replacement shipped instead (#4). |
| 3 | **`/lazy` generation reduction** ("build the minimum that works") | 🟢 **SHIPPED, always-on** | k=3, Opus/Sonnet, baseline = harness rules already on: **output tokens −35%, LOC −23%, tool-calls 4.0 vs 5.0, accuracy held 3/3 both arms.** The lever fires consistently across trials. |
| 4 | **Structural-orientation hook** (lightweight local code index) | 🟢 **SHIPPED, with a caveat** | Cache-creation parity → no context tax (fixes exactly what killed #2). It's a large-repo bet not yet benchmarked at scale — no harm measured on small repos, but not a proven win there either. |

## The honest caveats (read these before quoting the wins)

- **−35% output ≠ −35% dollars.** On the pilot task, cost was dominated by cached input
  (cacheRead ~614k + cacheCreate ~175k vs ~5k output tokens), so the measured dollar delta
  was only ~−3% — within n=3 noise. The output cut moves real money only on output-heavy
  work. The robust, consistent signals are mechanism-level: fewer output tokens, fewer
  lines, fewer turns.
- **Small corpus.** The GO verdict for #3 came from one over-build-prone feature task at
  k=3 (~$5 of trials). Corpus-widening before stronger claims is recorded as owed, not done.
- **#4 is a directional bet**, shipped because it provably does no harm where #2 did —
  not because it has a measured win yet.

## Why publish the kills?

Because the kills are the point. Anyone can publish two green numbers; the gate only means
something if a null or negative result actually stops a feature. The killed experiments'
apparatus and raw verdicts are retained in-repo as the reproducible record:

- [phase-3-layer1-observation-compression.md](./specs/phase-3-layer1-observation-compression.md) — the proxy kill
- [phase-3-layer2-codegraph.md](./specs/phase-3-layer2-codegraph.md) — the MCP kill (context-tax verdict + retained apparatus)
- [phase-3-layer2-codebase-memory.md](./specs/phase-3-layer2-codebase-memory.md) — the hook replacement that shipped instead
- [phase-3-layer3-generation-reduction.md](./specs/phase-3-layer3-generation-reduction.md) — the `/lazy` GO, with raw trial rows
- [v0.8-benchmark-evidence.md](./specs/v0.8-benchmark-evidence.md) — the benchmark apparatus itself

Run it yourself: `/benchmark` measures any component's marginal value the same way
(fork + worktree + with/without + pass@k / pass^k).
