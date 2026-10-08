class_name Whip
extends Node2D

@export var whip_range: float = 210.0
@export var target_radius: float = 70.0
@export var ray_hit_radius: float = 36.0
@export var whip_force: float = 520.0
@export var cooldown_time: float = 0.35
## Grab/throw fling strength (180° opposite aim, or steering direction).
@export var throw_force: float = 800.0
@export var grab_cooldown_time: float = 0.40

## Build 011 touch aim assist (never used with mouse aim). Half-angle of the
## cone around the rancher's facing, max distance, and how much the score
## favours a small angle over a short distance (0..1).
const AIM_ASSIST_CONE_DEG := 55.0
const AIM_ASSIST_RANGE := 220.0
const AIM_ASSIST_ANGLE_WEIGHT := 0.55

var cooldown := 0.0
## Build 013: LONG WHIP also stretches the touch aim-assist range.
var assist_range_mult := 1.0
var grab_cooldown := 0.0
var whip_end := Vector2.ZERO
var grab_end := Vector2.ZERO

## Visual-only. Gameplay still resolves on the click frame.
const CRACK_TIME := 0.34
const GRAB_TIME := 0.48
const LASH_SEGMENTS := 16
const ECHO_LIFE := 0.11

var _crack_age := -1.0
var _grab_age := -1.0
var _grab_aim := Vector2.RIGHT
## Build 010: direction the grabbed target was thrown (follow-through visual).
var _grab_throw_dir := Vector2.LEFT
var _crack_pts := PackedVector2Array()
var _grab_pts := PackedVector2Array()
var _echoes: Array = []
var _spark_sent_crack := false
var _spark_sent_grab := false
var _spark_kind := ""

@onready var crack: AnimatedSprite2D = get_node_or_null("Crack")


func _ready() -> void:
	if crack:
		crack.visible = false
		crack.animation_finished.connect(_on_crack_finished)


func _process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta
	if grab_cooldown > 0.0:
		grab_cooldown -= delta

	# Build 014: input is read by Weapons (player child), which calls
	# weapon_primary() / weapon_secondary() on the equipped weapon. Without a
	# Weapons node (old tests) the whip reads the input itself, as in 013.
	if get_parent() == null or get_parent().get_node_or_null("Weapons") == null:
		if Input.is_action_just_pressed("whip") or TouchInput.consume_whip():
			fire_whip()
		if Input.is_action_just_pressed("whip_grab") or TouchInput.consume_grab():
			fire_grab_throw()

	var i := _echoes.size() - 1
	while i >= 0:
		_echoes[i]["life"] = float(_echoes[i]["life"]) - delta
		if float(_echoes[i]["life"]) <= 0.0:
			_echoes.remove_at(i)
		i -= 1

	_crack_pts = PackedVector2Array()
	_grab_pts = PackedVector2Array()

	if _crack_age >= 0.0:
		_crack_age += delta
		if _crack_age > CRACK_TIME:
			_crack_age = -1.0
		else:
			_crack_pts = _build_crack_pts(_crack_age / CRACK_TIME)
			_remember(_crack_pts, Color(0.85, 0.62, 0.28, 0.85), 3.5)
			_track_spark("crack", _crack_pts)

	if _grab_age >= 0.0:
		_grab_age += delta
		if _grab_age > GRAB_TIME:
			_grab_age = -1.0
		else:
			_grab_pts = _build_grab_pts(_grab_age / GRAB_TIME)
			_remember(_grab_pts, Color(0.35, 0.9, 1.0, 0.8), 3.5)
			_track_spark("grab", _grab_pts)

	queue_redraw()


func fire_whip() -> void:
	if cooldown > 0.0:
		return

	cooldown = cooldown_time

	var owner_position := global_position
	var mouse_position := TouchInput.get_aim_world(self)
	var direction := owner_position.direction_to(mouse_position)
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT

	# Build 011 touch aim assist (touch only; the mouse path below is unchanged).
	var assist := _touch_assist(owner_position, direction)
	if assist != null:
		direction = _dir_to(owner_position, assist.global_position, direction)
		mouse_position = assist.global_position

	whip_end = owner_position + direction * whip_range

	var target := assist if assist != null else find_target(owner_position, mouse_position, direction)

	if target != null:
		whip_end = target.global_position
		if target.has_method("receive_whip"):
			target.receive_whip(owner_position, whip_force)

	_crack_age = 0.0
	_spark_sent_crack = false
	Sfx.play(self, "crack_fire" if has_power("fire_whip") else "crack", -7.0, randf_range(0.94, 1.08))
	_apply_crack_powerups(owner_position, direction, target)


