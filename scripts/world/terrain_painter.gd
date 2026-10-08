extends TileMapLayer

## Build 008 Level01 painter. Fills this TileMapLayer (grass + stone border wall)
## and its sibling layers with a designed ranch, using a fixed seed so every
## run (desktop and web) gets the same map:
##   ForestFloor / Dirt / Path / Water  corner-matched overlay layers
##   Tint                               soft multiply light/shade (Sprite2D)
##   Detail                             flat decals (flowers, tufts, reeds, lilies)
##   Entities/Props                     y-sorted trees, bushes, rocks, fences
## Only Ground (wall), Water and Props carry collision.
##
## Painting only runs when this layer is empty, so a map painted by hand in the
## editor is kept. Set paint_on_ready=false to disable it entirely.
##
## Spawn helpers (get_map_origin / tile_center / is_interior_local) are always
## callable from map_width/height — they do not require paint to have run.

@export var paint_on_ready: bool = true
@export var map_width: int = 72
@export var map_height: int = 48
@export var map_seed: int = 8008
@export var limit_camera: bool = true

# TileSet source ids (see tools/build_tileset.gd)
const SRC_GROUND := 0
const SRC_DIRT := 1
const SRC_PATH := 2
const SRC_FOREST := 3
const SRC_WATER := 4
const SRC_PROPS := 5
const SRC_DETAIL := 6
const SOURCE_ID := SRC_GROUND  # legacy name

const WALL_ROW := 2
const GRASS_PLAIN: Array[int] = [0, 1, 2, 3, 11, 15, 16, 18, 20, 22, 24, 27, 28, 30]
const GRASS_TUFT: Array[int] = [4, 5, 14, 17, 26]
const GRASS_FLOWER: Array[int] = [6, 7, 8, 21, 23, 29]
const GRASS_MISC: Array[int] = [9, 19, 10, 25]

# props atlas coords (tools/gen_props.py)
const OAKS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0), Vector2i(6, 0)]
const OAK_FRUIT := Vector2i(9, 0)
const PINE := Vector2i(12, 0)
const BIRCH := Vector2i(14, 0)
const BUSHES: Array[Vector2i] = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
const BUSH_BIG := Vector2i(4, 4)
const BOULDER := Vector2i(6, 4)
const ROCKS: Array[Vector2i] = [Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4)]
const LOG := Vector2i(11, 4)
const FENCE_L := Vector2i(13, 4)
const FENCE_M := Vector2i(14, 4)
const FENCE_R := Vector2i(15, 4)
const FENCE_V := Vector2i(8, 5)
const FENCE_POST := Vector2i(9, 5)
const STUMP := Vector2i(10, 5)
const HAY := Vector2i(11, 5)
const SIGN := Vector2i(12, 5)
const TROUGH := Vector2i(13, 5)

# detail atlas coords
const D_TUFTS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const D_FLOWERS: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)]
const D_FOREST: Array[Vector2i] = [Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(10, 0),
	Vector2i(11, 0), Vector2i(13, 0), Vector2i(14, 0), Vector2i(15, 0), Vector2i(13, 0), Vector2i(10, 0)]
const D_PEBBLES := Vector2i(12, 0)
const D_REEDS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1)]
const D_LILY: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
const D_SHORE_STONES := Vector2i(5, 1)

## Local tile cells kept clear of water, trees, rocks and fences — must match
## level_controller.gd spawn slots.
const CLEARINGS: Array[Vector2i] = [
	Vector2i(60, 38),  # SafeZone (bottom-right)
	Vector2i(36, 24),  # Player
	Vector2i(8, 8),    # Human1
	Vector2i(8, 40),   # Human2
	Vector2i(40, 8),   # Human3
	Vector2i(20, 20),  # Human4
	Vector2i(12, 32),  # Human5
	Vector2i(18, 14),  # Sheep1
	Vector2i(45, 12),  # Sheep2
	Vector2i(50, 30),  # Sheep3
	Vector2i(8, 10),   # SheepSpawner den (top-left)
	Vector2i(9, 40),   # Build 010: silly human camp (southwest)
]

