# DEVLOG

## 2026-11-17 — City rework, new blocks and rewritten bible

### Done

- Rewrote `BIBLE.md` as **v2** for this project (GTA-meets-Minecraft neon city): old Lumenfall biome/Cradle/seeding milestones removed; new rules explicitly allow new blocks, real-mesh vehicles/props and third-party assets, with visual quality as the priority.
- Widened the road grid: 20-block districts, 7-block roads, sidewalks, 11-block lots, intersections at x/z == 9 mod 20; spawn moved to (9, 9).
- Replaced axis-locked bouncing traffic with an intersection-graph AI: cars choose next junctions, steer into right-hand lanes, slow for turns/other vehicles and actually turn (verified node progression `(3,5)->(2,5)->(1,5)`).
- Rewrote driving: throttle/brake/reverse, speed-sensitive steering without reversed steering in reverse, handbrake on Space, `move_and_slide` collision response, smoothed third-person follow camera.
- Added eight new city blocks (glass dark/warm/cyan, brick, panel, crosswalk, traffic light, billboard) and used them in generation: zebra crossings, corner traffic lights, mixed facade materials, glass window grids and rooftop billboards. Neon block count dropped from ~4,400 to ~165.

### Verified

- `gda script validate --all` clean except the pre-existing `debug/m1_walk_test.gd:49` error; headless city check PASS including 7-wide roads, separated lanes, turning traffic, new blocks and determinism.
- Windowed captures in `debug/evidence/city_*.png`, including a clean HUD-free `city_topdown.png`; copies saved to `C:\Users\Serge\Desktop\Midnight Sploogecraft City Shots`.

### Next

- User playtest / M5 acceptance, then player weapons + hostile-weapon integration.

### Files changed this session

- `BIBLE.md`, `scripts/world/world_generator.gd`, `scripts/world/vehicle.gd`, `scripts/world/enemy_director.gd`, `scripts/player/player.gd`, `scripts/world/world.gd`
- `data/blocks/` (8 new blocks), `debug/city_capture.gd`, `debug/city_check.gd`, `debug/evidence/city_*.png`

### Commit message

`feat(city): rework roads, traffic AI and city block palette`

## 2026-11-17 — Driveable scale vehicles

### Done

- Added `assets/vehicles/` with seven imported PSX low-poly car models (sedans, police, taxi) plus their MTL/textures from the GGBot asset pack; source and licence note in `assets/vehicles/README.md`.
- Replaced the 1.9 m placeholder cars with `scripts/world/vehicle.gd`: imported cars normalized to ~4.9 m with headlights, taillights, neon underglow and roof trim; bikes are a Godot port of SKYJUMP3D's low-poly neon bike (`bike_visual.gd`).
- Traffic now mixes cars and bikes; three parked vehicles spawn by the start intersection so the player can actually walk up to one.
- Added driving: `E` enters/exits the nearest vehicle, WASD throttles/steers with arcade physics, third-person camera follows behind the vehicle, viewmodel hides while driving, HUD shows `E ENTER VEHICLE` / `WASD DRIVE · E EXIT VEHICLE`.
- Fixed the camera-forward mismatch (Godot camera looks down local -Z while vehicle forward is +Z).

### Verified

- `gda script validate --all` clean except the pre-existing `debug/m1_walk_test.gd:49` error; scene validate clean.
- Headless `city_check` PASS including parked/traffic vehicle counts, bike presence and real meshes.
- Windowed captures: `city_vehicle_close.png` shows a full-size car with headlights/underglow; `city_driving.png` confirms the third-person follow view with the car's neon trim and taillights in frame.

### Next

- User playtest / M5 acceptance, then player weapons + hostile-weapon integration.

### Files changed this session

- `assets/vehicles/` (new), `scripts/world/vehicle.gd`, `scripts/world/bike_visual.gd`
- `scripts/world/enemy_director.gd`, `scripts/player/player.gd`, `scripts/ui/game_hud.gd`
- `debug/city_check.gd`, `debug/city_capture.gd`, `debug/evidence/city_*.png`

### Commit message

`feat(vehicles): add real car/bike models and third-person driving`

## 2026-11-17 — Neon city visual overhaul

### Done

- Rebuilt `scripts/world/world_generator.gd`: 16-block districts with 3-wide roads, dashed centre lines, sidewalks and concrete lots; buildings generated per lot (not per chunk) so they cross chunk borders intact and stay seed-deterministic.
- Added 12 city blocks (facades dark/mid/light, warm/cyan/dark windows, pink/blue/yellow neon, sidewalk, road line, roof). Added `glow_only` to `BlockLightDef` so windows/signs glow visually without becoming propagation sources — the bake stayed at 258 sources.
- Buildings now have window grids, shopfront bands, signage strips, vertical signs, upper-floor setbacks, rooftop plant and antenna masts; the spawn-facing lot is a neon monument plaza.
- Street lamps render as real posts with a glowing head (dedicated mesher fixture branch); cars spawn on the road surface (y=3.05) in two proper lanes with coloured bodies, wheels, headlights/taillights and direction-aware rotation.
- City now opens at night (`DayNightCycle` starts 60 s into the night phase); added `debug/city_capture.gd`.

### Verified

- `gda script validate --all` clean except the pre-existing `debug/m1_walk_test.gd:49` error; `gda scene validate` clean.
- Headless `debug/city_check.gd` PASS: roadway/centre line/sidewalk/lots distinct, window grids present, lamp + plaza neon sources, 258 bake sources, cars above the road, deterministic stamping.
- Windowed capture run confirmed cars move (x 45.20→58.40, z 34.46→41.09) and produced `debug/evidence/city_spawn_night.png`, `city_overview.png`, `city_avenue.png`, `city_plaza.png`.

### Next

- User playtest / M5 acceptance, then player weapons + hostile-weapon integration.

### Files changed this session

- `scripts/world/world_generator.gd`, `scripts/world/world.gd`, `scripts/world/chunk_mesher.gd`, `scripts/world/traffic_car.gd`, `scripts/world/enemy_director.gd`, `scripts/world/day_night_cycle.gd`
- `scripts/light/block_light_def.gd`
- `data/blocks/` (12 new city blocks)
- `debug/city_check.gd`, `debug/city_capture.gd`, `debug/evidence/city_*.png`

### Commit message

`feat(city): rebuild neon city visuals and traffic`

## 2026-11-17 — Neon city blockout and city threat loop

### Done

- Replaced the Ashen Flats blockout with the Neon City: 128×128 road grid (avenues/streets on lines ≡8 mod 16, half-width 1), ground slab asphalt on roads / concrete off-road, buildings base 10+16*grid+jitter(0..1), size 8–9, height 4–15, spawn plaza cleared, street lamps stride 12, emissive neon signs on road-facing building faces.
- Added city blocks: asphalt, concrete, neon_sign, street_lamp (emissive 6/12).
- City spawn plaza via `world.get_city_spawn_position()`; player spawn wired to it.
- Gloom sky-fraction now counts air-above cells, so enclosed buildings read as underground instead of exposed sky.
- City threats: `Civilian` (hostile=false, wanders street lanes), `GangMember` (hostile, red accent), `PoliceOfficer` (hostile, blue accent); enemy config carries threat group stats plus gang/police/civilian exports; lamp eaters target `torch`+`street_lamp`.
- `TrafficCar` (CharacterBody3D FLOATING, boxes + capsule, bounce) with director traffic loop (MAX_CARS 10) and wanted/cop flow after player fires.
- Lumencaster default build block → concrete; `_place_target_block` uses the selected build material.

### Verified

- `gda script validate --all`: every script valid except the pre-existing `debug/m1_walk_test.gd:49` type-inference error.
- `gda scene validate res://scenes/world/main.tscn`: valid, no problems, no stale class entries.
- Headless `debug/city_check.gd` run: PASS — 256/256 chunks generated, street/plaza/building/lamp/neon assertions pass, 967 lamps + 90 neon sources emit static light, stamping deterministic.

### Next

- Player weapons and hostile-weapon integration for the city (gang/police combat, wanted escalation).
- Visual set dressing: real car meshes, neon sign art quality, night captures of the city.

### Files changed this session

- `scripts/world/world_generator.gd`
- `scripts/world/world.gd`
- `scripts/world/gloom_manager.gd`
- `scripts/world/enemy_config.gd`, `data/world/enemy_config.tres`
- `scripts/world/enemy_director.gd`
- `scripts/world/traffic_car.gd`
- `scripts/enemies/` (civilian, gang_member, police_officer, enemy_base)
- `scripts/player/` (player, lumencaster, lumencaster_config)
- `scripts/world/main.gd`, `scripts/ui/game_hud.gd`, `project.godot`
- `data/blocks/` (asphalt, concrete, neon_sign, street_lamp)

### Commit message

`Add neon city blockout and city threat loop`

## 2026-11-16 — M0 isolated light and dither spike

### Done

