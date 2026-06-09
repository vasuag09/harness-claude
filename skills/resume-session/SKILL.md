---
name: resume-session
description: Load the most recent session file and re-establish context at the start of a new session. Use when continuing multi-session work. Pairs with /save-session.
---

# /resume-session — pick up where you left off

Goal: restore working context cheaply, without re-exploring.

## Do this
1. Find the latest session file:
   - `.claude/sessions/` in the repo, else `~/.claude/harness-claude/sessions/`.
   - Pick the most recent by date; offer the user the last few if several exist.
2. Read it and **restate**: the objective, what's verified-working, what failed (avoid
   repeating those dead ends), and the concrete next steps.
3. Re-orient against current reality: quickly confirm the repo state still matches the
   file (branch, key files) — flag drift before acting on stale notes.
4. Propose the immediate next action from "remaining," and confirm with the user.

## Note
The SessionStart hook surfaces a pointer to the latest session file automatically; this
skill is the full, deliberate restore. Treat the file as *what was true when written* —
verify before trusting specifics (files/flags may have changed).
