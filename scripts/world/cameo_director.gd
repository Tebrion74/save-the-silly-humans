class_name CameoDirector
extends Node
## Build 030: drops CAMEO sub-bosses (scripts/world/cameo.gd) into regular
## levels at random: one at a time, the first CAMEO_FIRST_DELAY s into the
## round, then a roll every CAMEO_GAP s (CAMEO_CHANCE to spawn). Never in boss
## or bonus stages (they turn timed power-ups off) or before CAMEO_FROM_LEVEL.
## Beta cheat 3030 (BetaTools.cameo_party): back-to-back cameos every
## CAMEO_PARTY_GAP s cycling the roster, from level 1.
## Player summoning is deferred to the RPG spinoff.

var level: Node = null
var timer := 0.0
var spawned := 0
var current: Cameo = null
var rng := RandomNumberGenerator.new()
var _party_i := 0


func _ready() -> void:
	rng.randomize()
	add_to_group("cameo_director")
	timer = rng.randf_range(LevelConfig.CAMEO_FIRST_DELAY.x, LevelConfig.CAMEO_FIRST_DELAY.y)


func party() -> bool:
	var bt := get_node_or_null("/root/BetaTools")
	return bt != null and "cameo_party" in bt and bool(bt.cameo_party)


func enabled() -> bool:
	if level == null:
		return false
	if not level.has_method("timed_powerups_enabled") or not level.timed_powerups_enabled():
		return false
	if party():
		return true
	return int(level.level_number) >= LevelConfig.CAMEO_FROM_LEVEL


func _process(delta: float) -> void:
	if not enabled() or not bool(level.rescues_unlocked) or bool(level._ended):
		return
	if current != null and is_instance_valid(current):
		return
	current = null
	if party():
		timer = minf(timer, LevelConfig.CAMEO_PARTY_GAP)
	timer -= delta
	if timer > 0.0:
		return
	timer = LevelConfig.CAMEO_PARTY_GAP if party() else rng.randf_range(LevelConfig.CAMEO_GAP.x, LevelConfig.CAMEO_GAP.y)
	if party():
		spawn(Cameo.ORDER[_party_i % Cameo.ORDER.size()])
		_party_i += 1
	elif rng.randf() < LevelConfig.CAMEO_CHANCE:
		spawn(Cameo.ORDER[rng.randi() % Cameo.ORDER.size()])


func spawn(id: String) -> Cameo:
	var at: Vector2 = level._map_powerup_point() if level.has_method("_map_powerup_point") else Vector2.INF
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if at == Vector2.INF and p != null:
		at = p.global_position + Vector2(180, 0)
	if at == Vector2.INF:
		return null
	if p != null and at.distance_to(p.global_position) > 260.0:
		at = p.global_position + p.global_position.direction_to(at) * 200.0
	current = Cameo.make(level, id, at)
	spawned += 1
	return current
