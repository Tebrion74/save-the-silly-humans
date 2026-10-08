class_name HuvalYarheyhey
extends CharacterBody2D
## Build 016 boss 2: HUVAL YARHEYHEY, PROPHET OF THE ALGORITHM. An invented,
## good-natured cartoon parody of a generic futurist lecturer (shiny bald dome,
## round glasses, smug half-smile, dark sweater, headset mic, presentation
## clicker, a tablet of DATA). Art: tools/gen_boss2.py -> assets/boss2/huval_96.png.
##
## 12 hearts (LevelConfig.BOSS2_HEARTS). Same hit rules as Trustin Judeau:
##   WHIP crack / WHIP SHOT bolt / a lash that connects with SHOCKWAVE: 1 heart
##   FIRE WHIP: +1 delayed heart, at most once per BOSS_FIRE_COOLDOWN
##   GRAB / CAM SWING: shove + stagger (can cancel a wind-up, with cooldown)
##   MSM CAM REC: he LECTURES to the camera (stops, cancels a wind-up) up to
##                BOSS2_LECTURE_MAX, then camera-shy for BOSS_POSE_COOLDOWN
##   Touching him: 1 heart (huval_level.gd / boss_level.gd contact check)
## His weapon is PROGRAMMED SHEEP (robo_sheep.gd). Every summon is telegraphed:
## he raises the clicker ("!" + red LED beam), and a glitchy spawn ring shows
## at every spot a sheep will appear (never closer than BOSS2_SPAWN_MIN_DIST
## to you) for BOSS2_SUMMON_TELL seconds.
## Phases (hearts left): 12-9 summon 1 / 8-6 summon 2 + LECTURE RAY /
## 5-3 + SYSTEM UPDATE (all sheep faster) / 2-1 rage: summon 3, faster tells,
## TELEPORTS after hits and every few seconds. At 6 and 3 hearts he force-
## installs a SYSTEM UPDATE (1.5 s invulnerable "UPDATING..." shield).

signal hearts_changed(hearts: int, maximum: int)
signal took_hit(source: String)
signal defeated
signal summoned(sheep: Node)
signal system_updated(count: int)

const SHEET := preload("res://assets/boss2/huval_96.png")
## Same values as TrustinJudeau.S (boss_level.gd compares against those) + TELEPORT.
enum S { INTRO, MOVE, TELL_DASH, DASH, WINDUP, VOLLEY, RECOVER, POSE, STAGGER, DEFEATED, PHOTO_OP, TELEPORT }

const F_IDLE := 0
const F_WALK := 2
const F_WINDUP := 4
const F_CAST := 5
const F_LECTURE := 6
const F_HURT := 7
const F_DOWN := 8

var max_hearts: int = LevelConfig.BOSS2_HEARTS
var hearts: int = LevelConfig.BOSS2_HEARTS
var state: int = S.INTRO
var state_t := 0.0
var level: Node = null
var arena := Rect2(-600, -300, 1200, 640)
var invuln := 0.0
var exploding := false
var attack := ""
var attacks_fired: Dictionary = {}
var ai_enabled := true
var rng := RandomNumberGenerator.new()
## Spawn points chosen at the start of a summon wind-up (world coords).
var spawn_points: Array = []
var teleports := 0

var _aim := Vector2.RIGHT
var _aim_locked := false
var _ray_hit_done := false
var _flee := false
var _flee_pending := false
var _flee_cool := 0.0
var _fire_cool := 0.0
var _burn_t := -1.0
var _update_done: Dictionary = {}
var _gap := 1.2
var _dash_vel := Vector2.ZERO
var _strafe_sign := 1.0
var _strafe_flip := 3.0
var _push := Vector2.ZERO
var _wobble := 0.0
var _hurt_t := 0.0
var _cast_t := 0.0
var _pose_time := 0.0
var _since_filmed := 99.0
var _pose_cool := 0.0
var _interrupt_cool := 0.0
var _stagger := 0.0
var _tp_in := 4.0
var _tp_dest := Vector2.ZERO
var _last_attack := ""
var _t := 0.0
var _quip_ms := -100000
var _heavy_ms := -100000
var _shield_quip_ms := -100000
var _spr: Sprite2D


func _ready() -> void:
	add_to_group("boss")
	add_to_group("whippable")
	rng.randomize()
	collision_layer = 1 << 3
	collision_mask = (1 << 0) | (1 << 1)
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 20.0
	shape.shape = circ
	shape.position = Vector2(0, -6)
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.name = "Sprite"
	_spr.texture = SHEET
	_spr.hframes = 10
	_spr.position = Vector2(0, -48)
	add_child(_spr)
	_tp_in = rng.randf_range(LevelConfig.BOSS2_TELEPORT_EVERY.x, LevelConfig.BOSS2_TELEPORT_EVERY.y)


