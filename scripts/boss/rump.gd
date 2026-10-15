class_name DonaldRump
extends ShlausKwobb
## Build 027 boss 10, THE FINAL BOSS: DONALD RUMP. A good-natured cartoon
## parody of a tycoon golfer (a big golden swoop of hair, navy suit, an extra-long
## red tie, a white golf glove and a gold driver). Golf course arena with a
## gold tower: rump_level.gd. Art: tools/gen_boss9.py -> assets/boss10/rump_96.png.
## No real likeness, no slogans: his crowd wears plain red caps.
##
## Shlaus engine with LevelConfig.BOSS10_* numbers, plus scripts/boss/finale.gd:
##  - GOLF BALL DRIVES: "FORE!" marks around you (one on you), then impacts
##  - WALL DROP: gold walls slam down and partition the arena for a while
##  - RED-HAT CROWD: chasers - one whip sends a fan home
##  - GOLF BALLS: a telegraphed fan (the Shlaus envelopes)
##  - "YOU'RE FIRED!" rage at 8 hearts: a pink-slip ring with three gaps,
##    everything faster; TEE TIME shield at 26, 17 and 8 hearts
## 34 hearts - the most epic fight in the game.

const SHEET10 := preload("res://assets/boss10/rump_96.png")

var fired_shown := false


func _init() -> void:
	use_cfg(10)
	sheet = SHEET10
	projectile_skin = "golfball"
	ring_skin = "applause"
	quip_color = Color(1.0, 0.82, 0.3)
	hit_quips = ["WRONG!", "TOTALLY UNFAIR!", "I'VE HAD BIGGER WHIPPINGS!", "SAD!", "NOBODY WHIPS BETTER THAN ME!", "THAT WAS A MULLIGAN!"]
	cast_quips = ["FORE!", "BUILD THE WALLS!", "WHAT A CROWD! BIGGEST EVER!", "TREMENDOUS SWING!"]
	shield_quips = ["IT'S MY TEE TIME!", "I'M ON THE BACK NINE!", "NO WHIPPING ON THE GREEN!"]
	grab_quip = "HANDS OFF THE SUIT! IT'S VERY EXPENSIVE!"
	press_quips = ["FAKE CAMERAS!", "WHO LET THE PRESS ON MY COURSE?", "NO PICTURES!"]
	defeat_quip = "I CONCEDE... THE HOLE. JUST THE HOLE."
	panel_quip = "TEE TIME!"
	fire_quip = "MY HAIR! NOT THE HAIR!"
	hop_label = "GOLF CART"
	panel_label = "TEE TIME"
	press_label = "FAKE CAMS!"


func live_wall_count() -> int:
	return get_tree().get_nodes_in_group("wall_drop").size()


func live_crowd_count() -> int:
	return get_tree().get_nodes_in_group("crowd").size()


func choose_attack() -> String:
	var k := super.choose_attack()
	if k == "walls" and live_wall_count() >= LevelConfig.BOSS10_WALL_CAP:
		return "drive"
	if k == "crowd" and live_crowd_count() >= LevelConfig.BOSS10_CROWD_CAP:
		return "drive"
	return k


func take_hit(amount: int, source: String, from_pos: Vector2) -> bool:
	var ok := super.take_hit(amount, source, from_pos)
	if ok and not fired_shown and hearts > 0 and phase() >= 4:
		_youre_fired()
	return ok


## The rage-phase entrance: a big "YOU'RE FIRED!" and the pink-slip ring.
func _youre_fired() -> void:
	fired_shown = true
	ring_skin = "fired"
	Sfx.play(self, "fired", -2.0)
	_quip("YOU'RE FIRED!", Color(1.0, 0.35, 0.3))
	var hud: Node = level.get("hud") if level != null and is_instance_valid(level) and "hud" in level else null
	if hud != null and hud.has_method("show_callout"):
		hud.show_callout("YOU'RE FIRED!", "DONALD RUMP IS IN A RAGE", Color(1.0, 0.4, 0.3), 1.6)
	if level != null and level.has_method("shake_camera"):
		level.shake_camera(0.5, 7.0)


