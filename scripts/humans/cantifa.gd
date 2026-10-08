class_name Cantifa
extends CharacterBody2D
## Build 017: CANTIFA. A cartoon black-bloc mob (black hoodie, eye-holes,
## bandana, little flag, blocky rifle). Not a silly human and not a Karen:
## they can't be saved. Two whip hits, or one fire hit, drives them off the
## map. They wander in from the map edge, then hold a post just outside the
## safe zone or the human camp and shoot the rancher only.
## Art: tools/gen_cantifa.py -> assets/characters/cantifa_32.png.

signal driven_off

const SHEET := "res://assets/characters/cantifa_32.png"
const CELL := 64

var level: Node = null
var hp: int = LevelConfig.CANTIFA_HP
var post_pos := Vector2.ZERO
var post_face := Vector2.DOWN
var arriving := true
var fleeing := false
var scatter_timer := 0.0
var scatter_dir := Vector2.ZERO
var shot_cd := 0.6
var windup := -1.0
var flash_t := 0.0
var filmed_t := 0.0
var hurt_t := 0.0
var external_velocity := Vector2.ZERO
var knockback_velocity := Vector2.ZERO
var _throw_timer := 0.0
var _rng := RandomNumberGenerator.new()
var sprite: AnimatedSprite2D

func _ready() -> void:
	_rng.randomize()
	add_to_group("cantifa")
	add_to_group("whippable")
	collision_layer = 4
	collision_mask = 11
	motion_mode = MOTION_MODE_FLOATING
	sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.position = Vector2(0, -16)
		add_child(sprite)
	_build_frames()
	shot_cd = _rng.randf_range(0.3, LevelConfig.CANTIFA_COOLDOWN_MAX)


func _build_frames() -> void:
	var tex: Texture2D = load(SHEET)
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	for i in 8:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * CELL, 0, CELL, CELL)
		frames.add_frame("idle", at)
	sprite.sprite_frames = frames
	sprite.animation = "idle"
	sprite.frame = 0


static func make(parent: Node, at: Vector2) -> Cantifa:
	var n := Cantifa.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	n.add_child(col)
	parent.add_child(n)
	n.global_position = at
	return n


func _physics_process(delta: float) -> void:
	if fleeing:
		_physics_flee(delta)
		return
	if shot_cd > 0.0:
		shot_cd -= delta
	if filmed_t > 0.0:
		filmed_t -= delta
	if hurt_t > 0.0:
		hurt_t -= delta
	if scatter_timer > 0.0:
		scatter_timer -= delta
	if windup >= 0.0 and scatter_timer <= 0.0:
		windup -= delta
		flash_t = 0.12
		if windup <= 0.0:
			_fire()
			windup = -1.0
	elif flash_t > 0.0:
		flash_t -= delta
	var v := _desired_velocity()
	v = _separate(v)
	v.y *= 0.6
	if external_velocity.length() > 3.0:
		v += external_velocity
		external_velocity = external_velocity.lerp(Vector2.ZERO, delta * 3.2)
	if knockback_velocity.length() > 5.0:
		v += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 6.0)
	if _throw_timer > 0.0:
		_throw_timer -= delta
	velocity = v
	_keep_out_of_zones()
	move_and_slide()
	_clamp_inside()
	_keep_out_of_zones()
	if arriving and global_position.distance_to(post_pos) < 48.0:
		arriving = false
	_try_shoot(delta)
	_animate()
	queue_redraw()


func _desired_velocity() -> Vector2:
	if _throw_timer > 0.0:
		return external_velocity
	if scatter_timer > 0.0:
		return scatter_dir * LevelConfig.CANTIFA_ARRIVE_SPEED
	var to_post := post_pos - global_position
	if to_post.length() > LevelConfig.CANTIFA_HOLD_DIST:
		var spd := LevelConfig.CANTIFA_ARRIVE_SPEED if arriving else LevelConfig.CANTIFA_DRIFT_SPEED
		return to_post.normalized() * spd
	return Vector2.ZERO


