extends "res://tests/test_suite.gd"
## Combat tests (GDD §5–7): hit zones on the body, heartshots, fire rates
## and ammo, pickups and throwing, punches, and how dummies react to where
## they're hit. A script-driven player shoots real dummies in a small world.

const DT := 1.0 / 60.0

var world: Node3D
var player: Player
var dummy: TargetDummy


func _setup() -> void:
	seed(1234)  # Spread and spin are random; keep runs repeatable.
	await frames(1)
	world = Node3D.new()
	add_child(world)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 1, 200)
	col.shape = shape
	floor_body.add_child(col)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	player.human_controlled = false
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	world.add_child(player)
	player.set_process(false)
	dummy = TargetDummy.new()
	dummy.facing = PI  # Facing the player.
	world.add_child(dummy)
	dummy.global_position = Vector3(0, 0, -8)
	await get_tree().physics_frame
	await frames(2)


func _teardown() -> void:
	CombatFx.clear_holes()
	world.queue_free()
	world = null
	player = null
	dummy = null


func cmd() -> InputCommand:
	var c := InputCommand.new()
	c.yaw = player.yaw
	c.pitch = player.pitch
	return c


## Runs n ticks with `c`; presses only last the first tick.
func run(c: InputCommand, n := 1) -> void:
	for i in n:
		await get_tree().physics_frame
		c.yaw = player.yaw
		c.pitch = player.pitch
		player.tick(c, DT)
		c.clear_presses()


## Points the player's view at a world point.
func aim_at(point: Vector3) -> void:
	var to := point - player.weapons.eye_position()
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func fire_once() -> void:
	var c := cmd()
	c.fire_pressed = true
	c.fire_held = true
	await run(c, 1)
	await run(cmd(), 1)


## Waits for shots in flight to land.
func settle_shots(ticks := 20) -> void:
	await run(cmd(), ticks)


## A point on the dummy's heart / head / a bone, in the world.
func heart_point() -> Vector3:
	return dummy.model.heart.global_position


func bone_point(bone: String, offset := Vector3.ZERO) -> Vector3:
	var sk := dummy.model.skeleton
	return sk.global_transform * (sk.get_bone_global_pose(sk.find_bone(bone)) * offset)


# --- Roster -----------------------------------------------------------------

func test_roster_is_six_real_kinds_of_gun() -> void:
	check(Weapons.GUNS.size() == 6, "six guns")
	var names := {}
	var capacities := {}
	for id: StringName in Weapons.GUNS:
		var d := Weapons.get_def(id)
		check(d != null and not d.based_on.is_empty(), "%s is modelled on a real gun" % id)
		check(d.ammo > 0 and d.fire_interval > 0.0 and not d.parts.is_empty(), "%s has rounds, a rate, and a model" % id)
		names[d.display_name] = true
		capacities[d.ammo] = true
	check(names.size() == 6, "every gun has its own name")
	check(capacities.size() >= 5, "capacities vary (%d different)" % capacities.size())
	# Only precision weapons, and nothing faster than 0.3 s, can heartshot (GDD §6.1).
	for id: StringName in Weapons.GUNS:
		var d := Weapons.get_def(id)
		if d.heartshot:
			check(d.fire_interval >= 0.3 and d.pellets == 1, "%s can heartshot fairly" % id)


# --- Hit zones --------------------------------------------------------------

func test_shots_find_the_body_part_they_hit() -> void:
	var from := Vector3(0, 1.0, 0)
	var cases := {
		&"head": bone_point("DEF-head", Vector3(0, 0.1, 0)),
		&"gut": bone_point("DEF-spine.001"),
		&"leg_L": bone_point("DEF-shin.L"),
		&"leg_R": bone_point("DEF-shin.R"),
		&"arm_R": bone_point("DEF-forearm.R"),
	}
	for part: StringName in cases:
		var to: Vector3 = cases[part]
		var hit := dummy.ray_test(from, from + (to - from).normalized() * 20.0)
		check(hit.get("part") == part, "aiming at the %s hits the %s (got %s)" % [part, part, hit.get("part")])
	var head := dummy.ray_test(from, from + (cases[&"head"] - from).normalized() * 20.0)
	check(head.get("zone") == &"head", "the head is its own zone")
	var heart := dummy.ray_test(from, from + (heart_point() - from).normalized() * 20.0)
	check(heart.get("zone") == &"heart", "the heart is its own zone")
	# From behind, it still counts (GDD §6.2).
	var back := Vector3(0, 1.3, -16)
	var from_behind := dummy.ray_test(back, back + (heart_point() - back).normalized() * 20.0)
	check(from_behind.get("zone") == &"heart", "the heart counts from behind")
	var beside := dummy.ray_test(from, Vector3(1.2, 1.0, -20))
	check(beside.is_empty(), "a shot past the body misses")


