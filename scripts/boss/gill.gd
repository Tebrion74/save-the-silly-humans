class_name GillBates
extends ShlausKwobb
## Build 020 boss 5: GILL BATES, PATRON OF THE SERVER FARM. A good-natured
## cartoon parody of a cheerful software tycoon (sandy mop, big round glasses,
## pale-blue V-neck sweater, khakis, a floppy disk held high). Art:
## tools/gen_boss5.py -> assets/boss5/gill_96.png. Arena: gill_level.gd.
##
## Runs on Shlaus Kwobb's fight engine with LevelConfig.BOSS5_* numbers:
##  - BETA TESTERS: hologram delegates of earlier bosses (poutine / sheep)
##  - PROGRAMMED SHEEP he clicks in himself (more of them than Shlaus)
##  - FLOPPY PATCHES: a telegraphed fan of floppy disks (4-7)
##  - BLUE SCREEN: an expanding blue ring with two gaps (phase 2+)
##  - REBOOT hops (teleport with a destination telegraph) in rage
##  - SYSTEM UPDATE shield at 15, 10 and 5 hearts (ends in a free BLUE SCREEN)
## 20 hearts. Same hit rules as every boss (whip 1, fire +1 delayed, cam:
## "NO SCREENSHOTS!" he hides his face).

const SHEET5 := preload("res://assets/boss5/gill_96.png")


func _init() -> void:
	use_cfg(5)
	sheet = SHEET5
	projectile_skin = "floppy"
	ring_skin = "bluescreen"
	quip_color = Color(0.55, 0.8, 1.0)
	hit_quips = ["THAT'S A BUG, NOT A FEATURE!", "CTRL+ALT+OUCH!", "PLEASE RESTART YOUR RANCHER!", "I'LL PATCH THAT!", "THIS VOIDS MY WARRANTY!"]
	cast_quips = ["BETA TESTERS, ASSEMBLE!", "INSTALLING SHEEP 2.0...", "PUSHING AN UPDATE!", "PLEASE ACCEPT THE TERMS!"]
	shield_quips = ["UPDATING... DO NOT TURN OFF!", "37% COMPLETE...", "PLEASE WAIT..."]
	grab_quip = "HANDS OFF THE HARDWARE!"
	press_quips = ["NO SCREENSHOTS!", "THAT'S PROPRIETARY!", "NDA, PLEASE!"]
	defeat_quip = "FATAL ERROR... REBOOTING"
	panel_quip = "SYSTEM UPDATE!"
	fire_quip = "MY SERVERS ARE OVERHEATING!"
	hop_label = "REBOOT"
	panel_label = "SYSTEM UPDATE"
	press_label = "NO SCREENSHOTS!"
