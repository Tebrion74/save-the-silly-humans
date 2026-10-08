extends Control
## Title screen (build 011, HOW TO PLAY added in 012) — late-32-bit-era style.
## START (mouse click, touch tap, Enter, Space) resets GameProgress to level 1 /
## score 0 and loads the game (Main.tscn).
## HOW TO PLAY (mouse click, touch tap, H) opens the controls/objectives screen;
## BACK (mouse click, touch tap, Esc, Backspace) closes it. Enter/Space start the
## game from either screen.
## Mouse emulation from touch is off, so touches are hit-tested by hand.

const GAME_SCENE := "res://scenes/Main.tscn"
const BUILD_LABEL := "BUILD 015B"
const COPYRIGHT := "© 2026 ECHELON PUBLISHERS GROUP"
const HORIZON := 440.0
const TITLE_SHADER := preload("res://assets/shaders/title_text.gdshader")

var start_button: Button
var howto_button: Button
var back_button: Button
var sound_icon: SoundIcon
## Full-screen How to Play overlay (hidden until opened).
var howto_panel: Control
var _press_label: Label
var _hiscore_label: Label
var _title_box: Control
var _title_mats: Array[ShaderMaterial] = []
var _flash: ColorRect
var _t: float = 0.0
var _starting: bool = false
var _parade: Array = []
var _stars: Array = []
var _clouds: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("title_screen")
	Sfx.music(self, "")   # build 015b: the title is quiet; music starts in a level
	# Build 014b: the gameplay reticle hides the OS pointer; menus always get it back.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 11
	for i in 70:
		_stars.append(Vector3(_rng.randf_range(0, 1280), _rng.randf_range(0, 250), _rng.randf_range(0, TAU)))
	for i in 5:
		_clouds.append(Vector3(_rng.randf_range(0, 1280), _rng.randf_range(250, 360), _rng.randf_range(0.6, 1.3)))
	_build_scene_props()
	_build_parade()
	_build_title()
	_build_menu()
	_flash = ColorRect.new()
	_flash.color = Color(0, 0, 0, 1)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.6)
	# Build 014 debug scenarios (debug builds only): skip the title.
	var progress := get_node_or_null("/root/GameProgress")
	if OS.is_debug_build() and progress != null and "debug_scenario" in progress and String(progress.debug_scenario).begins_with("boss"):
		progress.start_at_boss()
		get_tree().change_scene_to_file.call_deferred(LevelConfig.BOSS_SCENE)
	elif OS.is_debug_build() and progress != null and "debug_scenario" in progress and progress.debug_scenario != "" \
			and progress.debug_scenario != "howto" and progress.debug_scenario != "title":
		get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
	elif OS.is_debug_build() and progress != null and "debug_scenario" in progress and progress.debug_scenario == "howto":
		open_howto.call_deferred()


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		TouchInput.note_touch(t.index, t.pressed, false)
		if t.pressed:
			if sound_icon != null and sound_icon.hit_rect().has_point(t.position):
				sound_icon.toggle()
			elif is_howto_open():
				if get_back_rect().grow(16.0).has_point(t.position):
					close_howto()
			elif get_start_rect().grow(24.0).has_point(t.position):
				start_game()
			elif get_howto_rect().grow(12.0).has_point(t.position):
				open_howto()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		TouchInput.note_touch(d.index, true, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		var kc: int = event.keycode
		if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			start_game()
			get_viewport().set_input_as_handled()
		elif k == KEY_H or kc == KEY_H:
			open_howto()
			get_viewport().set_input_as_handled()
		elif OS.is_debug_build() and (k == KEY_B or kc == KEY_B):
			# Build 015b: debug builds only (editor / native test runs). Release
			# builds reach the boss only by clearing level 2.
			start_boss()
			get_viewport().set_input_as_handled()
		elif k in [KEY_ESCAPE, KEY_BACKSPACE] or kc in [KEY_ESCAPE, KEY_BACKSPACE]:
			close_howto()
			get_viewport().set_input_as_handled()


func get_start_rect() -> Rect2:
	if start_button == null or not start_button.is_visible_in_tree():
		return Rect2()
	return start_button.get_global_rect()


func get_howto_rect() -> Rect2:
	if howto_button == null or not howto_button.is_visible_in_tree():
		return Rect2()
	return howto_button.get_global_rect()


func _rect_of(b: Control) -> Rect2:
	if b == null or not b.is_visible_in_tree():
		return Rect2()
	return b.get_global_rect()


func get_back_rect() -> Rect2:
	if back_button == null or not back_button.is_visible_in_tree():
		return Rect2()
	return back_button.get_global_rect()


func is_howto_open() -> bool:
	return howto_panel != null and howto_panel.visible


func open_howto() -> void:
	if _starting or howto_panel == null or howto_panel.visible:
		return
	howto_panel.visible = true
	Sfx.play(self, "click", -8.0)
	howto_panel.modulate.a = 0.0
	create_tween().tween_property(howto_panel, "modulate:a", 1.0, 0.15)
	_set_menu_visible(false)


func close_howto() -> void:
	if howto_panel == null or not howto_panel.visible:
		return
	howto_panel.visible = false
	Sfx.play(self, "click", -8.0)
	_set_menu_visible(true)


func _set_menu_visible(v: bool) -> void:
	for n in [start_button, howto_button, _press_label, _hiscore_label]:
		if n != null:
			n.visible = v


func start_game() -> void:
	if _starting:
		return
	_starting = true
	Sfx.play(self, "start", -6.0)
	var progress := get_node_or_null("/root/GameProgress")
	if progress != null and progress.has_method("reset_progress"):
		progress.reset_progress()
	close_howto()
	if start_button:
		start_button.disabled = true
	_flash.color = Color(1, 1, 1, 0.0)
	var tw := create_tween()
	tw.tween_property(_flash, "color", Color(1, 1, 1, 0.85), 0.08)
	tw.tween_property(_flash, "color", Color(0, 0, 0, 1.0), 0.18)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))


