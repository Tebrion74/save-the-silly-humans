class_name LevelConfig
extends RefCounted
## Build 010: every round/level tuning number lives here.
## Level numbers start at 1. GameProgress (autoload) holds the current level.

## Humans per round: INITIAL_HUMANS placed at round start + the rest from the camp.
const ROUND_TOTAL_HUMANS := 20
const INITIAL_HUMANS := 5
const INITIAL_SHEEP := 5

## Silly human camp (southwest), build 011: a new human is generated only while
## fewer than CAMP_LIVING_THRESHOLD living silly humans (on map, unresolved, not
## possessed) exist, and never sooner than CAMP_MIN_SPAWN_INTERVAL seconds after
## the previous camp spawn (or round start). Stops at ROUND_TOTAL_HUMANS.
const CAMP_LIVING_THRESHOLD := INITIAL_HUMANS
const CAMP_MIN_SPAWN_INTERVAL := 5.0

## Saves needed out of ROUND_TOTAL_HUMANS: level 1 = 5, +1 per level, capped.
const TARGET_LEVEL1 := 5
const TARGET_STEP := 1
const TARGET_CAP := 15

## Killer sheep speed multiplier per level (level 1 = 1.0 = build 009 speed).
const SHEEP_SPEED_STEP := 0.06
## Sheep den interval: level 1 value, multiplied by DEN_INTERVAL_FACTOR each level,
## never below DEN_INTERVAL_FLOOR. Cap on living sheep is unchanged (20).
const DEN_INTERVAL_LEVEL1 := 90.0
const DEN_INTERVAL_FACTOR := 0.92
const DEN_INTERVAL_FLOOR := 40.0
const DEN_MAX_LIVING_SHEEP := 20

## Silly human wander speed is randomized per human in this range (px/s).
const HUMAN_WANDER_SPEED_MIN := 50.0
const HUMAN_WANDER_SPEED_MAX := 92.0


static func target_for(level: int) -> int:
	var lv := maxi(level, 1)
	return mini(TARGET_LEVEL1 + (lv - 1) * TARGET_STEP, TARGET_CAP)


static func sheep_speed_mult(level: int) -> float:
	return 1.0 + float(maxi(level, 1) - 1) * SHEEP_SPEED_STEP


static func den_interval(level: int) -> float:
	var lv := maxi(level, 1)
	return maxf(DEN_INTERVAL_LEVEL1 * pow(DEN_INTERVAL_FACTOR, float(lv - 1)), DEN_INTERVAL_FLOOR)


# ---------------------------------------------------------------- build 013
## Karens (gregarious converted humans). Below KAREN_MIN_LEVEL possessed humans
## behave exactly as in build 012.
const KAREN_MIN_LEVEL := 3
## "More than three": this many possessed humans clustered together turn into Karens.
const KAREN_CLUSTER_SIZE := 4
## A possessed human with (KAREN_CLUSTER_SIZE - 1) other possessed/Karens within
## this radius (px) triggers the transformation for the whole cluster.
const KAREN_CLUSTER_RADIUS := 120.0
## Possessed humans (level 3+) steer toward the nearest other possessed / Karen
## within this range, at this speed. A silly human closer than
## KAREN_SEEK_DISTRACT still gets bitten first.
const KAREN_SEEK_RANGE := 900.0
const KAREN_SEEK_SPEED := 85.0
const KAREN_SEEK_DISTRACT := 70.0
## Once this close to the group they stop seeking and hunt as usual.
const KAREN_SEEK_SETTLE := 50.0
## Karen stats. Speed is multiplied by sheep_speed_mult(level); the rancher runs 260.
const KAREN_SPEED := 132.0
const KAREN_HP := 2                 ## whip hits (or fire ticks / shockwaves) to destroy
const KAREN_MOB_RANGE := 520.0      ## chase the rancher when this close
const KAREN_REACH := 34.0           ## contact distance for hits / bites
const KAREN_DAMAGE := 1             ## hearts per mob hit
## The whole mob can hurt the rancher at most once per this many seconds, so a
## crowd of Karens is dangerous but never an instant kill.
const KAREN_MOB_HIT_INTERVAL := 0.9
const KAREN_BITE_COOLDOWN := 1.0    ## per-Karen bite on silly humans (5 bites = possessed)
const KAREN_SEPARATION := 26.0      ## Karens push apart inside this distance
const POINTS_KAREN := 100

