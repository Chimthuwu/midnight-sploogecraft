# Lumenfall — world art direction research and rebuild plan

Goal: make Ashen Flats beautiful and atmospheric instead of cheap, using Godot 4.7.2
on the Compatibility renderer at 854×480, and explicitly allowing non-voxel art for
vegetation, props and landmarks.

Evidence used: `debug/evidence/audit_spawn.png`, `audit_vista.png`,
`audit_ground.png`, `night_torch.png`, `night_crystal.png`, plus the current
renderer code (`shaders/light_dither.gdshader`, `scripts/world/chunk_mesher.gd`,
`scripts/world/world_generator.gd`, `data/world/world_environment.tres`).

## 1. Why it currently reads as cheap

1. **No image texture anywhere.** Every surface is one flat vertex colour. A 1 m
   block face with a constant albedo is the definition of "untextured prototype".
2. **No colour ramp.** Light is a linear multiply, so shadows just get darker and
   desaturated. Film and games use hue-shifted ramps; that is why lit ash should turn
   gold and shaded ash should go violet, not grey.
3. **Flat lighting.** The world material is `unshaded`, there are no real-time
   shadows, and the DirectionalLight affects almost nothing. There is no contact
   between objects and ground, so everything floats visually.
4. **Sky is a two-colour gradient with no sun, moon, stars or cloud structure**, and
   fog is a single depth-fog colour. There are no depth layers to look at.
5. **Dunes are noise + 1-block steps.** No mesas, ridges, craters, dry riverbeds or
   cliffs; no macro composition, no landmark, no focal point.
6. **Trees are made of 1 m cubes.** A dead tree needs a branching silhouette with
   taper; a stack of cubes reads as scaffolding, not as a tree.
7. **Density is uniform-ish.** Trees, props and rocks are scattered by regular grids,
   so the eye finds no clusters, clearings, groves or negative space.
8. **Repeating 8×8 Bayer dots.** We gated the dither in daylight, but it still
   quantises surface tone; at this resolution the pattern is coarser than the art.
9. **No motion except enemies and the player.** No wind, drifting ash, dust devils,
   hanging vines, flickering light.
10. **Default tonemap (Linear).** The environment has no `tonemap_mode`, so highlights
    clip and the image has no filmic response. This alone makes a render look cheap.

## 2. Target look

**"A pale ash desert at the end of the world, lit like a remembered dream."**

Pillars, in priority order:

- **Silhouette first.** Dead trees, spires and ruins must read as black shapes on a
  luminous sky before any surface detail matters.
- **Atmospheric depth.** Three distinct depth layers: crisp foreground (dark, warm
  AO), mid-ground (saturated, readable), far ground (low contrast, cool haze).
  This is the single biggest difference between cheap and cinematic.
- **One hero colour per frame.** Ash gold + sky blue, or crystal teal + ember amber
  at night. Everything else supports it.
- **Hand-placed-feeling landmarks.** A colossal dead tree, a crystal spire visible
  from spawn, a broken arch on a ridge. Voxel noise cannot create awe; landmarks can.
- **Movement and air.** Wind in grass and cloth, ash motes, slow rolling ground mist.
- **Texture without noise.** Two or three procedural detail textures (ash grain,
  stone strata, bark) sampled triplanar; enough to catch light, never busy.

Reference touchstones: the palette discipline of *Journey* and *Sable*, the fog
layering of *Firewatch*, the readable silhouettes of *Limbo*, and the voxel
material treatment of *Teardown* (surface detail on a chunky grid).

## 3. System-by-system plan

### 3.1 Sky and time of day (high impact, low cost)

- Replace the flat `ProceduralSkyMaterial` gradient with a **custom sky shader**:
  three-stop vertical gradient (zenith / horizon / below-horizon), sun disc with
  bloom, moon, a sparse star field that fades in at night, and a thin high cloud
  band using two scrolling value-noise layers.
- Keep the existing four-phase cycle but drive **colour scripts** per phase instead
  of lerping two colours: day (pale gold horizon, desaturated blue zenith), twilight
  (burnt orange / magenta), night (deep indigo / teal), dawn (rose / cold blue).