# --- Firing -----------------------------------------------------------------

func test_heartshot_kills_with_a_precision_gun() -> void:
	player.weapons.give(Weapons.get_def(Weapons.PISTOL))
	await run(cmd(), 12)  # Ready time.
	var confirmed: Array[Dictionary] = []
	player.weapons.hit_confirmed.connect(func(r: Dictionary) -> void: confirmed.append(r))
	aim_at(heart_point())
	await fire_once()
	await settle_shots()
	check(dummy.dead, "one heartshot kills")
	check(dummy.model.heart.ending() == &"off", "and switches its heart off")
	check(confirmed.size() == 1 and confirmed[0].get("heartshot", false), "the shooter hears it was a heartshot")
	check(player.weapons.ammo == 11, "one round spent (%d left)" % player.weapons.ammo)


func test_the_heart_sits_in_a_pocket_in_the_chest() -> void:
	# The body's shape has a round pocket scooped out round the heart, and
	# the body's mesh follows it.
	var sk := dummy.model.skeleton
	var prims := BodyShape.primitives(sk)
	var centre: Vector3 = prims.heart
	check(BodyShape.sdf(centre, prims) > 0.02, "the heart's centre is empty space (%.3f)" % BodyShape.sdf(centre, prims))
	check(BodyShape.sdf(centre + Vector3(0, 0, -BodyShape.SOCKET_RADIUS - 0.02), prims) < 0.0, "with chest behind the pocket")
	var mesh: ArrayMesh = load("res://assets/characters/player_body.res")
	var nearest := INF
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		nearest = minf(nearest, v.distance_to(centre))
	near(nearest, BodyShape.SOCKET_RADIUS, 0.006, "the body's mesh has the pocket: nearest to the heart")


func test_the_heart_is_a_spinner_of_real_beads_floating_in_the_chest() -> void:
	var heart: Heart = dummy.model.heart
	check(heart.dots.size() == Heart.DOTS and heart.lining.visible and heart.ending() == &"on", "beads in a lined pocket, going")
	check(heart.lining.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "it casts no shadow down the chest")
	await frames(2)
	var inside := true
	for bead in heart.dots:
		var local := heart.global_transform.affine_inverse() * bead.global_position
		inside = inside and local.length() + Heart.DOT_RADIUS < HitShapes.HEART_RADIUS \
				and local.length() + Heart.DOT_RADIUS < Heart.LINING_RADIUS and local.z < 0.0
	check(inside, "every bead floats inside the chest's pocket, inside the hit sphere")
	var turns := func(speed: float) -> float:
		heart.speed = speed
		var from := heart.spin()
		heart._process(0.05)
		return fposmod(heart.spin() - from, TAU) / TAU / 0.05
	near(turns.call(0.0), Heart.SPIN_REST, 0.05, "turns per second at rest")
	check(turns.call(Heart.FAST_SPEED) > Heart.SPIN_REST * 2.0, "faster at speed")
	# Each bead on its own spring: a hit rattles them.
	var before: Array[Vector3] = []
	for bead in heart.dots:
		before.append(bead.global_position)
	heart.hurt()
	var held := heart.spin()
	heart._process(1.0 / 60.0)
	var moved := 0
	for i in heart.dots.size():
		if heart.dots[i].global_position.distance_to(before[i]) > 0.002:
			moved += 1
	check(moved == Heart.DOTS, "a hit rattles every bead (%d moved)" % moved)
	check(heart.spin() == held, "and makes the spin hitch")
	heart._process(Heart.HITCH_TIME)
	heart._process(0.05)
	check(heart.spin() != held, "then it carries on")
	# A death through the body times it out; back together, it's going again.
	dummy.take_hit({"damage": 500.0, "zone": &"body", "part": &"chest", "point": heart.global_position,
			"normal": Vector3.BACK, "direction": Vector3.FORWARD, "heartshot": false, "attacker": null})
	check(dummy.dead and heart.ending() == &"lost" and heart.dots.size() == Heart.DOTS, "killed through the body: timed out, beads kept")
	dummy._respawn()
	check(heart.ending() == &"on" and heart.get_parent().name == &"HeartMount" and heart.lining.visible,
			"back together: going again, in the chest")
	await frames(2)
	# A heartshot spills them out of the chest.
	var at := heart.global_position
	dummy.take_hit({"damage": 5.0, "zone": &"heart", "part": &"chest", "point": at,
			"normal": Vector3.BACK, "direction": Vector3.FORWARD, "heartshot": true, "attacker": null})
	check(heart.ending() == &"off" and heart.dots.is_empty() and heart.spilled().size() == Heart.DOTS,
			"a heartshot spills every bead")
	for i in 40:
		await get_tree().physics_frame
	var furthest := 0.0
	for body in heart.spilled():
		furthest = maxf(furthest, body.global_position.distance_to(at))
	check(furthest > 0.3, "out of the chest and away (%.2f m)" % furthest)
	dummy._respawn()
	await frames(2)
	check(heart.spilled().is_empty() and heart.dots.size() == Heart.DOTS, "back together: the spilled beads cleared, new ones in")


