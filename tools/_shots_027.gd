extends SceneTree
## Build 027 screenshots. args: -- <out.png> <mode: hud|mobile|biome|boss9|boss10|fired|ending|credits|choice> [level]
func _initialize() -> void:
	create_timer(150.0).timeout.connect(func(): print("SHOT WATCHDOG"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var mode: String = a[1]
	var lv := int(a[2]) if a.size() > 2 else 27
	var gp := root.get_node("GameProgress")
	var ti := root.get_node("TouchInput")
	ti.active = mode == "mobile"
	if mode in ["boss9", "boss10", "fired"]:
		change_scene_to_file(gp.start_at_stage("boss9" if mode == "boss9" else "boss10"))
	elif mode in ["ending", "credits", "choice"]:
		gp.reset_progress(); gp.score = 1234560
		change_scene_to_file("res://scenes/ui/Ending.tscn")
	else:
		gp.reset_progress()
		gp.current_level = lv
		change_scene_to_file("res://scenes/Main.tscn")
	for i in 40: await process_frame
	if mode in ["ending", "credits", "choice"]:
		var en = current_scene
		if mode == "ending":
			for i in 200: await process_frame
		else:
			en.skip()
			if mode == "choice":
				en.skip()
			for i in (300 if mode == "credits" else 30): await process_frame
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
		quit()
		return
	root.get_node("BetaTools").god = true
	var pl := get_first_node_in_group("player") as Node2D
	var pu = pl.get_node("PowerUps")
	if mode in ["hud", "mobile"]:
		pl.maximum_health = 16; pl.health = 13
		var lc = get_first_node_in_group("level_controller")
		lc.hud.set_health(13, 16)
		pu.grant("armor")
		pu.grant("fire_whip")
	if mode in ["boss9", "boss10", "fired"]:
		var b = get_first_node_in_group("boss")
		for i in 200: await process_frame
		if b != null:
			var atk: Array = ["tanks", "judo", "quake"] if mode == "boss9" else (["drives", "walls", "crowd"] if mode == "boss10" else [])
			b.hearts = 20 if mode == "boss9" else 22
			if mode == "fired":
				b.hearts = LevelConfig.BOSS10_RAGE_HEARTS + 1
				b.take_hit(1, "whip", pl.global_position)
				atk = ["fired", "drives"]
			for k in atk:
				b.force_attack(k)
				for i in 30: await process_frame
	for i in 50: await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
