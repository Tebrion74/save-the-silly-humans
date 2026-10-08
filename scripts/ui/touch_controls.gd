extends Control
## On-screen controls for mobile. Hidden until TouchInput.active.
## Build 014 layout (geometry in TouchLayout, all from the viewport size):
##  - Fixed joystick (bottom-left, unchanged since 011): the base never moves.
##    Movement = finger offset from the fixed centre, clamped to the radius.
##  - PRIMARY wedge (bottom-right corner): WHIP with the whip, REC (hold to
##    film) with the MSM Cam.
##  - SECONDARY wedge (top-right corner): GRAB with the whip, SWING with the cam.
##  - Weapon wedge (top-left corner): tap = next weapon; shows the current
##    weapon's icon.
##  The wedges are angled corner polygons (30 degree diagonal) and are hit-tested
##  with point-in-polygon. They are the ONLY way to act on touch: touching the
##  rest of the playfield does nothing. Multi-touch: every finger is tracked by
##  index, so joystick + a wedge (or both wedges) work at the same time.
##  - While the round is over, touches only hit PLAY AGAIN / NEXT LEVEL.

## ---- Sensitivity / layout hooks -------------------------------------------
const JOYSTICK_RADIUS := 100.0
## Deflection below JOYSTICK_DEADZONE (fraction of radius) is ignored; above it
## the vector is multiplied by JOYSTICK_SENSITIVITY and clamped to 1, so full
## speed arrives at ~1/JOYSTICK_SENSITIVITY (≈70%) deflection.
const JOYSTICK_DEADZONE := 0.12
const JOYSTICK_SENSITIVITY := 1.4
## Fixed base centre, measured from the bottom-left corner of the viewport.
const JOYSTICK_CENTER_FROM_BOTTOM_LEFT := TouchLayout.JOY_CENTER_FROM_BOTTOM_LEFT
## A touch grabs the joystick if it starts within this many radii of the base
## centre, or anywhere in the left JOYSTICK_GRAB_SCREEN_FRAC of the screen
## (below the weapon wedge).
const JOYSTICK_GRAB_RADIUS_MULT := 1.6
const JOYSTICK_GRAB_SCREEN_FRAC := 0.4
const KNOB_RADIUS := 40.0
const BUTTON_FLASH_TIME := 0.18
const OUT := Color(0.06, 0.03, 0.08)

var _joy_index: int = -1
var _joy_knob: Vector2 = Vector2.ZERO
var _whip_index: int = -1     ## PRIMARY finger
var _grab_index: int = -1     ## SECONDARY finger
var _swap_index: int = -1
var _restart_index: int = -1
var _level_ended: bool = false
var _whip_flash: float = 0.0
var _grab_flash: float = 0.0
var _swap_flash: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_joy_knob = joy_center()


func _process(delta: float) -> void:
	_t += delta
	var want := TouchInput.active
	if visible != want:
		visible = want
	_level_ended = _check_level_ended()
	_whip_flash = maxf(_whip_flash - delta, 0.0)
	_grab_flash = maxf(_grab_flash - delta, 0.0)
	_swap_flash = maxf(_swap_flash - delta, 0.0)
	TouchInput.whip_held = _whip_index >= 0 and not _level_ended and TouchInput.active
	if _joy_index < 0:
		_joy_knob = joy_center()
	if visible:
		queue_redraw()


func _check_level_ended() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("level_controller"):
		if "_ended" in node and bool(node.get("_ended")):
			return true
	return false


func _vp_size() -> Vector2:
	return get_viewport_rect().size


## Fixed joystick base centre (never moves).
func joy_center() -> Vector2:
	return TouchLayout.joy_center(_vp_size())


func primary_poly() -> PackedVector2Array:
	return TouchLayout.primary_poly(_vp_size())


func secondary_poly() -> PackedVector2Array:
	return TouchLayout.secondary_poly(_vp_size())


func swap_poly() -> PackedVector2Array:
	return TouchLayout.swap_poly(_vp_size())


## Bounding boxes (layout checks / old callers only; hit tests use polygons).
func whip_rect() -> Rect2:
	return TouchLayout.rect_of(primary_poly())


func grab_rect() -> Rect2:
	return TouchLayout.rect_of(secondary_poly())


