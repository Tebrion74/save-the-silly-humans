extends SceneTree
## Build 030 level bot (from 020): + arg 5 = cameo party 0|1; reports cameos seen.
## Temporary build 020 level bot: plays one level and prints a JSON line.
## args: -- <level> <seed> <old_targets 0|1> [time_scale]
## Herds: walks behind the nearest silly human (relative to the safe zone) and
## grab-throws it toward the zone; cracks sheep / possessed / Karens / Cantifa
## that get close; walks over nearby power-ups. Uses the real input actions,
## the whip API and MouseAim's cursor (no teleporting, no state edits).
var level := 1
var seed_v := 1
var old_targets := false
var ts := 4.0
var lvl
var pl
var wh
var zone: Node2D
var MA
var t := 0.0
var done := false
var party := false
var seen := {}

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 1: level = int(a[0])
	if a.size() >= 2: seed_v = int(a[1])
	if a.size() >= 3: old_targets = a[2] == "1"
	if a.size() >= 4: ts = float(a[3])
	if a.size() >= 5: party = a[4] == "1"
	_go.call_deferred()

func _go() -> void:
	seed(seed_v)
	var gp = root.get_node("GameProgress")
	MA = root.get_node("MouseAim")
	gp.reset_progress()
	root.get_node("BetaTools").cameo_party = party
	gp.current_level = level
	Engine.time_scale = ts
	change_scene_to_file(load("res://scripts/level_config.gd").GAME_SCENE)
	for i in 12:
		await physics_frame
	lvl = get_first_node_in_group("level_controller")
	lvl.drop_rng.seed = seed_v * 7919 + level
	if old_targets:
		var old_t := mini(5 + (level - 1), 15)
		lvl.target_rescued = old_t
		lvl.state.target_rescued = old_t
	pl = get_first_node_in_group("player")
	wh = pl.get_node("Whip")
	zone = get_first_node_in_group("safe_zones")
	physics_frame.connect(_tick)
	physics_frame.connect(func() -> void:
		for c in get_nodes_in_group("cameo"):
			seen[c.id] = true)
	create_timer(600.0 * ts).timeout.connect(func() -> void: _finish("timeout"))
	lvl.state.won.connect(func() -> void: _finish("won"))
	lvl.state.lost.connect(func(_r) -> void: _finish("lost"))

func _finish(res: String) -> void:
	if done:
		return
	done = true
	var s = lvl.state
	print("BOTJSON ", JSON.stringify({"level": level, "seed": seed_v, "old": old_targets, "result": res,
		"target": s.target_rescued, "rescued": s.rescued_humans, "dead": s.dead_humans, "time": int(lvl.round_time),
		"hp": pl.health, "maxhp": pl.maximum_health, "pickups": lvl.powerups_collected, "map_spawns": lvl.map_powerups_spawned,
		"star_saves": lvl.star_saves, "star_pts": lvl.star_points, "best_combo": lvl.star_best_combo, "score": lvl.current_score(), "cameos": lvl.cameo_director.spawned, "seen": seen}))
	Engine.time_scale = 1.0
	quit()

func _steer(v: Vector2) -> void:
	for pair in [["move_right", maxf(v.x, 0.0)], ["move_left", maxf(-v.x, 0.0)], ["move_down", maxf(v.y, 0.0)], ["move_up", maxf(-v.y, 0.0)]]:
		if pair[1] > 0.05:
			Input.action_press(pair[0], minf(pair[1], 1.0))
		else:
			Input.action_release(pair[0])

func _aim(world: Vector2) -> void:
	MA.cursor = pl.get_canvas_transform() * world

func _nearest(groups: Array, maxd: float, pred := Callable()) -> Node2D:
	var best: Node2D = null
	var bd := maxd
	for g in groups:
		for n in get_nodes_in_group(g):
			if not n is Node2D or not is_instance_valid(n) or n.is_queued_for_deletion():
				continue
			if pred.is_valid() and not pred.call(n):
				continue
			var d: float = (n as Node2D).global_position.distance_to(pl.global_position)
			if d < bd:
				bd = d
				best = n
	return best

func _tick() -> void:
	if done or lvl == null or not is_instance_valid(pl) or pl._dead:
		return
	if not lvl.rescues_unlocked:
		return
	var me: Vector2 = pl.global_position
	var star: bool = pl.get_node("PowerUps").is_invincible()
	# 1) threats close by: crack them (during star power, crack anything saveable)
	var threat := _nearest(["sheep", "possessed", "cantifa"], 200.0 if not star else wh.whip_range * 0.95,
		func(n): return not ("exploding" in n and n.exploding))
	if star:
		var any := _nearest(["humans", "possessed", "sheep", "cantifa"], wh.whip_range * 0.95,
			func(n): return StarSave.kind_of(n) != "")
		if any != null:
			threat = any
	if threat != null and wh.cooldown <= 0.0:
		_aim(threat.global_position)
		wh.weapon_primary()
	# 2) power-up nearby
	var pk := _nearest(["powerups"], 260.0)
	var goal := Vector2.INF
	var h: Node2D = null
	if pk != null:
		goal = pk.global_position
	else:
		h = _nearest(["humans"], INF, func(n): return not n.possessed and not n.has_meta("star_saved") and not n.rescued)
		if h != null:
			var to_zone: Vector2 = h.global_position.direction_to(zone.global_position)
			goal = h.global_position - to_zone * 110.0
	if goal != Vector2.INF:
		var dv: Vector2 = goal - me
		if dv.length() > 18.0:
			_steer(dv.normalized())
		else:
			_steer(Vector2.ZERO)
		if h != null and dv.length() < 70.0 and wh.grab_cooldown <= 0.0 and h.global_position.distance_to(me) < wh.whip_range * 0.9:
			_aim(h.global_position)
			_steer(h.global_position.direction_to(zone.global_position))
			wh.weapon_secondary()
	else:
		_steer(Vector2.ZERO)
