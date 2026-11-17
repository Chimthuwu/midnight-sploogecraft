# AGENT HANDOFF — MIDNIGHT SPLOOGECRAFT

> Read this before inspecting or modifying the project. This is a creative and technical reboot handoff, not a request to blindly rewrite the game.

## Project and workspace boundaries

The only project you are authorised to modify is:

`Z:\GITHUB\_GAMES\Midnight Sploogecraft`

The external asset library is:

`Z:\GITHUB\_ASSETS`

You may inspect that asset library and copy suitable assets into this project. Treat the original asset library as **read-only**: never rename, move, delete, overwrite, or modify anything inside it. Perform conversions on copies inside this project and preserve source/licence information where available.

If your tool's workspace is opened at `Z:\GITHUB` or another parent directory, that does **not** grant permission to edit sibling projects, shared folders, or anything outside the Midnight Sploogecraft project directory. Do not inspect unrelated repositories or projects.

## Why this note exists

The project is entering a new creative and technical direction. Earlier development established a playable foundation and a first neon-city pass, but the current visual result is not being treated as the final art direction or an accepted quality bar.

The next development effort should rethink and improve the game with ambition. Do not assume that the existing implementation, screenshots, old milestones, or previous visual conventions define what the finished game must look like.

The user's current task prompt and direct instructions are the primary creative brief. This file provides workspace boundaries and durable context only.

## Intended game direction

The current goal is a distinctive, dark neon urban sandbox with the recognisable city energy of places such as Shinjuku, Shibuya/Kabukicho, and Times Square.

The city should feel dense, lived-in, explorable, and visually distinctive: striking architecture, varied neighbourhoods, nightlife, signs and huge displays, street-level businesses, traffic, vehicles, wet or reflective surfaces where appropriate, alleys, rooftops, industrial areas, and genuinely dark/abandoned pockets.

**Do not feel locked to Minecraft-style graphics or an entirely voxel world.** A hybrid approach is encouraged: use conventional meshes, modular architecture, authored or generated assets, and voxel/block geometry wherever each makes the most sense. Buildings do not all need to be made of cubes; cars and ordinary props should use appropriate meshes. Keep block-based interaction where it serves mining, building, editing, or destruction gameplay.

Choose and implement a cohesive art direction rather than merely adding more random detail or neon. Visual quality and strong composition matter more than raw object counts.

## Current gameplay scope

For this development phase, prioritise:

1. **The city and urban sandbox:** exploration, distinct neighbourhoods, architecture, streets, environmental detail, and a convincing sense of place.
2. **Light and darkness:** preserve and improve the existing illumination, flashlight, Gloom, and enemy interactions.
3. **The Lumencaster:** preserve and improve its existing mining, block removal, construction/placement, cartridge/resource, and relevant light-related functionality.
4. **Vehicles and movement:** preserve and improve the existing on-foot and vehicle experience without breaking handling, traffic, or camera behaviour.
5. **Existing enemies and survival gameplay:** maintain the relationship between darkness, illumination, threats, and exploration.

**Do not add a Gravity Gun / Gravity Manipulator or a Portal Gun / Portal Device in this phase.** Do not prototype them, add supporting architecture for them, or divert time into their design. They are out of current scope unless the user explicitly brings them back in a future instruction.

Do not let speculative future features distract from making the existing city, lighting, tools, vehicles, and survival loop excellent.

## Core gameplay identity to protect: light and darkness

Light and darkness must remain meaningful gameplay systems, not just a post-processing effect.

Audit the actual Midnight Sploogecraft implementation before changing it. In particular, understand the existing static light propagation, dynamic flashlight behaviour, Gloom/darkness mechanics, light sources, enemy interactions with light, and any performance constraints.

Preserve useful existing behaviour and performance unless a replacement is demonstrated to be better and is verified. Do not break flashlight updates by causing unnecessary chunk rebuilds/remeshing. Darkness should have gameplay consequences; light should affect visibility, safety, exploration, and enemy behaviour.

The exact implementation must be confirmed from this repository's source code. Do not infer that a feature works merely because it appears in a name or design idea.

## The Lumencaster

The existing Lumencaster/tool should be audited and improved rather than casually discarded. Preserve its useful block excavation, mining, placement/construction, cartridge/resource, and relevant light-related capabilities while exploring a much better model, feel, animations, firing/mining/building feedback, sound, and interaction design.

Do not replace functioning tool mechanics with a purely cosmetic redesign. Improve the presentation while verifying that the actual gameplay modes still work.

## Asset library workflow

Inventory `Z:\GITHUB\_ASSETS` before spending time recreating assets that may already exist. Look for useful models, materials, textures, environment pieces, vehicles, characters, props, and audio. Inspect previews/metadata and licensing where available.

Only bring assets into Midnight Sploogecraft when they improve the actual result. Keep imported assets organised within this project's asset directories. Do not bulk-copy the whole library.

## Source of truth and archive boundaries

- The current Midnight Sploogecraft source code is the authority for what is implemented.
- The user's current prompt is the authority for the creative direction and current priorities.
- This `AGENTS.md` file is the authority for workspace boundaries and durable handoff context.
- The repository contains an `archived(old docs)/` directory. **Treat it as historical archive only. Do not read it, search it, copy from it, restore it, or use it as current instructions.** It is deliberately retained for history, not as active agent context.
- Skip generated/editor/test-user-data folders such as `.m2_test_userdata/` when looking for gameplay architecture or project instructions.
- Do not inspect external repositories, sibling folders, or other games to reconstruct project history. Work from the current project only.

Do not invent historical facts or assume old project documents are still authoritative. Establish fresh current documentation from verified source inspection and the user's current brief.

## Working style and safety

1. Start by confirming the project root and reading this file.
2. Inspect the current project structure and relevant code before editing. Make an evidence-based audit; do not guess at engine architecture, node types, input mappings, or system behaviour.
3. Establish a strong visual direction and implement a meaningful, playable vertical slice. Do not stop after producing only a design document.
4. Work in bounded, reversible steps. Keep working systems intact unless a change is justified.
5. Use the project's pinned Godot/GDScript/rendering setup and existing validation workflow unless technical evidence justifies a change.
6. Test actual runtime behaviour where possible. Use windowed captures for visual claims; headless checks alone do not establish visual quality.
7. Distinguish clearly between implemented, tested, visually inspected, partially implemented, and merely proposed features.
8. Never claim success for a system or visual improvement that was not actually verified.
9. Keep the project's new documentation current. Preserve historical development records if they are retained, but do not revive archived requirements.
10. Do not commit, push, delete, overwrite, or perform other irreversible Git/repository operations unless the user explicitly authorises them.

## First-session expectations

Begin with a focused audit of Midnight Sploogecraft and the authorised asset library. Identify:
- What currently works and what is broken or unverified.
- The actual light/darkness architecture and its performance constraints.
- The city generation, rendering, material, and asset pipelines.
- Existing player, Lumencaster, vehicle, traffic, and enemy implementations.
- The most promising assets in `Z:\GITHUB\_ASSETS`.

Then choose a realistic first vertical slice that materially advances the new neon-city vision while preserving the light/darkness identity. Record evidence, tests, limitations, and the next recommended milestone.

**Be creative about the game. Be conservative about workspace boundaries. Verify before claiming.**
