# Git Rules — branching, commits, merge discipline

Researched conventions (GitHub Flow · Conventional Branch v1.1.0 · Conventional Commits
v1.0.0) so every project the harness touches stays maintainable. Two layers: the
**conventions** (defaults below — apply them) and the **boundary** (absolute).

## The boundary (absolute)

- **Never `git commit` or `git push` without an explicit user ask.** No exceptions — not
  as a "checkpoint", not inside a long run, not from a worker.
- Branch **creation** is *not* gated: a local feature branch is cheap, reversible, and
  **expected** for non-trivial work (see "When to branch").
- Never force-push or rebase a shared/pushed branch. Never delete branches unasked.

## Detect and follow — adopt, don't impose

Before applying the defaults, detect the project's own conventions and follow those:

1. **Stated conventions win** — `CONTRIBUTING.md`, `docs/`, PR templates.
2. **Commit style** — scan the last ~50 `git log --oneline` subjects; ≥70% Conventional
   Commits → enforce it; otherwise mirror the observed style.
3. **Branch scheme** — existing prefixes (`feature/...`, ticket ids) → match them.
4. **`develop` / `release/*` present** → the project runs Git Flow; follow it (the one
   case Git Flow is still right: explicitly versioned software with concurrent releases —
   its own author says so: https://nvie.com/posts/a-successful-git-branching-model/).
5. **Tooling config** — commitlint / semantic-release / changesets → obey their rules.

Only when nothing is detectable, use the defaults below.

## Branching model (default: GitHub Flow)

Short-lived branches off an always-releasable default branch; PR; merge; delete the
branch. (https://docs.github.com/en/get-started/using-github/github-flow)

- **Never work directly on `main` / `master` / `develop`.**
- One branch per task/spec. Trivial follow-up tweaks may ride the open task branch —
  never the default branch.
- Branch from an up-to-date default branch; delete after merge.

## When to branch (branch-at-first-write)

At the first file write of non-trivial work (`/implement`, `/fix`):

1. `git rev-parse --is-inside-work-tree` fails → not a git repo; skip silently.
2. Already on a non-default branch → keep working there; don't re-branch.
3. On the default branch (`main`/`master`/`develop`, or whatever
   `git symbolic-ref refs/remotes/origin/HEAD` resolves to) → create the
   convention-named branch **before** the first edit.

For `/orchestrate` fan-outs, the **lead** creates **one** shared branch for the whole
task before dispatching workers — never one branch per worker. Read-only skills
(discover, observe, health, reviews) never branch — nothing to write.

## Branch naming (default: Conventional Branch v1.1.0)

`claude/<type>-<slug>` — the `claude/` prefix marks agent-authored branches
(standardized in v1.1.0: https://conventionalbranch.org/).

- `<type>` ∈ `feat | fix | chore | docs | refactor`.
- `<slug>`: lowercase, hyphens, ≤5 words — reuse the planning slug when one exists.
- Project uses ticket ids → include them: `claude/feat-123-login-form`.
- Project already has human prefixes (`feature/...`) → match those instead; commit
  attribution carries provenance.

## Commits (default: Conventional Commits v1.0.0)

`type(scope): imperative subject ≤72 chars` — types `feat | fix | build | chore | ci |
docs | style | refactor | perf | test`; breaking changes marked `!` after type/scope or a
`BREAKING CHANGE:` footer. Maps directly to SemVer (fix→patch, feat→minor,
breaking→major), which is what powers changelog/release automation.
(https://www.conventionalcommits.org/en/v1.0.0/)

- Small, self-contained commits — they double as recovery checkpoints for agent work.
- Don't police bodies; the enforceable subset is type + optional scope + subject + `!`.

## PRs & merging

- **Small diffs**: ~100 changed lines is a good change; ≳400 → split it; ~1000 is too
  large. One self-contained change per PR.
  (https://google.github.io/eng-practices/review/developer/small-cls.html)
- **Draft until verify passes**; ready-for-review only after the Verify phase.
- **Squash-merge by default** — one clean conventional commit on the default branch
  (ideal for agent trial-and-error histories). Merge-commit only when the project's own
  history shows non-squash merges; rebase-merge only where the project curates commits.
  (https://docs.github.com/articles/about-pull-request-merges)
- Recommend branch protection on the default branch (require PR + CI) — but never
  configure it unasked.
