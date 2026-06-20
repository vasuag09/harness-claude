# Aesthetic-direction rubric

The harness's standard for **marketing / brand / landing / expressive** surfaces — hero pages,
campaigns, portfolios, brand sites. (For dense product UI use `product-ui.md`; the accessibility
floor in `ux-floor.md` applies to everything.)

## Stance
Design like the lead at a studio known for giving every client an identity that couldn't be
mistaken for anyone else's. The brief has already rejected templated work. Make deliberate,
opinionated choices specific to *this* subject — and take **one real aesthetic risk you can justify**.

## Ground it in the subject
If the brief doesn't pin down the subject, pin it yourself: name one concrete subject, its
audience, and the page's single job — and state the choice. Distinctive choices come from the
subject's own world: its materials, instruments, artifacts, vernacular. Build with the brief's
real content throughout, not lorem placeholder.

## Principles
- **The hero is a thesis.** Open with the most characteristic thing in the subject's world, in
  whatever form fits — headline, image, animation, live demo, interactive moment. A big number +
  small label + gradient accent is the *template* answer; use it only if it's genuinely best.
- **Typography carries personality.** Pair display + body deliberately (not your reflex families).
  Make the type treatment itself memorable, not a neutral delivery vehicle.
- **Structure is information.** Numbering / eyebrows / dividers must encode something true, not
  decorate. `01 / 02 / 03` only when the content actually is a sequence.
- **Motion deliberately.** One orchestrated moment usually lands harder than scattered effects.
  Often less is more — surplus animation reads as machine-made.
- **Match complexity to vision.** Maximalist needs elaborate execution; minimal needs precision in
  spacing, type, and detail. Elegance is executing the chosen vision well.

## Anti-default calibration
AI-generated design currently clusters in a few looks — treat these as defaults to avoid spending
free creative axes on, *not* as forbidden (use them only when the brief actually asks):
1. Warm cream background (~#F4F1EA) + high-contrast serif display + terracotta accent.
2. Near-black background + a single acid-green / vermilion accent.
3. Broadsheet layout — hairline rules, zero radius, dense newspaper columns.
They appear regardless of subject — that's the tell. Where the brief leaves an axis free, spend
that freedom on something the subject earns.

## Process: brainstorm → explore → plan → critique → build → critique again
1. **Compact token system** — Color (4–6 named hex), Type (display + body + utility face),
   Layout (prose + ASCII wireframe), **Signature** (the one element the page is remembered by).
2. **Review the plan against the brief** — work a similar prompt; if any part reads like the
   generic default you'd produce for *any* such page, revise it and say what changed and why.
3. Only after confirming relative uniqueness, write code — deriving every color/type decision from
   the revised plan.

## Restraint & quality floor
- **Spend boldness in one place.** The signature is the one memorable thing; keep everything around
  it quiet. Cut decoration that doesn't serve the brief. (Before shipping, remove one flourish.)
- Hold the quality floor without announcing it: responsive to mobile, visible keyboard focus,
  reduced motion respected.
- Critique as you build — screenshot if the environment allows (a picture is worth 1000 tokens).

## Writing is design material
Words exist to make the design easier to understand. Write from the user's side of the screen —
name things by what people control, not how the system is built. Active voice; an action keeps
its name through the whole flow ("Publish" → toast "Published"). Errors don't apologize and are
never vague; an empty screen is an invitation to act. Sentence case, no filler.
