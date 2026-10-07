class_name InfectionAlarm
extends Control

## Tracks silly humans with health < maximum_health.
## Draws pulsing feet rings (canvas space) + edge chevrons when off-screen.

@export var pulse_speed: float = 4.0
@export var ring_radius: float = 22.0
@export var edge_margin: float = 28.0
@export var alarm_color := Color(1.0, 0.15, 0.55, 0.95)

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var viewport_size := get_viewport_rect().size
	var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * pulse_speed * TAU * 0.25))

	for node in tree.get_nodes_in_group("humans"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		if not ("health" in node and "maximum_health" in node):
			continue
		if node.health >= node.maximum_health:
			continue
		# Skip if somehow possessed/rescued but still listed.
		if "possessed" in node and node.possessed:
			continue
		if "rescued" in node and node.rescued:
			continue

		var human := node as Node2D
		var canvas_pos: Vector2 = human.get_global_transform_with_canvas().origin
		var on_screen := (
			canvas_pos.x >= -8.0
			and canvas_pos.y >= -8.0
			and canvas_pos.x <= viewport_size.x + 8.0
			and canvas_pos.y <= viewport_size.y + 8.0
		)

		var col := Color(alarm_color.r, alarm_color.g, alarm_color.b, alarm_color.a * pulse)

		if on_screen:
			# Pulsing ring at feet (slightly below sprite origin).
			var feet := canvas_pos + Vector2(0, 10)
			var r := ring_radius * (0.85 + 0.15 * pulse)
			draw_arc(feet, r, 0.0, TAU, 40, col, 3.0, true)
			draw_arc(feet, r * 0.65, 0.0, TAU, 28, Color(col.r, col.g, col.b, col.a * 0.45), 1.5, true)
		else:
			_draw_edge_arrow(canvas_pos, viewport_size, col)


func _draw_edge_arrow(world_canvas: Vector2, viewport_size: Vector2, col: Color) -> void:
	var center := viewport_size * 0.5
	var dir := (world_canvas - center)
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	# Clamp to screen edge inset.
	var edge := _intersect_rect_edge(center, dir, viewport_size, edge_margin)
	var tip := edge
	var base := tip - dir * 18.0
	var perp := Vector2(-dir.y, dir.x) * 9.0
	var points := PackedVector2Array([tip, base + perp, base - perp])
	draw_colored_polygon(points, col)
	# Small outline for readability
	draw_polyline(
		PackedVector2Array([tip, base + perp, base - perp, tip]),
		Color(0.1, 0.0, 0.05, col.a),
		1.5,
		true
	)


func _intersect_rect_edge(origin: Vector2, dir: Vector2, size: Vector2, margin: float) -> Vector2:
	var min_x := margin
	var max_x := size.x - margin
	var min_y := margin
	var max_y := size.y - margin
	var t := INF
	if abs(dir.x) > 0.0001:
		var tx := (max_x - origin.x) / dir.x if dir.x > 0.0 else (min_x - origin.x) / dir.x
		if tx > 0.0:
			t = minf(t, tx)
	if abs(dir.y) > 0.0001:
		var ty := (max_y - origin.y) / dir.y if dir.y > 0.0 else (min_y - origin.y) / dir.y
		if ty > 0.0:
			t = minf(t, ty)
	if t == INF:
		return origin
	var p := origin + dir * t
	p.x = clampf(p.x, min_x, max_x)
	p.y = clampf(p.y, min_y, max_y)
	return p
