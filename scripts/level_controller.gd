extends Node2D

## Level flow + authoritative spawns. Rescue is locked until physics has synced
## new positions (turning Area2D monitoring on in the same frame as teleports
## still sees everyone overlapping at the old (0,0) transforms).

@onready var hud: CanvasLayer = $HUD

var state: GameState = GameState.new()
var _ended: bool = false
## Build 010: current level (from GameProgress autoload) and round target.
var level_number: int = 1
var target_rescued: int = LevelConfig.TARGET_LEVEL1
var _transitioning: bool = false
## Gate for SafeZone rescues — false until after physics frames post-place.
var rescues_unlocked: bool = false
var _hud_refresh_timer: float = 0.0

## Build 012 scoring (see README "Build 012"): points only while the round is live.
const POINTS_RESCUE := 200
const POINTS_SHEEP := 50
## A possessed human destroyed by the whip or a throw counts as a monster kill.
const POINTS_POSSESSED := 50
## Level-clear bonus: flat amount + per silly human still alive in the field
## when the target is reached (the win is immediate, so "saves above target"
## can never happen — the field survivors are the extra humans instead).
const CLEAR_BONUS_FLAT := 500
const CLEAR_BONUS_PER_SURVIVOR := 100

## Round clock (seconds since rescues unlocked; stops at round end).
var round_time: float = 0.0
## Points earned this level (excluding the clear bonus).
var level_points: int = 0
var clear_bonus: int = 0
var survivors_at_win: int = 0
## Build 013: Karens + power-ups.
const POINTS_KAREN := LevelConfig.POINTS_KAREN
var karens_enabled: bool = false
var power_ups: PowerUps
var pickups_layer: Node2D
var _cluster_timer: float = 0.0
var karens_formed: int = 0
var powerups_collected: int = 0
var drop_rng := RandomNumberGenerator.new()
## Tests can force drops: -1 = use the configured chance, 0/1 = never/always.
var drop_override: float = -1.0
## Build 014: MSM Cam + weapon slots (Player children, added in _ready).
var weapons: Weapons
var cam: MsmCam
var camcorder: Camcorder
var reticle: Reticle
var virals: int = 0
var infections: int = 0

## World-space layer for score popups (outside Entities so it keeps animating
## after the gameplay freeze).
var fx_layer: Node2D

const SLOT_SAFE := Vector2i(60, 38)
const SLOT_PLAYER := Vector2i(36, 24)
const SLOT_HUMANS: Array[Vector2i] = [
	Vector2i(8, 8),
	Vector2i(8, 40),
	Vector2i(40, 8),
	Vector2i(20, 20),
	Vector2i(12, 32),
]
const SLOT_SHEEP: Array[Vector2i] = [
	Vector2i(18, 14),
	Vector2i(45, 12),
	Vector2i(50, 30),
	Vector2i(59, 10),  # Sheep4 (build 010, NE trail)
	Vector2i(21, 42),  # Sheep5 (build 010, south trail)
]
## Build 010: silly human camp (southwest) — generates the rest of the round's humans.
const SLOT_CAMP := Vector2i(9, 40)
## Top-left sheep den — periodic spawns (see SheepSpawner).
const SLOT_SHEEP_SPAWNER := Vector2i(8, 10)
const MIN_HUMAN_SAFE_CHEBYSHEV := 12


