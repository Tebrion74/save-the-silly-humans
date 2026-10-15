extends Node
## Internal beta tools (release builds too). Beta-only: documented in CHEATS.md,
## removed at alpha (v1.0).
## Entry: 4 digits typed on the title screen or while the game is paused
## (number row or numpad); on touch, hold the title logo 2 s for a keypad.

const HOLD_SECONDS := 2.0
const BUFFER_TIMEOUT := 2.5

var god := false
var noclip := false
## Any tool used since the last fresh START: the high score is not saved.
var tainted := false

var _buf := ""
var _buf_t := 0.0
var _hold_t := -1.0
var _hold_pos := Vector2.ZERO
var _touch_down := false
var _touch_pos := Vector2.ZERO
var _layer: CanvasLayer
var _tag: Label
var _pad: Control
var _pad_display: Label
var _pad_title: Label
var _pad_mode := "code"   # "code" | "level"
var _pad_text := ""
var _pad_prev_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_tag = Label.new()
	_tag.text = "CHEAT ON"
	_tag.add_theme_font_size_override("font_size", 15)
	_tag.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	_tag.add_theme_color_override("font_outline_color", Color(0.25, 0, 0.05))
	_tag.add_theme_constant_override("outline_size", 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.7, 0.05, 0.15, 0.85)
	sb.set_content_margin_all(3)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.set_corner_radius_all(3)
	_tag.add_theme_stylebox_override("normal", sb)
	# bottom centre, just above the control hint line: free on PC and touch
	_tag.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.offset_left = -60
	_tag.offset_right = 60
	_tag.offset_top = -78
	_tag.offset_bottom = -52
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.visible = false
	_layer.add_child(_tag)


func is_active() -> bool:
	return god or noclip


## A fresh START clears the taint unless a tool is still on.
func on_new_run() -> void:
	tainted = god or noclip
	_refresh_tag()


func _refresh_tag() -> void:
	_tag.visible = god or noclip or tainted
	_tag.text = "CHEAT ON" if (god or noclip) else "CHEATED"


# ------------------------------------------------------------------ input

func _on_title() -> bool:
	var cs := get_tree().current_scene
	return cs != null and cs.has_method("_build_title")


func _accepting() -> bool:
	return _on_title() or get_tree().paused


func _digit(ev: InputEventKey) -> String:
	var k := ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	if k >= KEY_0 and k <= KEY_9:
		return str(k - KEY_0)
	if k >= KEY_KP_0 and k <= KEY_KP_9:
		return str(k - KEY_KP_0)
	if ev.keycode >= KEY_KP_0 and ev.keycode <= KEY_KP_9:
		return str(ev.keycode - KEY_KP_0)
	return ""


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var d := _digit(ev)
		if _pad != null:
			if d != "":
				_pad_press(d)
			elif ev.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_pad_press("OK")
			elif ev.keycode == KEY_BACKSPACE:
				_pad_press("C")
			elif ev.keycode == KEY_ESCAPE:
				_close_pad()
			get_viewport().set_input_as_handled()
			return
		if d != "" and _accepting():
			_buf += d
			_buf_t = BUFFER_TIMEOUT
			if _buf.length() >= 4:
				var code := _buf.right(4)
				_buf = ""
				_apply_code(code)
		return


## The title screen consumes touches itself, so it forwards them here.
func note_title_touch(pressed: bool, pos: Vector2) -> void:
	_touch_down = pressed
	_touch_pos = pos


func _logo_rect() -> Rect2:
	var cs := get_tree().current_scene
	var box = cs.get("_title_box") if cs != null else null
	if box is Control:
		return (box as Control).get_global_rect()
	return Rect2()


func _process(delta: float) -> void:
	if _buf_t > 0.0:
		_buf_t -= delta
		if _buf_t <= 0.0:
			_buf = ""
	# long-press on the title logo (touch is emulated as the left button;
	# polled so the title's own input handling cannot swallow it)
	var down := _touch_down or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var at := _touch_pos if _touch_down else get_viewport().get_mouse_position()
	if down and _pad == null and _on_title() and _logo_rect().has_point(at):
		_hold_t = maxf(_hold_t, 0.0) + delta
		if _hold_t >= HOLD_SECONDS:
			_hold_t = -99.0   # one keypad per hold
			_open_pad("code")
	elif not down:
		_hold_t = -1.0
	if god:
		_god_tick()


# ------------------------------------------------------------------ codes

func _apply_code(code: String) -> void:
	match code:
		"7474":
			god = true
			tainted = true
			_toast("GOD MODE")
		"1974":
			tainted = true
			_toast("SKIP")
			_skip_stage.call_deferred()
		"2012":
			tainted = true
			_open_pad("level")
		"6969":
			noclip = not noclip
			tainted = true
			_toast("NOCLIP ON" if noclip else "NOCLIP OFF")
		"0000":
			god = false
			noclip = false
			_toast("CHEATS OFF")
			_restore_normal.call_deferred()
		_:
			return
	_refresh_tag()


func _toast(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0, 0.05))
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -150
	l.offset_right = 150
	l.offset_top = 84
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _gp() -> Node:
	return get_node_or_null("/root/GameProgress")


func _change(scene: String) -> void:
	get_tree().paused = false
	var ma := get_node_or_null("/root/MouseAim")
	if ma != null and ma.has_method("_show_prompt"):
		ma._show_prompt(false)
	get_tree().change_scene_to_file(scene)