func _fire_custom(kind: String, p: Node2D) -> void:
	match kind:
		"drive":
			_drives(p)
		"walls":
			_walls(p)
		"crowd":
			_crowd(p)
		"fired":
			_quip("YOU'RE FIRED!", Color(1.0, 0.35, 0.3))
			Sfx.play(self, "fired", -4.0)
			_spawn_reset(p)
			_drives(p, 2)


func _drives(p: Node2D, override_n: int = 0) -> void:
	var i := phase() - 1
	var n: int = override_n if override_n > 0 else int(LevelConfig.BOSS10_DRIVES[i])
	var tell: float = float(LevelConfig.BOSS10_DRIVE_TELL[i])
	var r: float = LevelConfig.BOSS10_DRIVE_RADIUS
	var inner := arena.grow(-30.0)
	var pts: Array = [p.global_position.clamp(inner.position, inner.end)]
	var guard := 0
	while pts.size() < n and guard < 80:
		guard += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(r * 2.2, r * 4.6)
		var c := (p.global_position + Vector2(cos(a) * d, sin(a) * d * 0.75)).clamp(inner.position, inner.end)
		var ok := true
		for o in pts:
			if c.distance_to(o) < r * 2.1:
				ok = false
		if ok:
			pts.append(c)
	Sfx.play(self, "golf", -6.0, rng.randf_range(0.95, 1.05))
	for k in pts.size():
		var s := Finale.MarkedStrike.new()
		s.level = level
		s.kind = "golf"
		s.tell = tell + 0.14 * k
		s.radius = r
		s.origin = global_position + Vector2(0, -30)
		_fx_parent().add_child(s)
		s.global_position = pts[k]


func _walls(p: Node2D) -> void:
	var i := phase() - 1
	var n: int = mini(int(LevelConfig.BOSS10_WALLS[i]), LevelConfig.BOSS10_WALL_CAP - live_wall_count())
	if n <= 0:
		_drives(p)
		return
	var tell: float = float(LevelConfig.BOSS10_WALL_TELL[i])
	var L: float = LevelConfig.BOSS10_WALL_LEN
	var T: float = LevelConfig.BOSS10_WALL_THICK
	var inner := arena.grow(-40.0)
	for k in n:
		var vertical := rng.randf() < 0.5
		var w := Finale.WallDrop.new()
		w.level = level
		w.tell = tell + 0.15 * k
		w.size = Vector2(T, L * 0.75) if vertical else Vector2(L, T)
		var c := p.global_position
		if k == 0:
			# the first wall drops right on you (step off the shadow)
			c += Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 20))
		else:
			var a := rng.randf() * TAU
			c += Vector2(cos(a), sin(a) * 0.75) * rng.randf_range(120.0, 220.0)
		w.position = c.clamp(inner.position, inner.end)
		_fx_parent().add_child(w)
		w.global_position = c.clamp(inner.position, inner.end)
	Sfx.play(self, "warn", -10.0, 0.9)


func _crowd(p: Node2D) -> void:
	var i := phase() - 1
	var n: int = mini(int(LevelConfig.BOSS10_CROWD[i]), LevelConfig.BOSS10_CROWD_CAP - live_crowd_count())
	if n <= 0:
		_drives(p)
		return
	Sfx.play(self, "crowd", -6.0)
	var pts := pick_spawn_points(global_position, p.global_position, n)
	for k in pts.size():
		var f := Finale.RallyFan.new()
		f.level = level
		f.arena = arena.grow(20.0)
		f.speed = float(LevelConfig.BOSS10_CROWD_SPEED[i]) * rng.randf_range(0.9, 1.1)
		_fx_parent().add_child(f)
		f.global_position = pts[k]
