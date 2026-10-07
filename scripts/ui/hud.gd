extends CanvasLayer
## Build 012 HUD — Sega Genesis / Mega Drive style (Sonic 2, Streets of Rage):
## chunky outlined pixel font (PixelFont), yellow/orange labels, white numbers.
##   top-left : SCORE 00000000 / TIME m:ss / LEVEL n / hearts (HP)
##   top-right: SAVED x/target, then ARRIVING, HUMANS, SHEEP, CONVERTED
## Build 014: on touch the HUD makes room for the corner wedges (TouchLayout):
## the left block (score, time, level, hearts, inventory) starts below the
## top-left weapon wedge and the right block ends left of the top-right
## SECONDARY wedge. PC layout is unchanged from 013 apart from the inventory
## panel replacing the power-up timer bar.
## Build 014 also adds the camcorder REC overlay and the VIRAL callout.
## The end screen is a bordered panel with the level's score breakdown, and the
## PLAY AGAIN / NEXT LEVEL buttons below it (same groups as before, so the touch
## hit-test in touch_controls.gd keeps working).

const LABEL_COL := Color(1.0, 0.82, 0.12)       ## Genesis yellow
const LABEL_COL_ALT := Color(1.0, 0.55, 0.12)   ## orange
const NUM_COL := Color(1, 1, 1)
const GOOD_COL := Color(0.45, 1.0, 0.45)
const BAD_COL := Color(1.0, 0.38, 0.3)
const HELP_PC := "LMB WHIP/REC · RMB GRAB/SWING · Q SWAP"
const HELP_TOUCH := "WHIP AUTO-AIMS · GRAB THROWS"
const HELP_TOUCH_CAM := "HOLD REC TO FILM · SWING SHOVES"
const HELP_SECONDS := 14.0

# Value labels (names kept from the pre-012 HUD where they existed).
var score_label: Label
var time_label: Label
var level_value_label: Label
var rescued_label: Label
var arrivals_label: Label
var living_humans_label: Label
var living_sheep_label: Label
var converted_label: Label
## Build 013
var karens_label: Label
var karens_row: Control
## Build 014
var inventory_panel: InventoryPanel
var cam_overlay: CamOverlay
var callout: Control
var callout_title: Label
var callout_sub: Label
var _touch_layout := false
var _layout_size := Vector2.ZERO
var _arrivals_left: int = 0
var _camp_held := false
var health_label: Label        ## hidden text mirror of HP ("5/5") for tests
var hearts: HeartBar
var objective_label: Label     ## short help line (bottom centre, fades out)
var level_label: Label         ## level banner at round start
var end_label: Label           ## end reason line
var end_title_label: Label
var end_panel: PanelContainer
var breakdown_box: GridContainer
var play_again_button: Button
var next_level_button: Button

var _target: int = 0
var _total: int = 0
var _score: int = 0
var _high_score: int = 0
var _time: float = 0.0
var _help_t: float = 0.0
var _left: VBoxContainer
var _right: VBoxContainer


