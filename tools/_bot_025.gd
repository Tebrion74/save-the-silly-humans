extends SceneTree
## Build 025 boss bot (not shipped; 020 bot + boss 7/8 hazards). Touch-assist play, same skill
## table as the 015b/016 bots. args: <kush|shlaus> <skill> <runs> <seed>
const SKILLS := {
	"perfect": {"react": 0.0, "miss": 0.0, "jit": 0.0, "wd": Vector2(0.0, 0.0)},
	"good": {"react": 0.16, "miss": 0.1, "jit": 15.0, "wd": Vector2(0.15, 0.45)},
	"avg": {"react": 0.24, "miss": 0.22, "jit": 28.0, "wd": Vector2(0.3, 0.9)},
	"weak": {"react": 0.32, "miss": 0.35, "jit": 40.0, "wd": Vector2(0.5, 1.3)},
}
var sk: Dictionary
var which := "kush"
var rng := RandomNumberGenerator.new()
var seen := {}
var ignore := {}
var results: Array = []

func _initialize() -> void:
	create_timer(3000.0, true, false, true).timeout.connect(func(): print("BOT WATCHDOG"); quit(3))
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	which = args[0]
	sk = SKILLS[args[1]]
	var runs := int(args[2])
	rng.seed = int(args[3])
	# build 020: run faster with the same 1/60 s physics step
	var spd := int(args[4]) if args.size() > 4 else 1
	Engine.physics_ticks_per_second = 60 * spd
	Engine.max_physics_steps_per_frame = 8 * spd
	Engine.time_scale = spd
	root.get_node("TouchInput").active = true
	root.get_node("TouchInput").forced = true
	for i in runs:
		var r = await one_run(i)
		results.append(r)
		print("RUN ", which, " ", args[1], " ", i, " ", JSON.stringify(r))
	var wins := 0
	var tt := 0.0
	var dmg := {}
	for r in results:
		if r.won:
			wins += 1
			tt += r.t
		for k in r.dmg:
			dmg[k] = int(dmg.get(k, 0)) + int(r.dmg[k])
	print("SUMMARY ", which, " ", args[1], " wins ", wins, "/", runs, " avg_win_time ", snappedf(tt / wins if wins > 0 else 0.0, 0.1), " damage_sources ", JSON.stringify(dmg))
	quit()

