extends "res://tests/test_suite.gd"
## Map tests (GDD §9.3): every map loads with its spawns, a player stands up
## at each, every weapon pad sits on something with room above it, and the
## routes each map is designed around can really be taken: driven through
## the real movement code, one tick at a time, like a player would.

const DT := 1.0 / 60.0
const Mode := MovementState.Mode
const STACK := "res://scenes/maps/stack.tscn"
const TERRACE := "res://scenes/maps/terrace.tscn"
const SWITCHBACK := "res://scenes/maps/switchback.tscn"
const ARCHIPELAGO := "res://scenes/maps/archipelago.tscn"
const RIFT := "res://scenes/maps/rift.tscn"
const BOULEVARD := "res://scenes/maps/boulevard.tscn"
const HOLDFAST := "res://scenes/maps/holdfast.tscn"
const DEPOT := "res://scenes/maps/depot.tscn"
## Map scene, and how many spawns it has.
const MAPS := {STACK: 4, TERRACE: 4, SWITCHBACK: 4, ARCHIPELAGO: 4, RIFT: 4, BOULEVARD: 8, HOLDFAST: 8, DEPOT: 8}
## The team maps: each team's half is the other's flipped by this, and how far
## out the map reaches (x, z).
const TEAM_MAPS := {
	BOULEVARD: [Vector3(-1, 1, 1), Vector2(72, 38)],
	HOLDFAST: [Vector3(-1, 1, 1), Vector2(112, 56)],
	DEPOT: [Vector3(-1, 1, -1), Vector2(84, 52)],
}
const Stack := preload("res://tools/maps/stack.gd")
const Terrace := preload("res://tools/maps/terrace.gd")
const Rift := preload("res://tools/maps/rift.gd")

var level: Node
var player: Player


func _teardown() -> void:
	if level:
		level.queue_free()
	level = null
	player = null


func load_map(path: String) -> void:
	level = load(path).instantiate()
	for layer in ["GameUI", "DebugHUD", "TuningPanel", "RetroScreen"]:
		var n := level.get_node_or_null(layer)
		if n:
			level.remove_child(n)
			n.free()
	player = level.get_node("Player")
	player.human_controlled = false
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	add_child(level)
	player.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame


## Puts the player at `at` (standing still, in the air) facing `yaw`.
func place(at: Vector3, yaw := 0.0) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = yaw
	player.state.reset(player.movement_params)
	player.state.mode = Mode.AIR


func cmd(move := Vector2.ZERO, yaw := 0.0) -> InputCommand:
	var c := InputCommand.new()
	c.move = move
	c.yaw = yaw
	return c


func run(c: InputCommand, n := 1) -> void:
	for i in n:
		await get_tree().physics_frame
		player.tick(c, DT)
		c.clear_presses()


## Runs at `to` (x and z) like a player would: jumping (with `climb`) when
## something is in the way at knee or head height, so ledges get grabbed,
## and (with `hop`) off the edge when the ground ahead drops away. Once
## there, waits to land. Returns the ticks taken, or -1 if it didn't get there.
func go(to: Vector3, climb := true, max_ticks := 900, hop := false) -> int:
	for i in max_ticks:
		var d := to - player.global_position
		d.y = 0.0
		if d.length() < 0.8:
			for j in 60:
				if player.state.on_ground and player.state.mode != Mode.MANTLE:
					break
				await run(cmd(Vector2.ZERO, atan2(-d.x, -d.z)))
			return i
		var c := cmd(Vector2(0, 1), atan2(-d.x, -d.z))
		if climb and player.state.on_ground and (_blocked(d, 0.5) or _blocked(d, 2.0)):
			c.jump_pressed = true
			c.jump_held = true
		if hop and player.state.on_ground and _edge_ahead(d):
			c.jump_pressed = true
			c.jump_held = true
		await run(c)
	return -1


func _blocked(dir: Vector3, height: float) -> bool:
	var from := player.global_position + Vector3.UP * height
	var hit := player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * 1.2, 1, [player.get_rid()]))
	return not hit.is_empty() and absf(hit.normal.y) < 0.5


func _edge_ahead(dir: Vector3) -> bool:
	var from := player.global_position + dir.normalized() * 0.6 + Vector3.UP * 0.3
	return player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5, 1, [player.get_rid()])).is_empty()


func on_floor_at(height: float) -> bool:
	return player.state.on_ground and absf(player.global_position.y - height) < 0.15


## Slides down a ramp from `start` toward `to`, running first to get up to
## slide speed, and returns the fastest horizontal speed reached.
func slide(start: Vector3, to: Vector3) -> float:
	place(start, atan2(-(to - start).x, -(to - start).z))
	await run(cmd(), 10)
	var best := 0.0
	for i in 150:
		var d := to - player.global_position
		d.y = 0.0
		if d.length() < 1.0:
			break
		var c := cmd(Vector2(0, 1), atan2(-d.x, -d.z))
		c.crouch_held = i > 20
		c.crouch_pressed = i == 21
		await run(c)
		best = maxf(best, player.horizontal_speed())
	return best