func _ready() -> void:
	var root := $Root as Control
	_left = VBoxContainer.new()
	_left.name = "LeftStats"
	_left.position = Vector2(22, 14)
	_left.add_theme_constant_override("separation", 6)
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_left)
	score_label = _stat_row(_left, "SCORE", "00000000", 3, 150)
	time_label = _stat_row(_left, "TIME", "0:00", 3, 150)
	level_value_label = _stat_row(_left, "LEVEL", "1", 3, 150)
	hearts = HeartBar.new()
	hearts.name = "Hearts"
	hearts.custom_minimum_size = Vector2(5 * 30, 26)
	_left.add_child(hearts)
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.visible = false
	root.add_child(health_label)

	_right = VBoxContainer.new()
	_right.name = "RightStats"
	_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_right.offset_left = -420
	_right.offset_right = -20
	_right.offset_top = 14
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right.add_theme_constant_override("separation", 6)
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_right)
	rescued_label = _stat_row(_right, "SAVED", "0/5", 3, 0, true)
	arrivals_label = _stat_row(_right, "ARRIVING", "15", 2, 0, true, LABEL_COL_ALT)
	living_humans_label = _stat_row(_right, "HUMANS", "5", 2, 0, true, LABEL_COL_ALT)
	living_sheep_label = _stat_row(_right, "SHEEP", "5", 2, 0, true, LABEL_COL_ALT)
	converted_label = _stat_row(_right, "CONVERTED", "0", 2, 0, true, LABEL_COL_ALT)
	karens_label = _stat_row(_right, "KARENS", "0", 2, 0, true, Color(1.0, 0.45, 0.8))
	karens_row = karens_label.get_parent()
	karens_row.visible = false

	inventory_panel = InventoryPanel.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.position = Vector2(22, 168)
	inventory_panel.size = Vector2(440, 60)
	root.add_child(inventory_panel)

	cam_overlay = CamOverlay.new()
	cam_overlay.name = "CamOverlay"
	cam_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cam_overlay)
	_build_callout(root)
	cam_overlay.callout = callout

	objective_label = Label.new()
	objective_label.name = "ObjectiveLabel"
	objective_label.label_settings = PixelFont.settings(2, Color(0.85, 0.95, 1.0))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	objective_label.offset_left = -400
	objective_label.offset_right = 400
	objective_label.offset_top = -40
	objective_label.offset_bottom = -16
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.text = HELP_PC
	root.add_child(objective_label)

	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.label_settings = PixelFont.settings(5, LABEL_COL)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.set_anchors_preset(Control.PRESET_CENTER)
	level_label.offset_left = -500
	level_label.offset_right = 500
	level_label.offset_top = -150
	level_label.offset_bottom = -40
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(level_label)

	_build_end_panel(root)
	play_again_button = _build_end_button(
		"PlayAgainButton", "PLAY AGAIN", Color(0.77, 0.3, 0.12, 0.97), Color(0.9, 0.42, 0.18, 1.0),
		"play_again_button")
	play_again_button.pressed.connect(_on_play_again)
	next_level_button = _build_end_button(
		"NextLevelButton", "NEXT LEVEL", Color(0.14, 0.55, 0.26, 0.97), Color(0.2, 0.7, 0.34, 1.0),
		"next_level_button")
	next_level_button.pressed.connect(_on_next_level)


## "LABEL value" pair. Returns the value Label.
func _stat_row(parent: Control, label_text: String, value: String, scale: int, label_w: float,
		right_align := false, label_col := LABEL_COL) -> Label:
	var row := HBoxContainer.new()
	row.name = label_text.capitalize().replace(" ", "") + "Row"
	row.add_theme_constant_override("separation", 6 * scale)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right_align:
		row.size_flags_horizontal = Control.SIZE_SHRINK_END
	parent.add_child(row)
	var l := Label.new()
	l.text = label_text
	l.label_settings = PixelFont.settings(scale, label_col)
	if label_w > 0.0:
		l.custom_minimum_size.x = label_w
	row.add_child(l)
	var v := Label.new()
	v.name = label_text.capitalize().replace(" ", "") + "Value"
	v.text = value
	v.label_settings = PixelFont.settings(scale, NUM_COL)
	row.add_child(v)
	return v


