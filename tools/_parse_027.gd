extends SceneTree
func _initialize() -> void:
	for p in ["res://scripts/boss/starwars.gd", "res://scripts/boss/drones.gd", "res://scripts/boss/rogan.gd", "res://scripts/boss/violentsky.gd",
			"res://scripts/boss/rogan_level.gd", "res://scripts/boss/violentsky_level.gd", "res://scripts/boss/shlaus.gd", "res://scripts/boss/summit.gd",
			"res://scripts/level_config.gd", "res://scripts/game_progress_check.gd", "res://scripts/game_progress.gd", "res://scripts/world/terrain_painter.gd",
			"res://scripts/sfx.gd", "res://scripts/ui/hud.gd", "res://scripts/player/player.gd", "res://scripts/player/power_ups.gd",
			"res://scripts/world/power_up.gd", "res://scripts/level_controller.gd", "res://scripts/beta_tools.gd", "res://scripts/ui/title_screen.gd",
			"res://scripts/boss/boss_level.gd", "res://scripts/world/secrets/secret_chambers.gd", "res://scripts/boss/finale.gd", "res://scripts/boss/puddin.gd", "res://scripts/boss/rump.gd", "res://scripts/boss/finale_level.gd", "res://scripts/boss/puddin_level.gd", "res://scripts/boss/rump_level.gd", "res://scripts/ui/ending.gd", "res://scripts/audio/game_audio.gd", "res://scripts/ui/attract_mode.gd", "res://scripts/ui/initials_entry.gd", "res://scripts/ui/ending.gd"]:
		var s = load(p)
		print("PARSE ", "OK  " if s != null and (s as Script).can_instantiate() else "FAIL", p)
	quit()
