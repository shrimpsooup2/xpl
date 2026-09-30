class_name Graphics
extends RefCounted
## The settings that trade looks for speed (the settings page's video tab,
## saved by Settings): shadow quality, the extra lamps, small detail, moving
## effects, and bloom. apply() puts them into effect on the level that's
## loaded; every level applies them as it loads (GameUI).
##
## What they switch, in a dressed map (tools/deco_kit.gd):
## - shadows: the moon's and the shadowed lamps' shadows, and how sharp.
## - extra lamps: lamps in the "minor_lights" group (exit signs, tellies).
## - detail: decor in the "decor_detail" group (pipes, props, signs).
## - effects: "decor_effects" (water, beams, dust), animated surfaces
##   (caustics, flickering tubes), held still when off.
## - bloom: the environment's glow.

enum Shadows { OFF, LOW, HIGH }

static var shadows := Shadows.HIGH
static var extra_lamps := true
static var detail := true
static var effects := true
static var bloom := true

const SHADOW_ATLAS := {Shadows.LOW: 1024, Shadows.HIGH: 4096}
const POSITIONAL_ATLAS := {Shadows.LOW: 1024, Shadows.HIGH: 4096}


## A preset: [shadows, extra lamps, detail, effects, bloom].
const PRESETS := {
	"low": [Shadows.OFF, false, false, false, false],
	"medium": [Shadows.LOW, true, true, false, true],
	"high": [Shadows.HIGH, true, true, true, true],
}


## One of the on/off settings by name ("extra_lamps", "detail", "effects",
## "bloom").
static func toggle(key: String) -> bool:
	match key:
		"extra_lamps":
			return extra_lamps
		"detail":
			return detail
		"effects":
			return effects
		"bloom":
			return bloom
	return false


static func set_toggle(key: String, on: bool) -> void:
	match key:
		"extra_lamps":
			extra_lamps = on
		"detail":
			detail = on
		"effects":
			effects = on
		"bloom":
			bloom = on


## Which preset the settings match ("" for a mix).
static func preset() -> String:
	var now := [shadows, extra_lamps, detail, effects, bloom]
	for name: String in PRESETS:
		if PRESETS[name] == now:
			return name
	return ""


## Puts the settings into effect on `scene` (the loaded level by default)
## and for the shaders everywhere.
static func apply(tree: SceneTree, scene: Node = null) -> void:
	RenderingServer.global_shader_parameter_set(&"effects", 1.0 if effects else 0.0)
	if shadows != Shadows.OFF:
		RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[shadows], true)
		tree.root.positional_shadow_atlas_size = POSITIONAL_ATLAS[shadows]
	if scene == null:
		scene = tree.current_scene
	if scene == null:
		return
	for light: Light3D in scene.find_children("*", "Light3D", true, false):
		_light(light)
	for n: Node in tree.get_nodes_in_group(&"decor_detail"):
		(n as Node3D).visible = detail
	for n: Node in tree.get_nodes_in_group(&"decor_effects"):
		(n as Node3D).visible = effects
		for p: CPUParticles3D in n.find_children("*", "CPUParticles3D", true, false):
			p.emitting = effects
	for env: WorldEnvironment in scene.find_children("*", "WorldEnvironment", true, false):
		if env.environment:
			if not env.has_meta(&"glow"):
				env.set_meta(&"glow", env.environment.glow_enabled)
			env.environment.glow_enabled = bloom and bool(env.get_meta(&"glow"))


static func _light(light: Light3D) -> void:
	# What the level set up is kept on the light, so each setting can go
	# back to it.
	if not light.has_meta(&"shadowed"):
		light.set_meta(&"shadowed", light.shadow_enabled)
		light.set_meta(&"cull_mask", light.light_cull_mask)
	var was_shadowed: bool = light.get_meta(&"shadowed")
	if light is DirectionalLight3D:
		light.shadow_enabled = was_shadowed and shadows != Shadows.OFF
	else:
		light.shadow_enabled = was_shadowed and shadows == Shadows.HIGH
	# A light that relies on its shadows to stay out of a room lights less
	# without them (the moon, kept off the floor under the pool).
	var mask: int = light.get_meta(&"cull_mask")
	if not light.shadow_enabled and light.has_meta(&"cull_mask_unshadowed"):
		mask = light.get_meta(&"cull_mask_unshadowed")
	light.light_cull_mask = mask
	if light.is_in_group(&"minor_lights"):
		light.visible = extra_lamps