## Build 010: silly human camp centre (local cell) — trodden dirt yard, kept
## clear of trees/rocks. Must match level_controller.gd SLOT_CAMP.
const CAMP_CELL := Vector2i(9, 40)

## Woodland clusters: centre (vertex coords), radii, dominant tree mix.
const WOODS := [
	{"c": Vector2(57.0, 12.5), "r": Vector2(11.5, 7.5), "mix": "oak_pine"},   # Northeast Wood
	{"c": Vector2(25.0, 32.5), "r": Vector2(8.5, 6.5), "mix": "oak_birch"},   # Western Wood
	{"c": Vector2(41.0, 41.5), "r": Vector2(10.5, 5.0), "mix": "oak_fruit"},  # South Wood
	{"c": Vector2(29.0, 5.5), "r": Vector2(5.5, 3.0), "mix": "pine"},         # North copse
	{"c": Vector2(3.5, 24.0), "r": Vector2(2.5, 5.0), "mix": "oak_birch"},    # West hedge grove
]

## Trails (vertex coords) and their half-width in vertices.
const TRAILS := [
	{"w": 0.85, "p": [Vector2(8.5, 10.5), Vector2(14, 13), Vector2(24, 17.5), Vector2(36.5, 23.0), Vector2(46, 27), Vector2(54, 33), Vector2(60.5, 38.5)]},
	{"w": 0.6, "p": [Vector2(36.5, 23.0), Vector2(44, 19), Vector2(52, 14.5), Vector2(60, 10), Vector2(67, 5)]},
	{"w": 0.6, "p": [Vector2(36.5, 23.0), Vector2(30, 26.5), Vector2(24, 31), Vector2(16, 36), Vector2(8.5, 40.5)]},
	{"w": 0.6, "p": [Vector2(54, 33), Vector2(46, 38), Vector2(39, 42), Vector2(28, 44), Vector2(16, 42.5), Vector2(8.5, 40.5)]},
	{"w": 0.6, "p": [Vector2(24, 17.5), Vector2(28, 12.5), Vector2(34, 9.5), Vector2(40.5, 8.5)]},
]

## Ponds (vertex coords).
const PONDS := [
	{"c": Vector2(32.0, 15.5), "r": Vector2(4.0, 2.6)},
	{"c": Vector2(12.5, 25.0), "r": Vector2(3.2, 2.4)},
	{"c": Vector2(63.0, 26.0), "r": Vector2(4.2, 3.0)},
	{"c": Vector2(29.5, 36.5), "r": Vector2(2.6, 1.9)},
]

## Build 015: "ranch" (Level01) or "boss_arena" (Parliament-lawn clearing).
@export var layout: String = "ranch"
var _arena := false
var _woods_v: Array = WOODS
var _trails_v: Array = TRAILS
var _ponds_v: Array = PONDS
var _clear_v: Array = CLEARINGS
var _vw := 0
var _vh := 0
var _forest := PackedByteArray()
var _dirt := PackedByteArray()
var _path := PackedByteArray()
var _water := PackedByteArray()
var _blocked: Dictionary = {}   # local cell -> true (collision props / wall)
var _occupied: Dictionary = {}  # local cell -> true (any prop footprint)
var _trunks: Array[Vector2i] = []
var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if not paint_on_ready:
		return
	if get_used_cells().size() > 0:
		return
	if layout == "boss_arena":
		paint_boss_arena()
	else:
		paint_level01()


func get_map_origin() -> Vector2i:
	return Vector2i(-map_width / 2, -map_height / 2)


## World/local position of the center of a local map cell (0..width-1, 0..height-1).
func tile_center(local_cell: Vector2i) -> Vector2:
	return map_to_local(get_map_origin() + local_cell)


## True only if local is strictly inside the wall ring with the given margin
## (not on wall cells 0 / width-1 / 0 / height-1).
func is_interior_local(local: Vector2i, margin: int = 3) -> bool:
	return (
		local.x >= 1 + margin
		and local.x <= map_width - 2 - margin
		and local.y >= 1 + margin
		and local.y <= map_height - 2 - margin
	)


## Convert a position in this layer's local space to a local map cell.
func local_pos_to_local_cell(local_pos: Vector2) -> Vector2i:
	return local_to_map(local_pos) - get_map_origin()


