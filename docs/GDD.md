# xtrapartial — Game Design Document

| | |
|---|---|
| **Version** | 1.6 (draft) |
| **Date** | 2026-09-29 |
| **Status** | Pre-production: structure and direction, all numbers are starting values to tune |
| **Genre** | Round-based, movement-first arena FPS with weapon pickups |
| **Platform** | PC (Windows / Linux, Steam Deck compatible), mouse & keyboard first |
| **Players** | 1v1 core; 2v2 and 3–4 player FFA later |

### Revision history

| Version | Changes |
|---|---|
| 0.1 | Initial draft (ROUNDS-style card draft) |
| 0.2 | "Rounds" means round-based play, not the game ROUNDS. Replaced the card draft with STRAFTAT-style weapon pickups and a weapon roster. Maps now rotate every round. Added Smashdown as a base move and the Heartshot mechanic. Removed Block and the ability slot. |
| 0.3 | Players spawn with fists only; the Pointer becomes a map pickup. Engine decided: Godot 4.7 with GDScript. |
| 0.4 | Art direction moves toward ULTRAKILL: point-filtered pixel textures, low internal resolution, glossy surfaces, deliberately "bad" lighting. Added the logo. |
| 0.5 | Player body defined (smooth, joint-free, gingerbread-person proportions). Added the death sequence: blackout, spotlight, and the body crumbling into diced pieces. |
| 0.6 | UI direction set: everything in the logo's style (tiny Arial in framed boxes, blown up soft), replacing the chrome/bevel idea. HUD, overlays, pause and main menu defined and built. |
| 0.7 | Body smoothed out (§11.4): legs split from the torso slab instead of glued on, one-piece tapered arms, C2 blends, A-pose rest. |
| 0.8 | UI motion (§13.5): springy HUD that reacts to movement, speed meter, kicks, stamped pop-ups, letter-tile banners, typed map cards, animated menus, scene wipe, *ui motion* setting. |
| 0.9 | Experimental impact frames on kills and hard smashdowns, with a camera punch the HUD rides too, off by default (§10.4). Pop-ups land letter by letter and shatter (§13.5). |
| 1.0 | Movement feel pass: constant slide friction (slides carry, hills speed you up), heavier smashdown (0.1 s hang, shockwave ring, landing tell), stronger slam bounce (9 + 0.75 × drop, max 22, plus a 3 m/s kick). A camera that reacts to every movement (§10.3), speed lines (§10.4). |
| 1.1 | Camera and HUD reactions are fast and jerky by default (snap in, drop off, stepped jitter, flickering speed lines); new *camera smoothing* setting for the smooth feel. |
| 1.2 | First six guns built, each modelled on a real kind of gun (§7.4), with first-person arms, third-person holds and animated actions (§11.5). Hit zones ride the animated body; dummies react to the part you hit (§5.2, §9.4). Ammo shown as a column sized by capacity and a ring around the crosshair (§13.3). Magazine sizes moved toward the real guns'. |
| 1.3 | Weapons renamed from computing jargon to realistic-sounding model names (SP-12, Marshal .357, SX-50, TR-30, Warden 12, Heron .308…). Damage numbers merge: one number per target that adds up and grows (§10.4). |
| 1.4 | Hats: the first cosmetic, and how teams are told apart. Sixteen hats in red or blue, or no hat and a team triangle over the head; picked on the title screen (§11.4, §13.4). Dash charges recharge slower (1.75 → 2.25 s). First-person arms sit lower and further back and carry on past the cut off screen, so no arm end ever shows. Punches mix jabs, crosses, hooks and uppercuts. UI boxes drawn like the logo: a crooked black frame set in from a white card. |
| 1.5 | Map rules rewritten (§9.1): size varies from map to map, structure before theme, fair but not always symmetrical, long sightlines allowed on the big maps. The first eight greybox maps built and tested (§9.3): Stack, Terrace, Switchback; two spread-out maps for more players and longer rounds, Archipelago and Rift, where the sniper has a job; and three large team maps in the traditional style, Boulevard, Holdfast and Depot. F9 steps through them in game. The movement sandbox moves to §9.4. |
| 1.6 | The two game styles built (§8.5): free-for-all in short rounds (last one standing, first to five, a new map each round) and teams as one long game (respawns, kill target, time limit), run by a server-side match, with practice bots. Ammo by style (§7.2): teams keep "no reloads" but add resupply crates, faster pads and a spawn pistol. Players take damage and die like the dummies, kills go to whoever hit them last (§5.1). In free-for-all everyone picks their colour; names float over heads (§11.4). |

---

## Table of contents

