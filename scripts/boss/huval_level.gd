extends "res://scripts/boss/boss_level.gd"
## Build 016: the HUVAL YARHEYHEY boss level (scenes/levels/Boss2Arena.tscn).
##
## Sits between level LevelConfig.BOSS2_AFTER_LEVEL (5) and level 6 (see
## LevelConfig "build 016 progression"). Same flow as the Trustin fight
## (boss_level.gd): title card, hearts bar, PLAY AGAIN restarts the fight with
## the score + inventory it began with, CONTINUE goes on to the next level.
## The arena is a data-centre plaza (terrain layout "data_plaza") in front of
## a glassy lecture hall with a big DATA screen.
##
## Damage to the rancher (all through the shared BOSS_PLAYER_HIT_COOLDOWN
## mercy window, so nothing chains):
##   touching Huval         1 heart
##   programmed sheep bite  1 heart (it bounces off and stalls)
##   lecture ray            1 heart
##   micro sheep nibble     HALF a heart: every 2nd nibble costs 1 heart. The
##                          pending half shows as a half-empty heart and is
##                          kept until the next nibble (or the fight ends).
##                          Micro nibbles use the shorter MICRO_HIT_COOLDOWN.

const PLAZA_TEX := preload("res://assets/boss2/data_plaza.png")

var robo_killed := 0
var micro_killed := 0
var robo_hits_taken := 0
var micro_nibbles := 0
var ray_hits_taken := 0
var chip := 0
var _micro_cool := 0.0


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS2_NAME
	boss_title = LevelConfig.BOSS2_TITLE
	music_track = "boss2"
	points_per_heart = LevelConfig.BOSS2_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS2_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS2_HEALTH_BONUS
	time_par = LevelConfig.BOSS2_TIME_PAR
	add_to_group("huval_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(HuvalYarheyhey.SHEET, Rect2(6 * 96, 0, 96, 84),
			"DODGE HIS PROGRAMMED SHEEP · WHIP HIM 12 TIMES")


func _place_boss_arena() -> void:
	var ground := get_node("Ground") as TileMapLayer
	var ents := get_node("Entities")
	var player := get_node("Entities/Player") as Node2D
	player.global_position = ground.to_global(ground.tile_center(SLOT_BOSS_PLAYER))
	player.facing = Vector2.UP
	var a := ground.to_global(ground.tile_center(ARENA_CELL_MIN))
	var b := ground.to_global(ground.tile_center(ARENA_CELL_MAX))
	arena_rect = Rect2(a, Vector2.ZERO).expand(b)
	var base_y := ground.to_global(ground.tile_center(Vector2i(21, 9))).y - 16.0
	var centre_x := ground.to_global(ground.tile_center(Vector2i(21, 7))).x - 16.0
	var bld := Node2D.new()
	bld.name = "LectureHall"
	ents.add_child(bld)
	bld.global_position = Vector2(centre_x, base_y)
	var spr := Sprite2D.new()
	spr.texture = PLAZA_TEX
	spr.centered = false
	spr.position = Vector2(-PLAZA_TEX.get_width() * 0.5, -PLAZA_TEX.get_height())
	bld.add_child(spr)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PLAZA_TEX.get_width(), 110.0)
	cs.shape = rect
	cs.position = Vector2(0, -55.0)
	body.add_child(cs)
	bld.add_child(body)
	boss = HuvalYarheyhey.new()
	boss.name = "HuvalYarheyhey"
	boss.level = self
	boss.arena = arena_rect
	ents.add_child(boss)
	boss.global_position = ground.to_global(ground.tile_center(SLOT_BOSS))
	boss.hearts_changed.connect(_on_boss_hearts_changed)
	boss.defeated.connect(_on_boss_defeated)
	boss.summoned.connect(_on_robo_summoned)
	boss.system_updated.connect(_on_system_updated)


func _unlock_rescues_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	rescues_unlocked = true
	if hud and hud.has_method("show_boss_title_card"):
		hud.show_boss_title_card()
	print("[boss2] arena ready; hearts=", boss.hearts)
	var prog := _progress()
	if OS.is_debug_build() and prog != null and "debug_scenario" in prog and String(prog.debug_scenario).begins_with("huval"):
		DebugScenarios.run_huval(self, String(prog.debug_scenario))


