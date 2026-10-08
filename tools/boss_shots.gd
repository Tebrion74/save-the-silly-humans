extends SceneTree
## Build 015 boss screenshots (needs a real renderer, e.g. xvfb-run + opengl3):
##   godot --path . --rendering-driver opengl3 -s res://tools/boss_shots.gd -- \
##       <out.png> <seconds> --scenario=boss_attack [--touch]
## Scenario "howto" renders the How to Play screen, "title" the title screen.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var delay: float = float(args[1])
	var gp := root.get_node("GameProgress")
	if String(gp.debug_scenario) == "title":
		change_scene_to_file("res://scenes/Title.tscn")
	elif String(gp.debug_scenario) == "howto":
		change_scene_to_file("res://scenes/Title.tscn")
		await create_timer(0.3).timeout
		current_scene.open_howto()
	else:
		# build 016: "huval*" -> boss 2, "bonus*" -> bonus stage, else Trustin
		var sc := String(gp.debug_scenario)
		var scene := ""
		if sc.begins_with("cantifa"):
			gp.current_level = 4
			scene = "res://scenes/Main.tscn"
		elif sc.begins_with("huval"):
			scene = gp.start_at_stage("boss2")
		elif sc.begins_with("bonus"):
			var n := 1
			if sc.length() > 5 and sc.substr(5, 1).is_valid_int():
				n = int(sc.substr(5, 1))
			scene = gp.start_at_stage("bonus", n)
		else:
			scene = gp.start_at_stage("boss1")
		change_scene_to_file(scene)
	await create_timer(delay).timeout
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
