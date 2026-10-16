extends SceneTree
## Build 028 top-10 high scores: qualify / order / trim, persistence in
## user://, one entry per run, initials entry (keys, letters, touch), game over
## + ending flows, cheated runs never qualify, attract table.
var fails := 0
var _backup := ""
func ok(c: bool, m: String) -> void:
	print(("PASS " if c else "FAIL ") + m)
	if not c: fails += 1
func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): print("FAIL watchdog"); _restore(); quit(2))
	_run.call_deferred()
func _wait(s: float) -> void:
	await create_timer(s).timeout
	await process_frame
func _key(k: Key) -> void:
	for p in [true, false]:
		var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = p
		if k >= KEY_A and k <= KEY_Z: e.unicode = k
		Input.parse_input_event(e)
		await process_frame
func _tap(pos: Vector2) -> void:
	for p in [true, false]:
		var e := InputEventScreenTouch.new(); e.index = 0; e.position = root.get_final_transform() * pos; e.pressed = p
		Input.parse_input_event(e)
		await process_frame
func _restore() -> void:
	var gp := root.get_node("GameProgress")
	if _backup != "":
		var f := FileAccess.open(gp.SAVE_PATH, FileAccess.WRITE); f.store_string(_backup); f.close()
	elif FileAccess.file_exists(gp.SAVE_PATH):
		DirAccess.remove_absolute(gp.SAVE_PATH)
func _entry() -> Node:
	for i in 10:
		await process_frame
		var n = get_first_node_in_group("initials_entry")
		if n != null: return n
	return null

