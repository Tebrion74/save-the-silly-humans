class_name Reticle
extends Node2D
## Build 014b aim reticle. Lives in its own CanvasLayer (LevelConfig.RETICLE_LAYER,
## under the HUD and the touch wedges), so it draws in screen space and never
## takes input (Node2D, no Control, no _input handlers).
##
## PC (mouse): the OS pointer is hidden over the game while a round is being
##   played (Input.MOUSE_MODE_HIDDEN) and this reticle is drawn at the mouse.
##   The pointer comes back as soon as the round ends (end panel buttons), the
##   rancher dies, the level changes, or the game returns to the title screen.
## Touch: a crosshair at the current weapon's reach along the rancher's 8-way
##   facing (the same aim the whip and cam use), snapped onto the whip's
##   aim-assist target when there is one, i.e. exactly where the crack lands.
##
## Colour rules (evaluate()):
##   WHIP  green when the crack would land on a sheep / possessed human / Karen.
##         It uses the whip's own target resolution (find_target on PC,
##         find_assist_target + find_target on touch), so green == a sure hit.
##         PC: the reticle must also be within reach (+RETICLE_SNAP_RADIUS);
##         past reach it stays red and a faint dot marks max reach on the aim line.
##         A silly human under the whip (herding) does not count: red.
##   CAM   "simple rule": green when the cam can film (battery or a spare) and
##         any filmable target (silly human or Karen) is inside the 39 degree /
##         420 px cone along the current aim. The nearest one to the aim line
##         gets the lock-on brackets.

var player: Node2D
var level: Node
## Debug/screenshots only: keep the touch crosshair at full brightness.
var debug_bright := false

var active := false
var info: Dictionary = {}
var _hidden_pointer := false
var _mouse_inside := true
var _touch_hold := 0.0
var _pulse := 0.0
var _t := 0.0
var _last_crack := -1.0
var _last_grab := -1.0
var _last_swing := -1.0


func _ready() -> void:
	var win := get_window()
	if win != null:
		win.mouse_entered.connect(_on_mouse_entered)
		win.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	_mouse_inside = true


func _on_mouse_exited() -> void:
	_mouse_inside = false


func _exit_tree() -> void:
	_set_pointer_hidden(false)
	var win := get_window()
	if win != null and win.mouse_entered.is_connected(_on_mouse_entered):
		win.mouse_entered.disconnect(_on_mouse_entered)
		win.mouse_exited.disconnect(_on_mouse_exited)


func _set_pointer_hidden(h: bool) -> void:
	if h == _hidden_pointer:
		return
	_hidden_pointer = h
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if h else Input.MOUSE_MODE_VISIBLE


## True while a round is actually being played (not before setup, not after
## win / loss, not while the level is changing, not when the rancher is dead).
func gameplay_active() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if "_dead" in player and player._dead:
		return false
	if level != null and is_instance_valid(level):
		if "_ended" in level and level._ended:
			return false
		if "_transitioning" in level and level._transitioning:
			return false
		if "state" in level and level.state != null:
			if not level.state.setup_complete or level.state.is_over():
				return false
	return true


func _process(delta: float) -> void:
	_t += delta
	active = gameplay_active()
	var touch: bool = TouchInput.active
	_set_pointer_hidden(active and not touch and _mouse_inside)
	if not active or (not touch and not _mouse_inside):
		info = {}
		queue_redraw()
		return
	var mouse_world := player.get_global_mouse_position()
	info = evaluate(touch, mouse_world)
	_update_feedback(delta, touch)
	queue_redraw()


func _whip() -> Node:
	return player.get_node_or_null("Whip") if player != null else null


func _cam() -> MsmCam:
	if player == null:
		return null
	for c in player.get_children():
		if c is MsmCam:
			return c
	return null


func current_weapon() -> String:
	var w: Node = player.get_node_or_null("Weapons") if player != null else null
	return w.current_id() if w != null and w.has_method("current_id") else "whip"