## Build 015: straight to the boss fight (a fresh run that starts at the boss;
## CONTINUE after beating him goes to level 3). Build 015b: DEBUG BUILDS ONLY
## (B key on the title); there is no menu button any more.
func start_boss() -> void:
	if not OS.is_debug_build():
		return
	if _starting:
		return
	_starting = true
	var progress := get_node_or_null("/root/GameProgress")
	if progress != null and progress.has_method("start_at_boss"):
		progress.start_at_boss()
	close_howto()
	_flash.color = Color(1, 1, 1, 0.0)
	var tw := create_tween()
	tw.tween_property(_flash, "color", Color(1, 0.85, 0.85, 0.85), 0.08)
	tw.tween_property(_flash, "color", Color(0, 0, 0, 1.0), 0.18)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(LevelConfig.BOSS_SCENE))


# ------------------------------------------------------------------ build

func _font(embolden: float, spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = embolden
	f.spacing_glyph = spacing
	return f


func _title_label(text: String, size: int, y: float, h: float, cols: Array, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(1280, h)
	var ls := LabelSettings.new()
	ls.font = _font(1.15, 2)
	ls.font_size = size
	ls.font_color = Color(1, 1, 1)
	ls.outline_size = outline
	ls.outline_color = Color(0.16, 0.05, 0.08)
	ls.shadow_size = 0
	ls.shadow_color = Color(0.05, 0.0, 0.08, 0.85)
	ls.shadow_offset = Vector2(6, 8)
	l.label_settings = ls
	var mat := ShaderMaterial.new()
	mat.shader = TITLE_SHADER
	mat.set_shader_parameter("top_color", cols[0])
	mat.set_shader_parameter("mid_color", cols[1])
	mat.set_shader_parameter("bottom_color", cols[2])
	mat.set_shader_parameter("text_top", h * 0.5 - size * 0.38)
	mat.set_shader_parameter("text_bottom", h * 0.5 + size * 0.38)
	l.material = mat
	_title_mats.append(mat)
	return l


func _build_title() -> void:
	_title_box = Control.new()
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.size = Vector2(1280, 360)
	add_child(_title_box)
	var warm := [Color(1.0, 0.98, 0.66), Color(1.0, 0.74, 0.2), Color(0.93, 0.3, 0.12)]
	_title_box.add_child(_title_label("SAVE THE", 70, 52, 96, warm, 18))
	_title_box.add_child(_title_label("SILLY HUMANS", 124, 128, 150, warm, 22))
	# RECONSIDERED ribbon
	var ribbon := TitleRibbon.new()
	ribbon.position = Vector2(640, 318)
	_title_box.add_child(ribbon)
	var cool := [Color(0.85, 1.0, 1.0), Color(0.45, 0.9, 1.0), Color(0.75, 0.55, 1.0)]
	var sub := _title_label("RECONSIDERED", 42, 288, 60, cool, 10)
	sub.label_settings.font = _font(0.9, 12)
	sub.label_settings.shadow_offset = Vector2(3, 4)
	_title_box.add_child(sub)


func _build_menu() -> void:
	_press_label = Label.new()
	_press_label.text = "PRESS START"
	_press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press_label.position = Vector2(0, 404)
	_press_label.size = Vector2(1280, 44)
	var ls := LabelSettings.new()
	ls.font = _font(0.7, 6)
	ls.font_size = 32
	ls.font_color = Color(1, 1, 0.92)
	ls.outline_size = 8
	ls.outline_color = Color(0.1, 0.03, 0.1)
	_press_label.label_settings = ls
	add_child(_press_label)

	start_button = Button.new()
	start_button.name = "StartButton"
	start_button.text = "START"
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.add_theme_font_override("font", _font(0.8, 6))
	start_button.add_theme_font_size_override("font_size", 40)
	start_button.add_theme_color_override("font_color", Color(1, 1, 1))
	start_button.add_theme_color_override("font_hover_color", Color(1, 1, 0.8))
	start_button.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
	start_button.add_theme_constant_override("outline_size", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.8, 0.3, 0.12, 0.95)
	normal.border_color = Color(1.0, 0.86, 0.45)
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 5)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.92, 0.42, 0.16, 1.0)
	start_button.add_theme_stylebox_override("normal", normal)
	start_button.add_theme_stylebox_override("hover", hover)
	start_button.add_theme_stylebox_override("pressed", hover)
	start_button.add_theme_stylebox_override("disabled", hover)
	start_button.position = Vector2(640 - 140, 456)
	start_button.size = Vector2(280, 78)
	start_button.add_to_group("start_button")
	start_button.pressed.connect(start_game)
	add_child(start_button)

	howto_button = _menu_button("HowToPlayButton", "HOW TO PLAY", 24,
		Color(0.16, 0.12, 0.38, 0.95), Color(0.26, 0.2, 0.55, 1.0), Color(0.55, 0.9, 1.0))
	howto_button.position = Vector2(640 - 140, 548)
	howto_button.size = Vector2(280, 54)
	howto_button.add_to_group("howto_button")
	howto_button.pressed.connect(open_howto)
	add_child(howto_button)

	_hiscore_label = Label.new()
	_hiscore_label.name = "HiScoreLabel"
	_hiscore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hiscore_label.position = Vector2(0, 12)
	_hiscore_label.size = Vector2(1280, 24)
	_hiscore_label.label_settings = PixelFont.settings(2, Color(1.0, 0.82, 0.12))
	var progress := get_node_or_null("/root/GameProgress")
	var hi := int(progress.high_score) if progress != null and "high_score" in progress else 0
	_hiscore_label.text = "HI-SCORE %08d" % hi
	add_child(_hiscore_label)
	add_child(_small_label(COPYRIGHT, 16, Vector2(0, 690), Vector2(1280, 24), HORIZONTAL_ALIGNMENT_CENTER))
	add_child(_small_label(BUILD_LABEL, 16, Vector2(1080, 690), Vector2(180, 24), HORIZONTAL_ALIGNMENT_RIGHT))
	_build_howto()
	# Build 015b: sound ON / LOW / OFF (also the M key anywhere).
	sound_icon = SoundIcon.new()
	sound_icon.name = "SoundIcon"
	sound_icon.position = Vector2(1280 - 56 - 18, 14)
	add_child(sound_icon)