- Tie the sun shader direction to `DayNightCycle._update_sun()` so sky, sun light and
  the baked-world sun term agree.

### 3.2 Atmosphere and fog (high impact, low cost)

- Turn on **environment fog with height** (`fog_height`, `fog_height_density`) in
  addition to depth fog: mist pools in basins and along the horizon while ridges stay
  clear. This is the cheapest way to get "expensive" depth.
- Enable **`fog_sun_scatter`** and `fog_aerial_perspective` so the sky and fog agree
  and the sun bleeds into the haze.
- Add 3–5 large, slow **mist billboards** (alpha-noise quads, 30–60 m wide) at low
  altitude for volumetric-looking ground fog; Compatibility has no volumetric fog,
  so this is the substitute.
- Add **ash motes** as a camera-attached `GPUParticles3D` (200–400 particles, 8–20 m
  radius, near-zero gravity, additive material, depth-tested off). Subtle, continuous,
  huge perceived-quality gain.

### 3.3 Lighting, shadow and contact

- Set a real **tonemap** (AgX or Filmic) and exposure/white in
  `world_environment.tres`. AcES pushes orange toward yellow; AgX keeps ember access
  amber. Then retune the palette once — everything will look richer immediately.
- Terrain currently cannot receive shadows because the material is unshaded. Two
  options:
  - **Recommended:** add **baked sun occlusion** in `chunk_mesher.gd` — march the
    column toward the sun through the block snapshot and darken vertex colour where
    occluded. This gives long cliff and ruin shadows with zero runtime cost.
  - Optional later: move terrain to a lit material for true shadow maps; costs the
    dither identity and needs the shader rewritten.
- Make all non-voxel props (trees, rocks, ruins) use **lit StandardMaterial3D** with
  roughness ~0.9 and let the shadowed DirectionalLight cast their long shadows onto
  the ground. One shadowed directional is supported in Compatibility.
- Add a **contact shadow** under every prop and tree: a small dark quad, scaled to
  the object, slightly above the ground. Cheap grounding.
- Increase the sun's `directional_shadow_max_distance` only enough to cover the
  60–80 m play area; at 854×480, 2048 shadow map is plenty.

### 3.4 Terrain surface and material treatment

- Add **procedural detail textures** (generated at load with `FastNoiseLite` into
  `NoiseTexture2D`, or authored as small PNGs): ash grain, stone strata, bark. Sample
  them **triplanar** in the world shader using world position and normal, at 2–4 m
  and 0.4 m scales. Modulate albedo ±8% only — detail, not noise.
- Introduce **colour ramps** per material: shadow / mid / lit colours (e.g. ash
  shadow `#4b4560` violet, mid `#b9a77f`, lit `#e7c98a`). Pack ramps into a 1D
  palette texture sampled by block id; replace the linear albedo × light with a
  ramp lookup. This is the biggest single material upgrade available.
- **Top-face treatment:** give top faces a slightly lighter, warmer variant than
  side faces (voxel-art standard), on top of the existing `FACE_SHADE`.
- **Micro-detail:** in `world_generator.gd`, displace 1–3 voxels per 8×8 surface
  patch, add pebble clusters and shallow cracks. Research on voxel art is unanimous
  that a few displaced voxels per surface do more than any texture.
- Reduce dither quantisation further in mid-light (or switch to 4-band with
  blue-noise); reserve visible dithering for night/flashlight.

### 3.5 Macro terrain and composition

- Rewrite the height function as **shaped landforms**, not pure fBm:
  - a broad basin around spawn with a raised rim (natural frame),
  - 2–3 long ridges/mesas at 6–10 m relief with cliff faces,
  - a dry riverbed winding through, 2–3 blocks below the plain,
  - one crater or sinkhole.
- **Landmarks** placed by hand-authored coordinates, not noise:
  - a 25–35 m dead titan tree at the spawn sightline,
  - a 20 m crystal spire cluster on a ridge, visible from anywhere,
  - a broken stone arch or fallen colossus at mid-distance.
