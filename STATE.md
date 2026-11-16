# STATE — Midnight Sploogecraft

_Cross-session daily report (~15 lines, rewritten each session via the `state` skill). Durable decisions live elsewhere, not here._

- **Phase/milestone:** M5 — NEON CITY, visual overhaul implemented; awaiting user playtest/acceptance.
- **Last session:** rebuilt city visuals — road grid with centre lines/sidewalks, lit windowed facades, neon signage, real lamp posts, moving lane-driven traffic, night start; verified with headless check + windowed captures in `debug/evidence/city_*.png`.
- **Experience:** `glow_only` blocks make windows/signs glow without adding bake sources (258 total); headless `--script` captures fail with dummy renderer — use a windowed Godot run for `debug/city_capture.gd`.
- **Next up:** user playtest / M5 acceptance, then player weapons + hostile-weapon integration (gang/police combat, wanted escalation).
- **Backlog:**
  - pre-existing `debug/m1_walk_test.gd:49` type-inference error (unrelated to M5).

_Updated: 2026-11-17_
