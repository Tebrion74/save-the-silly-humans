class_name ShlausKwobb
extends CharacterBody2D
## Build 018 boss 4: SHLAUS KWOBB, CHAIRMAN OF THE GREAT RESET. A good-natured
## cartoon parody of the summit chairman (tall, bald dome with a white
## fringe, bushy eyebrows, rimless glasses, grey high-collar suit, VIP
## lanyard, a big red RESET remote). Art: tools/gen_boss4.py ->
## assets/boss4/shlaus_96.png. Arena: shlaus_level.gd (a Davos-style summit).
##
## The puppet master: he CONDUCTS (arms up, "!") and summons hologram
## DELEGATES of the earlier bosses: Trustin Judeau throws poutine, Huval
## Yarheyhey clicks in programmed sheep (Summit.Delegate). His own attacks:
## INVITATIONS (a telegraphed fan of envelopes) and, from phase 2, THE GREAT
## RESET (an expanding ring with two gaps). Phase 3+ summons both delegates
## at once; rage adds PRIVATE JET hops (Huval-style teleport with a
## destination telegraph) and envelope combos.
##
## 18 hearts (cfg.HEARTS). Same hit rules as the other bosses:
##   WHIP / WHIP SHOT / SHOCKWAVE lash: 1 heart; FIRE: +1 delayed heart / 6 s
##   GRAB / CAM SWING: shove + stagger (cancels a tell, with cooldown)
##   Programmed sheep thrown into him: FEEDBACK LOOP, 1 heart (robo_sheep.gd)
##   MSM CAM REC: "NO PRESS!" he hides his face (stops, cancels his tell and
##                every delegate still fading in) up to BOSS4_PRESS_MAX, then
##                camera-shy. Filming a delegate dispels it (any time).
##   Touching him: 1 heart.
## At 13, 8 and 4 hearts he calls a PANEL DISCUSSION (invulnerable for
## BOSS4_PANEL_TIME) that ends with a free GREAT RESET.

signal hearts_changed(hearts: int, maximum: int)
signal took_hit(source: String)
signal defeated
signal summoned(sheep: Node)
signal delegate_spawned(d: Node)

const SHEET := preload("res://assets/boss4/shlaus_96.png")
enum S { INTRO, MOVE, TELL_DASH, DASH, WINDUP, VOLLEY, RECOVER, POSE, STAGGER, DEFEATED, PHOTO_OP, TELEPORT }

const F_IDLE := 0
const F_WALK := 2
const F_REMOTE := 4
const F_CONDUCT := 5
const F_PRESS := 6
const F_HURT := 7
const F_DOWN := 8

## Build 020: every tuning number comes from this table (LevelConfig.boss_cfg:
## the BOSS4_* constants, overlaid with BOSS5_* / BOSS6_* for the bosses that
## extend Shlaus). Subclasses set `boss_no` in _init().
var boss_no: int = 4
var cfg: Dictionary = LevelConfig.boss_cfg(4)
var max_hearts: int = LevelConfig.BOSS4_HEARTS
var hearts: int = LevelConfig.BOSS4_HEARTS
## Skin / flavour hooks for the subclasses.
var sheet: Texture2D = SHEET
var projectile_skin := ""       ## Summit.Envelope skin ("" = envelope)
var ring_skin := ""             ## Summit.ResetRing skin ("" = GREAT RESET)
var hit_quips: Array = ["THAT WAS NOT ON THE AGENDA!", "MOST IRREGULAR!", "I WILL RESET YOU!", "SECURITY!", "YOU WILL OWN NOTHING!"]
var cast_quips: Array = ["I INVITE OUR DELEGATES!", "STAKEHOLDERS, ASSEMBLE!", "THE FLOOR IS YOURS!", "BUILD BACK BETTER!"]
var shield_quips: Array = ["THE PANEL IS IN SESSION!", "ORDER! ORDER!", "PLEASE HOLD QUESTIONS!"]
var quip_color := Color(0.7, 0.85, 1.0)
var grab_quip := "UNHAND THE CHAIRMAN!"
var press_quips: Array = ["NO PRESS AT THE SUMMIT!", "THIS IS A PRIVATE MEETING!", "NO CAMERAS, PLEASE!"]
var defeat_quip := "THE SUMMIT IS... ADJOURNED"
var panel_quip := "PANEL DISCUSSION!"
var fire_quip := "MY AGENDA IS ON FIRE!"
var hop_label := "PRIVATE JET"
var panel_label := "PANEL DISCUSSION"
var press_label := "NO PRESS!"


