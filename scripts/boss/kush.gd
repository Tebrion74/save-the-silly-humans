class_name BeorgeKush
extends CharacterBody2D
## Build 018 boss 3: BEORGE KUSH JR., THE AIRSTRIKE ACE. An invented,
## good-natured cartoon parody of a swaggering ex fighter pilot (olive flight
## suit, big ears, squinty grin, gold aviators, helmet under his arm). Art:
## tools/gen_boss3.py -> assets/boss3/kush_96.png. Arena: kush_level.gd.
##
## 15 hearts (LevelConfig.BOSS3_HEARTS). Same hit rules as the other bosses:
##   WHIP crack / WHIP SHOT bolt / a lash that connects with SHOCKWAVE: 1 heart
##   FIRE WHIP: +1 delayed heart, at most once per BOSS_FIRE_COOLDOWN
##   GRAB / CAM SWING: shove + stagger (cancels a radio call, with cooldown)
##   MSM CAM REC: he SALUTES the camera (stops; a radio call is cancelled)
##                up to BOSS3_SALUTE_MAX, then camera-shy BOSS_POSE_COOLDOWN.
##                Marks already on the ground still blast.
##   Touching him: 1 heart (boss_level.gd contact check)
##   FRIENDLY FIRE: caught in one of his own blasts, he loses a heart.
## Every attack starts with a RADIO CALL ("!" + radio at the ear, crackle):
##   strike  red target marks (first on you) -> jet -> blasts
##   strafe  (phase 2+) a flashing DANGER lane through you -> jet strafes it;
##           rage: two crossing lanes
##   carpet  (phase 3+) a line of marks marching through you
## At 9 and 4 hearts he unfurls the MISSION ACCOMPLISHED banner (invulnerable
## BOSS3_BANNER_TIME) and calls an airstrike right after.

signal hearts_changed(hearts: int, maximum: int)
signal took_hit(source: String)
signal defeated

const SHEET := preload("res://assets/boss3/kush_96.png")
## Same values as TrustinJudeau.S (boss_level.gd compares against those).
enum S { INTRO, MOVE, TELL_DASH, DASH, WINDUP, VOLLEY, RECOVER, POSE, STAGGER, DEFEATED, PHOTO_OP, TELEPORT }

const F_IDLE := 0
const F_WALK := 2
const F_RADIO := 4
const F_POINT := 5
const F_SALUTE := 6
const F_HURT := 7
const F_DOWN := 8

var max_hearts: int = LevelConfig.BOSS3_HEARTS
var hearts: int = LevelConfig.BOSS3_HEARTS
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
var friendly_fire_hits := 0

var _flee_pending := false
var _flee_cool := 0.0
var _fire_cool := 0.0
var _burn_t := -1.0
var _banner_done: Dictionary = {}
var _gap := 1.2
var _dash_vel := Vector2.ZERO
var _strafe_sign := 1.0
var _strafe_flip := 3.0
var _push := Vector2.ZERO
var _wobble := 0.0
var _hurt_t := 0.0
var _point_t := 0.0
var _pose_time := 0.0
var _since_filmed := 99.0
var _pose_cool := 0.0
var _interrupt_cool := 0.0
var _stagger := 0.0
var _combo_next := ""
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


func phase() -> int:
	return LevelConfig.boss3_phase(hearts)


func is_defeated() -> bool:
	return state == S.DEFEATED


func state_name() -> String:
	return S.keys()[state]


