extends SceneTree
## Build 023 screenshot: Cantifa group firing first. args: -- <out.png> [level]
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var lv := int(a[1]) if a.size() > 1 else 12
	var gp := root.get_node("GameProgress")
	gp.reset_progress()
	gp.current_level = lv
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 20: await process_frame
	var bt := root.get_node("BetaTools")
	bt.god = true
	var lc = get_first_node_in_group("level_controller")
	for c in get_nodes_in_group("cantifa"): c.queue_free()
	await physics_frame
	var squad: Array = []
	for i in 5:
		squad.append(lc.spawn_cantifa_from_edge())
	for c in squad:    # skip the walk-in for the picture
		c.global_position = c.post_pos
		c.arriving = false
	var pl := get_first_node_in_group("player") as Node2D
	var center: Vector2 = lc._cantifa_rally["pos"]
	var best := Vector2.ZERO
	for ang in range(0, 360, 15):
		var p := center + Vector2.from_angle(deg_to_rad(ang)) * 230.0
		pl.global_position = p
		await physics_frame
		await physics_frame
		var clear := 0
		for c in squad:
			if c._clear_line(pl): clear += 1
		if clear >= 4:
			best = p
			break
	pl.global_position = best if best != Vector2.ZERO else center + Vector2(230, 0)
	bt._refresh_tag()
	var t := 0.0
	while t < 4.0:
		await process_frame
		t += 0.016
		if get_nodes_in_group("cantifa_bullets").size() >= 3 and t > 1.0:
			break
	await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " bullets=", get_nodes_in_group("cantifa_bullets").size())
	quit()
