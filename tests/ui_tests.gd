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
		ui.hud.add_kill("you", "them", "marshal .357", i == 3)
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
	ui.hud.show_prompt("e  pick up marshal .357")
	await frames(20)
	ui.hud.hide_prompt()
	await frames(2)
	ui.hud.show_prompt("e  pick up rl-5")
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


# --- Settings -------------------------------------------------------------------

## A fresh settings file for one test (the runner's own, emptied).
func fresh_settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	InputMap.load_from_project_settings()
	Settings.forget()


func saved() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(Settings.path)
	return cfg


func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func test_settings_save_only_what_you_changed() -> void:
	fresh_settings()
	var view := Settings.view()
	check(view.fov_horizontal == Settings.defaults().fov_horizontal and view != Settings.defaults(),
			"your view settings start as the defaults (a copy of them)")
	view.fov_horizontal = 110.0
	view.impact_frames = true
	Settings.save_view()
	var cfg := saved()
	check(cfg.get_section_keys("view").size() == 2 and cfg.get_value("view", "fov_horizontal") == 110.0,
			"only the two changed are saved (%s)" % cfg.get_section_keys("view"))
	Settings.forget()
	check(Settings.view().fov_horizontal == 110.0 and Settings.view().impact_frames, "and read back next time")
	Settings.reset_view(["fov_horizontal"])
	check(not saved().has_section_key("view", "fov_horizontal") and Settings.view().fov_horizontal == Settings.defaults().fov_horizontal,
			"a reset puts it back and forgets it")
	# A hand-edited file can't break anything.
	cfg = saved()
	cfg.set_value("view", "fov_horizontal", "wide")
	cfg.set_value("view", "no_such_setting", 3)
	cfg.set_value("view", "sensitivity", 2)
	cfg.save(Settings.path)
	Settings.forget()
	check(Settings.view().fov_horizontal == Settings.defaults().fov_horizontal and Settings.view().sensitivity == 2.0,
			"wrong types and unknown names are skipped; a whole number is fine for a decimal")
	fresh_settings()


func test_keys_rebind_take_over_and_come_back() -> void:
	fresh_settings()
	check(Settings.input_name(Settings.binding(&"jump", 0)) == "space" and Settings.input_name(Settings.binding(&"jump", 1)) == "wheel down",
			"jump: space and the wheel (%s, %s)" % [Settings.input_name(Settings.binding(&"jump", 0)), Settings.input_name(Settings.binding(&"jump", 1))])
	check(Settings.bind(&"jump", 0, key(KEY_F)) == &"" and InputMap.action_has_event(&"jump", key(KEY_F)),
			"jump rebound to f")
	check(not InputMap.action_has_event(&"jump", key(KEY_SPACE)), "space is off it")
	var taken := Settings.bind(&"dash", 0, key(KEY_F))
	check(taken == &"jump" and not InputMap.action_has_event(&"jump", key(KEY_F)) and InputMap.action_has_event(&"dash", key(KEY_F)),
			"binding f to dash takes it off jump (from %s)" % taken)
	Settings.unbind(&"crouch", 0)
	check(Settings.binding(&"crouch", 0) != null and Settings.input_name(Settings.binding(&"crouch", 0)) == "c",
			"clearing crouch's first key leaves c")
	check(saved().get_value("keys", "dash")[0] == "key:%d" % KEY_F, "saved as the physical key")
	# Next run: the saved keys come back.
	InputMap.load_from_project_settings()
	Settings.forget()
	Settings.apply_saved()
	check(InputMap.action_has_event(&"dash", key(KEY_F)) and not InputMap.action_has_event(&"jump", key(KEY_F)),
			"read back and put into effect")
	Settings.reset_keys()
	check(InputMap.action_has_event(&"jump", key(KEY_SPACE)) and not saved().has_section("keys"), "defaults put every key back")
	fresh_settings()


