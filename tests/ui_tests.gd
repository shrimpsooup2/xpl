extends "res://tests/test_suite.gd"
## UI tests: the in-game UI built around a real (script-driven) player, run
## frame by frame. Checks that the motion (GDD §13.5) happens, settles, and
## cleans up after itself.

var world: Node3D
var player: Player
var ui: GameUI


func _setup() -> void:
	LofiUI.motion = 1.0
	await frames(1)  # Let the previous test's world go.
	world = Node3D.new()
	add_child(world)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	col.shape = shape
	floor_body.add_child(col)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	player.human_controlled = false
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	world.add_child(player)
	player.add_to_group(&"local_player")
	ui = GameUI.new()
	world.add_child(ui)
	await frames(3)


func _teardown() -> void:
	player.remove_from_group(&"local_player")
	world.queue_free()
	world = null
	player = null
	ui = null
	LofiUI.motion = 1.0


func land(speed: float) -> void:
	player.movement_event.emit({"type": &"land", "impact_speed": speed})


# --- HUD motion -----------------------------------------------------------------

func test_hud_lags_behind_mouse_look_then_settles() -> void:
	await frames(20)
	near(ui.hud.position.length(), 0.0, 0.2, "resting sway")
	for i in 6:
		player.yaw -= 0.1  # Turning right.
		await frames(1)
	check(ui.hud.position.x < -1.0, "turning right drags the HUD left (x = %.2f)" % ui.hud.position.x)
	await frames(90)
	near(ui.hud.position.length(), 0.0, 0.3, "sway after settling")


func test_landing_knocks_hud_down() -> void:
	await frames(20)
	land(12.0)
	await frames(5)
	check(ui.hud.position.y > 1.0, "hard landing pushes the HUD down (y = %.2f)" % ui.hud.position.y)
	await frames(90)
	near(ui.hud.position.length(), 0.0, 0.3, "sway after settling")


func test_ui_motion_zero_keeps_hud_still() -> void:
	player.view_settings.ui_motion = 0.0
	await frames(2)
	for i in 6:
		player.yaw -= 0.1
		await frames(1)
	land(14.0)
	await frames(5)
	check(ui.hud.position == Vector2.ZERO, "HUD stays put (%s)" % ui.hud.position)
	check(is_zero_approx(ui.hud.rotation), "HUD doesn't lean")


func test_crosshair_bump_closes_again() -> void:
	land(14.0)
	check(ui.crosshair._bump > 0.5, "landing spreads the crosshair")
	await frames(30)
	near(ui.crosshair._bump, 0.0, 0.001, "spread after half a second")


func test_kick_dies_away() -> void:
	LofiUI.kick(ui.hud, 1.0)
	near(ui.layer._kick, 1.0, 0.001, "kick strength")
	await frames(30)
	near(ui.layer._kick, 0.0, 0.001, "kick after half a second")


# --- HUD elements ---------------------------------------------------------------

func test_killfeed_caps_and_expires() -> void:
	for i in 7:
		ui.hud.add_kill("you", "them", "hotkey", i == 3)
	await frames(30)
	check(ui.hud._killfeed.get_child_count() == GameHud.KILLFEED_MAX,
			"killfeed holds %d rows (has %d)" % [GameHud.KILLFEED_MAX, ui.hud._killfeed.get_child_count()])
	await frames(roundi((GameHud.KILLFEED_TIME + 0.5) * 60.0))
	check(ui.hud._killfeed.get_child_count() == 0, "rows expire (%d left)" % ui.hud._killfeed.get_child_count())


func test_popup_stamps_down_then_clears() -> void:
	ui.hud.popup("heartshot", LofiUI.Style.HEART)
	await frames(30)
	var rows := ui.hud._popup_anchor.get_children()
	check(rows.size() == 1, "one pop-up showing")
	if rows.size() == 1:
		var tiles := (rows[0] as Node).get_children().filter(func(c: Node) -> bool: return c is PanelContainer)
		check(tiles.size() == "heartshot".length() + 1, "a tile per letter, plus the heart")
		for tile: Control in tiles:
			near(tile.scale.x, 1.0, 0.01, "tile landed")
	ui.hud.popup("double kill")
	await frames(25)
	check(ui.hud._popup_anchor.get_child_count() == 1, "a new pop-up replaces the old one")
	await frames(90)
	check(ui.hud._popup_anchor.get_child_count() == 0, "pop-ups clear themselves")


