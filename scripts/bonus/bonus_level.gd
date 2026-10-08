extends "res://scripts/level_controller.gd"
## Build 016: the BONUS STAGE (scenes/levels/BonusStage.tscn), a sheep-ified
## Galaga "challenging stage".
##
## When: after level 1 and then every 3 levels (1, 4, 7, 10, ...), before
## any boss that shares the slot (see LevelConfig "build 016 progression").
## What: a 45 s countdown (LevelConfig.BONUS_TIME) with 8 scripted waves of
## 5-8 flying sheep (BonusWaves) that swoop, loop, zig-zag and cross the field
## and fly off again. Any hit pops one (+100). Pop a whole wave: PERFECT! +500.
## Pop every sheep of the stage: PERFECT! SPECIAL BONUS 10000. The rancher
## can't be hurt and can't die here. Later bonus stages: +1 sheep per wave
## (cap 8) and 12% faster each time (cap x1.7).
## Power-ups: your loadout comes along and works, but nothing is used up (the
## inventory you arrive with is what you leave with) and nothing drops.
## Ends when the clock runs out or the last wave has left; the tally screen's
## CONTINUE goes on to the next queued stage or level.

const BONUS_FIELD_MIN := Vector2i(1, 1)

var stage_index: int = 1
var field_rect := Rect2()
var plan: Array = []
var total_sheep: int = 0
var hits: int = 0
var escaped_count: int = 0
var wave_perfects: int = 0
var wave_spawned: Array = []      ## sheep launched per wave
var wave_hits: Array = []
var wave_done: Array = []         ## popped + escaped per wave
var waves_launched: int = 0
var time_left: float = LevelConfig.BONUS_TIME
var perfect := false
var special_bonus := 0
var _countdown := false
var _clock := 0.0
var _ending := false


func _ready() -> void:
	add_to_group("level_controller")
	add_to_group("bonus_level")
	rescues_unlocked = false
	level_number = _current_level()
	target_rescued = 0
	var progress := _progress()
	if progress != null and "bonus_index" in progress:
		stage_index = maxi(int(progress.bonus_index), 1)
	if progress != null and progress.has_method("begin_level"):
		progress.begin_level()
	fx_layer = Node2D.new()
	fx_layer.name = "FX"
	fx_layer.z_index = 200
	add_child(fx_layer)
	karens_enabled = false
	drop_override = 0.0
	var entities_node := get_node_or_null("Entities")
	pickups_layer = Node2D.new()
	pickups_layer.name = "Pickups"
	entities_node.add_child(pickups_layer)
	var rancher := get_node_or_null("Entities/Player")
	weapons = Weapons.new()
	rancher.add_child(weapons)
	cam = MsmCam.new()
	rancher.add_child(cam)
	camcorder = Camcorder.new()
	rancher.add_child(camcorder)
	power_ups = PowerUps.new()
	rancher.add_child(power_ups)
	if progress != null and "inventory" in progress and LevelConfig.INVENTORY_CARRIES_OVER:
		power_ups.from_dict(progress.inventory)
	if hud and hud.has_method("bind_player"):
		hud.bind_player(rancher)
	var rl := CanvasLayer.new()
	rl.name = "ReticleLayer"
	rl.layer = LevelConfig.RETICLE_LAYER
	add_child(rl)
	reticle = Reticle.new()
	reticle.player = rancher as Node2D
	reticle.level = self
	rl.add_child(reticle)

	var ground := get_node("Ground") as TileMapLayer
	var tl: Vector2 = ground.to_global(ground.map_to_local(ground.get_map_origin()) - Vector2(16, 16))
	var map_size := Vector2(ground.map_width, ground.map_height) * 32.0
	field_rect = Rect2(tl, map_size)
	(rancher as Node2D).global_position = ground.to_global(ground.tile_center(Vector2i(ground.map_width / 2, ground.map_height - 5)))
	rancher.facing = Vector2.UP

	plan = BonusWaves.plan(stage_index)
	total_sheep = LevelConfig.bonus_total(stage_index)
	for i in LevelConfig.BONUS_WAVES:
		wave_spawned.append(0)
		wave_hits.append(0)
		wave_done.append(0)

	state.begin_round(0, 0, 0, level_number)
	if "health" in rancher and "maximum_health" in rancher:
		state.register_player(rancher.health, rancher.maximum_health)
	state.player_health_changed.connect(_on_health_ui)
	state.won.connect(_on_won)
	if hud and hud.has_method("set_bonus_mode"):
		hud.set_bonus_mode(stage_index, total_sheep)
	_push_score_hud()
	if hud and hud.has_method("set_time"):
		hud.set_time(0.0)
	state.mark_setup_complete()
	_on_health_ui(state.player_health, state.player_max_health)
	Sfx.music(self, "bonus")
	_unlock_rescues_after_physics.call_deferred()


func _unlock_rescues_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	rescues_unlocked = true
	if hud and hud.has_method("show_bonus_title_card"):
		hud.show_bonus_title_card(stage_index)
	print("[bonus] stage ", stage_index, " ready; sheep=", total_sheep)
	var prog := _progress()
	if OS.is_debug_build() and prog != null and "debug_scenario" in prog and String(prog.debug_scenario).begins_with("bonus"):
		DebugScenarios.run_bonus(self, String(prog.debug_scenario))
	await get_tree().create_timer(LevelConfig.BONUS_INTRO_TIME).timeout
	if is_inside_tree() and not _ended:
		_countdown = true


func _start_sheep_spawner() -> void:
	pass


func _start_camp() -> void:
	pass