- Created a Godot project configured for 854x480 internal rendering, integer viewport scaling, keep-aspect letterboxing, and a 1708x960 default window.
- Added a sealed 32³ voxel test map with a free camera, one movable light, isolated air/mycelium/pale-bloom probe paths, chunk meshes, a light-level HUD, and an 8x8 Bayer world material shader.
- Light is stored per 16³ chunk. Each chunk copies its 15-block padded block neighborhood, runs a 16-bucket 6-neighbor propagation pass, and copies core levels into the chunk buffer.
- Added `.tres` definitions for air, mycelium, pale bloom, normal stone, and the sealed test wall. The runtime harness reports values at distances 1–15 and the slowest chunk update.
- Locked the dither decision as a patched world `ShaderMaterial` reading baked vertex light.

### Verified

- Godot 4.7.2 headless runs loaded the scene with no script parse errors. The air, mycelium, and pale-bloom `LIGHT_LEVEL` table passed for all 15 distances.
- A non-headless Compatibility-renderer run opened on an AMD Radeon RX 6600 and reported no shader errors. That run measured 1.678 ms for the slowest chunk update.
- Five additional headless timing runs ranged from 1.620 to 2.356 ms; one exceeded the 2 ms budget. M0 timing acceptance is not stable yet.
- Checked Godot 4.3 official docs for viewport scaling, spatial shader `COLOR`/`FRAGCOORD`, shader bitwise operators, `ArrayMesh.add_surface_from_arrays`, Environment fog fields, `Time.get_ticks_usec()`, GDScript line continuations, and `PackedByteArray` slice/append APIs.

### Broken / not verified

- The available engine is Godot 4.7.2, while the project pins 4.3.x. The spike has not been run in 4.3.
- Screenshot band count, HUD/fog appearance, manual light movement, three-angle chunk seam, and visible crosshair values remain unchecked. M0 acceptance has not passed.
- Godot logged environment write failures for `user://logs` and shader/editor caches, plus a certificate-store error. These did not prevent the scene from running.
- Git was initialized during this session, but sandbox permissions block writes to `.git/index.lock`; no commit could be created.

### Next

- Keep the project feature pin at 4.3 unless an explicit engine-version change is made.
- Make the <2 ms result repeatable, then capture the 854x480 screenshot and complete the visual checks in `STATE.md`.
- Stop at M0 until acceptance passes; M1 must not begin before then.

### Files changed this session

- `scripts/debug/lighttest.gd`
- `scripts/debug/lighttest.gd.uid` (generated by Godot)
- `.godot/` (generated editor/import cache)
- `STATE.md`
- `DEVLOG.md`

### Commit message

`Add isolated M0 voxel light and dither spike`

## 2026-11-16 — M0 HUD correction and visual evidence

### Done

- Changed the crosshair readout to sample the last AIR cell before the first solid ray hit, so the readout reports the illuminated air volume.
- Added a solid observation floor in the camera bay so the primary view aims into AIR immediately above it.
- Added `debug/capture_m0.gd`, a repeatable capture helper for the isolated test scene. It saves 854×480 images and exercises the existing L-key light-move action.
- Captured the AIR dither/HUD view, three chunk-border views, a same-view before/after light-move pair, and a separate HUD view in `debug/evidence/`.

### Verified

- Godot 4.7.2 reports nonzero `LIGHT_LEVEL 12` for AIR at `(13, 15, 14)` in the primary screenshot; HUD also shows `GLOOM_LEVEL`.
- Before/after images show the same view with changed dither lighting and the source marker moved from `(15, 15, 15)` to `(8, 15, 12)` after the L-key action.
- All seven saved screenshots are 854×480. Three border-angle screenshots are distinct views.
- The five-run timing criterion remains PASS: median 1.661 ms and max 2.356 ms. The meaningful budget is the amortized cost of up to two chunks in a frame against the 20 ms worst-case frame budget; a single-chunk timing in isolation does not establish that combined frame cost.
- No SubViewport is present; the light test scene inherits the project-settings root viewport.

### Broken / not verified

- Do not mark M0 passed yet: four clearly distinguishable Bayer bands and fog visibility are not confirmed; the captures alone do not conclusively prove no seam from all three angles; live-window integer scaling is unverified.

### Next

- Complete those visual checks, then update M0 verdict. M1 remains blocked on M0 acceptance.

### Files changed

- `scripts/debug/lighttest.gd`
- `debug/lighttest.tscn`
- `debug/capture_m0.gd`
- `debug/evidence/m0_01_dither_air_crosshair.png`
- `debug/evidence/m0_02_border_west.png`
- `debug/evidence/m0_03_border_upper_angle.png`
- `debug/evidence/m0_04_border_lower_angle.png`
- `debug/evidence/m0_05_light_before.png`
- `debug/evidence/m0_06_light_after.png`
- `debug/evidence/m0_07_debug_hud.png`
- `STATE.md`
- `DEVLOG.md`

### Commit message

`Verify M0 light HUD and capture visual evidence`

M0 verdict: OPEN — four-band/fog appearance, conclusive three-angle seam check, and live-window integer scaling remain unverified.

## 2026-11-16 — M0 accepted

### Confirmed

- Inspected `debug/evidence/m0_01_dither_air_crosshair.png`: its HUD reads `LIGHT_LEVEL 12 | GLOOM_LEVEL 0.00 | block air at (13, 15, 14)`. The crosshair sample is the AIR cell immediately before the wall hit, so the primary dither capture has the requested nonzero light value.
- Confirmed the 2569 us and 3191 us values came from screenshot capture runs with capture/render overhead. They are not part of the clean five-run timing set. The accepted five-run result remains 1.620, 1.641, 1.661, 1.783, and 2.356 ms (median 1.661 ms, max 2.356 ms), meeting median <3 ms and max <4 ms.
- Human visual review accepted the dither (five distinct wall bands), integer scaling/letterboxing in a resized window, and seam visibility (no brightness step across the chunk border at the supplied angles).

### Status

- M0 acceptance criteria are met. M1 is unblocked.
- Fog visibility was not separately assessed; it was not a listed M2 acceptance bullet.
- No Git commands were run.

### Files changed

- `STATE.md`
- `DEVLOG.md`

### Commit message

`Accept M0 light and dither spike`

M0 verdict: PASS — AIR HUD value, clean five-run timing, five dither bands, integer scaling, and chunk-border seam accepted.

## 2026-11-16 — Engine and timing criteria correction

### Done

- Ran the requested version command. Exact output: `4.7.2.stable.official.ed1daf0bf`.
- Recorded the engine gate: tests on another version do not count. The project still pins Godot 4.3.x, so visual verification is paused until the user decides whether to install 4.3.x or bump the pin.
- Replaced the single-run 2 ms gate with five-run criteria: median <3 ms and max <4 ms. Earlier 4.7.2 headless values were 1.620, 1.641, 1.661, 1.783, and 2.356 ms (median 1.661 ms, max 2.356 ms); these are diagnostic only and do not count for the pinned version.

Amortized frame cost is the relevant budget because two chunks may update in one frame and the frame must remain within 20 ms. Chunk update work consumes part of that shared budget, so an isolated per-chunk cutoff does not by itself indicate whether the game can meet its frame target.

### Skipped

- Did not continue visual verification on 4.7.2 as authoritative evidence because the project pins 4.3.x and the engine decision is unresolved.
- Did not run Git commands that write to `.git`; the user handles commits outside the sandbox.

### Next

- Wait for the engine decision, then continue M0 on the chosen exact version. M1 remains gated on M0 acceptance.

### M0 verdict

OPEN — engine version unresolved; AIR crosshair readout, three-angle chunk-border seam, visible light-movement propagation, and HUD screenshot remain unverified on the chosen engine. Five-run timing also remains unverified on that engine.

## 2026-11-16 — Pinned stack confirmed and timing accepted

### Done

- Read the updated `BIBLE.md` PIN THE STACK: Godot 4.7.2 stable, API docs target 4.7, and APIs newer than 4.7.2 are out of scope. Exact installed version was previously confirmed as `4.7.2.stable.official.ed1daf0bf`.
- Confirmed `debug/lighttest.tscn` has no SubViewport node. `project.godot` sets the root viewport to 854×480 with viewport stretch, keep aspect, and integer scale.
- Marked the supplied five-run timing result PASS: values 1.620, 1.641, 1.661, 1.783, 2.356 ms; median 1.661 ms (<3 ms), max 2.356 ms (<4 ms). Stop optimizing.

Amortized frame cost is the correct measure because two chunk updates can be scheduled in one frame; their combined CPU work must fit inside the worst-case 20 ms frame budget alongside the rest of that frame. A single per-chunk microsecond threshold does not express that actual frame-level constraint.

### Verified / blocked

