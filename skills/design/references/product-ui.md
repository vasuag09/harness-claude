# Product-UI craft rubric

The harness's standard for **product interfaces** — dashboards, admin panels, SaaS apps,
tools, settings, data UIs. (For marketing/brand/landing surfaces use `aesthetic-direction.md`;
the accessibility floor in `ux-floor.md` applies to everything.)

## The bar
Generic isn't a style — it's the absence of decisions. If another tool given the same prompt
would produce substantially the same screen, the design failed. Every choice (layout, color
temperature, typeface, spacing, hierarchy) must have a stated *why*; "it's common" or "it works"
means a default was taken, not a decision made.

## Intent first (state before any code)
- **Who is the human?** The actual person — where they are, what they did 5 min before/after.
  A teacher at 7am ≠ a developer debugging at midnight.
- **What must they accomplish?** The verb. It decides what leads, what follows, what hides.
- **What should it feel like?** In words that carry meaning — "warm like a notebook," "cold
  like a terminal," "dense like a trading floor." Not "clean and modern."
- **Intent is systemic.** If "warm," then surfaces, text, borders, accents, type — all warm.
  Check every token against the stated intent.

## Domain exploration (do all four before proposing)
- **Domain** — 5+ concepts/metaphors/vocabulary from this product's world.
- **Color world** — 5+ colors that exist *naturally* in that world (picture the physical space).
- **Signature** — one element that could exist only for THIS product.
- **Rejected defaults** — 3 obvious choices you're deliberately not taking (you can't avoid a
  pattern you haven't named).
- *Check:* strip the product name from the proposal — could someone still tell what it's for?

## Visual hierarchy (the biggest "designed vs generated" driver)
- **One focal point per view.** Name it; make it win via size / weight / contrast / isolation;
  demote everything else on purpose. Equal competition reads as a parking lot.
- **Type scale is a ratio**, not sizes by feel: ~1.2 dense · ~1.25 product · ~1.333 expressive.
- **Weight + color carry more hierarchy than size.** One 14px size holds three tiers:
  `value 600/primary · label 500/secondary · meta 400/muted`. Build from all three levers together.
- **Density is a decision, expressed in px**, and held everywhere (12–16px tight; 24px airy).
- **Breathe unevenly** — group related things tightly, then put real air between groups. Uniform
  gap/size/density everywhere is the sound of no one deciding.
- **~60/30/10** — dominant neutral surface, secondary tone, ≤10% accent. One accent beats five.
- **Structure through space and weight, not lines** — reach for whitespace/tonal shift before borders.

## Depth & surfaces (quiet layering is the backbone)
- **Surface elevation** stacks in whisper-quiet steps (a few % lightness: base → +7% → +9% →
  +12% on dark; light mode adds soft shadow instead). Felt rather than seen.
- **Sidebars:** same canvas color + a subtle border — not a different-colored "sidebar world."
- **Inputs:** slightly *darker* than their surroundings (inset; they receive content).
- **Borders:** low-opacity rgba (dark ~`rgba(255,255,255,.06–.12)`), findable but not loud.
- **Pick ONE depth strategy and commit:** borders-only · subtle shadows · layered shadows ·
  surface-tints. Don't mix.
- **Squint check:** blur your eyes — hierarchy still readable, nothing jumping out harshly.

## Polish floor
- Concentric radius (`outer = inner + padding`). · `tabular-nums` on any dynamic number.
- Every interactive element: default / hover / active / focus / disabled. Data: loading /
  empty / error. Missing states are the fastest "unfinished" tell.
- `text-wrap: balance` on headings, `pretty` on body. · Optical alignment on icons.

## Motion (felt, not watched)
- Should it animate at all? 100+×/day actions → none. Occasional surfaces → standard. Rare → delight.
- Duration < 300ms. Custom ease-out `cubic-bezier(0.23,1,0.32,1)`, **never ease-in**.
- Press `scale(0.97)` on `:active`. Never animate from `scale(0)` — start `0.95` + `opacity:0`.
- Animate only `transform`/`opacity`. Never `transition: all`. Respect `prefers-reduced-motion`.

## Use what exists (don't hand-roll)
Native HTML → a battle-tested headless primitive (for select/combobox/dialog/popover/tabs) →
hand-roll only as a last resort (and then own full keyboard/focus/ARIA). Styling: design system
→ component → semantic token → utility. A `<div onClick>` or a from-scratch dropdown without
keyboard support is both slop *and* a bug.

## The four checks (before showing)
- **Sameness** — swap your typeface/layout for the obvious one: would anything feel different?
  Where it wouldn't, you defaulted.
- **Squint** — hierarchy survives the blur; nothing harsh.
- **Signature** — point to 5 specific elements where it shows ("the overall feel" doesn't count).
- **Tokens** — read your CSS variables aloud: do they belong to *this* product's world?
