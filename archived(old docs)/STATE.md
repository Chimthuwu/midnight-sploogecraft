# STATE — Midnight Sploogecraft

_Cross-session daily report (~15 lines, rewritten each session via the `state` skill). Durable decisions live elsewhere, not here._

- **Phase/milestone:** M6 — visual rework vertical slice complete (facade architecture, lighting energy model, landmarks); awaiting user acceptance before any new content.
- **Last session:** rewrote world generation as style-programs (deco/office/tenement/venue/warehouse/walkup/shed) with facade depth, ground-floor kits, roof kits, alleys, yards and four handcrafted landmarks; changed the shader to a key-light + absolute-fill energy model; fixed reversed car steering; resized viewmodel; 8-view capture loop iterated to clean night-city renders (`city_check` passes with zero script errors).
- **Experience:** the world streams ~30 chunks around the player body — distant capture vantages need the player teleported (`_goto`) or they render empty; a stray window-activation click fires the idle Lumencaster, so disarm it at spawn; the shader fill floor is absolute, not scaled by night sky tint.
- **Next up:** user playtest/acceptance of the visual slice; then continue the visual loop on flagged nits (upper-facade window density, crosswalk stripe width) before any new weapons/content.
- **Backlog:**
  - pre-existing `debug/m1_walk_test.gd:49` type-inference error (unrelated). _(since 2026-11-16)_

_Updated: 2026-11-17_