## Power-ups: drop chance per kill, weighted type table, lifetimes.
const DROP_CHANCE_SHEEP := 0.12
const DROP_CHANCE_POSSESSED := 0.22
const DROP_CHANCE_KAREN := 0.40
## Weights for the type roll (HEALTH is the most common).
## Build 014 adds "msm_cam" and "battery"; their weights are adjusted at roll
## time (see CAM_* / BATTERY_* below).
const POWERUP_WEIGHTS := {
	"health": 30,
	"long_whip": 14,
	"strong_throw": 12,
	"shockwave": 14,
	"fire_whip": 16,
	"whip_shot": 14,
	"msm_cam": 8,
	"battery": 5,
}
## Build 014: power-ups have NO timers any more (see the build 014 section).
## Pickups vanish after this many seconds (they blink for the last 3 s).
const PICKUP_LIFETIME := 12.0
const PICKUP_RADIUS := 30.0
const LONG_WHIP_MULT := 1.5         ## whip reach 210 -> 315 px (and touch assist range)
const STRONG_THROW_MULT := 1.6      ## throw force 800 -> 1280
const SHOCKWAVE_RADIUS := 95.0      ## area hit around the whip tip
const FIRE_IGNITE_RADIUS := 60.0    ## fire crack ignites burnables near the tip
const FIRE_DURATION := 3.0          ## seconds a fire burns
const FIRE_TICK := 0.6              ## damage tick (1 hit per tick)
const FIRE_SPREAD_RADIUS := 36.0    ## burning creatures ignite others on contact
const FIRE_SPREAD_DELAY := 0.25     ## a fresh fire needs this long before it can spread
const WHIP_SHOT_SPEED := 560.0
const WHIP_SHOT_RANGE := 560.0
const WHIP_SHOT_HIT_RADIUS := 24.0


static func karens_enabled(level: int) -> bool:
	return level >= KAREN_MIN_LEVEL


static func karen_speed(level: int) -> float:
	return KAREN_SPEED * sheep_speed_mult(level)


# ---------------------------------------------------------------- build 014
## No power-up timers. Whip mods persist, fire/shockwave are charges, the
## MSM Cam is a slottable weapon with a battery, batteries are inventory.

## Persistent whip mods: one at a time, kept until a different one is picked up.
const WHIP_MODS := ["long_whip", "strong_throw", "whip_shot"]
## FIRE WHIP: lashes of fire per pickup (stacks up to the max). Each whip crack
## uses one; at 0 the whip goes back to the current whip mod / normal whip.
const FIRE_CHARGES := 10
const FIRE_CHARGES_MAX := 20
## SHOCKWAVE: charges per pickup, one per whip crack, stacks up to the max.
const SHOCK_CHARGES := 3
const SHOCK_CHARGES_MAX := 6
## Inventory (cam, battery, spares, whip mod, charges) carries into the next
## level of a run. Retry restores what you had when the level started.
const INVENTORY_CARRIES_OVER := true

## Weapon slots, in order. Slot 1 (whip) is always owned; the rest are added by
## pickups. Add new weapons here (id, display name, HUD icon kind).
## Every weapon has a PRIMARY and a SECONDARY action (PC: LMB / RMB, touch:
## bottom-right / top-right wedge). `node` is the Player child that
## implements weapon_primary() / weapon_secondary(); labels show on the
## touch wedges and the HUD.
const WEAPON_DEFS := [
	{"id": "whip", "name": "WHIP", "icon": "whip", "node": "Whip",
		"primary": "WHIP", "secondary": "GRAB",
		"primary_col": Color(1.0, 0.82, 0.25), "secondary_col": Color(0.45, 0.8, 1.0)},
	{"id": "cam", "name": "MSM CAM", "icon": "msm_cam", "node": "MsmCam",
		"primary": "REC", "secondary": "SWING",
		"primary_col": Color(1.0, 0.22, 0.2), "secondary_col": Color(0.75, 0.6, 1.0)},
]