func _ready() -> void:
	add_to_group("level_controller")
	rescues_unlocked = false
	level_number = _current_level()
	target_rescued = LevelConfig.target_for(level_number)
	var progress := _progress()
	if progress != null and progress.has_method("begin_level"):
		progress.begin_level()
	fx_layer = Node2D.new()
	fx_layer.name = "FX"
	fx_layer.z_index = 200
	add_child(fx_layer)
	karens_enabled = LevelConfig.karens_enabled(level_number)
	drop_rng.randomize()
	var entities_node := get_node_or_null("Entities")
	if entities_node != null:
		pickups_layer = Node2D.new()
		pickups_layer.name = "Pickups"
		entities_node.add_child(pickups_layer)
	var rancher := get_node_or_null("Entities/Player")
	if rancher != null:
		weapons = Weapons.new()
		rancher.add_child(weapons)
		cam = MsmCam.new()
		rancher.add_child(cam)
		camcorder = Camcorder.new()
		rancher.add_child(camcorder)
		power_ups = PowerUps.new()
		rancher.add_child(power_ups)
		cam.went_viral.connect(_on_cam_viral)
		cam.infected.connect(_on_cam_infected)
		# Build 014: inventory carried over from the previous level of the run.
		var prog := _progress()
		if prog != null and "inventory" in prog and LevelConfig.INVENTORY_CARRIES_OVER:
			power_ups.from_dict(prog.inventory)
		if hud and hud.has_method("bind_player"):
			hud.bind_player(rancher)
		# Build 014b: aim reticle (own CanvasLayer under the HUD and wedges).
		var rl := CanvasLayer.new()
		rl.name = "ReticleLayer"
		rl.layer = LevelConfig.RETICLE_LAYER
		add_child(rl)
		reticle = Reticle.new()
		reticle.player = rancher as Node2D
		reticle.level = self
		rl.add_child(reticle)

	_set_safe_zone_monitoring(false)
	_set_human_collisions_enabled(false)

	_ensure_ground_painted()
	_place_entities_from_tiles()

	var humans := get_tree().get_nodes_in_group("humans")
	if humans.is_empty():
		push_error("Level setup: no living humans after placement.")
	if humans.size() != LevelConfig.INITIAL_HUMANS:
		push_warning("Level setup: %d initial humans (config says %d)" % [humans.size(), LevelConfig.INITIAL_HUMANS])
	# Build 010 round: total 20 = initial humans now + camp arrivals later.
	state.begin_round(LevelConfig.ROUND_TOTAL_HUMANS, humans.size(), target_rescued, level_number)
	for human in humans:
		_connect_human(human)

	var camp := _camp()
	if camp != null and camp.has_signal("human_generated"):
		camp.human_generated.connect(_on_camp_human_generated)
	# Build 012: score sheep kills (placed sheep now, den sheep as they arrive).
	var flock := get_node_or_null("Entities/Sheep")
	if flock != null:
		for sheep in flock.get_children():
			_connect_sheep(sheep)
		flock.child_entered_tree.connect(_connect_sheep)

	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node = players[0]
		if "health" in player and "maximum_health" in player:
			state.register_player(player.health, player.maximum_health)
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)

	state.rescued_changed.connect(_on_rescued_changed)
	state.possessed_changed.connect(_on_possessed_changed)
	state.counts_changed.connect(_refresh_live_counts)
	state.player_health_changed.connect(_on_health_ui)
	state.won.connect(_on_won)
	state.lost.connect(_on_lost)

	if hud and hud.has_method("bind_state"):
		hud.bind_state(state)
	if hud and hud.has_method("set_level_info"):
		hud.set_level_info(level_number, target_rescued, state.total_humans)
	_push_score_hud()
	if hud and hud.has_method("set_time"):
		hud.set_time(0.0)

	state.mark_setup_complete()
	_refresh_hud()

	# Wait until physics transforms match placed positions, then unlock rescues.
	_unlock_rescues_after_physics.call_deferred()


func _process(delta: float) -> void:
	if rescues_unlocked and not _ended:
		round_time += delta
		if hud and hud.has_method("set_time"):
			hud.set_time(round_time)
		if karens_enabled:
			_cluster_timer -= delta
			if _cluster_timer <= 0.0:
				_cluster_timer = 0.25
				update_karen_clusters()
	# Build 014: filming makes the sheep den breed faster.
	var den := get_node_or_null("Entities/SheepSpawner")
	if den != null and "rate_mult" in den:
		den.rate_mult = LevelConfig.CAM_SHEEP_RATE_MULT if cam != null and cam.filming and not _ended else 1.0
	_hud_refresh_timer -= delta
	if _hud_refresh_timer <= 0.0:
		_hud_refresh_timer = 0.25
		_refresh_live_counts()
	if _ended:
		if TouchInput.consume_restart():
			request_retry()
		elif TouchInput.consume_next_level():
			if state.is_won:
				request_next_level()
	_check_lost_track()


