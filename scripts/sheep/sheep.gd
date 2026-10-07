class_name KillerSheep
extends CharacterBody2D

## Build 012: emitted once when the sheep starts exploding (its only death path).
signal killed
## Build 013: set on fire (FIRE WHIP / spreading fire).
signal ignited

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var explosion_sprite: AnimatedSprite2D = $Explosion
@export var movement_speed: float = 105.0
@export var interest_speed: float = 55.0
@export var roam_speed: float = 60.0
## Full chase / attack engagement (~5 tiles at 32px).
@export var attention_range: float = 160.0
## Soft interest: slow approach; beyond this → roam (~8 tiles at 32px).
@export var interest_range: float = 256.0
@export var attack_distance: float = 35.0
@export var attack_cooldown: float = 1.0
@export var direction_change_time: float = 2.2
## Proximity for thrown sheep–sheep (and sheep–possessed) mutual kill.
@export var throw_collide_radius: float = 40.0
@export var throw_duration: float = 0.75

var external_velocity := Vector2.ZERO
var attack_timer := 0.0
var target: Node2D = null
var exploding := false
var roam_direction := Vector2.ZERO
var direction_timer := 0.0
## "roam" | "interest" | "chase"
var _mode: String = "roam"
var _throw_timer: float = 0.0
var _thrown: bool = false
## Build 014: camcorder SWING stagger (pushed back, can't move or bite).
var stagger_timer: float = 0.0


## Build 010: speed multiplier applied in _ready from the current level
## (LevelConfig.sheep_speed_mult; level 1 = 1.0).
var level_speed_mult: float = 1.0


func _ready() -> void:
	add_to_group("sheep")
	add_to_group("whippable")
	apply_level_speed(_current_level())
	_pick_roam_direction()


func _current_level() -> int:
	var progress := get_node_or_null("/root/GameProgress")
	if progress != null and "current_level" in progress:
		return int(progress.current_level)
	return 1


func apply_level_speed(level: int) -> void:
	# Undo a previous multiplier so this is safe to call more than once.
	var m := LevelConfig.sheep_speed_mult(level)
	movement_speed = movement_speed / level_speed_mult * m
	interest_speed = interest_speed / level_speed_mult * m
	roam_speed = roam_speed / level_speed_mult * m
	level_speed_mult = m


func _physics_process(delta: float) -> void:
	if exploding:
		return

	if _throw_timer > 0.0:
		_throw_timer -= delta
		if _throw_timer <= 0.0:
			_thrown = false

	if attack_timer > 0.0:
		attack_timer -= delta

	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity = external_velocity
		external_velocity = external_velocity.lerp(Vector2.ZERO, delta * 3.0)
		move_and_slide()
		_soft_clamp_interior()
		return

	direction_timer -= delta
	if direction_timer <= 0.0:
		_pick_roam_direction()

	_update_target_and_mode()

	match _mode:
		"chase":
			_move_toward(target, movement_speed)
		"interest":
			_move_toward(target, interest_speed)
		_:
			_roam()

	if external_velocity.length() > 3.0:
		external_velocity = external_velocity.lerp(Vector2.ZERO, delta * 3.0)

	update_animation(velocity)
	move_and_slide()
	_soft_clamp_interior()
	if _thrown or _throw_timer > 0.0:
		_check_thrown_collisions()
	check_attack()


func was_thrown_recently() -> bool:
	return _throw_timer > 0.0 or _thrown


func _soft_clamp_interior() -> void:
	var root := get_tree().get_first_node_in_group("level_controller")
	if root == null:
		return
	if root.has_method("can_rescue_humans") and not root.can_rescue_humans():
		return
	var layer = root.get_node_or_null("Ground")
	if layer == null or not layer.has_method("is_interior_local"):
		return
	var ground_local: Vector2 = layer.to_local(global_position)
	var cell: Vector2i = layer.local_pos_to_local_cell(ground_local)
	if not layer.is_interior_local(cell, 1):
		global_position = layer.to_global(layer.clamp_to_interior(ground_local, 2))


