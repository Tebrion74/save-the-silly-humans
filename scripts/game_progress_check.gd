class_name GameProgressCheck
extends RefCounted
## Build 015: static helper (the GameProgress autoload has no class_name).


static func boss_follows(level: int) -> bool:
	return level == LevelConfig.BOSS_AFTER_LEVEL
