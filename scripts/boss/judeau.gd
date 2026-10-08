class_name TrustinJudeau
extends CharacterBody2D
## Build 015 boss: TRUSTIN JUDEAU, an invented, good-natured cartoon parody of
## a politician (big swoopy hair, toothy grin, sharp suit, maple-leaf pin and
## red maple-leaf socks). Art: tools/gen_boss.py -> assets/boss/judeau_96.png.
##
## 10 hearts (LevelConfig.BOSS_HEARTS). Every heart lost gives BOSS_IFRAMES
## (0.6 s) of invulnerability with a white flash + knock-back wobble.
## Weapon rules (see README "Build 015"):
##   WHIP crack / WHIP SHOT bolt  1 heart
##   SHOCKWAVE                    015b: no splash damage on him; only a lash
##                                that actually connects counts (1 heart)
##   FIRE WHIP                    +1 heart burn tick BOSS_FIRE_DELAY after the
##                                crack; 015b: at most once per BOSS_FIRE_COOLDOWN
##   GRAB                         too heavy to throw: a short tug + stagger
##   MSM CAM REC                  he POSES for the camera (no damage): stops,
##                                cancels a wind-up, then camera-shy for a while
##   MSM CAM SWING                shoves him back + stagger (no damage)
## GRAB / SWING / CAM can cancel a wind-up at most once per BOSS_INTERRUPT_COOLDOWN.
##
## Attacks escalate with the hearts left (LevelConfig.boss_phase):
##   phase 1 (10-8)  single aimed poutine
##   phase 2 (7-5)   + 3-way spread
##   phase 3 (4-3)   + 5-way spread, DOUBLE lob (on you + where you're heading),
##                   lob -> aimed-shot combos
##   phase 4 (2-1)   5-shot volley, radial burst of 14 with a 2-slot safe lane,
##                   double lobs, 5-way spreads, lob -> spread combos
## Every attack starts with a BOSS_WINDUP (0.4 s; 0.32 s in phase 4) wind-up:
## arm raised with a poutine, a "!" over his head and the aim line / ring.
## Build 015b also: contact damage (boss_level.gd), keeps his distance, dashes
## every 2-3 s, dash-strafes away right after a hit, and a 1.5 s invulnerable
## PHOTO OP wave when he drops to 5 and to 2 hearts.

signal hearts_changed(hearts: int, maximum: int)
signal took_hit(source: String)
signal defeated

const SHEET := preload("res://assets/boss/judeau_96.png")
enum S { INTRO, MOVE, TELL_DASH, DASH, WINDUP, VOLLEY, RECOVER, POSE, STAGGER, DEFEATED, PHOTO_OP }

const F_IDLE := 0
const F_WALK := 2
const F_WINDUP := 4
const F_THROW := 5
const F_POSE := 6
const F_HURT := 7
const F_DOWN := 8

var max_hearts: int = LevelConfig.BOSS_HEARTS
var hearts: int = LevelConfig.BOSS_HEARTS
var state: int = S.INTRO
var state_t := 0.0
var level: Node = null
## Walkable rectangle (world coords) he stays inside.
var arena := Rect2(-600, -300, 1200, 640)
var invuln := 0.0
## Whip / reticle code skips targets that are "exploding": true once defeated.
var exploding := false
var attack := ""
var attacks_fired: Dictionary = {}
## Tests / screenshots: freeze the AI (still hittable).
var ai_enabled := true
var rng := RandomNumberGenerator.new()