## MSM Cam (weapon). Range is CAM_RANGE_MULT x the base whip reach (210 px).
const CAM_HALF_ANGLE_DEG := 19.5        ## 39 degree cone
const CAM_RANGE_MULT := 2.0             ## 420 px
const CAM_BATTERY_SECONDS := 20.0       ## filming time per battery
const CAM_SPARE_BATTERIES_MAX := 3
## Silly humans: seconds in the cone to fill the "convinced" meter. It drains
## at CAM_CONVINCE_DECAY (fraction per second) when out of the cone.
const CAM_CONVINCE_TIME := 1.5
const CAM_CONVINCE_DECAY := 0.35
const CAM_CONVINCED_SPEED_MULT := 1.25  ## x the human's own wander speed
## Karens: cumulative seconds with >= CAM_EXPOSE_MIN_KARENS (or every living
## Karen, if fewer are alive) in the cone -> VIRAL: every silly human on the map
## stampedes to the safe zone for CAM_STAMPEDE_SECONDS (or until saved).
const CAM_EXPOSE_SECONDS := 3.0
const CAM_EXPOSE_MIN_KARENS := 2
const CAM_STAMPEDE_SECONDS := 8.0
const CAM_STAMPEDE_SPEED_MULT := 1.5    ## x the human's own wander speed
## Karens love cameras: in the cone and for CAM_KAREN_LINGER s after.
const CAM_KAREN_SPEED_MULT := 1.35
const CAM_KAREN_LINGER := 2.0
const CAM_KAREN_ZIGZAG_HZ := 3.2        ## side-to-side wiggles per second
const CAM_KAREN_ZIGZAG_AMP := 0.85      ## sideways speed as a fraction of forward
## Each second a Karen spends in the cone has this chance to possess a random
## silly human somewhere on the map.
const CAM_INFECT_CHANCE_PER_SEC := 0.02
## Sheep den spawn timer runs this much faster while filming (cap unchanged).
const CAM_SHEEP_RATE_MULT := 1.6

## MSM Cam SECONDARY: camcorder SWING. No damage, no battery; works with a
## dead battery. Pushes sheep / possessed / Karens back and staggers them.
const SWING_RANGE_MULT := 0.6           ## x base whip reach = 126 px
const SWING_HALF_ARC_DEG := 45.0        ## 90 degree arc in front
const SWING_PUSH_PX := 200.0            ## knockback distance (approx.)
const SWING_STAGGER := 0.6              ## seconds the target can't act
const SWING_COOLDOWN := 0.5
const SWING_FILM_PAUSE := 0.3           ## filming pauses this long, then resumes if REC is held
## Push velocity that decays to roughly SWING_PUSH_PX (targets damp
## external velocity at rate 3/s).
const SWING_PUSH_DAMPING := 3.0

## Drops. MSM Cam weight (POWERUP_WEIGHTS.msm_cam) is multiplied by
## CAM_KAREN_DROP_MULT for Karen kills and by CAM_OWNED_WEIGHT_MULT once you
## own the cam (a 2nd cam = battery refill). Battery weight is
## POWERUP_WEIGHTS.battery before you own the cam, BATTERY_WEIGHT_OWNED after.
const CAM_KAREN_DROP_MULT := 2.5
const CAM_OWNED_WEIGHT_MULT := 0.25
const BATTERY_WEIGHT_OWNED := 20
## Cam and battery pickups stay on the ground a bit longer than the rest.
const PICKUP_LIFETIME_RARE := 20.0


static func cam_range(base_whip_range: float = 210.0) -> float:
	return base_whip_range * CAM_RANGE_MULT


static func weapon_def(id: String) -> Dictionary:
	for d in WEAPON_DEFS:
		if d["id"] == id:
			return d
	return {}


# ---------------------------------------------------------------- build 014 touch
## Touch action buttons are corner wedges (see touch_controls.gd). Sizes are
## fractions of the viewport HEIGHT (thumb size scales with the short side in
## landscape), so the layout adapts to 19.5:9, 16:9 and 4:3.
## Bottom-right = PRIMARY, top-right = SECONDARY.
const WEDGE_ANGLE_DEG := 30.0           ## diagonal edge, degrees from horizontal
const WEDGE_HEIGHT_FRAC := 0.27         ## 194 px at 720
const WEDGE_INNER_FRAC := 0.20          ## width along the far edge (144 px)
## Top-left weapon exchange wedge (smaller).
const SWAP_WEDGE_HEIGHT_FRAC := 0.16    ## 115 px
const SWAP_WEDGE_INNER_FRAC := 0.14     ## 101 px
const WEDGE_TOUCH_SLOP := 14.0          ## polygon grown by this for hit tests


