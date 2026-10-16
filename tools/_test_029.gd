extends SceneTree
## Build 029 checks: touch facing = nearest equal 45-degree sector of the
## real-time stick angle (every frame), simulated touch diagonal whip, wedge
## still fires, keyboard facing unchanged (PC), touch reticle direction.
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("PASS " if c else "FAIL ") + m)
	if not c: fails += 1
func _initialize() -> void:
	create_timer(200.0).timeout.connect(func(): print("FAIL watchdog"); quit(2))
	_run.call_deferred()
func _frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func _ev(e: InputEvent) -> void:
	Input.parse_input_event(e)
	await _frames(2)
func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = idx; e.pressed = pressed
	e.position = root.get_final_transform() * pos
	await _ev(e)
func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = idx
	e.position = root.get_final_transform() * pos
	await _ev(e)
func _near_boundary(deg: float, h: float) -> bool:
	var m := fposmod(deg - 22.5, 45.0)
	return m < h or m > 45.0 - h

func _run() -> void:
	var gp := root.get_node("GameProgress")
	var ti := root.get_node("TouchInput")
	gp.reset_progress(); gp.current_level = 1
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 40: await process_frame
	root.get_node("BetaTools").god = true
	ti.active = true; ti.forced = true
	await _frames(3)
	var tc = current_scene.find_child("TouchControls", true, false)
	if tc != null and not tc.has_method("joy_center"):
		for ch in tc.find_children("*", "Control", true, false):
			if ch.has_method("joy_center"): tc = ch; break
	var pl = get_first_node_in_group("player")
	var whip = pl.get_node("Whip") if pl.has_node("Whip") else pl.find_child("Whip", true, false)
	ok(tc != null and pl != null and whip != null, "scene ready")
	var c: Vector2 = tc.joy_center()
	var R: float = tc.JOYSTICK_RADIUS
	# 1. sweep stick 0..355 in 5 deg steps (one finger, continuous drag)
	await _touch(0, c + Vector2(R * 0.8, 0), true)
	var bad := 0
	var checked := 0
	for k in 72:
		var deg := k * 5.0
		await _drag(0, c + Vector2.from_angle(deg_to_rad(deg)) * R * 0.8)
		if _near_boundary(deg, 4.5): continue
		checked += 1
		var want: Vector2 = pl.snap_8(Vector2.from_angle(deg_to_rad(deg)))
		if not pl.facing.is_equal_approx(want):
			bad += 1; print("  sweep miss at ", deg, " facing ", pl.facing)
	ok(bad == 0, "sweep: facing = nearest 45 sector at %d/%d stick angles" % [checked - bad, checked])
	# every sector equally wide: count angles mapping to each of 8 dirs (1 deg)
	var counts := {}
	for d in 360:
		var s: Vector2 = pl.snap_8(Vector2.from_angle(deg_to_rad(d + 0.25)))
		var key := wrapi(roundi(s.angle() / (PI / 4.0)), 0, 8)
		counts[key] = counts.get(key, 0) + 1
	var eq := counts.size() == 8
	for v in counts.values(): eq = eq and v == 45
	ok(eq, "8 sectors, each exactly 45 deg wide")
	# 2. same-frame response: snap from right to a diagonal without lag
	await _drag(0, c + Vector2(R * 0.8, 0))
	await _drag(0, c + Vector2.from_angle(deg_to_rad(40)) * R * 0.8)
	ok(pl.facing.is_equal_approx(Vector2(0.70710678, 0.70710678)), "stick 0->40 deg: diagonal facing within 2 frames")
	# 3. release drift toward centre does not flick facing
	await _drag(0, c + Vector2.from_angle(deg_to_rad(10)) * R * 0.15)
	await _touch(0, c + Vector2.from_angle(deg_to_rad(10)) * R * 0.15, false)
	ok(pl.facing.is_equal_approx(Vector2(0.70710678, 0.70710678)), "release drift near centre keeps diagonal")
	# 4. diagonal whip with simulated touches: stick held at 35 deg (thumb 1)
	#    while thumb 2 taps WHIP; a sheep sits down-right at 45 deg.
	var sheep_scene: PackedScene = load("res://scenes/sheep/Sheep.tscn")
	for s0 in get_nodes_in_group("whippable"):
		if s0 is Node2D and (s0 as Node2D).global_position.distance_to(pl.global_position) < 400: s0.queue_free()
	await _frames(2)
	var results := []
	for case in [[35.0, 45.0], [128.0, 135.0], [-130.0, -135.0], [-50.0, -45.0]]:
		var stick: float = case[0]; var tgt_deg: float = case[1]
		var sh: Node2D = sheep_scene.instantiate()
		current_scene.add_child(sh)
		sh.global_position = pl.global_position + Vector2.from_angle(deg_to_rad(tgt_deg)) * 110.0
		sh.set_physics_process(false); sh.set_process(false)
		await _frames(2)
		await _touch(0, c + Vector2.from_angle(deg_to_rad(stick)) * R * 0.85, true)
		whip.cooldown = 0.0
		var poly: PackedVector2Array = tc.primary_poly()
		await _touch(1, TouchLayout.centroid(poly), true)
		await _touch(1, TouchLayout.centroid(poly), false)
		await _touch(0, c, false)
		var ang := rad_to_deg((whip.whip_end - pl.global_position).angle())
		var hit := (whip.whip_end as Vector2).distance_to(sh.global_position) < 40.0
		ok(absf(wrapf(ang - tgt_deg, -180, 180)) < 22.5 and hit, "touch diagonal whip stick %d -> lash %d deg, hit=%s" % [stick, roundi(ang), hit])
		if is_instance_valid(sh): sh.queue_free()
		await _frames(25)
	# 5. no target: lash goes exactly along the snapped diagonal
	for s0 in get_nodes_in_group("whippable"):
		if s0 is Node2D and (s0 as Node2D).global_position.distance_to(pl.global_position) < 500: s0.queue_free()
	await _frames(2)
	await _touch(0, c + Vector2.from_angle(deg_to_rad(-140)) * R * 0.85, true)
	whip.cooldown = 0.0
	await _touch(1, TouchLayout.centroid(tc.primary_poly()), true)
	await _touch(1, TouchLayout.centroid(tc.primary_poly()), false)
	await _touch(0, c, false)
	var a2 := rad_to_deg((whip.whip_end - pl.global_position).angle())
	ok(absf(wrapf(a2 + 135.0, -180, 180)) < 1.0, "empty field: lash exactly at snapped -135 (got %.1f)" % a2)
	# 6. reticle on touch reports the snapped direction
	var ret = get_first_node_in_group("reticle")
	if ret == null:
		for n in current_scene.find_children("*", "", true, false):
			if n.get_script() != null and String(n.get_script().resource_path).ends_with("reticle.gd"): ret = n; break
	if ret != null and not ret.info.is_empty():
		ok((ret.info["dir"] as Vector2).is_equal_approx(pl.facing), "touch reticle dir == snapped facing")
	else:
		ok(false, "reticle found")
	# 7. PC keyboard: raw snap_8 unchanged
	ti.active = false; ti.forced = false
	var e := InputEventKey.new(); e.keycode = KEY_D; e.physical_keycode = KEY_D; e.pressed = true
	await _ev(e)
	var e2 := InputEventKey.new(); e2.keycode = KEY_S; e2.physical_keycode = KEY_S; e2.pressed = true
	await _ev(e2)
	ok(pl.facing.is_equal_approx(Vector2(0.70710678, 0.70710678)), "PC D+S -> diagonal facing (unchanged)")
	e.pressed = false; e2.pressed = false
	await _ev(e); await _ev(e2)
	print("RESULT 029: ", "ALL PASS" if fails == 0 else "%d FAIL" % fails)
	quit(fails)
