extends "res://tests/test_suite.gd"
## Hats and teams (GDD §11.4): every hat builds in both team colours and sits
## on the head, no hat means a team triangle over it, the hat flies off when
## the body falls apart and is back on respawn, the pick is saved, and the
## title screen's picker steps through them. Also: the first-person arms
## are a closed mesh (no open rims at the cut) that carries on out of view.

const TEST_PATH := "user://test_cosmetics.cfg"

var world: Node3D
var _saved_path := ""
var _saved_hat := Cosmetics.DEFAULT_HAT


func _setup() -> void:
	seed(99)
	_saved_path = Cosmetics.path
	_saved_hat = Cosmetics.hat
	Cosmetics.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	world = Node3D.new()
	add_child(world)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 1, 40)
	col.shape = shape
	floor_body.add_child(col)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	await frames(1)


func _teardown() -> void:
	world.queue_free()
	world = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Cosmetics.path = _saved_path
	Cosmetics.hat = _saved_hat


## A bare body standing at `at` (in a holder, so its pieces land in the world).
func model_at(at: Vector3) -> PlayerModel:
	var holder := Node3D.new()
	world.add_child(holder)
	var m := PlayerModel.new()
	holder.add_child(m)
	m.follow(at, 0.0)
	return m


func head_position(m: PlayerModel) -> Vector3:
	var bone := m.skeleton.find_bone("DEF-head")
	return m.skeleton.global_transform * m.skeleton.get_bone_global_pose(bone).origin


## Every colour used by the hat's parts.
func colors_of(hat: Node3D) -> Array[Color]:
	var out: Array[Color] = []
	for mi: MeshInstance3D in hat.find_children("*", "MeshInstance3D", true, false):
		out.append(mi.get_instance_shader_parameter(&"color"))
	return out


func test_every_hat_builds_in_its_team_colours() -> void:
	check(Hats.ALL.size() >= 15, "a good few hats to pick from (%d)" % Hats.ALL.size())
	check(Hats.NONE in Hats.ALL, "no hat is a choice")
	for id: StringName in Hats.ALL:
		check(Hats.NAMES.has(id), "%s has a name" % id)
		if id == Hats.NONE:
			check(Hats.build(id, Hats.team_color(Hats.Team.RED)) == null, "no hat builds nothing")
			continue
		var red := Hats.build(id, Hats.team_color(Hats.Team.RED))
		var blue := Hats.build(id, Hats.team_color(Hats.Team.BLUE))
		check(red != null and red.get_child_count() >= 1, "%s builds" % id)
		var red_colors := colors_of(red)
		var blue_colors := colors_of(blue)
		check(Hats.team_color(Hats.Team.RED) in red_colors, "%s is red for red" % id)
		check(Hats.team_color(Hats.Team.BLUE) in blue_colors, "%s is blue for blue" % id)
		check(not Hats.team_color(Hats.Team.BLUE) in red_colors and not Hats.team_color(Hats.Team.RED) in blue_colors,
				"%s never shows the other team's colour" % id)
		# Sits on the head (helmets come down over it): above its middle, about head-sized.
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in red.find_children("*", "MeshInstance3D", true, false):
			var b := mi.transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		check(box.get_center().y > 0.0 and box.position.y > -0.2, "%s sits on top of the head (%s)" % [id, box])
		check(box.size.x < 0.8 and box.size.z < 0.8 and box.size.y < 0.8, "%s is hat-sized (%s)" % [id, box.size])
		red.free()
		blue.free()


func test_a_hat_rides_on_the_head() -> void:
	var m := model_at(Vector3(2, 0, 0))
	m.dress(&"top_hat", Hats.team_color(Hats.Team.BLUE))
	await frames(2)
	check(m.hat != null and m.marker == null, "a hat and no triangle")
	check(m.hat_id == &"top_hat" and m.tint == Hats.team_color(Hats.Team.BLUE), "remembers what it's wearing")
	var head := head_position(m)
	check(m.hat.global_position.distance_to(head) < 0.35, "the hat is at the head (%.2f m off)" % m.hat.global_position.distance_to(head))
	check(m.hat.global_position.y > head.y - 0.05, "on top of it, not under")
	m.follow(Vector3(-3, 0, 4), 1.2)
	await frames(2)
	check(m.hat.global_position.distance_to(head_position(m)) < 0.35, "follows the head as it moves")
	m.dress(&"fez", Hats.team_color(Hats.Team.BLUE))
	await frames(1)
	check(m.find_children("Hat_top_hat", "", true, false).is_empty(), "changing hats takes the old one off")