- Existing screenshot shows patterned walls, but requested evidence remains incomplete. The current HUD samples only the first solid ray hit; it cannot display the light level of an AIR cell. Consequently the AIR crosshair artifact needs a small HUD sampling change or a narrower interpretation. That source change is outside the current instruction to update STATE.md and DEVLOG.md only, so no code was changed and visual capture work is paused pending direction.
- No SubViewport deviation exists; nothing needs removal in M1.
- No Git commands were run.

### Files changed

- `STATE.md`
- `DEVLOG.md`

### M0 verdict

OPEN — AIR crosshair readout, three-angle chunk-border seam, visible light-movement propagation, and requested debug HUD screenshot remain unverified.

## 2026-11-16 — M0 checkpoint after Git initialization

### Done

- Captured the Compatibility-rendered test scene at 854×480 as `debug/m0_review00000000.png`.
- Updated the project status to reflect initialized Git and the checks still outstanding.

### Verified

- Godot 4.7.2 headless scene run: all air, mycelium, and pale-bloom values match the table for distances 1–15.
- A Compatibility-rendered capture shows Bayer patterns on the walls and an undithered HUD. The capture resolution is 854×480.
- Latest measured slowest chunk update was 2.423 ms in the Compatibility-rendered capture run; another headless run measured 1.767 ms. The 2 ms target is not consistently met.

### Broken / not verified

- The center crosshair reads `LIGHT_LEVEL 0` on an opaque test wall. Four distinguishable bands, fog, integer scaling in a live window, moving the light, and the three-angle chunk seam check remain open.
- The available engine is 4.7.2; the project feature pin remains 4.3. Godot emits environment write/certificate errors for paths outside this workspace.
- M0 acceptance has not passed. M1 has not started.

### Next

- Make the <2 ms chunk update repeatable, then finish the outstanding visible checks and update acceptance status.

### Files changed

- `.gitignore`
- `STATE.md`
- `DEVLOG.md`
- `debug/m0_review00000000.png`

### Commit message

`Add isolated M0 voxel light and dither spike`


## 2026-11-16 — M2 isolated gate evidence

### Done

- Prepared an automated isolated M2 check for the expected light table, chunk-border continuity, AIR crosshair HUD, and five-run propagation timing.
- Captured a fresh set of 854×480 Compatibility-rendered M2 images: one AIR/dither view, three chunk-border views, before/after source movement, and a debug HUD view.
- Locked the flashlight implementation choice from the approved plan: propagate a voxel cone into the integer light buffer so rendered darkness, HUD LIGHT_LEVEL, and gameplay queries use the same value.

### Verified

- Godot 4.7.2 automated test passed all air, mycelium, and pale-bloom light values at distances 1–15.
- Automated values across the x=15/16 chunk boundary matched the expected propagated light.
- The primary capture reports `LIGHT_LEVEL 12 | GLOOM_LEVEL 0.00 | block air at (13, 15, 14)`.
- Five full padded chunk runs were 1182, 1184, 1184, 1190, and 1252 µs; median 1184 µs, max 1252 µs. Both revised criteria pass (<3 ms median, <4 ms max).
- Light movement was captured before and after using the existing L-key action; both images use the same view and show different illumination.

### Gate / not yet verified

- M2 visual evidence is ready for human review. Main-world M2 integration has not started, respecting the requirement that the isolated M2 acceptance pass first.
- Human acceptance of four distinct Bayer bands and no visible seam in the three current border-angle captures remains pending.
- The GDScript helper uses the M0 light test implementation; this checkpoint did not touch the main-world code or change light propagation.
- Environment-only root certificate-store warning remains present in Godot command-line output.
- No Git commands were run.

### Files changed

- `debug/m2_acceptance_test.gd`
- `debug/capture_m2.gd`
- `debug/m2_evidence/m2_01_dither_air_crosshair.png`
- `debug/m2_evidence/m2_02_border_west.png`
- `debug/m2_evidence/m2_03_border_upper_angle.png`
- `debug/m2_evidence/m2_04_border_lower_angle.png`
- `debug/m2_evidence/m2_05_light_before.png`
- `debug/m2_evidence/m2_06_light_after.png`
- `debug/m2_evidence/m2_07_debug_hud.png`
- `STATE.md`
- `DEVLOG.md`

### Commit message

`Add isolated M2 light and dither acceptance evidence`

M2 isolated verdict: OPEN — automated table, border-light continuity, AIR HUD, and timing checks pass; awaiting human visual acceptance before main-world integration.
## M2 flashlight performance correction

The flashlight decision is revised per the user's explicit performance direction: static sources (torches, crystals) use voxel propagation and are baked into chunk vertex colors; the dynamic player flashlight is computed in the Bayer fragment shader from position/direction uniforms. Looking around updates shared shader parameters only and must never mark chunks dirty or rebuild meshes. This supersedes the earlier mistaken proposal to propagate the flashlight cone.

The approved isolated M2 gate remains in force: validate the dynamic shader behavior in `debug/lighttest.tscn`; do not touch the main world until the user accepts the isolated evidence. No main-world files have been changed for M2.
## 2026-11-16 — Dynamic flashlight shader implementation

### Done

- Applied the performance correction: static voxel lights remain in baked vertex alpha; the moving flashlight now uses world-position and direction uniforms in `light_dither.gdshader` and contributes in the fragment shader before Bayer band quantization.
- Updated the isolated light test to refresh those two uniforms as the camera moves. No mesh rebuild is called by the flashlight update.
- Added an automated check that moves/rotates the camera, verifies the shader uniforms changed, and verifies the mesh-build generation counter did not change.
- Regenerated all seven M2 captures with the dynamic flashlight active in the dither shader.

### Verified

- Headless M2 acceptance test passes: light table, chunk-border continuity, AIR HUD, dynamic flashlight uniform update without remesh, and five-run chunk propagation timing.
- Latest five timing runs: 1262, 1271, 1371, 1375, 1677 µs; median 1371 µs, max 1677 µs, within the revised thresholds.
- Graphical Compatibility capture run on the RX 6600 compiled and rendered the updated shader with no shader errors. Captures are 854×480; the AIR screenshot reads LIGHT_LEVEL 12.

### Gate

- Main-world integration remains untouched until human M2 visual acceptance of the current dither and three border-angle captures.
- The flashlight adds light based on camera position/direction, cone angle, and range in the shader. Static source movement continues to use voxel propagation and chunk remeshing.
- Environment-only root certificate-store warning remains in Godot console output. No Git commands were run.

### Files changed

- `shaders/light_dither.gdshader`
- `scripts/debug/lighttest.gd`
- `debug/m2_acceptance_test.gd`
- `debug/capture_m2.gd`
- Seven updated PNGs in `debug/m2_evidence/`
- `STATE.md`
- `DEVLOG.md`

### Commit message

`Keep flashlight dynamic in M2 Bayer shader`

M2 isolated verdict: OPEN — automated checks pass; waiting for human visual acceptance before main-world integration.
## 2026-11-16 — M2 main-world acceptance and capture

### Done

- Recorded the user's M2 acceptance and official PASS verdict.
- Added `debug/capture_main_m2.gd` to boot the real main scene, wait for generation, light baking, and meshing, aim at the generated torch, update the shader flashlight uniforms, and capture the rendered root viewport.
- Captured `debug/m2_evidence/main_world_torch_flashlight.png` at 854×480. The screenshot shows the torch, flashlight-lit dithered terrain, crosshair, and debug HUD.

### Verified

- Godot 4.7.2 Compatibility renderer completed the capture with 256/256 chunks generated, lit, and meshed; one torch and 47 static light sources were present.
- The main-world light initialization timing log reported median 2738 µs and max 19154 µs with one chunk processed per frame. This is a main-world initialization measurement, not the accepted isolated five-run timing verdict (median 1371 µs, max 1677 µs).
- Startup emitted a >20 ms frame streak warning during generation in the capture run. The user's M2 functional/visual acceptance remains recorded as PASS; this capture does not claim a separate startup frame-budget pass.

### Broken / not verified

- No new M2 acceptance items remain open per user review. Startup frame timing during this capture was not part of the M2 user acceptance.

### Next

- M3 plan: Lumencaster cartridge swapping, mining hitscan and Gloom noise, Lumen reserve recharge/fire gating, and 4×4×4 Projector Mode. No code until user approves the plan.

### Files changed

- `STATE.md`
- `DEVLOG.md`
- `debug/capture_main_m2.gd`
- `debug/m2_evidence/main_world_torch_flashlight.png`

### Commit message

`Record accepted M2 main-world integration`
## 2026-11-16 — M3 integration and load/render fixes

### Done

- Added four cartridge resources and a data-driven Lumencaster configuration.
- Added a player Lumencaster with grid DDA, 1–4 cartridge selection, EXCAVATOR block mining/inventory and Gloom noise signal, light-gated Lumen reserve/recharge, temporary BEACON/FLARE lights, and PHOTON hit signaling.
- Added Projector Mode: surface drag rectangle capped at 4×4, scroll extrusion depth 1–4, translucent no-depth preview, and atomic inventory/Lumen checks before build.
- Fixed black world clear, opaque-or-discard dither pixels, explicit back-face culling, solid-to-air mesh face filtering, and the see-through projector preview.
- Converted static light propagation to resumable 16-cell batches with a 1 ms per-frame work budget and nearest-player chunk priority.

