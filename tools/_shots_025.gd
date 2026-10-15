extends SceneTree
## Build 025 screenshots. args: -- <out.png> <mode: hud|mobile|armor|biome|boss7|boss8|secret> [level]
func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): print("SHOT WATCHDOG"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var mode: String = a[1]
	var lv := int(a[2]) if a.size() > 2 else 18
	var gp := root.get_node("GameProgress")
	var ti := root.get_node("TouchInput")
	ti.active = a.has("touch") or mode == "mobile"
	if mode == "boss7" or mode == "boss8":
		change_scene_to_file(gp.start_at_stage(mode))
	else:
		gp.reset_progress()
		gp.current_level = lv
		change_scene_to_file("res://scenes/Main.tscn")
	for i in 40: await process_frame
	root.get_node("BetaTools").god = true
	var pl := get_first_node_in_group("player") as Node2D
	var pu = pl.get_node("PowerUps")
	if mode in ["hud", "mobile", "armor", "secret"]:
		pu.grant("armor")
		pu.grant("fire_whip")
		if mode != "armor":
			pu.grant("invincible")
	if mode == "secret":
		var lc = get_first_node_in_group("level_controller")
		lc.hud.show_toast("SECRET FOUND!")
	var lc2 = get_first_node_in_group("level_controller")
	if lc2 == null: lc2 = get_first_node_in_group("boss_level")
	if mode == "boss7" or mode == "boss8":
		var b = get_first_node_in_group("boss")
		for i in 200: await process_frame
		if b != null:
			var atk := ["orbital", "satbeam", "ufo"] if mode == "boss7" else ["drones", "swarm", "drones"]
			b.hearts = 16 if mode == "boss7" else 12
			for k in atk:
				b.force_attack(k)
				for i in 25: await process_frame
	for i in 60: await process_frame
	var cam := root.get_viewport().get_camera_2d()
	if mode == "armor":
		for i in 300: await process_frame
	if cam and mode == "armor":
		cam.position_smoothing_enabled = false
		cam.zoom = Vector2(3.0, 3.0)
		for i in 5: await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
