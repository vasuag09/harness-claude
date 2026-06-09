# TypeScript / JavaScript Rules

Stack: TypeScript, React, Next.js (App Router), Vercel.

## Type safety

- `strict` on. No `any` — use `unknown` + narrowing, generics, or a precise type.
- Type at boundaries (API, forms, env) with **zod**; infer internal types from schemas.
- Prefer `type`/`interface` over inline shapes repeated across files.
- No non-null `!` assertions to silence the compiler — handle the null case.

## Async correctness

- Always `await` or explicitly handle promises; no floating promises.
- Wrap awaited I/O in try/catch with meaningful errors.
- Parallelize independent awaits with `Promise.all`; avoid request waterfalls.

## React / Next

- Server Components by default; `"use client"` only when you need interactivity/state.
- Keep components small and presentational; push data-loading to the edges.
- Stable keys (never array index for dynamic lists). Clean up effects.
- Don't duplicate server state into client stores — derive it.
- Persist shareable UI state (filters, tab, pagination) in the URL.

## Vercel / Next platform notes

- Node.js runtime via Fluid Compute is the default; avoid edge-only assumptions.
- Prefer AI Gateway `"provider/model"` strings over provider-specific SDKs unless
  direct wiring is explicitly required.
- Explicit `width`/`height` on images; `fetchpriority="high"` for hero media only.

## Formatting & hygiene

- Prettier is authoritative (the format hook runs it on save).
- `tsc --noEmit` must pass (the typecheck hook runs it on `.ts/.tsx` edits).
- No `console.log` in committed code.
