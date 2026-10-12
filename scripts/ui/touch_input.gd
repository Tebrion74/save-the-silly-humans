extends Node
## Autoload: TouchInput — mobile touch state without affecting PC mouse/keyboard.

var active: bool = false
var move_vector: Vector2 = Vector2.ZERO
## Screen-space aim point, or null when unset.
var aim_screen: Variant = null

var whip_just_pressed: bool = false
var grab_just_pressed: bool = false
## Build 014: the WHIP button is held (it is the REC button with the MSM Cam).
var whip_held: bool = false
## Build 014: the SWAP (weapon) button was tapped.
var swap_just_pressed: bool = false
var restart_just_pressed: bool = false
## Build 010: NEXT LEVEL tapped on the win screen.
var next_level_just_pressed: bool = false
## True when --touch was passed (screenshots/testing); mouse then never disables touch.
var forced: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg == "--touch":
			active = true
			forced = true
			break
	_hook_web_focus()


# ------------------------------------------------------------ build 019: stuck keys
## Build 019 WASD fix. If a movement key is released while the game does not
## have keyboard focus (alt-tab, a click on the page around the game iframe,
## the browser UI), the key-up never reaches Godot: the key and its move_*
## action stay "pressed" forever. The rancher keeps walking that way and the
## opposite key only cancels it (looks "locked out") until the stuck key is
## pressed again. So: whenever the game loses OR regains focus, send a real
## key-up for every key still marked held (clears key and action state the
## same way a normal release does). Godot's focus notifications cover
## desktop; on the web the browser's blur / focus / visibilitychange are
## hooked directly, because the web build does not release keys on blur.
const RELEASE_KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_SPACE, KEY_Q]
const RELEASE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"whip", &"whip_grab"]
var _js_focus_cbs: Array = []   # keep the JS callbacks alive
var _release_pending := false
## How many times held input was dropped (tests).
var focus_releases := 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		release_held_input()


func _hook_web_focus() -> void:
	if not OS.has_feature("web"):
		return
	var win = JavaScriptBridge.get_interface("window")
	var doc = JavaScriptBridge.get_interface("document")
	if win == null or doc == null:
		return
	var cb = JavaScriptBridge.create_callback(_on_web_focus_change)
	_js_focus_cbs.append(cb)
	win.addEventListener("blur", cb)
	win.addEventListener("focus", cb)
	doc.addEventListener("visibilitychange", cb)
	var canvas = doc.querySelector("canvas")
	if canvas != null:
		canvas.addEventListener("blur", cb)
		canvas.addEventListener("focus", cb)


func _on_web_focus_change(_args: Array) -> void:
	# JS callback: defer to the main loop
	_release_pending = true


func _process(_delta: float) -> void:
	if _release_pending:
		_release_pending = false
		release_held_input()


## Release every held key / move action exactly as if the player let go.
func release_held_input() -> void:
	var any := false
	for k in RELEASE_KEYS:
		if Input.is_physical_key_pressed(k) or Input.is_key_pressed(k):
			var e := InputEventKey.new()
			e.physical_keycode = k
			e.keycode = k
			e.pressed = false
			Input.parse_input_event(e)
			any = true
	for a in RELEASE_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			Input.action_release(a)
			any = true
	if any:
		focus_releases += 1
	whip_held = false


## Last time (ms) any finger touched or dragged; mouse events right after a touch
## are browser compatibility events, not a real mouse.
var _last_touch_ms: int = -100000
var _fingers_down: Dictionary = {}

const MOUSE_IGNORE_AFTER_TOUCH_MS := 2000
const MOUSE_MIN_MOVE_PX := 6.0


## Called by TouchControls for every screen touch/drag it sees (it marks them
## handled, so this autoload would otherwise never get them).
func note_touch(index: int, pressed: bool, is_drag: bool) -> void:
	active = true
	_last_touch_ms = Time.get_ticks_msec()
	if is_drag or pressed:
		_fingers_down[index] = true
	else:
		_fingers_down.erase(index)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		note_touch(t.index, t.pressed, false)
	elif event is InputEventScreenDrag:
		note_touch((event as InputEventScreenDrag).index, true, true)
	elif not forced and active and (event is InputEventMouseMotion or event is InputEventMouseButton):
		# Hybrid touchscreen laptops: real mouse use returns to normal mouse aim
		# and hides the touch UI. Phones/browsers send fake mouse events around
		# touches, so ignore mouse input while a finger is down or just lifted.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if not _fingers_down.is_empty():
			return
		if Time.get_ticks_msec() - _last_touch_ms < MOUSE_IGNORE_AFTER_TOUCH_MS:
			return
		if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() < MOUSE_MIN_MOVE_PX:
			return
		active = false
		aim_screen = null
		move_vector = Vector2.ZERO
		whip_held = false


func consume_whip() -> bool:
	var v := whip_just_pressed
	whip_just_pressed = false
	return v


func consume_grab() -> bool:
	var v := grab_just_pressed
	grab_just_pressed = false
	return v


func consume_swap() -> bool:
	var v := swap_just_pressed
	swap_just_pressed = false
	return v


func consume_restart() -> bool:
	var v := restart_just_pressed
	restart_just_pressed = false
	return v


func consume_next_level() -> bool:
	var v := next_level_just_pressed
	next_level_just_pressed = false
	return v


func get_aim_world(node: CanvasItem) -> Vector2:
	# Touch: whip / grab aim along the rancher's facing. Mouse on PC is unchanged.
	if active:
		var origin: Vector2 = node.global_position
		var facing: Vector2 = Vector2.RIGHT
		var tree := node.get_tree()
		if tree:
			var player := tree.get_first_node_in_group("player")
			if player != null and "facing" in player:
				facing = (player.get("facing") as Vector2)
				if facing.length_squared() < 0.0001:
					facing = Vector2.RIGHT
				origin = player.global_position
		return origin + facing.normalized() * 240.0
	return node.get_global_mouse_position()
