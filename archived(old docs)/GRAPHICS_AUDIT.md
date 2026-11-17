# Lumenfall graphical audit

Audited against Godot 4.7.2, Compatibility renderer, 854×480 internal resolution.
Evidence: `debug/evidence/audit_spawn.png`, `audit_vista.png`, `audit_ground.png`
(captured with `debug/capture_audit.gd`).

## Resolved in the follow-up pass (2026-11-16)

- **Dither gating:** darkness stays banded and dithered, daylight is smooth
  (`dither_gate = 1 - smoothstep(0.26, 0.6, light_value)`), so the dot lattice is
  gone from sunlit ground.
- **Sun and warmth:** `light_dither.gdshader` now has `sun_direction`,
  `sun_strength`, `sun_color`, `sky_tint`, `flashlight_color` and
  `static_light_color`; the strongest source sets brightness and tint, so sunlit
  faces are warm and shaded faces cool. `DayNightCycle` sweeps the sun across the
  day and warms the horizon/sky pair.
- **Viewmodel:** scaled to 0.85 and pushed to `(0.22, -0.19, -0.56)`, stripe
  narrowed to 0.045 and dimmed, muzzle ring shrunk to a rim, plus shroud, magazine
  and a blocky hand in three non-emissive tones.
- **Fixture meshes:** the mesher now draws torches as a post + glowing head and
  `pale_bloom`/`mycelium` as two-sided cross quads instead of full cubes.
- **Tone:** baked face shading and AO softened and per-block tone narrowed to
  0.94–1.06 to stop the checkerboard.

- **Trees:** `dead_wood` is now a red-brown charred tone (0.55, 0.37, 0.29) and 42%
  of trees use a 2×2 trunk through the first four blocks, so they read as burnt
  timber instead of black cut-outs.
- **Glow:** Environment glow enabled (Compatibility supported), HDR 2D turned on,
  emitters boosted to HDR vertex colour, threshold 1.0 / intensity 0.85 so only
  crystals, torch heads and the muzzle flash bloom.
- **Surface detail:** world-space value-noise mottling plus a dark seam toward
  every voxel edge, in the world shader.
- **Transparency fix:** fixture blocks no longer occlude neighbouring faces, which
  was leaving see-through holes wherever flora sat in the ground surface
  (`debug/mesher_fixture_check.gd` guards this).

- **HUD:** debug readout off by default, loadout moved to a right-aligned
  top-right line, transient status split into its own centred label above the
  crosshair, and text shadows added.

- **Palette separation:** ash is now warm ochre (0.82, 0.71, 0.52), stone cool
  blue-slate (0.24, 0.30, 0.42), and dead wood red-brown (0.55, 0.37, 0.29), with
  dirt, ore, mycelium and rot pushed to match. The three ground families now hold
  apart in both sun and shade.

- **Night light colour:** static light is baked with a warm/cool hue per vertex
  from nearby emitters, so torch pools are amber and crystal light is teal once
  the sun is gone (`night_torch.png`, `night_crystal.png`).

- **HUD rebuild:** replaced the loose labels with a `GameHUD` layer: loadout card
  with accent pips and a Lumen reserve bar, VITALS bar, dot crosshair, centred
  status, Projector card and a pause/controls overlay with save, load and quit.

Still open: fog/sky horizon treatment and a custom font for the HUD.

## Verdict

The world is built from a solid technical base but the image is dominated by three
problems that read as "looks bad" before any content is judged:

1. A visible Bayer dot grid over every surface.
2. A monochrome grey palette with no sun, so terrain, sky, fog and trees collapse
   into one flat grey field.
3. A viewmodel that fills a third of the screen with a flat, fully emissive cyan
   slab.

Content itself (trees, props, crystals) is present but is then darkened into
near-black silhouettes by the lighting math, so the detail cannot be read.

## 1. Dither is being used as a texture, not as a shadow treatment

`shaders/light_dither.gdshader` quantises every fragment to 8 bands and applies an
8×8 Bayer threshold across the whole light range. Most of the visible plain sits in
a mid band, so roughly half the pixels flip to the next band and the result is a
uniform dot lattice at screen scale. It is most obvious on the ash plain in
`audit_spawn.png` and `audit_vista.png`.

Causes:

- `dither_bands = 8.0` (`scripts/world/world.gd:146`) applied unconditionally.
- The threshold is compared against `fract(scaled)` with no strength control, so
  band interiors are always noisy, not just band edges.
- The pattern is screen-space, so it slides over the world when the camera moves.

Direction:

- Keep dithering only where it is wanted: darkness, flashlight falloff and Gloom
  transitions. At daylight levels above ~0.55, skip quantisation entirely.
- Or scale the dither amplitude by the fractional distance to the band edge
  (e.g. `step(threshold, fract(scaled) * strength)` with `strength < 0.25`), which
  keeps the retro banding on gradients without carpeting flat faces in dots.
- If the dot lattice is intended as texture, move it to world space at a larger
  cell size (2–4 px equivalent in world units) so it reads as grain, not moiré.

## 2. Everything is grey because the lighting has no colour or direction

`ALBEDO = COLOR.rgb * quantized_light` in an `unshaded` shader, where
`COLOR.rgb` already contains `palette × FACE_SHADE × AO × tone`. At day
(`day_sky_level = 0.6`) the surface value is roughly
`albedo × 0.42…1.0 × 0.36…1.0 × 0.6`, so:

- Stone (`0.30, 0.32, 0.37`) bottoms out near `0.03` on a shaded, occluded face —
  black.
