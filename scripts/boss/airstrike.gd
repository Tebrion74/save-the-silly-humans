class_name Airstrike
extends RefCounted
## Build 018: Beorge Kush Jr.'s air force (all drawn in code, no assets but
## the jet sprite from tools/gen_boss3.py).
##   Airstrike.Mark     red target mark on the ground; blasts after its fuse
##   Airstrike.Blast    explosion flash + smoke (visual only)
##   Airstrike.JetPass  a jet streaking over (visual + sound only)
##   Airstrike.Strafe   STRAFING RUN: a DANGER lane, then a jet firing down it
## Damage to the rancher goes through the level (kush_level.gd), so the shared
## BOSS_PLAYER_HIT_COOLDOWN mercy window applies.

const JET_TEX := preload("res://assets/boss3/jet_80.png")


static func _ring(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, w: float, dashed := false) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := float(i) / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	if dashed:
		for i in 32:
			if i % 2 == 0:
				ci.draw_line(pts[i], pts[i + 1], col, w)
	else:
		ci.draw_polyline(pts, col, w)


static func _disc(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := float(i) / 24.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


## A target mark. `delay` > 0: not there yet (carpet bombing marches in).
## Blasts when `fuse` runs out: rancher inside `radius` -> level.airstrike_hit_player,
## Beorge inside -> FRIENDLY FIRE (1 heart, normal i-frames).
class Mark extends Node2D:
	var level: Node = null
	var boss: Node = null
	var radius := 52.0
	var fuse := 1.2
	var total := 1.2
	var delay := 0.0
	var kind := "strike"
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		add_to_group("airstrike_mark")
		z_index = 1
		visible = delay <= 0.0

	func is_live() -> bool:
		return delay <= 0.0 and not _done

	## 0..1 how close it is to blasting.
	func progress() -> float:
		return clampf(1.0 - fuse / maxf(total, 0.01), 0.0, 1.0)

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_t += delta
		if delay > 0.0:
			delay -= delta
			if delay <= 0.0:
				visible = true
				Sfx.play(self, "mark", -14.0, 1.0 + randf() * 0.15)
			return
		fuse -= delta
		if fuse <= 0.0:
			blast()
			return
		queue_redraw()

	func blast() -> void:
		if _done:
			return
		_done = true
		if level != null and is_instance_valid(level) and level.has_method("airstrike_blast"):
			level.airstrike_blast(global_position, radius, kind)
		queue_free()

	func cancel() -> void:
		_done = true
		queue_free()

	func _draw() -> void:
		if delay > 0.0:
			return
		var k := progress()
		var r := Vector2(radius, radius * 0.55)
		var pulse := 0.5 + 0.5 * sin(_t * (14.0 + 16.0 * k))
		Airstrike._disc(self, Vector2.ZERO, r, Color(0.9, 0.08, 0.05, 0.10 + 0.22 * k))
		Airstrike._ring(self, Vector2.ZERO, r, Color(0.06, 0.03, 0.08, 0.8), 5.0)
		Airstrike._ring(self, Vector2.ZERO, r, Color(1.0, 0.18 + 0.2 * pulse, 0.12, 0.85), 3.0)
		# the countdown ring closes in on the edge
		var rr := r * (1.0 + 0.9 * (1.0 - k))
		Airstrike._ring(self, Vector2.ZERO, rr, Color(1.0, 0.9, 0.4, 0.75), 2.0, true)
		# crosshair
		var col := Color(1.0, 0.95, 0.9, 0.9)
		draw_line(Vector2(-r.x * 0.55, 0), Vector2(-6, 0), col, 2.0)
		draw_line(Vector2(6, 0), Vector2(r.x * 0.55, 0), col, 2.0)
		draw_line(Vector2(0, -r.y * 0.55), Vector2(0, -4), col, 2.0)
		draw_line(Vector2(0, 4), Vector2(0, r.y * 0.55), col, 2.0)
		# falling bomb shadow in the last third
		if k > 0.66:
			var s := (k - 0.66) / 0.34
			Airstrike._disc(self, Vector2.ZERO, Vector2(4.0 + 8.0 * s, (4.0 + 8.0 * s) * 0.5), Color(0, 0, 0, 0.45))


## Explosion: white flash, orange fireball, rising smoke puffs. Visual only.
class Blast extends Node2D:
	var radius := 52.0
	var _t := 0.0
	const LIFE := 0.7

	func _ready() -> void:
		add_to_group("airstrike_blast")

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u := _t / LIFE
		var r := radius * (0.6 + 0.6 * minf(u * 4.0, 1.0))
		if u < 0.12:
			Airstrike._disc(self, Vector2(0, -10), Vector2(r * 1.1, r * 0.8), Color(1, 1, 0.9, 0.9 * (1.0 - u / 0.12)))
		Airstrike._disc(self, Vector2(0, -8), Vector2(r, r * 0.62), Color(1.0, 0.55, 0.1, 0.75 * (1.0 - u)))
		Airstrike._disc(self, Vector2(0, -14), Vector2(r * 0.6, r * 0.45), Color(1.0, 0.92, 0.4, 0.85 * (1.0 - u)))
		for i in 5:
			var a := float(i) / 5.0 * TAU + 0.6
			var c := Vector2(cos(a) * r * 0.55, -16.0 + sin(a) * r * 0.3 - 40.0 * u)
			Airstrike._disc(self, c, Vector2(12.0 + 10.0 * u, 10.0 + 8.0 * u), Color(0.25, 0.22, 0.24, 0.55 * (1.0 - u)))
		Airstrike._ring(self, Vector2.ZERO, Vector2(radius, radius * 0.55) * (0.9 + u * 0.5), Color(1.0, 0.8, 0.4, 0.6 * (1.0 - u)), 3.0)


## A jet streaking across (sprite + ground shadow). Visual and sound only.
class JetPass extends Node2D:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var speed := 1400.0
	var height := 70.0
	var _t := 0.0
	var _life := 1.0
	var _spr: Sprite2D

	func _ready() -> void:
		add_to_group("jet_pass")
		_spr = Sprite2D.new()
		_spr.texture = Airstrike.JET_TEX
		_spr.position = Vector2(0, -height)
		_spr.rotation = (to - from).angle()
		add_child(_spr)
		global_position = from
		_life = from.distance_to(to) / maxf(speed, 1.0)
		Sfx.play(self, "jet", -9.0, randf_range(0.95, 1.08))

	func _process(delta: float) -> void:
		_t += delta
		var u := clampf(_t / _life, 0.0, 1.0)
		global_position = from.lerp(to, u)
		if u >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var d := (to - from).normalized()
		# shadow (stretched ellipse along the flight path) + contrail
		var pts := PackedVector2Array()
		for i in 16:
			var a := float(i) / 16.0 * TAU
			var v := Vector2(cos(a) * 34.0, sin(a) * 12.0).rotated(d.angle())
			pts.append(v)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.28))
		draw_line(Vector2(0, -height) - d * 40.0, Vector2(0, -height) - d * 220.0, Color(1, 1, 1, 0.35), 5.0)


