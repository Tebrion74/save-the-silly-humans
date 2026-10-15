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

## Saves needed out of ROUND_TOTAL_HUMANS. Build 020: levels 1-2 (before the
## Trustin boss) need 5; level 3 (after Trustin) needs 6, then +1 per level,
## capped at TARGET_CAP (reached at level 12).
const TARGET_LEVEL1 := 5
const TARGET_STEP := 1
const TARGET_CAP := 15
const TARGET_AFTER_BOSS1 := 6

## Build 020 extra hearts: +1 max heart for every HEART_EVERY_LEVELS levels
## completed (5 at levels 1-2, 6 at 3-4, 7 at 5-6, 8 from level 7 on).
## Capped at HEARTS_CAP so the HUD row stays short and late levels stay tense.
## You start each level/stage with full hearts (unchanged).
## Build 020 spawn adjustment: from ROUND_EXTRA_FROM_LEVEL the camp sends one
## more human per level (cap ROUND_TOTAL_CAP), so the capped 15-save target
## keeps some margin: L10 21, L11 22, L12 23, L13+ 24 humans (L1-9: 20).
const ROUND_EXTRA_FROM_LEVEL := 10
const ROUND_TOTAL_CAP := 24
const HEARTS_BASE := 5
const HEART_EVERY_LEVELS := 2
const HEARTS_CAP := 16   # build 027: was 12 (build 022: was 8)

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
	if lv <= BOSS_AFTER_LEVEL:
		return TARGET_LEVEL1
	return mini(TARGET_AFTER_BOSS1 + (lv - BOSS_AFTER_LEVEL - 1) * TARGET_STEP, TARGET_CAP)


static func round_total_for(level: int) -> int:
	if level < ROUND_EXTRA_FROM_LEVEL:
		return ROUND_TOTAL_HUMANS
	return mini(ROUND_TOTAL_HUMANS + level - ROUND_EXTRA_FROM_LEVEL + 1, ROUND_TOTAL_CAP)


## Build 020: max hearts after `levels_completed` cleared levels.
static func max_hearts_for(levels_completed: int) -> int:
	return mini(HEARTS_BASE + maxi(levels_completed, 0) / HEART_EVERY_LEVELS, HEARTS_CAP)


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

# ---------------------------------------------------------------- build 017 cantifa
## CANTIFA: a cartoon black-bloc mob. Not saveable humans. They are not Karens.
## From level 4 on, 1 in CANTIFA_SPAWN_EVERY human spawn rolls (the 5 placed at
## the start and every camp arrival) is a Cantifa instead, walking in from off
## the map. A roll is skipped (a real human arrives) when the on-screen cap is
## full, or when replacing one more human would drop the best-case saves below
## the level target. They never spawn in the bonus stage or a boss arena.
const CANTIFA_MIN_LEVEL := 4
const CANTIFA_SPAWN_EVERY := 5          ## exactly 1 in 5 rolls
## On-screen cap: 3 at level 4, +1 every two levels, never more than 6.
const CANTIFA_CAP_BASE := 3
const CANTIFA_CAP_MAX := 6
const CANTIFA_HP := 2                   ## whip / shockwave / shot hits to drive off
const POINTS_CANTIFA := 75
## Posts just outside the zones. Safe-zone ring is drawn at 95 px.
const CANTIFA_SAFE_POST := 158.0        ## px from the safe-zone centre
const CANTIFA_SAFE_KEEP_OUT := 120.0    ## never walk closer than this
const CANTIFA_CAMP_POST := 230.0
const CANTIFA_CAMP_KEEP_OUT := 200.0
const CANTIFA_POSTS_PER_ZONE := 4
const CANTIFA_HOLD_DIST := 22.0         ## this close = posted, may shoot
const CANTIFA_DRIFT_SPEED := 80.0
const CANTIFA_ARRIVE_SPEED := 130.0
const CANTIFA_FLEE_SPEED := 220.0
const CANTIFA_SCATTER_TIME := 0.85
const CANTIFA_SCATTER_RADIUS := 260.0
const CANTIFA_SEPARATION := 34.0
## Rifle. Telegraph, then a straight tracer. Mercy window is the boss one
## (BOSS_PLAYER_HIT_COOLDOWN) so a burst can't empty the hearts.
const CANTIFA_TELL := 0.25
const CANTIFA_COOLDOWN_MIN := 0.70
const CANTIFA_COOLDOWN_MAX := 0.90
const CANTIFA_RANGE_L4 := 315.0         ## 1.5 x the 210 px whip
const CANTIFA_RANGE_PER_LEVEL := 12.0
const CANTIFA_RANGE_CAP := 420.0
const CANTIFA_BULLET_SPEED := 460.0
const CANTIFA_SPREAD_L4 := 14.0         ## +/- degrees, level 4
const CANTIFA_SPREAD_STEP := 0.6        ## tighter each level after 4
const CANTIFA_SPREAD_MIN := 8.0
const CANTIFA_CONE_DEG := 70.0          ## they only fire inside this arc
const CANTIFA_BULLET_RADIUS := 11.0
## Filming one: humans in the cone stampede (existing VIRAL run), and Karens
## get angrier than the normal "Karens love cameras" buff.
const CANTIFA_RAGE_TIME := 2.5
const CANTIFA_RAGE_SPEED_MULT := 1.75   ## cam-love is 1.35
const CANTIFA_RAGE_ZIG_AMP := 1.4


static func cantifa_enabled(level: int) -> bool:
	return level >= CANTIFA_MIN_LEVEL


static func cantifa_cap(level: int) -> int:
	if not cantifa_enabled(level):
		return 0
	if level <= CANTIFA_RAMP_FROM:
		return mini(CANTIFA_CAP_BASE + (level - CANTIFA_MIN_LEVEL) / 2, CANTIFA_CAP_MAX)
	# build 023: +1 every 2 levels above L8, up to CANTIFA_CAP_LATE
	return mini(CANTIFA_CAP_MAX - 1 + (level - CANTIFA_RAMP_FROM + 1) / 2, CANTIFA_CAP_LATE)


## Build 023: 1 in N human-spawn rolls become Cantifa (5 up to L8, 4 for L9-11, 3 from L12).
static func cantifa_spawn_every(level: int) -> int:
	if level <= CANTIFA_RAMP_FROM:
		return CANTIFA_SPAWN_EVERY
	return maxi(CANTIFA_SPAWN_EVERY - 1 - (level - CANTIFA_RAMP_FROM - 1) / 3, CANTIFA_SPAWN_EVERY_MIN)


static func cantifa_range(level: int) -> float:
	var lv := maxi(level, CANTIFA_MIN_LEVEL)
	return minf(CANTIFA_RANGE_L4 + float(lv - CANTIFA_MIN_LEVEL) * CANTIFA_RANGE_PER_LEVEL, CANTIFA_RANGE_CAP)


static func cantifa_spread_deg(level: int) -> float:
	var lv := maxi(level, CANTIFA_MIN_LEVEL)
	return maxf(CANTIFA_SPREAD_L4 - float(lv - CANTIFA_MIN_LEVEL) * CANTIFA_SPREAD_STEP, CANTIFA_SPREAD_MIN)


## Power-ups: drop chance per kill, weighted type table, lifetimes.
const DROP_CHANCE_SHEEP := 0.28      ## build 020: was 0.21 (017), 0.12 (016)
const DROP_CHANCE_POSSESSED := 0.50   ## build 020: was 0.385 (017), 0.22 (016)
const DROP_CHANCE_KAREN := 0.85       ## build 020: was 0.70 (017), 0.40 (016)
## Build 020: timed map spawns (normal levels only). Every
## POWERUP_MAP_INTERVAL seconds of play a random power-up appears on open
## ground POWERUP_MAP_MIN_DIST..MAX_DIST px from the rancher, if fewer than
## POWERUP_MAP_MAX_ON_MAP timed pickups are still lying around. The first one
## comes after POWERUP_MAP_FIRST seconds. They use the normal 12 s lifetime.
const POWERUP_MAP_FIRST := 12.0
const POWERUP_MAP_INTERVAL := 20.0
const POWERUP_MAP_MAX_ON_MAP := 2
const POWERUP_MAP_MIN_DIST := 220.0
const POWERUP_MAP_MAX_DIST := 650.0

