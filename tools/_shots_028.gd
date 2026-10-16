extends SceneTree
## Build 028 attract-mode screenshots. args: -- <out.png> <page> [touch]
func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): print("SHOT WATCHDOG"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var gp := root.get_node("GameProgress")
	gp.high_score = 1234560
	gp.hs_table = []
	var sample := [["RJM", 1234560, 30, true], ["ACE", 984200, 29, false], ["EWN", 702150, 26, false], ["BOB", 515000, 23, false],
		["SHE", 402880, 20, false], ["EPG", 310400, 17, false], ["YEE", 221000, 14, false], ["HAW", 150250, 11, false],
		["COW", 98000, 8, false], ["BAA", 41500, 5, false]]
	for e in sample: gp.hs_table.append({"i": e[0], "s": e[1], "l": e[2], "c": e[3], "id": 0})
	root.get_node("TouchInput").active = a.has("touch")
	change_scene_to_file("res://scenes/Title.tscn")
	for i in 30: await process_frame
	var ts = current_scene
	if a[1] == "entry":
		gp.reset_progress(); gp.score = 815400; gp.current_level = 24
		gp.hs_table.resize(9)
		var en = InitialsEntry.maybe_show(ts)
		await process_frame
		en.letters = [17, 9, 0]; en.slot = 2
	elif a[1] != "title":
		ts.attract.show_page(a[1])
	await create_timer(3.6).timeout
	for i in 3: await process_frame
	root.get_texture().get_image().save_png(a[0])
	print("saved ", a[0])
	quit()