func phase() -> int:
	return LevelConfig.boss2_phase(hearts)


func is_defeated() -> bool:
	return state == S.DEFEATED


func state_name() -> String:
	return S.keys()[state]


## boss_level.gd contact check: no contact damage while he's teleporting.
func is_contact_active() -> bool:
	return state != S.TELEPORT


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null


func _set_state(s: int) -> void:
	state = s
	state_t = 0.0


# ------------------------------------------------------------------ damage API

func receive_whip(source_position: Vector2, _force: float = 0.0) -> void:
	take_hit(1, "whip", source_position)


func take_hit(amount: int, source: String, from_pos: Vector2) -> bool:
	if state == S.PHOTO_OP and hearts > 0:
		var now := Time.get_ticks_msec()
		if now - _shield_quip_ms > 900:
			_shield_quip_ms = now
			_quip(["PLEASE WAIT...", "DO NOT TURN OFF!", "INSTALLING..."][rng.randi_range(0, 2)], Color(0.6, 1.0, 1.0))
		return false
	if state == S.DEFEATED or hearts <= 0 or invuln > 0.0 or state == S.TELEPORT:
		return false
	hearts = maxi(hearts - amount, 0)
	invuln = LevelConfig.BOSS_IFRAMES
	_hurt_t = 0.28
	_wobble = 1.0
	var dir := from_pos.direction_to(global_position) if from_pos.distance_to(global_position) > 1.0 else Vector2.UP
	_push = dir * LevelConfig.BOSS_HIT_PUSH
	hearts_changed.emit(hearts, max_hearts)
	took_hit.emit(source)
	Sfx.play(self, "boss_hit", -8.0, rng.randf_range(1.0, 1.12))
	if state == S.POSE:
		_end_pose()
	if hearts <= 0:
		_defeat()
		return true
	if LevelConfig.BOSS2_UPDATE_HEARTS.has(hearts) and not _update_done.has(hearts):
		_update_done[hearts] = true
		_start_forced_update()
		return true
	if _flee_cool <= 0.0:
		_flee_pending = true
	if rng.randf() < 0.45:
		_quip(["CITATION NEEDED!", "FAKE NEWS!", "THAT'S NOT IN MY DATA!", "OUCH, HUMANLY!", "A MINOR GLITCH!"][rng.randi_range(0, 4)], Color(0.6, 1.0, 1.0))
	return true


func boss_ignite() -> bool:
	if state == S.DEFEATED:
		return false
	if _burn_t < 0.0 and _fire_cool <= 0.0:
		_burn_t = LevelConfig.BOSS_FIRE_DELAY
		_fire_cool = LevelConfig.BOSS_FIRE_COOLDOWN
	return true


func is_burning() -> bool:
	return _burn_t >= 0.0


func receive_swing(source_position: Vector2, push: float, stagger: float) -> void:
	if state == S.DEFEATED or state == S.TELEPORT:
		return
	var dir := source_position.direction_to(global_position)
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	_push = dir * push * LevelConfig.BOSS_SWING_PUSH_MULT
	_interrupt(maxf(stagger, LevelConfig.BOSS_STAGGER))


func receive_throw(direction: Vector2, _force: float) -> void:
	if state == S.DEFEATED or state == S.TELEPORT:
		return
	_push = direction.normalized() * LevelConfig.BOSS_GRAB_TUG
	_interrupt(LevelConfig.BOSS_STAGGER * 0.5)
	var now := Time.get_ticks_msec()
	if now - _heavy_ms > 1500:
		_heavy_ms = now
		_quip("I CONTAIN MULTITUDES!", Color(0.6, 0.9, 1.0))


## MSM Cam REC: he can't resist an audience - he LECTURES to the camera.
func cam_film(delta: float) -> void:
	if state == S.DEFEATED or state == S.INTRO or state == S.PHOTO_OP or state == S.TELEPORT:
		return
	_since_filmed = 0.0
	if state == S.POSE:
		_pose_time += delta
		return
	if _pose_cool > 0.0:
		return
	if (state == S.WINDUP or state == S.VOLLEY) and _interrupt_cool > 0.0:
		return
	_cancel_attack()
	_set_state(S.POSE)
	_pose_time = 0.0
	_interrupt_cool = LevelConfig.BOSS_INTERRUPT_COOLDOWN
	Sfx.play(self, "clicker", -8.0)
	_quip(["AS I WROTE IN CHAPTER 9...", "SAPIENS, LISTEN UP!", "NEXT SLIDE PLEASE!"][rng.randi_range(0, 2)], Color(1.0, 0.6, 0.85))


