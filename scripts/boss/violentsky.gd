class_name ZelodymerViolentsky
extends ShlausKwobb
## Build 025 boss 8: ZELODYMER VIOLENTSKY, THE COMEDIAN COMMANDER. A
## good-natured cartoon parody of a comedian-turned-leader (short dark hair,
## stubble, olive tee, cargo trousers, a drone tablet, a stand-up microphone).
## Art: tools/gen_boss7.py -> assets/boss8/violentsky_96.png.
## Arena: violentsky_level.gd. No real likeness, no war imagery: the drones
## are toy quadcopters that pop in a cartoon burst.
##
## Runs on Shlaus Kwobb's fight engine with LevelConfig.BOSS8_* numbers, plus
## the drone swarm (scripts/boss/drones.gd):
##  - DRONES: a swarm flies out, hovers over telegraphed circles (one on you),
##    then dives and pops. Whip them out of the air for points.
##  - SWARM (phase 3+): a ring of drones from all sides around you
##  - SUNFLOWER SEEDS: a telegraphed fan (the Shlaus envelopes)
##  - STANDING OVATION: a gold ring with two gaps (the Shlaus reset)
##  - ON A CALL shield at 20, 13 and 6 hearts
## 26 hearts - the toughest fight in the game.

const SHEET8 := preload("res://assets/boss8/violentsky_96.png")


func _init() -> void:
	use_cfg(8)
	sheet = SHEET8
	projectile_skin = "seed"
	ring_skin = "applause"
	quip_color = Color(1.0, 0.86, 0.35)
	hit_quips = ["TOUGH CROWD!", "IS THIS THING ON?", "OOF, RIGHT IN THE PUNCHLINE!", "HECKLER!", "I'M HERE ALL WEEK!"]
	cast_quips = ["SEND IN THE BUZZERS!", "AND FOR MY NEXT TRICK...", "LIVE FROM THE WHEAT FIELD!", "DRONE-ING ON AND ON!"]
	shield_quips = ["SORRY, I'M ON A CALL!", "HOLD, PLEASE!", "I HAVE TO TAKE THIS!"]
	grab_quip = "HEY! NOT THE T-SHIRT!"
	press_quips = ["WE'RE LIVE, KEEP ROLLING!", "GET MY GOOD SIDE!", "NO RETAKES!"]
	defeat_quip = "THAT'S A WRAP... GOOD NIGHT!"
	panel_quip = "ON A CALL!"
	fire_quip = "MY SUNFLOWER SEEDS ARE ROASTED!"
	hop_label = "QUICK EXIT"
	panel_label = "ON A CALL"
	press_label = "LIVE!"


func live_drone_count() -> int:
	return get_tree().get_nodes_in_group("drone").size()


func choose_attack() -> String:
	var k := super.choose_attack()
	if (k == "drones" or k == "swarm") and live_drone_count() >= LevelConfig.BOSS8_DRONE_CAP:
		return "envelopes"
	return k


func _fire_custom(kind: String, p: Node2D) -> void:
	match kind:
		"drones":
			_launch(p, false)
		"swarm":
			_launch(p, true)


func _launch(p: Node2D, ring: bool) -> void:
	var i := phase() - 1
	var n: int = int(LevelConfig.BOSS8_SWARM[i]) if ring else int(LevelConfig.BOSS8_DRONES[i])
	if ring and n <= 0:
		n = int(LevelConfig.BOSS8_DRONES[i])
	n = mini(n, LevelConfig.BOSS8_DRONE_CAP - live_drone_count())
	if n <= 0:
		return
	var hover: float = LevelConfig.BOSS8_DRONE_HOVER[i]
	var blast: float = LevelConfig.BOSS8_DRONE_BLAST
	var inner := arena.grow(-30.0)
	var targets: Array = [p.global_position.clamp(inner.position, inner.end)]
	if ring:
		var a0 := rng.randf() * TAU
		var rr := rng.randf_range(110.0, 140.0)
		for k in n - 1:
			var a := a0 + TAU * k / float(n - 1)
			targets.append((p.global_position + Vector2(cos(a) * rr, sin(a) * rr * 0.75)).clamp(inner.position, inner.end))
	else:
		var guard := 0
		while targets.size() < n and guard < 60:
			guard += 1
			var a := rng.randf() * TAU
			var d := rng.randf_range(blast * 1.9, blast * 3.6)
			var c := (p.global_position + Vector2(cos(a) * d, sin(a) * d * 0.75)).clamp(inner.position, inner.end)
			var ok := true
			for o in targets:
				if c.distance_to(o) < blast * 1.7:
					ok = false
			if ok:
				targets.append(c)
	Sfx.play(self, "drone_buzz", -8.0)
	for k in targets.size():
		var d := Drones.Drone.new()
		d.level = level
		d.target = targets[k]
		d.hover_time = hover + (0.15 * k if not ring else 0.05 * k)
		d.global_position = global_position + Vector2(rng.randf_range(-20, 20), -10)
		_fx_parent().add_child(d)
