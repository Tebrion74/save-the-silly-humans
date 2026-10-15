class_name ReanaldRogan
extends ShlausKwobb
## Build 025 boss 7: REANALD ROGAN, THE GIPPER OF THE GALAXY. A good-natured
## cartoon parody of an old actor-turned-president (dark pompadour, grey
## temples, navy suit, red tie, a toy satellite remote, a jar of jelly beans).
## Art: tools/gen_boss7.py -> assets/boss7/rogan_96.png. Arena: rogan_level.gd.
##
## Runs on Shlaus Kwobb's fight engine with LevelConfig.BOSS7_* numbers, plus
## the "Star Wars" missile-defence toolkit (scripts/boss/starwars.gd):
##  - ORBITAL LASER: target circles (one on you), then beams from orbit
##  - SATELLITE BEAM: a line through you, then it sweeps; step to the safe side
##  - UFOs (phase 2+): drift over the arena, drop tractor beams; pop them
##  - JELLY BEANS: a telegraphed fan (the Shlaus envelopes)
##  - STAR WARS SHIELD at 18, 12 and 6 hearts
## 24 hearts.

const SHEET7 := preload("res://assets/boss7/rogan_96.png")


func _init() -> void:
	use_cfg(7)
	sheet = SHEET7
	projectile_skin = "jellybean"
	ring_skin = ""
	quip_color = Color(0.7, 0.85, 1.0)
	hit_quips = ["THERE YOU GO AGAIN!", "WELL...", "WINNING ONE FOR THE GIPPER!", "I PAID FOR THIS MICROPHONE!", "HONEY, I FORGOT TO DUCK!"]
	cast_quips = ["PEACE THROUGH LASERS!", "IT'S MORNING IN THE PASTURE!", "ACTIVATE THE STAR SHIELD!", "MISSION CONTROL, GO!"]
	shield_quips = ["STAR WARS SHIELD UP!", "TRUST, BUT DEFLECT!", "THE SHIELD IS DEFENSIVE!"]
	grab_quip = "MR. RANCHER, LET GO OF THIS SUIT!"
	press_quips = ["NO QUESTIONS, I'M LATE FOR LUNCH!", "WELL, I DON'T RECALL!", "TALK TO MY PRESS SECRETARY!"]
	defeat_quip = "MR. RANCHER... YOU TORE DOWN MY SHIELD"
	panel_quip = "STAR SHIELD!"
	fire_quip = "MY JELLY BEANS ARE TOASTED!"
	hop_label = "SHUTTLE HOP"
	panel_label = "STAR SHIELD"
	press_label = "NO QUESTIONS!"


func live_ufo_count() -> int:
	return get_tree().get_nodes_in_group("ufo").size()


func choose_attack() -> String:
	var k := super.choose_attack()
	# no UFO roll while the sky is full
	if k == "ufo" and live_ufo_count() >= LevelConfig.BOSS7_UFO_CAP:
		return "orbital"
	return k


func _fire_custom(kind: String, p: Node2D) -> void:
	match kind:
		"orbital":
			_orbital(p)
		"satbeam":
			_satbeam(p)
		"ufo":
			_ufos(p)


func _orbital(p: Node2D) -> void:
	var i := phase() - 1
	var n: int = LevelConfig.BOSS7_ORBITAL_COUNT[i]
	var tell: float = LevelConfig.BOSS7_ORBITAL_TELL[i]
	var r: float = LevelConfig.BOSS7_ORBITAL_RADIUS
	var inner := arena.grow(-36.0)
	var pts: Array = [p.global_position.clamp(inner.position, inner.end)]
	var guard := 0
	while pts.size() < n and guard < 80:
		guard += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(r * 2.1, r * 4.0)
		var c := (p.global_position + Vector2(cos(a) * d, sin(a) * d * 0.75)).clamp(inner.position, inner.end)
		var ok := true
		for o in pts:
			if c.distance_to(o) < r * 2.0:
				ok = false
		if ok:
			pts.append(c)
	Sfx.play(self, "radio", -8.0, 1.2)
	for k in pts.size():
		var s := StarWars.OrbitalStrike.new()
		s.level = level
		s.tell = tell + 0.12 * k
		s.radius = r
		s.global_position = pts[k]
		_fx_parent().add_child(s)


func _satbeam(p: Node2D) -> void:
	var i := phase() - 1
	var b := StarWars.SatBeam.new()
	b.level = level
	b.tell = float(LevelConfig.BOSS7_BEAM_TELL[i])
	b.sweep = deg_to_rad(float(LevelConfig.BOSS7_BEAM_SWEEP_DEG[i]))
	var cx := arena.get_center().x + rng.randf_range(-260.0, 260.0)
	var pivot := Vector2(cx, arena.position.y - 30.0)
	b.angle = pivot.angle_to_point(p.global_position)
	b.dir_sign = -1.0 if rng.randf() < 0.5 else 1.0
	b.global_position = pivot
	_fx_parent().add_child(b)
	Sfx.play(self, "warn", -10.0, 1.3)


func _ufos(p: Node2D) -> void:
	var i := phase() - 1
	var n: int = mini(int(LevelConfig.BOSS7_UFO_COUNT[i]), LevelConfig.BOSS7_UFO_CAP - live_ufo_count())
	if n <= 0:
		_orbital(p)
		return
	for k in n:
		var u := StarWars.Ufo.new()
		u.level = level
		u.arena = arena
		var x := arena.position.x + 60.0 + rng.randf() * (arena.size.x - 120.0)
		u.global_position = Vector2(x, arena.position.y + 40.0)
		_fx_parent().add_child(u)
