class_name SillyHuman
extends CharacterBody2D

signal was_rescued
signal was_killed
signal was_possessed
signal was_possession_saved
## Build 012: emitted when explode() starts (scoring / impossible-target check).
## `was_possessed_then` is true for a possessed human (the only normal case).
signal was_destroyed(was_possessed_then: bool)
signal health_changed(health: int, maximum: int)
## Build 013: this possessed human just turned gregarious (a "Karen").
signal became_karen
## Build 013: set on fire (FIRE WHIP / spreading fire).
signal ignited

@onready var sprite: AnimatedSprite2D = $Sprite
@export var maximum_health: int = 5
@export var wander_speed: float = 70.0
@export var flee_speed: float = 145.0
## ~5 tiles at 32px; flee sheep within this distance.
@export var flee_range: float = 160.0
## ~9 tiles; steer away from green safe zones (too dumb to enter on purpose).
@export var avoid_safe_range: float = 288.0
@export var avoid_safe_speed: float = 100.0
@export var direction_change_time: float = 2.0
## Chance each direction tick to pause briefly instead of moving.
@export var pause_chance: float = 0.18
@export var pause_time: float = 0.45

## Possessed hunter bands (match killer sheep).
@export var hunt_speed: float = 105.0
@export var hunt_interest_speed: float = 55.0
@export var hunt_roam_speed: float = 60.0
@export var attention_range: float = 160.0
@export var interest_range: float = 256.0
@export var attack_distance: float = 35.0
@export var attack_cooldown: float = 1.0
## How long throw momentum overrides safe-zone avoidance / enables rescue & collisions.
@export var throw_duration: float = 0.75
## Proximity for thrown possessed–sheep / possessed–possessed mutual kill.
@export var throw_collide_radius: float = 40.0

const POSSESSED_MODULATE := Color(0.85, 0.25, 1.0, 1.0)
const FLASH_MODULATE := Color(1.0, 0.35, 0.45, 1.0)
const NORMAL_MODULATE := Color(1, 1, 1, 1)
## Karens show their own blue-hair / pink-shirt sprite sheet, barely tinted.
const KAREN_MODULATE := Color(1.0, 0.94, 1.0, 1.0)
const KAREN_FRAMES_PATH := "res://assets/spriteframes/karen_frames.tres"

## Build 013 Karen state (see LevelConfig KAREN_*).
var karen := false
var karen_hp: int = LevelConfig.KAREN_HP
var _karen_bite_timer: float = 0.0
## Shared by all Karens: the mob may hurt the rancher at most once per
## KAREN_MOB_HIT_INTERVAL (msec timestamp of the next allowed hit).
static var mob_hit_ready_ms: int = 0
var _level_cache: int = -1

var health: int = 5
var wander_direction := Vector2.ZERO
var direction_timer := 0.0
var external_velocity := Vector2.ZERO
var knockback_velocity := Vector2.ZERO
var rescued := false
var possessed := false
var _dead: bool = false
var _pausing: bool = false
var _noise_offset: float = 0.0
var _flash_timer: float = 0.0
var attack_timer: float = 0.0
var hunt_target: Node2D = null
## "roam" | "interest" | "chase"
var _hunt_mode: String = "roam"
var exploding := false
var _explosion: AnimatedSprite2D = null
var _throw_timer: float = 0.0
var _thrown: bool = false

## Build 014 MSM Cam (see LevelConfig CAM_*).
## Silly humans: 0..1 "convinced" meter filled by being filmed; once full they
## walk to the safe zone by themselves. `stampede_timer` > 0 = VIRAL run.
var convince: float = 0.0
var convinced := false
var stampede_timer: float = 0.0
var _since_filmed: float = 999.0
## Karens: seconds of camera excitement left (faster, erratic, toward the cam).
var cam_love: float = 0.0
var _zig_phase: float = 0.0
## Sheep / possessed / Karens: camcorder SWING stagger (can't act).
var stagger_timer: float = 0.0
var _seek_check_t: float = 0.0
var _seek_last_d: float = INF
var _detour := Vector2.ZERO
var _detour_t: float = 0.0
var _badge: Node2D = null
const CONVINCED_MODULATE := Color(0.9, 1.0, 0.82, 1.0)


