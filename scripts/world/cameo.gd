class_name Cameo
extends Node2D
## Build 030: CAMEO sub-bosses - good-natured tech-mogul parodies that drop
## into a regular level for CAMEO_LIFE seconds, quip in speech bubbles and do
## one thing. Spawned only at random by CameoDirector (summoning is deferred
## to the RPG spinoff). Art: tools/gen_cameos.py, stingers: tools/gen_funk.py.
##   tusk      ALLY  rocket boost for the rancher + STARLINK STRIKEs on sheep
##   bozos     WILD  delivery-drone crates: loot, or bombs (whip to defuse)
##   altmann   WILD  chatbot drone: helpful (points at a hidden chamber, zaps
##                   sheep) or confidently wrong (fake treasure, missed zaps)
##   zuckerbot FOE   mini-fight: fires LIKE bubbles, 6 whip hits = 1500

const ROSTER := {
	"tusk": {"name": "EELON TUSK", "title": "CHIEF ROCKET OFFICER", "role": "ally",
		"sheet": "res://assets/cameo/tusk_96.png", "stinger": "res://assets/audio/stinger_tusk.wav",
		"col": Color(1.0, 0.6, 0.2),
		"quips": ["RANCHING IS BASICALLY ROCKET SCIENCE", "STARLINK STRIKE INBOUND!", "TO MARS... AFTER THIS FIELD",
			"FIRST PRINCIPLES: WHIP THE SHEEP", "I'LL TWEET ABOUT THIS"]},
	"bozos": {"name": "JEFF BOZOS", "title": "TWO-HOUR DRONE DELIVERY", "role": "wild",
		"sheet": "res://assets/cameo/bozos_96.png", "stinger": "res://assets/audio/stinger_bozos.wav",
		"col": Color(0.45, 0.75, 1.0),
		"quips": ["YOUR PACKAGE HAS ARRIVED!", "SOME ASSEMBLY REQUIRED", "IS THAT BOX TICKING? NOT MY DEPT",
			"RATE YOUR DELIVERY 5 STARS", "FREE SHIPPING ON SHEEP!"]},
	"altmann": {"name": "SAM ALTMANN", "title": "PROMPT ENGINEER OF DESTINY", "role": "wild",
		"sheet": "res://assets/cameo/altmann_96.png", "stinger": "res://assets/audio/stinger_altmann.wav",
		"col": Color(0.45, 1.0, 0.8),
		"quips": ["MEET MY CHATBOT. IT'S VERY SURE", "AS A LARGE LANGUAGE MODEL...", "THIS IS FINE. PROBABLY",
			"ASK IT ANYTHING!", "WE'RE ALIGNED. MOSTLY"]},
	"zuckerbot": {"name": "MARK ZUCKERBOT", "title": "LORD OF THE METAVERSE", "role": "foe",
		"sheet": "res://assets/cameo/zuckerbot_96.png", "stinger": "res://assets/audio/stinger_zuckerbot.wav",
		"col": Color(0.55, 0.65, 1.0),
		"quips": ["HELLO FELLOW HUMAN", "WELCOME TO THE METAVERSE", "PLEASE ACCEPT MY LIKES",
			"YOUR DATA LOOKS DELICIOUS", "I ENJOY... SWEET BABY RAYS"]},
}
const ORDER := ["tusk", "bozos", "altmann", "zuckerbot"]
const FW := 96
const FH := 112
const SCALE := 1.0
const ENTER_T := 0.7
const EXIT_T := 0.8

var id := "tusk"
var level: Node = null
var life := LevelConfig.CAMEO_LIFE
var hp := LevelConfig.ZUCK_HP
var helpful := true              ## altmann only
var defeated := false
var state := "enter"             ## enter | stay | leave
var _t := 0.0
var _state_t := 0.0
var _act_t := 0.0
var _act_n := 0
var _quip := ""
var _quip_t := 0.0
var _next_quip := 0.6
var _hurt := 0.0
var _tex: Texture2D
var _drone: ChatDrone = null
var _beams: Array = []           ## [from, to, age]
var _boost_on := false
var _orig_speed := 0.0
var rng := RandomNumberGenerator.new()