func one_run(i: int) -> Dictionary:
	var gp := root.get_node("GameProgress")
	var scene: String = gp.start_at_stage({"kush": "boss3", "shlaus": "boss4", "gill": "boss5", "nancy": "boss6", "rogan": "boss7", "violent": "boss8"}[which])
	seen.clear()
	ignore.clear()
	change_scene_to_file(scene)
	var lvl = null
	for k in 600:
		await process_frame
		lvl = current_scene
		if lvl != null and "boss" in lvl and lvl.boss != null and lvl.has_node("Entities/Player"):
			break
	if lvl == null or not ("boss" in lvl) or lvl.boss == null:
		print("BOOT FAIL ", scene)
		quit(2)
		return {}
	var boss = lvl.boss
	var p = lvl.get_node("Entities/Player")
	var whip = p.get_node("Whip")
	var t := 0.0
	var wait := -1.0
	var whips := 0
	while t < 300.0:
		await physics_frame
		var dt := 1.0 / 60.0
		t += dt
		if lvl.state.is_won or lvl.state.is_lost or not is_instance_valid(boss):
			break
		root.get_node("TouchInput").move_vector = _steer(p, boss, t)
		var tgt = null
		var tgt_d := INF
		for g in ["micro_sheep", "robo_sheep", "ufo", "drone"]:
			for s in get_nodes_in_group(g):
				if not is_instance_valid(s) or ("exploding" in s and s.exploding) or ("warp_in" in s and s.warp_in > 0.0):
					continue
				if not _noticed(s, t):
					continue
				var d: float = p.global_position.distance_to(s.global_position)
				if d < 150.0 and d < tgt_d:
					tgt = s
					tgt_d = d
		var bpos: Vector2 = boss.global_position + Vector2(0, -10)
		var shielded: bool = boss.invuln > 0.0 or boss.state == boss.S.PHOTO_OP or boss.state == boss.S.TELEPORT
		if tgt == null and p.global_position.distance_to(bpos) < 205.0 and not shielded and boss.state != 0:
			tgt = boss
		if tgt != null and whip.cooldown <= 0.0:
			if wait < 0.0:
				wait = rng.randf_range(sk.wd.x, sk.wd.y) * (0.5 if tgt != boss else 1.0)
			wait -= dt
			if wait <= 0.0:
				wait = -1.0
				var aim: Vector2 = bpos if tgt == boss else tgt.global_position
				var ang := deg_to_rad(rng.randfn(0.0, float(sk.jit)))
				p.facing = p.global_position.direction_to(aim).rotated(ang)
				whip.fire_whip()
				whips += 1
		elif tgt == null:
			wait = -1.0
	root.get_node("TouchInput").move_vector = Vector2.ZERO
	var dmg := {"contact": int(lvl.contact_hits_taken)}
	if which == "kush":
		dmg["strike"] = int(lvl.strike_hits_taken)
		dmg["strafe"] = int(lvl.strafe_hits_taken)
	else:
		dmg["poutine"] = int(lvl.poutine_hits_taken)
		dmg["robo"] = int(lvl.robo_hits_taken)
		dmg["micro"] = int(lvl.micro_nibbles)
		dmg["envelope"] = int(lvl.envelope_hits_taken)
		dmg["reset"] = int(lvl.reset_hits_taken)
		if "tech_hits" in lvl:
			for k in lvl.tech_hits:
				dmg[k] = int(lvl.tech_hits[k])
	var r := {"won": bool(lvl.state.is_won), "t": snappedf(t, 0.1), "hp": int(p.health), "whips": whips,
		"boss": int(boss.hearts) if is_instance_valid(boss) else 0, "dmg": dmg,
		"fired": boss.attacks_fired if is_instance_valid(boss) else {}}
	if which == "kush":
		r["ff"] = int(lvl.friendly_fire)
	return r

func _noticed(n, t: float) -> bool:
	var id: int = n.get_instance_id()
	if not seen.has(id):
		seen[id] = t
		if rng.randf() < float(sk.miss):
			ignore[id] = true
	return not ignore.has(id) and t - float(seen[id]) >= float(sk.react)

