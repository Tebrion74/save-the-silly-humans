extends "res://scripts/boss/finale_level.gd"
## Build 027: the DONALD RUMP boss level (scenes/levels/Boss10Arena.tscn), the
## FINAL boss, after level LevelConfig.BOSS10_AFTER_LEVEL. A golf course (the
## florida biome tiles with mown fairway stripes, bunkers and a putting
## green) in front of a gold tower. CONTINUE after the win plays the ending
## (scenes/ui/Ending.tscn): ENDLESS MODE there goes on to level 30.

const BACKDROP_TEX := preload("res://assets/boss10/gold_tower.png")


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS10_NAME
	boss_title = LevelConfig.BOSS10_TITLE
	music_track = "boss10"
	points_per_heart = LevelConfig.BOSS10_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS10_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS10_HEALTH_BONUS
	time_par = LevelConfig.BOSS10_TIME_PAR
	add_to_group("shlaus_level")
	add_to_group("rump_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(DonaldRump.SHEET10, Rect2(4 * 96, 0, 96, 84),
			"THE FINAL BOSS · WHIP HIM 34 TIMES")


func _make_boss() -> Node:
	var b := DonaldRump.new()
	b.name = "DonaldRump"
	return b


func _backdrop_tex() -> Texture2D:
	return BACKDROP_TEX


func _debug_prefix() -> String:
	return "rump"


func defeat_line() -> String:
	return "GAME, SET... WRONG SPORT. YOU WIN!"


func lose_text() -> String:
	return "Donald Rump says you're fired!  PLAY AGAIN restarts the final boss fight."


func win_text() -> String:
	return "The silly humans are saved!  CONTINUE for the ending."


## CONTINUE after the final win: the ending sequence (credits, then ENDLESS / TITLE).
func request_next_level() -> void:
	if _transitioning or not state.is_won:
		return
	_transitioning = true
	var prog := _progress()
	if prog != null and "ending_pending" in prog:
		prog.ending_pending = true
	get_tree().change_scene_to_file(LevelConfig.ENDING_SCENE)


func _make_floor_decal() -> Node2D:
	var d := GolfDecal.new()
	d.name = "Golf"
	d.z_index = -4
	d.rect = arena_rect
	d.cover = arena_rect.grow(700.0)
	return d


## Fairway: mown stripes (the terrain lawn), sand bunkers, a putting green + pin.
class GolfDecal extends Node2D:
	var rect := Rect2()
	var cover := Rect2()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2710
		var cc := rect.get_center()
		# putting green
		Summit._ellipse(self, cc + Vector2(0, 20), Vector2(170, 92), Color(0.55, 0.9, 0.45, 0.35))
		Summit._ellipse(self, cc + Vector2(0, 20), Vector2(150, 80), Color(0.6, 0.95, 0.5, 0.25))
		# bunkers
		for b in [Vector2(-330, -120), Vector2(320, 140), Vector2(-280, 170), Vector2(360, -150)]:
			var bc: Vector2 = cc + b
			Summit._ellipse(self, bc, Vector2(70 + rng.randf() * 20, 30), Color(0.6, 0.48, 0.25, 0.35))
			Summit._ellipse(self, bc, Vector2(64, 26), Color(0.98, 0.92, 0.72, 0.85))
		# the pin (top-right of the green)
		var pin := cc + Vector2(90, -10)
		Summit._ellipse(self, pin, Vector2(6, 3), Color(0.06, 0.03, 0.08, 0.9))
		draw_line(pin, pin + Vector2(0, -64), Color(0.95, 0.95, 0.9), 3.0)
		draw_colored_polygon(PackedVector2Array([pin + Vector2(1, -64), pin + Vector2(30, -55), pin + Vector2(1, -46)]), Color(0.9, 0.15, 0.2))
		# golf-cart tracks
		for i in 2:
			var y := rect.end.y - 40.0 - i * 10.0
			draw_line(Vector2(cover.position.x, y), Vector2(cover.end.x, y), Color(0.3, 0.45, 0.2, 0.25), 3.0)