func swap_rect() -> Rect2:
	return TouchLayout.rect_of(swap_poly())


func hits_primary(pos: Vector2) -> bool:
	return TouchLayout.hit(primary_poly(), pos)


func hits_secondary(pos: Vector2) -> bool:
	return TouchLayout.hit(secondary_poly(), pos)


func hits_swap(pos: Vector2) -> bool:
	return TouchLayout.hit(swap_poly(), pos)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player") if get_tree() != null else null


func _weapons() -> Node:
	var p := _player()
	return p.get_node_or_null("Weapons") if p != null else null


func _cam() -> Node:
	var p := _player()
	return p.get_node_or_null("MsmCam") if p != null else null


func _current_def() -> Dictionary:
	var w := _weapons()
	return LevelConfig.weapon_def(w.current_id() if w != null else "whip")


func _weapon_count() -> int:
	var w := _weapons()
	return w.slots.size() if w != null else 1


func _play_again_rect() -> Rect2:
	return _group_button_rect("play_again_button")


func _next_level_rect() -> Rect2:
	return _group_button_rect("next_level_button")


func _group_button_rect(group: String) -> Rect2:
	for node in get_tree().get_nodes_in_group(group):
		var b := node as Control
		if b and b.is_visible_in_tree():
			return b.get_global_rect().grow(16.0)
	return Rect2()


func _in_joy_grab_zone(pos: Vector2) -> bool:
	if pos.distance_to(joy_center()) <= JOYSTICK_RADIUS * JOYSTICK_GRAB_RADIUS_MULT:
		return true
	return pos.x < _vp_size().x * JOYSTICK_GRAB_SCREEN_FRAC


## Finger position -> move vector, relative to the FIXED centre.
func _apply_joy(pos: Vector2) -> void:
	var delta := pos - joy_center()
	if delta.length() > JOYSTICK_RADIUS:
		delta = delta.normalized() * JOYSTICK_RADIUS
	_joy_knob = joy_center() + delta
	var v := delta / JOYSTICK_RADIUS
	TouchInput.move_vector = Vector2.ZERO if v.length() < JOYSTICK_DEADZONE else (v * JOYSTICK_SENSITIVITY).limit_length(1.0)


func _release_joy() -> void:
	_joy_index = -1
	_joy_knob = joy_center()
	TouchInput.move_vector = Vector2.ZERO


func _input(event: InputEvent) -> void:
	# Screen touch/drag only ever come from real fingers, so no PC impact.
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		TouchInput.note_touch(t.index, t.pressed, false)
		_on_screen_touch(t)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		TouchInput.note_touch(d.index, true, true)
		_on_screen_drag(d)


func _on_screen_touch(e: InputEventScreenTouch) -> void:
	var pos: Vector2 = e.position
	var idx: int = e.index

	if e.pressed:
		# Build 015b: the HUD speaker icon (sound ON / LOW / OFF).
		for sb in get_tree().get_nodes_in_group("sound_button"):
			if sb is Control and sb.has_method("hit_rect") and sb.hit_rect().has_point(pos):
				sb.toggle()
				get_viewport().set_input_as_handled()
				return
		if _level_ended:
			# Game over: the only thing a tap can do is hit PLAY AGAIN / NEXT LEVEL.
			if _play_again_rect().has_point(pos):
				_restart_index = idx
				TouchInput.restart_just_pressed = true
			elif _next_level_rect().has_point(pos):
				_restart_index = idx
				TouchInput.next_level_just_pressed = true
			get_viewport().set_input_as_handled()
			return
		# Wedges first (the weapon wedge sits inside the joystick's left-40% zone).
		if hits_primary(pos):
			_whip_index = idx
			_whip_flash = BUTTON_FLASH_TIME
			TouchInput.whip_just_pressed = true
			get_viewport().set_input_as_handled()
			return
		if hits_secondary(pos):
			_grab_index = idx
			_grab_flash = BUTTON_FLASH_TIME
			TouchInput.grab_just_pressed = true
			get_viewport().set_input_as_handled()
			return
		if hits_swap(pos):
			_swap_index = idx
			_swap_flash = BUTTON_FLASH_TIME
			TouchInput.swap_just_pressed = true
			get_viewport().set_input_as_handled()
			return
		if _in_joy_grab_zone(pos):
			_joy_index = idx
			_apply_joy(pos)
			get_viewport().set_input_as_handled()
			return
		# Anywhere else (right-side playfield): deliberately does nothing.
		get_viewport().set_input_as_handled()
	else:
		if idx == _joy_index:
			_release_joy()
		if idx == _whip_index:
			_whip_index = -1
		if idx == _grab_index:
			_grab_index = -1
		if idx == _swap_index:
			_swap_index = -1
		if idx == _restart_index:
			_restart_index = -1
		get_viewport().set_input_as_handled()