func is_posing() -> bool:
	return state == S.POSE


func is_lecturing() -> bool:
	return state == S.POSE


func is_photo_op() -> bool:
	return state == S.PHOTO_OP


func is_updating() -> bool:
	return state == S.PHOTO_OP


func _end_pose() -> void:
	_pose_cool = LevelConfig.BOSS_POSE_COOLDOWN
	_set_state(S.MOVE)
	_gap = maxf(_gap, 0.7)


func _interrupt(t: float) -> void:
	var attacking := state == S.WINDUP or state == S.VOLLEY
	if state == S.INTRO or state == S.DEFEATED or state == S.PHOTO_OP:
		return
	if attacking and _interrupt_cool > 0.0:
		return
	if attacking:
		_interrupt_cool = LevelConfig.BOSS_INTERRUPT_COOLDOWN
	if state == S.POSE:
		_pose_cool = LevelConfig.BOSS_POSE_COOLDOWN
	_cancel_attack()
	_stagger = t
	_set_state(S.STAGGER)


func _cancel_attack() -> void:
	attack = ""
	spawn_points.clear()
	_aim_locked = false


func _quip(text: String, col: Color) -> void:
	var now := Time.get_ticks_msec()
	if now - _quip_ms < 700:
		return
	_quip_ms = now
	if level != null and is_instance_valid(level) and level.has_method("spawn_score_popup"):
		level.spawn_score_popup(text, global_position + Vector2(0, -78), col, 2)


func _defeat() -> void:
	_cancel_attack()
	_set_state(S.DEFEATED)
	exploding = true
	remove_from_group("whippable")
	_burn_t = -1.0
	invuln = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = 0
	Sfx.play(self, "defeat", -6.0)
	_quip("ERROR 404: PROPHECY NOT FOUND", Color(0.6, 1.0, 1.0))
	defeated.emit()


## 6 and 3 hearts: a forced SYSTEM UPDATE (invulnerable, speeds up his sheep).
func _start_forced_update() -> void:
	_cancel_attack()
	_set_state(S.PHOTO_OP)
	invuln = LevelConfig.BOSS2_UPDATE_TIME
	_flee_pending = true
	Sfx.play(self, "update", -6.0)
	_quip("UPDATING...", Color(0.5, 1.0, 1.0))
	_apply_system_update()


func _apply_system_update() -> int:
	var n := 0
	for g in ["robo_sheep", "micro_sheep"]:
		for s in get_tree().get_nodes_in_group(g):
			if is_instance_valid(s) and not s.exploding and s.has_method("system_update"):
				s.system_update()
				n += 1
	system_updated.emit(n)
	return n


# ------------------------------------------------------------------ AI

func _physics_process(delta: float) -> void:
	_t += delta
	state_t += delta
	invuln = maxf(invuln - delta, 0.0)
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	_cast_t = maxf(_cast_t - delta, 0.0)
	_wobble = maxf(_wobble - delta * 2.5, 0.0)
	_pose_cool = maxf(_pose_cool - delta, 0.0)
	_interrupt_cool = maxf(_interrupt_cool - delta, 0.0)
	_fire_cool = maxf(_fire_cool - delta, 0.0)
	_flee_cool = maxf(_flee_cool - delta, 0.0)
	_since_filmed += delta
	if _burn_t >= 0.0:
		_burn_t -= delta
		if _burn_t <= 0.0:
			if invuln > 0.0 or state == S.TELEPORT:
				_burn_t = invuln + 0.05
			elif take_hit(1, "fire", global_position + Vector2(0, 30)):
				_burn_t = -1.0
				_quip("MY SLIDES ARE ON FIRE!", Color(1.0, 0.55, 0.2))
			else:
				_burn_t = -1.0
	var p := _player()
	var want := Vector2.ZERO
	if state == S.DEFEATED:
		_push = _push.lerp(Vector2.ZERO, minf(delta * LevelConfig.SWING_PUSH_DAMPING, 1.0))
		velocity = _push
		move_and_slide()
		_clamp_arena()
		_animate()
		queue_redraw()
		return
	if ai_enabled and p != null:
		want = _think(delta, p)
	velocity = want + _push
	_push = _push.lerp(Vector2.ZERO, minf(delta * LevelConfig.SWING_PUSH_DAMPING, 1.0))
	if _push.length() < 4.0:
		_push = Vector2.ZERO
	move_and_slide()
	if _clamp_arena() and state == S.MOVE:
		_strafe_sign = -_strafe_sign
	_animate()
	queue_redraw()


