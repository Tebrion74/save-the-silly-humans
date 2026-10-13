class_name DebugScenarios
extends RefCounted
## Build 014: canned situations for screenshots and manual testing.
## DEBUG BUILDS ONLY: GameProgress reads the scenario only when
## OS.is_debug_build() (editor, or a web build exported with --export-debug),
## and run() refuses otherwise, so the shipped release export ignores it.
##   native : godot --path . -- --scenario=cam_humans [--level=3] [--touch]
##   web    : index.html?scenario=cam_karens&level=3&touch=1 (debug export)
## Scenarios: cam_humans, cam_karens, swing, inventory, pose_down/up/left,
## howto (title screen).
## Build 014b reticle: reticle_pc (whip, sheep + Karen-free; move the mouse),
## reticle_pc_karen (level 3: whip, Karens in reach), reticle_touch_whip,
## reticle_touch_cam (use with touch=1).
## Build 015 boss (the title jumps straight to the boss arena): boss_title,
## boss_attack (spread + lob in the air, 6 hearts), boss_hearts (whip hit at
## 4 -> 3 hearts, reticle on him), boss_pose (MSM Cam filming him),
## boss_win (last heart -> defeat -> win screen), boss_volley (rage attacks),
## boss_rage (015b: radial burst with its gap + double lob).
## Build 016: bonus stage (bonus, bonus_waves = mid-swoop, bonus_tally =
## perfect tally, bonus2 / bonus3 = later stages) and Huval Yarheyhey
## (huval_title, huval_fight = programmed + micro sheep on the field,
## huval_ray, huval_update, huval_lecture, huval_win).
## Add touch=1 / --touch for the mobile layout.


const START_DELAY := 2.9


static func run(lvl: Node, scenario: String) -> void:
	if not OS.is_debug_build():
		return
	var p := lvl.get_node_or_null("Entities/Player") as Node2D
	if p == null or lvl.cam == null:
		return
	# Let the "LEVEL n" banner fade first (screenshots).
	await lvl.get_tree().create_timer(START_DELAY).timeout
	if not is_instance_valid(p):
		return
	print("[debug] running scenario ", scenario)
	# Invulnerable for the shot (grab-ghost window), sheep parked far away.
	p.begin_grab_ghost(600.0)
	p.facing = Vector2.RIGHT
	_park_sheep(lvl, p)
	var pu: PowerUps = lvl.power_ups
	var cam: MsmCam = lvl.cam
	# build 020 scenarios (no cam)
	if scenario == "star_combo":
		await _run_star_combo(lvl, p)
		return
	if scenario == "extra_heart":
		p.end_grab_ghost()
		return
	if scenario == "reticle_busy":
		lvl.weapons.select_id("whip")
		_freeze_sheep_at(lvl, p, [Vector2(150, -40), Vector2(-200, 120), Vector2(260, 140), Vector2(-120, -160), Vector2(330, -120)])
		_stage_bystanders(lvl, p)
		lvl.spawn_map_powerup("fire_whip")
		return
	pu.grant("msm_cam")
	match scenario:
		"cantifa_post", "cantifa_shoot", "cantifa_film":
			_stage_cantifa(lvl, p, scenario)
		"cam_humans":
			cam.battery = 13.0
			pu.spare_batteries = 2
			_stage_humans(lvl, p, true)
			cam.debug_aim = Vector2.RIGHT
			cam.debug_force_film = true
		"inventory":
			cam.battery = 9.0
			pu.spare_batteries = 2
			pu.grant("long_whip")
			pu.fire_charges = 7
			pu.shock_charges = 2
			pu.changed.emit()
			_stage_humans(lvl, p, true)
			cam.debug_aim = Vector2.RIGHT
			cam.debug_force_film = true
		"cam_karens":
			cam.battery = 16.0
			pu.spare_batteries = 1
			_stage_karens(lvl, p, [Vector2(330, -44), Vector2(352, 6), Vector2(372, 48), Vector2(392, -18), Vector2(405, 26)])
			_stage_bystanders(lvl, p)
			cam.expose_time = LevelConfig.CAM_EXPOSE_SECONDS - 0.9
			cam.debug_aim = Vector2.RIGHT
			cam.debug_force_film = true
		"pose_down", "pose_up", "pose_left":
			cam.battery = 15.0
			cam.debug_aim = {"pose_down": Vector2.DOWN, "pose_up": Vector2.UP, "pose_left": Vector2.LEFT}[scenario]
			cam.debug_force_film = true
		"reticle_pc", "reticle_pc_karen", "reticle_touch_whip":
			lvl.weapons.select_id("whip")
			if scenario == "reticle_pc_karen":
				_stage_karens(lvl, p, [Vector2(150, -40), Vector2(330, 120)])
				for k in lvl.get_tree().get_nodes_in_group("karens"):
					k.set_physics_process(false)
			elif scenario == "reticle_pc":
				_freeze_sheep_at(lvl, p, [Vector2(160, -50), Vector2(-260, 150)])
			else:
				p.facing = Vector2(1, -1).normalized()
				_freeze_sheep_at(lvl, p, [Vector2(-200, 160)])
			_stage_bystanders(lvl, p)
			if lvl.reticle != null:
				lvl.reticle.debug_bright = true
		"reticle_touch_cam":
			cam.battery = 14.0
			pu.spare_batteries = 1
			p.facing = Vector2.RIGHT
			_stage_humans(lvl, p, false)
			if lvl.reticle != null:
				lvl.reticle.debug_bright = true
		"swing":
			cam.battery = 0.0
			pu.spare_batteries = 0
			_stage_karens(lvl, p, [Vector2(70, -26), Vector2(88, 22), Vector2(112, -4)])
			_place_sheep_near(lvl, p, [Vector2(96, 60), Vector2(64, -64)])
			cam.debug_aim = Vector2.RIGHT
			var auto := AutoSwing.new()
			auto.cam = cam
			lvl.add_child(auto)
	pu.changed.emit()



