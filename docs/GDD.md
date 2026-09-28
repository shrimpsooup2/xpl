# xtrapartial — Game Design Document

| | |
|---|---|
| **Version** | 0.6 (draft) |
| **Date** | 2026-09-27 |
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
| Windup | 0.06 s hang, vertical velocity zeroed | A tiny readable commit |
| Descent | 40 m/s straight down | Horizontal speed is **banked**, not lost. No air control during descent. |
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
| Slam bounce | Jump within 0.2 s of impact | Vertical velocity = min(7 + 0.5 × drop height, 16) m/s. Banked horizontal speed restored. |
| Slam slide | Hold crouch through impact | Slide at banked speed + 4 m/s. Ignores the normal slide boost cooldown. |
| Plain landing | Neither | Banked horizontal speed restored |

**Tells.** A rising whistle during the descent, a bright trail, and a ring projected on the ground where you will land, visible to both players. A smashdown is a commitment, and the opponent can read and punish it.

**Why the knockup matters.** A knocked-up opponent follows a predictable arc, which sets up an aimed follow-up shot. Smashdown → airborne opponent → Heartshot is the high-skill combo.

### 4.5 Movement rules

1. **Deterministic and pure.** Movement is a pure function of `(state, input, dt)`. That is needed for client prediction ([§15](#15-technical-design)).
2. **Fixed timestep.** Movement simulates at the fixed network tick. The camera and rendering interpolate between ticks.
3. **Momentum is never silently removed.** Only friction, drag above the soft cap, collisions, and explicit weapon effects (knockback, the Buffering slow field) reduce speed.
4. **Collision slides, not stops.** Glancing a wall or corner deflects velocity along the surface. Small ledges are stepped over or mantled.
5. **Every chain is legal.** Any verb can follow any other verb. There is no "recovery" state.
6. **Skill ceiling, skill floor.** Buffers and coyote windows make basic chaining easy. Air strafing, slope slides, and slam bounces give experts more.

---

## 5. Combat

### 5.1 Health and damage

| Property | Value |
|---|---|
| Max health | 100 |
| Regeneration | None. Rounds are too short to need it. |
| Armor / health pickups | None in MVP. Weapons are the only pickups. |

### 5.2 Damage zones

| Zone | Size | Effect |
|---|---|---|
| Body | Capsule | Base damage |
| Head | Sphere, 0.13 m radius | ×1.5 by default (set per weapon) |
| **Heart** | Sphere, 0.07 m radius, inside the chest | **Instant kill** with eligible weapons. See [§6](#6-heartshot). |

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
| Top-up | Moving over the same weapon type you hold adds its ammo to yours |
| Ready time | 0.15 s after a pickup or a switch |

### 7.2 Ammo and throwing

- **Map weapons have no reserve ammo and don't reload.** What's in the gun is what you get. When it runs dry, throw it and find the next one. This keeps players moving around the map.
- **Throw (Q):** throws your primary at any ammo count. A thrown weapon deals 25 damage and 6 m/s knockback on hit, then lands and can be picked up again with whatever ammo it has left.
- **Switching after a throw:** throwing switches to fists instantly.
- **When empty:** you switch to fists automatically after 0.2 s, unless you throw first.
- **Empty weapons** dissolve 3 s after landing.
- No weapon reloads.

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

Names are placeholders, but they follow one theme: **early-2000s computing jargon.** ♥ = can heartshot.

**Precision**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| Pointer | Standard | 20 | 0.3 s | 12 | Projectile 150 m/s | ♥ | Common pistol, found near spawns |
| Hotkey | Standard | 45 | 0.5 s | 6 | Projectile 250 m/s | ♥ | Alt: fan the hammer (remaining rounds at 0.1 s, +3° spread, no ♥) |
| Magnifier | Standard | 40 | 0.35 s | 10 | Hitscan | ♥ | Alt: 1.5× zoom |
| Stylus | Standard | 70 | 0.9 s | 5 | Bolt 90 m/s, with drop | ♥ | Crossbow. Bolts stick in walls. |
| Ping | Heavy | 85 (head kills) | 1.2 s | 4 | Hitscan | ♥ | Sniper. Alt: 3× zoom. |

**Automatic**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| Popup | Standard | 11 | 0.07 s | 60 | Projectile 180 m/s | — | SMG. Spread blooms 1° → 4°. |
| Keystroke | Standard | 16 | 0.11 s | 40 | Projectile 200 m/s | — | Rifle. 0.5° spread. |
| Spam | Standard | 14 | 0.09 s | 50 | Nail 90 m/s, slight drop | — | Nailgun. Nails bounce once. |
| Scroll Wheel | Heavy | 9 | 0.04 s after 0.5 s spin-up | 200 | Projectile 160 m/s | — | Minigun. 2.5° spread. Alt: keep spun up without firing. |

**Close range**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| Scatter Plot | Standard | 10 × 9 pellets | 0.8 s | 8 | Pellets, 5° spread | — | Pump shotgun |
| Double Click | Heavy | 12 × 9 pellets per barrel | 0.25 s | 10 | Pellets, 6° spread | — | Alt: both barrels at once, with 5 m/s self-knockback (shotgun jump) |
| Firewall | Heavy | 120 DPS + 15 burn over 3 s | Continuous | 5 s of fuel | 8 m cone | — | Flamethrower |

**Explosive**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| Overdraw | Heavy | 90 direct, up to 55 splash (3 m) | 0.9 s | 5 | Rocket 35 m/s | — | Rocket launcher. 12 m/s knockback enables rocket jumps. |
| Zip Bomb | Heavy | 60 (3 m) + 3 bomblets × 20 (1.5 m) | 0.7 s | 6 | Bouncing grenade | — | Explodes after 1 s or on contact with a player |

**Strange**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| Screensaver | Standard | 35, +10% per bounce | 0.5 s | 8 | Disc 40 m/s | — | Discs bounce off walls up to 4 times |
| Scanline | Standard | 80 DPS | Continuous | 5 s of charge | Hitscan beam, 25 m | — | Perfectly accurate, low burst |
| Defrag | **Power** | 100 | 0.5 s charge | 3 | Hitscan | — | Railgun. Pierces players and up to 1 m of wall. One per map, at a hard-to-reach spot. |

**Utility and melee**

| Weapon | Tier | Damage | Fire interval | Ammo | Delivery | ♥ | Alt-fire / notes |
|---|---|---|---|---|---|---|---|
| Hyperlink | Standard | 15 | 2.5 s cooldown | Unlimited | Hook, 35 m | — | Grapple gun. Pulls you at 22 m/s, release keeps velocity. Hooking a player pulls them toward you. |
| Backspace | Standard | 50 | 0.5 s | Unlimited | Melee | — | Bat. 12 m/s knockback. The start of each swing (0.2 s) deflects projectiles back at their shooter. |
| Ctrl+X | Standard | 55 | 0.4 s | Unlimited | Melee | — | Katana. Alt: 8 m lunge (2 s cooldown) that chains like a dash. |

### 7.5 Throwables

| Throwable | Effect |
|---|---|
| Packet | Frag grenade. 1.5 s fuse. 90 damage at center down to 20 at 4 m. |
| Buffering | Slow field. A 5 m sphere for 3 s. Players **and projectiles** inside move at 40% speed. |

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

---

## 9. Maps

### 9.1 Design rules

1. **Small and vertical.** Playable footprint between 25 × 25 m and 45 × 45 m, with at least 2 height layers. Spawns are about 3 s of travel apart at run speed.
2. **Built for lines.** Every map has at least one continuous "flow loop": a route you can run at speed using slides, wall rides, and hops without breaking momentum.
3. **Weapon routes.** Weapon pads sit on the flow loop. Every spawn has a Standard pad within about 1.5 s of travel, so the fists-only opening is a short race, not a brawl. Heavy pads are contested in the middle. The Power pad needs movement tech to reach quickly.
4. **No dead ends.** Every area has at least two exits, one of them vertical.
5. **Controlled sightlines.** The longest open sightline is about 40 m. Long lanes have cover breaks.
6. **Readable surfaces.** Wall-rideable surfaces share one consistent visual language across all maps (for example, a distinct tile or panel pattern). Players should never guess.
7. **Symmetrical for 1v1**, rotational or mirrored, including weapon pads. Asymmetry only in visual dressing.
8. **Unloading-ready.** Each map defines its collapse rings for sudden death ([§8.3](#83-round)).
9. **Cheap to build.** Rotation needs many maps, so each should be buildable from a shared modular kit plus a few signature props.

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

### 9.3 Movement sandbox
A dedicated training map with a speedometer, a ghost replay of your last run, movement challenges, a weapon range with every weapon, and target dummies that can move on rails (for heartshot practice). For a movement-first game this is a core feature, not a menu extra.

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
| Speed FOV kick | +5° at 16 m/s | toggle, 0–10° |
| Wall ride tilt | 6° | toggle |
| Smashdown impact shake | Short, low | 0–100% |
| View bob | Off | toggle |
| Landing dip | Subtle, 40 ms | toggle |
| Screen shake | Low | 0–100% |

The camera is **never** driven by the fixed tick directly. Mouse look is applied every rendered frame; position is interpolated between ticks.

### 10.4 Feedback
- **Hits:** hitmarker plus a distinct sound. Headshots and heartshots each get their own sound and marker. Kill confirm gets a short, sharp accent.
- **Being hit:** a directional damage indicator and a brief vignette. It must never obscure aim.
- **Viewmodel:** procedural sway that reacts to velocity, slides, wall rides, smashdowns, and landing, so the gun "breathes" with your movement.
- **Speed:** optional speedometer. At high speed, subtle wind audio and speed-line particles at the screen edges.
- **No hitstop** (online multiplayer can't pause time). Weight comes from sound and camera micro-kicks instead.

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
- Every camera motion effect can be toggled off.
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
- **Weapons in hand:** chunky silhouettes, identifiable at 30 m.
- **Weapon pickups:** float and rotate above glowing pads, arena-shooter style. Pad color shows the tier (Standard, Heavy, Power). Respawn timers are shown on the pad.
- **Projectiles:** bright emissive cores with short trails. Enemy projectiles use the enemy's color.
- **Gameplay surfaces:** wall-rideable surfaces, hazards, and unloading zones each have one consistent visual language across all maps.
- **Fog** never hides a player inside the maximum sightline.

### 11.4 Characters
- Base figure: a blank, glossy white blob of a person, in the spirit of Meccha Chameleon's figures. One seamless smooth shape with **no visible joints**: a big ball head on a short neck, one flat slab of a torso, long tube arms with no hands, and short stubby legs (crotch at about a third of the height) with no feet. A glowing heart sits on the chest. Uncanny but friendly.
- The body is one skinned mesh generated from a smooth signed-distance shape (`src/player/body_shape.gd`, `tools/gen_body.gd`), so proportions are tuned in code, not in a modeling tool.
- Animation comes from Quaternius's Universal Animation Library (CC0). Its human rig is reshaped at load time to the body's proportions (shorter legs, longer spine), and the hips motion is scaled to match.
- Cosmetics (post-MVP): head primitives, surface materials (chrome, marble, carpet, TV static), heart styles, weapon skins. Cosmetics can never change hitboxes or hide the heart.

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
| Boxes | Every piece of text sits in a white box with a thin black frame and black text. |
| Emphasis | Inverted boxes (black, white text) for emphasis, hover, and the current value. Ghost boxes (translucent, grey) for secondary labels. |
| Color | Monochrome. The only accents: **heart pink** (heartshots, the heart) and **red** (low health, alerts). |
| Motion | Things pop in with a quick overshoot; hits and damage shake. No slow fades. |
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
| Centre | The sharp crosshair. Hit markers: white (hit), yellow (head), red (kill), big pink (heartshot). |
| Above the crosshair | Pop-ups: *heartshot* (pink), later *double kill* etc. |
| Below the crosshair | Pickup prompt: `e  swap for overdraw (5)`. Never covers the crosshair. Auto-pickups only flash the name. |
| Bottom left | `hp` + health. Turns red and shakes at 30 or below. |
| Bottom centre | Dash charges as small boxes: black when ready, filling grey while recharging. |
| Bottom right | Throwable (ghost box) above weapon name + ammo left. Ammo box turns red at 0. `fists` when empty-handed. |

The HUD hides during your death sequence. Code: `src/ui/game_hud.gd`, `src/ui/crosshair.gd`.

### 13.4 Overlays and screens

| Screen | Status | Description |
|---|---|---|
| Main menu | Built | Your blob idles (and sometimes dances) under a spotlight on a dark stage. Logo top left, boxed menu below (*play*, *settings (soon)*, *quit*), version in a ghost box. |
| Pause (Esc) | Built | Dim + boxed list: *resume*, *respawn*, *tuning*, *main menu*, *quit*. The game keeps running underneath (it's multiplayer). |
| Map card + countdown | Built (preview) | *round 3* over the map name, a fake loading bar of boxes, then *3 · 2 · 1 · go*. |
| Round result | Built (preview) | Huge *round won* (inverted) or *round lost* banner over the score. |
| Scoreboard (hold Tab) | Built (preview) | One boxed table: rounds, kills, ♥ heartshots, ping. |
| Match end | Built (preview) | *you won* / *you lost*, final score, and a list of every round: map, winner, and how. |
| Death | Built | See §10.5. Caption in the same boxed style. |
| Settings | Planned | Video (pixel height, FOV), mouse, audio, key binds. |
| Lobby | Planned (M3) | Invite / join code, ready-up. |

"Preview" screens run on made-up data (press **F8** in the test course to cycle them) until rounds exist in M3. Code: `src/ui/overlays.gd`, `src/ui/pause_menu.gd`, `src/ui/main_menu.gd`, wired together by `src/ui/game_ui.gd`.

---

## 14. Modes

| Mode | Phase | Notes |
|---|---|---|
| 1v1 online (private lobby) | MVP | Invite or join code |
| Movement sandbox | MVP | See [§9.3](#93-movement-sandbox) |
| Custom rules | MVP (basic) | Rounds to win, weapon pool filters ("precision only", "melee only", "random roulette"), Heartshot on/off, round timer |
| 2v2 | Post-MVP | Needs team-symmetric maps |
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
- **Weapons are data.** A definition file declares the fire mode, damage, zone multipliers, heartshot eligibility, ammo, alt-fire, and projectile behaviors (bounce, stick, split, pierce, explode, knockback). New weapons should rarely need new code.
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
| M2 | Combat prototype (offline) | Fists plus 4 pickups (Pointer, Hotkey, Scatter Plot, Overdraw), pickup and throw, damage zones and heartshot, moving target dummies, hit feedback | Does shooting while moving feel fluid? Does a heartshot feel earned? |
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
| 10 | Do we want a defensive verb (block or parry)? It was removed with the card draft. | No. The Backspace bat's deflect covers it. |
| 11 | Rounds to win | 7 |
| 12 | Networking: listen server via Steam relay for MVP, or dedicated servers from day one? | Listen server |
| 13 | Controller support: in the MVP, or post-MVP with aim assist tuning? | Post-MVP |
| 14 | Monetization model (premium, or premium plus cosmetics)? | Premium, TBD |