func _process(delta: float) -> void:
	super(delta)
	if not _countdown or _ended:
		return
	_clock += delta
	time_left = maxf(LevelConfig.BONUS_TIME - _clock, 0.0)
	# launch waves on schedule
	while waves_launched < LevelConfig.BONUS_WAVES and _clock >= LevelConfig.BONUS_FIRST_WAVE + waves_launched * LevelConfig.BONUS_WAVE_EVERY:
		_launch_wave(waves_launched)
		waves_launched += 1
	if hud and hud.has_method("set_bonus_status"):
		hud.set_bonus_status(time_left, hits, total_sheep)
	if not _ending and (time_left <= 0.0 or (waves_launched >= LevelConfig.BONUS_WAVES and _live_bonus_sheep() == 0)):
		_ending = true
		_end_stage()


func _live_bonus_sheep() -> int:
	var n := 0
	for s in get_tree().get_nodes_in_group("bonus_sheep"):
		if is_instance_valid(s) and not s.exploding:
			n += 1
	return n


func _launch_wave(i: int) -> void:
	var w: Dictionary = plan[i]
	var n := LevelConfig.bonus_wave_size(i, stage_index)
	var spd := LevelConfig.BONUS_SHEEP_SPEED * LevelConfig.bonus_speed(i, stage_index)
	var pa := BonusWaves.sample(String(w["pattern"]), field_rect, bool(w["mirror"]))
	var pb := BonusWaves.sample(String(w["pattern"]), field_rect, not bool(w["mirror"]))
	var ents := get_node("Entities")
	for k in n:
		var s := BonusSheep.new()
		s.level = self
		s.wave = i
		s.speed = spd
		var pair := bool(w["pair"])
		s.path = pb if pair and k % 2 == 1 else pa
		s.delay = LevelConfig.BONUS_SPACING * (k / 2 if pair else k)
		s.popped.connect(_on_bonus_popped)
		s.escaped.connect(_on_bonus_escaped)
		ents.add_child(s)
	wave_spawned[i] = n


func _on_bonus_popped(s: Node) -> void:
	if _ended:
		return
	var i: int = s.wave
	hits += 1
	wave_hits[i] += 1
	wave_done[i] += 1
	_award(LevelConfig.BONUS_POINTS_PER_HIT, (s as Node2D).global_position, Color(1.0, 0.95, 0.5))
	if wave_done[i] >= wave_spawned[i] and wave_hits[i] == wave_spawned[i]:
		wave_perfects += 1
		level_points += LevelConfig.BONUS_WAVE_PERFECT
		var progress := _progress()
		if progress != null and progress.has_method("add_score"):
			progress.add_score(LevelConfig.BONUS_WAVE_PERFECT)
		_push_score_hud()
		spawn_score_popup("PERFECT! +%d" % LevelConfig.BONUS_WAVE_PERFECT, (s as Node2D).global_position + Vector2(0, -24), Color(1.0, 0.45, 0.8), 4)
		Sfx.play(self, "perfect", -8.0)


func _on_bonus_escaped(s: Node) -> void:
	escaped_count += 1
	wave_done[s.wave] += 1


func _end_stage() -> void:
	# let the last pops / popups play for a moment
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree() or _ended:
		return
	state.trigger_win()


func _on_won() -> void:
	_ended = true
	_countdown = false
	# NOTE: no carry_inventory(): charges / battery used here are given back.
	perfect = hits >= total_sheep and total_sheep > 0
	special_bonus = LevelConfig.BONUS_PERFECT_BONUS if perfect else 0
	clear_bonus = special_bonus
	level_points_bonus_award()
	# the remaining sheep fly off (frozen with the rest of Entities)
	_finish_round()
	Sfx.play(self, "win" if not perfect else "fanfare", -6.0)
	if hud and hud.has_method("show_bonus_tally"):
		hud.show_bonus_tally(score_breakdown())


func _on_player_died() -> void:
	pass   # can't happen: nothing here hurts the rancher


func score_breakdown() -> Dictionary:
	var progress := _progress()
	var nxt := ""
	if progress != null and "stage_queue" in progress and not progress.stage_queue.is_empty():
		nxt = String(progress.stage_queue[0])
	return {
		"bonus": true,
		"stage": stage_index,
		"level": level_number,
		"won": true,
		"hits": hits,
		"total": total_sheep,
		"escaped": escaped_count,
		"hit_points": hits * LevelConfig.BONUS_POINTS_PER_HIT,
		"wave_perfects": wave_perfects,
		"wave_points": wave_perfects * LevelConfig.BONUS_WAVE_PERFECT,
		"perfect": perfect,
		"special_bonus": special_bonus,
		"bonus_points": special_bonus,
		"level_total": level_points + clear_bonus,
		"score": current_score(),
		"high_score": int(progress.high_score) if progress != null and "high_score" in progress else current_score(),
		"new_high": bool(progress.new_high_score) if progress != null and "new_high_score" in progress else false,
		"time": _clock,
		"next_stage": nxt,
	}


## No retry on a bonus stage: R / PLAY AGAIN do nothing; Enter / N / tap = CONTINUE.
func request_retry() -> void:
	if _ended and state.is_won:
		request_next_level()


func request_next_level() -> void:
	if _transitioning or not state.is_won:
		return
	_transitioning = true
	Sfx.play(self, "start", -8.0)
	var progress := _progress()
	var next := LevelConfig.GAME_SCENE
	if progress != null and progress.has_method("finish_stage"):
		next = progress.finish_stage()
	get_tree().change_scene_to_file(next)