func test_timed_out_the_beads_settle_in_the_bottom_of_the_pocket() -> void:
	var heart: Heart = dummy.model.heart
	heart.stop(false)
	for i in 60:
		heart._process(1.0 / 60.0)
	var low := true
	for bead in heart.dots:
		var local := heart.global_transform.affine_inverse() * bead.global_position
		low = low and local.y < -Heart.RING_RADIUS * 0.8
	check(heart.ending() == &"lost" and low, "timed out: they sink to the bottom of the pocket")
	heart.revive()


func test_automatic_guns_cannot_heartshot() -> void:
	player.weapons.give(Weapons.get_def(Weapons.SMG))
	await run(cmd(), 12)
	aim_at(heart_point())
	await fire_once()
	await settle_shots()
	check(not dummy.dead, "an SMG round through the heart doesn't kill")
	near(dummy.health, TargetDummy.MAX_HEALTH - Weapons.get_def(Weapons.SMG).damage, 0.01, "it did body damage")


func test_headshots_do_more() -> void:
	var d := Weapons.get_def(Weapons.RIFLE)
	player.weapons.give(d)
	await run(cmd(), 12)
	aim_at(bone_point("DEF-head", Vector3(0, 0.12, 0)))
	await fire_once()
	await settle_shots()
	near(dummy.health, TargetDummy.MAX_HEALTH - d.damage * d.head_multiplier, 0.01, "head damage")


func test_semi_auto_fires_once_per_click_and_auto_while_held() -> void:
	player.weapons.give(Weapons.get_def(Weapons.PISTOL))
	await run(cmd(), 12)
	aim_at(Vector3(5, 1, -20))  # Away from the dummy.
	var held := cmd()
	held.fire_pressed = true
	held.fire_held = true
	await run(held, 1)
	held.fire_held = true
	for i in 60:
		await run(held, 1)
		held.fire_held = true
	check(player.weapons.ammo == 11, "holding a pistol's trigger fires once (%d left)" % player.weapons.ammo)
	var smg := Weapons.get_def(Weapons.SMG)
	player.weapons.give(smg)
	await run(cmd(), 12)
	held.fire_pressed = true
	held.fire_held = true
	for i in 60:
		await run(held, 1)
		held.fire_held = true
	var fired := smg.ammo - player.weapons.ammo
	near(fired, 1.0 / smg.fire_interval, 2.0, "an SMG held for a second fires at its rate (%d)" % fired)


