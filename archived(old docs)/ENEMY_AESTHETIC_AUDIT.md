# Enemy aesthetic audit

Scope: both enemy types — Gloomling and Lamp Eater — judged as horror designs,
in-engine at 854×480 with the current lighting, HUD and world art.

Evidence: `debug/evidence/enemy_gloomling.png`, `enemy_gloomling_close.png`,
`enemy_lamp_eater.png`, `enemy_lamp_eater_close.png`, `enemy_group_night.png`
(captured at night with `debug/capture_enemies.gd`, enemies frozen for the shot).

## What exists today

- **Gloomling** (`scripts/enemies/gloomling.gd`): one ellipsoid body
  (`SphereMesh` r 0.34, h 0.72) with near-black unshaded albedo and a weak violet
  emission (0.12, 0.02, 0.18 at 0.8), plus two emissive red eye spheres. A 0.07 m
  sine bob is the only animation. On death it emits an 18-particle dark burst and
  is freed.
- **Lamp Eater** (`scripts/enemies/lamp_eater.gd`): **no visual code at all** — it
  inherits `GloomEnemy._create_placeholder_mesh`, which is a bright purple
  unshaded sphere (0.34, 0.08, 0.42). It has no eyes, no limbs, no lantern motif,
  despite its entire behaviour being "hunts and eats light".
- Both are unshaded, cast no shadows, have no hit reaction, no attack telegraph,
  no footsteps, and no dissolve animation beyond a particle burst at the end.

## Confirmed bugs and hard failures

1. **The Gloomling's eyes are inside its head.** The body sphere has radius 0.34;
   the eyes sit at `z = -0.30` with radius 0.042 and `y = 0.07`. At that height the
   body surface is at `z ≈ -0.333`, so each eye protrudes about 1.2 cm — effectively
   hidden. The close-up confirms a featureless black egg with no eyes at all. The
   single strongest horror cue in the design is currently invisible.
2. **The Lamp Eater is a placeholder.** A smooth, saturated purple ball, brighter
   than anything else at night (unshaded), reads as a bouncy toy. It is the most
   obviously unfinished asset in the build and undermines every enemy next to it.
3. **They do not react to the flashlight.** Both use `SHADING_MODE_UNSHADED`, so
   the light cone lights the ground around them while they stay flat black or flat
   purple. They read as stickers composited over the world, not creatures in it.
4. **No silhouette.** A ball has no threat shape: no limbs, no hunch, no asymmetry,
   no spine, no mouth. Silhouette is the primary horror carrier at this palette and
   resolution; currently there is nothing to read.
5. **No grounding.** `cast_shadow` is off, there is no contact shadow, and the mesh
   is centred on the enemy origin. At night they look pasted onto the sand rather
   than standing on it.

## Why they don't feel scary

- **Nothing to track.** Horror reads through eyes and intent. The eyes are hidden,
  there is no head turn, no twitch, no lean, no reach. The creature only translates.
- **Wrong scale and shape.** At 0.72 m tall they are knee-high blobs; the brain reads
  "prop", not "predator". A thin, tall, top-heavy figure at 1.6–2.0 m is far more
  unnerving in the same silhouette budget.
- **No anticipation.** Touch damage happens on contact with no wind-up, no lunge, no
  sound, no screen feedback. There is no moment of "it's about to get me", which is
  where fear actually lives.
- **No consequence on death.** They pop out of existence; the dissolve burst is small
  and dark-on-dark, so there is no payoff or relief.
- **Colour story is unresolved.** The world now has warm torch light, cool crystal
  light and ochre ash. The Gloomling's violet-black is a good fit; the Lamp Eater's
  saturated purple is not, and neither creature uses the world's warm/cool language
  to say what it does.

## Redesign direction (highest impact first)

### 1. Fix the face and build a silhouette (Gloomling)

- Move the eyes onto the surface (`z ≈ -0.335`), enlarge them to ~0.055, and recess
  them in shallow dark sockets so they read as holes with light behind them.