func test_display_and_volume_apply_and_save() -> void:
	fresh_settings()
	Settings.set_fps_cap(144)
	Settings.set_volume(0.5)
	check(Engine.max_fps == 144 and saved().get_value("display", "fps_cap") == 144, "frame cap applied and saved")
	near(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 0.01, "volume in dB")
	Settings.set_volume(0.0)
	check(AudioServer.is_bus_mute(0), "silent at 0")
	Engine.max_fps = 0
	Settings.forget()
	Settings.apply_saved()
	check(Engine.max_fps == 144 and AudioServer.is_bus_mute(0), "put back into effect next run")
	Settings.set_fps_cap(0)
	Settings.set_volume(1.0)
	fresh_settings()



func test_graphics_settings_save_and_the_presets_set_them_all() -> void:
	fresh_settings()
	check(Graphics.preset() == "high", "out of the box: high")
	Settings.set_graphics_preset("low")
	check(Graphics.shadows == Graphics.Shadows.OFF and not Graphics.extra_lamps and not Graphics.detail
			and not Graphics.effects and not Graphics.bloom, "low turns it all down")
	Settings.set_graphics("bloom", true)
	check(Graphics.bloom and Graphics.preset() == "", "one changed on its own: a custom mix")
	Settings.set_shadows(Graphics.Shadows.LOW)
	var cfg := saved()
	check(int(cfg.get_value("graphics", "shadows")) == Graphics.Shadows.LOW and cfg.get_value("graphics", "bloom") == true
			and cfg.get_value("graphics", "detail") == false, "saved as they change")
	Settings.forget()
	check(Graphics.preset() == "high", "(reloaded: the defaults again)")
	Settings.apply_saved()
	check(Graphics.shadows == Graphics.Shadows.LOW and Graphics.bloom and not Graphics.detail, "and read back next time")
	Settings.set_graphics_preset("high")
	fresh_settings()


func test_settings_page_every_tab_and_a_key() -> void:
	fresh_settings()
	var page := SettingsMenu.new()
	ui.layer.canvas.add_child(page)
	await frames(2)
	for i in SettingsMenu.TABS.size():
		page.show_tab(i)
		await frames(2)
		check(page._card.get_child_count() == 1 and page._tabs[i].button_pressed, "%s tab shows" % SettingsMenu.TABS[i])
	# Camera: the field of view slider's arrow, then a toggle.
	page.show_tab(SettingsMenu.TABS.find("camera"))
	await frames(2)
	var fov_row: HBoxContainer = page._card.find_children("*", "HBoxContainer", true, false) \
			.filter(func(r: HBoxContainer) -> bool: return r.has_meta(&"bar"))[0]
	(fov_row.get_child(2) as Button).pressed.emit()
	check(Settings.view().fov_horizontal == Settings.defaults().fov_horizontal + 1.0 and saved().has_section_key("view", "fov_horizontal"),
			"its > arrow widens the view a degree, saved (%.0f)" % Settings.view().fov_horizontal)
	# Keys: click jump's first slot, press g.
	page.show_tab(SettingsMenu.TABS.find("keys"))
	await frames(2)
	var slot: Button = page._slots[&"jump"][0]
	slot.pressed.emit()
	check(page.capturing() and slot.text == "...", "waiting for a key")
	page._input(key(KEY_G))
	check(not page.capturing() and InputMap.action_has_event(&"jump", key(KEY_G)) and slot.text == "g", "g is jump now")
	slot.pressed.emit()
	page._input(key(KEY_ESCAPE))
	check(InputMap.action_has_event(&"jump", key(KEY_G)), "esc leaves it as it was")
	(page._slots[&"dash"][0] as Button).pressed.emit()
	page._input(key(KEY_G))
	check(not InputMap.action_has_event(&"jump", key(KEY_G)) and page._status.visible, "taking jump's key says so")
	page.reset_tab()
	check(InputMap.action_has_event(&"jump", key(KEY_SPACE)) and (page._slots[&"jump"][0] as Button).text == "space",
			"defaults on the keys tab puts them back")
	var went := []
	page.back.connect(func() -> void: went.append(true))
	page.escape()
	check(went.size() == 1, "esc goes back")
	page.queue_free()
	fresh_settings()