func test_shotgun_throws_all_its_pellets() -> void:
	var d := Weapons.get_def(Weapons.SHOTGUN)
	player.weapons.give(d)
	await run(cmd(), 12)
	aim_at(Vector3(0, 1.2, -8))
	await fire_once()
	var ballistics := Ballistics.of(world)
	check(ballistics.get_child_count() == d.pellets, "%d pellets in flight (%d)" % [d.pellets, ballistics.get_child_count()])
	await settle_shots()
	check(dummy.health <= TargetDummy.MAX_HEALTH - d.damage * 3, "several pellets hit at 8 m (%.0f hp left)" % dummy.health)


func test_an_empty_gun_lasts_until_its_pad_gives_out_the_next() -> void:
	var revolver := Weapons.get_def(Weapons.REVOLVER)
	var pad := WeaponPad.new()
	pad.weapon = Weapons.REVOLVER
	pad.respawn_time = 0.3
	world.add_child(pad)
	pad.global_position = player.global_position
	await run(cmd(), 3)
	check(player.weapons.primary == revolver and player.weapons.primary_origin == pad and pad.generation == 1,
			"walked onto the pad: took its first gun")
	player.global_position += Vector3(6, 0, 0)  # Off the pad.
	await run(cmd(), 12)
	aim_at(player.weapons.eye_position() + Vector3(0, 0, -20))
	for i in revolver.ammo:
		await fire_once()
		await run(cmd(), int(revolver.fire_interval / DT) + 1)
	await run(cmd(), 30)
	check(player.weapons.ammo == 0 and player.weapons.current == revolver, "empty, and still in your hands")
	var clicks := []
	player.weapons.dry_fired.connect(func(_d: WeaponDef) -> void: clicks.append(true))
	await fire_once()
	check(clicks.size() == 1, "click")
	# Thrown, it lies on the floor, past the old few seconds, while the
	# pad's next gun is still there.
	player.weapons.throw_primary()
	await run(cmd(), int((WeaponPickup.EMPTY_LIFE + 2.0) / DT))
	var loose := get_tree().get_nodes_in_group(WeaponPickup.GROUP) \
			.filter(func(n: Node) -> bool: return n != pad.pickup and (n as WeaponPickup).origin == pad)
	check(loose.size() == 1 and (loose[0] as WeaponPickup).ammo == 0 and pad.pickup != null,
			"thrown: it lies there empty (%d), the pad's next gun waiting" % loose.size())
	# Someone takes the pad's next gun: the empty one's had its time.
	player.global_position = pad.global_position
	await run(cmd(), 3)
	check(pad.generation == 2 and player.weapons.primary == revolver and player.weapons.ammo == revolver.ammo, "took the next one")
	await run(cmd(), int((WeaponPickup.DISSOLVE_TIME + 0.2) / DT))
	check(not is_instance_valid(loose[0]) or loose[0].is_queued_for_deletion(), "and the empty one's gone")
	# One empty in your hands goes too, once its pad's next is taken.
	player.global_position += Vector3(6, 0, 0)
	player.weapons.primary_ammo = 0
	await run(cmd(), int(pad.respawn_time / DT) + 5)
	check(player.weapons.primary == revolver, "empty in your hands while the pad's next gun waits")
	pad.pickup.take(pad.pickup.ammo)  # Someone else takes it.
	await run(cmd(), 2)
	check(player.weapons.primary == null and player.weapons.current.is_fists(), "then it's gone from your hands")
	# Taking another gun, or dying, drops an empty one rather than losing it.
	player.weapons.give(revolver, 0, pad, pad.generation)
	player.weapons.give(Weapons.get_def(Weapons.PISTOL))
	player.weapons.give(revolver, 0, pad, pad.generation)
	player.weapons.drop_on_death()
	await run(cmd(), 2)
	var dropped := get_tree().get_nodes_in_group(WeaponPickup.GROUP) \
			.filter(func(n: Node) -> bool: return (n as WeaponPickup).origin == pad and (n as WeaponPickup).ammo == 0)
	check(dropped.size() == 1, "dying drops the empty gun (%d)" % dropped.size())