# ------------------------------------------------------------- build 013 power-ups

## Build 014 dual-mode weapon API: PRIMARY = crack, SECONDARY = grab + throw.
func weapon_primary() -> void:
	fire_whip()


func weapon_secondary() -> void:
	fire_grab_throw()


## Build 014: true when the whip is the current weapon (or there is no
## Weapons node, e.g. in old tests).
func is_equipped() -> bool:
	var p := get_parent()
	var w: Node = p.get_node_or_null("Weapons") if p != null else null
	return w == null or w.current_id() == "whip"


func power_ups() -> Node:
	var p := get_parent()
	return p.get_node_or_null("PowerUps") if p != null else null


func has_power(kind: String) -> bool:
	var pu := power_ups()
	return pu != null and pu.is_active(kind)


## Runs after every whip crack (PC or touch). Without power-ups it does nothing,
## so the 012 crack is unchanged.
func _apply_crack_powerups(owner_position: Vector2, direction: Vector2, target: Node2D) -> void:
	var tip := whip_end
	if has_power("fire_whip"):
		if target != null:
			Burn.ignite(target)
		for group in ["possessed", "sheep", "boss"]:
			for c in get_tree().get_nodes_in_group(group):
				if c is Node2D and (c as Node2D).global_position.distance_to(tip) <= LevelConfig.FIRE_IGNITE_RADIUS:
					Burn.ignite(c)
	if has_power("shockwave"):
		# Build 015b: the boss is no longer in the splash list; a shockwave crack
		# only hurts him when the lash itself connects (target above).
		for group in ["possessed", "sheep"]:
			for c in get_tree().get_nodes_in_group(group):
				if c == target or not c is Node2D or not is_instance_valid(c):
					continue
				if "exploding" in c and c.exploding:
					continue
				if (c as Node2D).global_position.distance_to(tip) <= LevelConfig.SHOCKWAVE_RADIUS and c.has_method("receive_whip"):
					c.receive_whip(owner_position, whip_force)
		_spawn_fx(ShockRing.new(), tip)
		Sfx.play(self, "shock", -6.0)
	if has_power("whip_shot"):
		var shot := WhipShot.new()
		shot.direction = direction.normalized()
		shot.fire = has_power("fire_whip")
		shot.force = whip_force
		var parent := get_parent().get_parent() if get_parent() != null else null
		var lvl := get_tree().get_first_node_in_group("level_controller")
		if lvl != null and lvl.get_node_or_null("Entities") != null:
			parent = lvl.get_node("Entities")
		if parent != null:
			parent.add_child(shot)
			shot.global_position = owner_position + shot.direction * 24.0
			Sfx.play(self, "shot", -10.0)
	# Build 014: fire and shockwave are charges (one per crack).
	var pu := power_ups()
	if pu != null and pu.has_method("on_whip_crack"):
		pu.on_whip_crack()


func _spawn_fx(node: Node2D, at: Vector2) -> void:
	var lvl := get_tree().get_first_node_in_group("level_controller")
	var parent: Node = lvl.fx_layer if lvl != null and "fx_layer" in lvl and lvl.fx_layer != null else get_parent().get_parent()
	if parent == null:
		return
	parent.add_child(node)
	node.global_position = at


## Expanding ring for SHOCKWAVE.
class ShockRing extends Node2D:
	var r := 10.0
	var a := 1.0
	func _ready() -> void:
		add_to_group("shock_rings")
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "r", LevelConfig.SHOCKWAVE_RADIUS, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "a", 0.0, 0.35)
		tw.chain().tween_callback(queue_free)
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(0.06, 0.03, 0.08, a), 7.0)
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(0.75, 0.55, 1.0, a), 4.0)
		draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 32, Color(1.0, 0.95, 0.6, a * 0.7), 2.0)