## Build 020: switch to another boss's table (call in _init of a subclass).
func use_cfg(n: int) -> void:
	boss_no = n
	cfg = LevelConfig.boss_cfg(n)
	max_hearts = int(cfg.HEARTS)
	hearts = max_hearts


func _phase_of(h: int) -> int:
	if h <= int(cfg.RAGE_HEARTS):
		return 4
	if h <= int(cfg.PHASE3_HEARTS):
		return 3
	if h <= int(cfg.PHASE2_HEARTS):
		return 2
	return 1
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
var teleports := 0

var _aim := Vector2.DOWN
var _aim_locked := false
var _flee_pending := false
var _flee_cool := 0.0
var _fire_cool := 0.0
var _burn_t := -1.0
var _panel_done: Dictionary = {}
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
var _combo_next := ""
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
	_spr.texture = sheet
	_spr.hframes = 10
	_spr.position = Vector2(0, -48)
	add_child(_spr)
	_tp_in = rng.randf_range(cfg.HOP_EVERY.x, cfg.HOP_EVERY.y)


func phase() -> int:
	return _phase_of(hearts)


func is_defeated() -> bool:
	return state == S.DEFEATED


func state_name() -> String:
	return S.keys()[state]


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
			_quip(shield_quips[rng.randi_range(0, shield_quips.size() - 1)], quip_color)
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
	Sfx.play(self, "boss_hit", -8.0, rng.randf_range(0.9, 1.0))
	if state == S.POSE:
		_end_pose()
	if hearts <= 0:
		_defeat()
		return true
	if cfg.PANEL_HEARTS.has(hearts) and not _panel_done.has(hearts):
		_panel_done[hearts] = true
		_start_panel()
		return true
	if _flee_cool <= 0.0:
		_flee_pending = true
	if rng.randf() < 0.45:
		_quip(hit_quips[rng.randi_range(0, hit_quips.size() - 1)], quip_color)
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
		_quip(grab_quip, quip_color)


## MSM Cam REC: "NO PRESS!" - he hides from the camera; his tell and every
## delegate still fading in are cancelled.
func cam_film(delta: float) -> void:
	if state == S.DEFEATED or state == S.INTRO or state == S.PHOTO_OP or state == S.TELEPORT:
		return
	_since_filmed = 0.0
	if state == S.POSE:
		_pose_time += delta
		return
	if _pose_cool > 0.0:
		return
	if state == S.WINDUP and _interrupt_cool > 0.0:
		return
	_cancel_attack()
	for d in get_tree().get_nodes_in_group("delegate"):
		if is_instance_valid(d) and d.has_method("is_charging") and d.is_charging():
			d.dispel(true)
	_set_state(S.POSE)
	_pose_time = 0.0
	_interrupt_cool = LevelConfig.BOSS_INTERRUPT_COOLDOWN
	Sfx.play(self, "pose", -8.0, 0.8)
	_quip(press_quips[rng.randi_range(0, press_quips.size() - 1)], quip_color)


func is_posing() -> bool:
	return state == S.POSE


func is_hiding() -> bool:
	return state == S.POSE


func is_photo_op() -> bool:
	return state == S.PHOTO_OP


func is_panel() -> bool:
	return state == S.PHOTO_OP


func _end_pose() -> void:
	_pose_cool = LevelConfig.BOSS_POSE_COOLDOWN
	_set_state(S.MOVE)
	_gap = maxf(_gap, 0.7)


func _interrupt(t: float) -> void:
	var attacking := state == S.WINDUP
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
	_aim_locked = false
	_combo_next = ""


func _quip(text: String, col: Color) -> void:
	var now := Time.get_ticks_msec()
	if now - _quip_ms < 700:
		return
	_quip_ms = now
	if level != null and is_instance_valid(level) and level.has_method("spawn_score_popup"):
		level.spawn_score_popup(text, global_position + Vector2(0, -120), col, 2)


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
	_quip(defeat_quip, quip_color)
	defeated.emit()


