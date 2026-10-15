extends "res://scripts/boss/finale_level.gd"
## Build 027: the VLADIMIR PUDDIN boss level (scenes/levels/Boss9Arena.tscn),
## between level LevelConfig.BOSS9_AFTER_LEVEL and the next level. A frozen
## taiga clearing (the taiga biome tiles + a snow/ice decal) in front of a
## log lodge with birches.

const BACKDROP_TEX := preload("res://assets/boss9/taiga_lodge.png")


func _configure_boss() -> void:
	boss_name = LevelConfig.BOSS9_NAME
	boss_title = LevelConfig.BOSS9_TITLE
	music_track = "boss9"
	points_per_heart = LevelConfig.BOSS9_POINTS_PER_HEART
	defeat_bonus_points = LevelConfig.BOSS9_DEFEAT_BONUS
	health_bonus_per_heart = LevelConfig.BOSS9_HEALTH_BONUS
	time_par = LevelConfig.BOSS9_TIME_PAR
	add_to_group("shlaus_level")
	add_to_group("puddin_level")


func _customise_title_card() -> void:
	if hud and hud.has_method("set_title_card_art"):
		hud.set_title_card_art(VladimirPuddin.SHEET9, Rect2(4 * 128, 0, 128, 96),
			"DODGE THE TANKS · WHIP HIM 30 TIMES")


func _make_boss() -> Node:
	var b := VladimirPuddin.new()
	b.name = "VladimirPuddin"
	return b


func _backdrop_tex() -> Texture2D:
	return BACKDROP_TEX


func _debug_prefix() -> String:
	return "puddin"


func defeat_line() -> String:
	return "THE STRONGMAN IS OUT IN THE COLD"


func lose_text() -> String:
	return "Vladimir Puddin flipped you into a snowbank!  PLAY AGAIN restarts the boss fight."


func win_text() -> String:
	return "The taiga thaws!  On to level %d." % return_level


func _make_floor_decal() -> Node2D:
	var d := IceDecal.new()
	d.name = "Ice"
	d.z_index = -4
	d.rect = arena_rect
	d.cover = arena_rect.grow(700.0)
	return d


## A frozen clearing: snow drifts, a cracked ice pond in the middle, hoof prints.
class IceDecal extends Node2D:
	var rect := Rect2()
	var cover := Rect2()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2709
		draw_rect(cover, Color(0.95, 0.97, 1.0, 0.25))
		for i in 120:
			var c := Vector2(rng.randf_range(cover.position.x, cover.end.x), rng.randf_range(cover.position.y, cover.end.y))
			var rr := rng.randf_range(18.0, 46.0)
			Summit._ellipse(self, c, Vector2(rr, rr * 0.4), Color(1, 1, 1, rng.randf_range(0.12, 0.25)))
		var cc := rect.get_center() + Vector2(0, 30)
		Summit._ellipse(self, cc, Vector2(230, 120), Color(0.7, 0.86, 0.98, 0.45))
		Summit._ellipse(self, cc, Vector2(200, 100), Color(0.78, 0.92, 1.0, 0.4))
		for i in 9:
			var a := rng.randf() * TAU
			var p := cc + Vector2(cos(a) * 30, sin(a) * 15)
			var q := p
			for k in 4:
				var nq := q + Vector2(cos(a + rng.randf_range(-0.6, 0.6)), sin(a + rng.randf_range(-0.6, 0.6)) * 0.5) * rng.randf_range(20, 40)
				draw_line(q, nq, Color(1, 1, 1, 0.5), 1.5)
				q = nq
		for i in 14:
			var p := Vector2(rng.randf_range(rect.position.x + 40, rect.end.x - 40), rng.randf_range(rect.position.y + 40, rect.end.y - 40))
			for k in 4:
				var o := p + Vector2(k * 16.0, (k % 2) * 7.0)
				draw_arc(o, 4.0, PI * 0.1, PI * 0.9, 6, Color(0.55, 0.62, 0.76, 0.45), 2.0)
