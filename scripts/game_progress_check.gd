class_name GameProgressCheck
extends RefCounted
## Build 015: static helper (the GameProgress autoload has no class_name).
## Build 016: the between-level stage schedule (bonus stages + bosses).
## See LevelConfig "build 016 progression" for the order.


## Build 015 API: true when a boss fight (either boss) follows `level`.
static func boss_follows(level: int) -> bool:
	return level == LevelConfig.BOSS_AFTER_LEVEL or level == LevelConfig.BOSS2_AFTER_LEVEL


## True when the bonus stage follows `level` (1, 4, 7, 10, ... by default).
static func bonus_follows(level: int, first: int = LevelConfig.BONUS_FIRST_AFTER, every: int = LevelConfig.BONUS_EVERY) -> bool:
	return level >= first and every > 0 and (level - first) % every == 0


## Which bonus stage this is (1 = the first one, after level 1). Drives the
## per-repeat difficulty.
static func bonus_index(level: int, first: int = LevelConfig.BONUS_FIRST_AFTER, every: int = LevelConfig.BONUS_EVERY) -> int:
	return 1 + maxi(level - first, 0) / maxi(every, 1)


## Stages played after clearing `level`, in order: "bonus" first, then the
## boss ("boss1" Trustin, "boss2" Huval). Empty = straight to level + 1.
## The optional arguments exist so tests can check coinciding slots.
static func stages_after(level: int, boss1_after: int = LevelConfig.BOSS_AFTER_LEVEL,
		boss2_after: int = LevelConfig.BOSS2_AFTER_LEVEL,
		bonus_first: int = LevelConfig.BONUS_FIRST_AFTER, bonus_every: int = LevelConfig.BONUS_EVERY) -> Array[String]:
	var out: Array[String] = []
	if bonus_follows(level, bonus_first, bonus_every):
		out.append("bonus")
	if level == boss1_after:
		out.append("boss1")
	if level == boss2_after:
		out.append("boss2")
	return out


static func stage_scene(stage: String) -> String:
	match stage:
		"bonus":
			return LevelConfig.BONUS_SCENE
		"boss1":
			return LevelConfig.BOSS_SCENE
		"boss2":
			return LevelConfig.BOSS2_SCENE
	return LevelConfig.GAME_SCENE


## Text for the end-of-level button / "NEXT:" line.
static func stage_label(stage: String) -> String:
	match stage:
		"bonus":
			return "BONUS STAGE"
		"boss1":
			return LevelConfig.BOSS_NAME
		"boss2":
			return LevelConfig.BOSS2_NAME
	return ""


## The whole run as a list, e.g. ["L1", "BONUS1", "L2", "BOSS:TRUSTIN JUDEAU", ...]
## (tests + README).
static func progression(levels: int, boss1_after: int = LevelConfig.BOSS_AFTER_LEVEL,
		boss2_after: int = LevelConfig.BOSS2_AFTER_LEVEL,
		bonus_first: int = LevelConfig.BONUS_FIRST_AFTER, bonus_every: int = LevelConfig.BONUS_EVERY) -> Array[String]:
	var out: Array[String] = []
	for l in range(1, levels + 1):
		out.append("L%d" % l)
		for s in stages_after(l, boss1_after, boss2_after, bonus_first, bonus_every):
			if s == "bonus":
				out.append("BONUS%d" % bonus_index(l, bonus_first, bonus_every))
			else:
				out.append("BOSS:" + stage_label(s))
	return out
