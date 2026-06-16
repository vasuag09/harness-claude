---
name: ship
description: Final pre-merge step — sync docs, then prepare a clean commit/PR summary. Use after verify passes. Does NOT commit or push unless you explicitly ask; it prepares everything and stops.
---

# /ship — docs sync & merge prep

Goal: leave the change merge-ready, with docs in sync and a clear summary — without
performing git actions you didn't ask for.

## Do this
1. **Docs sync** — update **every** doc the change touches, not just the spec. Remove stale
   references; keep docs lean and accurate. For a release, run this sweep **before** committing:
   - **README.md** — skill/agent counts and any feature tables (the headline count must include
     newly added skills).
   - **ROADMAP.md** — phase status markers (🔄→✅), the per-version checklist line, and the
     "next" marker on the following phase.
   - **`.claude-plugin/plugin.json` + `marketplace.json`** — version **and** the skill/agent
     count in the marketplace description.
   - **CLAUDE.md** — skill lists / opt-in notes; **docs/HOOKS.md** — only if a hook changed.
   - The relevant **spec** status (and the parent spec's AC checkboxes).
   - Reconcile counts to the true `ls skills/` total. (Skipping this shipped wrong counts in
     v0.7.0 — README/marketplace went stale and were fixed only after the push.)
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