## Build 017 screenshots. Posts Cantifa just outside the safe zone.
static func _stage_cantifa(lvl: Node, p: Node2D, scenario: String) -> void:
	var safe := lvl.get_node_or_null("Entities/SafeZone") as Node2D
	if safe == null:
		return
	p.global_position = safe.global_position + Vector2(-40, -250)
	p.facing = Vector2.DOWN
	# park the opening humans so the posts read clearly
	var hi := 0
	for h in lvl.get_tree().get_nodes_in_group("humans"):
		if h is Node2D:
			(h as Node2D).global_position = safe.global_position + Vector2(-420, -80 + hi * 36)
			hi += 1
	var posts: Array = lvl.cantifa_posts()
	var want := 3
	var made: Array = []
	for i in posts.size():
		if made.size() >= want:
			break
		var post: Dictionary = posts[i]
		if (post["pos"] as Vector2).distance_to(safe.global_position) > 220.0:
			continue
		var c: Cantifa = Cantifa.make(lvl.get_node("Entities/Humans"), post["pos"])
		c.level = lvl
		c.post_pos = post["pos"]
		c.post_face = post["face"]
		c.arriving = false
		made.append(c)
	if made.is_empty():
		return
	if scenario == "cantifa_shoot":
		var gun: Cantifa = made[0]
		var best_d := gun.global_position.distance_to(p.global_position)
		for c in made:
			var d: float = (c as Node2D).global_position.distance_to(p.global_position)
			# the one just outside the zone, not the corner
			if d < best_d and d > 80.0:
				best_d = d
				gun = c
		gun.windup = 8.0
		var aim: Vector2 = gun.global_position.direction_to(p.global_position).normalized()
		var b := CantifaBullet.launch(lvl.get_node("Entities"), gun.global_position + aim * 40.0, aim)
		b.speed = 0.0
		b.max_dist = 9999.0
	if scenario == "cantifa_film":
		var cam: MsmCam = lvl.cam
		lvl.power_ups.grant("msm_cam")
		cam.battery = 16.0
		# stand so the cone covers a Cantifa and two humans
		var gun2: Node2D = made[0]
		p.global_position = gun2.global_position + Vector2(0, -160)
		p.facing = Vector2.DOWN
		cam.debug_aim = Vector2.DOWN
		cam.debug_force_film = true
		var humans := lvl.get_tree().get_nodes_in_group("humans")
		for i in mini(3, humans.size()):
			(humans[i] as Node2D).global_position = gun2.global_position + Vector2(-30 + i * 40, 70)
		var camp := lvl.get_node_or_null("Entities/HumanCamp")
		if camp != null:
			for o in [Vector2(180, 40), Vector2(220, -30)]:
				var kh = camp.spawn_one(false)
				if kh == null:
					break
				var spr := kh.get_node_or_null("Sprite") as Node2D
				if spr:
					spr.scale = Vector2.ONE
				(kh as Node2D).global_position = p.global_position + o
				kh._become_possessed()
				kh.become_karen()


