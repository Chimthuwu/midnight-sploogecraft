# PROJECT: MIDNIGHT SPLOOGECRAFT — BIBLE v2

_This supersedes the old Lumenfall bible. Ashen Flats, the Cradle, seeding,
Gloomlings-as-core-loop and the old milestone ladder are no longer the spec._

## VISION
An open-world **GTA meets Minecraft** neon city. The player explores a dark,
dense, cyberpunk city by foot and by vehicle: street traffic, pedestrians,
cops, hostile gangs, glowing signage, rain-slick roads and unlit ghettos where
the flashlight is the only thing between you and the dark. The Lumencaster
stays — it mines and builds blocks — but it is a tool in a bigger city, not
the whole game.
- The **visual aesthetic is the priority**. If something looks cheap, fix it.
- Very dark, neon-lit, retro/PSX-flavoured. Times Square / Tokyo energy in the
  rich districts; near-black, hostile streets in the poor ones.
- Weapons and deeper combat come after the city and driving feel right.

## WHAT IS A BLOCK AND WHAT IS NOT
- **Buildings, skyline, roads, sidewalks, lamps, neon signs = blocks.**
- **Cars, bikes, trees and other set dressing = real meshes/actors.** Do not
  force them into the voxel grid just to be "consistent".
- **Create new blocks freely.** The 12-block palette was a starting point, not
  a limit. If the city needs glass, brick, crosswalks, traffic lights,
  billboards or a new facade, add a `data/blocks/*.tres` and use it.
- Blocks are data (`BlockLightDef` resources); no hardcoded block tables.

## STACK (still pinned)
- Godot **4.7.2 stable**, GDScript only. No C#, no GDExtension, no addons.
- **Compatibility renderer**. AgX tonemap, glow enabled, 854×480 internal
  viewport with integer scaling. Do not switch renderers without evidence.
- Engine APIs newer than 4.7.2 do not exist for this project.
- Use the `gda` CLI for scan / script validate / scene validate / headless runs.

## WORLD
- 128×128×64 voxels, 16³ chunks, `PackedByteArray` block store.
- **20-block district grid**: 7-block roads (three lanes each direction),
  1-block sidewalks, 11-block building lots, intersections at x/z == 9 mod 20.
- City generation is deterministic from the world seed. Buildings are generated
  per lot so they cross chunk borders intact.
- The city **starts at night**; the day/night cycle continues from there.

## TRAFFIC AND DRIVING
- Traffic is a **graph of intersections**. Cars pick a next junction, steer to
  the correct right-hand lane and turn at junctions. No axis-locked bouncing.
- Cars and bikes use imported/ported low-poly meshes at real-world scale
  (~4.9 m car, ~2.2 m bike), with headlights, taillights and neon accents.
- `E` enters/exits the nearest vehicle; WASD drives; Space handbrake. The
  camera follows in third person. Parked vehicles spawn near the player.
- Driving must feel deliberate: throttle/brake/reverse, speed-sensitive
  steering, smoothed follow camera, no bumper-car collisions.

## LOOK
- Restrained facades in readable slate/concrete tones; windows are small
  recessed panels with a mix of lit and dark. Neon is **accent signage**, not
  whole-floor colour fields.
- Glow-only blocks light visually without multiplying propagation sources.
- Use third-party 3D assets from `_ASSETS` when they improve the look; keep a
  licence/source note in the asset folder.
- HUD is minimal and diegetic-ish; the city should carry the frame.

## WORKING RULES
- Keep momentum: state briefly what you are changing, then do it. Do not block
  on a formal approval for every new block or small system.
- One milestone per session is a guideline, not a straitjacket — finish the
  thing the user is actually waiting on.
- End each session: rewrite `STATE.md`, append `DEVLOG.md`, commit working
  states with conventional commit messages.
- Verify with `gda script validate --all`, `gda scene validate`, headless city
  checks and **windowed captures** — headless cannot capture viewport textures.
- Save city screenshots in `debug/evidence/` and copy the sky/overview ones to
  `C:\Users\Serge\Desktop\Midnight Sploogecraft City Shots`.
- If a system is broken, say so plainly and fix it; do not paper over it with
  a check that only proves data exists.

## NON-GOALS
- No hunger, no multiplayer, no old Lumenfall biome/boss/seed milestones.
- No placeholder-only art: the city must actually read as a city.