### Verified

- Ran `Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --quit`; the global cache registered `CartridgeDef` and `LumencasterConfig`, with no script parse errors.
- Ran a 600-frame headless startup. World generation completed and no repeated >20 ms frame warning occurred. The previous single-chunk light update spike was replaced by budgeted incremental work.
- A first smoke run exposed an unsupported StandardMaterial3D `wireframe` assignment; removed it and reran import/startup without that warning.

### Broken / not verified

- M3 remains pending the user's in-game visual/functional acceptance. Headless startup does not verify projector drag feel or final transparency on screen.
- Godot still prints Windows root certificate-store and local editor-cache case warnings; these did not block class-cache import or startup.

### Next

- User playtest: fire all cartridges, mine and recharge in light, then drag/extrude/build a projector volume. Check black clear, solid faces, and see-through preview.

### Files changed

- `STATE.md`, `DEVLOG.md`, `project.godot`
- `shaders/light_dither.gdshader`
- `scripts/world/chunk_mesher.gd`, `scripts/world/world.gd`, `scripts/light/light_propagator.gd`, `scripts/world/main.gd`
- `scripts/player/player.gd`, `scripts/player/cartridge_def.gd`, `scripts/player/lumencaster_config.gd`, `scripts/player/lumencaster.gd`
- `scenes/world/main.tscn`
- `data/cartridges/*.tres`

### Commit message

`Implement Lumencaster and smooth M3 rendering`
## 2026-11-16 — M3 rendering and bake follow-up

### Done

- Kept zero-light Bayer samples as opaque black and retained `depth_draw_opaque`; the voxel ShaderMaterial never writes `ALPHA` or uses alpha blending.
- Reversed each quad's triangle order to Godot's clockwise front-face winding while preserving outward face normals. `cull_back` remains enabled. The mesher checks each solid cell's six neighbors and emits only toward air.
- Replaced the filled projector box with a 12-edge `ArrayMesh` line cage sized to the complete selected volume. Added a 32 px HUD left inset and widened the Lumen label.
- Cut unnecessary lighting work: sources that cannot reach a chunk core are excluded by a conservative Manhattan bound; chunks with no relevant sources receive a zero buffer without copying the padded volume or starting a flood fill.
- Set incremental light work to a 7 ms/frame budget in 64-cell steps.

### Verified

- Godot 4.7.2 headless editor import completed and rebuilt script classes without parse errors.
- Headless main-scene startup generated and lit all 256 chunks in 93 frames; max light-work frame was 8278 µs. No repeated >20 ms frame warning appeared.
- Godot 4.7 docs specify clockwise winding for front faces; source: https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html.

### Broken / not verified

- User visual review is still needed for the opaque floor, correctly culled 3D blocks, projector wire cage, and HUD margins. Headless does not validate rendered appearance.

### Next

- User looks again in the running game; accept M3 after the visual and gameplay checks pass.

### Files changed

- `STATE.md`, `DEVLOG.md`
- `shaders/light_dither.gdshader`
- `scripts/world/chunk_mesher.gd`, `scripts/world/world.gd`, `scripts/light/light_propagator.gd`
- `scripts/world/main.gd`, `scenes/world/main.tscn`, `scripts/player/lumencaster.gd`

### Commit message

`Fix opaque voxel rendering and incremental light bake`
## 2026-11-16 — M3 accepted; M4 plan kickoff

### Done

- Recorded M3 as ACCEPTED and closed at the user's direction.
- Reviewed BIBLE.md M4 scope and the current world light, Gloom-noise, block-resource, and player weapon interfaces. Prepared an M4 implementation plan only; no M4 code was written.

### Verified

- M3 acceptance is based on the user's report that gun mechanics work and subsequent approval.

### Broken / not verified

- M4 has not started pending approval of the proposed architecture and tuning approach.

### Next

- After plan approval: implement data-driven Gloom, the 25-minute day/night cycle, Gloomling/Lamp Eater spawning and behavior, and bounded rotted-block conversion.

### Files changed

- `STATE.md`
- `DEVLOG.md`

### Commit message

`Mark M3 accepted and document M4 plan kickoff`## 2026-11-16 — M4 implementation

### Done

- Added data resources for day/night timing and sky levels, Gloom rates/thresholds, enemy spawning/combat, and rotted dirt/ashen-soil variants.
- Added per-chunk 0–1 Gloom values, per-chunk static-light coverage, ambient exposure, underground/night multipliers, Lumencaster noise input, save/restore, and bounded dirt/ashen-soil rotting.
- Added the 7-minute day, 2-minute twilight, 15-minute night, and 1-minute dawn cycle. Ambient sky level is evaluated in the opaque Bayer shader using per-vertex UV2 sky exposure, so it does not rebuild chunks each frame.
- Added hidden-from-player spawn checks, capped Gloomling swarms, Gloomling damage and strong-light dissolving, and Lamp Eaters that seek and temporarily extinguish torches/beacons.
- Added player health and Lumencaster hitscan damage against enemies. The debug overlay shows phase, HP, crosshair LIGHT_LEVEL/GLOOM_LEVEL, enemy count, and world status.

### Verified

- Godot 4.7.2 headless editor import rebuilt global classes without script parse errors.
- Headless main-scene startup generated the world and completed the incremental static-light bake in 112 frames. No M4 script/runtime errors appeared.
- `.tres` values and scenes load on the pinned project engine.

### Broken / not verified

- M4 is not yet accepted. In-game visual/gameplay review is still needed for day-to-night readability, Gloom changes under light, enemy spawn visibility, Gloomling attacks/dissolving, Lamp Eater targeting/extinguishing, and rotted terrain appearance.
- Headless startup reported the existing Windows Godot certificate/cache/log write warnings and startup slow-frame warnings; it also completed successfully. The headless timing is not a performance acceptance run.
- The current world has dirt and ashen_soil as rot substrates; no separate grass block exists in M1 content.

### Next

- User playtest M4. Tune thresholds and rates from actual gameplay feedback; do not start M5 until M4 acceptance passes.

### Files changed

- `STATE.md`, `DEVLOG.md`, `scenes/world/main.tscn`, `shaders/light_dither.gdshader`
- `scripts/world/world.gd`, `scripts/world/chunk.gd`, `scripts/world/chunk_mesher.gd`, `scripts/world/main.gd`, `scripts/world/day_night_cycle.gd`, `scripts/world/gloom_manager.gd`, `scripts/world/enemy_director.gd`, `scripts/world/day_night_config.gd`, `scripts/world/gloom_config.gd`, `scripts/world/enemy_config.gd`
- `scripts/enemies/enemy_base.gd`, `scripts/enemies/gloomling.gd`, `scripts/enemies/lamp_eater.gd`, `scripts/player/player.gd`, `scripts/player/lumencaster.gd`, `scripts/save/save_manager.gd`, `scripts/light/block_light_def.gd`
- `data/world/*.tres`, `data/blocks/dirt.tres`, `data/blocks/ashen_soil.tres`, `data/blocks/rotted_dirt.tres`, `data/blocks/rotted_ashen_soil.tres`

### Commit message

`Implement M4 Gloom, day-night cycle, and enemies`

## 2026-11-16 — M4 constraint pass

### Done

- Locked the three approved M4 decisions. Surface-only spawning and one-way rot already matched the code, so only the Lamp Eater targeting changed.
- Added `lamp_eater_target_radius` (24 m) and `lamp_eater_target_blocks` (data whitelist, currently `torch`) to `EnemyConfig` and its `.tres`.
- Lamp Eaters now skip sources outside the radius and any block not in the whitelist. Because player torches, Beacon rounds, and Flares all place the `torch` block, they remain valid targets; lumen crystals are excluded.

### Verified

- `Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --quit` exited 0, registered `LampEater`, `EnemyConfig`, and `EnemyDirector`, and reported no script parse errors.
- 600-frame headless main-scene run exited 0: all 256 chunks generated, block counts expected, and the incremental light bake completed in 112 frames (max frame work 9456 µs). No M4 script/runtime errors.
- The run emitted the pre-existing generation-time `10 consecutive >20ms frames` warnings during the light phase; they are startup timing warnings, not new failures.

### Broken / not verified

- The whitelist filter and radius have not been observed in gameplay; headless runs do not exercise Lamp Eater target selection. Confirm during the M4 playtest by placing a torch and a lumen crystal near a Lamp Eater.
- M4 remains unaccepted pending the user's playtest.

### Files changed

- `scripts/world/enemy_config.gd`, `scripts/enemies/lamp_eater.gd`, `scripts/world/enemy_director.gd`, `data/world/enemy_config.tres`, `STATE.md`, `DEVLOG.md`

### Commit message