## Smashes down from where the player is, and on landing bounces toward
## `yaw` (holding forward) to grab the ledge it came from.
func smash_and_bounce(yaw: float) -> void:
	var c := cmd(Vector2.ZERO, yaw)
	c.crouch_pressed = true
	await run(c)
	var landed := false
	for i in 240:
		c = cmd(Vector2(0, 1) if landed else Vector2.ZERO, yaw)
		if not landed and player.state.on_ground:
			landed = true
			c.jump_pressed = true
			c.move = Vector2(0, 1)
		await run(c)
		if landed and player.state.on_ground and i > 5 and player.state.mode != Mode.MANTLE:
			break


# --- Every map ----------------------------------------------------------------

func test_every_map_has_spawns_a_player_can_stand_at() -> void:
	for path: String in MAPS:
		await load_map(path)
		var spawns := get_tree().get_nodes_in_group(&"spawn")
		check(spawns.size() == MAPS[path], "%s has %d spawns (%d)" % [path.get_file(), MAPS[path], spawns.size()])
		for s: Node3D in spawns:
			place(s.global_position + Vector3.UP * 0.05, s.rotation.y)
			await run(cmd(), 30)
			check(on_floor_at(s.global_position.y), "%s: standing at %s (at %s)" % [path.get_file(), s.name, player.global_position])
		check(Maps.name_of(path) != "", "%s is in the map list" % path.get_file())
		_teardown()


func test_every_pad_sits_on_the_floor_with_room_above() -> void:
	for path: String in MAPS:
		await load_map(path)
		var space := player.get_world_3d().direct_space_state
		var pads := level.find_children("Pad_*", "Node3D", true, false)
		check(pads.size() >= 5, "%s has its pads (%d)" % [path.get_file(), pads.size()])
		for pad: Node3D in pads:
			var at := pad.global_position
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 0.3, 1))
			check(not down.is_empty() and absf(down.position.y - at.y) < 0.05, "%s: %s stands on something" % [path.get_file(), pad.name])
			var q := PhysicsShapeQueryParameters3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 0.45
			q.shape = sphere
			q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0)
			q.collision_mask = 1
			check(space.intersect_shape(q, 1).is_empty(), "%s: room above %s" % [path.get_file(), pad.name])
		_teardown()


# --- Stack ----------------------------------------------------------------------

func test_stack_crate_climb_gets_you_onto_the_roof() -> void:
	await load_map(STACK)
	place(Vector3(-6.5, 0.05, 7), 0.0)
	await run(cmd(), 10)
	var ticks := await go(Vector3(-6.5, 0, 0.2))
	check(ticks >= 0 and on_floor_at(Stack.ROOF), "crate, then the roof, in one run north (y %.2f)" % player.global_position.y)
	check(ticks >= 0 and ticks * DT < 2.0, "quick: %.2f s" % (ticks * DT))


func test_stack_well_stomp_and_bounce_back_out() -> void:
	await load_map(STACK)
	# Dropping in over the Well: smash to the bottom (a stomp on whoever's
	# at the shotgun), bounce straight back out onto the roof.
	place(Vector3(0, Stack.ROOF + 0.5, 0.8), 0.0)
	await smash_and_bounce(0.0)
	check(on_floor_at(Stack.ROOF) and player.global_position.z < -1.5,
			"bounced out of the well onto the roof (at %s)" % player.global_position)


func test_stack_ramps_are_slides_down() -> void:
	await load_map(STACK)
	var top_speed := await slide(Vector3(5, Stack.ROOF + 0.05, -9.5), Vector3(-6.5, 0, -9.5))
	check(top_speed > 11.0, "sliding down a ramp into the cellar is fast (%.1f m/s)" % top_speed)


# --- Terrace -------------------------------------------------------------------