func _start_panel() -> void:
	_cancel_attack()
	_set_state(S.PHOTO_OP)
	invuln = cfg.PANEL_TIME
	_flee_pending = false
	Sfx.play(self, "gavel", -6.0)
	_quip(panel_quip, quip_color)


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
				_quip(fire_quip, Color(1.0, 0.55, 0.2))
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
	var c := _clamp_rect(global_position, arena)
	if c != global_position:
		global_position = c
		return true
	return false


static func _clamp_rect(v: Vector2, r: Rect2) -> Vector2:
	return Vector2(clampf(v.x, r.position.x, r.end.x), clampf(v.y, r.position.y, r.end.y))


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
				_gap = 0.6
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
					_start_hop(p)
				else:
					_set_state(S.TELL_DASH)
				return Vector2.ZERO
			if phase() >= 4 and _tp_in <= 0.0 and _gap > 0.4:
				_start_hop(p)
				return Vector2.ZERO
			if _gap <= 0.0:
				_start_windup(p, _combo_next)
				_combo_next = ""
				return Vector2.ZERO
			var spd: float = float(cfg.SPEED_RAGE) if phase() >= 4 else float(cfg.SPEED)
			var tangent := radial.orthogonal() * _strafe_sign
			if dist > cfg.PREF_DIST + 60.0:
				return (radial * 0.8 + tangent * 0.5).normalized() * spd
			if dist < cfg.RETREAT_DIST:
				return (-radial * 0.9 + tangent * 0.4).normalized() * spd * cfg.RETREAT_MULT
			return (tangent + radial * clampf((dist - cfg.PREF_DIST) / 120.0, -0.6, 0.6)).normalized() * spd
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
			return _dash_vel
		S.TELEPORT:
			if state_t >= cfg.HOP_TELL:
				global_position = _tp_dest
				_set_state(S.MOVE)
				_flee_cool = LevelConfig.BOSS_FLEE_COOLDOWN
				_gap = minf(_gap, 0.5)
				_tp_in = rng.randf_range(cfg.HOP_EVERY.x, cfg.HOP_EVERY.y)
				Sfx.play(self, "jet", -10.0, 1.3)
			return Vector2.ZERO
		S.WINDUP:
			var tell := tell_time()
			if attack == "envelopes" and not _aim_locked:
				_aim = (global_position + Vector2(0, -20)).direction_to(p.global_position)
				if state_t >= tell - 0.15:
					_aim_locked = true
			if state_t >= tell:
				_fire(p)
			return Vector2.ZERO
		S.RECOVER:
			if state_t >= 0.25:
				_set_state(S.MOVE)
			return Vector2.ZERO
		S.POSE:
			if _since_filmed > LevelConfig.BOSS_POSE_LINGER or _pose_time > cfg.PRESS_MAX:
				_end_pose()
			return Vector2.ZERO
		S.STAGGER:
			if state_t >= _stagger:
				_set_state(S.MOVE)
				_gap = maxf(_gap, 0.6)
			return Vector2.ZERO
		S.PHOTO_OP:
			if state_t >= cfg.PANEL_TIME:
				_set_state(S.MOVE)
				_spawn_reset(p)
				attacks_fired["reset"] = int(attacks_fired.get("reset", 0)) + 1
				_gap = float(cfg.ATTACK_GAP[phase() - 1])
			return Vector2.ZERO
	return Vector2.ZERO


func tell_time() -> float:
	var i := phase() - 1
	if attack == "envelopes":
		return float(cfg.ENVELOPE_TELL[i])
	return float(cfg.CONDUCT_TELL[i])


func choose_attack() -> String:
	var w: Dictionary = (cfg.ATTACKS[phase() - 1] as Dictionary).duplicate()
	var cap: int = cfg.SHEEP_CAP[phase() - 1]
	if live_robo_count() >= cap:
		w.erase("sheep")
		if w.has("double"):
			w["poutine"] = int(w.get("poutine", 0)) + int(w["double"])
			w.erase("double")
	if _last_attack == "reset" and w.has("reset"):
		w.erase("reset")
	var total := 0
	for k in w:
		total += int(w[k])
	var roll := rng.randi_range(1, total)
	for k in w:
		roll -= int(w[k])
		if roll <= 0:
			return k
	return "poutine"


