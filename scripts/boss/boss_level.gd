extends "res://scripts/level_controller.gd"
## Build 015: the TRUSTIN JUDEAU boss level (scenes/levels/BossArena.tscn).
##
## Where it sits: BETWEEN level LevelConfig.BOSS_AFTER_LEVEL (2) and the next
## level. Clearing level 2 shows a "BOSS FIGHT!" button instead of NEXT LEVEL;
## beating the boss shows PLAY AGAIN (rematch) / CONTINUE (on to level 3, score
## and inventory carried). Dying here is a normal GAME OVER whose PLAY AGAIN
## (R / Enter / tap) restarts the BOSS fight with the score and inventory the
## fight began with (GameProgress.begin_level / restore_level_start_score).
## The title screen's BOSS button jumps straight here (score 0, then CONTINUE
## goes to level 3).
##
## Reuses the level controller for the rancher, weapons, inventory, reticle,
## HUD, touch controls, popups, scoring and the end flow; there are no humans,
## sheep, camp, den or safe zone. The arena is painted by terrain_painter.gd
## (layout "boss_arena") and the Parliament building is placed here.

const PARLIAMENT_TEX := preload("res://assets/boss/parliament.png")
const SLOT_BOSS := Vector2i(21, 11)
const SLOT_BOSS_PLAYER := Vector2i(21, 22)
## Walkable fighting rectangle for the boss (local cells, inclusive).
const ARENA_CELL_MIN := Vector2i(4, 9)
const ARENA_CELL_MAX := Vector2i(37, 25)

var boss: TrustinJudeau
var arena_rect := Rect2()
## Ground-level decals (gravy splats): under the characters, over the lawn.
var ground_fx: Node2D
var return_level: int = LevelConfig.BOSS_AFTER_LEVEL + 1
var boss_hearts_hit: int = 0
var health_bonus: int = 0
var time_bonus: int = 0
var poutine_hits_taken: int = 0
var _player_hit_cool := 0.0
var _defeat_pending := false


func _ready() -> void:
	add_to_group("level_controller")
	add_to_group("boss_level")
	rescues_unlocked = false
	level_number = _current_level()
	target_rescued = 0
	var progress := _progress()
	if progress != null and "boss_return_level" in progress and int(progress.boss_return_level) > 0:
		return_level = int(progress.boss_return_level)
	if progress != null and progress.has_method("begin_level"):
		progress.begin_level()
	fx_layer = Node2D.new()
	fx_layer.name = "FX"
	fx_layer.z_index = 200
	add_child(fx_layer)
	ground_fx = Node2D.new()
	ground_fx.name = "GroundFX"
	ground_fx.z_index = -3
	add_child(ground_fx)
	karens_enabled = false
	drop_rng.randomize()
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
	cam.went_viral.connect(_on_cam_viral)
	cam.infected.connect(_on_cam_infected)
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

	_place_boss_arena()
	state.begin_round(0, 0, 0, level_number)

	var player := rancher
	if "health" in player and "maximum_health" in player:
		state.register_player(player.health, player.maximum_health)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	state.player_health_changed.connect(_on_health_ui)
	state.won.connect(_on_won)
	state.lost.connect(_on_lost)

	if hud and hud.has_method("set_boss_mode"):
		hud.set_boss_mode(LevelConfig.BOSS_NAME, LevelConfig.BOSS_TITLE, boss.hearts, boss.max_hearts)
	_push_score_hud()
	if hud and hud.has_method("set_time"):
		hud.set_time(0.0)
	state.mark_setup_complete()
	_on_health_ui(state.player_health, state.player_max_health)
	Sfx.music(self, "boss")   # build 015b
	_unlock_rescues_after_physics.call_deferred()