## Build 020: INVINCIBLE with a running combo (humans, possessed, sheep saved).
static func _run_star_combo(lvl: Node, p: Node2D) -> void:
	p.end_grab_ghost()
	lvl.weapons.select_id("whip")
	lvl.power_ups.grant("invincible")
	var offs := [Vector2(140, -30), Vector2(200, 60), Vector2(-160, 40), Vector2(90, 150), Vector2(-120, -110), Vector2(250, -90)]
	var targets: Array = []
	var humans := lvl.get_tree().get_nodes_in_group("humans")
	for i in mini(humans.size(), 4):
		var h: Node2D = humans[i]
		h.global_position = p.global_position + offs[i]
		targets.append(h)
	if targets.size() >= 2 and targets[1].has_method("_become_possessed"):
		targets[1]._become_possessed()
	var flock := lvl.get_tree().get_nodes_in_group("sheep")
	for i in mini(flock.size(), 2):
		var sh: Node2D = flock[i]
		sh.global_position = p.global_position + offs[4 + i]
		sh.set_physics_process(false)
		targets.append(sh)
	await lvl.get_tree().create_timer(0.3).timeout
	for i in mini(targets.size(), 4):
		if is_instance_valid(targets[i]):
			lvl.star_save(targets[i], p.global_position)
		await lvl.get_tree().create_timer(0.22).timeout


static func _park_sheep(lvl: Node, p: Node2D) -> void:
	var i := 0
	for sh in lvl.get_tree().get_nodes_in_group("sheep"):
		if sh is Node2D and (sh as Node2D).global_position.distance_to(p.global_position) < 900.0:
			(sh as Node2D).global_position = p.global_position + Vector2(-1100 + i * 40, -500)
		if "stagger_timer" in sh:
			sh.stagger_timer = 120.0
		i += 1


static func _place_sheep_near(lvl: Node, p: Node2D, offsets: Array) -> void:
	var flock := lvl.get_tree().get_nodes_in_group("sheep")
	for i in mini(offsets.size(), flock.size()):
		var sh: Node2D = flock[i]
		sh.global_position = p.global_position + offsets[i]
		sh.stagger_timer = 0.0


## Sheep moved next to the rancher and frozen (long stagger) for a still shot.
static func _freeze_sheep_at(lvl: Node, p: Node2D, offsets: Array) -> void:
	var flock := lvl.get_tree().get_nodes_in_group("sheep")
	for i in mini(offsets.size(), flock.size()):
		var sh: Node2D = flock[i]
		sh.global_position = p.global_position + offsets[i]
		sh.stagger_timer = 120.0


