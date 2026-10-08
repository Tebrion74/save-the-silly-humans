class_name HumanCamp
extends Node2D
## Build 010: the silly human camp (southwest). Draws a few tents, a campfire and
## log seats (procedural, no collision so nobody gets trapped), and generates
## new silly humans until the round's quota is reached, then stops.
## Build 011: a human is generated only while fewer than living_threshold (5)
## living silly humans are on the map, at most one per min_spawn_interval (5 s).
##
## LevelController positions this node on SLOT_CAMP, then calls
## start_generating(count) after rescues unlock.

signal human_generated(human: Node)
signal generation_finished

@export var min_spawn_interval: float = LevelConfig.CAMP_MIN_SPAWN_INTERVAL
@export var living_threshold: int = LevelConfig.CAMP_LIVING_THRESHOLD
@export var jitter_px: float = 10.0

const HUMAN_SCENE := preload("res://scenes/humans/Human.tscn")

## Layout in pixels relative to the camp centre (campfire). Tents open south.
const TENT_SPOTS := [
	{"pos": Vector2(-76, -40), "canvas": Color(0.86, 0.76, 0.56), "patch": Color(0.86, 0.26, 0.22), "size": 1.3},
	{"pos": Vector2(70, -48), "canvas": Color(0.62, 0.78, 0.74), "patch": Color(0.98, 0.78, 0.25), "size": 1.2},
	{"pos": Vector2(-104, 46), "canvas": Color(0.9, 0.62, 0.42), "patch": Color(0.25, 0.6, 0.85), "size": 1.12},
]
const FIRE_POS := Vector2(0, 6)
const LOG_SPOTS := [Vector2(-34, 26), Vector2(36, 22), Vector2(4, -22)]
## Where new humans appear: tent doorways and around the fire.
const SPAWN_SPOTS := [
	Vector2(-76, -12), Vector2(70, -22), Vector2(-104, 70),
	Vector2(44, 46), Vector2(-40, 52), Vector2(70, 10),
]

var remaining: int = 0
var generated: int = 0
var _timer: float = 0.0
var _active: bool = false
var _rng := RandomNumberGenerator.new()
var _spot_i: int = 0


func _ready() -> void:
	add_to_group("human_camp")
	y_sort_enabled = true
	_rng.randomize()
	_build_decor()


## Generate `count` more humans over the round (see class notes for the rule).
## `_timer` = seconds since the last camp spawn (round start counts as one).
func start_generating(count: int) -> void:
	remaining = maxi(count, 0)
	_timer = 0.0
	_active = remaining > 0
	print("[camp] %d humans to generate; spawn while living < %d, min %.1fs apart" % [remaining, living_threshold, min_spawn_interval])
	if not _active:
		generation_finished.emit()


## Living silly humans on the map (group "humans" = unresolved, not possessed).
func living_humans() -> int:
	var n := 0
	for h in get_tree().get_nodes_in_group("humans"):
		if is_instance_valid(h) and not h.is_queued_for_deletion():
			n += 1
	return n


func is_generating() -> bool:
	return _active


func stop_generating() -> void:
	_active = false


func seconds_since_last_spawn() -> float:
	return _timer


## Build 013: while any Karen is alive the camp's humans "stay in camp" (no
## spawns). The spawn clock keeps running, so the camp resumes as soon as the
## last Karen is gone.
func held_by_karens() -> bool:
	for k in get_tree().get_nodes_in_group("karens"):
		if is_instance_valid(k) and not k.is_queued_for_deletion() and not ("exploding" in k and k.exploding):
			return true
	return false


func _process(delta: float) -> void:
	if not _active:
		return
	_timer += delta
	if _timer < min_spawn_interval:
		return
	if held_by_karens():
		return
	if living_humans() >= living_threshold:
		return
	spawn_one()


