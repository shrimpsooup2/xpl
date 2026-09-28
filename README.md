# xtrapartial

![xtrapartial](assets/ui/logo.png)

A round-based, movement-first arena FPS. Two players duel through short rounds on a rotation of small, surreal, early-2000s-styled maps, spawning with only their fists and racing for weapons scattered around each one. A precise shot to the heart kills instantly.

**Status:** pre-production. Milestone M1 (movement prototype) is playable.

- [Game Design Document](docs/GDD.md)

## Running the prototype

1. Install **Godot 4.7.2**, the standard build (not .NET): <https://godotengine.org/download>
2. Clone this repo, open Godot, choose **Import**, and select `project.godot`.
3. Press **F5** to play. The main menu opens; choose **play** to enter the movement test course.

### Controls

| Action | Key |
|---|---|
| Move | WASD |
| Look | Mouse |
| Jump | Space or mouse wheel down |
| Slide / crouch (on the ground) | Ctrl or C |
| Smashdown (in the air) | Ctrl or C |
| Dash | Shift |
| Tuning panel | F1 |
| Respawn | F2 |
| Toggle vsync | F3 |
| Toggle debug readout | F4 |
| Third-person camera (debug) | F6 |
| Die (debug, to see the death sequence) | F7 |
| Preview UI overlays (debug) | F8 |
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
| `src/player/` | `Player` (input, camera interpolated between ticks), `PlayerModel` (the body and its crumble), `BodyShape` (proportions and shape), `DeathSequence` (the death cinematic), `ViewSettings` |
| `src/ui/` | The UI: style kit (`LofiUI`), low-res canvas (`LofiLayer`), HUD, crosshair, overlays, pause and main menus |
| `src/world/` | `GreyBox` blocks (size and surface kind) |
| `src/render/` | Surface, sky, and screen shaders, and `RetroScreen` (low-res rendering) |
| `assets/` | Pixel textures, the reflection map, the logo, the generated body and chunk meshes, and third-party assets |
| `src/debug/` | Debug HUD and the live tuning panel |
| `data/` | Tuning resources |
| `scenes/` | `main_menu.tscn` (main scene), `test_course.tscn`, and `player.tscn` |
| `tests/` | Headless movement tests |
| `tools/` | Test runner and the scene generator |

## Tests

```sh
tools/run_tests.sh
```

This runs the headless movement tests. It uses `$GODOT` or `godot` on your PATH; on Linux x86_64 it downloads Godot 4.7.2 into `.tools/` if neither is found.

`tools/build_scenes.gd` regenerates the input map, `player.tscn`, and the greybox test course. Once you edit the course by hand in the editor, stop regenerating it (pass `-- --skip-course`). `tools/gen_textures.gd` and `tools/gen_logo.gd` regenerate the placeholder textures and the logo; paint over the PNGs freely instead. `tools/gen_body.gd` regenerates the player's body and its pre-diced chunks from `src/player/body_shape.gd` (about a minute).

## Credits

- Animations: [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) by Quaternius, CC0 (`assets/third_party/quaternius_ual/`).
- Font: Liberation Sans, SIL Open Font License 1.1 (`assets/fonts/`).
