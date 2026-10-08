class_name RoboSheep
extends Node2D
## Build 016: HUVAL YARHEYHEY's weapon.
##   kind "robo"  - PROGRAMMED SHEEP: steel wool, cyan circuit traces, glowing
##                  eyes, an antenna. Hunts the rancher with a limited turn rate
##                  (you can outrun and out-turn it). Touch = 1 heart, then it
##                  bounces back and stalls. ANY hit (whip, whip shot, shockwave
##                  splash, fire tick, cam swing) SPLITS it into MICRO_SPLIT
##                  micro sheep. A grab throws it: it splits where it lands, and
##                  if it flies into Huval he loses a heart ("FEEDBACK LOOP!").
##   kind "micro" - MICRO SHEEP: small, neon magenta, fast, short-lived
##                  (MICRO_LIFE, blinks before it fizzles). Touch = HALF a heart
##                  (huval_level.gd counts chips). Any hit pops it.
## Art: tools/gen_boss2.py -> assets/boss2/robo_sheep_32.png / micro_sheep_32.png
## (same 6x4 layout of 64x64 cells as the normal sheep sheet).

signal popped(kind: String, by_player: bool)

const ROBO_SHEET := preload("res://assets/boss2/robo_sheep_32.png")
const MICRO_SHEET := preload("res://assets/boss2/micro_sheep_32.png")

var kind := "robo"
var level: Node = null
var arena := Rect2(-600, -300, 1200, 640)
var velocity := Vector2.ZERO
var speed := 120.0
var turn := LevelConfig.ROBO_TURN
var speed_mult := 1.0
var exploding := false
var life := 0.0
var stun := 0.0
## Spawn-in: frozen + flickering for this long (no damage either way).
var warp_in := 0.35
var thrown := 0.0
var _t := 0.0
var _spr: Sprite2D
var _updated_flash := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("sheep")
	add_to_group("whippable")
	add_to_group("robo_sheep" if kind == "robo" else "micro_sheep")
	rng.randomize()
	_spr = Sprite2D.new()
	_spr.texture = ROBO_SHEET if kind == "robo" else MICRO_SHEET
	_spr.hframes = 6
	_spr.vframes = 4
	_spr.position = Vector2(0, -10) if kind == "robo" else Vector2(0, -6)
	_spr.scale = Vector2.ONE if kind == "robo" else Vector2(0.55, 0.55)
	add_child(_spr)
	if kind == "micro":
		life = LevelConfig.MICRO_LIFE
		turn = LevelConfig.MICRO_TURN
		warp_in = 0.18
	z_index = 0


func is_micro() -> bool:
	return kind == "micro"


func hit_radius() -> float:
	return LevelConfig.MICRO_HIT_RADIUS if kind == "micro" else LevelConfig.ROBO_HIT_RADIUS


func is_dangerous() -> bool:
	return not exploding and warp_in <= 0.0 and stun <= 0.0 and thrown <= 0.0


## SYSTEM UPDATE: faster (stacks up to SYSTEM_UPDATE_MAX).
func system_update() -> void:
	if exploding:
		return
	speed_mult = minf(speed_mult * LevelConfig.SYSTEM_UPDATE_MULT, LevelConfig.SYSTEM_UPDATE_MAX)
	_updated_flash = 0.6


# ------------------------------------------------------------------ damage API

func receive_whip(source_position: Vector2, _force: float = 0.0) -> void:
	_hit(source_position)


func fire_damage() -> void:
	_hit(global_position + Vector2(0, 20))


func receive_swing(source_position: Vector2, _push: float, _stagger: float) -> void:
	_hit(source_position)


## GRAB: a programmed sheep is flung (splits on landing, hurts Huval if it
## hits him); a micro sheep just pops.
func receive_throw(direction: Vector2, force: float) -> void:
	if exploding:
		return
	if kind == "micro":
		_hit(global_position - direction * 10.0)
		return
	var d := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	velocity = d * maxf(force, 420.0)
	thrown = 0.45
	stun = 0.0


func _hit(from_pos: Vector2) -> void:
	if exploding:
		return
	if kind == "robo":
		split(from_pos, true)
	else:
		pop(true)