func _separate(v: Vector2) -> Vector2:
	for c in get_tree().get_nodes_in_group("cantifa"):
		if c == self or not is_instance_valid(c):
			continue
		var off: Vector2 = global_position - (c as Node2D).global_position
		var d := off.length()
		if d < LevelConfig.CANTIFA_SEPARATION and d > 0.5:
			v += off / d * 90.0 * (1.0 - d / LevelConfig.CANTIFA_SEPARATION)
	return v


func _keep_out_of_zones() -> void:
	var safe := get_tree().get_first_node_in_group("safe_zones") as Node2D
	if safe != null:
		var off := global_position - safe.global_position
		if off.length() < LevelConfig.CANTIFA_SAFE_KEEP_OUT:
			var push := off.normalized() if off.length() > 1.0 else Vector2.RIGHT
			global_position = safe.global_position + push * LevelConfig.CANTIFA_SAFE_KEEP_OUT
	var camp := _camp()
	if camp != null:
		var off2 := global_position - camp.global_position
		if off2.length() < LevelConfig.CANTIFA_CAMP_KEEP_OUT:
			var push2 := off2.normalized() if off2.length() > 1.0 else Vector2.LEFT
			global_position = camp.global_position + push2 * LevelConfig.CANTIFA_CAMP_KEEP_OUT


func _camp() -> Node2D:
	if level != null:
		var c := level.get_node_or_null("Entities/HumanCamp") as Node2D
		if c != null:
			return c
	return get_tree().get_first_node_in_group("human_camp") as Node2D


func _clamp_inside() -> void:
	if level == null:
		return
	var layer = level.get_node_or_null("Ground")
	if layer == null or not layer.has_method("clamp_to_interior"):
		return
	var local: Vector2 = layer.to_local(global_position)
	var cell: Vector2i = layer.local_pos_to_local_cell(local)
	if not layer.is_interior_local(cell, 1):
		if arriving:
			return
		global_position = layer.to_global(layer.clamp_to_interior(local, 2))


func posted() -> bool:
	return not arriving and not fleeing and scatter_timer <= 0.0 \
		and global_position.distance_to(post_pos) <= LevelConfig.CANTIFA_HOLD_DIST + 10.0


func _aim_dir() -> Vector2:
	# While filmed they turn toward the camera (the rancher) and may shoot.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if filmed_t > 0.0 and player != null:
		var to := global_position.direction_to(player.global_position)
		if to.length_squared() > 0.01:
			return to
	if post_face.length_squared() > 0.01:
		return post_face.normalized()
	return Vector2.DOWN


func _try_shoot(_delta: float) -> void:
	if fleeing or scatter_timer > 0.0 or arriving or _throw_timer > 0.0:
		windup = -1.0
		return
	if not posted() and filmed_t <= 0.0:
		windup = -1.0
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or ("_dead" in player and player._dead):
		windup = -1.0
		return
	var to := player.global_position - global_position
	var dist := to.length()
	var lv := _level_num()
	if dist > LevelConfig.cantifa_range(lv) or dist < 36.0:
		windup = -1.0
		return
	var aim := _aim_dir()
	var ang := absf(rad_to_deg(aim.angle_to(to)))
	if ang > LevelConfig.CANTIFA_CONE_DEG * 0.5 and filmed_t <= 0.0:
		windup = -1.0
		return
	if windup >= 0.0:
		return
	if shot_cd > 0.0:
		return
	windup = LevelConfig.CANTIFA_TELL


func _fire() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var aim := _aim_dir()
	if player != null:
		aim = global_position.direction_to(player.global_position)
	var spread := deg_to_rad(LevelConfig.cantifa_spread_deg(_level_num()))
	aim = aim.rotated(_rng.randf_range(-spread, spread))
	var parent: Node = level.get_node_or_null("Entities") if level != null else get_parent()
	if parent == null:
		parent = get_parent()
	CantifaBullet.launch(parent, global_position + aim * 18.0, aim)
	shot_cd = _rng.randf_range(LevelConfig.CANTIFA_COOLDOWN_MIN, LevelConfig.CANTIFA_COOLDOWN_MAX)
	flash_t = 0.1
	Sfx.play(self, "rifle", -8.0)
	queue_redraw()


func _level_num() -> int:
	if level != null and "level_number" in level:
		return int(level.level_number)
	return 4