func _place_boss_arena() -> void:
	var ground := get_node("Ground") as TileMapLayer
	var ents := get_node("Entities")
	var player := get_node("Entities/Player") as Node2D
	player.global_position = ground.to_global(ground.tile_center(SLOT_BOSS_PLAYER))
	player.facing = Vector2.UP
	var a := ground.to_global(ground.tile_center(ARENA_CELL_MIN))
	var b := ground.to_global(ground.tile_center(ARENA_CELL_MAX))
	arena_rect = Rect2(a, Vector2.ZERO).expand(b)
	# Parliament building on the north edge (row 9 top edge = its base line,
	# so it sits in view above the lawn).
	var base_y := ground.to_global(ground.tile_center(Vector2i(21, 9))).y - 16.0
	var centre_x := ground.to_global(ground.tile_center(Vector2i(21, 7))).x - 16.0
	var bld := Node2D.new()
	bld.name = "Parliament"
	ents.add_child(bld)
	bld.global_position = Vector2(centre_x, base_y)
	var spr := Sprite2D.new()
	spr.texture = PARLIAMENT_TEX
	spr.centered = false
	spr.position = Vector2(-PARLIAMENT_TEX.get_width() * 0.5, -PARLIAMENT_TEX.get_height())
	bld.add_child(spr)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PARLIAMENT_TEX.get_width(), 120.0)
	cs.shape = rect
	cs.position = Vector2(0, -60.0)
	body.add_child(cs)
	bld.add_child(body)
	# The boss.
	boss = TrustinJudeau.new()
	boss.name = "TrustinJudeau"
	boss.level = self
	boss.arena = arena_rect
	ents.add_child(boss)
	boss.global_position = ground.to_global(ground.tile_center(SLOT_BOSS))
	boss.hearts_changed.connect(_on_boss_hearts_changed)
	boss.defeated.connect(_on_boss_defeated)


func _unlock_rescues_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	rescues_unlocked = true
	if hud and hud.has_method("show_boss_title_card"):
		hud.show_boss_title_card()
	print("[boss] arena ready; hearts=", boss.hearts)
	var prog := _progress()
	if OS.is_debug_build() and prog != null and "debug_scenario" in prog and String(prog.debug_scenario).begins_with("boss"):
		DebugScenarios.run_boss(self, String(prog.debug_scenario))


func _start_sheep_spawner() -> void:
	pass


func _start_camp() -> void:
	pass


func _process(delta: float) -> void:
	super(delta)
	_player_hit_cool = maxf(_player_hit_cool - delta, 0.0)
	_check_contact()


## Build 015b: touching Trustin Judeau costs 1 heart (same mercy window as
## poutine hits, so a touch can't chain with a splash).
var contact_hits_taken := 0


func _check_contact() -> void:
	if boss == null or not is_instance_valid(boss) or _ended or _defeat_pending:
		return
	if boss.state == TrustinJudeau.S.INTRO or boss.state == TrustinJudeau.S.DEFEATED:
		return
	var p := get_node_or_null("Entities/Player") as Node2D
	if p == null:
		return
	if p.global_position.distance_to(boss.global_position + Vector2(0, -6)) > LevelConfig.BOSS_CONTACT_RADIUS:
		return
	if poutine_hit_player(boss.global_position, LevelConfig.BOSS_CONTACT_DAMAGE, "OUCH! PERSONAL SPACE!"):
		contact_hits_taken += 1
		Sfx.play(self, "contact", -6.0)


## A poutine reached the rancher: 1 heart (the existing damage rule), at most
## once per BOSS_PLAYER_HIT_COOLDOWN.
func poutine_hit_player(from_pos: Vector2, damage: int = LevelConfig.POUTINE_DAMAGE, popup: String = "GRAVY'D!") -> bool:
	if _ended or _defeat_pending or _player_hit_cool > 0.0:
		return false
	var p := get_node_or_null("Entities/Player")
	if p == null or not p.has_method("take_damage"):
		return false
	var before: int = p.health
	p.take_damage(damage, from_pos)
	if p.health < before:
		_player_hit_cool = LevelConfig.BOSS_PLAYER_HIT_COOLDOWN
		if popup == "GRAVY'D!":
			poutine_hits_taken += 1
		spawn_score_popup(popup, (p as Node2D).global_position + Vector2(0, -20), Color(0.95, 0.7, 0.4), 2)
		return true
	return false


