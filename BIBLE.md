# PROJECT: LUMENFALL — 3D dark-Terraria vertical slice
### BIBLE v1 — vision, stack, constraints, milestones

## ROLE
You are the lead engineer on a solo-scale game prototype. Build a playable
vertical slice, milestone by milestone. Do not attempt the full game. Ask me
before deviating from this spec.

---

## PITCH
A chunky 3D block-world survival game in the spirit of Terraria, but the
world runs on a light economy. Darkness is a spreading, living system that
spawns enemies and rots terrain. The player mines and builds by firing a
light-based gun. Biomes are defined by how their light behaves, and biome
blocks can be transplanted to rewrite local light rules.

Tone target: mechanically frightening, not cinematically horrific. Fear
comes from information denial, resource pressure, and the world actively
working against you. NO jumpscares. NO gore. The dark is a system, not a
monster.

---

## PIN THE STACK
- **Godot 4.7.2 stable, GDScript only.** No C#, no GDExtension.
  If GDScript profiling at M2 shows meshing or light propagation cannot
  hit budget, stop and ask before switching anything to C#.
- **Renderer: Compatibility (GL).** Do not switch to Forward+ unless you
  can prove a specific feature requires it. Ask first.
- **No third-party addons. No GridMap. No per-block nodes. No OmniLight3D
  per torch.** Ask before adding any dependency.
- **Godot API:** if an API name is uncertain, check the 4.7 docs rather
  than guessing. Version-specific renames (Godot 3 → 4) are a known
  failure mode. Examples: `Spatial`→`Node3D`, `MeshInstance`→`MeshInstance3D`,
  `OS.get_ticks_msec` stays, `Viewport` scaling API changed in 4.x.
- **4.8 API guard:** if a method appears in a Godot version newer than
  4.7.2, treat it as nonexistent for this project. No bleeding-edge APIs.
- **Internal resolution: 854×480, enforced via project settings, not a
  SubViewport node.** The root viewport IS the internal surface.
  - display/window/size/viewport_width = 854
  - display/window/size/viewport_height = 480
  - display/window/size/window_width_override = 1708
  - display/window/size/window_height_override = 960
  - display/window/stretch/mode = viewport
  - display/window/stretch/aspect = keep
  - display/window/stretch/scale_mode = integer
  Integer scaling only. Non-16:9 windows letterbox with black bars —
  do not stretch, do not fill. Do not add a `SubViewport` node to
  re-implement what these settings already do; the only exception is a
  milestone that specifically requires a render-target pass, and that
  requires asking me first.
- **Textures:** Nearest by default; MSAA off; mipmaps off for block textures.
- **Audio:** Godot audio buses required (`Master`, `World`, `UI`).
  Muffling through terrain = lowpass filter on `World`, applied by a
  raycast-driven AudioEffectFilter, not by hand-rolled DSP.
---

## PROJECT STRUCTURE
Nothing lives outside this tree. If a new folder is needed, ask first.

res://
scenes/ player, world, cradle, enemies, ui, debug
scripts/ systems (world, light, gloom, gun, save)
data/blocks/ BlockDef .tres
data/biomes/ BiomeDef .tres
data/enemies/ EnemyDef .tres
data/cartridges/ CartridgeDef .tres
shaders/ dither, world, debug
debug/ debug scenes, test maps (committed artifacts)
STATE.md, DEVLOG.md
text


---

## HARD TECHNICAL CONSTRAINTS
Do not improvise the architecture for the two hardest systems — meshing
and light. These constraints are the architecture.

### WORLD / MESHING
- World data: `PackedByteArray`, one byte per block (index into BLOCKS),
  sized 128×128×64 = 1 MB. Nothing else stores block state.
- 16³ chunks. **One `MeshInstance3D` + one `StaticBody3D` (single
  `ConcavePolygonShape3D` built from the same face data) per chunk.**
  Nothing per-block.