var _aim := Vector2.RIGHT
var _lob_target := Vector2.ZERO
var _lob_target2 := Vector2.ZERO
var _radial_off := 0.0
var _radial_gap_at := 0
var _combo_next := ""
var _flee := false
var _flee_pending := false
var _fire_cool := 0.0
var _flee_cool := 0.0
var _photo_done: Dictionary = {}
var _shield_quip_ms := -100000
var _aim_locked := false
var _gap := 1.2
var _dash_in := 4.0
var _dash_vel := Vector2.ZERO
var _strafe_sign := 1.0
var _strafe_flip := 3.0
var _push := Vector2.ZERO
var _wobble := 0.0
var _hurt_t := 0.0
var _throw_t := 0.0
var _pose_time := 0.0
var _since_filmed := 99.0
var _pose_cool := 0.0
var _interrupt_cool := 0.0
var _burn_t := -1.0
var _volley_left := 0
var _volley_t := 0.0
var _stagger := 0.0
var _last_attack := ""
var _t := 0.0
var _quip_ms := -100000
var _heavy_ms := -100000
var _spr: Sprite2D


func _ready() -> void:
	add_to_group("boss")
	add_to_group("whippable")
	rng.randomize()
	collision_layer = 1 << 3          # "Sheep" layer bit: the rancher bumps into him
	collision_mask = (1 << 0) | (1 << 1)
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 22.0
	shape.shape = circ
	shape.position = Vector2(0, -6)
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.name = "Sprite"
	_spr.texture = SHEET
	_spr.hframes = 10
	_spr.position = Vector2(0, -48)
	add_child(_spr)
	_dash_in = rng.randf_range(LevelConfig.BOSS_DASH_EVERY.x, LevelConfig.BOSS_DASH_EVERY.y)


func phase() -> int:
	return LevelConfig.boss_phase(hearts)


func is_defeated() -> bool:
	return state == S.DEFEATED


func state_name() -> String:
	return S.keys()[state]


func _player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	return p


func _set_state(s: int) -> void:
	state = s
	state_t = 0.0


# ------------------------------------------------------------------ damage API

## Whip crack, whip-shot bolt, shockwave (Whip calls receive_whip).
func receive_whip(source_position: Vector2, _force: float = 0.0) -> void:
	take_hit(1, "whip", source_position)


## Returns true if a heart was taken (false while invulnerable / defeated).
func take_hit(amount: int, source: String, from_pos: Vector2) -> bool:
	if state == S.PHOTO_OP and hearts > 0:
		var now := Time.get_ticks_msec()
		if now - _shield_quip_ms > 900:
			_shield_quip_ms = now
			_quip(["NO COMMENT!", "SMILE!", "NOT NOW, PRESS!"][rng.randi_range(0, 2)], Color(0.7, 0.95, 1.0))
		return false
	if state == S.DEFEATED or hearts <= 0 or invuln > 0.0:
		return false
	hearts = maxi(hearts - amount, 0)
	invuln = LevelConfig.BOSS_IFRAMES
	_hurt_t = 0.28
	_wobble = 1.0
	var dir := from_pos.direction_to(global_position) if from_pos.distance_to(global_position) > 1.0 else Vector2.UP
	_push = dir * LevelConfig.BOSS_HIT_PUSH
	hearts_changed.emit(hearts, max_hearts)
	took_hit.emit(source)
	Sfx.play(self, "boss_hit", -8.0, rng.randf_range(0.95, 1.08))
	if state == S.POSE:
		_end_pose()
	if hearts <= 0:
		_defeat()
		return true
	if LevelConfig.BOSS_PHOTO_OP_HEARTS.has(hearts) and not _photo_done.has(hearts):
		_photo_done[hearts] = true
		_start_photo_op()
		return true
	if _flee_cool <= 0.0:
		_flee_pending = true
	if rng.randf() < 0.45:
		_quip(["SORRY!", "OOF, EH?", "NOT THE HAIR!", "SUNNY WAYS!", "HEY, EASY!"][rng.randi_range(0, 4)], Color(1, 0.9, 0.5))
	return true


## FIRE WHIP (Burn.ignite hands bosses here): one delayed burn tick.
func boss_ignite() -> bool:
	if state == S.DEFEATED:
		return false
	if _burn_t < 0.0 and _fire_cool <= 0.0:
		_burn_t = LevelConfig.BOSS_FIRE_DELAY
		_fire_cool = LevelConfig.BOSS_FIRE_COOLDOWN
	return true


