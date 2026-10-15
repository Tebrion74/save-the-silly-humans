class_name Summit
extends RefCounted
## Build 018: Shlaus Kwobb's summit toolkit (all drawn in code; the delegates
## reuse the Trustin Judeau / Huval Yarheyhey sheets as cyan holograms).
##   Summit.Delegate   a hologram DELEGATE that fades in (telegraph), acts once
##                     (Trustin: poutine; Huval: programmed sheep), then fades.
##                     Can't be hurt; the MSM Cam DISPELS it (msm_cam.gd).
##   Summit.Envelope   an INVITATION envelope (flat projectile, 1 heart)
##   Summit.ResetRing  THE GREAT RESET: an expanding ring with two gaps

const HOLO := Color(0.55, 1.0, 1.0, 0.72)


static func ring_pts(c: Vector2, r: Vector2, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


class Delegate extends Node2D:
	signal dispelled(d: Node)
	var kind := "trustin"
	var level: Node = null
	var shlaus: Node = null
	var tell := 0.8
	var phase := 1
	var poutine_mode := "single"
	var sheep_count := 1
	var spawn_points: Array = []
	var rng := RandomNumberGenerator.new()
	var _t := 0.0
	var _fired := false
	var _gone := false
	var _aim := Vector2.DOWN
	var _aim_locked := false
	var _volley_left := 0
	var _volley_t := 0.0
	var _spr: Sprite2D

	func _ready() -> void:
		add_to_group("delegate")
		rng.randomize()
		_spr = Sprite2D.new()
		_spr.texture = TrustinJudeau.SHEET if kind == "trustin" else HuvalYarheyhey.SHEET
		_spr.hframes = 10
		_spr.frame = 4
		_spr.position = Vector2(0, -48)
		_spr.modulate = Color(HOLO.r, HOLO.g, HOLO.b, 0.0)
		add_child(_spr)
		Sfx.play(self, "hologram", -9.0, 1.0 if kind == "trustin" else 1.15)

	func is_charging() -> bool:
		return not _fired and not _gone

	func time_to_fire() -> float:
		return maxf(tell - _t, 0.0)

	func aim() -> Vector2:
		return _aim

	func _player() -> Node2D:
		if not is_inside_tree():
			return null
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p == null or ("_dead" in p and p._dead):
			return null
		return p

	## MSM Cam: filming a delegate dispels it (a summon still fading in is cancelled).
	func cam_film(_delta: float) -> void:
		dispel(true)

	func dispel(by_player: bool = false) -> void:
		if _gone:
			return
		var was_charging := not _fired
		_gone = true
		_t = 0.0
		Sfx.play(self, "dispel", -8.0)
		if by_player and was_charging:
			dispelled.emit(self)
		if level != null and is_instance_valid(level) and level.has_method("spawn_score_popup") and by_player:
			level.spawn_score_popup("DISPELLED!", global_position + Vector2(0, -110), Color(0.6, 1.0, 1.0), 2)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _gone:
			_spr.modulate.a = maxf(0.0, HOLO.a * (1.0 - _t / 0.3))
			_spr.scale = Vector2(1.0 + _t * 2.0, maxf(1.0 - _t * 3.0, 0.05))
			if _t >= 0.3:
				queue_free()
			queue_redraw()
			return
		var p := _player()
		if not _fired:
			var k := clampf(_t / maxf(tell, 0.01), 0.0, 1.0)
			_spr.modulate.a = HOLO.a * k
			if p != null and not _aim_locked:
				_aim = (global_position + Vector2(0, -20)).direction_to(p.global_position)
				if _t >= tell - 0.2:
					_aim_locked = true
			if p != null:
				_spr.flip_h = p.global_position.x < global_position.x
			if _t >= tell:
				_fire(p)
		else:
			if _volley_left > 0:
				_volley_t -= delta
				if _volley_t <= 0.0 and p != null:
					_volley_left -= 1
					_volley_t = LevelConfig.POUTINE_VOLLEY_GAP
					_throw((global_position + Vector2(0, -20)).direction_to(p.global_position), LevelConfig.POUTINE_VOLLEY_SPEED)
				return
			if _t >= LevelConfig.BOSS4_DELEGATE_LINGER:
				_gone = true
				_t = 0.0
		queue_redraw()

	func _projectile_parent() -> Node:
		if level != null and is_instance_valid(level) and level.get_node_or_null("Entities") != null:
			return level.get_node("Entities")
		return get_parent()

	func _throw(dir: Vector2, speed: float) -> void:
		var pt := Poutine.new()
		pt.mode = "flat"
		pt.velocity = dir.normalized() * speed
		pt.level = level
		if level != null and "arena_rect" in level:
			pt.bounds = level.arena_rect.grow(40.0)
		_projectile_parent().add_child(pt)
		pt.global_position = global_position + dir.normalized() * 30.0
		Sfx.play(self, "throw", -12.0, rng.randf_range(0.9, 1.1))

	func _lob(target: Vector2) -> void:
		var pt := Poutine.new()
		pt.mode = "lob"
		pt.start = global_position + Vector2(0, -4)
		pt.target = target
		pt.level = level
		_projectile_parent().add_child(pt)
		Sfx.play(self, "throw", -12.0, 0.8)

	func _fire(p: Node2D) -> void:
		_fired = true
		_t = 0.0
		_spr.frame = 5
		if kind == "trustin":
			match poutine_mode:
				"single":
					_throw(_aim, LevelConfig.POUTINE_SPEED)
				"spread3":
					for k in [-1, 0, 1]:
						_throw(_aim.rotated(deg_to_rad(LevelConfig.POUTINE_SPREAD_DEG * k)), LevelConfig.POUTINE_SPREAD_SPEED)
				"spread5":
					for k in [-2, -1, 0, 1, 2]:
						_throw(_aim.rotated(deg_to_rad(LevelConfig.POUTINE_SPREAD5_DEG * k)), LevelConfig.POUTINE_SPREAD_SPEED)
				"lob2":
					if p != null:
						_lob(p.global_position)
						var pv: Vector2 = p.velocity if "velocity" in p else Vector2.ZERO
						var lead := p.global_position + pv * LevelConfig.POUTINE_LOB_LEAD
						if lead.distance_to(p.global_position) < LevelConfig.POUTINE_LOB_PAIR_MIN:
							lead = p.global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * LevelConfig.POUTINE_LOB_PAIR_MIN
						_lob(lead)
				"volley":
					_throw(_aim, LevelConfig.POUTINE_VOLLEY_SPEED)
					_volley_left = LevelConfig.BOSS4_VOLLEY_COUNT - 1
					_volley_t = LevelConfig.POUTINE_VOLLEY_GAP
		else:
			Sfx.play(self, "clicker", -6.0)
			for sp in spawn_points:
				if shlaus != null and is_instance_valid(shlaus) and shlaus.has_method("spawn_robo"):
					shlaus.spawn_robo(sp)
			spawn_points.clear()

	func _draw() -> void:
		# hologram base pad + scanlines
		var a := _spr.modulate.a
		Summit._ellipse(self, Vector2(0, 2), Vector2(30, 10), Color(0.3, 1.0, 1.0, 0.25 * a / HOLO.a if HOLO.a > 0.0 else 0.0))
		for i in 6:
			var y := -96.0 + i * 16.0 + fmod(_t * 40.0, 16.0)
			draw_line(Vector2(-26, y), Vector2(26, y), Color(0.6, 1.0, 1.0, 0.18 * a), 2.0)
		if _fired or _gone:
			return
		var k := clampf(_t / maxf(tell, 0.01), 0.0, 1.0)
		if kind == "trustin":
			var o := Vector2(0, -20)
			var col := Color(1.0, 0.55, 0.15, 0.3 + 0.55 * k)
			var dirs: Array = [_aim]
			if poutine_mode == "spread3":
				dirs = [_aim.rotated(-deg_to_rad(LevelConfig.POUTINE_SPREAD_DEG)), _aim, _aim.rotated(deg_to_rad(LevelConfig.POUTINE_SPREAD_DEG))]
			elif poutine_mode == "spread5":
				dirs = []
				for kk in [-2, -1, 0, 1, 2]:
					dirs.append(_aim.rotated(deg_to_rad(LevelConfig.POUTINE_SPREAD5_DEG * kk)))
			if poutine_mode != "lob2":
				for d in dirs:
					_dash_line(o, o + (d as Vector2) * (160.0 + 160.0 * k), col, 3.0 if not _aim_locked else 4.0)
			else:
				var p := _player()
				if p != null:
					var c := to_local(p.global_position)
					draw_arc(c, LevelConfig.POUTINE_LOB_RADIUS * (1.4 - 0.4 * k), 0, TAU, 24, col, 3.0)
		else:
			for sp in spawn_points:
				var c := to_local(sp)
				var r := 30.0 - 8.0 * k
				Summit._ring(self, c, Vector2(r, r * 0.55), Color(0.35, 1.0, 1.0, 0.4 + 0.5 * k), 3.0)
				Summit._ring(self, c, Vector2(r * 0.6, r * 0.33), Color(1, 1, 1, 0.3 + 0.5 * k), 2.0)
		# "!" over the hologram
		var bang := Vector2(0, -126 - 3.0 * sin(_t * 20.0))
		draw_rect(Rect2(bang + Vector2(-5, -18), Vector2(10, 26)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(bang + Vector2(-3, -16), Vector2(6, 14)), Color(0.5, 1.0, 1.0))
		draw_rect(Rect2(bang + Vector2(-3, 1), Vector2(6, 5)), Color(0.5, 1.0, 1.0))

	func _dash_line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		var d := b - a
		var n := int(d.length() / 14.0)
		for i in n:
			if i % 2 == 0:
				draw_line(a + d * (float(i) / n), a + d * (float(i + 1) / n), col, w)


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := float(i) / 20.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


static func _ring(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, w: float) -> void:
	ci.draw_polyline(ring_pts(c, r, 0.0, TAU, 32), col, w)


## INVITATION envelope: flies straight, 1 heart on the rancher (shared mercy window).
class Envelope extends Node2D:
	## Build 020: "" envelope, "floppy" (Gill Bates), "icecream" (Nancy Pelotto)
	var skin := ""
	var velocity := Vector2.ZERO
	var level: Node = null
	var bounds := Rect2(-100000, -100000, 200000, 200000)
	var travelled := 0.0
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		add_to_group("envelope")
		add_to_group("poutine")    # boss_level.gd splats every "poutine" at the win

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_t += delta
		var step := velocity * delta
		global_position += step
		travelled += step.length()
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null and global_position.distance_to(p.global_position) <= LevelConfig.BOSS4_ENVELOPE_HIT_RADIUS:
			if level != null and is_instance_valid(level) and level.has_method("envelope_hit_player"):
				level.envelope_hit_player(global_position)
			splat()
			return
		if travelled >= 1000.0 or not bounds.has_point(global_position):
			splat()
			return
		queue_redraw()

	func splat(_size: float = 1.0) -> void:
		if _done:
			return
		_done = true
		queue_free()

	func _draw() -> void:
		Summit._ellipse(self, Vector2(0, 2), Vector2(11, 4), Color(0, 0, 0, 0.3))
		var wob := sin(_t * 16.0) * 0.3
		draw_set_transform(Vector2(0, -24), wob, Vector2.ONE)
		if skin == "floppy":
			draw_rect(Rect2(-12, -12, 24, 24), Color(0.06, 0.03, 0.08))
			draw_rect(Rect2(-10, -10, 20, 20), Color(0.16, 0.18, 0.3))
			draw_rect(Rect2(-6, -10, 12, 7), Color(0.75, 0.78, 0.82))
			draw_rect(Rect2(2, -9, 3, 5), Color(0.16, 0.18, 0.3))
			draw_rect(Rect2(-7, 1, 14, 9), Color(0.96, 0.96, 0.92))
			draw_line(Vector2(-5, 4), Vector2(5, 4), Color(0.3, 0.5, 0.9), 1.0)
			draw_line(Vector2(-5, 7), Vector2(3, 7), Color(0.3, 0.5, 0.9), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		if skin == "jellybean":   # build 025 Reanald Rogan
			var cols := [Color(0.9, 0.2, 0.25), Color(0.3, 0.8, 0.3), Color(0.95, 0.8, 0.2), Color(0.6, 0.3, 0.9)]
			var bc: Color = cols[int(abs(get_instance_id())) % 4]
			draw_set_transform(Vector2(0, -24), wob + 0.6, Vector2.ONE)
			Summit._ellipse(self, Vector2.ZERO, Vector2(11, 7), Color(0.06, 0.03, 0.08))
			Summit._ellipse(self, Vector2.ZERO, Vector2(9, 5.5), bc)
			Summit._ellipse(self, Vector2(-3, -2), Vector2(3, 1.5), Color(1, 1, 1, 0.6))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		if skin == "seed":   # build 025 Zelodymer Violentsky: a sunflower seed
			draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(8, 0), Vector2(0, 12), Vector2(-8, 0)]), Color(0.06, 0.03, 0.08))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -10), Vector2(6, 0), Vector2(0, 10), Vector2(-6, 0)]), Color(0.22, 0.2, 0.18))
			draw_line(Vector2(-2, -7), Vector2(-2, 7), Color(0.92, 0.9, 0.82), 1.5)
			draw_line(Vector2(2, -7), Vector2(2, 7), Color(0.92, 0.9, 0.82), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		if skin == "icecream":
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -2), Vector2(9, -2), Vector2(0, 16)]), Color(0.06, 0.03, 0.08))
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -1), Vector2(7, -1), Vector2(0, 13)]), Color(0.85, 0.6, 0.3))
			draw_line(Vector2(-4, 2), Vector2(2, 10), Color(0.65, 0.42, 0.18), 1.0)
			draw_line(Vector2(4, 2), Vector2(-2, 10), Color(0.65, 0.42, 0.18), 1.0)
			draw_circle(Vector2(0, -5), 9.0, Color(0.06, 0.03, 0.08))
			draw_circle(Vector2(0, -5), 7.5, Color(1.0, 0.78, 0.82))
			draw_circle(Vector2(-2, -8), 2.5, Color(1, 1, 1, 0.8))
			draw_circle(Vector2(1, -12), 2.0, Color(0.85, 0.1, 0.15))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		draw_rect(Rect2(-13, -9, 26, 18), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(-11, -7, 22, 14), Color(0.98, 0.96, 0.88))
		draw_line(Vector2(-11, -7), Vector2(0, 1), Color(0.6, 0.55, 0.45), 2.0)
		draw_line(Vector2(11, -7), Vector2(0, 1), Color(0.6, 0.55, 0.45), 2.0)
		draw_circle(Vector2(0, 1), 3.0, Color(0.8, 0.12, 0.15))   # wax seal
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## THE GREAT RESET: rings show (with their gaps) for `tell`, then one ring
## expands at BOSS4_RESET_SPEED. The rancher is hit when the ring's edge
## passes them outside a gap.
class ResetRing extends Node2D:
	## Build 020: "" GREAT RESET (red), "bluescreen" (Gill), "gavel" (Nancy)
	var skin := ""
	var speed: float = LevelConfig.BOSS4_RESET_SPEED
	var level: Node = null
	var tell := 0.9
	var gaps: Array = []        ## gap centre angles (radians); each BOSS4_RESET_GAP_DEG wide
	var radius := 40.0
	var _prev := 40.0
	var _t := 0.0
	var _hit_done := false

	func _ready() -> void:
		add_to_group("reset_ring")
		z_index = 1
		Sfx.play(self, "reset_tell", -8.0)

	func is_expanding() -> bool:
		return _t >= tell

	func time_to_fire() -> float:
		return maxf(tell - _t, 0.0)

	func in_gap(pos: Vector2) -> bool:
		var rel := pos - global_position
		var a := atan2(rel.y / 0.75, rel.x)
		for g in gaps:
			if absf(angle_difference(a, float(g))) <= deg_to_rad(LevelConfig.BOSS4_RESET_GAP_DEG) * 0.5:
				return true
		return false

	## Elliptical distance used for the ring (y squashed like the floor).
	func ring_dist(pos: Vector2) -> float:
		var rel := pos - global_position
		return Vector2(rel.x, rel.y / 0.75).length()

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t < tell:
			queue_redraw()
			return
		if _prev == radius and _t - delta < tell:
			Sfx.play(self, "reset", -6.0)
		_prev = radius
		radius += speed * delta
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null and not _hit_done:
			var d := ring_dist(p.global_position)
			var th := LevelConfig.BOSS4_RESET_THICK
			if d >= _prev - th and d <= radius + th and not in_gap(p.global_position):
				if level != null and is_instance_valid(level) and level.has_method("reset_hit_player"):
					if level.reset_hit_player(global_position):
						_hit_done = true
		if radius >= LevelConfig.BOSS4_RESET_MAX_RADIUS:
			queue_free()
			return
		queue_redraw()

	func _main() -> Color:
		match skin:
			"bluescreen":
				return Color(0.25, 0.5, 1.0)
			"gavel":
				return Color(1.0, 0.3, 0.75)
			"applause":   # build 025 Violentsky: a gold standing-ovation ring
				return Color(1.0, 0.82, 0.2)
		return Color(1.0, 0.25, 0.3)

	func _arcs(r: float, col: Color, w: float) -> void:
		var half := deg_to_rad(LevelConfig.BOSS4_RESET_GAP_DEG) * 0.5
		var sorted: Array = gaps.duplicate()
		sorted.sort()
		for i in sorted.size():
			var a0: float = float(sorted[i]) + half
			var a1: float = float(sorted[(i + 1) % sorted.size()]) - half
			if a1 <= a0:
				a1 += TAU
			draw_polyline(Summit.ring_pts(Vector2.ZERO, Vector2(r, r * 0.75), a0, a1, 40), col, w)

	func _draw() -> void:
		if _t < tell:
			var k := _t / maxf(tell, 0.01)
			var pulse := 0.5 + 0.5 * sin(_t * 22.0)
			for rr in [120.0, 240.0, 380.0]:
				_arcs(rr, Color(0.06, 0.03, 0.08, 0.5 * k), 6.0)
				_arcs(rr, Color(_main().r, _main().g, _main().b, 0.35 + 0.45 * k * pulse), 3.0)
			# gap lanes: green safe wedges
			var half := deg_to_rad(LevelConfig.BOSS4_RESET_GAP_DEG) * 0.5
			for g in gaps:
				var pts := PackedVector2Array([Vector2.ZERO])
				for i in 9:
					var a := float(g) - half + 2.0 * half * i / 8.0
					pts.append(Vector2(cos(a) * 420.0, sin(a) * 315.0))
				draw_colored_polygon(pts, Color(0.3, 1.0, 0.5, 0.16 + 0.16 * k))
			return
		var fade := clampf(1.0 - radius / LevelConfig.BOSS4_RESET_MAX_RADIUS, 0.2, 1.0)
		var th := LevelConfig.BOSS4_RESET_THICK
		_arcs(radius, Color(0.06, 0.03, 0.08, 0.7 * fade), th * 2.0 + 4.0)
		_arcs(radius, Color(_main().r, _main().g, _main().b, 0.85 * fade), th * 1.6)
		_arcs(radius, Color(1.0, 0.9, 0.9, fade), th * 0.5)