func _process(delta: float) -> void:
	super(delta)
	_micro_cool = maxf(_micro_cool - delta, 0.0)


# ------------------------------------------------------------------ sheep

func _on_robo_summoned(s: Node) -> void:
	if s.has_signal("popped"):
		s.popped.connect(_on_sheep_popped.bind(s))


func _on_micro_spawned(m: Node) -> void:
	if m.has_signal("popped"):
		m.popped.connect(_on_sheep_popped.bind(m))


## How many more micro sheep fit under MICRO_CAP (a split makes at most this many).
func micro_room() -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("micro_sheep"):
		if is_instance_valid(m) and not m.exploding:
			n += 1
	return maxi(LevelConfig.MICRO_CAP - n, 0)


func _on_sheep_popped(kind: String, by_player: bool, s: Node) -> void:
	if not by_player or not _scoring_open():
		return
	var pos: Vector2 = (s as Node2D).global_position if is_instance_valid(s) else boss.global_position
	if kind == "robo":
		robo_killed += 1
		_award(LevelConfig.POINTS_ROBO, pos, Color(0.5, 1.0, 1.0))
	else:
		micro_killed += 1
		_award(LevelConfig.POINTS_MICRO, pos, Color(1.0, 0.6, 1.0))


func _on_system_updated(_n: int) -> void:
	if hud and hud.has_method("show_callout"):
		hud.show_callout("SYSTEM UPDATE!", "HIS SHEEP GOT FASTER", Color(0.4, 1.0, 1.0), 0.8)


## A programmed sheep bit the rancher: 1 heart (shared mercy window).
func robo_hit_player(s: Node2D) -> bool:
	if poutine_hit_player(s.global_position, LevelConfig.ROBO_DAMAGE, "BAA-SH SCRIPT!"):
		robo_hits_taken += 1
		return true
	return false


## The lecture ray caught the rancher: 1 heart.
func ray_hit_player(from_pos: Vector2) -> bool:
	if poutine_hit_player(from_pos, 1, "LECTURED!"):
		ray_hits_taken += 1
		return true
	return false


## A micro sheep nibbled the rancher: HALF a heart (every 2nd nibble = 1 heart).
func micro_hit_player(s: Node2D) -> bool:
	if _ended or _defeat_pending or _micro_cool > 0.0 or _player_hit_cool > 0.0:
		return false
	var p := get_node_or_null("Entities/Player")
	if p == null or not p.has_method("take_damage"):
		return false
	if "_ghost_active" in p and p._ghost_active:
		return false
	_micro_cool = LevelConfig.MICRO_HIT_COOLDOWN
	micro_nibbles += 1
	chip += 1
	if chip >= LevelConfig.MICRO_CHIPS_PER_HEART:
		chip = 0
		p.take_damage(1, s.global_position)
		_player_hit_cool = LevelConfig.MICRO_HIT_COOLDOWN
		spawn_score_popup("NIBBLED!", (p as Node2D).global_position + Vector2(0, -20), Color(1.0, 0.6, 1.0), 2)
	else:
		Sfx.play(self, "hurt", -14.0, 1.5)
		spawn_score_popup("NIBBLE! 1/2", (p as Node2D).global_position + Vector2(0, -20), Color(1.0, 0.6, 1.0), 2)
	if hud and hud.has_method("set_heart_chip"):
		hud.set_heart_chip(chip)
	return true


func _on_boss_down_extra() -> void:
	# his flock shuts down with him
	for g in ["robo_sheep", "micro_sheep"]:
		for s in get_tree().get_nodes_in_group(g):
			if is_instance_valid(s) and s.has_method("pop"):
				s.pop(false)


func defeat_line() -> String:
	return "HUVAL YARHEYHEY HAS BEEN UNPLUGGED"


func lose_text() -> String:
	return "Huval Yarheyhey predicted this!  PLAY AGAIN restarts the boss fight."


func win_text() -> String:
	return "Huval Yarheyhey's lecture is over!  On to level %d." % return_level


func score_breakdown() -> Dictionary:
	var d := super()
	d["robo"] = robo_killed
	d["robo_points"] = robo_killed * LevelConfig.POINTS_ROBO
	d["micro"] = micro_killed
	d["micro_points"] = micro_killed * LevelConfig.POINTS_MICRO
	return d
