# Design review bar & slop tells

The harness's standard for the `/harness-claude:design-review` gate (VERIFY) — the approval bar
and the machine-made tells. **Judge by default — report findings + verdict; rebuild only when asked.**

## The bar
Not "does it render / align." The bar is **"would a senior design lead put their name on this?"**
Most generated UI is *correct* (renders, aligns, no clashes) and *not crafted* (nothing decided,
flat hierarchy, looks like every other app). Pull it from correct toward crafted. Review against
the design's **own intent** (the `/harness-claude:design` brief, and a saved design-system note if
the project keeps one) — a deliberately dense terminal isn't failing for being dense.

## How to run it
1. **Scope & intent** — bound what's under review; read the design brief; infer intended user/task/feel.
2. **See the whole first** (squint, before line-picking): does one thing lead, or is it a parking
   lot? Does it breathe, or is it a monotone grid? Does it look like *this* product? The worst
   slop is compositional — invisible in any single line of CSS.
3. **Run the lenses independently** (decide-or-default per lens):
   - **A · Hierarchy** (highest value) — focal element actually wins? rest *demoted*? tiers legible without reading?
   - **B · Type & color** — size+weight+color (not size alone)? real ratio scale? four-step text ramp? one accent ~60/30/10, motivated? one hue shifting lightness? `tabular-nums` on updating numbers?
   - **C · Surfaces & depth** — whisper-quiet elevation? low-opacity findable borders? one committed depth strategy? concentric nested radii? sidebar same-canvas?
   - **D · Composition & rhythm** — breathes unevenly? proportions state a relationship?
   - **E · States, polish, motion** — all interaction + data states present? 44px hit areas? sub-300ms custom ease-out, never `ease-in`? press feedback? only `transform`/`opacity`?
   - **F · Structure, reuse, content** — hand-rolled what the platform/project provides (`<div onClick>`, from-scratch dropdown w/o keyboard/ARIA, duplicated utility string, hardcoded literals vs tokens)? structural hacks (negative margins undoing padding, escape-hatch `calc()`, absolute-position dodges)? content coherent?

## Severity
- **Blocker** — reads as generic or broken: no focal point, flat hierarchy, monotone layout,
  timid/competing palette, missing states, structural hacks, inaccessible hand-rolled control.
- **Should-fix** — a real craft gap a lead would call out, but it functions (slack tracking, one harsh border, one inconsistent radius).
- **Note** — minor; mention once.

## Filter out false positives (this is half the job)
Not findings: **taste** ("I'd have picked another font") · a **bold choice working as intended** ·
anything **outside scope / on untouched lines** · anything the project's **design system already
ratifies** · **lint/format/compile** concerns. If you can't say *why it costs the user or reads as
generated*, it's taste — cut it. A few high-conviction findings beat forty nitpicks.

## Verdict — presumptive blockers
Any one present → **not approved** (unless justified against intent): no focal point · size-only or
defaulted typography · monotone layout · timid/competing-accent palette · harsh/fragmented surfaces ·
missing states · structural hacks · an inaccessible hand-rolled control where a primitive/existing
component should be used · any a11y/touch floor failure. For each finding give: **what defaulted**,
**why it costs the user / reads generic**, the **specific crafted fix** (the decision, not a patch).

## Deslop mode (fast, surgical, behavior-preserving)
When the ask is "make it stop looking generated" (not a full review): **Pass 1 squint** the
rendered output for the top tells (no focal point → flat hierarchy → monotone layout → timid color
→ borders doing the work of space); **Pass 2 scan the diff** for line-level tells (generic token
names, size-only type, harsh borders, missing states, off-grid spacing, reinvention). Stay in the
diff; don't flatten intent; a fix that becomes a rebuild is a full review job — flag it, don't do it.