func is_burning() -> bool:
	return _burn_t >= 0.0


## MSM Cam SWING: shove + stagger (no damage).
func receive_swing(source_position: Vector2, push: float, stagger: float) -> void:
	if state == S.DEFEATED:
		return
	var dir := source_position.direction_to(global_position)
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	_push = dir * push * LevelConfig.BOSS_SWING_PUSH_MULT
	_interrupt(maxf(stagger, LevelConfig.BOSS_STAGGER))


## GRAB: too heavy to throw. Short tug toward the throw direction + stagger.
func receive_throw(direction: Vector2, _force: float) -> void:
	if state == S.DEFEATED:
		return
	_push = direction.normalized() * LevelConfig.BOSS_GRAB_TUG
	_interrupt(LevelConfig.BOSS_STAGGER * 0.5)
	var now := Time.get_ticks_msec()
	if now - _heavy_ms > 1500:
		_heavy_ms = now
		_quip("TOO HEAVY!", Color(0.6, 0.9, 1.0))


## MSM Cam REC: he can't resist a camera.
func cam_film(delta: float) -> void:
	if state == S.DEFEATED or state == S.INTRO or state == S.PHOTO_OP:
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
	Sfx.play(self, "pose", -10.0)
	_quip(["SAY POUTINE!", "MY GOOD SIDE!", "CHEESE CURDS!"][rng.randi_range(0, 2)], Color(1.0, 0.6, 0.85))


func is_posing() -> bool:
	return state == S.POSE


func _end_pose() -> void:
	_pose_cool = LevelConfig.BOSS_POSE_COOLDOWN
	_set_state(S.MOVE)
	_gap = maxf(_gap, 0.7)


## 015b PHOTO OP: invulnerable wave for the cameras, no attacks.
func _start_photo_op() -> void:
	_cancel_attack()
	_combo_next = ""
	_set_state(S.PHOTO_OP)
	invuln = LevelConfig.BOSS_PHOTO_OP_TIME
	_flee_pending = true
	Sfx.play(self, "shield", -8.0)
	_quip("PHOTO OP!", Color(0.7, 0.95, 1.0))


func is_photo_op() -> bool:
	return state == S.PHOTO_OP


func _interrupt(t: float) -> void:
	var attacking := state == S.WINDUP or state == S.VOLLEY
	if state == S.INTRO or state == S.DEFEATED or state == S.PHOTO_OP:
		return
	if attacking and _interrupt_cool > 0.0:
		return   # super armour: the push still lands, the attack doesn't stop
	if attacking:
		_interrupt_cool = LevelConfig.BOSS_INTERRUPT_COOLDOWN
	if state == S.POSE:
		_pose_cool = LevelConfig.BOSS_POSE_COOLDOWN
	_cancel_attack()
	_stagger = t
	_set_state(S.STAGGER)


func _cancel_attack() -> void:
	_combo_next = ""
	attack = ""
	_volley_left = 0
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
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps wobbling after the round freezes
	collision_layer = 0
	Sfx.play(self, "defeat", -6.0)
	_quip("SORRY! I'LL BE BACK... AFTER RECESS!", Color(1.0, 0.85, 0.4))
	defeated.emit()


# ------------------------------------------------------------------ AI

func _physics_process(delta: float) -> void:
	_t += delta
	state_t += delta
	invuln = maxf(invuln - delta, 0.0)
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	_throw_t = maxf(_throw_t - delta, 0.0)
	_wobble = maxf(_wobble - delta * 2.5, 0.0)
	_pose_cool = maxf(_pose_cool - delta, 0.0)
	_interrupt_cool = maxf(_interrupt_cool - delta, 0.0)
	_fire_cool = maxf(_fire_cool - delta, 0.0)
	_flee_cool = maxf(_flee_cool - delta, 0.0)
	_since_filmed += delta
	if _burn_t >= 0.0:
		_burn_t -= delta
		if _burn_t <= 0.0:
			if invuln > 0.0:
				_burn_t = invuln + 0.01   # wait for the i-frames, then burn
			elif take_hit(1, "fire", global_position + Vector2(0, 30)):
				_burn_t = -1.0
				_quip("HOT GRAVY!", Color(1.0, 0.55, 0.2))
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
	var c := Vector2(clampf(global_position.x, arena.position.x, arena.end.x),
		clampf(global_position.y, arena.position.y, arena.end.y))
	if c != global_position:
		global_position = c
		return true
	return false


