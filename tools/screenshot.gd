extends SceneTree
## Renders preview PNGs of Level01 (needs a real renderer, e.g. under xvfb-run):
##   godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd -- <out_prefix>
## Writes <prefix>-gameplay.png (player camera + HUD) and <prefix>-full.png
## (whole 72x48 map stitched from 1280x720 tiles, HUD hidden).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "/tmp/stsh-preview"
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in 50:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(prefix + "-gameplay.png")
	print("saved ", prefix, "-gameplay.png")

	var level := main.get_node("Level01")
	var hud := level.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	var ground := level.get_node("Ground") as TileMapLayer
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = false
	level.add_child(cam)
	cam.make_current()
	var vs := root.get_visible_rect().size
	var tl: Vector2 = ground.to_global(ground.map_to_local(ground.get_map_origin()) - Vector2(16, 16))
	var map_px := Vector2(ground.map_width, ground.map_height) * 32.0
	var full := Image.create(int(map_px.x), int(map_px.y), false, Image.FORMAT_RGBA8)
	var xs: Array = [0.0, map_px.x - vs.x]
	var ys: Array = []
	var yy := 0.0
	while yy + vs.y < map_px.y:
		ys.append(yy)
		yy += vs.y
	ys.append(map_px.y - vs.y)
	var xx := 0.0
	xs = []
	while xx + vs.x < map_px.x:
		xs.append(xx)
		xx += vs.x
	xs.append(map_px.x - vs.x)
	for y in ys:
		for x in xs:
			cam.global_position = tl + Vector2(x, y) + vs * 0.5
			for i in 4:
				await process_frame
			var shot := root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			full.blit_rect(shot, Rect2i(Vector2i.ZERO, Vector2i(vs)), Vector2i(int(x), int(y)))
	full.save_png(prefix + "-full.png")
	print("saved ", prefix, "-full.png")
	quit()
