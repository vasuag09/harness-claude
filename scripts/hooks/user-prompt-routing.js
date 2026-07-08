#!/usr/bin/env node
// UserPromptSubmit: re-inject the request→skill routing line so pipeline discipline
// survives mid-session and on installed projects (where rules/*.md never load).
// No-ops for slash-command prompts (the user already picked a skill) and under
// ROUTING_DISABLE=1. Failure-isolated: any error → exit 0, no output — never blocks
// a prompt.
'use strict';
try {
  if (process.env.ROUTING_DISABLE === '1') process.exit(0);
  const { readInput, ROUTING_TABLE } = require('./_lib.js');
  const prompt = String(readInput().prompt || '').trim();
  if (!prompt || prompt.startsWith('/')) process.exit(0);
  process.stdout.write(`[harness-claude] ${ROUTING_TABLE}\n`);
} catch {}
process.exit(0);