func is_contact_active() -> bool:
	return true


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
			_quip(["NOT NOW, PHOTO OP!", "BANNER'S UP!", "HOLD THAT POSE!"][rng.randi_range(0, 2)], Color(1.0, 0.9, 0.5))
		return false
	if state == S.DEFEATED or hearts <= 0 or invuln > 0.0:
		return false
	hearts = maxi(hearts - amount, 0)
	invuln = LevelConfig.BOSS_IFRAMES
	_hurt_t = 0.28
	_wobble = 1.0
	var dir := from_pos.direction_to(global_position) if from_pos.distance_to(global_position) > 1.0 else Vector2.UP
	_push = dir * LevelConfig.BOSS_HIT_PUSH
	if source == "airstrike":
		friendly_fire_hits += 1
	hearts_changed.emit(hearts, max_hearts)
	took_hit.emit(source)
	Sfx.play(self, "boss_hit", -8.0, rng.randf_range(0.95, 1.08))
	if state == S.POSE:
		_end_pose()
	if hearts <= 0:
		_defeat()
		return true
	if LevelConfig.BOSS3_BANNER_HEARTS.has(hearts) and not _banner_done.has(hearts):
		_banner_done[hearts] = true
		_start_banner()
		return true
	if _flee_cool <= 0.0:
		_flee_pending = true
	if source == "airstrike":
		_quip(["FRIENDLY FIRE!", "WRONG COORDINATES!", "WHO CALLED THAT IN?!"][rng.randi_range(0, 2)], Color(1.0, 0.6, 0.3))
	elif rng.randf() < 0.45:
		_quip(["MISUNDERESTIMATED!", "THAT'S A NEGATIVE!", "MAYDAY! MAYDAY!", "BRING IT ON!", "STRATEGERY!"][rng.randi_range(0, 4)], Color(1.0, 0.9, 0.5))
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
	if state == S.DEFEATED:
		return
	var dir := source_position.direction_to(global_position)
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	_push = dir * push * LevelConfig.BOSS_SWING_PUSH_MULT
	_interrupt(maxf(stagger, LevelConfig.BOSS_STAGGER))


func receive_throw(direction: Vector2, _force: float) -> void:
	if state == S.DEFEATED:
		return
	_push = direction.normalized() * LevelConfig.BOSS_GRAB_TUG
	_interrupt(LevelConfig.BOSS_STAGGER * 0.5)
	var now := Time.get_ticks_msec()
	if now - _heavy_ms > 1500:
		_heavy_ms = now
		_quip("I'M THE DECIDER!", Color(1.0, 0.9, 0.5))


## MSM Cam REC: he can't resist a camera - he SALUTES (cancels a radio call).
func cam_film(delta: float) -> void:
	if state == S.DEFEATED or state == S.INTRO or state == S.PHOTO_OP:
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
	_set_state(S.POSE)
	_pose_time = 0.0
	_interrupt_cool = LevelConfig.BOSS_INTERRUPT_COOLDOWN
	Sfx.play(self, "pose", -8.0)
	_quip(["MISSION ACCOMPLISHED!", "SMILE FOR THE TROOPS!", "SALUTE!"][rng.randi_range(0, 2)], Color(1.0, 0.9, 0.5))


func is_posing() -> bool:
	return state == S.POSE


func is_saluting() -> bool:
	return state == S.POSE


func is_photo_op() -> bool:
	return state == S.PHOTO_OP


func is_banner() -> bool:
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
		_quip("RADIO'S JAMMED!", Color(1.0, 0.9, 0.5))
	if state == S.POSE:
		_pose_cool = LevelConfig.BOSS_POSE_COOLDOWN
	_cancel_attack()
	_stagger = t
	_set_state(S.STAGGER)


func _cancel_attack() -> void:
	attack = ""
	_combo_next = ""


func _quip(text: String, col: Color) -> void:
	var now := Time.get_ticks_msec()
	if now - _quip_ms < 700:
		return
	_quip_ms = now
	if level != null and is_instance_valid(level) and level.has_method("spawn_score_popup"):
		level.spawn_score_popup(text, global_position + Vector2(0, -116), col, 2)


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
	_quip("FOOL ME ONCE... UH...", Color(1.0, 0.9, 0.5))
	defeated.emit()


## 9 and 4 hearts: MISSION ACCOMPLISHED banner (invulnerable), then a strike.
func _start_banner() -> void:
	_cancel_attack()
	_set_state(S.PHOTO_OP)
	invuln = LevelConfig.BOSS3_BANNER_TIME
	Sfx.play(self, "shield", -6.0)
	Sfx.play(self, "fanfare", -16.0, 1.2)
	_quip("MISSION ACCOMPLISHED!", Color(1.0, 0.9, 0.5))


# ------------------------------------------------------------------ AI