func _unlock_rescues_after_physics() -> void:
	# Two physics frames: teleports flush, then Area2D overlap rebuilds clean.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_set_human_collisions_enabled(true)
	await get_tree().physics_frame
	rescues_unlocked = true
	_set_safe_zone_monitoring(true)
	_start_sheep_spawner()
	_start_camp()
	_refresh_hud()
	print("[spawn] rescues unlocked; living humans=", get_tree().get_nodes_in_group("humans").size())
	var prog := _progress()
	if OS.is_debug_build() and prog != null and "debug_scenario" in prog and prog.debug_scenario != "":
		DebugScenarios.run(self, String(prog.debug_scenario))


func can_rescue_humans() -> bool:
	return rescues_unlocked and state.setup_complete and not state.is_won and not state.is_lost


func _set_human_collisions_enabled(enabled: bool) -> void:
	for human in get_tree().get_nodes_in_group("humans"):
		if human is CollisionObject2D:
			(human as CollisionObject2D).set_deferred("collision_layer", 4 if enabled else 0)
		var shape := human.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape:
			shape.set_deferred("disabled", not enabled)


func _set_safe_zone_monitoring(enabled: bool) -> void:
	var safe := get_node_or_null("Entities/SafeZone")
	if safe == null:
		return
	if safe.has_method("set_rescue_enabled"):
		safe.set_rescue_enabled(enabled)
	elif "monitoring" in safe:
		safe.monitoring = enabled


func _ensure_ground_painted() -> void:
	var ground := get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		return
	if ground.get_used_cells().size() > 0:
		return
	if ground.has_method("paint_level01"):
		ground.paint_level01()


func _place_entities_from_tiles() -> void:
	var ground := get_node_or_null("Ground") as TileMapLayer
	if ground == null or not ground.has_method("tile_center"):
		push_warning("Level01: Ground spawn API missing; using baked scene positions.")
		return

	var margin := 4
	_assert_interior(ground, SLOT_SAFE, margin, "SafeZone")
	_assert_interior(ground, SLOT_PLAYER, margin, "Player")
	for i in SLOT_HUMANS.size():
		_assert_interior(ground, SLOT_HUMANS[i], margin, "Human%d" % (i + 1))
		_assert_human_safe_distance(SLOT_HUMANS[i], "Human%d" % (i + 1))
	for i in SLOT_SHEEP.size():
		_assert_interior(ground, SLOT_SHEEP[i], margin, "Sheep%d" % (i + 1))
	_assert_interior(ground, SLOT_SHEEP_SPAWNER, margin, "SheepSpawner")
	_assert_interior(ground, SLOT_CAMP, margin, "HumanCamp")

	var camp := get_node_or_null("Entities/HumanCamp") as Node2D
	if camp:
		camp.global_position = ground.to_global(ground.tile_center(SLOT_CAMP))
		print("[spawn] HumanCamp local=%s world=%s" % [SLOT_CAMP, camp.global_position])

	var safe := get_node_or_null("Entities/SafeZone") as Node2D
	if safe:
		safe.global_position = ground.to_global(ground.tile_center(SLOT_SAFE))
		print("[spawn] SafeZone local=%s world=%s" % [SLOT_SAFE, safe.global_position])

	var player := get_node_or_null("Entities/Player") as Node2D
	if player:
		player.global_position = ground.to_global(ground.tile_center(SLOT_PLAYER))
		print("[spawn] Player local=%s world=%s" % [SLOT_PLAYER, player.global_position])

	for i in SLOT_HUMANS.size():
		var node := get_node_or_null("Entities/Humans/Human%d" % (i + 1)) as Node2D
		if node:
			node.global_position = ground.to_global(ground.tile_center(SLOT_HUMANS[i]))
			var d := _chebyshev(SLOT_HUMANS[i], SLOT_SAFE)
			print(
				"[spawn] Human%d local=%s world=%s chebyshev_from_safe=%d"
				% [i + 1, SLOT_HUMANS[i], node.global_position, d]
			)

	for i in SLOT_SHEEP.size():
		var node := get_node_or_null("Entities/Sheep/Sheep%d" % (i + 1)) as Node2D
		if node:
			node.global_position = ground.to_global(ground.tile_center(SLOT_SHEEP[i]))
			print("[spawn] Sheep%d local=%s world=%s" % [i + 1, SLOT_SHEEP[i], node.global_position])



