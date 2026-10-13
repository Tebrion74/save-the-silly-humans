extends "res://scripts/boss/huval_level.gd"
## Build 018: the SHLAUS KWOBB boss level (scenes/levels/Boss4Arena.tscn).
##
## Sits between level LevelConfig.BOSS4_AFTER_LEVEL (11) and level 12. Same
## flow as the other bosses (boss_level.gd). Extends huval_level.gd so the
## programmed sheep his Huval delegate clicks in (robo_sheep.gd: bites, splits
## into micro sheep, FEEDBACK LOOP when thrown into him) work unchanged.
## The arena is a snowy alpine summit (terrain layout "summit") in front of a
## chalet-roofed glass congress hall with a WORLD SUMMIT banner.
##
## Damage to the rancher (all through the shared BOSS_PLAYER_HIT_COOLDOWN
## mercy window): touching him, delegate poutine, programmed sheep bite,
## an INVITATION envelope, THE GREAT RESET ring: 1 heart each; micro sheep
## nibble: half a heart.

const SUMMIT_TEX := preload("res://assets/boss4/summit_hall.png")

var envelope_hits_taken := 0
var reset_hits_taken := 0
var dispelled := 0


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS4_NAME
	boss_title = LevelConfig.BOSS4_TITLE
	music_track = "boss4"
	points_per_heart = LevelConfig.BOSS4_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS4_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS4_HEALTH_BONUS
	time_par = LevelConfig.BOSS4_TIME_PAR
	add_to_group("shlaus_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(ShlausKwobb.SHEET, Rect2(4 * 96, 0, 96, 84),
			"FILM HIS DELEGATES AWAY · WHIP HIM 18 TIMES")


func _place_boss_arena() -> void:
	var ground := get_node("Ground") as TileMapLayer
	var ents := get_node("Entities")
	var player := get_node("Entities/Player") as Node2D
	player.global_position = ground.to_global(ground.tile_center(SLOT_BOSS_PLAYER))
	player.facing = Vector2.UP
	var a := ground.to_global(ground.tile_center(ARENA_CELL_MIN))
	var b := ground.to_global(ground.tile_center(ARENA_CELL_MAX))
	arena_rect = Rect2(a, Vector2.ZERO).expand(b)
	var decal := _make_floor_decal()
	if decal != null:
		add_child(decal)
	var base_y := ground.to_global(ground.tile_center(Vector2i(21, 9))).y - 16.0
	var centre_x := ground.to_global(ground.tile_center(Vector2i(21, 7))).x - 16.0
	var bld := Node2D.new()
	bld.name = "SummitHall"
	ents.add_child(bld)
	bld.global_position = Vector2(centre_x, base_y)
	var spr := Sprite2D.new()
	var tex := _backdrop_tex()
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	bld.add_child(spr)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tex.get_width(), 110.0)
	cs.shape = rect
	cs.position = Vector2(0, -55.0)
	body.add_child(cs)
	bld.add_child(body)
	boss = _make_boss()
	boss.level = self
	boss.arena = arena_rect
	ents.add_child(boss)
	boss.global_position = ground.to_global(ground.tile_center(SLOT_BOSS))
	boss.hearts_changed.connect(_on_boss_hearts_changed)
	boss.defeated.connect(_on_boss_defeated)
	boss.summoned.connect(_on_robo_summoned)
	boss.delegate_spawned.connect(_on_delegate_spawned)


## Build 020 hooks (Gill Bates / Nancy Pelotto levels override these).
func _debug_prefix() -> String:
	return "shlaus"


func _make_boss() -> Node:
	var b := ShlausKwobb.new()
	b.name = "ShlausKwobb"
	return b


func _backdrop_tex() -> Texture2D:
	return SUMMIT_TEX


func _make_floor_decal() -> Node2D:
	var snow := SnowDecal.new()
	snow.name = "Snow"
	snow.z_index = -4
	snow.rect = arena_rect
	snow.cover = arena_rect.grow(700.0)   # blanket the whole map: no hard edge
	return snow