func test_stack_is_dressed_and_the_graphics_settings_switch_it() -> void:
	await load_map(STACK)
	var crate := level.find_child("CrateA", true, false) as GreyBox
	check(crate.surface != null and crate.layers == 2, "the blocks wear the map's own surfaces, the cellar's on its own layer")
	var zone := level.find_child("Indoors", true, false) as AmbientZone
	check(zone != null and zone.ambient < 0.5, "the rooms under the pool are indoors: the sky's light stays out")
	var lamps := level.find_children("*", "Light3D", true, false)
	check(lamps.size() >= 15, "lamps all over (%d)" % lamps.size())
	var moon := level.get_node("Sun") as DirectionalLight3D
	var minor := get_tree().get_nodes_in_group(&"minor_lights")
	var detail := get_tree().get_nodes_in_group(&"decor_detail")
	var effects := get_tree().get_nodes_in_group(&"decor_effects")
	check(not minor.is_empty() and not detail.is_empty() and not effects.is_empty(), "minor lamps, detail and effects to switch")
	# Low: no shadows, no extra lamps, no detail, no effects, no bloom.
	Settings.set_graphics_preset("low", false)
	Graphics.apply(get_tree(), level)
	check(not moon.shadow_enabled, "low: no shadows")
	check(moon.light_cull_mask == moon.get_meta(&"cull_mask_unshadowed"), "and the moon keeps out from under the pool without them")
	check(minor.all(func(l: Node) -> bool: return not (l as Light3D).visible), "the extra lamps are off")
	check(detail.all(func(n: Node) -> bool: return not (n as Node3D).visible), "the detail's hidden")
	check(effects.all(func(n: Node) -> bool: return not (n as Node3D).visible), "the effects are off")
	var env := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(not env.glow_enabled, "no bloom")
	check(level.find_child("Fixtures", true, false).visible, "but the lamps' fittings stay: a light always comes from something")
	# High: all of it back as the level set it up.
	Settings.set_graphics_preset("high", false)
	Graphics.apply(get_tree(), level)
	check(moon.shadow_enabled and moon.light_cull_mask == int(moon.get_meta(&"cull_mask")), "high: the moon's shadows, and its light where the level wanted it")
	check(minor.all(func(l: Node) -> bool: return (l as Light3D).visible) and env.glow_enabled, "the lamps and the bloom are back")
	check(detail.all(func(n: Node) -> bool: return (n as Node3D).visible), "and the detail")


func test_terrace_is_a_mall_under_the_eclipse() -> void:
	await load_map(TERRACE)
	var desk := level.find_child("Pulpit", true, false) as GreyBox
	var cliff := level.find_child("Terrace", true, false) as GreyBox
	check(desk.surface != null and cliff.surface != null, "the blocks wear the map's own surfaces")
	var env := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(float((env.sky.sky_material as ShaderMaterial).get_shader_parameter(&"eclipse")) > 0.5, "the sun's in eclipse")
	var zone := level.find_child("UnderTheBridge", true, false) as AmbientZone
	check(zone != null and zone.ambient < 0.5, "under the skybridge the sky's light stays out")
	var lamps := level.find_children("*", "Light3D", true, false)
	check(lamps.size() >= 25, "lamps all over (%d)" % lamps.size())
	var glass := level.find_children("skylight*", "MeshInstance3D", true, false)
	check(not glass.is_empty(), "a glass roof over it all")
	var build := get_tree().get_nodes_in_group(&"decor_build")
	check(not build.is_empty(), "shopfronts and the roof built on")
	# The strings of bulbs hang out of reach, over 9 m.
	var festoons := level.find_children("Festoon_*", "OmniLight3D", true, false)
	check(festoons.size() == 10, "five strings of bulbs, two lamps each (%d)" % festoons.size())
	check(festoons.all(func(l: Node) -> bool: return (l as Node3D).global_position.y > 9.0), "hung out of reach")
	# Graphics at low keep the architecture (only the small stuff goes).
	Settings.set_graphics_preset("low", false)
	Graphics.apply(get_tree(), level)
	check(build.all(func(n: Node) -> bool: return (n as Node3D).visible), "low: the shops and the roof stay")
	Settings.set_graphics_preset("high", false)
	Graphics.apply(get_tree(), level)


func test_terrace_climbs_from_the_square_to_the_pulpit() -> void:
	await load_map(TERRACE)
	place(Vector3(-2, 0.05, -10), PI)
	await run(cmd(), 10)
	var ticks := await go(Vector3(-2.5, 0, 0))
	check(ticks >= 0 and on_floor_at(6.0), "crate, peninsula, pulpit (y %.2f)" % player.global_position.y)


func test_terrace_alley_wall_jump_up_onto_the_terrace() -> void:
	await load_map(TERRACE)
	# Run up the alley, angle in and jump onto the cliff, ride it, kick
	# across to Block C, ride that, kick back and grab the terrace.
	place(Vector3(0.0, 0.05, 14.4), 0.0)
	await run(cmd(), 10)
	var rides := 0
	var kicks := 0
	var riding := false
	for i in 240:
		# North up the alley, then angling in toward the cliff; after each kick,
		# toward the other wall; after the second, square on to the cliff.
		var steer := Vector2(0, 1) if i < 8 else Vector2(0.8, 1)
		if kicks == 1:
			steer = Vector2(-0.5, 1)
		elif kicks >= 2:
			steer = Vector2(1, 0.3)
		var c := cmd(steer.normalized(), 0.0)
		if i == 20:
			c.jump_pressed = true
		var now_riding := player.state.mode == Mode.WALLRIDE
		if now_riding and not riding:
			rides += 1
		if now_riding and player.state.wallride_timer > 0.08:
			c.jump_pressed = true
			kicks += 1
		riding = now_riding
		await run(c)
		if player.global_position.x > 2.2 and player.state.on_ground:
			break
	check(rides >= 2, "rode both walls (%d rides)" % rides)
	check(player.global_position.x > 2.2 and on_floor_at(Terrace.TOP), "up on the terrace (at %s)" % player.global_position)