- `ArrayMesh` built with `SurfaceTool`. Face-culled, per-face only.
  **Greedy meshing is a stretch goal after M10 — do not attempt now.**
  It fights vertex-color light baking.
- Rebuild only dirty chunks, queued and amortized: **max 2 chunks/frame**
  on the main thread from worker results. Never rebuild a whole chunk
  synchronously inside a frame.
- Chunk generation and meshing on `WorkerThreadPool`. Light propagation
  stays on the main thread, amortized.
- Budget: 256 chunks total, **<300 draw calls**, no per-frame allocations
  in hot loops (reuse scratch arrays; pool `Vector3`).

### LIGHT (do not improvise the algorithm)
- Light = integer **0..15** per block, `PackedByteArray` per chunk.
- **Attenuation model:** each block type has an integer `ATTENUATION`
  (1..15) derived from its `LIGHT_MODIFIER` via a lookup table at load:
  1.0 → 1, 0.33 → 4, 0.0 → 15 (blocked). Floats exist only in the data
  table. The propagation loop sees integers only.
- **Bucket queue** (16 buckets, 15 down to 0), 6-neighbour. Per-chunk
  with a **15-block padded margin** copied from neighbours before
  propagating. Re-propagate neighbouring chunk borders when a chunk's
  light changes — this is how you avoid seams. Prove it with the
  border test in M2.
- **Rendering:** bake final light into the chunk geometry's
  `COLOR` vertex attribute, quantized to 16 levels. Material uses
  `vertex_color_use_as_albedo`. Then **one full-screen Bayer 8×8
  dither shader** over the SubViewport that quantizes luminance into
  ~6 bands and dissolves to black. **Dither the world only, not the HUD.**
  No post-processing stack, no second render target.
- **Flashlight:** decide ONE approach before M2 — either propagated cone
  into the light buffer, or `SpotLight3D` for visuals + a cone query for
  gameplay. Document the choice in STATE.md. Do not change later without
  asking.

### SAVE
- `user://worlds/<seed>/` : one binary block file (`PackedByteArray`,
  compressed with `FileAccess.open_compressed`) + one JSON metadata file
  (seed, biome map, block-defs version, cradle state, inventory,
  player stats).
- Round-trip test required in M1: save, quit, load, diff 20 sampled
  blocks and the full metadata.
- Version field in metadata. A version mismatch must be a loud error,
  not a silent partial load.

### DETERMINISM
- Terrain shape and biome placement: deterministic from `world_seed` via
  `FastNoiseLite`. Per-chunk RNG = `hash(world_seed, cx, cy, cz)`.
  **No `randi()` / `randf()` anywhere in generation.**
- Enemy spawns, Gloom, loot: not required to be deterministic.

### LOOP / INPUT
- Fixed-timestep simulation (60 Hz accumulator in `_physics_process`),
  variable-rate render.
- Input map defined in Project Settings, not hardcoded key checks.
  Minimum: move, sprint, look, fire, mode-switch, interact, debug-toggle.
- Pause simulation on window focus loss; do not accumulate time while
  unfocused.

### PERFORMANCE
- Zero per-frame allocations in the hot loop.
- No `print()` inside the game loop. Debug overlay only.
- **Target: solid 60 fps at 854×480 internal on a mid-range laptop.**
- If frame time >20 ms for 10 consecutive frames, log a warning with
  draw calls, active chunks, and the phase (gen/light/render).

### AUDIO
- Godot buses: `Master` → `World` (lowpass, distance-filtered) and `UI`.
- Terrain muffling via raycast + `AudioEffectLowPassFilter` on `World`.
  Do not hand-roll DSP.
- Enemy sounds are on `World` and must be silent until close (distance
  attenuation), by design.

---

## SCOPE FOR THIS SLICE
One small map. Content list is fixed; do not add more.
- Biomes: **Ashen Flats** (start), **Hushwoods**, one underground cave layer.
- One boss: **Lamp Eater Queen**.
- Player base: **the Cradle** (crashed shuttle).
- 4 enemy types.
- 3 seed types.
- 4 cartridge types.