## Programmed sheep -> MICRO_SPLIT micro sheep fanning away from the hit.
func split(from_pos: Vector2, by_player: bool) -> void:
	if exploding:
		return
	exploding = true
	remove_from_group("whippable")
	remove_from_group("sheep")
	var away := from_pos.direction_to(global_position)
	if away.length_squared() < 0.0001:
		away = Vector2.UP
	var n := LevelConfig.MICRO_SPLIT
	if level != null and is_instance_valid(level) and level.has_method("micro_room"):
		n = mini(n, level.micro_room())
	var parent := get_parent()
	for i in n:
		var m := RoboSheep.new()
		m.kind = "micro"
		m.level = level
		m.arena = arena
		m.speed = LevelConfig.MICRO_SPEED
		m.speed_mult = speed_mult
		var a := (float(i) - (n - 1) * 0.5) * 0.9
		m.velocity = away.rotated(a) * 240.0
		parent.add_child(m)
		m.global_position = global_position + away.rotated(a) * 14.0
		if level != null and is_instance_valid(level) and level.has_method("_on_micro_spawned"):
			level._on_micro_spawned(m)
	Sfx.play(self, "split", -8.0, rng.randf_range(0.95, 1.08))
	popped.emit(kind, by_player)
	_burst()
	queue_free()


func pop(by_player: bool) -> void:
	if exploding:
		return
	exploding = true
	remove_from_group("whippable")
	remove_from_group("sheep")
	Sfx.play(self, "pop", -10.0 if by_player else -16.0, rng.randf_range(1.15, 1.35))
	popped.emit(kind, by_player)
	_burst()
	queue_free()


func _burst() -> void:
	var host: Node = level.fx_layer if level != null and is_instance_valid(level) and "fx_layer" in level and level.fx_layer != null else get_parent()
	if kind == "robo":
		WoolBurst.spawn(host, global_position + Vector2(0, -8), Color(0.62, 0.72, 0.86), Color(0.35, 0.95, 1.0), 1.0)
	else:
		WoolBurst.spawn(host, global_position + Vector2(0, -4), Color(0.9, 0.45, 1.0), Color(0.75, 1.0, 0.35), 0.55, false)


# ------------------------------------------------------------------ movement

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null


func _physics_process(delta: float) -> void:
	if exploding:
		return
	_t += delta
	_updated_flash = maxf(_updated_flash - delta, 0.0)
	if warp_in > 0.0:
		warp_in -= delta
		_spr.visible = int(_t * 30.0) % 2 == 0 or warp_in <= 0.0
		_animate(Vector2.DOWN)
		queue_redraw()
		return
	_spr.visible = true
	if kind == "micro":
		life -= delta
		if life <= 0.0:
			pop(false)
			return
	if thrown > 0.0:
		thrown -= delta
		global_position += velocity * delta
		velocity *= pow(0.25, delta)
		_check_thrown_into_boss()
		if thrown <= 0.0 or not arena.grow(-4.0).has_point(global_position):
			split(global_position + velocity.normalized() * 10.0 if velocity.length() > 1.0 else global_position + Vector2.DOWN, true)
		queue_redraw()
		return
	var p := _player()
	if stun > 0.0:
		stun -= delta
		global_position += velocity * delta
		velocity *= pow(0.05, delta)
	elif p != null:
		var want := global_position.direction_to(p.global_position)
		var cur := velocity.normalized() if velocity.length() > 1.0 else want
		var ang := cur.angle_to(want)
		var step := clampf(ang, -turn * delta, turn * delta)
		var dir := cur.rotated(step)
		var spd := speed * speed_mult
		velocity = velocity.lerp(dir * spd, minf(delta * 6.0, 1.0))
		global_position += velocity * delta
	# stay in the arena (slide along the walls)
	var c := Vector2(clampf(global_position.x, arena.position.x, arena.end.x), clampf(global_position.y, arena.position.y, arena.end.y))
	if c != global_position:
		if c.x != global_position.x:
			velocity.x = -velocity.x * 0.3
		if c.y != global_position.y:
			velocity.y = -velocity.y * 0.3
		global_position = c
	_separate()
	if p != null and is_dangerous():
		if global_position.distance_to(p.global_position) <= hit_radius():
			_bite(p)
	_animate(velocity)
	queue_redraw()


