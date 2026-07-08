<!--
  Evaluation doc for humans choosing a setup. Not a skill; not loaded into agent context.
-->

# How harness-claude compares

If you're evaluating agent-workflow setups, you'll likely also look at
[agent-skills](https://github.com/addyosmani/agent-skills) (Addy Osmani),
[Superpowers](https://github.com/obra/superpowers) (Jesse Vincent), and
[Matt Pocock's skills](https://github.com/mattpocock/skills). All three are good. This page
maps how they're **shaped differently** — not which is "best" — so you can pick what fits,
or combine pieces deliberately.

> **TL;DR** — The other three are **prompt packs**: markdown workflows an agent reads.
> harness-claude is a **system**: the same lifecycle discipline *plus* runtime hooks that
> actually fire, scoped subagents with cheapest-sufficient model routing, durable
> cross-session state, and features that had to beat a measured baseline to ship. The cost
> of that depth is portability — harness-claude is Claude Code–native, while the packs
> travel across many agents.

## At a glance

| | **harness-claude** | **agent-skills** | **Superpowers** | **Matt Pocock's skills** |
|---|---|---|---|---|
| **Core idea** | Full-SDLC harness with runtime enforcement and measured features | Senior-engineering lifecycle encoded as skills | An autonomous development methodology on composable skills | One expert's daily `.claude` toolkit, open-sourced |
| **Enforcement** | Hooks that fire (format, typecheck, quality/design gates, routing, memory) + prompt discipline | Prompt discipline (anti-rationalization tables, red flags) | Prompt discipline + subagent isolation | Prompt discipline + git guardrails |
| **State across sessions** | Durable: `STATE.md` spine + per-phase planning artifacts + session narratives | Per-session | Per-session (worktree isolation within a run) | Per-session |
| **Subagents** | 8 scoped agents, cheapest-sufficient model routing, three orchestration modes (sequential / iterative / parallel fan-out) | 4 review personas, parallel at `/ship` | Central mechanism: fresh subagents + two-stage review | Not a focus |
| **Evidence** | Benchmark-gated: features beat a bare baseline on cost-per-successful-task or get killed ([BENCHMARKS.md](./BENCHMARKS.md)) | Cites Google eng-practice lineage; one third-party head-to-head | Anecdotal + methodology write-ups | Anecdotal (expert practice) |
| **Beyond the repo edge** | `/deploy` (arm-to-fire) + `/observe` (prod signal → repro → `/fix`) close the loop | Shipping/launch + observability skills (guidance) | Not a focus | Not a focus |
| **Portability** | Claude Code–native (plugin). Atomic skills are standard `SKILL.md` and install anywhere via `npx skills add`; hooks/agents/orchestrators don't travel | Multi-tool (Claude Code, Cursor, Gemini, Copilot, +) | Multi-tool | Claude Code–first |
| **Trust footprint** | Runs Node hook scripts locally (each documented + disableable in [HOOKS.md](./HOOKS.md)) | Markdown only | Markdown + scripts for some tools | Markdown only |

## When to pick which

- **harness-claude** — you live in Claude Code and want the discipline *enforced*, not
  suggested: gates that fire as hooks, work that survives context resets and session
  boundaries (STATE spine + planning artifacts), subagent fan-out with a
  one-writer-per-file guarantee, and a maintainer who kills features that don't measure
  out. Heaviest of the four; earns it on multi-session, real-codebase work.
- **agent-skills** — you want broad lifecycle coverage as portable markdown across many
  agents, with human checkpoints at each phase and well-crafted anti-rationalization
  guards. Lightest mental model of the four.
- **Superpowers** — you want to hand off long autonomous stretches and get back a
  two-stage-reviewed result; heavy upfront reasoning, worktree isolation.
- **Matt Pocock's skills** — you want a sharp, low-ceremony daily loop (requirement
  grilling, strict TDD) reflecting one excellent engineer's practice.

## Combining them

Cherry-picking individual *skills* across packs works — they're markdown. What doesn't
work is running two **routers** at once: competing meta-skills fight over command names
and philosophies. If you run harness-claude as your primary (its session-start routing +
pipeline is the router), pull in individual skills from the others à la carte rather than
installing a second framework wholesale.

*Spotted something unfair or out of date about another project here? Open an issue — this
page is only useful if it's honest.*