## Soft clamp a position (this layer's local / Level01 space) into the interior.
func clamp_to_interior(local_pos: Vector2, margin: int = 2) -> Vector2:
	var cell := local_pos_to_local_cell(local_pos)
	cell.x = clampi(cell.x, 1 + margin, map_width - 2 - margin)
	cell.y = clampi(cell.y, 1 + margin, map_height - 2 - margin)
	return tile_center(cell)


func _layer(node_name: String) -> TileMapLayer:
	var l := get_parent().get_node_or_null(node_name) as TileMapLayer
	if l == null:
		l = get_parent().get_node_or_null("Entities/" + node_name) as TileMapLayer
	if l:
		l.clear()
		l.tile_set = tile_set
	return l


# ------------------------------------------------------------------ layout

func paint_level01() -> void:
	clear()
	_vw = map_width + 1
	_vh = map_height + 1
	_forest = _grid()
	_dirt = _grid()
	_path = _grid()
	_water = _grid()
	_blocked.clear()
	_occupied.clear()
	_trunks.clear()
	_rng.seed = map_seed
	_noise.seed = map_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.16
	_noise2.seed = map_seed + 1
	_noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise2.frequency = 0.07

	_layout_vertices()
	var origin := get_map_origin()
	_paint_ground(origin)
	_paint_overlay(_layer("ForestFloor"), _forest, SRC_FOREST, origin)
	_paint_overlay(_layer("Dirt"), _dirt, SRC_DIRT, origin)
	_paint_overlay(_layer("Path"), _path, SRC_PATH, origin)
	_paint_water(_layer("Water"), origin)
	_paint_props(_layer("Props"), origin)
	_paint_details(_layer("Detail"), origin)
	_paint_tint(origin)
	if limit_camera:
		_apply_camera_limits.call_deferred()


func _grid() -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(_vw * _vh)
	g.fill(0)
	return g


func _vi(x: int, y: int) -> int:
	return y * _vw + x