static func _stage_humans(lvl: Node, p: Node2D, convinced_one: bool) -> void:
	var offs := [Vector2(150, -25), Vector2(232, 34), Vector2(305, -36), Vector2(372, 28), Vector2(40, 190)]
	var humans := lvl.get_tree().get_nodes_in_group("humans")
	for i in mini(humans.size(), offs.size()):
		var h: Node2D = humans[i]
		h.global_position = p.global_position + offs[i]
		h.wander_speed = 16.0
	if convinced_one and humans.size() > 1:
		humans[0].convince = 0.99
		humans[0].cam_film(0.1)
		humans[1].convince = 0.55
		humans[1].cam_film(0.0)


static func _stage_bystanders(lvl: Node, p: Node2D) -> void:
	var offs := [Vector2(-170, 120), Vector2(-240, 40), Vector2(-120, -150), Vector2(-60, 200)]
	var humans := lvl.get_tree().get_nodes_in_group("humans")
	for i in mini(humans.size(), offs.size()):
		var h: Node2D = humans[i]
		h.global_position = p.global_position + offs[i]
		h.wander_speed = 30.0


static func _stage_karens(lvl: Node, p: Node2D, offs: Array) -> void:
	var camp := lvl.get_node_or_null("Entities/HumanCamp")
	if camp == null:
		return
	for o in offs:
		var h: Node = camp.spawn_one()
		if h == null:
			return
		var spr := h.get_node_or_null("Sprite") as Node2D
		if spr:
			spr.scale = Vector2.ONE
		(h as Node2D).global_position = p.global_position + o
		h._become_possessed()
		h.become_karen()


## Swings the camcorder every 0.75 s (for the swing screenshot).
class AutoSwing extends Node:
	var cam: Node
	var _t := 0.3

	func _process(delta: float) -> void:
		_t -= delta
		if _t <= 0.0 and cam != null and is_instance_valid(cam):
			_t = 0.75
			cam.swing()


# ------------------------------------------------------------------ build 015 boss

static func run_boss(lvl: Node, scenario: String) -> void:
	if not OS.is_debug_build():
		return
	var p := lvl.get_node_or_null("Entities/Player") as Node2D
	var boss = lvl.boss
	if p == null or boss == null:
		return
	print("[debug] boss scenario ", scenario)
	p.begin_grab_ghost(600.0)   # invulnerable for the shot
	if scenario == "boss_title":
		return
	# skip the intro card
	if lvl.hud != null and lvl.hud.title_card != null:
		lvl.hud.title_card.visible = false
		lvl.hud.title_card.position.x = 5000.0
	boss._set_state(TrustinJudeau.S.MOVE)
	boss._gap = 99.0
	boss._dash_in = 99.0
	boss.global_position = p.global_position + Vector2(-40, -250)
	p.global_position += Vector2(60, 0)
	var tree := lvl.get_tree()
	match scenario:
		"boss_attack":
			boss.hearts = 6
			lvl.hud.set_boss_hearts(6, boss.max_hearts)
			boss.force_attack("lob")
			await tree.create_timer(0.62).timeout
			boss.force_attack("spread")
			boss._gap = 99.0
		"boss_volley":
			boss.hearts = 2
			lvl.hud.set_boss_hearts(2, boss.max_hearts)
			boss.force_attack("radial")
		"boss_rage":   # 015b: radial burst (with its gap) + a double lob in rage
			boss.hearts = 2
			lvl.hud.set_boss_hearts(2, boss.max_hearts)
			boss.force_attack("radial")
			await tree.create_timer(0.5).timeout
			boss.force_attack("lob")
			boss._gap = 99.0
		"boss_hearts":
			boss.hearts = 4
			lvl.hud.set_boss_hearts(4, boss.max_hearts)
			lvl.weapons.select_id("whip")
			p.global_position = boss.global_position + Vector2(150, 110)
			boss.ai_enabled = false
			await tree.create_timer(0.3).timeout
			var target_screen: Vector2 = lvl.get_viewport().get_canvas_transform() * (boss.global_position + Vector2(0, -40))
			Input.warp_mouse(target_screen)
			p.get_viewport().warp_mouse(target_screen)
			await tree.create_timer(0.2).timeout
			p.get_node("Whip").fire_whip()
		"boss_pose":
			var pu: PowerUps = lvl.power_ups
			pu.grant("msm_cam")
			lvl.cam.battery = 14.0
			p.global_position = boss.global_position + Vector2(-60, 260)
			lvl.cam.debug_aim = p.global_position.direction_to(boss.global_position)
			lvl.cam.debug_force_film = true
			pu.changed.emit()
		"boss_win":
			boss.hearts = 1
			lvl.hud.set_boss_hearts(1, boss.max_hearts)
			boss.ai_enabled = false
			await tree.create_timer(0.3).timeout
			boss.take_hit(1, "whip", p.global_position)