func note_filmed() -> void:
	filmed_t = 0.2


func receive_whip(source_position: Vector2, _force: float) -> void:
	if fleeing:
		return
	var dir := source_position.direction_to(global_position)
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	knockback_velocity = dir * 420.0
	hurt_t = 0.18
	hp -= 1
	Sfx.play(self, "stagger", -8.0)
	_scatter_neighbors()
	if hp <= 0:
		drive_off()


func fire_damage() -> void:
	if fleeing:
		return
	drive_off()


func receive_swing(source_position: Vector2, push: float, stagger: float) -> void:
	if fleeing:
		return
	var dir := source_position.direction_to(global_position)
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	external_velocity = dir * push
	scatter_timer = maxf(scatter_timer, stagger)
	scatter_dir = dir


func receive_throw(throw_direction: Vector2, force: float) -> void:
	if fleeing:
		return
	var dir := throw_direction
	if dir.length_squared() < 0.01:
		dir = Vector2.LEFT
	external_velocity = dir.normalized() * force
	_throw_timer = 0.7
	_scatter_neighbors()


func _scatter_neighbors() -> void:
	for c in get_tree().get_nodes_in_group("cantifa"):
		if c == self or not is_instance_valid(c) or c.fleeing:
			continue
		if global_position.distance_to((c as Node2D).global_position) > LevelConfig.CANTIFA_SCATTER_RADIUS:
			continue
		var away: Vector2 = (c as Node2D).global_position - global_position
		if away.length_squared() < 0.01:
			away = Vector2.RIGHT.rotated(randf() * TAU)
		c.scatter_timer = LevelConfig.CANTIFA_SCATTER_TIME
		c.scatter_dir = away.normalized()
		c.windup = -1.0


func drive_off() -> void:
	if fleeing:
		return
	fleeing = true
	windup = -1.0
	remove_from_group("whippable")
	Sfx.play(self, "flee", -8.0)
	driven_off.emit()
	if level != null and level.has_method("on_cantifa_driven_off"):
		level.on_cantifa_driven_off(self)


func _physics_flee(delta: float) -> void:
	var layer = level.get_node_or_null("Ground") if level != null else null
	var dir := Vector2.RIGHT
	if layer != null and layer.has_method("local_pos_to_local_cell"):
		var local: Vector2 = layer.to_local(global_position)
		var cell: Vector2i = layer.local_pos_to_local_cell(local)
		var cx := float(layer.map_width) * 0.5
		var cy := float(layer.map_height) * 0.5
		var away := Vector2(float(cell.x) - cx, float(cell.y) - cy)
		if away.length_squared() > 0.01:
			dir = away.normalized()
		velocity = dir * LevelConfig.CANTIFA_FLEE_SPEED
		move_and_slide()
		if cell.x <= 1 or cell.y <= 1 or cell.x >= layer.map_width - 2 or cell.y >= layer.map_height - 2:
			queue_free()
			return
	else:
		velocity = dir * LevelConfig.CANTIFA_FLEE_SPEED
		move_and_slide()
	_animate()
	if delta > 10.0:
		queue_free()


func _animate() -> void:
	if sprite == null:
		return
	var face := _aim_dir() if posted() or filmed_t > 0.0 else velocity
	if face.length_squared() < 0.04:
		face = post_face
	var side := absf(face.x) > absf(face.y)
	var shooting := windup >= 0.0 or flash_t > 0.0
	if fleeing:
		sprite.frame = 7
	elif hurt_t > 0.0:
		sprite.frame = 6
	elif side:
		sprite.frame = 3 if shooting else 2
	elif face.y < 0.0:
		sprite.frame = 5 if shooting else 4
	else:
		sprite.frame = 1 if shooting else 0
	sprite.flip_h = side and face.x < 0.0


func _draw() -> void:
	if flash_t <= 0.0:
		return
	var aim := _aim_dir()
	var tip := aim * 28.0
	draw_line(aim * 16.0, tip, Color(1.0, 0.85, 0.3, 0.9), 3.0)
	draw_circle(tip, 5.0, Color(1.0, 0.9, 0.4, 0.85))
