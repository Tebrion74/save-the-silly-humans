extends SceneTree
## Build 030 checks: cameo sub-bosses (director gating, all four abilities,
## Zuckerbot mini-fight via the real whip, crates, chatbot, lifetimes),
## cheat 3030 cameo party, attract mode lineup + score table, build label.
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("PASS " if c else "FAIL ") + m)
	if not c: fails += 1
func _initialize() -> void:
	create_timer(300.0).timeout.connect(func(): print("FAIL watchdog"); quit(2))
	_run.call_deferred()
func _wait(s: float) -> void:
	await create_timer(s).timeout
	await process_frame
func _key(k: Key) -> void:
	for pr in [true, false]:
		var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = pr
		Input.parse_input_event(e)
		await process_frame
func _level(n: int) -> Node:
	var gp := root.get_node("GameProgress")
	gp.reset_progress(); gp.current_level = n
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 40: await process_frame
	await _wait(0.3)
	return get_first_node_in_group("level_controller")
func _clear_cameos() -> void:
	for g in ["cameo", "cameo_crate", "cameo_shot", "chat_drone"]:
		for n in get_nodes_in_group(g): n.queue_free()
	await process_frame
func _sheep_near(pl: Node2D, n: int) -> void:
	var sc: PackedScene = load("res://scenes/sheep/Sheep.tscn")
	var lc = get_first_node_in_group("level_controller")
	var flock = lc.get_node_or_null("Entities/Sheep")
	for i in n:
		var s: Node2D = sc.instantiate()
		(flock if flock != null else current_scene).add_child(s)
		s.global_position = pl.global_position + Vector2.from_angle(i * 1.3) * (90.0 + i * 15.0)
	await process_frame

