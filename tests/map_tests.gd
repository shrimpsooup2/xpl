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
## Map scene, and how many spawns it has.
const MAPS := {STACK: 2, TERRACE: 2, SWITCHBACK: 2, ARCHIPELAGO: 4, RIFT: 4}
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
