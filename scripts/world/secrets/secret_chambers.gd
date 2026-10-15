class_name SecretChambers
extends Node2D
## Build 024: hidden chambers in the regular levels. A small sealed pocket of
## rocks and brush with ONE breakable door tile; break it (whip / fire whip /
## shockwave) and the pocket opens on a treasure that can be claimed once per run.
##
## Modular on purpose (hook for a future RPG spinoff):
##   * plan(ground, level)  -> Array[Dictionary] pure data, no nodes; deterministic
##   * build(level, ground)  -> paints the walls, adds collision, door and reward
##   * a chamber spec is plain data:
##       {id, rect: Rect2i, door: Vector2i, out: Vector2i, pocket: Array[Vector2i],
##        walls: Array[Vector2i], subtle: bool, reward: String, theme: String}
##   * SecretDoor / SecretReward are self-contained nodes; the only coupling to the
##     level is LevelController.grant_secret_reward(kind, pos) and
##     GameProgress.claim_secret(id).

signal opened(spec: Dictionary)
signal claimed(spec: Dictionary)

const W := 5                 ## chamber footprint incl. walls (cells)
const H := 4
const CLEAR_MARGIN := 1      ## free ring kept around the footprint (pathing)
const MIN_FROM_CLEARING := 4 ## cells from any spawn slot / den
const MIN_FROM_SAFE := 9     ## safe zone / camp + their Cantifa post rings
const MIN_APART := 14
const EDGE_MARGIN := 5       ## Cantifa / humans enter at the edges
const PROP_ROCKS: Array[Vector2i] = [Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4)]
const PROP_BUSHES: Array[Vector2i] = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
const SRC_PROPS := 5
## reward table: kind -> weight
const REWARDS := {"score": 30, "heart": 22, "fire_whip": 12, "shockwave": 12, "long_whip": 10, "invincible": 8, "whip_shot": 6}

var specs: Array = []
var doors: Array = []
var level_no := 1


static func enabled_for(level_node: Node) -> bool:
	if level_node == null or level_node.is_in_group("bonus_level") or level_node.is_in_group("boss_level"):
		return false
	return true


## 1-2 chambers: odd levels 1, even levels 2 (L1 keeps one, near the woods).
static func count_for(level: int) -> int:
	return 1 if level % 2 == 1 else 2


static func _rect_cells(r: Rect2i) -> Array:
	var out: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


static func _footprint_ok(g, r: Rect2i, avoid: Array) -> bool:
	# footprint: no blocking prop, water or trail; the 1-cell ring around it
	# only has to stay walkable (so humans / sheep can always walk around)
	var big := r.grow(CLEAR_MARGIN)
	for c in _rect_cells(big):
		if not g.is_interior_local(c, EDGE_MARGIN - 1):
			return false
		if g._blocked.has(c) or g._cell_has(g._water, c):
			return false
		if r.has_point(c) and g._cell_has(g._path, c):
			return false
	var mid := Vector2(r.get_center())
	for k in g.CLEARINGS:
		var lim := MIN_FROM_SAFE if (k == g.CLEARINGS[0] or k == g.CAMP_CELL) else MIN_FROM_CLEARING
		if mid.distance_to(Vector2(k)) < lim + W * 0.5:
			return false
	for a in avoid:
		if mid.distance_to(Vector2((a as Rect2i).get_center())) < MIN_APART:
			return false
	return true


## Door on the side facing the most open ground (so it is visible and reachable).
static func _pick_door(g, r: Rect2i) -> Dictionary:
	var best := {}
	var best_open := -1
	var opts := [
		[Vector2i(r.position.x + W / 2, r.end.y - 1), Vector2i(0, 1)],
		[Vector2i(r.position.x + W / 2, r.position.y), Vector2i(0, -1)],
		[Vector2i(r.position.x, r.position.y + H / 2), Vector2i(-1, 0)],
		[Vector2i(r.end.x - 1, r.position.y + H / 2), Vector2i(1, 0)],
	]
	for o in opts:
		var d: Vector2i = o[0]
		var n: Vector2i = o[1]
		var open := 0
		for k in range(1, 5):
			var c := d + n * k
			if not g._blocked.has(c) and not g._cell_has(g._water, c):
				open += 1
		if open > best_open:
			best_open = open
			best = {"door": d, "out": d + n}
	return best