func _start_windup(p: Node2D, forced: String = "") -> void:
	attack = forced if forced != "" else choose_attack()
	_aim = (global_position + Vector2(0, -20)).direction_to(p.global_position)
	_aim_locked = false
	if attack == "envelopes":
		Sfx.play(self, "windup", -12.0, 0.7)
	elif attack == "reset":
		Sfx.play(self, "clicker", -6.0, 0.6)
	else:
		Sfx.play(self, "gavel", -10.0, 1.2)
		if rng.randf() < 0.4:
			_quip(cast_quips[rng.randi_range(0, cast_quips.size() - 1)], quip_color)
	_set_state(S.WINDUP)


## Tests / screenshots / bots.
func force_attack(kind: String) -> void:
	var p := _player()
	if p != null and state != S.DEFEATED:
		_start_windup(p, kind)


func _fire(p: Node2D) -> void:
	_last_attack = attack
	attacks_fired[attack] = int(attacks_fired.get(attack, 0)) + 1
	_cast_t = 0.35
	var i := phase() - 1
	match attack:
		"poutine":
			_spawn_delegate(p, "trustin")
		"sheep":
			_spawn_delegate(p, "huval")
		"double":
			_spawn_delegate(p, "trustin")
			_spawn_delegate(p, "huval")
		"envelopes":
			_throw_envelopes()
		"reset":
			_spawn_reset(p)
	if attack != "envelopes" and rng.randf() < float(cfg.COMBO_CHANCE[i]):
		_combo_next = "envelopes"
	attack = ""
	_set_state(S.RECOVER)
	_gap = float(cfg.ATTACK_GAP[i])
	if _combo_next != "":
		_gap = 0.3


func _fx_parent() -> Node:
	if level != null and is_instance_valid(level) and level.get_node_or_null("Entities") != null:
		return level.get_node("Entities")
	return get_parent()


## Where a delegate appears: BOSS4_DELEGATE_DIST from you, inside the arena,
## away from Shlaus and from other delegates.
func pick_delegate_point(player_pos: Vector2) -> Vector2:
	var inner := arena.grow(-30.0)
	var best := global_position
	var best_score := -INF
	var others: Array = []
	for d in get_tree().get_nodes_in_group("delegate"):
		if is_instance_valid(d):
			others.append((d as Node2D).global_position)
	for tries in 16:
		var a := rng.randf() * TAU
		var r := rng.randf_range(cfg.DELEGATE_DIST.x, cfg.DELEGATE_DIST.y)
		var c := _clamp_rect(player_pos + Vector2(cos(a) * r, sin(a) * r * 0.8), inner)
		var dp := c.distance_to(player_pos)
		var score := -absf(dp - (cfg.DELEGATE_DIST.x + cfg.DELEGATE_DIST.y) * 0.5) * 0.5
		score += minf(c.distance_to(global_position), 200.0) * 0.3
		for o in others:
			score += minf(c.distance_to(o), 220.0) * 0.4
		if dp < 180.0:
			score -= 1000.0
		if score > best_score:
			best_score = score
			best = c
	return best


func pick_spawn_points(around: Vector2, player_pos: Vector2, n: int) -> Array:
	var out: Array = []
	var inner := arena.grow(-30.0)
	for i in n:
		var best := around
		var best_score := -INF
		for tries in 14:
			var a := rng.randf() * TAU
			var r := rng.randf_range(50.0, 120.0)
			var c := _clamp_rect(around + Vector2(cos(a) * r, sin(a) * r * 0.7), inner)
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
			best = _clamp_rect(player_pos + player_pos.direction_to(best if best != player_pos else global_position) * (LevelConfig.BOSS2_SPAWN_MIN_DIST + 10.0), inner)
		out.append(best)
	return out


func _spawn_delegate(p: Node2D, kind: String) -> Node:
	var i := phase() - 1
	var d := Summit.Delegate.new()
	d.kind = kind
	d.level = level
	d.shlaus = self
	d.phase = phase()
	d.tell = float(cfg.DELEGATE_TELL[i])
	var mode: String = cfg.POUTINE_MODE[i]
	if mode == "spread5" and rng.randf() < 0.5:
		mode = "lob2"
	d.poutine_mode = mode
	var at := pick_delegate_point(p.global_position)
	if kind == "huval":
		var cap: int = cfg.SHEEP_CAP[i]
		var n := mini(int(cfg.SHEEP_COUNT[i]), maxi(cap - live_robo_count(), 0))
		d.spawn_points = pick_spawn_points(at, p.global_position, n)
	_fx_parent().add_child(d)
	d.global_position = at
	delegate_spawned.emit(d)
	return d


