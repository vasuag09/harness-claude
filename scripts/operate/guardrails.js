#!/usr/bin/env node
// guardrails.js — pure halt-decision logic for a long-running agent run (Phase 4 / v0.10.0).
// Given a run-state object, decide whether the run must STOP and why. No I/O, no clock, no
// requires: a pure function so the operator (step.js) can call it at each checkpoint and the
// tests can drive it with literal states. The caller is responsible for refreshing the mutable
// fields (iteration, budget.spentWallClockMs, consecutiveFails) before evaluating.
//
// Halt reasons (priority order — first match wins):
//   1. 'drift'         consecutiveFails >= maxConsecutiveFails  (safety: the run is diverging)
//   2. 'budget'        spentWallClockMs >= maxWallClockMs OR spentTokens >= maxTokens
//   3. 'iteration-cap' iteration >= maxIterations
// Drift outranks the benign ceilings so a diverging run is reported as drift even if it also hit
// its iteration cap on the same step. Any cap left null/undefined is INERT — it never halts.
//
// lazy: no-progress halt (no measurable change across K iterations) is a recommended-optional
// guardrail deferred from v1 (see spec) — add a 'no-progress' branch here keyed off a
// caller-supplied change signal when it earns its keep.
'use strict';

// A cap is "armed" only when it is a finite, non-negative number. null/undefined/NaN/Infinity =>
// inert (never halts). NOTE: 0 is ARMED and means "halt immediately" — `--max-iterations 0`
// halts before any work, `--max-fails 0` halts on the first checkpoint, `--budget-ms 0` halts at
// once. 0 is not "off"; to disable a cap, omit it (leave it null).
function armed(n) {
  return typeof n === 'number' && Number.isFinite(n) && n >= 0;
}

// evaluateGuardrails(state) -> { halt: boolean, reason: 'drift'|'budget'|'iteration-cap'|null }
function evaluateGuardrails(state) {
  const s = state || {};
  const b = s.budget || {};

  if (armed(s.maxConsecutiveFails) && (s.consecutiveFails || 0) >= s.maxConsecutiveFails) {
    return { halt: true, reason: 'drift' };
  }
  if (armed(b.maxWallClockMs) && (b.spentWallClockMs || 0) >= b.maxWallClockMs) {
    return { halt: true, reason: 'budget' };
  }
  if (armed(b.maxTokens) && (b.spentTokens || 0) >= b.maxTokens) {
    return { halt: true, reason: 'budget' };
  }
  if (armed(s.maxIterations) && (s.iteration || 0) >= s.maxIterations) {
    return { halt: true, reason: 'iteration-cap' };
  }
  return { halt: false, reason: null };
}

module.exports = { evaluateGuardrails, armed };
