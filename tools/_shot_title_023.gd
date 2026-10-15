extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://scenes/Title.tscn")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