func test_impact_rattles_and_zooms_the_hud_then_settles() -> void:
	player.view_settings.impact_frames = true
	await frames(10)
	ui.kill_confirmed(false)
	await frames(2)
	check(ui.hud.scale.x > 1.02, "HUD punches in (scale %.3f)" % ui.hud.scale.x)
	var rattled := ui.hud._groups().filter(func(c: Control) -> bool: return absf(c.rotation) > 0.01)
	check(rattled.size() >= 4, "groups rattle (%d)" % rattled.size())
	await frames(60)
	near(ui.hud.scale.x, 1.0, 0.001, "HUD scale settled")
	for c: Control in ui.hud._groups():
		near(c.rotation, 0.0, 0.001, "%s rotation settled" % c.name)


func test_health_rolls_and_heartbeat_follows_low_health() -> void:
	ui.hud.set_health(24)
	await frames(30)
	check(LofiUI.label_of(ui.hud._health).text == "24", "health rolled to 24")
	check(ui.hud._heartbeat != null, "heartbeat at low health")
	ui.hud.set_health(100)
	await frames(30)
	check(LofiUI.label_of(ui.hud._health).text == "100", "health rolled back to 100")
	check(ui.hud._heartbeat == null and ui.hud._health_row.scale == Vector2.ONE, "heartbeat stopped")


func test_prompt_can_show_again_while_hiding() -> void:
	ui.hud.show_prompt("e  pick up hotkey")
	await frames(20)
	ui.hud.hide_prompt()
	await frames(2)
	ui.hud.show_prompt("e  pick up overdraw")
	await frames(20)
	check(ui.hud._prompt.visible and is_equal_approx(ui.hud._prompt.modulate.a, 1.0), "prompt visible")


func test_alert_blinks_and_hides() -> void:
	ui.hud.set_alert("the map is unloading")
	var seen := {}
	for i in 60:
		await frames(1)
		seen[LofiUI.style_of(ui.hud._alert)] = true
	check(seen.has(LofiUI.Style.ALERT) and seen.has(LofiUI.Style.INVERTED), "alert blinks")
	ui.hud.set_alert("")
	await frames(20)
	check(not ui.hud._alert.visible, "alert hidden")


# --- Overlays and menus ---------------------------------------------------------

func test_countdown_card_finishes_and_clears() -> void:
	await frames(150)  # The start-up map card.
	var done := [false]
	ui.overlays.card_finished.connect(func() -> void: done[0] = true)
	ui.overlays.round_card("waiting room", 3)
	for i in 400:
		if done[0]:
			break
		await frames(1)
	check(done[0], "card_finished emitted")
	await frames(30)
	check(ui.overlays.get_child_count() == 0, "card cleared (%d left)" % ui.overlays.get_child_count())


func test_every_overlay_preview_cleans_up() -> void:
	await frames(150)
	for i in 4:
		ui.overlays.preview_next()
		await frames(60)
	await frames(360)
	check(ui.overlays.get_child_count() == 0, "overlays cleared (%d left)" % ui.overlays.get_child_count())


func test_pause_opens_and_closes() -> void:
	ui.pause.open()
	await frames(10)
	check(ui.pause.is_open and ui.pause.visible, "open")
	ui.pause.close()
	await frames(20)
	check(not ui.pause.is_open and not ui.pause.visible, "closed")
	ui.pause.open()
	ui.pause.close()
	ui.pause.open()
	await frames(20)
	check(ui.pause.visible and is_equal_approx(ui.pause.modulate.a, 1.0), "reopening cancels the closing fade")
	ui.pause.close()


func test_wipe_runs_middle_once_and_frees_itself() -> void:
	var hits := [0]
	var wipe := Wipe.run(get_tree(), func() -> void: hits[0] += 1)
	await frames(90)
	check(hits[0] == 1, "middle ran once (%d)" % hits[0])
	check(not is_instance_valid(wipe), "wipe freed")


# --- Impact frames (experimental) ------------------------------------------------

func smash(drop: float) -> void:
	player.movement_event.emit({"type": &"smash_impact", "drop": drop, "position": player.global_position, "slide": false})


