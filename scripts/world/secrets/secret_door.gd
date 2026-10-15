class_name SecretDoor
extends StaticBody2D
## Build 024: the one breakable tile of a hidden chamber. Looks like the wall
## rocks around it; "subtle" doors carry a faint tint + hairline cracks.
## Broken by whip cracks along the lash (2 hits; 1 with the fire whip or a
## shockwave). Works with mouse and touch aim (the shared crack path calls
## SecretDoor.on_crack for every node in the "secret_doors" group).

signal broken

const HITS := 2
const LASH_RADIUS := 26.0
const TIP_RADIUS := 34.0
const SUBTLE_TINT := Color(1.07, 0.98, 0.86)

var spec: Dictionary = {}
var ground = null
var atlas := Vector2i(9, 4)
var hits := 0
var _shake := 0.0
var _sprite: Sprite2D
var _broken := false


func _ready() -> void:
	add_to_group("secret_doors")
	collision_layer = 1
	collision_mask = 0
	z_index = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(32, 32)
	cs.shape = rs
	add_child(cs)
	_sprite = Sprite2D.new()
	var src: TileSetAtlasSource = ground.tile_set.get_source(5) if ground != null else null
	if src != null:
		var at := AtlasTexture.new()
		at.atlas = src.texture
		at.region = Rect2(src.get_tile_texture_region(atlas))
		_sprite.texture = at
		var td := src.get_tile_data(atlas, 0)
		if td != null:
			_sprite.offset = -Vector2(td.texture_origin)
	if subtle():
		_sprite.modulate = SUBTLE_TINT
	add_child(_sprite)


func subtle() -> bool:
	return bool(spec.get("subtle", false))


## Called after every whip crack (PC and touch) with the lash segment.
static func on_crack(tree: SceneTree, from: Vector2, tip: Vector2, strong: bool) -> void:
	for d in tree.get_nodes_in_group("secret_doors"):
		if is_instance_valid(d) and not d._broken:
			d._try_hit(from, tip, strong)


func _try_hit(from: Vector2, tip: Vector2, strong: bool) -> void:
	var p := global_position
	var ab := tip - from
	var t := clampf((p - from).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	if p.distance_to(from + ab * t) > LASH_RADIUS and p.distance_to(tip) > TIP_RADIUS:
		return
	hit(2 if strong else 1)


func hit(n: int = 1) -> void:
	if _broken:
		return
	hits += n
	_shake = 0.25
	if hits >= HITS:
		_break()
	else:
		Sfx.play(self, "secret_hit", -5.0)
		_spawn_debris(5)
		queue_redraw()


func _break() -> void:
	_broken = true
	remove_from_group("secret_doors")
	collision_layer = 0
	Sfx.play(self, "secret_break", -3.0)
	_spawn_debris(16)
	broken.emit()
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.25, 0.6), 0.08)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _spawn_debris(n: int) -> void:
	var d := Debris.new()
	d.count = n
	d.base = Color(0.55, 0.5, 0.45) if not String(spec.get("theme", "")) in ["pnw", "bavaria"] else Color(0.45, 0.5, 0.4)
	d.position = global_position
	get_parent().add_child(d)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		_sprite.position = Vector2(randf_range(-2, 2), randf_range(-1, 1)) if _shake > 0.0 else Vector2.ZERO
	if subtle() or hits > 0:
		queue_redraw()


func _draw() -> void:
	# hairline cracks: faint on subtle doors, plain doors only show them once hit
	if not subtle() and hits == 0:
		return
	var a := 0.28 if hits == 0 else 0.75
	var c := Color(0.12, 0.09, 0.08, a)
	draw_polyline(PackedVector2Array([Vector2(-5, -11), Vector2(-1, -6), Vector2(-3, -1), Vector2(2, 4)]), c, 1.0)
	draw_polyline(PackedVector2Array([Vector2(-1, -6), Vector2(4, -8)]), c, 1.0)
	if hits > 0:
		draw_polyline(PackedVector2Array([Vector2(2, 4), Vector2(6, 2), Vector2(9, 6)]), c, 1.5)


## Stone chips flying out and falling (drawn, no assets).
class Debris extends Node2D:
	var count := 10
	var base := Color(0.55, 0.5, 0.45)
	var t := 0.0
	var parts: Array = []
	func _ready() -> void:
		z_index = 5
		for i in count:
			parts.append([Vector2.ZERO, Vector2.from_angle(randf() * TAU) * randf_range(40, 130) + Vector2(0, -60), randf_range(2, 4)])
	func _process(d: float) -> void:
		t += d
		for p in parts:
			p[1].y += 260.0 * d
			p[0] += p[1] * d
		if t > 0.7:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var a := clampf(1.0 - t / 0.7, 0, 1)
		for p in parts:
			draw_rect(Rect2(p[0], Vector2(p[2], p[2])), Color(base.r, base.g, base.b, a))