# ------------------------------------------------------------------ build 016

## Bonus-stage scenarios (bonus_level.gd calls this when the scenario starts with "bonus").
static func run_bonus(lvl: Node, scenario: String) -> void:
	if not OS.is_debug_build():
		return
	print("[debug] bonus scenario ", scenario)
	var tree := lvl.get_tree()
	match scenario:
		"bonus_waves":
			# auto-play for screenshots: chase + whip the nearest flying sheep
			var p := lvl.get_node_or_null("Entities/Player") as Node2D
			var whip = p.get_node("Whip")
			for i in 1500:
				await tree.physics_frame
				if not is_instance_valid(lvl) or lvl._ended:
					return
				var best: Node2D = null
				var bd := INF
				for sh in tree.get_nodes_in_group("bonus_sheep"):
					if is_instance_valid(sh) and sh.is_flying():
						var d: float = p.global_position.distance_to(sh.global_position)
						if d < bd:
							bd = d
							best = sh
				if best != null and bd < 190.0 and whip.cooldown <= 0.0 and i % 40 == 0:
					p.facing = p.global_position.direction_to(best.global_position)
					var target_screen: Vector2 = lvl.get_viewport().get_canvas_transform() * best.global_position
					p.get_viewport().warp_mouse(target_screen)
					whip.fire_whip()
		"bonus_tally":
			# a perfect stage: pop every sheep as it launches
			await tree.create_timer(LevelConfig.BONUS_INTRO_TIME + 0.1).timeout
			lvl._clock = LevelConfig.BONUS_TIME - 0.5
			while lvl.waves_launched < LevelConfig.BONUS_WAVES:
				lvl._launch_wave(lvl.waves_launched)
				lvl.waves_launched += 1
			await tree.create_timer(0.2).timeout
			for i in 40:
				for s in tree.get_nodes_in_group("bonus_sheep"):
					if is_instance_valid(s):
						s.delay = 0.0
				await tree.physics_frame
				for s in tree.get_nodes_in_group("bonus_sheep"):
					if is_instance_valid(s) and s.is_flying():
						s.pop()
				if lvl.hits >= lvl.total_sheep:
					break