## Pure planning: no nodes, no side effects. Same level -> same chambers.
static func plan(g, level: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g.map_seed) * 31 + level * 977 + 24
	var cands: Array = []
	for y in range(EDGE_MARGIN, g.map_height - EDGE_MARGIN - H):
		for x in range(EDGE_MARGIN, g.map_width - EDGE_MARGIN - W):
			var r := Rect2i(x, y, W, H)
			if not _footprint_ok(g, r, []):
				continue
			# fit the biome: tucked against woods / forest floor scores higher
			var near := 0
			for c in _rect_cells(r.grow(3)):
				if g._blocked.has(c) or g._cell_has(g._forest, c):
					near += 1
			cands.append([near + rng.randi_range(0, 6), r])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var chosen: Array = []
	var out: Array = []
	var n := count_for(level)
	for cd in cands:
		if out.size() >= n:
			break
		var r: Rect2i = cd[1]
		if not _footprint_ok(g, r, chosen):
			continue
		chosen.append(r)
		var dd := _pick_door(g, r)
		var pocket: Array = _rect_cells(Rect2i(r.position + Vector2i.ONE, Vector2i(W - 2, H - 2)))
		var walls: Array = []
		for c in _rect_cells(r):
			if not pocket.has(c) and c != dd["door"]:
				walls.append(c)
		# mix: on 2-chamber levels one is marked, one is not; 1-chamber levels alternate
		var subtle: bool = (out.size() == 0) if n == 2 else ((level / 2) % 2 == 0)
		out.append({
			"id": "L%d#%d" % [level, out.size()], "rect": r, "door": dd["door"], "out": dd["out"],
			"pocket": pocket, "walls": walls, "subtle": subtle, "reward": _roll(rng),
			"theme": String(g.theme),
		})
	return out


static func _roll(rng: RandomNumberGenerator) -> String:
	var tot := 0
	for k in REWARDS: tot += int(REWARDS[k])
	var x := rng.randi_range(0, tot - 1)
	for k in REWARDS:
		x -= int(REWARDS[k])
		if x < 0:
			return k
	return "score"


## Paints + builds every chamber for this level. Returns the SecretChambers node
## (or null when the level has none / is a boss or bonus stage).
static func build(level_node: Node, g) -> SecretChambers:
	if not enabled_for(level_node) or g == null or not ("_blocked" in g) or g._arena:
		return null
	var lv: int = int(level_node.level_number) if "level_number" in level_node else 1
	var sp := plan(g, lv)
	if sp.is_empty():
		return null
	var node := SecretChambers.new()
	node.name = "SecretChambers"
	node.y_sort_enabled = true   # doors sort with props / actors in the y-sorted Entities
	node.level_no = lv
	node.specs = sp
	var ent: Node = level_node.get_node_or_null("Entities")
	(ent if ent != null else level_node).add_child(node)
	for s in sp:
		node._build_one(level_node, g, s)
	return node