- Use **density masks**: empty ash basins, dense dead groves, sparse crystal fields.
  Empty space is a composition tool; uniform scatter reads as procedural.

### 3.6 Vegetation — stop using voxel trees

This is explicitly allowed now and is the highest-impact art change.

- **Trees:** procedurally generate 6–10 **low-poly dead-tree archetypes** as
  `ArrayMesh`es at load: tapered cylinders for trunk and branches, 3–5 recursion
  levels, slight gnarl, broken tips, a few twig cards. Flat-shaded, bark texture,
  vertex-colour variation, 6–14 m tall. Instance via `MultiMeshInstance3D` per
  archetype (one draw call each, shadows on). Keep voxel root mounds and fallen logs
  for ground continuity.
- **Grass/ash tufts:** 3–5 crossed alpha-tested quads per tuft, one MultiMesh of
  ~3000–6000 instances in a 40 m radius around the player (respawned in tiles as the
  player moves), with a wind shader (vertex sway by world position + time). One draw
  call, huge life gain.
- **Shrubs:** billboard cards or low-poly clumps, not full cubes.
- **Hanging vines / dead creepers:** thin card strips on tree and ruin edges, wind-swayed.
- **Distant trees:** billboard impostors or 2-triangle silhouettes at >50 m to keep
  the horizon dense without cost.

### 3.7 Rocks, ruins and props

- Replace voxel pebble clusters with **faceted low-poly boulders** (deformed
  icospheres, flat shading, 3–8 m³) in MultiMeshes with per-instance rotation/scale.
- Ruins as **modular low-poly meshes**: broken wall segments, arches, column stumps,
  a collapsed roof beam, sized 2–6 m and placed on ridges. Voxel ruins can stay for
  small rubble only.
- Props should have **material hierarchy**: stone (cool, rough), timber (warm, rough),
  metal (dark, slight sheen), cloth (frayed cards). Right now everything is one flat
  colour.

### 3.8 Crystals and emissives

- Replace cube-column crystals with **faceted prism shards** (custom ArrayMesh,
  tapered, slight irregularity, internal fracture planes via emissive texture).
- Add an **inner core** mesh with additive emission so the crystal looks lit from
  within, plus a soft additive billboard halo at 1.2–1.6× size.
- Keep the warm/cool static light split; add a subtle pulse (0.95–1.05 emission) so
  the world breathes.
- Torches: keep the post + head, add a flickering additive sprite and a small
  `OmniLight3D` (no shadows) so nearby enemies/props catch warm light.

### 3.9 Motion and life

- Wind field: a single global direction + gust noise, used by grass, vines, cloth,
  ash motes and tree sway. One shader uniform.
- Ambient particles: drifting ash (always), embers near torches, dust devils
  (occasional, 4–8 s, on the plain), fireflies/motes near crystals at night.
- Water: a shallow toxic/dark water plane in the riverbed with a scrolling normal
  texture and reflection faked by a lighter horizon colour. Even a simple animated
  plane adds enormous atmosphere.
- Bird/bat silhouettes crossing the sky at dusk (3–5 billboard sprites).

### 3.10 Post-processing and camera

- `Environment`: AgX tonemap, exposure ~1.0–1.2, adjustments (contrast +0.05,
  saturation +0.05), glow threshold ~1.0 with a little bloom on emissives.
- Add a **fullscreen post shader** (supported in Compatibility as a fullscreen
  quad/CanvasLayer): subtle vignette, film grain at 3–5%, slight chromatic aberration
  at the edges, and a gentle blue-lift in shadows. Keep it under 10% strength.
- Camera: FOV 70 (currently default 75), slight head bob, subtle breathing sway when
  idle, a 2–3 cm landing dip. No camera shake spam.
- Consider a 2.35:1 letterbox option for cinematic moments (landmark reveal), but not
  as the default.

### 3.11 Audio (50% of atmosphere)

