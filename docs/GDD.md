# xtrapartial — Game Design Document

| | |
|---|---|
| **Version** | 0.1 (first draft) |
| **Date** | 2026-09-27 |
| **Status** | Pre-production: structure and direction, all numbers are starting values to tune |
| **Genre** | Round-based, movement-first arena FPS with a card draft between rounds |
| **Platform** | PC (Windows / Linux, Steam Deck compatible), mouse & keyboard first |
| **Players** | 1v1 core; 2v2 and 3–4 player FFA later |

---

## Table of contents

1. [Vision](#1-vision)
2. [Design pillars](#2-design-pillars)
3. [Core loops](#3-core-loops)
4. [Movement](#4-movement)
5. [Combat](#5-combat)
6. [Match structure](#6-match-structure)
7. [Cards (Partials)](#7-cards-partials)
8. [Arenas](#8-arenas)
9. [Game feel and flow](#9-game-feel-and-flow)
10. [Art direction](#10-art-direction)
11. [Audio](#11-audio)
12. [UI / UX](#12-ui--ux)
13. [Modes](#13-modes)
14. [Technical design](#14-technical-design)
15. [Scope and milestones](#15-scope-and-milestones)
16. [Open questions](#16-open-questions)

---

## 1. Vision

**Elevator pitch:** *ROUNDS as a first-person shooter set in an early-2000s fever dream.* Two players duel in small, surreal arenas across short, fast rounds. Whoever loses a round drafts a card that changes how they shoot, move, or survive. By the late rounds, both players are running strange builds that neither could have planned, and they are still bound by one movement system that rewards flow over everything.

**The fantasy:** you are a blank, glossy figure pouring through a dreamlike space at 15 m/s, sliding under a floating water cooler, kicking off a wall of bathroom tile, and landing a bouncing shot around a corner that you set up three rounds ago.

**What xtrapartial is:**
- Short rounds (20–45 s) and fast matches (8–15 min).
- A movement system with a high skill ceiling that still feels good in the first minute.
- A build-crafting layer where the player who is behind is the one who gets stronger.
- A distinctive look: surreal, low-poly, early-2000s realtime 3D.

**What xtrapartial is not:**
- Not a loadout or class shooter. Everyone starts every match identical.
- Not a tactical shooter. No aim-down-sights, no movement inaccuracy, no economy.
- Not a hero shooter. Abilities come from the draft, not from a character pick.

### Comparable titles

| Title | What we take |
|---|---|
| ROUNDS | Loser-picks card draft, stacking modifiers, block as a core verb, short rounds |
| Titanfall 2 | Wall ride, slide-hop, momentum preservation |
| ULTRAKILL | Dash charges, chaining movement into combat, "no dead frames" feel |
| Quake / Source bhop | Air strafing, friction model, skill ceiling from input mastery |
| Endocopia-style surreal games | Dreamlike, uncanny, early-2000s 3D aesthetic |

---

## 2. Design pillars

Every feature is weighed against these. If something violates a pillar, it needs a strong reason to exist.

### P1. Momentum is sacred
Movement is the main skill. Every verb either preserves speed or adds to it. Nothing silently eats momentum. Shooting, reloading, and blocking never slow you down.

### P2. Smooth over everything
Input-to-screen latency, frame pacing, netcode, animation, and camera all serve one goal: the game should feel frictionless under your hands. When a feature costs frame time or adds input delay, the feature loses.

### P3. Every round tells a story
The draft makes each match unique. Builds diverge and synergies emerge. Because the loser picks, matches stay close and comebacks happen.

### P4. Dreamlike, but readable
The world is strange, but the opponent, their projectiles, and their build must always be instantly legible. The surreal never gets in the way of combat clarity.

---

## 3. Core loops

```
 MOMENT (seconds)            ROUND (20–45 s)               MATCH (8–15 min)
 ┌──────────────────┐       ┌──────────────────────┐      ┌─────────────────────┐
 │ move → position  │       │ spawn → hunt → duel  │      │ round → draft →     │
 │ → shoot / block  │ ───▶  │ → one player falls   │ ───▶ │ round → draft → ... │
 │ → reposition     │       │ → loser drafts card  │      │ → first to 5 wins   │
 └──────────────────┘       └──────────────────────┘      └─────────────────────┘
```

- **Moment-to-moment:** chain movement verbs to control distance and angles, land shots on a moving target, block their shots, stay out of their lines.
- **Round:** one life each. Last player standing wins the round.
- **Match:** the loser of each round drafts one card. First player to win 5 rounds wins the match.
- **Meta (post-MVP):** cosmetics, card unlocks or collection, ranked play, movement time trials.

---

## 4. Movement

Movement is the heart of the game and gets the most tuning time. The first playable milestone is movement alone (see [§15](#15-scope-and-milestones)).

### 4.1 Player body

| Property | Value |
|---|---|
| Units | 1 unit = 1 m |
| Standing capsule | 1.8 m tall, 0.35 m radius, eye height 1.6 m |
| Crouch / slide capsule | 0.9 m tall, eye height 0.75 m |
| Step height | 0.4 m (stairs and small lips never interrupt a run) |
| Max walkable slope | 50° |

### 4.2 Base verbs

Every player has these from the start of every match. Cards can add more (double jump, grapple, slam).

| Verb | Input | Summary |
|---|---|---|
| **Run** | WASD | Source-style acceleration and friction. Snappy but with weight. |
| **Jump** | Space | Fixed height, with coyote time and input buffer. |
| **Air strafe** | A/D + mouse | Quake-style air control. Steering plus modest speed gain. |
| **Slide** | Ctrl (or C) | Low-friction slide with an entry boost. Gains speed on slopes. |
| **Slide-hop** | Jump during slide | Keeps all horizontal speed. The core chaining move. |
| **Dash** | Shift | Short burst in the input direction. 2 charges. |
| **Wall ride** | Automatic (airborne, moving along a wall) | Brief run along a wall with reduced gravity. |
| **Wall jump** | Space on or near a wall | Kick off the wall. 3 per airtime. |
| **Mantle** | Automatic (forward into a ledge) | Fast vault onto ledges, keeps most speed. |

### 4.3 Starting parameters

Tune these in the M1 movement prototype with a live tweak panel. They are a starting point, not a spec.

**Ground**

| Parameter | Value | Notes |
|---|---|---|
| Max run speed | 8.5 m/s | |
| Ground acceleration | 10 × wishspeed / s | Reaches max speed in about 0.1 s |
| Ground friction | 6 | Source-style friction |
| Stop speed | 2.5 m/s | Friction floor for crisp stops |
| Crouch-walk speed | 4.0 m/s | |
| Landing grace | 50 ms | No friction right after landing, so well-timed hops keep speed |

**Air**

| Parameter | Value | Notes |
|---|---|---|
| Gravity | 20 m/s² | Snappier than real gravity |
| Jump velocity | 7.0 m/s | Apex around 1.2 m, about 0.7 s of airtime |
| Coyote time | 100 ms | Can still jump after leaving a ledge |
| Jump buffer | 120 ms | Jump pressed just before landing fires on landing |
| Air acceleration | 12 × wishspeed / s | |
| Air wishspeed cap | 1.0 m/s | Enables strafe gain, as in Quake |
| Speed soft cap | 16 m/s horizontal | Above this, extra drag of 2 m/s² per 1 m/s over the cap |
| Terminal velocity | 40 m/s | |
| Fall damage | None | Falling never punishes |

**Slide**

| Parameter | Value | Notes |
|---|---|---|
| Entry condition | Grounded and speed ≥ 6 m/s, or landing while holding crouch | Below the threshold, crouch is a crouch-walk |
| Entry boost | +3 m/s | 1.5 s cooldown so spamming slides can't build speed |
| Slide friction | 0.8 | Very low. Slides carry. |
| Slope behavior | Gravity projected on the slope | Downhill slides gain speed |
| Exit | Speed < 4 m/s → crouch-walk. Release → stand, if there is headroom. | |
| Slide-hop | Jump keeps 100% of horizontal speed | |

**Dash**

| Parameter | Value | Notes |
|---|---|---|
| Charges | 2 | |
| Recharge | 1.75 s per charge, one at a time | |
| Burst | 18 m/s for 0.15 s in the input direction (look direction if no input) | Horizontal only |
| Exit speed | max(pre-dash horizontal speed, 10 m/s) along the dash direction | A dash never slows you down |
| Airborne | Zeroes downward velocity at start | Recovers bad jumps |
| Dash-jump | Jumping during a dash cancels it and keeps its exit speed | |

**Wall ride, wall jump, mantle**

| Parameter | Value | Notes |
|---|---|---|
| Wall ride attach | Airborne, touching a wall, speed along the wall ≥ 5 m/s | |
| Wall ride duration | 1.2 s | Gravity starts at 25% and ramps back to 100% |
| Wall ride reuse | Once per wall surface until you land or touch a different wall | Prevents climbing a single wall forever |
| Wall jump | Normal × 6 m/s + up 6.5 m/s, keeps speed along the wall | 3 per airtime, refilled on landing |
| Wall jump window | 150 ms after leaving the wall | "Coyote" for walls |
| Mantle trigger | Ledge top 0.5–2.0 m above feet, within 0.6 m, moving forward | |
| Mantle | 0.2 s, exits with 80% of prior horizontal speed | |

### 4.4 Movement rules

1. **Deterministic and pure.** Movement is a pure function of `(state, input, dt)`. That is needed for client prediction ([§14](#14-technical-design)).
2. **Fixed timestep.** Movement simulates at the fixed network tick. The camera and rendering interpolate between ticks.
3. **Momentum is never silently removed.** Only friction, drag above the soft cap, collisions, and explicit card effects (such as Vsync) reduce speed.
4. **Collision slides, not stops.** Glancing a wall or corner deflects velocity along the surface. Small ledges are stepped over or mantled.
5. **Every chain is legal.** Any verb can follow any other verb. There is no "recovery" state.
6. **Skill ceiling, skill floor.** Buffers and coyote windows make basic chaining easy. Air strafing and slope slides give experts more.

---

## 5. Combat

### 5.1 Health and damage

| Property | Value |
|---|---|
| Max health | 100 |
| Regeneration | None by default (cards can add it) |
| Headshot multiplier | ×1.5 |
| Pickups | None. The draft is the only source of power. |

### 5.2 Base weapon: "The Pointer"

Everyone starts every match with the same projectile pistol. Cards modify it.

| Stat | Value | Notes |
|---|---|---|
| Damage | 25 (37.5 on headshot) | 4 body or 3 head to kill |
| Fire interval | 0.22 s | Hold to fire automatically at the same rate |
| Magazine | 6 | |
| Reload | 1.2 s | Automatic when empty, manual with R |
| Reload cancel | Firing cancels a reload if at least 1 round is loaded | |
| Projectile speed | 150 m/s | Visible, fast, needs slight lead at range |
| Projectile drop | None | |
| Projectile radius | 0.1 m | Small forgiveness on hit tests |
| Max range | 150 m, then despawns | |
| Spread | 0 | No movement inaccuracy |
| Recoil | Visual kick only | The camera stays where you aim |

**TTK:** about 0.66 s (4 body shots) or 0.44 s (3 headshots). That is fast enough to be lethal and slow enough that movement and block can decide a duel.

### 5.3 Block

The core defensive verb, taken from ROUNDS. Many cards trigger on block.

| Property | Value |
|---|---|
| Input | Right mouse (there is no ADS) |
| Active window | 0.3 s |
| Effect | Negates all incoming damage and destroys incoming projectiles |
| Cooldown | 4.0 s from activation |
| Movement | No effect on movement. You can block mid-slide, mid-dash, mid-wall-ride. |
| Tell | Bright shell effect and sound, clearly visible to the opponent |

### 5.4 Ability slot

- One ability slot (E). It is empty at match start.
- ABILITY cards fill it (grapple, slam, and so on). Drafting a second ability replaces the first; the draft UI warns you.

### 5.5 Combat rules

- **No dead states.** Firing, reloading, and blocking never lock or slow movement.
- **No ADS.** Right mouse is block. Zoom may exist as a card.
- **Projectiles, not hitscan.** Projectiles let the card system visibly transform your gun (bouncing, homing, splitting, exploding).
- **Self-damage** exists only from explosive cards, at 50%, and comes with knockback (explosive jumps are allowed).

### 5.6 Default controls (keyboard and mouse)

| Action | Key |
|---|---|
| Move | WASD |
| Look | Mouse (raw input) |
| Fire | Left mouse |
| Block | Right mouse |
| Jump | Space (also mouse wheel down, for hop timing) |
| Slide / crouch | Left Ctrl or C |
| Dash | Left Shift |
| Reload | R |
| Ability | E |
| Scoreboard / builds | Tab |

Everything is rebindable. Crouch supports hold or toggle.

---

## 6. Match structure

### 6.1 Flow

```
Lobby → Warmup → [ Round → Round end → Draft ] × N → Match end → Rematch / Lobby
```

### 6.2 Warmup
- Free movement, weapons active, instant respawn, no cards.
- Ends when both players ready up, or after 60 s.

### 6.3 Round

| Phase | Duration | Rules |
|---|---|---|
| Countdown | 3 s | Camera and movement active. Weapons off. Spawns are walled off by a translucent barrier that dissolves at 0. |
| Live | Up to 75 s | One life each. Last player standing wins. |
| Unloading (sudden death) | Starts at 45 s | The arena "unloads" from the edges inward: geometry dissolves into wireframe, then into void. Standing in the unloaded zone deals 10 HP/s, rising to 25 HP/s. By 75 s only a small central platform remains. |
| Round end | 2 s | Slow-motion freeze frame on the killing blow (presentation only), then the scoreboard. |

**Draw:** if both players die on the same tick, nobody scores and both draft.

**Target average round length:** 20–45 s.

### 6.4 Draft (after every round)

- Each player who **lost** the round is dealt **5 cards** and picks **1**.
- Draft timer: 15 s. On timeout, a random card from the hand is picked.
- The winner watches the loser's hand and pick live. It builds drama, and you always know what you are facing.
- Before the next round, a matchup screen briefly shows both players' full builds with the new card highlighted.

### 6.5 Winning
- First to **5 round wins** by default (configurable 3–9 in custom games).
- A match is at most 9 decisive rounds (draws add rounds).

### 6.6 Why loser-picks
The losing player gets stronger every round they lose, so the match pulls itself back toward 50/50. A 4–0 lead is never safe against a player with four cards. Winning the match means beating an opponent whose build is designed around beating *you*.

---

## 7. Cards (Partials)

> **Naming proposal:** in-world, cards are called **Partials**, fragments that attach to your blank figure. Each Partial you draft adds a visible accretion to your character (a floating shape, a halo, an extra limb), so your build can be read at a glance. The game's name comes from this: you become *extra partial*.

### 7.1 Card rules

- Cards are permanent for the rest of the match.
- A hand of 5 never contains duplicates. You can draft the same card again in a later round, and it stacks, unless the card is marked **Unique**.
- **Rarity weights:** Common 60%, Uncommon 30%, Rare 10%.
- **Design rule:** commons are small upgrades, usually with no drawback. Uncommons are strong or situational. Rares are build-defining and always carry a real drawback.
- **Tags:** `GUN`, `BODY`, `MOVE`, `BLOCK`, `FLOW`, `ABILITY` (later: `CURSE`, which affects the opponent).

### 7.2 Stat stacking

```
final = (base + Σ additive) × Π (multipliers)
```

Hard limits apply after stacking:

| Stat | Limit |
|---|---|
| Fire interval | ≥ 0.05 s |
| Reload | ≥ 0.2 s |
| Projectile speed | 20–600 m/s |
| Max health | ≥ 25 |
| Move speed | ≤ 2× base |

### 7.3 Card behaviors

Cards are data-driven and combine three building blocks:

1. **Stat modifiers:** additive or multiplicative changes to player and weapon stats.
2. **Event hooks:** `on_fire`, `on_hit`, `on_kill`, `on_block`, `on_block_success`, `on_dash`, `on_slide_start`, `on_land`, `on_wall_jump`, `on_reload`, `on_take_damage`, `on_round_start`.
3. **Projectile behaviors:** components attached to projectiles (bounce, home, split, pierce, explode, apply status).

### 7.4 Starter pool (MVP, about 35 cards)

Names are placeholders, but they follow one theme: **early-2000s computing and rendering jargon.**

**GUN**

| Card | Rarity | Effect | Drawback |
|---|---|---|---|
| Polygon Budget | Common | +40% damage, +50% projectile size | −20% fire rate |
| Frame Skip | Common | +60% fire rate | −25% damage |
| Broadband | Common | +80% projectile speed | — |
| Swap File | Common | +4 magazine | +0.3 s reload |
| Quick Load | Common | −35% reload time | — |
| Physics Object | Common | Hits knock the target back 5 m/s | — |
| Scatter Plot | Uncommon | Fires 5 pellets per shot, 30% damage each, 6° spread | +0.3 s reload |
| Normal Map | Uncommon | Projectiles bounce twice, +15% damage per bounce | −15% projectile speed |
| Screensaver | Uncommon | Projectiles home gently toward the nearest visible enemy (90°/s) | −30% projectile speed |
| Clipping | Uncommon | Projectiles pass through walls up to 1 m thick | −20% damage |
| Corrupted Texture | Uncommon | Hits apply 18 damage over 3 s (stacks ×3) | −20% direct damage |
| Vsync | Uncommon | Hits slow the target's movement by 20% for 1 s | −10% damage |
| Overdraw | Rare | Projectiles explode on impact: 2.5 m radius, 20 splash damage, knockback | −2 magazine, −20% fire rate |
| Mipmap | Rare | After 10 m, each projectile splits into 3 at 40% damage | Split projectiles −25% speed |

**BODY**

| Card | Rarity | Effect | Drawback |
|---|---|---|---|
| High Poly | Common | +40 max health | −5% run speed |
| Low Poly | Common | Model and hitbox 15% smaller | −20 max health |
| Idle Animation | Uncommon | After 3 s without taking damage, regenerate 10 HP/s | — |
| Parasite Process | Uncommon | Heal 25% of damage dealt | −10 max health |
| Save State | Rare, Unique | Once per round, lethal damage instead rewinds you to where you were 2 s ago, with 40 HP | −20 max health |

**MOVE**

| Card | Rarity | Effect | Drawback |
|---|---|---|---|
| Overclock | Common | +1 dash charge | — |
| Frictionless | Common | −60% slide friction | −15% ground acceleration |
| Screen Tear | Common | +100% wall ride duration, +1 wall jump | — |
| Refresh Rate | Common | +12% run speed, +2 m/s to the speed soft cap | −10 max health |
| Double Buffer | Uncommon | +1 air jump | — |

**BLOCK**

| Card | Rarity | Effect | Drawback |
|---|---|---|---|
| Cache Hit | Common | −35% block cooldown | — |
| Ctrl+Z | Common | A block that absorbs damage instantly reloads and refunds a dash charge | — |
| Alt+Tab | Uncommon | Blocking teleports you 5 m in your movement direction | — |
| Reflection Map | Rare | Blocked projectiles reflect back at their shooter at full damage | +1 s block cooldown |

**FLOW** (these tie movement and combat together)

| Card | Rarity | Effect | Drawback |
|---|---|---|---|
| Hot Swap | Common | While sliding, reload 1 round every 0.15 s | — |
| Kinetic Energy | Uncommon | +5% damage per m/s of horizontal speed above 8 m/s (max +40%, reached at 16 m/s) | — |
| Momentum Loan | Uncommon | Each hit refunds 25% of a dash charge | — |
| Recoil Engine | Uncommon | Each shot pushes you 3 m/s away from where you aim (shoot down to climb) | — |

**ABILITY** (fills the E slot)

| Card | Rarity | Effect | Cooldown |
|---|---|---|---|
| Hard Drop | Uncommon | In the air: slam down at 35 m/s. Impact deals 30 damage in a 3 m radius. Jumping within 0.2 s of impact launches you 1.5× higher. | 5 s |
| Bookmark | Uncommon | Place a beacon. Reactivate to teleport back to it. | 8 s |
| Hyperlink | Rare | Grapple: 30 m range, pulls you at 22 m/s. Releasing keeps your velocity. | 6 s |

### 7.5 Future card directions
- **CURSE cards:** your pick also weakens the opponent (for example, "Packet Loss": the opponent's projectiles randomly vanish 10% of the time, and yours lose 10% damage).
- **Transformations:** rare cards that replace the Pointer's fire mode (beam, charge shot, railgun).
- **Synergy "sets":** holding 3 cards of one theme unlocks a hidden bonus.

---

## 8. Arenas

### 8.1 Design rules

1. **Small and vertical.** Playable footprint around 40 × 40 m, with at least 3 height layers. Spawns are about 3–4 s of travel apart at run speed.
2. **Built for lines.** Every arena has at least one continuous "flow loop": a route you can run at speed using slides, wall rides, and hops without breaking momentum.
3. **No dead ends.** Every area has at least two exits, one of them vertical.
4. **Controlled sightlines.** The longest open sightline is about 40 m. Long lanes have cover breaks.
5. **Readable surfaces.** Wall-rideable surfaces share one consistent visual language across all arenas (for example, a distinct tile or panel pattern). Players should never guess.
6. **Symmetrical for 1v1**, rotational or mirrored. Asymmetry only in visual dressing.
7. **Unloading-ready.** Each arena defines its collapse rings for sudden death ([§6.3](#63-round)).

### 8.2 Arena concepts

| Arena | Concept | Movement feature |
|---|---|---|
| **Waiting Room** | An endless beige waiting room. Floating plastic chairs, a monolithic water cooler, a TV showing a looping weather channel. | Chair "stepping stones", long carpeted slide lanes |
| **Food Court Eclipse** | An empty mall food court under a black sun. Dry fountains, escalators, neon signs for restaurants that never existed. | Escalators as slide ramps, fountain bowls as half-pipes |
| **Aquarium Server** | Server racks on a sea floor. Caustic light, drifting bubbles, a whale made of cables. | Tall rack corridors for wall ride chains |
| **Birthday.exe** | A giant low-poly birthday cake island floating in a cloud skybox. Party hats the size of houses. | Cake tiers as layers, candles as grapple anchors |
| **Hotel Pool Nocturne** | An indoor hotel pool at 3 a.m. Tiled slides, chlorine glow, too many doors. | Empty pool as a slope bowl, tiled water slides |

**MVP:** 3 greybox arenas, 1 of them art-complete for the vertical slice.

### 8.3 Movement sandbox
A dedicated training map with a speedometer, a ghost replay of your last run, movement challenges, and target dummies. For a movement-first game this is a core feature, not a menu extra.

---

## 9. Game feel and flow

Flow is the promise of the game. These rules make it concrete.

### 9.1 No dead frames
- No landing recovery, no sprint-to-fire delay, no reload slowdown, no ADS transition.
- Reload is cancelled by firing (if ammo > 0) and never blocks movement.
- Every input is buffered for 120 ms: jump, dash, slide, block, ability.

### 9.2 Chains
Any verb can flow into any other. The system is designed around chains like these:
- **Slide → hop → air strafe → wall ride → wall jump → dash → land in slide.**
- **Dash → dash-jump → mantle → slide**
- **Block mid-slide → Ctrl+Z refund → dash out**

Flow cards (Hot Swap, Momentum Loan, Kinetic Energy) turn good movement into combat rewards, so good movement *is* good combat.

### 9.3 Camera

| Setting | Default | Range |
|---|---|---|
| FOV (horizontal, 16:9) | 100° | 80–120° |
| Speed FOV kick | +5° at 16 m/s | toggle, 0–10° |
| Wall ride tilt | 6° | toggle |
| View bob | Off | toggle |
| Landing dip | Subtle, 40 ms | toggle |
| Screen shake | Low | 0–100% |

The camera is **never** driven by the fixed tick directly. Mouse look is applied every rendered frame; position is interpolated between ticks.

### 9.4 Feedback
- **Hits:** hitmarker plus a distinct sound. Headshots get their own sound and marker. Kill confirm gets a short, sharp accent.
- **Being hit:** a directional damage indicator and a brief vignette. It must never obscure aim.
- **Viewmodel:** procedural sway that reacts to velocity, slides, wall rides, and landing, so the gun "breathes" with your movement.
- **Speed:** optional speedometer. At high speed, subtle wind audio and speed-line particles at the screen edges.
- **No hitstop** (online multiplayer can't pause time). Weight comes from sound and camera micro-kicks instead.

### 9.5 Accessibility
- Sensitivity shown in cm/360 as well as a raw value. Raw input is always on.
- Every camera motion effect can be toggled off.
- Colorblind-safe enemy highlight presets.
- Hold/toggle options for crouch and block.
- Full key rebinding.

---

## 10. Art direction

### 10.1 Target
**Surreal, early-2000s realtime 3D.** The look of PS2, Dreamcast, and early-2000s PC games, used to build dream spaces: mundane places (waiting rooms, malls, hotel pools, offices) made uncanny through scale, emptiness, repetition, and wrong details.

### 10.2 Visual rules

| Element | Direction |
|---|---|
| Geometry | Low-poly. Characters 1.5–3k triangles, props a few hundred. Faceted silhouettes are welcome. |
| Textures | Low resolution (64–256 px), bilinear filtering. Visible texel density is part of the look. |
| Lighting | Baked lightmaps plus vertex color. Strong ambient gradients. No realtime GI. |
| Materials | "Wet plastic" specular highlights, chrome environment-mapped reflections, emissive signs. These are signatures of the era. |
| Atmosphere | Heavy distance fog in dreamy colors, gradient skyboxes, lens flares, soft bloom. |
| Color | Pastels and beige for the world, saturated emissive for gameplay-relevant elements. |
| Post-processing | Bloom, LUT color grading, optional subtle dithering. **No motion blur** (it fights readability and flow). |
| Surreal devices | Impossible scale (giant mundane objects), liminal emptiness, repeating architecture, floating props, looping TVs, skies that aren't skies. |

### 10.3 Readability rules (Pillar 4)
- **Players:** glossy, featureless figures with a strong rim light and emissive player color. They must separate from any background at any distance.
- **Projectiles:** bright emissive cores with short trails. Enemy projectiles use the enemy's color.
- **Card accretions:** Partials attach to the player model in consistent slots (head, back, orbit), so builds are readable at combat range.
- **Gameplay surfaces:** wall-rideable surfaces, hazards, and unloading zones each have one consistent visual language across all arenas.
- **Fog** never hides a player inside the maximum sightline.

### 10.4 Characters
- Base figure: a blank, glossy mannequin-like body with a simple primitive head (sphere, cube, or CRT monitor). It is uncanny but friendly.
- Cosmetics (post-MVP): head primitives, surface materials (chrome, marble, carpet, TV static), idle animations, accretion styles.

---

## 11. Audio

### 11.1 Music
- Early-2000s electronic: breakbeat, trip-hop, chopped vocals, glossy synth pads, reverb-drenched lounge.
- Dynamic intensity: low layer during the countdown, full track once live, a filtered and warped layer during Unloading.
- Each arena has a signature track. The draft screen has calm "menu music" that stays in the arena's key.

### 11.2 Sound effects
- **Clarity first.** Footsteps, slides, dashes, wall rides, and enemy fire are fully spatialized and audible, so you can track the opponent by ear.
- Each card with a visible effect has a distinct sound signature (bounce, explode, homing hum).
- Movement sounds are satisfying on their own: slide scrape, dash whoosh, wall kick thud, a landing sound that changes with impact speed.
- The world's sound is surreal, too: distant muzak, HVAC hum, looping TV audio, all mixed below gameplay.

---

## 12. UI / UX

### 12.1 Style
The UI draws on early-2000s interfaces: beveled chrome, translucent panels, pixel fonts mixed with glossy display type, installer-wizard and media-player-skin energy. Cards can be presented as CD-ROM jewel cases or installer dialogs.

### 12.2 HUD (minimal)
- Crosshair (customizable)
- Health
- Ammo and reload progress
- Dash charges
- Block cooldown
- Ability cooldown (if any)
- Round timer and score
- Both players' card icons (compact strip)
- Optional: speedometer, FPS / ping

### 12.3 Key screens
- Main menu, settings, lobby (invite / join code)
- Draft screen (5 cards, timer, the opponent's build visible on the side)
- Matchup screen (both builds, new card highlighted)
- Match end (round-by-round recap with the card picked each round)
- Movement sandbox menus

---

## 13. Modes

| Mode | Phase | Notes |
|---|---|---|
| 1v1 online (private lobby) | MVP | Invite or join code |
| Movement sandbox | MVP | See [§8.3](#83-movement-sandbox) |
| Custom rules | MVP (basic) | Rounds to win, card pool on/off, round timer |
| 2v2 | Post-MVP | Losing team members each draft |
| FFA (3–4) | Post-MVP | Everyone except the winner drafts |
| Ranked 1v1 | Post-MVP | Needs dedicated servers |
| Time trials | Post-MVP | Movement courses, ghosts, leaderboards |

---

## 14. Technical design

### 14.1 Engine (decision needed)

| Option | For | Against |
|---|---|---|
| **Godot 4** (recommended) | Lightweight and fast to iterate. Custom shaders for the retro look are easy. Open source, no licensing risk. A small binary and fast load times suit short rounds. | The high-level multiplayer API is basic, so prediction and lag compensation are ours to build. (We need custom movement prediction in any engine anyway.) |
| Unity | Mature ecosystem, several netcode libraries with prediction (Fish-Net, Photon Fusion) | Heavier. A history of licensing changes. |
| Unreal 5 | Best built-in networking and prediction | Heavy. Fights the low-fi pipeline. Custom movement in CharacterMovementComponent is painful. Slow iteration. |

**Recommendation:** Godot 4 with a custom kinematic character controller and our own prediction and reconciliation layer. Language choice (GDScript vs C#) is part of this decision. See [§16](#16-open-questions).

### 14.2 Simulation and netcode

| Topic | Plan |
|---|---|
| Authority | Server-authoritative. MVP uses a listen server (host) over a relay (such as Steam Networking Sockets). The server code stays headless-capable for future dedicated servers. |
| Tick rate | 60 Hz fixed simulation and send rate (configurable to 120 Hz) |
| Local player | Client-side prediction of movement, weapon, and block, with server reconciliation (rewind and replay unacknowledged inputs) |
| Remote players | Interpolated about 2 ticks behind, with extrapolation capped at 100 ms on packet loss |
| Projectile hits | The server spawns the authoritative projectile fast-forwarded by the shooter's latency (capped at 100 ms) and tests that segment against lag-compensated (rewound) hitboxes. After that, the projectile simulates in present time. The client shows its own predicted projectile immediately. |
| Input | Commands carry full-precision view angles and buttons. Input is sampled every rendered frame and aggregated per tick. |
| Validation | The server checks movement against the sim (speed and teleport checks) and card-derived stats |
| Test matrix | 0 / 50 / 100 / 150 ms RTT, with ±20 ms jitter and 0–3% packet loss, from M3 onward |

### 14.3 Performance targets

| Target | Value |
|---|---|
| Frame rate | 144+ fps at 1080p on a GTX 1060 / RX 580-class GPU; 240+ fps on high-end |
| Frame pacing | No spikes over 2 ms above the average frame time during a round |
| Input latency | Mouse look applied on the rendered frame. No input smoothing. Support for the vendor low-latency modes where available. |
| Allocations | No per-frame garbage in gameplay. Projectiles, VFX, and decals are pooled. |
| Load times | Under 2 s between rounds (arenas stay loaded for the whole match) |

### 14.4 Architecture outline

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation (client only)                                  │
│  camera · viewmodel · VFX · audio · HUD · menus             │
├─────────────────────────────────────────────────────────────┤
│ Simulation (shared client/server, fixed tick, pure logic)   │
│  movement · weapon · projectiles · block · abilities        │
│  health/damage · card effects (stats, hooks, behaviors)     │
├─────────────────────────────────────────────────────────────┤
│ Match layer (server-authoritative)                          │
│  match state machine · round phases · draft · unloading     │
├─────────────────────────────────────────────────────────────┤
│ Net layer                                                   │
│  transport · input commands · snapshots · prediction ·      │
│  reconciliation · interpolation · lag compensation          │
├─────────────────────────────────────────────────────────────┤
│ Data                                                        │
│  card definitions · tuning tables · arena metadata          │
└─────────────────────────────────────────────────────────────┘
```

- **Simulation never reads presentation state.** Presentation only reads sim state and events.
- **All tuning values live in data files** and can be hot-reloaded in dev builds.
- **Cards are data**: a definition file declares stat modifiers, hooks, and projectile behaviors. New cards should rarely need new code.

### 14.5 Telemetry (playtests)
Round length, match length, card pick rates, win rate after picking each card, speed distribution, kill distance, block success rate, and movement verb usage.

---

## 15. Scope and milestones

Each milestone has a **gate question**. We don't move on until the answer is yes.

| # | Milestone | Contents | Gate question |
|---|---|---|---|
| M0 | Pre-production | Engine decision, repo setup, coding conventions, greybox kit | Can we greybox an arena in an afternoon? |
| M1 | **Movement prototype** (offline) | Full base movement kit, live tweak panel, speedometer, one greybox test course | Is running around alone fun for 10 minutes? |
| M2 | Combat prototype (offline) | Pointer, projectiles, block, health, target dummies, hit feedback | Does shooting while moving feel fluid and fair? |
| M3 | Networked 1v1 | Prediction, reconciliation, interpolation, lag compensation, round state machine, sudden death | Does a 100 ms match feel as good as LAN? |
| M4 | Cards | Card system (stats, hooks, behaviors), draft flow, 15 cards | Do matches produce different builds and close scores? |
| M5 | Vertical slice | 1 art-complete arena in the target style, 3 greybox arenas, ~35 cards, audio pass, core menus, movement sandbox | Would a stranger play a second match? |
| M6 | Alpha | Closed playtests, telemetry, balance passes, remaining arena art | — |

**MVP = M5 vertical slice:** 1v1 online, 3 arenas (1 fully arted), about 35 cards, movement sandbox, basic custom rules.

---

## 16. Open questions

| # | Question | Default assumption in this draft |
|---|---|---|
| 1 | Engine: Godot 4, Unity, or Unreal? If Godot, GDScript or C#? | Godot 4 |
| 2 | Should dash and block merge into one "phase dash" with i-frames (fewer verbs, tighter flow), or stay separate (more card hooks, closer to ROUNDS)? | Separate |
| 3 | Headshots: keep ×1.5, lower it, or remove them to put more weight on movement? | ×1.5 |
| 4 | Should air strafing gain speed at all, or only steer? (Skill ceiling vs. accessibility) | Gain, soft-capped at 16 m/s |
| 5 | Opening draft: does everyone pick 1 card before round 1? | No; round 1 is vanilla |
| 6 | Does the winner get anything (such as a smaller "winner's pick" every few rounds)? | Nothing |
| 7 | Does "Partials" hold up as the name for cards, with visible body accretions? | Yes, as a proposal |
| 8 | Networking: listen server via Steam relay for MVP, or dedicated servers from day one? | Listen server |
| 9 | Controller support: in the MVP, or post-MVP with aim assist tuning? | Post-MVP |
| 10 | Monetization model (premium, or premium plus cosmetics)? | Premium, TBD |