func _think(delta: float, p: Node2D) -> Vector2:
	var to := p.global_position - global_position
	var dist := to.length()
	var radial := to / dist if dist > 1.0 else Vector2.DOWN
	match state:
		S.INTRO:
			if state_t >= LevelConfig.BOSS_INTRO_TIME:
				_set_state(S.MOVE)
				_gap = 0.6
			return Vector2.ZERO
		S.MOVE:
			_gap -= delta
			_dash_in -= delta
			_strafe_flip -= delta
			if _strafe_flip <= 0.0:
				_strafe_flip = rng.randf_range(2.0, 4.0)
				_strafe_sign = -_strafe_sign
			if _flee_pending:
				_flee_pending = false
				_flee = true
				_set_state(S.TELL_DASH)
				return Vector2.ZERO
			if _combo_next != "":
				var k := _combo_next
				_combo_next = ""
				_start_windup(p, k)
				return Vector2.ZERO
			if _dash_in <= 0.0 and _gap > 0.5:
				_flee = false
				_set_state(S.TELL_DASH)
				return Vector2.ZERO
			if _gap <= 0.0:
				_start_windup(p)
				return Vector2.ZERO
			var spd := LevelConfig.BOSS_STRAFE_SPEED_RAGE if phase() >= 4 else LevelConfig.BOSS_STRAFE_SPEED
			var tangent := radial.orthogonal() * _strafe_sign
			if dist > LevelConfig.BOSS_PREF_DIST + 60.0:
				return (radial * 0.8 + tangent * 0.5).normalized() * spd
			if dist < LevelConfig.BOSS_RETREAT_DIST:
				return (-radial * 0.9 + tangent * 0.4).normalized() * spd * LevelConfig.BOSS_RETREAT_MULT
			return (tangent + radial * clampf((dist - LevelConfig.BOSS_PREF_DIST) / 120.0, -0.6, 0.6)).normalized() * spd
		S.TELL_DASH:
			_gap -= delta
			if state_t >= (LevelConfig.BOSS_FLEE_TELL if _flee else LevelConfig.BOSS_DASH_TELL):
				var side := radial.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
				var dir := (side + radial * (0.35 if dist > LevelConfig.BOSS_PREF_DIST else -0.35)).normalized()
				if _flee:   # dash-strafe away from the rancher after a hit
					dir = (side * 0.75 - radial * 0.75).normalized()
				# stay inside the arena: flip if the dash would hit a side
				var dest := global_position + dir * LevelConfig.BOSS_DASH_SPEED * LevelConfig.BOSS_DASH_TIME
				if not arena.grow(-20.0).has_point(dest):
					dir = Vector2(-dir.x, dir.y) if _flee else -dir
					dest = global_position + dir * LevelConfig.BOSS_DASH_SPEED * LevelConfig.BOSS_DASH_TIME
					if _flee and not arena.grow(-20.0).has_point(dest):
						dir = (side * 0.6 - radial * 0.3).normalized()
					if _flee and not arena.grow(-20.0).has_point(global_position + dir * LevelConfig.BOSS_DASH_SPEED * LevelConfig.BOSS_DASH_TIME):
						dir = -side
				_dash_vel = dir * LevelConfig.BOSS_DASH_SPEED
				_set_state(S.DASH)
				_spawn_dust()
			return Vector2.ZERO
		S.DASH:
			_gap -= delta
			if state_t >= LevelConfig.BOSS_DASH_TIME:
				_set_state(S.MOVE)
				_dash_in = rng.randf_range(LevelConfig.BOSS_DASH_EVERY.x, LevelConfig.BOSS_DASH_EVERY.y)
				if _flee:
					# 015b: dash away, then answer at once (counter-throw)
					_flee_cool = LevelConfig.BOSS_FLEE_COOLDOWN
					_gap = minf(_gap, LevelConfig.BOSS_COUNTER_GAP)
				else:
					_gap = maxf(_gap, 0.35)
				_flee = false
			return _dash_vel
		S.WINDUP:
			var wind := wind_time()
			if not _aim_locked and attack != "lob":
				_aim = radial
				if state_t >= wind - 0.15:
					_aim_locked = true   # last 0.15 s: the aim line freezes
			if state_t >= wind:
				_fire(p)
			return Vector2.ZERO
		S.VOLLEY:
			_volley_t -= delta
			if _volley_t <= 0.0 and _volley_left > 0:
				_volley_t = LevelConfig.POUTINE_VOLLEY_GAP
				_volley_left -= 1
				_throw_one(radial, LevelConfig.POUTINE_VOLLEY_SPEED)
			if _volley_left <= 0 and _volley_t <= 0.0:
				_after_attack()
			return Vector2.ZERO
		S.RECOVER:
			if state_t >= 0.25:
				_set_state(S.MOVE)
			return Vector2.ZERO
		S.POSE:
			if _since_filmed > LevelConfig.BOSS_POSE_LINGER or _pose_time > LevelConfig.BOSS_POSE_MAX:
				_end_pose()
			return Vector2.ZERO
		S.STAGGER:
			if state_t >= _stagger:
				_set_state(S.MOVE)
				_gap = maxf(_gap, 0.6)
			return Vector2.ZERO
		S.PHOTO_OP:
			if state_t >= LevelConfig.BOSS_PHOTO_OP_TIME:
				_set_state(S.MOVE)
				_gap = maxf(_gap, 0.4)
			return Vector2.ZERO
	return Vector2.ZERO


