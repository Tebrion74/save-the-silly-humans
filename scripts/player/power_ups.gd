class_name PowerUps
extends Node
## The rancher's power-ups + inventory (child "PowerUps" of the Player, added
## by level_controller). Lives under Entities, so it freezes with gameplay at
## round end.
##
## Build 014: NO timers.
##  - Whip mods (LONG WHIP, STRONG THROW, WHIP SHOT): one at a time, kept until
##    a different whip mod is picked up. They only affect the whip.
##  - FIRE WHIP: charges (one per whip crack). At 0 the whip is back to the
##    current whip mod / normal whip.
##  - SHOCKWAVE: charges (one per whip crack).
##  - HEALTH: instant.
##  - MSM CAM: adds the cam to the weapon slots with a full battery.
##  - BATTERY: spare batteries for the cam (max CAM_SPARE_BATTERIES_MAX).
## All numbers are in LevelConfig (build 014 section).

signal changed

var whip_mod: String = ""
var fire_charges: int = 0
var shock_charges: int = 0
var spare_batteries: int = 0
## Kept for compatibility with build 013 callers/tests: kind -> 1.0 while the
## effect is available (no timers any more).
var active := {}
var _whip: Node = null
var _base_range := 0.0
var _base_throw := 0.0


func _ready() -> void:
	name = "PowerUps"
	_whip = get_parent().get_node_or_null("Whip")
	if _whip:
		_base_range = _whip.whip_range
		_base_throw = _whip.throw_force
	_apply()


func weapons() -> Node:
	return get_parent().get_node_or_null("Weapons") if get_parent() != null else null


func cam() -> Node:
	return get_parent().get_node_or_null("MsmCam") if get_parent() != null else null


## Collect a pickup. Returns a short HUD/popup note ("" = just the name).
func grant(kind: String) -> String:
	var note := ""
	match kind:
		"health":
			var p := get_parent()
			if p != null and "health" in p and "maximum_health" in p and not p._dead:
				p.health = mini(p.health + 1, p.maximum_health)
				p.health_changed.emit(p.health, p.maximum_health)
		"long_whip", "strong_throw", "whip_shot":
			whip_mod = kind
		"fire_whip":
			fire_charges = mini(fire_charges + LevelConfig.FIRE_CHARGES, LevelConfig.FIRE_CHARGES_MAX)
			note = "x%d" % fire_charges
		"shockwave":
			shock_charges = mini(shock_charges + LevelConfig.SHOCK_CHARGES, LevelConfig.SHOCK_CHARGES_MAX)
			note = "x%d" % shock_charges
		"msm_cam":
			note = _grant_cam()
		"battery":
			note = _grant_battery()
	_apply()
	changed.emit()
	return note


func _grant_cam() -> String:
	var w := weapons()
	var c := cam()
	if w == null or c == null:
		return ""
	if not w.has_weapon("cam"):
		w.add_weapon("cam")
		c.battery = LevelConfig.CAM_BATTERY_SECONDS
		# First pickup equips it so the player sees what it is.
		w.select_id("cam")
		return "EQUIPPED"
	# Already owned: a fresh battery; if the cam is full, it goes to the spares.
	if c.battery < LevelConfig.CAM_BATTERY_SECONDS - 0.05:
		c.battery = LevelConfig.CAM_BATTERY_SECONDS
		return "RECHARGED"
	return _grant_battery()


func _grant_battery() -> String:
	var c := cam()
	var w := weapons()
	var owned: bool = w != null and w.has_weapon("cam")
	# A dead cam takes the new battery straight away.
	if owned and c != null and c.battery <= 0.0:
		c.battery = LevelConfig.CAM_BATTERY_SECONDS
		c.flash_swap()
		return "LOADED"
	if spare_batteries < LevelConfig.CAM_SPARE_BATTERIES_MAX:
		spare_batteries += 1
		return "x%d" % spare_batteries
	if owned and c != null and c.battery < LevelConfig.CAM_BATTERY_SECONDS - 0.05:
		c.battery = LevelConfig.CAM_BATTERY_SECONDS
		return "RECHARGED"
	return "FULL"


## The cam's battery hit 0: load a spare if there is one.
func take_spare_battery() -> bool:
	if spare_batteries <= 0:
		return false
	spare_batteries -= 1
	changed.emit()
	return true


func is_active(kind: String) -> bool:
	match kind:
		"fire_whip":
			return fire_charges > 0
		"shockwave":
			return shock_charges > 0
		"long_whip", "strong_throw", "whip_shot":
			return whip_mod == kind
	return false


## Whip cracked: spend one fire and one shockwave charge (whichever are loaded).
func on_whip_crack() -> void:
	var was_fire := fire_charges > 0
	var spent := false
	if fire_charges > 0:
		fire_charges -= 1
		spent = true
	if shock_charges > 0:
		shock_charges -= 1
		spent = true
	if spent:
		_apply()
		changed.emit()
	if was_fire and fire_charges == 0:
		var lvl := get_tree().get_first_node_in_group("level_controller") if is_inside_tree() else null
		if lvl != null and lvl.has_method("spawn_score_popup"):
			lvl.spawn_score_popup("FIRE OUT", (get_parent() as Node2D).global_position, Color(1.0, 0.6, 0.3), 2)


func clear_all() -> void:
	whip_mod = ""
	fire_charges = 0
	shock_charges = 0
	spare_batteries = 0
	_apply()
	changed.emit()


func _apply() -> void:
	active.clear()
	for k in ["long_whip", "strong_throw", "whip_shot", "fire_whip", "shockwave"]:
		if is_active(k):
			active[k] = 1.0
	if _whip == null:
		return
	_whip.whip_range = _base_range * (LevelConfig.LONG_WHIP_MULT if whip_mod == "long_whip" else 1.0)
	_whip.assist_range_mult = LevelConfig.LONG_WHIP_MULT if whip_mod == "long_whip" else 1.0
	_whip.throw_force = _base_throw * (LevelConfig.STRONG_THROW_MULT if whip_mod == "strong_throw" else 1.0)


# ---------------------------------------------------------------- carry-over

## Snapshot for GameProgress (next level / retry).
func to_dict() -> Dictionary:
	var c := cam()
	var w := weapons()
	return {
		"whip_mod": whip_mod,
		"fire": fire_charges,
		"shock": shock_charges,
		"spares": spare_batteries,
		"has_cam": w != null and w.has_weapon("cam"),
		"battery": c.battery if c != null else 0.0,
		"weapon": w.current_id() if w != null else "whip",
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	whip_mod = String(d.get("whip_mod", ""))
	fire_charges = int(d.get("fire", 0))
	shock_charges = int(d.get("shock", 0))
	spare_batteries = int(d.get("spares", 0))
	var w := weapons()
	var c := cam()
	if bool(d.get("has_cam", false)) and w != null:
		w.add_weapon("cam")
		if c != null:
			c.battery = float(d.get("battery", 0.0))
		w.select_id(String(d.get("weapon", "whip")))
	_apply()
	changed.emit()
