extends "res://scripts/boss/shlaus_level.gd"
## Build 025: the ZelodymerViolentsky boss level (scenes/levels/Boss8Arena.tscn),
## between level LevelConfig.BOSS8_AFTER_LEVEL and the next level.
## Same rules and damage as Shlaus Kwobb; the boss-specific hazards hurt
## through tech_hit_player().

const BACKDROP_TEX := preload("res://assets/boss8/broadcast_tent.png")
var tech_hits_taken := 0
var tech_hits: Dictionary = {}


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS8_NAME
	boss_title = LevelConfig.BOSS8_TITLE
	music_track = "boss8"
	points_per_heart = LevelConfig.BOSS8_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS8_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS8_HEALTH_BONUS
	time_par = LevelConfig.BOSS8_TIME_PAR
	add_to_group("shlaus_level")
	add_to_group("violentsky_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(ZelodymerViolentsky.SHEET8, Rect2(4 * 96, 0, 96, 84),
			"DODGE THE DRONES · WHIP HIM 26 TIMES")


func _make_boss() -> Node:
	var b := ZelodymerViolentsky.new()
	b.name = "ZelodymerViolentsky"
	return b


func _backdrop_tex() -> Texture2D:
	return BACKDROP_TEX


func _debug_prefix() -> String:
	return "violentsky"


## Build 025: lasers, beams, UFO tractor beams, drones.
func tech_hit_player(kind: String, from_pos: Vector2) -> bool:
	var popup: String = {"orbital": "ZAPPED!", "satbeam": "BEAMED!", "ufo": "ABDUCTED!", "drone": "BUZZED!"}.get(kind, "OUCH!")
	if poutine_hit_player(from_pos, 1, popup):
		tech_hits_taken += 1
		tech_hits[kind] = int(tech_hits.get(kind, 0)) + 1
		return true
	return false


func defeat_line() -> String:
	return "THAT'S A WRAP"


func lose_text() -> String:
	return "Zelodymer Violentsky's drones got you!  PLAY AGAIN restarts the boss fight."


func win_text() -> String:
	return "Standing ovation!  On to level %d." % return_level


func _make_floor_decal() -> Node2D:
	var d := FieldDecal.new()
	d.name = "WheatField"
	d.z_index = -4
	d.rect = arena_rect
	d.cover = arena_rect.grow(700.0)
	return d


## A sunny wheat-field floor: gold wash, mown stripes, a few sunflowers.
class FieldDecal extends Node2D:
	var rect := Rect2()
	var cover := Rect2()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2125
		draw_rect(cover, Color(0.95, 0.8, 0.35, 0.38))
		var y := cover.position.y
		var k := 0
		while y < cover.end.y:
			if k % 2 == 0:
				draw_rect(Rect2(cover.position.x, y, cover.size.x, 24.0), Color(1.0, 0.9, 0.5, 0.12))
			y += 24.0
			k += 1
		for i in 26:
			var c := Vector2(rng.randf_range(cover.position.x, cover.end.x), rng.randf_range(cover.position.y, cover.end.y))
			if rect.grow(-40.0).has_point(c):
				continue
			draw_line(c, c + Vector2(0, 16), Color(0.25, 0.5, 0.2, 0.8), 2.0)
			draw_circle(c, 7.0, Color(0.98, 0.78, 0.15, 0.9))
			draw_circle(c, 3.0, Color(0.35, 0.2, 0.08, 0.9))