## Spawns one human now (also used by tests). Returns it, or null when done.
func spawn_one(allow_cantifa: bool = true) -> Node:
	if remaining <= 0:
		_active = false
		return null
	var level := get_tree().get_first_node_in_group("level_controller")
	if allow_cantifa and level != null and level.has_method("cantifa_roll_replaces") and level.cantifa_roll_replaces():
		if level.spawn_cantifa_from_roll():
			remaining -= 1
			generated += 1
			_timer = 0.0
			if remaining <= 0:
				_active = false
				generation_finished.emit()
			return null
	var parent: Node = null
	if level != null:
		parent = level.get_node_or_null("Entities/Humans")
	if parent == null:
		parent = get_parent()
	var human: Node2D = HUMAN_SCENE.instantiate()
	var spot: Vector2 = SPAWN_SPOTS[_spot_i % SPAWN_SPOTS.size()]
	_spot_i += 1 + _rng.randi_range(0, 2)
	var jitter := Vector2(_rng.randf_range(-jitter_px, jitter_px), _rng.randf_range(-jitter_px, jitter_px))
	parent.add_child(human)
	human.global_position = global_position + spot + jitter
	var spr := human.get_node_or_null("Sprite") as Node2D
	if spr:
		spr.scale = Vector2(0.4, 0.4)
		var tw := human.create_tween()
		tw.tween_property(spr, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	remaining -= 1
	generated += 1
	_timer = 0.0
	human_generated.emit(human)
	if remaining <= 0:
		_active = false
		print("[camp] all humans generated; camp timer stopped")
		generation_finished.emit()
	return human


# ------------------------------------------------------------------ decor

func _build_decor() -> void:
	for t in TENT_SPOTS:
		var tent := CampTent.new()
		tent.position = t["pos"]
		tent.canvas = t["canvas"]
		tent.patch = t["patch"]
		tent.size_mul = float(t["size"])
		add_child(tent)
	for i in LOG_SPOTS.size():
		var lg := CampLog.new()
		lg.position = LOG_SPOTS[i]
		lg.vertical = i == 2
		add_child(lg)
	var fire := CampFire.new()
	fire.position = FIRE_POS
	add_child(fire)
	var pole := CampPennant.new()
	pole.position = Vector2(126, -14)
	add_child(pole)


## A-frame canvas tent; origin at the front base (for y-sorting).
class CampTent extends Node2D:
	var canvas := Color(0.86, 0.76, 0.56)
	var patch := Color(0.86, 0.26, 0.22)
	var size_mul := 1.0

	func _draw() -> void:
		var s := size_mul
		var ink := Color(0.22, 0.14, 0.08)
		var shade := canvas.darkened(0.28)
		var light := canvas.lightened(0.18)
		var w := 46.0 * s
		var h := 50.0 * s
		var depth := 16.0 * s
		# ground shadow
		_ellipse(Vector2(4, 2), Vector2(w + 12.0, 10.0 * s), Color(0, 0, 0, 0.22))
		var apex := Vector2(0, -h)
		var back_apex := apex + Vector2(6.0 * s, -depth * 0.55)
		# back roof slope (right side, in shade)
		draw_colored_polygon(PackedVector2Array([apex, back_apex, Vector2(w + 6.0 * s, -depth * 0.55), Vector2(w, 0)]), shade)
		# front triangle
		var front := PackedVector2Array([Vector2(-w, 0), apex, Vector2(w, 0)])
		draw_colored_polygon(front, canvas)
		# left light panel
		draw_colored_polygon(PackedVector2Array([Vector2(-w, 0), apex, Vector2(-w * 0.45, 0)]), light)
		# patch + seam stitches
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.36, -h * 0.30), Vector2(w * 0.62, -h * 0.30),
			Vector2(w * 0.68, -h * 0.08), Vector2(w * 0.42, -h * 0.08)]), patch)
		for i in 5:
			var u := 0.15 + 0.16 * float(i)
			var p := apex.lerp(Vector2(-w, 0), u)
			draw_line(p, p + Vector2(3, 1), shade, 1.0)
		# doorway (dark flap opening) + rolled flap
		var door := PackedVector2Array([Vector2(-w * 0.34, 0), Vector2(0, -h * 0.62), Vector2(w * 0.34, 0)])
		draw_colored_polygon(door, Color(0.16, 0.1, 0.07))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -h * 0.62), Vector2(w * 0.34, 0), Vector2(w * 0.46, 0), Vector2(w * 0.08, -h * 0.6)]), light)
		# outline
		draw_polyline(PackedVector2Array([Vector2(-w, 0), apex, Vector2(w, 0)]), ink, 2.0, true)
		draw_polyline(PackedVector2Array([apex, back_apex, Vector2(w + 6.0 * s, -depth * 0.55), Vector2(w, 0)]), ink, 1.5, true)
		draw_line(Vector2(-w, 0), Vector2(w, 0), ink, 2.0, true)
		# ridge pole tip + guy ropes and pegs
		draw_line(apex, apex + Vector2(0, -7.0 * s), Color(0.42, 0.27, 0.13), 2.5)
		var rope := Color(0.85, 0.8, 0.66, 0.85)
		draw_line(apex + Vector2(-2, 2), Vector2(-w - 14.0 * s, 4), rope, 1.0, true)
		draw_line(apex + Vector2(2, 2), Vector2(w + 14.0 * s, 4), rope, 1.0, true)
		draw_rect(Rect2(Vector2(-w - 16.0 * s, 2), Vector2(3, 4)), Color(0.4, 0.26, 0.12))
		draw_rect(Rect2(Vector2(w + 13.0 * s, 2), Vector2(3, 4)), Color(0.4, 0.26, 0.12))

	func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 20:
			var a := float(i) / 20.0 * TAU
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)