func test_impact_frames_are_off_by_default() -> void:
	check(not ViewSettings.new().impact_frames, "setting defaults to off")
	ui.kill_confirmed(true)
	smash(15.0)
	await frames(1)
	check(not ui.impact.is_showing(), "nothing shows while off")


func test_impact_frames_on_kills_and_hard_smashdowns_only() -> void:
	player.view_settings.impact_frames = true
	smash(GameUI.SMASH_IMPACT_DROP - 1.0)
	await frames(1)
	check(not ui.impact.is_showing(), "an ordinary smashdown doesn't fire one")
	smash(GameUI.SMASH_IMPACT_DROP + 4.0)
	await frames(1)
	check(ui.impact.is_showing(), "a hard smashdown fires one")
	await frames(12)
	check(not ui.impact.is_showing(), "and it's gone within a few frames")
	await frames(30)
	ui.kill_confirmed(false)
	await frames(1)
	check(ui.impact.is_showing(), "a kill fires one")
	await frames(12)
	player.die()
	await frames(1)
	check(not ui.impact.is_showing(), "your own death doesn't")


func test_impact_frames_never_strobe() -> void:
	player.view_settings.impact_frames = true
	var shown := 0
	var was := false
	for i in 60:  # One second of kills every frame.
		ui.kill_confirmed(false)
		await frames(1)
		if ui.impact.is_showing() and not was:
			shown += 1
		was = ui.impact.is_showing()
	check(shown <= 2, "at most 2 impact frames a second (got %d)" % shown)


func test_impact_frame_punches_the_camera_and_settles() -> void:
	player.view_settings.impact_frames = true
	await frames(120)  # Let the fov ease in from the scene's default.
	var rest := Player.vfov_from_hfov_16_9(player.view_settings.fov_horizontal)
	near(player.camera.fov, rest, 0.05, "fov at rest")
	ui.kill_confirmed(false)
	await frames(1)
	check(player.camera.fov < rest - 2.0, "zooms in on the hit (%.1f -> %.1f)" % [rest, player.camera.fov])
	await frames(45)
	near(player.camera.fov, rest, 0.05, "fov once settled")
	player.view_settings.screen_shake = 0.0
	ui.kill_confirmed(false)
	await frames(1)
	check(ui.impact.is_showing(), "the frame still shows with screen shake off")
	near(player.camera.fov, rest, 0.05, "but the camera doesn't punch")


# --- Camera and speed lines -------------------------------------------------------

func test_smash_impact_slams_the_camera_then_settles() -> void:
	await frames(120)
	var rest := Player.vfov_from_hfov_16_9(player.view_settings.fov_horizontal)
	var eye := player.camera.global_position.y
	player._react({"type": &"smash_impact", "drop": 10.0, "position": player.global_position, "slide": false})
	await frames(6)
	check(player.camera.fov < rest - 3.0, "snaps in (%.1f -> %.1f)" % [rest, player.camera.fov])
	check(player.camera.global_position.y < eye - 0.1, "slams down (%.2f -> %.2f)" % [eye, player.camera.global_position.y])
	await frames(90)
	near(player.camera.fov, rest, 0.05, "fov settled")
	near(player.camera.global_position.y, eye, 0.01, "eye height settled")


func test_camera_motion_zero_turns_reactions_off() -> void:
	player.view_settings.camera_motion = 0.0
	player.view_settings.screen_shake = 0.0
	player.view_settings.landing_dip = false
	await frames(120)
	var before := player.camera.global_transform
	for type in [&"jump", &"slide_start", &"slam_bounce"]:
		player._react({"type": type})
	player._react({"type": &"dash", "direction": Vector3.RIGHT})
	await frames(4)
	check(player.camera.global_transform.is_equal_approx(before), "camera didn't move")


func test_speed_lines_follow_speed() -> void:
	await frames(20)
	near(ui.speed_lines.amount(), 0.0, 0.01, "none standing still")
	player.velocity = Vector3(0, 0, -20)
	await frames(40)
	check(ui.speed_lines.amount() > 0.6, "streaming at 20 m/s (%.2f)" % ui.speed_lines.amount())
	player.view_settings.speed_lines = false
	await frames(40)
	near(ui.speed_lines.amount(), 0.0, 0.01, "gone when switched off")