## Build 010: per-human wander speed range (silly humans amble at different
## paces). Set randomize_wander=false to keep the exported wander_speed.
@export var randomize_wander: bool = true
@export var wander_speed_min: float = LevelConfig.HUMAN_WANDER_SPEED_MIN
@export var wander_speed_max: float = LevelConfig.HUMAN_WANDER_SPEED_MAX


func _ready() -> void:
	health = maximum_health
	add_to_group("humans")
	add_to_group("whippable")
	_noise_offset = randf() * TAU
	_zig_phase = randf() * TAU
	if randomize_wander:
		wander_speed = randf_range(wander_speed_min, wander_speed_max)
		# A little personality: dawdlers change their mind less often.
		direction_change_time = randf_range(1.5, 2.8)
		pause_chance = randf_range(0.12, 0.26)
	pick_new_direction()
	health_changed.emit(health, maximum_health)


func _physics_process(delta: float) -> void:
	if rescued or _dead or exploding:
		return

	if _throw_timer > 0.0:
		_throw_timer -= delta
		if _throw_timer <= 0.0:
			_thrown = false

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and not possessed:
			sprite.modulate = CONVINCED_MODULATE if heading_to_safety() else NORMAL_MODULATE
		elif _flash_timer <= 0.0 and possessed:
			sprite.modulate = KAREN_MODULATE if karen else POSSESSED_MODULATE

	if possessed:
		_physics_possessed(delta)
		return

	direction_timer -= delta
	if direction_timer <= 0.0:
		pick_new_direction()

	_update_cam_state(delta)

	var movement := Vector2.ZERO
	# Build 014: convinced (MSM Cam) / VIRAL stampede humans head for safety.
	var threat_any := _nearest_sheep()
	if heading_to_safety() and not was_thrown_recently():
		movement = _safety_movement(delta, threat_any)
	# Priority: flee sheep > avoid safe zone > wander (silly). Never chase rancher.
	# Throw override: skip safe-zone avoidance while _throw_timer is active.
	var threat := threat_any
	if movement != Vector2.ZERO:
		pass
	elif threat != null:
		_pausing = false
		var away := threat.global_position.direction_to(global_position)
		if away.length_squared() < 0.0001:
			away = wander_direction
		movement = away * flee_speed
	elif not was_thrown_recently():
		var zone := _nearest_safe_zone()
		if zone != null:
			_pausing = false
			var away_zone := zone.global_position.direction_to(global_position)
			if away_zone.length_squared() < 0.0001:
				away_zone = wander_direction
			if away_zone.length_squared() < 0.0001:
				away_zone = Vector2.RIGHT.rotated(_noise_offset)
			movement = away_zone.normalized() * avoid_safe_speed
		elif _pausing:
			movement = Vector2.ZERO
		else:
			movement = wander_direction * wander_speed
	elif _pausing:
		movement = Vector2.ZERO
	else:
		movement = wander_direction * wander_speed

	movement.y *= 0.60

	# Whip shove / throw still applies — this is how you herd them into the zone.
	if external_velocity.length() > 3.0:
		movement += external_velocity
		external_velocity = external_velocity.lerp(Vector2.ZERO, delta * 3.5)

	if knockback_velocity.length() > 5.0:
		movement += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 7.0)

	velocity = movement
	update_animation(movement)
	move_and_slide()
	_soft_clamp_interior()