- Make the head a separate, slightly smaller mass on a short neck, so it can tilt
  and turn independently of the body.
- Add 4–6 thin, angular limbs (BoxMesh 0.05–0.08 thick, 0.5–0.7 long) with a
  hunched, asymmetric pose: two long front arms, short back legs, one shoulder
  higher. Low-poly matches the voxel world better than more spheres.
- End the arms in tapered points, not hands. No fingers at this resolution.
- Target height 1.2–1.4 m for Gloomlings — tall enough to loom at eye level when
  close, small enough to swarm.

### 2. Give the Lamp Eater its own body

- Tall and thin (1.8–2.0 m), hunched, with elongated arms that reach toward lights.
- Ribcage of thin dark boxes around a **warm amber lantern-organ** in the chest —
  the one warm light source that is hostile in a world where warmth means safety.
  It should visibly dim for a second after it extinguishes a torch.
- A vertical slit or cage of teeth where a head would be, with a single ember eye
  above it. No round friendly head.
- Give it a slow, deliberate walk with a lurch; speed 1.8 already supports that.

### 3. Make them exist in the lighting

- Keep them unshaded, but drive body brightness from the world light at their
  position: `world.get_flashlight_level_at()` and `world.get_light_level()` already
  exist and are used by the AI. Lerp the body albedo from near-black to a readable
  dark violet in the cone, and add a rim shell (slightly scaled duplicate with
  `cull_front`, additive violet) so edges catch light.
- Add a cheap contact shadow: a flat dark quad under each enemy, scaled by distance
  to the ground. This single change fixes most of the "pasted on" feeling.
- When lit by the flashlight, flare the eyes and add a brief recoil/hiss so light
  is a weapon with feedback.

### 4. Animate intent, not just position

- Idle: asymmetric breathing (body scale 0.98–1.02), slow eye blink by scaling the
  eye spheres on Y, occasional twitch of one limb.
- Movement: lean into the direction of travel, bob with a landing squash, and trail
  the limbs a few frames behind the body.
- Attack: a 0.35 s wind-up (hunch, arms pull back, eyes flare from 6 to 14 emission)
  before the damage tick, then a lunge. This is the single cheapest way to make them
  frightening.
- Damage: white/violet flash for 0.08 s and a small knockback; currently there is
  none.

### 5. Death as a beat

- Over the existing 0.65 s dissolve timer: shrink and jitter the silhouette, drop
  the eyes' emission to zero, then burst dark motes plus a short-lived violet point
  glow. Add a low, wet sound when audio lands.
- Keep the burst, but emit it from the body centre at chest height and make it
  larger than the current 18 particles.

### 6. Spawn presentation

- Spawn them at the edge of the flashlight, not on top of the player: a two-stage
  materialise where the eyes appear first in the dark, then the body resolves over
  ~0.5 s. The player should see eyes before they see the creature.

## What is already working

- The near-black Gloomling body with red eyes is the correct palette direction; it
  just needs the eyes visible and a shape around them.
- The bob, the dark dissolve burst and the Gloom-driven dissolve rule are good
  systems to build on.
- The Lamp Eater's behaviour (targets only whitelisted light blocks, 24 m radius,
  extinguishes for 12 s) is a strong horror premise. The design should sell that
  premise visually: a thing that eats the light.
- Violet vs amber is a ready-made creature colour language that fits the world's
  warm/cool lighting.

## Suggested order of work

1. Fix eye placement and add a contact shadow (hours, not days; immediate gain).
2. Rebuild the Gloomling silhouette with limbs and a tilting head.
3. Replace the Lamp Eater placeholder with the lantern-ribcage design.
4. Flashlight-reactive body brightness and rim shell.
5. Wind-up/lunge telegraph, hit flash, dissolve animation.
6. Spawn materialise and audio.

## Verification notes

- Captures used `debug/capture_enemies.gd`, which spawns via the existing F6/F7
  debug paths, freezes the enemy, and shoots at night (700 s into the cycle).
- No hand playtest of how they feel to fight; this audit is appearance and
  animation-readability only.