func test_terrace_slide_is_fast_into_town() -> void:
	await load_map(TERRACE)
	var top_speed := await slide(Vector3(6, Terrace.TOP + 0.05, 16.5), Vector3(-8, 0, 16.5))
	check(top_speed > 11.0, "the Slide carries you into town fast (%.1f m/s)" % top_speed)


func test_terrace_overpass_links_block_a_to_the_terrace() -> void:
	await load_map(TERRACE)
	place(Vector3(-21, 0.05, -12), PI)
	await run(cmd(), 10)
	# Crate, Block A's roof, across the overpass.
	var ticks := await go(Vector3(-21, 0, -8))
	ticks = await go(Vector3(-15, 0, -8.5)) if ticks >= 0 else -1
	ticks = await go(Vector3(6, 0, -8.5), false) if ticks >= 0 else -1
	check(ticks >= 0 and on_floor_at(Terrace.TOP) and player.global_position.x > 2, "over to the terrace (at %s)" % player.global_position)


# --- Switchback ------------------------------------------------------------------

func test_switchback_is_a_car_park_at_dusk() -> void:
	await load_map(SWITCHBACK)
	var overlook := level.find_child("Overlook", true, false) as GreyBox
	var cliff := level.find_child("Level2", true, false) as GreyBox
	check(overlook.surface != null and cliff.surface != null, "the blocks wear the map's own surfaces")
	var lamps := level.find_children("*", "Light3D", true, false)
	check(lamps.size() >= 20, "lamps on every level (%d)" % lamps.size())
	# A light reaching the whole map draws it all again: only the floods do.
	var far_reaching := lamps.filter(func(l: Light3D) -> bool:
			return (l is SpotLight3D and (l as SpotLight3D).spot_range > 20.0) or (l is OmniLight3D and (l as OmniLight3D).omni_range > 20.0))
	check(far_reaching.size() <= 4, "no more than four floods (%d)" % far_reaching.size())
	# The solid props stand against the walls or on roofs, out of the routes.
	var solids := level.find_children("Solid_*", "StaticBody3D", true, false)
	check(not solids.is_empty(), "a few solid props")
	for s: StaticBody3D in solids:
		var box := ((s.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
		var p := s.global_position
		var to_wall := minf(minf(32.0 - (absf(p.x) + box.x * 0.5), (p.z - box.z * 0.5) + 28.0), 12.0 - (p.z + box.z * 0.5))
		check(to_wall < 0.6 or p.y - box.y * 0.5 > 14.9, "%s is against a wall or on a roof (at %s)" % [s.name, p])
	# The car park carries on up out of sight.
	var tower := level.find_children("far_decks*", "MeshInstance3D", true, false)
	check(tower.any(func(m: MeshInstance3D) -> bool: return m.get_aabb().end.y > 200.0), "the spiral tower climbs into the sky")
	var build := get_tree().get_nodes_in_group(&"decor_build")
	check(not build.is_empty(), "the huts and signs built on")


func test_switchback_ladder_climbs_bottom_to_overlook() -> void:
	await load_map(SWITCHBACK)
	place(Vector3(-6, 0.05, 9), 0.0)
	await run(cmd(), 10)
	var total := 0
	for step: Array in [[Vector3(-6, 0, 0.5), 4.0], [Vector3(0, 0, -4), 4.0], [Vector3(0, 0, -9.5), 8.0],
			[Vector3(6, 0, -14), 8.0], [Vector3(6, 0, -18.6), 12.0], [Vector3(6, 0, -20.5), 13.5]]:
		var ticks := await go(step[0])
		total += ticks
		check(ticks >= 0 and on_floor_at(step[1]), "up to %.1f m (at %s)" % [step[1], player.global_position])
		if ticks < 0:
			return
	check(total * DT < 7.0, "bottom to the overlook in %.1f s" % (total * DT))


func test_switchback_hairpins_are_slides_down() -> void:
	await load_map(SWITCHBACK)
	var top_speed := await slide(Vector3(31, 12.05, -13), Vector3(16, 0, -13))
	check(top_speed > 11.0, "the hairpins carry speed (%.1f m/s)" % top_speed)


func test_switchback_huts_tunnel_and_climb() -> void:
	await load_map(SWITCHBACK)
	# Slide through Hut 2's tunnel.
	var through := await slide(Vector3(2, 8.05, -13), Vector3(-18, 0, -13))
	check(player.global_position.x < -14.5 and through > 6.0, "slid through the tunnel (at %s)" % player.global_position)
	# Climb Hut 3's roof, then up onto level 2.
	place(Vector3(15, 4.05, -6), PI * 0.5)
	await run(cmd(), 10)
	var ticks := await go(Vector3(8, 0, -6))
	check(ticks >= 0 and on_floor_at(6.6), "onto the hut roof (at %s)" % player.global_position)
	ticks = await go(Vector3(9.5, 0, -10)) if ticks >= 0 else -1
	check(ticks >= 0 and on_floor_at(8.0), "then up onto level 2 (at %s)" % player.global_position)


func test_switchback_smash_down_and_bounce_back_up() -> void:
	await load_map(SWITCHBACK)
	# Just off level 2's edge, over level 3: smash, bounce, grab level 2 again.
	place(Vector3(3, 9.0, -7.3), 0.0)
	await smash_and_bounce(0.0)
	check(on_floor_at(8.0) and player.global_position.z < -8.0, "back up on level 2 (at %s)" % player.global_position)


# --- Archipelago -----------------------------------------------------------------

func test_archipelago_spire_spiral_climbs_to_the_nest() -> void:
	await load_map(ARCHIPELAGO)
	place(Vector3(-9, 8.05, 6.25), -PI * 0.5)
	await run(cmd(), 10)
	var total := 0
	# Round the four faces, corner to corner, then onto the top.
	for step: Array in [[Vector3(6.25, 0, 6.25), 14.5], [Vector3(6.25, 0, -6.25), 21.0], [Vector3(-6.25, 0, -6.25), 27.5],
			[Vector3(-6.25, 0, 6.25), 34.0], [Vector3(-3.5, 0, 2.5), 34.0]]:
		var ticks := await go(step[0], false)
		total += ticks
		check(ticks >= 0 and on_floor_at(step[1]), "up to %.1f m (at %s)" % [step[1], player.global_position])
		if ticks < 0:
			return
	check(total * DT < 9.0, "the hub to the nest in %.1f s" % (total * DT))


func test_archipelago_garden_slide_is_fast() -> void:
	await load_map(ARCHIPELAGO)
	var top_speed := await slide(Vector3(-10, 8.05, 0), Vector3(-62, -6, 0))
	check(top_speed > 13.0, "the Garden Slide carries you down fast (%.1f m/s)" % top_speed)
	await go(Vector3(-64, 0, 0), false)
	check(on_floor_at(-6.0), "down in the Garden (at %s)" % player.global_position)


func test_archipelago_stones_hop_down_and_climb_back_up() -> void:
	await load_map(ARCHIPELAGO)
	# NW outpost to the Keep: hop down the stones.
	place(Vector3(-47, 10.05, -53), 0.0)
	await run(cmd(), 10)
	var ticks := await go(Vector3(-20, 0, -71), true, 900, true)
	check(ticks >= 0 and on_floor_at(4.0), "hopped down to the Keep (at %s)" % player.global_position)
	# The Garden up to the SW outpost: 3 m a stone, jump and grab each.
	place(Vector3(-73, -5.95, 19), PI)
	await run(cmd(), 10)
	ticks = await go(Vector3(-52, 0, 52), true, 900, true)
	check(ticks >= 0 and on_floor_at(12.0), "climbed the stones to the SW outpost (at %s)" % player.global_position)


func test_archipelago_fin_rides_across_the_gap() -> void:
	await load_map(ARCHIPELAGO)
	# SE outpost to the Terraces: angle in, jump off the edge, ride the fin,
	# kick off toward the Terraces.
	var from := Vector3(39, 10, 56)
	var to := Vector3(24, 8, 68)
	var dir := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	var right := dir.cross(Vector3.UP)
	var start := from - dir * 4.5 - right * 1.2
	var aim := from + dir * 7.0 + right * 1.3 - start
	var yaw := atan2(-aim.x, -aim.z)
	place(start + Vector3.UP * 0.05, yaw)
	await run(cmd(), 10)
	var jumped := false
	var rode := false
	for i in 240:
		var c := cmd(Vector2(0, 1), yaw)
		if not jumped and player.global_position.x < from.x + 0.4:
			c.jump_pressed = true
			jumped = true
		if player.state.mode == Mode.WALLRIDE:
			rode = true
			c.move = Vector2(0.2, 1).normalized()
			if player.state.wallride_timer > 1.0:
				c.jump_pressed = true
		await run(c)
		if jumped and i > 30 and (player.state.on_ground or player.global_position.y < 0.0):
			break
	check(rode, "rode the fin")
	check(on_floor_at(8.0) and player.global_position.z > 64.0, "over on the Terraces (at %s)" % player.global_position)


func test_archipelago_keep_roof_and_the_hole_in_it() -> void:
	await load_map(ARCHIPELAGO)
	place(Vector3(16.5, 4.05, -70), 0.0)
	await run(cmd(), 10)
	var ticks := await go(Vector3(16.5, 0, -89.5))
	ticks = await go(Vector3(10, 0, -89.5)) if ticks >= 0 else -1
	check(ticks >= 0 and on_floor_at(9.5), "up the ramp onto the roof (at %s)" % player.global_position)
	ticks = await go(Vector3(6, 0, -87.5), false) if ticks >= 0 else -1
	var p := player.global_position
	check(ticks >= 0 and on_floor_at(4.0) and p.x > 0.3 and p.x < 11.4 and p.z < -83.3, "dropped into the NE room (at %s)" % p)


# --- Rift -------------------------------------------------------------------------

func test_rift_end_ramp_is_the_long_slide() -> void:
	await load_map(RIFT)
	var top_speed := await slide(Vector3(99, Rift.NORTH, 0), Vector3(40, 0, 0))
	check(top_speed > 16.0, "the East Ramp slide (%.1f m/s)" % top_speed)


func test_rift_floor_to_shelf_to_rim() -> void:
	await load_map(RIFT)
	place(Vector3(60, 0.05, -14), PI * 0.5)
	await run(cmd(), 10)
	var total := 0
	for step: Array in [[Vector3(28, 0, -14), Rift.NORTH_SHELF], [Vector3(-40, 0, -14), Rift.NORTH_SHELF],
			[Vector3(-69.7, 0, -14), Rift.NORTH], [Vector3(-69.7, 0, -20), Rift.NORTH]]:
		var ticks := await go(step[0])
		total += ticks
		check(ticks >= 0 and on_floor_at(step[1]), "up to %.1f m (at %s)" % [step[1], player.global_position])
		if ticks < 0:
			return
	check(total * DT < 20.0, "floor to the north rim by the shelf in %.1f s" % (total * DT))


func test_rift_smash_from_the_rim_bounces_up_to_the_shelf() -> void:
	await load_map(RIFT)
	# Off the north rim, past the shelf, over the floor: smash 28 m, bounce,
	# grab the shelf.
	place(Vector3(-10, Rift.NORTH + 0.5, -10.8), 0.0)
	await smash_and_bounce(0.0)
	check(on_floor_at(Rift.NORTH_SHELF) and player.global_position.z < -12.0, "up on the north shelf (at %s)" % player.global_position)


func test_rift_is_a_station_above_the_clouds_at_dawn() -> void:
	await load_map(RIFT)
	var wall := level.find_child("NorthRim", true, false) as GreyBox
	var arch := level.find_child("ArchN", true, false) as GreyBox
	check(wall.surface != null and arch.surface != null, "the blocks wear the map's own surfaces")
	var sun := level.get_node("Sun") as DirectionalLight3D
	var toward := sun.global_transform.basis.z
	check(toward.x > 0.8 and toward.y > 0.1 and toward.y < 0.4, "the sun's just up in the east (%s)" % toward)
	var zone := level.find_child("Tunnel", true, false) as AmbientZone
	check(zone != null and zone.ambient < 0.5, "the tunnel through the station keeps the sky out")
	var lamps := level.find_children("*", "Light3D", true, false)
	check(lamps.size() >= 12, "the station's lamps still lit (%d)" % lamps.size())
	# The solid props stand against walls (benches on the galleries, the
	# station's chimneys) or at the shoulders' outer edges (benches).
	for s: StaticBody3D in level.find_children("Solid_*", "StaticBody3D", true, false):
		var z := absf(s.global_position.z)
		check((z > 14.5 and z < 16.0) or z > 41.0, "%s is against a wall or at the edge (at %s)" % [s.name, s.global_position])
	# The line goes on far off, across the notches in the mountains round
	# the station, not from the edge: nothing to step onto.
	var far := level.find_children("far_stone*", "MeshInstance3D", true, false)
	check(not far.is_empty(), "viaducts across the cloud")
	var near := 0
	for m: MeshInstance3D in far:
		for v: Vector3 in m.mesh.get_faces():
			if Vector2(v.x, v.z).length() < 250.0:
				near += 1
	check(near == 0, "they're far off (%d points nearer)" % near)


func test_rift_bridges_cross_the_canyon() -> void:
	await load_map(RIFT)
	place(Vector3(0, Rift.SOUTH + 0.05, 20), 0.0)
	await run(cmd(), 10)
	var ticks := await go(Vector3(0, 0, -20), false)
	check(ticks >= 0 and on_floor_at(Rift.NORTH), "the High Bridge, south rim to north (at %s)" % player.global_position)
	place(Vector3(10, Rift.SOUTH_SHELF + 0.05, 14), 0.0)
	await run(cmd(), 10)
	ticks = await go(Vector3(10, 0, -14), false)
	check(ticks >= 0 and on_floor_at(Rift.NORTH_SHELF), "the Mid Bridge, shelf to shelf (at %s)" % player.global_position)


# --- Team maps ----------------------------------------------------------------------

func test_team_maps_are_the_same_for_both_teams() -> void:
	for path: String in TEAM_MAPS:
		await load_map(path)
		var flip: Vector3 = TEAM_MAPS[path][0]
		var reach: Vector2 = TEAM_MAPS[path][1]
		var file := path.get_file()
		# Four spawns a team, each one's twin where the flip puts it.
		var spawns := get_tree().get_nodes_in_group(&"spawn")
		var red := spawns.filter(func(n: Node) -> bool: return n.get_meta(&"team", -1) == Hats.Team.RED)
		var blue := spawns.filter(func(n: Node) -> bool: return n.get_meta(&"team", -1) == Hats.Team.BLUE)
		check(red.size() == 4 and blue.size() == 4, "%s: four spawns a team (%d red, %d blue)" % [file, red.size(), blue.size()])
		for r: Node3D in red:
			check(blue.any(func(b: Node3D) -> bool: return b.global_position.distance_to(r.global_position * flip) < 0.01),
					"%s: %s has a blue twin" % [file, r.name])
		# Every pad's twin holds the same gun (a pad in the middle is its own).
		var pads := level.find_children("Pad_*", "Node3D", true, false)
		for pad: Node3D in pads:
			var twin := pads.filter(func(o: Node3D) -> bool:
					return o.global_position.distance_to(pad.global_position * flip) < 0.01 and o.get(&"weapon") == pad.get(&"weapon"))
			check(twin.size() == 1, "%s: %s has a twin" % [file, pad.name])
		# The ground: the same height at 400 points and their twins.
		var space := player.get_world_3d().direct_space_state
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var mismatches := 0
		for i in 400:
			var at := Vector3(rng.randf_range(-reach.x, reach.x), 60, rng.randf_range(-reach.y, reach.y))
			var here := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 80, 1))
			var there := space.intersect_ray(PhysicsRayQueryParameters3D.create(at * flip, at * flip + Vector3.DOWN * 80, 1))
			if here.is_empty() != there.is_empty() or (not here.is_empty() and absf(here.position.y - there.position.y) > 0.01):
				mismatches += 1
		check(mismatches == 0, "%s: the ground matches its twin (%d of 400 points don't)" % [file, mismatches])
		_teardown()