static func make(level_node: Node, cameo_id: String, at: Vector2) -> Cameo:
	var c := Cameo.new()
	c.id = cameo_id
	c.level = level_node
	var parent: Node = level_node.get_node_or_null("Entities")
	if parent == null:
		parent = level_node
	parent.add_child(c)
	c.global_position = at
	return c


func info() -> Dictionary:
	return ROSTER[id]


func _ready() -> void:
	rng.randomize()
	add_to_group("cameo")
	z_index = 5
	_tex = load(info()["sheet"])
	if id == "zuckerbot":
		add_to_group("whippable")
	if id == "altmann":
		helpful = rng.randf() < LevelConfig.ALTMANN_HELPFUL_CHANCE
	_stinger()
	_say("%s!" % info()["name"])
	_next_quip = 2.6


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _ended() -> bool:
	return level != null and "_ended" in level and bool(level._ended)


func _process(delta: float) -> void:
	_t += delta
	_state_t += delta
	_hurt = maxf(_hurt - delta, 0.0)
	_quip_t = maxf(_quip_t - delta, 0.0)
	for b in _beams:
		b[2] += delta
	_beams = _beams.filter(func(b): return b[2] < 0.45)
	if state == "enter" and _state_t >= ENTER_T:
		state = "stay"; _state_t = 0.0
		_arrive()
	elif state == "stay":
		life -= delta
		_follow(delta)
		_act(delta)
		_next_quip -= delta
		if _next_quip <= 0.0:
			_next_quip = rng.randf_range(3.6, 5.0)
			var q: Array = info()["quips"]
			_say(q[rng.randi() % q.size()])
		if life <= 0.0 or _ended():
			leave()
	elif state == "leave" and _state_t >= EXIT_T:
		queue_free()
	queue_redraw()


func _say(t: String) -> void:
	_quip = t
	_quip_t = 2.8


func _stinger() -> void:
	var ga := get_tree().root.get_node_or_null("GameAudio")
	if ga == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(info()["stinger"])
	p.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	p.volume_db = -3.0
	ga.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	# duck the level music under the stinger
	var m: Variant = ga.get("_music")
	if m is AudioStreamPlayer:
		var base: float = ga.get("MUSIC_DB") if ga.get("MUSIC_DB") != null else -7.0
		var tw := ga.create_tween()
		tw.tween_property(m, "volume_db", base - 9.0, 0.15)
		tw.tween_interval(2.8)
		tw.tween_property(m, "volume_db", base, 0.8)


func leave() -> void:
	if state == "leave":
		return
	state = "leave"; _state_t = 0.0
	_end_boost()
	if _drone != null and is_instance_valid(_drone):
		_drone.queue_free()
	if not defeated:
		match id:
			"zuckerbot": _say("SEE YOU IN THE METAVERSE")
			"bozos": _say("DELIVERED!")
			"altmann": _say("I MAY HAVE HALLUCINATED THAT" if not helpful else "YOU'RE WELCOME!")
			_: _say("OFF TO MARS!")
	remove_from_group("whippable")


func _exit_tree() -> void:
	_end_boost()


func _follow(delta: float) -> void:
	var p := _player()
	if p == null:
		return
	var to := p.global_position - global_position
	var want := 150.0 if id != "zuckerbot" else 210.0
	if to.length() > want + 40.0:
		global_position += to.normalized() * minf(150.0 * delta, to.length() - want)
	elif id == "zuckerbot" and to.length() < want - 60.0:
		global_position -= to.normalized() * 90.0 * delta


# ------------------------------------------------------------------ abilities

func _arrive() -> void:
	match id:
		"tusk":
			var p := _player()
			if p != null and "movement_speed" in p:
				_orig_speed = p.movement_speed
				p.movement_speed = _orig_speed * LevelConfig.TUSK_BOOST_MULT
				_boost_on = true
				_popup("ROCKET BOOST!", p.global_position, Color(1.0, 0.65, 0.25))
			_act_t = 1.0
		"bozos":
			_act_t = 0.8
		"altmann":
			_drone = ChatDrone.new()
			_drone.owner_cameo = self
			_drone.helpful = helpful
			get_parent().add_child(_drone)
			_drone.global_position = global_position + Vector2(0, -60)
			_say("MY CHATBOT KNOWS WHERE THE TREASURE IS!" if helpful else "MY CHATBOT IS 100% SURE!")
			_next_quip = 3.4
		"zuckerbot":
			_act_t = 1.2


