extends Control
## Build 027: the victory ending, shown after beating the final boss (Donald
## Rump). Three beats:
##   1. "celebrate" - the saved humans cheer in the pasture, fireworks, score
##   2. "credits"   - a credits roll (Robert J. Morris, Echelon Publishers Group,
##                    "Code & design assist: Ewan Shepherd, LLM", ...)
##   3. "choice"    - ENDLESS MODE (on to level 30, run carried) or RETURN TO TITLE
## Any key / click / tap skips to the next beat. Everything is drawn in code
## from the game's own sprites.

const CELEBRATE_TIME := 7.0
const CREDITS_SPEED := 46.0        ## px/s
const TITLE_SCENE := "res://scenes/Title.tscn"
const HUMAN_FRAMES := preload("res://assets/spriteframes/human_frames.tres")
const KAREN_FRAMES := preload("res://assets/spriteframes/karen_frames.tres")
const RANCHER_FRAMES := preload("res://assets/spriteframes/rancher_frames.tres")
const SHEEP_FRAMES := preload("res://assets/spriteframes/sheep_frames.tres")

const CREDITS := [
	["SAVE THE SILLY HUMANS", 5, Color(1.0, 0.86, 0.25)],
	["", 2, Color.WHITE],
	["A GAME BY", 2, Color(0.7, 0.85, 1.0)],
	["ROBERT J. MORRIS", 4, Color.WHITE],
	["", 2, Color.WHITE],
	["PUBLISHED BY", 2, Color(0.7, 0.85, 1.0)],
	["ECHELON PUBLISHERS GROUP", 3, Color.WHITE],
	["CALGARY, ALBERTA", 2, Color(0.85, 0.85, 0.9)],
	["", 2, Color.WHITE],
	["CODE & DESIGN ASSIST: EWAN SHEPHERD, LLM", 3, Color.WHITE],
	["", 2, Color.WHITE],
	["ENGINE", 2, Color(0.7, 0.85, 1.0)],
	["GODOT 4.7.2", 3, Color.WHITE],
	["", 2, Color.WHITE],
	["ORIGINAL GENERATED ART, MUSIC AND SOUND", 2, Color(0.85, 0.85, 0.9)],
	["", 2, Color.WHITE],
	["THE BOSSES (CARTOON PARODIES, ALL IN GOOD FUN)", 2, Color(0.7, 0.85, 1.0)],
	["TRUSTIN JUDEAU", 3, Color(1.0, 0.75, 0.75)],
	["HUVAL YARHEYHEY", 3, Color(1.0, 0.75, 0.75)],
	["BEORGE KUSH JR.", 3, Color(1.0, 0.75, 0.75)],
	["SHLAUS KWOBB", 3, Color(1.0, 0.75, 0.75)],
	["GILL BATES", 3, Color(1.0, 0.75, 0.75)],
	["NANCY PELOTTO", 3, Color(1.0, 0.75, 0.75)],
	["REANALD ROGAN", 3, Color(1.0, 0.75, 0.75)],
	["ZELODYMER VIOLENTSKY", 3, Color(1.0, 0.75, 0.75)],
	["VLADIMIR PUDDIN", 3, Color(1.0, 0.75, 0.75)],
	["DONALD RUMP", 3, Color(1.0, 0.75, 0.75)],
	["", 2, Color.WHITE],
	["AND THE SILLY HUMANS, AS THEMSELVES", 2, Color(0.85, 0.85, 0.9)],
	["", 3, Color.WHITE],
	["THANKS FOR PLAYING!", 4, Color(1.0, 0.86, 0.25)],
]

var phase := "celebrate"
var _t := 0.0
var _phase_t := 0.0
var _rng := RandomNumberGenerator.new()
var _sky: SkyDraw
var _crowd: Array[AnimatedSprite2D] = []
var _crowd_base: Array[Vector2] = []
var _title: Label
var _sub: Label
var _score: Label
var _hint: Label
var _roll: VBoxContainer
var _choice: VBoxContainer
var endless_button: Button
var title_button: Button
var _chosen := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 2027
	_sky = SkyDraw.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	_build_crowd()
	_title = _label("YOU SAVED THE SILLY HUMANS!", 5, Color(1.0, 0.86, 0.25), Vector2(0, 70))
	_sub = _label("DONALD RUMP HAS BEEN BENCHED. THE PASTURE IS SAFE!", 2, Color.WHITE, Vector2(0, 150))
	var gp := get_node_or_null("/root/GameProgress")
	var sc: int = int(gp.score) if gp != null and "score" in gp else 0
	if gp != null and gp.has_method("commit_high_score"):
		gp.commit_high_score()
	InitialsEntry.maybe_show.call_deferred(self, true)   # build 028: top-10 initials after the final win
	var hi: int = int(gp.high_score) if gp != null and "high_score" in gp else sc
	_score = _label("FINAL SCORE  %d     BEST  %d" % [sc, maxi(hi, sc)], 3, Color(0.75, 1.0, 0.75), Vector2(0, 190))
	_hint = _label("PRESS ANY KEY OR TAP TO CONTINUE", 2, Color(0.85, 0.9, 1.0, 0.8), Vector2(0, 676))
	_build_roll()
	_build_choice()
	Sfx.play(self, "fanfare", -4.0)
	var ga := get_node_or_null("/root/GameAudio")
	if ga != null and ga.has_method("play_music"):
		ga.play_music("bonus")