func _run() -> void:
	var gp := root.get_node("GameProgress")
	var bt := root.get_node("BetaTools")
	if FileAccess.file_exists(gp.SAVE_PATH): _backup = FileAccess.get_file_as_string(gp.SAVE_PATH)
	bt._apply_code("0000"); bt.tainted = false
	gp.reset_progress(); gp.hs_table = []; gp.high_score = 0
	# --- qualify, order, trim
	ok(gp.qualifies(10) and not gp.qualifies(0), "empty table: any score > 0 qualifies")
	bt.tainted = true
	ok(not gp.qualifies(999999) and not gp.needs_initials(), "cheated run never qualifies")
	bt.tainted = false
	var scores := [500, 9000, 1200, 1200, 70000, 300, 4400, 8800, 15000, 2500, 650]
	var names := ["AAA", "BBB", "CCC", "DDD", "EEE", "FFF", "GGG", "HHH", "III", "JJJ", "KKK"]
	for i in scores.size():
		gp.run_entry = -1
		gp.submit_initials(names[i], scores[i], i + 1)
	ok(gp.hs_table.size() == 10, "table keeps 10")
	var ordered := true
	for i in 9:
		if int(gp.hs_table[i]["s"]) < int(gp.hs_table[i + 1]["s"]): ordered = false
	ok(ordered and gp.hs_table[0]["i"] == "EEE" and int(gp.hs_table[0]["s"]) == 70000, "sorted best first")
	ok(int(gp.hs_table[9]["s"]) == 500 and not gp.hs_table.any(func(e): return int(e["s"]) == 300), "lowest (300) dropped")
	var ci := -1; var di := -1
	for i in 10:
		if gp.hs_table[i]["i"] == "CCC": ci = i
		if gp.hs_table[i]["i"] == "DDD": di = i
	ok(ci >= 0 and di == ci + 1, "a tie keeps the older entry above")
	ok(not gp.qualifies(500) and gp.qualifies(501), "must beat the 10th to qualify")
	ok(gp.high_score == 70000, "high score follows the table")
	# --- persistence
	var cfg := ConfigFile.new()
	ok(cfg.load(gp.SAVE_PATH) == OK and (cfg.get_value("scores", "top10", []) as Array).size() == 10, "table saved to user:// (%s)" % ProjectSettings.globalize_path(gp.SAVE_PATH))
	var before := JSON.stringify(gp.hs_table)
	gp.hs_table = []; gp.high_score = 0
	gp.load_high_score()
	ok(JSON.stringify(gp.hs_table) == before and gp.high_score == 70000, "table reloads identically")
	# --- one entry per run
	gp.reset_progress(); gp.score = 20000; gp.current_level = 12
	ok(gp.needs_initials(), "new run with 20000 needs initials")
	gp.submit_initials("RUN")
	gp.score = 26000; gp.current_level = 13
	ok(not gp.needs_initials(), "same run, second game over: no second prompt")
	var run_e: Array = gp.hs_table.filter(func(e): return e["i"] == "RUN")
	ok(run_e.size() == 1 and int(run_e[0]["s"]) == 26000 and int(run_e[0]["l"]) == 13, "...but its entry rises to 26000 / L13")
	# --- entry screen: keys + typing
	gp.reset_progress(); gp.score = 33000; gp.current_level = 9
	change_scene_to_file("res://scenes/Title.tscn")
	for i in 10: await process_frame
	var e = InitialsEntry.maybe_show(current_scene)
	ok(e != null, "entry screen opens for a qualifying score")
	await process_frame
	await _key(KEY_UP)
	ok(e.initials()[0] == "-", "UP from A wraps to the last character")
	await _key(KEY_DOWN); await _key(KEY_DOWN); await _key(KEY_S)
	ok(e.initials()[0] == "C", "DOWN / S cycle forward (A->C)")
	await _key(KEY_W)
	ok(e.initials()[0] == "B", "W cycles back")
	await _key(KEY_RIGHT)
	ok(e.slot == 1, "RIGHT moves to the next letter")
	await _key(KEY_LEFT); await _key(KEY_R); await _key(KEY_J); await _key(KEY_M)
	ok(e.initials() == "RJM" and e.slot == 2, "typing letters fills the slots (RJM)")
	await _key(KEY_ENTER)
	ok(e.done and e.rank >= 0 and gp.hs_table.any(func(x): return x["i"] == "RJM" and int(x["s"]) == 33000 and int(x["l"]) == 9), "ENTER saves RJM 33000 L9 (rank %d)" % (e.rank + 1))
	await _wait(1.8)
	ok(not is_instance_valid(e), "entry screen closes after the rank flash")
	# --- touch arrows
	gp.reset_progress(); gp.score = 34000
	root.get_node("TouchInput").active = true
	e = InitialsEntry.maybe_show(current_scene)
	await process_frame
	await _tap(e.down_rect(0).get_center()); await _tap(e.down_rect(0).get_center())
	await _tap(e.right_rect().get_center())
	await _tap(e.up_rect(1).get_center())
	await _tap(e.down_rect(2).get_center())
	ok(e.initials() == "C-B", "tapping arrows picks C, -, B (got %s)" % e.initials())
	await _tap(e.ok_rect().get_center())
	ok(e.done and gp.hs_table.any(func(x): return x["i"] == "C-B"), "tapping OK saves")
	root.get_node("TouchInput").active = false
	await _wait(1.8)
	# --- game over flow on a level
	gp.reset_progress(); gp.current_level = 6
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 30: await physics_frame
	var lc = get_first_node_in_group("level_controller")
	gp.score = 99000
	lc.state.trigger_lose("TEST", "rancher")
	e = await _entry()
	ok(e != null, "game over with a top-10 score -> initials screen")
	await _key(KEY_R)
	ok(is_instance_valid(lc) and lc.state.is_lost and e.initials()[0] == "R", "R types a letter instead of restarting the level")
	await _key(KEY_O); await _key(KEY_B); await _key(KEY_ENTER)
	ok(gp.hs_table[0]["i"] == "ROB" and int(gp.hs_table[0]["s"]) == 99000 and int(gp.hs_table[0]["l"]) == 6, "ROB 99000 L6 is now 1st")
	await _wait(1.8)
	# --- cheated game over: no entry
	gp.reset_progress(); gp.current_level = 6
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 30: await physics_frame
	bt._apply_code("7474")
	lc = get_first_node_in_group("level_controller")
	gp.score = 500000
	lc.state.trigger_lose("TEST", "rancher")
	ok(await _entry() == null and not gp.hs_table.any(func(x): return int(x["s"]) == 500000), "cheated run: no initials screen, not saved")
	bt._apply_code("0000"); bt.on_new_run()
	# --- ending
	gp.reset_progress(); gp.score = 120000; gp.current_level = 29; gp.game_cleared = true
	change_scene_to_file("res://scenes/ui/Ending.tscn")
	e = await _entry()
	ok(e != null and e.cleared, "the ending asks for initials (cleared run)")
	var ph: String = current_scene.phase
	await _key(KEY_A); await _key(KEY_C); await _key(KEY_E)
	ok(current_scene.phase == ph, "keys go to the entry, not the ending")
	await _key(KEY_ENTER)
	ok(gp.hs_table[0]["i"] == "ACE" and bool(gp.hs_table[0]["c"]), "ACE saved as 1st, ALL CLEAR")
	await _wait(1.8)
	# --- attract table
	change_scene_to_file("res://scenes/Title.tscn")
	for i in 20: await process_frame
	var ts = current_scene
	ok(ts.attract.pages().has("hiscore") and ts.attract.table().size() == 10 and ts.attract.table()[0]["i"] == "ACE", "attract high score page shows the top-10 table")
	_restore()
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
