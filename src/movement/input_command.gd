class_name InputCommand
extends RefCounted
## One tick of player input. This is what a client will send to the server,
## so it holds intent only: axes, view angles, and buttons.

## x = right, y = forward. Length is at most 1.
var move: Vector2 = Vector2.ZERO
## Radians. Yaw 0 looks down -Z; positive yaw turns left.
var yaw: float = 0.0
var pitch: float = 0.0

## "pressed" flags are true only on the tick the button went down.
var jump_pressed: bool = false
var jump_held: bool = false
var crouch_pressed: bool = false
var crouch_held: bool = false
var dash_pressed: bool = false
var fire_pressed: bool = false
var fire_held: bool = false
var alt_pressed: bool = false
var alt_held: bool = false
var interact_pressed: bool = false
var throw_pressed: bool = false
## 1: switch to the primary, 2: to fists, 3: toggle, 0: stay.
var switch_to: int = 0


func clear_presses() -> void:
	jump_pressed = false
	crouch_pressed = false
	dash_pressed = false
	fire_pressed = false
	alt_pressed = false
	interact_pressed = false
	throw_pressed = false
	switch_to = 0
