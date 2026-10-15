class_name VladimirPuddin
extends ShlausKwobb
## Build 027 boss 9: VLADIMIR PUDDIN, THE BAREBACK STRONGMAN. A good-natured
## cartoon parody of a strongman leader: a shirtless judo master (white judo
## trousers, black belt) riding a stocky brown horse, in a frozen taiga arena.
## Art: tools/gen_boss9.py -> assets/boss9/puddin_128.png (10 frames of 128x112:
## the horse needs the room). Arena: puddin_level.gd. No real likeness.
##
## Runs on Shlaus Kwobb's fight engine with LevelConfig.BOSS9_* numbers, plus
## scripts/boss/finale.gd:
##  - TANK CHARGE: striped lanes (one through you), then toy tanks roll through
##  - JUDO THROW: a grab ring tracks you, locks, he pounces; caught = tossed
##  - ARENA SHAKE (phase 2+): a 1 s warning, then CONTROLS INVERTED for 3 s,
##    plus falling icicles from phase 2
##  - SNOWBALLS: a telegraphed fan (the Shlaus envelopes)
##  - THE BIG FREEZE: an icy ring with two gaps (the Shlaus reset)
##  - PHOTO OP shield at 23, 15 and 7 hearts
## 30 hearts - tougher than Violentsky.

const SHEET9 := preload("res://assets/boss9/puddin_128.png")
const FRAME_W := 128

var pounces := 0
var _pounce_t := 0.0
var _pounce_from := Vector2.ZERO
var _pounce_to := Vector2.ZERO


func _init() -> void:
	use_cfg(9)
	sheet = SHEET9
	projectile_skin = "snowball"
	ring_skin = "quake"
	quip_color = Color(0.75, 0.9, 1.0)
	hit_quips = ["NYET!", "THAT WAS A WARM-UP!", "I DO MY OWN STUNTS!", "MY HORSE SAW NOTHING!", "IS VERY COLD FOR WHIPPING!"]
	cast_quips = ["ROLL OUT THE TOYS!", "WATCH MY JUDO!", "MOTHER NATURE, SHAKE!", "SNOW TIME!"]
	shield_quips = ["PHOTO OP IN PROGRESS!", "GET MY GOOD SIDE!", "NO WHIPPING DURING PHOTOS!"]
	grab_quip = "YOU DARE GRAB THE STRONGMAN?!"
	press_quips = ["ONLY STATE CAMERAS!", "DELETE THAT PHOTO!", "NO SELFIES!"]
	defeat_quip = "I... WILL NEED A WARMER COAT"
	panel_quip = "PHOTO OP!"
	fire_quip = "FINALLY, SOME WARMTH!"
	hop_label = "GALLOP"
	panel_label = "PHOTO OP"
	press_label = "NO CAMERAS!"


func _ready() -> void:
	super()
	# 128-wide frames (horse + rider); same 10-frame layout as bosses 4-8
	_spr.hframes = 10


func _fire_custom(kind: String, p: Node2D) -> void:
	match kind:
		"tank":
			_tanks(p)
		"judo":
			_judo(p)
		"quake":
			_quake(p)


func _tanks(p: Node2D) -> void:
	var i := phase() - 1
	var n: int = int(LevelConfig.BOSS9_TANKS[i])
	var tell: float = float(LevelConfig.BOSS9_TANK_TELL[i])
	var w: float = LevelConfig.BOSS9_TANK_WIDTH
	var horizontal := rng.randf() < 0.6
	var pp := p.global_position
	var used: Array[float] = []
	for k in n:
		var off := 0.0
		if k > 0:
			var guard := 0
			while guard < 20:
				guard += 1
				off = rng.randf_range(-1.0, 1.0) * (arena.size.y * 0.45 if horizontal else arena.size.x * 0.45)
				var ok := true
				for u in used:
					if absf(off - u) < w * 2.4:
						ok = false
				if ok:
					break
		used.append(off)
		var lane := Finale.TankLane.new()
		lane.level = level
		lane.tell = tell + 0.18 * k
		lane.width = w
		if horizontal:
			var y := clampf(pp.y + off, arena.position.y + 10.0, arena.end.y - 10.0)
			var left := rng.randf() < 0.5
			lane.from = Vector2(arena.position.x - 80.0 if left else arena.end.x + 80.0, y)
			lane.to = Vector2(arena.end.x + 120.0 if left else arena.position.x - 120.0, y)
		else:
			var x := clampf(pp.x + off, arena.position.x + 10.0, arena.end.x - 10.0)
			var top := rng.randf() < 0.5
			lane.from = Vector2(x, arena.position.y - 80.0 if top else arena.end.y + 80.0)
			lane.to = Vector2(x, arena.end.y + 120.0 if top else arena.position.y - 120.0)
		_fx_parent().add_child(lane)
	Sfx.play(self, "warn", -9.0, 1.1)


func _judo(p: Node2D) -> void:
	var i := phase() - 1
	var g := Finale.JudoGrab.new()
	g.level = level
	g.boss = self
	g.arena = arena
	g.track = float(LevelConfig.BOSS9_JUDO_TRACK[i])
	g.lock = float(LevelConfig.BOSS9_JUDO_LOCK[i])
	_fx_parent().add_child(g)
	g.global_position = p.global_position


func _quake(_p: Node2D) -> void:
	var q := Finale.Quake.new()
	q.level = level
	q.arena = arena
	q.icicles = int(LevelConfig.BOSS9_ICICLES[phase() - 1])
	_fx_parent().add_child(q)


## JudoGrab calls this when it fires: a short leap onto the grab ring.
func judo_pounce(to: Vector2) -> void:
	if state == S.DEFEATED:
		return
	pounces += 1
	_pounce_from = global_position
	_pounce_to = _clamp_rect(to + Vector2(0, -24), arena)
	_pounce_t = 0.22
	_quip("HAJIME!", quip_color)


func _physics_process(delta: float) -> void:
	if _pounce_t > 0.0 and state != S.DEFEATED:
		_pounce_t = maxf(_pounce_t - delta, 0.0)
		global_position = _pounce_to.lerp(_pounce_from, _pounce_t / 0.22)
	super(delta)