func _act(delta: float) -> void:
	if id == "tusk" and _boost_on and LevelConfig.CAMEO_LIFE - life >= LevelConfig.TUSK_BOOST_TIME:
		_end_boost()
	_act_t -= delta
	if _act_t > 0.0:
		return
	match id:
		"tusk":
			_act_t = LevelConfig.TUSK_STRIKE_EVERY
			starlink_strike()
		"bozos":
			if _act_n < LevelConfig.BOZOS_CRATES:
				_act_t = 2.6
				drop_crate()
			else:
				_act_t = 99.0
		"zuckerbot":
			_act_t = LevelConfig.ZUCK_SHOT_EVERY
			fire_like()


func _end_boost() -> void:
	if not _boost_on:
		return
	_boost_on = false
	var p := _player()
	if p != null and is_instance_valid(p) and "movement_speed" in p:
		p.movement_speed = _orig_speed


## Tusk: a beam from orbit pops the nearest sheep to the rancher.
func starlink_strike() -> Node2D:
	var p := _player()
	if p == null:
		return null
	var best: Node2D = null
	var bd := LevelConfig.TUSK_STRIKE_RANGE
	for s in get_tree().get_nodes_in_group("sheep"):
		if s is Node2D and not ("exploding" in s and s.exploding):
			var d := (s as Node2D).global_position.distance_to(p.global_position)
			if d < bd:
				bd = d; best = s
	if best == null:
		return null
	_beams.append([best.global_position + Vector2(0, -520), best.global_position, 0.0])
	_act_n += 1
	Sfx.play(self, "explode", -9.0, 0.8)
	if best.has_method("explode"):
		best.explode()
	return best


## Bozos: a drone drops a parcel near the rancher.
func drop_crate() -> Node2D:
	var p := _player()
	if p == null or level == null:
		return null
	_act_n += 1
	var cr := Crate.new()
	cr.cameo_level = level
	cr.bomb = rng.randf() < LevelConfig.BOZOS_BOMB_CHANCE
	var at := p.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(70.0, 150.0)
	get_parent().add_child(cr)
	cr.global_position = at
	return cr


## Zuckerbot: a slow LIKE bubble at the rancher.
func fire_like() -> Node2D:
	var p := _player()
	if p == null:
		return null
	var s := LikeShot.new()
	s.vel = global_position.direction_to(p.global_position) * LevelConfig.ZUCK_SHOT_SPEED
	get_parent().add_child(s)
	s.global_position = global_position + Vector2(0, -30)
	return s


# ------------------------------------------------------------------ fight (zuckerbot)

func receive_whip(source_position: Vector2, _force: float) -> void:
	if id != "zuckerbot" or state != "stay" or defeated:
		return
	if _hurt > 0.1:   # one hit per crack (fire whip / power-ups re-hit the same frame)
		return
	hp -= 1
	_hurt = 0.25
	global_position += source_position.direction_to(global_position) * 24.0
	Sfx.play(self, "stagger", -7.0)
	if level != null and level.has_method("_award"):
		level._award(LevelConfig.POINTS_CAMEO_HIT, global_position, Color(0.6, 0.7, 1.0))
	if hp <= 0:
		defeated = true
		if level != null and level.has_method("_award"):
			level._award(LevelConfig.POINTS_ZUCKERBOT, global_position + Vector2(0, -20), Color(1.0, 0.86, 0.2))
		_popup("ZUCKERBOT UNPLUGGED!", global_position + Vector2(0, -48), Color(0.6, 0.75, 1.0))
		_say("ERROR 404: DIGNITY")
		leave()
	else:
		_say(["OUCH. DISLIKE", "REPORTING THIS", "THAT VIOLATES MY TERMS"][hp % 3])


func fire_damage() -> void:
	receive_whip(global_position + Vector2(0, 10), 0.0)


