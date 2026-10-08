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


## Title-screen BOSS button: a fresh run that starts at the boss fight.
func start_at_boss() -> void:
	reset_progress()
	current_level = LevelConfig.BOSS_AFTER_LEVEL
	boss_return_level = LevelConfig.BOSS_AFTER_LEVEL + 1


## Boss beaten: on to the level after it.
func finish_boss() -> void:
	current_level = boss_return_level if boss_return_level > 0 else current_level + 1
	boss_return_level = 0


## START from the title: level 1, score 0.
func reset_progress() -> void:
	current_level = 1
	score = 0
	level_start_score = 0
	new_high_score = false
	inventory = {}
	level_start_inventory = {}
	boss_return_level = 0


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
