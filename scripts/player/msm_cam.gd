class_name MsmCam
extends Node2D
## Build 014: the MSM Cam weapon (child "MsmCam" of the Player, added by
## level_controller). Equipped through Weapons; films while the action button
## is held (PC: hold LMB, touch: hold REC = the WHIP button). The battery only
## drains while filming; at 0 a spare battery is loaded automatically.
##
## While filming, everything inside a 39 degree cone (2x whip reach) is "on camera":
##  - silly humans fill a "convinced" meter, then walk to the safe zone by
##    themselves (SillyHuman.cam_film)
##  - Karens love cameras: faster + erratic (SillyHuman.cam_excite), a small
##    chance per second to infect a random silly human, and enough Karen
##    screen time makes it go VIRAL: every silly human stampedes to safety
##  - the sheep den breeds faster (level_controller reads `filming`)
## SECONDARY = SWING: a short camcorder bash (no damage, no battery, works
## with a dead battery) that shoves sheep / possessed / Karens back and
## staggers them. Filming pauses briefly and resumes if REC is still held.
## This node draws the cone (z -1: under the characters, over the ground).
## All numbers: LevelConfig build 014 section.

signal battery_swapped
signal went_viral(humans: int)
signal infected(human: Node)

var battery: float = 0.0
var filming := false
var aim_dir := Vector2.RIGHT
## Cumulative Karen screen time toward the next VIRAL.
var expose_time: float = 0.0
var range_px: float = LevelConfig.cam_range()
var rec_time: float = 0.0
var humans_in_cone: int = 0
var karens_in_cone: int = 0
var viral_count: int = 0
## HUD cues (seconds left).
var swap_flash: float = 0.0
var dead_flash: float = 0.0
## Debug scenarios only (never set in a shipped build).
## SWING state: cooldown, and the swing animation (read by Camcorder).
var swing_cooldown: float = 0.0
var swing_t: float = -1.0
var swing_dir := Vector2.RIGHT
var swing_hits: int = 0
const SWING_ANIM := 0.28
var debug_force_film := false
var debug_aim := Vector2.ZERO
var rng := RandomNumberGenerator.new()

var _t: float = 0.0
var _flicker: float = 1.0
var _flicker_t: float = 0.0
var _was_pressed := false
var _beep: AudioStreamPlayer
var _rec_tick := 0.0
var _dead_popup_ms: int = -100000


func _ready() -> void:
	name = "MsmCam"
	z_index = -1
	rng.randomize()
	var base := 210.0
	var whip := get_parent().get_node_or_null("Whip") if get_parent() != null else null
	if whip != null and "whip_range" in whip:
		base = whip.whip_range
	range_px = LevelConfig.cam_range(base)
	_beep = AudioStreamPlayer.new()
	_beep.stream = Sfx.swap_beep()
	_beep.volume_db = -14.0
	_beep.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_beep)


func _player() -> Node2D:
	return get_parent() as Node2D


func weapons() -> Node:
	return get_parent().get_node_or_null("Weapons") if get_parent() != null else null


func power_ups() -> Node:
	return get_parent().get_node_or_null("PowerUps") if get_parent() != null else null


func is_owned() -> bool:
	var w := weapons()
	return w != null and w.has_weapon("cam")


func is_equipped() -> bool:
	var w := weapons()
	return w != null and w.current_id() == "cam"


func is_dead() -> bool:
	return battery <= 0.0


func battery_frac() -> float:
	return clampf(battery / LevelConfig.CAM_BATTERY_SECONDS, 0.0, 1.0)


func _action_held() -> bool:
	if debug_force_film:
		return true
	return Weapons.primary_held()


## Dual-mode weapon API (called by Weapons). REC is hold-to-film, read every
## physics frame in _physics_process, so the press itself needs nothing.
func weapon_primary() -> void:
	pass


func weapon_secondary() -> void:
	swing()


