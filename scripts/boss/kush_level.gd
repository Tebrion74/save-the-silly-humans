extends "res://scripts/boss/boss_level.gd"
## Build 018: the BEORGE KUSH JR. boss level (scenes/levels/Boss3Arena.tscn).
##
## Sits between level LevelConfig.BOSS3_AFTER_LEVEL (8) and level 9. Same
## flow as the other bosses (boss_level.gd): title card, hearts bar, PLAY
## AGAIN restarts the fight with the score + inventory it began with,
## CONTINUE goes on to the next level. The arena is a flight deck / airfield
## (terrain layout "airfield", runway markings drawn here) in front of a
## carrier island tower with a MISSION ACCOMPLISHED banner.
##
## Damage to the rancher (all through the shared BOSS_PLAYER_HIT_COOLDOWN
## mercy window, so nothing chains): touching him, an airstrike / carpet
## blast, a strafing run: 1 heart each.

const DECK_TEX := preload("res://assets/boss3/flight_deck.png")

var strike_hits_taken := 0
var strafe_hits_taken := 0
var friendly_fire := 0


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS3_NAME
	boss_title = LevelConfig.BOSS3_TITLE
	music_track = "boss3"
	points_per_heart = LevelConfig.BOSS3_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS3_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS3_HEALTH_BONUS
	time_par = LevelConfig.BOSS3_TIME_PAR
	add_to_group("kush_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(BeorgeKush.SHEET, Rect2(6 * 96, 0, 96, 84),
			"LEAVE THE RED MARKS · WHIP HIM 15 TIMES")


func _place_boss_arena() -> void:
	var ground := get_node("Ground") as TileMapLayer
	var ents := get_node("Entities")
	var player := get_node("Entities/Player") as Node2D
	player.global_position = ground.to_global(ground.tile_center(SLOT_BOSS_PLAYER))
	player.facing = Vector2.UP
	var a := ground.to_global(ground.tile_center(ARENA_CELL_MIN))
	var b := ground.to_global(ground.tile_center(ARENA_CELL_MAX))
	arena_rect = Rect2(a, Vector2.ZERO).expand(b)
	# runway markings under everything
	var deck := RunwayDecal.new()
	deck.name = "Runway"
	deck.z_index = -4
	deck.rect = arena_rect.grow(26.0)
	add_child(deck)
	var base_y := ground.to_global(ground.tile_center(Vector2i(21, 9))).y - 16.0
	var centre_x := ground.to_global(ground.tile_center(Vector2i(21, 7))).x - 16.0
	var bld := Node2D.new()
	bld.name = "CarrierIsland"
	ents.add_child(bld)
	bld.global_position = Vector2(centre_x, base_y)
	var spr := Sprite2D.new()
	spr.texture = DECK_TEX
	spr.centered = false
	spr.position = Vector2(-DECK_TEX.get_width() * 0.5, -DECK_TEX.get_height())
	bld.add_child(spr)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DECK_TEX.get_width(), 110.0)
	cs.shape = rect
	cs.position = Vector2(0, -55.0)
	body.add_child(cs)
	bld.add_child(body)
	boss = BeorgeKush.new()
	boss.name = "BeorgeKush"
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
	print("[boss3] arena ready; hearts=", boss.hearts)
	var prog := _progress()
	if OS.is_debug_build() and prog != null and "debug_scenario" in prog and String(prog.debug_scenario).begins_with("kush"):
		DebugScenarios.run_kush(self, String(prog.debug_scenario))


# ------------------------------------------------------------------ air force