func _menu_button(node_name: String, text: String, font_size: int, bg: Color, bg_hover: Color, border: Color) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font(0.8, 4))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.8))
	b.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.12))
	b.add_theme_constant_override("outline_size", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 5)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg_hover
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", hover)
	return b


const HOWTO_PC := "WASD  —  move   ·   MOUSE  —  aim the reticle\nLEFT CLICK  —  WHIP   ·   cam: hold REC\nRIGHT CLICK  —  GRAB & throw   ·   cam: SWING\nQ / WHEEL / 1-2  —  swap weapon   ·   M  —  sound\nR  —  restart   ·   N / ENTER  —  next level"
const HOWTO_TOUCH := "JOYSTICK (bottom left)  —  move\nBOTTOM-RIGHT  —  WHIP   ·   cam: hold REC\nTOP-RIGHT  —  GRAB   ·   cam: SWING\nTOP-LEFT  —  swap weapon   ·   SPEAKER  —  sound\nWHIP auto-aims  ·  crosshair = weapon reach"
const HOWTO_RULES := "• Herd silly humans into the green SAFE ZONE. Throw POSSESSED humans in to save them too.\n• The CAMP sends humans, the SHEEP DEN breeds sheep. Hit the SAVE TARGET; lose if the rancher falls.\n• LEVEL 3+: 4 possessed together become KARENS: they mob you, convert humans, shut the camp.\n• POWER-UPS never time out. Whip mods stay till you grab another. FIRE: 10 lashes. SHOCKWAVE: 3.\n• MSM CAM (rare): hold REC to film a 39° cone. Filmed humans walk to safety; filmed Karens go VIRAL!\n• Filming drains the BATTERY (spares auto-load, carry 3), breeds sheep, and Karens LOVE it.\n• Two moves per weapon: WHIP / GRAB, or MSM CAM REC / SWING (shove + stun, no damage, no battery).\n• SCORE: 200 per human · 50 per sheep or possessed · 100 per Karen. Sheep speed up each level!\n• RETICLE / crosshair turns GREEN when a target's in range (whip reach or cam cone); RED = nothing to hit.\n• Clear LEVEL 2 to face TRUSTIN JUDEAU (10 hearts). Dodge poutine, don't touch him. Die = retry boss."


