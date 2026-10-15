extends SceneTree
## Build 025 checks: boss 7/8 progression + configs, hazards hit/dodge,
## biomes, body armour, level-select boss codes, HUD, cheats intact.
const LC := preload("res://scripts/level_config.gd")
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("PASS " if c else "FAIL ") + m)
	if not c: fails += 1
func _initialize() -> void:
	create_timer(400.0).timeout.connect(func(): print("FAIL watchdog"); quit(2))
	_run.call_deferred()
func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await physics_frame
		t += 1.0 / 60.0
func _boss(stage: String) -> Node:
	var gp := root.get_node("GameProgress")
	change_scene_to_file(gp.start_at_stage(stage))
	for i in 10: await physics_frame
	return get_first_node_in_group("boss")
func _quiet(b: Node) -> void:
	b.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_nodes_in_group("poutine"): n.queue_free()

func _run() -> void:
	var gp := root.get_node("GameProgress")
	var bt := root.get_node("BetaTools")
	# --- progression
	ok(GameProgressCheck.stages_after(20).has("boss7"), "boss7 follows L20")
	ok(GameProgressCheck.stages_after(23).has("boss8"), "boss8 follows L23")
	ok(not GameProgressCheck.stages_after(19).has("boss7") and not GameProgressCheck.stages_after(22).has("boss8"), "no boss7/8 elsewhere")
	ok(GameProgressCheck.stage_scene("boss7").ends_with("Boss7Arena.tscn") and GameProgressCheck.stage_scene("boss8").ends_with("Boss8Arena.tscn"), "stage scenes")
	ok(LC.BOSS7_HEARTS == 24 and LC.BOSS8_HEARTS == 26, "boss hearts 24 / 26")
	ok(LC.BOSS8_NAME == "ZELODYMER VIOLENTSKY" and LC.BOSS7_NAME == "REANALD ROGAN", "boss names (exact spelling)")
	# --- themes
	for lv in [18, 19, 20]: ok(LC.theme_for(lv) == "midwest", "L%d midwest" % lv)
	for lv in [21, 22, 23]: ok(LC.theme_for(lv) == "ukraine", "L%d ukraine" % lv)
	var cyc := {}
	for lv in range(24, 24 + LC.THEME_ORDER.size()): cyc[LC.theme_for(lv)] = true
	ok(cyc.size() == LC.THEME_ORDER.size(), "levels 24+ cycle all %d biomes" % LC.THEME_ORDER.size())
	ok(ResourceLoader.exists("res://assets/tiles/biome/midwest/tileset.tres") and ResourceLoader.exists("res://assets/tiles/biome/ukraine/tileset.tres"), "biome tilesets")
	for t in ["boss7", "boss8", "level_midwest", "level_ukraine"]:
		ok(GameAudio.TRACKS.has(t), "music track " + t)
	# --- armour drops + absorption on a regular level
	gp.reset_progress(); gp.current_level = 11
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 10: await physics_frame
	var lc = get_first_node_in_group("level_controller")
	ok(not lc.drop_weights().has("armor"), "no armour drops before L12")
	gp.reset_progress(); gp.current_level = 12
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 10: await physics_frame
	lc = get_first_node_in_group("level_controller")
	ok(lc.drop_weights().has("armor"), "armour drops from L12")
	for e in get_nodes_in_group("cantifa"): e.queue_free()
	var pl = get_first_node_in_group("player")
	var pu = pl.get_node("PowerUps")
	pu.grant("armor")
	await physics_frame
	ok(pu.armor == 3 and pl.get_parent().get_node_or_null("ArmorVest") != null or pl.get_node_or_null("ArmorVest") != null, "armour granted x3 + vest visual")
	var hp0: int = pl.health
	for k in 3:
		pl.take_damage(1, pl.global_position + Vector2(20, 0))
		await _wait(0.7)
	ok(pl.health == hp0 and pu.armor == 0, "3 hits soaked by armour, hearts untouched")
	pl.take_damage(1, pl.global_position + Vector2(20, 0))
	ok(pl.health == hp0 - 1, "4th hit costs a heart")
	pu.grant("armor")
	var d: Dictionary = pu.to_dict()
	pu.armor = 0
	pu.from_dict(d)
	ok(pu.armor == 3, "armour persists across levels")
	await physics_frame; await physics_frame
	ok(lc.hud.hearts.armor == 3, "HUD shows 3 armour shields next to hearts")
	lc.hud.show_toast("SECRET FOUND!")
	await physics_frame
	var tr: Rect2 = lc.hud.toast_label.get_global_rect()
	ok(not tr.intersects(lc.hud.score_label.get_global_rect()) and not tr.intersects(lc.hud.rescued_label.get_global_rect()), "secret toast clear of score/SAVED (PC)")
	root.get_node("TouchInput").active = true
	for i in 3: await process_frame
	lc.hud.show_toast("SECRET FOUND!")
	await process_frame
	tr = lc.hud.toast_label.get_global_rect()
	ok(not tr.intersects(lc.hud.score_label.get_global_rect()) and not tr.intersects(lc.hud.rescued_label.get_global_rect()), "secret toast clear of score/SAVED (mobile)")
	root.get_node("TouchInput").active = false
	# --- boss 7 hazards
	var b = await _boss("boss7")
	ok(b != null and b.get_script().get_global_name() == "ReanaldRogan" and b.hearts == 24, "boss7 boots with 24 hearts")
	_quiet(b)
	var lvl = get_first_node_in_group("boss_level")
	pl = get_first_node_in_group("player")
	pl.global_position = Vector2(0, 120)
	await _wait(0.2)
	var h: int = pl.health
	var s = StarWars.OrbitalStrike.new(); s.level = lvl; s.tell = 0.3; s.global_position = pl.global_position
	lvl.add_child(s); await _wait(0.6)
	ok(pl.health == h - 1, "orbital strike on the rancher hits")
	await _wait(1.6); h = pl.health
	s = StarWars.OrbitalStrike.new(); s.level = lvl; s.tell = 0.3; s.global_position = pl.global_position + Vector2(160, 0)
	lvl.add_child(s); await _wait(0.6)
	ok(pl.health == h, "orbital strike dodged when outside the ring")
	pu = pl.get_node("PowerUps"); pu.grant("armor")
	await _wait(1.6); h = pl.health
	s = StarWars.OrbitalStrike.new(); s.level = lvl; s.tell = 0.3; s.global_position = pl.global_position
	lvl.add_child(s); await _wait(0.6)
	ok(pl.health == h and pu.armor == 2, "armour soaks boss hazard")
	var u = StarWars.Ufo.new(); u.level = lvl; u.global_position = pl.global_position + Vector2(0, -60)
	lvl.add_child(u); await physics_frame
	u.receive_whip(pl.global_position); u.receive_whip(pl.global_position)
	await _wait(0.3)
	ok(not is_instance_valid(u) or u.is_queued_for_deletion() or u.hp <= 0, "UFO downed by 2 whips")
	# --- boss 8 hazards
	b = await _boss("boss8")
	ok(b != null and b.get_script().get_global_name() == "ZelodymerViolentsky" and b.hearts == 26, "boss8 boots with 26 hearts")
	_quiet(b)
	lvl = get_first_node_in_group("boss_level")
	pl = get_first_node_in_group("player")
	pl.global_position = Vector2(0, 120)
	await _wait(0.2); h = pl.health
	var dr = Drones.Drone.new(); dr.level = lvl; dr.global_position = Vector2(0, -150); dr.target = pl.global_position; dr.hover_time = 0.3
	lvl.add_child(dr); await _wait(3.0)
	ok(pl.health == h - 1, "drone dive on the rancher hits")
	await _wait(1.0); h = pl.health
	dr = Drones.Drone.new(); dr.level = lvl; dr.global_position = Vector2(0, -150); dr.target = pl.global_position + Vector2(200, 0); dr.hover_time = 0.3
	lvl.add_child(dr); await _wait(3.0)
	ok(pl.health == h, "drone dodged when away from the blast")
	dr = Drones.Drone.new(); dr.level = lvl; dr.global_position = pl.global_position + Vector2(0, -40); dr.target = pl.global_position; dr.hover_time = 5.0
	lvl.add_child(dr); await _wait(0.4)
	dr.receive_whip(pl.global_position)
	await _wait(0.2)
	ok(not is_instance_valid(dr) or dr.is_queued_for_deletion(), "drone popped by whip")
	# --- level select codes + cheats
	for code in [91, 94, 97, 98]:
		bt._open_pad("level"); bt._pad_text = str(code); bt._pad_submit()
		for i in 12: await process_frame
		var cs := current_scene.scene_file_path if current_scene != null else ""
		var want := GameProgressCheck.stage_scene("boss%d" % (code - 90))
		ok(cs == want, "level select %d -> %s" % [code, want.get_file()])
	bt._open_pad("level"); bt._pad_text = "18"; bt._pad_submit()
	for i in 12: await process_frame
	ok(gp.current_level == 18, "level select 18 still a level")
	bt._apply_code("7474"); ok(bt.god, "7474 god mode still works")
	bt._apply_code("0000"); ok(not bt.god, "0000 clears cheats")
	var ts = load("res://scripts/ui/title_screen.gd")
	ok(ts.BUILD_LABEL == "BUILD 025" and ts.CREDIT_ASSIST.find("EWAN SHEPHERD, LLM") >= 0, "build label + Ewan Shepherd, LLM credit")
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