func test_pause_menu_opens_settings_and_esc_comes_back() -> void:
	ui.pause.open()
	await frames(5)
	ui.pause.open_settings()
	await frames(3)
	check(ui.pause._settings != null and not ui.pause._panel.visible, "settings in the menu's place")
	ui.pause.toggle()  # Esc.
	await frames(3)
	check(ui.pause._settings == null and ui.pause._panel.visible and ui.pause.is_open, "esc: back to the menu, still paused")
	ui.pause.close()
	fresh_settings()


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


func test_camera_smoothing_snaps_or_eases() -> void:
	await frames(120)
	var rest := player.camera.fov
	player._react({"type": &"slam_bounce"})
	await frames(1)
	var snappy_first := player.camera.fov - rest
	check(snappy_first > 9.0, "snappy: the kick lands on the first frame (+%.1f)" % snappy_first)
	await frames(60)
	near(player.camera.fov, rest, 0.05, "snappy kick gone")
	player.view_settings.camera_smoothing = 1.0
	player._react({"type": &"slam_bounce"})
	await frames(1)
	var smooth_first := player.camera.fov - rest
	await frames(5)
	var smooth_later := player.camera.fov - rest
	check(smooth_first < snappy_first * 0.6, "smooth: it starts small (+%.1f)" % smooth_first)
	check(smooth_later > smooth_first, "and builds (+%.1f)" % smooth_later)


# --- Weapons ----------------------------------------------------------------

func test_ammo_column_follows_the_gun_in_hand() -> void:
	var meter: AmmoMeter = ui.hud._ammo
	check(not meter.visible, "no column for fists")
	check(ui.crosshair.capacity == 0, "no ring for fists")
	player.weapons.give(Weapons.get_def(Weapons.REVOLVER))
	await frames(30)
	check(meter.visible and meter.capacity == 6 and meter.ammo == 6, "a six-shooter's column")
	near(meter._height, AmmoMeter.height_for(6), 0.5, "grown to its size")
	check(ui.crosshair.capacity == 6 and ui.crosshair.ammo == 6, "and its ring")
	var short := meter._height
	player.weapons.give(Weapons.get_def(Weapons.SMG))
	await frames(30)
	check(meter._height > short * 2.0, "an SMG's column is far taller (%.0f vs %.0f px)" % [meter._height, short])
	player.weapons.primary_ammo = 3
	player.weapons.ammo_changed.emit(3, 50)
	await frames(2)
	check(meter.ammo == 3 and meter.is_low(), "low ammo shows")
	check(ui.crosshair.ammo == 3, "the ring follows")
	player.weapons.reset()
	await frames(2)
	check(not meter.visible and ui.crosshair.capacity == 0, "gone again with fists")


func test_hits_and_kills_reach_the_crosshair_and_killfeed() -> void:
	var w := player.weapons
	w.hit_confirmed.emit({"zone": &"head", "killed": false})
	check(ui.crosshair._mark_time > 0.0 and ui.crosshair._mark_color == Color(1.0, 0.9, 0.3), "a headshot marker")
	w.hit_confirmed.emit({"zone": &"heart", "killed": true, "heartshot": true, "name": "dummy",
			"weapon": Weapons.get_def(Weapons.PISTOL)})
	await frames(2)
	check(ui.crosshair._mark_color == LofiUI.HEART, "a heartshot marker")
	check(ui.hud._killfeed.get_child_count() == 1, "and a killfeed line")



