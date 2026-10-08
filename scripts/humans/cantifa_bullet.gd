class_name CantifaBullet
extends Node2D
## Build 017: a Cantifa rifle round. Straight line, hits only the rancher,
## and shares the boss mercy window so several rifles can't drain every heart
## in one moment. Humans, sheep and other Cantifa are ignored.

var direction := Vector2.RIGHT
var speed := LevelConfig.CANTIFA_BULLET_SPEED
var travelled := 0.0
var max_dist := 420.0

static var next_hit_msec: int = 0


static func launch(parent: Node, at: Vector2, dir: Vector2) -> CantifaBullet:
	var b := CantifaBullet.new()
	b.direction = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	parent.add_child(b)
	b.global_position = at
	return b


func _ready() -> void:
	add_to_group("cantifa_bullets")
	z_index = 6


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	global_position += step
	travelled += step.length()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) <= LevelConfig.CANTIFA_BULLET_RADIUS:
		_hit_player(player)
		return
	if travelled >= max_dist:
		queue_free()
	queue_redraw()


func _hit_player(player: Node) -> void:
	var now := Time.get_ticks_msec()
	if now < next_hit_msec:
		queue_free()
		return
	if not player.has_method("take_damage"):
		queue_free()
		return
	var before: int = player.health if "health" in player else 0
	player.take_damage(1, global_position)
	if "health" in player and player.health < before:
		next_hit_msec = now + int(LevelConfig.BOSS_PLAYER_HIT_COOLDOWN * 1000.0)
		var lvl := get_tree().get_first_node_in_group("level_controller")
		if lvl != null and lvl.has_method("spawn_score_popup"):
			lvl.spawn_score_popup("BANG!", (player as Node2D).global_position + Vector2(0, -18), Color(1.0, 0.85, 0.3), 2)
	queue_free()


func _draw() -> void:
	draw_line(-direction * 8.0, direction * 48.0, Color(1.0, 0.95, 0.35, 1.0), 5.0)
	draw_circle(direction * 8.0, 4.0, Color(1.0, 0.85, 0.25))