static func wedge_outer_width(h: float, inner: float, angle_deg: float = WEDGE_ANGLE_DEG) -> float:
	return inner + h / tan(deg_to_rad(angle_deg))



# ---------------------------------------------------------------- build 014b reticle
## Aim reticle (scripts/ui/reticle.gd). PC: replaces the OS mouse pointer during
## gameplay. Touch: a crosshair at the current weapon's reach along the facing.
## GREEN = the current weapon's PRIMARY would hit / affect a valid target,
## otherwise matte RED.
const RETICLE_RADIUS := 11.0            ## ring radius (px, screen)
const RETICLE_ARM := 7.0                ## crosshair arm length outside the ring
const RETICLE_GAP := 3.0                ## arms start this far inside the ring
const RETICLE_THICK := 2.0              ## line thickness (1 px dark outline added)
const RETICLE_GREEN := Color(0.46, 1.0, 0.40)
const RETICLE_RED := Color(0.72, 0.33, 0.31)        ## matte / desaturated
const RETICLE_OUTLINE := Color(0.06, 0.03, 0.08)
const RETICLE_ALPHA := 0.92
## PC whip: the reticle may sit this far past the whip's reach and still count
## as "in reach"; also the radius of the lock-on brackets drawn on the target.
## The target test itself is the whip's own PC aim assist (find_target: 70 px
## around the reticle or 36 px around the aim line), so green == a sure hit.
const RETICLE_SNAP_RADIUS := 28.0
## Touch: full brightness while the joystick / a wedge is held and for this
## long after release, then it fades to RETICLE_TOUCH_IDLE_ALPHA (always faintly
## visible during play). Green is always full brightness.
const RETICLE_TOUCH_HOLD := 1.0
const RETICLE_TOUCH_IDLE_ALPHA := 0.35
## Fire / film feedback: ring grows by this fraction and brightens on a crack,
## grab or swing; a gentle pulse while filming.
const RETICLE_PULSE := 0.35
## Max-reach marker (PC, reticle beyond reach): dot alpha.
const RETICLE_REACH_DOT_ALPHA := 0.75
## CanvasLayer: under the HUD (10) and the touch wedges (11).
const RETICLE_LAYER := 9