func _physics_possessed(delta: float) -> void:
	# Build 014: camcorder SWING stagger - pushed back, can't act.
	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity = external_velocity + knockback_velocity
		external_velocity = external_velocity.lerp(Vector2.ZERO, delta * 3.0)
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 7.0)
		if cam_love > 0.0:
			cam_love -= delta
		move_and_slide()
		_soft_clamp_interior()
		return
	if karen:
		_physics_karen(delta)
		return
	if attack_timer > 0.0:
		attack_timer -= delta

	direction_timer -= delta
	if direction_timer <= 0.0:
		_pick_hunt_roam()

	_update_hunt_target_and_mode()

	match _hunt_mode:
		"seek":
			_hunt_move_toward(hunt_target, LevelConfig.KAREN_SEEK_SPEED)
		"chase":
			_hunt_move_toward(hunt_target, hunt_speed)
		"interest":
			_hunt_move_toward(hunt_target, hunt_interest_speed)
		_:
			_hunt_roam()

	if external_velocity.length() > 3.0:
		external_velocity = external_velocity.lerp(Vector2.ZERO, delta * 3.0)

	if knockback_velocity.length() > 5.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 7.0)

	update_animation(velocity)
	move_and_slide()
	_soft_clamp_interior()
	if was_thrown_recently():
		_check_thrown_collisions()
	_check_hunt_attack()


func _soft_clamp_interior() -> void:
	var root := get_tree().get_first_node_in_group("level_controller")
	if root == null:
		return
	# Do not clamp until spawn/rescue gate is open — early clamps fight teleports.
	if root.has_method("can_rescue_humans") and not root.can_rescue_humans():
		return
	var layer = root.get_node_or_null("Ground")
	if layer == null or not layer.has_method("is_interior_local"):
		return
	var ground_local: Vector2 = layer.to_local(global_position)
	var cell: Vector2i = layer.local_pos_to_local_cell(ground_local)
	if not layer.is_interior_local(cell, 1):
		global_position = layer.to_global(layer.clamp_to_interior(ground_local, 2))


