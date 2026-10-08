class_name SoundIcon
extends Control
## Build 015b: small pixel speaker button (ON = 2 waves, LOW = 1 wave, OFF = X).
## Tapping / clicking cycles GameAudio's setting. The HUD shows it on touch
## layouts (top, right of the swap wedge); the title screen shows it always.
## Touch taps are routed here by touch_controls.gd / title_screen.gd through the
## "sound_button" group, mouse clicks through gui_input.

const SIZE := Vector2(56, 44)


func _ready() -> void:
	add_to_group("sound_button")
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ga := get_node_or_null("/root/GameAudio")
	if ga != null and ga.has_signal("setting_changed"):
		ga.setting_changed.connect(func(_i: int) -> void: queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle()
		accept_event()


func toggle() -> void:
	var ga := get_node_or_null("/root/GameAudio")
	if ga != null:
		ga.cycle()
	queue_redraw()


func hit_rect() -> Rect2:
	return get_global_rect().grow(8.0) if is_visible_in_tree() else Rect2()


func _setting() -> int:
	var ga := get_node_or_null("/root/GameAudio")
	return int(ga.setting) if ga != null else 0


func _draw() -> void:
	var ink := Color(0.06, 0.03, 0.08, 0.92)
	var fg := Color(1, 1, 1)
	draw_rect(Rect2(Vector2.ZERO, SIZE), ink)
	draw_rect(Rect2(Vector2(2, 2), SIZE - Vector2(4, 4)), Color(1.0, 0.82, 0.12), false, 2.0)
	# speaker: box + cone
	draw_rect(Rect2(Vector2(11, 17), Vector2(8, 10)), fg)
	draw_colored_polygon(PackedVector2Array([Vector2(19, 17), Vector2(28, 9), Vector2(28, 35), Vector2(19, 27)]), fg)
	var s := _setting()
	if s == 2:
		var red := Color(1.0, 0.38, 0.3)
		draw_line(Vector2(33, 15), Vector2(45, 29), red, 4.0)
		draw_line(Vector2(45, 15), Vector2(33, 29), red, 4.0)
		return
	draw_arc(Vector2(28, 22), 8.0, -0.9, 0.9, 8, fg, 3.0)
	if s == 0:
		draw_arc(Vector2(28, 22), 15.0, -0.9, 0.9, 10, fg, 3.0)