func test_the_revolver_fans_when_you_hold_the_trigger_from_the_hip() -> void:
	var revolver := Weapons.get_def(Weapons.REVOLVER)
	player.weapons.give(revolver)
	await run(cmd(), 12)
	aim_at(Vector3(5, 1, -20))
	await fire_once()
	await run(cmd(), 40)
	check(player.weapons.primary_ammo == 5, "a click is one shot (%d left)" % player.weapons.primary_ammo)
	var fanned := []
	player.weapons.fired.connect(func(_def: WeaponDef, shot: Dictionary) -> void:
		if shot.fanned:
			fanned.append(shot))
	var c := cmd()
	c.fire_pressed = true
	for i in int((WeaponHolder.FAN_HOLD + WeaponHolder.FAN_INTERVAL * 4.0) / DT) + 4:
		c.fire_held = true
		await run(c, 1)
	check(player.weapons.primary_ammo == 0 and fanned.size() == 4,
			"held from the hip: a shot, then the other four fanned in under half a second (%d left, %d fanned)" % [player.weapons.primary_ammo, fanned.size()])
	player.weapons.give(revolver)
	await run(cmd(), 12)
	c = cmd()
	c.fire_pressed = true
	for i in 60:
		c.fire_held = true
		c.alt_held = true
		await run(c, 1)
	check(player.weapons.primary_ammo == 5, "held while aiming: one careful shot (%d left)" % player.weapons.primary_ammo)


# --- Aiming -----------------------------------------------------------------

func test_every_gun_aims_down_its_sights() -> void:
	for id: StringName in Weapons.GUNS:
		var d := Weapons.get_def(id)
		player.weapons.give(d)
		await run(cmd(), 12)
		var hip := player.weapons.spread()
		var c := cmd()
		c.alt_held = true
		await run(c, int(d.aim_time / DT) + 2)
		check(d.zoom > 1.0 and player.weapons.aim == 1.0 and is_equal_approx(player.weapons.zoom, d.zoom),
				"%s: alt-fire held aims, zoomed %.2fx" % [d.display_name, player.weapons.zoom])
		near(player.weapons.spread(), hip * d.aim_spread, 0.001, "%s: its spread, aimed" % d.display_name)
		near(player.aim_turn_scale(), 1.0 / d.zoom, 0.001, "%s: turning slows with the zoom" % d.display_name)
		await run(cmd(), int(d.aim_time / DT) + 2)
		check(player.weapons.aim == 0.0 and player.weapons.zoom == 1.0, "%s: let go, back to the hip" % d.display_name)
	var c := cmd()
	c.alt_held = true
	await run(c, 5)
	c.switch_to = 2
	await run(c, 20)
	check(player.weapons.current.is_fists() and player.weapons.aim == 0.0 and player.weapons.zoom == 1.0,
			"fists have nothing to aim")
	check(Weapons.get_def(Weapons.SNIPER).sight == WeaponDef.Sight.SCOPE and Weapons.get_def(Weapons.SMG).sight == WeaponDef.Sight.DOT,
			"the sniper has a scope, the SMG a dot sight")


# --- Pickups and throwing ---------------------------------------------------

func test_pickups_auto_top_up_and_swap() -> void:
	var drop := func(id: StringName, at: Vector3, rounds := -1) -> WeaponPickup:
		var p := WeaponPickup.create(Weapons.get_def(id), Weapons.get_def(id).ammo if rounds < 0 else rounds)
		world.add_child(p)
		p.rest_on_pad(at, null)
		p.pad = null
		return p
	drop.call(Weapons.PISTOL, player.global_position + Vector3(0, 0.9, 0))
	await run(cmd(), 2)
	check(player.weapons.primary == Weapons.get_def(Weapons.PISTOL), "walking over a gun empty-handed takes it")
	player.weapons.primary_ammo = 4
	drop.call(Weapons.PISTOL, player.global_position + Vector3(0, 0.9, 0.5))
	await run(cmd(), 2)
	check(player.weapons.primary_ammo == 12, "the same gun tops it up to full (%d)" % player.weapons.primary_ammo)
	drop.call(Weapons.SNIPER, player.global_position + Vector3(0.5, 0.9, 0))
	await run(cmd(), 2)
	check(player.weapons.primary == Weapons.get_def(Weapons.PISTOL), "a different gun needs E")
	check(player.weapons.swap_candidate != null, "and offers the swap")
	var c := cmd()
	c.interact_pressed = true
	await run(c, 1)
	check(player.weapons.primary == Weapons.get_def(Weapons.SNIPER), "E swaps")
	var dropped := get_tree().get_nodes_in_group(WeaponPickup.GROUP).filter(
			func(n: Node) -> bool: return (n as WeaponPickup).def == Weapons.get_def(Weapons.PISTOL) and (n as WeaponPickup).ammo == 12)
	check(dropped.size() == 1, "the old gun drops with its rounds")