func spawn_robo(at: Vector2) -> Node:
	var s := RoboSheep.new()
	s.kind = "robo"
	s.level = level
	s.arena = arena.grow(30.0)
	s.speed = float(LevelConfig.ROBO_SPEED[phase() - 1])
	_fx_parent().add_child(s)
	s.global_position = at
	summoned.emit(s)
	return s


func envelope_dirs() -> Array:
	var n: int = cfg.ENVELOPES[phase() - 1]
	var out: Array = []
	var mid := (n - 1) * 0.5
	for k in n:
		out.append(_aim.rotated(deg_to_rad(cfg.ENVELOPE_FAN_DEG * (float(k) - mid))))
	return out


func _throw_envelopes() -> void:
	var bounds: Rect2 = level.arena_rect.grow(40.0) if level != null and "arena_rect" in level else Rect2(-100000, -100000, 200000, 200000)
	for d in envelope_dirs():
		var e := Summit.Envelope.new()
		e.skin = projectile_skin
		e.velocity = (d as Vector2) * cfg.ENVELOPE_SPEED
		e.level = level
		e.bounds = bounds
		_fx_parent().add_child(e)
		e.global_position = global_position + (d as Vector2) * 30.0
	Sfx.play(self, "paper", -8.0)


func _spawn_reset(p: Node2D) -> Node:
	var i := phase() - 1
	var r := Summit.ResetRing.new()
	r.skin = ring_skin
	r.speed = float(cfg.RESET_SPEED)
	r.level = level
	r.tell = float(cfg.RESET_TELL[i])
	var rel := p.global_position - global_position
	var toward := atan2(rel.y / 0.75, rel.x)
	var near := deg_to_rad(cfg.RESET_GAP_NEAR_DEG)
	var g0 := toward + rng.randf_range(-near, near)
	var gaps: Array = [g0]
	for k in range(1, cfg.RESET_GAPS):
		gaps.append(g0 + TAU * k / cfg.RESET_GAPS + rng.randf_range(-0.5, 0.5))
	r.gaps = gaps
	var host: Node = level.ground_fx if level != null and "ground_fx" in level and level.ground_fx != null else get_parent()
	host.add_child(r)
	r.global_position = global_position
	_cast_t = 0.4
	return r


func _start_hop(p: Node2D) -> void:
	_cancel_attack()
	var inner := arena.grow(-40.0)
	var best := global_position
	var best_d := -1.0
	for i in 10:
		var c := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
		var d := c.distance_to(p.global_position)
		if d >= cfg.HOP_MIN_DIST and d <= cfg.HOP_MIN_DIST + 220.0:
			best = c
			break
		if d > best_d:
			best_d = d
			best = c
	_tp_dest = best
	teleports += 1
	invuln = maxf(invuln, cfg.HOP_TELL)
	_set_state(S.TELEPORT)
	Sfx.play(self, "jet", -10.0, 0.9)


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
			f = F_CONDUCT if fmod(state_t, 1.4) < 0.8 else F_IDLE
		S.MOVE:
			f = F_WALK + (int(_t * 6.0) % 2) if velocity.length() > 20.0 else f
		S.TELL_DASH:
			_spr.scale = Vector2(1.08, 0.9)
		S.DASH:
			f = F_WALK
			_spr.scale = Vector2(0.92, 1.06)
		S.WINDUP:
			f = F_REMOTE if attack == "reset" else F_CONDUCT
		S.POSE:
			f = F_PRESS
		S.PHOTO_OP:
			f = F_REMOTE if fmod(state_t, 0.5) < 0.25 else F_CONDUCT
		S.TELEPORT:
			f = F_IDLE
			_spr.scale = Vector2(1.0 - 0.5 * state_t / cfg.HOP_TELL, 1.0 + 0.3 * state_t / cfg.HOP_TELL)
		S.STAGGER:
			f = F_HURT
		S.DEFEATED:
			f = F_DOWN + (int(_t * 3.0) % 2) if state_t > 0.5 else F_HURT
	if _cast_t > 0.0 and state != S.DEFEATED and state == S.MOVE:
		f = F_CONDUCT
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
	if state == S.PHOTO_OP:
		_spr.modulate = Color(0.95, 1.05, 1.25)
	elif state == S.TELEPORT:
		_spr.modulate = Color(1, 1, 1, 1.0 - 0.7 * state_t / cfg.HOP_TELL)
	elif invuln > 0.0 and state != S.DEFEATED:
		_spr.modulate = Color(3.0, 3.0, 3.0, 1.0) if fmod(invuln, 0.12) > 0.06 else Color(1, 1, 1, 0.75)
	elif state == S.POSE:
		_spr.modulate = Color(1.12, 1.12, 1.12)
	else:
		_spr.modulate = Color(1, 1, 1, 1)


