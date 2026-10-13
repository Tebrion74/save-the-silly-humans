class_name StarSave
extends Node2D
## Build 020 INVINCIBLE: a creature whipped during star power is SAVED.
## This child node takes over its host (the host's own _physics_process is
## switched off): it bolts away from the rancher for STAR_FLEE_SECONDS, then
## runs straight to the nearest safe zone, ghosting through obstacles. On
## arrival the level controller credits it (see level_controller.star_arrived).
## The host leaves the whippable / sheep / possessed / cantifa / karens groups
## at once, so nothing can hurt, burn or re-target it on the way.

const LEAVE_GROUPS := ["whippable", "sheep", "possessed", "cantifa", "karens", "cantifa_target"]

var kind: String = ""           ## "human", "possessed", "cantifa", "sheep"
var flee_t: float = LevelConfig.STAR_FLEE_SECONDS
var _t: float = 0.0
var _away := Vector2.RIGHT
var _done := false


## Turn `body` into a star-saved runner. Returns the kind ("" = can't be saved).
static func save(body: Node2D, from_pos: Vector2) -> String:
	var k := kind_of(body)
	if k == "":
		return ""
	var s := StarSave.new()
	s.name = "StarSave"
	s.kind = k
	s._away = from_pos.direction_to(body.global_position)
	if s._away.length_squared() < 0.0001:
		s._away = Vector2.RIGHT
	body.set_meta("star_saved", true)
	for g in LEAVE_GROUPS:
		if body.is_in_group(g):
			body.remove_from_group(g)
	body.add_to_group("star_saved")
	body.set_physics_process(false)
	if body is CollisionObject2D:
		(body as CollisionObject2D).collision_layer = 0
		(body as CollisionObject2D).collision_mask = 0
	var burn := body.get_node_or_null("Burn")
	if burn != null:
		burn.queue_free()
	body.add_child(s)
	return k


## What a whip hit on `body` would save during star power ("" = nothing).
static func kind_of(body: Node) -> String:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return ""
	if body.has_meta("star_saved") or body.has_method("boss_ignite"):
		return ""
	if "exploding" in body and body.exploding:
		return ""
	if "rescued" in body and body.rescued:
		return ""
	if "_dead" in body and body._dead:
		return ""
	if body.is_in_group("cantifa"):
		return "cantifa"
	if body.is_in_group("sheep"):
		return "sheep"
	if body.is_in_group("possessed") or ("possessed" in body and body.possessed and body.is_in_group("whippable")):
		return "possessed"
	if body.is_in_group("humans"):
		return "human"
	return ""


func _ready() -> void:
	z_index = 7
	var host := get_parent()
	var spr = host.get_node_or_null("Sprite") if host != null else null
	if spr is CanvasItem:
		(spr as CanvasItem).modulate = Color(0.75, 1.6, 0.8)
	if spr is AnimatedSprite2D:
		(spr as AnimatedSprite2D).speed_scale = 2.0


func _physics_process(delta: float) -> void:
	var host := get_parent() as CharacterBody2D
	if host == null or _done:
		return
	_t += delta
	var level := get_tree().get_first_node_in_group("level_controller")
	if level != null and level.has_method("is_gameplay_frozen") and level.is_gameplay_frozen():
		return
	var v := Vector2.ZERO
	var zone := _nearest_zone(host)
	if flee_t > 0.0:
		flee_t -= delta
		v = _away * LevelConfig.STAR_FLEE_SPEED
	elif zone != null:
		var d := host.global_position.distance_to(zone.global_position)
		if d < 60.0:
			_done = true
			if level != null and level.has_method("star_arrived"):
				level.star_arrived(host, kind)
			else:
				host.queue_free()
			return
		v = host.global_position.direction_to(zone.global_position) * LevelConfig.STAR_RUN_SPEED
	else:
		v = _away * LevelConfig.STAR_RUN_SPEED
	host.global_position += v * delta
	if host.has_method("update_animation"):
		host.update_animation(v)
	queue_redraw()


func _nearest_zone(host: Node2D) -> Node2D:
	var best: Node2D = null
	var bd := INF
	for z in get_tree().get_nodes_in_group("safe_zones"):
		if z is Node2D:
			var d := host.global_position.distance_to((z as Node2D).global_position)
			if d < bd:
				bd = d
				best = z
	return best


func _draw() -> void:
	# little orbiting stars + a green ring
	draw_arc(Vector2(0, -6), 22.0, 0, TAU, 24, Color(0.4, 1.0, 0.5, 0.7), 3.0)
	for i in 3:
		var a := _t * 6.0 + TAU * i / 3.0
		var p := Vector2(cos(a) * 20.0, -30.0 + sin(a) * 7.0)
		var c := Color.from_hsv(fmod(_t + i * 0.33, 1.0), 0.6, 1.0)
		draw_rect(Rect2(p - Vector2(3, 1), Vector2(7, 3)), c)
		draw_rect(Rect2(p - Vector2(1, 3), Vector2(3, 7)), c)