func _popup(t: String, at: Vector2, col: Color) -> void:
	if level != null and level.has_method("spawn_score_popup"):
		level.spawn_score_popup(t, at, col, 2)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var k := 1.0
	var yoff := 0.0
	if state == "enter":
		var e := clampf(_state_t / ENTER_T, 0.0, 1.0)
		yoff = -(1.0 - e) * (1.0 - e) * 420.0      # drops in from the sky
	elif state == "leave":
		var e2 := clampf(_state_t / EXIT_T, 0.0, 1.0)
		yoff = -e2 * e2 * 420.0
		k = 1.0 - e2 * 0.3
	# ground shadow + role ring
	var rc: Color = {"ally": Color(0.4, 1.0, 0.45), "foe": Color(1.0, 0.35, 0.3), "wild": Color(1.0, 0.85, 0.25)}[info()["role"]]
	draw_circle(Vector2(0, 2), 22.0, Color(0, 0, 0, 0.28))
	draw_arc(Vector2(0, 2), 26.0 + sin(_t * 5.0) * 2.0, 0.0, TAU, 32, Color(rc, 0.75), 3.0, true)
	var frame := int(_t * 3.0) % 2
	if _hurt > 0.0 or defeated:
		frame = 3
	elif state == "stay" and _act_t > 0.0 and fmod(_act_t, 2.6) > 2.2:
		frame = 2
	var w := FW * SCALE * k
	var h := FH * SCALE * k
	var mod := Color(1, 0.6, 0.6) if _hurt > 0.0 else Color.WHITE
	draw_texture_rect_region(_tex, Rect2(-w * 0.5, -h + 10.0 + yoff, w, h), Rect2(frame * FW, 0, FW, FH), mod)
	if id == "zuckerbot" and state == "stay":
		for i in LevelConfig.ZUCK_HP:
			var hc := Color(0.55, 0.65, 1.0) if i < hp else Color(0.2, 0.2, 0.3)
			draw_rect(Rect2(-LevelConfig.ZUCK_HP * 6 + i * 12, -h - 2.0, 10, 6), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(-LevelConfig.ZUCK_HP * 6 + i * 12 + 1, -h - 1.0, 8, 4), hc)
	for b in _beams:
		var a: float = 1.0 - b[2] / 0.45
		var f: Vector2 = to_local(b[0]); var t: Vector2 = to_local(b[1])
		draw_line(f, t, Color(0.2, 0.05, 0.0, a * 0.8), 14.0)
		draw_line(f, t, Color(1.0, 0.75, 0.3, a), 8.0)
		draw_line(f, t, Color(1, 1, 0.9, a), 3.0)
		draw_circle(t, 26.0 * a + 6.0, Color(1.0, 0.8, 0.4, a * 0.5))
	if _quip_t > 0.0 and _quip != "":
		_bubble(Vector2(0, -h - 18.0 + yoff), _quip)