`Constrain Lamp Eater targeting to nearby torches`

## 2026-11-16 — M4 viewmodel and debug spawn keys

### Done

- Added `LumencasterViewmodel` under the player camera: five BoxMeshes for body/barrel/muzzle/grip/sight, an unshaded material whose albedo follows local voxel light plus the flashlight cone, a six-segment emissive Lumen strip, and a muzzle-flash cube.
- Added a `fired(cartridge_id, kick)` signal to the Lumencaster, emitted only after a shot passes the light/reserve checks. The viewmodel converts it into positional kickback, upward pitch, and a short lateral shake with exponential recovery.
- Replaced the top-left reserve bar/text with the gun's Lumen cells: the `HUD/LumenBar` node was removed, and `LumenReadout` now shows mode/build/status only. `lumencaster.gd` looks the nodes up with `get_node_or_null` and tolerates the removed bar.
- Added F6/F7/F8 input actions and handlers: F6 spawns three Gloomlings, F7 spawns a Lamp Eater, F8 sets the player's current chunk Gloom to 1.0. Debug spawning bypasses the Gloom threshold and enemy cap.

### Verified

- Headless editor import exited 0 and registered `LumencasterViewmodel` with no script parse errors.
- 600-frame headless main-scene run exited 0: world generated, light bake completed in 115 frames (max 9525 µs), and no viewmodel or debug-key runtime errors appeared.
- The headless run executes the viewmodel `_ready`/`_process`, so mesh construction, material setup, and the per-frame light query are exercised.

### Broken / not verified

- Screen placement, silhouette, recoil feel, Lumen-cell readability, and muzzle flash are not verified headlessly; they need the user's playtest.
- Firing is not simulated headlessly, so the `fired` signal path is only parse-checked until the user shoots in game.

### Files changed

- `scripts/player/lumencaster_viewmodel.gd` (new), `scripts/player/lumencaster.gd`
- `scripts/world/main.gd`, `scripts/world/gloom_manager.gd`, `scripts/world/enemy_director.gd`
- `scenes/world/main.tscn`, `project.godot`, `STATE.md`, `DEVLOG.md`

### Commit message

`Add Lumencaster viewmodel and M4 debug spawn keys`

## 2026-11-16 — M4 cave enemy spawning

### Done

- Split surface placement into `_find_surface_spawn_position` and added `_find_cave_spawn_position`; `_find_spawn_position` tries the surface first, then the cave fallback.
- Cave placement samples 16 random cells inside the eligible chunk, below `get_surface_height - 2`, requiring air at the cell and the cell above plus a solid block below. It reuses the existing 10–28 m distance, chunk-index, and line-of-sight rejection, so cave enemies do not appear in the player's view.
- Kept surface behavior unchanged; cave spawns use the same enemy mix and chunk cooldown as surface spawns.
- Made the viewmodel resolve `VoxelWorld` through its scene `owner` instead of `get_tree().current_scene`, which is null when the main scene is instantiated manually by a test harness.

### Verified

- Added `debug/cave_spawn_check.gd`, a headless SceneTree check that loads the real main scene, finds a generated cave cell, places the player 12 m away, and calls `_find_cave_spawn_position` until it returns a spot. It passed: `chunk=0 spawn=(13.5, 2.05, 1.5) distance=11.5`, and the returned cell had air above and solid ground below.
- Re-ran the 600-frame headless main-scene startup: exit 0, world generated, light bake completed in 134 frames (max 13738 µs), and no runtime errors.
- The check also caught and verified the fix for the viewmodel's null `current_scene` lookup.

### Broken / not verified

- Cave spawn frequency and whether cave Gloomlings feel fair are playtest questions; the cave path passed once per check run and uses randomized sampling.
- Cave Gloomlings still use the existing horizontal chase with no pathfinding, so they cannot follow the player between cave levels.

### Files changed

- `scripts/world/enemy_director.gd`, `scripts/player/lumencaster_viewmodel.gd`, `debug/cave_spawn_check.gd` (new), `STATE.md`, `DEVLOG.md`

### Commit message

`Add cave enemy spawning for underground Gloom`

## 2026-11-16 — M4 visual polish and weapon simplification

### Done

- Removed the firing economy for this phase: all four cartridges now have `energy_cost = 0`, and `minimum_light = 0` so shots work away from torches. The existing reserve gates remain in code for restoration; Projector Mode still spends Lumen.
- Confirmed the Excavator was already instant: it breaks the raycast block in the same shot, with no charge/beam state to remove.
- Upgraded the muzzle flash from a box to a bright emissive sphere, shown for 0.05 s and scaled randomly per shot.
- Added `scripts/fx/vfx.gd` (`Vfx.burst`), a one-shot `GPUParticles3D` helper with per-effect color, direction, count, speed, size, lifetime, and glow. Block hits emit amber sparks along the face normal; enemy hits emit magenta sparks.
- Rebuilt the Gloomling visual: near-black sphere with two red emissive eyes, a sine-wave bob on a visual child, and a dim purple smoke burst on dissolve. Lamp Eaters keep the base placeholder sphere.
- Raised the block palette contrast: pale ash surface, dark earth, charcoal stone, rust iron, bright teal crystal, violet mycelium, bone pale bloom, near-black rotted soils.
- Debug F6/F7/F8 were already present and were left in place.
- Fixed two issues found while testing: debug enemy spawning now retries angles near world edges instead of placing out of bounds, and enemies resolve the world/player through the scene root when `current_scene` is null.

### Verified

- Headless editor import exited 0 with `Vfx`, `Gloomling`, `GloomEnemy`, `Lumencaster`, and `LumencasterViewmodel` registered and no parse errors.
- Extended `debug/cave_spawn_check.gd`; three consecutive headless runs all passed: cave spawn, particle burst creation, debug Gloomling spawn, and a real `_fire_selected_cartridge()` call that emitted `fired`.
- 600-frame headless startup exited 0: world generated and light bake completed in 123 frames (max 9004 µs); only the pre-existing startup slow-frame warnings appeared.

### Broken / not verified

- Rendered particle visibility, muzzle-flash brightness, eye glow, bob feel, and the new palette are not verified headlessly; they need the user's visual review.
- `GPUParticles3D` creation is verified, but not on-screen Compatibility-renderer output.
- With `minimum_light = 0`, the Bible's pitch-black firing restriction is intentionally disabled for this phase and must be restored with the reserve economy.

### Files changed

- `scripts/fx/vfx.gd` (new), `scripts/enemies/enemy_base.gd`, `scripts/enemies/gloomling.gd`
- `scripts/player/lumencaster.gd`, `scripts/player/lumencaster_viewmodel.gd`, `scripts/world/enemy_director.gd`
- `data/cartridges/*.tres`, `data/blocks/*.tres`, `debug/cave_spawn_check.gd`, `STATE.md`, `DEVLOG.md`

### Commit message

`Polish Lumencaster and Gloomling visuals, remove firing costs`

## 2026-11-16 — Ashen Flats world generation overhaul

### Done

- Reverted the jagged spike/chasm/plateau heightfield after playtest: it read as chaotic blocks. Terrain is again a gentle FBM plain plus detail noise, clamped 16–28 and landing at 17–23 with a max adjacent slope of 2.
- Kept the flattened spawn clearing and the 7-block structure suppression, so the player still spawns on clean ground.
- Added deterministic dead trees using `dead_wood` (block index 11), recolored from near-black to medium-dark grey so trunks read against the pale plain: 11–20 block trunks, occasional 2x2 bases, lean every fourth step, branches only in the upper half, a four-arm crown, and pale ash blooms (`pale_bloom`) on 35% of branch tips.
- Added eight landmark trees in a ring 10–20 m from spawn, so a grove is visible immediately instead of depending on random density.
- Added giant Lumen-crystal clusters: 3–5 shards, sometimes a 12–17 block central shard, 2x2 bases that taper. Two landmark clusters at `(80,51)` and `(46,77)`; one is visible from spawn.
- Removed large brown dirt patches from the surface; the plain is now pale ashen soil with rare charcoal stone outcrops.
- Brightened daytime from 0.22 to 0.5 sky level (twilight 0.16) and raised dither bands from 6 to 8, so the world reads as a pale overcast day instead of near-night.
- Added a flashlight toggle on T. `VoxelWorld.set_flashlight_enabled()` updates the shader uniform, `get_flashlight_level_at()` returns 0 when off, and the HUD shows `T flashlight ON/OFF`.

### Verified

- Headless editor import exited 0 with no parse errors.
- Generated-world counts: `dead_wood=4843`, `pale_bloom=285`, `lumen_crystal=572`, `ashen_soil=15894`, `stone=248947`, `dirt=65534`.
- Extended `debug/cave_spawn_check.gd`: heights 17..23, relief 6, max adjacent slope 2, tall dead wood and tall crystal present, spawn cell clear, flashlight action and shader flag wired. Cave spawn, particle burst, debug Gloomling spawn, and firing checks also pass.
- 1,200-frame headless startup exited 0; light bake completed in 204 frames (max frame work 10,747 µs).
- Captured the spawn view with the flashlight off and reviewed it: individual trunk/branch silhouettes, visible crystal, pale plain. The temporary capture script and screenshot were deleted afterward.