func _vget(g: PackedByteArray, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= _vw or y >= _vh:
		return 0
	return g[_vi(x, y)]


func _mask(g: PackedByteArray, cx: int, cy: int) -> int:
	return (_vget(g, cx, cy) * 1) | (_vget(g, cx + 1, cy) * 2) | (_vget(g, cx, cy + 1) * 4) | (_vget(g, cx + 1, cy + 1) * 8)


func _blob(c: Vector2, r: Vector2, p: Vector2, wobble: float) -> bool:
	var d := Vector2((p.x - c.x) / r.x, (p.y - c.y) / r.y).length_squared()
	return d < 1.0 + _noise.get_noise_2d(p.x * 1.7, p.y * 1.7) * wobble


## Lobed, low-frequency blob for ponds and bare patches.
func _blob2(c: Vector2, r: Vector2, p: Vector2, wobble: float) -> bool:
	var d := Vector2((p.x - c.x) / r.x, (p.y - c.y) / r.y).length_squared()
	return d < 1.0 + _noise2.get_noise_2d(p.x * 2.0 + c.x * 5.0, p.y * 2.0) * wobble


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _trail_dist(p: Vector2) -> float:
	var best := 999.0
	for tr in _trails_v:
		var pts: Array = tr["p"]
		for i in range(pts.size() - 1):
			best = minf(best, _seg_dist(p, pts[i], pts[i + 1]) - float(tr["w"]))
	return best


## Vertex (corner) clearance from every spawn slot cell, in Chebyshev cells.
func _slot_cheb(p: Vector2) -> float:
	var best := 999.0
	for c in _clear_v:
		var cc := Vector2(c.x + 0.5, c.y + 0.5)
		best = minf(best, maxf(absf(p.x - cc.x), absf(p.y - cc.y)))
	return best


func _layout_vertices() -> void:
	if _arena:
		_layout_arena_vertices()
		return
	for y in range(1, _vh - 1):
		for x in range(1, _vw - 1):
			var p := Vector2(x, y)
			var i := _vi(x, y)
			# woodland floor
			for w in WOODS:
				if _blob(w["c"], w["r"] + Vector2(1.2, 1.2), p, 0.45):
					_forest[i] = 1
			# trails (+ meander noise so they are not ruler-straight)
			var wob := _noise2.get_noise_2d(x * 2.0, y * 2.0) * 0.12
			if _trail_dist(p) + wob < 0.0:
				_path[i] = 1
			# safe-zone pad and crossroads
			if p.distance_to(Vector2(60.5, 38.5)) < 3.4 + _noise.get_noise_2d(x * 3.0, y * 3.0) * 0.5:
				_path[i] = 1
			if p.distance_to(Vector2(36.5, 23.5)) < 2.2:
				_path[i] = 1
			# dirt: den yard + scattered bare patches
			if _blob2(Vector2(8.5, 10.5), Vector2(4.8, 4.2), p, 0.5):
				_dirt[i] = 1
			# camp yard (southwest)
			if _blob2(Vector2(CAMP_CELL.x + 0.5, CAMP_CELL.y + 0.5), Vector2(5.2, 3.4), p, 0.35):
				_dirt[i] = 1
			for dc in [Vector2(23, 9), Vector2(47.5, 22.5), Vector2(5.5, 33.5)]:
				if _blob2(dc, Vector2(2.4, 1.8), p, 0.6):
					_dirt[i] = 1
			# ponds, never near spawn slots, trails, or the wall
			for pd in PONDS:
				if _blob2(pd["c"], pd["r"], p, 0.45):
					if _slot_cheb(p) >= 3.5 and _trail_dist(p) > 1.2 and x >= 4 and y >= 4 and x <= _vw - 5 and y <= _vh - 5:
						_water[i] = 1
	# no single-vertex specks of water (they read as puddles)
	for y in range(1, _vh - 1):
		for x in range(1, _vw - 1):
			if _water[_vi(x, y)] == 1:
				var n := _water[_vi(x - 1, y)] + _water[_vi(x + 1, y)] + _water[_vi(x, y - 1)] + _water[_vi(x, y + 1)]
				if n == 0:
					_water[_vi(x, y)] = 0


func _woods_at(cell: Vector2i) -> int:
	var p := Vector2(cell.x + 0.5, cell.y + 0.5)
	for i in _woods_v.size():
		if _blob(_woods_v[i]["c"], _woods_v[i]["r"], p, 0.35):
			return i
	return -1


func _cell_has(g: PackedByteArray, c: Vector2i) -> bool:
	return _mask(g, c.x, c.y) != 0


func _near(g: PackedByteArray, c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if _cell_has(g, Vector2i(c.x + dx, c.y + dy)):
				return true
	return false


func _in_clearing(cell: Vector2i, radius: int) -> bool:
	for c in _clear_v:
		var dx: int = cell.x - c.x
		var dy: int = cell.y - c.y
		if dx * dx + dy * dy <= radius * radius:
			return true
	return false


## Build 010: camp footprint (tents, fire, pennant) — no props of any kind.
func _in_camp(c: Vector2i) -> bool:
	if _arena:
		return false
	var dx := float(c.x - CAMP_CELL.x) / 6.0
	var dy := float(c.y - CAMP_CELL.y) / 4.2
	return dx * dx + dy * dy <= 1.0


func _is_wall(c: Vector2i) -> bool:
	return c.x == 0 or c.y == 0 or c.x == map_width - 1 or c.y == map_height - 1


# ------------------------------------------------------------------ layers

func _paint_ground(origin: Vector2i) -> void:
	for y in range(map_height):
		for x in range(map_width):
			var c := Vector2i(x, y)
			if _is_wall(c):
				var m := 0
				if y > 0 and _is_wall(Vector2i(x, y - 1)) and (x == 0 or x == map_width - 1): m |= 1
				if y < map_height - 1 and _is_wall(Vector2i(x, y + 1)) and (x == 0 or x == map_width - 1): m |= 4
				if x > 0 and _is_wall(Vector2i(x - 1, y)) and (y == 0 or y == map_height - 1): m |= 8
				if x < map_width - 1 and _is_wall(Vector2i(x + 1, y)) and (y == 0 or y == map_height - 1): m |= 2
				set_cell(origin + c, SRC_GROUND, Vector2i(m, WALL_ROW))
				_blocked[c] = true
				continue
			var h := _hash(x, y)
			var meadow := _noise2.get_noise_2d(x * 1.3 + 40.0, y * 1.3)
			var idx: int
			if h % 100 < 62:
				idx = GRASS_PLAIN[h % GRASS_PLAIN.size()]
			elif h % 100 < 80:
				idx = GRASS_TUFT[(h / 7) % GRASS_TUFT.size()]
			elif meadow > 0.1 or h % 100 < 86:
				idx = GRASS_FLOWER[(h / 11) % GRASS_FLOWER.size()]
			else:
				idx = GRASS_MISC[(h / 13) % GRASS_MISC.size()]
			set_cell(origin + c, SRC_GROUND, Vector2i(idx % 16, idx / 16))


func _hash(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ (map_seed * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _paint_overlay(layer: TileMapLayer, g: PackedByteArray, src: int, origin: Vector2i) -> void:
	if layer == null:
		return
	for y in range(1, map_height - 1):
		for x in range(1, map_width - 1):
			var m := _mask(g, x, y)
			if m == 0:
				continue
			var atlas := Vector2i(m, 0)
			if m == 15:
				var h := _hash(x + 101, y + 7) % 10
				atlas = Vector2i(15, 0) if h < 4 else Vector2i(h % 4, 1)
			layer.set_cell(origin + Vector2i(x, y), src, atlas)


func _paint_water(layer: TileMapLayer, origin: Vector2i) -> void:
	if layer == null:
		return
	for y in range(1, map_height - 1):
		for x in range(1, map_width - 1):
			var m := _mask(_water, x, y)
			if m == 0:
				continue
			var atlas := Vector2i((m % 4) * 4, m / 4)
			if m == 15:
				var h := _hash(x + 3, y + 911) % 4
				if h > 0:
					atlas = Vector2i((h - 1) * 4, 4)
			layer.set_cell(origin + Vector2i(x, y), SRC_WATER, atlas)
			_blocked[Vector2i(x, y)] = true


## Footprint check for a prop anchored at cell c with width w (cells).
func _free(c: Vector2i, w: int, clear_r: int, blocking: bool) -> bool:
	for dx in range(w):
		var k := Vector2i(c.x + dx, c.y)
		if not is_interior_local(k, 1):
			return false
		if _occupied.has(k) or _cell_has(_water, k) or _cell_has(_path, k):
			return false
		if _in_camp(k):
			return false
		if blocking:
			if _near(_water, k, 1) or _near(_path, k, 1):
				return false
			if _in_clearing(k, clear_r):
				return false
			# keep a 1-cell walkable ring around every blocking prop
			for dy in range(-1, 2):
				for ex in range(-1, 2):
					if _blocked.has(Vector2i(k.x + ex, k.y + dy)) and not _is_wall(Vector2i(k.x + ex, k.y + dy)):
						return false
	return true


func _put(layer: TileMapLayer, origin: Vector2i, c: Vector2i, atlas: Vector2i, w: int, blocking: bool) -> void:
	layer.set_cell(origin + c, SRC_PROPS, atlas)
	for dx in range(w):
		_occupied[Vector2i(c.x + dx, c.y)] = true
		if blocking:
			_blocked[Vector2i(c.x + dx, c.y)] = true


func _paint_props(layer: TileMapLayer, origin: Vector2i) -> void:
	if layer == null:
		return
	# --- woodland trees (Poisson-ish: trunks keep >= 2 cells apart)
	var cand: Array[Vector2i] = []
	for y in range(2, map_height - 2):
		for x in range(2, map_width - 2):
			cand.append(Vector2i(x, y))
	_shuffle(cand)
	for c in cand:
		var wi := _woods_at(c)
		if wi < 0:
			continue
		if not _tree_spacing_ok(c, 2.2):
			continue
		if not _free(c, 1, 4, true):
			continue
		if _near(_path, c, 1):
			continue
		_put(layer, origin, c, _pick_tree(_woods_v[wi]["mix"]), 1, true)
		_trunks.append(c)
	if _arena:
		_paint_arena_props(layer, origin, cand)
		return
	# --- lone meadow trees
	var lone := 0
	for c in cand:
		if lone >= 14:
			break
		if _woods_at(c) >= 0 or _cell_has(_forest, c):
			continue
		if _hash(c.x, c.y) % 23 != 0:
			continue
		if not _tree_spacing_ok(c, 6.0) or not _free(c, 1, 5, true) or _near(_dirt, c, 1):
			continue
		_put(layer, origin, c, OAKS[_hash(c.y, c.x) % 3] if _hash(c.x, 5) % 3 else OAK_FRUIT, 1, true)
		_trunks.append(c)
		lone += 1
	# --- ranch decor around the den (top-left) — short runs with open ends
	_fence_h(layer, origin, 3, 16, 6)
	_fence_v(layer, origin, 15, 3, 4)
	for c in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 5)]:
		if _free(c, 1, 3, true):
			_put(layer, origin, c, HAY, 1, true)
	if _free(Vector2i(12, 13), 2, 3, true):
		_put(layer, origin, Vector2i(12, 13), TROUGH, 2, true)
	for c in [Vector2i(16, 12), Vector2i(56, 34)]:
		if _free(c, 1, 3, true):
			_put(layer, origin, c, SIGN, 1, true)
	# --- rocks, logs, stumps
	var rock_n := 0
	var wood_n := 0
	var boulder_n := 0
	for c in cand:
		var wi := _woods_at(c)
		var h := _hash(c.x * 3, c.y * 5) % 100
		if wi >= 0:
			if h < 6 and wood_n < 14 and _free(c, 2, 4, true) and _free(Vector2i(c.x, c.y), 2, 4, true):
				_put(layer, origin, c, LOG if h < 3 else STUMP, 2 if h < 3 else 1, true)
				wood_n += 1
			elif h < 10 and rock_n < 26 and _free(c, 1, 4, true):
				_put(layer, origin, c, ROCKS[h % 3], 1, true)
				rock_n += 1
		else:
			if h < 1 and boulder_n < 4 and not _cell_has(_forest, c) and _free(c, 2, 5, true) \
					and _free(Vector2i(c.x, c.y - 1), 2, 5, true):
				_put(layer, origin, c, BOULDER, 2, true)
				_occupied[Vector2i(c.x, c.y - 1)] = true
				_occupied[Vector2i(c.x + 1, c.y - 1)] = true
				boulder_n += 1
			elif h < 3 and rock_n < 40 and _free(c, 1, 4, true):
				_put(layer, origin, c, ROCKS[h % 3], 1, true)
				rock_n += 1
	# shore stones/rocks next to ponds (walkable side only)
	# --- bushes (no collision): woodland fringe + meadow scatter
	for c in cand:
		if _occupied.has(c) or _cell_has(_path, c) or _cell_has(_water, c) or _in_clearing(c, 2) or _in_camp(c):
			continue
		if not is_interior_local(c, 1):
			continue
		var fringe := _cell_has(_forest, c) and _woods_at(c) < 0
		var inwood := _woods_at(c) >= 0
		var h := _hash(c.x + 17, c.y * 3) % 100
		if (fringe and h < 30) or (inwood and h < 9) or (not fringe and not inwood and h < 2):
			if h < 3 and _free(c, 2, 2, false) and not _occupied.has(Vector2i(c.x, c.y - 1)) and not _occupied.has(Vector2i(c.x + 1, c.y - 1)):
				_put(layer, origin, c, BUSH_BIG, 2, false)
			else:
				_put(layer, origin, c, BUSHES[h % 4], 1, false)


func _pick_tree(mix: String) -> Vector2i:
	var r := _rng.randi_range(0, 99)
	match mix:
		"oak_pine":
			return PINE if r < 40 else OAKS[r % 3]
		"oak_birch":
			return BIRCH if r < 30 else OAKS[r % 2]
		"oak_fruit":
			return OAK_FRUIT if r < 22 else (BIRCH if r < 32 else OAKS[r % 3])
		"pine":
			return PINE if r < 80 else OAKS[1]
	return OAKS[0]


func _tree_spacing_ok(c: Vector2i, d: float) -> bool:
	for t in _trunks:
		if Vector2(t - c).length() < d:
			return false
	return true


func _fence_h(layer: TileMapLayer, origin: Vector2i, x0: int, y: int, n: int) -> void:
	for i in n:
		var c := Vector2i(x0 + i, y)
		var a := FENCE_M
		if i == 0: a = FENCE_L
		elif i == n - 1: a = FENCE_R
		_put(layer, origin, c, a, 1, true)


func _fence_v(layer: TileMapLayer, origin: Vector2i, x: int, y0: int, n: int) -> void:
	for i in n:
		_put(layer, origin, Vector2i(x, y0 + i), FENCE_V, 1, true)


func _shuffle(a: Array[Vector2i]) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t


func _paint_details(layer: TileMapLayer, origin: Vector2i) -> void:
	if layer == null:
		return
	for y in range(1, map_height - 1):
		for x in range(1, map_width - 1):
			var c := Vector2i(x, y)
			if _occupied.has(c):
				continue
			var h := _hash(x * 7 + 3, y * 11 + 5) % 1000
			var wm := _mask(_water, x, y)
			if wm == 15:
				if h < 120 and _mask(_water, x - 1, y) == 15 and _mask(_water, x + 1, y) == 15:
					layer.set_cell(origin + c, SRC_DETAIL, D_LILY[h % 3])
				continue
			if wm != 0:
				if h < 420:
					layer.set_cell(origin + c, SRC_DETAIL, D_REEDS[h % 2] if h < 340 else D_SHORE_STONES)
				continue
			if _cell_has(_path, c):
				if h < 40:
					layer.set_cell(origin + c, SRC_DETAIL, D_PEBBLES)
				continue
			if _cell_has(_dirt, c):
				if _arena:
					layer.set_cell(origin + c, SRC_DETAIL, D_FLOWERS[h % 4])
					continue
				if h < 60:
					layer.set_cell(origin + c, SRC_DETAIL, D_PEBBLES)
				continue
			if _mask(_forest, x, y) == 15:
				if h < 330:
					layer.set_cell(origin + c, SRC_DETAIL, D_FOREST[h % D_FOREST.size()])
				continue
			var meadow := _noise2.get_noise_2d(x * 1.3 + 40.0, y * 1.3)
			if meadow > 0.18 and h < 260:
				layer.set_cell(origin + c, SRC_DETAIL, D_FLOWERS[(h + int(meadow * 9.0)) % 4])
			elif h < 70:
				layer.set_cell(origin + c, SRC_DETAIL, D_TUFTS[h % 3])


## Soft, low-frequency light and shade so the grass never reads as a grid:
## one pixel per cell, linear-filtered, multiplied over the ground layers.
func _paint_tint(origin: Vector2i) -> void:
	var spr := get_parent().get_node_or_null("Tint") as Sprite2D
	if spr == null:
		return
	var img := Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	var warm := Color(1.0, 1.0, 0.96)
	var cool := Color(0.84, 0.9, 0.86)
	for y in range(map_height):
		for x in range(map_width):
			var n := (_noise2.get_noise_2d(x * 0.9 - 30.0, y * 0.9 + 12.0) + 1.0) * 0.5
			var col := cool.lerp(warm, smoothstep(0.25, 0.75, n))
			var f := float(_mask(_forest, x, y)) / 15.0
			if _mask(_forest, x, y) == 15:
				f = 1.0
			col = col.lerp(Color(0.78, 0.84, 0.82), f * 0.8)
			if _arena and f < 0.5:
				# Build 015: mown-lawn stripes on the Parliament lawn
				col = col * (1.0 if (x / 2) % 2 == 0 else 0.9)
				col.a = 1.0
			img.set_pixel(x, y, col)
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.scale = Vector2(tile_set.tile_size)
	spr.position = map_to_local(origin) - Vector2(tile_set.tile_size) * 0.5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	spr.material = mat


func _apply_camera_limits() -> void:
	var cam := get_parent().get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		return
	var tl := to_global(map_to_local(get_map_origin()) - Vector2(tile_set.tile_size) * 0.5)
	var br := tl + Vector2(map_width, map_height) * Vector2(tile_set.tile_size)
	cam.limit_left = int(tl.x)
	cam.limit_top = int(tl.y)
	cam.limit_right = int(br.x)
	cam.limit_bottom = int(br.y)


# ------------------------------------------------------------------ build 015 boss arena

## Parliament-lawn clearing for the Trustin Judeau fight (42x28 cells): mown
## lawn, an oval promenade, tree groves in the corners, flower beds, and a
## clear cell band at the top for the Parliament building (placed by
## boss_level.gd). The fighting area in the middle has no blocking props.
const ARENA_WOODS := [
	{"c": Vector2(4.0, 4.0), "r": Vector2(5.0, 4.0), "mix": "oak_pine"},
	{"c": Vector2(38.0, 4.0), "r": Vector2(5.0, 4.0), "mix": "oak_pine"},
	{"c": Vector2(3.0, 25.0), "r": Vector2(4.0, 3.0), "mix": "oak_birch"},
	{"c": Vector2(39.0, 25.0), "r": Vector2(4.0, 3.0), "mix": "oak_birch"},
	{"c": Vector2(1.5, 15.0), "r": Vector2(1.6, 5.0), "mix": "pine"},
	{"c": Vector2(40.5, 15.0), "r": Vector2(1.6, 5.0), "mix": "pine"},
]
const ARENA_CLEARINGS: Array[Vector2i] = [
	Vector2i(16, 4), Vector2i(21, 4), Vector2i(26, 4),   # Parliament building
	Vector2i(21, 11),   # boss start
	Vector2i(21, 16),   # centre
	Vector2i(21, 22),   # player start
	Vector2i(10, 16), Vector2i(32, 16),
]


func paint_boss_arena() -> void:
	_arena = true
	_woods_v = ARENA_WOODS
	_ponds_v = []
	_clear_v = ARENA_CLEARINGS
	var ring: Array = []
	for i in 21:
		var a := float(i) / 20.0 * TAU
		ring.append(Vector2(21.0 + cos(a) * 13.5, 16.0 + sin(a) * 7.5))
	_trails_v = [
		{"w": 0.75, "p": ring},
		{"w": 0.9, "p": [Vector2(21.0, 7.2), Vector2(21.0, 8.6)]},
		{"w": 0.6, "p": [Vector2(21.0, 23.5), Vector2(21.0, 27.0)]},
	]
	paint_level01()


func _layout_arena_vertices() -> void:
	for y in range(1, _vh - 1):
		for x in range(1, _vw - 1):
			var p := Vector2(x, y)
			var i := _vi(x, y)
			for w in _woods_v:
				if _blob(w["c"], w["r"] + Vector2(1.0, 1.0), p, 0.4):
					_forest[i] = 1
			var wob := _noise2.get_noise_2d(x * 2.0, y * 2.0) * 0.1
			if _trail_dist(p) + wob < 0.0:
				_path[i] = 1
			# forecourt in front of the building
			if absf(p.x - 21.0) < 6.5 and p.y > 6.0 and p.y < 8.6:
				_path[i] = 1
			# flower beds: two round beds left/right of the centre (dirt + flowers)
			for bc in [Vector2(12.0, 16.0), Vector2(30.0, 16.0)]:
				if p.distance_to(bc) < 1.9:
					_dirt[i] = 1


func _paint_arena_props(layer: TileMapLayer, origin: Vector2i, cand: Array[Vector2i]) -> void:
	# bushes on the woodland fringe only; the lawn stays open for dodging
	for c in cand:
		if _occupied.has(c) or _cell_has(_path, c) or _in_clearing(c, 3):
			continue
		if not is_interior_local(c, 1):
			continue
		var fringe := _cell_has(_forest, c) and _woods_at(c) < 0
		var h := _hash(c.x + 17, c.y * 3) % 100
		if fringe and h < 35:
			_put(layer, origin, c, BUSHES[h % 4], 1, false)
	# hedge-row fence posts along the bottom
	for x in [8, 9, 10, 31, 32, 33]:
		var c := Vector2i(x, 26)
		if _free(c, 1, 2, false):
			_put(layer, origin, c, FENCE_M if x != 8 and x != 31 else FENCE_L, 1, false)