func _build_howto() -> void:
	howto_panel = Control.new()
	howto_panel.name = "HowToPlay"
	howto_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	howto_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	howto_panel.visible = false
	add_child(howto_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.06, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	howto_panel.add_child(dim)
	var box := Panel.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(70, 28)
	box.size = Vector2(1140, 664)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.2, 0.95)
	sb.border_color = Color(0.55, 0.9, 1.0)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 8)
	box.add_theme_stylebox_override("panel", sb)
	howto_panel.add_child(box)
	var warm := [Color(1.0, 0.98, 0.66), Color(1.0, 0.74, 0.2), Color(0.93, 0.3, 0.12)]
	var head := _title_label("HOW TO PLAY", 56, 34, 76, warm, 14)
	head.label_settings.shadow_offset = Vector2(4, 5)
	howto_panel.add_child(head)
	howto_panel.add_child(_howto_heading("PC CONTROLS", Vector2(110, 118), Color(1.0, 0.82, 0.12)))
	howto_panel.add_child(_howto_heading("MOBILE CONTROLS", Vector2(660, 118), Color(0.55, 0.9, 1.0)))
	howto_panel.add_child(_howto_body(HOWTO_PC, Vector2(110, 156), Vector2(530, 140), 19))
	howto_panel.add_child(_howto_body(HOWTO_TOUCH, Vector2(660, 156), Vector2(530, 140), 19))
	var line := ColorRect.new()
	line.color = Color(0.55, 0.9, 1.0, 0.55)
	line.position = Vector2(110, 300)
	line.size = Vector2(1060, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	howto_panel.add_child(line)
	howto_panel.add_child(_howto_heading("OBJECTIVE", Vector2(110, 312), Color(1.0, 0.55, 0.12)))
	var rules := _howto_body(HOWTO_RULES, Vector2(110, 346), Vector2(1060, 260), 17)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	howto_panel.add_child(rules)
	back_button = _menu_button("BackButton", "BACK", 30,
		Color(0.8, 0.3, 0.12, 0.95), Color(0.92, 0.42, 0.16, 1.0), Color(1.0, 0.86, 0.45))
	back_button.position = Vector2(640 - 110, 610)
	back_button.size = Vector2(220, 62)
	back_button.add_to_group("back_button")
	back_button.pressed.connect(close_howto)
	howto_panel.add_child(back_button)
	var keys_l := _small_label("ESC / BACKSPACE: BACK", 15, Vector2(110, 646), Vector2(380, 22), HORIZONTAL_ALIGNMENT_LEFT)
	keys_l.label_settings.font_color = Color(0.8, 0.85, 1.0, 0.8)
	howto_panel.add_child(keys_l)
	var keys_r := _small_label("ENTER / SPACE: START", 15, Vector2(790, 646), Vector2(380, 22), HORIZONTAL_ALIGNMENT_RIGHT)
	keys_r.label_settings.font_color = Color(0.8, 0.85, 1.0, 0.8)
	howto_panel.add_child(keys_r)


func _howto_heading(text: String, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.label_settings = PixelFont.settings(3, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _howto_body(text: String, pos: Vector2, sz: Vector2, font_size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = _font(0.45, 1)
	ls.font_size = font_size
	ls.line_spacing = 1
	ls.font_color = Color(0.97, 0.95, 0.9)
	ls.outline_size = 4
	ls.outline_color = Color(0.03, 0.0, 0.08, 0.9)
	l.label_settings = ls
	return l


func _small_label(text: String, size: int, pos: Vector2, sz: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.position = pos
	l.size = sz
	var ls := LabelSettings.new()
	ls.font = _font(0.35, 2)
	ls.font_size = size
	ls.font_color = Color(0.95, 0.92, 0.85, 0.9)
	ls.outline_size = 5
	ls.outline_color = Color(0, 0, 0, 0.8)
	l.label_settings = ls
	return l


func _build_scene_props() -> void:
	# Camp on the left of the field, reusing the in-game camp art.
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	add_child(props)
	var tent := HumanCamp.CampTent.new()
	tent.position = Vector2(150, 560)
	tent.scale = Vector2(1.7, 1.7)
	tent.canvas = Color(0.86, 0.76, 0.56)
	tent.patch = Color(0.86, 0.26, 0.22)
	props.add_child(tent)
	var tent2 := HumanCamp.CampTent.new()
	tent2.position = Vector2(300, 520)
	tent2.scale = Vector2(1.3, 1.3)
	tent2.canvas = Color(0.62, 0.78, 0.74)
	tent2.patch = Color(0.98, 0.78, 0.25)
	props.add_child(tent2)
	var fire := HumanCamp.CampFire.new()
	fire.position = Vector2(270, 600)
	fire.scale = Vector2(1.6, 1.6)
	props.add_child(fire)


func _build_parade() -> void:
	var lane := Node2D.new()
	lane.name = "Parade"
	add_child(lane)
	var human_frames: SpriteFrames = load("res://assets/spriteframes/human_frames.tres")
	var sheep_frames: SpriteFrames = load("res://assets/spriteframes/sheep_frames.tres")
	var rancher_frames: SpriteFrames = load("res://assets/spriteframes/rancher_frames.tres")
	# Silly humans flee right, sheep chase, the rancher brings up the rear.
	var cast := [
		[human_frames, 0.0, 616.0, 1.0], [human_frames, -90.0, 636.0, 1.0],
		[sheep_frames, -260.0, 620.0, 1.0], [sheep_frames, -360.0, 640.0, 1.0],
		[rancher_frames, -560.0, 628.0, 1.0],
		[human_frames, -900.0, 618.0, 1.0], [sheep_frames, -1080.0, 630.0, 1.0],
	]
	for c in cast:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = c[0]
		spr.animation = &"right"
		spr.play()
		spr.scale = Vector2(2, 2)
		spr.position = Vector2(c[1], c[2])
		lane.add_child(spr)
		_parade.append(spr)


# ------------------------------------------------------------------ animate

func _process(delta: float) -> void:
	_t += delta
	if _title_box:
		_title_box.position.y = sin(_t * 1.7) * 5.0
	if _press_label:
		_press_label.visible = fmod(_t, 1.0) < 0.62 or _starting
	var shine := fmod(_t * 520.0, 2600.0) - 400.0
	for m in _title_mats:
		m.set_shader_parameter("shine_x", shine)
	for spr in _parade:
		var s := spr as AnimatedSprite2D
		s.position.x += 95.0 * delta
		if s.position.x > 1360.0:
			s.position.x -= 1360.0 + 900.0
	for i in _clouds.size():
		var c: Vector3 = _clouds[i]
		c.x += 8.0 * c.z * delta
		if c.x > 1450.0:
			c.x = -200.0
		_clouds[i] = c
	queue_redraw()


func _draw() -> void:
	var w := 1280.0
	# sky gradient (indigo → violet → sunset orange at the horizon)
	var sky_cols := [Color(0.06, 0.05, 0.2), Color(0.32, 0.14, 0.4), Color(0.86, 0.38, 0.32), Color(1.0, 0.7, 0.36)]
	var sky_ys := [0.0, 210.0, 360.0, HORIZON]
	for i in 3:
		draw_polygon(
			PackedVector2Array([Vector2(0, sky_ys[i]), Vector2(w, sky_ys[i]), Vector2(w, sky_ys[i + 1]), Vector2(0, sky_ys[i + 1])]),
			PackedColorArray([sky_cols[i], sky_cols[i], sky_cols[i + 1], sky_cols[i + 1]]))
	for s in _stars:
		var a: float = 0.35 + 0.35 * sin(_t * 2.2 + s.z)
		draw_rect(Rect2(Vector2(s.x, s.y), Vector2(2, 2)), Color(1, 1, 0.95, a * (1.0 - s.y / 260.0)))
	# sun with retro bands
	var sun_c := Vector2(1070, HORIZON - 84)
	draw_circle(sun_c, 150.0, Color(1.0, 0.75, 0.4, 0.18))
	draw_circle(sun_c, 112.0, Color(1.0, 0.84, 0.46))
	for b in 5:
		var by := sun_c.y + 18.0 + b * 17.0
		var half := sqrt(maxf(112.0 * 112.0 - pow(by - sun_c.y + 2.0, 2.0), 0.0))
		draw_rect(Rect2(sun_c.x - half, by, half * 2.0, 3.0 + b * 1.8), Color(0.93, 0.5, 0.36))
	# clouds
	for c in _clouds:
		_cloud(Vector2(c.x, c.y), c.z)
	# far mountains
	_ridge(HORIZON - 40.0, 90.0, 0.011, Color(0.36, 0.2, 0.42), 3.0)
	_ridge(HORIZON - 10.0, 60.0, 0.017, Color(0.22, 0.17, 0.32), 9.0)
	# tree line
	var tl_y := HORIZON + 8.0
	draw_rect(Rect2(0, tl_y - 4, w, 30), Color(0.1, 0.2, 0.16))
	for i in 46:
		var x := float(i) * 29.0 + fmod(float(i * 37), 13.0)
		var hgt := 34.0 + fmod(float(i * 53), 26.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 14, tl_y + 10), Vector2(x, tl_y - hgt), Vector2(x + 14, tl_y + 10)]), Color(0.08, 0.17, 0.13))
	# field
	var g0 := Color(0.24, 0.42, 0.2)
	var g1 := Color(0.16, 0.32, 0.14)
	draw_polygon(PackedVector2Array([Vector2(0, tl_y + 20), Vector2(w, tl_y + 20), Vector2(w, 720), Vector2(0, 720)]),
		PackedColorArray([g0, g0, g1, g1]))
	# light stripes on the field (mowed look)
	for i in 6:
		var y := tl_y + 40.0 + i * 42.0
		draw_rect(Rect2(0, y, w, 10.0 + i * 2.0), Color(0.36, 0.56, 0.26, 0.18))
	# winding dirt path toward the horizon
	var path := PackedVector2Array()
	var path_r := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		var y := lerpf(tl_y + 22.0, 720.0, u)
		var cx := 700.0 + sin(u * 3.2) * 140.0 * u
		var hw := lerpf(10.0, 120.0, u * u)
		path.append(Vector2(cx - hw, y))
		path_r.insert(0, Vector2(cx + hw, y))
	path.append_array(path_r)
	draw_colored_polygon(path, Color(0.66, 0.5, 0.3, 0.9))
	# grass tufts
	for i in 60:
		var x := fmod(float(i) * 97.3, w)
		var y := tl_y + 30.0 + fmod(float(i) * 53.7, 720.0 - tl_y - 40.0)
		draw_line(Vector2(x, y), Vector2(x - 3, y - 7), Color(0.42, 0.66, 0.3, 0.7), 2.0)
		draw_line(Vector2(x + 3, y), Vector2(x + 5, y - 8), Color(0.42, 0.66, 0.3, 0.7), 2.0)
	# darken top + bottom for text contrast (vignette)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 380), Vector2(0, 380)]),
		PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	draw_polygon(PackedVector2Array([Vector2(0, 620), Vector2(w, 620), Vector2(w, 720), Vector2(0, 720)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5)]))


func _ridge(base_y: float, amp: float, freq: float, col: Color, phase: float) -> void:
	var pts := PackedVector2Array([Vector2(0, base_y + 40)])
	for i in 65:
		var x := float(i) * 20.0
		var y := base_y - amp * (0.5 + 0.3 * sin(x * freq + phase) + 0.2 * sin(x * freq * 2.7 + phase * 2.0))
		pts.append(Vector2(x, y))
	pts.append(Vector2(1280, base_y + 40))
	draw_colored_polygon(pts, col)


func _cloud(p: Vector2, s: float) -> void:
	var col := Color(1.0, 0.72, 0.62, 0.32)
	for k in 4:
		var off := Vector2(k * 34.0 * s - 50.0 * s, sin(k * 1.7) * 6.0 * s)
		_ellipse(p + off, Vector2(42.0 * s, 13.0 * s), col)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := float(i) / 20.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


## Dark slanted banner behind "RECONSIDERED".
class TitleRibbon extends Node2D:
	func _draw() -> void:
		var w := 300.0
		var h := 30.0
		var body := PackedVector2Array([Vector2(-w - 18, -h), Vector2(w + 18, -h), Vector2(w - 2, h), Vector2(-w - 38, h)])
		draw_colored_polygon(PackedVector2Array([Vector2(-w - 12, -h + 8), Vector2(w + 24, -h + 8), Vector2(w + 4, h + 8), Vector2(-w - 32, h + 8)]), Color(0, 0, 0, 0.45))
		draw_colored_polygon(body, Color(0.12, 0.06, 0.24, 0.92))
		draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), Color(0.55, 0.9, 1.0, 0.9), 3.0, true)
		# little tails
		draw_colored_polygon(PackedVector2Array([Vector2(-w - 38, h), Vector2(-w - 70, h + 14), Vector2(-w - 52, h - 4)]), Color(0.08, 0.04, 0.16, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(w - 2, h), Vector2(w + 34, h + 14), Vector2(w + 18, h - 4)]), Color(0.08, 0.04, 0.16, 0.9))