func _facing() -> Vector2:
	var f: Vector2 = player.facing if "facing" in player else Vector2.RIGHT
	return f.normalized() if f.length_squared() > 0.0001 else Vector2.RIGHT


## Pure logic (also used by the tests). Returns:
##   pos (world), green (bool), target (Node2D or null), reach_pos (world or
##   null: PC max-reach marker), weapon ("whip"/"cam"), dir, reach, origin.
func evaluate(touch: bool, mouse_world: Vector2) -> Dictionary:
	if current_weapon() == "cam" and _cam() != null:
		return _eval_cam(touch, mouse_world)
	return _eval_whip(touch, mouse_world)


static func is_whip_target(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if "exploding" in n and n.exploding:
		return false
	if n.is_in_group("sheep") or n.is_in_group("boss") or n.is_in_group("cantifa"):
		return true
	return "possessed" in n and bool(n.possessed)


func _eval_whip(touch: bool, mouse_world: Vector2) -> Dictionary:
	var whip := _whip()
	var origin := player.global_position
	if whip == null:
		return {"pos": mouse_world, "green": false, "target": null, "reach_pos": null,
			"weapon": "whip", "dir": Vector2.RIGHT, "reach": 0.0, "origin": origin}
	origin = (whip as Node2D).global_position
	var reach: float = whip.whip_range
	if touch:
		# Mirrors Whip.fire_whip on touch: assist cone first, then the ray.
		var dir := _facing()
		var target: Node2D = whip.find_assist_target(origin, dir)
		if target == null:
			target = whip.find_target(origin, origin + dir * 240.0, dir)
		var pos := origin + dir * reach
		if target != null:
			pos = target.global_position
			dir = origin.direction_to(pos) if origin.distance_to(pos) > 1.0 else dir
		return {"pos": pos, "green": is_whip_target(target), "target": target, "reach_pos": null,
			"weapon": "whip", "dir": dir, "reach": reach, "origin": origin}
	var d := origin.direction_to(mouse_world)
	if d.length_squared() < 0.0001:
		d = Vector2.RIGHT
	var in_reach := origin.distance_to(mouse_world) <= reach + LevelConfig.RETICLE_SNAP_RADIUS
	var hit: Node2D = whip.find_target(origin, mouse_world, d)
	var green := in_reach and is_whip_target(hit)
	return {"pos": mouse_world, "green": green, "target": hit if green else null,
		"reach_pos": null if in_reach else origin + d * reach,
		"weapon": "whip", "dir": d, "reach": reach, "origin": origin}


static func filmable_targets(tree: SceneTree) -> Array:
	var out: Array = []
	for h in tree.get_nodes_in_group("humans"):
		if not is_instance_valid(h) or not h is Node2D or h.is_queued_for_deletion():
			continue
		if ("possessed" in h and h.possessed) or ("rescued" in h and h.rescued):
			continue
		out.append(h)
	for k in tree.get_nodes_in_group("karens"):
		if not is_instance_valid(k) or not k is Node2D or k.is_queued_for_deletion():
			continue
		if "exploding" in k and k.exploding:
			continue
		out.append(k)
	# Build 015: the boss loves a camera too.
	for b in tree.get_nodes_in_group("boss"):
		if is_instance_valid(b) and b is Node2D and not ("exploding" in b and b.exploding):
			out.append(b)
	return out


func _eval_cam(touch: bool, mouse_world: Vector2) -> Dictionary:
	var cam := _cam()
	var origin := player.global_position
	var dir: Vector2
	if cam.debug_aim.length_squared() > 0.0001:
		dir = cam.debug_aim.normalized()
	elif touch:
		dir = _facing()
	else:
		dir = origin.direction_to(mouse_world)
		if dir.length_squared() < 0.0001:
			dir = cam.aim_dir
	var reach: float = cam.range_px
	var pu: Node = player.get_node_or_null("PowerUps")
	var can_film: bool = cam.battery > 0.0 or (pu != null and "spare_batteries" in pu and int(pu.spare_batteries) > 0)
	var cos_half := cos(deg_to_rad(LevelConfig.CAM_HALF_ANGLE_DEG))
	var best: Node2D = null
	var best_off := INF
	for t in filmable_targets(get_tree()):
		var to: Vector2 = (t as Node2D).global_position - origin
		var dist := to.length()
		if dist > reach or dist < 4.0:
			continue
		if dir.dot(to / dist) < cos_half:
			continue
		var off := absf(dir.cross(to))
		if off < best_off:
			best_off = off
			best = t
	var green := can_film and best != null
	var pos := origin + dir * reach if touch else mouse_world
	var beyond := (not touch) and origin.distance_to(mouse_world) > reach
	return {"pos": pos, "green": green, "target": best if green else null,
		"reach_pos": origin + dir * reach if beyond else null,
		"weapon": "cam", "dir": dir, "reach": reach, "origin": origin, "can_film": can_film}


func _update_feedback(delta: float, touch: bool) -> void:
	_pulse = maxf(_pulse - delta * 5.0, 0.0)
	var whip := _whip()
	if whip != null:
		var ca: float = whip._crack_age
		var ga: float = whip._grab_age
		if ca >= 0.0 and (_last_crack < 0.0 or ca < _last_crack):
			_pulse = 1.0
		if ga >= 0.0 and (_last_grab < 0.0 or ga < _last_grab):
			_pulse = 1.0
		_last_crack = ca
		_last_grab = ga
	var cam := _cam()
	if cam != null:
		if cam.swing_t >= 0.0 and (_last_swing < 0.0 or cam.swing_t < _last_swing):
			_pulse = 1.0
		_last_swing = cam.swing_t
		if cam.filming:
			_pulse = maxf(_pulse, 0.35 + 0.2 * sin(_t * 9.0))
	if touch:
		var busy: bool = TouchInput.move_vector.length() > 0.05 or TouchInput.whip_held or _pulse > 0.5
		if busy:
			_touch_hold = LevelConfig.RETICLE_TOUCH_HOLD
		else:
			_touch_hold = maxf(_touch_hold - delta, 0.0)


## World -> screen (this node lives in a CanvasLayer with identity transform).
func to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


func _wedges() -> Array:
	var s := get_viewport().get_visible_rect().size
	return [TouchLayout.primary_poly(s), TouchLayout.secondary_poly(s), TouchLayout.swap_poly(s)]


func _blocked(sp: Vector2, pad: float) -> bool:
	var vr := get_viewport().get_visible_rect()
	if not vr.grow(-pad).has_point(sp):
		return true
	for poly in _wedges():
		if TouchLayout.hit(poly, sp, pad):
			return true
	return false


## Touch screen position of the crosshair. The whip crosshair stays exactly on
## the crack point (it just fades if it lands under a wedge / off screen); the
## cam crosshair (far edge of the cone) slides back along the aim line until it
## is on screen and clear of the wedges (never closer than half the range).
func touch_screen_pos() -> Dictionary:
	var sp := to_screen(info["pos"])
	var pad := LevelConfig.RETICLE_RADIUS + LevelConfig.RETICLE_ARM + 2.0
	if info["weapon"] == "cam" and _blocked(sp, pad):
		var o := to_screen(info["origin"])
		var reach: float = info["reach"]
		var r := reach
		while r > reach * 0.5 and _blocked(o + (info["dir"] as Vector2) * r, pad):
			r -= 6.0
		sp = o + (info["dir"] as Vector2) * r
	return {"sp": sp, "under": _blocked(sp, pad)}


func _draw() -> void:
	if info.is_empty():
		return
	var touch: bool = TouchInput.active
	var green: bool = info["green"]
	var col: Color = LevelConfig.RETICLE_GREEN if green else LevelConfig.RETICLE_RED
	var alpha := LevelConfig.RETICLE_ALPHA
	var sp: Vector2
	if touch:
		var tp := touch_screen_pos()
		sp = tp["sp"]
		if not green and not debug_bright:
			var k := clampf(_touch_hold / 0.3, 0.0, 1.0)
			alpha *= lerpf(LevelConfig.RETICLE_TOUCH_IDLE_ALPHA, 1.0, k)
		if tp["under"]:
			alpha *= 0.4
	else:
		sp = get_viewport().get_mouse_position()
	if info["reach_pos"] != null:
		_draw_reach_dot(to_screen(info["reach_pos"]), col, alpha)
	var tgt: Variant = info["target"]
	if green and tgt != null and is_instance_valid(tgt):
		var lock_off := Vector2(0, -48) if (tgt as Node).is_in_group("boss") else Vector2(0, -6)
		var ts := to_screen((tgt as Node2D).global_position + lock_off)
		_draw_lock(ts, col, alpha)
	var c2 := col.lerp(Color(1, 1, 1), 0.35 * _pulse)
	_draw_reticle(sp.round(), 1.0 + LevelConfig.RETICLE_PULSE * _pulse, c2, alpha)


func _draw_reticle(c: Vector2, scale_k: float, col: Color, alpha: float) -> void:
	var r := roundf(LevelConfig.RETICLE_RADIUS * scale_k)
	var arm := roundf(LevelConfig.RETICLE_ARM * scale_k)
	var gap := LevelConfig.RETICLE_GAP
	var th := LevelConfig.RETICLE_THICK
	var out := Color(LevelConfig.RETICLE_OUTLINE, alpha * 0.9)
	var fill := Color(col, alpha)
	var seg := 16
	# Dark outline pass, then colour pass (pixel look: no antialiasing).
	draw_arc(c, r, 0.0, TAU, seg, out, th + 2.0, false)
	var arms := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for a in arms:
		_arm_rect(c, a, r - gap, r + arm, th + 2.0, out)
	draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), out)
	draw_arc(c, r, 0.0, TAU, seg, fill, th, false)
	for a in arms:
		_arm_rect(c, a, r - gap + 1.0, r + arm - 1.0, th, fill)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), fill)