func test_no_hat_puts_a_team_triangle_over_the_head() -> void:
	var m := model_at(Vector3.ZERO)
	m.dress(Hats.NONE, Hats.team_color(Hats.Team.BLUE))
	await frames(3)
	check(m.hat == null and m.marker != null, "no hat: the triangle instead")
	check(m.marker.is_visible_in_tree(), "the triangle shows")
	var colors: Array[Color] = []
	for mi: MeshInstance3D in m.marker.find_children("*", "MeshInstance3D", true, false):
		colors.append((mi.material_override as StandardMaterial3D).albedo_color)
	check(Hats.team_color(Hats.Team.BLUE) in colors, "in the team's colour")
	var above := m.marker.global_position.y - head_position(m).y
	check(above > 0.45 and above < 0.8, "hovering over the head (%.2f m above)" % above)
	check(absf(m.marker.global_position.x - head_position(m).x) < 0.1, "right over it")
	m.dress(&"cap", Hats.team_color(Hats.Team.BLUE))
	await frames(1)
	check(m.marker == null, "a hat puts the triangle away")


func test_the_hat_flies_off_when_the_body_falls_apart_and_is_back_after() -> void:
	var m := model_at(Vector3.ZERO)
	m.dress(&"cowboy_hat", Hats.team_color(Hats.Team.RED))
	await frames(2)
	m.fall_apart(false, Vector3(0, 1.5, -4))
	await get_tree().create_timer(0.6).timeout
	check(m.hat == null, "the hat's off the head")
	var flying: Node = null
	for f in m.fragments():
		if not f.find_children("Hat_cowboy_hat", "", true, false).is_empty():
			flying = f
	check(flying != null, "it's flying on its own")
	await get_tree().create_timer(1.6).timeout
	if flying:
		var y: float = (flying as Node3D).global_position.y
		check(y > -0.3 and y < 2.6, "and lands (y %.2f)" % y)
	m.reassemble()
	await frames(2)
	check(m.hat != null and m.hat_id == &"cowboy_hat", "back on after reassembling")

	m.dress(Hats.NONE, Hats.team_color(Hats.Team.RED))
	await frames(1)
	m.fall_apart(false, Vector3(0, 1.5, -4))
	await get_tree().create_timer(0.6).timeout
	check(not m.marker.visible, "the triangle goes when the body does")
	m.reassemble()
	await frames(2)
	check(m.marker != null and m.marker.is_visible_in_tree(), "and comes back with it")


func test_the_picked_hat_is_saved() -> void:
	Cosmetics.load_saved()
	check(Cosmetics.hat == Cosmetics.DEFAULT_HAT, "nothing saved: the default hat")
	Cosmetics.set_hat(&"wizard_hat")
	Cosmetics.hat = &"beanie"
	Cosmetics.load_saved()
	check(Cosmetics.hat == &"wizard_hat", "the pick comes back next time")
	Cosmetics.set_hat(Hats.NONE)
	Cosmetics.load_saved()
	check(Cosmetics.hat == Hats.NONE, "no hat is saved too")
	var cfg := ConfigFile.new()
	cfg.set_value("look", "hat", "sombrero_from_the_future")
	cfg.save(TEST_PATH)
	Cosmetics.load_saved()
	check(Cosmetics.hat == Cosmetics.DEFAULT_HAT, "an unknown hat falls back to the default")


func test_players_wear_their_hats_and_dummies_play_for_blue() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	player.human_controlled = false
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	player.hat = &"viking_helmet"
	world.add_child(player)
	await frames(2)
	check(player.model.hat_id == &"viking_helmet" and player.model.tint == Hats.team_color(Hats.Team.RED), "the player wears its hat, for red")
	check(player.model.hat != null, "and it's on")
	var dummy := TargetDummy.new()
	dummy.hat = Hats.NONE
	world.add_child(dummy)
	dummy.global_position = Vector3(3, 0, 0)
	var capped := TargetDummy.new()
	world.add_child(capped)
	capped.global_position = Vector3(-3, 0, 0)
	await frames(2)
	check(dummy.model.tint == Hats.team_color(Hats.Team.BLUE) and capped.model.tint == Hats.team_color(Hats.Team.BLUE), "dummies play for blue")
	check(dummy.model.marker != null and dummy.model.hat == null, "a hatless dummy shows the triangle")
	check(capped.model.hat != null and Hats.team_color(Hats.Team.BLUE) in colors_of(capped.model.hat), "a blue hat on the other")