static func run_huval(lvl: Node, scenario: String) -> void:
	if not OS.is_debug_build():
		return
	var p := lvl.get_node_or_null("Entities/Player") as Node2D
	var boss = lvl.boss
	if p == null or boss == null:
		return
	print("[debug] huval scenario ", scenario)
	p.begin_grab_ghost(600.0)
	if scenario == "huval_title":
		return
	if lvl.hud != null and lvl.hud.title_card != null:
		lvl.hud.title_card.visible = false
		lvl.hud.title_card.position.x = 5000.0
	boss._set_state(HuvalYarheyhey.S.MOVE)
	boss._gap = 99.0
	boss.global_position = p.global_position + Vector2(-40, -260)
	p.global_position += Vector2(60, 0)
	var tree := lvl.get_tree()
	match scenario:
		"huval_fight":
			boss.hearts = 7
			lvl.hud.set_boss_hearts(7, boss.max_hearts)
			boss.ai_enabled = false
			for off in [Vector2(-260, -60), Vector2(230, -110), Vector2(-120, 90)]:
				var s = boss._spawn_robo(p.global_position + off)
				s.warp_in = 0.0
			var victim = boss._spawn_robo(p.global_position + Vector2(170, 40))
			victim.warp_in = 0.0
			await tree.create_timer(0.25).timeout
			victim.split(p.global_position, true)
			boss.force_attack("summon")
			lvl.chip = 1
			lvl.hud.set_heart_chip(1)
		"huval_ray":
			boss.hearts = 6
			lvl.hud.set_boss_hearts(6, boss.max_hearts)
			boss.force_attack("ray")
		"huval_update":
			boss.hearts = 4
			lvl.hud.set_boss_hearts(4, boss.max_hearts)
			for off in [Vector2(-260, -60), Vector2(230, -110)]:
				var s = boss._spawn_robo(p.global_position + off)
				s.warp_in = 0.0
			boss._start_forced_update()
		"huval_lecture":
			var pu: PowerUps = lvl.power_ups
			pu.grant("msm_cam")
			lvl.cam.battery = 14.0
			p.global_position = boss.global_position + Vector2(-60, 260)
			lvl.cam.debug_aim = p.global_position.direction_to(boss.global_position)
			lvl.cam.debug_force_film = true
			pu.changed.emit()
		"huval_win":
			boss.hearts = 1
			lvl.hud.set_boss_hearts(1, boss.max_hearts)
			boss.ai_enabled = false
			await tree.create_timer(0.3).timeout
			boss.take_hit(1, "whip", p.global_position)


## Build 018: BEORGE KUSH JR. screenshots ("kush_title", "kush_fight",
## "kush_strike", "kush_strafe", "kush_carpet", "kush_banner", "kush_salute",
## "kush_win"). Debug builds only.
static func run_kush(lvl: Node, scenario: String) -> void:
	if not OS.is_debug_build():
		return
	var p := lvl.get_node_or_null("Entities/Player") as Node2D
	var boss = lvl.boss
	if p == null or boss == null:
		return
	print("[debug] kush scenario ", scenario)
	p.begin_grab_ghost(600.0)
	if scenario == "kush_title":
		return
	if lvl.hud != null and lvl.hud.title_card != null:
		lvl.hud.title_card.visible = false
		lvl.hud.title_card.position.x = 5000.0
	boss._set_state(BeorgeKush.S.MOVE)
	boss._gap = 99.0
	boss.global_position = p.global_position + Vector2(-40, -260)
	p.global_position += Vector2(60, 0)
	var tree := lvl.get_tree()
	match scenario:
		"kush_fight":
			boss.hearts = 9
			lvl.hud.set_boss_hearts(9, boss.max_hearts)
			boss._set_state(BeorgeKush.S.MOVE)
			boss.ai_enabled = false
			boss._call_strike(p)
			await tree.create_timer(0.35).timeout
			boss.global_position = p.global_position + Vector2(-150, -150)
			boss._set_state(BeorgeKush.S.WINDUP)
			boss.attack = "strafe"
		"kush_strike":
			boss.hearts = 12
			lvl.hud.set_boss_hearts(12, boss.max_hearts)
			boss.force_attack("strike")
		"kush_strafe":
			boss.hearts = 8
			lvl.hud.set_boss_hearts(8, boss.max_hearts)
			boss.force_attack("strafe")
		"kush_carpet":
			boss.hearts = 4
			lvl.hud.set_boss_hearts(4, boss.max_hearts)
			boss.force_attack("carpet")
		"kush_banner":
			boss.hearts = 10
			lvl.hud.set_boss_hearts(10, boss.max_hearts)
			boss.take_hit(1, "whip", p.global_position)
		"kush_salute":
			var pu: PowerUps = lvl.power_ups
			pu.grant("msm_cam")
			lvl.cam.battery = 14.0
			p.global_position = boss.global_position + Vector2(-60, 260)
			lvl.cam.debug_aim = p.global_position.direction_to(boss.global_position)
			lvl.cam.debug_force_film = true
			pu.changed.emit()
			boss.force_attack("strike")
		"kush_win":
			boss.hearts = 1
			lvl.hud.set_boss_hearts(1, boss.max_hearts)
			boss.ai_enabled = false
			await tree.create_timer(0.3).timeout
			boss.take_hit(1, "whip", p.global_position)