---

## CORE SYSTEMS

### 1. Block world
- Chunked voxel world, 16×16×16 chunks, face-culled meshing.
- Block types: air, dirt, stone, iron ore, lumen crystal, wood, pale wood,
  mycelium, glowreed, rotted variants of each, plus crafted blocks.
- Fully destructible and placeable via the gun's projector mode.
- Saving/loading to disk.

### 2. Light system (THE HEART OF THE GAME — build this first)
- Voxel flood-fill light propagation (torches, crystals, beacons, player
  flashlight, gunshots).
- Every light source has a RANGE. Every block type has a LIGHT_MODIFIER
  that scales incoming light: 1.0 normal, 0.33 for mycelium (absorbs),
  0.0 for pale bloom, etc. Propagate with per-step attenuation modified
  by the target block.
- Render darkness as an ordered Bayer dither dissolving into black, not
  a smooth gradient. The dark must have visible pixel texture.
- Expose a read-only per-block `LIGHT_LEVEL` that all other systems query.

### 3. Gloom system
- Per-chunk float `GLOOM_LEVEL`, 0..1. Rises when unlit, falls when lit,
  rises faster underground and at night.
- Above a threshold, the chunk can spawn enemies and rots adjacent blocks
  over time (terrain conversion to rotted variants).
- Rotted blocks INVERT their biome's light behaviour (rotted glowreed
  drains light instead of emitting it).
- Global day/night cycle: 7 min dim day, 2 min twilight, 15 min night,
  1 min dawn. Underground has no cycle, only Gloom depth.

### 4. Lumencaster (the only tool)
- One gun, swappable cartridges. No pickaxe, no axe.
  - **PHOTON SLUG:** hitscan damage, weak vs armour, loud.
  - **EXCAVATOR ROUND:** charged beam, mines blocks, very loud, raises
    local Gloom by releasing trapped dark.
  - **BEACON ROUND:** plants a temporary light source on a surface.
  - **FLARE:** bright, short-lived, burns enemies, throws light far.
- Ammo is charged from light: standing near a light source refills
  LUMEN RESERVE. In pitch black the gun cannot fire.
- **PROJECTOR MODE:** aim at a surface, drag a 1×1×1 to 4×4×4 volume,
  spend blocks from inventory, fabricator assembles it. Slow and loud.

### 5. Seeding (Terraria-style biome transplant)
- SEED CORES are items (boss drops + crafted).
- Plant in valid substrate → growth phase of ~90 s where the seed is
  vulnerable and enemies target it → then self-spreads outward,
  converting terrain, growing trees/reeds/caps.
- Spreading is slow (real minutes) and visible.
- Seeds in slice: **HUSHWOOD** (sound-deadening), **GLOWFEN** (free
  ankle-height glow, attracts Glowmoths), **SPOREWOOD** (cuts light range
  to 1/3, ground detects footsteps).
- Gloom rots seeds and rotted biomes fight back. The border is contested.

### 6. Player stats
- **HEALTH:** no regen in dark. Slow regen in bright light.
- **ENERGY:** sprint, steady aim, hold breath. Drains faster in darkness.
- **LUMEN RESERVE:** ammo charge. Refilled by light.
- **CORRUPTION (earned):** from dark-alchemy gear. Lowers max HP, makes
  enemies ignore you. A deliberate trade. Show in UI.
- **DISSONANCE (inflicted):** from spores and certain enemies. Fills with
  hallucinations — phantom enemies that vanish when shot, false light,
  fake loot. Grounding: stand in true bright light or hold a physical
  item from inventory. Distinct UI colour from Corruption; never confuse
  the two.
- **NO HUNGER SYSTEM.**

### 7. Enemies
- **GLOOMLING:** swarm, weak, dissolves in strong light.
- **LAMP EATER:** moth-like, targets light sources first, extinguishes
  beacons.
- **HOLLOW:** tall, silent, only moves when not directly observed.
  Flashlight beam freezes it.
