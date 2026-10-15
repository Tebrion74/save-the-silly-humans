extends "res://scripts/boss/shlaus_level.gd"
## Build 025: the ReanaldRogan boss level (scenes/levels/Boss7Arena.tscn),
## between level LevelConfig.BOSS7_AFTER_LEVEL and the next level.
## Same rules and damage as Shlaus Kwobb; the boss-specific hazards hurt
## through tech_hit_player().

const BACKDROP_TEX := preload("res://assets/boss7/space_hq.png")
var tech_hits_taken := 0
var tech_hits: Dictionary = {}


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS7_NAME
	boss_title = LevelConfig.BOSS7_TITLE
	music_track = "boss7"
	points_per_heart = LevelConfig.BOSS7_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS7_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS7_HEALTH_BONUS
	time_par = LevelConfig.BOSS7_TIME_PAR
	add_to_group("shlaus_level")
	add_to_group("rogan_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(ReanaldRogan.SHEET7, Rect2(4 * 96, 0, 96, 84),
			"DODGE THE LASERS · WHIP HIM 24 TIMES")


func _make_boss() -> Node:
	var b := ReanaldRogan.new()
	b.name = "ReanaldRogan"
	return b


func _backdrop_tex() -> Texture2D:
	return BACKDROP_TEX


func _debug_prefix() -> String:
	return "rogan"


## Build 025: lasers, beams, UFO tractor beams, drones.
func tech_hit_player(kind: String, from_pos: Vector2) -> bool:
	var popup: String = {"orbital": "ZAPPED!", "satbeam": "BEAMED!", "ufo": "ABDUCTED!", "drone": "BUZZED!"}.get(kind, "OUCH!")
	if poutine_hit_player(from_pos, 1, popup):
		tech_hits_taken += 1
		tech_hits[kind] = int(tech_hits.get(kind, 0)) + 1
		return true
	return false


func defeat_line() -> String:
	return "THE STAR SHIELD IS DOWN"


func lose_text() -> String:
	return "Reanald Rogan zapped you from orbit!  PLAY AGAIN restarts the boss fight."


func win_text() -> String:
	return "Mission accomplished!  On to level %d." % return_level


func _make_floor_decal() -> Node2D:
	var d := PadDecal.new()
	d.name = "LaunchPad"
	d.z_index = -4
	d.rect = arena_rect
	d.cover = arena_rect.grow(700.0)
	return d


## A dusky launch-pad apron: dark tarmac, a faint star grid, a big pad circle.
class PadDecal extends Node2D:
	var rect := Rect2()
	var cover := Rect2()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2025
		draw_rect(cover, Color(0.12, 0.14, 0.24, 0.55))
		var x := cover.position.x
		while x < cover.end.x:
			draw_line(Vector2(x, cover.position.y), Vector2(x, cover.end.y), Color(0.4, 0.6, 1.0, 0.07), 2.0)
			x += 64.0
		var y := cover.position.y
		while y < cover.end.y:
			draw_line(Vector2(cover.position.x, y), Vector2(cover.end.x, y), Color(0.4, 0.6, 1.0, 0.07), 2.0)
			y += 64.0
		for i in 90:
			var c := Vector2(rng.randf_range(cover.position.x, cover.end.x), rng.randf_range(cover.position.y, cover.end.y))
			draw_circle(c, rng.randf_range(1.0, 2.0), Color(1, 1, 1, rng.randf_range(0.15, 0.4)))
		var cc := rect.get_center()
		draw_polyline(Summit.ring_pts(cc, Vector2(210, 150), 0.0, TAU, 48), Color(1.0, 0.85, 0.3, 0.35), 6.0)
		draw_polyline(Summit.ring_pts(cc, Vector2(170, 120), 0.0, TAU, 48), Color(1.0, 0.85, 0.3, 0.2), 3.0)