func _nearest_sheep() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := flee_range
	for candidate in get_tree().get_nodes_in_group("sheep"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		if "exploding" in candidate and candidate.exploding:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate as Node2D
	return nearest


func _nearest_safe_zone() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := avoid_safe_range
	for candidate in get_tree().get_nodes_in_group("safe_zones"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate as Node2D
	return nearest


func _nearest_in_group(group_name: String, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist := max_range
	for candidate in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		if candidate == self:
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
		if candidate == self:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance > min_range and distance < best_dist:
			best_dist = distance
			best = candidate as Node2D
	return best


func _update_hunt_target_and_mode() -> void:
	# Build 013 (level 3+): converted humans seek each other out. A silly human
	# right next to them still gets bitten first.
	if possessed and LevelConfig.karens_enabled(_level()):
		var close_human := _nearest_in_group("humans", LevelConfig.KAREN_SEEK_DISTRACT)
		if close_human != null:
			hunt_target = close_human
			_hunt_mode = "chase"
			return
		# Nearest buddy that is not already beside us, so pairs keep merging
		# into bigger groups instead of settling as pairs.
		var buddy := _nearest_buddy(LevelConfig.KAREN_SEEK_RANGE, LevelConfig.KAREN_SEEK_SETTLE)
		if buddy != null:
			hunt_target = buddy
			_hunt_mode = "seek"
			return
	# Prefer silly humans over player (same as killer sheep).
	var human_attn := _nearest_in_group("humans", attention_range)
	if human_attn != null:
		hunt_target = human_attn
		_hunt_mode = "chase"
		return

	var player_attn := _nearest_in_group("player", attention_range)
	if player_attn != null:
		hunt_target = player_attn
		_hunt_mode = "chase"
		return

	var human_interest := _nearest_in_band("humans", attention_range, interest_range)
	if human_interest != null:
		hunt_target = human_interest
		_hunt_mode = "interest"
		return

	var player_interest := _nearest_in_band("player", attention_range, interest_range)
	if player_interest != null:
		hunt_target = player_interest
		_hunt_mode = "interest"
		return

	hunt_target = null
	_hunt_mode = "roam"


func _hunt_move_toward(node: Node2D, speed: float) -> void:
	if node == null:
		_hunt_roam()
		return
	var direction := global_position.direction_to(node.global_position)
	var chase_velocity := direction * speed
	chase_velocity.y *= 0.60
	velocity = chase_velocity + external_velocity


func _hunt_roam() -> void:
	var movement := wander_direction * hunt_roam_speed
	movement.y *= 0.60
	velocity = movement + external_velocity


func _pick_hunt_roam() -> void:
	direction_timer = randf_range(
		direction_change_time * 0.5,
		direction_change_time * 1.5
	)
	wander_direction = Vector2.from_angle(randf() * TAU)


func _check_hunt_attack() -> void:
	if hunt_target == null or attack_timer > 0.0 or _hunt_mode != "chase":
		return
	var distance := global_position.distance_to(hunt_target.global_position)
	if distance > attack_distance:
		return
	attack_timer = attack_cooldown
	if hunt_target.has_method("take_damage"):
		hunt_target.take_damage(1, global_position)


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


func pick_new_direction() -> void:
	if randf() < pause_chance:
		_pausing = true
		direction_timer = randf_range(pause_time * 0.6, pause_time * 1.4)
		wander_direction = Vector2.ZERO
		return

	_pausing = false
	direction_timer = randf_range(
		direction_change_time * 0.5,
		direction_change_time * 1.5
	)
	wander_direction = Vector2.from_angle(randf() * TAU)
	_noise_offset = randf() * TAU


func take_damage(amount: int, source_position := Vector2.ZERO) -> void:
	if rescued or _dead or possessed or exploding:
		return

	health = max(health - amount, 0)

	if source_position != Vector2.ZERO:
		var direction := source_position.direction_to(global_position)
		knockback_velocity = direction * 300.0

	_flash_timer = 0.18
	sprite.modulate = FLASH_MODULATE
	health_changed.emit(health, maximum_health)

	if health <= 0:
		_become_possessed()


func _become_possessed() -> void:
	if possessed or rescued or _dead:
		return
	possessed = true
	convinced = false
	convince = 0.0
	stampede_timer = 0.0
	sprite.speed_scale = 1.0
	remove_from_group("humans")
	add_to_group("possessed")
	# Stay whippable — whip will explode like sheep.
	sprite.modulate = POSSESSED_MODULATE
	# Soft eye glow via slight scale pulse cue on modulate alpha stay full.
	_pick_hunt_roam()
	was_possessed.emit()


func receive_whip(source_position: Vector2, force: float) -> void:
	if exploding or _dead or rescued:
		return
	if possessed and karen:
		karen_damage(1, source_position)
		return
	if possessed:
		explode()
		return
	var direction := source_position.direction_to(global_position)
	external_velocity += direction * force


# ------------------------------------------------------------------ build 013

func _level() -> int:
	if _level_cache < 0:
		var progress := get_node_or_null("/root/GameProgress")
		_level_cache = int(progress.current_level) if progress != null and "current_level" in progress else 1
	return _level_cache


## Nearest other possessed human (Karens included), not exploding.
func _nearest_buddy(max_range: float, min_range: float = 0.0) -> Node2D:
	var best: Node2D = null
	var best_d := max_range
	for c in get_tree().get_nodes_in_group("possessed"):
		if c == self or not is_instance_valid(c) or not c is Node2D:
			continue
		if "exploding" in c and c.exploding:
			continue
		var d := global_position.distance_to((c as Node2D).global_position)
		if d > min_range and d < best_d:
			best_d = d
			best = c
	return best


## Turn this possessed human into a gregarious Karen (called by the level's
## cluster check). Returns false if it can't (not possessed, already a Karen...).
func become_karen() -> bool:
	if karen or not possessed or exploding or rescued or _dead:
		return false
	karen = true
	karen_hp = LevelConfig.KAREN_HP
	add_to_group("karens")
	var frames := load(KAREN_FRAMES_PATH) as SpriteFrames
	if frames != null:
		var anim := sprite.animation
		sprite.sprite_frames = frames
		sprite.animation = anim
	sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
	_flash_timer = 0.25
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.35, 1.35), 0.1)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.18)
	became_karen.emit()
	return true