func _physics_process(delta: float) -> void:
	_t += delta
	state_t += delta
	invuln = maxf(invuln - delta, 0.0)
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	_point_t = maxf(_point_t - delta, 0.0)
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
				_burn_t = invuln + 0.05
			elif take_hit(1, "fire", global_position + Vector2(0, 30)):
				_burn_t = -1.0
				_quip("MY FLIGHT SUIT'S ON FIRE!", Color(1.0, 0.55, 0.2))
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
	var c := Vector2(clampf(global_position.x, arena.position.x, arena.end.x), clampf(global_position.y, arena.position.y, arena.end.y))
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
			_strafe_flip -= delta
			if _strafe_flip <= 0.0:
				_strafe_flip = rng.randf_range(2.0, 4.0)
				_strafe_sign = -_strafe_sign
			if _flee_pending:
				_flee_pending = false
				_set_state(S.TELL_DASH)
				return Vector2.ZERO
			if _gap <= 0.0:
				_start_windup(p, _combo_next)
				_combo_next = ""
				return Vector2.ZERO
			var spd := LevelConfig.BOSS3_SPEED_RAGE if phase() >= 4 else LevelConfig.BOSS3_SPEED
			var tangent := radial.orthogonal() * _strafe_sign
			if dist > LevelConfig.BOSS3_PREF_DIST + 60.0:
				return (radial * 0.8 + tangent * 0.5).normalized() * spd
			if dist < LevelConfig.BOSS3_RETREAT_DIST:
				return (-radial * 0.9 + tangent * 0.4).normalized() * spd * LevelConfig.BOSS3_RETREAT_MULT
			return (tangent + radial * clampf((dist - LevelConfig.BOSS3_PREF_DIST) / 120.0, -0.6, 0.6)).normalized() * spd
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
		S.WINDUP:
			# radio call: he keeps walking slowly, then calls it in
			if state_t >= radio_time():
				_fire(p)
			var tangent2 := radial.orthogonal() * _strafe_sign
			return tangent2 * LevelConfig.BOSS3_SPEED * 0.35
		S.RECOVER:
			if state_t >= 0.25:
				_set_state(S.MOVE)
			return Vector2.ZERO
		S.POSE:
			if _since_filmed > LevelConfig.BOSS_POSE_LINGER or _pose_time > LevelConfig.BOSS3_SALUTE_MAX:
				_end_pose()
			return Vector2.ZERO
		S.STAGGER:
			if state_t >= _stagger:
				_set_state(S.MOVE)
				_gap = maxf(_gap, 0.6)
			return Vector2.ZERO
		S.PHOTO_OP:
			if state_t >= LevelConfig.BOSS3_BANNER_TIME:
				_set_state(S.MOVE)
				_start_windup(p, "strike")
			return Vector2.ZERO
	return Vector2.ZERO


func radio_time() -> float:
	return float(LevelConfig.BOSS3_RADIO_TELL[phase() - 1])


func choose_attack() -> String:
	var w: Dictionary = (LevelConfig.BOSS3_ATTACKS[phase() - 1] as Dictionary).duplicate()
	var total := 0
	for k in w:
		total += int(w[k])
	var roll := rng.randi_range(1, total)
	for k in w:
		roll -= int(w[k])
		if roll <= 0:
			return k
	return "strike"


func _start_windup(p: Node2D, forced: String = "") -> void:
	attack = forced if forced != "" else choose_attack()
	Sfx.play(self, "radio", -6.0)
	if rng.randf() < 0.4:
		var lines := {"strike": ["REQUESTING AIR SUPPORT!", "BOMBS AWAY!", "GOT YOU ON RADAR!"],
			"strafe": ["STRAFE THAT RANCHER!", "GUNS GUNS GUNS!", "DANGER CLOSE!"],
			"carpet": ["CARPET'S COMING DOWN!", "SHOCK AND AWE, BABY!", "FULL PAYLOAD!"]}
		var arr: Array = lines.get(attack, ["ROGER THAT!"])
		_quip(arr[rng.randi_range(0, arr.size() - 1)], Color(1.0, 0.9, 0.5))
	_set_state(S.WINDUP)


## Tests / screenshots / bots.
func force_attack(kind: String) -> void:
	var p := _player()
	if p != null and state != S.DEFEATED:
		_start_windup(p, kind)