func wind_time() -> float:
	return LevelConfig.BOSS_WINDUP_RAGE if phase() >= 4 else LevelConfig.BOSS_WINDUP


func choose_attack() -> String:
	var w: Dictionary
	match phase():
		1: w = {"single": 1}
		2: w = {"single": 40, "spread": 60}
		3: w = {"single": 25, "spread": 40, "lob": 35}
		_: w = {"volley": 30, "radial": 30, "lob": 25, "spread": 15}
	if _last_attack == "radial" and w.has("radial") and w.size() > 1:
		w.erase("radial")
	var total := 0
	for k in w:
		total += int(w[k])
	var roll := rng.randi_range(1, total)
	for k in w:
		roll -= int(w[k])
		if roll <= 0:
			return k
	return "single"


func _start_windup(p: Node2D, forced: String = "") -> void:
	attack = forced if forced != "" else choose_attack()
	_aim = global_position.direction_to(p.global_position)
	_aim_locked = false
	_lob_target = p.global_position
	_lob_target2 = _second_lob_target(p)
	var n := LevelConfig.POUTINE_RADIAL_COUNT
	_radial_off = rng.randf() * TAU / n
	_radial_gap_at = rng.randi_range(0, n - 1)
	_set_state(S.WINDUP)
	Sfx.play(self, "windup", -14.0)


## Tests / screenshots: start a specific attack now.
func force_attack(kind: String) -> void:
	var p := _player()
	if p != null and state != S.DEFEATED:
		_start_windup(p, kind)


