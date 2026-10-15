extends SceneTree
## Build 027 quick smoke: boots boss 9/10, fires every attack, and the L24/L27/L30 biome levels.
func _initialize() -> void:
	create_timer(200.0).timeout.connect(func(): print("SMOKE WATCHDOG"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var gp := root.get_node("GameProgress")
	for st in ["boss9", "boss10"]:
		gp.reset_progress()
		change_scene_to_file(gp.start_at_stage(st))
		for i in 240: await physics_frame
		var b = get_first_node_in_group("boss")
		print(st, " boss=", b.name if b else "none", " hearts=", b.hearts if b else -1, " state=", b.state_name() if b else "")
		var p = get_first_node_in_group("player")
		for k in (["tanks", "judo", "quake", "envelopes", "reset", "sheep"] if st == "boss9" else ["drives", "walls", "crowd", "fired", "envelopes", "reset"]):
			b.force_attack(k)
			for i in 150: await physics_frame
			print("  ", k, " fired=", b.attacks_fired.get(k, 0), " hazards=", get_nodes_in_group("hazard027").size(), " poutine=", get_nodes_in_group("poutine").size(), " inv=", snappedf(p.invert_time, 0.1), " hp=", p.health)
			p.health = p.maximum_health
	for lv in [24, 27, 30, 31]:
		gp.reset_progress()
		gp.current_level = lv
		change_scene_to_file("res://scenes/Main.tscn")
		for i in 40: await process_frame
		var lc = get_first_node_in_group("level_controller")
		var g = lc.get_node("Ground")
		print("L", lv, " theme=", g.theme, " props=", lc.get_node("Entities/Props").get_used_cells().size(), " music=", lc.get("music_track"))
	print("SMOKE DONE")
	quit()