func _clamp_arena() -> bool:
	var c := _clamp_to_arena(global_position)
	if c != global_position:
		global_position = c
		return true
	return false


func _clamp_to_arena(v: Vector2) -> Vector2:
	return Vector2(clampf(v.x, arena.position.x, arena.end.x), clampf(v.y, arena.position.y, arena.end.y))


func live_robo_count() -> int:
	var n := 0
	for s in get_tree().get_nodes_in_group("robo_sheep"):
		if is_instance_valid(s) and not s.exploding:
			n += 1
	return n


func _think(delta: float, p: Node2D) -> Vector2:
	var to := p.global_position - global_position
	var dist := to.length()
	var radial := to / dist if dist > 1.0 else Vector2.DOWN
	match state:
		S.INTRO:
			if state_t >= LevelConfig.BOSS_INTRO_TIME:
				_set_state(S.MOVE)
				_gap = 0.5
			return Vector2.ZERO
		S.MOVE:
			_gap -= delta
			_strafe_flip -= delta
			if phase() >= 4:
				_tp_in -= delta
			if _strafe_flip <= 0.0:
				_strafe_flip = rng.randf_range(2.0, 4.0)
				_strafe_sign = -_strafe_sign
			if _flee_pending:
				_flee_pending = false
				if phase() >= 4:
					_start_teleport(p)
				else:
					_flee = true
					_set_state(S.TELL_DASH)
				return Vector2.ZERO
			if phase() >= 4 and _tp_in <= 0.0 and _gap > 0.4:
				_start_teleport(p)
				return Vector2.ZERO
			if _gap <= 0.0:
				_start_windup(p)
				return Vector2.ZERO
			var spd := LevelConfig.BOSS2_SPEED_RAGE if phase() >= 4 else LevelConfig.BOSS2_SPEED
			var tangent := radial.orthogonal() * _strafe_sign
			if dist > LevelConfig.BOSS2_PREF_DIST + 60.0:
				return (radial * 0.8 + tangent * 0.5).normalized() * spd
			if dist < LevelConfig.BOSS2_RETREAT_DIST:
				return (-radial * 0.9 + tangent * 0.4).normalized() * spd * LevelConfig.BOSS2_RETREAT_MULT
			return (tangent + radial * clampf((dist - LevelConfig.BOSS2_PREF_DIST) / 120.0, -0.6, 0.6)).normalized() * spd
		S.TELL_DASH:
			_gap -= delta
			if state_t >= LevelConfig.BOSS_FLEE_TELL:
				var side := radial.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
				var dir := (side * 0.75 - radial * 0.75).normalized()
				var dest := global_position + dir * LevelConfig.BOSS_DASH_SPEED * LevelConfig.BOSS_DASH_TIME
				if not arena.grow(-20.0).has_point(dest):
					dir = Vector2(-dir.x, dir.y)
					if not arena.grow(-20.0).has_point(global_position + dir * LevelConfig.BOSS_DASH_SPEED * LevelConfig.BOSS_DASH_TIME):
						dir = -side
				_dash_vel = dir * LevelConfig.BOSS_DASH_SPEED
				_set_state(S.DASH)
			return Vector2.ZERO
		S.DASH:
			_gap -= delta
			if state_t >= LevelConfig.BOSS_DASH_TIME:
				_set_state(S.MOVE)
				_flee_cool = LevelConfig.BOSS_FLEE_COOLDOWN
				_gap = minf(_gap, 0.45)
				_flee = false
			return _dash_vel
		S.TELEPORT:
			if state_t >= LevelConfig.BOSS2_TELEPORT_TELL:
				global_position = _tp_dest
				_set_state(S.MOVE)
				_flee_cool = LevelConfig.BOSS_FLEE_COOLDOWN
				_gap = minf(_gap, 0.5)
				_tp_in = rng.randf_range(LevelConfig.BOSS2_TELEPORT_EVERY.x, LevelConfig.BOSS2_TELEPORT_EVERY.y)
				Sfx.play(self, "teleport", -8.0, 1.25)
			return Vector2.ZERO
		S.WINDUP:
			var tell := tell_time()
			if attack == "ray" and not _aim_locked:
				_aim = radial
				if state_t >= tell - LevelConfig.BOSS2_RAY_LOCK:
					_aim_locked = true
			if state_t >= tell:
				_fire(p)
			return Vector2.ZERO
		S.VOLLEY:   # the lecture ray is live
			if not _ray_hit_done and _ray_hits(p.global_position):
				_ray_hit_done = true
				if level != null and is_instance_valid(level) and level.has_method("ray_hit_player"):
					level.ray_hit_player(global_position)
			if state_t >= LevelConfig.BOSS2_RAY_TIME:
				_after_attack()
			return Vector2.ZERO
		S.RECOVER:
			if state_t >= 0.25:
				_set_state(S.MOVE)
			return Vector2.ZERO
		S.POSE:
			if _since_filmed > LevelConfig.BOSS_POSE_LINGER or _pose_time > LevelConfig.BOSS2_LECTURE_MAX:
				_end_pose()
			return Vector2.ZERO
		S.STAGGER:
			if state_t >= _stagger:
				_set_state(S.MOVE)
				_gap = maxf(_gap, 0.6)
			return Vector2.ZERO
		S.PHOTO_OP:
			if state_t >= LevelConfig.BOSS2_UPDATE_TIME:
				_set_state(S.MOVE)
				_gap = maxf(_gap, 0.4)
			return Vector2.ZERO
	return Vector2.ZERO