## RMB: latch nearest whippable along aim, then fling it: 180° opposite aim when
## standing still, or in the steering direction while moving (build 010).
func fire_grab_throw() -> void:
	if grab_cooldown > 0.0:
		return

	grab_cooldown = grab_cooldown_time

	var owner_position := global_position
	var mouse_position := TouchInput.get_aim_world(self)
	var direction := owner_position.direction_to(mouse_position)
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT

	# Build 011 touch aim assist (touch only; mouse path unchanged).
	var assist := _touch_assist(owner_position, direction)
	if assist != null:
		direction = _dir_to(owner_position, assist.global_position, direction)
		mouse_position = assist.global_position

	_grab_aim = direction
	grab_end = owner_position + direction * whip_range

	# Build 010 directional throw: sampled on the grab frame (the throw resolves
	# immediately). Steering (WASD / joystick) throws that way; standing still
	# keeps the classic throw 180° opposite aim.
	var throw_direction := -direction
	var steer := _steer_direction()
	if steer.length_squared() > 0.0001:
		throw_direction = steer.normalized()
	_grab_throw_dir = throw_direction

	# Build 010: no rancher body for sheep/humans during the grab event.
	var player := get_parent()
	if player != null and player.has_method("begin_grab_ghost"):
		player.begin_grab_ghost(GRAB_TIME)

	var target := assist if assist != null else find_target(owner_position, mouse_position, direction)
	Sfx.play(self, "grab", -10.0)
	if target != null:
		grab_end = target.global_position
		if target.has_method("receive_throw"):
			target.receive_throw(throw_direction, throw_force)
			Sfx.play(self, "throw", -9.0, 1.1)

	_grab_age = 0.0
	_spark_sent_grab = false


## Touch only: best whippable inside the aim-assist cone around the facing
## direction, or null (then the whip cracks straight along facing as before).
## Always null with mouse/keyboard, so PC aim and targeting are untouched.
func _touch_assist(owner_position: Vector2, facing_dir: Vector2) -> Node2D:
	if not TouchInput.active:
		return null
	return find_assist_target(owner_position, facing_dir)


