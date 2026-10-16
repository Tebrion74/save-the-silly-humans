class_name InitialsEntry
extends CanvasLayer
## Build 028: arcade "ENTER YOUR INITIALS" screen for the top-10 table.
## PC: UP/DOWN or W/S cycle the letter, LEFT/RIGHT move, ENTER confirms,
##     typing a letter sets it and moves on, BACKSPACE steps back.
## Touch (and mouse): tap the arrows above/below each letter, the side
##     arrows, and OK.
## It swallows all input while open, so the game-over / ending screens
## underneath can't be triggered by the same keys.

signal finished(rank: int)

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ.-"
const SLOT_X := [520.0, 640.0, 760.0]
const SLOT_Y := 360.0

var letters: Array = [0, 0, 0]       ## indices into LETTERS
var slot := 0
var points := 0
var level := 1
var cleared := false
var rank := -1
var done := false
var _t := 0.0
var _done_t := 0.0
var _view: Control


## Show the entry screen over the current scene when this run's score makes
## the top 10. Returns the screen, or null when it isn't needed.
static func maybe_show(host: Node, is_cleared := false) -> InitialsEntry:
	if host == null or not host.is_inside_tree():
		return null
	var gp := host.get_tree().root.get_node_or_null("GameProgress")
	if gp == null or not gp.has_method("needs_initials") or not gp.needs_initials():
		return null
	var e := InitialsEntry.new()
	e.points = int(gp.score)
	e.level = int(gp.current_level)
	e.cleared = is_cleared
	var cs := host.get_tree().current_scene
	(cs if cs != null else host).add_child(e)
	return e


static func is_open(tree: SceneTree) -> bool:
	for n in tree.get_nodes_in_group("initials_entry"):
		if is_instance_valid(n) and not n.done:
			return true
	return false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("initials_entry")
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP     # blocks the end-panel buttons underneath
	_view.draw.connect(_draw_view)
	add_child(_view)
	Sfx.play(self, "fanfare", -6.0)


func initials() -> String:
	var s := ""
	for i in letters:
		s += LETTERS[int(i)]
	return s


func cycle(d: int) -> void:
	letters[slot] = posmod(int(letters[slot]) + d, LETTERS.length())
	Sfx.play(self, "click", -10.0)


func move(d: int) -> void:
	slot = clampi(slot + d, 0, 2)


func type_letter(ch: String) -> void:
	var i := LETTERS.find(ch.to_upper())
	if i < 0:
		return
	letters[slot] = i
	if slot < 2:
		slot += 1


func confirm() -> void:
	if done:
		return
	done = true
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_method("submit_initials"):
		rank = gp.submit_initials(initials(), points, level, cleared)
	Sfx.play(self, "save", -4.0)
	_done_t = 0.0


func _input(event: InputEvent) -> void:
	if done:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		var kc: int = k.keycode if k.keycode != 0 else k.physical_keycode
		match kc:
			KEY_UP, KEY_W:
				cycle(-1)
			KEY_DOWN, KEY_S:
				cycle(1)
			KEY_LEFT:
				move(-1)
			KEY_RIGHT:
				move(1)
			KEY_BACKSPACE:
				move(-1)
			KEY_ENTER, KEY_KP_ENTER:
				if not k.echo:
					confirm()
			KEY_PERIOD:
				type_letter(".")
			KEY_MINUS:
				type_letter("-")
			_:
				if not k.echo and kc >= KEY_A and kc <= KEY_Z:
					type_letter(char(kc))
	elif event is InputEventScreenTouch and event.pressed:
		_tap((event as InputEventScreenTouch).position)
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_tap((event as InputEventMouseButton).position)
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP: cycle(-1)
			JOY_BUTTON_DPAD_DOWN: cycle(1)
			JOY_BUTTON_DPAD_LEFT: move(-1)
			JOY_BUTTON_DPAD_RIGHT: move(1)
			JOY_BUTTON_A, JOY_BUTTON_START: confirm()
	get_viewport().set_input_as_handled()


## Touch targets (viewport coords), big enough for a thumb.
func up_rect(i: int) -> Rect2:
	return Rect2(SLOT_X[i] - 50, SLOT_Y - 150, 100, 80)


func down_rect(i: int) -> Rect2:
	return Rect2(SLOT_X[i] - 50, SLOT_Y + 70, 100, 80)


func left_rect() -> Rect2:
	return Rect2(300, SLOT_Y - 50, 100, 100)


func right_rect() -> Rect2:
	return Rect2(880, SLOT_Y - 50, 100, 100)


func ok_rect() -> Rect2:
	return Rect2(540, 560, 200, 76)


