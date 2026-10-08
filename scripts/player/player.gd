class_name Player
extends CharacterBody2D

signal health_changed(health: int, maximum: int)
signal died

@onready var sprite: AnimatedSprite2D = $Sprite
@export var movement_speed: float = 260.0
@export var maximum_health: int = 5

var health: int
var knockback_velocity := Vector2.ZERO
var _dead: bool = false
var facing: Vector2 = Vector2.RIGHT
## Build 014: while filming with the MSM Cam the body (4-way sprite) turns to
## the camera's aim (mouse on PC, facing on touch). ZERO = follow movement.
var aim_override: Vector2 = Vector2.ZERO

## Build 010: facing tracks movement in 8 directions (snapped to 45°). Touch
## whip/grab aim along it. Only updated when input is stronger than this, so
## letting go of the joystick never flicks the facing.
const FACING_MIN_INPUT := 0.25
const FACING_8: Array[Vector2] = [
	Vector2(1.0, 0.0),
	Vector2(0.70710678, 0.70710678),
	Vector2(0.0, 1.0),
	Vector2(-0.70710678, 0.70710678),
	Vector2(-1.0, 0.0),
	Vector2(-0.70710678, -0.70710678),
	Vector2(0.0, -1.0),
	Vector2(0.70710678, -0.70710678),
]

## Build 010: while > 0 the rancher has no body for sheep/humans (whip grab).
var _grab_ghost_timer: float = 0.0
var _ghost_active: bool = false
var _saved_layer: int = 0
var _saved_mask: int = 0
## Physics layer bits (project layer_names): 2 Player, 3 Humans, 4 Sheep.
const LAYER_BIT_PLAYER := 1 << 1
const LAYER_BITS_CREATURES := (1 << 2) | (1 << 3)


func _ready() -> void:
	health = maximum_health
	add_to_group("player")
	health_changed.emit(health, maximum_health)


func _physics_process(delta: float) -> void:
	if _ghost_active:
		_grab_ghost_timer -= delta
		if _grab_ghost_timer <= 0.0:
			end_grab_ghost()
	if _dead:
		return

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	if input_vector == Vector2.ZERO:
		input_vector = TouchInput.move_vector
	update_animation(input_vector)
	# Compress vertical movement slightly for an isometric feel.
	var iso_vector := Vector2(
		input_vector.x,
		input_vector.y * 0.60
	)

	if iso_vector.length() > 1.0:
		iso_vector = iso_vector.normalized()

	velocity = iso_vector * movement_speed

	if knockback_velocity.length() > 5.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(
			Vector2.ZERO,
			delta * 7.0
		)

	move_and_slide()


func update_animation(input_vector: Vector2) -> void:
	if aim_override.length_squared() > 0.0001:
		_set_dir_animation(aim_override)
	if input_vector == Vector2.ZERO:
		sprite.pause()
		return

	sprite.play()

	# Sprite art is 4-directional (unchanged); facing is 8-way.
	if aim_override.length_squared() <= 0.0001:
		_set_dir_animation(input_vector)

	if input_vector.length() >= FACING_MIN_INPUT:
		facing = snap_8(input_vector)


func _set_dir_animation(v: Vector2) -> void:
	var anim := ""
	if abs(v.x) > abs(v.y):
		anim = "right" if v.x > 0.0 else "left"
	else:
		anim = "down" if v.y > 0.0 else "up"
	if sprite.animation != anim:
		sprite.animation = anim


## Nearest of the 8 compass directions (unit length).
static func snap_8(v: Vector2) -> Vector2:
	if v.length_squared() < 0.000001:
		return Vector2.RIGHT
	var idx := wrapi(roundi(v.angle() / (PI / 4.0)), 0, 8)
	return FACING_8[idx]


## Build 010 directional throw: the direction the player is actively steering,
## or ZERO when there is no movement input. Keyboard (WASD) wins, normalized;
## otherwise the touch joystick, as the 8-way facing.
func get_steer_direction() -> Vector2:
	if _dead:
		return Vector2.ZERO
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if kb.length_squared() > 0.0001:
		return kb.normalized()
	if TouchInput.move_vector.length() >= FACING_MIN_INPUT:
		return facing
	return Vector2.ZERO


## Build 010: drop the rancher's body for sheep/humans for `duration` seconds
## (whip grab). World walls still collide. Re-calling extends the window.
func begin_grab_ghost(duration: float) -> void:
	if _dead:
		return
	if not _ghost_active:
		_saved_layer = collision_layer
		_saved_mask = collision_mask
		_ghost_active = true
	collision_layer = _saved_layer & ~LAYER_BIT_PLAYER
	collision_mask = _saved_mask & ~LAYER_BITS_CREATURES
	_grab_ghost_timer = maxf(_grab_ghost_timer, duration)


func end_grab_ghost() -> void:
	if not _ghost_active:
		return
	_ghost_active = false
	_grab_ghost_timer = 0.0
	collision_layer = _saved_layer
	collision_mask = _saved_mask


func is_grab_ghost() -> bool:
	return _ghost_active


func _exit_tree() -> void:
	end_grab_ghost()


func take_damage(amount: int, source_position := Vector2.ZERO) -> void:
	if _dead:
		return
	# Sheep/possessed bites are distance-based, not collision-based: during the
	# grab window the rancher has no body, so contact bites are ignored too.
	if _ghost_active:
		return

	health -= amount
	Sfx.play(self, "hurt", -6.0)

	if source_position != Vector2.ZERO:
		var direction := source_position.direction_to(global_position)
		knockback_velocity = direction * 300.0

	health_changed.emit(health, maximum_health)

	if health <= 0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	end_grab_ghost()
	velocity = Vector2.ZERO
	died.emit()