func tell_time() -> float:
	var i := phase() - 1
	match attack:
		"ray":
			return float(LevelConfig.BOSS2_RAY_TELL[i])
		"update":
			return 0.55
	return float(LevelConfig.BOSS2_SUMMON_TELL[i])


func choose_attack() -> String:
	var w: Dictionary = (LevelConfig.BOSS2_ATTACKS[phase() - 1] as Dictionary).duplicate()
	var cap: int = LevelConfig.BOSS2_SHEEP_CAP[phase() - 1]
	if live_robo_count() >= cap:
		w.erase("summon")
	var live_total := live_robo_count() + get_tree().get_nodes_in_group("micro_sheep").size()
	if w.has("update") and (live_total < 2 or _last_attack == "update"):
		w.erase("update")
	if w.is_empty():
		return ""
	var total := 0
	for k in w:
		total += int(w[k])
	var roll := rng.randi_range(1, total)
	for k in w:
		roll -= int(w[k])
		if roll <= 0:
			return k
	return "summon"


func _start_windup(p: Node2D, forced: String = "") -> void:
	attack = forced if forced != "" else choose_attack()
	if attack == "":
		_gap = 0.5    # field is full and no ray yet: walk a bit, try again
		return
	_aim = global_position.direction_to(p.global_position)
	_aim_locked = false
	spawn_points.clear()
	if attack == "summon":
		var cap: int = LevelConfig.BOSS2_SHEEP_CAP[phase() - 1]
		var n := mini(int(LevelConfig.BOSS2_SUMMON_COUNT[phase() - 1]), maxi(cap - live_robo_count(), 1))
		spawn_points = pick_spawn_points(p.global_position, n)
		Sfx.play(self, "clicker", -6.0)
		Sfx.play(self, "spawn_glitch", -10.0)
	elif attack == "ray":
		Sfx.play(self, "windup", -12.0, 0.8)
	else:
		Sfx.play(self, "clicker", -6.0, 0.8)
		_quip("INSTALLING UPDATE...", Color(0.5, 1.0, 1.0))
	_set_state(S.WINDUP)


## Tests / screenshots / bots.
func force_attack(kind: String) -> void:
	var p := _player()
	if p != null and state != S.DEFEATED:
		_start_windup(p, kind)


## Spawn spots: around him (his side of the field), never within
## BOSS2_SPAWN_MIN_DIST of the rancher, spread apart from each other.
func pick_spawn_points(player_pos: Vector2, n: int) -> Array:
	var out: Array = []
	var inner := arena.grow(-30.0)
	for i in n:
		var best := Vector2.ZERO
		var best_score := -INF
		for tries in 14:
			var a := rng.randf() * TAU
			var r := rng.randf_range(60.0, 150.0)
			var c := _clamp_rect(global_position + Vector2(cos(a) * r, sin(a) * r * 0.7), inner)
			var dp := c.distance_to(player_pos)
			var sep := 999.0
			for o in out:
				sep = minf(sep, c.distance_to(o))
			var score := minf(dp - LevelConfig.BOSS2_SPAWN_MIN_DIST, 60.0) + minf(sep, 80.0) * 0.5
			if dp < LevelConfig.BOSS2_SPAWN_MIN_DIST:
				score -= 1000.0
			if score > best_score:
				best_score = score
				best = c
		if best.distance_to(player_pos) < LevelConfig.BOSS2_SPAWN_MIN_DIST:
			# boxed in: push it straight away from the rancher
			best = _clamp_rect(player_pos + player_pos.direction_to(best if best != player_pos else global_position) * (LevelConfig.BOSS2_SPAWN_MIN_DIST + 10.0), inner)
		out.append(best)
	return out