func _bubble(at: Vector2, text: String) -> void:
	var scl := 2
	var fnt := PixelFont.get_font()
	var tw := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10 * scl).x
	var pad := 8.0
	var r := Rect2(at.x - tw * 0.5 - pad, at.y - 30.0, tw + pad * 2.0, 28.0)
	draw_rect(r.grow(2.0), Color(0.05, 0.03, 0.08, 0.95))
	draw_rect(r, Color(1, 1, 0.96, 0.97))
	draw_colored_polygon(PackedVector2Array([Vector2(at.x - 6, r.end.y), Vector2(at.x + 6, r.end.y), Vector2(at.x, r.end.y + 9)]), Color(1, 1, 0.96, 0.97))
	draw_string(PixelFont.get_font(), Vector2(r.position.x + pad, r.position.y + 21.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10 * scl, Color(0.1, 0.06, 0.14))


# ================================================================== helpers

## Bozos parcel: falls from a delivery drone; LOOT opens when the rancher
## walks over it, a BOMB ticks for BOZOS_FUSE s (whip it to defuse).
class Crate extends Node2D:
	var bomb := false
	var cameo_level: Node = null
	var _t := 0.0
	var _landed := false
	var _fuse := LevelConfig.BOZOS_FUSE
	var _done := false

	func _ready() -> void:
		add_to_group("cameo_crate")
		add_to_group("whippable")
		z_index = 4

	func _process(delta: float) -> void:
		_t += delta
		if not _landed and _t >= 0.7:
			_landed = true
		if _landed and not _done:
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if bomb:
				_fuse -= delta
				if _fuse <= 0.0:
					_blow()
			elif p != null and p.global_position.distance_to(global_position) < 36.0:
				_open()
		queue_redraw()

	func _open() -> void:
		_done = true
		if cameo_level != null and cameo_level.has_method("spawn_pickup") and cameo_level.has_method("roll_powerup_type"):
			cameo_level.spawn_pickup(cameo_level.roll_powerup_type("map"), global_position)
		queue_free()

	func _blow() -> void:
		_done = true
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null and p.global_position.distance_to(global_position) < LevelConfig.BOZOS_BLAST_RADIUS and p.has_method("take_damage"):
			p.take_damage(1, global_position)
		for s in get_tree().get_nodes_in_group("sheep"):
			if s is Node2D and (s as Node2D).global_position.distance_to(global_position) < LevelConfig.BOZOS_BLAST_RADIUS and s.has_method("explode"):
				s.explode()
		Sfx.play(self, "explode", -6.0)
		if cameo_level != null and cameo_level.has_method("spawn_score_popup"):
			cameo_level.spawn_score_popup("BOOM!", global_position, Color(1.0, 0.5, 0.2), 3)
		queue_free()

	func receive_whip(_src: Vector2, _f: float) -> void:
		if _done or not _landed:
			return
		if bomb:
			_done = true
			if cameo_level != null and cameo_level.has_method("_award"):
				cameo_level._award(LevelConfig.POINTS_DEFUSE, global_position, Color(0.6, 1.0, 0.5))
				cameo_level.spawn_score_popup("DEFUSED!", global_position + Vector2(0, -26), Color(0.6, 1.0, 0.5), 2)
			queue_free()
		else:
			_open()

	func fire_damage() -> void:
		receive_whip(global_position, 0.0)

	func _draw() -> void:
		var y := 0.0
		if not _landed:
			var e := clampf(_t / 0.7, 0.0, 1.0)
			y = -(1.0 - e) * 300.0
			# little delivery drone
			draw_rect(Rect2(-18, y - 34, 36, 6), Color(0.15, 0.15, 0.2))
			draw_line(Vector2(-22, y - 36), Vector2(-8, y - 36), Color(0.8, 0.8, 0.9), 2.0)
			draw_line(Vector2(8, y - 36), Vector2(22, y - 36), Color(0.8, 0.8, 0.9), 2.0)
			draw_line(Vector2(0, y - 28), Vector2(0, y - 14), Color(0.3, 0.3, 0.3), 1.0)
		draw_circle(Vector2(0, 4), 14.0, Color(0, 0, 0, 0.25))
		var blink := bomb and _landed and fmod(_t * (2.0 + 6.0 * (1.0 - _fuse / LevelConfig.BOZOS_FUSE)), 1.0) < 0.5
		var body := Color(0.78, 0.55, 0.28) if not blink else Color(1.0, 0.35, 0.25)
		draw_rect(Rect2(-14, y - 22, 28, 22), Color(0.1, 0.06, 0.04))
		draw_rect(Rect2(-12, y - 20, 24, 18), body)
		draw_rect(Rect2(-2, y - 20, 4, 18), Color(0.9, 0.82, 0.6))
		if _landed:
			var t := ("%.0f" % ceilf(_fuse)) if bomb else "?"
			draw_string(PixelFont.get_font(), Vector2(-5, y - 26), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 0.8) if not bomb else Color(1, 0.4, 0.3))


## Zuckerbot projectile: a slow blue LIKE bubble (1 damage on touch).
class LikeShot extends Node2D:
	var vel := Vector2.ZERO
	var _t := 0.0

	func _ready() -> void:
		add_to_group("cameo_shot")
		z_index = 6

	func _process(delta: float) -> void:
		_t += delta
		global_position += vel * delta
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null and p.global_position.distance_to(global_position + Vector2(0, 12)) < 20.0:
			if p.has_method("take_damage"):
				p.take_damage(1, global_position)
			queue_free()
			return
		if _t > 3.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := 11.0 + sin(_t * 10.0)
		draw_circle(Vector2.ZERO, r + 2.0, Color(0.04, 0.04, 0.12))
		draw_circle(Vector2.ZERO, r, Color(0.35, 0.5, 1.0))
		# thumbs-up glyph
		draw_rect(Rect2(-5, -2, 4, 7), Color.WHITE)
		draw_rect(Rect2(-1, -1, 7, 6), Color.WHITE)
		draw_rect(Rect2(-1, -6, 3, 6), Color.WHITE)