func _fire(p: Node2D) -> void:
	attacks_fired[attack] = int(attacks_fired.get(attack, 0)) + 1
	_point_t = 0.45
	var i := phase() - 1
	match attack:
		"strike":
			_call_strike(p)
			if rng.randf() < float(LevelConfig.BOSS3_COMBO_CHANCE[i]):
				_combo_next = "strafe"
		"strafe":
			_call_strafe(p)
		"carpet":
			_call_carpet(p)
	_after_attack()


func _after_attack() -> void:
	attack = ""
	_set_state(S.RECOVER)
	_gap = float(LevelConfig.BOSS3_ATTACK_GAP[phase() - 1])
	if _combo_next != "":
		_gap = 0.25


func _host() -> Node:
	if level != null and is_instance_valid(level) and "ground_fx" in level and level.ground_fx != null:
		return level.ground_fx
	return get_parent()


func _fx_host() -> Node:
	if level != null and is_instance_valid(level) and "fx_layer" in level and level.fx_layer != null:
		return level.fx_layer
	return get_parent()


static func _clamp_rect(v: Vector2, r: Rect2) -> Vector2:
	return Vector2(clampf(v.x, r.position.x, r.end.x), clampf(v.y, r.position.y, r.end.y))


## Where the strike marks go: the first on you, the second where you're
## heading, the rest scattered around you (apart from each other).
func pick_mark_points(player_pos: Vector2, player_vel: Vector2, n: int) -> Array:
	var inner := arena.grow(-10.0)
	var out: Array = [_clamp_rect(player_pos, inner)]
	if n >= 2:
		var lead := player_pos + player_vel * LevelConfig.BOSS3_MARK_LEAD
		if lead.distance_to(player_pos) < LevelConfig.BOSS3_MARK_MIN_SEP:
			var a := rng.randf() * TAU
			lead = player_pos + Vector2(cos(a), sin(a)) * LevelConfig.BOSS3_MARK_MIN_SEP * 1.1
		out.append(_clamp_rect(lead, inner))
	while out.size() < n:
		var best := Vector2.ZERO
		var best_sep := -1.0
		for tries in 12:
			var a := rng.randf() * TAU
			var r := rng.randf_range(LevelConfig.BOSS3_MARK_SPREAD.x, LevelConfig.BOSS3_MARK_SPREAD.y)
			var c := _clamp_rect(player_pos + Vector2(cos(a) * r, sin(a) * r * 0.75), inner)
			var sep := 9999.0
			for o in out:
				sep = minf(sep, c.distance_to(o))
			if sep > best_sep:
				best_sep = sep
				best = c
			if sep >= LevelConfig.BOSS3_MARK_MIN_SEP:
				break
		out.append(best)
	return out


func _spawn_mark(at: Vector2, radius: float, fuse: float, delay: float, kind: String) -> Node:
	var m := Airstrike.Mark.new()
	m.level = level
	m.boss = self
	m.radius = radius
	m.fuse = fuse
	m.total = fuse
	m.delay = delay
	m.kind = kind
	_host().add_child(m)
	m.global_position = at
	return m


func _call_strike(p: Node2D) -> void:
	var i := phase() - 1
	var pv: Vector2 = p.velocity if "velocity" in p else Vector2.ZERO
	var pts := pick_mark_points(p.global_position, pv, int(LevelConfig.BOSS3_STRIKE_MARKS[i]))
	var fuse := float(LevelConfig.BOSS3_MARK_TIME[i])
	var centre := Vector2.ZERO
	for pt in pts:
		_spawn_mark(pt, LevelConfig.BOSS3_BLAST_RADIUS, fuse, 0.0, "strike")
		centre += pt
	centre /= float(pts.size())
	Sfx.play(self, "mark", -10.0)
	# the jet: crosses over the marks just before they blast
	var d := Vector2.RIGHT.rotated(rng.randf_range(-0.5, 0.5)) * (1.0 if rng.randf() < 0.5 else -1.0)
	_jet_over(centre, d, maxf(fuse - 0.35, 0.1))


func _jet_over(centre: Vector2, d: Vector2, after: float) -> void:
	var tree := get_tree()
	var host := _fx_host()
	tree.create_timer(after).timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		var j := Airstrike.JetPass.new()
		j.from = centre - d * 900.0
		j.to = centre + d * 900.0
		host.add_child(j))