### Broken / not verified

- Night appearance with the brighter day settings is not re-reviewed; the 15-minute night still drops sky level to 0.
- No long-session performance test with 572 crystal light blocks; tune `CRYSTAL_DENSITY` if editing near clusters stutters.
- No cave trees or ceiling crystals; structures are surface-only.
- A startup capture occasionally catches one frame of the muzzle-flash sphere before it hides; the in-game flash is still the intended 0.05 s on fire.

### Files changed

- `scripts/world/world_generator.gd`, `scripts/world/world.gd`, `scripts/world/main.gd`, `data/blocks/dead_wood.tres`, `data/world/day_night_config.tres`, `project.godot`, `debug/cave_spawn_check.gd`, `STATE.md`, `DEVLOG.md`

### Commit message

`Restore gentle Ashen Flats plains and add a visible dead grove`## 2026-11-16 — Terrain and tree art pass

### Done

- Rebuilt the Ashen Flats heightfield from three layered noise octaves (broad landform, hills, fine detail) and cut the fine detail amplitude so the plain reads as smooth rolling dunes instead of a crumpled one-block mosaic.
- Surface material: pale ashen soil with coherent charcoal stone where the local slope exposes rock, plus rare coherent outcrops, replacing the old high-frequency black speckle that covered the plain.
- Replaced per-column decoration RNG with deterministic per-grid-cell placement: trees on an 11-block grid and crystal clusters on a 24-block grid, both stamped with a reach margin so neighbouring chunks produce identical, complete structures.
- Rewrote the dead trees: 2x2 ground-level root flare, coherent single-axis lean with filled elbows, thick-trunk and broken-stump variants, face-connected stair-step branches (no edge-only diagonal cubes that read as floating), drooping twigs, forked spires, and pale ash blooms on some tips.
- Slimmer crystal clusters: tapered central shard plus 2–4 leaning side shards and a single nub; landmark clusters are taller.
- Added sparse flush lichen patches (`mycelium` / `pale_bloom`) on ashen soil for colour accents without littering single cubes.
- Mesher now bakes per-face sun shading, per-corner voxel ambient occlusion, and a small deterministic per-block tone variation into vertex `COLOR.rgb`; baked light stays in `COLOR.a`.
- Palette: brighter charcoal stone, warmer dirt, lighter dead wood, dustier violet mycelium.
- Sky: procedural gradient sky plus pale distance fog, driven by the day/night cycle; daytime sky level 0.5 → 0.6, twilight 0.16 → 0.2.

### Verified

- `--headless --editor` import exits 0 with no script parse errors.
- `debug/cave_spawn_check.gd` passes: terrain 17..28 (relief 11, max adjacent slope 1), tall wood and crystal features, clear spawn cell, flashlight toggle, cave spawn, VFX, Gloomling debug spawn, and cartridge fire.
- Reviewed 854x480 captures for the spawn view, a close tree portrait, a wide vista, a torch-lit night, and the day torch: branches are connected, terrain contours read cleanly, and the sky/fog gradient works in Compatibility.
- Before/after vista captures kept at `debug/evidence/terrain_before_wide.png` and `debug/evidence/terrain_after_wide.png`; the temporary capture script was deleted.

### Broken / not verified

- No timing measurement of the AO mesher. It runs on `WorkerThreadPool`, but the added corner queries were not profiled.
- Startup slow-frame warnings during generation/lighting remain unchanged from before this pass.
- Night fog/sky behaviour under Gloom was not playtested beyond the static capture.

### Files changed

- `scripts/world/world_generator.gd`, `scripts/world/chunk_mesher.gd`, `scripts/world/day_night_cycle.gd`
- `data/world/world_environment.tres`, `data/world/day_night_config.tres`
- `data/blocks/stone.tres`, `data/blocks/dirt.tres`, `data/blocks/dead_wood.tres`, `data/blocks/mycelium.tres`
- `debug/evidence/terrain_before_wide.png`, `debug/evidence/terrain_after_wide.png`
- `STATE.md`, `DEVLOG.md`

### Commit message

`Rework Ashen Flats terrain, trees, and voxel shading`
## 2026-11-16 — P0 gun feel pass

### Done

- Added `cartridge_next` / `cartridge_prev` InputMap actions (wheel down / up) and moved cartridge selection into `_select_cartridge`, which wraps and emits `cartridge_changed`. Wheel cycling is disabled while Projector Mode is active; the wheel still sets build depth during a projector drag.
- HUD readout now shows `NAME n/4`; a new `HUD/ContextHint` overlay lists Projector Mode controls for 6 s with a fade-out, and hides immediately on exit.
- Esc cancels an active projector drag, or leaves Projector Mode when idle. The event is consumed, so it no longer also toggles mouse capture.
- Added `accent_color` to `CartridgeDef` and all four rounds (amber excavator, cyan beacon, magenta photon, orange flare). The viewmodel gained an emissive top stripe and muzzle ring tinted by the selected round, switching to projector cyan while in Projector Mode.
- Strengthened fire feedback: recoil gain ×1.25 with a higher cap, muzzle flash 0.07 s, wider flash size range.

### Verified

- Headless editor import exited 0 with no script parse errors.
- New `debug/gun_feel_check.gd` passed every check: wheel actions, direction and wrap, distinct accents, HUD/viewmodel indicator recolour, projector hint text and hide, wheel lockout in Projector Mode, Esc drag cancel and mode exit, kick emission, recoil and flash reaction.
- 600-frame headless startup: `M1 world generated seed=139732 ... chunks=256`, `M2 incremental light bake complete: chunks=256 frames=223`, no errors or >20 ms warnings.

### Broken / not verified

- Sound and distinct per-cartridge behaviours (beam/arc) are deliberately out of this pass, as are the numeric reserve readout and a camera punch.
- Feel was validated by scripted state checks only; no hand playtest yet.

### Files changed

- `scripts/player/lumencaster.gd`, `scripts/player/lumencaster_viewmodel.gd`, `scripts/player/cartridge_def.gd`
- `data/cartridges/excavator.tres`, `data/cartridges/beacon.tres`, `data/cartridges/photon_slug.tres`, `data/cartridges/flare.tres`
- `scenes/world/main.tscn`, `project.godot`
- `debug/gun_feel_check.gd`
- `STATE.md`, `DEVLOG.md`
## 2026-11-16 — Distinct cartridge behaviours and P1 ground props

### Done

- Excavator now fires a three-block drill burst along the impact axis, banking every block and reporting `DRILLED n`.
- Beacon plants its temporary light and raises a fading cyan signal pillar; Photon Slug produces an instant accent-tinted beam tracer to the hit point or max range; Flare is a gravity-arc projectile with a GPU ember trail that plants its light where it lands and splashes damage in a 1.8 m radius.
- Per-cartridge recoil kicks, and impact bursts plus the viewmodel muzzle flash are tinted by the round's `accent_color`. Added `Vfx.beam`, `Vfx.pillar`, and `Vfx.flare_projectile`.
- Added the P1 prop pass: a deterministic 7-block grid of boulder clusters, fallen logs (with raised broken ends), broken stone wall remnants with timber and rubble, and ground-cover clumps, excluded around spawn and landmarks and requiring flat ground.
- Added `debug/world_density_check.gd` and three graphical-audit captures (`debug/evidence/audit_spawn.png`, `audit_vista.png`, `audit_ground.png`) plus `debug/capture_audit.gd`.

### Verified

- Headless editor import exited 0; no script parse errors.
- `debug/gun_feel_check.gd` passed every previous P0 check plus the new ones: excavator drills three blocks and banks them, photon spawns a beam and kicks harder than the beacon, beacon plants a light, flare launches/lands/plants its light, and the projectile clears itself.
- `debug/world_density_check.gd`: 293 stone prop cells, 211 log cells and 88 cover cells above the surface; a regenerated chunk is byte-identical.
- 600-frame headless startup reached the usual 256-chunk light bake (225 frames) with no errors.

### Broken / not verified

- No hand playtest of the new behaviours; the arc, beam and pillar read only from scripted checks and the capture images.
- Props were counted, not art-reviewed up close; no perf measurement of the extra meshing.

### Files changed

- `scripts/player/lumencaster.gd`, `scripts/player/lumencaster_viewmodel.gd`, `scripts/fx/vfx.gd`
- `scripts/world/world_generator.gd`
- `debug/gun_feel_check.gd`, `debug/world_density_check.gd`, `debug/capture_audit.gd`
- `debug/evidence/audit_spawn.png`, `debug/evidence/audit_vista.png`, `debug/evidence/audit_ground.png`
- `STATE.md`, `DEVLOG.md`
## 2026-11-16 — Graphics pass: gated dither, sun lighting, viewmodel and fixtures

