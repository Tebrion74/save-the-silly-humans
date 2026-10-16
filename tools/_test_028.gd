extends SceneTree
## Build 028 checks: title attract mode (idle start, page cycle, all 10 bosses,
## score values from the code, high score page, any input interrupts), cheats +
## long-press keypad still work, title theme plays + respects mute, build label.
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("PASS " if c else "FAIL ") + m)
	if not c: fails += 1
func _initialize() -> void:
	create_timer(240.0).timeout.connect(func(): print("FAIL watchdog"); quit(2))
	_run.call_deferred()
func _wait(s: float) -> void:
	await create_timer(s).timeout
	await process_frame
func _key(k: Key, pressed := true) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = pressed
	Input.parse_input_event(e)
	await process_frame
	await process_frame
func _tap_key(k: Key) -> void:
	await _key(k, true); await _key(k, false)
func _touch(pos: Vector2, pressed: bool) -> void:
	# headless window is not 1280x720: map viewport coords to window coords
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = root.get_final_transform() * pos; e.pressed = pressed
	Input.parse_input_event(e)
	await process_frame
	await process_frame
func _title() -> Node:
	change_scene_to_file("res://scenes/Title.tscn")
	for i in 20: await process_frame
	return current_scene
func _into_attract(ts) -> void:
	ts.wake()
	ts.idle_t = AttractMode.IDLE_SECONDS - 0.05
	await _wait(0.2 + AttractMode.SHUTTER * 2.0)

func _run() -> void:
	var gp := root.get_node("GameProgress")
	var bt := root.get_node("BetaTools")
	var ga := root.get_node("GameAudio")
	gp.high_score = 0
	var ts = await _title()
	ok(ts.BUILD_LABEL == "BUILD 028", "build label 028")
	var credit := false
	for n in ts.get_children():
		if n is Label and (n as Label).text.find("EWAN SHEPHERD, LLM") >= 0 and n.visible:
			credit = true
	ok(credit, "Ewan Shepherd, LLM credit visible on the title")
	# --- music
	ok(ga.TRACKS.has("title") and ga.track == "title", "title theme plays on the title")
	# --- idle start
	ok(not ts.attract.active, "no attract mode right away")
	await _into_attract(ts)
	ok(ts.attract.active and ts.attract.page == "villains0" and ts.attract.visible, "idle %ds -> attract mode (MEET THE VILLAINS)" % int(AttractMode.IDLE_SECONDS))
	ok(ga.track == "title", "title theme keeps playing through attract mode")
	# --- page cycle
	var seen := [ts.attract.page]
	for k in 8:
		ts.attract._page_t = AttractMode.PAGE_SECONDS
		await _wait(AttractMode.SHUTTER * 2.0 + 0.1)
		seen.append(ts.attract.page)
	ok(seen.has("villains1") and seen.has("villains2") and seen.has("score0") and seen.has("score1") and seen.has("title"), "cycles villains 1-3, score table 1-2, back to the title: %s" % [seen])
	ok(not seen.has("hiscore"), "no high score page when there is no high score")
	gp.high_score = 4321
	ok(ts.attract.pages().has("hiscore"), "high score page when one exists")
	ok(AttractMode.PAGE_SECONDS >= 6.0 and AttractMode.PAGE_SECONDS <= 8.0, "pages last 6-8 s")
	# --- content
	var names := []
	for pg in AttractMode.VILLAIN_PAGES:
		for i in pg: names.append(AttractMode.bosses()[i][0])
	ok(names.size() == 10 and names.has("VLADIMIR PUDDIN") and names.has("DONALD RUMP") and names.has("TRUSTIN JUDEAU"), "all 10 bosses on the villain pages")
	for b in AttractMode.bosses():
		ok(ResourceLoader.exists(b[3]) and int(b[2]) > 0, "boss sprite + slot: %s after L%d" % [b[0], b[2]])
	var rows: Array = AttractMode.score_rows(0) + AttractMode.score_rows(1)
	var val := {}
	for r in rows: val[r[1]] = r[2]
	ok(val["SILLY HUMAN SAVED"] == "200" and val["KILLER SHEEP"] == "50" and val["POSSESSED WHIPPED"] == "50" and val["KAREN"] == "100" and val["CANTIFA DRIVEN OFF"] == "75", "score table field values (200/50/50/100/75)")
	ok(val["HIDDEN TREASURE"] == "750" and String(val["STAR COMBO"]).begins_with("200 x2") and val["RALLY FAN"] == "120" and val["BOSS DEFEATED"] == "2500 - 25000", "treasure 750, star combo 200 x2, bosses")
	# --- any input interrupts, instantly
	await _into_attract(ts)
	await _key(KEY_X)
	ok(not ts.attract.active and not ts.attract.visible, "a key press drops attract mode at once")
	await _key(KEY_X, false)
	await _into_attract(ts)
	await _key(KEY_ENTER); await _key(KEY_ENTER, false)
	ok(not ts.attract.active and not ts._starting, "ENTER during attract only returns to the title (no game start)")
	await _into_attract(ts)
	await _touch(Vector2(640, 600), true); await _touch(Vector2(640, 600), false)
	ok(not ts.attract.active and not ts._starting, "a tap drops attract mode (no game start)")
	await _into_attract(ts)
	var mm := InputEventMouseMotion.new(); mm.relative = Vector2(40, 0); mm.position = Vector2(300, 300)
	Input.parse_input_event(mm); await process_frame; await process_frame
	ok(not ts.attract.active, "mouse movement drops attract mode")
	var jb := InputEventJoypadButton.new(); jb.button_index = JOY_BUTTON_A; jb.pressed = true
	await _into_attract(ts)
	Input.parse_input_event(jb); await process_frame; await process_frame
	ok(not ts.attract.active, "gamepad button drops attract mode")
	jb.pressed = false; Input.parse_input_event(jb)
	# --- cheats typed during attract mode
	await _into_attract(ts)
	for k in [KEY_7, KEY_4, KEY_7, KEY_4]: await _tap_key(k)
	ok(bt.god and not ts.attract.active, "7474 typed during attract mode: god mode on")
	for k in [KEY_0, KEY_0, KEY_0, KEY_0]: await _tap_key(k)
	ok(not bt.god, "0000 clears cheats")
	# --- mobile long-press keypad from attract mode
	root.get_node("TouchInput").active = true
	await _into_attract(ts)
	var logo: Rect2 = ts._title_box.get_global_rect()
	await _touch(logo.get_center(), true)
	ok(not ts.attract.active, "touch on attract drops it")
	await _wait(BetaTools.HOLD_SECONDS + 0.4)
	ok(bt._pad != null, "long-press on the logo still opens the keypad")
	await _touch(logo.get_center(), false)
	ts.idle_t = AttractMode.IDLE_SECONDS + 5.0
	await _wait(0.3)
	ok(not ts.attract.active, "no attract mode while the keypad is open")
	bt._close_pad()
	await process_frame
	root.get_node("TouchInput").active = false
	# --- how to play blocks it
	ts.open_howto()
	ts.idle_t = AttractMode.IDLE_SECONDS + 5.0
	await _wait(0.3)
	ok(not ts.attract.active, "no attract mode while HOW TO PLAY is open")
	ts.close_howto()
	# --- mute
	var prev: int = ga.setting
	ga.set_setting(2)
	ok(ga.is_muted() and AudioServer.is_bus_mute(0), "SOUND OFF mutes the title theme (master bus)")
	ga.set_setting(prev)
	ok(not AudioServer.is_bus_mute(0) or prev == 2, "sound setting restored")
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
