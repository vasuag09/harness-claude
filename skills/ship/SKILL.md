---
name: ship
description: Final pre-merge step — sync docs, then prepare a clean commit/PR summary. Use after verify passes. Does NOT commit or push unless you explicitly ask; it prepares everything and stops.
---

# /ship — docs sync & merge prep

Goal: leave the change merge-ready, with docs in sync and a clear summary — without
performing git actions you didn't ask for.

## Do this
1. **Docs sync** — update READMEs, inline docs, codemaps, and any spec/ADR the change
   affected. Remove stale references. Keep docs lean and accurate.
2. **Change summary** — assemble from the full diff (`git diff <base>...HEAD`), not just
   the last edit:
   ```
   ## Summary — what & why
   ## Changes (grouped by area)
   ## Test plan — how it was verified (link the /verify evidence)
   ## Risks / follow-ups
   ```
3. **CI readiness** — confirm build, types, lint, tests are green locally; no secrets,
   no debug logs, no `--no-verify`.

## Git boundary (important)
Do **not** run `git commit`, `git push`, branch, or open a PR unless the user explicitly
asks. Prepare the message and report "ready to commit/PR — say the word." If asked,
follow conventional-commit format and push with `-u` for new branches.

## Exit criterion
Docs synced, summary drafted, checks green. Awaiting the user's go for any git action.