func _run() -> void:
	var gp := root.get_node("GameProgress")
	var bt := root.get_node("BetaTools")
	# ---- title: cheat + attract
	change_scene_to_file("res://scenes/Title.tscn")
	for i in 20: await process_frame
	var ts = current_scene
	ok(ts.BUILD_LABEL == "BUILD 030", "build label 030")
	for k in [KEY_3, KEY_0, KEY_3, KEY_0]: await _key(k)
	ok(bt.cameo_party, "cheat 3030 turns CAMEO PARTY on (title)")
	for k in [KEY_3, KEY_0, KEY_3, KEY_0]: await _key(k)
	ok(not bt.cameo_party, "3030 again turns it off")
	for k in [KEY_7, KEY_4, KEY_7, KEY_4]: await _key(k)
	ok(bt.god, "god mode 7474 still works")
	var am = ts.find_child("AttractMode", true, false)
	var pages: Array = am.pages()
	ok(pages.has("cameos") and pages.has("score2"), "attract pages include SURPRISE CAMEOS + cameo score table: %s" % [pages])
	var rows: Array = AttractMode.score_rows(2)
	ok(rows.size() == 6 and rows[1][2] == str(LevelConfig.POINTS_ZUCKERBOT), "score table page 3 lists cameo points (Zuckerbot %s)" % rows[1][2])
	am.show_page("cameos"); await _wait(2.6)
	ok(am.page == "cameos" and am.visible, "cameo lineup page draws")
	am.show_page("score2"); await _wait(0.5)
	am.stop()
	# ---- level gating
	var lc := await _level(1)
	ok(lc.cameo_director != null and not lc.cameo_director.enabled(), "L1: director present but off (cameos from L%d)" % LevelConfig.CAMEO_FROM_LEVEL)
	bt.cameo_party = true
	ok(lc.cameo_director.enabled(), "cheat party enables cameos on L1")
	lc.cameo_director.timer = 0.05
	await _wait(1.2)
	ok(get_nodes_in_group("cameo").size() == 1 and lc.cameo_director.spawned == 1, "party: a cameo drops in")
	bt.cameo_party = false
	await _clear_cameos()
	lc = await _level(2)
	var dir = lc.cameo_director
	ok(dir.enabled(), "L2: random cameos enabled")
	ok(dir.timer >= LevelConfig.CAMEO_FIRST_DELAY.x - 1.0 and dir.timer <= LevelConfig.CAMEO_FIRST_DELAY.y, "first cameo roll in %.1f s" % dir.timer)
	# natural random spawning (many rolls): chance respected and only one at a time
	var spawned_ids := {}
	dir.rng.seed = 7
	for i in 30:
		await _clear_cameos(); dir.current = null
		dir.timer = 0.0
		await process_frame; await process_frame
		for c in get_nodes_in_group("cameo"): spawned_ids[c.id] = int(spawned_ids.get(c.id, 0)) + 1
	var tot := 0
	for v in spawned_ids.values(): tot += v
	ok(tot >= 12 and tot <= 29 and spawned_ids.size() >= 3, "30 random rolls -> %d cameos (chance %.0f%%), ids %s" % [tot, LevelConfig.CAMEO_CHANCE * 100, spawned_ids])
	await _clear_cameos(); dir.current = null; dir.timer = 999.0
	var pl: Node2D = get_first_node_in_group("player")
	# ---- TUSK (ally)
	var base_speed: float = pl.movement_speed
	for s in get_nodes_in_group("sheep"): s.explode()
	await _wait(0.2)
	await _sheep_near(pl, 3)
	var score0: int = gp.score
	var tusk = dir.spawn("tusk")
	await _wait(Cameo.ENTER_T + 0.2)
	ok(absf(pl.movement_speed - base_speed * LevelConfig.TUSK_BOOST_MULT) < 0.1, "Tusk: rocket boost x%.2f" % LevelConfig.TUSK_BOOST_MULT)
	var before := get_nodes_in_group("sheep").size()
	tusk._act_t = 0.0
	await _wait(0.1)
	ok(get_nodes_in_group("sheep").size() == before - 1 and gp.score > score0, "Tusk: STARLINK STRIKE pops a sheep (+%d)" % (gp.score - score0))
	tusk.life = 0.0
	await _wait(Cameo.EXIT_T + 0.3)
	ok(not is_instance_valid(tusk) and absf(pl.movement_speed - base_speed) < 0.1, "Tusk leaves; speed restored")
	# ---- BOZOS (wild)
	bt.god = false
	pl.health = pl.maximum_health
	var bz = dir.spawn("bozos")
	await _wait(Cameo.ENTER_T + 0.1)
	bz._act_t = 0.0
	await _wait(0.1)
	ok(get_nodes_in_group("cameo_crate").size() == 1, "Bozos: drone drops a crate")
	await _clear_cameos()
	# bomb next to the rancher hurts (no sheep around to bite)
	for s in get_nodes_in_group("sheep"): s.explode()
	var den = lc.get_node_or_null("Entities/SheepSpawner")
	if den != null: den.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(0.2)
	var cr = Cameo.Crate.new(); cr.bomb = true; cr.cameo_level = lc
	lc.get_node("Entities").add_child(cr); cr.global_position = pl.global_position + Vector2(30, 0)
	var hp0: int = pl.health
	await _wait(0.7 + LevelConfig.BOZOS_FUSE + 0.3)
	ok(pl.health == hp0 - 1 or pl.absorbed_frame > 0, "bomb crate blows up next to the rancher (hearts %d -> %d)" % [hp0, pl.health])
	bt.god = true
	pl.health = pl.maximum_health
	# bomb defused by the whip
	var cr2 = Cameo.Crate.new(); cr2.bomb = true; cr2.cameo_level = lc
	lc.get_node("Entities").add_child(cr2); cr2.global_position = pl.global_position + Vector2(400, 0)
	await _wait(0.8)
	var s1: int = gp.score
	cr2.receive_whip(pl.global_position, 0.0)
	await process_frame
	ok(not is_instance_valid(cr2) and gp.score - s1 == LevelConfig.POINTS_DEFUSE, "whip defuses a bomb crate +%d" % (gp.score - s1))
	# loot crate opens into a power-up when walked over
	var cr3 = Cameo.Crate.new(); cr3.bomb = false; cr3.cameo_level = lc
	lc.get_node("Entities").add_child(cr3); cr3.global_position = pl.global_position + Vector2(10, 0)
	var pk0: int = lc.pickups_layer.get_child_count() + lc.powerups_collected
	await _wait(1.0)
	ok(not is_instance_valid(cr3) and lc.pickups_layer.get_child_count() + lc.powerups_collected > pk0, "loot crate opens into a power-up")
	# ---- ALTMANN (wild)
	for helpful in [true, false]:
		await _clear_cameos(); dir.current = null
		for s in get_nodes_in_group("sheep"): s.explode()
		await _wait(0.1)
		await _sheep_near(pl, 2)
		var al = dir.spawn("altmann")
		al.helpful = helpful
		await _wait(Cameo.ENTER_T + 0.2)
		var dr = get_first_node_in_group("chat_drone")
		var n0 := get_nodes_in_group("sheep").size()
		dr.zap()
		await process_frame
		var popped := n0 - get_nodes_in_group("sheep").size()
		if helpful:
			var doors := get_nodes_in_group("secret_doors").size()
			ok(popped == 1 and (doors == 0 or dr.target_pos != Vector2.INF), "Altmann helpful: chatbot zaps a sheep, points at a chamber (doors=%d)" % doors)
		else:
			ok(popped == 0 and dr.target_pos != Vector2.INF, "Altmann misleading: zap misses, points at nothing useful")
	await _clear_cameos(); dir.current = null
	# ---- ZUCKERBOT (foe) via the real whip
	pl.health = pl.maximum_health
	bt.god = false
	var zk = dir.spawn("zuckerbot")
	zk.global_position = pl.global_position + Vector2(110, 0)
	await _wait(Cameo.ENTER_T + 0.1)
	zk.set_process(true)
	zk._act_t = 99.0
	var sh = zk.fire_like()
	sh.global_position = pl.global_position + Vector2(40, -12); sh.vel = Vector2(-120, 0)
	var hpz: int = pl.health
	await _wait(0.6)
	ok(pl.health < hpz or pl.absorbed_frame > 0, "Zuckerbot LIKE bubble hurts the rancher")
	pl.health = pl.maximum_health
	bt.god = true
	var whip = pl.find_child("Whip", true, false)
	var s2: int = gp.score
	var hits := 0
	for i in 12:
		if not is_instance_valid(zk) or zk.defeated: break
		zk.global_position = pl.global_position + Vector2(110, 0)
		zk.life = 10.0
		whip.cooldown = 0.0
		root.get_node("TouchInput").active = true
		pl.facing = Vector2.RIGHT
		whip.fire_whip()
		hits += 1
		await _wait(0.4)
	root.get_node("TouchInput").active = false
	ok(is_instance_valid(zk) and zk.defeated, "Zuckerbot mini-fight: defeated by %d real whip cracks" % hits)
	ok(gp.score - s2 >= LevelConfig.POINTS_ZUCKERBOT + LevelConfig.ZUCK_HP * LevelConfig.POINTS_CAMEO_HIT and zk.hp == 0, "Zuckerbot pays %d (1500 + 6x50, plus any sheep the power-up whip popped)" % (gp.score - s2))
	await _wait(Cameo.EXIT_T + 0.3)
	ok(not is_instance_valid(zk), "defeated Zuckerbot flies off")
	# ---- lifetime: a cameo leaves by itself
	var t0 := Time.get_ticks_msec()
	var lifer = dir.spawn("bozos")
	lifer.life = 1.0
	await _wait(Cameo.ENTER_T + 1.0 + Cameo.EXIT_T + 0.4)
	ok(not is_instance_valid(lifer), "cameo leaves after its life runs out")
	# ---- never in boss / bonus stages
	change_scene_to_file(gp.start_at_stage("boss1") if gp.has_method("start_at_stage") else "res://scenes/Main.tscn")
	for i in 40: await process_frame
	var blc = get_first_node_in_group("level_controller")
	var bd = blc.get("cameo_director") if blc != null else null
	ok(bd == null or not bd.enabled(), "boss stage: no cameos")
	print("RESULT 030: ", "ALL PASS" if fails == 0 else "%d FAIL" % fails)
	quit(fails)