## One hit on a Karen (whip, shockwave, whip shot, fire tick).
func karen_damage(amount: int, source_position := Vector2.ZERO) -> void:
	if exploding or not karen:
		return
	karen_hp -= amount
	if karen_hp <= 0:
		explode()
		return
	if source_position != Vector2.ZERO:
		knockback_velocity = source_position.direction_to(global_position) * 420.0
	_flash_timer = 0.15
	sprite.modulate = FLASH_MODULATE


## Burn tick (scripts/world/burn.gd): Karens lose a hit, other possessed explode.
func fire_damage() -> void:
	if exploding or not possessed:
		return
	if karen:
		karen_damage(1)
	else:
		explode()


func _physics_karen(delta: float) -> void:
	if _karen_bite_timer > 0.0:
		_karen_bite_timer -= delta
	direction_timer -= delta
	if direction_timer <= 0.0:
		_pick_hunt_roam()
	var target: Node2D = null
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and not ("_dead" in player and player._dead) \
			and global_position.distance_to(player.global_position) <= LevelConfig.KAREN_MOB_RANGE:
		target = player
	if target == null:
		target = _nearest_in_group("humans", interest_range)
	if target == null:
		# Nearest buddy that is not already beside us, so pairs keep merging
		# into bigger groups instead of settling as pairs.
		var buddy := _nearest_buddy(LevelConfig.KAREN_SEEK_RANGE, LevelConfig.KAREN_SEEK_SETTLE)
		if buddy != null:
			target = buddy
	# Build 014: Karens love cameras - while filmed (and CAM_KAREN_LINGER s
	# after) they rush the camera faster, zig-zagging and jittering.
	var loving := cam_love > 0.0
	if loving:
		cam_love -= delta
		if player != null and not ("_dead" in player and player._dead):
			target = player
	hunt_target = target
	_hunt_mode = "mob" if target != null else "roam"
	var v := Vector2.ZERO
	if target != null:
		var fwd := global_position.direction_to(target.global_position)
		var spd := LevelConfig.karen_speed(_level())
		if loving:
			spd *= LevelConfig.CAM_KAREN_SPEED_MULT
			var t := Time.get_ticks_msec() / 1000.0
			var side := Vector2(-fwd.y, fwd.x)
			var zig := sin(t * TAU * LevelConfig.CAM_KAREN_ZIGZAG_HZ + _zig_phase) * LevelConfig.CAM_KAREN_ZIGZAG_AMP
			zig += randf_range(-0.45, 0.45)
			v = (fwd + side * zig) * spd
		else:
			v = fwd * spd
	else:
		v = wander_direction * hunt_roam_speed * (LevelConfig.CAM_KAREN_SPEED_MULT if loving else 1.0)
	# Karens jostle instead of stacking on one pixel.
	for k in get_tree().get_nodes_in_group("karens"):
		if k == self or not is_instance_valid(k):
			continue
		var off := global_position - (k as Node2D).global_position
		var d := off.length()
		if d < LevelConfig.KAREN_SEPARATION and d > 0.01:
			v += off / d * 70.0 * (1.0 - d / LevelConfig.KAREN_SEPARATION)
	v.y *= 0.60
	velocity = v + external_velocity
	if external_velocity.length() > 3.0:
		external_velocity = external_velocity.lerp(Vector2.ZERO, delta * 3.0)
	if knockback_velocity.length() > 5.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 7.0)
	update_animation(velocity)
	move_and_slide()
	_soft_clamp_interior()
	if was_thrown_recently():
		_check_thrown_collisions()
		if exploding:
			return
	_karen_contact(player)