## Runs the waypoints in turn, checking each is reached standing at its
## height (x, height, z). Returns the ticks taken, or -1.
func route(waypoints: Array, what: String) -> int:
	var total := 0
	for w: Vector3 in waypoints:
		var ticks := await go(w)
		check(ticks >= 0 and on_floor_at(w.y), "%s: at %s, standing at %.1f m (at %s)" % [what, Vector2(w.x, w.z), w.y, player.global_position])
		if ticks < 0 or not on_floor_at(w.y):
			return -1
		total += ticks
	return total


func test_boulevard_routes() -> void:
	await load_map(BOULEVARD)
	# The yard up the ramp to the roof and the tower.
	place(Vector3(68, 0.05, -26), PI * 0.5)
	await run(cmd(), 10)
	var ticks := await route([Vector3(61, 0, -13.5), Vector3(57.5, 0, -13.5), Vector3(57.5, 9.5, -32), Vector3(53, 9.5, -31), Vector3(53, 12, -19),
			Vector3(53, 12, -17)], "yard to tower")
	check(ticks >= 0 and ticks * DT < 10.0, "yard to the tower in %.1f s" % (ticks * DT))
	# Through the Arcade's rooms: street door, the zigzag of doors, the Atrium.
	place(Vector3(55, 0.05, -10), PI * 0.5)
	await run(cmd(), 10)
	ticks = await route([Vector3(50.2, 0, -12), Vector3(50.2, 0, -16), Vector3(43.5, 0, -18.8), Vector3(40.5, 0, -18.8),
			Vector3(30.5, 0, -28.8), Vector3(27.5, 0, -28.8), Vector3(17.5, 0, -24), Vector3(12, 0, -24)], "through the Arcade")
	check(ticks >= 0, "through the Arcade's rooms to the Atrium")
	# Up the Atrium's stair to the shotgun on the balcony.
	ticks = await route([Vector3(14, 0, -27.5), Vector3(3, 5, -27.5), Vector3(0, 5, -31.5)], "up to the balcony")
	check(ticks >= 0, "up to the Atrium's balcony")
	# The canal ramp is a slide in.
	var top_speed := await slide(Vector3(61, 0.05, 25), Vector3(30, -3.5, 25))
	check(top_speed > 10.0, "sliding down into the canal (%.1f m/s)" % top_speed)
	# Off the roof through the skylight.
	place(Vector3(0, 9.55, -29), 0.0)
	await run(cmd(), 10)
	ticks = await go(Vector3(0, 0, -22), false)
	check(ticks >= 0 and on_floor_at(0.0), "down through the skylight (at %s)" % player.global_position)


