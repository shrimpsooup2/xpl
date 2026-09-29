class_name ViewSettings
extends Resource
## Camera and mouse settings (GDD §10.3). Player-facing options, kept apart
## from MovementParams because they never affect the simulation.

## Source-style sensitivity: degrees of yaw per mouse count = 0.022 × this.
@export_range(0.05, 10.0, 0.01) var sensitivity: float = 1.5
## Horizontal FOV at 16:9. Other aspect ratios keep the same vertical FOV.
@export_range(80.0, 120.0, 1.0) var fov_horizontal: float = 100.0
## Extra FOV at the speed soft cap.
@export_range(0.0, 15.0, 0.5) var speed_fov_kick: float = 8.0
@export_range(0.0, 15.0, 0.5) var wallride_tilt: float = 6.0
@export var landing_dip: bool = true
@export_range(0.0, 1.0, 0.05) var screen_shake: float = 0.3
## How much the camera reacts to your movement: leaning into strafes, the
## slide tilt and rumble, jump, landing, dash and wall jump kicks, and the
## smashdown's stretch and slam (GDD §10.3). 0 turns all of it off. It never
## moves on its own.
@export_range(0.0, 1.0, 0.05) var camera_motion: float = 1.0
## How smoothly the camera and HUD react. 0 (default) is fast and jerky:
## kicks snap in on the frame and drop straight off, shake jitters. 1 eases
## everything in and lets it settle with a little overshoot.
@export_range(0.0, 1.0, 0.05) var camera_smoothing: float = 0.0
## Streaks at the screen edges when you're fast (GDD §10.4).
@export var speed_lines: bool = true
## How much the UI moves on its own: HUD sway, UI kicks and shakes, the idle
## wobble. 0 keeps it still (GDD §13.5).
@export_range(0.0, 1.0, 0.05) var ui_motion: float = 1.0
@export var invert_y: bool = false

@export_group("Look")
## Height of the internal 3D resolution in pixels, upscaled with hard pixels.
## 0 renders at native resolution.
@export_range(0, 1080, 1) var pixel_height: int = 360
## Optional colour-depth cut with ordered dither (32 ≈ 16-bit colour). 0 is off.
@export_range(0, 256, 1) var color_levels: int = 0
@export_range(0.0, 1.0, 0.05) var dither: float = 1.0
## The hearts' look, on trial (GDD §6.4): 0 the tiny TV, 1 the loading
## spinner. Every heart you see changes at once.
@export_range(0, 1, 1) var heart_style: int = 0

@export_group("Experimental")
## Anime-style impact frames on kills and hard smashdowns: a beat of stark
## two-tone ink with speed lines (see ImpactFrames). Off by default: they're high-contrast
## flashes, and still being tried out.
@export var impact_frames: bool = false
