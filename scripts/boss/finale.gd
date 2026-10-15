class_name Finale
extends RefCounted
## Build 027: the final two bosses' hazards (drawn in code, toy-like).
##   Finale.TankLane     Vladimir Puddin: a striped lane telegraphs (one through
##                       you), then a toy tank rolls through it. Step out of the lane.
##   Finale.JudoGrab     Puddin: a grab ring tracks you, locks, then he pounces.
##                       Caught = tossed across the arena + 1 heart.
##   Finale.Quake        Puddin: ARENA SHAKE - a clear 1 s warning, then your
##                       controls are inverted for BOSS9_INVERT_TIME s (+ icicles).
##   Finale.MarkedStrike icicles (Puddin) / golf balls (Rump): a mark, then impact.
##   Finale.WallDrop     Donald Rump: a shadow, then a gold wall slams down and
##                       blocks (you, him, his shots) for BOSS10_WALL_LIFE s.
##   Finale.RallyFan     Rump's red-hat crowd: plain red caps that jog after you.
##                       Touch = 1 heart; one whip sends a fan home (points).
## Every hazard hurts through level.tech_hit_player(kind, pos) (shared mercy
## window, god mode, armour, star). Each one answers threat(pos) -> seconds
## until it can hurt `pos` (-1 = safe there) so bots and tests can read it.


static func _hit(level: Node, kind: String, pos: Vector2) -> bool:
	if level != null and is_instance_valid(level) and level.has_method("tech_hit_player"):
		return bool(level.tech_hit_player(kind, pos))
	return false


static func _player(n: Node) -> Node2D:
	return n.get_tree().get_first_node_in_group("player") as Node2D


static func _in_ellipse(d: Vector2, r: float) -> bool:
	return Vector2(d.x, d.y / 0.75).length() <= r


