extends Node
## Autoload MouseAim (build 020). PC mouse aim that can't escape the game.
##
## 019 and earlier: the reticle followed the OS pointer. When the pointer left
## the canvas (fast flicks, the page around the game iframe, a second monitor)
## the reticle vanished and aiming stopped, and a button released out there
## never reached Godot, so the whip / grab action stayed "pressed" and every
## later click was ignored (is_action_just_pressed never fired again).
##
## Now, while a round is being played on PC (never on touch):
##   web      Pointer Lock on the canvas (Input.MOUSE_MODE_CAPTURED). The OS
##            pointer is gone; a virtual cursor moves by the raw mouse deltas
##            (movementX/Y -> InputEventMouseMotion.relative) and is clamped to
##            the game view, so it can never leave. ESC (the browser's own
##            pointer-lock exit), alt-tab or a lost focus drop the lock: the
##            game pauses behind a "CLICK TO RESUME" prompt; a click re-locks.
##            If the browser refuses the lock, the game keeps running with
##            the plain pointer (clamped at the edge, buttons self-heal) and
##            asks again on the next click.
##   desktop  Input.MOUSE_MODE_CONFINED_HIDDEN: the OS pointer is confined to
##            the window and hidden; the reticle is drawn at it.
## Touch / mobile: untouched (TouchInput.active -> pointer visible, no lock).

const LOCK_GRACE := 0.6          ## s to wait for the browser to grant the lock
const PROMPT_LAYER := 120
const EDGE_MARGIN := 10.0       ## keep the reticle fully on screen

var web := OS.has_feature("web")
## Set every frame by the reticle: a PC round is being played.
var want := false
## Virtual cursor (viewport / screen coordinates).
var cursor := Vector2(640, 360)
var locked := false
var prompt_shown := false
var fallback := false            ## lock refused: plain pointer mode
var lock_requests := 0           ## tests / diagnostics
var _was_locked := false
var _request_t := -1.0
var _want_seen_t := -1.0
var _paused_by_us := false
var _layer: CanvasLayer
var _prompt: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_prompt()


## Called by the reticle each frame (true only during PC gameplay).
func set_want(w: bool) -> void:
	want = w and not TouchInput.active


var _unwant_t := 0.0
const RELEASE_GRACE := 0.4      ## keep the lock across scene swaps


var _dbg_last := ""


func _dbg() -> void:
	if not OS.is_debug_build():
		return
	var st := "want=%d locked=%d prompt=%d fallback=%d paused=%d req=%d" % [int(want), int(locked), int(prompt_shown), int(fallback), int(get_tree().paused), lock_requests]
	if st != _dbg_last:
		_dbg_last = st
		print("MOUSEAIM ", st)


func _process(delta: float) -> void:
	_dbg()
	if not want:
		if prompt_shown:
			_show_prompt(false)
		_unwant_t += delta
		if _unwant_t >= RELEASE_GRACE or TouchInput.active:
			_release()
		return
	_unwant_t = 0.0
	if _want_seen_t < 0.0:
		_want_seen_t = 0.0
		cursor = _real_mouse()
	if not web:
		if Input.mouse_mode != Input.MOUSE_MODE_CONFINED_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		locked = true
		cursor = _real_mouse()
		return
	locked = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if locked:
		_was_locked = true
		fallback = false
		_request_t = -1.0
		if prompt_shown:
			_show_prompt(false)
		return
	# not locked
	if _was_locked:
		# lost it (ESC / alt-tab / focus): pause behind the prompt
		_was_locked = false
		TouchInput.release_held_input()
		_show_prompt(true)
		return
	if prompt_shown:
		return
	if _request_t < 0.0 and not fallback:
		_request_lock()
	elif _request_t >= 0.0:
		_request_t += delta
		if _request_t > LOCK_GRACE:
			_request_t = -1.0
			fallback = true
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if fallback:
		if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		cursor = _real_mouse()


func _request_lock() -> void:
	lock_requests += 1
	_request_t = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _real_mouse() -> Vector2:
	var vp := get_viewport()
	return _clamp(vp.get_mouse_position())


func _clamp(p: Vector2) -> Vector2:
	var r := get_viewport().get_visible_rect().grow(-EDGE_MARGIN)
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


func _input(event: InputEvent) -> void:
	if not want:
		return
	if event is InputEventMouseMotion and web and locked:
		cursor = _clamp(cursor + (event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if prompt_shown:
			# the resume click only re-locks; it must not whip
			get_viewport().set_input_as_handled()
			Input.action_release(&"whip")
			Input.action_release(&"whip_grab")
			_show_prompt(false)
			cursor = _clamp((event as InputEventMouseButton).position) if not web else cursor
			_request_lock()
		elif web and fallback:
			_request_lock()   # try again on every click (still whips)


func _show_prompt(on: bool) -> void:
	prompt_shown = on
	if _prompt != null:
		_prompt.visible = on
	if on:
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_us = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false


func _release() -> void:
	_want_seen_t = -1.0
	_request_t = -1.0
	_was_locked = false
	fallback = false
	locked = false
	if prompt_shown:
		_show_prompt(false)
	if Input.mouse_mode in [Input.MOUSE_MODE_CAPTURED, Input.MOUSE_MODE_CONFINED_HIDDEN, Input.MOUSE_MODE_CONFINED]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Screen (viewport) position of the PC aim point.
func screen_pos() -> Vector2:
	if want and ((web and locked) or (not web)):
		return cursor
	return _real_mouse()


## World position of the PC aim point for a CanvasItem in the game world.
func world_pos(node: CanvasItem) -> Vector2:
	return node.get_canvas_transform().affine_inverse() * screen_pos()


func _build_prompt() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = PROMPT_LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var c := ColorRect.new()
	c.color = Color(0.03, 0.02, 0.06, 0.62)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	_layer.add_child(c)
	var l := Label.new()
	l.text = "PAUSED\nCLICK TO RESUME"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ls := LabelSettings.new()
	ls.font_size = 44
	ls.font_color = Color(1.0, 0.86, 0.3)
	ls.outline_size = 10
	ls.outline_color = Color(0.06, 0.03, 0.08)
	l.label_settings = ls
	c.add_child(l)
	var s := Label.new()
	s.text = "the mouse is locked to the game while you play  ·  ESC frees it"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.anchor_left = 0.0
	s.anchor_right = 1.0
	s.anchor_top = 1.0
	s.anchor_bottom = 1.0
	s.offset_left = 0.0
	s.offset_right = 0.0
	s.offset_top = -110.0
	s.offset_bottom = -80.0
	var ss := LabelSettings.new()
	ss.font_size = 20
	ss.font_color = Color(0.9, 0.92, 1.0)
	ss.outline_size = 6
	ss.outline_color = Color(0.06, 0.03, 0.08)
	s.label_settings = ss
	c.add_child(s)
	_prompt = c