class CampLog extends Node2D:
	var vertical := false

	func _draw() -> void:
		var bark := Color(0.42, 0.26, 0.13)
		var dark := Color(0.24, 0.14, 0.07)
		var ring := Color(0.78, 0.6, 0.38)
		draw_colored_polygon(_ell(Vector2(2, 3), Vector2(20, 5)), Color(0, 0, 0, 0.2))
		if vertical:
			draw_rect(Rect2(-14, -8, 28, 10), bark)
			draw_line(Vector2(-14, -8), Vector2(14, -8), bark.lightened(0.2), 2.0)
			draw_rect(Rect2(-14, -8, 28, 10), dark, false, 1.5)
		else:
			draw_rect(Rect2(-18, -9, 36, 11), bark)
			draw_line(Vector2(-16, -6), Vector2(14, -6), bark.lightened(0.22), 1.5)
			draw_line(Vector2(-12, -2), Vector2(10, -2), dark, 1.0)
			draw_rect(Rect2(-18, -9, 36, 11), dark, false, 1.5)
			draw_colored_polygon(_ell(Vector2(18, -3.5), Vector2(4, 5.5)), ring)
			draw_arc(Vector2(18, -3.5), 4.5, 0.0, TAU, 12, dark, 1.2)

	func _ell(c: Vector2, r: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 16:
			var a := float(i) / 16.0 * TAU
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts


## Stone ring with crossed logs and an animated flame.
class CampFire extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var glow := 0.16 + 0.05 * sin(_t * 9.0) + 0.03 * sin(_t * 23.0)
		draw_colored_polygon(_ell(Vector2(0, -4), Vector2(46, 26)), Color(1.0, 0.6, 0.2, glow * 0.6))
		draw_colored_polygon(_ell(Vector2(0, -2), Vector2(26, 14)), Color(1.0, 0.7, 0.3, glow))
		# stones
		for i in 9:
			var a := float(i) / 9.0 * TAU
			var p := Vector2(cos(a) * 17.0, sin(a) * 9.0)
			draw_colored_polygon(_ell(p, Vector2(5, 3.6)), Color(0.48, 0.47, 0.45))
			draw_colored_polygon(_ell(p + Vector2(-1, -1), Vector2(3, 2)), Color(0.66, 0.65, 0.62))
		# char + logs
		draw_colored_polygon(_ell(Vector2(0, 0), Vector2(12, 6)), Color(0.12, 0.08, 0.06))
		draw_line(Vector2(-12, 3), Vector2(10, -5), Color(0.4, 0.24, 0.12), 5.0)
		draw_line(Vector2(-10, -5), Vector2(12, 3), Color(0.34, 0.2, 0.1), 5.0)
		# flame (three flickering tongues)
		var cols := [Color(0.95, 0.3, 0.1, 0.95), Color(1.0, 0.62, 0.15, 0.95), Color(1.0, 0.92, 0.55, 0.95)]
		var sizes := [1.0, 0.7, 0.42]
		for k in 3:
			var sz: float = sizes[k]
			var flick := sin(_t * (11.0 + k * 3.0) + k) * 3.0
			var top := Vector2(flick * 0.6, -28.0 * sz - 4.0 - absf(flick))
			var pts := PackedVector2Array([
				Vector2(-10.0 * sz, -1), Vector2(-7.0 * sz + flick * 0.3, -12.0 * sz), top,
				Vector2(7.0 * sz + flick * 0.3, -12.0 * sz), Vector2(10.0 * sz, -1)])
			draw_colored_polygon(pts, cols[k])
		# sparks
		for j in 3:
			var ph := fmod(_t * 0.9 + j * 0.37, 1.0)
			var sp := Vector2(sin(j * 2.1 + _t * 2.0) * 8.0, -20.0 - ph * 30.0)
			draw_rect(Rect2(sp, Vector2(2, 2)), Color(1.0, 0.8, 0.35, 1.0 - ph))

	func _ell(c: Vector2, r: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 18:
			var a := float(i) / 18.0 * TAU
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts


## Little striped pennant on a pole so the camp reads from a distance.
class CampPennant extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(4, 3), Vector2(-4, 3)]), Color(0, 0, 0, 0.22))
		draw_line(Vector2(0, 0), Vector2(0, -58), Color(0.36, 0.22, 0.1), 3.0)
		var wave := sin(_t * 4.0) * 3.0
		var flag := PackedVector2Array([Vector2(1, -58), Vector2(30, -51 + wave), Vector2(1, -44)])
		draw_colored_polygon(flag, Color(0.95, 0.35, 0.55))
		draw_colored_polygon(PackedVector2Array([Vector2(1, -53), Vector2(17, -51 + wave * 0.6), Vector2(1, -49)]), Color(1.0, 0.9, 0.35))
		draw_polyline(PackedVector2Array([Vector2(1, -58), Vector2(30, -51 + wave), Vector2(1, -44)]), Color(0.25, 0.1, 0.12), 1.2, true)
		draw_circle(Vector2(0, -59), 2.5, Color(0.95, 0.82, 0.4))