## Build 020 INVINCIBLE (star power). Rare pickup, normal levels only (never
## dropped in boss or bonus stages). For INVINCIBLE_SECONDS the rancher can't
## be hurt, and a whip crack on a silly human, possessed human / Karen,
## Cantifa or sheep (they all flash green) SAVES it: it bolts away from the
## rancher for STAR_FLEE_SECONDS, then runs to the safe zone (ghosting through
## obstacles). Humans and possessed humans count as normal rescues when they
## arrive; Cantifa and sheep just leave the field. Each star save scores
## STAR_COMBO_BASE x 2^(combo-1): 200, 400, 800, 1600 ... The combo resets
## if STAR_COMBO_WINDOW s pass without a save, and the per-save value is
## capped at STAR_COMBO_BASE x 2^STAR_COMBO_MAX_DOUBLINGS (102 400).
const INVINCIBLE_SECONDS := 30.0
const INVINCIBLE_WARN_SECONDS := 3.0
const STAR_COMBO_BASE := 200
const STAR_COMBO_WINDOW := 4.0
const STAR_COMBO_MAX_DOUBLINGS := 9
const STAR_FLEE_SECONDS := 0.7
const STAR_FLEE_SPEED := 330.0
const STAR_RUN_SPEED := 300.0


static func star_combo_points(combo: int) -> int:
	return STAR_COMBO_BASE * (1 << clampi(combo - 1, 0, STAR_COMBO_MAX_DOUBLINGS))
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
	"invincible": 3,   ## build 020: rare (~2.5% of rolls), normal levels only
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
const RETICLE_RADIUS := 15.0            ## ring radius (px, screen)
const RETICLE_ARM := 9.0                ## crosshair arm length outside the ring
const RETICLE_GAP := 3.0                ## arms start this far inside the ring
const RETICLE_THICK := 3.0              ## line thickness (1 px dark outline added)
const RETICLE_GREEN := Color(0.30, 1.0, 0.36)      ## build 020: brighter
## build 020: "nothing to hit" is hot magenta (was a matte red that vanished
## on dirt, tarmac and the boss arenas); same meaning
const RETICLE_RED := Color(1.0, 0.24, 0.86)
## bright halo between the dark outline and the colour (readable on any floor)
const RETICLE_HALO := Color(1.0, 1.0, 1.0)
## idle "breathing" pulse (scale), so it catches the eye in busy scenes
const RETICLE_IDLE_PULSE := 0.08
const RETICLE_OUTLINE := Color(0.06, 0.03, 0.08)
const RETICLE_ALPHA := 1.0
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
const BOSS_IFRAMES := 0.9               ## seconds of invulnerability after any heart lost (015b, was 0.6)
const BOSS_HIT_PUSH := 260.0            ## knock-back velocity on a whip hit (decays at SWING_PUSH_DAMPING/s, ~85 px)
## Build 015b: touching him costs the rancher 1 heart (shares the 0.8 s
## BOSS_PLAYER_HIT_COOLDOWN mercy window with poutine hits).
const BOSS_CONTACT_RADIUS := 40.0       ## centre distance (bodies bump at ~34)
const BOSS_CONTACT_DAMAGE := 1
## FIRE WHIP: a fire crack on him burns for one extra heart after this delay
## (once per fire crack, it never stacks; delay > i-frames so it always lands).
const BOSS_FIRE_DELAY := 0.75
const BOSS_FIRE_COOLDOWN := 6.0         ## 015b: at most one fire bonus heart per 6 s
## MSM Cam: filming him makes him POSE (stops, cancels a wind-up, grins at the
## lens). No damage. He holds the pose while filmed, up to BOSS_POSE_MAX, keeps
## it BOSS_POSE_LINGER after the cam stops (swap to the whip and crack him!),
## then he's camera-shy for BOSS_POSE_COOLDOWN.
const BOSS_POSE_MAX := 1.2              ## 015b (was 2.2)
const BOSS_POSE_LINGER := 0.5           ## 015b (was 0.8)
const BOSS_POSE_COOLDOWN := 8.0         ## 015b (was 6.0)
## SWING (cam) and GRAB (whip) shove him (he's too heavy to throw) and stagger
## him; both can cancel a wind-up, at most once per BOSS_INTERRUPT_COOLDOWN.
const BOSS_SWING_PUSH_MULT := 0.6       ## x the normal swing push (~120 px)
const BOSS_GRAB_TUG := 300.0            ## tug velocity toward the throw direction (~100 px)
const BOSS_STAGGER := 0.6
const BOSS_INTERRUPT_COOLDOWN := 3.0
## Movement: strafes around the rancher inside whip-able range, short dashes.
const BOSS_STRAFE_SPEED := 115.0        ## 015b (was 95)
const BOSS_STRAFE_SPEED_RAGE := 145.0   ## at <= BOSS_RAGE_HEARTS (015b, was 125)
const BOSS_PREF_DIST := 310.0           ## orbit distance (whip reach is 210): chase him (015b, was 250)
const BOSS_RETREAT_DIST := 170.0        ## backs off (slower than you) when closer (015b, was 120)
const BOSS_DASH_SPEED := 620.0
const BOSS_DASH_TIME := 0.26            ## ~160 px
const BOSS_DASH_TELL := 0.25            ## crouch + dust before a dash
const BOSS_DASH_EVERY := Vector2(2.0, 3.0)   ## 015b (was 3-5 s)
## 015b: right after a hit he dash-strafes away (short 0.12 s tell).
const BOSS_FLEE_TELL := 0.12
const BOSS_FLEE_COOLDOWN := 1.6         ## 015b: hits inside this window after a flee don't trigger another
const BOSS_COUNTER_GAP := 0.25          ## 015b: after a flee dash he throws again this soon
const BOSS_RETREAT_MULT := 1.5          ## 015b: back-off speed x strafe speed (was 1.1; still slower than you)
## Attacks. Every attack is telegraphed by a wind-up (arm up, poutine in hand,
## "!" and an aim line / landing ring) of BOSS_WINDUP seconds.
const BOSS_WINDUP := 0.4                ## 015b (was 0.5)
const BOSS_WINDUP_RAGE := 0.32          ## 015b (was 0.42)
const BOSS_INTRO_TIME := 2.8            ## title card; he waves and doesn't attack
## Phases by hearts left: 10-8 single aimed shots; 7-5 adds 3-way spreads;
## 4-3 adds the lobbed poutine; 2-1 (rage) adds fast volleys + radial bursts.
const BOSS_PHASE2_HEARTS := 7
const BOSS_PHASE3_HEARTS := 4
const BOSS_RAGE_HEARTS := 2
## Pause between attacks (after the throw) per phase 1..4.
const BOSS_ATTACK_GAP := [1.1, 0.95, 0.8, 0.65]   ## 015b (was 1.5/1.3/1.15/1.0)
## Poutine projectiles.
const POUTINE_SPEED := 360.0            ## single aimed shot (015b, was 290)
const POUTINE_SPREAD_SPEED := 335.0     ## 015b (was 270)
const POUTINE_SPREAD_DEG := 20.0        ## 3-way: -20 / 0 / +20 degrees
## 015b: phase 3+ spreads are 5-way, 18 degrees apart (gaps ~2x the rancher).
const POUTINE_SPREAD5_DEG := 18.0
const POUTINE_VOLLEY_SPEED := 440.0     ## rage: quick aimed shots (015b, was 360)
const POUTINE_VOLLEY_COUNT := 5         ## 015b (was 3)
const POUTINE_VOLLEY_GAP := 0.17        ## 015b (was 0.2)
const POUTINE_RADIAL_COUNT := 14        ## rage: ring of 14 slots (015b, was 10)
const POUTINE_RADIAL_GAP := 2           ## 015b: 2 neighbouring slots left empty (a safe lane)
const POUTINE_RADIAL_SPEED := 275.0     ## 015b (was 220)
const POUTINE_LOB_TIME := 1.0           ## lob flight time; the landing ring shows all along (015b, was 1.1)
## 015b: phase 3+ lobs come in pairs: one on you, one where you're heading.
const POUTINE_LOB_LEAD := 0.75          ## seconds of your velocity to lead the 2nd lob
const POUTINE_LOB_PAIR_MIN := 90.0      ## the 2nd ring is at least this far from the 1st
## 015b combos: chance that a lob is chained straight into an aimed shot
## (phase 3) or a spread (rage); the chained attack still has its wind-up.
const BOSS_COMBO_CHANCE := [0.0, 0.0, 0.35, 0.5]
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
## 015b PHOTO OP: when he drops to these hearts he waves for the cameras,
## invulnerable, for BOSS_PHOTO_OP_TIME (shimmering shield, no attacks).
const BOSS_PHOTO_OP_HEARTS := [5, 2]
const BOSS_PHOTO_OP_TIME := 1.5