## Build 018: SHLAUS KWOBB screenshots ("shlaus_title", "shlaus_fight",
## "shlaus_reset", "shlaus_envelopes", "shlaus_double", "shlaus_panel",
## "shlaus_press", "shlaus_win"). Debug builds only.
static func run_shlaus(lvl: Node, scenario: String) -> void:
	if not OS.is_debug_build():
		return
	var p := lvl.get_node_or_null("Entities/Player") as Node2D
	var boss = lvl.boss
	if p == null or boss == null:
		return
	print("[debug] shlaus scenario ", scenario)
	p.begin_grab_ghost(600.0)
	if scenario == "shlaus_title":
		return
	if lvl.hud != null and lvl.hud.title_card != null:
		lvl.hud.title_card.visible = false
		lvl.hud.title_card.position.x = 5000.0
	boss._set_state(ShlausKwobb.S.MOVE)
	boss._gap = 99.0
	boss.global_position = p.global_position + Vector2(-40, -260)
	p.global_position += Vector2(60, 0)
	var tree := lvl.get_tree()
	match scenario:
		"shlaus_fight":
			boss.hearts = 11
			lvl.hud.set_boss_hearts(11, boss.max_hearts)
			boss.ai_enabled = false
			var dt = boss._spawn_delegate(p, "trustin")
			dt.tell = 3.0   # screenshot: caught mid fade-in, aim line showing
			dt.global_position = p.global_position + Vector2(-250, -120)
			var dh = boss._spawn_delegate(p, "huval")
			dh.tell = 3.0
			dh.global_position = p.global_position + Vector2(260, -140)
			dh.spawn_points = boss.pick_spawn_points(dh.global_position, p.global_position, 2)
			for off in [Vector2(-240, 60), Vector2(220, -100)]:
				var s = boss.spawn_robo(p.global_position + off)
				s.warp_in = 0.0
			await tree.create_timer(0.2).timeout
			boss._set_state(ShlausKwobb.S.WINDUP)
			boss.attack = "envelopes"
		"shlaus_reset":
			boss.hearts = 9
			lvl.hud.set_boss_hearts(9, boss.max_hearts)
			boss.ai_enabled = false
			boss.global_position = p.global_position + Vector2(-20, -180)
			var ring = boss._spawn_reset(p)
			ring.tell = 3.0   # screenshot: the telegraph (rings + green gaps)
			boss._set_state(ShlausKwobb.S.WINDUP)
			boss.attack = "reset"
		"shlaus_envelopes":
			boss.hearts = 7
			lvl.hud.set_boss_hearts(7, boss.max_hearts)
			boss.force_attack("envelopes")
			boss.ai_enabled = false   # screenshot: hold the telegraphed fan
			await tree.create_timer(0.45).timeout
			boss._aim_locked = true
		"shlaus_double":
			boss.hearts = 7
			lvl.hud.set_boss_hearts(7, boss.max_hearts)
			boss.force_attack("double")
		"shlaus_panel":
			boss.hearts = 14
			lvl.hud.set_boss_hearts(14, boss.max_hearts)
			boss.take_hit(1, "whip", p.global_position)
		"shlaus_press":
			var pu: PowerUps = lvl.power_ups
			pu.grant("msm_cam")
			lvl.cam.battery = 14.0
			boss._spawn_delegate(p, "trustin")
			p.global_position = boss.global_position + Vector2(-60, 260)
			lvl.cam.debug_aim = p.global_position.direction_to(boss.global_position)
			lvl.cam.debug_force_film = true
			pu.changed.emit()
			boss.force_attack("poutine")
		"shlaus_win":
			boss.hearts = 1
			lvl.hud.set_boss_hearts(1, boss.max_hearts)
			boss.ai_enabled = false
			await tree.create_timer(0.3).timeout
			boss.take_hit(1, "whip", p.global_position)