func _on_boss_hearts_changed(hearts: int, maximum: int) -> void:
	if hud and hud.has_method("set_boss_hearts"):
		hud.set_boss_hearts(hearts, maximum)
	if _scoring_open():
		boss_hearts_hit += 1
		_award(LevelConfig.BOSS_POINTS_PER_HEART, boss.global_position + Vector2(0, -40), Color(1.0, 0.86, 0.25))


func _on_boss_defeated() -> void:
	if _ended or _defeat_pending:
		return
	_defeat_pending = true
	var p := get_node_or_null("Entities/Player")
	if p != null and p.has_method("begin_grab_ghost"):
		p.begin_grab_ghost(LevelConfig.BOSS_DEFEAT_ANIM + 10.0)   # no more damage
	for pt in get_tree().get_nodes_in_group("poutine"):
		if is_instance_valid(pt) and pt.has_method("splat"):
			pt.splat()
	if hud and hud.has_method("show_callout"):
		hud.show_callout("BOSS DOWN!", "TRUSTIN JUDEAU IS OUT OF GRAVY", Color(1.0, 0.86, 0.25), 1.2)
	await get_tree().create_timer(LevelConfig.BOSS_DEFEAT_ANIM).timeout
	if is_inside_tree():
		state.trigger_win()


func _on_player_died() -> void:
	state.trigger_lose("Trustin Judeau wins this round!  PLAY AGAIN restarts the boss fight.", "rancher")


func _on_won() -> void:
	_ended = true
	var prog := _progress()
	if prog != null and prog.has_method("carry_inventory") and power_ups != null:
		prog.carry_inventory(power_ups.to_dict())
	var p := get_node_or_null("Entities/Player")
	var hp: int = maxi(int(p.health), 0) if p != null else 0
	health_bonus = hp * LevelConfig.BOSS_HEALTH_BONUS
	time_bonus = maxi(int(LevelConfig.BOSS_TIME_PAR - round_time), 0) * LevelConfig.BOSS_TIME_BONUS_PER_SEC
	clear_bonus = LevelConfig.BOSS_DEFEAT_BONUS + health_bonus + time_bonus
	level_points_bonus_award()
	_finish_round()
	Sfx.play(self, "fanfare", -8.0)
	if hud and hud.has_method("show_boss_end"):
		hud.show_boss_end(true, "Trustin Judeau has left the lawn!  On to level %d." % return_level, score_breakdown())


func _on_lost(reason: String) -> void:
	_ended = true
	_finish_round()
	Sfx.play(self, "lose", -6.0)
	if hud and hud.has_method("show_boss_end"):
		hud.show_boss_end(false, reason, score_breakdown())


func score_breakdown() -> Dictionary:
	var progress := _progress()
	return {
		"boss": true,
		"level": level_number,
		"return_level": return_level,
		"won": state.is_won,
		"hearts_hit": boss_hearts_hit,
		"hearts_points": boss_hearts_hit * LevelConfig.BOSS_POINTS_PER_HEART,
		"boss_hearts": boss.hearts if boss != null else 0,
		"defeat_bonus": LevelConfig.BOSS_DEFEAT_BONUS if state.is_won else 0,
		"health_bonus": health_bonus,
		"time_bonus": time_bonus,
		"bonus": clear_bonus,
		"level_total": level_points + clear_bonus,
		"score": current_score(),
		"high_score": int(progress.high_score) if progress != null and "high_score" in progress else current_score(),
		"new_high": bool(progress.new_high_score) if progress != null and "new_high_score" in progress else false,
		"time": round_time,
	}


## CONTINUE after the win: on to the level after the boss (score + inventory carry).
func request_next_level() -> void:
	if _transitioning or not state.is_won:
		return
	_transitioning = true
	var progress := _progress()
	if progress != null and progress.has_method("finish_boss"):
		progress.finish_boss()
	get_tree().change_scene_to_file(LevelConfig.GAME_SCENE)