- Dead wood (`0.34, 0.31, 0.34`) renders as near-black posts, which is exactly what
  the vista shows.
- Ash soil (`0.72, 0.70, 0.64`) renders as mid grey, and because sky, fog and ash
  are all neutral, there is no colour separation anywhere in frame.

There is a `DirectionalLight3D` in `scenes/world/main.tscn:34`, but the world
material is unshaded, so it contributes nothing to terrain (it does light enemies,
which makes their shading inconsistent with the ground).

`FACE_SHADE` is a fixed axis table, not a sun direction, so every face has the same
tone regardless of time of day. Tone variation is `0.9–1.08`, too small to break up
a 1 m face.

Direction:

- Add a sun term in the shader: transform `NORMAL` to world space, take
  `dot(normal, sun_dir)`, wrap it (`(dot + 0.4) / 1.4`) and use it to modulate the
  day component. Pass `sun_dir`, `sun_color` and day level as uniforms from
  `DayNightCycle` so dusk actually rakes across the dunes.
- Give the flashlight a warm tint (`1.0, 0.86, 0.62`) and the ambient sky a cool
  tint (`0.62, 0.70, 0.86`). Colour temperature is the cheapest way to stop the
  scene reading as grey.
- Raise tone variation to `0.85–1.15` and jitter hue slightly per block.
- Rebalance the palette for separation rather than uniform darkness: warm ash,
  cool blue-grey stone, indigo-black wood, and keep teal/green only for emissives.

## 3. The viewmodel is the loudest object in the frame

At `position = (0.24, -0.2, -0.46)` with a 0.42 m-long body and the default 75° FOV,
the gun covers roughly a third of the screen and its muzzle sits near the centre
line. Worse, `CartridgeStripe` is `0.134` wide against a `0.13`-wide body, so it is
wider than the receiver and reads as a bright cyan plate; at emission energy 1.8 and
unshaded, it has no shading at all. The result is the flat cyan trapezoid visible in
all three captures.

There is no hand, no bevel, no barrel detail beyond three boxes, and the muzzle ring
is another emissive plate.

Direction:

- Narrow the stripe to ~`0.03` and inset it (`x = 0`), lower emission to ~0.8, and
  let the dark receiver carry the silhouette.
- Move and scale the model: `position ≈ (0.22, -0.19, -0.58)`, `scale ≈ 0.85`,
  slight yaw so the barrel converges toward the crosshair instead of running
  parallel to the screen edge.
- Add one non-emissive mid-tone (barrel shroud, grip wrap, magazine) and a simple
  blocky hand so the weapon has a material hierarchy.
- Reserve full emission for the muzzle flash and the reserve cells.

## 4. Individual objects that break the style

- **Torches are full 1 m cubes.** `torch` has albedo `(1.0, 0.46, 0.16)` and its own
  cell light is 15, so it renders as a solid orange crate (see `audit_spawn.png`,
  the orange box, and the two in `audit_ground.png`). It reads as a placeholder
  prop and is the brightest thing in the world. Same issue at smaller scale for
  `pale_bloom`/`mycelium`, which read as coloured floor tiles.
  Direction: special-case these blocks in `chunk_mesher.gd` to emit a small
  non-cube fixture (cross quads or a 0.5-scale lantern box with a dark frame), and
  keep the full voxel only for collision/light logic.
- **Branches read as ladders.** Trunks are one voxel wide with stair-step branches
  and no canopy; against a grey sky they read as scaffolding. Thicker trunks
  (2×2 from the base up), tapered tips and more clustered branch ends will do more
  for the silhouette than adding more trees.
- **The Beacon pillar is a flat translucent rectangle.** Fine as a placeholder, but
  a soft vertical gradient with a wider base and a fading top would sell it.
- **Fog and sky do not meet.** `fog_sky_affect = 0.0` and a flat grey horizon leave
  a hard line where the ground plane ends. Let fog tint the lower sky, or lift
  `sky_curve` and warm the horizon colour.
- **No bloom.** Emissive crystals, flashes and torches do not glow; they are just
  bright flat colour. Verify glow support in Compatibility before designing around
  it; if unavailable, fake it with a small additive sprite at emitters.

## 5. HUD and presentation

- The debug readout is on by default, full of internals, in the default label font.
  It is the first text a player sees. Default it off and keep it on F.
- `LumenReadout` duplicates the cartridge name and sits directly under the debug
  text at y=108, so the top-left is a wall of small teal text.
- The pause hint, status line, cartridge state and depth value are all in one
  string. Split them: cartridge row bottom-right, status above the crosshair,
  hint centered and short-lived (the new `ContextHint` already does this).
- The crosshair is a default-font `+`. A four-pixel dot or bracket would match the
  blocky style better.

## What is working and should be kept

- The chunky 1 m voxel identity and the AO corner darkening: walls and props already
  have real form, the problem is tone, not geometry.
- The teal/amber accent split on cartridges; it is the only strong colour story in
  the build and is worth extending to the world's emissives.
- Distance fog as a depth cue, and the pale ash direction for the biome. The
  palette needs saturation and temperature, not a new palette concept.
- The layered terrain (dunes, slopes, cliffs) reads well in the vista once the dot
  grid and the grey wash are removed.

## Suggested order of work

1. Shader dither gating + sun term + warm/cool light split (largest visual return,
   one file plus two uniforms).
2. Viewmodel stripe/scale/detail fix.
3. Torch and flora mesh special cases in the mesher.
4. Palette and fog/sky pass.
5. HUD cleanup and debug-off default.
6. Tree silhouette pass (thicker trunks, clustered tips).