## 015b double lob: the 2nd ring leads the rancher's movement (or sits beside
## the 1st ring when standing still), at least POUTINE_LOB_PAIR_MIN away.
func _second_lob_target(p: Node2D) -> Vector2:
	var t1 := p.global_position
	var v: Vector2 = p.velocity if "velocity" in p else Vector2.ZERO
	var t2 := _clamp_to_arena(t1 + v * LevelConfig.POUTINE_LOB_LEAD)
	if t2.distance_to(t1) >= LevelConfig.POUTINE_LOB_PAIR_MIN:
		return t2
	# standing still / pinned at a wall: put the 2nd ring beside the 1st
	var side := global_position.direction_to(t1).orthogonal()
	if side == Vector2.ZERO:
		side = Vector2.RIGHT
	var sgn := 1.0 if rng.randf() < 0.5 else -1.0
	var off := LevelConfig.POUTINE_LOB_PAIR_MIN + 20.0
	for s in [sgn, -sgn]:
		t2 = _clamp_to_arena(t1 + side * off * s)
		if t2.distance_to(t1) >= LevelConfig.POUTINE_LOB_PAIR_MIN:
			return t2
	# corner: drop it toward the arena centre instead
	return _clamp_to_arena(t1 + t1.direction_to(arena.get_center()) * off)


func _clamp_to_arena(v: Vector2) -> Vector2:
	return Vector2(clampf(v.x, arena.position.x, arena.end.x), clampf(v.y, arena.position.y, arena.end.y))


func spread_angles() -> Array:
	if phase() >= 3:
		var d := LevelConfig.POUTINE_SPREAD5_DEG
		return [-2.0 * d, -d, 0.0, d, 2.0 * d]
	return [-LevelConfig.POUTINE_SPREAD_DEG, 0.0, LevelConfig.POUTINE_SPREAD_DEG]


## Radial slots that will fire (the gap slots are skipped).
func radial_dirs() -> Array:
	var n := LevelConfig.POUTINE_RADIAL_COUNT
	var out: Array = []
	for i in n:
		var rel := (i - _radial_gap_at + n) % n
		if rel < LevelConfig.POUTINE_RADIAL_GAP:
			continue
		out.append(Vector2.from_angle(_radial_off + TAU * i / n))
	return out


func _fire(p: Node2D) -> void:
	_last_attack = attack
	attacks_fired[attack] = int(attacks_fired.get(attack, 0)) + 1
	_quip_throw()
	match attack:
		"single":
			_throw_one(_aim, LevelConfig.POUTINE_SPEED)
		"spread":
			for deg in spread_angles():
				_throw_one(_aim.rotated(deg_to_rad(deg)), LevelConfig.POUTINE_SPREAD_SPEED)
		"lob":
			_lob(_lob_target)
			if phase() >= 3:
				_lob(_lob_target2)
				if rng.randf() < float(LevelConfig.BOSS_COMBO_CHANCE[phase() - 1]):
					_combo_next = "spread" if phase() >= 4 else "single"
		"radial":
			for d in radial_dirs():
				_throw_one(d, LevelConfig.POUTINE_RADIAL_SPEED)
		"volley":
			_volley_left = LevelConfig.POUTINE_VOLLEY_COUNT
			_volley_t = 0.0
			_set_state(S.VOLLEY)
			return
	_after_attack()


func _after_attack() -> void:
	attack = ""
	_set_state(S.RECOVER)
	_gap = float(LevelConfig.BOSS_ATTACK_GAP[phase() - 1])
	if _combo_next != "":
		_gap = 0.0


func _quip_throw() -> void:
	if rng.randf() < 0.3:
		_quip(["POUTINE TIME!", "EXTRA GRAVY!", "HAVE SOME CURDS!", "GRAVY TRAIN!"][rng.randi_range(0, 3)], Color(1.0, 0.75, 0.4))


func _projectile_parent() -> Node:
	if level != null and is_instance_valid(level) and level.get_node_or_null("Entities") != null:
		return level.get_node("Entities")
	return get_parent()


func _throw_one(dir: Vector2, speed: float) -> Poutine:
	var pt := Poutine.new()
	pt.mode = "flat"
	pt.velocity = dir.normalized() * speed
	pt.level = level
	if level != null and "arena_rect" in level:
		pt.bounds = level.arena_rect.grow(40.0)
	_projectile_parent().add_child(pt)
	pt.global_position = global_position + dir.normalized() * 30.0
	_throw_t = 0.18
	Sfx.play(self, "throw", -12.0, rng.randf_range(0.9, 1.1))
	return pt