## STRAFING RUN. `origin` is a point on the lane (your position when it was
## called), `dir` the lane direction. Tell: a flashing DANGER lane with
## chevrons. Then a jet flies the lane at BOSS3_STRAFE_SPEED and its gun
## point hits anything inside the lane within BOSS3_STRAFE_GUN_REACH.
class Strafe extends Node2D:
	var level: Node = null
	var origin := Vector2.ZERO
	var dir := Vector2.RIGHT
	var half_width := 34.0
	var length := 1600.0
	var tell := 1.0
	var _t := 0.0
	var _firing := false
	var _jet_along := 0.0
	var _hit_done := false
	var _spr: Sprite2D
	var _impacts: Array = []

	func _ready() -> void:
		add_to_group("strafe_run")
		z_index = 1
		global_position = origin
		Sfx.play(self, "warn", -10.0)

	func is_firing() -> bool:
		return _firing

	## Signed distance of `pos` from the lane centre line, and along it.
	func lane_coords(pos: Vector2) -> Vector2:
		var rel := pos - origin
		return Vector2(rel.dot(dir), rel.dot(dir.orthogonal()))

	func in_lane(pos: Vector2) -> bool:
		var lc := lane_coords(pos)
		return absf(lc.y) <= half_width and absf(lc.x) <= length * 0.5

	func time_to_fire() -> float:
		return maxf(tell - _t, 0.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _firing:
			if _t >= tell:
				_firing = true
				_jet_along = -length * 0.5 - 120.0
				_spr = Sprite2D.new()
				_spr.texture = Airstrike.JET_TEX
				_spr.rotation = dir.angle()
				_spr.z_index = 210
				add_child(_spr)
				Sfx.play(self, "strafe", -7.0)
				Sfx.play(self, "jet", -8.0, 1.1)
			queue_redraw()
			return
		_jet_along += LevelConfig.BOSS3_STRAFE_SPEED * delta
		_spr.position = dir * _jet_along + Vector2(0, -60)
		var gun := _jet_along - 40.0
		if randf() < 0.9:
			_impacts.append([gun + randf_range(-20.0, 20.0), randf_range(-half_width * 0.8, half_width * 0.8), 0.0])
		if not _hit_done and level != null and is_instance_valid(level):
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p != null:
				var lc := lane_coords(p.global_position)
				if absf(lc.y) <= half_width and absf(lc.x - gun) <= LevelConfig.BOSS3_STRAFE_GUN_REACH:
					if level.has_method("strafe_hit_player") and level.strafe_hit_player(p.global_position):
						_hit_done = true
		for im in _impacts:
			im[2] += delta
		_impacts = _impacts.filter(func(im) -> bool: return im[2] < 0.35)
		if _jet_along > length * 0.5 + 200.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var n := dir.orthogonal()
		var a := -dir * length * 0.5
		var b := dir * length * 0.5
		if not _firing:
			var k := clampf(_t / maxf(tell, 0.01), 0.0, 1.0)
			var flash := fmod(_t, 0.24) < 0.12
			var fill := Color(1.0, 0.85, 0.1, 0.10 + 0.18 * k) if flash else Color(1.0, 0.2, 0.1, 0.10 + 0.18 * k)
			draw_colored_polygon(PackedVector2Array([a + n * half_width, b + n * half_width, b - n * half_width, a - n * half_width]), fill)
			for s in [-1.0, 1.0]:
				draw_line(a + n * half_width * s, b + n * half_width * s, Color(0.06, 0.03, 0.08, 0.7), 5.0)
				draw_line(a + n * half_width * s, b + n * half_width * s, Color(1.0, 0.85, 0.15, 0.9), 3.0)
			# chevrons marching in the jet's direction
			var step := 70.0
			var off := fmod(_t * 260.0, step)
			var x := -length * 0.5 + off
			while x < length * 0.5:
				var c := dir * x
				draw_line(c - dir * 10.0 + n * 14.0, c + dir * 6.0, Color(1, 1, 1, 0.5 + 0.4 * k), 3.0)
				draw_line(c - dir * 10.0 - n * 14.0, c + dir * 6.0, Color(1, 1, 1, 0.5 + 0.4 * k), 3.0)
				x += step
			return
		# firing: lane fades, bullet impacts kick up dust
		draw_colored_polygon(PackedVector2Array([a + n * half_width, b + n * half_width, b - n * half_width, a - n * half_width]), Color(1.0, 0.3, 0.1, 0.08))
		for im in _impacts:
			var p: Vector2 = dir * float(im[0]) + n * float(im[1])
			var u: float = float(im[2]) / 0.35
			Airstrike._disc(self, p, Vector2(6.0 + 6.0 * u, 3.0 + 3.0 * u), Color(0.85, 0.75, 0.55, 0.7 * (1.0 - u)))
			draw_line(p, p + Vector2(0, -10.0 * (1.0 - u)), Color(1, 0.95, 0.6, 0.9 * (1.0 - u)), 2.0)
		# tracer line from the jet's guns
		var g := dir * (_jet_along - 40.0)
		draw_line(g + Vector2(0, -50), g - dir * 30.0, Color(1, 0.95, 0.5, 0.9), 3.0)