# ---------------------------------------------------------------- build 015 boss
## Boss battle: TRUSTIN JUDEAU (scripts/boss/, scenes/levels/BossArena.tscn).
## The fight sits BETWEEN level BOSS_AFTER_LEVEL and the next level: clearing
## level 2 leads into the boss arena, beating him advances to level 3. Dying
## in the arena retries the boss (score + inventory restored to the boss start).
const BOSS_AFTER_LEVEL := 2
const BOSS_SCENE := "res://scenes/levels/BossArena.tscn"
const GAME_SCENE := "res://scenes/Main.tscn"
const BOSS_NAME := "TRUSTIN JUDEAU"
const BOSS_TITLE := "PRIME MINISTER OF POUTINE"
## Hearts and hit rules.
const BOSS_HEARTS := 10
const BOSS_IFRAMES := 0.6               ## seconds of invulnerability after any heart lost
const BOSS_HIT_PUSH := 260.0            ## knock-back velocity on a whip hit (decays at SWING_PUSH_DAMPING/s, ~85 px)
## FIRE WHIP: a fire crack on him burns for one extra heart after this delay
## (once per fire crack, it never stacks; delay > i-frames so it always lands).
const BOSS_FIRE_DELAY := 0.75
## MSM Cam: filming him makes him POSE (stops, cancels a wind-up, grins at the
## lens). No damage. He holds the pose while filmed, up to BOSS_POSE_MAX, keeps
## it BOSS_POSE_LINGER after the cam stops (swap to the whip and crack him!),
## then he's camera-shy for BOSS_POSE_COOLDOWN.
const BOSS_POSE_MAX := 2.2
const BOSS_POSE_LINGER := 0.8
const BOSS_POSE_COOLDOWN := 6.0
## SWING (cam) and GRAB (whip) shove him (he's too heavy to throw) and stagger
## him; both can cancel a wind-up, at most once per BOSS_INTERRUPT_COOLDOWN.
const BOSS_SWING_PUSH_MULT := 0.6       ## x the normal swing push (~120 px)
const BOSS_GRAB_TUG := 300.0            ## tug velocity toward the throw direction (~100 px)
const BOSS_STAGGER := 0.6
const BOSS_INTERRUPT_COOLDOWN := 3.0
## Movement: strafes around the rancher inside whip-able range, short dashes.
const BOSS_STRAFE_SPEED := 95.0
const BOSS_STRAFE_SPEED_RAGE := 125.0   ## at <= BOSS_RAGE_HEARTS
const BOSS_PREF_DIST := 250.0           ## orbit distance (whip reach is 210)
const BOSS_RETREAT_DIST := 120.0        ## backs off (slower than you) when closer
const BOSS_DASH_SPEED := 620.0
const BOSS_DASH_TIME := 0.26            ## ~160 px
const BOSS_DASH_TELL := 0.25            ## crouch + dust before a dash
const BOSS_DASH_EVERY := Vector2(3.0, 5.0)
## Attacks. Every attack is telegraphed by a wind-up (arm up, poutine in hand,
## "!" and an aim line / landing ring) of BOSS_WINDUP seconds.
const BOSS_WINDUP := 0.5
const BOSS_WINDUP_RAGE := 0.42
const BOSS_INTRO_TIME := 2.8            ## title card; he waves and doesn't attack
## Phases by hearts left: 10-8 single aimed shots; 7-5 adds 3-way spreads;
## 4-3 adds the lobbed poutine; 2-1 (rage) adds fast volleys + radial bursts.
const BOSS_PHASE2_HEARTS := 7
const BOSS_PHASE3_HEARTS := 4
const BOSS_RAGE_HEARTS := 2
## Pause between attacks (after the throw) per phase 1..4.
const BOSS_ATTACK_GAP := [1.5, 1.3, 1.15, 1.0]
## Poutine projectiles.
const POUTINE_SPEED := 290.0            ## single aimed shot
const POUTINE_SPREAD_SPEED := 270.0
const POUTINE_SPREAD_DEG := 20.0        ## 3-way: -20 / 0 / +20 degrees
const POUTINE_VOLLEY_SPEED := 360.0     ## rage: 3 quick aimed shots
const POUTINE_VOLLEY_COUNT := 3
const POUTINE_VOLLEY_GAP := 0.2
const POUTINE_RADIAL_COUNT := 10        ## rage: ring of 10 (36 degree gaps)
const POUTINE_RADIAL_SPEED := 220.0
const POUTINE_LOB_TIME := 1.1           ## lob flight time; the landing ring shows all along
const POUTINE_LOB_HEIGHT := 150.0
const POUTINE_LOB_RADIUS := 42.0        ## splash radius on landing
const POUTINE_HIT_RADIUS := 22.0        ## flying poutine vs the rancher's body
const POUTINE_RANGE := 900.0
const POUTINE_DAMAGE := 1               ## hearts, the existing 1-per-hit rule
## The rancher can lose at most 1 heart per this many seconds to poutine (same
## idea as the Karen mob cooldown), so a burst can never chain-hit.
const BOSS_PLAYER_HIT_COOLDOWN := 0.8
## Scoring.
const BOSS_POINTS_PER_HEART := 100
const BOSS_DEFEAT_BONUS := 2500
const BOSS_HEALTH_BONUS := 300          ## per rancher heart left at the win
const BOSS_TIME_PAR := 90.0             ## +BOSS_TIME_BONUS_PER_SEC for every second under par
const BOSS_TIME_BONUS_PER_SEC := 20
const BOSS_DEFEAT_ANIM := 1.8           ## defeat animation before the win screen


static func boss_phase(hearts: int) -> int:
	if hearts <= BOSS_RAGE_HEARTS:
		return 4
	if hearts <= BOSS_PHASE3_HEARTS:
		return 3
	if hearts <= BOSS_PHASE2_HEARTS:
		return 2
	return 1