func test_you_wear_your_picked_hat_in_a_match_every_session() -> void:
	Cosmetics.set_hat(&"crown")
	Cosmetics.hat = Cosmetics.DEFAULT_HAT  # A fresh session: nothing in memory.
	var player: Player = load("res://scenes/player.tscn").instantiate()
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	world.add_child(player)
	await frames(2)
	check(player.model.hat_id == &"crown", "your player wears the saved hat (%s)" % player.model.hat_id)
	check(player.model.hat != null, "and it's on")
	player.die()
	await get_tree().create_timer(0.3).timeout
	player.respawn()
	await frames(2)
	check(player.model.hat_id == &"crown" and player.model.hat != null, "still wearing it after a respawn")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_title_screen_picker_steps_through_the_hats() -> void:
	Cosmetics.set_hat(&"cap")
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	world.add_child(menu)
	await frames(2)
	var model: PlayerModel = menu.get(&"_model")
	check(model.hat_id == &"cap", "the blob wears the saved hat")
	check(model.tint in colors_of(model.hat), "in its team's colour")
	var hat_name: Control = menu.get(&"_hat_name")
	var play: Control = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "free-for-all":
			play = b
	check(play != null and not play.get_parent().is_ancestor_of(hat_name), "the picker isn't in the main menu column")
	check(LofiUI.style_of(hat_name) == LofiUI.Style.GHOST, "it's a quiet ghost box")
	menu.cycle_hat(1)
	var after_cap: StringName = Hats.ALL[Hats.ALL.find(&"cap") + 1]
	check(Cosmetics.hat == after_cap and model.hat_id == after_cap, "→ puts the next hat on (%s)" % Cosmetics.hat)
	Cosmetics.hat = &"none"
	Cosmetics.load_saved()
	check(Cosmetics.hat == after_cap, "and saves it")
	menu.cycle_hat(-2)
	check(model.hat_id == Hats.ALL[Hats.ALL.find(&"cap") - 1], "← goes back")
	for i in Hats.ALL.size():
		menu.cycle_hat(1)
		if model.hat_id == Hats.NONE:
			break
	check(model.hat == null and model.marker != null, "no hat shows the triangle on the blob")
	# The free-for-all colour: steps, saves, and shows on the blob.
	Cosmetics.set_color(&"red")
	menu.cycle_color(1)
	var next_color: StringName = Hats.PALETTE.keys()[1]
	check(Cosmetics.color == next_color and model.tint == Hats.PALETTE[next_color], "→ picks the next colour and wears it")
	Cosmetics.color = &"red"
	Cosmetics.load_saved()
	check(Cosmetics.color == next_color, "and saves it")
	menu.cycle_color(-2)
	check(Cosmetics.color == Hats.PALETTE.keys()[-1], "← wraps round")
	await frames(20)
	menu.queue_free()
	await frames(1)


func test_the_title_screen_online_page_hosts_and_shows_the_lobby() -> void:
	OnlineMenu.prefs_path = "user://test_online.cfg"
	Cosmetics.set_player_name("hostess")
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	world.add_child(menu)
	await frames(2)
	menu.open_online()
	await frames(2)
	var page: OnlineMenu = menu.get(&"_online")
	check(page != null and page.is_visible_in_tree(), "online opens its page")
	var shown := func(text: String) -> bool:
		return menu.find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text == text and b.is_visible_in_tree())
	check(shown.call("host") and shown.call("join") and not shown.call("free-for-all"), "host and join in place of the menu's buttons")
	var status: PanelContainer = page.get(&"_status")
	page.get(&"_address_field").text = "no such:address:here"
	page.call(&"_join")
	check(status.visible and LofiUI.style_of(status) == LofiUI.Style.ALERT and not NetSession.active(), "a bad address says so, and goes nowhere")
	page.get(&"_port_field").text = "80"
	page.call(&"_host")
	check(LofiUI.label_of(status).text.contains("1024") and not NetSession.active(), "so does a port it can't use")
	page.get(&"_port_field").text = "27982"
	page.call(&"_host")
	await frames(3)
	var s := NetSession.current
	check(NetSession.active() and s.role == NetSession.Role.HOST, "host starts hosting")
	var texts := func() -> PackedStringArray:
		var out := PackedStringArray()
		for l: Label in page.find_children("*", "Label", true, false):
			if l.is_visible_in_tree() and not l.get_parent().is_queued_for_deletion():
				out.append(l.text)
		return out
	check("your game" in texts.call() and "hostess  (host, you)" in texts.call(), "the lobby: your game, with you in it (%s)" % [texts.call()])
	check(not (menu.get(&"_pickers") as Control).visible, "your look is set by now: the pickers go")
	page.call(&"_step_bots", 1)
	page.call(&"_step_bots", 1)
	await frames(2)
	check(s.bot_count() == 2 and "bot 1  (bot)" in texts.call() and "bot 2  (bot)" in texts.call(), "bots join the roster")
	check("2 bots" in texts.call(), "and the count says so")
	page.call(&"_step_bots", -1)
	await frames(2)
	check(s.bot_count() == 1 and not "bot 2  (bot)" in texts.call(), "and leave it")
	page.call(&"_step_style", 1)
	await frames(2)
	check(s.rules.is_teams() and "teams" in texts.call(), "the style goes to teams")
	check(texts.call().has("hostess  (red, host, you)") or texts.call().has("hostess  (blue, host, you)"), "and the roster shows sides")
	page.call(&"_leave")
	await frames(2)
	check(not NetSession.active() and shown.call("host"), "closing the game goes back to host and join")
	menu.close_online()
	await frames(2)
	check(shown.call("free-for-all") and menu.get(&"_online") == null, "back shows the menu's buttons again")
	menu.queue_free()
	await frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OnlineMenu.prefs_path))
	OnlineMenu.prefs_path = "user://online.cfg"