func _build_end_panel(root: Control) -> void:
	end_panel = PanelContainer.new()
	end_panel.name = "EndPanel"
	end_panel.visible = false
	end_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.16, 0.9)
	sb.border_color = LABEL_COL_ALT
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(8, 8)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 24
	sb.expand_margin_left = 0
	end_panel.add_theme_stylebox_override("panel", sb)
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.offset_left = -330
	end_panel.offset_right = 330
	end_panel.offset_top = -244
	end_panel.offset_bottom = 92
	end_panel.grow_vertical = Control.GROW_DIRECTION_END
	root.add_child(end_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_panel.add_child(v)
	end_title_label = Label.new()
	end_title_label.name = "EndTitle"
	end_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title_label.label_settings = PixelFont.settings(4, LABEL_COL)
	v.add_child(end_title_label)
	end_label = Label.new()
	end_label.name = "EndLabel"
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.custom_minimum_size = Vector2(580, 0)
	end_label.label_settings = PixelFont.settings(2, NUM_COL)
	v.add_child(end_label)
	var sep := ColorRect.new()
	sep.color = Color(1.0, 0.55, 0.12, 0.8)
	sep.custom_minimum_size = Vector2(0, 4)
	v.add_child(sep)
	breakdown_box = GridContainer.new()
	breakdown_box.name = "Breakdown"
	breakdown_box.columns = 3
	breakdown_box.add_theme_constant_override("h_separation", 26)
	breakdown_box.add_theme_constant_override("v_separation", 8)
	breakdown_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(breakdown_box)


func _build_end_button(node_name: String, label: String, bg: Color, bg_hover: Color, group: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = label
	b.visible = false
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", PixelFont.get_font())
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.55))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.55))
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = Color(1.0, 0.86, 0.4)
	normal.set_border_width_all(5)
	normal.set_corner_radius_all(0)
	normal.shadow_color = Color(0, 0, 0, 0.5)
	normal.shadow_offset = Vector2(6, 6)
	normal.shadow_size = 1
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg_hover
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.offset_left = -170.0
	b.offset_right = 170.0
	b.offset_top = 168.0
	b.offset_bottom = 244.0
	b.add_to_group(group)
	$Root.add_child(b)
	return b


func _level() -> Node:
	return get_tree().get_first_node_in_group("level_controller")


func _on_play_again() -> void:
	var lvl := _level()
	if lvl and lvl.has_method("request_retry"):
		lvl.request_retry()
	else:
		get_tree().reload_current_scene()


func _on_next_level() -> void:
	var lvl := _level()
	if lvl and lvl.has_method("request_next_level"):
		lvl.request_next_level()


## Screen rect of the Play Again button while it is showing (used by touch controls).
func get_play_again_rect() -> Rect2:
	if play_again_button == null or not play_again_button.visible:
		return Rect2()
	return play_again_button.get_global_rect()


func get_next_level_rect() -> Rect2:
	if next_level_button == null or not next_level_button.visible:
		return Rect2()
	return next_level_button.get_global_rect()


