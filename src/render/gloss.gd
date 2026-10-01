class_name Gloss
extends RefCounted
## Shared glossy materials (gloss_shared.gdshader): one for each colour and
## finish, handed to every part drawn alike (every gun's, every hat's, the
## casings and gibs). Instance uniforms would be simpler, but the GL
## Compatibility renderer has room for them on only 256 instances in all,
## which a big map's pickups and a few players holding guns fill (see
## gloss.gdshaderinc). What changes on its own (a pad's ring, a crate) still
## uses gloss.gdshader's instance uniforms.

const REFLECTION := preload("res://assets/textures/reflection_map.png")
const SHADERS := [preload("res://src/render/gloss_shared.gdshader"), preload("res://src/render/gloss_shared_double.gdshader")]

static var _cache := {}


## The shared material for `color` with `finish` ([gloss, rim, glow,
## roughness]), drawn in the first-person view with `viewmodel`, from both
## sides with `double_sided`.
static func material(color: Color, finish: Array, viewmodel := false, double_sided := false) -> ShaderMaterial:
	var key := "%s %s %s %s" % [color, finish, viewmodel, double_sided]
	var m: ShaderMaterial = _cache.get(key)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = SHADERS[1 if double_sided else 0]
		m.set_shader_parameter(&"reflection_map", REFLECTION)
		m.set_shader_parameter(&"viewmodel", viewmodel)
		m.set_shader_parameter(&"color", color)
		m.set_shader_parameter(&"gloss", finish[0])
		m.set_shader_parameter(&"rim_amount", finish[1])
		m.set_shader_parameter(&"glow", finish[2])
		m.set_shader_parameter(&"roughness_amount", finish[3])
		_cache[key] = m
	return m


## Fades a part drawn with a shared material out (`amount` 1 to 0): it gets
## its own copy while it fades, and the shared one back once it's whole.
static func fade(part: GeometryInstance3D, amount: float) -> void:
	if amount >= 0.999:
		if part.has_meta(&"shared"):
			part.material_override = part.get_meta(&"shared")
			part.remove_meta(&"shared")
		return
	if not part.has_meta(&"shared"):
		part.set_meta(&"shared", part.material_override)
		part.material_override = (part.material_override as ShaderMaterial).duplicate()
	(part.material_override as ShaderMaterial).set_shader_parameter(&"fade", amount)
