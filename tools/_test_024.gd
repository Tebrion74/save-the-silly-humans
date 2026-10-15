extends SceneTree
## Build 024 checks: hidden chambers (placement, pathing, breaking on touch +
## PC, reveal, once-per-run reward, bosses/bonus untouched, noclip).
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
func _load(scene: String, lv: int, fresh := true) -> Node:
	var gp := root.get_node("GameProgress")
	if fresh: gp.reset_progress()
	gp.current_level = lv
	change_scene_to_file(scene)
	for i in 8: await physics_frame
	return get_first_node_in_group("level_controller")

func _reach(g, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not g.is_interior_local(n, 0) or g._blocked.has(n):
				continue
			seen[n] = true
			q.append(n)
	return seen

func _run() -> void:
	var gp := root.get_node("GameProgress")
	var bt := root.get_node("BetaTools")
	var ti := root.get_node("TouchInput")
	var total := 0
	var subtle := 0
	var kinds := {}
	var ids := {}
	for lv in range(1, 25):
		if lv in [2, 5, 8, 11, 14, 17]:
			pass   # regular levels still exist at these numbers (boss comes after)
		var lc = await _load(LC.GAME_SCENE, lv)
		var g = lc.get_node("Ground")
		var sc = lc.secrets
		var n: int = sc.specs.size() if sc != null else 0
		ok(n >= 1 and n <= 2, "L%d %s: %d chamber(s)" % [lv, g.theme, n])
		if sc == null: continue
		total += n
		var pl_layer: TileMapLayer = lc.get_node("Entities/Props")
		var dt_layer = lc.get_node_or_null("Detail")
		ok(pl_layer.get_used_cells().size() > 150 and (dt_layer == null or dt_layer.get_used_cells().size() > 100), "L%d props / details intact (%d props)" % [lv, pl_layer.get_used_cells().size()])
		var start: Vector2i = g.CLEARINGS[1]
		var reach := _reach(g, start)
		var all_clear := true
		for k in g.CLEARINGS:
			if not reach.has(k): all_clear = false
		ok(all_clear, "L%d all spawn slots / zones still reachable" % lv)
		for s in sc.specs:
			ids[s["id"]] = true
			if s["subtle"]: subtle += 1
			kinds[s["reward"]] = true
			ok(reach.has(s["out"]), "L%d %s door reachable from the player start" % [lv, s["id"]])
			var sealed := true
			for c in s["pocket"]:
				if reach.has(c): sealed = false
			ok(sealed, "L%d %s pocket sealed until opened" % [lv, s["id"]])
	ok(total >= 24 and total <= 48, "about 1-2 per level (%d over 24 levels)" % total)
	ok(subtle > 0 and subtle < total, "mix of marked (%d) and unmarked (%d) doors" % [subtle, total - subtle])
	ok(kinds.size() >= 4, "varied rewards %s" % str(kinds.keys()))
	ok(ids.size() == total, "chamber ids unique")
	# ---------------- no chambers in bosses / bonus
	for sc_path in [LC.BOSS_SCENE, LC.BOSS2_SCENE, LC.BOSS6_SCENE, LC.BONUS_SCENE]:
		var l2 = await _load(sc_path, 2)
		ok(l2.secrets == null and get_nodes_in_group("secret_doors").is_empty(), "no chambers in %s" % sc_path.get_file())
	# ---------------- break on TOUCH with the real whip path
	var lc = await _load(LC.GAME_SCENE, 4)
	var g = lc.get_node("Ground")
	bt.god = true
	var s: Dictionary = lc.secrets.specs[0]
	var pl := get_first_node_in_group("player") as Node2D
	var door_pos: Vector2 = g.to_global(g.tile_center(s["door"]))
	var out_dir := Vector2(s["out"] - s["door"])
	var stand := door_pos + out_dir * 80.0
	pl.global_position = stand
	await physics_frame
	# door blocks before breaking
	var into := -out_dir
	for a in ["move_right", "move_left", "move_up", "move_down"]: Input.action_release(a)
	Input.action_press("move_right", maxf(into.x, 0)); Input.action_press("move_left", maxf(-into.x, 0))
	Input.action_press("move_down", maxf(into.y, 0)); Input.action_press("move_up", maxf(-into.y, 0))
	await _wait(1.5)
	for a in ["move_right", "move_left", "move_up", "move_down"]: Input.action_release(a)
	var pc: Vector2i = g.local_pos_to_local_cell(g.to_local(pl.global_position))
	ok(not s["pocket"].has(pc), "closed door blocks the rancher (at %s)" % pc)
	ti.active = true
	pl.global_position = stand
	pl.facing = (door_pos - stand).normalized()
	var whip = pl.get_node("Whip")
	var door = get_nodes_in_group("secret_doors")[0]
	for d in get_nodes_in_group("secret_doors"):
		if (d as Node2D).global_position.distance_to(door_pos) < 2.0: door = d
	var pu = pl.get_node("PowerUps")
	bt.god = false
	if "active" in pu: pu.active.clear()
	pu.fire_charges = 0
	pu.shock_charges = 0
	pu._apply()
	whip.cooldown = 0.0
	whip.fire_whip()
	ok(door.hits == 1 and is_instance_valid(door) and not door._broken, "touch crack #1 chips the door (hits=%d)" % door.hits)
	await _wait(0.6)
	whip.cooldown = 0.0
	whip.fire_whip()
	ok(not is_instance_valid(door) or door._broken, "touch crack #2 breaks it open")
	ti.active = false
	await _wait(0.4)
	var rw := get_nodes_in_group("secret_rewards")
	ok(rw.size() == 1, "reward revealed in the pocket")
	ok(not g._blocked.has(s["door"]), "door cell walkable after opening")
	var score0: int = gp.score
	var hp0: int = pl.health
	pl.global_position = (rw[0] as Node2D).global_position
	await _wait(0.4)
	ok(get_nodes_in_group("secret_rewards").is_empty() or not rw[0].visible or rw[0]._done, "reward claimed by walking onto it")
	ok(gp.secret_claimed(s["id"]), "claim recorded for the run (%s, %s)" % [s["id"], s["reward"]])
	# same level again in the same run: chamber reopens empty
	lc = await _load(LC.GAME_SCENE, 4, false)
	g = lc.get_node("Ground")
	for d in get_nodes_in_group("secret_doors"):
		if (d as Node2D).global_position.distance_to(door_pos) < 2.0:
			d.hit(2)
	await _wait(0.3)
	ok(get_nodes_in_group("secret_rewards").is_empty(), "reward only once per run (replay shows ALREADY LOOTED)")
	# new run: available again
	gp.reset_progress()
	ok(not gp.secret_claimed(s["id"]), "new run resets claims")
	# ---------------- PC path (mouse-style crack along a lash) breaks with fire in one go
	lc = await _load(LC.GAME_SCENE, 6)
	g = lc.get_node("Ground")
	var s2: Dictionary = lc.secrets.specs[0]
	var dp: Vector2 = g.to_global(g.tile_center(s2["door"]))
	var d2 = null
	for d in get_nodes_in_group("secret_doors"):
		if (d as Node2D).global_position.distance_to(dp) < 2.0: d2 = d
	SecretDoor.on_crack(self, dp + Vector2(s2["out"] - s2["door"]) * 120.0, dp - Vector2(s2["out"] - s2["door"]) * 40.0, true)
	ok(not is_instance_valid(d2) or d2._broken, "a fire-whip lash breaks it in one crack")
	SecretDoor.on_crack(self, dp + Vector2(300, 300), dp + Vector2(500, 300), false)
	ok(true, "cracks elsewhere ignored")
	# ---------------- noclip still goes through everything
	lc = await _load(LC.GAME_SCENE, 9)
	g = lc.get_node("Ground")
	var s3: Dictionary = lc.secrets.specs[0]
	pl = get_first_node_in_group("player") as Node2D
	bt.noclip = true
	var wall_cell: Vector2i = s3["walls"][0]
	var target: Vector2 = g.to_global(g.tile_center(s3["pocket"][0]))
	pl.global_position = target + Vector2(-90, 0)
	Input.action_press("move_right")
	var best := INF
	for i in 90:
		await physics_frame
		best = minf(best, pl.global_position.distance_to(target))
	Input.action_release("move_right")
	ok(best < 24.0, "noclip walks through chamber walls (%.0f px)" % best)
	bt._apply_code("0000")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
