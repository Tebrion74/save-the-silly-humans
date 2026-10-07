class_name Weapons
extends Node
## Build 014: slottable weapons (child "Weapons" of the Player, added by
## level_controller). Slot 1 is always the whip; other weapons (the MSM Cam)
## are added by pickups. Defs live in LevelConfig.WEAPON_DEFS, so adding a
## weapon later = a new def + its own node that checks `current_id()`.
##
## Every weapon has a PRIMARY and a SECONDARY action (LevelConfig.WEAPON_DEFS):
##   whip: WHIP / GRAB      MSM Cam: REC (hold) / SWING
## This node reads the presses (PC: "whip" = LMB, "whip_grab" = RMB; touch:
## bottom-right / top-right wedge) and hands them to the equipped weapon's
## node: weapon_primary() / weapon_secondary(). Hold-to-use weapons (REC)
## also read the held state themselves (`primary_held()`).
## PC: Q or the mouse wheel cycles, 1..9 select a slot directly.
## Touch: the top-left weapon wedge (touch_controls.gd) cycles.
## Whip mods only apply to the whip.

signal changed(current_id: String)

var slots: Array[String] = ["whip"]
var current: int = 0
## Mouse wheels send several notches per flick; one swap per WHEEL_DEBOUNCE_MS.
const WHEEL_DEBOUNCE_MS := 180
var _wheel_ms: int = -100000


func _ready() -> void:
	name = "Weapons"


func current_id() -> String:
	return slots[clampi(current, 0, slots.size() - 1)]


func has_weapon(id: String) -> bool:
	return slots.has(id)


## Adds a weapon in WEAPON_DEFS order. Returns true if it was new.
func add_weapon(id: String) -> bool:
	if slots.has(id) or LevelConfig.weapon_def(id).is_empty():
		return false
	var cur := current_id()
	var ordered: Array[String] = []
	for d in LevelConfig.WEAPON_DEFS:
		var wid: String = d["id"]
		if wid == id or slots.has(wid):
			ordered.append(wid)
	slots = ordered
	current = slots.find(cur)
	changed.emit(current_id())
	return true


func select_index(i: int) -> bool:
	if i < 0 or i >= slots.size() or i == current:
		return false
	current = i
	changed.emit(current_id())
	return true


func select_id(id: String) -> bool:
	return select_index(slots.find(id))


func cycle(step: int = 1) -> bool:
	if slots.size() < 2:
		return false
	return select_index(wrapi(current + step, 0, slots.size()))


func current_def() -> Dictionary:
	return LevelConfig.weapon_def(current_id())


func weapon_node(id: String = "") -> Node:
	var d := LevelConfig.weapon_def(id if id != "" else current_id())
	if d.is_empty() or get_parent() == null:
		return null
	return get_parent().get_node_or_null(String(d.get("node", "")))


## PRIMARY held right now (PC LMB / touch bottom-right wedge).
static func primary_held() -> bool:
	if TouchInput.active:
		return TouchInput.whip_held
	return Input.is_action_pressed("whip")


func _process(_delta: float) -> void:
	if TouchInput.consume_swap():
		cycle(1)
	var p := get_parent()
	if p != null and "_dead" in p and p._dead:
		TouchInput.consume_whip()
		TouchInput.consume_grab()
		return
	var prim := Input.is_action_just_pressed("whip")
	if TouchInput.consume_whip():
		prim = true
	var sec := Input.is_action_just_pressed("whip_grab")
	if TouchInput.consume_grab():
		sec = true
	if not prim and not sec:
		return
	var n := weapon_node()
	if n == null:
		return
	if prim and n.has_method("weapon_primary"):
		n.weapon_primary()
	if sec and n.has_method("weapon_secondary"):
		n.weapon_secondary()


func _unhandled_input(event: InputEvent) -> void:
	var p := get_parent()
	if p != null and "_dead" in p and p._dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).physical_keycode
		if k == KEY_Q:
			cycle(1)
			get_viewport().set_input_as_handled()
		elif k >= KEY_1 and k <= KEY_9:
			if select_index(k - KEY_1):
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_WHEEL_DOWN and mb.button_index != MOUSE_BUTTON_WHEEL_UP:
			return
		get_viewport().set_input_as_handled()
		var now := Time.get_ticks_msec()
		if now - _wheel_ms < WHEEL_DEBOUNCE_MS:
			return
		_wheel_ms = now
		cycle(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