# ------------------------------------------------------------------ TANK CHARGE
class TankLane extends Node2D:
	var level: Node = null
	var from := Vector2.ZERO          ## global start (outside the arena edge)
	var to := Vector2.ZERO            ## global end
	var width: float = LevelConfig.BOSS9_TANK_WIDTH
	var speed: float = LevelConfig.BOSS9_TANK_SPEED
	var tell := 1.0
	var _t := 0.0
	var _pos := Vector2.ZERO          ## tank position (global)
	var _rolling := false
	var _hit_done := false

	func _ready() -> void:
		add_to_group("tank_lane")
		add_to_group("hazard027")
		add_to_group("poutine")
		z_index = 1
		global_position = Vector2.ZERO
		_pos = from

	func splat(_s: float = 1.0) -> void:
		queue_free()

	func dir() -> Vector2:
		return from.direction_to(to)

	## Distance of `pos` from the lane's centre line.
	func lane_dist(pos: Vector2) -> float:
		var d := dir()
		var rel := pos - from
		return absf(rel.dot(d.orthogonal()))

	func threat(pos: Vector2) -> float:
		if lane_dist(pos) > width * 0.5 + 18.0:
			return -1.0
		if not _rolling:
			return maxf(tell - _t, 0.0)
		# already rolled past this point?
		if (pos - _pos).dot(dir()) < -40.0:
			return -1.0
		return 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _rolling and _t >= tell:
			_rolling = true
			Sfx.play(self, "tank", -6.0, randf_range(0.9, 1.1))
		if _rolling:
			_pos += dir() * speed * delta
			var p := Finale._player(self)
			if p != null and not _hit_done:
				var rel := p.global_position - _pos
				if absf(rel.dot(dir())) <= 34.0 and absf(rel.dot(dir().orthogonal())) <= width * 0.5 + 4.0:
					_hit_done = true
					Finale._hit(level, "tank", _pos)
			if (_pos - from).length() >= (to - from).length():
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var d := dir()
		var n := d.orthogonal()
		var hw := width * 0.5
		var a0 := from + n * hw
		var a1 := to + n * hw
		var b0 := from - n * hw
		var b1 := to - n * hw
		var k := clampf(_t / maxf(tell, 0.01), 0.0, 1.0)
		var a := (0.12 + 0.2 * k) if not _rolling else 0.12
		draw_colored_polygon(PackedVector2Array([a0, a1, b1, b0]), Color(1.0, 0.3, 0.2, a))
		var blink := 0.5 + 0.5 * sin(_t * (10.0 + 18.0 * k))
		draw_line(a0, a1, Color(1.0, 0.45, 0.3, 0.55 + 0.4 * blink), 3.0)
		draw_line(b0, b1, Color(1.0, 0.45, 0.3, 0.55 + 0.4 * blink), 3.0)
		# chevrons pointing the way it will roll
		var L := (to - from).length()
		var s := 30.0 + fmod(_t * 160.0, 60.0)
		while s < L:
			var c := from + d * s
			draw_line(c - d * 10.0 + n * 12.0, c, Color(1, 0.9, 0.8, 0.45), 3.0)
			draw_line(c - d * 10.0 - n * 12.0, c, Color(1, 0.9, 0.8, 0.45), 3.0)
			s += 60.0
		var tp := _pos if _rolling else from + d * 20.0
		_draw_tank(tp, d)

	func _draw_tank(c: Vector2, d: Vector2) -> void:
		draw_set_transform(c, 0.0, Vector2.ONE)
		Summit._ellipse(self, Vector2(0, 6), Vector2(36, 12), Color(0, 0, 0, 0.3))
		var flip := -1.0 if d.x < -0.3 else 1.0
		var side := absf(d.x) >= absf(d.y)
		# treads
		draw_rect(Rect2(-34, -10, 68, 18), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(-32, -8, 64, 14), Color(0.25, 0.27, 0.24))
		for i in 7:
			var x := -28.0 + i * 9.5 + fmod(_t * 60.0 * flip, 9.5)
			draw_circle(Vector2(x, -1), 3.5, Color(0.42, 0.44, 0.4))
		# hull + turret (toy olive-grey, plain - no insignia)
		draw_rect(Rect2(-30, -24, 60, 16), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(-28, -22, 56, 12), Color(0.46, 0.52, 0.38))
		draw_rect(Rect2(-28, -22, 56, 4), Color(0.6, 0.66, 0.5))
		draw_rect(Rect2(-14, -36, 28, 14), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(-12, -34, 24, 11), Color(0.5, 0.56, 0.42))
		var bx := 12.0 * flip if side else 0.0
		var by := -29.0 if side else (-29.0 + 10.0 * signf(d.y))
		draw_line(Vector2(bx, by), Vector2(bx + 26.0 * flip if side else bx, by if side else by + 14.0 * signf(d.y)), Color(0.06, 0.03, 0.08), 6.0)
		draw_line(Vector2(bx, by), Vector2(bx + 26.0 * flip if side else bx, by if side else by + 14.0 * signf(d.y)), Color(0.4, 0.45, 0.34), 3.0)
		# snow on top
		draw_rect(Rect2(-10, -36, 20, 3), Color(0.95, 0.97, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ JUDO THROW
class JudoGrab extends Node2D:
	var level: Node = null
	var boss: Node2D = null
	var track := 0.5
	var lock := 0.5
	var radius: float = LevelConfig.BOSS9_JUDO_RADIUS
	var arena := Rect2()
	var _t := 0.0
	var _fired := false
	var _from := Vector2.ZERO

	func _ready() -> void:
		add_to_group("judo_grab")
		add_to_group("hazard027")
		add_to_group("poutine")
		z_index = 2
		Sfx.play(self, "warn", -10.0, 0.8)

	func splat(_s: float = 1.0) -> void:
		queue_free()

	func is_locked() -> bool:
		return _t >= track

	func threat(pos: Vector2) -> float:
		if _fired:
			return -1.0
		if not Finale._in_ellipse(pos - global_position, radius + 14.0):
			return -1.0
		return maxf(track + lock - _t, 0.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		var p := Finale._player(self)
		if _t < track and p != null:
			global_position = global_position.lerp(p.global_position, minf(delta * 12.0, 1.0))
		if not _fired and _t >= track + lock:
			_fired = true
			_from = boss.global_position if boss != null and is_instance_valid(boss) else global_position
			if boss != null and is_instance_valid(boss) and boss.has_method("judo_pounce"):
				boss.judo_pounce(global_position)
			Sfx.play(self, "grab", -6.0, 0.8)
			if p != null and Finale._in_ellipse(p.global_position - global_position, radius + 4.0):
				var away := (p.global_position - _from)
				if away.length() < 1.0:
					away = Vector2.RIGHT
				var dir := away.normalized()
				# toss towards the roomier side of the arena
				var land := p.global_position + dir * LevelConfig.BOSS9_JUDO_TOSS
				if arena.size != Vector2.ZERO and not arena.grow(-30.0).has_point(land):
					dir = (arena.get_center() - p.global_position).normalized()
				var hurt := Finale._hit(level, "judo", global_position)
				if hurt or ("absorbed_frame" in p and int(p.absorbed_frame) == Engine.get_physics_frames()):
					if "knockback_velocity" in p:
						p.knockback_velocity = dir * LevelConfig.BOSS9_JUDO_TOSS * 4.2
					if level != null and level.has_method("spawn_score_popup"):
						level.spawn_score_popup("JUDO FLIP!", p.global_position + Vector2(0, -50), Color(1.0, 0.85, 0.4), 2)
		if _t > track + lock + 0.35:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var ry := radius * 0.75
		if _fired:
			var f := clampf(1.0 - (_t - track - lock) / 0.35, 0.0, 1.0)
			Summit._ellipse(self, Vector2.ZERO, Vector2(radius * 1.3, ry * 1.3), Color(1, 1, 1, 0.4 * f))
			draw_string(ThemeDB.fallback_font, Vector2(-26, -ry - 10), "HAJIME!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.5, f))
			return
		var locked := _t >= track
		var k := clampf((_t - track) / maxf(lock, 0.01), 0.0, 1.0) if locked else 0.0
		var col := Color(1.0, 0.85, 0.2) if not locked else Color(1.0, 0.3, 0.2)
		Summit._ellipse(self, Vector2.ZERO, Vector2(radius, ry), Color(col.r, col.g, col.b, 0.12 + 0.2 * k))
		draw_polyline(Summit.ring_pts(Vector2.ZERO, Vector2(radius, ry), 0.0, TAU, 32), Color(col.r, col.g, col.b, 0.85), 3.0)
		var r2 := lerpf(radius * 1.7, radius * 0.25, k)
		if locked:
			draw_polyline(Summit.ring_pts(Vector2.ZERO, Vector2(r2, r2 * 0.75), 0.0, TAU, 28), Color(1, 0.95, 0.9, 0.8), 2.0)
		# a judo-belt knot icon
		draw_rect(Rect2(-12, -ry - 22, 24, 6), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(-11, -ry - 21, 22, 4), Color(0.12, 0.1, 0.12))
		draw_line(Vector2(-3, -ry - 16), Vector2(-7, -ry - 6), Color(0.12, 0.1, 0.12), 3.0)
		draw_line(Vector2(3, -ry - 16), Vector2(7, -ry - 6), Color(0.12, 0.1, 0.12), 3.0)


# ------------------------------------------------------------------ ARENA SHAKE
class Quake extends Node2D:
	var level: Node = null
	var tell: float = LevelConfig.BOSS9_QUAKE_TELL
	var invert: float = LevelConfig.BOSS9_INVERT_TIME
	var icicles := 0
	var arena := Rect2()
	var _t := 0.0
	var _fired := false
	var rng := RandomNumberGenerator.new()

	func _ready() -> void:
		add_to_group("quake")
		add_to_group("poutine")
		rng.randomize()
		Sfx.play(self, "warn", -6.0, 0.6)
		var hud: Node = level.get("hud") if level != null and is_instance_valid(level) and "hud" in level else null
		if hud != null and hud.has_method("show_callout"):
			hud.show_callout("ARENA SHAKE!", "CONTROLS FLIP FOR %d SECONDS" % int(round(invert)), Color(0.6, 0.85, 1.0), tell + 0.2)

	func splat(_s: float = 1.0) -> void:
		queue_free()

	func time_to_invert() -> float:
		return maxf(tell - _t, 0.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _fired and _t >= tell:
			_fired = true
			Sfx.play(self, "quake", -4.0)
			var p := Finale._player(self)
			if p != null and p.has_method("invert_controls"):
				var bt := get_node_or_null("/root/BetaTools")
				if not (bt != null and "god" in bt and bt.god):
					p.invert_controls(invert)
			if level != null and level.has_method("shake_camera"):
				level.shake_camera(0.7, 9.0)
			if p != null:
				var inner := arena.grow(-36.0)
				for k in icicles:
					var a := rng.randf() * TAU
					var d := 0.0 if k == 0 else rng.randf_range(80.0, 170.0)
					var c := p.global_position + Vector2(cos(a) * d, sin(a) * d * 0.75)
					if inner.size != Vector2.ZERO:
						c = c.clamp(inner.position, inner.end)
					var s := Finale.MarkedStrike.new()
					s.level = level
					s.kind = "icicle"
					s.tell = LevelConfig.BOSS9_ICICLE_TELL + 0.12 * k
					s.radius = LevelConfig.BOSS9_ICICLE_RADIUS
					get_parent().add_child(s)
					s.global_position = c
		if _t > tell + 0.2:
			queue_free()
			return
		queue_redraw()


# ------------------------------------------------------------------ ICICLES / GOLF BALLS
class MarkedStrike extends Node2D:
	var level: Node = null
	var kind := "icicle"            ## "icicle" | "golf"
	var tell := 1.0
	var radius := 34.0
	var origin := Vector2.ZERO      ## golf: where the drive started (global)
	var _t := 0.0
	var _fired := false

	func _ready() -> void:
		add_to_group("marked_strike")
		add_to_group("hazard027")
		add_to_group("poutine")
		z_index = 2

	func splat(_s: float = 1.0) -> void:
		queue_free()

	func threat(pos: Vector2) -> float:
		if _fired or not Finale._in_ellipse(pos - global_position, radius + 14.0):
			return -1.0
		return maxf(tell - _t, 0.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _fired and _t >= tell:
			_fired = true
			Sfx.play(self, "bomb" if kind == "golf" else "splat", -12.0, 1.5 if kind == "golf" else 1.2)
			var p := Finale._player(self)
			if p != null and Finale._in_ellipse(p.global_position - global_position, radius + 5.0):
				Finale._hit(level, kind, global_position)
		if _t > tell + 0.45:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var ry := radius * 0.75
		if _fired:
			var f := clampf(1.0 - (_t - tell) / 0.45, 0.0, 1.0)
			if kind == "golf":
				Summit._ellipse(self, Vector2.ZERO, Vector2(radius * (1.0 + 0.4 * (1.0 - f)), ry * (1.0 + 0.4 * (1.0 - f))), Color(0.55, 0.4, 0.2, 0.45 * f))
				draw_circle(Vector2(0, -6), 7.0, Color(0.06, 0.03, 0.08, f))
				draw_circle(Vector2(0, -6), 5.5, Color(1, 1, 1, f))
			else:
				for i in 8:
					var a := TAU * i / 8.0
					draw_line(Vector2.ZERO, Vector2(cos(a), sin(a) * 0.75) * radius * (1.2 - 0.4 * f), Color(0.85, 0.95, 1.0, f), 3.0)
				Summit._ellipse(self, Vector2.ZERO, Vector2(radius * 0.7, ry * 0.7), Color(0.9, 0.97, 1.0, 0.7 * f))
			return
		var k := clampf(_t / maxf(tell, 0.01), 0.0, 1.0)
		var col := Color(0.55, 0.85, 1.0) if kind == "icicle" else Color(1.0, 0.85, 0.25)
		var blink := 0.5 + 0.5 * sin(_t * (10.0 + 20.0 * k))
		Summit._ellipse(self, Vector2.ZERO, Vector2(radius, ry), Color(col.r, col.g, col.b, 0.12 + 0.2 * k))
		draw_polyline(Summit.ring_pts(Vector2.ZERO, Vector2(radius, ry), 0.0, TAU, 30), Color(col.r, col.g, col.b, 0.55 + 0.45 * blink), 3.0)
		Summit._ellipse(self, Vector2.ZERO, Vector2(radius * k * 0.6, ry * k * 0.6), Color(0, 0, 0, 0.25))
		if kind == "icicle":
			var y := -260.0 * (1.0 - k)
			draw_colored_polygon(PackedVector2Array([Vector2(-8, y - 34), Vector2(8, y - 34), Vector2(0, y)]), Color(0.06, 0.03, 0.08))
			draw_colored_polygon(PackedVector2Array([Vector2(-6, y - 32), Vector2(6, y - 32), Vector2(0, y - 4)]), Color(0.8, 0.93, 1.0))
			draw_line(Vector2(-2, y - 30), Vector2(0, y - 10), Color(1, 1, 1, 0.9), 1.5)
		else:
			draw_string(ThemeDB.fallback_font, Vector2(-22, -ry - 8), "FORE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.8, 0.6 + 0.4 * blink))
			# the ball in flight: an arc from the tee to the mark
			var o := to_local(origin)
			var bp := o.lerp(Vector2.ZERO, k)
			bp.y -= sin(k * PI) * 180.0
			draw_circle(bp, 6.0, Color(0.06, 0.03, 0.08))
			draw_circle(bp, 4.5, Color(1, 1, 1))


# ------------------------------------------------------------------ WALL DROP
class WallDrop extends Node2D:
	var level: Node = null
	var size := Vector2(220, 26)     ## footprint (w, h) centred on the node
	var tell := 0.9
	var life: float = LevelConfig.BOSS10_WALL_LIFE
	var _t := 0.0
	var _slammed := false
	var _body: StaticBody2D = null

	func _ready() -> void:
		add_to_group("wall_drop")
		add_to_group("hazard027")
		add_to_group("poutine")
		z_index = 1

	func splat(_s: float = 1.0) -> void:
		queue_free()

	func rect() -> Rect2:
		return Rect2(global_position - size * 0.5, size)

	func is_solid() -> bool:
		return _slammed

	func threat(pos: Vector2) -> float:
		if _slammed or not rect().grow(16.0).has_point(pos):
			return -1.0
		return maxf(tell - _t, 0.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _slammed and _t >= tell:
			_slammed = true
			Sfx.play(self, "wall", -4.0)
			if level != null and level.has_method("shake_camera"):
				level.shake_camera(0.25, 5.0)
			var p := Finale._player(self)
			if p != null and rect().grow(6.0).has_point(p.global_position):
				Finale._hit(level, "wall", global_position)
				# shove the rancher out of the footprint (shortest way)
				var r := rect().grow(14.0)
				var lp := p.global_position
				var outs: Array[Vector2] = [Vector2(r.position.x, lp.y), Vector2(r.end.x, lp.y), Vector2(lp.x, r.position.y), Vector2(lp.x, r.end.y)]
				var best: Vector2 = outs[0]
				for o in outs:
					if o.distance_to(lp) < best.distance_to(lp):
						best = o
				p.global_position = best
			_body = StaticBody2D.new()
			_body.collision_layer = 1
			_body.collision_mask = 0
			var cs := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = size
			cs.shape = rs
			_body.add_child(cs)
			add_child(_body)
		if _t >= tell + life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-size * 0.5, size)
		if not _slammed:
			var k := clampf(_t / maxf(tell, 0.01), 0.0, 1.0)
			var blink := 0.5 + 0.5 * sin(_t * (10.0 + 20.0 * k))
			draw_rect(r, Color(0, 0, 0, 0.18 + 0.3 * k))
			draw_rect(r, Color(1.0, 0.82, 0.25, 0.5 + 0.5 * blink), false, 3.0)
			# the wall falling in from above
			var y := -300.0 * (1.0 - k) * (1.0 - k)
			_wall(Rect2(r.position + Vector2(0, y), r.size), 0.5 + 0.5 * k)
			return
		var left := tell + life - _t
		var a := 1.0 if left > 1.0 else clampf(left, 0.0, 1.0)
		_wall(r, a)

	func _wall(r: Rect2, a: float) -> void:
		var h := 44.0
		var top := Rect2(Vector2(r.position.x, r.position.y - h), r.size)
		Summit._ellipse(self, r.get_center() + Vector2(0, r.size.y * 0.5), Vector2(r.size.x * 0.55, 8), Color(0, 0, 0, 0.25 * a))
		draw_rect(Rect2(top.position, Vector2(top.size.x, r.size.y + h)).grow(2.0), Color(0.06, 0.03, 0.08, a))
		draw_rect(Rect2(top.position, Vector2(top.size.x, r.size.y + h)), Color(0.86, 0.66, 0.18, a))
		draw_rect(Rect2(top.position, Vector2(top.size.x, 6)), Color(1.0, 0.9, 0.5, a))
		var x := r.position.x + 18.0
		while x < r.end.x - 4.0:
			draw_line(Vector2(x, top.position.y + 8), Vector2(x, r.end.y - 4), Color(0.7, 0.5, 0.1, 0.8 * a), 2.0)
			x += 36.0
		if r.size.x > 0.0:
			draw_rect(Rect2(Vector2(r.position.x, r.end.y - 6), Vector2(r.size.x, 6)), Color(0.6, 0.42, 0.08, a))


# ------------------------------------------------------------------ RED-HAT CROWD
class RallyFan extends Node2D:
	signal popped(f: Node)
	var level: Node = null
	var speed := 100.0
	var life: float = LevelConfig.BOSS10_CROWD_LIFE
	var arena := Rect2()
	var shirt := Color(0.3, 0.45, 0.8)
	var _t := 0.0
	var _done := false
	var _bob := 0.0
	var _hit_cool := 0.0

	func _ready() -> void:
		add_to_group("crowd")
		add_to_group("hazard027")
		add_to_group("whippable")
		add_to_group("poutine")
		z_index = 3
		_bob = randf() * 3.0
		var shirts := [Color(0.3, 0.45, 0.8), Color(0.9, 0.9, 0.85), Color(0.25, 0.5, 0.3), Color(0.55, 0.4, 0.3), Color(0.4, 0.4, 0.45)]
		shirt = shirts[randi() % shirts.size()]

	func splat(_s: float = 1.0) -> void:
		_done = true
		queue_free()

	func threat(pos: Vector2) -> float:
		var d := pos.distance_to(global_position)
		if d > 80.0:
			return -1.0
		return maxf((d - 22.0) / maxf(speed, 1.0), 0.0)

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_t += delta
		_hit_cool = maxf(_hit_cool - delta, 0.0)
		var p := Finale._player(self)
		if _t >= life:
			# rally's over: wander off and fade
			modulate.a = maxf(1.0 - (_t - life) / 0.6, 0.0)
			global_position += Vector2(0, -60) * delta
			if _t >= life + 0.6:
				queue_free()
			queue_redraw()
			return
		if p != null:
			var to := p.global_position - global_position
			var v := to.normalized() * speed if to.length() > 1.0 else Vector2.ZERO
			# keep a little space from the other fans
			for o in get_tree().get_nodes_in_group("crowd"):
				if o != self and is_instance_valid(o):
					var away := global_position - (o as Node2D).global_position
					if away.length() < 26.0 and away.length() > 0.01:
						v += away.normalized() * 60.0
			global_position += v * delta
			if arena.size != Vector2.ZERO:
				global_position = global_position.clamp(arena.position, arena.end)
			if to.length() <= 22.0 and _hit_cool <= 0.0:
				_hit_cool = 0.8
				if Finale._hit(level, "crowd", global_position):
					# a big hug, then off home
					_go_home(false)
					return
		queue_redraw()

	func receive_whip(_from: Vector2, _f: float = 0.0) -> void:
		if _done:
			return
		_go_home(true)

	func receive_throw(_d: Vector2, _f: float) -> void:
		receive_whip(Vector2.ZERO)

	func _go_home(award: bool) -> void:
		_done = true
		Sfx.play(self, "pop", -10.0, 0.9)
		if award and level != null and is_instance_valid(level) and level.has_method("_award"):
			level._award(LevelConfig.BOSS10_CROWD_POINTS, global_position, Color(1.0, 0.9, 0.4))
		if level != null and is_instance_valid(level) and level.has_method("spawn_score_popup"):
			level.spawn_score_popup("SENT HOME!" if award else "BIG HUG!", global_position + Vector2(0, -40), Color(1, 0.6, 0.6), 1)
		popped.emit(self)
		queue_free()

	func _draw() -> void:
		var b := absf(sin(_t * 10.0 + _bob)) * 3.0
		Summit._ellipse(self, Vector2(0, 2), Vector2(9, 3.5), Color(0, 0, 0, 0.3))
		# legs
		draw_line(Vector2(-3, -2), Vector2(-4 + sin(_t * 10.0) * 2.0, 2), Color(0.12, 0.12, 0.2), 3.0)
		draw_line(Vector2(3, -2), Vector2(4 - sin(_t * 10.0) * 2.0, 2), Color(0.12, 0.12, 0.2), 3.0)
		# body
		draw_rect(Rect2(-7, -18 - b, 14, 16), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(-6, -17 - b, 12, 14), shirt)
		# waving arm with a little blank pennant
		var wa := sin(_t * 8.0 + _bob) * 0.5
		var hand := Vector2(8, -22 - b) + Vector2(cos(-1.2 + wa), sin(-1.2 + wa)) * 8.0
		draw_line(Vector2(5, -15 - b), hand, Color(0.95, 0.78, 0.62), 2.5)
		draw_line(hand, hand + Vector2(0, -12), Color(0.5, 0.35, 0.2), 1.5)
		draw_colored_polygon(PackedVector2Array([hand + Vector2(0, -12), hand + Vector2(10, -9), hand + Vector2(0, -6)]), Color(0.9, 0.15, 0.2))
		# head + plain red cap (no text)
		draw_circle(Vector2(0, -24 - b), 6.5, Color(0.06, 0.03, 0.08))
		draw_circle(Vector2(0, -24 - b), 5.2, Color(0.96, 0.8, 0.66))
		draw_rect(Rect2(-6.5, -32 - b, 13, 6), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(-5.5, -31 - b, 11, 5), Color(0.86, 0.12, 0.16))
		draw_rect(Rect2(-1, -27 - b, 10, 2.5), Color(0.7, 0.08, 0.12))
		draw_circle(Vector2(-2, -23 - b), 0.9, Color(0.06, 0.03, 0.08))
		draw_circle(Vector2(2, -23 - b), 0.9, Color(0.06, 0.03, 0.08))