## Keep a pack from stacking into one blob (cheap pairwise push).
func _separate() -> void:
	var grp := "robo_sheep" if kind == "robo" else "micro_sheep"
	var min_d := 30.0 if kind == "robo" else 16.0
	for o in get_tree().get_nodes_in_group(grp):
		if o == self or not is_instance_valid(o):
			continue
		var d: Vector2 = global_position - (o as Node2D).global_position
		var l := d.length()
		if l < min_d and l > 0.01:
			global_position += d / l * (min_d - l) * 0.5


func _bite(p: Node2D) -> void:
	if level == null or not is_instance_valid(level):
		return
	if kind == "robo":
		if level.has_method("robo_hit_player") and level.robo_hit_player(self):
			velocity = p.global_position.direction_to(global_position) * 260.0
			stun = LevelConfig.ROBO_BUMP_STUN
	else:
		if level.has_method("micro_hit_player") and level.micro_hit_player(self):
			pop(false)


func _check_thrown_into_boss() -> void:
	for b in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b) or ("exploding" in b and b.exploding):
			continue
		if global_position.distance_to((b as Node2D).global_position + Vector2(0, -10)) < 46.0:
			if b.has_method("take_hit") and b.take_hit(1, "feedback", global_position):
				if level != null and is_instance_valid(level) and level.has_method("spawn_score_popup"):
					level.spawn_score_popup("FEEDBACK LOOP!", (b as Node2D).global_position + Vector2(0, -90), Color(0.4, 1.0, 1.0), 2)
			split(global_position, true)
			return


func _animate(v: Vector2) -> void:
	var row := 0
	if absf(v.x) > absf(v.y):
		row = 1 if v.x < 0.0 else 2
	else:
		row = 3 if v.y < 0.0 else 0
	var fps := 10.0 if kind == "robo" else 16.0
	_spr.frame = row * 6 + int(_t * fps) % 6
	var flash := _updated_flash > 0.0 and int(_t * 20.0) % 2 == 0
	if flash:
		_spr.modulate = Color(2.2, 2.2, 2.6)
	elif kind == "micro" and life < 1.5 and int(_t * 12.0) % 2 == 0:
		_spr.modulate = Color(1, 1, 1, 0.35)
	elif speed_mult > 1.01:
		_spr.modulate = Color(1.15, 1.0, 1.0) if kind == "robo" else Color(1.1, 1.0, 1.1)
	else:
		_spr.modulate = Color(1, 1, 1)


func _draw() -> void:
	if warp_in > 0.0:
		# spawn-in glitch: a few offset scanline bars
		var r := 22.0 if kind == "robo" else 12.0
		for i in 4:
			var y := -r + i * r * 0.6 + sin(_t * 40.0 + i) * 3.0
			var w := r * (1.0 + 0.6 * sin(_t * 33.0 + i * 2.0))
			draw_rect(Rect2(Vector2(-w, y - 8.0), Vector2(w * 2.0, 3.0)), Color(0.3, 1.0, 1.0, 0.7) if kind == "robo" else Color(1.0, 0.4, 1.0, 0.7))
	elif kind == "robo":
		# glowing antenna tip + eye glow halo
		var tip := Vector2(0, -42) + Vector2(sin(_t * 6.0) * 1.5, 0)
		draw_circle(tip, 3.5, Color(0.06, 0.03, 0.08))
		draw_circle(tip, 2.5, Color(1.0, 0.25, 0.3) if int(_t * 3.0) % 2 == 0 else Color(0.4, 1.0, 1.0))
		draw_line(Vector2(0, -30), tip, Color(0.75, 0.8, 0.9), 1.5)
	if speed_mult > 1.01 and not exploding:
		# "updated" speed streaks behind it
		var back := -velocity.normalized() if velocity.length() > 1.0 else Vector2.UP
		var s := 1.0 if kind == "robo" else 0.6
		for i in 3:
			var o := back.orthogonal() * (i - 1) * 7.0 * s
			draw_line(o + back * 18.0 * s + Vector2(0, -10 * s), o + back * (30.0 + 6.0 * i) * s + Vector2(0, -10 * s), Color(0.5, 1.0, 1.0, 0.55), 2.0)
