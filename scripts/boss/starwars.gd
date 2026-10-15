class_name StarWars
extends RefCounted
## Build 025: Reanald Rogan's "Star Wars" missile-defence toolkit (drawn in code).
##   StarWars.OrbitalStrike  ORBITAL LASER: a target circle telegraphs, then a beam
##                           drops from orbit. Step out of the circle.
##   StarWars.SatBeam        SATELLITE BEAM: a line telegraphs through you, then
##                           the beam sweeps across the arena. Dodge the sweep.
##   StarWars.Ufo            a UFO drifts over the arena and drops a telegraphed
##                           tractor beam on your spot every few seconds. Two
##                           whip cracks (or one throw) pop it for points.
## Every hazard hurts through level.tech_hit_player(kind, pos), which goes via
## boss_level.poutine_hit_player (shared mercy window, god mode, armour, star).


static func _hit(level: Node, kind: String, pos: Vector2) -> void:
	if level != null and is_instance_valid(level) and level.has_method("tech_hit_player"):
		level.tech_hit_player(kind, pos)


static func _player(n: Node) -> Node2D:
	return n.get_tree().get_first_node_in_group("player") as Node2D


class OrbitalStrike extends Node2D:
	var level: Node = null
	var tell := 1.0
	var radius: float = LevelConfig.BOSS7_ORBITAL_RADIUS
	var _t := 0.0
	var _fired := false

	func _ready() -> void:
		add_to_group("orbital_strike")
		add_to_group("poutine")
		z_index = 2

	func splat(_s: float = 1.0) -> void:
		queue_free()

	func time_to_fire() -> float:
		return maxf(tell - _t, 0.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _fired and _t >= tell:
			_fired = true
			Sfx.play(self, "laser", -8.0, randf_range(0.92, 1.08))
			var p := StarWars._player(self)
			if p != null:
				var d := p.global_position - global_position
				if Vector2(d.x, d.y / 0.75).length() <= radius + 6.0:
					StarWars._hit(level, "orbital", global_position)
		if _t > tell + 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var ry := radius * 0.75
		if not _fired:
			var k := clampf(_t / maxf(tell, 0.01), 0.0, 1.0)
			var blink := 0.5 + 0.5 * sin(_t * (10.0 + 20.0 * k))
			Summit._ellipse(self, Vector2.ZERO, Vector2(radius, ry), Color(1.0, 0.15, 0.2, 0.12 + 0.18 * k))
			draw_polyline(Summit.ring_pts(Vector2.ZERO, Vector2(radius, ry), 0.0, TAU, 32), Color(1.0, 0.3, 0.3, 0.6 + 0.4 * blink), 3.0)
			var r2 := lerpf(radius * 1.8, radius * 0.3, k)
			draw_polyline(Summit.ring_pts(Vector2.ZERO, Vector2(r2, r2 * 0.75), 0.0, TAU, 28), Color(1, 0.9, 0.9, 0.7), 2.0)
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				var v := Vector2(cos(a) * radius, sin(a) * ry)
				draw_line(v * 0.55, v * 1.25, Color(1, 0.95, 0.95, 0.9), 2.0)
			return
		var f := clampf(1.0 - (_t - tell) / 0.4, 0.0, 1.0)
		draw_rect(Rect2(-16, -900, 32, 900), Color(0.4, 0.9, 1.0, 0.35 * f))
		draw_rect(Rect2(-8, -900, 16, 900), Color(0.8, 1.0, 1.0, 0.8 * f))
		draw_rect(Rect2(-3, -900, 6, 900), Color(1, 1, 1, f))
		Summit._ellipse(self, Vector2.ZERO, Vector2(radius * 1.2, ry * 1.2), Color(0.6, 1.0, 1.0, 0.5 * f))
		Summit._ellipse(self, Vector2.ZERO, Vector2(radius * 0.6, ry * 0.6), Color(1, 1, 1, 0.8 * f))


class SatBeam extends Node2D:
	## Positioned at the satellite (above the arena); the beam is a ray from it.
	var level: Node = null
	var tell := 0.9
	var sweep := deg_to_rad(60.0)
	var sweep_time: float = LevelConfig.BOSS7_BEAM_TIME
	var width: float = LevelConfig.BOSS7_BEAM_WIDTH
	var angle := PI * 0.5        ## starting beam angle (aimed at the rancher)
	var dir_sign := 1.0
	var _t := 0.0
	var _hummed := false

	func _ready() -> void:
		add_to_group("sat_beam")
		add_to_group("poutine")
		z_index = 3

	func splat(_s: float = 1.0) -> void:
		queue_free()

	func current_angle() -> float:
		var u := clampf((_t - tell) / maxf(sweep_time, 0.01), 0.0, 1.0)
		return angle + dir_sign * sweep * u

	func is_live() -> bool:
		return _t >= tell and _t <= tell + sweep_time

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= tell and not _hummed:
			_hummed = true
			Sfx.play(self, "beam_hum", -9.0)
		if is_live():
			var p := StarWars._player(self)
			if p != null:
				var a := current_angle()
				var dirv := Vector2(cos(a), sin(a))
				var rel := p.global_position - global_position
				var along := rel.dot(dirv)
				if along > 0.0:
					var off := absf(rel.cross(dirv))
					if off <= width * 0.5 + 10.0:
						StarWars._hit(level, "satbeam", p.global_position - dirv * 20.0)
		if _t > tell + sweep_time + 0.25:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var L := 1500.0
		# the satellite itself
		draw_rect(Rect2(-30, -6, 20, 12), Color(0.15, 0.3, 0.75))
		draw_rect(Rect2(10, -6, 20, 12), Color(0.15, 0.3, 0.75))
		draw_rect(Rect2(-10, -9, 20, 18), Color(0.8, 0.82, 0.88))
		draw_circle(Vector2(0, 10), 5.0, Color(0.95, 0.95, 1.0))
		if _t < tell:
			var k := clampf(_t / maxf(tell, 0.01), 0.0, 1.0)
			var d0 := Vector2(cos(angle), sin(angle))
			var d1 := Vector2(cos(angle + dir_sign * sweep), sin(angle + dir_sign * sweep))
			# swept wedge + start line
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in 13:
				var a := angle + dir_sign * sweep * i / 12.0
				pts.append(Vector2(cos(a), sin(a)) * L)
			draw_colored_polygon(pts, Color(1.0, 0.3, 0.3, 0.06 + 0.1 * k))
			var blink := 0.5 + 0.5 * sin(_t * 24.0)
			var seg := 0.0
			while seg < L:
				draw_line(d0 * seg, d0 * minf(seg + 22.0, L), Color(1.0, 0.35, 0.35, 0.5 + 0.5 * blink), 3.0)
				seg += 36.0
			draw_line(d1 * 60.0, d1 * L, Color(1.0, 0.6, 0.6, 0.25), 2.0)
			return
		if is_live():
			var a := current_angle()
			var dv := Vector2(cos(a), sin(a))
			draw_line(Vector2.ZERO, dv * L, Color(0.4, 0.9, 1.0, 0.35), width * 1.6)
			draw_line(Vector2.ZERO, dv * L, Color(0.8, 1.0, 1.0, 0.85), width * 0.7)
			draw_line(Vector2.ZERO, dv * L, Color(1, 1, 1), width * 0.25)


class Ufo extends Node2D:
	signal popped(u: Node)
	var level: Node = null
	var arena := Rect2(-600, -300, 1200, 640)
	var hp := 2
	var life: float = LevelConfig.BOSS7_UFO_LIFE
	var beam_every: float = LevelConfig.BOSS7_UFO_BEAM_EVERY
	var beam_tell: float = LevelConfig.BOSS7_UFO_BEAM_TELL
	var beam_r: float = LevelConfig.BOSS7_UFO_BEAM_RADIUS
	var _t := 0.0
	var _beam_cd := 1.6
	var _beam_t := -1.0       ## >= 0 while telegraphing / firing
	var _beam_at := Vector2.ZERO
	var _vel := Vector2.ZERO
	var _flash := 0.0
	var _leaving := false
	var _done := false

	func _ready() -> void:
		add_to_group("ufo")
		add_to_group("whippable")
		add_to_group("poutine")
		z_index = 4
		Sfx.play(self, "ufo", -10.0)

	func splat(_s: float = 1.0) -> void:
		_done = true
		queue_free()

	func is_beaming() -> bool:
		return _beam_t >= 0.0

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_t += delta
		_flash = maxf(_flash - delta, 0.0)
		var p := StarWars._player(self)
		if _t >= life and not _leaving and _beam_t < 0.0:
			_leaving = true
		if _leaving:
			_vel = _vel.lerp(Vector2(0, -420), minf(delta * 2.0, 1.0))
			global_position += _vel * delta
			if not arena.grow(220.0).has_point(global_position):
				splat()
			queue_redraw()
			return
		if _beam_t >= 0.0:
			_beam_t += delta
			global_position = global_position.lerp(_beam_at, minf(delta * 6.0, 1.0))
			if _beam_t >= beam_tell and _beam_t - delta < beam_tell:
				Sfx.play(self, "laser", -12.0, 1.4)
			if _beam_t >= beam_tell and _beam_t <= beam_tell + 0.3 and p != null:
				var d := p.global_position - _beam_at
				if Vector2(d.x, d.y / 0.75).length() <= beam_r + 4.0:
					StarWars._hit(level, "ufo", _beam_at)
			if _beam_t > beam_tell + 0.35:
				_beam_t = -1.0
				_beam_cd = beam_every
		else:
			_beam_cd -= delta
			# drift: wander towards a point near (but not on) the rancher
			var goal := global_position
			if p != null:
				goal = p.global_position + Vector2(cos(_t * 0.9) * 150.0, sin(_t * 0.7) * 90.0)
			var want := global_position.direction_to(goal) * 120.0 if global_position.distance_to(goal) > 12.0 else Vector2.ZERO
			_vel = _vel.lerp(want, minf(delta * 2.5, 1.0))
			global_position += _vel * delta
			global_position = global_position.clamp(arena.position + Vector2(30, 30), arena.end - Vector2(30, 30))
			if _beam_cd <= 0.0 and p != null:
				_beam_t = 0.0
				_beam_at = p.global_position
				Sfx.play(self, "mark", -10.0, 0.8)
		queue_redraw()

	func receive_whip(_from: Vector2, _f: float = 0.0) -> void:
		if _done or _leaving:
			return
		hp -= 1
		_flash = 0.18
		Sfx.play(self, "boss_hit", -8.0, 1.5)
		if hp <= 0:
			_pop()

	func receive_throw(_d: Vector2, _f: float) -> void:
		if not _done and not _leaving:
			_pop()

	func _pop() -> void:
		_done = true
		Sfx.play(self, "pop", -6.0, 0.7)
		if level != null and is_instance_valid(level):
			if level.has_method("_award"):
				level._award(LevelConfig.BOSS7_UFO_POINTS, global_position, Color(0.6, 1.0, 0.7))
			elif level.has_method("spawn_score_popup"):
				level.spawn_score_popup("+%d" % LevelConfig.BOSS7_UFO_POINTS, global_position, Color(0.6, 1.0, 0.7))
		popped.emit(self)
		queue_free()

	func _draw() -> void:
		var hover := sin(_t * 3.0) * 4.0
		# ground shadow (this is the whip target point)
		Summit._ellipse(self, Vector2(0, 2), Vector2(22, 7), Color(0, 0, 0, 0.3))
		if _beam_t >= 0.0:
			var at := _beam_at - global_position
			var k := clampf(_beam_t / maxf(beam_tell, 0.01), 0.0, 1.0)
			var firing := _beam_t >= beam_tell
			var cone := PackedVector2Array([Vector2(-10, -52 + hover), Vector2(10, -52 + hover), at + Vector2(beam_r, 0), at + Vector2(-beam_r, 0)])
			draw_colored_polygon(cone, Color(0.6, 1.0, 0.6, 0.55 if firing else 0.08 + 0.12 * k))
			draw_polyline(Summit.ring_pts(at, Vector2(beam_r, beam_r * 0.75), 0.0, TAU, 28), Color(0.5, 1.0, 0.5, 0.5 + 0.5 * sin(_beam_t * 26.0)), 3.0)
			if firing:
				Summit._ellipse(self, at, Vector2(beam_r, beam_r * 0.75), Color(0.7, 1.0, 0.7, 0.6))
		var body := Color(1, 1, 1) if _flash > 0.0 else Color(0.62, 0.66, 0.74)
		var y := -56.0 + hover
		Summit._ellipse(self, Vector2(0, y), Vector2(30, 10), Color(0.06, 0.03, 0.08))
		Summit._ellipse(self, Vector2(0, y), Vector2(28, 8), body)
		Summit._ellipse(self, Vector2(0, y - 7), Vector2(13, 9), Color(0.06, 0.03, 0.08))
		Summit._ellipse(self, Vector2(0, y - 7), Vector2(11, 7.5), Color(0.55, 0.95, 1.0, 0.9))
		for i in 5:
			var lx := -20.0 + i * 10.0
			var on := int(_t * 8.0 + i) % 2 == 0
			draw_circle(Vector2(lx, y + 2), 2.2, Color(1.0, 0.9, 0.3) if on else Color(1.0, 0.4, 0.3))
		if hp < 2:
			draw_line(Vector2(-12, y - 2), Vector2(4, y + 4), Color(0.2, 0.2, 0.25), 2.0)
