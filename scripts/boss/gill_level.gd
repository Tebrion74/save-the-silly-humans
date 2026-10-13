extends "res://scripts/boss/shlaus_level.gd"
## Build 020: the GILL BATES boss level (scenes/levels/Boss5Arena.tscn),
## between level LevelConfig.BOSS5_AFTER_LEVEL (14) and level 15.
## Arena: a paved tech campus ("data_plaza" terrain) in front of a server farm
## dressed up for a FOUNDATION GALA (red carpet, string lights, blinking racks).
## Same rules and damage as Shlaus Kwobb (see shlaus_level.gd).

const GALA_TEX := preload("res://assets/boss5/server_gala.png")


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS5_NAME
	boss_title = LevelConfig.BOSS5_TITLE
	music_track = "boss5"
	points_per_heart = LevelConfig.BOSS5_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS5_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS5_HEALTH_BONUS
	time_par = LevelConfig.BOSS5_TIME_PAR
	add_to_group("shlaus_level")
	add_to_group("gill_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(GillBates.SHEET5, Rect2(4 * 96, 0, 96, 84),
			"DODGE THE PATCHES · WHIP HIM 20 TIMES")


func _make_boss() -> Node:
	var b := GillBates.new()
	b.name = "GillBates"
	return b


func _backdrop_tex() -> Texture2D:
	return GALA_TEX


func _make_floor_decal() -> Node2D:
	var d := GalaDecal.new()
	d.name = "Gala"
	d.z_index = -4
	d.rect = arena_rect
	return d


func _debug_prefix() -> String:
	return "gill"


func defeat_line() -> String:
	return "FATAL ERROR: BOSS NOT FOUND"


func lose_text() -> String:
	return "Gill Bates force-quit you!  PLAY AGAIN restarts the boss fight."


func win_text() -> String:
	return "Uninstalled!  On to level %d." % return_level


## Red carpet + cable trays across the campus plaza (drawn overlay).
class GalaDecal extends Node2D:
	var rect := Rect2()

	func _draw() -> void:
		var r := rect
		var cx := r.get_center().x
		draw_rect(Rect2(Vector2(cx - 34.0, r.position.y), Vector2(68.0, r.size.y * 0.5)), Color(0.62, 0.1, 0.14, 0.7))
		draw_rect(Rect2(Vector2(cx - 34.0, r.position.y), Vector2(4.0, r.size.y * 0.5)), Color(0.95, 0.8, 0.3, 0.7))
		draw_rect(Rect2(Vector2(cx + 30.0, r.position.y), Vector2(4.0, r.size.y * 0.5)), Color(0.95, 0.8, 0.3, 0.7))
		var rng := RandomNumberGenerator.new()
		rng.seed = 2014
		for i in 6:
			var y := r.position.y + r.size.y * (0.35 + 0.1 * i)
			draw_line(Vector2(r.position.x + 30, y), Vector2(r.end.x - 30, y + rng.randf_range(-6, 6)), Color(0.2, 0.35, 0.7, 0.25), 3.0)
