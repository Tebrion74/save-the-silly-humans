extends SceneTree
## Build 015 boss screenshots (needs a real renderer, e.g. xvfb-run + opengl3):
##   godot --path . --rendering-driver opengl3 -s res://tools/boss_shots.gd -- \
##       <out.png> <seconds> --scenario=boss_attack [--touch]
## Scenario "howto" renders the How to Play screen instead of the arena.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var delay: float = float(args[1])
	var gp := root.get_node("GameProgress")
	if String(gp.debug_scenario) == "howto":
		change_scene_to_file("res://scenes/Title.tscn")
		await create_timer(0.3).timeout
		current_scene.open_howto()
	else:
		gp.start_at_boss()
		change_scene_to_file(LevelConfig.BOSS_SCENE)
	await create_timer(delay).timeout
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