func test_the_title_screen_blob_is_red_or_blue_at_random() -> void:
	var teams := {}
	for k in 6:
		seed(k * 7919)
		var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
		world.add_child(menu)
		await frames(1)
		teams[(menu.get(&"_model") as PlayerModel).tint] = true
		menu.queue_free()
		await frames(1)
	check(teams.has(Hats.team_color(Hats.Team.RED)) and teams.has(Hats.team_color(Hats.Team.BLUE)) and teams.size() == 2,
			"both teams come up, and only them (%s)" % [teams.keys()])


## Sleeve vertices in the eye's space, this frame.
func sleeve_points(player: Player) -> PackedVector3Array:
	var vm := player.viewmodel
	var mesh: ArrayMesh = vm.get(&"_sleeve_mesh")
	var out := PackedVector3Array()
	if mesh.get_surface_count() == 0:
		return out
	var to_eye := vm.global_transform.affine_inverse() * vm.skeleton.global_transform
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		out.append(to_eye * v)
	return out


## Checks the sleeves this frame: they're there, their tails are out of view,
## and nothing reaches the eye's plane near the line of sight (the viewmodel's
## depth doesn't clip there, so that would smear across the screen).
func check_sleeves(player: Player, what: String) -> void:
	var points := sleeve_points(player)
	check(points.size() > 100, "%s: the arms carry on as sleeves" % what)
	var closest := INF
	var tails_in_view := 0
	var slope := tan(deg_to_rad(Viewmodel.FOV * 0.5))
	for p in points:
		if p.z > -0.03:
			closest = minf(closest, Vector2(p.x, p.y).length())
		if -p.z < 0.15 and absf(p.y) < -p.z * slope and absf(p.x) < -p.z * slope * 16.0 / 9.0:
			tails_in_view += 1
	check(closest > 0.2, "%s: nothing at the eye's plane near the line of sight (%.2f m off it)" % [what, closest])
	check(tails_in_view == 0, "%s: no sleeve end in view (%d points)" % [what, tails_in_view])


func test_first_person_arms_carry_on_out_of_view() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	world.add_child(player)
	await frames(4)
	check_sleeves(player, "fists")
	player.viewmodel.layers.play(&"Punch_Jab", BodyLayers.UPPER_BODY, 1.4, 0.1, 0.75, 0.02, 0.12)
	await frames(8)
	check_sleeves(player, "jab")
	player.weapons.give(Weapons.get_def(Weapons.RIFLE), -1)
	await frames(12)
	check_sleeves(player, "rifle")
	player.viewmodel.layers.play(&"Pistol_Reload", BodyLayers.ARMS["L"], 1.8, 0.1, 1.0, 0.05, 0.12)
	await frames(15)
	check_sleeves(player, "top-up")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_first_person_arms_are_a_closed_mesh() -> void:
	var m := model_at(Vector3.ZERO)
	await frames(1)
	var mesh := Viewmodel.arms_only(m.skeleton)
	check(mesh.get_surface_count() > 0, "there are arms")
	var open := 0
	var triangles := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		triangles += indices.size() / 3
		var count := {}
		for i in range(0, indices.size(), 3):
			for k in 3:
				var a := indices[i + k]
				var b := indices[i + (k + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				count[key] = count.get(key, 0) + 1
		for key: Vector2i in count:
			if count[key] != 2:
				open += 1
	check(triangles > 100, "a real mesh (%d triangles)" % triangles)
	check(open == 0, "no open edges where the arms are cut (%d)" % open)