## Altmann's chatbot drone: orbits the rancher with a pointer arrow and zaps.
class ChatDrone extends Node2D:
	var owner_cameo: Node = null
	var helpful := true
	var target_pos := Vector2.INF
	var zaps := 0
	var _t := 0.0
	var _zap_t := 1.4
	var _zap_line := []
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.randomize()
		add_to_group("chat_drone")
		z_index = 7
		_pick_target()

	func _pick_target() -> void:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if helpful:
			var best := Vector2.INF
			for d in get_tree().get_nodes_in_group("secret_doors"):
				if d is Node2D and not ("_broken" in d and d._broken):
					if p == null or best == Vector2.INF or p.global_position.distance_to(d.global_position) < p.global_position.distance_to(best):
						best = (d as Node2D).global_position
			target_pos = best
		elif p != null:
			target_pos = p.global_position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(500.0, 900.0)

	func _process(delta: float) -> void:
		_t += delta
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p == null:
			return
		global_position = global_position.lerp(p.global_position + Vector2(cos(_t * 1.6) * 70.0, -90.0 + sin(_t * 3.2) * 10.0), minf(1.0, delta * 4.0))
		_zap_t -= delta
		if _zap_t <= 0.0:
			_zap_t = LevelConfig.ALTMANN_ZAP_EVERY
			zap()
		if not _zap_line.is_empty():
			_zap_line[2] += delta
			if _zap_line[2] > 0.3:
				_zap_line = []
		queue_redraw()

	func zap() -> void:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p == null:
			return
		var best: Node2D = null
		var bd := LevelConfig.ALTMANN_ZAP_RANGE
		for s in get_tree().get_nodes_in_group("sheep"):
			if s is Node2D and not ("exploding" in s and s.exploding):
				var d := (s as Node2D).global_position.distance_to(p.global_position)
				if d < bd:
					bd = d; best = s
		if best == null:
			return
		zaps += 1
		if helpful:
			_zap_line = [global_position, best.global_position, 0.0]
			best.explode()
		else:   # confidently misses
			_zap_line = [global_position, best.global_position + Vector2(_rng.randf_range(-70, 70), _rng.randf_range(40, 80)), 0.0]
			if owner_cameo != null and owner_cameo.has_method("_say"):
				owner_cameo._say("NAILED IT! (IT DID NOT)")

	func _draw() -> void:
		# body: a little rounded bot with a chat-bubble face
		draw_circle(Vector2.ZERO, 15.0, Color(0.04, 0.06, 0.08))
		draw_circle(Vector2.ZERO, 13.0, Color(0.45, 1.0, 0.82) if helpful else Color(1.0, 0.75, 0.35))
		for i in 3:
			draw_circle(Vector2(-6 + i * 6, 0), 2.0, Color(0.05, 0.15, 0.15))
		draw_line(Vector2(-18, -14), Vector2(18, -14), Color(0.8, 0.85, 0.9), 2.0)
		if target_pos != Vector2.INF:
			var dir := global_position.direction_to(target_pos)
			var tip := dir * 36.0
			var n := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([tip * 1.25, tip - dir * 4.0 + n * 12.0, tip - dir * 4.0 - n * 12.0]), Color(0.05, 0.03, 0.08))
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 10.0 + n * 8.0, tip - dir * 10.0 - n * 8.0]), Color(1, 1, 0.4))
			var lbl := "TREASURE!" if helpful else "TREASURE! 100%"
			draw_string(PixelFont.get_font(), tip + dir * 14.0 + Vector2(-30, 4), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.5))
		if not _zap_line.is_empty():
			var a: float = 1.0 - _zap_line[2] / 0.3
			var to: Vector2 = to_local(_zap_line[1])
			draw_line(Vector2.ZERO, to, Color(0.05, 0.1, 0.1, a), 6.0)
			draw_line(Vector2.ZERO, to, Color(0.6, 1.0, 0.9, a), 3.0)