### Done

- `light_dither.gdshader`: the 8-band Bayer dither now fades out above `light_value` 0.26–0.60, so daylight gradients are smooth and only darkness and flashlight falloff keep the dot pattern.
- Added sun lighting: a world-space `NORMAL` varying, a wrapped `sun_direction` diffuse term, and tinted sources. The strongest of static, flashlight, sky and sun sets both brightness and colour, giving warm sunlit faces and cool sky-lit faces. Warm flashlight tint and warm horizon/sky pairing.
- `DayNightCycle` now sweeps `sun_direction` across the day and pushes `sun_color`/`sun_strength` through `VoxelWorld.set_sun`; the day starts with the sun already 0.65 rad above the horizon so spawn is not lit edge-on.
- Softened baked `FACE_SHADE` from 0.42–1.0 to 0.74–1.0, AO from 0.36–1.0 to 0.46–1.0, and narrowed per-block tone from 0.88–1.12 to 0.94–1.06 to remove the checkerboard.
- Viewmodel: scaled to 0.85, moved to `(0.22, -0.19, -0.56)`, receiver lightened, stripe narrowed from 0.134 to 0.045 and emission dimmed (1.8 → 1.1; projector 2.4 → 1.6), muzzle ring reduced to a 0.056 rim. Added shroud, magazine and a blocky hand in mid/dark non-emissive tones.
- Mesher fixtures: torches render as a dark post plus a glowing head, `pale_bloom` and `mycelium` as two-sided cross quads, all keyed through `world.fixture_ids`; cube faces are skipped for those blocks.

### Verified

- Headless editor import exited 0; no shader or script errors.
- `gun_feel_check.gd` and `world_density_check.gd` still pass end to end.
- Refreshed `audit_spawn/vista/ground.png` windowed captures confirm: no daylight dot lattice, warm sunlit ash with cool shaded faces, a smaller gun without the cyan slab, and small lantern/cross fixtures instead of full-block torches.
- 600-frame headless startup completed the light bake (233 frames); the existing startup >20 ms lighting warnings still appear.

### Broken / not verified

- Trees still read as near-black silhouettes; no palette or trunk-shape change was made in this pass.
- No bloom/glow on emissives, HUD is unchanged, and no live FPS measurement was taken after the shader change.

### Files changed

- `shaders/light_dither.gdshader`, `scripts/world/world.gd`, `scripts/world/day_night_cycle.gd`, `data/world/day_night_config.tres`
- `scripts/world/chunk_mesher.gd`, `scripts/player/lumencaster_viewmodel.gd`, `scenes/world/main.tscn`
- `debug/evidence/audit_spawn.png`, `debug/evidence/audit_vista.png`, `debug/evidence/audit_ground.png`
- `GRAPHICS_AUDIT.md`, `STATE.md`, `DEVLOG.md`
## 2026-11-16 — Watertight fixtures, charred trees, glow and surface detail

### Done

- Fixed the see-through blocks: fixture cells were solid for meshing, so the ground and walls facing them had their faces culled while the fixture only drew a small prop, leaving holes wherever flora sat in the surface. Fixtures are now non-occluding for neighbour face emission.
- Rebalanced trees toward charred wood: `dead_wood` albedo raised to warm brown (0.50, 0.42, 0.40), 42% of trees get a 2×2 trunk through the first four blocks instead of a one-block pole.
- Enabled Environment glow (supported in Compatibility) and `viewport/hdr_2d`, boosted emissive blocks 1.5× into HDR vertex colour via `world.emissive_ids`, and set glow threshold 1.0 / intensity 0.85 / bloom 0.0 so only crystals, torch heads and the muzzle flash bloom.
- Added world-space surface detail to `light_dither.gdshader`: two octaves of value-noise mottling (0.87–1.13) plus a 0.79 bevel darkening near voxel edges.
- Sky ground colour now follows the horizon (darkened) instead of the blue top colour, removing the "ocean" band at the world edge; `fog_sky_affect` raised to 0.35.
- Added `debug/mesher_fixture_check.gd` and the diagnostic captures `probe_bloom`, `probe_pit`, `probe_torch`, `probe_crystal` and `probe_flash`.

### Verified

- `mesher_fixture_check.gd`: the soil face under a mycelium fixture is emitted and the fixture renders; PASS.
- `gun_feel_check.gd`, `world_density_check.gd` and `cave_spawn_check.gd` all pass.
- Headless editor import exits 0; 600-frame startup completes the 256-chunk light bake.
- Captures confirm: no holes around flora or the dug pit, warm brown trees, soft teal halo on crystal clusters and a glowing muzzle flash, with no full-frame wash.

### Broken / not verified

- No hand playtest; the transparency fix is verified by mesh-level checks and stills.
- Glow is bright at close range (crystal and muzzle halo) and may need per-effect control; HUD and palette work remain.
- The startup >20 ms lighting-frame warnings still appear.

### Files changed

- `scripts/world/chunk_mesher.gd`, `scripts/world/world.gd`, `scripts/world/world_generator.gd`, `scripts/world/day_night_cycle.gd`
- `shaders/light_dither.gdshader`, `data/blocks/dead_wood.tres`, `data/world/world_environment.tres`, `project.godot`
- `debug/mesher_fixture_check.gd`, `debug/capture_glow.gd`, `debug/capture_props.gd`
- `debug/evidence/probe_bloom.png`, `probe_pit.png`, `probe_torch.png`, `probe_crystal.png`, `probe_flash.png`
- `GRAPHICS_AUDIT.md`, `STATE.md`, `DEVLOG.md`
## 2026-11-16 — HUD cleanup

### Done

- `DebugReadout` now starts hidden (`debug_visible := false`); F still toggles it.
- Moved `LumenReadout` from under the debug text to the top-right, right-aligned, and reduced it to the loadout only: `CARTRIDGE n/4 | BUILD <material> ×n | DEPTH n`.
- Added `HUD/StatusLabel`, centred above the crosshair, and moved all transient status messages ("PHOTON BEAM HIT", "FLARE LANDED", reserve warnings, projector errors) into it. Cartridge switching and projector-mode toggles no longer post duplicate status lines because the readout already shows them.
- Added a 1 px dark text shadow to the cartridge readout, status label and context hint so they stay readable over bright sky and ash.

### Verified

- Headless editor import exits 0; 600-frame startup completes the 256-chunk bake.
- `gun_feel_check.gd` passes with new assertions: the debug readout starts hidden, the cartridge readout is anchored top-right and right-aligned, the loadout text no longer contains status, and a fired shot posts a separate status message.
- Fresh `audit_spawn.png` and `probe_flash.png` show the quiet top-right loadout, centred status, and no debug wall of text.

### Broken / not verified

- No hand playtest of the new HUD at 1708×960; layout was checked at the 854×480 internal resolution only.
- Fonts are still the default theme font.

### Files changed

- `scenes/world/main.tscn`, `scripts/player/lumencaster.gd`, `scripts/world/main.gd`
- `debug/gun_feel_check.gd`
- `debug/evidence/audit_spawn.png`, `debug/evidence/probe_flash.png`
- `GRAPHICS_AUDIT.md`, `STATE.md`, `DEVLOG.md`
## 2026-11-16 — Palette saturation pass

### Done

- Warm ochre ash: `ashen_soil` (0.72, 0.70, 0.64) → (0.82, 0.71, 0.52).
- Cool blue-slate stone: `stone` (0.30, 0.32, 0.37) → (0.24, 0.30, 0.42).
- Red-brown charred wood: `dead_wood` (0.50, 0.42, 0.40) → (0.55, 0.37, 0.29).
- Supporting tones pushed with the same warm/cool logic: dirt (0.46, 0.29, 0.18), iron ore (0.74, 0.34, 0.13), mycelium (0.30, 0.14, 0.42), pale bloom (0.98, 0.94, 0.80), and the two rot blocks darkened toward violet.

### Verified

- Headless editor import exits 0; 600-frame startup completes the 256-chunk light bake.
- Refreshed `audit_spawn.png` / `audit_vista.png`: ash reads as warm ochre, stone as cold slate, and tree trunks as red-brown timber, so all three families separate in sun and shade while crystals stay the only saturated teal.

### Broken / not verified

- No hand playtest and no numeric contrast measurement; the judgement is from stills at 854×480.
- Iron ore now sits closer to the ash hue in low light; worth checking in a mine.

### Files changed

- `data/blocks/ashen_soil.tres`, `stone.tres`, `dead_wood.tres`, `dirt.tres`, `iron_ore.tres`, `mycelium.tres`, `pale_bloom.tres`, `rotted_ashen_soil.tres`, `rotted_dirt.tres`
- `debug/evidence/audit_spawn.png`, `audit_vista.png`
- `GRAPHICS_AUDIT.md`, `STATE.md`, `DEVLOG.md`
## 2026-11-16 — Coloured static light at night