func _tap(p: Vector2) -> void:
	for i in 3:
		if up_rect(i).has_point(p):
			slot = i; cycle(-1); return
		if down_rect(i).has_point(p):
			slot = i; cycle(1); return
		if Rect2(SLOT_X[i] - 50, SLOT_Y - 60, 100, 120).has_point(p):
			slot = i; return
	if left_rect().has_point(p):
		move(-1)
	elif right_rect().has_point(p):
		move(1)
	elif ok_rect().has_point(p):
		confirm()


func _process(delta: float) -> void:
	_t += delta
	if done:
		_done_t += delta
		if _done_t >= 1.6:
			finished.emit(rank)
			queue_free()
	_view.queue_redraw()


func _tri(c: Vector2, up: bool, col: Color) -> void:
	var h := 26.0 if up else -26.0
	_view.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(-32, h * 0.6), c + Vector2(32, h * 0.6)]), col)


func _txt(s: String, y: float, size: int, col: Color) -> void:
	var f := PixelFont.get_font()
	_view.draw_string(f, Vector2(4, y + 4), s, HORIZONTAL_ALIGNMENT_CENTER, 1280, size, Color(0, 0, 0, 0.9))
	_view.draw_string(f, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, 1280, size, col)


func _draw_view() -> void:
	var f := PixelFont.get_font()
	_view.draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.08, 0.93))
	for y in range(0, 720, 4):
		_view.draw_rect(Rect2(0, y, 1280, 1), Color(1, 1, 1, 0.03))
	var hue := fmod(_t * 0.6, 1.0)
	_txt("NEW HIGH SCORE!", 92, 60, Color.from_hsv(hue, 0.6, 1.0))
	_txt("SCORE %08d    LEVEL %d%s" % [points, level, "  (CLEARED)" if cleared else ""], 150, 30, Color.WHITE)
	if done:
		_txt("RANK %d!" % (rank + 1) if rank >= 0 else "SAVED", 400, 80, Color(1.0, 0.86, 0.2))
		_txt(initials(), 500, 60, Color(0.55, 1.0, 0.5))
		return
	_txt("ENTER YOUR INITIALS", 196, 30, Color(1.0, 0.6, 0.9))
	for i in 3:
		var sel := i == slot
		var col := Color(1.0, 0.86, 0.2) if sel else Color(0.75, 0.8, 0.95)
		_tri(up_rect(i).get_center(), true, col if sel else col.darkened(0.4))
		_tri(down_rect(i).get_center(), false, col if sel else col.darkened(0.4))
		if sel:
			_view.draw_rect(Rect2(SLOT_X[i] - 46, SLOT_Y - 56, 92, 112), Color(1.0, 0.86, 0.2, 0.18 + 0.12 * sin(_t * 8.0)))
			_view.draw_rect(Rect2(SLOT_X[i] - 46, SLOT_Y + 48, 92, 8), Color(1.0, 0.86, 0.2) if fmod(_t, 0.5) < 0.3 else Color(1.0, 0.5, 0.2))
		var ch := LETTERS[int(letters[i])]
		_view.draw_string(f, Vector2(SLOT_X[i] - 36 + 5, SLOT_Y + 40 + 5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 100, Color(0, 0, 0, 0.9))
		_view.draw_string(f, Vector2(SLOT_X[i] - 36, SLOT_Y + 40), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 100, col)
	# side arrows
	var lc := left_rect().get_center()
	var rc := right_rect().get_center()
	_view.draw_colored_polygon(PackedVector2Array([lc + Vector2(-28, 0), lc + Vector2(20, -34), lc + Vector2(20, 34)]), Color(0.6, 0.85, 1.0))
	_view.draw_colored_polygon(PackedVector2Array([rc + Vector2(28, 0), rc + Vector2(-20, -34), rc + Vector2(-20, 34)]), Color(0.6, 0.85, 1.0))
	var ok := ok_rect()
	_view.draw_rect(ok, Color(0.2, 0.62, 0.25))
	_view.draw_rect(ok, Color(0.75, 1.0, 0.7), false, 4.0)
	_view.draw_string(f, Vector2(ok.position.x, ok.position.y + 54), "OK", HORIZONTAL_ALIGNMENT_CENTER, ok.size.x, 50, Color.WHITE)
	var ti := get_node_or_null("/root/TouchInput")
	if ti != null and bool(ti.active):
		_txt("TAP THE ARROWS TO PICK LETTERS, THEN OK", 690, 20, Color(0.85, 0.9, 1.0))
	else:
		_txt("UP/DOWN OR W/S: LETTER   LEFT/RIGHT: MOVE   TYPE A LETTER   ENTER: OK", 690, 20, Color(0.85, 0.9, 1.0))
