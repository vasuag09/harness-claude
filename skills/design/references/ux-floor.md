# UX & accessibility floor

The harness's **cross-cutting quality floor** — applies to *every* surface (product UI,
marketing, and especially mobile/native), regardless of which craft rubric leads. Fix in
priority order 1→10. Items **1 and 2 are CRITICAL** — part of the harness's non-negotiable
accuracy floor; never trade them for brevity or aesthetics.

## 1 · Accessibility (CRITICAL)
- Contrast **4.5:1** normal text / 3:1 large. · Visible focus rings (2–4px) — never remove them.
- `alt` on meaningful images. · `aria-label` (web) / `accessibilityLabel` (native) on icon-only buttons.
- Tab order matches visual order; full keyboard support. · `<label for>` on inputs.
- Sequential headings h1→h6, no skips. · Never convey info by **color alone** (add icon/text).
- Respect `prefers-reduced-motion`. · Support system text scaling without truncation.
- Cancel/back escape routes in modals + multi-step flows.

## 2 · Touch & interaction (CRITICAL)
- Touch targets **44×44pt** (Apple) / 48×48dp (Material); extend hit area beyond visual bounds if smaller.
- ≥8px gap between targets. · Primary actions on tap/click — **never hover-only**.
- Disable buttons during async + show a spinner. · Visible press feedback (ripple/highlight/`scale`).
- Don't block system gestures (back-swipe, Control Center). · Keep targets clear of notch / gesture bar.

## 3 · Performance (HIGH — guards Core Web Vitals)
- WebP/AVIF, responsive `srcset`, lazy-load below-fold. · Declare `width/height` or `aspect-ratio` (**CLS < 0.1**).
- `font-display: swap`; preload only critical fonts. · Split code by route/feature; reserve space for async content.
- Virtualize lists 50+ items. · Per-frame work < ~16ms (60fps). · Skeletons over long blocking spinners (>1s).

## 4 · Style selection (HIGH)
Match style to product type; stay consistent; SVG icons not emoji; don't randomly mix flat & skeuomorphic.

## 5 · Layout & responsive (HIGH)
Mobile-first breakpoints; viewport meta; **no horizontal scroll**; no fixed-px container widths; never disable zoom.

## 6 · Typography & color (MEDIUM)
Base 16px body, line-height ~1.5; semantic color tokens (no raw hex in components); no body text < 12px; avoid gray-on-gray.

## 7 · Animation (MEDIUM)
150–300ms; motion conveys meaning (spatial continuity); animate `transform`/`opacity` not width/height; honor reduced-motion.

## 8 · Forms & feedback (MEDIUM)
Visible labels (not placeholder-only); error message near the field; helper text; progressive disclosure over upfront overwhelm.

## 9 · Navigation (HIGH)
Predictable back behavior; bottom nav ≤5 items; support deep links; don't overload nav.

## 10 · Charts & data (LOW)
Legends + tooltips; accessible colors; never rely on color alone to encode meaning.

---
**Decision rule:** if the task changes how a feature *looks, feels, moves, or is interacted
with*, this floor applies. Items 1–2 are non-negotiable.