static func boss_phase(hearts: int) -> int:
	if hearts <= BOSS_RAGE_HEARTS:
		return 4
	if hearts <= BOSS_PHASE3_HEARTS:
		return 3
	if hearts <= BOSS_PHASE2_HEARTS:
		return 2
	return 1


# ---------------------------------------------------------------- build 016 progression
## Between-level stages. After clearing level L the game plays, in this order:
##   1. the BONUS STAGE when L == BONUS_FIRST_AFTER + k * BONUS_EVERY (1, 4, 7, 10, ...)
##   2. the boss whose *_AFTER_LEVEL is L (Trustin Judeau after 2, Huval
##      Yarheyhey after 5)
## then level L + 1. So with the defaults:
##   L1 > BONUS 1 > L2 > TRUSTIN > L3 > L4 > BONUS 2 > L5 > HUVAL > L6 > L7 >
##   BONUS 3 > L8 > KUSH > L9 > L10 > BONUS 4 > L11 > KWOBB > L12 > L13 >
##   BONUS 5 > ... (build 018 adds Beorge Kush Jr. after 8, Shlaus Kwobb after 11)
## If a bonus and a boss ever share a slot: level > bonus > boss > next level.
const BONUS_FIRST_AFTER := 1
const BONUS_EVERY := 3
const BONUS_SCENE := "res://scenes/levels/BonusStage.tscn"
const BOSS2_AFTER_LEVEL := 5
const BOSS2_SCENE := "res://scenes/levels/Boss2Arena.tscn"
## Build 018: boss 3 (Beorge Kush Jr.) between levels 8 and 9, boss 4
## (Shlaus Kwobb) between levels 11 and 12. Each placement is this one value.
const BOSS3_AFTER_LEVEL := 8
const BOSS3_SCENE := "res://scenes/levels/Boss3Arena.tscn"
const BOSS4_AFTER_LEVEL := 11
const BOSS4_SCENE := "res://scenes/levels/Boss4Arena.tscn"
## Build 020: boss 5 (Gill Bates) between levels 14 and 15, boss 6 (Nancy
## Pelotto) between levels 17 and 18. Neither is a bonus slot (bonus stages
## follow levels 1, 4, 7 ... = 1 mod 3; 14 and 17 are 2 mod 3).
const BOSS5_AFTER_LEVEL := 14
const BOSS5_SCENE := "res://scenes/levels/Boss5Arena.tscn"
const BOSS6_AFTER_LEVEL := 17
const BOSS6_SCENE := "res://scenes/levels/Boss6Arena.tscn"
## Build 025: boss 7 (Reanald Rogan) between levels 20 and 21, boss 8
## (Zelodymer Violentsky) between levels 23 and 24. Neither is a bonus slot
## (20 and 23 are 2 mod 3).
const BOSS7_AFTER_LEVEL := 20
const BOSS7_SCENE := "res://scenes/levels/Boss7Arena.tscn"
const BOSS8_AFTER_LEVEL := 23
const BOSS8_SCENE := "res://scenes/levels/Boss8Arena.tscn"
## Build 027: boss 9 (Vladimir Puddin) between levels 26 and 27, boss 10
## (Donald Rump, the FINAL boss) after level 29. Neither is a bonus slot
## (26 and 29 are 2 mod 3). Beating Rump plays the ending; ENDLESS goes on to L30.
const BOSS9_AFTER_LEVEL := 26
const BOSS9_SCENE := "res://scenes/levels/Boss9Arena.tscn"
const BOSS10_AFTER_LEVEL := 29
const BOSS10_SCENE := "res://scenes/levels/Boss10Arena.tscn"
const FINAL_BOSS_AFTER_LEVEL := BOSS10_AFTER_LEVEL
const ENDING_SCENE := "res://scenes/ui/Ending.tscn"


# ---------------------------------------------------------------- build 016 bonus stage
## Galaga-style "challenging stage": BONUS_WAVES scripted waves of flying
## bonus sheep swoop across the field; any whip / weapon hit pops one. A sheep
## that leaves the field is a miss. The rancher can't be hurt. Power-ups work
## but nothing is used up (charges / battery are given back afterwards) and
## nothing drops.
const BONUS_TIME := 45.0
const BONUS_WAVES := 8
const BONUS_FIRST_WAVE := 1.0           ## seconds into the countdown (it starts after the title card)
const BONUS_WAVE_EVERY := 5.0           ## a new wave every 5 s (8 waves in ~42 s)
const BONUS_WAVE_SIZE := [5, 5, 6, 6, 6, 7, 7, 8]   ## sheep per wave (bonus 1)
const BONUS_SIZE_PER_REPEAT := 1        ## +1 sheep per wave each later bonus stage (cap 8)
const BONUS_WAVE_MAX := 8
const BONUS_SPACING := 0.32             ## seconds between sheep in a wave
const BONUS_SHEEP_SPEED := 340.0        ## px/s along the flight path (wave 1, bonus 1); the rancher runs 260
const BONUS_WAVE_SPEEDUP := 0.045       ## each later wave is this much faster (x1.315 by wave 8)
const BONUS_FLY_HEIGHT := 14.0          ## sprite drawn this far above its shadow
const BONUS_REPEAT_SPEEDUP := 0.12      ## each later bonus stage is 12% faster (cap BONUS_SPEED_CAP)
const BONUS_SPEED_CAP := 1.7
## Scoring (Galaga numbers, sheep-ified).
const BONUS_POINTS_PER_HIT := 100
const BONUS_WAVE_PERFECT := 500         ## a whole wave popped
const BONUS_PERFECT_BONUS := 10000      ## every sheep of the stage popped
const BONUS_INTRO_TIME := 2.0           ## "BONUS STAGE" title card


static func bonus_wave_size(wave: int, repeat: int) -> int:
	var base: int = BONUS_WAVE_SIZE[clampi(wave, 0, BONUS_WAVE_SIZE.size() - 1)]
	return mini(base + BONUS_SIZE_PER_REPEAT * maxi(repeat - 1, 0), BONUS_WAVE_MAX)


static func bonus_speed(wave: int, repeat: int) -> float:
	var s := (1.0 + BONUS_WAVE_SPEEDUP * wave) * (1.0 + BONUS_REPEAT_SPEEDUP * maxi(repeat - 1, 0))
	return minf(s, BONUS_SPEED_CAP)


static func bonus_total(repeat: int) -> int:
	var n := 0
	for w in BONUS_WAVES:
		n += bonus_wave_size(w, repeat)
	return n


