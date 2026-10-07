extends SceneTree
## Headless layout check: godot --headless --path . -s res://tools/verify_layout.gd
## Samples real physics at each Level01 cell, then BFS-checks that all slots are
## walkable, have open space and are reachable from the player start.

const SLOTS := {"player": Vector2i(36, 24), "safe": Vector2i(60, 38), "den": Vector2i(8, 10),
	"h1": Vector2i(8, 8), "h2": Vector2i(8, 40), "h3": Vector2i(40, 8), "h4": Vector2i(20, 20),
	"h5": Vector2i(12, 32), "s1": Vector2i(18, 14), "s2": Vector2i(45, 12), "s3": Vector2i(50, 30),
	"s4": Vector2i(59, 10), "s5": Vector2i(21, 42), "camp": Vector2i(9, 40)}
## Build 010: camp spawn spots (pixel offsets from the camp centre, see
## scripts/world/human_camp.gd SPAWN_SPOTS) must be walkable and reachable too.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var lvl: Node2D = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(lvl)
	for i in 6:
		await physics_frame
	var ground: TileMapLayer = lvl.get_node("Ground")
	var ts: TileSet = ground.tile_set
	# collision summary per source
	for si in ts.get_source_count():
		var sid := ts.get_source_id(si)
		var src := ts.get_source(sid) as TileSetAtlasSource
		var n := 0
		for ti in src.get_tiles_count():
			var td := src.get_tile_data(src.get_tile_id(ti), 0)
			if td and ts.get_physics_layers_count() > 0 and td.get_collision_polygons_count(0) > 0:
				n += 1
		print("source %d %s tiles=%d colliding=%d" % [sid, src.texture.resource_path.get_file(), src.get_tiles_count(), n])
	for ln in ["Ground", "ForestFloor", "Dirt", "Path", "Water", "Detail", "Entities/Props"]:
		var l: TileMapLayer = lvl.get_node(ln)
		print("layer %s cells=%d collision_enabled=%s" % [ln, l.get_used_cells().size(), l.collision_enabled])
	var origin: Vector2i = ground.get_map_origin()
	var W := 72; var H := 48
	var space := lvl.get_world_2d().direct_space_state
	var blocked := {}
	for y in H:
		for x in W:
			var c: Vector2 = ground.tile_center(Vector2i(x, y))
			for o in [Vector2(-8, -8), Vector2(8, -8), Vector2(-8, 8), Vector2(8, 8), Vector2.ZERO]:
				var q := PhysicsPointQueryParameters2D.new()
				q.position = c + o
				q.collision_mask = 1
				var hits := space.intersect_point(q, 8)
				var solid := false
				for h in hits:
					if h.collider is TileMapLayer:
						solid = true
				if solid:
					blocked[Vector2i(x, y)] = true
					break
	print("blocked cells: %d of %d" % [blocked.size(), W * H])
	# reachability
	var start: Vector2i = SLOTS["player"]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while queue.size() > 0:
		var p: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or seen.has(n) or blocked.has(n):
				continue
			seen[n] = true
			queue.append(n)
	var free_total := W * H - blocked.size()
	print("reachable %d of %d free cells" % [seen.size(), free_total])
	var bad := 0
	for k in SLOTS:
		var s: Vector2i = SLOTS[k]
		var open := 0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if not blocked.has(s + Vector2i(dx, dy)):
					open += 1
		var ok: bool = not blocked.has(s) and seen.has(s) and open >= 22
		if not ok:
			bad += 1
		print("%s %s blocked=%s reachable=%s open5x5=%d/25 %s" % [k, s, blocked.has(s), seen.has(s), open, "OK" if ok else "BAD"])
	# Build 010: camp — every human spawn spot walkable + reachable, and the
	# camp must not overlap the safe zone, the den, ponds or trees.
	var camp_cell: Vector2i = SLOTS["camp"]
	var camp_center: Vector2 = ground.tile_center(camp_cell)
	var camp_script: Script = load("res://scripts/world/human_camp.gd")
	var spots: Array = camp_script.SPAWN_SPOTS
	for sp in spots:
		var cell: Vector2i = ground.local_pos_to_local_cell(camp_center + sp)
		var ok2: bool = not blocked.has(cell) and seen.has(cell) and ground.is_interior_local(cell, 1)
		if not ok2:
			bad += 1
		print("camp spawn %s cell %s blocked=%s reachable=%s %s" % [sp, cell, blocked.has(cell), seen.has(cell), "OK" if ok2 else "BAD"])
	var props_l: TileMapLayer = lvl.get_node("Entities/Props")
	var water_l: TileMapLayer = lvl.get_node("Water")
	var camp_clash := 0
	for dy in range(-3, 4):
		for dx in range(-5, 6):
			var k: Vector2i = origin + camp_cell + Vector2i(dx, dy)
			if props_l.get_cell_source_id(k) != -1 or water_l.get_cell_source_id(k) != -1:
				camp_clash += 1
	var d_safe: int = maxi(absi(camp_cell.x - SLOTS["safe"].x), absi(camp_cell.y - SLOTS["safe"].y))
	var d_den: int = maxi(absi(camp_cell.x - SLOTS["den"].x), absi(camp_cell.y - SLOTS["den"].y))
	var camp_ok: bool = camp_clash == 0 and d_safe >= 12 and d_den >= 12
	if not camp_ok:
		bad += 1
	print("camp footprint props/water=%d cheb_to_safe=%d cheb_to_den=%d %s" % [camp_clash, d_safe, d_den, "OK" if camp_ok else "BAD"])
	var path: TileMapLayer = lvl.get_node("Path")
	print("safe on path pad: ", path.get_cell_source_id(origin + SLOTS["safe"]) != -1)
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	quit()