func test_hits_point_round_the_crosshair_to_whoever_shot() -> void:
	var shooter: Player = load("res://scenes/player.tscn").instantiate()
	shooter.human_controlled = false
	shooter.movement_params = MovementParams.new()
	shooter.view_settings = ViewSettings.new()
	world.add_child(shooter)
	shooter.global_position = player.global_position + Vector3(8, 0, 0)  # On your right (you face -z).
	await frames(3)
	var shot := func() -> void:
		player.take_hit({"damage": 10.0, "zone": &"body", "part": &"chest", "point": player.global_position + Vector3.UP,
				"normal": Vector3.RIGHT, "direction": Vector3.LEFT, "attacker": shooter, "weapon": Weapons.get_def(Weapons.PISTOL)})
	shot.call()
	var angles := ui.crosshair.hurt_angles()
	check(angles.size() == 1, "a hit puts an arc round the crosshair")
	near(angles[0], PI * 0.5, 0.1, "on the right, where they are")
	player.yaw -= PI * 0.5  # Turn right, to face them.
	await frames(2)
	near(ui.crosshair.hurt_angles()[0], 0.0, 0.1, "turn to face them and it points straight up")
	shooter.global_position = player.global_position + Vector3(-8, 0, 0)
	await frames(2)
	check(absf(ui.crosshair.hurt_angles()[0]) > PI - 0.1, "they go round behind you, and it follows them down")
	shot.call()
	check(ui.crosshair.hurt_angles().size() == 1, "another hit from them renews theirs, no second arc")
	player.show_hurt(70.0, 10.0, player.global_position + Vector3.UP, Vector3.BACK, &"body", &"chest", false)
	check(ui.crosshair.hurt_angles().size() == 2, "a hit the server sends (nobody's) gets one too")
	near(ui.crosshair.hurt_angles()[1], -PI * 0.5, 0.1, "back along the shot: from the left of you")
	await frames(int((Crosshair.HURT_TIME + 0.1) * 60.0))
	check(ui.crosshair.hurt_angles().is_empty(), "and they fade")
	shot.call()
	player.respawned.emit()
	check(ui.crosshair.hurt_angles().is_empty(), "back from the dead, none left over")


func test_boxes_are_drawn_like_the_logo() -> void:
	var a := LofiUI.box("hi")
	var style := a.get_theme_stylebox(&"panel") as PaperBox
	check(style != null, "boxes are paper cards")
	check(style.paper == Color.WHITE and style.frame == Color.BLACK, "a white card with a black frame")
	check(style.content_margin_left > style.margin * 1.4 + 1.0 and style.content_margin_top > style.margin * 1.4 + 1.0,
			"the text sits inside the frame, which sits inside the card")
	LofiUI.restyle(a, LofiUI.Style.INVERTED)
	var inverted := a.get_theme_stylebox(&"panel") as PaperBox
	check(inverted.fill == LofiUI.BLACK and inverted.paper == Color.WHITE, "inverted: black inside the frame, the card still white around it")
	check(inverted.hand == style.hand, "restyling keeps the box's shape")
	var b := LofiUI.box("hi")
	check((b.get_theme_stylebox(&"panel") as PaperBox).hand != style.hand, "each box is a little off in its own way")
	var big := LofiUI.box("x", LofiUI.HUGE)
	check((big.get_theme_stylebox(&"panel") as PaperBox).margin > style.margin, "bigger text, more card around the frame")
	var button := LofiUI.button("go", func() -> void: pass)
	var hover := button.get_theme_stylebox(&"hover") as PaperBox
	var normal := button.get_theme_stylebox(&"normal") as PaperBox
	check(hover.hand == normal.hand and hover.fill == LofiUI.BLACK and hover.shadow > 0.0, "a hovered button inverts and lifts, same shape")
	check(is_equal_approx(hover.content_margin_left + hover.content_margin_right, normal.content_margin_left + normal.content_margin_right),
			"and doesn't change size")
	for n: Node in [a, b, big, button]:
		n.free()
