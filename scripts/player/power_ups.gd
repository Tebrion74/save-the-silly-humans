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
## Build 020: while the rancher has full hearts the whip is the LONG WHIP
## (same reach as the pickup). The first hit ends it; getting back to full
## hearts (health pickup) brings it back. A picked-up LONG WHIP mod is
## separate and is kept as before.
var full_heart_long: bool = false
## Build 020 INVINCIBLE: seconds of star power left, and the save combo.
var invincible_time: float = 0.0
## Build 025: BODY ARMOUR plates left (each absorbs one hit before hearts).
var armor: int = 0
var armor_grace: float = 0.0
var _armor_fx: Node2D = null
var star_combo: int = 0
var star_combo_timer: float = 0.0
var star_best_combo: int = 0
var _star_fx: Node2D = null
var _base_range := 0.0
var _base_throw := 0.0


func _ready() -> void:
	name = "PowerUps"
	_whip = get_parent().get_node_or_null("Whip")
	if _whip:
		_base_range = _whip.whip_range
		_base_throw = _whip.throw_force
	var p := get_parent()
	if p != null and p.has_signal("health_changed"):
		p.health_changed.connect(_on_health_changed)
	if p != null and "health" in p and "maximum_health" in p:
		full_heart_long = p.health >= p.maximum_health
	_apply()


func _on_health_changed(health: int, maximum: int) -> void:
	var f := health >= maximum and health > 0
	if f != full_heart_long:
		full_heart_long = f
		_apply()
		changed.emit()


## Build 020: star power on (or refreshed to the full time).
func start_invincible(seconds: float = LevelConfig.INVINCIBLE_SECONDS) -> void:
	var was := invincible_time > 0.0
	invincible_time = seconds
	if not was:
		star_combo = 0
		star_combo_timer = 0.0
	_ensure_star_fx()
	if is_inside_tree():
		Sfx.play(self, "star", -3.0)
	changed.emit()


func is_invincible() -> bool:
	return invincible_time > 0.0


## A star save landed: returns the points for it (200, 400, 800 ...).
func star_save_points() -> int:
	star_combo += 1
	star_best_combo = maxi(star_best_combo, star_combo)
	star_combo_timer = LevelConfig.STAR_COMBO_WINDOW
	changed.emit()
	return LevelConfig.star_combo_points(star_combo)


func _process(delta: float) -> void:
	armor_grace = maxf(armor_grace - delta, 0.0)
	if invincible_time <= 0.0:
		return
	var before := invincible_time
	invincible_time = maxf(invincible_time - delta, 0.0)
	if star_combo_timer > 0.0:
		star_combo_timer -= delta
		if star_combo_timer <= 0.0:
			star_combo = 0
	var warn := LevelConfig.INVINCIBLE_WARN_SECONDS
	if before > warn and invincible_time <= warn and is_inside_tree():
		Sfx.play(self, "star_end", -6.0)
	if invincible_time <= 0.0:
		star_combo = 0
		star_combo_timer = 0.0
		changed.emit()


## Build 025: BODY ARMOUR. Called by player.take_damage before hearts: true =
## this hit was soaked by a plate (or by the short grace after one).
func absorb_hit() -> bool:
	if armor_grace > 0.0:
		return true
	if armor <= 0:
		return false
	armor -= 1
	armor_grace = LevelConfig.ARMOR_IFRAMES
	if _armor_fx != null and is_instance_valid(_armor_fx):
		_armor_fx.flash = 0.35
	changed.emit()
	return true


func _ensure_armor_fx() -> void:
	if _armor_fx != null and is_instance_valid(_armor_fx):
		return
	var p := get_parent()
	if p == null:
		return
	_armor_fx = ArmorVest.new()
	_armor_fx.name = "ArmorVest"
	_armor_fx.pu = self
	p.add_child(_armor_fx)