Wind bed with altitude-dependent filtering, distant metal creaks, crystal chimes that
respond to proximity, footstep material variants (ash, stone, wood), torch crackle,
a low sub drone that rises with Gloom. Even placeholder procedural audio will make
the same scene feel twice as expensive.

## 4. Two viable art paths

**Path A — "Stylised dither evolution" (fast, 1–2 weeks)**
Keep the unshaded baked-light look, add colour ramps, triplanar detail, height fog,
tonemap, sky shader, non-voxel trees/grass/rocks, landmarks and particles. Target:
cohesive retro-diorama, like a high-end PS1-era art piece. Lower risk, preserves the
dither identity.

**Path B — "Painted voxel diorama" (3–5 weeks)**
Move the terrain to a lit material with real shadows, PBR-ish roughness, texture
atlases, SSAO (if confirmed on target) and a full post stack. Target: modern
stylised realism. Higher ceiling, but the dither mechanic and the flat-shaded
identity would need re-authoring.

**Recommendation: A now, with two B prep steps** — write the terrain shader so the
light term is isolated behind a function (easy to swap to lit later), and build the
non-voxel asset pipeline (trees/grass/rocks) that both paths share.

## 5. Phased plan

**Phase 1 — free wins (1–2 days)**
Tonemap + exposure + adjustments; height fog + sun scatter; sky shader with sun and
stars; vignette/grain post; glow retune. Expected: immediately less cheap.

**Phase 2 — silhouette pass (3–5 days)**
Procedural low-poly dead-tree archetypes + MultiMesh + shadows + contact shadows;
replace voxel trees in generation. This changes the skyline more than anything else.

**Phase 3 — ground and material (4–6 days)**
Triplanar detail textures, colour ramps, top-face variation, micro-detail voxels,
grass MultiMesh with wind, low-poly boulders and modular ruins.

**Phase 4 — composition (3–4 days)**
Macro landforms (basin, ridges, riverbed), hand-placed landmarks, density masks,
crystal shard meshes with inner glow, water plane.

**Phase 5 — life and polish (3–4 days)**
Ash motes, mist billboards, dust devils, wind field, ambient audio, camera feel,
final colour script per phase, screenshot review.

## 6. Performance budget (854×480, 60 FPS target)

- Draw calls: stay under ~120 total. Current M1 measured 43. MultiMesh trees (8–10
  archetypes), grass (1), rocks (1–2), ruins (1–2) add ~15.
- Vertices: terrain unchanged; trees ~2–5k tris each archetype instanced; grass
  ~6 quads × 4000 = 48k tris; fine at this resolution.
- Shadows: one 2048 directional shadow map, max distance 80 m, only props/trees cast
  (terrain uses baked sun occlusion).
- Particles: <1000 live particles; all `GPUParticles3D`, no CPU simulation.
- Post: one fullscreen pass, no SSAO/SSR.
- Keep the 7 ms light budget and asynchronous meshing untouched.

## 7. Verification

- A screenshot set per milestone from the same three cameras (spawn, vista, ground)
  plus a night shot, compared side by side (`debug/capture_audit.gd`).
- Colour check: histogram p05/p95 and focal contrast; avoid crushed blacks under 0.03
  and clipped highlights over 0.97 except emitters.
- Perf: draw calls, frame time and slow-frame warnings on a 600-frame headless run
  plus a windowed 60 FPS check.
- Art review questions: can you name the focal point in 2 seconds? Are there three
  depth layers? Does the silhouette read at 100 m? Is there one hero colour?

## 8. Sources

- Godot renderer feature matrix (fog, glow, tonemap supported in Compatibility;
  volumetric fog/SSR/SSIL/SDFGI not): docs.godotengine.org, "Overview of renderers".
- Godot Environment docs: height fog, fog sun scatter, aerial perspective, glow
  limitations in Compatibility, tonemap modes.
- Voxel art technique references: palette constraint (8–16 colours), top-face colour
  variants, silhouette-first design, breaking flat surfaces with 2–3 details per 8×8.
- Atmospheric perspective / height-fog practice from graphics-programming write-ups on
  screen-space exponential height fog.
