# xtrapartial

![xtrapartial](assets/ui/logo.png)

A round-based, movement-first arena FPS. Two players duel through short rounds on a rotation of small, surreal, early-2000s-styled maps, spawning with only their fists and racing for weapons scattered around each one. A precise shot to the heart kills instantly.

**Status:** pre-production. Milestone M1 (movement prototype) is playable, and the first six guns are in with a shooting range to try them on.

- [Game Design Document](docs/GDD.md)

## Running the prototype

1. Install **Godot 4.7.2**, the standard build (not .NET): <https://godotengine.org/download>
2. Clone this repo, open Godot, choose **Import**, and select `project.godot`.
3. Press **F5** to play. The main menu opens: **free-for-all** starts a practice game of short rounds against three bots, **teams** a long four-against-four game with bots, and **sandbox** the movement test course. In the bottom-right corner you type your name and pick your hat and your free-for-all colour; they're saved and worn in every game. In the sandbox the gun pads are just to your left, and the shooting range is beyond them; its dummies play for blue. Press **F9** to step through the maps: Stack, Terrace, Switchback, Archipelago and Rift, then the team maps Boulevard, Holdfast and Depot (greybox, [GDD §9.3](docs/GDD.md#93-built-maps)).

### Controls

| Action | Key |
|---|---|
| Move | WASD |
| Look | Mouse |
| Jump | Space or mouse wheel down |
| Slide / crouch (on the ground) | Ctrl or C |
| Smashdown (in the air) | Ctrl or C |
| Dash | Shift |
| Fire / alt-fire | Left / right mouse (the revolver fans its hammer, the sniper zooms) |
| Swap for the gun you're standing at | E (walking over one empty-handed takes it) |
| Throw your gun | Q |
| Switch gun / fists | 1 / 2, mouse wheel up |
| Tuning panel | F1 |
| Respawn | F2 |
| Toggle vsync | F3 |
| Toggle debug readout | F4 |
| Third-person camera (debug) | F6 |
| Die (debug, to see the death sequence) | F7 |
| Preview UI overlays (debug) | F8 |
| Next map | F9 |
| Scoreboard | Hold Tab |
| Pause menu | Esc |

Wall ride and mantle are automatic: jump along a wall to ride it, and move into a ledge to climb it.

### Tuning

Press **F1** in-game to edit every movement value live. **Save** writes them to `data/movement_params.tres` and `data/view_settings.tres` when you run from the editor, so tuned values can be committed.

The **View → Look** section of the panel controls the render: `pixel height` is the internal 3D resolution (360 by default, 0 for native), and `color levels` turns on an optional 16-bit color and dither mode (off by default).

## Project layout

| Path | Contents |
|---|---|
| `src/movement/` | The movement simulation: `MovementSim` (one fixed tick), `MovementState`, `MovementParams`, `InputCommand` |
| `src/player/` | `Player` (input, camera interpolated between ticks), `PlayerModel` (the body, its holds, hit reactions and crumble), `BodyLayers` (clips over some bones, arm IK, hit flinches), `Viewmodel` (first-person arms and gun), `BodyShape` (proportions and shape), `DeathSequence` (the death cinematic), `ViewSettings` |
| `src/cosmetics/` | `Hats` (every hat, built from primitives in team colours, and the no-hat team triangle) and `Cosmetics` (the saved pick) |
| `src/combat/` | The roster (`Weapons`, `WeaponDef`), gun models (`WeaponModel`), a player's hands (`WeaponHolder`: firing, pickups, throwing), shots in flight (`Ballistics`), hit zones (`HitShapes`), pickups and pads, `TargetDummy`, and shooting effects |
| `src/ui/` | The UI: style and motion kit (`LofiUI`), low-res canvas (`LofiLayer`), HUD and its ammo column, crosshair and ammo ring, overlays, pause and main menus, scene wipe |
| `src/game/` | Games: `GameRules` (the free-for-all and teams presets), `Match` (runs a game across maps), `Game` (starts and ends one), `PlayerInfo` (each player's name, side and score), `BotBrain` (practice bots) |
| `src/world/` | `GreyBox` blocks (size and surface kind) and `Maps` (the map list F9 steps through) |
| `src/render/` | Surface, sky, screen, prop and viewmodel shaders, and `RetroScreen` (low-res rendering) |
| `assets/` | Pixel textures, the reflection map, the logo, the generated body and chunk meshes, and third-party assets |
| `src/debug/` | Debug HUD and the live tuning panel |
| `data/` | Tuning resources |
| `scenes/` | `main_menu.tscn` (main scene), `test_course.tscn`, `player.tscn`, and the maps in `maps/` |
| `tests/` | Headless movement, UI, combat, cosmetics and map tests |
| `tools/` | Test runner, the scene generator, the level kit (with `level_side.gd` for symmetric team maps) and the map layouts (`maps/`) |

## Tests

```sh
tools/run_tests.sh
```

This runs the headless movement, UI, combat, cosmetics and map tests (the map tests drive a player through each map's routes). Set `TEST_ONLY` to part of a test's name to run just those. It uses `$GODOT` or `godot` on your PATH; on Linux x86_64 it downloads Godot 4.7.2 into `.tools/` if neither is found.

`tools/build_scenes.gd` regenerates the input map, `player.tscn`, the greybox test course, and the maps (each laid out by a script in `tools/maps/` with the kit in `tools/level_kit.gd`). Once you edit the course by hand in the editor, stop regenerating it (pass `-- --skip-course`). `tools/gen_textures.gd` and `tools/gen_logo.gd` regenerate the placeholder textures and the logo; paint over the PNGs freely instead. `tools/gen_body.gd` regenerates the player's body and its pre-diced chunks from `src/player/body_shape.gd` (about a minute; add `-- --body-only` to skip the dicing while tuning the shape).

## Credits

- Animations: [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) by Quaternius, CC0 (`assets/third_party/quaternius_ual/`).
- Font: Liberation Sans, SIL Open Font License 1.1 (`assets/fonts/`).