## Build 025: steel-blue plates over the rancher's chest + one pip per plate
## left; flashes white when a plate soaks a hit, falls away at 0.
class ArmorVest extends Node2D:
	var pu: Node = null
	var flash := 0.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_t += delta
		flash = maxf(flash - delta, 0.0)
		if pu == null or not is_instance_valid(pu) or (pu.armor <= 0 and flash <= 0.0):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var n: int = pu.armor
		var col := Color(1, 1, 1, 0.95) if flash > 0.0 and fmod(_t, 0.1) < 0.05 else Color(0.45, 0.6, 0.78, 0.92)
		var dark := Color(0.06, 0.08, 0.14, 0.95)
		# vest: two shoulder straps + a chest plate over the torso
		var r := Rect2(-7, -13, 14, 10)
		draw_rect(r.grow(1.0), dark)
		draw_rect(r, col)
		draw_rect(Rect2(-7, -16, 3, 3), dark)
		draw_rect(Rect2(4, -16, 3, 3), dark)
		draw_line(Vector2(0, -13), Vector2(0, -3), dark, 1.0)
		for rv in [Vector2(-4, -11), Vector2(4, -11), Vector2(-4, -6), Vector2(4, -6)]:
			draw_rect(Rect2(rv - Vector2(1, 1), Vector2(2, 2)), Color(0.9, 0.95, 1.0, 0.9))
		# plate pips above the hat
		for i in LevelConfig.ARMOR_HITS:
			var px := Vector2(-7 + i * 7, -32)
			draw_rect(Rect2(px - Vector2(3, 3), Vector2(6, 6)), dark)
			draw_rect(Rect2(px - Vector2(2, 2), Vector2(4, 4)), Color(0.55, 0.85, 1.0) if i < n else Color(0.25, 0.25, 0.32))


func _ensure_star_fx() -> void:
	if _star_fx != null and is_instance_valid(_star_fx):
		return
	var p := get_parent()
	if p == null:
		return
	_star_fx = StarAura.new()
	_star_fx.name = "StarAura"
	_star_fx.pu = self
	p.add_child(_star_fx)


## Rainbow tint + sparkles on the rancher while star power lasts.
class StarAura extends Node2D:
	var pu: Node = null
	var _t := 0.0

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		_t += delta
		var host := get_parent()
		var spr = host.get_node_or_null("Sprite") if host != null else null
		var on: bool = pu != null and is_instance_valid(pu) and pu.invincible_time > 0.0
		if spr is CanvasItem:
			if on:
				var blink: bool = pu.invincible_time < LevelConfig.INVINCIBLE_WARN_SECONDS and fmod(_t, 0.2) < 0.1
				var c := Color.from_hsv(fmod(_t * 1.6, 1.0), 0.55, 1.0)
				(spr as CanvasItem).modulate = Color(1, 1, 1) if blink else Color(c.r * 1.4, c.g * 1.4, c.b * 1.4)
			else:
				(spr as CanvasItem).modulate = Color(1, 1, 1)
		if not on:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for i in 6:
			var a := _t * 3.5 + TAU * i / 6.0
			var p := Vector2(cos(a) * 30.0, -24.0 + sin(a) * 12.0)
			var c := Color.from_hsv(fmod(_t * 0.7 + i / 6.0, 1.0), 0.7, 1.0)
			var s := 2.0 + 1.5 * absf(sin(_t * 8.0 + i))
			draw_rect(Rect2(p - Vector2(s * 2, s * 0.5), Vector2(s * 4, s)), c)
			draw_rect(Rect2(p - Vector2(s * 0.5, s * 2), Vector2(s, s * 4)), c)


## True when the whip has the long reach (pickup mod or full hearts).
func long_reach() -> bool:
	return whip_mod == "long_whip" or full_heart_long or _god()


func _god() -> bool:
	var bt := get_node_or_null("/root/BetaTools") if is_inside_tree() else null
	return bt != null and bt.god


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
		"invincible":
			start_invincible()
			note = "%ds" % int(LevelConfig.INVINCIBLE_SECONDS)
		"armor":
			armor = LevelConfig.ARMOR_HITS
			note = "x%d" % armor
			if is_inside_tree():
				Sfx.play(self, "armor_on", -6.0)
			_ensure_armor_fx()
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
	if _god() and kind in ["fire_whip", "shockwave", "long_whip", "strong_throw", "whip_shot"]:
		return true
	match kind:
		"fire_whip":
			return fire_charges > 0
		"shockwave":
			return shock_charges > 0
		"long_whip":
			return long_reach()
		"strong_throw", "whip_shot":
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
	armor = 0
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
	_whip.whip_range = _base_range * (LevelConfig.LONG_WHIP_MULT if long_reach() else 1.0)
	_whip.assist_range_mult = LevelConfig.LONG_WHIP_MULT if long_reach() else 1.0
	_whip.throw_force = _base_throw * (LevelConfig.STRONG_THROW_MULT if (whip_mod == "strong_throw" or _god()) else 1.0)


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
		"armor": armor,
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
	armor = int(d.get("armor", 0))
	if armor > 0:
		_ensure_armor_fx.call_deferred()
	var w := weapons()
	var c := cam()
	if bool(d.get("has_cam", false)) and w != null:
		w.add_weapon("cam")
		if c != null:
			c.battery = float(d.get("battery", 0.0))
		w.select_id(String(d.get("weapon", "whip")))
	_apply()
	changed.emit()