func _lob(target: Vector2) -> Poutine:
	var pt := Poutine.new()
	pt.mode = "lob"
	pt.start = global_position + Vector2(0, -4)
	pt.target = target
	pt.level = level
	_projectile_parent().add_child(pt)
	_throw_t = 0.18
	Sfx.play(self, "throw", -12.0, 0.8)
	return pt


func _spawn_dust() -> void:
	if level == null or not is_instance_valid(level) or not "fx_layer" in level:
		return
	for i in 5:
		var d := DustPuff.new()
		level.fx_layer.add_child(d)
		d.global_position = global_position + Vector2(rng.randf_range(-22, 22), rng.randf_range(-4, 6))


# ------------------------------------------------------------------ look

func _animate() -> void:
	var p := _player()
	if p != null and state != S.DEFEATED:
		_spr.flip_h = p.global_position.x < global_position.x
	var f := F_IDLE + (int(_t * 2.5) % 2)
	_spr.scale = Vector2.ONE
	match state:
		S.INTRO:
			f = F_POSE if fmod(state_t, 1.4) < 0.9 else F_IDLE
		S.MOVE:
			f = F_WALK + (int(_t * 7.0) % 2) if velocity.length() > 20.0 else f
		S.TELL_DASH:
			_spr.scale = Vector2(1.08, 0.9)
		S.DASH:
			f = F_WALK
			_spr.scale = Vector2(0.92, 1.06)
		S.WINDUP, S.VOLLEY:
			f = F_WINDUP
		S.POSE, S.PHOTO_OP:
			f = F_POSE if state == S.POSE or fmod(state_t, 0.5) < 0.32 else F_IDLE
		S.STAGGER:
			f = F_HURT
		S.DEFEATED:
			f = F_DOWN + (int(_t * 3.0) % 2) if state_t > 0.5 else F_HURT
	if _throw_t > 0.0 and state != S.DEFEATED:
		f = F_THROW
	elif _hurt_t > 0.0 and state != S.DEFEATED:
		f = F_HURT
	_spr.frame = f
	# position the sprite so the feet stay on the ground (scale pivots at centre)
	_spr.position = Vector2(0, -48.0 * _spr.scale.y - (56.0 - 56.0 * _spr.scale.y) * 0.0)
	var wob := sin(_t * 28.0) * 0.16 * _wobble
	if state == S.DEFEATED:
		wob = sin(state_t * 10.0) * 0.25 * maxf(0.0, 1.0 - state_t / 1.2)
		if state_t < 0.45:
			_spr.position.y -= sin(state_t / 0.45 * PI) * 30.0
	_spr.rotation = wob
	if state == S.PHOTO_OP:
		_spr.modulate = Color(1.1, 1.2, 1.35)
	elif invuln > 0.0 and state != S.DEFEATED:
		_spr.modulate = Color(3.0, 3.0, 3.0, 1.0) if fmod(invuln, 0.12) > 0.06 else Color(1, 1, 1, 0.75)
	elif state == S.POSE:
		_spr.modulate = Color(1.15, 1.15, 1.15)
	else:
		_spr.modulate = Color(1, 1, 1, 1)