func _call_strafe(p: Node2D) -> void:
	var i := phase() - 1
	var dirs: Array = []
	var base := Vector2.RIGHT if rng.randf() < 0.5 else Vector2.DOWN
	base = base.rotated(rng.randf_range(-0.35, 0.35))
	dirs.append(base * (1.0 if rng.randf() < 0.5 else -1.0))
	if phase() >= 4:
		dirs.append(base.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0))
	for d in dirs:
		var s := Airstrike.Strafe.new()
		s.level = level
		s.origin = p.global_position
		s.dir = d
		s.half_width = LevelConfig.BOSS3_STRAFE_HALF_WIDTH
		s.length = arena.size.length() + 200.0
		s.tell = float(LevelConfig.BOSS3_STRAFE_TELL[i])
		_host().add_child(s)


func _call_carpet(p: Node2D) -> void:
	# a line of marks marching through you, from his side of the field
	var n := LevelConfig.BOSS3_CARPET_COUNT
	var dir := global_position.direction_to(p.global_position).rotated(rng.randf_range(-0.25, 0.25))
	if dir.length_squared() < 0.01:
		dir = Vector2.DOWN
	var mid := (n - 1) * 0.5
	var inner := arena.grow(-6.0)
	var first := Vector2.ZERO
	for k in n:
		var at := _clamp_rect(p.global_position + dir * (float(k) - mid) * LevelConfig.BOSS3_CARPET_SPACING, inner)
		if k == 0:
			first = at
		_spawn_mark(at, LevelConfig.BOSS3_CARPET_RADIUS, LevelConfig.BOSS3_CARPET_TIME, k * LevelConfig.BOSS3_CARPET_STAGGER, "carpet")
	_jet_over(p.global_position, dir, LevelConfig.BOSS3_CARPET_TIME * 0.6)


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
			f = F_SALUTE if fmod(state_t, 1.4) < 0.8 else F_IDLE
		S.MOVE:
			f = F_WALK + (int(_t * 6.0) % 2) if velocity.length() > 20.0 else f
		S.TELL_DASH:
			_spr.scale = Vector2(1.08, 0.9)
		S.DASH:
			f = F_WALK
			_spr.scale = Vector2(0.92, 1.06)
		S.WINDUP:
			f = F_RADIO
		S.POSE:
			f = F_SALUTE
		S.PHOTO_OP:
			f = F_SALUTE if fmod(state_t, 0.6) < 0.4 else F_IDLE
		S.STAGGER:
			f = F_HURT
		S.DEFEATED:
			f = F_DOWN + (int(_t * 3.0) % 2) if state_t > 0.5 else F_HURT
	if _point_t > 0.0 and state != S.DEFEATED and state != S.WINDUP and state != S.POSE:
		f = F_POINT
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
		_spr.modulate = Color(1.15, 1.12, 1.0)
	elif invuln > 0.0 and state != S.DEFEATED:
		_spr.modulate = Color(3.0, 3.0, 3.0, 1.0) if fmod(invuln, 0.12) > 0.06 else Color(1, 1, 1, 0.75)
	elif state == S.POSE:
		_spr.modulate = Color(1.12, 1.12, 1.12)
	else:
		_spr.modulate = Color(1, 1, 1, 1)


