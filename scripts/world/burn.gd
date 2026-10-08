class_name Burn
extends Node2D
## Build 013: fire on a creature (FIRE WHIP). Child node named "Burn".
## Ticks 1 hit every FIRE_TICK for FIRE_DURATION, and ignites other burnable
## creatures (sheep, possessed humans, Karens) it touches. Normal silly humans
## and the rancher never burn.

var time_left: float = LevelConfig.FIRE_DURATION
var _tick: float = LevelConfig.FIRE_TICK
var _t: float = 0.0


static func can_burn(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if "exploding" in node and node.exploding:
		return false
	if node.is_in_group("sheep"):
		return true
	return node.is_in_group("possessed") and "possessed" in node and node.possessed


static func is_burning(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.get_node_or_null("Burn") != null


## Set `node` on fire (or refresh its fire). Returns true if it is burning now.
static func ignite(node: Node) -> bool:
	# Build 015: the boss handles fire itself (one delayed burn tick).
	if node != null and is_instance_valid(node) and node.has_method("boss_ignite"):
		return node.boss_ignite()
	if not can_burn(node):
		return false
	var b := node.get_node_or_null("Burn") as Burn
	if b != null:
		b.time_left = LevelConfig.FIRE_DURATION
		return true
	b = Burn.new()
	b.name = "Burn"
	node.add_child(b)
	if node.has_signal("ignited"):
		node.emit_signal("ignited")
	return true


func _ready() -> void:
	add_to_group("burning")
	z_index = 6


func _physics_process(delta: float) -> void:
	var host := get_parent()
	if host == null or not can_burn(host):
		queue_free()
		return
	_t += delta
	time_left -= delta
	if _t >= LevelConfig.FIRE_SPREAD_DELAY:
		_spread(host)
	_tick -= delta
	if _tick <= 0.0:
		_tick = LevelConfig.FIRE_TICK
		if host.has_method("fire_damage"):
			host.fire_damage()
			if not is_instance_valid(host) or not can_burn(host):
				return
	if time_left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _spread(host: Node) -> void:
	var p: Vector2 = (host as Node2D).global_position
	for group in ["possessed", "sheep"]:
		for other in get_tree().get_nodes_in_group(group):
			if other == host or is_burning(other) or not can_burn(other):
				continue
			if p.distance_to((other as Node2D).global_position) <= LevelConfig.FIRE_SPREAD_RADIUS:
				Burn.ignite(other)


func _draw() -> void:
	# Flickering pixel flames over the creature.
	for i in 5:
		var ph := _t * 9.0 + i * 1.7
		var x := -12.0 + i * 6.0
		var h := 10.0 + 6.0 * absf(sin(ph))
		var base := Vector2(x, -6.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-4, 0), base + Vector2(0, -h - 10), base + Vector2(4, 0)]), Color(1.0, 0.35, 0.05, 0.85))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-2, 0), base + Vector2(0, -h - 2), base + Vector2(2, 0)]), Color(1.0, 0.9, 0.3, 0.95))
	draw_circle(Vector2(0, -14), 16.0, Color(1.0, 0.5, 0.1, 0.18))