func _draw() -> void:
	# wind-up telegraphs (in local space; drawn behind the sprite)
	if state == S.WINDUP:
		var wind := wind_time()
		var k := clampf(state_t / wind, 0.0, 1.0)
		var col := Color(1.0, 0.3, 0.2, 0.35 + 0.5 * k)
		match attack:
			"single", "volley":
				_dash_line(Vector2.ZERO, _aim * (170.0 + 60.0 * k), col, 3.0)
			"spread":
				for deg in spread_angles():
					_dash_line(Vector2.ZERO, _aim.rotated(deg_to_rad(deg)) * (150.0 + 50.0 * k), col, 2.5)
			"lob":
				var r := LevelConfig.POUTINE_LOB_RADIUS
				_ring(to_local(_lob_target), Vector2(r, r * 0.55), col, 3.0)
				if phase() >= 3:
					_ring(to_local(_lob_target2), Vector2(r, r * 0.55), col, 3.0)
			"radial":
				var rr := 40.0 + 80.0 * k
				_ring(Vector2.ZERO, Vector2(rr, rr * 0.55), col, 3.0)
				# one short spoke per poutine; the empty slots are the safe lane
				for d in radial_dirs():
					var dd: Vector2 = d * Vector2(1.0, 0.55)
					draw_line(dd * rr, dd * (rr + 26.0), col, 3.0)
		# "!" over his head
		var bang := Vector2(0, -122 - 3.0 * sin(_t * 20.0))
		draw_rect(Rect2(bang + Vector2(-5, -18), Vector2(10, 26)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(bang + Vector2(-3, -16), Vector2(6, 14)), Color(1.0, 0.85, 0.2))
		draw_rect(Rect2(bang + Vector2(-3, 1), Vector2(6, 5)), Color(1.0, 0.85, 0.2))
	if state == S.TELL_DASH:
		_ring(Vector2(0, 2), Vector2(30, 10), Color(1, 1, 1, 0.5), 2.0)
	if state == S.PHOTO_OP:
		# shimmering "photo op" shield: whips bounce off
		var a := 0.35 + 0.2 * sin(_t * 14.0)
		_ring(Vector2(0, -46), Vector2(48, 64), Color(0.6, 0.9, 1.0, a + 0.3), 3.0)
		_ring(Vector2(0, -46), Vector2(42, 57), Color(1, 1, 1, a), 2.0)
		for i in 3:
			var c := Vector2(cos(_t * 4.0 + i * 2.1) * 40.0, -60.0 + sin(_t * 5.0 + i) * 40.0)
			draw_line(c - Vector2(6, 0), c + Vector2(6, 0), Color(1, 1, 0.8, 0.9), 2.0)
			draw_line(c - Vector2(0, 6), c + Vector2(0, 6), Color(1, 1, 0.8, 0.9), 2.0)
	if state == S.POSE:
		# camera flash sparkles
		for i in 4:
			var a := _t * 3.0 + i * TAU / 4.0
			var c := Vector2(cos(a) * 46.0, -60.0 + sin(a) * 34.0)
			var s := 4.0 + 3.0 * absf(sin(_t * 9.0 + i))
			draw_line(c - Vector2(s, 0), c + Vector2(s, 0), Color(1, 1, 0.8, 0.9), 2.0)
			draw_line(c - Vector2(0, s), c + Vector2(0, s), Color(1, 1, 0.8, 0.9), 2.0)
	if _burn_t >= 0.0:
		for i in 5:
			var ph := _t * 9.0 + i * 1.7
			var x := -20.0 + i * 10.0
			var h := 14.0 + 8.0 * absf(sin(ph))
			var base := Vector2(x, -20.0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 0), base + Vector2(0, -h - 14), base + Vector2(6, 0)]), Color(1.0, 0.35, 0.05, 0.85))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(0, -h - 3), base + Vector2(3, 0)]), Color(1.0, 0.9, 0.3, 0.95))
	if state == S.DEFEATED and state_t > 0.5:
		for i in 3:
			var a := _t * 5.0 + i * TAU / 3.0
			var c := Vector2(cos(a) * 30.0, -104.0 + sin(a) * 8.0)
			_star(c, Color(1.0, 0.95, 0.4) if i != 1 else Color(1, 1, 1))


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
	# arrow head
	var dir := d.normalized()
	draw_line(b, b - dir.rotated(0.5) * 12.0, col, w)
	draw_line(b, b - dir.rotated(-0.5) * 12.0, col, w)


func _ring(c: Vector2, r: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := float(i) / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, w)


## Dust puff for dashes.
class DustPuff extends Node2D:
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.4:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k := _t / 0.4
		draw_circle(Vector2(0, -k * 10.0), 5.0 + 9.0 * k, Color(0.85, 0.8, 0.65, 0.6 * (1.0 - k)))
