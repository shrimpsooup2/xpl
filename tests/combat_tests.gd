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
	check(confirmed.size() == 1 and confirmed[0].get("heartshot", false), "the shooter hears it was a heartshot")
	check(player.weapons.ammo == 11, "one round spent (%d left)" % player.weapons.ammo)


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


func test_empty_gun_switches_to_fists() -> void:
	player.weapons.give(Weapons.get_def(Weapons.REVOLVER), 1)
	await run(cmd(), 12)
	aim_at(Vector3(5, 1, -20))
	await fire_once()
	check(player.weapons.ammo == 0, "empty")
	await run(cmd(), int(WeaponHolder.EMPTY_SWITCH / DT) + 2)
	check(player.weapons.current.is_fists(), "fists after a moment")
	check(player.weapons.primary != null, "the empty gun is still carried")


func test_fanning_empties_the_revolver_quickly() -> void:
	player.weapons.give(Weapons.get_def(Weapons.REVOLVER))
	await run(cmd(), 12)
	aim_at(Vector3(5, 1, -20))
	var c := cmd()
	c.alt_pressed = true
	c.alt_held = true
	await run(c, 1)
	await run(cmd(), int(WeaponHolder.FAN_INTERVAL * 6.0 / DT) + 4)
	check(player.weapons.primary_ammo == 0, "six rounds fanned in about 0.6 s (%d left)" % player.weapons.primary_ammo)


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
