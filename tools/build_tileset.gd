extends SceneTree
## Builds res://assets/tiles/stsh_terrain_tileset.tres from the generated atlases.
## Run: godot --headless --path . -s res://tools/build_tileset.gd
## (after python3 tools/gen_terrain.py && python3 tools/gen_props.py and an --import pass)

const TS := 32
const OUT := "res://assets/tiles/stsh_terrain_tileset.tres"

const SRC_GROUND := 0
const SRC_DIRT := 1
const SRC_PATH := 2
const SRC_FOREST := 3
const SRC_WATER := 4
const SRC_PROPS := 5
const SRC_DETAIL := 6


func _initialize() -> void:
	var tm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/terrain_meta.json"))
	var pm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/props_meta.json"))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TS, TS)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	# terrain sets: 0 dirt, 1 path, 2 forest floor, 3 water (corner matched), 4 wall (side matched)
	var names := ["Dirt", "Path", "Forest floor", "Water"]
	var colors := [Color(0.55, 0.36, 0.2), Color(0.85, 0.72, 0.45), Color(0.15, 0.32, 0.18), Color(0.2, 0.45, 0.8)]
	for i in 4:
		ts.add_terrain_set()
		ts.set_terrain_set_mode(i, TileSet.TERRAIN_MODE_MATCH_CORNERS)
		ts.add_terrain(i)
		ts.set_terrain_name(i, 0, "Grass (empty)")
		ts.set_terrain_color(i, 0, Color(0.3, 0.6, 0.25))
		ts.add_terrain(i)
		ts.set_terrain_name(i, 1, names[i])
		ts.set_terrain_color(i, 1, colors[i])
	ts.add_terrain_set()
	ts.set_terrain_set_mode(4, TileSet.TERRAIN_MODE_MATCH_SIDES)
	ts.add_terrain(4)
	ts.set_terrain_name(4, 0, "Stone wall")
	ts.set_terrain_color(4, 0, Color(0.5, 0.5, 0.55))

	# --- ground: grass rows 0-1, wall row 2
	var g := _atlas("res://assets/tiles/stsh_ground_atlas.png")
	ts.add_source(g, SRC_GROUND)
	for y in 2:
		for x in 16:
			g.create_tile(Vector2i(x, y))
	var full := PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	for m in 16:
		var c := Vector2i(m, 2)
		g.create_tile(c)
		var td := g.get_tile_data(c, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
		td.terrain_set = 4
		td.terrain = 0
		var sides := [[1, TileSet.CELL_NEIGHBOR_TOP_SIDE], [2, TileSet.CELL_NEIGHBOR_RIGHT_SIDE],
			[4, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE], [8, TileSet.CELL_NEIGHBOR_LEFT_SIDE]]
		for s in sides:
			td.set_terrain_peering_bit(s[1], 0 if (m & s[0]) else -1)

	# --- overlays
	var overlay_paths := {SRC_DIRT: "dirt", SRC_PATH: "path", SRC_FOREST: "forest"}
	for sid in overlay_paths:
		var a := _atlas("res://assets/tiles/stsh_%s_atlas.png" % overlay_paths[sid])
		ts.add_source(a, sid)
		var tset: int = sid - 1
		for m in 16:
			var c := Vector2i(m, 0)
			a.create_tile(c)
			_corner_terrain(a.get_tile_data(c, 0), tset, m)
		for v in 4:
			var c2 := Vector2i(v, 1)
			a.create_tile(c2)
			_corner_terrain(a.get_tile_data(c2, 0), tset, 15)

	# --- water (animated, 4 frames, per-mask collision)
	var w := _atlas("res://assets/tiles/stsh_water_atlas.png")
	ts.add_source(w, SRC_WATER)
	var wc: Dictionary = tm["water_collision"]
	for m in 16:
		var c := Vector2i((m % 4) * 4, m / 4)
		_water_tile(w, c, m, wc)
	for v in 3:
		_water_tile(w, Vector2i(v * 4, 4), 15, wc)

	# --- props (multi-cell, y-sorted, trunk/rock/fence collision)
	var p := _atlas("res://assets/tiles/stsh_props_atlas.png")
	ts.add_source(p, SRC_PROPS)
	for prop in pm["props"]:
		var c := Vector2i(int(prop["cell"][0]), int(prop["cell"][1]))
		var sz := Vector2i(int(prop["size"][0]), int(prop["size"][1]))
		p.create_tile(c, sz)
		var td := p.get_tile_data(c, 0)
		var center := Vector2(sz.x * TS, sz.y * TS) * 0.5
		var anchor := Vector2(prop["anchor"][0], prop["anchor"][1])
		td.texture_origin = Vector2i(anchor - center)
		td.y_sort_origin = int(prop.get("ysort", 0))
		var i := 0
		for poly in prop["polys"]:
			var pts := PackedVector2Array()
			for pt in poly:
				pts.append(Vector2(pt[0], pt[1]))
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, i, pts)
			i += 1

	# --- flat details
	var d := _atlas("res://assets/tiles/stsh_details_atlas.png")
	ts.add_source(d, SRC_DETAIL)
	for det in pm["details"]:
		d.create_tile(Vector2i(int(det["cell"][0]), int(det["cell"][1])))

	var err := ResourceSaver.save(ts, OUT)
	# keep the TileSet UID used by Level01.tscn since build 002
	var txt := FileAccess.get_file_as_string(OUT)
	if not txt.contains("uid="):
		txt = txt.replace('[gd_resource type="TileSet"', '[gd_resource type="TileSet" uid="uid://bstshterrainset01"')
		var fw := FileAccess.open(OUT, FileAccess.WRITE)
		fw.store_string(txt)
		fw.close()
	print("tileset saved: ", OUT, " err=", err)
	quit()


func _atlas(path: String) -> TileSetAtlasSource:
	var a := TileSetAtlasSource.new()
	a.texture = load(path)
	a.texture_region_size = Vector2i(TS, TS)
	return a


func _corner_terrain(td: TileData, tset: int, m: int) -> void:
	td.terrain_set = tset
	td.terrain = 1 if m == 15 else 0
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, 1 if (m & 1) else 0)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, 1 if (m & 2) else 0)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, 1 if (m & 4) else 0)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, 1 if (m & 8) else 0)


func _water_tile(w: TileSetAtlasSource, c: Vector2i, m: int, wc: Dictionary) -> void:
	w.create_tile(c)
	w.set_tile_animation_frames_count(c, 4)
	for f in 4:
		w.set_tile_animation_frame_duration(c, f, 0.32)
	var td := w.get_tile_data(c, 0)
	_corner_terrain(td, 3, m)
	var i := 0
	for poly in wc[str(m)]:
		var pts := PackedVector2Array()
		for pt in poly:
			pts.append(Vector2(pt[0], pt[1]))
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, i, pts)
		i += 1