### Done

- `static_light_sources` now carries a `cool` flag, set for `lumen_crystal` emitters and false for torch-based ones (torches, flares, beacons).
- Each mesh dispatch copies the sources within 12 blocks of the chunk into a per-task array (thread-safe snapshot), so worker threads never touch the live source list.
- The mesher bakes a per-vertex light hue: distance-weighted warm/cool blend from nearby emitters, applied only to faces with non-zero static light, with strength scaled by the baked level. Torch pools read warm amber; crystal light reads cool teal.
- The world shader's `static_light_color` is now neutral white, so the baked vertex hue is the only static-light tint — previously every static light was tinted warm, which made crystal light orange.
- Night captures added to `debug/capture_glow.gd` (`night_torch.png`, `night_crystal.png`) and tint assertions added to `debug/mesher_fixture_check.gd`.

### Verified

- `mesher_fixture_check.gd` passes: warm source bakes (1.0, 0.72, 0.47), cool source bakes (0.51, 0.85, 1.0), unlit cells stay neutral.
- `gun_feel_check.gd`, `world_density_check.gd` and `cave_spawn_check.gd` pass; headless import exits 0.
- 600-frame startup completes the 256-chunk light bake in 238 frames, so the per-face tint pass did not disturb the bake budget.
- `night_torch.png` shows a warm amber pool around the torch with the rest of the plain black; `night_crystal.png` shows cool teal cast around the crystal cluster.

### Broken / not verified

- The tint is baked without occlusion, so a torch on the far side of a wall can still warm the hue of a lit face (intensity remains correct). Worth checking in caves.
- No live night playtest; night shots are from two fixed camera positions.

### Files changed

- `scripts/world/world.gd`, `scripts/world/chunk_mesher.gd`, `shaders/light_dither.gdshader`
- `debug/mesher_fixture_check.gd`, `debug/capture_glow.gd`
- `debug/evidence/night_torch.png`, `debug/evidence/night_crystal.png`
- `GRAPHICS_AUDIT.md`, `STATE.md`, `DEVLOG.md`
## 2026-11-16 — Proper HUD and pause overlay

### Done

- Added `scripts/ui/game_hud.gd` (`GameHUD`) and reduced the scene's HUD to a single CanvasLayer node with that script. It builds all UI in code with StyleBoxFlat panels, rather than a pile of loose labels in the scene.
- Bottom-left loadout card: cartridge accent strip, name, `LUMENCASTER`/`PROJECTOR MODE` line in the cartridge accent, four cartridge pips (selected pip taller and opaque), six Lumen segments plus the numeric reserve, and a build line with material, stock and depth. Material ids render with spaces and stock 0 highlights red.
- New VITALS bar and numeric health readout above the card, a dot-and-tick crosshair, and a bordered Projector controls card.
- Status messages are polled from the Lumencaster and shown above the crosshair with a short fade; hint text and fade come from the same source, so the HUD is now the only writer of UI text.
- Pause: Esc opens a full-screen overlay with a dimmed backdrop, a 460×320 panel, a two-column controls list, and Resume/Save/Load/Quit buttons. Esc resumes; the overlay defers to the Lumencaster when it is dragging or in Projector Mode. The tree pauses and the mouse is released while open.
- `VoxelPlayer` no longer toggles mouse capture on Esc; `Main` now exposes `save_game()`/`load_game()` so the K/J keys and the overlay buttons share one path.

### Verified

- Headless editor import exits 0 and registers `GameHUD`.
- `gun_feel_check.gd` passes, including loadout card anchoring, separate loadout/status text, and pause open/resume.
- `world_density_check.gd`, `cave_spawn_check.gd` and `mesher_fixture_check.gd` pass.
- 600-frame startup completes the 256-chunk bake.
- Captures: `ui_projector.png` shows the mode tint, hint card and loadout state; `ui_pause.png` shows the pause overlay and controls.

### Broken / not verified

- Buttons were exercised by direct calls and stills, not by real mouse clicks; no hand playtest of pause/resume input ordering.
- Still the default Godot font; no title screen, settings or key rebinding.
- HUD layout is fixed to the 854×480 base resolution and was only inspected there.

### Files changed

- `scripts/ui/game_hud.gd` (new), `scenes/world/main.tscn`
- `scripts/player/lumencaster.gd`, `scripts/player/player.gd`, `scripts/world/main.gd`
- `debug/gun_feel_check.gd`, `debug/capture_audit.gd`
- `debug/evidence/audit_spawn.png`, `ui_projector.png`, `ui_pause.png`
- `GRAPHICS_AUDIT.md`, `STATE.md`, `DEVLOG.md`
## 2026-11-16 — Enemy aesthetic audit

### Done

- Audited both enemy types in-engine at night and wrote `ENEMY_AESTHETIC_AUDIT.md`.
- Added `debug/capture_enemies.gd` to spawn via the F6/F7 paths, freeze an enemy and capture it from two distances, plus a group shot.
- Captures: `enemy_gloomling.png`, `enemy_gloomling_close.png`, `enemy_lamp_eater.png`, `enemy_lamp_eater_close.png`, `enemy_group_night.png`.

### Findings

- The Gloomling's eyes are buried inside its body sphere (eye z −0.30 vs surface −0.333 at eye height), so the red eyes never render; it reads as a featureless black egg.
- The Lamp Eater still inherits `GloomEnemy._create_placeholder_mesh` and is a bright purple unshaded sphere with no eyes, limbs or lantern motif.
- Both are unshaded with no shadow, no hit reaction, no attack wind-up and no dissolve animation, so they read as pasted-on props rather than creatures.

### Verified

- `capture_enemies.gd` runs cleanly and produced all five captures. No engine changes were made, so existing gameplay checks were not rerun.

### Next

- Fix eye placement and add contact shadows first, then rebuild both silhouettes, add flashlight-reactive bodies, wind-up/lunge telegraphs and a dissolve beat.
## 2026-11-16 — World art direction research

### Done

- Researched why the world reads as cheap and wrote `WORLD_ART_DIRECTION.md`: diagnosis, target look, per-system plan, phased roadmap, performance budget and verification criteria.
- Confirmed Godot Compatibility constraints (depth/height fog, glow, tonemap and a fullscreen post pass are available; volumetric fog, SSR, SSIL and SDFGI are not), so the plan fakes volumetric mist with billboards and baked sun occlusion.
- Called out the ten concrete causes in the current build: untextured flat vertex colour, linear lighting with no colour ramps, no real shadows or contact shadows, empty sky/fog, noise-only dunes with no landmarks, voxel trees, uniform density, residual dither, no ambient motion, and the default Linear tonemap.
- Proposed the non-voxel asset pivot (explicitly allowed by the user): procedural low-poly dead trees via MultiMesh, alpha-card ash grass with wind, faceted boulders, modular ruins and prism crystal shards.

### Verified

- No engine changes in this pass; existing captures and code were used as evidence.
- Renderer capability claims checked against the Godot renderer feature matrix and Environment docs.

### Next

- Start Phase 1: tonemap, exposure, height fog, sky shader, vignette/grain and glow retune, then Phase 2's procedural tree pipeline.
## 2026-11-17 — Atmosphere + sky pass

### Done

- Added `shaders/sky_ash.gdshader`: stylised sky gradient with a small hard sun disc, soft halo, sun-biased horizon glow, a twilight band and hashed night stars. It replaces the old `ProceduralSkyMaterial`.
- `DayNightCycle` now drives the sky shader (top/horizon/ground colours, sun direction/colour/energy, star and twilight energy, horizon glow) and grades the fog per phase. Stars fade in below 0.10 daylight and are gone by 0.38.
- Environment switched to AgX tonemapping with exposure 1.0 and a light brightness/contrast/saturation adjustment. Height fog is on (height 8, height density 0.05, density 0.0016 day / 0.0030 night) with sun scatter 0.35 and sky affect 0.22.
- Added `ScreenGrade` (CanvasLayer 0, below the HUD) and `shaders/screen_grade.gdshader`: screen-texture vignette, 14 fps grain, small shadow lift and 1.06 saturation.
- HUD gained a top-right `FlashlightState` label that reads `TORCH ON/OFF` from `world.flashlight_enabled`.

### Tuning

- First capture was over-fogged with a halo that filled the sky. Reduced density, cut sky affect, shrank the halo exponents, saturated the authored sky colours (AgX desaturates), and raised the twilight band. Final captures keep a blue zenith and warm dusk horizon while distance still hazes.

### Verified

- Headless editor import: no parse errors.
- Windowed captures at 854×480 for day, dusk and night ground and sky views, saved in `debug/evidence/atmo_*.png`.
- 600-frame headless startup: exit 0, 256-chunk light bake in 234 frames, max light-work frame 9102 µs. The known headless bake >20 ms warnings remain unchanged.

### Next

- Phase 2: procedural low-poly dead trees and MultiMesh ground cover so silhouettes stop reading as stacked cubes.