func _start_sheep_spawner() -> void:
	var spawner := get_node_or_null("Entities/SheepSpawner")
	if spawner and spawner.has_method("start_spawning"):
		spawner.start_spawning()
	else:
		push_warning("Level01: Entities/SheepSpawner missing or has no start_spawning()")


func _camp() -> Node:
	return get_node_or_null("Entities/HumanCamp")


func _start_camp() -> void:
	var camp := _camp()
	if camp and camp.has_method("start_generating"):
		camp.start_generating(state.humans_left_to_arrive())
	else:
		push_warning("Level01: Entities/HumanCamp missing or has no start_generating()")


func _current_level() -> int:
	var progress := get_node_or_null("/root/GameProgress")
	if progress != null and "current_level" in progress:
		return maxi(int(progress.current_level), 1)
	return 1


func _connect_human(human: Node) -> void:
	# Bound callables (position for the score popup) — guard with a meta flag.
	if human.has_meta("_stsh_level_connected"):
		return
	human.set_meta("_stsh_level_connected", true)
	if human.has_signal("was_rescued"):
		human.was_rescued.connect(_on_human_rescued.bind(human))
	if human.has_signal("was_killed"):
		human.was_killed.connect(_on_human_killed)
	if human.has_signal("was_possessed"):
		human.was_possessed.connect(_on_human_possessed)
	if human.has_signal("was_possession_saved"):
		human.was_possession_saved.connect(_on_human_possession_saved.bind(human))
	if human.has_signal("was_destroyed"):
		human.was_destroyed.connect(_on_human_destroyed.bind(human))
	if human.has_signal("became_karen"):
		human.became_karen.connect(_on_became_karen.bind(human))


func _connect_sheep(sheep: Node) -> void:
	if sheep == null or not sheep.has_signal("killed") or sheep.has_meta("_stsh_level_connected"):
		return
	sheep.set_meta("_stsh_level_connected", true)
	sheep.killed.connect(_on_sheep_killed.bind(sheep))


func _on_camp_human_generated(human: Node) -> void:
	if _ended:
		return
	_connect_human(human)
	if not state.note_human_spawned():
		push_warning("Camp generated a human past the round total")
	_refresh_live_counts()


## Safety net: if every human has been generated, none is left in the field and
## the counters still disagree (a human vanished without a signal), count the
## missing ones as lost so the round can never soft-lock.
var _lost_track_timer: float = 0.0


func _check_lost_track() -> void:
	if _ended or not rescues_unlocked or not state.all_spawned():
		return
	if state.resolved_humans() >= state.total_humans:
		return
	if not get_tree().get_nodes_in_group("humans").is_empty():
		_lost_track_timer = 0.0
		return
	_lost_track_timer += get_process_delta_time()
	if _lost_track_timer < 1.0:
		return
	var missing := state.total_humans - state.resolved_humans()
	push_warning("Round accounting: %d humans unaccounted for; counting as lost" % missing)
	for i in missing:
		state.add_human_death()


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _assert_human_safe_distance(local: Vector2i, label: String) -> void:
	var d := _chebyshev(local, SLOT_SAFE)
	if d < MIN_HUMAN_SAFE_CHEBYSHEV:
		push_error(
			"Spawn slot %s at local %s is only Chebyshev %d from SafeZone %s (need ≥%d)"
			% [label, local, d, SLOT_SAFE, MIN_HUMAN_SAFE_CHEBYSHEV]
		)