func _on_screen_drag(e: InputEventScreenDrag) -> void:
	var pos: Vector2 = e.position
	var idx: int = e.index

	if idx == _joy_index:
		_apply_joy(pos)
		get_viewport().set_input_as_handled()
	elif idx == _whip_index or idx == _grab_index or idx == _restart_index or idx == _swap_index:
		get_viewport().set_input_as_handled()
	elif not _level_ended:
		# Unknown finger (some browsers renumber touches between press and drag):
		# a drag in the joystick zone (or near the knob) drives the joystick.
		if hits_swap(pos) or hits_primary(pos) or hits_secondary(pos):
			return
		var near_knob := pos.distance_to(_joy_knob) < JOYSTICK_RADIUS * 2.5
		if _in_joy_grab_zone(pos) or (_joy_index >= 0 and near_knob):
			if _joy_index < 0 or near_knob:
				_joy_index = idx
				_apply_joy(pos)
				get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if not TouchInput.active:
		return
	if _level_ended:
		return
	var s := _vp_size()
	_draw_joystick()
	var def := _current_def()
	var cam := _cam()
	var cam_dead: bool = cam != null and cam.battery <= 0.0
	var is_cam: bool = def.get("id", "") == "cam"
	# PRIMARY (bottom-right)
	var p_col: Color = def.get("primary_col", Color(1.0, 0.82, 0.25))
	if is_cam and cam_dead:
		p_col = Color(0.5, 0.5, 0.55)
	var p_poly := primary_poly()
	var p_pressed := _whip_index >= 0 or _whip_flash > 0.0
	_draw_wedge(p_poly, p_col, p_pressed)
	var p_anchor := TouchLayout.label_anchor(p_poly, Vector2(s.x, s.y))
	var p_label: String = def.get("primary", "WHIP")
	if is_cam:
		var dot_on: bool = cam == null or not cam.filming or fmod(_t, 0.8) < 0.5
		_draw_label(p_anchor, p_label, Color(1.0, 0.3, 0.26) if not cam_dead else Color(0.75, 0.75, 0.78), "rec" if dot_on and not cam_dead else "")
		if cam_dead:
			_draw_small(p_anchor + Vector2(0, 34), "NO BATTERY", Color(1.0, 0.5, 0.45))
		elif cam != null and cam.filming:
			_draw_small(p_anchor + Vector2(0, 34), "FILMING", Color(1, 1, 1))
		else:
			_draw_small(p_anchor + Vector2(0, 34), "HOLD", Color(1, 1, 1, 0.8))
	else:
		_draw_label(p_anchor, p_label, Color(1, 1, 1), "")
	# SECONDARY (top-right)
	var s_poly := secondary_poly()
	var s_col: Color = def.get("secondary_col", Color(0.45, 0.8, 1.0))
	var s_pressed := _grab_index >= 0 or _grab_flash > 0.0
	_draw_wedge(s_poly, s_col, s_pressed)
	var s_anchor := TouchLayout.label_anchor(s_poly, Vector2(s.x, 0))
	_draw_label(s_anchor, def.get("secondary", "GRAB"), Color(1, 1, 1), "")
	if is_cam and cam != null and cam.swing_cooldown > 0.0:
		var frac: float = cam.swing_cooldown / LevelConfig.SWING_COOLDOWN
		draw_rect(Rect2(s_anchor + Vector2(-40, 26), Vector2(80, 6)), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(s_anchor + Vector2(-40, 26), Vector2(80 * (1.0 - frac), 6)), Color(1, 1, 1, 0.8))
	# WEAPON (top-left)
	_draw_swap_wedge(def, cam_dead)


