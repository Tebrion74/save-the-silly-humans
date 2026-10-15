class_name Drones
extends RefCounted
## Build 025: Zelodymer Violentsky's drone swarm (drawn in code, toy-like).
##   Drones.Drone  launches from the boss, flies to a hover point over a
##                 target, telegraphs the target circle while hovering, then
##                 dives and pops in a cartoon burst. Whip one out of the air
##                 (any crack) before it dives for points.
## Damage goes through level.tech_hit_player("drone", pos).


class Drone extends Node2D:
	signal popped(d: Node)
	enum S { LAUNCH, HOVER, DIVE, BLAST }
	var level: Node = null
	var target := Vector2.ZERO
	var hover_time := 1.0
	var speed: float = LevelConfig.BOSS8_DRONE_SPEED
	var blast_r: float = LevelConfig.BOSS8_DRONE_BLAST
	var state: int = S.LAUNCH
	var _st := 0.0
	var _t := 0.0
	var _alt := 0.0             ## drawn height above the ground point
	var _done := false

	func _ready() -> void:
		add_to_group("drone")
		add_to_group("whippable")
		add_to_group("poutine")
		z_index = 4
		_t = randf() * 3.0

	func splat(_s: float = 1.0) -> void:
		_done = true
		queue_free()

	func is_armed() -> bool:
		return state == S.HOVER or state == S.DIVE

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_t += delta
		_st += delta
		match state:
			S.LAUNCH:
				_alt = minf(_alt + delta * 160.0, 46.0)
				var to := target - global_position
				if to.length() <= speed * delta + 2.0:
					global_position = target
					state = S.HOVER
					_st = 0.0
					Sfx.play(self, "mark", -14.0, 1.3)
				else:
					global_position += to.normalized() * speed * delta
			S.HOVER:
				if _st >= hover_time:
					state = S.DIVE
					_st = 0.0
			S.DIVE:
				_alt = maxf(_alt - delta * 420.0, 0.0)
				if _alt <= 0.0:
					state = S.BLAST
					_st = 0.0
					Sfx.play(self, "bomb", -12.0, 1.35)
					var p := get_tree().get_first_node_in_group("player") as Node2D
					if p != null:
						var d := p.global_position - global_position
						if Vector2(d.x, d.y / 0.75).length() <= blast_r + 4.0:
							if level != null and is_instance_valid(level) and level.has_method("tech_hit_player"):
								level.tech_hit_player("drone", global_position)
			S.BLAST:
				if _st > 0.35:
					queue_free()
		queue_redraw()

	func receive_whip(_from: Vector2, _f: float = 0.0) -> void:
		if _done or state == S.BLAST:
			return
		_pop()

	func receive_throw(_d: Vector2, _f: float) -> void:
		receive_whip(Vector2.ZERO)

	func _pop() -> void:
		_done = true
		Sfx.play(self, "pop", -8.0, 1.2)
		if level != null and is_instance_valid(level) and level.has_method("_award"):
			level._award(LevelConfig.BOSS8_DRONE_POINTS, global_position, Color(1.0, 0.9, 0.4))
		popped.emit(self)
		queue_free()

	func _draw() -> void:
		if state == S.BLAST:
			var k := clampf(_st / 0.35, 0.0, 1.0)
			var r := blast_r * (0.6 + 0.6 * k)
			var pts := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				var rr := r if i % 2 == 0 else r * 0.55
				pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.75))
			draw_colored_polygon(pts, Color(1.0, 0.85, 0.25, 1.0 - k))
			Summit._ellipse(self, Vector2.ZERO, Vector2(r * 0.45, r * 0.34), Color(1, 1, 0.9, 1.0 - k))
			draw_string(ThemeDB.fallback_font, Vector2(-16, -r * 0.6), "POP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 1.0 - k))
			return
		# ground target circle while armed
		if state == S.HOVER or state == S.DIVE:
			var k := clampf(_st / maxf(hover_time, 0.01), 0.0, 1.0) if state == S.HOVER else 1.0
			Summit._ellipse(self, Vector2.ZERO, Vector2(blast_r, blast_r * 0.75), Color(1.0, 0.5, 0.1, 0.1 + 0.18 * k))
			draw_polyline(Summit.ring_pts(Vector2.ZERO, Vector2(blast_r, blast_r * 0.75), 0.0, TAU, 28), Color(1.0, 0.6, 0.15, 0.55 + 0.45 * sin(_t * 24.0)), 2.5)
		else:
			Summit._ellipse(self, Vector2(0, 2), Vector2(12, 4), Color(0, 0, 0, 0.25))
		# the toy quadcopter
		var y := -_alt + sin(_t * 9.0) * 2.0
		draw_rect(Rect2(-9, y - 4, 18, 8), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(-7, y - 3, 14, 6), Color(0.35, 0.38, 0.32))
		for sx in [-1.0, 1.0]:
			draw_line(Vector2(sx * 6, y), Vector2(sx * 15, y - 5), Color(0.06, 0.03, 0.08), 3.0)
			var spin := absf(sin(_t * 40.0 + sx)) * 8.0 + 3.0
			draw_line(Vector2(sx * 15 - spin, y - 7), Vector2(sx * 15 + spin, y - 7), Color(0.85, 0.88, 0.92, 0.8), 2.0)
		draw_circle(Vector2(0, y + 4), 2.0, Color(1.0, 0.3, 0.25) if int(_t * 6.0) % 2 == 0 else Color(0.3, 1.0, 0.4))