func _nearest_in_group(group_name: String, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist := max_range
	for candidate in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_dist:
			best_dist = distance
			best = candidate as Node2D
	return best


func _nearest_in_band(group_name: String, min_range: float, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist := max_range
	for candidate in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance > min_range and distance < best_dist:
			best_dist = distance
			best = candidate as Node2D
	return best


func _update_target_and_mode() -> void:
	# Prefer normal silly humans over player. Do not chase possessed as victims.
	var human_attn := _nearest_in_group("humans", attention_range)
	if human_attn != null:
		target = human_attn
		_mode = "chase"
		return

	var player_attn := _nearest_in_group("player", attention_range)
	if player_attn != null:
		target = player_attn
		_mode = "chase"
		return

	# Soft interest band (attention_range .. interest_range]: prefer humans.
	var human_interest := _nearest_in_band("humans", attention_range, interest_range)
	if human_interest != null:
		target = human_interest
		_mode = "interest"
		return

	var player_interest := _nearest_in_band("player", attention_range, interest_range)
	if player_interest != null:
		target = player_interest
		_mode = "interest"
		return

	target = null
	_mode = "roam"


func _move_toward(node: Node2D, speed: float) -> void:
	if node == null:
		_roam()
		return
	var direction := global_position.direction_to(node.global_position)
	var chase_velocity := direction * speed
	chase_velocity.y *= 0.60
	velocity = chase_velocity + external_velocity


func _roam() -> void:
	var movement := roam_direction * roam_speed
	movement.y *= 0.60
	velocity = movement + external_velocity


func _pick_roam_direction() -> void:
	direction_timer = randf_range(
		direction_change_time * 0.5,
		direction_change_time * 1.5
	)
	roam_direction = Vector2.from_angle(randf() * TAU)


func update_animation(movement: Vector2) -> void:
	if exploding:
		return

	if movement.length() < 2.0:
		sprite.pause()
		return

	sprite.play()

	if abs(movement.x) > abs(movement.y):
		if movement.x > 0.0:
			sprite.animation = "right"
		else:
			sprite.animation = "left"
	else:
		if movement.y > 0.0:
			sprite.animation = "down"
		else:
			sprite.animation = "up"


func check_attack() -> void:
	# Only attack while in full attention (chase) engagement.
	if target == null or attack_timer > 0.0 or _mode != "chase":
		return

	var distance := global_position.distance_to(target.global_position)
	if distance > attack_distance:
		return

	attack_timer = attack_cooldown

	# Humans take multi-hit damage → possession at 0; player keeps take_damage.
	if target.has_method("take_damage"):
		target.take_damage(1, global_position)


func receive_whip(_source_position: Vector2, _force: float) -> void:
	explode()


## Build 014: camcorder SWING - shove (no damage) and stagger.
func receive_swing(source_position: Vector2, push: float, stagger: float) -> void:
	if exploding:
		return
	var dir := source_position.direction_to(global_position)
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	external_velocity = dir * push
	stagger_timer = maxf(stagger_timer, stagger)


## Build 013: a burn tick (scripts/world/burn.gd) finishes a sheep off.
func fire_damage() -> void:
	explode()


## Grab/throw: fling without exploding. Flight enables sheep–sheep double death.
func receive_throw(throw_direction: Vector2, force: float) -> void:
	if exploding:
		return
	var direction := throw_direction
	if direction.length_squared() < 0.0001:
		direction = Vector2.LEFT
	else:
		direction = direction.normalized()
	external_velocity += direction * force
	_throw_timer = throw_duration
	_thrown = true


func _check_thrown_collisions() -> void:
	if exploding:
		return
	# Sheep–sheep mutual kill (primary rule).
	for candidate in get_tree().get_nodes_in_group("sheep"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if "exploding" in candidate and candidate.exploding:
			continue
		if global_position.distance_to(candidate.global_position) > throw_collide_radius:
			continue
		if candidate.has_method("explode"):
			candidate.explode()
		explode()
		return
	# Nice-to-have: sheep–possessed mutual destroy.
	for candidate in get_tree().get_nodes_in_group("possessed"):
		if not is_instance_valid(candidate):
			continue
		if "exploding" in candidate and candidate.exploding:
			continue
		if global_position.distance_to(candidate.global_position) > throw_collide_radius:
			continue
		if candidate.has_method("explode"):
			candidate.explode()
		explode()
		return


func explode() -> void:
	if exploding:
		return

	killed.emit()
	exploding = true
	_thrown = false
	_throw_timer = 0.0
	velocity = Vector2.ZERO
	external_velocity = Vector2.ZERO
	target = null

	remove_from_group("whippable")
	remove_from_group("sheep")

	collision_layer = 0
	collision_mask = 0

	var collision_shape := get_node_or_null("CollisionShape2D")
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	sprite.visible = false
	explosion_sprite.visible = true
	explosion_sprite.play("explode")

	await explosion_sprite.animation_finished
	queue_free()