static func _clamp_rect(v: Vector2, r: Rect2) -> Vector2:
	return Vector2(clampf(v.x, r.position.x, r.end.x), clampf(v.y, r.position.y, r.end.y))


func _fire(p: Node2D) -> void:
	_last_attack = attack
	attacks_fired[attack] = int(attacks_fired.get(attack, 0)) + 1
	_cast_t = 0.3
	match attack:
		"summon":
			for sp in spawn_points:
				_spawn_robo(sp)
			spawn_points.clear()
			if rng.randf() < 0.35:
				_quip(["BEHOLD: SHEEP 2.0!", "THE FLOCK IS THE ALGORITHM!", "RESISTANCE IS STATISTICAL!", "UPGRADED LIVESTOCK!"][rng.randi_range(0, 3)], Color(0.5, 1.0, 1.0))
		"ray":
			_ray_hit_done = false
			_set_state(S.VOLLEY)
			Sfx.play(self, "ray", -6.0)
			if _ray_hits(p.global_position):
				_ray_hit_done = true
				if level != null and is_instance_valid(level) and level.has_method("ray_hit_player"):
					level.ray_hit_player(global_position)
			return
		"update":
			Sfx.play(self, "update", -6.0)
			var n := _apply_system_update()
			_quip("SYSTEM UPDATE! (%d)" % n, Color(0.5, 1.0, 1.0))
	_after_attack()


func _ray_hits(pos: Vector2) -> bool:
	var origin := global_position + Vector2(0, -40)
	var rel := pos + Vector2(0, -12) - origin
	var along := rel.dot(_aim)
	if along < 0.0 or along > LevelConfig.BOSS2_RAY_LENGTH:
		return false
	return absf(rel.dot(_aim.orthogonal())) <= LevelConfig.BOSS2_RAY_WIDTH


func _spawn_robo(at: Vector2) -> Node:
	var s := RoboSheep.new()
	s.kind = "robo"
	s.level = level
	s.arena = arena.grow(30.0)
	s.speed = float(LevelConfig.ROBO_SPEED[phase() - 1])
	var parent: Node = level.get_node("Entities") if level != null and is_instance_valid(level) and level.get_node_or_null("Entities") != null else get_parent()
	parent.add_child(s)
	s.global_position = at
	summoned.emit(s)
	return s


func _after_attack() -> void:
	attack = ""
	_set_state(S.RECOVER)
	_gap = float(LevelConfig.BOSS2_ATTACK_GAP[phase() - 1])


func _start_teleport(p: Node2D) -> void:
	_cancel_attack()
	var inner := arena.grow(-40.0)
	var best := global_position
	var best_d := -1.0
	for i in 10:
		var c := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
		var d := c.distance_to(p.global_position)
		if d >= LevelConfig.BOSS2_TELEPORT_MIN_DIST and d <= LevelConfig.BOSS2_TELEPORT_MIN_DIST + 220.0:
			best = c
			break
		if d > best_d:
			best_d = d
			best = c
	_tp_dest = best
	teleports += 1
	invuln = maxf(invuln, LevelConfig.BOSS2_TELEPORT_TELL)
	_set_state(S.TELEPORT)
	Sfx.play(self, "teleport", -8.0)


# ------------------------------------------------------------------ look