func _karen_contact(player: Node2D) -> void:
	var reach := LevelConfig.KAREN_REACH
	if player != null and not ("_dead" in player and player._dead) \
			and global_position.distance_to(player.global_position) <= reach:
		var now := Time.get_ticks_msec()
		if now >= mob_hit_ready_ms and player.has_method("take_damage"):
			var was: int = player.health if "health" in player else 0
			player.take_damage(LevelConfig.KAREN_DAMAGE, global_position)
			# Only start the shared cooldown if the hit landed (not during a grab).
			if "health" in player and player.health < was:
				mob_hit_ready_ms = now + int(LevelConfig.KAREN_MOB_HIT_INTERVAL * 1000.0)
	if _karen_bite_timer <= 0.0:
		var victim := _nearest_in_group("humans", reach)
		if victim != null and victim.has_method("take_damage"):
			_karen_bite_timer = LevelConfig.KAREN_BITE_COOLDOWN
			victim.take_damage(1, global_position)


## Grab/throw: fling 180° opposite aim. Possessed get thrown (not exploded).
func receive_throw(throw_direction: Vector2, force: float) -> void:
	if exploding or _dead or rescued:
		return
	var direction := throw_direction
	if direction.length_squared() < 0.0001:
		direction = Vector2.LEFT
	else:
		direction = direction.normalized()
	external_velocity += direction * force
	_throw_timer = throw_duration
	_thrown = true


func was_thrown_recently() -> bool:
	return _throw_timer > 0.0 or _thrown


## Thrown possessed: mutual destroy with sheep or other possessed nearby.
func _check_thrown_collisions() -> void:
	if exploding or _dead or rescued or not possessed:
		return
	for candidate in get_tree().get_nodes_in_group("sheep"):
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
	for candidate in get_tree().get_nodes_in_group("possessed"):
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


func explode() -> void:
	if exploding:
		return
	was_destroyed.emit(possessed)
	exploding = true
	_thrown = false
	_throw_timer = 0.0
	velocity = Vector2.ZERO
	external_velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	hunt_target = null

	remove_from_group("whippable")
	remove_from_group("possessed")
	remove_from_group("humans")
	remove_from_group("karens")

	collision_layer = 0
	collision_mask = 0

	var collision_shape := get_node_or_null("CollisionShape2D")
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	sprite.visible = false
	_ensure_explosion_sprite()
	if _explosion != null:
		_explosion.visible = true
		_explosion.play("explode")
		await _explosion.animation_finished
	else:
		await get_tree().create_timer(0.35).timeout
	queue_free()


func _ensure_explosion_sprite() -> void:
	_explosion = get_node_or_null("Explosion") as AnimatedSprite2D
	if _explosion != null:
		return
	var frames := load("res://assets/spriteframes/explosion_frames.tres")
	if frames == null:
		return
	_explosion = AnimatedSprite2D.new()
	_explosion.name = "Explosion"
	_explosion.sprite_frames = frames
	_explosion.animation = &"explode"
	_explosion.visible = false
	_explosion.z_index = 5
	add_child(_explosion)


func rescue() -> void:
	if rescued or _dead or possessed or exploding:
		return
	rescued = true
	_thrown = false
	_throw_timer = 0.0
	remove_from_group("whippable")
	remove_from_group("humans")
	was_rescued.emit()
	queue_free()


## Thrown into safe zone: rescue possessed without killing/exploding.
func rescue_from_possession() -> void:
	if rescued or _dead or exploding:
		return
	if not possessed:
		return
	rescued = true
	possessed = false
	_thrown = false
	_throw_timer = 0.0
	remove_from_group("whippable")
	remove_from_group("possessed")
	remove_from_group("humans")
	remove_from_group("karens")
	was_possession_saved.emit()
	queue_free()