func test_holdfast_routes() -> void:
	await load_map(HOLDFAST)
	# Spawn, in the back gate, up both stairs to the roof and the sniper.
	place(Vector3(106, 0.05, -18), PI * 0.5)
	await run(cmd(), 10)
	var ticks := await route([Vector3(102, 0, 0), Vector3(97, 0, 0), Vector3(90, 0, -15), Vector3(83, 0, -21.5), Vector3(96.5, 5, -21.5),
			Vector3(97, 5, 0), Vector3(85, 10, 0), Vector3(97, 10, 20), Vector3(85, 16, 20), Vector3(83, 16, 20)], "spawn to the tower")
	check(ticks >= 0 and ticks * DT < 20.0, "spawn to the sniper on the fort's tower in %.1f s" % (ticks * DT))
	# The flank: up the Ledge from the field and over the bridge onto the roof.
	place(Vector3(66, 0.05, -24), 0.0)
	await run(cmd(), 10)
	ticks = await route([Vector3(66, 8, -47), Vector3(88, 8, -47), Vector3(88, 10, -21)], "the Ledge to the roof")
	check(ticks >= 0, "up the Ledge and over the bridge onto the fort's roof")
	# Along the Ledge to the Lookout, and over the Sky Bridge onto the Crown.
	ticks = await route([Vector3(88, 8, -46.5), Vector3(24, 8, -50), Vector3(3, 11, -50), Vector3(0, 11, -46), Vector3(0, 9, -3)], "the Sky Bridge")
	check(ticks >= 0, "from the Ledge over the Sky Bridge onto the Crown")
	# Through the Hill's tunnel, then up its south face and the crate to the Crown.
	place(Vector3(20, 0.05, 0), PI * 0.5)
	await run(cmd(), 10)
	ticks = await route([Vector3(-20, 0, 0), Vector3(-2, 0, 22), Vector3(0, 5, 6.5), Vector3(10, 5, 0), Vector3(7, 7, 0), Vector3(3, 9, 0)], "the Hill")
	check(ticks >= 0, "through the tunnel, up the Hill and onto the Crown")