func _animate() -> void:
	var p := _player()
	if p != null and state != S.DEFEATED:
		_spr.flip_h = p.global_position.x < global_position.x
	var f := F_IDLE + (int(_t * 2.0) % 2)
	_spr.scale = Vector2.ONE
	_spr.visible = true
	match state:
		S.INTRO:
			f = F_LECTURE if fmod(state_t, 1.4) < 0.9 else F_IDLE
		S.MOVE:
			f = F_WALK + (int(_t * 6.0) % 2) if velocity.length() > 20.0 else f
		S.TELL_DASH:
			_spr.scale = Vector2(1.08, 0.9)
		S.DASH:
			f = F_WALK
			_spr.scale = Vector2(0.92, 1.06)
		S.WINDUP:
			f = F_WINDUP if attack != "ray" else F_CAST
		S.VOLLEY:
			f = F_CAST
		S.POSE:
			f = F_LECTURE
		S.PHOTO_OP:
			f = F_WINDUP if fmod(state_t, 0.4) < 0.2 else F_LECTURE
		S.TELEPORT:
			f = F_WINDUP
			_spr.visible = int(state_t * 40.0) % 3 != 0
			_spr.scale = Vector2(1.0 + 0.4 * state_t / LevelConfig.BOSS2_TELEPORT_TELL, 1.0 - 0.3 * state_t / LevelConfig.BOSS2_TELEPORT_TELL)
		S.STAGGER:
			f = F_HURT
		S.DEFEATED:
			f = F_DOWN + (int(_t * 3.0) % 2) if state_t > 0.5 else F_HURT
	if _cast_t > 0.0 and state != S.DEFEATED and state != S.VOLLEY:
		f = F_CAST
	elif _hurt_t > 0.0 and state != S.DEFEATED:
		f = F_HURT
	_spr.frame = f
	_spr.position = Vector2(0, -48.0 * _spr.scale.y)
	var wob := sin(_t * 28.0) * 0.16 * _wobble
	if state == S.DEFEATED:
		wob = sin(state_t * 10.0) * 0.25 * maxf(0.0, 1.0 - state_t / 1.2)
		if state_t < 0.45:
			_spr.position.y -= sin(state_t / 0.45 * PI) * 30.0
	_spr.rotation = wob
	# glitch jitter while teleporting / updating
	if state == S.TELEPORT or (state == S.PHOTO_OP and int(_t * 15.0) % 4 == 0):
		_spr.position.x += rng.randf_range(-4.0, 4.0)
	if state == S.PHOTO_OP:
		_spr.modulate = Color(0.9, 1.25, 1.4)
	elif state == S.TELEPORT:
		_spr.modulate = Color(0.6, 1.4, 1.6, 0.8)
	elif invuln > 0.0 and state != S.DEFEATED:
		_spr.modulate = Color(3.0, 3.0, 3.0, 1.0) if fmod(invuln, 0.12) > 0.06 else Color(1, 1, 1, 0.75)
	elif state == S.POSE:
		_spr.modulate = Color(1.12, 1.12, 1.12)
	else:
		_spr.modulate = Color(1, 1, 1, 1)