func die() -> void:
	# Non-possession death path (edge cases). Sheep damage uses possession.
	if rescued or _dead or possessed or exploding:
		return
	_dead = true
	remove_from_group("whippable")
	remove_from_group("humans")
	was_killed.emit()
	queue_free()


# ------------------------------------------------------------------ build 014

## Convinced by the MSM Cam, or running in a VIRAL stampede.
func heading_to_safety() -> bool:
	return not possessed and (convinced or stampede_timer > 0.0)


## Called every physics frame this silly human is inside the filming cone.
func cam_film(delta: float) -> void:
	if possessed or rescued or exploding or _dead:
		return
	_since_filmed = 0.0
	if not convinced:
		convince = minf(convince + delta / LevelConfig.CAM_CONVINCE_TIME, 1.0)
		if convince >= 1.0:
			convinced = true
			_on_heading_to_safety()
	_ensure_badge()


## VIRAL: run to the safe zone for CAM_STAMPEDE_SECONDS (or until saved).
func start_stampede() -> void:
	if possessed or rescued or exploding or _dead:
		return
	stampede_timer = LevelConfig.CAM_STAMPEDE_SECONDS
	_on_heading_to_safety()
	_ensure_badge()


func _on_heading_to_safety() -> void:
	_pausing = false
	_seek_last_d = INF
	if _flash_timer <= 0.0:
		sprite.modulate = CONVINCED_MODULATE


## Karens: in the cone this frame (refreshes the linger timer).
func cam_excite() -> void:
	if not karen or exploding:
		return
	cam_love = LevelConfig.CAM_KAREN_LINGER
	_ensure_badge()


## Karen footage infected this silly human (random pick by the cam).
func cam_infect() -> bool:
	if possessed or rescued or exploding or _dead:
		return false
	health = 0
	health_changed.emit(health, maximum_health)
	_become_possessed()
	var lvl := get_tree().get_first_node_in_group("level_controller")
	if lvl != null and lvl.has_method("spawn_score_popup"):
		lvl.spawn_score_popup("INFECTED!", global_position, Color(0.85, 0.4, 1.0), 2)
	_flash_timer = 0.3
	sprite.modulate = Color(2.0, 1.2, 2.2, 1.0)
	return true


## Camcorder SWING: shove (no damage) + stagger. Sheep have their own version.
func receive_swing(source_position: Vector2, push: float, stagger: float) -> void:
	if exploding or _dead or rescued or not possessed:
		return
	var dir := source_position.direction_to(global_position)
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	external_velocity = dir * push
	stagger_timer = maxf(stagger_timer, stagger)


func _update_cam_state(delta: float) -> void:
	_since_filmed += delta
	if not convinced and convince > 0.0 and _since_filmed > 0.12:
		convince = maxf(convince - LevelConfig.CAM_CONVINCE_DECAY * delta, 0.0)
	if stampede_timer > 0.0:
		stampede_timer -= delta
		if stampede_timer <= 0.0 and not convinced:
			sprite.speed_scale = 1.0
			if _flash_timer <= 0.0:
				sprite.modulate = NORMAL_MODULATE


func _safety_movement(delta: float, threat: Node2D) -> Vector2:
	var zone := _nearest_in_group("safe_zones", INF)
	if zone == null:
		return Vector2.ZERO
	var mult := LevelConfig.CAM_CONVINCED_SPEED_MULT if convinced else 0.0
	if stampede_timer > 0.0:
		mult = maxf(mult, LevelConfig.CAM_STAMPEDE_SPEED_MULT)
	sprite.speed_scale = mult
	var dir := global_position.direction_to(zone.global_position)
	# Still scared of sheep: sidestep a close one instead of walking into it.
	if threat != null and global_position.distance_to(threat.global_position) < flee_range * 0.6:
		dir = (dir + threat.global_position.direction_to(global_position) * 0.9).normalized()
	# Simple unstick: no progress for 0.6 s -> walk sideways for a bit.
	var d := global_position.distance_to(zone.global_position)
	_seek_check_t -= delta
	if _seek_check_t <= 0.0:
		_seek_check_t = 0.6
		if _seek_last_d - d < 10.0 and _detour_t <= 0.0:
			_detour = Vector2(-dir.y, dir.x) * (1.0 if randf() < 0.5 else -1.0)
			_detour_t = 0.7
		_seek_last_d = d
	if _detour_t > 0.0:
		_detour_t -= delta
		dir = (dir * 0.35 + _detour).normalized()
	# Compensate the isometric y squash so they really head for the zone.
	var mv := dir * wander_speed * mult
	mv.y /= 0.60
	return mv