func _arm_rect(c: Vector2, dir: Vector2, from: float, to: float, th: float, col: Color) -> void:
	var a := c + dir * from
	var b := c + dir * to
	var rect := Rect2(a, Vector2.ZERO).expand(b)
	if dir.x != 0.0:
		rect = rect.grow_individual(0, th * 0.5, 0, th * 0.5)
	else:
		rect = rect.grow_individual(th * 0.5, 0, th * 0.5, 0)
	draw_rect(rect, col)


## Four corner brackets around the target the shot would land on.
func _draw_lock(c: Vector2, col: Color, alpha: float) -> void:
	var r := LevelConfig.RETICLE_SNAP_RADIUS * 0.5 + 2.0 + 2.0 * sin(_t * 8.0)
	var l := 5.0
	var out := Color(LevelConfig.RETICLE_OUTLINE, alpha * 0.85)
	var fill := Color(col, alpha * 0.95)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := c + Vector2(sx * r, sy * r)
			for pass_i in 2:
				var w := 4.0 if pass_i == 0 else 2.0
				var cc := out if pass_i == 0 else fill
				draw_line(p, p - Vector2(sx * l, 0), cc, w)
				draw_line(p, p - Vector2(0, sy * l), cc, w)


func _draw_reach_dot(c: Vector2, col: Color, alpha: float) -> void:
	var a := alpha * LevelConfig.RETICLE_REACH_DOT_ALPHA
	c = c.round()
	draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), Color(LevelConfig.RETICLE_OUTLINE, a))
	draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color(col, a))