func _draw() -> void:
	var cyan := Color(0.35, 1.0, 1.0)
	if state == S.WINDUP:
		var tell := tell_time()
		var k := clampf(state_t / tell, 0.0, 1.0)
		match attack:
			"summon":
				# glitchy spawn rings where the programmed sheep will appear
				for sp in spawn_points:
					var c := to_local(sp)
					var r := 30.0 - 8.0 * k
					_ring(c, Vector2(r, r * 0.55), Color(cyan.r, cyan.g, cyan.b, 0.4 + 0.5 * k), 3.0)
					_ring(c, Vector2(r * 0.6, r * 0.33), Color(1, 1, 1, 0.3 + 0.5 * k), 2.0)
					for g in 3:
						var gx := sin(_t * 37.0 + g * 2.3) * r
						var gy := -10.0 - g * 9.0 + cos(_t * 23.0 + g) * 4.0
						draw_rect(Rect2(c + Vector2(gx - 7.0, gy), Vector2(14.0, 3.0)), Color(cyan.r, cyan.g, cyan.b, 0.7 * k + 0.2))
				# red LED beam up from the clicker
				var tip := Vector2(28.0 * (-1.0 if _spr.flip_h else 1.0), -112.0)
				draw_line(tip, tip + Vector2(0, -16.0 - 8.0 * k), Color(1.0, 0.3, 0.35, 0.9), 3.0)
			"ray":
				var col := Color(1.0, 0.3, 0.8, 0.3 + 0.55 * k)
				var o := Vector2(0, -40)
				_dash_line(o, o + _aim * (220.0 + 200.0 * k), col, 3.0 if not _aim_locked else 4.0)
			"update":
				var rr := 30.0 + 50.0 * k
				_ring(Vector2(0, -46), Vector2(rr, rr * 0.8), Color(cyan.r, cyan.g, cyan.b, 0.6), 2.0)
		var bang := Vector2(0, -122 - 3.0 * sin(_t * 20.0))
		draw_rect(Rect2(bang + Vector2(-5, -18), Vector2(10, 26)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(bang + Vector2(-3, -16), Vector2(6, 14)), Color(0.4, 1.0, 1.0))
		draw_rect(Rect2(bang + Vector2(-3, 1), Vector2(6, 5)), Color(0.4, 1.0, 1.0))
	if state == S.VOLLEY:
		# the LECTURE RAY: a thick magenta/white beam of "knowledge"
		var o := Vector2(0, -40)
		var e := o + _aim * LevelConfig.BOSS2_RAY_LENGTH
		var fade := 1.0 - state_t / LevelConfig.BOSS2_RAY_TIME
		draw_line(o, e, Color(0.06, 0.03, 0.08, 0.6 * fade), LevelConfig.BOSS2_RAY_WIDTH * 2.0 + 4.0)
		draw_line(o, e, Color(1.0, 0.3, 0.8, 0.85 * fade), LevelConfig.BOSS2_RAY_WIDTH * 1.6)
		draw_line(o, e, Color(1.0, 0.95, 1.0, fade), LevelConfig.BOSS2_RAY_WIDTH * 0.6)
		for i in 6:
			var t := fmod(_t * 3.0 + i / 6.0, 1.0)
			var pnt := o.lerp(e, t)
			draw_rect(Rect2(pnt + _aim.orthogonal() * 10.0 * sin(_t * 30.0 + i) - Vector2(4, 4), Vector2(8, 8)), Color(1, 1, 1, fade))
	if state == S.TELEPORT:
		var k := state_t / LevelConfig.BOSS2_TELEPORT_TELL
		var c := to_local(_tp_dest)
		_ring(c, Vector2(36, 20) * (1.2 - 0.4 * k), Color(cyan.r, cyan.g, cyan.b, 0.5 + 0.4 * k), 3.0)
		for g in 4:
			draw_rect(Rect2(c + Vector2(sin(_t * 29.0 + g) * 26.0 - 8.0, -14.0 - g * 16.0), Vector2(16.0, 3.0)), Color(cyan.r, cyan.g, cyan.b, 0.6))
	if state == S.PHOTO_OP:
		# "UPDATING..." shield: a cyan code ring + progress bar
		var a := 0.35 + 0.2 * sin(_t * 14.0)
		_ring(Vector2(0, -46), Vector2(48, 64), Color(0.35, 1.0, 1.0, a + 0.3), 3.0)
		_ring(Vector2(0, -46), Vector2(42, 57), Color(1, 1, 1, a), 2.0)
		var prog := clampf(state_t / LevelConfig.BOSS2_UPDATE_TIME, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-34, -132), Vector2(68, 10)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(Vector2(-32, -130), Vector2(64 * prog, 6)), cyan)
		for i in 5:
			var ang := _t * 3.0 + i * TAU / 5.0
			var c := Vector2(cos(ang) * 46.0, -46.0 + sin(ang) * 60.0)
			draw_string(ThemeDB.fallback_font, c, "01"[i % 2], HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.6, 1.0, 1.0, 0.9))
	if state == S.POSE:
		# holographic DATA panel he lectures from
		var side := -1.0 if _spr.flip_h else 1.0
		var base := Vector2(side * 58.0 - 26.0, -118.0)
		draw_rect(Rect2(base, Vector2(52, 34)), Color(0.2, 0.9, 1.0, 0.25))
		draw_rect(Rect2(base, Vector2(52, 34)), Color(0.4, 1.0, 1.0, 0.9), false, 2.0)
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(base + Vector2(5 + i * 8.5, 28 - i * 4.0 - 3.0 * sin(_t * 4.0 + i)))
		draw_polyline(pts, Color(1, 1, 1, 0.95), 2.0)
	if _burn_t >= 0.0:
		for i in 5:
			var ph := _t * 9.0 + i * 1.7
			var x := -20.0 + i * 10.0
			var h := 14.0 + 8.0 * absf(sin(ph))
			var base2 := Vector2(x, -20.0)
			draw_colored_polygon(PackedVector2Array([base2 + Vector2(-6, 0), base2 + Vector2(0, -h - 14), base2 + Vector2(6, 0)]), Color(1.0, 0.35, 0.05, 0.85))
			draw_colored_polygon(PackedVector2Array([base2 + Vector2(-3, 0), base2 + Vector2(0, -h - 3), base2 + Vector2(3, 0)]), Color(1.0, 0.9, 0.3, 0.95))
	if state == S.DEFEATED and state_t > 0.5:
		for i in 3:
			var ang := _t * 5.0 + i * TAU / 3.0
			var c := Vector2(cos(ang) * 30.0, -104.0 + sin(ang) * 8.0)
			_star(c, Color(0.5, 1.0, 1.0) if i != 1 else Color(1, 1, 1))


func _star(c: Vector2, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(-1.5, -6), Vector2(3, 12)), Color(0.06, 0.03, 0.08))
	draw_rect(Rect2(c + Vector2(-6, -1.5), Vector2(12, 3)), Color(0.06, 0.03, 0.08))
	draw_rect(Rect2(c + Vector2(-0.5, -5), Vector2(1.5, 10)), col)
	draw_rect(Rect2(c + Vector2(-5, -0.5), Vector2(10, 1.5)), col)


func _dash_line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	var n := int(d.length() / 14.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a + d * (float(i) / n), a + d * (float(i + 1) / n), col, w)
	var dir := d.normalized()
	draw_line(b, b - dir.rotated(0.5) * 12.0, col, w)
	draw_line(b, b - dir.rotated(-0.5) * 12.0, col, w)


func _ring(c: Vector2, r: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := float(i) / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, w)