func _label(text: String, scale: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = PixelFont.settings(scale, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(1280, 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build_crowd() -> void:
	var sets: Array[SpriteFrames] = [HUMAN_FRAMES, HUMAN_FRAMES, KAREN_FRAMES, HUMAN_FRAMES]
	for i in 22:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = sets[i % sets.size()]
		s.animation = &"down"
		s.play()
		s.speed_scale = _rng.randf_range(0.7, 1.3)
		s.scale = Vector2(2.6, 2.6)
		var row := i / 11
		var x := 110.0 + (i % 11) * 106.0 + (53.0 if row == 1 else 0.0) + _rng.randf_range(-12, 12)
		var y := 430.0 + row * 90.0 + _rng.randf_range(-8, 8)
		s.position = Vector2(x, y)
		_sky.add_child(s)
		_crowd.append(s)
		_crowd_base.append(s.position)
	var r := AnimatedSprite2D.new()
	r.sprite_frames = RANCHER_FRAMES
	r.animation = &"down"
	r.play()
	r.scale = Vector2(3.4, 3.4)
	r.position = Vector2(640, 330)
	_sky.add_child(r)
	_crowd.append(r)
	_crowd_base.append(r.position)
	for k in 3:
		var sh := AnimatedSprite2D.new()
		sh.sprite_frames = SHEEP_FRAMES
		sh.animation = &"left" if k % 2 else &"right"
		sh.play()
		sh.scale = Vector2(2.2, 2.2)
		sh.position = Vector2(180.0 + k * 460.0, 640.0)
		sh.modulate = Color(1, 1, 1, 0.95)
		_sky.add_child(sh)


func _build_roll() -> void:
	_roll = VBoxContainer.new()
	_roll.name = "CreditsRoll"
	_roll.add_theme_constant_override("separation", 10)
	_roll.position = Vector2(0, 760)
	_roll.size = Vector2(1280, 10)
	_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.visible = false
	for c in CREDITS:
		var l := Label.new()
		l.text = String(c[0]) if String(c[0]) != "" else " "
		l.label_settings = PixelFont.settings(int(c[1]), c[2] as Color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(1280, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_roll.add_child(l)
	add_child(_roll)


func credits_text() -> String:
	var out: PackedStringArray = []
	for c in CREDITS:
		out.append(String(c[0]))
	return "\n".join(out)


func _build_choice() -> void:
	_choice = VBoxContainer.new()
	_choice.name = "Choice"
	_choice.add_theme_constant_override("separation", 22)
	_choice.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice.position = Vector2(390, 300)
	_choice.size = Vector2(500, 260)
	_choice.visible = false
	add_child(_choice)
	var q := Label.new()
	q.text = "WHAT NEXT, RANCHER?"
	q.label_settings = PixelFont.settings(4, Color(1.0, 0.86, 0.25))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice.add_child(q)
	endless_button = _button("ENDLESS MODE", "Keep your score, hearts and gear and play on from level %d." % (LevelConfig.FINAL_BOSS_AFTER_LEVEL + 1))
	endless_button.pressed.connect(choose_endless)
	title_button = _button("RETURN TO TITLE", "Finish the run here.")
	title_button.pressed.connect(choose_title)


func _button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(500, 78)
	b.add_theme_font_override("font", PixelFont.get_font())
	b.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.24, 0.95)
	sb.border_color = Color(1.0, 0.86, 0.25)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.3, 0.22, 0.5, 0.98)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("focus", sh)
	b.add_theme_stylebox_override("pressed", sh)
	_choice.add_child(b)
	return b


func _process(delta: float) -> void:
	_t += delta
	if not InitialsEntry.is_open(get_tree()):   # build 028: hold the beat while initials are entered
		_phase_t += delta
	_sky.t = _t
	_sky.fireworks = phase == "celebrate" or phase == "credits"
	_sky.queue_redraw()
	for i in _crowd.size():
		var jump := absf(sin(_t * (5.0 + (i % 5) * 0.7) + i * 1.3)) * (26.0 if i < _crowd.size() - 1 else 16.0)
		_crowd[i].position = _crowd_base[i] - Vector2(0, jump)
	match phase:
		"celebrate":
			if _phase_t >= CELEBRATE_TIME:
				skip()
		"credits":
			_roll.position.y -= CREDITS_SPEED * delta
			if _roll.position.y + _roll.size.y < 40.0:
				skip()
	_hint.visible = phase != "choice"


func _unhandled_input(event: InputEvent) -> void:
	if phase == "choice":
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true
	elif event is InputEventScreenTouch and event.pressed:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		skip()


## Next beat (tests / bots / any key).
func skip() -> void:
	match phase:
		"celebrate":
			phase = "credits"
			_phase_t = 0.0
			_title.visible = false
			_sub.visible = false
			_score.visible = false
			_roll.visible = true
			_roll.position.y = 730.0
			_sky.dim = 0.55
		"credits":
			phase = "choice"
			_phase_t = 0.0
			_roll.visible = false
			_choice.visible = true
			_title.visible = true
			_title.text = "THE END?"
			endless_button.grab_focus()


func choose_endless() -> void:
	if _chosen:
		return
	_chosen = true
	var gp := get_node_or_null("/root/GameProgress")
	var next := LevelConfig.GAME_SCENE
	if gp != null and gp.has_method("continue_endless"):
		next = gp.continue_endless()
	get_tree().change_scene_to_file.call_deferred(next)


func choose_title() -> void:
	if _chosen:
		return
	_chosen = true
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_method("finish_game_to_title"):
		gp.finish_game_to_title()
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)


## Sunset pasture + fireworks, drawn.
class SkyDraw extends Control:
	var t := 0.0
	var fireworks := true
	var dim := 0.0
	var _bursts: Array = []
	var _rng := RandomNumberGenerator.new()
	var _next := 0.0

	func _init() -> void:
		_rng.seed = 9027

	func _draw() -> void:
		var w := 1280.0
		for i in 24:
			var k := i / 24.0
			var c := Color(0.16, 0.12, 0.38).lerp(Color(1.0, 0.55, 0.35), k)
			draw_rect(Rect2(0, i * 16.0, w, 17.0), c)
		draw_circle(Vector2(980, 330), 70.0, Color(1.0, 0.85, 0.45, 0.9))
		draw_rect(Rect2(0, 370, w, 350), Color(0.3, 0.62, 0.28))
		for i in 18:
			var x := float(i) * 76.0
			draw_circle(Vector2(x, 372), 44.0, Color(0.26, 0.55, 0.25))
		draw_rect(Rect2(0, 600, w, 120), Color(0.36, 0.68, 0.3))
		# the safe-pen fence
		for i in 33:
			var x := 10.0 + i * 39.0
			draw_rect(Rect2(x, 380, 6, 34), Color(0.5, 0.33, 0.18))
		draw_rect(Rect2(0, 388, w, 5), Color(0.6, 0.42, 0.24))
		draw_rect(Rect2(0, 402, w, 5), Color(0.6, 0.42, 0.24))
		# bunting
		for i in 26:
			var x := i * 50.0
			var cols := [Color(1, 0.3, 0.3), Color(1, 0.85, 0.3), Color(0.4, 0.8, 1.0), Color(0.5, 1, 0.5)]
			draw_colored_polygon(PackedVector2Array([Vector2(x, 240), Vector2(x + 40, 240), Vector2(x + 20, 266)]), cols[i % 4])
		draw_line(Vector2(0, 240), Vector2(w, 240), Color(0.95, 0.95, 0.9), 2.0)
		if fireworks:
			_fireworks()
		if dim > 0.0:
			draw_rect(Rect2(0, 0, w, 720), Color(0.02, 0.02, 0.08, dim))

	func _fireworks() -> void:
		if t >= _next:
			_next = t + _rng.randf_range(0.25, 0.6)
			var cols := [Color(1, 0.4, 0.4), Color(1, 0.9, 0.4), Color(0.5, 0.85, 1.0), Color(0.6, 1.0, 0.6), Color(1, 0.6, 1.0)]
			_bursts.append({"c": Vector2(_rng.randf_range(120, 1160), _rng.randf_range(60, 230)), "t0": t, "col": cols[_rng.randi() % cols.size()]})
		var keep: Array = []
		for b in _bursts:
			var age: float = t - float(b["t0"])
			if age > 1.4:
				continue
			keep.append(b)
			var c: Vector2 = b["c"]
			var col: Color = b["col"]
			col.a = clampf(1.4 - age, 0.0, 1.0)
			for i in 16:
				var a := TAU * i / 16.0
				var r := 18.0 + age * 90.0
				var p := c + Vector2(cos(a), sin(a)) * r + Vector2(0, age * age * 30.0)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col)
		_bursts = keep