func _draw() -> void:
	if state == S.WINDUP:
		var k := clampf(state_t / maxf(radio_time(), 0.01), 0.0, 1.0)
		# "!" + radio waves from the handset
		var side := -1.0 if _spr.flip_h else 1.0
		var ant := Vector2(26.0 * side, -112.0)
		for w in 3:
			var rr := 8.0 + w * 7.0 + 6.0 * fmod(_t * 3.0, 1.0)
			_arc(ant, rr, Color(1.0, 0.9, 0.4, 0.8 - 0.22 * w))
		var bang := Vector2(0, -132 - 3.0 * sin(_t * 20.0))
		draw_rect(Rect2(bang + Vector2(-5, -18), Vector2(10, 26)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(bang + Vector2(-3, -16), Vector2(6, 14)), Color(1.0, 0.85, 0.2))
		draw_rect(Rect2(bang + Vector2(-3, 1), Vector2(6, 5)), Color(1.0, 0.85, 0.2))
		# a faint crosshair already tracking the rancher
		var p := _player()
		if p != null:
			var c := to_local(p.global_position)
			var r := 30.0 - 10.0 * k
			draw_arc(c, r, 0, TAU, 24, Color(1.0, 0.25, 0.2, 0.25 + 0.45 * k), 2.0)
	if state == S.PHOTO_OP:
		# MISSION ACCOMPLISHED banner on a pole beside him (head height, so it
		# stays on screen even when he's pressed against the top of the deck)
		var prog := clampf(state_t / LevelConfig.BOSS3_BANNER_TIME, 0.0, 1.0)
		var w := 184.0
		var sgn := -1.0 if _spr.flip_h else 1.0
		var pole_x := 34.0 * sgn
		var top := Vector2(pole_x + (2.0 if sgn > 0.0 else -w - 2.0), -116)
		# near the top of the screen the HUD boss bar would cover it: fly it
		# low instead (below his boots)
		if get_global_transform_with_canvas().origin.y < 200.0:
			top.y = 24.0
		var py0 := minf(top.y, -60.0)
		var py1 := maxf(top.y + 28.0, 6.0)
		draw_line(Vector2(pole_x, py1), Vector2(pole_x, py0), Color(0.06, 0.03, 0.08), 5.0)
		draw_line(Vector2(pole_x, py1), Vector2(pole_x, py0), Color(0.85, 0.85, 0.82), 3.0)
		var wave := sin(_t * 6.0) * 2.0
		top.y += wave
		draw_rect(Rect2(top - Vector2(2, 2), Vector2(w + 4, 30)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(top, Vector2(w, 26)), Color(0.97, 0.96, 0.92))
		for x in range(0, int(w), 10):
			draw_rect(Rect2(top + Vector2(x, 0), Vector2(5, 3)), Color(0.8, 0.15, 0.17))
			draw_rect(Rect2(top + Vector2(x + 5, 0), Vector2(5, 3)), Color(0.16, 0.24, 0.6))
			draw_rect(Rect2(top + Vector2(x, 23), Vector2(5, 3)), Color(0.16, 0.24, 0.6))
			draw_rect(Rect2(top + Vector2(x + 5, 23), Vector2(5, 3)), Color(0.8, 0.15, 0.17))
		draw_string(ThemeDB.fallback_font, top + Vector2(0, 19), "MISSION ACCOMPLISHED", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.12, 0.18, 0.5))
		var a := 0.35 + 0.2 * sin(_t * 14.0)
		draw_arc(Vector2(0, -46), 54.0, 0, TAU, 32, Color(1.0, 0.85, 0.3, a + 0.3), 3.0)
		var bar_y := 10.0 if top.y < 0.0 else top.y + 32.0
		draw_rect(Rect2(Vector2(-36, bar_y), Vector2(72, 8)), Color(0.06, 0.03, 0.08))
		draw_rect(Rect2(Vector2(-34, bar_y + 2.0), Vector2(68 * prog, 4)), Color(1.0, 0.85, 0.3))
	if state == S.POSE:
		# camera-flash sparkle
		for i in 3:
			var ang := _t * 4.0 + i * TAU / 3.0
			_star(Vector2(cos(ang) * 40.0, -100.0 + sin(ang) * 10.0), Color(1, 1, 0.8))
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
			_star(Vector2(cos(ang) * 30.0, -104.0 + sin(ang) * 8.0), Color(1.0, 0.85, 0.3) if i != 1 else Color(1, 1, 1))


func _arc(c: Vector2, r: float, col: Color) -> void:
	draw_arc(c, r, -PI * 0.85, -PI * 0.15, 8, Color(0.06, 0.03, 0.08, col.a), 4.0)
	draw_arc(c, r, -PI * 0.85, -PI * 0.15, 8, col, 2.0)


func _star(c: Vector2, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(-1.5, -6), Vector2(3, 12)), Color(0.06, 0.03, 0.08))
	draw_rect(Rect2(c + Vector2(-6, -1.5), Vector2(12, 3)), Color(0.06, 0.03, 0.08))
	draw_rect(Rect2(c + Vector2(-0.5, -5), Vector2(1.5, 10)), col)
	draw_rect(Rect2(c + Vector2(-5, -0.5), Vector2(10, 1.5)), col)
