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
		elif sc.begins_with("kush"):
			scene = gp.start_at_stage("boss3")
		elif sc.begins_with("shlaus"):
			scene = gp.start_at_stage("boss4")
		elif sc.begins_with("gill"):
			scene = gp.start_at_stage("boss5")
		elif sc.begins_with("nancy"):
			scene = gp.start_at_stage("boss6")
		elif sc in ["star_combo", "reticle_busy", "extra_heart", "reticle_pc", "level", "cheat"]:
			scene = "res://scenes/Main.tscn"
		elif sc.begins_with("bonus"):
			var n := 1
			if sc.length() > 5 and sc.substr(5, 1).is_valid_int():
				n = int(sc.substr(5, 1))
			scene = gp.start_at_stage("bonus", n)
		else:
			scene = gp.start_at_stage("boss1")
		change_scene_to_file(scene)
	if sc_name() == "cheat":
		await create_timer(0.5).timeout
		root.get_node("BetaTools")._apply_code("7474")
	await create_timer(maxf(delay - 0.4, 0.05)).timeout
	_aim_cursor(sc_name())
	if sc_name() == "bonus_multi":
		await _bonus_multi()
	await create_timer(0.4 if sc_name() != "bonus_multi" else 0.12).timeout
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func sc_name() -> String:
	return String(root.get_node("GameProgress").debug_scenario)


## Build 020: put the PC virtual cursor on something worth aiming at, so the
## reticle shows its in-range (green) state in boss / bonus / busy shots.
func _aim_cursor(sc: String) -> void:
	var ma = root.get_node_or_null("MouseAim")
	var lvl = current_scene
	if ma == null or lvl == null or root.get_node("TouchInput").active:
		return
	var p := lvl.get_node_or_null("Entities/Player") as Node2D
	if p == null:
		return
	var tgt: Node2D = null
	if "boss" in lvl and lvl.boss != null and is_instance_valid(lvl.boss) and not sc.ends_with("_title"):
		tgt = lvl.boss
	if tgt == null:
		var best := INF
		for n in get_nodes_in_group("whippable"):
			if n is Node2D and n != p:
				var d: float = (n as Node2D).global_position.distance_to(p.global_position)
				if d > 60.0 and d < best:
					best = d
					tgt = n
	if tgt != null:
		ma.cursor = tgt.get_global_transform_with_canvas().origin + Vector2(0, -12)


## Build 022: line three flying sheep up on the lash and crack once.
func _bonus_multi() -> void:
	var p := get_first_node_in_group("player") as Node2D
	if p == null:
		return
	var whip := p.get_node("Whip")
	var ti = root.get_node("TouchInput")
	var dir: Vector2 = p.global_position.direction_to(ti.get_aim_world(whip))
	var sheep := get_nodes_in_group("bonus_sheep").filter(func(s): return s._started and not s.exploding)
	for i in mini(4, sheep.size()):
		sheep[i].global_position = p.global_position + dir * (70 + i * 50)
		sheep[i].set_physics_process(false)
	await process_frame
	whip.cooldown = 0.0
	whip.fire_whip()
