class_name SafeZone
extends Area2D

signal human_rescued(human: Node)

var rescued_count := 0


func _ready() -> void:
	add_to_group("safe_zones")
	monitoring = false
	monitorable = true
	body_entered.connect(_on_body_entered)
	queue_redraw()


func set_rescue_enabled(enabled: bool) -> void:
	monitoring = enabled


func _on_body_entered(body: Node2D) -> void:
	if not monitoring:
		return
	var level = get_tree().get_first_node_in_group("level_controller")
	if level == null or not level.has_method("can_rescue_humans") or not level.can_rescue_humans():
		return
	# Ignore stale overlaps: body must actually be near this zone now.
	if global_position.distance_to(body.global_position) > 120.0:
		return

	# Possessed: only rescue when thrown into the zone (no casual walk-in).
	if _is_possessed(body):
		if not _was_thrown(body):
			return
		if not body.has_method("rescue_from_possession"):
			return
		rescued_count += 1
		human_rescued.emit(body)
		body.rescue_from_possession()
		return

	# Normal silly humans.
	if not body.is_in_group("humans"):
		return
	if not body.has_method("rescue"):
		return
	rescued_count += 1
	human_rescued.emit(body)
	body.rescue()


func _is_possessed(body: Node) -> bool:
	if body.is_in_group("possessed"):
		return true
	if "possessed" in body and body.possessed:
		return true
	return false


func _was_thrown(body: Node) -> bool:
	if body.has_method("was_thrown_recently"):
		return body.was_thrown_recently()
	if "_throw_timer" in body and body._throw_timer > 0.0:
		return true
	if "_thrown" in body and body._thrown:
		return true
	return false


func _draw() -> void:
	draw_circle(Vector2.ZERO, 95, Color(0.15, 0.75, 0.35, 0.17))
	draw_arc(Vector2.ZERO, 95, 0, TAU, 64, Color(0.25, 1.0, 0.45), 5)
	draw_arc(Vector2.ZERO, 75, 0, TAU, 64, Color(0.25, 1.0, 0.45, 0.4), 2)
