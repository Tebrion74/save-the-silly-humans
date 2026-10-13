extends "res://scripts/boss/shlaus_level.gd"
## Build 020: the NANCY PELOTTO boss level (scenes/levels/Boss6Arena.tscn),
## between level LevelConfig.BOSS6_AFTER_LEVEL (17) and level 18.
## Arena: the Capitol lawn ("boss_arena" terrain) in front of a white domed
## Capitol with an IN SESSION banner. Same rules and damage as Shlaus Kwobb.

const CAPITOL_TEX := preload("res://assets/boss6/capitol_hall.png")


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS6_NAME
	boss_title = LevelConfig.BOSS6_TITLE
	music_track = "boss6"
	points_per_heart = LevelConfig.BOSS6_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS6_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS6_HEALTH_BONUS
	time_par = LevelConfig.BOSS6_TIME_PAR
	add_to_group("shlaus_level")
	add_to_group("nancy_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(NancyPelotto.SHEET6, Rect2(4 * 96, 0, 96, 84),
			"DODGE THE CONES · WHIP HER 22 TIMES")


func _make_boss() -> Node:
	var b := NancyPelotto.new()
	b.name = "NancyPelotto"
	return b


func _backdrop_tex() -> Texture2D:
	return CAPITOL_TEX


func _make_floor_decal() -> Node2D:
	var d := CapitolDecal.new()
	d.name = "Capitol"
	d.z_index = -4
	d.rect = arena_rect
	return d


func _debug_prefix() -> String:
	return "nancy"


func defeat_line() -> String:
	return "THE HOUSE IS ADJOURNED"


func lose_text() -> String:
	return "Nancy Pelotto gavelled you out!  PLAY AGAIN restarts the boss fight."


func win_text() -> String:
	return "Motion carried!  On to level %d." % return_level


## A blue-and-gold carpet up the Capitol steps (drawn overlay).
class CapitolDecal extends Node2D:
	var rect := Rect2()

	func _draw() -> void:
		var r := rect
		var cx := r.get_center().x
		draw_rect(Rect2(Vector2(cx - 34.0, r.position.y), Vector2(68.0, r.size.y * 0.5)), Color(0.12, 0.2, 0.55, 0.7))
		draw_rect(Rect2(Vector2(cx - 34.0, r.position.y), Vector2(4.0, r.size.y * 0.5)), Color(0.95, 0.8, 0.3, 0.8))
		draw_rect(Rect2(Vector2(cx + 30.0, r.position.y), Vector2(4.0, r.size.y * 0.5)), Color(0.95, 0.8, 0.3, 0.8))