func _process(delta: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	if TouchInput.active != _touch_layout or vs != _layout_size:
		apply_layout(TouchInput.active, vs)
	var want := HELP_PC
	if TouchInput.active:
		want = HELP_TOUCH
		var pl: Node = inventory_panel.player if inventory_panel != null else null
		var w: Node = pl.get_node_or_null("Weapons") if pl != null and is_instance_valid(pl) else null
		if w != null and w.current_id() == "cam":
			want = HELP_TOUCH_CAM
	if objective_label.text != want:
		if objective_label.text != "" and objective_label.text != HELP_PC:
			_help_t = 0.0  # weapon changed: show the hint again
			objective_label.modulate.a = 1.0
		objective_label.text = want
	_help_t += delta
	if _help_t > HELP_SECONDS:
		objective_label.modulate.a = clampf(1.0 - (_help_t - HELP_SECONDS) / 1.5, 0.0, 1.0)


## Build 014: PC layout (013 positions) or touch layout (room for the wedges).
func apply_layout(touch: bool, vs: Vector2) -> void:
	_touch_layout = touch
	_layout_size = vs
	if touch:
		_left.position = Vector2(22, TouchLayout.hud_left_top(vs))
		_right.offset_right = -TouchLayout.hud_right_margin(vs)
		_right.offset_left = _right.offset_right - 400.0
		# help line between the joystick and the PRIMARY wedge
		var pw := TouchLayout.wedge_dims(vs).z
		objective_label.offset_left = 290.0 - vs.x * 0.5
		objective_label.offset_right = vs.x * 0.5 - pw - 10.0
	else:
		_left.position = Vector2(22, 14)
		_right.offset_left = -420
		_right.offset_right = -20
		objective_label.offset_left = -400
		objective_label.offset_right = 400
	inventory_panel.position = Vector2(22, _left.position.y + 154.0)


func _build_callout(root: Control) -> void:
	callout = Control.new()
	callout.name = "Callout"
	callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	callout.set_anchors_preset(Control.PRESET_CENTER)
	callout.visible = false
	root.add_child(callout)
	callout_title = Label.new()
	callout_title.name = "CalloutTitle"
	callout_title.label_settings = PixelFont.settings(8, Color(1.0, 0.45, 0.8))
	callout_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	callout_title.position = Vector2(-500, -190)
	callout_title.size = Vector2(1000, 90)
	callout_title.pivot_offset = Vector2(500, 45)
	callout_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	callout.add_child(callout_title)
	callout_sub = Label.new()
	callout_sub.name = "CalloutSub"
	callout_sub.label_settings = PixelFont.settings(3, LABEL_COL)
	callout_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	callout_sub.position = Vector2(-500, -100)
	callout_sub.size = Vector2(1000, 40)
	callout_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	callout.add_child(callout_sub)


## Build 014: big centred callout ("VIRAL!") that pops in and fades out.
func show_callout(title: String, sub: String, col: Color = Color(1.0, 0.45, 0.8), seconds: float = 2.2) -> void:
	callout_title.text = title
	callout_title.label_settings.font_color = col
	callout_sub.text = sub
	callout.visible = true
	callout.modulate.a = 1.0
	callout_title.scale = Vector2(0.3, 0.3)
	var tw := callout.create_tween()
	tw.tween_property(callout_title, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(callout_title, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(seconds)
	tw.tween_property(callout, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: callout.visible = false)


func bind_state(_state: GameState) -> void:
	pass


static func pad_score(value: int) -> String:
	return "%08d" % clampi(value, 0, 99999999)


static func format_time(seconds: float) -> String:
	var s := int(floor(maxf(seconds, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


## Level number + target. Shows the start-of-round banner ("LEVEL 3 / SAVE 7 HUMANS").
func set_level_info(level: int, target: int, total: int) -> void:
	_target = target
	_total = total
	level_value_label.text = str(level)
	karens_row.visible = LevelConfig.karens_enabled(level)
	level_label.text = "LEVEL %d\nSAVE %d HUMANS" % [level, target]
	level_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(level_label, "modulate:a", 0.0, 0.6)


func set_score(value: int) -> void:
	_score = value
	score_label.text = pad_score(value)


func set_high_score(value: int) -> void:
	_high_score = value


func set_time(seconds: float) -> void:
	_time = seconds
	var t := format_time(seconds)
	if time_label.text != t:
		time_label.text = t


func set_rescued(rescued: int, target: int) -> void:
	_target = target
	rescued_label.text = "%d/%d" % [rescued, target]
	rescued_label.label_settings.font_color = GOOD_COL if target > 0 and rescued >= target else NUM_COL


func set_arrivals(left: int) -> void:
	_arrivals_left = left
	_update_arrivals()


func _update_arrivals() -> void:
	# Build 013: while Karens are alive the camp is held ("13 HELD" in red).
	arrivals_label.text = ("%d HELD" % _arrivals_left) if _camp_held and _arrivals_left > 0 else str(_arrivals_left)
	arrivals_label.label_settings.font_color = BAD_COL if _camp_held and _arrivals_left > 0 else NUM_COL


## Build 013: living Karens + whether they are holding the camp.
func set_karens(count: int, camp_held: bool) -> void:
	karens_label.text = str(count)
	karens_label.label_settings.font_color = Color(1.0, 0.45, 0.8) if count > 0 else NUM_COL
	if count > 0 and not karens_row.visible:
		karens_row.visible = true
	if camp_held != _camp_held:
		_camp_held = camp_held
		_update_arrivals()


## Build 014: the inventory panel and the REC overlay read the rancher's
## PowerUps / Weapons / MsmCam nodes directly.
func bind_player(player: Node) -> void:
	inventory_panel.player = player
	cam_overlay.player = player


func set_health(health: int, maximum: int) -> void:
	health_label.text = "%d/%d" % [health, maximum]
	hearts.set_hp(health, maximum)


func set_living_humans(count: int) -> void:
	living_humans_label.text = str(count)


func set_living_sheep(count: int) -> void:
	living_sheep_label.text = str(count)


func set_converted(count: int) -> void:
	converted_label.text = str(count)
	converted_label.label_settings.font_color = Color(1.0, 0.6, 1.0) if count > 0 else NUM_COL


## won=true shows NEXT LEVEL; otherwise PLAY AGAIN (retry the same level).
## `breakdown` comes from level_controller.score_breakdown().
func show_end(won: bool, message: String, breakdown: Dictionary = {}) -> void:
	end_panel.visible = true
	level_label.visible = false
	objective_label.visible = false
	end_label.text = message
	end_label.label_settings.font_color = GOOD_COL if won else Color(1.0, 0.75, 0.7)
	var lvl := int(breakdown.get("level", 0))
	if won:
		end_title_label.text = "LEVEL %d CLEAR!" % lvl if lvl > 0 else "LEVEL CLEAR!"
		end_title_label.label_settings.font_color = LABEL_COL
	else:
		end_title_label.text = "GAME OVER"
		end_title_label.label_settings.font_color = BAD_COL
	for c in breakdown_box.get_children():
		c.queue_free()
	if not breakdown.is_empty():
		_breakdown_row("HUMANS", "%d x200" % int(breakdown.get("rescued", 0)), str(int(breakdown.get("humans_points", 0))))
		_breakdown_row("SHEEP", "%d x50" % int(breakdown.get("sheep", 0)), str(int(breakdown.get("sheep_points", 0))))
		_breakdown_row("POSSESSED", "%d x50" % int(breakdown.get("possessed", 0)), str(int(breakdown.get("possessed_points", 0))))
		if bool(breakdown.get("karens_enabled", false)) or int(breakdown.get("karens", 0)) > 0:
			_breakdown_row("KARENS", "%d x100" % int(breakdown.get("karens", 0)), str(int(breakdown.get("karens_points", 0))))
		var bonus_note := "%d ALIVE" % int(breakdown.get("survivors", 0)) if won else "-"
		_breakdown_row("BONUS", bonus_note, str(int(breakdown.get("bonus", 0))))
		_breakdown_row("LEVEL TOTAL", "", str(int(breakdown.get("level_total", 0))), GOOD_COL)
		_breakdown_row("SCORE", "", pad_score(int(breakdown.get("score", 0))))
		var hi_note := "NEW!" if bool(breakdown.get("new_high", false)) else ""
		_breakdown_row("HI-SCORE", hi_note, pad_score(int(breakdown.get("high_score", 0))), LABEL_COL_ALT)
	if play_again_button:
		play_again_button.visible = not won
	if next_level_button:
		next_level_button.visible = won


func _breakdown_row(a: String, b: String, c: String, value_col := NUM_COL) -> void:
	var la := Label.new()
	la.text = a
	la.label_settings = PixelFont.settings(2, LABEL_COL)
	breakdown_box.add_child(la)
	var lb := Label.new()
	lb.text = b
	lb.label_settings = PixelFont.settings(2, Color(0.8, 0.85, 1.0))
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lb.custom_minimum_size.x = 130
	breakdown_box.add_child(lb)
	var lc := Label.new()
	lc.text = c
	lc.label_settings = PixelFont.settings(2, value_col)
	lc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lc.custom_minimum_size.x = 170
	breakdown_box.add_child(lc)


## Text of every breakdown cell (tests).
func breakdown_text() -> String:
	var parts: PackedStringArray = []
	for c in breakdown_box.get_children():
		if c is Label and not c.is_queued_for_deletion():
			parts.append((c as Label).text)
	return " | ".join(parts)


## Build 014: compact Genesis-style inventory panel (top-left, under the
## hearts): weapon slots (current one framed yellow, a dead cam greyed), the
## cam battery bar + spare batteries, the active whip mod, fire and shockwave
## charges.
class InventoryPanel extends Control:
	const SLOT := 46.0
	const OUT := Color(0.06, 0.03, 0.08)
	const YEL := Color(1.0, 0.82, 0.12)
	const ORANGE := Color(1.0, 0.55, 0.12)
	var player: Node = null
	var _t := 0.0
	var _sig := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _node(n: String) -> Node:
		return player.get_node_or_null(n) if player != null and is_instance_valid(player) else null

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	## Text summary (tests / debugging).
	func summary() -> String:
		var pu := _node("PowerUps")
		var w := _node("Weapons")
		var c := _node("MsmCam")
		if pu == null or w == null:
			return ""
		return "weapon=%s slots=%s batt=%.1f spares=%d mod=%s fire=%d shock=%d" % [
			w.current_id(), ",".join(w.slots), c.battery if c != null else 0.0, pu.spare_batteries,
			pu.whip_mod, pu.fire_charges, pu.shock_charges]

	func _txt(pos: Vector2, t: String, col: Color, size := 20) -> void:
		draw_string(PixelFont.get_font(), pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

	func _draw() -> void:
		var pu := _node("PowerUps")
		var w := _node("Weapons")
		var cam := _node("MsmCam")
		if pu == null or w == null:
			return
		var owned_cam: bool = w.has_weapon("cam")
		# measure
		var width := 8.0 + LevelConfig.WEAPON_DEFS.size() * SLOT + 2.0
		if owned_cam or pu.spare_batteries > 0:
			width += 118.0
		if pu.whip_mod != "":
			width += 40.0
		if pu.fire_charges > 0:
			width += 34.0 + PixelFont.text_width("x%d" % pu.fire_charges, 2) + 8.0
		if pu.shock_charges > 0:
			width += 34.0 + PixelFont.text_width("x%d" % pu.shock_charges, 2) + 8.0
		var h := 56.0
		draw_rect(Rect2(5, 5, width, h), Color(0, 0, 0.05, 0.45))
		draw_rect(Rect2(0, 0, width, h), Color(0.04, 0.05, 0.16, 0.8))
		draw_rect(Rect2(0, 0, width, h), ORANGE, false, 3.0)
		var x := 8.0
		# weapon slots
		for i in LevelConfig.WEAPON_DEFS.size():
			var d: Dictionary = LevelConfig.WEAPON_DEFS[i]
			var id: String = d["id"]
			var r := Rect2(x, 6, 42, 42)
			draw_rect(r, Color(0.1, 0.08, 0.22, 0.95))
			var slot_i: int = w.slots.find(id)
			var is_cur: bool = slot_i >= 0 and slot_i == w.current
			if slot_i >= 0:
				var dead: bool = id == "cam" and cam != null and cam.battery <= 0.0
				PowerUp.draw_icon(self, String(d["icon"]), r.get_center(), 2.3, 0.35 if dead else 1.0)
				if dead:
					draw_line(r.position + Vector2(8, 34), r.position + Vector2(34, 8), Color(1.0, 0.3, 0.25), 3.0)
			else:
				_txt(r.position + Vector2(15, 28), "?", Color(0.4, 0.35, 0.55))
			draw_rect(r, YEL if is_cur else Color(0.35, 0.3, 0.5), false, 3.0 if is_cur else 2.0)
			_txt(r.position + Vector2(3, 11), str(i + 1), Color(1, 1, 1, 0.85), 10)
			x += SLOT
		x += 4.0
		# battery
		if owned_cam or pu.spare_batteries > 0:
			var frac: float = cam.battery_frac() if cam != null and owned_cam else 0.0
			var flash: bool = cam != null and cam.swap_flash > 0.0 and fmod(_t, 0.16) < 0.08
			_txt(Vector2(x, 23), "BATT", YEL if owned_cam else Color(0.6, 0.6, 0.65))
			# spares
			for b in LevelConfig.CAM_SPARE_BATTERIES_MAX:
				var bx := x + 78.0 + b * 12.0
				var have: bool = b < pu.spare_batteries
				draw_rect(Rect2(bx + 2, 6, 4, 2), OUT)
				draw_rect(Rect2(bx - 1, 8, 10, 16), OUT)
				draw_rect(Rect2(bx + 1, 10, 6, 12), Color(0.45, 1.0, 0.35) if have else Color(0.22, 0.2, 0.3))
			# bar
			var segs := 8
			var lit := int(ceil(frac * segs))
			draw_rect(Rect2(x - 2, 31, segs * 13 + 2, 16), OUT)
			for sgi in segs:
				var col := Color(0.25, 0.2, 0.3)
				if sgi < lit:
					col = Color(0.45, 1.0, 0.35) if frac > 0.5 else (YEL if frac > 0.25 else Color(1.0, 0.38, 0.3))
				if flash:
					col = Color(1, 1, 1)
				draw_rect(Rect2(x + sgi * 13, 33, 11, 12), col)
			if owned_cam and frac <= 0.0 and fmod(_t, 0.6) < 0.35:
				_txt(Vector2(x + 18, 45), "EMPTY", Color(1.0, 0.4, 0.35), 10)
			x += 118.0
		# whip mod
		if pu.whip_mod != "":
			PowerUp.draw_icon(self, pu.whip_mod, Vector2(x + 16, 27), 2.0)
			x += 40.0
		for pair in [["fire_whip", pu.fire_charges], ["shockwave", pu.shock_charges]]:
			var n: int = pair[1]
			if n <= 0:
				continue
			PowerUp.draw_icon(self, String(pair[0]), Vector2(x + 16, 27), 2.0)
			var t := "x%d" % n
			_txt(Vector2(x + 34, 36), t, Color(1, 1, 1))
			x += 34.0 + PixelFont.text_width(t, 2) + 8.0


## Build 014: camcorder viewfinder overlay while filming: corner brackets,
## blinking REC, tape counter, battery, Karen-exposure meter, battery-swap cue.
class CamOverlay extends Control:
	var callout: Control = null  # hides the Karen meter while a callout is up
	const OUT := Color(0.06, 0.03, 0.08)
	var player: Node = null
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _cam() -> Node:
		return player.get_node_or_null("MsmCam") if player != null and is_instance_valid(player) else null

	func _process(delta: float) -> void:
		_t += delta
		var c := _cam()
		var show: bool = c != null and (c.filming or c.swap_flash > 0.0)
		if visible != show:
			visible = show
		if show:
			queue_redraw()

	func frame_rect() -> Rect2:
		var s := size
		if TouchInput.active:
			# below the moved right stats, clear of all three wedges
			return Rect2(s.x * 0.36, s.y * 0.28, s.x * 0.33, s.y * 0.5)
		return Rect2(s.x * 0.34, s.y * 0.17, s.x * 0.36, s.y * 0.58)

	func _txt(pos: Vector2, t: String, col: Color, sz := 20) -> void:
		draw_string(PixelFont.get_font(), pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

	func _draw() -> void:
		var c := _cam()
		if c == null:
			return
		var r := frame_rect()
		var wc := Color(1, 1, 1, 0.6)
		var arm := 34.0
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if corner.x < r.get_center().x else -1.0
			var sy := 1.0 if corner.y < r.get_center().y else -1.0
			draw_line(corner, corner + Vector2(arm * sx, 0), Color(0, 0, 0, 0.35), 7.0)
			draw_line(corner, corner + Vector2(0, arm * sy), Color(0, 0, 0, 0.35), 7.0)
			draw_line(corner, corner + Vector2(arm * sx, 0), wc, 4.0)
			draw_line(corner, corner + Vector2(0, arm * sy), wc, 4.0)
		# faint scanlines inside the frame
		var y := r.position.y + fmod(_t * 20.0, 4.0)
		while y < r.end.y:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.022), 1.0)
			y += 4.0
		# centre cross
		var cc := r.get_center()
		draw_line(cc + Vector2(-10, 0), cc + Vector2(10, 0), Color(1, 1, 1, 0.3), 2.0)
		draw_line(cc + Vector2(0, -10), cc + Vector2(0, 10), Color(1, 1, 1, 0.3), 2.0)
		if c.filming:
			if fmod(_t, 1.0) < 0.6:
				draw_circle(r.position + Vector2(24, 26), 10.0, OUT)
				draw_circle(r.position + Vector2(24, 26), 7.5, Color(1.0, 0.15, 0.12))
			_txt(r.position + Vector2(40, 38), "REC", Color(1, 1, 1), 30)
			var tsec := int(c.rec_time)
			var tc := "%d:%02d:%02d" % [tsec / 3600, (tsec / 60) % 60, tsec % 60]
			var tw := PixelFont.text_width(tc, 2)
			_txt(Vector2(r.end.x - tw - 14, r.position.y + 34), tc, Color(1, 1, 1, 0.9))
			_txt(Vector2(r.end.x - PixelFont.text_width("SP", 2) - 14, r.position.y + 58), "SP", Color(1, 1, 1, 0.6))
			_txt(Vector2(r.position.x + 14, r.end.y - 14), "MSM CAM", Color(1, 1, 1, 0.55))
		# battery (bottom right)
		var bx := r.end.x - 82.0
		var by := r.end.y - 34.0
		draw_rect(Rect2(bx - 2, by - 2, 64, 22), OUT)
		draw_rect(Rect2(bx + 62, by + 4, 5, 10), OUT)
		var frac: float = c.battery_frac()
		var segs := 5
		var lit := int(ceil(frac * segs))
		for i in segs:
			var col := Color(1, 1, 1, 0.9) if i < lit else Color(1, 1, 1, 0.15)
			if i < lit and frac <= 0.25 and fmod(_t, 0.5) < 0.25:
				col = Color(1.0, 0.35, 0.3)
			draw_rect(Rect2(bx + 1 + i * 12, by + 1, 10, 16), col)
		var pu: Node = player.get_node_or_null("PowerUps")
		if pu != null and pu.spare_batteries > 0:
			_txt(Vector2(bx - 34, by + 17), "+%d" % pu.spare_batteries, Color(0.6, 1.0, 0.5))
		# Karen exposure meter
		if c.expose_time > 0.0 and not (callout != null and callout.visible):
			var ex: float = clampf(c.expose_time / LevelConfig.CAM_EXPOSE_SECONDS, 0.0, 1.0)
			var lx := r.position.x + 14.0
			var ly := r.position.y + 54.0
			_txt(Vector2(lx, ly + 14), "KAREN CAM", Color(1.0, 0.5, 0.85))
			draw_rect(Rect2(lx - 2, ly + 20, 164, 12), OUT)
			draw_rect(Rect2(lx, ly + 22, 160 * ex, 8), Color(1.0, 0.45, 0.8))
		if c.swap_flash > 0.0 and fmod(_t, 0.2) < 0.13:
			var t := "BATTERY SWAP"
			_txt(Vector2(cc.x - PixelFont.text_width(t, 3) * 0.5, r.end.y - 50), t, Color(0.6, 1.0, 0.5), 30)


## Row of pixel hearts (Genesis style): red full, dark empty, thick outline.
class HeartBar extends Control:
	const SHAPE := [
		".##.##.",
		"#######",
		"#######",
		".#####.",
		"..###..",
		"...#...",
	]
	const PX := 3
	var hp: int = 5
	var max_hp: int = 5

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_hp(h: int, m: int) -> void:
		hp = h
		max_hp = maxi(m, 1)
		custom_minimum_size = Vector2(max_hp * 30, 26)
		queue_redraw()

	func _draw() -> void:
		for i in max_hp:
			var o := Vector2(i * 30, 2)
			var full := i < hp
			var fill := Color(0.95, 0.15, 0.2) if full else Color(0.25, 0.2, 0.3)
			var shine := Color(1, 0.75, 0.75) if full else Color(0.38, 0.33, 0.45)
			# shadow, outline, fill
			for y in SHAPE.size():
				for x in 7:
					if SHAPE[y][x] == "#":
						draw_rect(Rect2(o + Vector2((x + 1) * PX + 3, (y + 1) * PX + 3), Vector2(PX, PX)), Color(0, 0, 0.05, 0.5))
			for y in SHAPE.size():
				for x in 7:
					if SHAPE[y][x] == "#":
						draw_rect(Rect2(o + Vector2(x * PX, y * PX), Vector2(PX * 3, PX * 3)), Color(0.06, 0.03, 0.08))
			for y in SHAPE.size():
				for x in 7:
					if SHAPE[y][x] == "#":
						draw_rect(Rect2(o + Vector2((x + 1) * PX, (y + 1) * PX), Vector2(PX, PX)), fill)
			draw_rect(Rect2(o + Vector2(2 * PX, 2 * PX), Vector2(PX, PX)), shine)