func _unlock_rescues_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	rescues_unlocked = true
	if hud and hud.has_method("show_boss_title_card"):
		hud.show_boss_title_card()
	print("[boss%d] arena ready; hearts=" % boss.boss_no, boss.hearts)
	var prog := _progress()
	var pre := _debug_prefix()
	if OS.is_debug_build() and prog != null and "debug_scenario" in prog and String(prog.debug_scenario).begins_with(pre + "_"):
		# build 020: gill_* / nancy_* reuse the shlaus_* scenarios
		DebugScenarios.run_shlaus(self, "shlaus_" + String(prog.debug_scenario).substr(pre.length() + 1))


func _on_delegate_spawned(d: Node) -> void:
	if d.has_signal("dispelled"):
		d.dispelled.connect(_on_delegate_dispelled)


func _on_delegate_dispelled(d: Node) -> void:
	if not _scoring_open():
		return
	dispelled += 1
	var pos: Vector2 = (d as Node2D).global_position if is_instance_valid(d) else boss.global_position
	_award(LevelConfig.POINTS_DISPEL, pos + Vector2(0, -80), Color(0.6, 1.0, 1.0))


func envelope_hit_player(from_pos: Vector2) -> bool:
	if poutine_hit_player(from_pos, 1, "YOU'RE INVITED!"):
		envelope_hits_taken += 1
		return true
	return false


func reset_hit_player(from_pos: Vector2) -> bool:
	if poutine_hit_player(from_pos, 1, "RESET!"):
		reset_hits_taken += 1
		return true
	return false


func _on_boss_down_extra() -> void:
	super()
	for g in ["delegate", "reset_ring", "envelope"]:
		for n in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(n):
				continue
			if n.has_method("dispel"):
				n.dispel(false)
			else:
				n.queue_free()


func defeat_line() -> String:
	return "THE SUMMIT IS ADJOURNED"


func lose_text() -> String:
	return "Shlaus Kwobb has reset you!  PLAY AGAIN restarts the boss fight."


func win_text() -> String:
	return "The Great Reset is cancelled!  On to level %d." % return_level


func score_breakdown() -> Dictionary:
	var d := super()
	d["dispelled"] = dispelled
	d["dispelled_points"] = dispelled * LevelConfig.POINTS_DISPEL
	return d


## Snow on the summit plaza: soft drifts, a red-carpet walkway to the hall and
## footprints (drawn overlay; the terrain tint can only darken).
class SnowDecal extends Node2D:
	var rect := Rect2()
	var cover := Rect2()

	func _draw() -> void:
		var r := rect
		var rng := RandomNumberGenerator.new()
		rng.seed = 1804
		draw_rect(cover, Color(0.93, 0.96, 1.0, 0.40))
		for i in 140:
			var c := Vector2(rng.randf_range(cover.position.x, cover.end.x), rng.randf_range(cover.position.y, cover.end.y))
			var rr := rng.randf_range(18.0, 46.0)
			Summit._ellipse(self, c, Vector2(rr, rr * 0.4), Color(1, 1, 1, rng.randf_range(0.10, 0.2)))
		# red carpet from the hall door down the middle
		var cx := r.get_center().x
		draw_rect(Rect2(Vector2(cx - 34.0, r.position.y), Vector2(68.0, r.size.y * 0.55)), Color(0.62, 0.1, 0.14, 0.75))
		draw_rect(Rect2(Vector2(cx - 34.0, r.position.y), Vector2(4.0, r.size.y * 0.55)), Color(0.95, 0.8, 0.3, 0.7))
		draw_rect(Rect2(Vector2(cx + 30.0, r.position.y), Vector2(4.0, r.size.y * 0.55)), Color(0.95, 0.8, 0.3, 0.7))
		# footprints
		for i in 18:
			var p := Vector2(rng.randf_range(r.position.x + 40, r.end.x - 40), rng.randf_range(r.position.y + 40, r.end.y - 40))
			for k in 4:
				var q := p + Vector2(k * 14.0, (k % 2) * 8.0)
				Summit._ellipse(self, q, Vector2(4, 2.5), Color(0.6, 0.66, 0.78, 0.35))
