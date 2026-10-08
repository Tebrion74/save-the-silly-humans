class_name Poutine
extends Node2D
## Build 015: Trustin Judeau's poutine projectile (fries + gravy + curds in a
## paper boat, art from tools/gen_boss.py). Lives under Entities (y-sorted by
## its GROUND position); the sprite is drawn above its shadow.
##   mode "flat": flies straight at `velocity`, ~26 px above the ground; hits
##                the rancher when its ground point is within POUTINE_HIT_RADIUS.
##   mode "lob" : arcs from `start` to `target` in POUTINE_LOB_TIME; a pulsing
##                landing ring + a growing shadow telegraph where it will land;
##                splashes POUTINE_LOB_RADIUS on landing.
## Every poutine ends in a gravy splat (GravySplat) and a splat sound.

const TEX := preload("res://assets/boss/poutine_32.png")
const FLY_HEIGHT := 26.0

var mode := "flat"
var velocity := Vector2.ZERO
var start := Vector2.ZERO
var target := Vector2.ZERO
var level: Node = null
var bounds := Rect2(-100000, -100000, 200000, 200000)
var travelled := 0.0
var _t := 0.0
var _height := FLY_HEIGHT
var _spr: Sprite2D
var _done := false


func _ready() -> void:
	add_to_group("poutine")
	_spr = Sprite2D.new()
	_spr.texture = TEX
	_spr.position = Vector2(0, -FLY_HEIGHT)
	add_child(_spr)
	if mode == "lob":
		global_position = start
		_height = 0.0


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if mode == "lob":
		var u := clampf(_t / LevelConfig.POUTINE_LOB_TIME, 0.0, 1.0)
		global_position = start.lerp(target, u)
		_height = 4.0 * LevelConfig.POUTINE_LOB_HEIGHT * u * (1.0 - u) + 10.0 * (1.0 - u)
		_spr.position = Vector2(0, -_height)
		_spr.rotation = u * TAU * 1.25
		if u >= 1.0:
			_land(LevelConfig.POUTINE_LOB_RADIUS)
			return
	else:
		var step := velocity * delta
		global_position += step
		travelled += step.length()
		_spr.rotation = sin(_t * 14.0) * 0.25
		_spr.position = Vector2(0, -FLY_HEIGHT + sin(_t * 9.0) * 2.0)
		var p := _player()
		if p != null and global_position.distance_to(p.global_position) <= LevelConfig.POUTINE_HIT_RADIUS:
			_hit_player(p)
			splat()
			return
		if travelled >= LevelConfig.POUTINE_RANGE or not bounds.has_point(global_position):
			splat()
			return
	queue_redraw()


func _player() -> Node2D:
	if not is_inside_tree():
		return null
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or ("_dead" in p and p._dead):
		return null
	return p


func _hit_player(p: Node2D) -> void:
	if level != null and is_instance_valid(level) and level.has_method("poutine_hit_player"):
		level.poutine_hit_player(global_position)
	elif p.has_method("take_damage"):
		p.take_damage(LevelConfig.POUTINE_DAMAGE, global_position)


func _land(radius: float) -> void:
	var p := _player()
	if p != null and global_position.distance_to(p.global_position) <= radius:
		_hit_player(p)
	splat(1.35)


## End of the line: gravy splat on the ground, then free.
func splat(size: float = 1.0) -> void:
	if _done:
		return
	_done = true
	var parent: Node = level.ground_fx if level != null and is_instance_valid(level) and "ground_fx" in level and level.ground_fx != null else get_parent()
	if parent != null:
		var s := GravySplat.new()
		s.scale = Vector2(size, size)
		parent.add_child(s)
		s.global_position = global_position
	Sfx.play(parent if parent != null else self, "splat", -12.0, randf_range(0.9, 1.15))
	queue_free()


func _draw() -> void:
	if mode == "lob":
		var lt := to_local(target)
		var u := clampf(_t / LevelConfig.POUTINE_LOB_TIME, 0.0, 1.0)
		var r := LevelConfig.POUTINE_LOB_RADIUS
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		# landing telegraph: dark fill growing, red dashed ring, centre shadow
		_ellipse(lt, Vector2(r, r * 0.55), Color(0.35, 0.05, 0.05, 0.12 + 0.18 * u))
		_ring(lt, Vector2(r, r * 0.55), Color(1.0, 0.25, 0.2, 0.55 + 0.4 * pulse), 3.0)
		_ring(lt, Vector2(r * (1.0 - u) + 6.0, (r * (1.0 - u) + 6.0) * 0.55), Color(1.0, 0.9, 0.5, 0.7), 2.0)
		var sh := lerpf(6.0, 16.0, u)
		_ellipse(Vector2.ZERO, Vector2(sh, sh * 0.45), Color(0, 0, 0, 0.25 + 0.2 * u))
	else:
		_ellipse(Vector2(0, 2), Vector2(12, 5), Color(0, 0, 0, 0.3))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := float(i) / 20.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _ring(c: Vector2, r: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := float(i) / 24.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	# dashed: draw every other segment
	for i in 24:
		if i % 2 == 0:
			draw_line(pts[i], pts[i + 1], col, w)


## Gravy splat decal (4 frames from tools/gen_boss.py), fades out.
class GravySplat extends Sprite2D:
	const SHEET := preload("res://assets/boss/gravy_splat_48.png")
	var _t := 0.0

	func _ready() -> void:
		add_to_group("gravy_splat")
		texture = SHEET
		hframes = 4
		frame = 0
		position.y -= 2

	func _process(delta: float) -> void:
		_t += delta
		frame = mini(int(_t / 0.07), 2) if _t < 0.9 else 3
		if _t > 0.9:
			modulate.a = clampf(1.0 - (_t - 0.9) / 0.6, 0.0, 1.0)
		if _t > 1.5:
			queue_free()
