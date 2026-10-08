extends Node
## Autoload: GameProgress — survives scene reloads (retry / next level).
## Level 1 on first launch.
## Build 012: run score + high score.
##  - `score` carries over between levels of a run.
##  - START on the title resets level and score (reset_progress()).
##  - Retrying a level (PLAY AGAIN, R, Enter after a loss) restores the score the
##    level started with (restore_level_start_score()), so a retry can't farm points.
##  - `high_score` is the best score this session, also saved to
##    user://stsh_save.cfg (IndexedDB on web) and loaded at startup.

const SAVE_PATH := "user://stsh_save.cfg"

var current_level: int = 1
var score: int = 0
## Score when the current level began (retry restores this).
var level_start_score: int = 0
var high_score: int = 0
## True when the last round end beat the stored high score.
var new_high_score: bool = false
## Build 014: the rancher's inventory (PowerUps.to_dict()) carried into the
## level being played, and what it was when the level started (retry).
var inventory: Dictionary = {}
var level_start_inventory: Dictionary = {}
## Build 014 debug scenarios (screenshots/tests). Only ever set in DEBUG
## builds (editor / --export-debug); a release export ignores them.
## Native: -- --scenario=NAME [--level=N] [--touch]
## Web (debug export only): index.html?scenario=NAME&level=N&touch=1
var debug_scenario: String = ""
## Build 015: level to go to after the Trustin Judeau boss fight (0 = not in
## a boss fight). The fight sits between LevelConfig.BOSS_AFTER_LEVEL and the
## next level.
var boss_return_level: int = 0
## Build 016: between-level stages. After a level is cleared, stage_queue
## holds what's left to play (["bonus", "boss1"] ...), current_stage is the
## one being played ("" = a normal level) and stage_return_level the level
## after them. Retrying a stage (PLAY AGAIN) keeps all three.
var stage_queue: Array[String] = []
var current_stage: String = ""
var stage_return_level: int = 0
## Which bonus stage this is (1 = after level 1): later ones are harder.
var bonus_index: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			current_level = maxi(int(arg.substr(8)), 1)
	if OS.is_debug_build():
		_read_debug_args()
	load_high_score()


func _read_debug_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			debug_scenario = arg.substr(11)
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search || ''", true)
		if typeof(q) == TYPE_STRING and q != "":
			for part in String(q).trim_prefix("?").split("&"):
				var kv := part.split("=")
				if kv.size() != 2:
					continue
				match kv[0]:
					"scenario":
						debug_scenario = kv[1]
					"level":
						current_level = maxi(int(kv[1]), 1)
					"touch":
						if kv[1] == "1":
							TouchInput.active = true
							TouchInput.forced = true
	if debug_scenario != "":
		print("[debug] scenario=", debug_scenario, " level=", current_level)


func advance_level() -> void:
	current_level += 1


## Build 015: enter the boss arena; CONTINUE afterwards goes to `return_level`.
## current_level stays on the level just cleared while the boss is fought.
func enter_boss(return_level: int) -> void:
	boss_return_level = return_level


## Build 016: level `level` was cleared. Queues its stages (bonus, boss) and
## returns the scene to load next: the first stage, or the game scene (with
## current_level already advanced) when nothing follows.
func begin_after_level(level: int) -> String:
	stage_queue = GameProgressCheck.stages_after(level)
	stage_return_level = level + 1
	bonus_index = GameProgressCheck.bonus_index(level)
	return next_stage_scene()


## Pops the next queued stage (or returns to the levels).
func next_stage_scene() -> String:
	if stage_queue.is_empty():
		current_stage = ""
		if stage_return_level > 0:
			current_level = stage_return_level
		stage_return_level = 0
		boss_return_level = 0
		return LevelConfig.GAME_SCENE
	current_stage = stage_queue.pop_front()
	boss_return_level = stage_return_level   # 015 compatibility (boss_level.return_level)
	return GameProgressCheck.stage_scene(current_stage)


## A bonus stage / boss is done (CONTINUE): the next scene to load.
func finish_stage() -> String:
	return next_stage_scene()


## Debug: a fresh run that starts at `stage` ("bonus", "boss1", "boss2"),
## exactly as if its level had just been cleared. `bonus_n` picks which bonus
## stage (1 = after level 1, 2 = after level 4, ...).
func start_at_stage(stage: String, bonus_n: int = 1) -> String:
	reset_progress()
	var level := LevelConfig.BOSS_AFTER_LEVEL
	match stage:
		"bonus":
			level = LevelConfig.BONUS_FIRST_AFTER + (maxi(bonus_n, 1) - 1) * LevelConfig.BONUS_EVERY
		"boss2":
			level = LevelConfig.BOSS2_AFTER_LEVEL
	current_level = level
	stage_queue = GameProgressCheck.stages_after(level)
	stage_return_level = level + 1
	bonus_index = GameProgressCheck.bonus_index(level)
	# drop anything queued before the requested stage
	while not stage_queue.is_empty() and stage_queue[0] != stage:
		stage_queue.pop_front()
	return next_stage_scene()


## Title-screen BOSS button: a fresh run that starts at the boss fight.
func start_at_boss() -> void:
	start_at_stage("boss1")


## Boss beaten: on to the level after it (015 API; 016 uses finish_stage).
func finish_boss() -> void:
	stage_queue.clear()
	if boss_return_level > 0:
		stage_return_level = boss_return_level
	next_stage_scene()


## START from the title: level 1, score 0.
func reset_progress() -> void:
	current_level = 1
	score = 0
	level_start_score = 0
	new_high_score = false
	inventory = {}
	level_start_inventory = {}
	boss_return_level = 0
	stage_queue.clear()
	current_stage = ""
	stage_return_level = 0
	bonus_index = 1


## Called when a level scene starts: remember the score to restore on retry.
func begin_level() -> void:
	level_start_score = score
	new_high_score = false
	level_start_inventory = inventory.duplicate(true)


func add_score(points: int) -> int:
	score = maxi(score + points, 0)
	return score


func restore_level_start_score() -> void:
	score = level_start_score
	inventory = level_start_inventory.duplicate(true)


## Build 014: a won level hands its inventory to the next level.
func carry_inventory(d: Dictionary) -> void:
	if LevelConfig.INVENTORY_CARRIES_OVER:
		inventory = d.duplicate(true)


## Round over: bump + persist the high score. Returns true for a new record.
func commit_high_score() -> bool:
	if score > high_score:
		high_score = score
		new_high_score = true
		save_high_score()
	return new_high_score


func save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "high_score", high_score)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("GameProgress: could not save high score (%d)" % err)


func load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = maxi(int(cfg.get_value("scores", "high_score", 0)), 0)