## Camcorder bash in a 90 degree arc in front. Returns how many it hit, or -1
## while on cooldown.
func swing() -> int:
	var p := _player()
	if p == null or ("_dead" in p and p._dead) or swing_cooldown > 0.0:
		return -1
	swing_cooldown = LevelConfig.SWING_COOLDOWN
	Sfx.play(self, "swing", -7.0)
	swing_dir = current_aim()
	aim_dir = swing_dir
	swing_t = 0.0
	var base := range_px / LevelConfig.CAM_RANGE_MULT
	var reach := base * LevelConfig.SWING_RANGE_MULT
	var cos_half := cos(deg_to_rad(LevelConfig.SWING_HALF_ARC_DEG))
	var push := LevelConfig.SWING_PUSH_PX * LevelConfig.SWING_PUSH_DAMPING
	var n := 0
	for group in ["sheep", "possessed", "boss"]:
		for c in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(c) or not c is Node2D or ("exploding" in c and c.exploding):
				continue
			var to: Vector2 = (c as Node2D).global_position - p.global_position
			var d := to.length()
			if d > reach + 14.0:
				continue
			if d > 6.0 and swing_dir.dot(to / d) < cos_half:
				continue
			if c.has_method("receive_swing"):
				c.receive_swing(p.global_position, push, LevelConfig.SWING_STAGGER)
				n += 1
				var stars := StaggerStars.new()
				stars.life = LevelConfig.SWING_STAGGER
				c.add_child(stars)
				if c.is_in_group("boss"):
					stars.position = Vector2(0, -116)
				_spawn_impact((c as Node2D).global_position + Vector2(0, -18))
	swing_hits += n
	return n


func _spawn_impact(at: Vector2) -> void:
	var lvl := get_tree().get_first_node_in_group("level_controller")
	var parent: Node = lvl.fx_layer if lvl != null and "fx_layer" in lvl and lvl.fx_layer != null else null
	if parent == null:
		return
	var fx := ImpactStars.new()
	parent.add_child(fx)
	fx.global_position = at


func _physics_process(delta: float) -> void:
	_t += delta
	swap_flash = maxf(swap_flash - delta, 0.0)
	swing_cooldown = maxf(swing_cooldown - delta, 0.0)
	if swing_t >= 0.0:
		swing_t += delta
		if swing_t > SWING_ANIM:
			swing_t = -1.0
	dead_flash = maxf(dead_flash - delta, 0.0)
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		_flicker_t = 0.08
		_flicker = 0.82 + rng.randf() * 0.18
	var p := _player()
	var alive: bool = p != null and not ("_dead" in p and p._dead)
	var pressed := alive and is_equipped() and _action_held()
	# A swing interrupts filming briefly (resumes if REC is still held).
	var swinging := swing_t >= 0.0 and swing_t < LevelConfig.SWING_FILM_PAUSE
	var want := pressed and not swinging
	if want and battery <= 0.0 and not _load_spare():
		want = false
		if not _was_pressed:
			_no_battery_cue()
	_was_pressed = pressed
	# Build 015b: REC start / stop beeps and a soft tick each second of filming.
	if want and not filming:
		Sfx.play(self, "rec_start", -8.0)
		_rec_tick = 0.0
	elif filming and not want:
		Sfx.play(self, "rec_stop", -10.0)
	filming = want
	humans_in_cone = 0
	karens_in_cone = 0
	if filming:
		aim_dir = current_aim()
		battery -= delta
		rec_time += delta
		_rec_tick += delta
		if _rec_tick >= 1.0:
			_rec_tick -= 1.0
			Sfx.play(self, "rec_tick", -14.0)
		if battery <= 0.0:
			battery = 0.0
			if not _load_spare():
				filming = false
				_no_battery_cue()
		if filming:
			_film(delta)
	if p != null and "aim_override" in p:
		p.aim_override = aim_dir if filming or swing_t >= 0.0 else Vector2.ZERO
	if is_equipped() or filming:
		if not filming:
			aim_dir = current_aim()
		queue_redraw()
	elif visible:
		queue_redraw()


## Same aim as the whip: mouse on PC, 8-way facing on touch.
func current_aim() -> Vector2:
	if debug_aim.length_squared() > 0.0001:
		return debug_aim.normalized()
	var p := _player()
	if p == null:
		return Vector2.RIGHT
	var d := p.global_position.direction_to(TouchInput.get_aim_world(self))
	return d if d.length_squared() > 0.0001 else aim_dir