func _ensure_badge() -> void:
	if _badge != null and is_instance_valid(_badge):
		return
	_badge = CamBadge.new()
	_badge.name = "CamBadge"
	add_child(_badge)


## Little indicator above the head: the convinced meter while being filmed,
## a green "play" tag once convinced / stampeding, pink hearts on Karens that
## are loving the camera.
class CamBadge extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 9
		position = Vector2(0, -50)

	func _process(delta: float) -> void:
		_t += delta
		var h := get_parent()
		if h == null or ("exploding" in h and h.exploding):
			queue_free()
			return
		var busy: bool = h.cam_love > 0.0 if h.karen else (h.heading_to_safety() or h.convince > 0.0)
		if not busy:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var h := get_parent()
		var out := Color(0.06, 0.03, 0.08)
		if h.karen:
			# bouncing pink heart + sparkle
			var b := sin(_t * 9.0) * 2.0
			var rows := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
			var o := Vector2(-7, -6 + b)
			for y in rows.size():
				for x in 7:
					if rows[y][x] == "#":
						draw_rect(Rect2(o + Vector2(x * 2 - 1, y * 2 - 1), Vector2(4, 4)), out)
			for y in rows.size():
				for x in 7:
					if rows[y][x] == "#":
						draw_rect(Rect2(o + Vector2(x * 2, y * 2), Vector2(2, 2)), Color(1.0, 0.4, 0.75))
			draw_rect(Rect2(o + Vector2(2, 2), Vector2(2, 2)), Color(1, 0.85, 0.95))
			if fmod(_t, 0.4) < 0.2:
				draw_rect(Rect2(Vector2(10, -10 - b), Vector2(2, 6)), Color(1, 1, 0.7))
				draw_rect(Rect2(Vector2(8, -8 - b), Vector2(6, 2)), Color(1, 1, 0.7))
			return
		if h.heading_to_safety():
			# green tag with a "play" triangle (VIRAL runners get a pink one)
			var col := Color(1.0, 0.45, 0.8) if h.stampede_timer > 0.0 and not h.convinced else Color(0.4, 1.0, 0.45)
			var bob := sin(_t * 6.0) * 1.5
			var r := Rect2(Vector2(-9, -8 + bob), Vector2(18, 14))
			draw_rect(r.grow(1), out)
			draw_rect(r, col)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-3, -5 + bob), Vector2(5, -1 + bob), Vector2(-3, 3 + bob)]), Color(1, 1, 1))
			return
		# convinced meter (while being filmed / draining)
		var w := 24.0
		draw_rect(Rect2(-w * 0.5 - 2, -4, w + 4, 8), out)
		draw_rect(Rect2(-w * 0.5, -2, w, 4), Color(0.25, 0.2, 0.3))
		draw_rect(Rect2(-w * 0.5, -2, w * clampf(h.convince, 0.0, 1.0), 4), Color(1.0, 0.82, 0.12))
		if h._since_filmed < 0.15 and fmod(_t, 0.5) < 0.3:
			draw_circle(Vector2(-w * 0.5 - 6, 0), 3.0, out)
			draw_circle(Vector2(-w * 0.5 - 6, 0), 2.0, Color(1.0, 0.15, 0.12))