func _skip_stage() -> void:
	var gp := _gp()
	if gp == null:
		return
	var next := ""
	if _on_title():
		gp.reset_progress()
		tainted = true
		_refresh_tag()
		next = gp.begin_after_level(1)
	elif String(gp.current_stage) != "":
		next = gp.finish_stage()
	else:
		next = gp.begin_after_level(int(gp.current_level))
	if next != "":
		_change(next)


func _start_level(n: int) -> void:
	var gp := _gp()
	if gp == null or n < 1:
		return
	gp.reset_progress()
	tainted = true
	_refresh_tag()
	gp.current_level = n
	_change(LevelConfig.GAME_SCENE)


func _start_boss(b: int) -> void:
	var gp := _gp()
	if gp == null or not gp.has_method("start_at_stage"):
		return
	var scene: String = gp.start_at_stage("boss%d" % b)
	tainted = true
	_refresh_tag()
	if scene != "":
		_change(scene)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _god_tick() -> void:
	var p := _player()
	if p == null:
		return
	if "health" in p and "maximum_health" in p and p.health < p.maximum_health and not p._dead:
		p.health = p.maximum_health
		p.health_changed.emit(p.health, p.maximum_health)
	var pu := p.get_node_or_null("PowerUps")
	if pu == null:
		return
	var dirty := false
	if pu.fire_charges < LevelConfig.FIRE_CHARGES_MAX:
		pu.fire_charges = LevelConfig.FIRE_CHARGES_MAX
		dirty = true
	if pu.shock_charges < LevelConfig.SHOCK_CHARGES_MAX:
		pu.shock_charges = LevelConfig.SHOCK_CHARGES_MAX
		dirty = true
	var w = pu.weapons()
	var c = pu.cam()
	if w != null and c != null and not w.has_weapon("cam"):
		w.add_weapon("cam")
		dirty = true
	if c != null and c.battery < LevelConfig.CAM_BATTERY_SECONDS:
		c.battery = LevelConfig.CAM_BATTERY_SECONDS
	if dirty or not pu.active.has("strong_throw"):
		pu._apply()
		pu.changed.emit()


func _restore_normal() -> void:
	var p := _player()
	if p == null:
		return
	var pu := p.get_node_or_null("PowerUps")
	if pu != null:
		pu._apply()
		pu.changed.emit()


# ------------------------------------------------------------------ keypad

func _open_pad(mode: String) -> void:
	_close_pad()
	_pad_mode = mode
	_pad_text = ""
	# modal: the scene underneath (title START on Enter etc.) gets no input
	_pad_prev_paused = get_tree().paused
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	_pad = dim
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.16, 0.97)
	sb.border_color = Color(0.5, 0.85, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -210
	panel.offset_bottom = 210
	dim.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_pad_title = Label.new()
	_pad_title.text = "CODE" if mode == "code" else "LEVEL  (91-99 = BOSS 1-9, 90 = BOSS 10)"
	_pad_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad_title.add_theme_font_size_override("font_size", 20)
	v.add_child(_pad_title)
	_pad_display = Label.new()
	_pad_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad_display.add_theme_font_size_override("font_size", 34)
	_pad_display.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	v.add_child(_pad_display)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]:
		var b := Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(84, 58)
		b.add_theme_font_size_override("font_size", 26)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pad_press.bind(k))
		grid.add_child(b)
	var x := Button.new()
	x.text = "CLOSE"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(0, 44)
	x.add_theme_font_size_override("font_size", 18)
	x.pressed.connect(_close_pad)
	v.add_child(x)
	_pad_refresh()


func _pad_refresh() -> void:
	if _pad_display != null:
		_pad_display.text = (_pad_text if _pad_text != "" else "_") if _pad_mode == "level" else ("•".repeat(_pad_text.length()) + "_".repeat(4 - _pad_text.length()))


func _pad_press(k: String) -> void:
	match k:
		"C":
			_pad_text = ""
		"OK":
			_pad_submit()
			return
		_:
			if _pad_text.length() < (2 if _pad_mode == "level" else 4):
				_pad_text += k
	_pad_refresh()
	if _pad_mode == "code" and _pad_text.length() == 4:
		_pad_submit()


func _pad_submit() -> void:
	var t := _pad_text
	var mode := _pad_mode
	_close_pad()
	if mode == "code":
		_apply_code(t)
	elif t.is_valid_int() and int(t) >= 90 and int(t) <= 99:
		# build 025: 91-98 = boss 1-8; build 027: 99 = boss 9, 90 = boss 10
		# (bosses 7-10 are not on the title menu)
		tainted = true
		_refresh_tag()
		_start_boss.call_deferred(boss_for_code(int(t)))
	elif t.is_valid_int() and int(t) >= 1:
		tainted = true
		_refresh_tag()
		_start_level.call_deferred(int(t))


## Build 027: level-select boss codes (91-99 = boss 1-9, 90 = boss 10, else 0).
static func boss_for_code(code: int) -> int:
	if code == 90:
		return 10
	if code >= 91 and code <= 99:
		return code - 90
	return 0


func _close_pad() -> void:
	if _pad != null:
		_pad.queue_free()
		get_tree().paused = _pad_prev_paused
	_pad = null
	_pad_display = null
	_pad_title = null