func _load_spare() -> bool:
	var pu := power_ups()
	if pu == null or not pu.take_spare_battery():
		return false
	battery = LevelConfig.CAM_BATTERY_SECONDS
	flash_swap()
	return true


## Battery swap cue (beep + HUD flash + popup).
func flash_swap() -> void:
	swap_flash = 0.8
	if _beep != null and is_inside_tree():
		_beep.play()
	battery_swapped.emit()
	_popup("BATTERY SWAP", Color(0.6, 1.0, 0.5))


func _no_battery_cue() -> void:
	dead_flash = 1.0
	var now := Time.get_ticks_msec()
	if now - _dead_popup_ms > 1200:
		_dead_popup_ms = now
		Sfx.play(self, "no_battery", -8.0)
		_popup("NO BATTERY!", Color(1.0, 0.4, 0.35))


func _popup(text: String, col: Color) -> void:
	var lvl := get_tree().get_first_node_in_group("level_controller") if is_inside_tree() else null
	var p := _player()
	if lvl != null and lvl.has_method("spawn_score_popup") and p != null:
		lvl.spawn_score_popup(text, p.global_position + Vector2(0, -10), col, 2)


## True if a world position is inside the cone (from the rancher's feet).
func in_cone(world_pos: Vector2) -> bool:
	var p := _player()
	if p == null:
		return false
	var to := world_pos - p.global_position
	var d := to.length()
	if d > range_px or d < 4.0:
		return false
	return aim_dir.dot(to / d) >= cos(deg_to_rad(LevelConfig.CAM_HALF_ANGLE_DEG))


func _film(delta: float) -> void:
	var tree := get_tree()
	for h in tree.get_nodes_in_group("humans"):
		if not is_instance_valid(h) or not h is Node2D or h.is_queued_for_deletion():
			continue
		if ("possessed" in h and h.possessed) or ("rescued" in h and h.rescued):
			continue
		if in_cone((h as Node2D).global_position) and h.has_method("cam_film"):
			h.cam_film(delta)
			humans_in_cone += 1
	# Build 015: the boss poses for the camera (TrustinJudeau.cam_film).
	for b in tree.get_nodes_in_group("boss"):
		if is_instance_valid(b) and not ("exploding" in b and b.exploding) and in_cone((b as Node2D).global_position) \
				and b.has_method("cam_film"):
			b.cam_film(delta)
	var living := 0
	for k in tree.get_nodes_in_group("karens"):
		if not is_instance_valid(k) or k.is_queued_for_deletion() or ("exploding" in k and k.exploding):
			continue
		living += 1
		if in_cone((k as Node2D).global_position):
			karens_in_cone += 1
			if k.has_method("cam_excite"):
				k.cam_excite()
			if rng.randf() < LevelConfig.CAM_INFECT_CHANCE_PER_SEC * delta:
				infect_random_human()
	if living > 0 and karens_in_cone >= mini(LevelConfig.CAM_EXPOSE_MIN_KARENS, living):
		expose_time += delta
		if expose_time >= LevelConfig.CAM_EXPOSE_SECONDS:
			expose_time = 0.0
			go_viral()


## Karen footage spreads: a random silly human somewhere becomes possessed.
func infect_random_human() -> Node:
	var pool: Array = []
	for h in get_tree().get_nodes_in_group("humans"):
		if is_instance_valid(h) and not h.is_queued_for_deletion() and not ("possessed" in h and h.possessed) \
				and not ("rescued" in h and h.rescued) and h.has_method("cam_infect"):
			pool.append(h)
	if pool.is_empty():
		return null
	var victim: Node = pool[rng.randi_range(0, pool.size() - 1)]
	if not victim.cam_infect():
		return null
	infected.emit(victim)
	return victim


