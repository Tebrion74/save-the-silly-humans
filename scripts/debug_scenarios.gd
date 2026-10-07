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
	pu.grant("msm_cam")
	match scenario:
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