1. [Vision](#1-vision)
2. [Design pillars](#2-design-pillars)
3. [Core loops](#3-core-loops)
4. [Movement](#4-movement)
5. [Combat](#5-combat)
6. [Heartshot](#6-heartshot)
7. [Weapons](#7-weapons)
8. [Match structure](#8-match-structure)
9. [Maps](#9-maps)
10. [Game feel and flow](#10-game-feel-and-flow)
11. [Art direction](#11-art-direction)
12. [Audio](#12-audio)
13. [UI / UX](#13-ui--ux)
14. [Modes](#14-modes)
15. [Technical design](#15-technical-design)
16. [Scope and milestones](#16-scope-and-milestones)
17. [Open questions](#17-open-questions)

---

## 1. Vision

**Elevator pitch:** a round-based arena FPS where every round drops you into a new small, surreal map with a new spread of weapons, and the player who moves best gets to the good guns first. One life per round, rounds last seconds, and a perfect shot to the heart ends it instantly.

**The fantasy:** you are a glossy, blank figure with a glowing heart and nothing but your fists, pouring through a dreamlike space at 15 m/s. You slide under a floating water cooler, wall-jump off bathroom tile, smash down onto a rocket launcher before your opponent reaches it, and throw your empty revolver at their face on the way.

**What xtrapartial is:**
- Short rounds (15–40 s) on a large rotation of small maps, and quick matches (5–10 min).
- A movement system with a high skill ceiling that still feels good in the first minute.
- Weapons found on the map. Many types, each with a clear identity. Map control means weapon control.
- A precision mechanic, the **Heartshot**, that gives skilled aim a rare, dramatic instant kill.
- A distinctive look: surreal, low-poly, early-2000s realtime 3D.

**What xtrapartial is not:**
- Not a loadout or class shooter. Everyone spawns with only their fists. Power comes from the map.
- Not a tactical shooter. No aim-down-sights (except scoped weapons), no movement inaccuracy, no economy.
- Not a hero shooter. No abilities beyond movement and what you pick up.

### Comparable titles

| Title | What we take |
|---|---|
| STRAFTAT | Round-based duels, many small maps in rotation, weapons picked up from the map, wide weapon variety |
| Titanfall 2 | Wall ride, slide-hop, momentum preservation |
| ULTRAKILL | Dash charges, ground slam with slam bounce, "no dead frames" feel |
| Quake / Unreal Tournament | Air strafing, glowing floating weapon pickups, map control |
| Endocopia-style surreal games | Dreamlike, uncanny, early-2000s 3D aesthetic |

---

## 2. Design pillars

Every feature is weighed against these. If something violates a pillar, it needs a strong reason to exist.

### P1. Momentum is sacred
Movement is the main skill. Every verb either preserves speed or adds to it. Nothing silently eats momentum. Shooting, switching, picking up, and throwing never slow you down.

### P2. Smooth over everything
Input-to-screen latency, frame pacing, netcode, animation, and camera all serve one goal: the game should feel frictionless under your hands. When a feature costs frame time or adds input delay, the feature loses.

### P3. Every round is new
A new map and a new weapon spread each round. Players read the layout during the countdown, plan a route, and race for it. No two rounds play the same.

### P4. Dreamlike, but readable
The world is strange, but the opponent, their weapon, their projectiles, and their heart must always be instantly legible. The surreal never gets in the way of combat clarity.

---

## 3. Core loops

```
 MOMENT (seconds)              ROUND (15–40 s)                MATCH (5–10 min)
 ┌────────────────────┐       ┌────────────────────────┐     ┌──────────────────────┐
 │ move → grab weapon │       │ new map → read pads    │     │ round → round → ...  │
 │ → fight → throw    │ ───▶  │ → race to weapons →    │ ──▶ │ first to 7 wins      │
 │ empty → grab next  │       │ duel → one player falls│     │                      │
 └────────────────────┘       └────────────────────────┘     └──────────────────────┘
```

- **Moment-to-moment:** chain movement to reach weapons and angles, fight with what you hold, throw it when it runs dry, and route to the next pickup.
- **Round:** a new map. Everyone spawns with fists. One life each. Last player standing wins the round.
- **Match:** first player to win 7 rounds wins.
- **Meta (post-MVP):** cosmetics, ranked play, movement time trials.

---

## 4. Movement

Movement is the heart of the game and gets the most tuning time. The first playable milestone is movement alone (see [§16](#16-scope-and-milestones)).

### 4.1 Player body

| Property | Value |
|---|---|
| Units | 1 unit = 1 m |
| Standing capsule | 1.8 m tall, 0.35 m radius, eye height 1.6 m |
| Crouch / slide capsule | 0.9 m tall, eye height 0.75 m |
| Step height | 0.4 m (stairs and small lips never interrupt a run) |
| Max walkable slope | 50° |

### 4.2 Base verbs

Every player has all of these at all times.

| Verb | Input | Summary |
|---|---|---|
| **Run** | WASD | Source-style acceleration and friction. Snappy but with weight. |
| **Jump** | Space | Fixed height, with coyote time and input buffer. |
| **Air strafe** | A/D + mouse | Quake-style air control. Steering plus modest speed gain. |
| **Slide** | Ctrl (or C) on the ground | Low-friction slide with an entry boost. Gains speed on slopes. |
| **Slide-hop** | Jump during slide | Keeps all horizontal speed. The core chaining move. |
| **Dash** | Shift | Short burst in the input direction. 2 charges. |
| **Smashdown** | Ctrl (or C) in the air | Slam straight down, shockwave on impact, then bounce or slide out. |
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
| Slide friction | 3.5 m/s², constant | Not proportional to speed, so fast slides carry: a 13 m/s dash-slide still has 11.6 m/s after 0.4 s. |
| Slope behavior | Gravity projected on the slope | Any slope steeper than about 10° out-pulls the friction, so downhill slides gain speed (the 20° slide hill adds about 3 m/s²). |
| Exit | Speed < 4 m/s → crouch-walk. Release → stand, if there is headroom. | |
| Slide-hop | Jump keeps 100% of horizontal speed | |

**Dash**

| Parameter | Value | Notes |
|---|---|---|
| Charges | 2 | |
| Recharge | 2.25 s per charge, one at a time | |
| Burst | 18 m/s for 0.15 s in the input direction (look direction if no input) | Horizontal only |
| Exit speed | max(pre-dash horizontal speed, 10 m/s) along the dash direction | A dash never slows you down |
| Airborne | Zeroes downward velocity at start | Recovers bad jumps |
| Dash-jump | Jumping during a dash cancels it and keeps its exit speed | |

**Wall ride, wall jump, mantle**

| Parameter | Value | Notes |
|---|---|---|
| Wall ride attach | Airborne, touching a wall, speed along the wall ≥ 5 m/s | |
| Wall ride duration | 1.2 s | Gravity eases from 0% back to 100% on a squared curve: a ride holds height early and sinks late (about 2.4 m over a full ride that starts level) |
| Wall ride reuse | Once per wall surface until you land or touch a different wall | Prevents climbing a single wall forever |
| Wall jump | Normal × 6 m/s + up 6.5 m/s, keeps speed along the wall | 3 per airtime, refilled on landing |
| Wall jump window | 150 ms after leaving the wall | "Coyote" for walls |
| Mantle trigger | Ledge top 0.5–2.0 m above feet, within 0.6 m, moving forward | |
| Mantle | 0.2 s, exits with 80% of prior horizontal speed | |

### 4.4 Smashdown

The smashdown is a vertical move that is also an attack and a chain starter. It turns height into speed, damage, or more height.

**Input.** Pressing crouch in the air triggers a smashdown if there is at least 1.5 m of clearance below. On a shorter drop, the same press is buffered as a landing slide instead, so slide-landings still work. Players who prefer a dedicated key can bind smashdown separately and turn off crouch-to-slam.

**Sequence**

| Phase | Value | Notes |
|---|---|---|
| Windup | 0.1 s hang, vertical velocity zeroed | A readable commit. The view tightens and tips up. |
| Descent | 40 m/s straight down | Horizontal speed is **banked**, not lost. No air control during descent. The view stretches wide, rattles, and speed lines stream in. |
| Limit | Once per airtime, no cooldown | Refills on landing |

**Impact**

| Effect | Value |
|---|---|
| Shockwave radius | 3.5 m |
| Shockwave damage | 15 + 1.5 per meter fallen (max 45) at center, 50% at the edge |
| Shockwave knockup | Players hit are launched 9 m/s up and 4 m/s outward |
| Direct stomp | Landing on a player deals 70 damage |
| Self-damage | None |

**Exits (the chain)**

| Exit | Input | Result |
|---|---|---|
| Slam bounce | Jump within 0.2 s of impact | Vertical velocity = min(9 + 0.75 × drop height, 22) m/s. Banked horizontal speed restored, plus a 3 m/s kick toward your input (or onward without input). |
| Slam slide | Hold crouch through impact | Slide at banked speed + 4 m/s. Ignores the normal slide boost cooldown. |
| Plain landing | Neither | Banked horizontal speed restored |

**Tells.** A rising whistle during the descent, a bright trail, and a ring projected on the ground where you will land, visible to both players (the ring is built: it tightens as you get close). A smashdown is a commitment, and the opponent can read and punish it.

**Weight.** The impact sends a white shockwave ring racing out to the 3.5 m radius over a ground flash, slams the camera down with a pitch-in, twist and zoom-snap, and shakes it (harder the further you fell). A slam bounce launches off a smaller ring while the view whooshes wide and tips up. Code: `src/render/smash_fx.gd`, camera in `src/player/player.gd`.

**Why the knockup matters.** A knocked-up opponent follows a predictable arc, which sets up an aimed follow-up shot. Smashdown → airborne opponent → Heartshot is the high-skill combo.

### 4.5 Movement rules

1. **Deterministic and pure.** Movement is a pure function of `(state, input, dt)`. That is needed for client prediction ([§15](#15-technical-design)).
2. **Fixed timestep.** Movement simulates at the fixed network tick. The camera and rendering interpolate between ticks.
3. **Momentum is never silently removed.** Only friction, drag above the soft cap, collisions, and explicit weapon effects (knockback, the Stasis slow field) reduce speed.
4. **Collision slides, not stops.** Glancing a wall or corner deflects velocity along the surface. Small ledges are stepped over or mantled.
5. **Every chain is legal.** Any verb can follow any other verb. There is no "recovery" state.
6. **Skill ceiling, skill floor.** Buffers and coyote windows make basic chaining easy. Air strafing, slope slides, and slam bounces give experts more.

---

## 5. Combat

### 5.1 Health and damage

| Property | Value |
|---|---|
| Max health | 100 |
| Regeneration | None in free-for-all: rounds are too short to need it. In teams, 25/s after 5 s untouched. |
| Armor / health pickups | None in MVP. Weapons are the only pickups. |
| Who gets the kill | Whoever hit you last, if that was within the last 5 s: knocking someone off the map counts. A fall nobody caused is nobody's kill. |
| Friendly fire | Off in teams (a teammate's shots don't land), on in free-for-all. |

Players take hits exactly like the practice dummies (the same hit shapes, zones and reactions); they have their own physics layer, so shots trace the world and then the bodies' hit shapes, never a player's movement capsule. Code: `Player.take_hit()`.

### 5.2 Damage zones

| Zone | Size | Effect |
|---|---|---|
| Body | Capsules on the body's bones: neck, chest and gut (two each, the slab's rounded sides), upper arms, forearms, thighs, shins | Base damage |
| Head | Sphere matching the drawn head, 0.165 m radius | ×1.5 by default (set per weapon) |
| **Heart** | Sphere, 0.07 m radius, inside the chest | **Instant kill** with eligible weapons. See [§6](#6-heartshot). |

The shapes ride the animated skeleton, so a shot hits what you see, and each one names a part (head, neck, chest, gut, left/right arm, left/right leg) that the body reacts with:

| Part hit | Reaction |
|---|---|
| Head / neck | The head-hit clip over the upper body; the head and neck snap back away from the shot. |
| Chest | The chest-hit clip; the upper spine is knocked back. |
| Gut | A lighter chest clip; the lower spine folds and the hips dip. |
| Arm | That arm is flung back along the shot, the shoulders twist a little. |
| Leg | That leg is kicked back and the knee buckles; the hips drop. |

Knocks land partly on the frame and swing out the rest of the way on springs, wobble once and settle, bigger for bigger hits. Code: `src/combat/hit_shapes.gd`, `PlayerModel.react_to_hit()`.

*Prototype note:* the zones follow the rendered pose. That is exact locally, but for netcode the server and every client must agree on the pose (rule 4 of §6.1): see open question 15.

### 5.3 Loadout

| Slot | Contents |
|---|---|
| Fists | Always available. The only thing you spawn with. |
| Primary | One weapon picked up from the map. Empty at spawn. |
| Throwable | One throwable type, up to 2 charges, picked up from the map |

### 5.4 Combat rules

- **No dead states.** Firing, switching, picking up, and throwing never lock or slow movement.
- **No ADS.** Right mouse is each weapon's alt-fire. Scoped weapons zoom as their alt-fire.
- **No movement inaccuracy.** Spread is a property of the weapon, never of your speed.
- **Self-damage** exists only from explosives, at 40%, and comes with knockback (explosive jumps are allowed).
- **Mixed hitscan and projectile.** Each weapon picks whichever suits its identity. Most weapons are projectiles, so shots are visible.

### 5.5 Default controls (keyboard and mouse)

| Action | Key |
|---|---|
| Move | WASD |
| Look | Mouse (raw input) |
| Fire | Left mouse |
| Alt-fire | Right mouse |
| Jump | Space (also mouse wheel down, for hop timing) |
| Slide / crouch (smashdown in the air) | Left Ctrl or C |
| Dash | Left Shift |
| Pick up / swap | E |
| Throw primary | Q |
| Use throwable | G |
| Switch primary / fists | 1 / 2, mouse wheel up |
| Scoreboard | Tab |

Everything is rebindable. Crouch supports hold or toggle.

---

## 6. Heartshot

> **The rule:** every player has a small heart in their chest. A shot from an eligible weapon that passes through it kills instantly, whatever the target's health.

### 6.1 Will it work?

It can, if a few conditions hold. Instant-kill zones work when they feel **earned**, and they fail when they feel **random**. These rules exist to keep it earned:

1. **Only precision weapons can heartshot.** No pellets, explosions, beams, flames, bouncing projectiles, melee, or thrown weapons, and nothing that fires faster than one shot every 0.3 s. If an SMG could heartshot, spraying center mass would sometimes "win the lottery," and that would ruin the mechanic.
2. **The heart is visible.** It glows on the character's chest. It is a target you choose to aim at, not a hidden bonus.
3. **Small, but not microscopic.** With a 0.07 m radius, the heart is about 11 px wide at 10 m, 6 px at 20 m, and 3 px at 40 m (1080p, 100° FOV). For comparison, the head is about 10 px wide at 20 m. That is very hard on a moving target, but possible on a predictable one (a wall ride, the arc after a knockup, a player who stops moving).
4. **Hitboxes agree everywhere.** The heart is attached to the simulated capsule, not to client-side animated bones, so the server and every client agree exactly on where it is. A heartshot that looks clean on your screen must register.
5. **It is a highlight, not the main way to win.** The target is **3–8% of kills**. Telemetry decides the final size.

Rounds are one life and 15–40 s long, so an instant death costs little. It is a lost round, not a lost match. That makes a dramatic mechanic like this more acceptable than it would be in a longer-life shooter.

### 6.2 Rules

| Rule | Value |
|---|---|
| Location | Chest, about 1.3 m above the feet, 0.085 m left of the center line. Moves with the body's pose. |
| Hit test | The shot's path must intersect the heart sphere. It counts from the front, back, or side. |
| Walls | No heartshots through geometry, even with piercing weapons |
| Eligible weapons | Marked ♥ in the weapon tables ([§7](#7-weapons)). Fists never. |
| Headshot interaction | None. Heart and head are separate zones. |

### 6.3 Feedback

- **Shooter:** a unique sound (a heartbeat that stops on a glass chime), a distinct hitmarker, a short white flash on the crosshair.
- **Victim:** the heart visibly shatters. The death camera shows the shooter and the shot's path, so the kill reads as skill, not luck.
- **Everyone:** a Heartshot icon in the killfeed, and a stat on the match recap screen.

### 6.4 Tuning levers

In order of preference, if heartshots land too often or not often enough:

1. Heart radius.
2. Which weapons are eligible.
3. A max range for heartshots.
4. *(Experimental)* The heart shrinks as its owner's speed rises. This rewards staying in motion and ties the mechanic to Pillar 1. Test it in M2 and keep it only if it reads clearly.

---

## 7. Weapons

### 7.1 Pickup system

| Rule | Value |
|---|---|
| Weapon pads | Maps place weapon pads at fixed spots. Each pad has a tier (Standard, Heavy, Power) and a curated weapon pool. |
| Rolling | At round start, each pad rolls one weapon from its pool. Mirrored pads roll the same weapon, so 1v1 stays fair. |
| Reveal | Rolled weapons are visible during the countdown, so players can plan a route |
| Respawn | Standard pads respawn 20 s after pickup, with a visible timer. Heavy and Power pads don't respawn within a round. |
| Auto-pickup | Moving over a weapon while your primary slot is empty (or holds an empty weapon) picks it up instantly, even mid-slide or in the air. Pickup radius is 1.5 m. |
| Swap | Press E near a weapon to swap it for your current primary. The old one drops with its remaining ammo. |
| Top-up | Moving over the same weapon type you hold adds its ammo to yours, up to a full gun; the rest stays in the pickup |
| Ready time | 0.15 s after a pickup or a switch |

### 7.2 Ammo and throwing

- **Map weapons have no reserve ammo and don't reload.** What's in the gun is what you get. When it runs dry, throw it and find the next one. This keeps players moving around the map.
- **Throw (Q):** throws your primary at any ammo count. A thrown weapon deals 25 damage and 6 m/s knockback on hit, then lands and can be picked up again with whatever ammo it has left.
- **Switching after a throw:** throwing switches to fists instantly.
- **When empty:** you switch to fists automatically after 0.2 s, unless you throw first.
- **Empty weapons** dissolve 3 s after landing.
- No weapon reloads.

**By game style** (§8.5). The rules above are free-for-all's: short rounds on small maps, where scarcity keeps everyone moving and each round resets the race. A long team game on a big map would turn that into a long walk for ammo, and a "once a round" sniper would appear once a game, so teams change four things (all in `GameRules`, tunable per game):
- **Still no reloads**: no dead frames.
- **Resupply crates** stand in each team's base and along its lanes: walk up to one holding a gun and its magazine fills up, once every 8 s per player. They're hidden and inert in free-for-all.
- **Pads come back twice as fast** (10 s), and **power pads come back** after 60 s instead of never.
- **You respawn holding a pistol**, not just fists.

### 7.3 Fists

Everyone spawns with fists and nothing else. The opening seconds of every round are a race to the nearest pad ([§9.1](#91-design-rules) keeps that race short).

| Property | Value | Notes |
|---|---|---|
| Damage | 25 | +1 per m/s of your speed above run speed (max +15). A punch at full flow hits hard. |
| Swing interval | 0.4 s | |
| Reach | 2.2 m | Slight aim assist toward the target's capsule, melee only |
| Knockback | 5 m/s | |
| Alt-fire | Shove: no damage, 10 m/s knockback, 1.5 s cooldown | Knocks an opponent off a ledge or a weapon pad |
| Heartshot | Never | |
| Movement | Punching never slows you. A punch during a smashdown descent adds to the stomp. | |

### 7.4 Primary weapons (MVP roster)

Names are made up but realistic: model names in the style of real guns (a letter code with a round count, or a name with a calibre), never real products. ♥ = can heartshot.

Every gun is modelled on a real kind of gun, abstracted: chunky blocks in beige plastic, gunmetal and chrome, with one part in a candy colour like the translucent computers of the time. Its mechanism works the way the real one does (a pistol's slide, a revolver's cylinder and hammer, a pump, a bolt). Magazine sizes stay close to the real guns', so the ammo column (§13.3) tells you what you're holding.

**Built so far** (`src/combat/weapons.gd`):

| Weapon | Modelled on | Rounds | Accent | Its animation |
|---|---|---|---|---|
| SP-12 | 9 mm semi-automatic pistol | 12 | Bondi blue slide | Slide snaps back; one-handed |
| Marshal .357 | .357 revolver | 6 | Tangerine cylinder | Hammer falls, cylinder turns a sixth; alt fans the hammer with the left hand |
| SX-50 | 9 mm submachine gun | 50 | Grape magazine | Bolt carrier chatters; two hands |
| TR-30 | Assault rifle | 30 | Lime magazine | Bolt carrier; carry handle, banana mag |
| Warden 12 | Pump-action shotgun | 8 | Strawberry pump | The left hand racks the pump; red shells fly |
| Heron .308 | Bolt-action sniper rifle | 5 | Blueberry scope | The right hand leaves the grip to work the bolt; alt zooms 3× into a scope |

**Precision**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| SP-12 | Standard | 20 | 0.3 s | 12 | Projectile 150 m/s | ♥ | 9 mm pistol. Common, found near spawns. |
| Marshal .357 | Standard | 45 | 0.5 s | 6 | Projectile 250 m/s | ♥ | .357 revolver. Alt: fan the hammer (remaining rounds at 0.1 s, +3° spread, no ♥) |
| Sentry DMR | Standard | 40 | 0.35 s | 10 | Hitscan | ♥ | Alt: 1.5× zoom |
| Talon | Standard | 70 | 0.9 s | 5 | Bolt 90 m/s, with drop | ♥ | Crossbow. Bolts stick in walls. |
| Heron .308 | Heavy | 85 (head kills) | 1.2 s | 5 | Hitscan | ♥ | Bolt-action sniper. Alt: 3× zoom. |

**Automatic**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| SX-50 | Standard | 11 | 0.07 s | 50 | Projectile 180 m/s | — | SMG. Spread blooms 1° → 4°. |
| TR-30 | Standard | 16 | 0.11 s | 30 | Projectile 200 m/s | — | Assault rifle. 0.5° spread, blooming to 1.5°. |
| NX-50 | Standard | 14 | 0.09 s | 50 | Nail 90 m/s, slight drop | — | Nailgun. Nails bounce once. |
| GX-6 | Heavy | 9 | 0.04 s after 0.5 s spin-up | 200 | Projectile 160 m/s | — | Minigun. 2.5° spread. Alt: keep spun up without firing. |

**Close range**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| Warden 12 | Standard | 10 × 9 pellets | 0.8 s | 8 | Pellets, 5° spread | — | Pump shotgun. Pellets land in a readable pattern: one in the middle, a tight inner ring, an outer ring. |
| Coachman | Heavy | 12 × 9 pellets per barrel | 0.25 s | 10 | Pellets, 6° spread | — | Alt: both barrels at once, with 5 m/s self-knockback (shotgun jump) |
| FT-5 | Heavy | 120 DPS + 15 burn over 3 s | Continuous | 5 s of fuel | 8 m cone | — | Flamethrower |

**Explosive**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| RL-5 | Heavy | 90 direct, up to 55 splash (3 m) | 0.9 s | 5 | Rocket 35 m/s | — | Rocket launcher. 12 m/s knockback enables rocket jumps. |
| GL-6 | Heavy | 60 (3 m) + 3 bomblets × 20 (1.5 m) | 0.7 s | 6 | Bouncing grenade | — | Explodes after 1 s or on contact with a player |

**Strange**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| DL-8 | Standard | 35, +10% per bounce | 0.5 s | 8 | Disc 40 m/s | — | Discs bounce off walls up to 4 times |
| LX-25 | Standard | 80 DPS | Continuous | 5 s of charge | Hitscan beam, 25 m | — | Perfectly accurate, low burst |
| RG-1 | **Power** | 100 | 0.5 s charge | 3 | Hitscan | — | Railgun. Pierces players and up to 1 m of wall. One per map, at a hard-to-reach spot. |

**Utility and melee**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| GH-35 | Standard | 15 | 2.5 s cooldown | Unlimited | Hook, 35 m | — | Grapple gun. Pulls you at 22 m/s, release keeps velocity. Hooking a player pulls them toward you. |
| Slugger | Standard | 50 | 0.5 s | Unlimited | Melee | — | Bat. 12 m/s knockback. The start of each swing (0.2 s) deflects projectiles back at their shooter. |
| Katana | Standard | 55 | 0.4 s | Unlimited | Melee | — | Sword. Alt: 8 m lunge (2 s cooldown) that chains like a dash. |

### 7.5 Throwables

| Throwable | Effect |
|---|---|
| Frag | Frag grenade. 1.5 s fuse. 90 damage at center down to 20 at 4 m. |
| Stasis | Slow field. A 5 m sphere for 3 s. Players **and projectiles** inside move at 40% speed. |

### 7.6 Weapon design rules

- **One clear identity each.** A player should know what a weapon does from its silhouette and its first shot.
- **Distinct silhouettes.** Weapons are chunky and readable at 30 m in an opponent's hands.
- **Movement interactions are a feature.** Rocket jumps, shotgun jumps, the grapple, and the katana lunge all feed the movement system.
- **Power weapons are placed to reward movement.** The fastest route to them should need movement tech (a wall-ride chain, a slam bounce, a slope slide).

### 7.7 Future directions
- More weapons each update. The weapon definition system should make adding one mostly data work.
- Dual-wielding pistols.
- Map-specific weapons tied to a map's theme.
- Rare "cursed" variants of existing weapons, with a twist and a drawback.

---

## 8. Match structure

### 8.1 Flow

```
Lobby → Warmup → [ Countdown → Round → Round end → Next map ] × N → Match end → Rematch / Lobby
```

### 8.2 Warmup
- Free movement on a warmup map. Every weapon is available on racks. Instant respawn with fists.
- Ends when both players ready up, or after 60 s.

### 8.3 Round

| Phase | Duration | Rules |
|---|---|---|
| Map load | ≤ 1 s | The next map is preloaded during the previous round. A title card shows the map name. |
| Countdown | 3 s | Camera and movement active. Weapons off. Spawns are walled off by a translucent barrier that dissolves at 0. Rolled weapons are visible so players can plan a route. |
| Live | Up to 70 s | One life each. Last player standing wins. |
| Unloading (sudden death) | Starts at 40 s | The map "unloads" from the edges inward: geometry dissolves into wireframe, then into void. Standing in the unloaded zone deals 10 HP/s, rising to 25 HP/s. By 70 s only a small central platform remains. |
| Round end | 2 s | Slow-motion freeze frame on the killing blow (presentation only), then the score |

**Draw:** if both players die on the same tick, nobody scores and play moves to the next map.

**Target average round length:** 15–40 s. **Downtime between rounds:** 6 s or less in total.

### 8.4 Winning
- First to **7 round wins** by default (configurable 3–15 in custom games).
- Maps rotate every round. A match draws from the map pool without repeats until the pool runs out.
- There is no comeback mechanic by default. Rounds are short and every map resets the weapon race.

### 8.5 Game styles (built)

Two styles, each a `GameRules` preset (`src/game/game_rules.gd`), run by a `Match` (`src/game/match.gd`) that lives outside the level so it survives map changes. It runs on the machine that hosts the game (offline, yours): damage, deaths, scores, spawns and respawns are decided there and only there, ready for the network (§15.2).

| | Free-for-all (classic) | Teams |
|---|---|---|
| Shape | Short rounds, one life each; last one standing wins the round | One long game on one map, respawning |
| Win | First to 5 round wins | First team to 50 kills, or ahead after 10 min |
| Maps | A new map every round, from Stack, Terrace, Switchback, Archipelago, Rift | One of Boulevard, Holdfast, Depot |
| Round limit | 70 s, then nobody wins it (sudden death to come) | — |
| Countdown | 3 s, moving, weapons off | 5 s |
| Spawn with | Fists | A pistol; 3 s to respawn, at your team's spawns, away from enemies |
| Ammo | No reloads, no resupply (§7.2) | No reloads; resupply crates, faster pads, power pads return |
| Health | 100, no regeneration | 100, back after 5 s untouched |
| Friendly fire | — | Off |
| Colours | Everyone picks their own (§11.4) | Red and blue |

The flow: loading (the Match finds the new level and puts everyone in it: the local person in the level's own Player, everyone else in a new one), countdown (the round card's "go" lands on the moment weapons come on), live, round end (a result card), then the next round or the match end (the winner, the rounds) and back to the menu. The HUD follows along: the score (your side on the left), the round or game timer, a killfeed of every kill, and a real scoreboard on Tab.

**Practice bots** (`src/game/bot_brain.gd`) make both styles playable offline: free-for-all against three, teams four against four. A bot drives its Player through the same input commands a person does: to the nearest gun when empty-handed, then at the nearest enemy it can see, strafing and shooting with a reaction time and aim error, jumping what's in the way and refusing to walk into the void. They don't navigate (no navigation mesh yet), so on multi-level maps they can get stuck.

*Not built yet:* warmup, the map unloading (sudden death), spectating while dead, the barrier at spawn during the countdown, a rematch vote.

---

## 9. Maps

### 9.1 Design rules

1. **Structure before theme.** A map is its layout first: what fights it creates, how you get around it, and how getting around changes the fights. Theme and dressing come after, on a layout that already plays well.
2. **Size varies.** Maps range from short concentrated spaces (about 20 × 20 m, first contact in two seconds) through large winding ones (about 60 × 40 m) to spread-out maps (about 200 × 200 m) for more players and longer rounds. Every map has at least two height layers, and the rotation should mix sizes.
3. **Built for lines.** Every map has at least one continuous "flow loop": a route you can run at speed using slides, wall rides, and hops without breaking momentum.
4. **Weapon routes.** Weapon pads sit on the flow loop. Every spawn has a Standard pad within about 1.5 s of travel, so the fists-only opening is a short race, not a brawl. Heavy pads are contested in the middle. The Power pad needs movement tech, or a long exposed route, to reach.
5. **No dead ends.** Every area has at least two exits, one of them vertical.
6. **Sightlines fit the map.** On small maps the longest open sightline is about 40 m, with cover breaks. Big maps have long ones on purpose, so the sniper has a job, but every long line has cover along it and a way under or around it.
7. **Up is a choice.** Down is always quick (drop, slide, smash). Each way up trades speed against exposure: a slow readable ramp, a quick climb in the open, a hidden skill route (wall jumps, a fin to ride, stepping stones).
8. **Readable surfaces.** Wall-rideable surfaces share one consistent visual language across all maps (for example, a distinct tile or panel pattern). Players should never guess.
9. **Fair, not always symmetrical.** Mirrored or rotated layouts are the easy way to be fair, not the only one. An asymmetric map is fair when every spawn is about as far from the power weapon as the others (measured, see §9.3) and each side has its own advantages.
10. **Void edges.** Spread-out maps can float in the void: falling off is death. Edges are clear and bridges are wide enough to fight on.
11. **Unloading-ready.** Each map defines its collapse rings for sudden death ([§8.3](#83-round)).
12. **Cheap to build.** Rotation needs many maps, so each should be buildable from a shared modular kit plus a few signature props.

### 9.2 Map concepts

| Map | Concept | Movement feature |
|---|---|---|
| **Waiting Room** | An endless beige waiting room. Floating plastic chairs, a monolithic water cooler, a TV showing a looping weather channel. | Chair "stepping stones", long carpeted slide lanes |
| **Food Court Eclipse** | An empty mall food court under a black sun. Dry fountains, escalators, neon signs for restaurants that never existed. | Escalators as slide ramps, fountain bowls as half-pipes |
| **Aquarium Server** | Server racks on a sea floor. Caustic light, drifting bubbles, a whale made of cables. | Tall rack corridors for wall ride chains |
| **Birthday.exe** | A giant low-poly birthday cake floating in a cloud skybox. Party hats the size of houses. | Cake tiers as layers, candles as grapple anchors |
| **Hotel Pool Nocturne** | An indoor hotel pool at 3 a.m. Tiled slides, chlorine glow, too many doors. | Empty pool as a slope bowl, tiled water slides |
| **Desktop** | A giant CRT desktop. Icons as platforms, a start menu that folds out as stairs. | Window edges to wall-ride, icon hopping |
| **Parking Structure Dream** | A spiral parking garage that never reaches the top, lit by sodium lamps. | Continuous ramp for slope slides |
| **Bedroom at 4 a.m.** | A child's bedroom at giant scale. Glow-in-the-dark stars, a lava lamp tower. | Smashdown onto the bed to bounce high |

**MVP:** 8 greybox maps, 1 of them art-complete for the vertical slice. The long-term goal is a rotation of 20+ maps.

### 9.3 Built maps

Eight greybox maps so far, with no theme yet (rule 1): five for free-for-all and duels, three for teams. Each is a script in `tools/maps/` that lays it out from a shared kit (`tools/level_kit.gd`: blocks, ramps, terraces, floors with holes, pads, spawns); `tools/build_scenes.gd` saves them to `scenes/maps/`. **F9** in game steps to the next map. `tests/map_tests.gd` loads every map, stands a player at every spawn, checks every pad has room, and drives the routes each map is built around through the real movement code. None of them needs a new mechanic.

| Map | Size | Heights | Spawns | What it's about |
|---|---|---|---|---|
| **Stack** | 22 × 22 m | 0 to 8 m | 2 | Two floors in a box: a cellar and a roof, a shotgun at the bottom of the Well |
| **Terrace** | 48 × 36 m | 0 to 6 m | 2 | Asymmetric: a close-range town against an open high terrace, the sniper on a pulpit between them |
| **Switchback** | 64 × 40 m | 0 to 13.5 m | 2 | Four levels down a hill, joined end to end by hairpin ramps; high ground over everything below |
| **Archipelago** | about 190 × 200 m | −6 to 35 m | 4 | Islands in the void round a spire; long exposed crossings, a different skill for each ring link |
| **Rift** | 200 × 88 m | 0 to 37 m | 4 | A canyon: rims, shelves and floor, three layers and three kinds of fight |
| **Boulevard** (teams) | 144 × 72 m | −3.5 to 13 m | 4 a team | Three lanes through a town: a building, a street, a canal; rooftops over them |
| **Holdfast** (teams) | 224 × 112 m | −3 to 17 m | 4 a team | Two forts across an open valley, high ground layered over the field |
| **Depot** (teams) | 168 × 104 m | 0 to 11 m | 4 a team | A rail yard between two warehouses: boxcar lanes below, crossings 7 to 10 m up |

**Stack** (small). Below, a dim cellar under a 4.5 m ceiling with four pillars; above, the open roof. Down is always one step away (four holes, two ramp slots); up is slow and readable: the ramps, or a crate under a hole. The shotgun sits at the bottom of the Well, the hole in the middle, so taking it puts you under anyone on the roof: they can stomp you through it (a 5 m smashdown) and bounce straight back out. Rifles on two pulpits on the roof. Rotationally symmetric.

**Terrace** (medium, asymmetric). West, the Town: dense blocks, short sightlines, the SMG, shotgun and revolver. East, the Terrace, an open plateau 4 m up with the rifle. The Peninsula sticks out of the terrace into the town with the sniper on its Pulpit, seeing down the town's long street and across the terrace, and shot at from both. Ways between, from fast and open to slow and hidden: the Slide (20°, the fast way into town), the Overpass (a bridge onto Block A's roof), the Stairs, crates up the peninsula, and the Alley (a 2.5 m gap to wall-jump up).

**Switchback** (large, winding). Each level's edge is a 4 m drop onto the next, so everyone above looks down on everyone below. Down is easy: drop, slide a hairpin, or smash onto someone and bounce back up (a 4 m smashdown bounces about 3.6 m, enough to grab the edge you came from). Up is the question: the hairpins (long, but you keep your speed), the Ladder (a crate against each cliff up the middle, quick and in the open), or a hut roof. The sniper waits on the Overlook at the top.

**Archipelago** (spread out). The Hub (8 m) holds the Spire, 34 m tall, with the sniper nest on top, seeing every island; the only way up is a ramp spiral round its faces, in full view of everyone. Round it: the Keep (north, a building of rooms and doors, the SMG and a shotgun, a hole in the roof to drop in by), the Terraces (south, three wide steps facing the spire, the rifle), the Ridge (east, a long high island with the second sniper and cover along its edge), the Garden (west, low, a grid of pillars, the other shotgun), and four small outposts on the diagonals with a gun each. The Hub reaches each big island by a long exposed crossing (the Causeway, the South Bridge, the Garden Slide, the Ridge Ramp): the snipers' prey. Round the outside the islands join in a ring, each link a different skill: ramps; stepping stones, hopped down or jumped and grabbed up (3 m a stone on the Garden side); and the Fin, a floating ride wall across a 19 m gap too far to jump: angle in before you jump (air control can't steer you sideways), ride it, kick off toward the Terraces.

**Rift** (spread out). The Rims: the north at 28 m, the south at 20, with long sightlines down and across the canyon, a sniper tower on each (36 m and 28 m), and rifles. The Shelves: a solid ledge along each wall (12 m north, 10 m south), flanking paths between the floor and the rims, their faces rideable from the floor. The Floor: ruins, a colonnade under an overhang of the north rim, and the Arch, a block across the canyon with a tunnel through it and the shotgun inside. Getting between the layers: the end ramps (the whole floor rises at each end, to the south rim in the west and the north rim in the east: 28 m of 35° slope, the long slide down); a ramp from the floor up to each shelf and on up to its rim; the High Bridge (rim to rim) and the Mid Bridge (shelf to shelf), both crossings in the open; and the big drop: smash off a rim onto the floor (28 m) and the 22 m/s bounce throws you back up to grab the shelf.

**Team maps.** Built the traditional way for team play: each team has a base at one end where it spawns out of sight, lanes run between the bases, and the middle is contested. Both halves are the same, mirrored (Boulevard, Holdfast) or turned 180° (Depot, so the lanes cross diagonally); the map script lays out one half and `tools/level_side.gd` builds it for both teams, and a test checks every spawn, every pad and 400 points of ground against their twins. Each team gets four spawns, a pistol within 2 s of them, its own sniper perch, and the heavy guns in the middle.

**Boulevard.** Three lanes, each a different range. The Arcade (north): a two-storey building the length of the lane, rooms below joined by doors that zigzag so there's no line through, a long gallery above whose windows look down on the street; in the middle the Atrium, a double-height hall with the shotgun on its balcony and a skylight in its roof. Main Street (centre): long and open, parked cars for cover, the Plaza in the middle with the rifle on the fountain's plinth, a gate wall at each end so no one shoots into a yard from across the map. The Canal (south): a sunken channel 3.5 m deep with rideable walls, the revolver under the middle bridge, a slide down into it from each yard; beside it a row of kiosks whose flat roofs make a middle layer, and a walkway along the far bank. Over it all the rooftops: a ramp from each yard to the Arcade's roof and the Tower on it (the sniper, looking down the street), and the roof runs the length of the lane over the Atrium's skylight.

**Holdfast.** Two forts facing each other across a valley, 160 m apart, with the open field layered with high ground. Each fort: two floors, the SMG at the second floor's windows, a roof, and a corner tower 16 m up with the sniper. The Field: rocks, hedges, a bunker and an 8 m watchtower on each half, and the Hill in the middle, a tunnel through it (the shotgun), a first tier at 5 m and the Crown at 9 m (the rifle). The Ledge (8 m) along the north cliff: a ramp up from each half of the field, a bridge from it onto each fort's roof (the flank that comes out on top of the enemy), and the Lookout in its middle, from which the Sky Bridge runs over the field onto the Crown. The River (−3 m) along the south: out of the field's sight, ramps up into each fort's yard, and the Bluff (5 m) over it with a ruined wall along it.

**Depot.** A rail yard between two warehouses in opposite corners. Each team spawns in its warehouse's back room; a mezzanine along the front (the SMG) looks out over the yard; a ramp from the loading yard climbs to the roof, and skylights drop you back in. The yard: four tracks of parked boxcars make long lanes, some stacked two high, crates beside others to climb onto their roofs, and one open car each side you can run through (the shotgun). Above the lanes, a second yard: the Gantry, a crane bridge 9 m up across the middle (a ramp up at each team's corner, a stair of containers from the lanes, the rifle on the trolley in its centre), and on each side a Footbridge 7 m up across all four tracks, joined to the Signal tower (10 m, the sniper). Smash off any of them onto the cars.

**Measured routes.** Times from the test pilot, which runs, jumps obstacles and grabs ledges but doesn't slide, dash or wall-ride, so a good player is faster:

| Map | Route | Time |
|---|---|---|
| Stack | A → shotgun / rifle pulpit | 1.5 s / 2.0 s |
| Terrace | A / B → the sniper's pulpit | 3.9 s / 3.5 s |
| Switchback | A / B → the Overlook | 4.8 s / 5.3 s |
| Archipelago | Keep / Terraces / Ridge spawn → the Hub | 9.3 s / 11.0 s / 9.9 s |
| Archipelago | Keep / Terraces spawn → the Spire's nest | 19.4 s / 20.2 s |
| Archipelago | Ridge spawn → the Ridge sniper | 6.6 s |
| Rift | North / south rim spawn → its own tower | 11.1 s / 11.1 s |
| Rift | North / south rim spawn → the far tower (High Bridge) | 16.1 s / 16.4 s |
| Rift | Floor spawns → the rims (end ramps) | 8.0 s / 8.5 s |
| Rift | West floor spawn → the shotgun / the SMG | 2.4 s / 6.1 s |
| Boulevard | Spawn → first pistol / the Tower's sniper / the fountain's rifle | 0.9 s / 7.1 s / 8.6 s |
| Holdfast | Spawn → first pistol / the fort tower's sniper / the Crown's rifle | 1.4 s / 16.6 s / 17.6 s |
| Depot | Spawn → first pistol / the Gantry's rifle / the Signal tower's sniper | 2.0 s / 17.5 s / 18.8 s |

Every spawn's nearest pistol is under 0.6 s away on the small maps. On the spread-out maps the first fight comes later (the Hub is about 10 s from every spawn), and rounds run longer.

### 9.4 Movement sandbox
A dedicated training map with a speedometer, a ghost replay of your last run, movement challenges, a weapon range with every weapon, and target dummies that can move on rails (for heartshot practice). For a movement-first game this is a core feature, not a menu extra.

**In the prototype** the test course has it started: an armory of weapon pads (one per gun, back in 3 s) next to spawn, and a shooting range of dummies at 7, 12, 22 and 42 m, one up on a block, one walking and one jogging across. Dummies are the player's own body on a little stand: they take hits by zone (§5.2), show damage numbers and a health bar, fall apart like a player on a kill, pull themselves back together 2.5 s later, and heal after 2 s untouched. Code: `src/combat/target_dummy.gd`.

---

## 10. Game feel and flow

Flow is the promise of the game. These rules make it concrete.

### 10.1 No dead frames
- No landing recovery, no sprint-to-fire delay, no ADS transition, no pickup animation lock.
- Switching weapons takes 0.15 s and never slows you down.
- Every input is buffered for 120 ms: jump, dash, slide, smashdown, fire, pickup.

### 10.2 Chains
Any verb can flow into any other. The system is designed around chains like these:
- **Slide → hop → air strafe → wall ride → wall jump → dash → land in slide.**
- **Wall jump → smashdown → slam bounce → air strafe.** Height becomes more height.
- **Dash off a ledge → smashdown → slam slide.** Height becomes speed.
- **Slide over a pickup → fire before the slide ends → throw the empty gun → dash to the next pad.**
- **Smashdown knockup → shot at the airborne opponent → Heartshot.**
- **Rocket jump or shotgun jump → wall ride → mantle.**

### 10.3 Camera

| Setting | Default | Range |
|---|---|---|
| FOV (horizontal, 16:9) | 100° | 80–120° |
| Speed FOV kick | +8° at 16 m/s | 0–15° |
| Wall ride tilt | 6° | toggle |
| Camera motion | 100% | 0–100%. Scales every movement reaction below; 0 turns them off. |
| Camera smoothing | 0% (snappy) | 0–100%. How reactions move, not how big they are: see below. Also sets how the HUD and speed lines move. |
| View bob | Off | The camera never moves on its own. |
| Landing dip | Subtle, 40 ms | toggle |
| Screen shake | Low | 0–100% |

**The camera reacts to what you do, and only that.** Nothing sways on its own; every motion answers a movement:

| Movement | Camera |
|---|---|
| Strafing | Leans into sideways motion, up to 3°. |
| Sliding | Drops and kicks down at the start, tilts 4.5° into the slide, widens up to +10° with speed, rumbles faintly. |
| Jump / landing | A small tip up and lag on the jump; a pitch-down kick on landing that grows with impact speed, plus shake on hard landings. |
| Dash | FOV kick and a roll toward the dash direction. |
| Wall jump / mantle | Roll away from the wall; a pull-down as you mantle over. |
| Smashdown | Tightens and tips up during the hang, stretches +22° and rattles on the way down, then the impact slam (§4.4). |
| Slam bounce | Whooshes wide and tips up as you launch. |

**Fast and jerky by default.** Reactions snap in on the frame they happen and drop straight off (gone in about 0.2 s), shake is random jitter stepped at 30 Hz, the slide tilt and smashdown stretch arrive within a couple of frames, and the smashdown impact holds its slam for 50 ms before letting go. Only things that change gradually blend: the speed FOV eases with your speed, and the HUD lags your mouse a touch. **Camera smoothing** blends toward the old feel: kicks swell in and settle with a little overshoot, shake wobbles, everything eases, and the HUD, pop-ups and speed lines soften to match (speed lines stream instead of flickering). They only move the view; aim still follows your mouse.

The camera is **never** driven by the fixed tick directly. Mouse look is applied every rendered frame; position is interpolated between ticks.

### 10.4 Feedback
- **Hits:** hitmarker plus a distinct sound. Headshots and heartshots each get their own sound and marker. Kill confirm gets a short, sharp accent.
- **Damage numbers:** one number per target, never a spray of them. Every hit that lands while it's up (a burst, a string of shots, a shotgun's pellets, anything on a far-off target) adds to it: it rolls up to the new total, pops, and grows with the damage (a little bigger each time the total doubles, capped). It follows the target and fades 0.8 s after the last hit; the next hit after that starts a new one. White for the body, yellow once a hit lands on the head, pink with a ♥ for a heartshot. Code: `src/combat/damage_number.gd`.
- **Being hit:** a directional damage indicator and a brief vignette. It must never obscure aim.
- **Viewmodel:** procedural sway that reacts to velocity, slides, wall rides, smashdowns, and landing, so the gun "breathes" with your movement.
- **Speed:** the HUD speed meter (§13.3). Speed lines: thin white streaks at the screen edges pointing out from where you are heading, pixel-chunky like the 3D, redrawn at random 24 times a second like hand-drawn anime lines (they stream smoothly with camera smoothing up). They start just above run speed, reach full strength around 22 m/s (vertical speed counts, so a smashdown's descent streams them), and burst on dashes and slam bounces. The middle stays clear. Toggle: *speed lines*. Later: wind audio. Code: `src/render/speed_lines.gd(shader)`.
- **No hitstop** (online multiplayer can't pause time). Weight comes from sound and camera micro-kicks instead.
- **Impact frames (experimental, off by default):** on a kill you make and on a hard smashdown (8 m or more), the screen is redrawn for a beat or two as stark two-tone ink with outlines and speed lines bursting from the hit, like a held anime frame. Heartshot kills use heart pink instead of white. Each held beat jolts off-centre. The camera takes the hit too: it snaps into a zoom with a roll, a pitch kick and a shove back, is still punched in when the picture returns, then swings out past rest into a recoil and settles in about half a second. The HUD rides the same punch (§13.5). The punch only moves the view, never your aim, and scales with *screen shake* (0 turns it off). Visual only (the game runs on underneath), at most one every 0.5 s. They stay off by default for two reasons. They are high-contrast full-screen flashes. And on a smashdown they blank the screen for about 0.1 s at the exact moment of the smashdown → knockup → heartshot follow-up (§4.4). Your own death and the crumble never fire one. Setting: *impact frames* (View → Experimental). Code: `src/render/impact_frames.gd(shader)`.

### 10.5 Death

Dying is slightly over the top and silly on purpose. The body turns out to have been diced all along.

**What everyone sees:** the body takes the hit, freezes, hairline cuts open up across it, and it crumbles into a heap of chunks (about 90–100 pieces, pre-cut along a randomly rotated grid, with flat pale cut faces). The heart pops out and bounces.

**What the dead player sees** (about 5 s):

| Beat | Time | What happens |
|---|---|---|
| Blackout | 0.15 s | The screen cuts to black. The world goes dark: sky, ambient light, lamps, fog, and fake reflections all off. |
| Spotlight | about 1 s | The camera now faces you from the front. A spotlight clunks on beside you with a stagey flicker, then swings over and settles on you with an overshoot. |
| Performance | about 1.2 s | You do a little dance, freeze mid-move, and shiver. |
| Crumble | about 1.8 s | Cuts open, you crumble, the heart pops out toward the camera, and the camera tilts down to the heap. |
| Caption | 1.8 s | A logo-style boxed caption: *you fell apart*. Then fade out. |

Every timing lives as a constant in `src/player/death_sequence.gd` and `src/player/player_model.gd`. Later: a skip button, audio stings, and the killer's name and weapon in the caption.

### 10.6 Accessibility
- Sensitivity shown in cm/360 as well as a raw value. Raw input is always on.
- Every camera motion effect can be toggled off, and UI motion can be turned down to nothing (§13.5).
- No full-screen flashing by default. The experimental impact frames (§10.4) are opt-in and never fire more than twice a second.
- Colorblind-safe enemy highlight and heart color presets.
- Hold/toggle options for crouch. Smashdown can have its own key.
- Full key rebinding.

---

## 11. Art direction

### 11.1 Target
**Surreal, early-2000s realtime 3D, rendered crunchy.** The look of PS2, Dreamcast, and early-2000s PC games, pushed toward ULTRAKILL: chunky pixel textures, a low internal resolution with hard pixels, glossy surfaces, and lighting that is flat and harsh on purpose. It builds dream spaces: mundane places (waiting rooms, malls, hotel pools, bedrooms) made uncanny through scale, emptiness, repetition, and wrong details.

### 11.2 Visual rules

| Element | Direction |
|---|---|
| Geometry | Low-poly. Characters 1.5–3k triangles, weapons 500–1.5k, props a few hundred. Faceted silhouettes are welcome. |
| Resolution | 3D renders at a low internal resolution (360 lines by default, adjustable, or native) and is upscaled with hard pixels. The HUD stays sharp. |
| Textures | Low resolution (64–128 px), point-filtered (no smoothing), with mipmaps to limit shimmer. Hand-pixel style: bevels, grout, rivets, grime. Visible texel density is part of the look. |
| Lighting | Deliberately "bad": flat colored ambient, hard low-res shadows, harsh unshadowed colored point lights, no GI or bounce. Lightmaps plus vertex color later for final maps. |
| Materials | Glossy. Sharp specular highlights plus a fake sphere-map environment reflection ("chrome"/"wet plastic"), stronger at grazing angles. Emissive signs. These are signatures of the era. |
| Atmosphere | Heavy distance fog in dreamy colors, gradient skyboxes, lens flares, soft bloom. |
| Color | Pastels and beige for the world, saturated emissive for gameplay-relevant elements. |
| Post-processing | Bloom. Colors are **not** altered by post-processing by default; an optional 16-bit color and dither mode exists as a setting. **No motion blur** (it fights readability and flow). |
| Surreal devices | Impossible scale (giant mundane objects), liminal emptiness, repeating architecture, floating props, looping TVs, skies that aren't skies. |

### 11.3 Readability rules (Pillar 4)
- **Players:** glossy, featureless figures with a strong rim light and emissive player color. They must separate from any background at any distance.
- **The heart:** glows on the chest, in the player's color. It is never hidden by cosmetics.
- **Teams:** told apart by the hat. Every hat's main mass is the team colour (red or blue), and a player with no hat has a team-coloured triangle over the head instead (§11.4).
- **Weapons in hand:** chunky silhouettes, identifiable at 30 m.
- **Weapon pickups:** float and rotate above glowing pads, arena-shooter style. Pad color shows the tier (Standard, Heavy, Power). Respawn timers are shown on the pad.
- **Projectiles:** bright emissive cores with short trails. Enemy projectiles use the enemy's color.
- **Gameplay surfaces:** wall-rideable surfaces, hazards, and unloading zones each have one consistent visual language across all maps.
- **Fog** never hides a player inside the maximum sightline.

### 11.4 Characters
- Base figure: a blank, glossy white blob of a person, in the spirit of Meccha Chameleon's figures. One seamless smooth shape with **no visible joints**: a big ball head on a short neck, one flat slab of a torso, long tube arms with no hands, and short stubby legs (crotch at about a third of the height) with no feet. A glowing heart sits on the chest. Uncanny but friendly.
- The body is one skinned mesh generated from a smooth signed-distance shape (`src/player/body_shape.gd`, `tools/gen_body.gd`), so proportions are tuned in code, not in a modeling tool.
- It must never read as lumpy. Nothing is glued on: the legs are the bottom of the torso slab split by a slit, each arm is one tapered tube, and every join is a wide C2 blend. The mesh is built in an A-pose (arms 45° down, where they spend most of their time), so skinning never bends a shoulder far.
- Animation comes from Quaternius's Universal Animation Library (CC0). Its human rig is reshaped at load time to the body's proportions (shorter legs, longer spine, A-pose rest), and the hips motion is scaled to match.
- **Hats** are the first cosmetic, and they carry the wearer's colour: the team's in teams, and in free-for-all a colour each player picks from ten (red, orange, yellow, lime, green, teal, sky, blue, violet, pink). Sixteen, built like the guns from glossy primitives listed as data (`src/cosmetics/hats.gd`): top hat, cap, beanie, cowboy hat, bowler, party hat, crown, fez, propeller cap, chef hat, viking helmet, hard hat, bucket hat, mortarboard, wizard hat, halo. Each one's main mass is the wearer's team colour (red or blue) with trim in black, white, gold or metal, so one glance at the head says whose side someone is on. **No hat** is a choice too: a team-coloured triangle, pointing down at the head with a dark outline, hovers over the head and turns to face whoever looks. The hat rides the head bone, flies off when the body falls apart, and is back on respawn. You pick yours on the title screen, and that is the hat you wear in every match until you change it (it's saved, `src/cosmetics/cosmetics.gd`). Your team comes from the match, not the menu. Practice dummies play for blue, each in a different hat.
- **Names** float over everyone's head but your own, in their colour, small and the same size at any distance, gone past 70 m and while the body is in pieces. A teammate's shows through walls; anyone else's only while you can see their head. You type yours on the title screen (up to 16 characters, cleaned of anything unprintable), next to the hat and colour pickers.
- Cosmetics (post-MVP): more hats, surface materials (chrome, marble, carpet, TV static), heart styles, weapon skins. Cosmetics can never change hitboxes or hide the heart, and hats are never hit shapes.
- **Layered animation** (`src/player/body_layers.gd`): on top of the locomotion clip, clips can be laid over some bones (the arms aim while the legs run), played once over some bones (a hit, a punch), arms reach for targets by two-bone IK, and bones can be knocked on springs.

### 11.5 Weapons in hand

**First person.** Your own arms: the body's mesh cut down to the arms, a little smaller, posed by the same rig and drawn over the world with a steady 62° field of view (it follows 30% of the camera's FOV swings), so it never clips into walls. Only the arms are drawn, so the shoulders sit wherever reads best: low and back, so the thick upper arms rise from below the screen, away from the eye. Past the cut, each arm carries on as the same tube, rebuilt every frame (first person only): straight on up the arm, bending down out of view only once it's off screen, so you never see where an arm ends.

| Action | Animation |
|---|---|
| Holding a gun | Both hands on it by IK: the right on the grip, the left on the foregrip or pump (one-handed guns leave the left arm down). |
| Firing | The gun kicks around the grip (pitch, a random twist, a shove back) on a snappy spring, its mechanism cycles, a muzzle flash, a light pops on the world, casings fly out to the right. |
| Pump / bolt | The left hand rides the pump; the right hand leaves the grip to work the bolt and comes back. |
| Fanning (Marshal .357 alt) | The left hand swipes over the hammer on every shot. |
| Drawing | The gun comes up from below, turned, and eases past its place. |
| Top-up | The left arm plays the rig's pistol reload: down to the belt, back up to slap the rounds in; the gun tilts. |
| Throwing | The throwing arm (the rig's cross punch) flings it. |
| Fists | Held up in a guard by IK, like hands on a gun. Hands alternate, and each punch is a straight (jab or cross, about half), a hook (swings out wide, elbow up, comes across) or an uppercut (dips and drives up), never the same hook or uppercut twice running. Every kind is fully out as the hit lands and only looks different; the rig's jab and cross clips turn the shoulders into it. |
| Scoped | The arms drop out of view; a scope with fine lines, the rest of the screen dimmed. |

Like the camera, it only moves in answer to you: looking drags it, strafing leans it, landing drops it, sliding tucks it in and rolls it over, dashes swing it, wall rides tilt it away from the wall, smashdowns brace it and slam it down.

**Third person.** Other players hold the same model, drawn 25% bigger so it reads across a map. Pistols use the rig's two-handed pistol aim, blended between its up, level and down poses with the view pitch; two-handed guns are shouldered, both hands on them by IK. Shots play the pistol-shoot clip over the arms. Fists hold the rig's guard and punch with its jab and cross clips; hooks add a torso turn and a raised elbow, uppercuts a hip dip and a rising chest (on the flinch springs).

Code: `src/player/viewmodel.gd`, `src/combat/weapon_model.gd`, `PlayerModel.hold()`.

---

## 12. Audio

### 12.1 Music
- Early-2000s electronic: breakbeat, trip-hop, chopped vocals, glossy synth pads, reverb-drenched lounge.
- Dynamic intensity: low layer during the countdown, full track once live, a filtered and warped layer during Unloading.
- Each map has a short signature loop. Rounds are short, so music carries across rounds and shifts key or layer with each map.

### 12.2 Sound effects
- **Clarity first.** Footsteps, slides, dashes, wall rides, smashdowns, pickups, and enemy fire are fully spatialized and audible, so you can track the opponent by ear.
- **Every weapon sounds unique**, and its sound is recognizable from across the map. You should know what your opponent just picked up from the sound alone.
- Movement sounds are satisfying on their own: slide scrape, dash whoosh, wall kick thud, smashdown whistle and impact, a landing sound that changes with impact speed.
- The Heartshot has the most distinctive sound in the game.
- The world's sound is surreal, too: distant muzak, HVAC hum, looping TV audio, all mixed below gameplay.

---

## 13. UI / UX

### 13.1 Style
The interface follows the logo: it looks **default and unfinished** on purpose, which plays against the glossy world.

| Element | Rule |
|---|---|
| Canvas | All UI is laid out on a small canvas (about 270 px tall) and scaled up with smooth filtering, so it is soft and blurry like the logo. |
| Type | Liberation Sans (Arial metrics), lowercase copy everywhere. Sizes on the canvas: 8 small, 10 normal, 16 big, 36 huge. |
| Boxes | Every piece of text sits on a white card like the logo's: a thin black frame set in from the card's edge, so white shows all round it, and black text. Drawn by hand, not ruled: each box's margins, corners and frame lines are a touch off, differently for every box, and the same every frame (`src/ui/paper_box.gd`). No drop shadows; only a hovered button lifts off one. |
| Emphasis | Inverted boxes (black inside the frame, white text, the white card still around it) for emphasis, hover, and the current value. Ghost boxes (translucent, grey) for secondary labels. |
| Color | Monochrome. The only accents: **heart pink** (heartshots, the heart) and **red** (low health, alerts). |
| Motion | Nothing just appears or vanishes: boxes spring, stamp, type, roll, and flick (§13.5). No slow fades. |
| Exceptions | The crosshair and hit markers are drawn at full resolution, sharp, because aiming needs to be exact. Developer tools (F1 tuning, debug readout) stay crisp too. |

Code: `src/ui/lofi_ui.gd` (style kit), `src/ui/lofi_layer.gd` (the low-res canvas).

### 13.2 Logo
- The wordmark is plain lowercase **xtrapartial** in Arial, rendered tiny, framed by a thin black box, then blown up blurry and slightly warped. Black on white.
- It deliberately looks default and unfinished, which plays against the glossy world.
- Files: `assets/ui/logo.png` (also the boot splash) and `assets/ui/logo_small.png` (the tiny original, for upscaling live in menus). `tools/gen_logo.gd` regenerates both.

### 13.3 HUD

| Position | Contents |
|---|---|
| Top centre | Your score · round timer (inverted) · their score. Map name in a ghost box below. Alerts (e.g. *the map is unloading*) in red below that. |
| Top right | Killfeed: `killer [weapon] victim`, newest on top, five at most, five seconds each. A heartshot kill shows a pink ♥ instead of the weapon. |
| Centre | The sharp crosshair. Hit markers: white (hit), yellow (head), red (kill), big pink (heartshot). Around it, a ring of the gun's rounds (below). |
| Above the crosshair | Pop-ups: *heartshot* (pink), later *double kill* etc. |
| Below the crosshair | Pickup prompt: `e  swap for rl-5 (5)`. Never covers the crosshair. Auto-pickups only flash the name. |
| Bottom left | `hp` + health. Turns red and shakes at 30 or below. |
| Bottom centre | Speed meter: a row of cells that get taller left to right (volume-meter style), lit black up to your speed, a grey cell marking the recent peak, jittering past the soft cap. Your speed in a box to its left, inverted above run speed. Dash charges underneath as small boxes: black when ready, filling grey while recharging; a used charge flashes, a recharged one pops. |
| Bottom right | Throwable (ghost box) above the weapon name and the ammo column (below). `fists` when empty-handed, with no column. |

The HUD hides during your death sequence and springs back in on respawn. Code: `src/ui/game_hud.gd`, `src/ui/crosshair.gd`.

**Ammo is shown, not counted.** Map weapons never reload (§7.2), so what matters is how much the gun holds and how much is left:

- **The column** (`src/ui/ammo_meter.gd`) stands next to the weapon name. Its height is set by the gun's capacity (9 px × √rounds on the 270 px canvas: 22 px for the Marshal .357's 6, 64 px for the SX-50's 50), so a glance tells you what you're carrying. Guns that hold a dozen or fewer are cut into one cell per round; bigger ones get a notch every ten. It fills black from the bottom; a small tag rides the top of the fill with the exact count. Each shot pops its cell off the top; a new gun grows its column in; a top-up rolls the fill back up. At a quarter or less it turns red, empty it blinks.
- **The ring** around the crosshair says the same where you're looking: one arc per round for small guns, one notched arc for big ones, spent rounds dimming from the end, the one just fired flicking outward. Red when low, blinking when empty, a red blink on a dry click.
- **The cycle arc**, a thin arc inside the ring, fills while a slow gun (0.45 s or more between shots) gets its next round ready.

### 13.4 Overlays and screens

| Screen | Status | Description |
|---|---|---|
| Main menu | Built | Your blob idles (and sometimes dances) under a spotlight on a dark stage. Logo top left, boxed menu below (*play*, *settings (soon)*, *quit*), version in a ghost box. The blob wears your hat, in red or blue at random. A small ghost-box hat picker sits in the bottom-right corner, `<` *hat: name* `>` (or ← →): each step drops the next hat onto the blob, which nods under it. The pick is saved and is the hat you wear in a match. |
| Pause (Esc) | Built | Dim + boxed list: *resume*, *respawn*, *tuning*, *main menu*, *quit*. The game keeps running underneath (it's multiplayer). |
| Map card + countdown | Built (preview) | *round 3* over the map name, a fake loading bar of boxes, then *3 · 2 · 1 · go*. |
| Round result | Built (preview) | Huge *round won* (inverted) or *round lost* banner over the score. |
| Scoreboard (hold Tab) | Built (preview) | One boxed table: rounds, kills, ♥ heartshots, ping. |
| Match end | Built (preview) | *you won* / *you lost*, final score, and a list of every round: map, winner, and how. |
| Death | Built | See §10.5. Caption in the same boxed style. |
| Settings | Planned | Video (pixel height, FOV), mouse, audio, key binds. |
| Lobby | Planned (M3) | Invite / join code, ready-up. |

"Preview" screens run on made-up data (press **F8** in the test course to cycle them) until rounds exist in M3. Code: `src/ui/overlays.gd`, `src/ui/pause_menu.gd`, `src/ui/main_menu.gd`, wired together by `src/ui/game_ui.gd`.

### 13.5 Motion
The boxes are plain, so the motion carries the energy. The UI should feel as alive as the movement: it reacts to what you do and never just blinks things on and off.

| Where | What moves |
|---|---|
| Everywhere | The canvas warps very faintly and slowly, like the warped logo. **Kicks** shake, punch (zoom), and warp the whole UI for a moment on big events: heartshots, smashdown impacts, damage, the countdown, *go*. |
| HUD | Hangs off the view on a spring: lags behind mouse look, leans into strafes, rises while falling. Movement knocks it around: jumps bump it up, landings (scaled by impact) and smashdowns slam it down, dashes and wall jumps shove it sideways. It springs into place at spawn. |
| Crosshair | The ticks spread briefly on jumps, landings, dashes, and smashdowns and close again within ~0.15 s. The centre never moves, so aim is never affected. |
| Numbers | Roll to new values (health, ammo, scores). A score that goes up flashes inverted and pops. The round timer pops every second for the last 10 and turns red for the last 5. |
| Health | Damage shakes the row, pops the number, and kicks the UI. At 30 or below the red box beats like a heart. |
| Killfeed | Rows slide in from the right with an overshoot (a heartshot's ♥ pops) and slide back out when they expire. |
| Pop-ups | One letter tile per character, each slamming down from big and crooked in quick succession, then a kick. A heartshot gets a black ♥ tile in front and beats twice like a heart. They drift up while they hold, then shatter: every tile tumbles off in its own direction. |
| Impact frames | When one fires (§10.4) the HUD takes the hit with the camera: it punches in on the camera's spring and recoils past rest, every group rattles loose and wobbles back, and the crosshair blows wide open. |
| Alerts | Stamp in, then blink red/black. |
| Map card | The map name types itself into a box that flips open; the load cells pop as they fill. Countdown numbers stamp down, *go* bursts. |
| Banners | *round won*, *you won* land one letter tile at a time, then kick; the winner's score rolls up. |
| Menus | Buttons slide in one after another, invert and lift off a shadow on hover, press in on click. The pause menu snaps open (fast dim, stamped title). |
| Main menu | The logo stamps down, then wobbles gently. The blob reacts to what you hover (a jab for *play*, a flinch for *quit*) and the spotlight pumps. The camera leans toward the mouse. A news ticker crawls along the bottom. |
| Scene changes | A wipe: black boxes pop in across the screen in a diagonal sweep, the scene changes behind them, and they clear the same way. |

**Accessibility:** *ui motion* (0–1, `ViewSettings.ui_motion`) scales all of the self-motion: sway, lean, kicks, shakes, wobble, and crosshair spread. At 0 the UI holds still; things still arrive and leave, but nothing shakes.

Code: the motion kit is in `src/ui/lofi_ui.gd` (`enter`, `leave`, `pop`, `stamp`, `burst`, `type_in`, `roll`, `flash`, `blink`, `pulse`, `tiles_in`, `kick`), the warp and kick in `src/ui/lofi_layer.gd(shader)`, and the wipe in `src/ui/wipe.gd`.

---

## 14. Modes

| Mode | Phase | Notes |
|---|---|---|
| 1v1 online (private lobby) | MVP | Invite or join code |
| Free-for-all (classic) | Built, offline vs bots | Short rounds, see §8.5 |
| Teams | Built, offline vs bots | One long game, see §8.5 |
| Movement sandbox | MVP | See [§9.4](#94-movement-sandbox) |
| Custom rules | MVP (basic) | Rounds to win, weapon pool filters ("precision only", "melee only", "random roulette"), Heartshot on/off, round timer |
| 2v2 | Post-MVP | Team maps built (§9.3) |
| FFA (3–4) | Post-MVP | |
| Ranked 1v1 | Post-MVP | Needs dedicated servers |
| Time trials | Post-MVP | Movement courses, ghosts, leaderboards |

---

## 15. Technical design

### 15.1 Engine

**Decided: Godot 4.7 (standard build, not .NET), GDScript with static typing everywhere.** GDScript needs no .NET toolchain, so anyone can open the project with a single download, and iteration is fastest. If profiling ever shows a hot path (for example, prediction replays), that piece moves to a C++ GDExtension. Physics uses Jolt, which ships inside Godot.

Alternatives considered:

| Option | For | Against |
|---|---|---|
| **Godot 4** (recommended) | Lightweight and fast to iterate. Custom shaders for the retro look are easy. Open source, no licensing risk. Small scenes load fast, which suits rotating maps every round. | The high-level multiplayer API is basic, so prediction and lag compensation are ours to build. (We need custom movement prediction in any engine anyway.) |
| Unity | Mature ecosystem, several netcode libraries with prediction (Fish-Net, Photon Fusion) | Heavier. A history of licensing changes. |
| Unreal 5 | Best built-in networking and prediction | Heavy. Fights the low-fi pipeline. Custom movement in CharacterMovementComponent is painful. Slow iteration. |

Movement is a custom kinematic controller on top of `CharacterBody3D`, with our own prediction and reconciliation layer.

### 15.2 Simulation and netcode

| Topic | Plan |
|---|---|
| Authority | Server-authoritative. MVP uses a listen server (host) over a relay (such as Steam Networking Sockets). The server code stays headless-capable for future dedicated servers. |
| Tick rate | 60 Hz fixed simulation and send rate (configurable to 120 Hz) |
| Local player | Client-side prediction of movement, firing, pickups, and throws, with server reconciliation (rewind and replay unacknowledged inputs) |
| Remote players | Interpolated about 2 ticks behind, with extrapolation capped at 100 ms on packet loss |
| Hitscan hits | Server-side lag compensation: rewind hitboxes to what the shooter saw, capped at 150 ms |
| Projectile hits | The server spawns the authoritative projectile fast-forwarded by the shooter's latency (capped at 100 ms) and tests that segment against rewound hitboxes. After that, the projectile simulates in present time. The client shows its own predicted projectile immediately. |
| Hitboxes | Body, head, and heart are attached to the simulated capsule and pose state, not to client-side animation. This keeps the tiny heart consistent between server and clients. |
| Pickups | Predicted on the client, confirmed by the server. If both players grab the same weapon on the same tick, the earlier input timestamp wins and the loser's prediction rolls back cleanly. |
| Input | Commands carry full-precision view angles and buttons. Input is sampled every rendered frame and aggregated per tick. |
| Validation | The server checks movement against the sim (speed and teleport checks), fire rates, and ammo |
| Test matrix | 0 / 50 / 100 / 150 ms RTT, with ±20 ms jitter and 0–3% packet loss, from M3 onward |

### 15.3 Performance targets

| Target | Value |
|---|---|
| Frame rate | 144+ fps at 1080p on a GTX 1060 / RX 580-class GPU; 240+ fps on high-end |
| Frame pacing | No spikes over 2 ms above the average frame time during a round |
| Input latency | Mouse look applied on the rendered frame. No input smoothing. Support for the vendor low-latency modes where available. |
| Allocations | No per-frame garbage in gameplay. Projectiles, VFX, decals, and dropped weapons are pooled. |
| Map transitions | Next map preloaded during the current round. Swap in 1 s or less. |

### 15.4 Architecture outline

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation (client only)                                  │
│  camera · viewmodel · VFX · audio · HUD · menus             │
├─────────────────────────────────────────────────────────────┤
│ Simulation (shared client/server, fixed tick, pure logic)   │
│  movement · smashdown · weapons · projectiles · pickups ·   │
│  throws · health/damage zones · heartshot                   │
├─────────────────────────────────────────────────────────────┤
│ Match layer (server-authoritative)                          │
│  match state machine · round phases · map rotation ·        │
│  pad rolling/respawn · unloading                            │
├─────────────────────────────────────────────────────────────┤
│ Net layer                                                   │
│  transport · input commands · snapshots · prediction ·      │
│  reconciliation · interpolation · lag compensation          │
├─────────────────────────────────────────────────────────────┤
│ Data                                                        │
│  weapon definitions · tuning tables · map metadata          │
└─────────────────────────────────────────────────────────────┘
```

- **Simulation never reads presentation state.** Presentation only reads sim state and events.
- **All tuning values live in data files** and can be hot-reloaded in dev builds.
- **Weapons are data.** A definition file declares the fire mode, damage, zone multipliers, heartshot eligibility, ammo, alt-fire, and projectile behaviors (bounce, stick, split, pierce, explode, knockback). New weapons should rarely need new code. In the prototype that's `WeaponDef` (`src/combat/weapon_def.gd`): stats, feel (recoil, cycle), and the model as a list of parts with its moving parts tagged.
- **Maps carry metadata:** weapon pads (tier and pool), mirror pairs, spawn points, flow-loop markup, and collapse rings.

### 15.5 Telemetry (playtests)
Round length, match length, heartshot share of kills (target 3–8%), kill share and pickup rate per weapon, time to first pickup, fist kill share, smashdown usage and hit rate, speed distribution, kill distance, movement verb usage.

---

## 16. Scope and milestones

Each milestone has a **gate question**. We don't move on until the answer is yes.

| # | Milestone | Contents | Gate question |
|---|---|---|---|
| M0 | Pre-production | Engine decision (done: Godot 4.7), repo setup, coding conventions, greybox kit | Can we greybox a map in an afternoon? |
| M1 | **Movement prototype** (offline) | Full base movement kit including smashdown, live tweak panel, speedometer, one greybox test course | Is running around alone fun for 10 minutes? |
| M2 | Combat prototype (offline) | Fists plus 4 pickups (SP-12, Marshal .357, Warden 12, RL-5), pickup and throw, damage zones and heartshot, moving target dummies, hit feedback | Does shooting while moving feel fluid? Does a heartshot feel earned? |
| M3 | Networked 1v1 | Prediction, reconciliation, interpolation, lag compensation, round loop with map rotation on 3 greybox maps, sudden death | Does a 100 ms match feel as good as LAN? Do heartshots register as seen? |
| M4 | Weapons and maps | Data-driven weapon system, 12 weapons plus throwables, pad rolling and respawn, 6 greybox maps | Do rounds feel different from each other? |
| M5 | Vertical slice | ~20 weapons, 8 maps (1 art-complete in the target style), audio pass, core menus, movement sandbox | Would a stranger play a second match? |
| M6 | Alpha | Closed playtests, telemetry, balance passes, more map art | — |

**MVP = M5 vertical slice:** 1v1 online, 8 maps (1 fully arted), about 20 weapons plus 2 throwables, movement sandbox, basic custom rules.

---

## 17. Open questions

| # | Question | Default assumption in this draft |
|---|---|---|
| 1 | ~~Engine~~ | **Decided:** Godot 4.7, GDScript |
| 2 | ~~Spawn loadout~~ | **Decided:** fists only |
| 3 | Heartshot: which weapons are eligible, and how big is the heart? | Precision weapons only, 0.07 m radius |
| 4 | Keep headshots (×1.5) alongside the heart, or remove them so the heart is the only precision target? | Keep both |
| 5 | Carry one primary or two? | One |
| 6 | Weapon pads: roll from curated pools each round, or a fixed layout per map? | Rolled, with mirrored pads matching |
| 7 | Do Standard pads respawn within a round? | Yes, after 20 s. Heavy and Power never. |
| 8 | Smashdown input: context-sensitive crouch in the air, or a dedicated key by default? | Context-sensitive, with an optional dedicated key |
| 9 | Should air strafing gain speed at all, or only steer? (Skill ceiling vs. accessibility) | Gain, soft-capped at 16 m/s |
| 10 | Do we want a defensive verb (block or parry)? It was removed with the card draft. | No. The Slugger bat's deflect covers it. |
| 11 | Rounds to win | 7 |
| 12 | Networking: listen server via Steam relay for MVP, or dedicated servers from day one? | Listen server |
| 13 | Controller support: in the MVP, or post-MVP with aim assist tuning? | Post-MVP |
| 14 | Monetization model (premium, or premium plus cosmetics)? | Premium, TBD |
| 15 | Hit shapes follow the animated pose, which is exact locally. Online, do we sync a deterministic pose (the sim's movement state drives the upper body's aim, so the server can rebuild it), or fall back to capsules on the simulated body? | Rebuild the pose from sim state; keep the heart on the chest bone |
| 16 | Teams are shown by hat colour (red / blue). In 3–4 player FFA, does each player get their own hat colour, or do enemies all show one "enemy" colour? | One colour per player, from a fixed palette that stays readable |
