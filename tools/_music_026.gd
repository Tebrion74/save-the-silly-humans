extends SceneTree
## Build 026: every music track loads, loops forward, is QOA-compressed and
## long enough; each biome level / bonus / boss starts its own track; the
## ON -> LOW -> OFF sound toggle still mutes and restores.
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("PASS " if c else "FAIL ") + m)
	if not c: fails += 1
func _initialize() -> void:
	create_timer(240.0).timeout.connect(func(): print("FAIL watchdog"); quit(2))
	_run.call_deferred()
func _run() -> void:
	for k in GameAudio.TRACKS:
		var s: AudioStreamWAV = GameAudio.TRACKS[k]
		ok(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD and s.format == AudioStreamWAV.FORMAT_QOA and s.get_length() > 20.0 and s.loop_end >= int(s.get_length() * s.mix_rate) - 2,
			"%s loops (%.1f s, QOA)" % [k, s.get_length()])
	var ga = root.get_node("GameAudio")
	var gp = root.get_node("GameProgress")
	var want := {1: "level_prairie", 4: "level_med", 7: "level_texas", 10: "level_bavaria", 13: "level_pnw",
		16: "level_norcal", 19: "level_midwest", 22: "level_ukraine"}
	for lv in want:
		gp.reset_progress(); gp.current_level = lv
		change_scene_to_file("res://scenes/Main.tscn")
		for i in 12: await process_frame
		ok(ga.track == want[lv] and ga.is_music_playing(), "L%d plays %s (got %s)" % [lv, want[lv], ga.track])
	var cyc := {}
	for lv in range(24, 32):
		gp.reset_progress(); gp.current_level = lv
		change_scene_to_file("res://scenes/Main.tscn")
		for i in 10: await process_frame
		cyc[ga.track] = true
	ok(cyc.size() == 8, "L24-31 cycle all 8 biome tracks (%d)" % cyc.size())
	for st in ["bonus", "boss1", "boss7", "boss8"]:
		change_scene_to_file(gp.start_at_stage(st))
		for i in 12: await process_frame
		var exp: String = {"bonus": "bonus", "boss1": "boss", "boss7": "boss7", "boss8": "boss8"}[st]
		ok(ga.track == exp and ga.is_music_playing(), "%s plays %s (got %s)" % [st, exp, ga.track])
	# sound toggle: ON -> LOW -> OFF -> ON
	ga.set_setting(0)
	var vol_on := AudioServer.get_bus_volume_db(0)
	ok(not ga.is_muted() and not AudioServer.is_bus_mute(0), "sound ON: master audible")
	ga.cycle()
	ok(ga.setting == 1 and AudioServer.get_bus_volume_db(0) < vol_on and not AudioServer.is_bus_mute(0), "sound LOW: quieter, not muted")
	ga.cycle()
	ok(ga.setting == 2 and ga.is_muted() and AudioServer.is_bus_mute(0), "sound OFF: master muted")
	var pos0: float = ga._music.get_playback_position()
	for i in 30: await process_frame
	ok(ga.is_music_playing(), "music keeps its place while muted")
	ga.cycle()
	ok(ga.setting == 0 and not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(0), vol_on), "back to sound ON")
	ga.set_setting(0)
	print("FAILS ", fails)
	quit(1 if fails else 0)
