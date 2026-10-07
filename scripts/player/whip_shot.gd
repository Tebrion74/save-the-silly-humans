class_name WhipShot
extends Node2D
## Build 013: WHIP SHOT projectile. Flies along the crack direction and hits
## the first whippable within WHIP_SHOT_HIT_RADIUS exactly like a whip crack
## (sheep explode, possessed explode, Karens take a hit, silly humans get a
## shove). With FIRE WHIP active it also ignites what it hits.

var direction := Vector2.RIGHT
var speed: float = LevelConfig.WHIP_SHOT_SPEED
var max_distance: float = LevelConfig.WHIP_SHOT_RANGE
var fire := false
var force: float = 520.0
var travelled := 0.0
var _t := 0.0
var _trail: Array[Vector2] = []


func _ready() -> void:
	add_to_group("whip_shots")
	z_index = 15


func _physics_process(delta: float) -> void:
	_t += delta
	var step := direction * speed * delta
	global_position += step
	travelled += step.length()
	_trail.push_front(global_position)
	if _trail.size() > 6:
		_trail.pop_back()
	var hit := _find_hit()
	if hit != null:
		if fire:
			Burn.ignite(hit)
		if hit.has_method("receive_whip"):
			hit.receive_whip(global_position - direction * 40.0, force)
		queue_free()
		return
	if travelled >= max_distance:
		queue_free()
		return
	queue_redraw()


func _find_hit() -> Node2D:
	var best: Node2D = null
	var best_d := LevelConfig.WHIP_SHOT_HIT_RADIUS
	for c in get_tree().get_nodes_in_group("whippable"):
		if not c is Node2D or not is_instance_valid(c):
			continue
		if "exploding" in c and c.exploding:
			continue
		var d := global_position.distance_to((c as Node2D).global_position + Vector2(0, -6))
		if d < best_d:
			best_d = d
			best = c
	return best


func _draw() -> void:
	for i in _trail.size():
		var p := to_local(_trail[i])
		var a := 0.5 * (1.0 - float(i) / 6.0)
		draw_circle(p, 6.0 - i * 0.7, Color(1.0, 0.85, 0.3, a) if not fire else Color(1.0, 0.45, 0.1, a))
	var core := Color(1, 1, 0.75) if not fire else Color(1.0, 0.8, 0.3)
	draw_circle(Vector2.ZERO, 8.0, Color(0.06, 0.03, 0.08))
	draw_circle(Vector2.ZERO, 6.0, core)
	draw_circle(Vector2(-2, -2), 2.5, Color(1, 1, 1))