func _build_one(level_node: Node, g, s: Dictionary) -> void:
	var props := _find_layer(g, "Props")
	var detail := _find_layer(g, "Detail")
	var origin: Vector2i = g.get_map_origin()
	var rocky: bool = String(s["theme"]) in ["med", "texas", "norcal"]
	# walls: full-cell collision (no squeezing between rocks) + natural looking props
	var body := StaticBody2D.new()
	body.name = "Walls_" + String(s["id"]).replace("#", "_")
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var i := 0
	for c in s["walls"]:
		var cell: Vector2i = c
		g._blocked[cell] = true
		g._occupied[cell] = true
		if detail != null: detail.erase_cell(origin + cell)
		var h := (cell.x * 73856093) ^ (cell.y * 19349663)
		var rock := rocky or i % 2 == 0
		if props != null:
			props.set_cell(origin + cell, SRC_PROPS, PROP_ROCKS[absi(h) % 3] if rock else PROP_BUSHES[absi(h) % 4])
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(32, 32)
		cs.shape = rs
		cs.position = g.to_global(g.tile_center(cell))
		body.add_child(cs)
		i += 1
	for c in s["pocket"]:
		if detail != null: detail.erase_cell(origin + c)
	# door: clear any map prop / detail painted on the door cell (the door node draws it)
	if props != null: props.erase_cell(origin + s["door"])
	if detail != null: detail.erase_cell(origin + s["door"])
	var door := SecretDoor.new()
	door.spec = s
	door.ground = g
	door.atlas = PROP_ROCKS[1]
	door.position = g.to_global(g.tile_center(s["door"]))
	door.broken.connect(_on_door_broken.bind(level_node, g, s))
	add_child(door)
	doors.append(door)
	g._blocked[s["door"]] = true
	g._occupied[s["door"]] = true


## Look up a sibling TileMapLayer WITHOUT clearing it (the painter's own
## _layer() helper clears the layer for a fresh paint - never call it here).
static func _find_layer(g, layer_name: String) -> TileMapLayer:
	var par: Node = g.get_parent()
	var l := par.get_node_or_null(layer_name) as TileMapLayer
	if l == null:
		l = par.get_node_or_null("Entities/" + layer_name) as TileMapLayer
	return l


func _on_door_broken(level_node: Node, g, s: Dictionary) -> void:
	g._blocked.erase(s["door"])
	opened.emit(s)
	var center := Vector2.ZERO
	for c in s["pocket"]:
		center += g.to_global(g.tile_center(c))
	center /= float(s["pocket"].size())
	var gp := get_node_or_null("/root/GameProgress")
	var already: bool = gp != null and gp.has_method("secret_claimed") and gp.secret_claimed(String(s["id"]))
	# build 025: HUD toast (clear of the score/SAVED cards, mobile too)
	var hud = level_node.get("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.show_toast("SECRET FOUND!" if not already else "ALREADY LOOTED")
	elif level_node.has_method("spawn_score_popup"):
		level_node.spawn_score_popup("SECRET FOUND!" if not already else "ALREADY LOOTED", center + Vector2(0, -40), Color(1.0, 0.9, 0.4), 3)
	Sfx.play(self, "secret_reveal", -4.0)
	add_child(RevealFx.make(center))
	if already:
		return
	var rw := SecretReward.new()
	rw.kind = String(s["reward"])
	rw.spec = s
	rw.position = center
	rw.taken.connect(func(k): claimed.emit(s))
	add_child(rw)


## Reveal sparkle: expanding gold ring + rays + rising motes (drawn, no assets).
class RevealFx extends Node2D:
	var t := 0.0
	static func make(at: Vector2) -> Node2D:
		var f := RevealFx.new()
		f.position = at
		f.z_index = 6
		return f
	func _process(d: float) -> void:
		t += d
		if t > 1.2:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var u := t / 1.2
		var a := 1.0 - u
		draw_arc(Vector2.ZERO, 12.0 + u * 70.0, 0, TAU, 32, Color(1, 0.9, 0.4, a), 4.0 * a + 1.0)
		for k in 10:
			var dir := Vector2.from_angle(TAU * k / 10.0 + u * 1.5)
			draw_line(dir * (10.0 + u * 30.0), dir * (24.0 + u * 64.0), Color(1, 1, 0.75, a * 0.9), 2.0)
		for k in 8:
			var p := Vector2(sin(k * 2.1) * 26.0, -u * 60.0 - k * 4.0)
			draw_rect(Rect2(p, Vector2(3, 3)), Color(1, 0.95, 0.6, a))
