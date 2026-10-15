extends SceneTree
## Build 023: detects spinning / stuck humans. For each biome level, plays
## N seconds with an idle (god-mode) rancher and watches every human:
##  SPIN  = facing direction changes >= 8 times within 2 s while net travel < 32 px
##  STUCK = wants to move (> 30 px/s intended) for 3 s but travels < 12 px
## PASS = no biome level has more than 2 events (the 022 baseline had 4-76).
## args: -- [seconds=90] [levels=1,3,6,9,12,15] [--quiet]
var events: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var secs := 90.0
	var levels := [1, 3, 6, 9, 12, 15]
	var quiet := false
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0].is_valid_float(): secs = float(a[0])
	if a.size() > 1 and not a[1].begins_with("--"):
		levels = Array(a[1].split(",")).map(func(x): return int(x))
	quiet = "--quiet" in a
	var gp := root.get_node("GameProgress")
	var bt := root.get_node("BetaTools")
	var total_spin := 0
	var total_stuck := 0
	var worst := 0
	for lv in levels:
		seed(lv * 1009 + 69)
		gp.reset_progress()
		gp.current_level = lv
		bt.god = true
		change_scene_to_file("res://scenes/Main.tscn")
		for i in 10: await physics_frame
		var g = get_first_node_in_group("level_controller").get_node("Ground")
		var hist := {}   # id -> {anims: [[t, name]], pos: [[t, pos]], want: [[t, len]]}
		var t := 0.0
		var spins := 0
		var stucks := 0
		var flagged := {}
		while t < secs:
			await physics_frame
			t += 1.0 / 60.0
			for h in get_nodes_in_group("humans") + get_nodes_in_group("possessed"):
				if not is_instance_valid(h) or h.rescued or h._dead or h.exploding:
					continue
				var id := h.get_instance_id()
				if not hist.has(id):
					hist[id] = {"a": [], "p": [], "w": [], "last": ""}
				var H: Dictionary = hist[id]
				# facing changes only (stand <-> walk is not spinning)
				var an := String(h.sprite.animation)
				if an != H["last"]:
					H["a"].append(t)
					H["last"] = an
				H["p"].append([t, h.global_position])
				H["w"].append([t, h.velocity.length(), h.get_real_velocity().length()])
				while H["a"].size() > 0 and t - H["a"][0] > 2.0: H["a"].pop_front()
				while H["p"].size() > 0 and t - H["p"][0][0] > 3.0: H["p"].pop_front()
				while H["w"].size() > 0 and t - H["w"][0][0] > 3.0: H["w"].pop_front()
				if t < 3.0 or h._throw_timer > 0.0 or h.stagger_timer > 0.0:
					continue
				# a Karen hugging the (idle, god-mode) rancher is mobbing him, not stuck
				var pl := get_first_node_in_group("player") as Node2D
				if h.possessed and pl != null and h.hunt_target == pl and h.global_position.distance_to(pl.global_position) < 64.0:
					H["w"].clear()
					continue
				var p2: Array = H["p"].filter(func(e): return t - e[0] <= 2.0)
				var net: float = (p2[-1][1] as Vector2).distance_to(p2[0][1]) if p2.size() > 1 else 0.0
				var cooldown_ok: bool = not flagged.has(id) or t - flagged[id] > 3.0
				if H["a"].size() >= 8 and net < 32.0 and cooldown_ok:
					spins += 1
					flagged[id] = t
					events.append(_snap("SPIN", lv, g, h, t, H["a"].size(), net))
				elif H["w"].size() >= 170 and cooldown_ok:
					var want: float = H["w"].reduce(func(acc, e): return acc + e[1], 0.0) / H["w"].size()
					var trav: float = (H["p"][-1][1] as Vector2).distance_to(H["p"][0][1])
					var real: float = H["w"].reduce(func(acc, e): return acc + e[2], 0.0) / H["w"].size()
					if want > 30.0 and trav < 12.0 and real < want * 0.35:
						stucks += 1
						flagged[id] = t
						events.append(_snap("STUCK", lv, g, h, t, H["a"].size(), trav))
		total_spin += spins
		total_stuck += stucks
		worst = maxi(worst, spins + stucks)
		print("LEVEL %d %s spins=%d stucks=%d humans_seen=%d" % [lv, g.theme, spins, stucks, hist.size()])
	if not quiet:
		for e in events.slice(0, 40):
			print(e)
	print("RESULT spins=%d stucks=%d" % [total_spin, total_stuck])
	print("PASS" if worst <= 2 else "FAIL worst level had %d spin+stuck events" % worst)
	bt.god = false
	quit()

func _snap(kind: String, lv: int, g, h, t: float, flips: int, net: float) -> String:
	var cell: Vector2i = g.local_pos_to_local_cell(g.to_local(h.global_position))
	var sheep_n := 0
	for s in get_nodes_in_group("sheep"):
		if s is Node2D and (s as Node2D).global_position.distance_to(h.global_position) < h.flee_range:
			sheep_n += 1
	var zone = h._nearest_safe_zone()
	return "mode=%s/%s %s L%d t=%.1f cell=%s flips=%d net=%.0f poss=%s safety=%s sheep_in_range=%d zone_avoid=%s pausing=%s wall=%s edge=%s vel=%s" % [
		h.get("_last_mode"), h.get("_hunt_mode"), kind, lv, t, cell, flips, net, h.possessed, h.heading_to_safety(), sheep_n, zone != null, h._pausing,
		h.is_on_wall(), not g.is_interior_local(cell, 2), h.velocity.round()]