# ---------------------------------------------------------------- build 016 boss 2
## HUVAL YARHEYHEY, PROPHET OF THE ALGORITHM (scripts/boss/huval.gd,
## scenes/levels/Boss2Arena.tscn). Same hit rules as Trustin (whip / shot /
## lash-only shockwave = 1 heart, fire = 1 delayed heart per 6 s, grab and
## swing shove + stagger, contact = 1 heart). His weapon: PROGRAMMED SHEEP.
const BOSS2_NAME := "HUVAL YARHEYHEY"
const BOSS2_TITLE := "PROPHET OF THE ALGORITHM"
const BOSS2_HEARTS := 12
## Phases by hearts left: 12-9 / 8-6 / 5-3 / rage 2-1.
const BOSS2_PHASE2_HEARTS := 8
const BOSS2_PHASE3_HEARTS := 5
const BOSS2_RAGE_HEARTS := 2
## At these hearts he force-installs a SYSTEM UPDATE (1.5 s invulnerable,
## every sheep on the field gets faster).
const BOSS2_UPDATE_HEARTS := [6, 3]
const BOSS2_UPDATE_TIME := 1.5
## Movement (he's a lecturer, not a sprinter; still keeps his distance).
const BOSS2_SPEED := 105.0
const BOSS2_SPEED_RAGE := 135.0
const BOSS2_PREF_DIST := 300.0
const BOSS2_RETREAT_DIST := 170.0
const BOSS2_RETREAT_MULT := 1.5
## Attack rhythm.
const BOSS2_ATTACK_GAP := [1.6, 1.35, 1.15, 0.95]
const BOSS2_SUMMON_TELL := [0.85, 0.8, 0.75, 0.65]     ## clicker raised + spawn rings + glitch
const BOSS2_SUMMON_COUNT := [1, 2, 2, 3]               ## programmed sheep per summon
const BOSS2_SHEEP_CAP := [4, 5, 6, 6]                  ## programmed sheep alive at once
const BOSS2_SPAWN_MIN_DIST := 170.0                    ## spawn rings never closer to you than this
## Programmed sheep: hunt the rancher with a limited turn rate (outrunnable).
const ROBO_SPEED := [115.0, 130.0, 145.0, 160.0]
const ROBO_TURN := 2.2                  ## rad/s
const ROBO_DAMAGE := 1                  ## hearts on contact
const ROBO_HIT_RADIUS := 26.0
const ROBO_BUMP_STUN := 0.8             ## after biting, it bounces back and stalls
## Micro sheep: a programmed sheep that's hit splits into MICRO_SPLIT micros.
const MICRO_SPLIT := 3
const MICRO_SPEED := 190.0
const MICRO_TURN := 3.4
const MICRO_LIFE := 7.0                 ## then it fizzles out on its own
const MICRO_CAP := 12
const MICRO_HIT_RADIUS := 18.0
## Micro damage = HALF a heart: every 2nd micro touch costs 1 heart; a pending
## half shows as a half-empty heart in the HUD and carries through the fight.
const MICRO_CHIPS_PER_HEART := 2
const MICRO_HIT_COOLDOWN := 0.45        ## micro-only mercy window (shorter than 0.8)
## SYSTEM UPDATE (attack, phase 3+, and the forced ones above): every live
## programmed / micro sheep gets this speed multiplier (stacks to SYSTEM_UPDATE_MAX).
const SYSTEM_UPDATE_MULT := 1.25
const SYSTEM_UPDATE_MAX := 1.6
## LECTURE RAY (phase 2+): aim line, locks BOSS2_RAY_LOCK before firing.
const BOSS2_RAY_TELL := [0.75, 0.75, 0.7, 0.6]
const BOSS2_RAY_LOCK := 0.25
const BOSS2_RAY_TIME := 0.3
const BOSS2_RAY_WIDTH := 22.0           ## half width incl. the rancher's body
const BOSS2_RAY_LENGTH := 760.0
## Rage: after a hit (and every few seconds) he TELEPORTS (glitch out, rings
## at the destination for BOSS2_TELEPORT_TELL, then pops in there).
const BOSS2_TELEPORT_TELL := 0.4
const BOSS2_TELEPORT_EVERY := Vector2(3.5, 5.0)
const BOSS2_TELEPORT_MIN_DIST := 260.0
## Weighted attack menu per phase.
const BOSS2_ATTACKS := [
	{"summon": 1},
	{"summon": 60, "ray": 40},
	{"summon": 45, "ray": 35, "update": 20},
	{"summon": 45, "ray": 35, "update": 20},
]
## MSM Cam: he LECTURES to the camera (stops, cancels a wind-up) up to
## BOSS2_LECTURE_MAX, lingers BOSS_POSE_LINGER, then camera-shy BOSS_POSE_COOLDOWN.
const BOSS2_LECTURE_MAX := 1.4
## Scoring (same structure as Trustin, bigger numbers).
const BOSS2_POINTS_PER_HEART := 100
const BOSS2_DEFEAT_BONUS := 4000
const BOSS2_HEALTH_BONUS := 300
const BOSS2_TIME_PAR := 120.0
const POINTS_ROBO := 50                 ## per programmed sheep split
const POINTS_MICRO := 25                ## per micro sheep popped


static func boss2_phase(hearts: int) -> int:
	if hearts <= BOSS2_RAGE_HEARTS:
		return 4
	if hearts <= BOSS2_PHASE3_HEARTS:
		return 3
	if hearts <= BOSS2_PHASE2_HEARTS:
		return 2
	return 1


# ---------------------------------------------------------------- build 018 boss 3
## BEORGE KUSH JR., THE AIRSTRIKE ACE (scripts/boss/kush.gd, kush_level.gd,
## airstrike.gd, scenes/levels/Boss3Arena.tscn). An ex fighter pilot who
## radios in his air force. Same hit rules as the other bosses (whip / shot /
## lash-only shockwave = 1 heart, fire = 1 delayed heart per 6 s, grab and
## swing shove + stagger, contact = 1 heart). Harder than Huval.
const BOSS3_NAME := "BEORGE KUSH JR."
const BOSS3_TITLE := "THE AIRSTRIKE ACE"
const BOSS3_HEARTS := 15
## Phases by hearts left: 15-11 / 10-7 / 6-4 / rage 3-1.
const BOSS3_PHASE2_HEARTS := 10
const BOSS3_PHASE3_HEARTS := 6
const BOSS3_RAGE_HEARTS := 3
## At these hearts he unfurls the MISSION ACCOMPLISHED banner: invulnerable
## for BOSS3_BANNER_TIME, then an airstrike is called straight away.
const BOSS3_BANNER_HEARTS := [9, 4]
const BOSS3_BANNER_TIME := 1.5
## Movement (swaggering, keeps out of whip reach like the others).
const BOSS3_SPEED := 120.0
const BOSS3_SPEED_RAGE := 150.0
const BOSS3_PREF_DIST := 300.0
const BOSS3_RETREAT_DIST := 170.0
const BOSS3_RETREAT_MULT := 1.5
## Attack rhythm (pause after each call, per phase 1..4).
const BOSS3_ATTACK_GAP := [1.25, 1.05, 0.9, 0.75]
## Every attack starts with a RADIO CALL: he holds the radio to his ear ("!",
## crackle) for this long. Filming him or a swing/grab during the call cancels
## it before anything is marked.
const BOSS3_RADIO_TELL := [0.6, 0.55, 0.5, 0.45]
## AIRSTRIKE: red target marks drop on the ground (the first on you, the rest
## around you), a jet streaks over, and each mark blasts after BOSS3_MARK_TIME.
const BOSS3_STRIKE_MARKS := [3, 4, 5, 6]
const BOSS3_MARK_TIME := [1.1, 1.0, 0.92, 0.85]
const BOSS3_BLAST_RADIUS := 55.0
const BOSS3_MARK_SPREAD := Vector2(60.0, 180.0)  ## other marks: this far from you
const BOSS3_MARK_MIN_SEP := 75.0
const BOSS3_MARK_LEAD := 0.45           ## 2nd mark leads your velocity by this many seconds
## STRAFING RUN (phase 2+): a lane through you flashes DANGER for
## BOSS3_STRAFE_TELL, then a jet fires down it. Rage: two crossing lanes.
const BOSS3_STRAFE_TELL := [0.85, 0.8, 0.75, 0.7]
const BOSS3_STRAFE_HALF_WIDTH := 34.0
const BOSS3_STRAFE_SPEED := 1500.0      ## jet speed along the lane (px/s)
const BOSS3_STRAFE_GUN_REACH := 55.0    ## the bullets hit this close to the jet's gun point
## CARPET BOMBING (phase 3+): a line of marks marching through you, each
## blasting BOSS3_CARPET_TIME after it appears; step sideways out of the line.
const BOSS3_CARPET_COUNT := 7
const BOSS3_CARPET_SPACING := 62.0
const BOSS3_CARPET_STAGGER := 0.11
const BOSS3_CARPET_TIME := 1.1
const BOSS3_CARPET_RADIUS := 44.0
## Weighted attack menu per phase.
const BOSS3_ATTACKS := [
	{"strike": 1},
	{"strike": 55, "strafe": 45},
	{"strike": 40, "strafe": 30, "carpet": 30},
	{"strike": 40, "strafe": 30, "carpet": 30},
]
## Rage combos: chance that an airstrike is chained into a strafing run.
const BOSS3_COMBO_CHANCE := [0.0, 0.15, 0.3, 0.5]
## FRIENDLY FIRE: Beorge caught in one of his own blasts loses a heart
## (normal i-frames apply). Lure him onto the marks!
const BOSS3_FRIENDLY_FIRE := true
## MSM Cam: he SALUTES for the camera (stops, cancels a radio call) up to
## BOSS3_SALUTE_MAX, lingers BOSS_POSE_LINGER, then camera-shy BOSS_POSE_COOLDOWN.
## Marks already on the ground still blast (the jets are already inbound).
const BOSS3_SALUTE_MAX := 1.0
## Scoring.
const BOSS3_POINTS_PER_HEART := 100
const BOSS3_DEFEAT_BONUS := 5000
const BOSS3_HEALTH_BONUS := 300
const BOSS3_TIME_PAR := 150.0
const POINTS_FRIENDLY_FIRE := 150       ## extra, per heart he loses to his own blasts