## A mark blasted (Airstrike.Mark.blast): explosion, the rancher and (FRIENDLY
## FIRE) Beorge himself take a heart if inside the radius.
func airstrike_blast(pos: Vector2, radius: float, kind: String) -> void:
	var fx := Airstrike.Blast.new()
	fx.radius = radius
	fx_layer.add_child(fx)
	fx.global_position = pos
	Sfx.play(self, "bomb", -9.0, randf_range(0.9, 1.1))
	if _ended:
		return
	var p := get_node_or_null("Entities/Player") as Node2D
	if p != null and not _defeat_pending and p.global_position.distance_to(pos) <= radius:
		if poutine_hit_player(pos, 1, "AIRSTRIKE!" if kind == "strike" else "CARPET BOMBED!"):
			strike_hits_taken += 1
	if LevelConfig.BOSS3_FRIENDLY_FIRE and boss != null and is_instance_valid(boss) and not boss.is_defeated():
		if (boss.global_position).distance_to(pos) <= radius + 12.0:
			if boss.take_hit(1, "airstrike", pos):
				friendly_fire += 1
				if _scoring_open():
					_award(LevelConfig.POINTS_FRIENDLY_FIRE, boss.global_position + Vector2(0, -70), Color(1.0, 0.6, 0.3))


func strafe_hit_player(from_pos: Vector2) -> bool:
	if poutine_hit_player(from_pos, 1, "STRAFED!"):
		strafe_hits_taken += 1
		return true
	return false


func _on_boss_down_extra() -> void:
	for g in ["airstrike_mark", "strafe_run"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.queue_free()


func defeat_line() -> String:
	return "BEORGE KUSH JR. HAS BEEN GROUNDED"


func lose_text() -> String:
	return "Beorge Kush Jr. declares victory!  PLAY AGAIN restarts the boss fight."


func win_text() -> String:
	return "Mission actually accomplished!  On to level %d." % return_level


func score_breakdown() -> Dictionary:
	var d := super()
	d["friendly"] = friendly_fire
	d["friendly_points"] = friendly_fire * LevelConfig.POINTS_FRIENDLY_FIRE
	return d


## Flight-deck markings: a wide runway with a dashed centre line, threshold
## bars and edge lights (drawn, no assets).
class RunwayDecal extends Node2D:
	var rect := Rect2()
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if int(_t * 2.0) != int((_t - delta) * 2.0):
			queue_redraw()

	func _draw() -> void:
		var r := rect
		draw_rect(r, Color(0.32, 0.34, 0.37, 0.55))
		var cy := r.get_center().y
		var strip := Rect2(Vector2(r.position.x, cy - 70.0), Vector2(r.size.x, 140.0))
		draw_rect(strip, Color(0.22, 0.23, 0.26, 0.55))
		var x := r.position.x + 20.0
		while x < r.end.x - 40.0:
			draw_rect(Rect2(Vector2(x, cy - 3.0), Vector2(36.0, 6.0)), Color(0.95, 0.95, 0.9, 0.7))
			x += 64.0
		for side in [r.position.x + 30.0, r.end.x - 70.0]:
			for k in 6:
				draw_rect(Rect2(Vector2(side, strip.position.y + 10.0 + k * 21.0), Vector2(40.0, 10.0)), Color(0.95, 0.95, 0.9, 0.6))
		# deck-edge warning stripes top and bottom
		for e in [r.position.y, r.end.y - 8.0]:
			var xx := r.position.x
			var i := 0
			while xx < r.end.x:
				draw_rect(Rect2(Vector2(xx, e), Vector2(16.0, 8.0)), Color(0.95, 0.78, 0.15, 0.7) if i % 2 == 0 else Color(0.1, 0.1, 0.1, 0.6))
				xx += 16.0
				i += 1
		# edge lights blinking
		var on := int(_t * 2.0) % 2 == 0
		var xx2 := r.position.x + 12.0
		while xx2 < r.end.x:
			for yy in [strip.position.y - 6.0, strip.end.y + 6.0]:
				draw_circle(Vector2(xx2, yy), 3.0, Color(0.3, 0.9, 1.0, 0.9) if on else Color(0.15, 0.4, 0.5, 0.7))
			xx2 += 80.0
