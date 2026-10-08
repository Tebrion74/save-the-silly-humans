class_name WoolBurst
extends Node2D
## Build 016: a quick pop effect for bonus / programmed / micro sheep: the
## shared explosion flipbook plus a ring of wool tufts (or circuit sparks)
## flying out and fading. Frees itself.

const EXPLOSION := preload("res://assets/spriteframes/explosion_frames.tres")

## Tuft colour (white wool; steel/cyan for programmed; magenta for micro).
var tint := Color(1, 1, 1)
var spark := Color(1.0, 0.95, 0.6)
var size_mult := 1.0
var tufts := 9
var _parts: Array = []
var _t := 0.0
const LIFE := 0.55


static func spawn(parent: Node, at: Vector2, tint_col: Color, spark_col: Color, scale_mult: float = 1.0, with_flipbook: bool = true) -> WoolBurst:
	var b := WoolBurst.new()
	b.tint = tint_col
	b.spark = spark_col
	b.size_mult = scale_mult
	parent.add_child(b)
	b.global_position = at
	if with_flipbook:
		var ex := AnimatedSprite2D.new()
		ex.sprite_frames = EXPLOSION
		ex.scale = Vector2.ONE * scale_mult
		b.add_child(ex)
		ex.play("explode")
	return b


func _ready() -> void:
	z_index = 40
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in tufts:
		var a := TAU * i / tufts + rng.randf_range(-0.25, 0.25)
		var sp := rng.randf_range(90.0, 170.0) * size_mult
		_parts.append([Vector2.from_angle(a) * sp, rng.randf_range(4.0, 7.0) * size_mult, i % 3 == 0])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var ease_k := 1.0 - pow(1.0 - k, 2.0)
	for p in _parts:
		var v: Vector2 = p[0]
		var pos := v * ease_k * 0.55 + Vector2(0, -8.0 * size_mult + 30.0 * k * k)
		var r: float = float(p[1]) * (1.0 - 0.5 * k)
		var col: Color = spark if p[2] else tint
		col.a = 1.0 - k
		draw_circle(pos, r + 1.5, Color(0.06, 0.03, 0.08, col.a * 0.8))
		draw_circle(pos, r, col)
	# bright flash ring at the start
	if k < 0.35:
		var rr := (10.0 + 40.0 * k / 0.35) * size_mult
		draw_arc(Vector2(0, -6), rr, 0, TAU, 28, Color(1, 1, 0.9, 1.0 - k / 0.35), 3.0)
