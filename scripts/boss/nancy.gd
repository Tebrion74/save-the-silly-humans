class_name NancyPelotto
extends ShlausKwobb
## Build 020 boss 6: NANCY PELOTTO, SPEAKER OF THE HOUSE. A good-natured
## cartoon parody of a long-serving speaker (auburn bob, magenta pantsuit,
## pearls, a giant gavel, an ice-cream cone at rest). Art:
## tools/gen_boss5.py -> assets/boss6/nancy_96.png. Arena: nancy_level.gd.
##
## Runs on Shlaus Kwobb's fight engine with LevelConfig.BOSS6_* numbers:
##  - COMMITTEE HEARINGS: hologram delegates of earlier bosses testify
##    (poutine / programmed sheep)
##  - ICE CREAM: a telegraphed fan of cones (4-7), from phase 1
##  - ORDER!: a gavel shockwave ring with two gaps, from phase 1
##  - FILIBUSTER hops (teleport with a destination telegraph) in rage
##  - IN RECESS shield at 17, 11 and 5 hearts (ends in a free ORDER! ring)
## 22 hearts - the toughest fight in the game.

const SHEET6 := preload("res://assets/boss6/nancy_96.png")


func _init() -> void:
	use_cfg(6)
	sheet = SHEET6
	projectile_skin = "icecream"
	ring_skin = "gavel"
	quip_color = Color(1.0, 0.6, 0.85)
	hit_quips = ["OUT OF ORDER!", "THE CHAIR DOES NOT RECOGNISE YOU!", "POINT OF ORDER!", "YOU'RE NOT ON THE AGENDA!", "I'LL TABLE THAT!"]
	cast_quips = ["THE COMMITTEE WILL COME TO ORDER!", "I CALL A WITNESS!", "ALL IN FAVOUR?", "THE AYES HAVE IT!"]
	shield_quips = ["THE HOUSE IS IN RECESS!", "COME BACK AFTER LUNCH!", "NO VOTES DURING RECESS!"]
	grab_quip = "UNHAND THE SPEAKER!"
	press_quips = ["NO COMMENT!", "TALK TO MY PRESS OFFICE!", "NOT NOW, DEAR!"]
	defeat_quip = "THE HOUSE IS... ADJOURNED"
	panel_quip = "RECESS!"
	fire_quip = "MY ICE CREAM IS MELTING!"
	hop_label = "FILIBUSTER"
	panel_label = "IN RECESS"
	press_label = "NO COMMENT!"