## Every non-possessed silly human on the map runs for the safe zone.
func go_viral() -> int:
	var n := 0
	for h in get_tree().get_nodes_in_group("humans"):
		if is_instance_valid(h) and not ("possessed" in h and h.possessed) and h.has_method("start_stampede"):
			h.start_stampede()
			n += 1
	viral_count += 1
	went_viral.emit(n)
	return n


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not is_equipped() and not filming:
		return
	var o := Vector2(0, -18) + aim_dir * 16.0
	var ang := aim_dir.angle()
	var half := deg_to_rad(LevelConfig.CAM_HALF_ANGLE_DEG)
	var r1 := range_px
	if not filming:
		# Equipped, not filming: barely-there dashed edges so you can aim.
		var a := 0.13 if not is_dead() else 0.06
		for s in [-1.0, 1.0]:
			var d := Vector2.from_angle(ang + half * s)
			var x := 24.0
			while x < r1 - 10.0:
				draw_line(o + d * x, o + d * minf(x + 10.0, r1), Color(1, 0.95, 0.8, a), 1.5)
				x += 22.0
		return
	var base := Color(1.0, 0.95, 0.78)
	var k := _flicker
	# Soft wedge: stacked translucent wedges, each a bit narrower and shorter,
	# so the middle/near part is brightest and the edges fade out.
	var layers := 6
	for j in layers:
		var f := float(j) / layers
		var hj := half * (1.0 - 0.13 * j)
		var rj := r1 * (1.0 - 0.11 * j)
		var pts := PackedVector2Array([o])
		var steps := 8
		for i in steps + 1:
			pts.append(o + Vector2.from_angle(ang - hj + 2.0 * hj * float(i) / steps) * rj)
		draw_colored_polygon(pts, Color(base.r, base.g, base.b, (0.085 + 0.035 * f) * k))
	# Faint scanlines (arcs) drifting outward + one rolling brighter band.
	var off := fmod(_t * 26.0, 14.0)
	var rr := 20.0 + off
	while rr < r1:
		var fade := 1.0 - rr / r1
		draw_arc(o, rr, ang - half * 0.92, ang + half * 0.92, 10, Color(1, 1, 1, 0.07 * fade * k), 1.0)
		rr += 14.0
	var band := fmod(_t * 160.0, r1 + 80.0)
	if band < r1:
		draw_arc(o, band, ang - half * 0.9, ang + half * 0.9, 12, Color(1, 0.97, 0.85, 0.07 * (1.0 - band / r1)), 5.0)
	# Thin edge lines, fading out with distance.
	for s in [-1.0, 1.0]:
		var d := Vector2.from_angle(ang + half * s)
		draw_line(o + d * 10.0, o + d * r1 * 0.5, Color(1, 0.95, 0.8, 0.26 * k), 1.5)
		draw_line(o + d * r1 * 0.5, o + d * r1 * 0.85, Color(1, 0.95, 0.8, 0.12 * k), 1.5)


func _edge(u: float) -> float:
	# 0 at the side edges, 1 in the middle 60%.
	return smoothstep(0.0, 1.0, minf(u, 1.0 - u) / 0.2)


func _c(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Spinning stars over a staggered creature (child of the target).
class StaggerStars extends Node2D:
	var life := 0.6
	var _t := 0.0

	func _ready() -> void:
		z_index = 9
		position = Vector2(0, -44)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for i in 3:
			var a := _t * 9.0 + i * TAU / 3.0
			var p := Vector2(cos(a) * 12.0, sin(a) * 4.0)
			var c := Color(1.0, 0.95, 0.4) if i != 1 else Color(1, 1, 1)
			draw_rect(Rect2(p + Vector2(-1, -4), Vector2(2, 8)), Color(0.06, 0.03, 0.08))
			draw_rect(Rect2(p + Vector2(-4, -1), Vector2(8, 2)), Color(0.06, 0.03, 0.08))
			draw_rect(Rect2(p + Vector2(-0.5, -3), Vector2(1.5, 6)), c)
			draw_rect(Rect2(p + Vector2(-3, -0.5), Vector2(6, 1.5)), c)


## "THUNK" burst where the camcorder connects.
class ImpactStars extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.3:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / 0.3
		var r := 6.0 + 16.0 * k
		var a := 1.0 - k
		for i in 6:
			var ang := i * TAU / 6.0 + 0.3
			var d := Vector2.from_angle(ang)
			draw_line(d * r * 0.5, d * r, Color(1.0, 0.95, 0.6, a), 2.5)
		draw_circle(Vector2.ZERO, 5.0 * (1.0 - k), Color(1, 1, 1, a))