func _assert_interior(ground: TileMapLayer, local: Vector2i, margin: int, label: String) -> void:
	if not ground.is_interior_local(local, margin):
		push_error(
			"Spawn slot %s at local %s fails interior margin=%d (map %dx%d)"
			% [label, local, margin, ground.map_width, ground.map_height]
		)


func _unhandled_input(event: InputEvent) -> void:
	if not _ended:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		var kc: int = event.keycode
		if k == KEY_R or kc == KEY_R:
			request_retry()
		elif state.is_won and (k == KEY_N or kc == KEY_N or k == KEY_ENTER or kc == KEY_ENTER or k == KEY_KP_ENTER or kc == KEY_KP_ENTER):
			request_next_level()
		elif not state.is_won and (k == KEY_ENTER or kc == KEY_ENTER or k == KEY_KP_ENTER or kc == KEY_KP_ENTER):
			request_retry()


## Retry the same level (PLAY AGAIN button, R, touch tap).
## Build 012: the score goes back to what it was when this level started.
func request_retry() -> void:
	if _transitioning:
		return
	_transitioning = true
	var progress := _progress()
	if progress != null and progress.has_method("restore_level_start_score"):
		progress.restore_level_start_score()
	get_tree().reload_current_scene()


## Advance to the next level (NEXT LEVEL button, Enter/N, touch tap). Only
## after a won round.
func request_next_level() -> void:
	if _transitioning or not state.is_won:
		return
	_transitioning = true
	var progress := get_node_or_null("/root/GameProgress")
	# Build 015: clearing level BOSS_AFTER_LEVEL leads into the boss fight.
	if GameProgressCheck.boss_follows(level_number) and progress != null and progress.has_method("enter_boss"):
		progress.enter_boss(level_number + 1)
		get_tree().change_scene_to_file(LevelConfig.BOSS_SCENE)
		return
	if progress != null and progress.has_method("advance_level"):
		progress.advance_level()
	get_tree().reload_current_scene()


func _on_human_rescued(human: Node = null) -> void:
	if _scoring_open():
		_award(POINTS_RESCUE, _pos_of(human), Color(0.55, 1.0, 0.45))
	state.add_rescue()


func _on_human_killed() -> void:
	state.add_human_death()


func _on_human_possessed() -> void:
	state.add_possession()


func _on_human_possession_saved(human: Node = null) -> void:
	if _scoring_open():
		_award(POINTS_RESCUE, _pos_of(human), Color(0.55, 1.0, 0.45))
	state.add_possession_save()


func _on_human_destroyed(was_possessed_then: bool, human: Node = null) -> void:
	if not was_possessed_then or not _scoring_open():
		return
	var pos := _pos_of(human)
	var was_karen: bool = human != null and is_instance_valid(human) and "karen" in human and human.karen
	if was_karen:
		_award(POINTS_KAREN, pos, Color(1.0, 0.45, 0.8))
		state.add_karen_destroyed()
		_maybe_drop(LevelConfig.DROP_CHANCE_KAREN, pos, "karen")
	else:
		_award(POINTS_POSSESSED, pos, Color(1.0, 0.6, 1.0))
		state.add_possessed_destroyed()
		_maybe_drop(LevelConfig.DROP_CHANCE_POSSESSED, pos)


func _on_sheep_killed(sheep: Node = null) -> void:
	if not _scoring_open():
		return
	var pos := _pos_of(sheep)
	_award(POINTS_SHEEP, pos, Color(1.0, 0.86, 0.25))
	state.add_sheep_kill()
	_maybe_drop(LevelConfig.DROP_CHANCE_SHEEP, pos)


# ------------------------------------------------------------------ Karens (013)