func test_depot_routes() -> void:
	await load_map(DEPOT)
	# Spawn, out of the back room and the loading doors, up to the Gantry and
	# onto the trolley for the rifle.
	place(Vector3(78, 0.05, -46), PI * 0.5)
	await run(cmd(), 10)
	var ticks := await route([Vector3(74, 0, -48.8), Vector3(71, 0, -48.8), Vector3(71, 0, -38), Vector3(60, 0, -37), Vector3(55, 0, -40),
			Vector3(22, 0, -48.5), Vector3(2, 9, -48.5), Vector3(0, 9, -6), Vector3(0, 11, 0)], "spawn to the trolley")
	check(ticks >= 0 and ticks * DT < 20.0, "spawn to the rifle on the Gantry in %.1f s" % (ticks * DT))
	# Straight through the open boxcar.
	place(Vector3(36, 0.05, 4), PI)
	await run(cmd(), 10)
	ticks = await route([Vector3(36, 0, 16)], "through the open car")
	check(ticks >= 0, "through the open boxcar's doors")
	# A crate up onto a boxcar's roof.
	place(Vector3(16, 0.05, -2), 0.0)
	await run(cmd(), 10)
	ticks = await route([Vector3(16, 2, -7.5), Vector3(16, 3.6, -10)], "onto a boxcar")
	check(ticks >= 0, "onto a boxcar's roof from its crate")
	# Up the Signal tower.
	place(Vector3(50, 0.05, 49.5), PI * 0.5)
	await run(cmd(), 10)
	ticks = await route([Vector3(31, 10, 49.5), Vector3(30, 10, 47.5)], "the Signal tower")
	check(ticks >= 0, "up the Signal tower to the sniper")
	# Up the container stair onto the Gantry.
	place(Vector3(6, 0.05, 12.5), PI)
	await run(cmd(), 10)
	ticks = await route([Vector3(6, 2.6, 16.75), Vector3(6, 5.2, 19.25), Vector3(6, 7.8, 21.75), Vector3(1, 9, 21.75)], "the container stair")
	check(ticks >= 0, "up the containers onto the Gantry")
	# The Footbridge: up its stair, across the tracks, up onto the Signal tower.
	place(Vector3(46, 0.05, -43.5), PI * 0.5)
	await run(cmd(), 10)
	ticks = await route([Vector3(30, 7, -43.5), Vector3(30, 7, 36), Vector3(30, 10, 46)], "the Footbridge")
	check(ticks >= 0, "across the Footbridge to the Signal tower")
	# From the loading yard up onto the Warehouse roof, and down a skylight.
	place(Vector3(57, 0.05, -3.5), PI * 0.5)
	await run(cmd(), 10)
	ticks = await route([Vector3(79, 10, -3.5), Vector3(81, 10, -9), Vector3(67.5, 10, -21)], "onto the roof")
	check(ticks >= 0, "up onto the Warehouse roof")
	ticks = await go(Vector3(67.5, 0, -24.5), false)
	check(ticks >= 0 and on_floor_at(0.0), "down through a skylight into the hall (at %s)" % player.global_position)
