class_name BonusSheep
extends Node2D
## Build 016: a flying bonus-stage sheep (the normal sheep sprite + flapping
## wings, a ground shadow below). Flies its wave's path at a constant speed;
## ANY hit pops it (whip, whip shot, shockwave splash, fire, cam swing, grab).
## A sheep that reaches the end of its path has left the field: a miss.

signal popped(sheep: Node)
signal escaped(sheep: Node)

const SHEET := preload("res://assets/characters/sheep_32.png")

var path := PackedVector2Array()
var speed := 340.0
var delay := 0.0
var wave := 0
var level: Node = null
var exploding := false
var dist := 0.0
var _seg := 0
var _seg_start := 0.0
var _t := 0.0
var _dir := Vector2.RIGHT
var _spr: Sprite2D
var _started := false


func _ready() -> void:
	add_to_group("bonus_sheep")
	_spr = Sprite2D.new()
	_spr.texture = SHEET
	_spr.hframes = 6
	_spr.vframes = 4
	_spr.position = Vector2(0, -LevelConfig.BONUS_FLY_HEIGHT)
	add_child(_spr)
	visible = false
	if path.size() > 0:
		global_position = path[0]


func is_flying() -> bool:
	return _started and not exploding


func _physics_process(delta: float) -> void:
	if exploding:
		return
	if not _started:
		delay -= delta
		if delay > 0.0:
			return
		_started = true
		visible = true
		add_to_group("sheep")
		add_to_group("whippable")
	_t += delta
	dist += speed * delta
	# advance along the polyline
	while _seg < path.size() - 1:
		var l := path[_seg].distance_to(path[_seg + 1])
		if dist - _seg_start <= l:
			var k := (dist - _seg_start) / maxf(l, 0.001)
			var np := path[_seg].lerp(path[_seg + 1], k)
			var d := np - global_position
			if d.length_squared() > 0.01:
				_dir = d.normalized()
			global_position = np
			break
		_seg_start += l
		_seg += 1
	if _seg >= path.size() - 1:
		exploding = true
		remove_from_group("sheep")
		remove_from_group("whippable")
		escaped.emit(self)
		queue_free()
		return
	_animate()
	queue_redraw()


func _animate() -> void:
	var row := 0
	if absf(_dir.x) > absf(_dir.y):
		row = 1 if _dir.x < 0.0 else 2
	else:
		row = 3 if _dir.y < 0.0 else 0
	_spr.frame = row * 6 + int(_t * 12.0) % 6
	_spr.position.y = -LevelConfig.BONUS_FLY_HEIGHT - absf(sin(_t * 9.0)) * 3.0


# ------------------------------------------------------------------ hits

func receive_whip(_source_position: Vector2, _force: float = 0.0) -> void:
	pop()


func fire_damage() -> void:
	pop()


func receive_swing(_source_position: Vector2, _push: float, _stagger: float) -> void:
	pop()


func receive_throw(_direction: Vector2, _force: float) -> void:
	pop()


func pop() -> void:
	if exploding or not _started:
		return
	exploding = true
	remove_from_group("sheep")
	remove_from_group("whippable")
	Sfx.play(self, "pop", -8.0, randf_range(0.92, 1.1))
	var host: Node = level.fx_layer if level != null and is_instance_valid(level) and "fx_layer" in level and level.fx_layer != null else get_parent()
	WoolBurst.spawn(host, global_position + Vector2(0, -LevelConfig.BONUS_FLY_HEIGHT), Color(1, 1, 1), Color(1.0, 0.85, 0.35), 1.0)
	popped.emit(self)
	queue_free()


func _draw() -> void:
	if not _started:
		return
	# ground shadow (it's flying)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 16.0, 10.0 + sin(a) * 5.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))
	# flapping wings behind the body
	var flap := sin(_t * 18.0)
	var y := -LevelConfig.BONUS_FLY_HEIGHT - 14.0
	for side in [-1.0, 1.0]:
		var root := Vector2(side * 8.0, y + 4.0)
		var tip := Vector2(side * (26.0 + 4.0 * flap), y - 12.0 * flap)
		var mid := Vector2(side * 20.0, y + 6.0 + 4.0 * flap)
		var poly := PackedVector2Array([root, tip, mid])
		draw_colored_polygon(poly, Color(0.06, 0.03, 0.08))
		var inner := PackedVector2Array([root.lerp(mid, 0.15) + Vector2(0, -1), root.lerp(tip, 0.88), mid.lerp(root, 0.12)])
		draw_colored_polygon(inner, Color(1.0, 0.98, 0.9))
		draw_line(root, root.lerp(tip, 0.8), Color(0.75, 0.82, 1.0), 1.5)
