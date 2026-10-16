extends SceneTree
## Build 030 screenshots. args: -- <out.png> <mode: cameo|lineup|score2> [id] [mobile 0|1]
func _initialize() -> void:
	create_timer(150.0).timeout.connect(func(): print("SHOT WATCHDOG"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var mode: String = a[1]
	var id: String = a[2] if a.size() > 2 else "tusk"
	var mobile := a.size() > 3 and a[3] == "1"
	var gp := root.get_node("GameProgress")
	root.get_node("TouchInput").active = mobile
	if mode in ["lineup", "score2"]:
		change_scene_to_file("res://scenes/Title.tscn")
		for i in 20: await process_frame
		var am = current_scene.find_child("AttractMode", true, false)
		am.show_page("cameos" if mode == "lineup" else "score2")
		for i in 260: await process_frame
	else:
		gp.reset_progress(); gp.current_level = 5
		change_scene_to_file("res://scenes/Main.tscn")
		for i in 60: await process_frame
		root.get_node("BetaTools").god = true
		await create_timer(4.5).timeout
		var lc = get_first_node_in_group("level_controller")
		lc.cameo_director.timer = 999.0
		var pl: Node2D = get_first_node_in_group("player")
		if mobile:
			pl.facing = Vector2(0.70710678, -0.70710678)
		var c = lc.cameo_director.spawn(id)
		c.global_position = pl.global_position + Vector2(150, -30)
		for i in 60: await process_frame
		c.global_position = pl.global_position + Vector2(150, -30)
		if id == "bozos":
			c._act_t = 0.0
			for i in 20: await process_frame
			c._act_t = 0.0
		elif id == "tusk":
			c._act_t = 0.0
			for i in 6: await process_frame
		elif id == "zuckerbot":
			c._act_t = 0.0
			for i in 25: await process_frame
			c.receive_whip(pl.global_position, 0.0)
		c._say(c.info()["quips"][0])
		for i in 8: await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
