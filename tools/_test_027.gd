extends SceneTree
## Build 027 checks: boss 9/10 progression + configs, final-boss hazards hit /
## dodge, invert controls + banner, taiga/florida biomes and the 10-biome cycle,
## 16-heart HUD (PC + mobile), level-select 99/90, the ending flow, cheats.
const LC := preload("res://scripts/level_config.gd")
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("PASS " if c else "FAIL ") + m)
	if not c: fails += 1
func _initialize() -> void:
	create_timer(500.0).timeout.connect(func(): print("FAIL watchdog"); quit(2))
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
func _hud_ok(lc: Node, tag: String) -> void:
	var vs: Vector2 = lc.get_viewport().get_visible_rect().size
	var hr: Rect2 = lc.hud.hearts.get_global_rect()
	var card: Rect2 = lc.hud._left_card.get_global_rect()
	ok(card.encloses(hr) or card.grow(2).encloses(hr), "16 hearts + 3 shields inside the left card (%s) %s in %s" % [tag, hr, card])
	ok(card.end.x < vs.x * 0.5, "left card stays in the left half (%s) w=%d" % [tag, int(card.size.x)])
	ok(not hr.intersects(lc.hud.score_label.get_global_rect()), "hearts clear of score (%s)" % tag)

func _run() -> void:
	var gp := root.get_node("GameProgress")
	var bt := root.get_node("BetaTools")
	# --- progression + configs
	ok(GameProgressCheck.stages_after(26).has("boss9"), "boss9 follows L26")
	ok(GameProgressCheck.stages_after(29).has("boss10"), "boss10 follows L29")
	ok(not GameProgressCheck.stages_after(25).has("boss9") and not GameProgressCheck.stages_after(28).has("boss10") and not GameProgressCheck.stages_after(32).has("boss10"), "no boss9/10 elsewhere")
	ok(GameProgressCheck.stage_scene("boss9").ends_with("Boss9Arena.tscn") and GameProgressCheck.stage_scene("boss10").ends_with("Boss10Arena.tscn"), "stage scenes")
	ok(LC.BOSS9_HEARTS == 30 and LC.BOSS10_HEARTS == 34, "boss hearts 30 / 34")
	ok(LC.BOSS9_NAME == "VLADIMIR PUDDIN" and LC.BOSS10_NAME == "DONALD RUMP", "boss names")
	ok(LC.HEARTS_CAP == 16 and LC.max_hearts_for(40) == 16 and LC.max_hearts_for(18) == 14, "hearts cap 16")
	# --- themes
	for lv in [24, 25, 26]: ok(LC.theme_for(lv) == "taiga", "L%d taiga" % lv)
	for lv in [27, 28, 29]: ok(LC.theme_for(lv) == "florida", "L%d florida" % lv)
	ok(LC.theme_for(23) == "ukraine" and LC.theme_for(21) == "ukraine", "L21-23 still ukraine")
	var cyc := {}
	for lv in range(30, 30 + LC.THEME_ORDER.size()): cyc[LC.theme_for(lv)] = true
	ok(LC.THEME_ORDER.size() == 10 and cyc.size() == 10, "levels 30+ cycle all 10 biomes")
	ok(ResourceLoader.exists("res://assets/tiles/biome/taiga/tileset.tres") and ResourceLoader.exists("res://assets/tiles/biome/florida/tileset.tres"), "biome tilesets")
	for t in ["boss9", "boss10", "level_taiga", "level_florida"]:
		ok(GameAudio.TRACKS.has(t) and GameAudio.TRACKS[t] != null, "music track " + t)
	# --- 16-heart HUD on PC and mobile
	gp.reset_progress(); gp.current_level = 27
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 10: await physics_frame
	var lc = get_first_node_in_group("level_controller")
	for e in get_nodes_in_group("cantifa"): e.queue_free()
	var pl = get_first_node_in_group("player")
	pl.maximum_health = 16; pl.health = 16
	lc.hud.set_health(16, 16)
	pl.get_node("PowerUps").grant("armor")
	for i in 4: await process_frame
	ok(lc.hud.hearts.rows() == 2 and lc.hud.hearts.per_row() == 8, "16 hearts = 2 rows of 8")
	_hud_ok(lc, "PC")
	root.get_node("TouchInput").active = true
	for i in 4: await process_frame
	_hud_ok(lc, "mobile")
	root.get_node("TouchInput").active = false
	# --- invert controls + banner
	pl.invert_controls(3.0)
	await process_frame; await process_frame
	ok(pl.is_inverted() and lc.hud.invert_banner.visible and lc.hud.invert_banner.text.begins_with("CONTROLS FLIPPED"), "invert on + banner")
	Input.action_press("move_right")
	await physics_frame
	ok(pl.get_steer_direction().x < -0.5, "right steers left while inverted")
	Input.action_release("move_right")
	await _wait(3.2)
	ok(not pl.is_inverted() and not lc.hud.invert_banner.visible, "invert wears off after 3 s, banner gone")
	# --- boss 9 hazards
	var b = await _boss("boss9")
	ok(b != null and b.get_script().get_global_name() == "VladimirPuddin" and b.hearts == 30, "boss9 boots with 30 hearts")
	var lvl = get_first_node_in_group("boss_level")
	ok(lvl.boss_bar_rows() == 2 if lvl.has_method("boss_bar_rows") else lvl.hud.boss_bar.rows() == 2, "boss bar wraps to 2 rows")
	var vs: Vector2 = lvl.get_viewport().get_visible_rect().size
	var bb: Rect2 = lvl.hud.boss_bar.get_global_rect()
	ok(bb.position.x >= 0 and bb.end.x <= vs.x, "boss bar on screen")
	ok(lvl.get_node("Ground").theme == "taiga", "boss9 arena on taiga tiles")
	_quiet(b)
	pl = get_first_node_in_group("player")
	pl.global_position = Vector2(0, 120)
	await _wait(0.2)
	var h: int = pl.health
	var s = Finale.MarkedStrike.new(); s.level = lvl; s.tell = 0.3; s.global_position = pl.global_position
	lvl.add_child(s); await _wait(0.8)
	ok(pl.health == h - 1, "icicle on the rancher hits")
	await _wait(1.6); h = pl.health
	s = Finale.MarkedStrike.new(); s.level = lvl; s.tell = 0.3; s.global_position = pl.global_position + Vector2(160, 0)
	lvl.add_child(s); await _wait(0.8)
	ok(pl.health == h, "icicle dodged")
	ok(s == null or not is_instance_valid(s) or s.threat(pl.global_position) < 0.0, "threat() says safe away from the ring")
	await _wait(1.0); h = pl.health
	var tk = Finale.TankLane.new(); tk.level = lvl; tk.tell = 0.3
	tk.from = Vector2(-900, pl.global_position.y); tk.to = Vector2(900, pl.global_position.y)
	lvl.add_child(tk)
	ok(tk.threat(pl.global_position) >= 0.0, "tank lane threatens the rancher")
	await _wait(4.0)
	ok(pl.health == h - 1, "tank charge hits")
	await _wait(1.0); h = pl.health
	var q = Finale.Quake.new(); q.level = lvl; q.tell = 0.4; q.arena = lvl.arena_rect
	lvl.add_child(q); await _wait(0.2)
	ok(not pl.is_inverted(), "quake warns before inverting")
	await _wait(0.5)
	ok(pl.is_inverted() and pl.health == h, "quake inverts controls (no damage)")
	pl.invert_controls(0.0)
	# --- boss 10 hazards
	b = await _boss("boss10")
	ok(b != null and b.get_script().get_global_name() == "DonaldRump" and b.hearts == 34, "boss10 boots with 34 hearts")
	lvl = get_first_node_in_group("boss_level")
	ok(lvl.get_node("Ground").theme == "florida", "boss10 arena on florida tiles")
	_quiet(b)
	pl = get_first_node_in_group("player")
	pl.global_position = Vector2(0, 120)
	await _wait(0.2); h = pl.health
	s = Finale.MarkedStrike.new(); s.level = lvl; s.kind = "golf"; s.tell = 0.3; s.origin = Vector2(0, -300); s.global_position = pl.global_position
	lvl.add_child(s); await _wait(0.8)
	ok(pl.health == h - 1, "golf drive on the rancher hits")
	var w = Finale.WallDrop.new(); w.level = lvl; w.tell = 0.2; w.size = Vector2(220, 26); w.global_position = pl.global_position + Vector2(0, -60)
	lvl.add_child(w); await _wait(0.6)
	var hit: Dictionary = pl.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(pl.global_position, pl.global_position + Vector2(0, -120), 1))
	ok(not hit.is_empty(), "dropped wall blocks movement")
	await _wait(1.6); h = pl.health
	var f = Finale.RallyFan.new(); f.level = lvl; f.arena = lvl.arena_rect; f.global_position = pl.global_position + Vector2(0, 50)
	lvl.add_child(f); await _wait(0.1)
	f.receive_whip(pl.global_position)
	await _wait(0.3)
	ok(not is_instance_valid(f) or f.is_queued_for_deletion() or f._done, "red-hat fan shooed by a whip")
	b.process_mode = Node.PROCESS_MODE_INHERIT
	b.hearts = LC.BOSS10_RAGE_HEARTS + 1
	b.take_hit(1, "whip", pl.global_position)
	await _wait(0.3)
	ok(lvl.hud.callout.visible and lvl.hud.callout_title.text.find("FIRED") >= 0, "rage phase calls YOU'RE FIRED!")
	# --- ending flow
	lvl.state.is_won = true
	lvl.request_next_level()
	for i in 20: await process_frame
	var en = current_scene
	ok(en != null and en.scene_file_path == LC.ENDING_SCENE, "final win -> ending scene")
	var ct: String = en.credits_text()
	ok(ct.find("ROBERT J. MORRIS") >= 0 and ct.find("ECHELON PUBLISHERS GROUP") >= 0 and ct.find("EWAN SHEPHERD, LLM") >= 0, "credits: Robert J. Morris, Echelon, Ewan Shepherd LLM")
	ok(en.phase == "celebrate", "ending opens on the celebration")
	en.skip(); ok(en.phase == "credits", "then credits roll")
	en.skip(); ok(en.phase == "choice" and en.endless_button.visible, "then ENDLESS / TITLE choice")
	en.choose_endless()
	for i in 20: await process_frame
	ok(current_scene.scene_file_path == LC.GAME_SCENE and gp.current_level == 30 and gp.endless, "ENDLESS MODE -> level 30")
	b = await _boss("boss10")
	lvl = get_first_node_in_group("boss_level")
	lvl.state.is_won = true; lvl.request_next_level()
	for i in 20: await process_frame
	current_scene.skip(); current_scene.skip(); current_scene.choose_title()
	for i in 20: await process_frame
	ok(current_scene.scene_file_path == "res://scenes/Title.tscn" and gp.current_level == 1, "RETURN TO TITLE -> title, fresh run")
	# --- level select codes + cheats
	for code in [99, 90, 91, 98]:
		bt._open_pad("level"); bt._pad_text = str(code); bt._pad_submit()
		for i in 12: await process_frame
		var cs := current_scene.scene_file_path if current_scene != null else ""
		var want := GameProgressCheck.stage_scene("boss%d" % bt.boss_for_code(code))
		ok(cs == want, "level select %d -> %s" % [code, want.get_file()])
	bt._open_pad("level"); bt._pad_text = "27"; bt._pad_submit()
	for i in 12: await process_frame
	ok(gp.current_level == 27, "level select 27 still a level")
	bt._apply_code("7474"); ok(bt.god, "7474 god mode still works")
	bt._apply_code("0000"); ok(not bt.god, "0000 clears cheats")
	var ts = load("res://scripts/ui/title_screen.gd")
	ok(ts.BUILD_LABEL.begins_with("BUILD 0") and ts.CREDIT_ASSIST.find("EWAN SHEPHERD, LLM") >= 0, "build label + Ewan Shepherd, LLM credit")
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