## Level 3+: any possessed human with (KAREN_CLUSTER_SIZE - 1) other possessed
## humans / Karens within KAREN_CLUSTER_RADIUS turns gregarious together with
## those neighbours. Returns how many new Karens formed.
func update_karen_clusters() -> int:
	if not karens_enabled or _ended:
		return 0
	var pool: Array = []
	for h in get_tree().get_nodes_in_group("possessed"):
		if is_instance_valid(h) and not h.is_queued_for_deletion() and "possessed" in h and h.possessed \
				and not ("exploding" in h and h.exploding):
			pool.append(h)
	if pool.size() < LevelConfig.KAREN_CLUSTER_SIZE:
		return 0
	var formed := 0
	var r := LevelConfig.KAREN_CLUSTER_RADIUS
	for seed_h in pool:
		var group: Array = [seed_h]
		for other in pool:
			if other != seed_h and (other as Node2D).global_position.distance_to((seed_h as Node2D).global_position) <= r:
				group.append(other)
		if group.size() < LevelConfig.KAREN_CLUSTER_SIZE:
			continue
		for g in group:
			if g.has_method("become_karen") and g.become_karen():
				formed += 1
	return formed


func living_karens() -> int:
	var n := 0
	for k in get_tree().get_nodes_in_group("karens"):
		if is_instance_valid(k) and not k.is_queued_for_deletion() and not ("exploding" in k and k.exploding):
			n += 1
	return n


var _karen_popup_ms: int = -100000

func _on_became_karen(human: Node = null) -> void:
	karens_formed += 1
	# One popup per mob (all members turn on the same frame), not one per Karen.
	var now := Time.get_ticks_msec()
	if human != null and is_instance_valid(human) and now - _karen_popup_ms > 600:
		_karen_popup_ms = now
		spawn_score_popup("KAREN!", (human as Node2D).global_position, Color(1.0, 0.45, 0.8), 2)
	_refresh_live_counts()


# ------------------------------------------------------------------ power-ups (013)

func _maybe_drop(chance: float, pos: Vector2, source: String = "") -> void:
	var c := chance if drop_override < 0.0 else drop_override
	if c <= 0.0 or drop_rng.randf() >= c:
		return
	spawn_pickup(roll_powerup_type(source), pos)


## Build 014: drop weights for this roll. The MSM Cam is rarer once owned and
## more common from Karens; batteries are much more common once you own it.
func drop_weights(source: String = "") -> Dictionary:
	var w := LevelConfig.POWERUP_WEIGHTS.duplicate()
	var owned: bool = weapons != null and weapons.has_weapon("cam")
	var cam_w := float(w.get("msm_cam", 0))
	if source == "karen":
		cam_w *= LevelConfig.CAM_KAREN_DROP_MULT
	if owned:
		cam_w *= LevelConfig.CAM_OWNED_WEIGHT_MULT
		w["battery"] = LevelConfig.BATTERY_WEIGHT_OWNED
	w["msm_cam"] = int(round(cam_w))
	return w


func roll_powerup_type(source: String = "") -> String:
	var weights := drop_weights(source)
	var total := 0
	for k in weights:
		total += int(weights[k])
	var roll := drop_rng.randi_range(1, total)
	for k in weights:
		roll -= int(weights[k])
		if roll <= 0:
			return k
	return "health"


func spawn_pickup(kind: String, pos: Vector2) -> Node2D:
	if pickups_layer == null:
		return null
	var p := PowerUp.new()
	p.kind = kind
	p.collected.connect(_on_pickup_collected)
	pickups_layer.add_child(p)
	p.global_position = pos
	return p


func _on_pickup_collected(kind: String, pickup: Node2D) -> void:
	if _ended or power_ups == null:
		return
	powerups_collected += 1
	var note: String = power_ups.grant(kind)
	var col: Color = PowerUp.PLATE.get(kind, Color.WHITE).lightened(0.35)
	if kind == "msm_cam" or kind == "battery":
		col = Color(1.0, 0.45, 0.4) if kind == "msm_cam" else Color(0.6, 1.0, 0.5)
	var text := PowerUp.display_name(kind) + "!"
	if note != "":
		text += " " + note
	spawn_score_popup(text, pickup.global_position, col, 2)


