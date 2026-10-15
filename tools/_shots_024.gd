extends SceneTree
## Build 024 screenshots. args: -- <out.png> <mode: subtle|open|reward|mobile> [level]
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var mode: String = a[1]
	var lv := int(a[2]) if a.size() > 2 else 2
	var gp := root.get_node("GameProgress")
	var ti := root.get_node("TouchInput")
	if mode == "mobile": ti.active = true
	gp.reset_progress()
	gp.current_level = lv
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 30: await process_frame
	root.get_node("BetaTools").god = true
	var lc = get_first_node_in_group("level_controller")
	var g = lc.get_node("Ground")
	var sc = lc.secrets
	var s: Dictionary = sc.specs[0]
	for sp in sc.specs:
		if sp["subtle"] == (mode == "subtle" or mode == "mobile"): s = sp; break
	var door: Node2D = null
	for d in get_nodes_in_group("secret_doors"):
		if d.spec["id"] == s["id"]: door = d
	for e in get_nodes_in_group("cantifa"): e.queue_free()
	var pl := get_first_node_in_group("player") as Node2D
	var outside: Vector2 = g.to_global(g.tile_center(s["out"]))
	var dpos := door.global_position
	pl.global_position = outside + (outside - dpos).normalized() * 20.0
	pl.facing = (dpos - outside).normalized()
	for i in 260: await process_frame
	var cam := root.get_viewport().get_camera_2d()
	if cam:
		cam.position_smoothing_enabled = false
		cam.zoom = Vector2(1.5, 1.5) if mode == "mobile" else Vector2(2.2, 2.2)
	if cam and mode == "subtle":
		pl.global_position = outside + (outside - dpos).normalized() * 70.0
		cam.zoom = Vector2(3.2, 3.2)
		cam.offset = (dpos - pl.global_position) * 0.6
	for i in 10: await process_frame
	if mode != "subtle":
		SecretDoor.on_crack(self, pl.global_position, dpos, false)
		for i in 6: await process_frame
		if mode == "mobile":
			root.get_texture().get_image().save_png(out.replace(".png", "-hit.png"))
		SecretDoor.on_crack(self, pl.global_position, dpos, false)
		for i in (14 if mode != "reward" else 70): await process_frame
	if mode == "reward":
		var rw = get_first_node_in_group("secret_rewards")
		pl.global_position = rw.global_position + Vector2(0, 26)
		rw.claim()
		for i in 8: await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " ", s["id"], " subtle=", s["subtle"], " reward=", s["reward"], " touch=", ti.active)
	quit()