func test_thrown_gun_hits_for_25() -> void:
	player.weapons.give(Weapons.get_def(Weapons.SNIPER))
	await run(cmd(), 12)
	aim_at(Vector3(0, 1.5, -8))
	var c := cmd()
	c.throw_pressed = true
	await run(c, 1)
	check(player.weapons.primary == null and player.weapons.current.is_fists(), "throwing leaves you with fists")
	for i in 60:
		await run(cmd(), 1)
		if dummy.health < TargetDummy.MAX_HEALTH:
			break
	near(dummy.health, TargetDummy.MAX_HEALTH - WeaponPickup.THROW_DAMAGE, 0.01, "the thrown gun hit")


func test_punch_lands_in_reach() -> void:
	dummy.global_position = Vector3(0, 0, -1.6)
	await frames(2)
	aim_at(Vector3(0, 1.2, -1.6))
	await fire_once()
	await run(cmd(), 6)
	near(dummy.health, TargetDummy.MAX_HEALTH - Weapons.get_def(Weapons.FISTS).damage, 0.01, "a standing punch does 25")


# --- Dummies ----------------------------------------------------------------

func test_dummy_reacts_to_where_it_was_hit() -> void:
	var layers := dummy.model.layers
	var hit := func(part: StringName, point: Vector3) -> void:
		dummy.take_hit({"damage": 20.0, "zone": &"body", "part": part, "point": point,
				"normal": Vector3.BACK, "direction": Vector3.FORWARD, "heartshot": false})
	hit.call(&"head", bone_point("DEF-head", Vector3(0, 0.1, 0)))
	check(layers.is_playing(&"Hit_Head"), "a head hit plays the head flinch")
	dummy.health = TargetDummy.MAX_HEALTH
	hit.call(&"chest", bone_point("DEF-spine.003"))
	check(layers.is_playing(&"Hit_Chest"), "a chest hit plays the chest flinch")
	dummy.health = TargetDummy.MAX_HEALTH
	var sk := dummy.model.skeleton
	hit.call(&"leg_L", bone_point("DEF-shin.L"))
	check(layers._flinch.has(sk.find_bone("DEF-thigh.L")) and layers._flinch.has(sk.find_bone("DEF-shin.L")), "a leg hit knocks that leg")
	check(not layers._flinch.has(sk.find_bone("DEF-thigh.R")), "and not the other one")
	hit.call(&"arm_R", bone_point("DEF-forearm.R"))
	check(layers._flinch.has(sk.find_bone("DEF-upper_arm.R")), "an arm hit knocks that arm")
	for i in 90:
		await get_tree().process_frame
	check(layers.is_settled(), "and it all settles")


func test_dummy_falls_apart_and_comes_back() -> void:
	var killed := []
	dummy.killed.connect(func(h: bool) -> void: killed.append(h))
	dummy.take_hit({"damage": 5.0, "zone": &"heart", "part": &"chest", "point": heart_point(),
			"normal": Vector3.BACK, "direction": Vector3.FORWARD, "heartshot": true})
	check(dummy.dead and killed == [true], "a heartshot kills outright")
	check(dummy.ray_test(Vector3(0, 1.2, 0), Vector3(0, 1.2, -20)).is_empty(), "nothing to hit while it's in pieces")
	for i in int((TargetDummy.RESPAWN_TIME + 0.5) * 60):
		await get_tree().process_frame
	check(not dummy.dead and dummy.health == TargetDummy.MAX_HEALTH, "back together, full health")
	check(not dummy.ray_test(Vector3(0, 1.2, 0), Vector3(0, 1.2, -20)).is_empty(), "and hittable again")