func _draw() -> void:
	if state == S.WINDUP:
		var tell := tell_time()
		var k := clampf(state_t / tell, 0.0, 1.0)
		if attack == "envelopes":
			var o := Vector2(0, -20)
			for d in envelope_dirs():
				_dash_line(o, o + (d as Vector2) * (160.0 + 180.0 * k), Color(1.0, 0.95, 0.7, 0.3 + 0.55 * k), 3.0 if not _aim_locked else 4.0)
		elif attack == "reset":
			var rr := 30.0 + 50.0 * k
			draw_arc(Vector2(0, -46), rr, 0, TAU, 32, Color(1.0, 0.3, 0.35, 0.7), 3.0)
		else:
			# conducting: little baton sparkles in both hands
			for sx in [-1.0, 1.0]:
				var c := Vector2(sx * 36.0, -88.0 + sin(_t * 18.0 + sx) * 6.0)
				_star(c, Color(0.6, 1.0, 1.0))
		var bang := Vector2(0, -150 - 3.0 * sin(_t * 20.0))
		draw_rect(Rect2(bang + Vector2(-5, -18), Vector2(10, 26)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(bang + Vector2(-3, -16), Vector2(6, 14)), Color(0.7, 0.85, 1.0))
		draw_rect(Rect2(bang + Vector2(-3, 1), Vector2(6, 5)), Color(0.7, 0.85, 1.0))
	if state == S.TELEPORT:
		var k: float = state_t / float(cfg.HOP_TELL)
		var c := to_local(_tp_dest)
		draw_arc(c, 34.0 * (1.2 - 0.4 * k), 0, TAU, 28, Color(0.7, 0.85, 1.0, 0.5 + 0.4 * k), 3.0)
		draw_line(c + Vector2(-20, -60), c + Vector2(20, -60), Color(1, 1, 1, 0.6 * k), 3.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-40, -66), hop_label, HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(0.8, 0.9, 1.0, 0.5 + 0.5 * k))
	if state == S.PHOTO_OP:
		# PANEL DISCUSSION: a podium-blue shield + gavel progress bar
		var a := 0.35 + 0.2 * sin(_t * 14.0)
		draw_arc(Vector2(0, -50), 58.0, 0, TAU, 32, Color(0.5, 0.7, 1.0, a + 0.3), 4.0)
		draw_arc(Vector2(0, -50), 50.0, 0, TAU, 32, Color(1, 1, 1, a), 2.0)
		var prog := clampf(state_t / cfg.PANEL_TIME, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-40, 8), Vector2(80, 12)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(Vector2(-38, 10), Vector2(76 * prog, 8)), Color(0.4, 0.6, 1.0))
		draw_rect(Rect2(Vector2(-66, 24), Vector2(132, 18)), Color(0.06, 0.03, 0.08, 0.85))
		draw_string(ThemeDB.fallback_font, Vector2(-66, 38), panel_label, HORIZONTAL_ALIGNMENT_CENTER, 132, 13, Color(0.85, 0.92, 1.0))
	if state == S.POSE:
		draw_rect(Rect2(Vector2(-44, 10), Vector2(88, 18)), Color(0.06, 0.03, 0.08, 0.85))
		draw_string(ThemeDB.fallback_font, Vector2(-44, 24), press_label, HORIZONTAL_ALIGNMENT_CENTER, 88, 14, Color(1.0, 0.5, 0.5))
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
			_star(Vector2(cos(ang) * 30.0, -116.0 + sin(ang) * 8.0), Color(0.7, 0.85, 1.0) if i != 1 else Color(1, 1, 1))


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