# ------------------------------------------------------------------ MSM Cam (014)

func _on_cam_viral(humans: int) -> void:
	virals += 1
	if hud and hud.has_method("show_callout"):
		hud.show_callout("VIRAL!", "KARENS EXPOSED! %d HUMANS RUN FOR SAFETY" % humans if humans != 1 else "KARENS EXPOSED! 1 HUMAN RUNS FOR SAFETY")
	var p := get_node_or_null("Entities/Player") as Node2D
	if p != null:
		spawn_score_popup("KARENS EXPOSED!", p.global_position + Vector2(0, -30), Color(1.0, 0.45, 0.8), 2)


func _on_cam_infected(_human: Node) -> void:
	infections += 1


# ------------------------------------------------------------------ scoring (012)

func _progress() -> Node:
	return get_node_or_null("/root/GameProgress")


func _scoring_open() -> bool:
	return state.setup_complete and not state.is_over() and not _ended


func _pos_of(node: Node) -> Vector2:
	if node != null and is_instance_valid(node) and node is Node2D:
		return (node as Node2D).global_position
	var player := get_node_or_null("Entities/Player") as Node2D
	return player.global_position if player else Vector2.ZERO


func current_score() -> int:
	var progress := _progress()
	return int(progress.score) if progress != null and "score" in progress else level_points


func _award(points: int, world_pos: Vector2, color: Color) -> void:
	level_points += points
	var progress := _progress()
	if progress != null and progress.has_method("add_score"):
		progress.add_score(points)
	spawn_score_popup("+%d" % points, world_pos, color)
	_push_score_hud()


func _push_score_hud() -> void:
	if hud == null:
		return
	var progress := _progress()
	if hud.has_method("set_score"):
		hud.set_score(current_score())
	if hud.has_method("set_high_score") and progress != null and "high_score" in progress:
		hud.set_high_score(maxi(int(progress.high_score), current_score()))


## Floating "+200" / "+50" at a world position (pixel font, rises and fades).
func spawn_score_popup(text: String, world_pos: Vector2, color: Color, scale_px: int = 3) -> Label:
	if fx_layer == null:
		return null
	var l := Label.new()
	l.text = text
	l.label_settings = PixelFont.settings(scale_px, color)
	l.add_to_group("score_popup")
	fx_layer.add_child(l)
	var w := PixelFont.text_width(text, scale_px)
	l.position = world_pos + Vector2(-w * 0.5, -60.0)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 48.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tw.chain().tween_callback(l.queue_free)
	return l


## Breakdown for the end screen (also used by tests).
func score_breakdown() -> Dictionary:
	var progress := _progress()
	return {
		"level": level_number,
		"won": state.is_won,
		"rescued": state.rescued_humans,
		"target": state.target_rescued,
		"total": state.total_humans,
		"humans_points": state.rescued_humans * POINTS_RESCUE,
		"sheep": state.sheep_killed,
		"sheep_points": state.sheep_killed * POINTS_SHEEP,
		"possessed": state.possessed_destroyed - state.karens_destroyed,
		"possessed_points": (state.possessed_destroyed - state.karens_destroyed) * POINTS_POSSESSED,
		"karens": state.karens_destroyed,
		"karens_points": state.karens_destroyed * POINTS_KAREN,
		"karens_enabled": karens_enabled,
		"survivors": survivors_at_win,
		"bonus": clear_bonus,
		"level_total": level_points + clear_bonus,
		"score": current_score(),
		"high_score": int(progress.high_score) if progress != null and "high_score" in progress else current_score(),
		"new_high": bool(progress.new_high_score) if progress != null and "new_high_score" in progress else false,
		"time": round_time,
		"next_is_boss": GameProgressCheck.boss_follows(level_number),
	}


func _on_player_health_changed(health: int, maximum: int) -> void:
	state.player_max_health = maximum
	state.player_health = health
	state.player_health_changed.emit(health, maximum)