static func boss3_phase(hearts: int) -> int:
	if hearts <= BOSS3_RAGE_HEARTS:
		return 4
	if hearts <= BOSS3_PHASE3_HEARTS:
		return 3
	if hearts <= BOSS3_PHASE2_HEARTS:
		return 2
	return 1


# ---------------------------------------------------------------- build 018 boss 4
## SHLAUS KWOBB, CHAIRMAN OF THE GREAT RESET (scripts/boss/shlaus.gd,
## shlaus_level.gd, delegate.gd, scenes/levels/Boss4Arena.tscn). The puppet
## master of the summit: he summons hologram DELEGATES of Trustin Judeau
## (poutine) and Huval Yarheyhey (programmed sheep) and adds his own
## attacks. Same hit rules as the other bosses. The hardest boss so far.
const BOSS4_NAME := "SHLAUS KWOBB"
const BOSS4_TITLE := "CHAIRMAN OF THE GREAT RESET"
const BOSS4_HEARTS := 18
## Phases by hearts left: 18-14 / 13-9 / 8-5 / rage 4-1.
const BOSS4_PHASE2_HEARTS := 13
const BOSS4_PHASE3_HEARTS := 8
const BOSS4_RAGE_HEARTS := 4
## At these hearts he calls a PANEL DISCUSSION (invulnerable, gavel ring)
## for BOSS4_PANEL_TIME and ends it with a free GREAT RESET wave.
const BOSS4_PANEL_HEARTS := [13, 8, 4]
const BOSS4_PANEL_TIME := 1.5
## Movement.
const BOSS4_SPEED := 100.0
const BOSS4_SPEED_RAGE := 130.0
const BOSS4_PREF_DIST := 320.0
const BOSS4_RETREAT_DIST := 180.0
const BOSS4_RETREAT_MULT := 1.5
## Rage: PRIVATE JET hops (same telegraph as Huval's teleport: rings at the
## destination for BOSS4_HOP_TELL).
const BOSS4_HOP_TELL := 0.45
const BOSS4_HOP_EVERY := Vector2(3.5, 5.0)
const BOSS4_HOP_MIN_DIST := 260.0
## Attack rhythm. Every attack starts with a short CONDUCTING tell (arms up).
const BOSS4_ATTACK_GAP := [1.6, 1.4, 1.2, 1.0]
const BOSS4_CONDUCT_TELL := [0.45, 0.4, 0.38, 0.32]
## DELEGATES: translucent holograms that appear BOSS4_DELEGATE_DIST from you,
## fade in for BOSS4_DELEGATE_TELL (aim line / spawn rings), act, then fade.
## They can't be hurt, but the MSM Cam DISPELS any delegate it films.
const BOSS4_DELEGATE_TELL := [0.85, 0.8, 0.72, 0.62]
const BOSS4_DELEGATE_DIST := Vector2(250.0, 340.0)
const BOSS4_DELEGATE_LINGER := 0.45
## Trustin delegate poutine per phase: "single", "spread3", "spread5"/"lob2", "volley".
const BOSS4_POUTINE_MODE := ["single", "spread3", "spread5", "volley"]
const BOSS4_VOLLEY_COUNT := 3
## Huval delegate programmed sheep per summon and the cap alive at once.
const BOSS4_SHEEP_COUNT := [1, 1, 2, 2]
const BOSS4_SHEEP_CAP := [3, 3, 4, 5]
## INVITATIONS (signature): a fan of envelopes, telegraphed by fan lines.
const BOSS4_ENVELOPES := [3, 4, 5, 6]
const BOSS4_ENVELOPE_FAN_DEG := 20.0    ## between envelopes (~70 px lanes at 200 px)
const BOSS4_ENVELOPE_SPEED := 280.0
const BOSS4_ENVELOPE_TELL := [0.7, 0.65, 0.6, 0.55]
const BOSS4_ENVELOPE_HIT_RADIUS := 17.0
## THE GREAT RESET (phase 2+, signature): an expanding ring from him with two
## gaps. The rings and the gaps show for BOSS4_RESET_TELL first; one gap is
## always within BOSS4_RESET_GAP_NEAR_DEG of your direction.
const BOSS4_RESET_TELL := [1.0, 0.95, 0.85, 0.75]
const BOSS4_RESET_SPEED := 280.0
const BOSS4_RESET_MAX_RADIUS := 760.0
const BOSS4_RESET_THICK := 16.0
const BOSS4_RESET_GAPS := 2
const BOSS4_RESET_GAP_DEG := 48.0
const BOSS4_RESET_GAP_NEAR_DEG := 50.0
## Weighted attack menu per phase. "double" = both delegates at once.
const BOSS4_ATTACKS := [
	{"poutine": 40, "sheep": 30, "envelopes": 30},
	{"poutine": 28, "sheep": 22, "envelopes": 20, "reset": 30},
	{"poutine": 20, "sheep": 18, "envelopes": 17, "reset": 25, "double": 20},
	{"poutine": 18, "sheep": 15, "envelopes": 17, "reset": 25, "double": 25},
]
## Rage combos: chance that an attack is chained straight into an envelope fan.
const BOSS4_COMBO_CHANCE := [0.0, 0.0, 0.2, 0.4]
## MSM Cam: "NO PRESS!" he shields his face (stops, cancels his tell and every
## delegate still fading in) up to BOSS4_PRESS_MAX, then camera-shy.
const BOSS4_PRESS_MAX := 1.0
## Scoring.
const BOSS4_POINTS_PER_HEART := 100
const BOSS4_DEFEAT_BONUS := 7500
const BOSS4_HEALTH_BONUS := 300
const BOSS4_TIME_PAR := 180.0
const POINTS_DISPEL := 100              ## per delegate dispelled with the cam


static func boss4_phase(hearts: int) -> int:
	if hearts <= BOSS4_RAGE_HEARTS:
		return 4
	if hearts <= BOSS4_PHASE3_HEARTS:
		return 3
	if hearts <= BOSS4_PHASE2_HEARTS:
		return 2
	return 1


