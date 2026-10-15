extends SceneTree
## Build 023 checks: biome music, Cantifa (shoot first / congregate / ramp),
## internal tool 6969, docs. Spinning-human detection lives in _spin_023.gd.
const LC := preload("res://scripts/level_config.gd")
var fails := 0

func ok(c: bool, m: String) -> void:
	print(("PASS " if c else "FAIL ") + m)
	if not c: fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await physics_frame
		t += 1.0 / 60.0

func _load(scene: String, lv: int) -> Node:
	var gp := root.get_node("GameProgress")
	gp.reset_progress()
	gp.current_level = lv
	change_scene_to_file(scene)
	for i in 8: await physics_frame
	return get_first_node_in_group("level_controller")

func _run() -> void:
	var ga := root.get_node("GameAudio")
	var bt := root.get_node("BetaTools")
	# ---------------- music
	var seen := {}
	for lv in [1, 3, 6, 9, 12, 15, 18]:
		var lc = await _load(LC.GAME_SCENE, lv)
		var th: String = LC.theme_for(lv)
		ok(ga.TRACKS.has("level_" + th), "track exists level_%s" % th)
		ok(ga.track == "level_" + th, "L%d plays level_%s (got %s)" % [lv, th, ga.track])
		seen[ga.track] = true
	ok(seen.size() == 6, "six different biome tracks heard (%d)" % seen.size())
	var lcb = await _load(LC.BOSS_SCENE, 2)
	ok(String(ga.track).begins_with("boss"), "boss arena keeps its boss track (%s)" % ga.track)
	var lcn = await _load(LC.BONUS_SCENE, 2)
	ok(ga.track == "bonus", "bonus stage keeps bonus track (%s)" % ga.track)
	var bus := FileAccess.get_file_as_string("res://default_bus_layout.tres")
	var bus_old := FileAccess.get_file_as_string("/workspace/backups/stsh-game-022-src-pre023/default_bus_layout.tres")
	ok(bus == bus_old, "bus layout unchanged")
	ok(ga.LEVELS == [1.0, 0.4, 0.0] and ga.LEVEL_NAMES.size() == 3, "mute toggle levels unchanged")

	# ---------------- cantifa ramp
	ok(LC.cantifa_cap(3) == 0 and LC.cantifa_cap(4) == 3 and LC.cantifa_cap(8) == 5, "caps unchanged up to L8")
	ok(LC.cantifa_cap(9) == 6 and LC.cantifa_cap(13) == 8 and LC.cantifa_cap(17) == 10 and LC.cantifa_cap(30) == 10, "caps ramp above L8 to 10")
	ok(LC.cantifa_spawn_every(8) == 5 and LC.cantifa_spawn_every(9) == 4 and LC.cantifa_spawn_every(12) == 3 and LC.cantifa_spawn_every(40) == 3, "spawn ratio 1/5 -> 1/4 (L9) -> 1/3 (L12+)")
	var mono := true
	for l in range(4, 30):
		if LC.cantifa_cap(l + 1) < LC.cantifa_cap(l) or LC.cantifa_spawn_every(l + 1) > LC.cantifa_spawn_every(l): mono = false
	ok(mono, "ramp is gradual / monotonic")

	# ---------------- cantifa congregate + shoot first
	var lc = await _load(LC.GAME_SCENE, 12)
	bt.god = true
	for c in get_nodes_in_group("cantifa"): c.queue_free()
	await physics_frame
	var pl := get_first_node_in_group("player") as Node2D
	var squad: Array = []
	for i in 5:
		squad.append(lc.spawn_cantifa_from_edge())
	var rally: Vector2 = lc._cantifa_rally["pos"]
	var posts_same := true
	for c in squad:
		if (c.post_pos as Vector2).distance_to(rally) > LC.CANTIFA_SLOT_R * 2.2: posts_same = false
	ok(posts_same, "all 5 share one rally post (formation slots)")
	# park the rancher far away so they gather undisturbed
	var g = lc.get_node("Ground")
	pl.global_position = g.to_global(g.tile_center(Vector2i(4, 4))) if (rally.distance_to(g.to_global(g.tile_center(Vector2i(4, 4)))) > 500) else g.to_global(g.tile_center(Vector2i(66, 44)))
	await _wait(22.0)
	var maxd := 0.0
	for a in squad:
		for b in squad:
			if is_instance_valid(a) and is_instance_valid(b):
				maxd = maxf(maxd, (a as Node2D).global_position.distance_to((b as Node2D).global_position))
	ok(maxd < 170.0, "group clustered at the same post (max spread %.0f px)" % maxd)
	# moving together: force a regroup
	lc._cantifa_regroup_t = LC.CANTIFA_REGROUP_EVERY + 1.0
	var old_rally := rally
	await _wait(0.2)
	var new_rally: Vector2 = lc._cantifa_rally["pos"]
	ok(new_rally.distance_to(old_rally) > 8.0, "group relocates to another post together")
	var tw := 0.0
	while tw < 25.0 and squad.any(func(c): return c.arriving):
		await _wait(0.5)
		tw += 0.5
	lc._cantifa_regroup_t = 0.0
	maxd = 0.0
	for a in squad:
		for b in squad:
			maxd = maxf(maxd, (a as Node2D).global_position.distance_to((b as Node2D).global_position))
	ok(maxd < 170.0, "still one cluster after moving (%.0f px, arrived in %.1f s)" % [maxd, tw])
	# shoot first: rancher in range + clear line, never filmed
	var lead := squad[0] as Node2D
	var spot := Vector2.ZERO
	var found := false
	for ang in range(0, 360, 20):
		for r in [200.0, 160.0, 240.0]:
			var p: Vector2 = lead.global_position + Vector2.from_angle(deg_to_rad(ang)) * r
			pl.global_position = p
			await physics_frame
			await physics_frame
			if lead._clear_line(pl) and lead.global_position.distance_to(p) < LC.cantifa_range(12):
				spot = p
				found = true
				break
		if found: break
	ok(found, "found a clear-line spot in range")
	for c in squad: c.filmed_t = 0.0
	var shots := 0
	var t := 0.0
	var first_shot := -1.0
	var seen_b := {}
	while t < 3.0:
		await physics_frame
		t += 1.0 / 60.0
		pl.global_position = spot
		for b in get_nodes_in_group("cantifa_bullets"):
			if not seen_b.has(b.get_instance_id()):
				seen_b[b.get_instance_id()] = true
				shots += 1
				if first_shot < 0.0: first_shot = t
	var filmed_any := false
	for c in squad: if c.filmed_t > 0.0: filmed_any = true
	ok(not filmed_any and shots >= 3, "they open fire unprovoked (never filmed): %d shots, first after %.2f s" % [shots, first_shot])
	ok(first_shot >= 0.0 and first_shot < 1.2, "first shot within the tell + cooldown window")
	# blocked line: put a wall between -> no new shots from that one
	bt.god = false
	for c in squad: if is_instance_valid(c): c.queue_free()

	# ---------------- 6969 internal tool
	change_scene_to_file("res://scenes/Title.tscn")
	for i in 6: await process_frame
	for code in ["6969"]:
		bt._buf = ""
		for ch in code:
			var e := InputEventKey.new(); e.pressed = true; e.keycode = KEY_0 + int(ch); e.physical_keycode = e.keycode
			bt._input(e)
	ok(bt.noclip and bt._tag.visible and bt._tag.text == "CHEAT ON", "6969 turns noclip on + CHEAT ON tag")
	bt._apply_code("6969")
	ok(not bt.noclip, "6969 again toggles it off")
	bt._apply_code("6969")
	bt._apply_code("0000")
	ok(not bt.noclip and not bt.god, "0000 clears noclip")
	ok(bt._tag.text == "CHEATED", "run still marked cheated after 0000")
	# physics: walk through a blocked prop cell
	var lc2 = await _load(LC.GAME_SCENE, 9)
	var g2 = lc2.get_node("Ground")
	var pl2 := get_first_node_in_group("player") as Node2D
	var cand: Array = []
	for c in g2._blocked.keys():
		var cc: Vector2i = c
		if g2.is_interior_local(cc, 4) and not g2._blocked.has(cc + Vector2i(-2, 0)) and not g2._blocked.has(cc + Vector2i(-1, 0)) \
				and not g2._blocked.has(cc + Vector2i(2, 0)) and not g2._blocked.has(cc + Vector2i(1, 0)):
			cand.append(cc)
	cand = cand.slice(0, 12)
	var blocked_off := 0
	var passed_on := 0
	for cc in cand:
		var A: Vector2 = g2.to_global(g2.tile_center(cc + Vector2i(-2, 0)))
		var B: Vector2 = g2.to_global(g2.tile_center(cc + Vector2i(2, 0)))
		for nc in [false, true]:
			bt.noclip = nc
			pl2.global_position = A
			pl2.velocity = Vector2.ZERO
			var d := A.direction_to(B)
			Input.action_press("move_right", maxf(d.x, 0.0)); Input.action_press("move_left", maxf(-d.x, 0.0))
			Input.action_press("move_down", maxf(d.y, 0.0)); Input.action_press("move_up", maxf(-d.y, 0.0))
			var tt := 0.0
			var best := INF
			while tt < 1.6:
				await physics_frame
				tt += 1.0 / 60.0
				best = minf(best, pl2.global_position.distance_to(B))
			for a in ["move_right", "move_left", "move_up", "move_down"]: Input.action_release(a)
			var reached := best < 20.0
			if not nc and not reached: blocked_off += 1
			if nc and reached: passed_on += 1
	ok(blocked_off >= 3, "without noclip props block the rancher (%d/%d)" % [blocked_off, cand.size()])
	ok(passed_on * 4 >= blocked_off * 3 and passed_on >= 3, "with noclip he walks through them (%d/%d)" % [passed_on, cand.size()])
	# water
	var water = lc2.get_node_or_null("Water")
	if water == null: water = lc2.get_node_or_null("Entities/Water")
	# bounds still apply
	bt.noclip = true
	pl2.global_position = g2.to_global(g2.tile_center(Vector2i(4, 24)))
	Input.action_press("move_left")
	await _wait(4.0)
	Input.action_release("move_left")
	var cell: Vector2i = g2.local_pos_to_local_cell(g2.to_local(pl2.global_position))
	ok(g2.is_interior_local(cell, 0), "noclip still stops at the map bounds (cell %s)" % cell)
	bt._apply_code("0000")
	await physics_frame
	await physics_frame
	ok((pl2.collision_mask & 1) == 1, "world collision restored after 0000")

	# ---------------- docs
	for f in ["res://README.md", "/workspace/stsh-game-repo/docs/DEVLOG.md", "/workspace/stsh-game-repo/README.md"]:
		var txt := FileAccess.get_file_as_string(f)
		ok(txt.length() > 100, "%s readable" % f)
		ok(not ("6969" in txt or "noclip" in txt.to_lower() or "7474" in txt), "%s doesn't document the codes" % f)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