- **LAMP EATER QUEEN (boss):** summons Lamp Eaters, drains all light in a
  radius, fought in a player-built lit arena. Killing it drops the
  Hushwood seed core and a gun mod.

### 8. The Cradle (base)
- Crashed shuttle, half-buried, players spawn in a cryo bay.
- Systems: **EMERGENCY LIGHTS** (drain a battery), **FABRICATOR**
  (crafting bench, needs charge, loud), **HULL BREACHES** (darkness and
  enemies leak in), **RESPAWN ANCHOR** (a beacon round must keep it lit).
- The base is NOT safe by default. It must be powered, lit, and repaired.
- Enemies can attack the hull. Lamp Eaters target the shuttle's lights.

### 9. Death
- Respawn at the Cradle. All inventory drops where you died.
- Every ~60 s that dropped loot sits in darkness, it DRIFTS toward the
  nearest Gloom concentration or down one level. Corpse runs are a race
  against a world stealing your gear.

---

## VERTICAL SLICE CONTENT
- **Ashen Flats** (honest weak light) — start zone, teaches the rules.
- **Hushwoods** (sound-deadening — gunshots don't carry, Hushwood enemies
  can't be heard) — second zone.
- One cave layer beneath, teaching that mining = noise = danger.
- Cradle base with all systems functional.
- Full loop working: leave base → mine with gun → Gloom rises → enemies
  converge → retreat → power fabricator → craft ammo → plant Glowfen
  seed → defend it → fight Lamp Eater Queen → get Hushwood seed → base
  gets attacked at night → repair and hold.

---

## ART DIRECTION (non-negotiable)
- Internal res 480p (854×480), nearest-neighbour, 16×16 block textures.
- Flat/low-detail lighting, no specular, no bloom, no SSAO.
- Tiny palette: ~48 colours, 6–8 per biome.
- Extreme scale: 40 ft mushroom caps, chasms with no visible bottom.
- Diegetic HUD: ammo shown as a light on the gun, health as a wrist
  readout. Nothing floats in screen space. No minimap; a handheld map
  item costs you a hand and a light source.

---

## AUDIO DIRECTION
- Mono-leaning, distance-filtered, muffled through terrain.
- Enemies silent until close. The Hushwoods must make the player turn
  the volume up and then punish them for it.
- Gunshots are the loudest thing in the game and should feel expensive.

---

## DEBUG REQUIREMENTS
- **Debug overlay** (F3): FPS, frame ms, draw calls, active chunks,
  block ID + `LIGHT_LEVEL` + `GLOOM_LEVEL` at crosshair, Lumen reserve,
  all player stats, worker queue depth.
- **Toggles:** chunk borders, light values as face tint, enemy paths,
  collision boxes.
- Every milestone ships with a **debug scene** that proves its acceptance
  criteria without needing to "play the game properly". `debug/` scenes
  are committed artifacts, not throwaways.
- **Startup log** lists data files loaded and their counts. A mismatch
  between data files and expected content is a loud error.

---

## BUILD ORDER
Do these in order. Stop and show me each. Never start M(n+1) until M(n)
acceptance passes.

### M0. Light + dither spike
Isolated `debug/lighttest.html`-equivalent scene: 32³ sealed world, free
camera, no player, no enemies, key to place/move a light. **Must pass
M2 acceptance before M2 touches the main game.** This is the highest-risk
system in the project.

### M1. Project, viewport, player, world
Godot project, 480p pixel-perfect viewport, first-person controller,
block world generation + destruction/placement.
- **Acceptance:** Spawn in 128×128×64 generated world; break and place;
  neighbour faces update same frame as a break; save → quit → load
  restores exactly (spot-check 20); startup log prints block/biome
  counts; FPS overlay ≥60; `renderer.info`-equivalent draw calls <300;
  debug test scene walks 50 blocks and logs any frame >20 ms.

### M2. Voxel light + dithered darkness
- **Acceptance:** Isolated test map (sealed 32³ room, one light, one
  mycelium wall, one pale-bloom wall). `LIGHT_LEVEL` matches expected
  table at distances 1..15 for all three. Screenshot shows ≥4
  distinguishable Bayer bands. Torch on chunk border: no seam from 3
  angles. Full chunk light update <2 ms. Crosshair overlay shows
  `LIGHT_LEVEL` and `GLOOM_LEVEL`.

### M3. Lumencaster
All 4 cartridges, Lumen reserve, projector building.

### M4. Gloom + day/night + enemies
Gloom system, day/night cycle, enemy spawning, Gloomlings + Lamp Eaters.

### M5. The Cradle
Battery, fabricator, breaches, respawn anchor.

### M6. Seeding
Glowfen and Sporewood seeds, growth, spread, defence.

### M7. Hushwoods
Hushwoods biome, Hushwood seed, Hollows.

### M8. Boss
Lamp Eater Queen boss + arena.

### M9. Stats polish
Corruption, Dissonance with hallucinations, death drift.

### M10. Audio pass, tuning, bugfix, playtest.

---

## DONE MEANS
- I can play for 30 minutes and the loop holds: tension, retreat, craft,
  expand, fight, survive.
- Night genuinely frightens me because I can't see and I'm low on ammo —
  not because something screamed at me.
- Planting a Glowfen patch near my base feels like a smart, dangerous bet.
- The dithered darkness is distinctive enough to recognise from a single
  screenshot.

---

## NON-GOALS
- No full Terraria-size world. No biome beyond the three listed.
- No hunger. No multiplayer. No storyline. No menuing beyond crafting.
- No polished art assets — placeholder blocks with correct colours are fine.

---

## HOW WE WORK
- One milestone per session. Never start M(n+1) before M(n) acceptance
  passes.
- **Before writing code: propose a plan (files, approach, risks, test
  steps) and wait for my OK.**
- Never paste more than ~400 lines in one response. Split into files and
  show me each.
- End every session: update `STATE.md` and `DEVLOG.md` — done / verified /
  broken / next / files changed / commit message.
- Prefer boring, obvious Godot idioms over clever architecture.
- **Never refactor a working system without asking.** Never silently
  reduce scope. If something is infeasible, stop and say so.
- If unsure, ask ONE question at a time rather than guessing.
- Never hardcode content; everything in `res://data/*.tres`.
- Commit working states. If a milestone is broken, tell me rather than
  papering over it.
- If something in this spec is ambiguous or you think it will not be fun,
  say so before building it.

---

## AMBIGUITIES — answer or ask me before coding
1. Exact internal resolution and behaviour on non-16:9 windows
   (letterbox vs stretch)? Confirmed 854×480?
2. Flashlight: propagated light into the buffer, or `SpotLight3D` +
   cone query? Pick one, document, don't revisit.
3. Dither approach: patched world material (recommended) or a
   SubViewport post pass? Pick one, document, don't revisit.
4. Lamp Eater Queen spawn trigger: what condition in a player-built
   arena fires it (radius? lit-block count? beacon rounds?)
5. Corruption: exact numbers for the HP/enemy-ignore trade.
6. Dissonance: max concurrent hallucinations, despawn rules.
7. Death drift: rate and target-selection rule.
8. Save format: confirmed as binary blocks + JSON metadata?
9. What is offloaded to threads, explicitly? (Answer: gen + meshing
   only. Light stays main-thread, amortized.)


## STATE.md
- Milestone: M2
- Verified (passes acceptance): [...]
- Works, not yet verified: [...]
- Broken / known bugs: [...]
- Files changed this session: [...]
- Next: [...]
- Open questions for the user: [...]
- Decisions locked (don't revisit): [flashlight=propagated, dither=patched material, ...]

M1 — medium (expected 1 session)
M2 — HIGH RISK (expected 2–3 sessions, may need iteration on shader)
M5 — medium
M8 — medium-high (boss state machine)