func _draw_joystick() -> void:
	var c := joy_center()
	var active := _joy_index >= 0
	draw_circle(c, JOYSTICK_RADIUS, Color(0.05, 0.08, 0.06, 0.28 if active else 0.2))
	draw_arc(c, JOYSTICK_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.6 if active else 0.38), 3.0, true)
	draw_arc(c, JOYSTICK_RADIUS * 0.55, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 1.5, true)
	# direction ticks
	for i in 4:
		var a := float(i) * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (JOYSTICK_RADIUS - 16.0), c + d * (JOYSTICK_RADIUS - 6.0), Color(1, 1, 1, 0.3), 2.0, true)
	var knob := _joy_knob if active else c
	draw_circle(knob + Vector2(0, 3), KNOB_RADIUS, Color(0, 0, 0, 0.18))
	draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.55 if active else 0.32))
	draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.75 if active else 0.45), 2.0, true)


## Semi-transparent Genesis-style wedge: tinted fill, a darker band along the
## diagonal, thick outline. Pressed = brighter fill + thicker cream border.
func _draw_wedge(poly: PackedVector2Array, tint: Color, pressed: bool) -> void:
	var fill := tint
	fill.a = 0.42 if pressed else 0.2
	draw_colored_polygon(poly, fill)
	var c := TouchLayout.centroid(poly)
	var closed := poly.duplicate()
	closed.append(poly[0])
	# inner highlight line (Genesis bevel)
	var inset := PackedVector2Array()
	for p in poly:
		inset.append(p.lerp(c, 0.12))
	inset.append(inset[0])
	draw_polyline(inset, Color(1, 1, 1, 0.18 if pressed else 0.1), 2.0, true)
	draw_polyline(closed, Color(0.06, 0.03, 0.08, 0.5), 7.0, true)
	draw_polyline(closed, Color(1, 1, 0.85, 0.95) if pressed else Color(1, 1, 1, 0.55), 5.0 if pressed else 3.0, true)


func _draw_label(center: Vector2, text: String, col: Color, icon: String) -> void:
	var fs := 40
	var w := PixelFont.text_width(text, 4)
	var x := center.x - w * 0.5
	if icon == "rec":
		x += 14.0
		draw_circle(Vector2(x - 22.0, center.y - 2.0), 12.0, OUT)
		draw_circle(Vector2(x - 22.0, center.y - 2.0), 9.0, Color(1.0, 0.15, 0.12))
	draw_string(PixelFont.get_font(), Vector2(x, center.y + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_small(center: Vector2, text: String, col: Color) -> void:
	var w := PixelFont.text_width(text, 2)
	draw_string(PixelFont.get_font(), Vector2(center.x - w * 0.5, center.y + 7.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)


func _draw_swap_wedge(def: Dictionary, cam_dead: bool) -> void:
	var poly := swap_poly()
	var n := _weapon_count()
	var pressed := _swap_index >= 0 or _swap_flash > 0.0
	_draw_wedge(poly, Color(0.75, 0.55, 1.0) if n > 1 else Color(0.55, 0.55, 0.6), pressed)
	var d := TouchLayout.swap_dims(_vp_size())
	var icon_c := Vector2(d.y * 0.5 + 6.0, d.x * 0.42)
	var alpha := 0.5 if def.get("id", "") == "cam" and cam_dead else 1.0
	PowerUp.draw_icon(self, String(def.get("icon", "whip")), icon_c, 3.6, alpha if n > 1 else 0.7)
	# slot dots (current one lit) + "SWAP" (only once there is something to swap to)
	var w := _weapons()
	var cur: int = w.current if w != null else 0
	for i in n:
		var dc := Vector2(icon_c.x + 46.0 + i * 16.0, icon_c.y - 14.0)
		draw_circle(dc, 6.0, OUT)
		draw_circle(dc, 4.0, Color(1.0, 0.82, 0.12) if i == cur else Color(0.4, 0.35, 0.5))
	if n > 1:
		_draw_small(Vector2(icon_c.x + 62.0, icon_c.y + 14.0), "SWAP", Color(1, 1, 1, 0.95))