func _on_player_died() -> void:
	state.trigger_lose(
		"The rancher is down!  Saved %d/%d — needed %d"
		% [state.rescued_humans, state.total_humans, state.target_rescued],
		"rancher"
	)


func _on_rescued_changed(rescued: int, _total: int) -> void:
	if hud and hud.has_method("set_rescued"):
		hud.set_rescued(rescued, state.target_rescued)


func _on_possessed_changed(possessed: int) -> void:
	if hud and hud.has_method("set_converted"):
		hud.set_converted(possessed)


func _on_health_ui(health: int, maximum: int) -> void:
	if hud and hud.has_method("set_health"):
		hud.set_health(health, maximum)


func _count_living_sheep() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("sheep"):
		if not is_instance_valid(node):
			continue
		if "exploding" in node and node.exploding:
			continue
		n += 1
	return n


func _count_living_humans() -> int:
	return get_tree().get_nodes_in_group("humans").size()


func _refresh_live_counts() -> void:
	if hud == null:
		return
	if hud.has_method("set_living_humans"):
		hud.set_living_humans(_count_living_humans())
	if hud.has_method("set_living_sheep"):
		hud.set_living_sheep(_count_living_sheep())
	if hud.has_method("set_converted"):
		hud.set_converted(state.possessed_humans)
	if hud.has_method("set_arrivals"):
		hud.set_arrivals(state.humans_left_to_arrive())
	if hud.has_method("set_karens"):
		var camp := _camp()
		var held: bool = camp != null and camp.has_method("held_by_karens") and camp.is_generating() and camp.held_by_karens()
		hud.set_karens(living_karens(), held)


func _on_won() -> void:
	_ended = true
	# Build 014: the inventory goes on to the next level.
	var prog := _progress()
	if prog != null and prog.has_method("carry_inventory") and power_ups != null:
		prog.carry_inventory(power_ups.to_dict())
	# Clear bonus: flat + every silly human still alive in the field.
	survivors_at_win = state.living_silly()
	clear_bonus = CLEAR_BONUS_FLAT + CLEAR_BONUS_PER_SURVIVOR * survivors_at_win
	level_points_bonus_award()
	_finish_round()
	if hud and hud.has_method("show_end"):
		hud.show_end(
			true,
			"Level %d complete!  Saved %d/%d" % [level_number, state.rescued_humans, state.target_rescued],
			score_breakdown()
		)


func level_points_bonus_award() -> void:
	var progress := _progress()
	if progress != null and progress.has_method("add_score"):
		progress.add_score(clear_bonus)
	_push_score_hud()


func _on_lost(reason: String) -> void:
	_ended = true
	_finish_round()
	if hud and hud.has_method("show_end"):
		hud.show_end(false, reason, score_breakdown())


## Build 012: round over (win or lose) — stop the camp and the sheep den,
## freeze everything under Entities (player, humans, sheep, safe zone),
## store the high score. HUD, touch controls and score popups keep running.
func _finish_round() -> void:
	_stop_spawners()
	var progress := _progress()
	if progress != null and progress.has_method("commit_high_score"):
		progress.commit_high_score()
	_push_score_hud()
	_refresh_live_counts()
	var entities := get_node_or_null("Entities")
	if entities:
		entities.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)


func is_gameplay_frozen() -> bool:
	var entities := get_node_or_null("Entities")
	return entities != null and entities.process_mode == Node.PROCESS_MODE_DISABLED


func _stop_spawners() -> void:
	var camp := _camp()
	if camp and camp.has_method("stop_generating"):
		camp.stop_generating()
	var den := get_node_or_null("Entities/SheepSpawner")
	if den and den.has_method("stop_spawning"):
		den.stop_spawning()


func _refresh_hud() -> void:
	_on_rescued_changed(state.rescued_humans, state.total_humans)
	_on_health_ui(state.player_health, state.player_max_health)
	_refresh_live_counts()
