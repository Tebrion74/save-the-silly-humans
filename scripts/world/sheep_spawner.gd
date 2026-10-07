extends Node2D

## Top-left sheep den: instances Sheep.tscn on a timer after rescues unlock.
## Soft-capped so flocks cannot grow without bound (default max 20 living).
## Interval comes from LevelConfig.den_interval(level) (build 011: 90s at level 1,
## x0.92 per level, floor 40s).

@export var spawn_interval: float = 60.0
## Soft cap — when living (non-exploding) sheep reach this count, skip a tick.
@export var max_living_sheep: int = 20
@export var spawn_slot: Vector2i = Vector2i(8, 10)
@export var jitter_px: float = 16.0

const SHEEP_SCENE := preload("res://scenes/sheep/Sheep.tscn")

var _timer: float = 0.0
var _active: bool = false
## Build 014: the spawn timer runs this many times faster (MSM Cam filming =
## LevelConfig.CAM_SHEEP_RATE_MULT, set every frame by the level). The living
## sheep cap is unchanged.
var rate_mult: float = 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_active = false
	_timer = spawn_interval


## Build 010: take spawn_interval / cap from LevelConfig for the current level.
@export var use_level_config: bool = true
var spawned_count: int = 0


## Called by LevelController after physics sync / rescues_unlocked.
## Runs until the round ends (build 012: stop_spawning() on win/lose).
func start_spawning() -> void:
	if use_level_config:
		var level := 1
		var progress := get_node_or_null("/root/GameProgress")
		if progress != null and "current_level" in progress:
			level = int(progress.current_level)
		spawn_interval = LevelConfig.den_interval(level)
		max_living_sheep = LevelConfig.DEN_MAX_LIVING_SHEEP
	_active = true
	_timer = spawn_interval
	print("[sheep_spawner] started; interval=%.0fs slot=%s soft_cap=%d" % [spawn_interval, spawn_slot, max_living_sheep])


## Build 012: the round is over (win or lose) — no more den spawns.
func stop_spawning() -> void:
	if _active:
		print("[sheep_spawner] stopped")
	_active = false


func is_spawning() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta * rate_mult
	if _timer > 0.0:
		return
	_timer = spawn_interval
	_try_spawn()


func _try_spawn() -> void:
	var living := _count_living_sheep()
	if living >= max_living_sheep:
		print("[sheep_spawner] soft cap (%d) reached; skip spawn" % max_living_sheep)
		return

	var level := get_tree().get_first_node_in_group("level_controller")
	if level == null:
		return
	var ground := level.get_node_or_null("Ground") as TileMapLayer
	var sheep_parent := level.get_node_or_null("Entities/Sheep") as Node2D
	if ground == null or sheep_parent == null:
		push_warning("SheepSpawner: Ground or Entities/Sheep missing")
		return
	if not ground.has_method("tile_center"):
		return
	if ground.has_method("is_interior_local") and not ground.is_interior_local(spawn_slot, 4):
		push_error("SheepSpawner slot %s fails interior margin=4" % spawn_slot)
		return

	var sheep: Node2D = SHEEP_SCENE.instantiate()
	sheep_parent.add_child(sheep)
	var center: Vector2 = ground.to_global(ground.tile_center(spawn_slot))
	var jitter := Vector2(
		_rng.randf_range(-jitter_px, jitter_px),
		_rng.randf_range(-jitter_px, jitter_px)
	)
	var pos := center + jitter
	# Keep jitter when still interior; only fall back to exact den center if not.
	if ground.has_method("local_pos_to_local_cell") and ground.has_method("is_interior_local"):
		var cell: Vector2i = ground.local_pos_to_local_cell(ground.to_local(pos))
		if not ground.is_interior_local(cell, 4):
			pos = center
	sheep.global_position = pos
	spawned_count += 1
	print("[sheep_spawner] spawned at world=%s (living was %d)" % [sheep.global_position, living])


func _count_living_sheep() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("sheep"):
		if not is_instance_valid(node):
			continue
		if "exploding" in node and node.exploding:
			continue
		n += 1
	return n