## Score = angle off facing (normalised to the cone) * AIM_ASSIST_ANGLE_WEIGHT
## + distance (normalised to range) * (1 - weight). Lowest score wins.
func find_assist_target(owner_position: Vector2, facing_dir: Vector2) -> Node2D:
	var fwd := facing_dir.normalized() if facing_dir.length_squared() > 0.0001 else Vector2.RIGHT
	var half_cone := deg_to_rad(AIM_ASSIST_CONE_DEG)
	var best: Node2D = null
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("whippable"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var object := candidate as Node2D
		if "exploding" in object and object.exploding:
			continue
		var to_object := object.global_position - owner_position
		var dist := to_object.length()
		if dist > AIM_ASSIST_RANGE * assist_range_mult or dist < 1.0:
			continue
		var ang := absf(fwd.angle_to(to_object))
		if ang > half_cone:
			continue
		var score := (ang / half_cone) * AIM_ASSIST_ANGLE_WEIGHT \
			+ (dist / (AIM_ASSIST_RANGE * assist_range_mult)) * (1.0 - AIM_ASSIST_ANGLE_WEIGHT)
		if score < best_score:
			best_score = score
			best = object
	return best


func _dir_to(from: Vector2, to: Vector2, fallback: Vector2) -> Vector2:
	var d := from.direction_to(to)
	return d if d.length_squared() > 0.0001 else fallback


func _steer_direction() -> Vector2:
	var player := get_parent()
	if player != null and player.has_method("get_steer_direction"):
		return player.get_steer_direction()
	return Vector2.ZERO


func find_target(
	owner_position: Vector2,
	mouse_position: Vector2,
	direction: Vector2
) -> Node2D:
	var nearest: Node2D = null
	var nearest_score := INF

	for candidate in get_tree().get_nodes_in_group("whippable"):
		if not candidate is Node2D:
			continue
		var object := candidate as Node2D
		var to_object := object.global_position - owner_position
		var player_distance := to_object.length()
		if player_distance > whip_range or player_distance < 1.0:
			continue

		var cursor_distance := mouse_position.distance_to(object.global_position)
		var projection := to_object.dot(direction)
		if projection < 0.0:
			continue
		var closest_on_ray := owner_position + direction * clampf(
			projection,
			0.0,
			whip_range
		)
		var ray_distance := closest_on_ray.distance_to(object.global_position)

		# Forgiving: near cursor OR near the whip ray segment.
		# Touch aims by facing (aim point far ahead), so skip the near-cursor
		# bonus; only the ray counts. Mouse aim on PC is unchanged.
		var along_ray := ray_distance <= ray_hit_radius and projection <= whip_range
		var near_cursor := (not TouchInput.active) and cursor_distance <= target_radius
		if not along_ray and not near_cursor:
			continue

		# Prefer closer to cursor, then closer to ray, then closer to player.
		var score := (ray_distance if TouchInput.active else cursor_distance * 0.65 + ray_distance * 0.35)
		if score < nearest_score:
			nearest_score = score
			nearest = object

	return nearest


func _play_crack(end_global: Vector2, tint: Color) -> void:
	if crack == null:
		return
	crack.global_position = end_global
	crack.modulate = tint
	crack.visible = true
	crack.z_index = 20
	crack.play("crack")


func _on_crack_finished() -> void:
	if crack:
		crack.visible = false


func _track_spark(kind: String, pts: PackedVector2Array) -> void:
	if pts.size() < 2 or crack == null:
		return
	var tip := to_global(pts[pts.size() - 1])
	if kind == "crack":
		var p := _crack_age / CRACK_TIME
		if p > 0.50 and not _spark_sent_crack:
			_spark_sent_crack = true
			_spark_kind = "crack"
			_play_crack(tip, Color(1.0, 0.55, 0.2) if has_power("fire_whip") else Color(1.0, 0.95, 0.72))
		elif _spark_sent_crack and _spark_kind == "crack" and crack.visible:
			crack.global_position = tip
	elif kind == "grab":
		var p := _grab_age / GRAB_TIME
		# Spark when the lash finishes extending, before the throw follow-through.
		if p > 0.52 and not _spark_sent_grab:
			_spark_sent_grab = true
			_spark_kind = "grab"
			_play_crack(tip, Color(0.62, 1.0, 1.0))
		elif _spark_sent_grab and _spark_kind == "grab" and crack.visible:
			crack.global_position = tip


func _remember(pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() < 2:
		return
	_echoes.append({
		"pts": pts.duplicate(),
		"color": color,
		"width": width,
		"life": ECHO_LIFE,
	})
	if _echoes.size() > 8:
		_echoes.pop_front()


func _lash_points(local_end: Vector2, extend: float, wave: float, curl: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var length := local_end.length()
	var dir := local_end / length if length > 1.0 else Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	var reach := clampf(extend, 0.04, 1.0)
	for i in LASH_SEGMENTS:
		var u := float(i) / float(LASH_SEGMENTS - 1)
		if u > reach:
			u = reach
		var envelope := sin(u * PI)
		var wobble := sin(u * PI * 3.0 - wave) * 15.0 * envelope * (0.3 + 0.7 * reach)
		var curl_off := side * curl * (1.0 - u) * 20.0
		pts.append(dir * length * u + side * wobble + curl_off)
		if reach < 0.999 and u >= reach - 0.0001:
			break
	return pts


func _append_loop(pts: PackedVector2Array, radius: float) -> void:
	if pts.is_empty():
		return
	var tip: Vector2 = pts[pts.size() - 1]
	for i in 9:
		var a := float(i) / 8.0 * TAU
		pts.append(tip + Vector2(cos(a), sin(a)) * radius)


func _coil_points(aim: Vector2, t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var radius := lerpf(16.0, 6.0, t)
	var back := -aim * lerpf(4.0, 18.0, sin(t * PI))
	var spins := lerpf(0.35, 2.05, t)
	for i in 20:
		var u := float(i) / 19.0
		var ang := -t * 8.0 + u * TAU * spins
		pts.append(back + Vector2(cos(ang), sin(ang)) * radius * u)
	return pts


func _build_crack_pts(p: float) -> PackedVector2Array:
	var target := to_local(whip_end)
	var extend := 1.0 if p >= 0.58 else smoothstep(0.0, 0.58, p)
	return _lash_points(target, extend, _crack_age * 36.0, sin(_crack_age * 16.0) * 0.32)


func _build_grab_pts(p: float) -> PackedVector2Array:
	var aim := _grab_aim if _grab_aim.length_squared() > 0.0001 else Vector2.RIGHT
	if p < 0.24:
		# Wind-up pulls back toward the throw side (= opposite aim when still).
		var coil_ref := -_grab_throw_dir if _grab_throw_dir.length_squared() > 0.0001 else aim
		return _coil_points(coil_ref.normalized(), p / 0.24)
	var target := to_local(grab_end)
	if p < 0.58:
		var e := smoothstep(0.0, 1.0, (p - 0.24) / 0.34)
		var pts := _lash_points(target, e, _grab_age * 28.0, 0.12)
		if e > 0.66:
			_append_loop(pts, 6.5 * e)
		return pts
	var f := smoothstep(0.0, 1.0, (p - 0.58) / 0.42)
	var throw_dir := _grab_throw_dir if _grab_throw_dir.length_squared() > 0.0001 else -aim
	var throw_local := throw_dir.normalized() * whip_range * 0.72
	var end := target.lerp(throw_local, f)
	return _lash_points(end, 1.0 - 0.12 * f, _grab_age * 22.0, -0.55 * f)


func _stroke(pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, color, width, true)


func _draw_tip(pos: Vector2, power: float, color: Color) -> void:
	if power <= 0.02:
		return
	var rays := 7
	for i in rays:
		var a := float(i) / float(rays) * TAU + power * 4.0
		var leng := 4.0 + 11.0 * power * (1.0 if i % 2 == 0 else 0.62)
		draw_line(pos, pos + Vector2(cos(a), sin(a)) * leng, color, 1.6, true)
	draw_circle(pos, 2.2 + 3.4 * power, Color(1.0, 0.98, 0.86, color.a))


func _draw() -> void:
	for echo in _echoes:
		var life := float(echo["life"])
		var a := clampf(life / ECHO_LIFE, 0.0, 1.0)
		var c: Color = echo["color"]
		c.a *= a * 0.42
		_stroke(echo["pts"], c, float(echo["width"]))

	if _crack_age >= 0.0 and _crack_pts.size() >= 2:
		var p := clampf(_crack_age / CRACK_TIME, 0.0, 1.0)
		var fade := 1.0 if p < 0.70 else 1.0 - (p - 0.70) / 0.30
		_stroke(_crack_pts, Color(0.20, 0.09, 0.04, 0.92 * fade), 7.2)
		_stroke(_crack_pts, Color(0.55, 0.32, 0.12, 0.96 * fade), 4.2)
		_stroke(_crack_pts, Color(0.95, 0.78, 0.42, 0.75 * fade), 1.6)
		if p > 0.48:
			var spark := clampf((p - 0.48) / 0.28, 0.0, 1.0) * fade
			_draw_tip(_crack_pts[_crack_pts.size() - 1], spark, Color(1.0, 0.86, 0.4, fade))

	if _grab_age >= 0.0 and _grab_pts.size() >= 2:
		var p := clampf(_grab_age / GRAB_TIME, 0.0, 1.0)
		var fade := 1.0 if p < 0.74 else 1.0 - (p - 0.74) / 0.26
		# Wind-up reads thinner; the thrown follow-through stays teal.
		var width_scale := 0.72 if p < 0.24 else 1.0
		_stroke(_grab_pts, Color(0.05, 0.28, 0.36, 0.92 * fade), 7.0 * width_scale)
		_stroke(_grab_pts, Color(0.12, 0.72, 0.82, 0.96 * fade), 4.0 * width_scale)
		_stroke(_grab_pts, Color(0.75, 1.0, 1.0, 0.8 * fade), 1.6 * width_scale)
		if p >= 0.24:
			var spark := clampf((p - 0.40) / 0.3, 0.0, 1.0) * fade
			_draw_tip(_grab_pts[_grab_pts.size() - 1], spark, Color(0.55, 1.0, 1.0, fade))