# --- Ammo display -----------------------------------------------------------

func test_ammo_column_grows_with_capacity() -> void:
	var heights: Array[float] = []
	var caps: Array[int] = []
	for id: StringName in Weapons.GUNS:
		caps.append(Weapons.get_def(id).ammo)
	caps.sort()
	for c in caps:
		heights.append(AmmoMeter.height_for(c))
	for i in range(1, heights.size()):
		check(heights[i] > heights[i - 1] or caps[i] == caps[i - 1], "more rounds, taller column (%d: %.0f px)" % [caps[i], heights[i]])
	check(AmmoMeter.is_segmented(6) and AmmoMeter.is_segmented(12), "small guns are cut into rounds")
	check(not AmmoMeter.is_segmented(30), "big ones aren't")


func test_hits_add_up_in_one_number() -> void:
	var hit := func(amount: float, zone: StringName) -> void:
		dummy.take_hit({"damage": amount, "zone": zone, "part": &"chest", "point": bone_point("DEF-spine.003"),
				"normal": Vector3.BACK, "direction": Vector3.FORWARD, "heartshot": false})
	hit.call(11.0, &"body")
	var first := DamageNumber.over(dummy)
	check(first != null and first.text == "11", "the first hit shows its damage")
	await frames(6)
	hit.call(11.0, &"body")
	hit.call(16.5, &"head")
	check(DamageNumber.over(dummy) == first, "more hits add to the same number")
	near(first.total, 38.5, 0.01, "the total")
	check(first.zone == &"head", "a head hit colours it")
	var small := first.scale.x
	await frames(20)
	check(first.text == "39", "it rolls up to the total (shows %s)" % first.text)
	check(first.scale.x > 1.0 and first.scale.x < small, "bigger for more damage, settled after the pop")
	await frames(int((DamageNumber.HOLD + DamageNumber.FADE) * 60) + 5)
	check(DamageNumber.over(dummy) == null, "gone after a pause")
	hit.call(20.0, &"body")
	check(DamageNumber.over(dummy) != null and DamageNumber.over(dummy).total == 20.0, "the next hit starts a new one")


func test_through_the_heart_without_a_heartshot_is_a_body_hit() -> void:
	player.weapons.give(Weapons.get_def(Weapons.SMG))
	await run(cmd(), 12)
	var results: Array[Dictionary] = []
	player.weapons.hit_confirmed.connect(func(r: Dictionary) -> void: results.append(r))
	aim_at(heart_point())
	await fire_once()
	await settle_shots()
	check(results.size() == 1 and results[0].zone == &"body" and not results[0].heartshot, "an SMG round through the heart counts as body")
	check(DamageNumber.over(dummy) != null and DamageNumber.over(dummy).zone == &"body", "and its number isn't pink")


func test_punches_mix_straights_hooks_and_uppercuts() -> void:
	var holder := player.weapons
	var counts := {}
	var last := &""
	var repeats := 0
	for i in 400:
		var kind: StringName = holder.call(&"_pick_punch")
		counts[kind] = counts.get(kind, 0) + 1
		if kind == last and kind != &"straight":
			repeats += 1
		last = kind
	for kind: StringName in WeaponHolder.PUNCH_KINDS:
		check(counts.get(kind, 0) > 40, "%s comes up (%d of 400)" % [kind, counts.get(kind, 0)])
	check(counts.get(&"straight", 0) > counts.get(&"hook", 0), "straights are the most common")
	check(repeats == 0, "never the same hook or uppercut twice running (%d)" % repeats)
	# A swing says which it is.
	var kinds: Array[StringName] = []
	holder.fired.connect(func(_def: WeaponDef, shot: Dictionary) -> void: kinds.append(shot.get("kind", &"")))
	await fire_once()
	await run(cmd(), 20)
	check(kinds.size() == 1 and kinds[0] in WeaponHolder.PUNCH_KINDS, "a punch carries its kind (%s)" % [kinds])