# ---------------------------------------------------------------- build 020 bosses 5 + 6
## Gill Bates and Nancy Pelotto reuse Shlaus Kwobb's fight engine
## (shlaus.gd: delegates, programmed sheep, projectile fans, gap rings, hops,
## panel shields, cam "no press") with their own skins and numbers. Any key
## missing from BOSS5_* / BOSS6_* falls back to BOSS4_* (boss_cfg()).
## Each one is tuned to be harder than the boss before it on the bot ladder.

const BOSS5_NAME := "GILL BATES"
const BOSS5_TITLE := "PATRON OF THE SERVER FARM"
const BOSS5_HEARTS := 20
const BOSS5_PHASE2_HEARTS := 15
const BOSS5_PHASE3_HEARTS := 10
const BOSS5_RAGE_HEARTS := 5
const BOSS5_PANEL_HEARTS := [15, 10, 5]   ## "SYSTEM UPDATE" shield (panel)
const BOSS5_SPEED := 108.0
const BOSS5_SPEED_RAGE := 140.0
const BOSS5_ATTACK_GAP := [1.5, 1.3, 1.1, 0.95]
const BOSS5_CONDUCT_TELL := [0.42, 0.38, 0.35, 0.3]
const BOSS5_DELEGATE_TELL := [0.8, 0.75, 0.68, 0.58]
const BOSS5_SHEEP_COUNT := [1, 2, 2, 2]
const BOSS5_SHEEP_CAP := [3, 4, 4, 5]
const BOSS5_ENVELOPES := [4, 5, 6, 7]       ## FLOPPY PATCH fan
const BOSS5_ENVELOPE_SPEED := 300.0
const BOSS5_ENVELOPE_TELL := [0.65, 0.6, 0.55, 0.5]
const BOSS5_RESET_TELL := [0.95, 0.9, 0.8, 0.72]   ## BLUE SCREEN ring
const BOSS5_RESET_SPEED := 300.0
const BOSS5_ATTACKS := [
	{"sheep": 40, "envelopes": 35, "poutine": 25},
	{"sheep": 28, "envelopes": 24, "poutine": 18, "reset": 30},
	{"sheep": 22, "envelopes": 20, "poutine": 13, "reset": 25, "double": 20},
	{"sheep": 18, "envelopes": 20, "poutine": 12, "reset": 25, "double": 25},
]
const BOSS5_COMBO_CHANCE := [0.0, 0.15, 0.3, 0.45]
const BOSS5_POINTS_PER_HEART := 120
const BOSS5_DEFEAT_BONUS := 9000
const BOSS5_HEALTH_BONUS := 350
const BOSS5_TIME_PAR := 200.0

const BOSS6_NAME := "NANCY PELOTTO"
const BOSS6_TITLE := "SPEAKER OF THE HOUSE"
const BOSS6_HEARTS := 22
const BOSS6_PHASE2_HEARTS := 17
const BOSS6_PHASE3_HEARTS := 11
const BOSS6_RAGE_HEARTS := 5
const BOSS6_PANEL_HEARTS := [17, 11, 5]   ## "IN RECESS" shield (panel)
const BOSS6_SPEED := 112.0
const BOSS6_SPEED_RAGE := 150.0
const BOSS6_ATTACK_GAP := [1.4, 1.2, 1.0, 0.9]
const BOSS6_CONDUCT_TELL := [0.4, 0.36, 0.33, 0.28]
const BOSS6_DELEGATE_TELL := [0.78, 0.72, 0.65, 0.55]
const BOSS6_SHEEP_COUNT := [1, 2, 2, 3]
const BOSS6_SHEEP_CAP := [3, 4, 5, 5]
const BOSS6_ENVELOPES := [4, 5, 6, 7]       ## ICE CREAM fan
const BOSS6_ENVELOPE_SPEED := 315.0
const BOSS6_ENVELOPE_TELL := [0.62, 0.58, 0.52, 0.48]
const BOSS6_RESET_TELL := [0.9, 0.85, 0.75, 0.68]  ## ORDER! gavel ring
const BOSS6_RESET_SPEED := 310.0
const BOSS6_ATTACKS := [
	{"poutine": 30, "envelopes": 35, "reset": 35},
	{"poutine": 22, "sheep": 18, "envelopes": 25, "reset": 35},
	{"poutine": 18, "sheep": 15, "envelopes": 20, "reset": 27, "double": 20},
	{"poutine": 15, "sheep": 13, "envelopes": 20, "reset": 27, "double": 25},
]
const BOSS6_COMBO_CHANCE := [0.1, 0.2, 0.35, 0.5]
const BOSS6_POINTS_PER_HEART := 140
const BOSS6_DEFEAT_BONUS := 10500
const BOSS6_HEALTH_BONUS := 400
const BOSS6_TIME_PAR := 220.0


# ------------------------------------------------------------------ Build 025 bosses
## Boss 7: REANALD ROGAN, THE GIPPER OF THE GALAXY (cartoon parody). Shlaus
## engine + "Star Wars" missile-defence tech (scripts/boss/starwars.gd):
##   orbital  - ORBITAL LASER: telegraphed target circles, then a beam from orbit
##   satbeam  - SATELLITE BEAM: a sweeping line beam with a telegraph
##   ufo      - UFOs that drift over the arena dropping tractor beams
const BOSS7_NAME := "REANALD ROGAN"
const BOSS7_TITLE := "THE GIPPER OF THE GALAXY"
const BOSS7_HEARTS := 24
const BOSS7_PHASE2_HEARTS := 18
const BOSS7_PHASE3_HEARTS := 12
const BOSS7_RAGE_HEARTS := 6
const BOSS7_PANEL_HEARTS := [18, 12, 6]   ## "STAR WARS SHIELD"
const BOSS7_SPEED := 114.0
const BOSS7_SPEED_RAGE := 152.0
const BOSS7_ATTACK_GAP := [1.35, 1.15, 0.98, 0.86]
const BOSS7_CONDUCT_TELL := [0.42, 0.38, 0.34, 0.3]
const BOSS7_DELEGATE_TELL := [0.78, 0.72, 0.65, 0.55]
const BOSS7_SHEEP_COUNT := [1, 2, 2, 3]
const BOSS7_SHEEP_CAP := [3, 4, 4, 5]
const BOSS7_ENVELOPES := [5, 6, 7, 7]       ## jelly-bean fan
const BOSS7_ENVELOPE_SPEED := 315.0
const BOSS7_ENVELOPE_TELL := [0.58, 0.54, 0.49, 0.45]
const BOSS7_RESET_TELL := [0.9, 0.85, 0.75, 0.68]
const BOSS7_RESET_SPEED := 310.0
const BOSS7_ATTACKS := [
	{"envelopes": 30, "orbital": 40, "satbeam": 30},
	{"envelopes": 20, "sheep": 15, "orbital": 26, "satbeam": 22, "ufo": 17},
	{"poutine": 10, "sheep": 13, "envelopes": 15, "orbital": 22, "satbeam": 18, "ufo": 12, "double": 15},
	{"poutine": 8, "sheep": 12, "envelopes": 13, "orbital": 22, "satbeam": 18, "ufo": 12, "double": 20},
]
const BOSS7_COMBO_CHANCE := [0.1, 0.2, 0.3, 0.45]
const BOSS7_POINTS_PER_HEART := 150
const BOSS7_DEFEAT_BONUS := 12000
const BOSS7_HEALTH_BONUS := 420
const BOSS7_TIME_PAR := 240.0
## ORBITAL LASER: targets around the rancher (one always on you).
const BOSS7_ORBITAL_COUNT := [4, 5, 6, 7]
const BOSS7_ORBITAL_TELL := [1.0, 0.92, 0.84, 0.76]
const BOSS7_ORBITAL_RADIUS := 50.0
## SATELLITE BEAM: telegraph line through the rancher, then it sweeps.
const BOSS7_BEAM_TELL := [1.0, 0.9, 0.8, 0.72]
const BOSS7_BEAM_SWEEP_DEG := [50.0, 60.0, 70.0, 80.0]
const BOSS7_BEAM_TIME := 1.2
const BOSS7_BEAM_WIDTH := 26.0
## UFOs: drift across, drop a tractor beam on you every few seconds; whip one twice to pop it.
const BOSS7_UFO_COUNT := [1, 1, 2, 2]
const BOSS7_UFO_CAP := 3
const BOSS7_UFO_LIFE := 11.0
const BOSS7_UFO_BEAM_EVERY := 2.8
const BOSS7_UFO_BEAM_TELL := 0.85
const BOSS7_UFO_BEAM_RADIUS := 34.0
const BOSS7_UFO_POINTS := 300