func _steer(p, boss, t: float) -> Vector2:
	var pos: Vector2 = p.global_position
	var bpos: Vector2 = boss.global_position
	var to_b := bpos - pos
	var d := to_b.length()
	var want := Vector2.ZERO
	if boss.state == boss.S.PHOTO_OP:
		want = -to_b.normalized() * 0.5 if d < 220.0 else Vector2.ZERO
	elif d > 185.0:
		want = to_b.normalized()
	elif d < 120.0:
		want = -to_b.normalized()
	else:
		want = to_b.normalized().orthogonal() * 0.4
	var dodge := Vector2.ZERO
	var threat := false
	var tree: SceneTree = p.get_tree()
	# airstrike / carpet marks: get out of (and stay out of) the circles
	for m in tree.get_nodes_in_group("airstrike_mark"):
		if not is_instance_valid(m) or not m.is_live() or not _noticed(m, t):
			continue
		var rel: Vector2 = pos - (m.global_position as Vector2)
		var dd := rel.length()
		var r: float = m.radius + 22.0
		if dd < r:
			var away := rel / dd if dd > 1.0 else Vector2.RIGHT.rotated(rng.randf() * TAU)
			dodge += away * (1.5 + 2.0 * m.progress())
			threat = true
	# strafing lanes
	for s in tree.get_nodes_in_group("strafe_run"):
		if not is_instance_valid(s) or not _noticed(s, t):
			continue
		var lc: Vector2 = s.lane_coords(pos)
		if absf(lc.y) < s.half_width + 24.0:
			var sgn := 1.0 if lc.y >= 0.0 else -1.0
			dodge += s.dir.orthogonal() * sgn * 3.0
			threat = true
	# GREAT RESET: get into a gap before the ring passes
	for rg in tree.get_nodes_in_group("reset_ring"):
		if not is_instance_valid(rg) or not _noticed(rg, t):
			continue
		var rd: float = rg.ring_dist(pos)
		if rg.is_expanding() and rg.radius > rd + LevelConfig.BOSS4_RESET_THICK:
			continue
		if rg.in_gap(pos) and absf(_gap_off(rg, pos)) < deg_to_rad(LevelConfig.BOSS4_RESET_GAP_DEG) * 0.3:
			dodge += Vector2.ZERO
			threat = true
			want = Vector2.ZERO
			continue
		var rel: Vector2 = pos - (rg.global_position as Vector2)
		var cur := atan2(rel.y / 0.75, rel.x)
		var best := 0.0
		var bd := INF
		for g in rg.gaps:
			var ad := absf(angle_difference(cur, float(g)))
			if ad < bd:
				bd = ad
				best = float(g)
		var dist := maxf(rd, 140.0)
		var goal: Vector2 = (rg.global_position as Vector2) + Vector2(cos(best) * dist, sin(best) * dist * 0.75)
		dodge += pos.direction_to(goal) * 3.0
		threat = true
	# poutine / envelopes
	for pt in tree.get_nodes_in_group("poutine"):
		if not is_instance_valid(pt) or not _noticed(pt, t):
			continue
		if "mode" in pt and pt.mode == "lob":
			var tg: Vector2 = pt.target
			if pos.distance_to(tg) < 72.0:
				var away: Vector2 = tg.direction_to(pos)
				if away == Vector2.ZERO:
					away = Vector2.RIGHT
				dodge += away * 2.0
				threat = true
			continue
		if not ("velocity" in pt):
			continue
		var v: Vector2 = pt.velocity
		if v.length() < 1.0:
			continue
		var rel: Vector2 = pos - (pt.global_position as Vector2)
		var tca: float = rel.dot(v) / v.length_squared()
		if tca < 0.0 or tca > 0.9:
			continue
		var closest: Vector2 = rel - v * tca
		if closest.length() < 50.0:
			var side: Vector2 = closest.normalized() if closest.length() > 1.0 else v.orthogonal().normalized()
			dodge += side * (1.5 + (0.9 - tca))
			threat = true
	# envelope fan / delegate aim: sidestep the telegraphed lines
	if which in ["shlaus", "gill", "nancy", "rogan", "violent"] and boss.state == boss.S.WINDUP and boss.attack == "envelopes" and _noticed(boss, t) and boss.state_t > float(sk.react):
		# head for the middle between two lanes (or outside the fan)
		var o: Vector2 = bpos + Vector2(0, -20)
		var rel2 := pos - o
		var dist2 := rel2.length()
		if dist2 > 1.0:
			var aim0: Vector2 = boss._aim
			var th := aim0.angle_to(rel2)
			var fan := deg_to_rad(LevelConfig.BOSS4_ENVELOPE_FAN_DEG)
			var n: int = boss.envelope_dirs().size()
			var mid := (n - 1) * 0.5
			var cands: Array = [-(mid + 1.0) * fan, (mid + 1.0) * fan]
			for k in n - 1:
				cands.append((float(k) - mid + 0.5) * fan)
			var best := 0.0
			var bd := INF
			for c in cands:
				if absf(float(c) - th) < bd:
					bd = absf(float(c) - th)
					best = float(c)
			var lane_px := INF
			for k in n:
				lane_px = minf(lane_px, absf(sin(th - (float(k) - mid) * fan)) * dist2)
			if lane_px < LevelConfig.BOSS4_ENVELOPE_HIT_RADIUS + 18.0:
				var goal: Vector2 = o + aim0.rotated(best) * dist2
				dodge += pos.direction_to(goal) * 2.5
				threat = true
	for dg in tree.get_nodes_in_group("delegate"):
		if not is_instance_valid(dg) or dg.kind != "trustin" or not dg.is_charging() or not _noticed(dg, t):
			continue
		if dg.time_to_fire() < 0.35:
			var rel3: Vector2 = pos - (dg.global_position as Vector2)
			var side3: float = rel3.dot(dg.aim().orthogonal())
			if absf(side3) < 45.0:
				dodge += dg.aim().orthogonal() * (1.0 if side3 >= 0.0 else -1.0) * 2.5
				threat = true
	for g in ["robo_sheep", "micro_sheep"]:
		for s in tree.get_nodes_in_group(g):
			if not is_instance_valid(s) or s.exploding or not _noticed(s, t):
				continue
			var rel: Vector2 = pos - (s.global_position as Vector2)
			var dd := rel.length()
			var r := 110.0 if g == "robo_sheep" else 75.0
			if dd < r and dd > 0.1:
				dodge += rel / dd * (r - dd) / r * 2.0
				threat = true
	# build 025: orbital rings, UFO tractor beams, drone blasts = circles
	for m in tree.get_nodes_in_group("orbital_strike"):
		if not is_instance_valid(m) or m.time_to_fire() <= 0.0 or not _noticed(m, t):
			continue
		var rel: Vector2 = pos - (m.global_position as Vector2)
		if rel.length() < m.radius + 24.0:
			dodge += (rel.normalized() if rel.length() > 1.0 else Vector2.RIGHT.rotated(rng.randf() * TAU)) * 2.5
			threat = true
	for u in tree.get_nodes_in_group("ufo"):
		if not is_instance_valid(u) or not u.is_beaming() or not _noticed(u, t):
			continue
		var rel: Vector2 = pos - (u._beam_at as Vector2)
		if rel.length() < u.beam_r + 26.0:
			dodge += (rel.normalized() if rel.length() > 1.0 else Vector2.LEFT) * 2.5
			threat = true
	for dr in tree.get_nodes_in_group("drone"):
		if not is_instance_valid(dr) or dr.state < 1 or dr.state > 2 or not _noticed(dr, t):
			continue
		var rel: Vector2 = pos - (dr.global_position as Vector2)
		if rel.length() < dr.blast_r + 24.0:
			dodge += (rel.normalized() if rel.length() > 1.0 else Vector2.RIGHT.rotated(rng.randf() * TAU)) * 2.5
			threat = true
	# satellite beam: it starts on you and sweeps one way - step the other way
	for sb in tree.get_nodes_in_group("sat_beam"):
		if not is_instance_valid(sb) or not _noticed(sb, t):
			continue
		var a: float = sb.current_angle()
		var dv := Vector2(cos(a), sin(a))
		var rel: Vector2 = pos - (sb.global_position as Vector2)
		var off: float = rel.cross(dv)
		if rel.dot(dv) > 0.0 and absf(off) < sb.width * 0.5 + 40.0:
			# sweep moves the beam toward sign(dir_sign); go to the side it left
			dodge += dv.orthogonal() * sb.dir_sign * 3.0   # orthogonal() = -d(dir)/da: away from the sweep
			threat = true
	if threat:
		want = (dodge.normalized() if dodge.length() > 0.01 else Vector2.ZERO) + want * 0.2
	var ar: Rect2 = tree.get_first_node_in_group("boss_level").arena_rect
	if not ar.grow(-40.0).has_point(pos):
		want += pos.direction_to(ar.get_center()) * 1.2
	return want.limit_length(1.0) if want.length() > 0.05 else Vector2.ZERO

func _gap_off(rg, pos: Vector2) -> float:
	var rel: Vector2 = pos - (rg.global_position as Vector2)
	var cur := atan2(rel.y / 0.75, rel.x)
	var bd := INF
	var out := 0.0
	for g in rg.gaps:
		var ad := angle_difference(float(g), cur)
		if absf(ad) < bd:
			bd = absf(ad)
			out = ad
	return out
