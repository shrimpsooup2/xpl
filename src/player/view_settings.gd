class_name ViewSettings
extends Resource
## Camera and mouse settings (GDD §10.3). Player-facing options, kept apart
## from MovementParams because they never affect the simulation.

## Source-style sensitivity: degrees of yaw per mouse count = 0.022 × this.
@export_range(0.05, 10.0, 0.01) var sensitivity: float = 1.5
## Horizontal FOV at 16:9. Other aspect ratios keep the same vertical FOV.
@export_range(80.0, 120.0, 1.0) var fov_horizontal: float = 100.0
## Extra FOV at the speed soft cap.
@export_range(0.0, 10.0, 0.5) var speed_fov_kick: float = 5.0
@export_range(0.0, 15.0, 0.5) var wallride_tilt: float = 6.0
@export var landing_dip: bool = true
@export_range(0.0, 1.0, 0.05) var screen_shake: float = 0.3
@export var invert_y: bool = false