## Boss 8: ZELODYMER VIOLENTSKY, THE COMEDIAN COMMANDER (cartoon parody). Shlaus
## engine + explosive drone swarms (scripts/boss/drones.gd):
##   drones - a swarm launches, hovers (telegraphed target), then dives and pops
##   swarm  - a bigger ring of drones from all sides (phase 3+)
const BOSS8_NAME := "ZELODYMER VIOLENTSKY"
const BOSS8_TITLE := "THE COMEDIAN COMMANDER"
const BOSS8_HEARTS := 26
const BOSS8_PHASE2_HEARTS := 20
const BOSS8_PHASE3_HEARTS := 13
const BOSS8_RAGE_HEARTS := 6
const BOSS8_PANEL_HEARTS := [20, 13, 6]   ## "ON A CALL" shield
const BOSS8_SPEED := 118.0
const BOSS8_SPEED_RAGE := 156.0
const BOSS8_ATTACK_GAP := [1.4, 1.2, 1.0, 0.9]
const BOSS8_CONDUCT_TELL := [0.4, 0.36, 0.33, 0.28]
const BOSS8_DELEGATE_TELL := [0.78, 0.72, 0.65, 0.55]
const BOSS8_SHEEP_COUNT := [1, 2, 2, 3]
const BOSS8_SHEEP_CAP := [3, 4, 5, 5]
const BOSS8_ENVELOPES := [4, 5, 6, 7]       ## sunflower-seed fan
const BOSS8_ENVELOPE_SPEED := 320.0
const BOSS8_ENVELOPE_TELL := [0.6, 0.56, 0.5, 0.46]
const BOSS8_RESET_TELL := [0.9, 0.85, 0.75, 0.68]
const BOSS8_RESET_SPEED := 315.0
const BOSS8_ATTACKS := [
	{"envelopes": 30, "drones": 45, "reset": 25},
	{"envelopes": 22, "drones": 40, "reset": 23, "poutine": 15},
	{"envelopes": 18, "drones": 32, "swarm": 20, "reset": 18, "poutine": 12},
	{"envelopes": 15, "drones": 30, "swarm": 27, "reset": 18, "poutine": 10},
]
const BOSS8_COMBO_CHANCE := [0.1, 0.2, 0.32, 0.45]
const BOSS8_POINTS_PER_HEART := 160
const BOSS8_DEFEAT_BONUS := 13500
const BOSS8_HEALTH_BONUS := 450
const BOSS8_TIME_PAR := 250.0
## Drones: launch, hover over a telegraphed target, dive, explode in a radius.
const BOSS8_DRONES := [3, 4, 5, 6]
const BOSS8_SWARM := [0, 0, 7, 9]
const BOSS8_DRONE_CAP := 12
const BOSS8_DRONE_HOVER := [1.1, 1.0, 0.9, 0.8]   ## telegraph time over the target
const BOSS8_DRONE_SPEED := 260.0
const BOSS8_DRONE_BLAST := 44.0
const BOSS8_DRONE_POINTS := 100                   ## whip a drone out of the air

# ------------------------------------------------------------------ Build 027 bosses
## Boss 9: VLADIMIR PUDDIN, THE BAREBACK STRONGMAN (cartoon parody): a
## shirtless judo master on a horse in a frozen taiga arena. Shlaus engine +
## scripts/boss/finale.gd:
##   tank   - TANK CHARGE: telegraphed lanes (one through you), then toy tanks roll through
##   judo   - JUDO THROW: a grab ring locks on you, he pounces; caught = tossed + 1 heart
##   quake  - ARENA SHAKE: a 1 s warning, then CONTROLS INVERTED for 3 s (+ icicles)
const BOSS9_NAME := "VLADIMIR PUDDIN"
const BOSS9_TITLE := "THE BAREBACK STRONGMAN"
const BOSS9_HEARTS := 30
const BOSS9_PHASE2_HEARTS := 23
const BOSS9_PHASE3_HEARTS := 15
const BOSS9_RAGE_HEARTS := 7
const BOSS9_PANEL_HEARTS := [23, 15, 7]   ## "PHOTO OP" shield
const BOSS9_SPEED := 130.0
const BOSS9_SPEED_RAGE := 162.0
const BOSS9_ATTACK_GAP := [1.15, 0.98, 0.86, 0.75]   ## 027 tuning: was [1.3, 1.1, 0.95, 0.84]
const BOSS9_CONDUCT_TELL := [0.4, 0.36, 0.32, 0.28]
const BOSS9_DELEGATE_TELL := [0.76, 0.7, 0.62, 0.54]
const BOSS9_SHEEP_COUNT := [1, 2, 2, 3]
const BOSS9_SHEEP_CAP := [3, 4, 5, 5]
const BOSS9_ENVELOPES := [5, 6, 7, 8]       ## snowball fan
const BOSS9_ENVELOPE_SPEED := 345.0
const BOSS9_ENVELOPE_TELL := [0.56, 0.52, 0.48, 0.44]
const BOSS9_RESET_TELL := [0.88, 0.82, 0.74, 0.66]
const BOSS9_RESET_SPEED := 320.0
const BOSS9_ATTACKS := [
	{"envelopes": 25, "tank": 35, "judo": 30, "reset": 10},
	{"envelopes": 18, "tank": 28, "judo": 24, "quake": 16, "sheep": 14},
	{"envelopes": 14, "tank": 24, "judo": 22, "quake": 16, "sheep": 10, "reset": 14},
	{"envelopes": 12, "tank": 24, "judo": 22, "quake": 18, "sheep": 8, "reset": 16},
]
const BOSS9_COMBO_CHANCE := [0.18, 0.28, 0.4, 0.52]
const BOSS9_POINTS_PER_HEART := 170
const BOSS9_DEFEAT_BONUS := 15000
const BOSS9_HEALTH_BONUS := 480
const BOSS9_TIME_PAR := 270.0
## TANK CHARGE: lanes across the arena (one through you), tank rolls after the tell.
const BOSS9_TANKS := [2, 2, 3, 3]
const BOSS9_TANK_TELL := [1.0, 0.92, 0.84, 0.76]
const BOSS9_TANK_SPEED := 560.0
const BOSS9_TANK_WIDTH := 46.0
## JUDO THROW: the grab ring tracks you for TRACK s, locks, then he pounces at LOCK.
const BOSS9_JUDO_TRACK := [0.5, 0.45, 0.4, 0.35]
const BOSS9_JUDO_LOCK := [0.5, 0.45, 0.4, 0.36]
const BOSS9_JUDO_RADIUS := 60.0
const BOSS9_JUDO_TOSS := 240.0
## ARENA SHAKE: warning, then inverted controls for INVERT_TIME + falling icicles.
const BOSS9_QUAKE_TELL := 1.0
const BOSS9_INVERT_TIME := 3.0
const BOSS9_ICICLES := [2, 3, 5, 6]
const BOSS9_ICICLE_TELL := 1.1
const BOSS9_ICICLE_RADIUS := 34.0

## Boss 10: DONALD RUMP, THE FINAL BOSS (cartoon parody of a tycoon golfer).
## Golf course + gold tower. Shlaus engine + scripts/boss/finale.gd:
##   drive  - GOLF BALL DRIVES: "FORE!" landing marks, then balls drop on them
##   walls  - WALL DROP: a shadow, then a gold wall slams down and partitions
##            the arena for a while (blocks you, him and his shots)
##   crowd  - RED-HAT CROWD: plain red caps chase you; whip them home
##   rage   - at RAGE_HEARTS: "YOU'RE FIRED!" - everything faster + a pink-slip ring
const BOSS10_NAME := "DONALD RUMP"
const BOSS10_TITLE := "THE FINAL BOSS"
const BOSS10_HEARTS := 34
const BOSS10_PHASE2_HEARTS := 26
const BOSS10_PHASE3_HEARTS := 17
const BOSS10_RAGE_HEARTS := 8
const BOSS10_PANEL_HEARTS := [26, 17, 8]   ## "TEE TIME" shield
const BOSS10_SPEED := 120.0
const BOSS10_SPEED_RAGE := 168.0
const BOSS10_ATTACK_GAP := [1.25, 1.05, 0.92, 0.78]
const BOSS10_CONDUCT_TELL := [0.4, 0.36, 0.32, 0.27]
const BOSS10_DELEGATE_TELL := [0.74, 0.68, 0.6, 0.52]
const BOSS10_SHEEP_COUNT := [1, 2, 2, 3]
const BOSS10_SHEEP_CAP := [3, 4, 5, 5]
const BOSS10_ENVELOPES := [5, 6, 7, 9]       ## golf-ball fan
const BOSS10_ENVELOPE_SPEED := 335.0
const BOSS10_ENVELOPE_TELL := [0.55, 0.5, 0.46, 0.42]
const BOSS10_RESET_TELL := [0.86, 0.8, 0.72, 0.64]
const BOSS10_RESET_SPEED := 330.0
const BOSS10_ATTACKS := [
	{"envelopes": 25, "drive": 40, "walls": 20, "crowd": 15},
	{"envelopes": 18, "drive": 30, "walls": 20, "crowd": 18, "reset": 14},
	{"envelopes": 14, "drive": 26, "walls": 18, "crowd": 18, "reset": 12, "sheep": 12},
	{"envelopes": 12, "drive": 26, "walls": 16, "crowd": 18, "fired": 18, "sheep": 10},
]
const BOSS10_COMBO_CHANCE := [0.14, 0.24, 0.36, 0.52]
const BOSS10_POINTS_PER_HEART := 200
const BOSS10_DEFEAT_BONUS := 25000
const BOSS10_HEALTH_BONUS := 600
const BOSS10_TIME_PAR := 300.0
## GOLF BALL DRIVES: landing marks around you (one on you).
const BOSS10_DRIVES := [3, 4, 5, 6]
const BOSS10_DRIVE_TELL := [1.05, 0.96, 0.88, 0.8]
const BOSS10_DRIVE_RADIUS := 36.0
## WALL DROP: gold wall segments that block for WALL_LIFE seconds.
const BOSS10_WALLS := [1, 1, 2, 2]
const BOSS10_WALL_CAP := 3
const BOSS10_WALL_TELL := [0.9, 0.85, 0.78, 0.7]
const BOSS10_WALL_LIFE := 7.0
const BOSS10_WALL_LEN := 220.0
const BOSS10_WALL_THICK := 26.0
## RED-HAT CROWD: chasers (1 heart on touch, popped by one whip).
const BOSS10_CROWD := [3, 4, 5, 6]
const BOSS10_CROWD_CAP := 8
const BOSS10_CROWD_SPEED := [92.0, 100.0, 110.0, 122.0]
const BOSS10_CROWD_LIFE := 11.0
const BOSS10_CROWD_POINTS := 120
## YOU'RE FIRED! rage: the pink-slip ring has three gaps; shown once on entry too.
const BOSS10_FIRED_GAPS := 3

# ------------------------------------------------------------------ Build 025 body armour
## ARMOUR power-up: drops only from level ARMOR_FROM_LEVEL (after Shlaus Kwobb).
## It absorbs ARMOR_HITS hits before any heart is lost (one plate per hit,
## ARMOR_IFRAMES of grace after each absorbed hit). Picking one up again tops
## the plates back up. It carries over between levels like the inventory.
const ARMOR_FROM_LEVEL := 12
const ARMOR_HITS := 3
const ARMOR_IFRAMES := 0.6
const ARMOR_WEIGHT := 7

## Shlaus-engine tuning table for boss `n` (4-10): every BOSS4_* constant
## (prefix stripped), overlaid with the BOSSn_* ones.
static func boss_cfg(n: int) -> Dictionary:
	var consts: Dictionary = (load("res://scripts/level_config.gd") as Script).get_script_constant_map()
	var out := {}
	for pre in ["BOSS4_", "BOSS%d_" % n]:
		for k in consts:
			var ks := String(k)
			if ks.begins_with(pre):
				out[ks.substr(pre.length())] = consts[k]
	return out


# ------------------------------------------------------------------ Build 021
## Regular-level biomes: the levels BEFORE each boss look like the natural
## environment of that boss's home region (terrain, plants, palette, water
## only; no landmarks). Bonus stages and boss arenas are unchanged.
##   L1-2 prairie (Canadian ranch, before Trustin)   L3-5 med (Israel, before Huval)
##   L6-8 texas (before Kush)                        L9-11 bavaria (before Shlaus)
##   L12-14 pnw (Seattle, before Gill)               L15-17 norcal (before Nancy)
##   L18-20 midwest (Illinois corn and farmland, before Rogan)   (build 025)
##   L21-23 ukraine (wheat fields and birch groves, before Violentsky)
##   L24-26 taiga (snowy Russian birch and spruce, before Puddin)   (build 027)
##   L27-29 florida (palms and golf greens, before Rump)
##   L30+ cycles all ten, one level each, in that order (build 027: was L24+, eight).
const THEME_ORDER: Array[String] = ["prairie", "med", "texas", "bavaria", "pnw", "norcal", "midwest", "ukraine", "taiga", "florida"]
const THEME_NAMES := {
	"prairie": "PRAIRIE RANCH", "med": "OLIVE HILLS", "texas": "LONE STAR SCRUB",
	"bavaria": "ALPINE FOREST", "pnw": "RAINFOREST", "norcal": "GOLDEN COAST",
	"midwest": "CORN BELT", "ukraine": "WHEAT STEPPE",
	"taiga": "FROZEN TAIGA", "florida": "PALM LINKS",
}
const THEME_CYCLE_FROM := 30


static func theme_for(level: int) -> String:
	if level <= BOSS_AFTER_LEVEL:
		return "prairie"
	if level >= THEME_CYCLE_FROM:
		return THEME_ORDER[(level - THEME_CYCLE_FROM) % THEME_ORDER.size()]
	if level <= BOSS2_AFTER_LEVEL:
		return "med"
	if level <= BOSS3_AFTER_LEVEL:
		return "texas"
	if level <= BOSS4_AFTER_LEVEL:
		return "bavaria"
	if level <= BOSS5_AFTER_LEVEL:
		return "pnw"
	if level <= BOSS6_AFTER_LEVEL:
		return "norcal"
	if level <= BOSS7_AFTER_LEVEL:
		return "midwest"
	if level <= BOSS8_AFTER_LEVEL:
		return "ukraine"
	if level <= BOSS9_AFTER_LEVEL:
		return "taiga"
	return "florida"


# ------------------------------------------------------------------ Build 022
## Bonus stages: whip cooldown x0.5 and one crack pops every sheep it overlaps.
const BONUS_WHIP_COOLDOWN_MULT := 0.5
const BONUS_MULTI_TIP_RADIUS := 44.0


# ------------------------------------------------------------------ Build 023 Cantifa
const CANTIFA_RAMP_FROM := 8          ## caps / spawn ratio ramp above this level
const CANTIFA_CAP_LATE := 10
const CANTIFA_SPAWN_EVERY_MIN := 3
const CANTIFA_LOS_MASK := 1           ## environment layer: trees, rocks, walls block the shot
const CANTIFA_SLOT_R := 36.0          ## formation ring spacing at the shared rally post
const CANTIFA_REGROUP_EVERY := 20.0   ## the whole group moves to another post together


# ------------------------------------------------------------------ Build 024 hidden chambers
const SECRET_SCORE := 750
