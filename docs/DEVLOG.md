# Save The Silly Humans — Development Log

The full build-by-build history of the game, from the first prototype to the current live build. Every build's original source zip is attached to its [GitHub release](https://github.com/Tebrion74/save-the-silly-humans/releases) (tags `build-000-prototype`, `build-001` … `build-017`, including hotfixes 009b–009d).

**Playable Web exports** (`web-beta-<build>.zip`) are attached to the releases for **007, 008, 009d and 010 through 017**. To self-host one, unzip it and serve `index.html` from any web server. No Web exports exist for the prototypes, builds 001–006, or 009, 009b and 009c; those releases have source only.

Times are Mountain Time (Calgary). Build times come from when each source zip was uploaded; live times are from the deploy notes.

## Timeline

| Build | Date (MT) | Status | Headline |
|---|---|---|---|
| [000-prototype](#build-000prototype) | 2026-09-16 19:28 → 2026-09-17 00:21 MT | Pre-release | Prototypes 1–3 |
| [001](#build-001) | 2026-09-17 ~21:55 MT | Pre-release | tile-anchored spawns |
| [002](#build-002) | 2026-09-17 ~22:12 MT | Pre-release | false-win fix, humans avoid the safe zone |
| [003](#build-003) | 2026-09-17 ~22:19 MT | Pre-release | rescues locked until spawns settle |
| [004](#build-004) | 2026-09-17 ~22:43 MT | Pre-release | human HP, possession, win/lose accounting, infection alarm |
| [005](#build-005) | 2026-09-17 ~23:05 MT | Pre-release | RMB grab & throw |
| [006](#build-006) | 2026-09-19 ~03:20 MT | Pre-release | layout: safe zone bottom-right, sheep den |
| [007](#build-007) | 2026-10-04 ~18:11 MT | Web beta | whip animation and 32-bit art |
| [008](#build-008) | 2026-10-04 ~22:22 MT | Web beta | painted terrain (grassland, woods, paths, ponds) |
| [009](#build-009) | 2026-10-04 ~22:53 MT | Live | mobile touch controls (PC controls unchanged) |
| [009b](#build-009b) | 2026-10-04 ~23:48 MT | Live hotfix | PLAY AGAIN button (hotfix) |
| [009c](#build-009c) | 2026-10-04 ~23:57 MT | Live hotfix | touch joystick freeze fix (hotfix) |
| [009d](#build-009d) | 2026-10-05 ~00:12 MT | Live hotfix | touch whip aims along facing (hotfix) |
| [010](#build-010) | 2026-10-05 ~20:41 MT | Live | rounds & levels, human camp, diagonal touch whip, directional throw |
| [011](#build-011) | 2026-10-05 ~21:22 MT | Live | title screen, mobile aim assist, fixed joystick, square buttons, spawn tuning |
| [012](#build-012) | 2026-10-05 ~22:08 MT | Live | immediate win, scoring, Genesis-style HUD, How to Play |
| [013](#build-013) | 2026-10-06 ~00:16 MT | Live | Karens, camp hold, power-ups |
| [014](#build-014) | 2026-10-07 ~04:17 MT | Not deployed (superseded by 014b) | MSM Cam, inventory (no power-up timers), corner-wedge touch controls |
| [014b](#build-014b) | 2026-10-07 ~04:41 MT | Live | aim reticle (PC) and reach crosshair (touch) |
| [015](#build-015) | 2026-10-07 ~22:22 MT | Live | boss battle: Trustin Judeau (between level 2 and level 3) |
| [015b](#build-015b) | 2026-10-08 ~09:47 MT | Live | boss only after level 2, harder boss, sound and music everywhere |
| [016](#build-016) | 2026-10-08 ~13:05 MT | Live | Galaga-style bonus stage, boss 2 Huval Yarheyhey |
| [017](#build-017) | 2026-10-08 ~16:34 MT | Live | Cantifa: posted gunmen, from level 4 |

## Prototypes (before build 001)
<a id="build-000prototype"></a>

**Date:** 2026-09-16 19:28 → 2026-09-17 00:21 MT  
**Status:** Pre-release. Editor prototype, not published.

Three unnumbered `Save-the-Silly-Humans-Godot.zip` snapshots came before build 001. They're attached to the `build-000-prototype` release as `-proto-1`, `-proto-2` and `-proto-3`.

### Prototype 1 (2026-09-16 ~19:28 MT)
- First playable skeleton in **Godot 4.7.2**: `scenes/Main.tscn` is a thin shell that instances `scenes/levels/Level01.tscn`.
- Rancher with WASD movement (isometric Y compression), mouse aim, **LMB whip** (shove humans along the aim ray, explode sheep), **R** to restart after a win or loss.
- Silly humans wander the field and flee sheep. Killer sheep hunt humans and the player, and prefer humans when both are in range.
- Win: rescue every living human into the green safe zone. Lose: every human dies or the rancher runs out of HP.
- HUD: rescued count, player HP and a short objective line.
- Terrain: `stsh_terrain_atlas.png` with five 32×32 tiles (grass, dirt, path, rock, wall). Rock and wall collide on the World layer. `terrain_painter.gd` paints a default bordered pasture when `Ground` is empty.
- Collision layers 1–5: World, Player, Humans, Sheep, SafeZone. Groups: `player`, `humans`, `sheep`, `whippable`, `safe_zones`, `level_controller`.
- Art: STSH Pixel Pack v1 (32×32 sheets for the rancher, human and sheep, plus whip crack and explosion FX).

### Prototype 2 (2026-09-16 ~23:16 MT)
- Level01 became a larger open ranch (~72×48 tiles) with walls only on the outer border.
- Terrain atlas grew to eight cells: tree, bush and decor rock were added and don't collide. A second non-colliding `Decor` TileMapLayer holds trees, bushes and scenic rocks.
- Player scene and TileSet updated to match.

### Prototype 3 (2026-09-17 ~00:21 MT) — 16-bit art pass and sheep AI ranges
- **STSH Pixel Pack v2 (16-bit pass):** character sheets, terrain atlas and FX redrawn toward a SNES/Genesis ranch look (clearer silhouettes, limited palettes, dither and shading). Frame layouts stay 32×32.
- Silly humans now drift toward the rancher with silly pauses and path noise, and flee sheep within `flee_range` **160** px (5 tiles).
- Killer sheep **roam** by default (`roam_speed` 60), make a soft approach inside `interest_range` **256** (8 tiles), and fully chase and attack inside `attention_range` **160** (5 tiles). They prefer humans over the player.

## Build 001 — tile-anchored spawns
<a id="build-001"></a>

**Date:** 2026-09-17 ~21:55 MT  
**Status:** Pre-release (editor build, not published).

- **Spawns are tile-anchored inside the wall ring** (local slots → `map_to_local`). Scene positions are overwritten at runtime.
- `level_controller.gd` places the safe zone, player, 5 humans and 3 sheep from authoritative local tile slots on `Ground` once the terrain painter has run (`_place_entities_from_tiles`, deferred). Every slot is asserted to sit at least 4 tiles inside the border, and the slots are kept in sync with `CLEARINGS` in `terrain_painter.gd`.
  - Safe zone `(36, 24)`, player `(28, 28)`, humans `(12,10) (32,37) (49,35) (52,19) (13,32)`, sheep `(21,16) (50,12) (54,33)`.
- Humans and sheep get a soft interior clamp (`_soft_clamp_interior`), so nothing can be pushed through or outside the wall ring.
- `terrain_painter.gd` gained the helpers the spawner needs (`tile_center`, `is_interior_local`, `clamp_to_interior`).

## Build 002 — false-win fix, humans avoid the safe zone
<a id="build-002"></a>

**Date:** 2026-09-17 ~22:12 MT  
**Status:** Pre-release (editor build, not published).

- **False-win fix:** SafeZone stays `monitoring=false` until tile placement finishes. Humans spawn in map corners (≥12 tiles Chebyshev from the safe zone), and `GameState.setup_complete` gates win and loss. The instant "all rescued" at t=0 is fixed, so herding with the whip is required. At level start the HUD should read **0/5** rescued.
- Humans **avoid** the green zone on purpose ("too dumb to enter"): they steer away from it within `avoid_safe_range` **288** px (9 tiles). Overlap still rescues them, and a whip shove (`external_velocity`) is the intended rescue path.
- Human AI priority: flee sheep → avoid safe zone → follow rancher → wander.
- Shipping mindset for zip **002**: lock the herding mechanic (no auto-rescue, no empty win) and keep spawn slots synced with `CLEARINGS` in `terrain_painter.gd`.

## Build 003 — rescues locked until spawns settle
<a id="build-003"></a>

**Date:** 2026-09-17 ~22:19 MT  
**Status:** Pre-release (editor build, not published).

Rescues stay locked until physics syncs spawn teleports (fixes false 5/5 at start).
Humans spawn in corners and avoid the green zone; whip-herd them in.

- New `rescues_unlocked` gate in `level_controller.gd`. Spawn positions are baked to tiles, and SafeZone monitoring stays deferred.
- **Two 003 zips exist.** The original upload, kept on Drive, is attached as `Save-the-Silly-Humans-Godot-003.zip`. A repack made the same minute (`-003-rev.zip`) adds one more guard in `sheep.gd`: the sheep's interior clamp waits until `can_rescue_humans()` is true, so it can't fight the spawn teleports.

## Build 004 — human HP, possession, win/lose accounting, infection alarm
<a id="build-004"></a>

**Date:** 2026-09-17 ~22:43 MT  
**Status:** Pre-release (editor build, not published).

Gates kept in build 004: `rescues_unlocked`, baked tile positions, deferred SafeZone monitoring.

### Humans
- **No rancher attraction** — AI is flee sheep → avoid safe zone → wander only.
- **5 HP**; sheep call `take_damage(1, …)` (knockback + flash). At 0 HP → **possess** in place (reuse node).
- Possessed: leave group `humans`, join `possessed`, purple/magenta modulate, hunt like killer sheep; **LMB** whip **explodes** them; SafeZone ignores casual entry.
- Signal `was_possessed` → `GameState.add_possession()`.
- **RMB throw into safe zone** → `rescue_from_possession()` → `GameState.add_possession_save()` (possessed−−, rescued++; no explode).

### Win / lose (exact)
- `total_humans` = initial silly humans at setup.
- Living silly in field ≈ `total - rescued - possessed - dead`.
- **Win** when `rescued + possessed + dead == total` **and** `rescued >= 1` (every original human resolved; at least one saved).
- **Lose** when:
  - `possessed == total` (full conversion), or
  - player dead, or
  - all resolved with `rescued == 0` (no one saved).

### HUD / alarm
- Rescued X/Y, living humans, living sheep (non-exploding `sheep`), converted, player HP.
- Counts refresh ~every 0.25s from `level_controller`.
- `InfectionAlarm` (HUD child): pulsing red/magenta ring under humans with `health < maximum_health` still in `humans`; edge chevron if off-screen.

- Humans no longer follow the rancher: their AI is flee sheep → avoid safe zone → wander.
- New `scripts/ui/infection_alarm.gd`.

## Build 005 — RMB grab & throw
<a id="build-005"></a>

**Date:** 2026-09-17 ~23:05 MT  
**Status:** Pre-release (editor build, not published).

- New **RMB grab & throw**: latch a whippable along the aim and fling it **180° opposite the aim** (`throw_force` ~800). It shows a brief teal grab line.
- **LMB** crack still shoves silly humans and explodes sheep and possessed humans.
- Possessed humans thrown into the green zone are **saved** (rescue credit, no death). They won't casually walk in.
- Thrown sheep that pass within ~40 px of another living sheep → **both explode**. Possessed–sheep and possessed–possessed mutual destruction while thrown also works.
- `project.godot` gains the `whip_grab` input action.

### Grab / throw (RMB)

- Input action `whip_grab` = mouse button 2 (right click).
- Same `find_target` ray/cursor targeting as LMB; does **not** zip (no parent-to-target reel).
- Throw direction = **−aim** (180° from player→mouse). Tunables on `Whip`: `throw_force` **800**, `grab_cooldown_time` **0.40**.
- Targets implement `receive_throw(throw_direction, force)` with `_throw_timer` / `_thrown`.
- Sheep–sheep collision radius while thrown: `throw_collide_radius` **40**.
- Possessed flung into green → saved via `add_possession_save()` (not kill).

## Build 006 — layout: safe zone bottom-right, sheep den
<a id="build-006"></a>

**Date:** 2026-09-19 ~03:20 MT  
**Status:** Pre-release (editor build, not published).

- **Safe zone** moved to **bottom-right** interior (`SLOT_SAFE` local `(60, 38)`), path pad painted around it.
- Humans repositioned away from BR (≥12 Chebyshev): `(8,8)`, `(8,40)`, `(40,8)`, `(20,20)`, `(12,32)`.
- Player mid-field `(36, 24)` (old safe cell).
- **Sheep den** top-left (`SLOT_SHEEP_SPAWNER` `(8, 10)`): `scripts/world/sheep_spawner.gd` instances `Sheep.tscn` under `Entities/Sheep` every **60s** after `rescues_unlocked`, with ±16px jitter and soft cap **20** living sheep.
- Initial sheep: `(18,14)`, `(45,12)`, `(50,30)` (not on the den cell).
- Builds 003–005 kept: rescue unlock, HP/possession, grab/throw, HUD/alarm.
- New `scripts/world/sheep_spawner.gd`.

## Build 007 — whip animation and 32-bit art
<a id="build-007"></a>

**Date:** 2026-10-04 ~18:11 MT  
**Status:** Web beta (playable test build, not the live page).

Gameplay numbers are unchanged from build 006: LMB shove/explode, RMB grab and throw 180° opposite aim, `whip_force` 520, `throw_force` 800, cooldowns 0.35 / 0.40, the same targeting radii, HP, ranges, spawn slots, and sheep spawner timing (60s, cap 20). Hits still resolve on the click. Only the whip drawing and the art changed.

### Whip

`scripts/player/whip.gd` no longer draws one static segment.

- **LMB crack** (0.34s): a **16-segment** leather lash extends toward the aim point over the first ~0.20s (a traveling sine so the cord whips, not a straight rod), then fades. A handful of previous poses are kept as a short **afterimage**. At full extension a drawn tip spark fires, plus the **8-frame** `whip_crack` sprite (64×64, 22 fps, play-once) sitting on the tip.
- **RMB grab** (0.48s, still teal): three phases — a tightening **coil wind-up** (~0.12s, pulled back off the aim), a lash out to the latch point with a small **loop** at the tip, then a **follow-through** that swings the cord 180° opposite aim (the throw direction). Same 16 segments, same afterimage, tip spark tinted cyan. The 8-frame spark sheet is shared; grab tints it.

### Art pass

Sheets were redrawn (not scaled up). Nearest-neighbor stays on. File names are unchanged so the existing texture UIDs keep working.

| Sheet | Cells | Layout |
|-------|--------|--------|
| Rancher, human, sheep | **64×64** | 6 walk frames × 4 directions (down, left, right, up). Was 4×32. |
| Whip tip spark | **64×64** | 8 frames, non-looping |
| Explosion | **96×96** | 8 frames (hot core through smoke). Was 6×32. |
| Terrain atlas | **32×32** | Same 8 cells in a row: grass, dirt, path, rock, wall, tree, bush, decor rock. Richer color and detail inside each cell. |

SpriteFrames regions and speeds match those grids. Character sprites are offset up a few pixels so the new frames sit on the old collision feet; collision shapes are untouched. Rock and wall are still the only tiles with physics. Possessed humans stay the purple/magenta modulate of the human sheet.

Silhouettes: wide-hat rancher with a whip, big-headed silly humans (scarf, bright tunic), horned red-eyed sheep. Shading is local highlight plus a cool rim, not flat NES blocks.

_Web export: `web-beta-007.zip` is the unlabelled `web-beta/` folder from the project. Its game data (scenes, resources, textures and script identifiers) matches the 007 source exactly, and 006 and 008 don't match._

_Also attached: `stsh-game-007-backup-src.zip`, a working-folder backup of the 007 source taken before build 008. It matches the 007 zip except for an `export_presets.cfg` (Web preset), a regenerated `.import` file for the terrain atlas, and `infection_alarm.gd.uid`. The `.godot/` editor cache is left out._

## Build 008 — painted terrain (grassland, woods, paths, ponds)
<a id="build-008"></a>

**Date:** 2026-10-04 ~22:22 MT  
**Status:** Web beta (`web-beta-008/`, not the live page).

The old flat VIC-20-style terrain is gone. Level01 (72x48 tiles, 32 px, outer
stone wall) is now painted procedurally at runtime by
`scripts/world/terrain_painter.gd` (seed 8008) onto stacked TileMapLayers:
Ground → ForestFloor → Dirt → Path → Water → Tint → Detail → Entities/Props (y-sorted).

**Layout**
- Open, noise-varied grassland with tufts, wildflowers and pebbles (Detail layer).
- Woodland: Northeast Wood (oak/pine), Western Wood (oak/birch), South Wood
  (oak/fruit), a small pine copse in the north and a western hedge grove.
  Each cluster sits on a darker forest-floor layer and has dirt trails through it.
- Trails radiate from the player start (36,24): den (8,10) → centre → safe zone
  (60,38); centre → NE; centre → SW → (8,40); south loop; north spur to (40,8).
- Four small ponds with shore stones, reeds and lily pads; a few dirt patches.
- Safe zone sits on a path pad bottom-right; sheep den top-left with fence/hay/trough.
- All spawn/safe/den slots are forced into clearings (props keep a radius clear).

**Collision rules**
- Collide: outer wall (ground atlas wall row), water tiles (shore-aware polygons
  from `terrain_meta.json`), tree **trunks** only (small ellipse at the base),
  rocks/boulders, logs, stumps, fences, hay, trough, sign post.
- Walk-through: grass, forest floor, dirt, paths, flowers/tufts/reeds/lilies
  (Detail layer has collision disabled), bushes, and tree canopies.

**Art pipeline** (Python + Pillow, regenerate with `python3 tools/gen_terrain.py`
and `python3 tools/gen_props.py`, then
`godot --headless --path . -s res://tools/build_tileset.gd`): atlases in
`assets/tiles/stsh_*_atlas.png`, metadata in `terrain_meta.json` /
`props_meta.json`, tileset `stsh_terrain_tileset.tres` (sources 0 ground,
1 dirt, 2 path, 3 forest, 4 water, 5 props, 6 details).

**Tools**
- `tools/screenshot.gd` — preview render under xvfb:
  `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd -- /tmp/prefix`
- `tools/verify_layout.gd` — headless check that samples real physics per cell
  and confirms every slot is walkable, open (5x5) and reachable from the player
  start: `godot --headless --path . -s res://tools/verify_layout.gd`
  (Build 008: 517/3456 cells blocked, all 2939 free cells connected, PASS).

Gameplay numbers, whip, character art and the no-false-win gates
(`rescues_unlocked`, deferred SafeZone monitoring) are unchanged.
Web build: `web-beta-008/` (single-threaded "Web" preset). Not deployed when these notes were written; see **Status** above.

## Build 009 — mobile touch controls (PC controls unchanged)
<a id="build-009"></a>

**Date:** 2026-10-04 ~22:53 MT  
**Status:** **LIVE** — first build on https://savethesillyhumans.org/game.php, about 2026-10-04 23:50 MT. Hotfixes 009b–009d followed that night.

- New autoload `TouchInput` (`scripts/ui/touch_input.gd`) and `scenes/ui/TouchControls.tscn`
  (CanvasLayer 11, `scripts/ui/touch_controls.gd`), instanced in Level01.
- Touch UI stays hidden until the first real screen touch (or the `--touch` user arg for
  screenshots). Mouse/touch emulation is off in project settings, so a mouse click never
  turns it on.
- Left 40% of the screen: floating virtual joystick (multi-touch, per touch index).
- Right side: tap or drag anywhere in the playfield to aim and crack the whip; WHIP button
  cracks toward the last aim; GRAB button grabs and throws (180° from aim, as RMB).
  RESTART button appears on the win/lose screen. HUD help text shortens on touch.
- PC protection: WASD always wins over the joystick; whip aim uses
  `get_global_mouse_position()` whenever touch is inactive; LMB/RMB/R paths unchanged.
- Hybrid touchscreen laptops: any real mouse motion or click turns touch mode off and
  returns to mouse aim; touching the screen turns it back on.
- Gameplay numbers, terrain, art and win/lose logic unchanged.
- Web build: `web-beta-009/` (single-threaded "Web" preset).

## Build 009b — PLAY AGAIN button (hotfix)
<a id="build-009b"></a>

**Date:** 2026-10-04 ~23:48 MT  
**Status:** Live hotfix for 009.

- End screen: big PLAY AGAIN button under the win/lose message (works with mouse click
  and touch tap); R still restarts on keyboard. End messages no longer say "Press R".
  While the game is over, touches only hit PLAY AGAIN (joystick/WHIP/GRAB hidden).
- Files: `game_state.gd`, `level_controller.gd`, `hud.gd`, `touch_controls.gd`.

## Build 009c — touch joystick freeze fix (hotfix)
<a id="build-009c"></a>

**Date:** 2026-10-04 ~23:57 MT  
**Status:** Live hotfix for 009.

- 009 hotfix (joystick): phone browsers send fake mouse events around touches, which the
  hybrid-laptop check treated as a real mouse and switched touch mode off mid-drag (rancher
  froze). Now mouse input is ignored while a finger is down and for 2 s after the last touch,
  and tiny mouse moves are ignored. TouchControls reports every touch to TouchInput, drags
  with a renumbered finger id on the left side still drive the joystick, the joystick has a
  small dead zone and reaches full speed at ~70% deflection, and the player reads the touch
  vector whenever the keyboard vector is zero.
- Files: `player.gd`, `touch_controls.gd`, `touch_input.gd`.

## Build 009d — touch whip aims along facing (hotfix)
<a id="build-009d"></a>

**Date:** 2026-10-05 ~00:12 MT  
**Status:** Live hotfix for 009. Final 009 source; the local `Save-the-Silly-Humans-Godot-009.zip` is byte-identical to 009d. Web export: `web-beta-009d.zip` (the project's `web-beta-009/` folder, whose contents match 009d, not the original 009).

- 009 hotfix (facing whip): on touch, whip and grab aim along the rancher's facing
  direction (WHIP / playfield tap crack forward, GRAB throws behind). Mouse aim and
  LMB/RMB on non-touch stay exactly as before. Touch targeting uses the facing ray only.
- Files: `player.gd`, `whip.gd`, `hud.gd`, `touch_controls.gd`, `touch_input.gd`.

## Build 010 — rounds & levels, human camp, diagonal touch whip, directional throw
<a id="build-010"></a>

**Date:** 2026-10-05 ~20:41 MT  
**Status:** **LIVE** 2026-10-05 ~20:50 MT.

PC keyboard + mouse stay as before: WASD move, mouse aim, LMB crack, RMB grab, R restart.
Mouse aim and targeting are untouched (`TouchInput.get_aim_world()` still returns
`get_global_mouse_position()` whenever touch is inactive). The two intended RMB changes
(directional throw while moving, no rancher hitbox during a grab) apply on PC too.

### 1. 8-way facing / diagonal touch whip
- `player.facing` now follows the movement input snapped to the nearest 45° (8 unit
  vectors, `Player.snap_8()`). It only updates when the input length is
  >= `Player.FACING_MIN_INPUT` (**0.25**), so letting go of the stick never flicks it.
- Sprite animation choice is unchanged (4-direction art).
- On touch, WHIP / playfield tap / GRAB aim along this facing, so diagonals work.
  `whip.gd find_target` already normalises the facing ray (touch = ray only), so
  diagonal targets are hit. Mouse path unchanged.

### 2. No rancher hitbox during a whip grab
- Every RMB / GRAB calls `player.begin_grab_ghost(Whip.GRAB_TIME)` (**0.48 s**): the
  player body drops its Player layer bit (layer 2) and stops masking Humans (3) and
  Sheep (4). Result: layer 2→0, mask 13→1 (world walls still collide). Sheep and
  humans neither bounce off nor block the rancher.
- Sheep / possessed bites are distance-based (not collision), so `take_damage` is ignored
  while the grab window is active (brief contact invulnerability, by design).
- Restore is reliable: the player's own physics timer restores the saved layer/mask,
  `die()` restores immediately, `_exit_tree()` restores on scene reload, and a second
  grab just extends the window.

### 3. Directional throw
- The throw still resolves on the grab frame, and the steering input is read on that
  same frame. While moving (`player.get_steer_direction()`): PC = normalized WASD vector
  (so W+A throws exactly up-left), touch = the 8-way facing (stick past 0.25). With no
  movement input it's the classic throw 180° opposite aim.
- The teal coil wind-up and the follow-through swing now use the actual throw
  direction (`Whip._grab_throw_dir`). The standing-still visual is identical to 009.

### 4. Silly human camp, rounds and levels
- **Camp** (`scripts/world/human_camp.gd`, node `Entities/HumanCamp`, slot
  `SLOT_CAMP` = local **(9, 40)**, southwest): three canvas tents, campfire with animated
  flame, log seats and a pennant, all drawn procedurally on a trodden dirt yard that
  the terrain painter adds. There's **no collision**, so nobody can get trapped. The painter keeps
  the camp ellipse (6×4.2 cells) clear of trees, rocks and bushes (`CAMP_CELL`,
  `_in_camp`). The rest of the map is unchanged. It is 51 Chebyshev cells from the safe
  zone and 30 from the den.
- **Round**: 20 humans total. At start, 5 humans are placed (same slots as before) plus 5 sheep
  (new Sheep4 (59,10), Sheep5 (21,42)). The camp makes one human every **9 s**
  at its tent doorways until 20 have been generated (5 + 15). Then its timer stops.
  The sheep den keeps running (cap 20 living sheep).
- Humans wander at a random speed per human (**50–92 px/s**, was a fixed 70), with slightly
  varied pause chance and turn timing. Flee / avoid-safe-zone behaviour is unchanged.
- **Round end** (`GameState._check_end`): only when all 20 have been generated and
  every one is resolved (rescued, possessed, or dead). Zero living humans while the camp
  still has humans to send does not end the round. A safety net counts humans
  that vanish without a signal as lost, so a round can't soft-lock.
- **Win**: saved >= target → "Level N complete!  Saved X/20" plus a green **NEXT LEVEL**
  button (mouse click, touch tap, Enter or N). **Lose**: "Saved X/20 — needed Y"
  plus **PLAY AGAIN** (retry the same level; R or Enter also work). If the rancher dies, it's a loss: "The
  rancher is down!  Saved X/20 — needed Y", and you retry the same level.
- **Level persistence**: autoload `GameProgress` (`scripts/game_progress.gd`) keeps
  `current_level` across scene reloads, starting at level 1 on launch. It isn't saved to disk. The `--level=N` user
  arg is for testing.
- **HUD**: top-centre "Level N — save Y of 20". On the left: "Saved X / target Y" (turns green
  once you reach the target), HP, "Humans left to arrive: Z", living humans, living sheep, converted.
  Fonts are 17–28 px.
- **Touch**: while the round is over, `touch_controls.gd` hit-tests both the
  `play_again_button` and the `next_level_button` groups. NEXT LEVEL sets
  `TouchInput.next_level_just_pressed`, which the level controller consumes.

### Tuning (all in `scripts/level_config.gd`)

| Constant | Value | Meaning |
|---|---|---|
| `ROUND_TOTAL_HUMANS` | 20 | humans per round |
| `INITIAL_HUMANS` / `INITIAL_SHEEP` | 5 / 5 | placed at round start |
| `CAMP_SPAWN_INTERVAL` | 9.0 s | camp human timer (15 arrivals ≈ 2 min 15 s) |
| `TARGET_LEVEL1` / `TARGET_STEP` / `TARGET_CAP` | 10 / +1 / 18 | saves needed: L1 10, L2 11 … L9+ 18 |
| `SHEEP_SPEED_STEP` | 0.06 | sheep move/interest/roam speed ×(1 + 0.06·(L−1)); L1 = 105 (same as 009) |
| `DEN_INTERVAL_LEVEL1` | 45 s | den interval at L1 (was 60 s in 009; shortened because rounds are now ~3–4 min) |
| `DEN_INTERVAL_FACTOR` / `DEN_INTERVAL_FLOOR` | ×0.9 / 20 s | L2 40.5 s, L3 36.5 s, L4 32.8 s … floor 20 s (L9+) |
| `DEN_MAX_LIVING_SHEEP` | 20 | den soft cap (unchanged) |
| `HUMAN_WANDER_SPEED_MIN/MAX` | 50 / 92 | per-human wander speed |

Other constants: `Player.FACING_MIN_INPUT` 0.25, `Whip.GRAB_TIME` 0.48 s (= ghost window).
Possessed-human hunt speed doesn't scale with level.

### 5. Control sensitivity hook
`touch_controls.gd`: `JOYSTICK_DEADZONE` (0.12) and `JOYSTICK_SENSITIVITY` (1.4, full
speed at ≈70% deflection), plus the existing `JOYSTICK_RADIUS` (90). Values match 009.

### Tests / tools
- `tools/verify_layout.gd` now also checks Sheep4/5, the camp slot, every camp spawn spot
  (walkable + reachable) and that the camp footprint has no props or water and is far from the safe
  zone and den. Build 010: 515/3456 cells blocked, all 2941 free cells connected, PASS.
- A temporary scripted suite (deleted after the run) passed all 51 checks: 8-way facing and diagonal touch whip/targeting,
  grab ghost on/off and restore on death, directional throw (touch E/NE/still, PC W, W+A,
  still), camp stopping at 20 while the den keeps spawning, no early round end, win/lose
  screens, NEXT LEVEL / PLAY AGAIN via touch, mouse, N, Enter and R, level scaling, and PC mouse aim.
- Web build: `web-beta-010/` (single-threaded "Web" preset). Not deployed when these notes were written; see **Status** above.

## Build 011 — title screen, mobile aim assist, fixed joystick, square buttons, spawn tuning
<a id="build-011"></a>

**Date:** 2026-10-05 ~21:22 MT  
**Status:** **LIVE** 2026-10-05 ~21:25 MT.

PC keyboard + mouse are unchanged: WASD, mouse aim, LMB crack, RMB grab (and the 010
steer-throw), R restart, N/Enter next level. With touch inactive, the mouse aim and
targeting code runs exactly as in 010.

### 1. Mobile aim assist (touch only)
- When a touch whip or touch grab fires, `whip.gd find_assist_target()` picks the best
  whippable within `AIM_ASSIST_RANGE` (**220 px**) and inside a cone of
  ±`AIM_ASSIST_CONE_DEG` (**55°**) around the rancher's 8-way facing.
  Score = `(angle/cone)·0.55 + (distance/range)·0.45` (`AIM_ASSIST_ANGLE_WEIGHT`). The
  lowest score wins.
- The whip, the `whip_end` visual and the grab lash aim straight at that target. A grab with
  no steering throws 180° away from the target; a grab while steering throws in the
  steering direction (010 rule).
- With nothing in the cone, the whip cracks straight along facing, as before.
- `_touch_assist()` returns null whenever `TouchInput.active` is false, so the mouse path
  still calls the old `find_target()` with `get_global_mouse_position()`.

### 2–3. Square WHIP / GRAB buttons, buttons only
- `touch_controls.gd` draws two see-through rounded squares (**160×160**, corner radius 26)
  stacked on the right edge: WHIP (lower, primary) at (1092, 532), GRAB above it at
  (1092, 348), 28 px margins and a 24 px gap. They have 14 px of touch slop.
  When pressed, the fill gets brighter, the border turns thick and bright, and the button grows slightly;
  a short 0.18 s flash shows even quick taps. Both stay clear of the HUD text (top-left)
  and the level banner (top-centre).
- The old "tap the right side of the playfield to whip" is gone. Touches there do nothing.
  Only the WHIP button whips and only the GRAB button grabs.

### 4. Fixed joystick
- The base is stationary at (170, h−170) with `JOYSTICK_RADIUS` **100**, always drawn
  (semi-transparent) in touch mode. A touch grabs it if it starts within
  `JOYSTICK_GRAB_RADIUS_MULT` (1.6) × radius of the centre, or anywhere in the left
  `JOYSTICK_GRAB_SCREEN_FRAC` (40%) of the screen. The base itself never moves.
- Movement = finger offset from the fixed centre, clamped to the radius. Then
  `JOYSTICK_DEADZONE` (0.12) and `JOYSTICK_SENSITIVITY` (1.4) apply as in 010. Dragging past the edge
  keeps the knob on the rim and keeps steering.
- Kept from 009: an unknown or renumbered finger dragging in the joystick zone (or near the knob)
  takes over the joystick. Mouse events are ignored while a finger is down and for 2 s after the last touch.

### 5. Spawn / goal tuning (`scripts/level_config.gd`)

| Constant | 011 value | was (010) |
|---|---|---|
| `CAMP_LIVING_THRESHOLD` | 5 (= `INITIAL_HUMANS`) | — |
| `CAMP_MIN_SPAWN_INTERVAL` | 5.0 s | fixed 9 s timer |
| `TARGET_LEVEL1` / `TARGET_STEP` / `TARGET_CAP` | 5 / +1 / 15 | 10 / +1 / 18 |
| `DEN_INTERVAL_LEVEL1` | 90 s | 45 s |
| `DEN_INTERVAL_FACTOR` / `DEN_INTERVAL_FLOOR` | ×0.92 / 40 s | ×0.9 / 20 s |
| `SHEEP_SPEED_STEP`, `INITIAL_SHEEP`, `ROUND_TOTAL_HUMANS` | 0.06, 5, 20 | unchanged |

- Camp rule: a new human is generated only while fewer than 5 living silly humans are
  on the map. "Living" means the `humans` group: not yet rescued, not possessed, not dead. Camp spawns are at least 5 s apart,
  and round start counts as a spawn. The camp still stops at 20 per round.
  The round still ends only when all 20 have been generated and resolved.
- Den intervals: L1 90 s, L2 82.8 s, L3 76.2 s … floor 40 s (L11+). Targets: L1 5, L2 6 … L11+ 15.
  The HUD and end screen read their numbers from these constants.

### 6. Title screen
- `scenes/Title.tscn` + `scripts/ui/title_screen.gd` is now the project's main scene
  (`run/main_scene`), so the web export starts on it.
- The look is late-32-bit-era: a sunset sky with twinkling stars, a banded sun, drifting clouds,
  layered mountains, a pine tree line and a striped field with a dirt path. The camp tents and campfire
  (reused from `HumanCamp`) sit on the field, and a parade of 2× pixel sprites crosses the bottom
  (silly humans fleeing, sheep chasing, the rancher behind).
- The title is "SAVE THE / SILLY HUMANS" in emboldened, thick-outlined, drop-shadowed letters with a
  gradient and a sweeping shine (`assets/shaders/title_text.gdshader`), plus a slow bob.
  Under it is "RECONSIDERED" on a slanted ribbon. Below that: blinking "PRESS START", a START
  button, a controls hint, "© 2026 ECHELON PUBLISHERS GROUP" and "BUILD 011".
- START works by mouse click, Enter, Space or a touch tap on START (touches are hit-tested
  by hand because mouse emulation is off). Taps elsewhere do nothing. Start resets
  `GameProgress` to level 1, flashes, and loads `scenes/Main.tscn`. PLAY AGAIN and NEXT LEVEL
  reload the game scene directly and don't return to the title. Any first tap on the title
  also counts as the web-audio unlock gesture.
- Uses only Godot's built-in font (via FontVariation embolden), with no new font files.

### 7. Sensitivity constants
`touch_controls.gd`: `JOYSTICK_RADIUS`, `JOYSTICK_DEADZONE`, `JOYSTICK_SENSITIVITY`,
`JOYSTICK_CENTER_FROM_BOTTOM_LEFT`, `JOYSTICK_GRAB_RADIUS_MULT`, `JOYSTICK_GRAB_SCREEN_FRAC`,
`BUTTON_SIZE`, `BUTTON_TOUCH_SLOP`. `whip.gd`: `AIM_ASSIST_CONE_DEG`, `AIM_ASSIST_RANGE`,
`AIM_ASSIST_ANGLE_WEIGHT`.

### Tests
- A temporary scripted suite (deleted afterwards) passed all 54 checks. It covered:
  - the title (Enter, Space, mouse, touch, and taps away from START)
  - PC W/D movement, LMB, RMB, R, mouse aim and old targeting
  - aim assist at 40° hit, 120° ignored, out-of-range ignored, straight crack with an empty cone, scoring, grab assist
  - the buttons-only rule
  - the fixed joystick: fixed centre, clamping, deadzone, renumbered finger, fake mouse
  - the camp threshold, minimum interval and 20 cap, and the round end
  - den 90 / 82.8 s, targets, and NEXT LEVEL straight into the game
- `tools/verify_layout.gd`: PASS. 515/3456 cells blocked, all 2941 free cells connected.
- Web build: `web-beta-011/`. Not deployed when these notes were written; see **Status** above.

## Build 012: immediate win, scoring, Genesis-style HUD, How to Play
<a id="build-012"></a>

**Date:** 2026-10-05 ~22:08 MT  
**Status:** **LIVE** 2026-10-05 ~22:15 MT.

PC keyboard + mouse are unchanged (WASD, mouse aim, LMB crack, RMB grab/throw with WASD
steering, R restart and N/Enter next level on the end screen). The 011 touch controls are
unchanged too (fixed joystick, square WHIP/GRAB buttons, buttons-only, touch aim assist).

### 1. Round end (`scripts/game_state.gd` `_check_end`)
These are checked after every rescue, death, possession, possession save and destroyed
possessed human, in this order:
1. **Win** as soon as `rescued >= target`. The other humans of the 20 don't need to be resolved.
2. **Early lose** when the target is out of reach:
   `max_possible_saves() = total - dead - possessed_destroyed < target`. Humans still to
   arrive, silly humans in the field and *living* possessed humans count as savable, because a
   thrown possessed human can still be saved in the zone. The message is "Target out of reach!".
3. **Fallback (pre-012 rule)**: every human generated and resolved
   (rescued + possessed + dead = 20) with the target not reached → lose. As before, possessed
   humans who are still walking around count as resolved here.
- The rancher dying is still a lose. The 010 lost-track safety net is unchanged.
- On any round end, `level_controller._finish_round()` does the following:
  - stops the camp (`stop_generating`) and the sheep den (new `SheepSpawner.stop_spawning()`)
  - freezes gameplay by setting `Entities` to `PROCESS_MODE_DISABLED` (player, humans, sheep, safe zone)
  - saves the high score
  - shows the end screen (NEXT LEVEL on a win, PLAY AGAIN on a loss).
  The HUD, touch controls and score popups keep running.

### 2. Scoring (`level_controller.gd`, `game_progress.gd`)

| Event | Points |
|---|---|
| Silly human rescued (walked or thrown into the zone) | **+200** |
| Possessed human thrown into the zone (possession save) | **+200** (it counts as a save) |
| Sheep killed (a sheep's only death is `explode()`: whip crack, thrown sheep, thrown possessed human) | **+50** |
| Possessed human destroyed (whip / throw collision) | **+50** (treated as a monster kill) |
| Level clear bonus | **+500** flat **+100 per silly human still alive in the field** at the win |

- Points only count while the round is live (nothing after the end).
- The clear bonus doesn't use "per save above the target", because the win now fires on
  exactly the target save, so that term would always be 0. Humans kept alive in the field
  are the "extra" instead.
- Each award shows a floating pixel-font "+200" / "+50" popup at the event's world position.
  The popup rises about 48 px and fades over 0.9 s, in a `Level01/FX` layer outside `Entities`.
- `GameProgress.score` carries between levels in a run. START on the title calls
  `reset_progress()`, which sets level 1 and score 0. **Retrying a level (PLAY AGAIN, R, Enter
  after a loss, touch PLAY AGAIN) restores the score the level started with**
  (`level_start_score`), so a retry doesn't stack points.
- High score: `GameProgress.high_score` is the best for the session. It is also saved to
  `user://stsh_save.cfg` (IndexedDB on web) at each round end and loaded at startup.
  The title shows HI-SCORE at the top, and the end screen marks a new record with NEW!.

### 3. Genesis / Mega Drive HUD (`scripts/ui/hud.gd`, `scripts/ui/pixel_font.gd`)
- `PixelFont` is a hand-drawn 7×7 bold bitmap font (A–Z, 0–9, punctuation) baked at runtime
  into a `FontFile`. Each glyph has a white fill (tinted by `font_color`), a 1-px dark outline
  and a drop shadow. Integer scaling only, so it stays crisp. No font files were added.
- Top-left: `SCORE 00012450` (8-digit zero padding), `TIME m:ss` (round clock from
  rescues-unlocked to the round end), `LEVEL n`, and a row of pixel **hearts** for HP.
  The labels are yellow and the numbers white.
- Top-right (right-aligned): `SAVED x/target` (turns green on target), then smaller orange
  labels `ARRIVING` (humans still to come from the camp), `HUMANS` (living silly), `SHEEP`
  (living) and `CONVERTED`.
- The whole HUD sits above y≈150, so it is clear of the GRAB (y≥348) and WHIP buttons and the
  joystick. The text is 20–30 px on the 1280×720 canvas for phone landscape.
- The long help line is gone. A single short line sits at the bottom centre
  (`LMB WHIP · RMB GRAB+THROW · R RESTART`, or `WHIP AUTO-AIMS · GRAB THROWS` on touch)
  and fades out after 14 s. A "LEVEL n / SAVE x HUMANS" banner shows for about 3 s at round start.
- End screen: a bordered navy panel with the header (LEVEL n CLEAR! / GAME OVER), the reason
  line, and the breakdown: HUMANS n x200, SHEEP n x50, POSSESSED n x50, BONUS, LEVEL TOTAL,
  SCORE and HI-SCORE. The PLAY AGAIN / NEXT LEVEL buttons (same groups, so touch hit-testing is
  unchanged) are below the panel in the pixel font.

### 4. How to Play (title screen)
- A HOW TO PLAY button sits under START. It opens a panel in the title's 32-bit style with
  the gradient-shine heading, PC controls, mobile controls and the objective/mechanics list
  (safe zone, possession, camp SW, den NW, save target, scoring, faster sheep). It has a
  BACK button.
- Inputs: mouse click on the buttons; touch tap, hit-tested by hand (BACK first while the
  panel is open, START/HOW TO PLAY otherwise); keyboard **Enter/Space = START**,
  **H = How to Play**, **Esc/Backspace = Back**. While the panel is open, START and HOW TO
  PLAY are hidden, so stray clicks or taps can't start the game. Enter/Space still start the
  game from the panel.

### 5. Title build label: `BUILD 012`.

### Tests
- A temporary scripted suite (`tools/_test_012.gd`, deleted afterwards) passed **124/124** checks. It covered:
  - GameState: immediate win, early lose from deaths and from destroyed possessed humans, possession save toward the target, the all-resolved fallback
  - title How to Play open/close by mouse, touch and H/Esc/Backspace; START by Enter, Space, mouse, touch and Enter from the panel (each resets level 1 / score 0)
  - level 1: the 5th rescue (real safe-zone path) wins with 2 living humans and 13 camp humans pending; camp and den stopped, gameplay frozen, no spawns in the next 6.5 s
  - +50 for a real LMB sheep kill and +200 per rescue, with popups at the event position; bonus 700; score 1750 carries to level 2 via touch NEXT LEVEL
  - rancher-death lose, then PLAY AGAIN (mouse) and R restore the level-start score
  - early lose at level 11 (target 15) on the 6th destroyed possessed human, with +50 each
  - HUD values (time, score padding, counters, hearts) and layout clear of the touch controls
  - 011 PC regressions: D/W movement, LMB toward the mouse, RMB, no assist and old mouse targeting
  - 011 touch regressions: assist 40° hit / 120° ignored / out of range ignored, buttons-only, WHIP straight crack, GRAB, the fixed joystick, the camp threshold 5 and 5 s interval, den 90 / 82.8 s
- `tools/verify_layout.gd`: PASS (515/3456 cells blocked, all 2941 free cells connected).
- Web build: `web-beta-012/`. Not deployed when these notes were written; see **Status** above.

## Build 013: Karens, camp hold, power-ups
<a id="build-013"></a>

**Date:** 2026-10-06 ~00:16 MT  
**Status:** **LIVE** 2026-10-06 ~06:40 MT.

PC keyboard and mouse controls are unchanged: WASD, mouse aim, LMB crack, RMB grab and throw, R to restart, N/Enter for the next level. `project.godot` (including `[input]`) is byte-identical to 012. The 011/012 touch controls are unchanged too: fixed joystick, WHIP/GRAB buttons, aim assist. All 012 rules still apply: immediate win, out-of-reach loss, scoring, HUD, How to Play, high score.

### 1. Karens (level 3+, `scripts/humans/human.gd`, `level_controller.update_karen_clusters`)
- **Seeking.** From level 3, possessed humans look for each other.
  - Each one walks at 85 px/s toward the nearest other possessed human that is between 50 and 900 px away. Ignoring buddies already beside it means pairs keep merging instead of stopping as pairs.
  - A silly human within 70 px is still chased and bitten first.
  - At levels 1–2, possessed humans behave exactly as in 012.
- **Forming.** The level checks for clusters every 0.25 s.
  - When a possessed human has 3 or more other possessed humans or Karens within **120 px** (a group of **4 or more**), the whole group turns into **Karens**.
  - A possessed human that joins an existing mob turns too.
  - Each new mob gets one pink "KAREN!" popup.
- **Look.** Karens use their own sprite sheet (`assets/characters/human_karen_32.png`) with blue hair and a pink shirt. They don't get the possessed purple tint.
- **Mobbing.**
  - Karens chase the rancher when he is within 520 px. Otherwise they go after the nearest silly human, or another possessed human.
  - Speed is 132 px/s × the sheep speed multiplier, so about 148 px/s at level 3. The rancher runs at 260 px/s, so you can always outrun a mob.
  - Karens push apart within 26 px.
- **Fair contact damage.** A touch (34 px reach) does **1 heart**.
  - All Karens share **one 0.9 s cooldown**, so a mob of 5 hurts no more than a single Karen.
  - The cooldown only starts when the rancher actually loses health, so the grab-ghost window and other invulnerable moments don't count.
- **Converting.** Each Karen bites silly humans on a 1.0 s cooldown each. This uses the same 5-bite possession rule as sheep.
- **Toughness.** Karens have **2 HP**.
  - Whip cracks, shockwave hits, whip-shot hits and fire ticks each take 1 HP and knock the Karen back (420).
  - Thrown-body collisions work like they do for possessed humans and destroy the Karen outright: a thrown sheep or possessed human hitting a Karen, or a thrown Karen hitting one of them.
- **Saving.** A Karen grabbed and thrown into the safe zone counts as a normal possession save (+200, counts toward the target).

### 2. Camp hold (`scripts/world/human_camp.gd` `held_by_karens()`)
- While any Karen is alive, the camp sends nobody out.
- The HUD ARRIVING row turns red and reads `13 HELD`.
- The spawn timer keeps running, so humans start arriving again straight away once the last Karen is gone.
- Waiting humans still count as reachable in `max_possible_saves()`, so a hold never causes an out-of-reach loss by itself.
- A destroyed Karen counts exactly like a destroyed possessed human (`GameState.add_karen_destroyed()` → `add_possessed_destroyed()`).

### 3. Scoring
| Event | Points |
|---|---|
| Karen destroyed | **+100** (pink popup) |
| Karen thrown into the zone | +200 (possession save) |
| everything else | unchanged from 012 |

- The HUD shows a pink `KARENS n` row (living Karens) from level 3.
- The end screen adds a `KARENS n x100` row. The POSSESSED row no longer includes Karens.

### 4. Power-ups (`scripts/world/power_up.gd`, `scripts/player/power_ups.gd`)
**Drops.** Drop chance per kill:

| Kill | Drop chance |
|---|---|
| Sheep | 12% |
| Possessed human | 22% |
| Karen | 40% |

The type is weighted: HEALTH 30, FIRE WHIP 16, LONG WHIP 14, SHOCKWAVE 14, WHIP SHOT 14, STRONG THROW 12.

**Pickups.**
- Walk within 30 px to collect.
- Each pickup is a round coloured plate with a 9×9 pixel icon. It bobs, glows and blinks for its last 3 s.
- It disappears after **12 s**.
- Collecting one shows a popup with the power-up's name.

**Types:**

| Type | Effect |
|---|---|
| **HEALTH** | +1 heart, never above the maximum (no effect at full health) |
| **LONG WHIP** | Whip reach × 1.5 (210 → 315 px). The touch aim-assist range scales with it. |
| **STRONG THROW** | Throw force × 1.6 (800 → 1280) |
| **SHOCKWAVE** | Every crack also hits each sheep, possessed human and Karen within 95 px of the whip tip, with a ring effect |
| **FIRE WHIP** | Every crack sets fire to its target and to any sheep, possessed human or Karen within 60 px of the tip |
| **WHIP SHOT** | Every crack also fires a bolt (560 px/s, 560 px range) along the crack direction. It hits the first sheep, possessed human or Karen it reaches. It is aimed by mouse on PC and by the aim-assisted direction on touch. With FIRE WHIP also active, the bolt sets its target on fire. |

**Fire details.**
- A fire burns for 3 s and does 1 hit every 0.6 s, so a Karen burns out on the second tick and sheep or possessed humans on the first.
- After 0.25 s, a burning creature sets fire to sheep, possessed humans and Karens within 36 px, so fire runs through a packed mob.
- Silly humans and the rancher never burn.

**Timers.**
- Timed types last **18 s**.
- Picking up a type that is already active resets it to 18 s. Durations don't add up.
- Different types run at the same time.

**HUD.** Active power-ups show as icons under the hearts (top-left, y=168). Each has a 6-segment countdown bar that turns red under 25%, and the icon blinks for the last 3 s.

All numbers are in `scripts/level_config.gd`.

### 5. Title
- How to Play gains two bullets: Karens, and power-ups. The scoring bullet now includes 100 per Karen.
- The build label reads `BUILD 013`.

### Debug: start at level 3 (not shown to players)
`$GODOT --path . res://scenes/Main.tscn -- --level=3` (`GameProgress` reads `--level=N` from the user command-line arguments). The title's START button still resets to level 1, and the web build has no way to pass the argument.

### Export exclude filter
`export_presets.cfg` (Web preset) has `exclude_filter="web-beta*/*"`. Build 012 added it so that older `web-beta-0xx/` folders inside the project (including their icons and .pck files) are never packed into a new export. Keep it when adding presets.

### Tests
The temporary suites were deleted after the run.
- `tools/_test_013.gd`: **88/88** checks.
  - Input map: WASD, LMB-only whip, RMB-only grab, no new actions.
  - Karen formation: never at level 2. At level 3, seeking closes the gap. Three possessed humans close together or four spread 200 px apart do not form; four within 120 px do. Checks HP, the sprite sheet, the popup and the HUD count, a 5th possessed human joining, and the automatic 0.25 s check.
  - Camp hold: holds while a Karen is alive, counts as reachable, resumes once the Karens are gone.
  - Conversion by Karens, and mob damage with the shared cooldown.
  - Karen kill: +100, the breakdown row, and a destroyed Karen counting as a destroyed possessed human.
  - Each power-up: health cap, long whip reach and assist, strong throw, shockwave, fire crack and spread, whip-shot hit and range, drops, and pickup despawn.
  - How to Play fits above BACK.
- `tools/_test_012.gd`: all **99/99** 012 regression checks, plus 013 checks (base whip and throw values unchanged without power-ups, and no KARENS row at level 1).
- `tools/verify_layout.gd`: PASS.

### Web build
`web-beta-013/`, exported with the same preset. Not deployed when these notes were written (Build 012 stays live. See **Status** above.)

## Build 014: MSM Cam, inventory (no power-up timers), corner-wedge touch controls
<a id="build-014"></a>

**Date:** 2026-10-07 ~04:17 MT  
**Status:** Not deployed on its own; build 014b (014 plus the aim reticle) replaced it before going live.

All new numbers are in the **build 014** sections of `scripts/level_config.gd`.

### 1. Controls

Every weapon has a **PRIMARY** and a **SECONDARY** action.

| Weapon | PRIMARY | SECONDARY |
|---|---|---|
| WHIP (slot 1, always owned) | WHIP (crack) | GRAB (grab & throw) |
| MSM CAM (slot 2, from a pickup) | REC (hold to film) | SWING (camcorder shove) |

**PC:** WASD moves and the mouse aims. LMB is PRIMARY and RMB is SECONDARY; hold LMB to film with the cam. Q or the mouse wheel cycles weapons, and 1 / 2 select a slot. R restarts and N / Enter goes to the next level, as before. The help line reads `LMB WHIP/REC · RMB GRAB/SWING · Q SWAP`.

**Touch** (`scripts/ui/touch_controls.gd`, geometry in `scripts/ui/touch_layout.gd`):
- **Joystick:** fixed at the bottom-left, unchanged from build 011.
- **PRIMARY wedge:** bottom-right corner (WHIP, or REC with the cam).
- **SECONDARY wedge:** top-right corner (GRAB, or SWING with the cam).
- **Weapon exchange wedge:** top-left corner. It shows the current weapon's icon and one dot per slot; tap it to cycle weapons.
- **Wedge shape:** a right-angle corner piece. The inner edge is a diagonal at `WEDGE_ANGLE_DEG` = **30°** from horizontal, so each wedge is wider than it is tall. Sizes are fractions of `TouchLayout.unit(viewport) = min(h, w·9/16)`:
  - action wedges: 0.27 tall (194 px at 720), 0.20 along the far edge, ≈481 px along the screen edge
  - exchange wedge: 0.16 tall (115 px), 0.14 along the far edge
- **Look:** semi-transparent Genesis-style panels with a bevel and outline, and a label in the weapon's colour. REC is red with a dot and shows `HOLD` / `FILMING` / `NO BATTERY`. SWING shows a cooldown bar. A pressed wedge brightens.
- **Hit-testing:** point-in-polygon on each wedge grown by `WEDGE_TOUCH_SLOP` = 14 px (`Geometry2D.offset_polygon` + `is_point_in_polygon`). Wedges are tested before the joystick zone.
- **Multi-touch:** each wedge and the joystick track their own finger index, so you can steer, hold REC and SWING at the same time. The 011 fake-mouse-event guard (`TouchInput.note_touch`) is kept.
- **HUD on touch:** left stats start under the exchange wedge (`hud_left_top`), right stats end left of the SECONDARY wedge (`hud_right_margin`), and the objective/help line sits between the joystick and the PRIMARY wedge.
- **Removed:** the old square WHIP / GRAB buttons and the planned SWAP button.
- **Why PRIMARY is bottom-right:** that is where the right thumb rests in landscape, and REC is a held action.

**Aspect ratios.** Layout and hit-tests are computed from the viewport size, checked at 1280×720, 1560×720 (19.5:9), 1280×960 (4:3) and 1280×591: no wedge overlaps another wedge, the joystick or the HUD. The project keeps stretch aspect `keep`, so in practice the viewport is always 1280×720 letterboxed (see Known issues).

### 2. MSM Cam (`scripts/player/msm_cam.gd`, art in `scripts/player/camcorder.gd`)
- **Cone:** 39° (half-angle `CAM_HALF_ANGLE_DEG` 19.5°), range 2 × base whip reach = **420 px**.
- **REC:** hold PRIMARY to film. The battery drains only while filming: **20 s** per battery.
  - At 0 a spare loads automatically, with a beep, a `BATTERY SWAP` flash and a popup.
  - With no spare left, the cam is dead: REC shows `NO BATTERY`, and the slot and wedge grey out.
- **Look:** a subtle warm cone with scanlines, a rolling band and flicker (dashed outline when equipped but not filming). The ranger carries an obvious 1980s VHS shoulder camcorder with side, front and back views and a blinking tally light. A red `●REC` tag shows over his head, and he faces the aim while filming or swinging.
- **REC overlay** (HUD): corner brackets, `●REC`, a running timecode, `SP`, `MSM CAM`, a battery gauge with `+N` spares, and a `KAREN CAM` exposure meter.
- **Silly humans in the cone:** a "convinced" meter fills in **1.5 s** and drains at 0.35/s outside the cone. A badge over the head shows the meter, then a green ▶ tag. Once convinced, the human walks to the nearest safe zone at **1.25×** its own speed with a green tint, side-stepping close sheep.
- **Karens in the cone:** **+35 %** speed, erratic zig-zag toward the camera, for as long as they are filmed plus **2 s**. Each Karen in the cone has a **2 %/s** chance to possess a random silly human (an `INFECTED!` popup).
- **VIRAL:** VIRAL triggers after **3 s** of cumulative screen time with **≥2 Karens** in the cone (or every living Karen, if fewer than 2 are alive).
  - A callout reads `VIRAL!` / `KARENS EXPOSED! N HUMANS RUN FOR SAFETY`.
  - Every non-possessed human stampedes to safety at **1.5×** for **8 s**.
- **Sheep den:** spawns **×1.6** faster while filming (`SheepSpawner.rate_mult`).
- **SWING** (SECONDARY):
  - reach 0.6 × base whip = **126 px**, in a **90°** arc
  - no damage, no battery cost; works with a dead battery
  - knockback ≈**200 px** (measured 218 px on a sheep), **0.6 s** stagger with stars, **0.5 s** cooldown
  - visuals: a whoosh arc, a camcorder lunge and impact stars
  - filming pauses for 0.3 s, then resumes if REC is still held
  - hits sheep, possessed humans and Karens; silly humans are never hit

### 3. Power-ups → inventory (`scripts/player/power_ups.gd`)
- **No more power-up timers** (the 18 s timers are gone).
- **Whip mods** (LONG WHIP, STRONG THROW, WHIP SHOT): one at a time. A mod stays until a different mod is picked up.
- **FIRE WHIP:** **10** charges per pickup (max 20). **SHOCKWAVE:** **3** charges per pickup (max 6). Each whip crack spends one of each held charge type, even on a miss. Fire overlays the current mod, and at 0 the whip is back to the mod alone.
- **HEALTH:** +1 heart instantly.
- **MSM CAM:** a rare drop with a full 20 s battery.
  - The first pickup adds slot 2 and auto-equips it.
  - Later pickups recharge the battery, or count as a spare.
- **BATTERY:**
  - loads a dead cam straight away
  - otherwise it becomes a spare (max **3**)
  - otherwise it tops up the battery
- **Drop weights.** The base weights are HEALTH 30, FIRE 16, LONG 14, SHOCK 14, SHOT 14, STRONG 12, **MSM CAM 8** and **BATTERY 5**.
  - Karen kills: the cam weight is ×2.5.
  - Once you own the cam: the cam weight is ×0.25, and BATTERY rises to 20.
  - Cam and battery pickups stay on the ground for 20 s (other pickups 12 s). This is ground despawn, not a power-up timer.
- **Carry-over:** the inventory (cam, battery, spares, mod, charges, equipped weapon) carries into the next level of a run (`INVENTORY_CARRIES_OVER`). A retry restores the inventory you had at the start of the level. A new game clears it.

### 4. Weapon slots (`scripts/player/weapons.gd`)
- `LevelConfig.WEAPON_DEFS` lists the weapons in slot order: id, name, icon, the node that implements `weapon_primary()` / `weapon_secondary()`, the wedge labels and the colours.
- The whip is always slot 1. To add a weapon, add a def and a Player child node with those two methods.

### 5. HUD (`scripts/ui/hud.gd`)
- The old power-up timer bar is replaced by an **inventory panel** under the hearts:
  - weapon slots (the current one framed, a dead cam greyed out with a slash)
  - an 8-segment `BATT` bar and 3 spare pips
  - the whip-mod icon, and fire `xN` / shockwave `xN`
- Also new: the camcorder REC overlay and the big `VIRAL!` callout.

### 6. Title / How to Play
- The build label reads `BUILD 014`.
- How to Play has new PC and mobile control lists (corner wedges and dual modes), plus bullets for no-timer power-ups, the MSM Cam, the battery and SWING.

### Debug scenarios (debug builds only)
`scripts/debug_scenarios.gd` and `GameProgress._read_debug_args()` run only when `OS.is_debug_build()` is true: the editor, a native debug run, or a web export made with `--export-debug`. The shipped `--export-release` web build ignores them.
- Native: `$GODOT --path . -- --scenario=NAME [--level=3] [--touch]`
- Web debug export: `index.html?scenario=NAME&level=3&touch=1`

Scenarios:
- `cam_humans`, `cam_karens` (needs level 3), `swing`, `inventory`
- `pose_down` / `pose_up` / `pose_left` (camcorder views)
- `howto` (opens How to Play)

In a scenario the rancher is invulnerable for the shot.

### Tests
The temporary suite `tools/_logic014.gd` was deleted after the run. It passed **39/39** checks:
- whip-mod replacement, fire/shock charges and caps, charge spend per crack
- cam pickup, slot and auto-equip; spare cap of 3; cycle and select
- cone angle and range; no drain while idle, drain while filming; sheep rate ×1.6 on and off; automatic battery swap
- swing hit, stagger, knockback distance and cooldown
- drop weights
- wedge geometry and no overlap at 4 viewport sizes, point-in-polygon tests that exclude the diagonal
- multi-touch (joystick + PRIMARY + SECONDARY on 3 fingers) and the exchange-wedge tap

All scripts parse with no errors, and the release web export loads in headless Chrome with no script errors.

### Known issues / notes
- **Letterboxing:** stretch aspect stays `keep` (the title screen uses fixed 1280-wide coordinates). On a 19.5:9 phone, the wedges sit in the corners of the 16:9 game area with black bars at the sides, not in the physical screen corners. Switching to `expand` would put them in the physical corners because the layout already follows the viewport size, but the title screen and HUD would then need a pass.
- **Not tested on real phones or tablets**, only in headless Chrome with emulated touch and native renders.
- **Audio:** the battery-swap beep is procedural (`scripts/sfx.gd`), and browsers play audio only after the first tap or click.

### Web build
`web-beta-014/`, exported with the same Web preset (`--export-release`). Not deployed when these notes were written (Build 013 stays live. See **Status** above.)

## Build 014b: aim reticle (PC) and reach crosshair (touch)
<a id="build-014b"></a>

**Date:** 2026-10-07 ~04:41 MT  
**Status:** **LIVE** 2026-10-07 ~06:41 MT. Replaced by build 015 at ~22:27 MT.

Everything from 014, plus the aim reticle. The in-game label reads `BUILD 014B`.

### What it does
- **PC (mouse):** while a round is being played, the OS pointer is hidden over the game (`Input.MOUSE_MODE_HIDDEN`). A pixel-art reticle is drawn at the mouse instead: a ring, four crosshair arms and a centre dot, with a 1 px dark outline so it reads over grass, dirt and water.
  - The pointer comes back as soon as the round ends (PLAY AGAIN / NEXT LEVEL buttons), when the rancher dies, while the level changes, on the title screen / How to Play, and when the mouse leaves the window. The game has no pause menu.
- **Touch:** the joystick is unchanged. A crosshair is drawn in the world at the **current weapon's reach along the rancher's 8-way facing**, the same aim the whip and cam use.
  - Whip: it sits exactly where the crack lands: on the aim-assist target if there is one (snapped, green), otherwise at whip range (210 px, or 315 px with LONG WHIP).
  - Cam: it sits at the far edge of the cone (420 px). If that point is off screen or under a corner wedge, it slides back along the aim line (never closer than half range), so it never covers a wedge.
  - Visibility: **always faintly visible** during play (alpha 0.35). It is full brightness while the joystick or a wedge is held and for **1 s** after release, and whenever it is green.
  - It is a `Node2D` on its own CanvasLayer (layer 9, under the HUD 10 and the wedges 11) and never handles input, so wedges, joystick and multi-touch are untouched.
- **Feedback:** the ring grows and brightens on a whip crack, grab or camcorder swing, and pulses gently while filming.

### Colour rules (`Reticle.evaluate()`, `scripts/ui/reticle.gd`)
- **GREEN** = the current weapon's PRIMARY would hit / affect a valid target. Otherwise it is matte **RED**.
- **Whip** (valid targets: sheep, possessed humans, Karens):
  - The rule uses the whip's own target resolution, so green means the crack really lands on it.
  - PC: `Whip.find_target` with the mouse as the aim point, which is the existing PC aim assist: 70 px around the reticle or 36 px around the aim line, within the current whip range (LONG WHIP included). The reticle itself must also be within reach + `RETICLE_SNAP_RADIUS` (28 px).
  - PC, past reach: the reticle stays at the mouse and stays red, and a small dot marks max reach on the aim line.
  - Touch: `find_assist_target` (the 55° touch assist cone), then `find_target` along the facing ray, exactly as `fire_whip` does.
  - A silly human under the whip counts as "not a target" (whipping them is herding): red.
  - When green, small lock-on brackets mark the target the crack will land on.
- **MSM Cam** ("simple rule"): green when the cam can film (battery left, or a spare that REC would auto-load) and any filmable target (a silly human or a Karen) is inside the 39° / 420 px cone along the current aim. The target closest to the aim line gets the lock-on brackets. On PC the reticle stays at the mouse; past 420 px a dot marks the cone's range.

### Config (`LevelConfig`, "build 014b reticle")
| Constant | Value |
|---|---|
| `RETICLE_RADIUS` / `RETICLE_ARM` / `RETICLE_GAP` / `RETICLE_THICK` | 11 / 7 / 3 / 2 px |
| `RETICLE_GREEN` | (0.46, 1.0, 0.40) |
| `RETICLE_RED` (matte) | (0.72, 0.33, 0.31) |
| `RETICLE_OUTLINE` | (0.06, 0.03, 0.08) |
| `RETICLE_ALPHA` | 0.92 |
| `RETICLE_SNAP_RADIUS` | 28 px (reach tolerance + lock-on size) |
| `RETICLE_TOUCH_HOLD` / `RETICLE_TOUCH_IDLE_ALPHA` | 1.0 s / 0.35 |
| `RETICLE_PULSE` | 0.35 |
| `RETICLE_REACH_DOT_ALPHA` | 0.75 |
| `RETICLE_LAYER` | 9 |

### How to Play
- PC: `MOUSE — aim the reticle`. Mobile: `crosshair = weapon reach`.
- New bullet: "RETICLE / crosshair turns GREEN when a target's in range (whip reach or cam cone); RED = nothing to hit."

### Debug scenarios (debug builds only)
- `reticle_pc` (whip; a frozen sheep; move the mouse)
- `reticle_pc_karen` (use with `level=3`)
- `reticle_touch_whip`, `reticle_touch_cam` (use with `touch=1`)

### Tests
The temporary suite `tools/_logic014b.gd` was deleted after the run. It passed **34/34** checks:
- PC whip: green on a sheep, red on empty ground, red + reach dot past reach, LONG WHIP reach, silly human = red, and green target == `find_target`
- touch whip: range along facing, 8-way, snap to the assist target, crosshair == `whip_end` after a real crack
- cam: cone in/out, range, dead battery with and without a spare, Karen; touch far edge; wedge slide-back
- pointer hidden in play; restored on round end, death and level exit; never touched in touch mode
- reticle is a non-Control `Node2D` under the HUD and wedge layers

Whip, aim assist, facing, weapons and touch-control code is unchanged in 014b.

### Known issues / notes
- Headless Chrome screenshots don't include the OS pointer. Hiding was checked through the canvas CSS cursor (`none` in play, `auto` on the title screen).
- PC cam: the "simple rule" means the reticle can be green while the mouse is beyond 420 px, because the cone points that way. The reach dot shows where the cone ends.
- The touch crosshair is drawn in the 16:9 game area (same letterboxing note as 014).
- Not tested on real phones or tablets.

### Web build
`web-beta-014b/`, exported with the same Web preset (`--export-release`). It was the live build at https://savethesillyhumans.org/game.php until build 015.

## Build 015: boss battle, TRUSTIN JUDEAU (between level 2 and level 3)
<a id="build-015"></a>

**Date:** 2026-10-07 ~22:22 MT  
**Status:** **LIVE** 2026-10-07 ~22:27 MT. Replaced by build 015b at ~10:12 MT on 2026-10-08.

Everything from 014b, plus a boss fight. The in-game label reads `BUILD 015`.

Trustin Judeau, "Prime Minister of Poutine", is an invented, good-natured cartoon parody: swoopy side-part hair, a big toothy grin, a sharp navy suit, a maple-leaf lapel pin and red maple-leaf socks. He throws poutine (fries, gravy and cheese curds in a paper boat) that splats into gravy puddles. No real likeness, photos or third-party assets: all art comes from `tools/gen_boss.py` (MIT, same generator approach and `tools/artlib.py` shading as the other sprites). All sounds are generated in code (`scripts/sfx.gd`).

### Where the boss sits in the campaign
- **Level 1 → Level 2 → BOSS → Level 3 → …** Levels 2 and 3 already existed in `LevelConfig` (save targets **6** and **7**; Karens start at level 3), so no new level progression was needed.
- Win level 2 and the end panel's button reads **BOSS FIGHT!** (the panel adds "NEXT: TRUSTIN JUDEAU!"). It loads `scenes/levels/BossArena.tscn`. Score and inventory carry over, exactly as they do between levels.
- Beat him and **CONTINUE** goes to **level 3** (`GameProgress.finish_boss()`). **PLAY AGAIN** on the win screen replays the boss fight.
- **Die in the arena:** normal GAME OVER panel. **PLAY AGAIN** (or R) restarts **the boss fight**, not level 1. Score and inventory are restored to what you had when you entered the arena (the usual `begin_level` / `restore_level_start_score` retry).
- **Direct test entry:** a red **BOSS FIGHT** button on the title screen and on the How to Play screen (or press **B** there). It starts a fresh run at the boss (score 0, empty inventory); CONTINUE afterwards goes to level 3.
- Flow code: `LevelConfig.BOSS_AFTER_LEVEL` (2), `GameProgressCheck.boss_follows()`, `level_controller.request_next_level()`, and `GameProgress.enter_boss()` / `start_at_boss()` / `finish_boss()`. While in the arena, `current_level` stays 2 and `boss_return_level` is 3.

### The fight
- **10 hearts**, shown in a Genesis-style boss bar (name plate and 10 hearts) at the top centre. On touch it sits between the swap wedge and the GRAB wedge. A heart flashes as it is lost, and the border blinks red in rage.
- **Title card** on entry: the band slides in with his portrait, "BOSS BATTLE!", the name plate, "PRIME MINISTER OF POUTINE" and "DODGE THE POUTINE · WHIP HIM 10 TIMES". For 2.8 s he only waves.
- **Hit feedback:** each heart lost gives **0.6 s of i-frames** with a white flash, a wobble, a knock-back (~85 px), a quip ("NOT THE HAIR!", "SUNNY WAYS!", …) and +100 points.
- **Movement:** he strafes around you at about 250 px, just outside whip reach (210 px), so step in to crack him. He backs off when you're closer than 120 px, but slower than you run. Every 3–5 s he does a short dash (~160 px) after a 0.25 s crouch-and-dust tell. He never leaves the lawn.
- **Arena:** a Parliament-lawn clearing painted by `terrain_painter.gd` with `layout = "boss_arena"` (42×28 cells, seed 1515):
  - a mown lawn with stripes, an oval promenade path, two flower beds and a forecourt path
  - corner groves, hedges and fences
  - the generated Parliament building (stone, copper roofs, clock tower, flag; solid) on the north edge
  - no humans, sheep, camp or pickups; you fight with the inventory you brought

### Attack patterns (escalate with his hearts left)
Every attack has a wind-up: his arm goes up with a poutine, a "!" appears over his head, and a dashed aim line (or landing ring) shows where it will go. The wind-up lasts **0.5 s** (**0.42 s** in rage), and the aim locks 0.15 s before release, so a sidestep always dodges. Pause after each attack: 1.5 / 1.3 / 1.15 / 1.0 s by phase.

| Phase | Hearts | Attacks (weights) |
|---|---|---|
| 1 | 10–8 | single aimed poutine (290 px/s) |
| 2 | 7–5 | single 40 % · **3-way spread** 60 % (±20°, 270 px/s) |
| 3 | 4–3 | single 20 % · spread 35 % · **lob** 45 % |
| 4 (rage) | 2–1 | **volley** 30 % (3 fast aimed shots, 360 px/s, 0.2 s apart) · **radial burst** 30 % (ring of 10, 220 px/s; never twice in a row) · lob 25 % · spread 15 %; strafe 95 → 125 px/s |

- **Lob:** the target is your position when the wind-up starts. A red landing ring and a shadow show the spot for the whole 1.1 s flight (arc 150 px high). It splashes everything within 42 px.
- **Poutine hit:** 1 rancher heart (the existing 1-per-hit rule; 5 hearts), a "GRAVY'D!" popup and a gravy splat. You can lose at most one heart per 0.8 s to poutine, so a burst can't chain-hit you. Poutine that misses splats where it lands or disappears after 900 px.

### Weapons vs. the boss
| Weapon / move | Effect |
|---|---|
| WHIP crack | 1 heart (normal targeting; the reticle turns GREEN when he's in reach, with lock-on brackets) |
| WHIP SHOT bolt | 1 heart |
| SHOCKWAVE crack | 1 heart, even if the lash itself misses, as long as he's inside the shockwave radius |
| FIRE WHIP | the crack's heart + a burn tick of **+1 heart 0.75 s later** (once per fire crack, never stacks, waits out i-frames) |
| GRAB (whip RMB) | "TOO HEAVY!": a short tug (~100 px) and a 0.3 s stagger. No throw, no damage |
| MSM CAM REC | he **poses** for the camera (thumbs-up, wink, teeth sparkle): stops, cancels a wind-up, no damage. Holds while filmed (max 2.2 s) + 0.8 s after, which is time to swap to the whip and crack him. Then he's camera-shy for 6 s. Counts as a filmable target (green reticle) |
| MSM CAM SWING | shoves him ~120 px (0.6 × normal swing) + 0.6 s stagger, no damage |

Whip hits do **not** cancel a wind-up. GRAB, SWING and REC can cancel one at most once per **3 s** ("super armour"), so the fight can't be stun-locked.

### Win / lose
- **Win:** he sits down dizzy ("SORRY! I'LL BE BACK... AFTER RECESS!"), the poutine on screen splats, and you're invulnerable for the 1.8 s defeat animation. Then a fanfare and the **BOSS DEFEATED!** panel with **PLAY AGAIN** / **CONTINUE**.
- **Score:** +100 per heart knocked off (1000 total), **+2500** defeat bonus, **+300** per rancher heart left, **+20 per second under 90 s**. The breakdown rows are HEARTS, DEFEAT BONUS, HEALTH, TIME, LEVEL TOTAL, SCORE and HI-SCORE. The hi-score updates as usual.
- **Lose:** the normal GAME OVER panel ("Trustin Judeau wins this round! PLAY AGAIN restarts the boss fight."), with the rows HEARTS and BOSS LEFT.

### Config (`LevelConfig`, "build 015 boss")
| Constant | Value |
|---|---|
| `BOSS_AFTER_LEVEL` | 2 |
| `BOSS_HEARTS` / `BOSS_IFRAMES` | 10 / 0.6 s |
| `BOSS_HIT_PUSH` | 260 px/s (decays at `SWING_PUSH_DAMPING` 3/s ≈ 85 px) |
| `BOSS_FIRE_DELAY` | 0.75 s |
| `BOSS_POSE_MAX` / `_LINGER` / `_COOLDOWN` | 2.2 / 0.8 / 6.0 s |
| `BOSS_SWING_PUSH_MULT` / `BOSS_GRAB_TUG` / `BOSS_STAGGER` | 0.6 / 300 px/s / 0.6 s |
| `BOSS_INTERRUPT_COOLDOWN` | 3.0 s |
| `BOSS_STRAFE_SPEED` / `_RAGE` | 95 / 125 px/s (rancher: 260) |
| `BOSS_PREF_DIST` / `BOSS_RETREAT_DIST` | 250 / 120 px |
| `BOSS_DASH_SPEED` / `_TIME` / `_TELL` / `_EVERY` | 620 px/s / 0.26 s / 0.25 s / 3–5 s |
| `BOSS_WINDUP` / `BOSS_WINDUP_RAGE` | 0.5 / 0.42 s |
| `BOSS_INTRO_TIME` | 2.8 s |
| `BOSS_PHASE2_HEARTS` / `PHASE3` / `RAGE` | 7 / 4 / 2 |
| `BOSS_ATTACK_GAP` | 1.5, 1.3, 1.15, 1.0 s |
| `POUTINE_SPEED` / `_SPREAD_SPEED` / `_VOLLEY_SPEED` / `_RADIAL_SPEED` | 290 / 270 / 360 / 220 px/s |
| `POUTINE_SPREAD_DEG` | 20° |
| `POUTINE_VOLLEY_COUNT` / `_GAP` | 3 / 0.2 s |
| `POUTINE_RADIAL_COUNT` | 10 |
| `POUTINE_LOB_TIME` / `_HEIGHT` / `_RADIUS` | 1.1 s / 150 px / 42 px |
| `POUTINE_HIT_RADIUS` / `POUTINE_RANGE` / `POUTINE_DAMAGE` | 22 px / 900 px / 1 |
| `BOSS_PLAYER_HIT_COOLDOWN` | 0.8 s |
| `BOSS_POINTS_PER_HEART` / `BOSS_DEFEAT_BONUS` / `BOSS_HEALTH_BONUS` | 100 / 2500 / 300 |
| `BOSS_TIME_PAR` / `BOSS_TIME_BONUS_PER_SEC` | 90 s / 20 |
| `BOSS_DEFEAT_ANIM` | 1.8 s |

A good clear (about 60 s, full health) scores roughly 1000 + 2500 + 1500 + 600 = **5600**.

### Files
- New:
  - `scripts/boss/judeau.gd` (boss AI, hit rules, telegraphs)
  - `scripts/boss/poutine.gd` (projectiles, lob, gravy splat)
  - `scripts/boss/boss_level.gd` (arena controller; extends `level_controller.gd`)
  - `scenes/levels/BossArena.tscn`
  - `scripts/game_progress_check.gd`
  - `tools/gen_boss.py` → `assets/boss/judeau_96.png`, `poutine_32.png`, `gravy_splat_48.png` and `parliament.png`
  - `tools/boss_shots.gd` (screenshot driver)
- Boss sheet `judeau_96.png`: 10 frames of 96×112. Frames 0–1 idle, 2–3 walk, 4 wind-up, 5 throw, 6 pose, 7 hurt, 8–9 defeated.
- Changed:
  - `level_config.gd`
  - `game_progress.gd`
  - `level_controller.gd` (boss hand-off)
  - `terrain_painter.gd` (`layout` export, arena painter)
  - `whip.gd`, `burn.gd` and `msm_cam.gd` (boss in the fire / shockwave / swing / film loops)
  - `reticle.gd` (boss = whip and film target)
  - `hud.gd` (boss bar, title card, boss end panel, "BOSS FIGHT!" button)
  - `title_screen.gd` (BOSS FIGHT buttons, B key, How to Play text)
  - `sfx.gd` (generated throw, splat, boss hit, wind-up, pose, defeat and fanfare sounds)
  - `debug_scenarios.gd`

### How to Play
- PC column: `B — boss`.
- New bullet: "BOSS after LEVEL 2: TRUSTIN JUDEAU, 10 hearts. Dodge poutine, WHIP him, CAM = pose. Die = retry boss."
- The How to Play screen has a BOSS FIGHT button next to BACK.

### Debug scenarios (debug builds only; `-- --scenario=NAME [--touch]` or `?scenario=NAME&touch=1`)
`boss_title`, `boss_attack` (lob + spread in the air, 6 hearts), `boss_volley` (radial burst, 2 hearts), `boss_hearts` (4 → 3 hearts via a real whip crack), `boss_pose` (cam filming him) and `boss_win` (last heart → win screen). Any `boss*` scenario jumps straight into the arena.

Screenshots: `godot --path . --rendering-driver opengl3 -s res://tools/boss_shots.gd -- out.png <seconds> --scenario=boss_attack [--touch]` (under `xvfb-run`).

### Tests
The temporary suite `tools/_test_015.gd` was deleted after the run. It passed **55/55** checks:
- levels 2/3 targets; the boss only follows level 2; phases by hearts
- the arena loads with a 10-heart bar, BOSS HUD mode and the title card
- whip `find_target` picks him; the reticle shows him as a target; whip = 1 heart and +100; i-frames block a 2nd hit; a hit lands after 0.6 s
- fire = exactly +1 heart; shockwave near-miss = 1 heart
- swing: stagger + wind-up cancel + no damage + push > 60 px; interrupt cooldown; a single shot fires
- cam: pose, no damage, pose ends + camera-shy
- poutine hit = 1 heart + gravy splat; 0.8 s mercy; spread = 3, radial = 10, lob aims at the telegraphed spot; phase-1 and rage attack sets
- defeat → untargetable → win panel, PLAY AGAIN + CONTINUE, bonus, breakdown; CONTINUE → level 3 (Karens on)
- level 2 win → "BOSS FIGHT!" → arena; death → GAME OVER → PLAY AGAIN restarts the boss with the entry score; level 1 → level 2 (no boss)
- title and How to Play BOSS buttons

The release web export was also smoke-tested in headless Chrome: title (BUILD 015, BOSS FIGHT button) → B → arena, poutine hit the idle rancher.

### Known issues / notes
- Not tested on real phones or tablets (the touch layout was checked with `--touch` screenshots only). Same 16:9 letterboxing note as 014.
- Web audio starts after the first tap or click (browser rule).
- On PC the boss bar overlaps the bottom of the Parliament sprite at the top of the screen; it's scenery only.
- Balance is first-pass. He has no contact damage; only poutine hurts.

### Web build
`web-beta-015/`, exported with the same Web preset (`--export-release`). Cache bust: `index.html` loads `index.js?v=015` and the pack as `"mainPack":"index.pck?v=015"` (with a matching `fileSizes` entry), so link it as `…/index.html?v=015`. The `.wasm` and engine JS are byte-identical to 014b (same Godot 4.7.2 templates). **LIVE** 2026-10-07 ~22:27 MT on https://savethesillyhumans.org/game.php. Live `index.pck` sha256 `97cd07e88e2410ade30b168879f29e1d2f679dd5165e7d320c37f6a5b35d22c4` (716,124 bytes).

## Build 015b: boss only after level 2, harder boss, sound and music everywhere
<a id="build-015b"></a>

**Date:** 2026-10-08 ~09:47 MT  
**Status:** **LIVE** 2026-10-08 ~10:12 MT. Replaced by build 016 at ~13:23 MT.

Everything from 015, plus the changes below. The in-game label reads `BUILD 015B`.

### 1. No menu access to the boss
- Removed the red **BOSS FIGHT** buttons from the title screen and the How to Play screen, and removed the **B** key. Players only reach Trustin Judeau by clearing **level 2**. Beating him goes to level 3, and dying retries the boss fight from its start, as in 015.
- How to Play now says: "Clear LEVEL 2 to face TRUSTIN JUDEAU (10 hearts). Dodge poutine, don't touch him. Die = retry boss."
- Debug entry only: in debug builds, **B** on the title screen and the `boss*` debug scenarios still jump straight to the arena. Both are gated by `OS.is_debug_build()` (`title_screen.gd` `start_boss()`), so release exports can't do it. Verified in the release web build: pressing B on the title does nothing.

### 2. Harder boss (Robert: "too easy")
| | 015 | 015b |
|---|---|---|
| Contact damage | none | **1 heart** when you touch him (40 px), "OUCH! PERSONAL SPACE!" (shares the 0.8 s mercy window) |
| Pause after an attack (phase 1/2/3/rage) | 1.5 / 1.3 / 1.15 / 1.0 s | **1.1 / 0.95 / 0.8 / 0.65 s** |
| Wind-up (still telegraphed: "!", aim line or ring, aim locks 0.15 s before release) | 0.5 s (rage 0.42) | **0.4 s (rage 0.32)** |
| Poutine speed: single / spread / volley / radial | 290 / 270 / 360 / 220 | **360 / 335 / 440 / 275** (+20–25 %) |
| Spread | 3-way ±20° | 3-way in phase 2, **5-way (±18°, ±36°) from phase 3** |
| Lob | 1 ring, 1.1 s flight | 1.0 s flight; **two rings from phase 3** (2nd one leads your movement, ≥ 90 px from the 1st) |
| Rage volley | 3 shots, 0.2 s apart | **5 shots, 0.17 s apart** |
| Rage radial | 10 | **ring of 14 with a 2-slot gap** (12 fly; the gap is the safe lane and is drawn on the telegraph) |
| Combos | none | after a lob: 35 % (phase 3) a quick aimed shot, 50 % (rage) a spread |
| Movement | orbits at 250 px, backs off under 120 px at 1.1× strafe speed, strafe 95 (rage 125), dash every 3–5 s | **orbits at 310 px**, backs off under 170 px at 1.5× strafe speed (still slower than you), strafe **115 (rage 145)**, **dash every 2–3 s** |
| After you hit him | nothing | **dash-strafes away** (0.12 s tell) and **throws again right away** (0.25 s). There is at most one flee every 1.6 s |
| Boss i-frames after a heart | 0.6 s | **0.9 s** |
| MSM Cam pose | up to 2.2 s, lingers 0.8 s, camera-shy 6 s | **up to 1.2 s, lingers 0.5 s, camera-shy 8 s** |
| FIRE whip bonus heart | every fire crack | **at most once per 6 s** |
| SHOCKWAVE | a near miss still cost him a heart | **the lash itself must connect**; the splash ring no longer hurts him |
| PHOTO OP | none | at **5 and 2 hearts**: 1.5 s invulnerable wave with a shimmering shield ("PHOTO OP!", "NO COMMENT!" if you whip him), then he dashes off |

Unchanged: 10 hearts; phases at 7 / 4 / 2 hearts; poutine = 1 heart, then 0.8 s mercy; swing and grab interrupts (cooldown 3 s); scoring (100 per heart, 2500 defeat, 300 per heart left, 90 s par). All values are in `scripts/level_config.gd` under "build 015 boss" (015b values are commented).

Mobile: every attack still has its wind-up, and the radial always leaves a gap. The touch WHIP auto-aims at him within reach, so the fight stays dodgeable with the joystick.

**Bot check (`--fixed-fps 60`, touch auto-aim, 12 runs per skill level, same seeds for 015 and 015b).** The bots chase into whip range and dodge any projectile whose path passes within 50 px (lob rings + 30 px). Their reaction time and the share of throws they ignore stand in for skill. They aim well and never get bored, so real fights take longer.

| bot (reaction / ignored throws / aim error) | 015: wins, win time, hearts lost | 015b: wins, win time, hearts lost |
|---|---|---|
| perfect (0 s / 0 % / 0°) | 12/12, 11.4 s, 0.2 | 12/12, 16.8 s, 0.8 |
| good (0.16 s / 10 % / 15°) | 12/12, 14.5 s, 1.2 | 11/12, 19.1 s, 1.4 |
| average (0.24 s / 22 % / 28°) | 12/12, 17.3 s, 1.8 | 9/12, 22.9 s, 3.2 |
| weak (0.32 s / 35 % / 40°) | 9/12, 21.8 s, 3.5 | 3/12, 29.0 s, 4.5 |

Result: harder (he throws 2–3× as often, and average and weak players now lose a fair share), but still beatable, and retries are free.

### 3. Sound and music (Robert: "why do we not have audio for the entire game?")
**Root cause:** the game barely had any sound to play. Before 015b the only sounds anywhere were the MSM Cam battery-swap beep (014) and the boss-fight sounds (015). The whip, grabs, saves, explosions, damage, pickups, UI, win and lose had **no sounds wired at all**, and there was **no music**. So levels 1–2 and 3+ were silent by design, not by a broken engine. The web audio path itself worked: in headless Chrome the 015 build's AudioContext was running and the boss sounds reached the output. There was also no explicit mobile unlock beyond Godot's own, and no mute control.

While fixing it we hit a second trap and fixed it: **audio buses created at runtime (`AudioServer.add_bus()`) are silent in the Godot web export.** Samples played and the music source carried signal, but nothing reached the speakers (measured with an analyser on the AudioContext destination). The buses now come from `default_bus_layout.tres`, which the engine loads at start-up, and the web build is audible.

**What 015b adds**
- **SFX everywhere** (all generated in code, `scripts/sfx.gd`):
  - whip crack (and a fire crack), shockwave, whip shot, grab, throw
  - human saved, possessed human saved, human turned possessed, explosion
  - rancher hurt, Karen, pickup, viral, cam REC start / stop / tick, cam swing, no battery, weapon swap
  - UI click and start, win and lose stingers
  - all the boss sounds: throw, splat, hit, wind-up, pose, shield, contact, defeat, fanfare
  - Per-sound limits (35 ms minimum interval, 4 voices) keep busy scenes from clipping.
- **Music:** two original looping chiptune tracks generated by `tools/gen_music.py` (numpy, MIT; pulse lead, 12.5 % pulse arpeggio, triangle bass, noise drums; 22.05 kHz 8-bit PCM, exact bar lengths so the loops are seamless):
  - `music_level.wav`, "Ranch Hand Hustle" (C major, 132 BPM, 29 s): plays in the levels
  - `music_boss.wav`, "Question Period" (D minor, 156 BPM, 25 s): plays in the boss fight, tenser
  - The title screen is quiet, and the music stops on the win/lose panel.
- **Buses:** Master ← Music (−7 dB) + SFX.
- **Sound toggle:** **M** on PC; on touch, a **speaker icon** on the title screen and next to the swap wedge in the HUD. It cycles **SOUND ON → SOUND LOW → SOUND OFF** with a short toast, and the setting is saved in `user://audio.cfg`. Autoload: `scripts/audio/game_audio.gd` (`GameAudio`); icon: `scripts/ui/sound_icon.gd`.
- **Web unlock** (`export_presets.cfg` → `html/head_include`): Godot already resumes the AudioContext on its own input events. The extra script also resumes it on `touchstart` / `touchend` / `pointerdown` / `pointerup` / `mousedown` / `keydown` / `click`, plays a 1-sample silent buffer (the iOS Safari wake-up), sets `navigator.audioSession.type = 'playback'` (iOS 17+: the ring/silent switch no longer mutes the game, like a video), and resumes again when the tab comes back.
- Audio imports are PCM with forward loop for the music (no QOA), for safe web sample playback.

**Verified in the release web build** (`web-beta-015b`, headless Chrome, analyser tapped on the AudioContext destination):
- After a click and ENTER, the context is running, the music buffer is created and plays, and whip cracks add new buffer sources.
- Output level: ON ≈ 0.23 RMS, LOW ≈ 0.09, OFF = 0, back ON. Same result with an emulated Android phone, tapping START and then the speaker icon.
- Not tested on a real iPhone or Android device.

### 4. Files
- New:
  - `scripts/audio/game_audio.gd`
  - `scripts/ui/sound_icon.gd`
  - `default_bus_layout.tres`
  - `assets/audio/music_level.wav`, `assets/audio/music_boss.wav`
  - `tools/gen_music.py`
- Changed:
  - `scripts/boss/judeau.gd`: PHOTO_OP state, flee and counter-throw, 5-way spread, double lob, combos, gapped radial, fire cooldown, telegraphs
  - `scripts/boss/boss_level.gd`: contact damage, boss music
  - `scripts/level_config.gd`
  - `scripts/player/whip.gd`: shockwave no longer splashes the boss, plus sounds
  - `scripts/sfx.gd`
  - `scripts/ui/title_screen.gd`, `scripts/ui/hud.gd`, `scripts/ui/touch_controls.gd`
  - `scripts/player/player.gd`, `scripts/player/msm_cam.gd`, `scripts/player/weapons.gd`, `scripts/level_controller.gd`: sounds
  - `scripts/debug_scenarios.gd`: new `boss_rage` scenario
  - `tools/boss_shots.gd`: new `title` scenario
  - `project.godot`: GameAudio autoload
  - `export_presets.cfg`: audio unlock

### Tests
The temporary suite `tools/_test_015b.gd` (deleted after the run) passed **49/49** checks:
- **Title and How to Play:** no boss button or BOSS FIGHT text; the new rules line is present; the B key and `start_boss()` are debug-only; the speaker icon shows.
- **Flow:** the boss only follows level 2; a boss win goes to level 3; retry restarts the boss with 10 hearts.
- **Boss rules:**
  - whip = 1 heart; 0.9 s i-frames
  - flee queued after a hit (none inside the 1.6 s window)
  - fire once per 6 s; the shockwave splash skips the boss
  - contact = 1 heart
  - cam pose ends by 1.2 s, then 8 s camera-shy; swing still staggers
  - photo op at 5 and 2 hearts blocks whips and ends after 1.5 s
- **Attack shapes:** 3-way spread in phase 2 and 5-way in phase 3; radial = 12 of 14; volley 5; double lob in phase 3 with rings ≥ 90 px apart, even in a corner; combos ≈ 25 %.
- **Audio:**
  - level / boss / title music
  - crack, throw, hit, contact and hurt sounds fire
  - SFX and Music buses exist
  - ON / LOW / OFF set the Master bus

Also: `tools/verify_layout.gd` PASS. Main, Title and BossArena run 25 s headless with no script errors. The bot runs are above.

Screenshots (attached to the source-zip folder, not in the repo): `stsh-build015b-title.png` (no BOSS button, speaker icon), `stsh-build015b-rage.png` (gapped radial ring and double lob), `stsh-build015b-rage-touch.png`, `stsh-build015b-howto.png`, `stsh-build015b-web-sound.png` (release web build, "SOUND LOW (M)" toast).

### Known issues / notes
- Not implemented: Karens / possessed joining in rage. They'd need their own lose-condition rules in the arena; the fight is hard enough without them.
- Audio is untested on real phones. On iOS older than 17 the silent switch still mutes web audio, as it does on every web game.
- The `.pck` grew from 0.7 MB to 1.9 MB (two PCM music loops). The `.wasm` and engine JS are byte-identical to 015.

### Web build
`web-beta-015b/`, exported with the same Web preset (`--export-release`). Cache bust: `index.js?v=015b` and `"mainPack":"index.pck?v=015b"` (with a matching `fileSizes` entry), so link it as `…/index.html?v=015b`. `index.pck` is 1,920,872 bytes. **LIVE** 2026-10-08 ~10:12 MT on https://savethesillyhumans.org/game.php; only `index.pck` and `index.html` changed (the engine `.js`/`.wasm` and audio worklets are byte-identical to 015). Live `index.pck` sha256 `e0b692603a29177d869b8908c63fee36bb044659b23e353b8eb674bf58946b2d`.

## Build 016: Galaga-style BONUS STAGE, boss 2 HUVAL YARHEYHEY
<a id="build-016"></a>

**Date:** 2026-10-08 ~13:05 MT  
**Status:** **LIVE** 2026-10-08 ~13:23 MT. Replaced by build 017 at ~16:43 MT.

Everything from 015b, plus the changes below. The in-game label reads `BUILD 016`.

### 1. Progression order
Every between-level stage comes from `LevelConfig` (`scripts/level_config.gd`, "build 016 progression"). `GameProgress` builds a small stage queue when a level is cleared. After level **L** it plays:
1. the **BONUS STAGE** if `L == BONUS_FIRST_AFTER + k * BONUS_EVERY` (1, 4, 7, 10, …);
2. the **boss** whose `*_AFTER_LEVEL` is L (`BOSS_AFTER_LEVEL = 2` Trustin Judeau, `BOSS2_AFTER_LEVEL = 5` Huval Yarheyhey; one config value each);
3. then level L + 1.

If a bonus slot and a boss ever coincide, the order is **level → bonus → boss → next level** (covered by tests with both bosses moved onto a bonus slot).

With the defaults:

`L1 > BONUS 1 > L2 > TRUSTIN > L3 > L4 > BONUS 2 > L5 > HUVAL > L6 > L7 > BONUS 3 > L8 > L9 > L10 > BONUS 4 > L11 > L12 > L13 > BONUS 5 > …`

The level-clear button says what's next (`BONUS STAGE!` / `BOSS FIGHT! NEXT: HUVAL`). The score carries through every stage. Dying in a boss fight shows GAME OVER and PLAY AGAIN retries the boss with the score you entered it with. You can't die in a bonus stage.

### 2. Bonus stage (`scenes/levels/BonusStage.tscn`, `scripts/bonus/*`)
A sheep-ified Galaga "challenging stage" on an open walled meadow, with its own chiptune (`assets/audio/music_bonus.wav`).
- **Title card** "BONUS STAGE / POP THE FLYING SHEEP!" (2 s), then a **45 s countdown**. The HUD bar shows `BONUS n  0:45  HITS x/total` (top right on PC, top centre on touch).
- **8 waves**, one every 5 s, of 5–8 winged sheep that fly scripted Galaga patterns (swoop, loop, zig-zag, S-curve, figure-eight, orbit, dive, cross, mirrored and paired variants) in a line, then leave. **A sheep that leaves the field is a miss.** All waves are gone before 0:45 (worst case 43.3 s); the stage ends at 0:00 or when the last wave has left.
- **Any hit pops a sheep**: whip crack, whip shot, shockwave splash, fire, cam swing, a thrown body. Wool-burst effect + "+100".
- **The rancher can't be hurt** and can't die here.
- **Power-up policy:** your loadout comes along and works (fire, shockwave, shot, cam), but **nothing is used up**: the inventory you arrive with is restored when you leave. **Nothing drops** in the bonus stage.
- **Scoring:** 100 per hit, **PERFECT! +500** for a whole wave popped (callout on screen), **PERFECT! SPECIAL BONUS 10000** for every sheep of the stage.
- **Tally** (CONTINUE only): `NUMBER OF HITS: n`, `BONUS n×100`, and `PERFECT! SPECIAL BONUS 10000 PTS` when perfect, plus a breakdown (hits, wave perfects, special bonus, stage total, score, hi-score).

| Bonus stage | After level | Sheep | Wave sizes | Speed wave 1 → wave 8 (px/s) |
|---|---|---|---|---|
| 1 | 1 | 50 | 5 5 6 6 6 7 7 8 | 340 → 447 |
| 2 | 4 | 57 | 6 6 7 7 7 8 8 8 | 381 → 501 |
| 3 | 7 | 62 | 7 7 8 8 8 8 8 8 | 422 → 554 |
| 4+ | 10, 13, … | 64 | 8 × 8 | 462 → 578 (cap ×1.7) |

Each later wave is 4.5 % faster; each recurrence adds +1 sheep per wave (cap 8) and is 12 % faster (cap ×1.7). The rancher runs 260 px/s. Tunables: `BONUS_*` in `level_config.gd`.

### 3. Boss 2: HUVAL YARHEYHEY, PROPHET OF THE ALGORITHM
An invented, good-natured cartoon caricature of a generic futurist lecturer: shiny bald dome, round glasses, smug half-smile, dark sweater, headset mic, presentation clicker and a tablet of DATA. Generated original pixel art (`tools/gen_boss2.py` → `assets/boss2/`), no real likeness. Arena: **DATA PLAZA** (`scenes/levels/Boss2Arena.tscn`), a paved grid of paths with a glass lecture hall, with its own synth track (`assets/audio/music_boss2.wav`).

Title card: **BOSS BATTLE! / HUVAL YARHEYHEY / PROPHET OF THE ALGORITHM** with portrait. **12 hearts**. Same hit rules as Trustin:
- whip crack / whip shot / a lash that connects with SHOCKWAVE = 1 heart (0.9 s i-frames)
- FIRE = +1 delayed heart, at most once per 6 s
- GRAB / CAM SWING = shove + stagger (can cancel a wind-up)
- **MSM CAM REC → he LECTURES to the camera** (stops, cancels a wind-up) for up to 1.4 s, then is camera-shy for 8 s
- **touching him = 1 heart**

**Weapon: PROGRAMMED SHEEP** (`scripts/boss/robo_sheep.gd`). Every summon is telegraphed: he raises the clicker ("!" + red LED beam) and a glitchy cyan **spawn ring** shows wherever a sheep will appear (never closer than 170 px to you) for 0.65–0.85 s. Programmed sheep (steel wool, circuit traces, antenna) hunt you with a limited turn rate, so you can outrun and out-turn them.
- **Programmed sheep touch = 1 heart**, then it bounces back and stalls 0.8 s.
- **Any hit splits it into 3 MICRO SHEEP** (+50). Grab and throw one: it splits where it lands, and if it hits Huval he loses a heart ("FEEDBACK LOOP!").
- **Micro sheep** (small, neon magenta, fast) **do HALF a heart**: every 2nd micro touch costs 1 heart; a pending half shows as a half-empty heart in the HUD. Micro mercy window 0.45 s. Any hit pops one (+25). They **expire after 7 s** (blink first), and at most **12** are alive.

| Phase (hearts left) | Attack gap | Summon tell | Sheep per summon | Programmed cap | Programmed speed | Attacks |
|---|---|---|---|---|---|---|
| 1 (12–9) | 1.6 s | 0.85 s | 1 | 4 | 115 | summon |
| 2 (8–6) | 1.35 s | 0.80 s | 2 | 5 | 130 | summon 60 / LECTURE RAY 40 |
| 3 (5–3) | 1.15 s | 0.75 s | 2 | 6 | 145 | summon 45 / ray 35 / SYSTEM UPDATE 20 |
| rage (2–1) | 0.95 s | 0.65 s | 3 | 6 | 160 | same + TELEPORT after hits and every 3.5–5 s |

- **LECTURE RAY:** an aim line tracks you for 0.6–0.75 s, locks 0.25 s, then fires for 0.3 s (1 heart). A sidestep dodges it.
- **SYSTEM UPDATE:** every programmed and micro sheep on the field gets ×1.25 faster (stacks to ×1.6). At **6 and 3 hearts** he force-installs one ("UPDATING…", 1.5 s invulnerable, then flees).
- **TELEPORT (rage):** glitches out; rings show the destination 0.4 s before he pops in there, at least 260 px from you.
- Movement 105 px/s (135 in rage); keeps ~300 px away and backs off when you close in.
- Robo sheep turn rate 2.2 rad/s; micro 190 px/s, 3.4 rad/s. Tunables: `BOSS2_*`, `ROBO_*`, `MICRO_*`, `SYSTEM_UPDATE_*` in `level_config.gd`.

**Win screen** (PLAY AGAIN / CONTINUE → level 6): hearts ×100, programmed ×50, micro ×25, defeat bonus 4000, health ×300 per heart left, time bonus (20 per second under a 120 s par), level total, score, hi-score.

### 4. Balance (bots, headless, 60 fps fixed)
**Bonus stage**, 8 runs per row. Hit rate / wave PERFECTs per run (no bot got a whole-stage PERFECT; it is meant to be rare):

| Skill | Bonus 1 | Bonus 2 | Bonus 3 |
|---|---|---|---|
| perfect | 96.0 % / 7.0 | 89.5 % / 5.0 | 91.9 % / 6.0 |
| good | 91.2 % / 5.6 | 84.2 % / 3.5 | 82.1 % / 3.1 |
| average | 77.8 % / 2.1 | 69.7 % / 1.2 | 66.5 % / 0.5 |
| weak | 56.0 % / 0.2 | 51.5 % / 0.2 | 46.8 % / 0.0 |

**Huval vs Trustin (015b)**, 24 runs per row (seeds 77 + 91). Wins / average win time:

| Skill | Trustin Judeau | Huval Yarheyhey |
|---|---|---|
| perfect | 24/24, 17.1 s | 24/24, 19.4 s |
| good | 24/24, 19.1 s | 24/24, 32.1 s |
| average | 20/24, ~24 s | 15/24, ~44 s |
| weak | 5/24 | 5/24 |

Huval is the longer, harder fight (average players win ~62 % vs ~83 %, good players take ~70 % longer and lose more hearts), but beatable at every skill level. Hits taken by the average bot over 24 runs: programmed-sheep bites 53, ray 23, micro touches 22 (half a heart each), contact 0. A first pass with faster programmed sheep (120–165 px/s, turn 2.4) left the weak bot at 0/12; they were eased to 115–160 px/s, turn 2.2.

### 5. Debug-only entries (`OS.is_debug_build()`)
Release builds have no menu, key or button to reach a boss or a bonus stage.
- Title keys: **B** Trustin, **V** Huval, **G** bonus stage 1.
- `GameProgress.start_at_stage(stage, level)` / `debug_scenario` (via `tools/boss_shots.gd`): `bonus`, `bonus2`, `bonus3`, `bonus_waves` (auto-whips for screenshots), `bonus_tally` (perfect stage), `huval_title`, `huval_fight`, `huval_ray`, `huval_update`, `huval_lecture`, `huval_win`, plus the 015b `boss_*` scenarios.

### 6. Files
- New:
  - `scripts/bonus/bonus_level.gd`, `bonus_waves.gd`, `bonus_sheep.gd`; `scripts/world/wool_burst.gd`
  - `scripts/boss/huval.gd`, `huval_level.gd`, `robo_sheep.gd`
  - `scenes/levels/BonusStage.tscn`, `scenes/levels/Boss2Arena.tscn`
  - `assets/boss2/huval_96.png`, `robo_sheep_32.png`, `micro_sheep_32.png`, `data_plaza.png`; `tools/gen_boss2.py`
  - `assets/audio/music_bonus.wav`, `music_boss2.wav` (generated by `tools/gen_music.py`)
- Changed:
  - `scripts/level_config.gd`: progression, bonus and boss 2 constants
  - `scripts/game_progress.gd`, `scripts/game_progress_check.gd`: stage queue
  - `scripts/level_controller.gd`: next-stage button text and routing
  - `scripts/boss/boss_level.gd`: generalized (hooks for boss 2)
  - `scripts/ui/hud.gd`: bonus bar, tally, half-heart, boss title art, generic breakdown
  - `scripts/ui/title_screen.gd`: BUILD 016, V/G debug keys, How to Play lines
  - `scripts/world/terrain_painter.gd`: data plaza and bonus field styles
  - `scripts/audio/game_audio.gd`, `scripts/sfx.gd`: 2 tracks, 9 new sounds
  - `scripts/debug_scenarios.gd`, `tools/boss_shots.gd`: stage scenarios

### Tests
The temporary suite `tools/_test_016.gd` (deleted after the run) passed **95/95** checks:
- **Progression:** order L1…L13 and recurrence 1, 4, 7, 10, …; bonus index; coinciding slots play level > bonus > boss (both bosses); Huval after level 5 from a single value; each CONTINUE goes to the right next scene; debug `start_at_stage` for both bosses and bonus 3; level-clear button text.
- **Bonus:** 50 / 57 sheep, wave sizes and speeds per repeat with caps; wave 1 only after the title card; wave PERFECT +500; 100 per hit; escaped sheep are misses; no damage to the rancher; ends at 0:00; special bonus only when perfect; tally text and CONTINUE; inventory restored; all waves gone before 45 s.
- **Huval:** 12 hearts, title text, music; summon ring ≥ 170 px and no sheep before the tell; split into 3 micros; first micro nibble = half heart, second = 1 heart; programmed bite = 1 heart; cam swing pops micros; SYSTEM UPDATE ×1.25; whip = 1 heart with i-frames; fire once per 6 s; shockwave splash skips him; cam lecture + camera-shy; forced update at 6 hearts is invulnerable; ray hits on its line, misses an 80 px sidestep; rage teleport away from you; win breakdown + CONTINUE → level 6; death → GAME OVER, retry restarts Huval with the entry score.
- **Title:** BUILD 016, no boss/bonus buttons, V/G keys and `start_stage` debug-only, How to Play mentions both; all new sounds exist.

Also: `tools/verify_layout.gd` PASS; Main, Title, BonusStage, BossArena and Boss2Arena run headless with no script errors. The 015b suite still passes except two checks that test 015b-only text (old How to Play line; `start_boss` now delegates to `start_stage`).

Screenshots: `stsh-build016-01-bonus-title.png`, `-02-bonus-waves.png`, `-03-bonus-tally-perfect.png`, `-04-huval-title.png`, `-05-huval-fight.png`, `-06-mobile-huval.png`, `-07-mobile-bonus.png`, `-08-huval-ray.png`, `-09-huval-update.png`, `-10-huval-lecture.png`, `-11-huval-win.png`, `-12-howto.png`.

### Known issues / notes
- No bot reached a whole-stage PERFECT (best: 50/50 needs every sheep, including the fast last waves); a human with a fire or shot whip can. It's a rare reward by design.
- The weak bot wins Huval as often as Trustin (5/24); he's harder mostly for average and good players.
- The clicker LED beam in the summon tell is drawn from an approximate hand position.
- Not tested on real phones.

### Web build
`web-beta-016/`, exported with the same Web preset (`--export-release`). Cache bust: `index.js?v=016` and `"mainPack":"index.pck?v=016"` (with a matching `fileSizes` entry), so link it as `…/index.html?v=016`. `index.pck` is 3,098,768 bytes (two more PCM music loops). **LIVE** 2026-10-08 ~13:23 MT on https://savethesillyhumans.org/game.php; only `index.pck` and `index.html` changed (the engine `.js`/`.wasm`, audio worklets and icons are byte-identical to 015b). Live `index.pck` sha256 `baa9e6a24f8ee55940926a7031960c762915e9a6f6f54faf2daa06a20cf08d33`. Verified live in headless Chrome: BUILD 016 on the title, B/V/G do nothing, level music plays (peak ≈ 0.23 RMS), no console errors. Before release, the bonus and Huval tracks were checked in a debug web export (≈ 0.17 / 0.18 RMS).

## Build 017: CANTIFA
<a id="build-017"></a>

**Date:** 2026-10-08 ~16:34 MT  
**Status:** **LIVE** 2026-10-08 ~16:43 MT. Current build.

Everything from 016, plus the changes below. The in-game label reads `BUILD 017`.

Cartoon black-bloc mob (original art, `tools/gen_cantifa.py`): black hoodie, two eye-holes, red bandana, a little two-colour flag and a blocky rifle. No real likeness. They are **not** Karens and **not** saveable humans.

### When
Level 4 and on. Level 4 is the first level after Trustin Judeau (L1 → bonus → L2 → Trustin → L3 → **L4**). They do not appear in the bonus stage or in a boss arena.

### Spawn
1 in 5 human spawn rolls (the 5 humans placed at the start, and every camp arrival) is a Cantifa instead. They walk in from off the map edge. A roll stays a real human when the on-screen cap is full, or when replacing one more human would drop the best-case saves below the level target. That slot is not a death and not someone you can save.

| Level | On-screen cap |
|---|---|
| 1–3 | 0 |
| 4–5 | 3 |
| 6–7 | 4 |
| 8–9 | 5 |
| 10+ | 6 |

### Posts and rifle
They drift to a free post just outside the safe zone (158 px from the centre; the ring is drawn at 95) or just outside the camp (230 px). They face inward and do not enter either zone (keep-out 120 / 200). Whip one and the others within 260 px scatter for 0.85 s, then re-post.

They only shoot the rancher, only while posted (or while being filmed), and only inside a 70° cone. Range starts at 315 px (1.5× the whip) and grows 12 px per level, cap 420. Wind-up 0.25 s, then a straight tracer at 460 px/s. Spread ±14° at level 4, 0.6° tighter each level, never under ±8°. Cooldown 0.7–0.9 s. A hit costs 1 heart and shares the boss mercy window (0.8 s). Humans, sheep and other Cantifa are ignored.

### Whip, fire, grab
Not saveable. **2 whip hits** (a shockwave or whip-shot counts) or **1 fire hit** drives them off the map for **75 points**. A grab throws them like any other target; landing in the safe zone does not rescue them. A cam swing only shoves them.

### Cam
Filming a Cantifa does not convince them; they turn and may shoot back. Silly humans in the cone stampede to the safe zone (the existing VIRAL run). Every Karen becomes angrier than the normal camera buff: ×1.75 speed (camera-love is ×1.35) and a wider zig-zag for 2.5 s, refreshing while the filming continues.

### Power-up drops
The chance that a kill drops anything is ×1.75. The type weights are unchanged, so the cam and batteries stay rare.

| Source | Was | Now |
|---|---|---|
| Sheep | 0.12 | 0.21 |
| Possessed | 0.22 | 0.385 |
| Karen | 0.40 | 0.70 |

Weights: health 30, fire 16, long 14, shock 14, shot 14, strong 12, cam 8, battery 5.

### HUD and debug
A CANTIFA counter from level 4. How to Play has one new line. Debug builds only: **C** on the title starts level 4. Scenarios `cantifa_post`, `cantifa_shoot`, `cantifa_film`. Release builds have no key and no button.

### Tests
Temporary suite `tools/_test_017.gd` (deleted after the run) passed **36/36**: no Cantifa before level 4, about 1 in 5 (99/500), entry from the map edge, posts held outside both zones, the cap, the save-target safety, bullets hit only the rancher and the mercy window blocks the next, two whips or one fire drives them off and neighbours scatter, filming stampedes humans and enrages Karens.

Survivability bot, 25 s, 6 runs, seed 77 (the rifle numbers were left as designed):

| | Level 4 | Level 6 |
|---|---|---|
| average | 0/6 down, 7 hearts lost in total | 1/6 down, 7 hearts |
| weak | 0/6 down, 4 hearts | 0/6 down, 4 hearts |

Screenshots: `stsh-build017-01-posted.png`, `-02-shooting.png`, `-03-filmed.png`, `-04-howto.png`, `-05-mobile.png`.

### Web build
`web-beta-017/`, exported with the same Web preset (`--export-release`). Cache bust: `index.js?v=017` and `"mainPack":"index.pck?v=017"` (with a matching `fileSizes` entry), so link it as `…/index.html?v=017`. `index.pck` is 3,124,340 bytes. **LIVE** 2026-10-08 ~16:43 MT on https://savethesillyhumans.org/game.php; only `index.pck` and `index.html` changed (the engine `.js`/`.wasm`, audio worklets and icons are byte-identical to 016). Live `index.pck` sha256 `{sha}`. Verified live in headless Chrome: BUILD 017 on the title, B/V/G/C do nothing, level music plays (peak ≈ 0.23 RMS), no console errors.

## Appendix: project reference notes

These general notes (requirements, controls, gameplay loop, layout, collision layers, TileSet workflow) headed the project README during development. They are kept as they stood at build 014b.

Zelda-style 2D action-herding prototype in **Godot 4.7.2**.

You are a slightly questionable rancher. Silly humans wander on their own,
flee nearby sheep, and steer clear of the green safe zone. Killer sheep
**roam** until something enters their interest/attention ranges, then hunt.
**Whip-herd** humans into the safe zone and crack sheep (and possessed
humans) into explosions. Sheep bites chip human HP — five hits convert a
silly human into a purple **possessed** hunter.

### Requirements

- Godot **4.7.2** (project feature tag `4.7`)
- Open the project folder `stsh-game` in the Godot Project Manager

Main scene: `scenes/Main.tscn` (thin shell that instances `scenes/levels/Level01.tscn`).

### Controls

| Input | Action |
|-------|--------|
| WASD | Move (isometric Y compression) |
| Mouse | Aim (build 014b: in-game reticle replaces the pointer during play) |
| LMB | Crack whip — shove silly humans / explode sheep & possessed |
| RMB | Grab & throw — fling target **180° opposite aim** |
| R | Restart after win or lose |
| Q / wheel / 1-2 | Swap weapon (build 014: with the MSM Cam, LMB = hold REC, RMB = SWING) |

Touch layout and dual-mode weapons: see **Build 014** below. Aim reticle / touch crosshair: see **Build 014b**.

### Gameplay loop

1. **Herd** silly humans into the **green safe zone** with the whip — they will not walk in on purpose (and they never chase you).
2. **LMB** crack: shove silly humans along the aim ray; explode sheep & possessed. The lash is a multi-segment arc that extends to the aim point, with a tip spark and a short afterimage.
3. **RMB** grab/throw: latch a whippable along aim and fling them **opposite** the aim direction (`throw_force` ~800). Teal grab plays a coil wind-up, an extending lash, then a follow-through opposite aim (gameplay still resolves on the click).
4. Sheep deal **1 damage** per bite. Humans have **5 HP**. At 0 HP they **convert in place** into possessed hunters (purple tint) — not deleted.
5. Possessed hunt like killer sheep. **LMB** explodes them. **Throw them into the green zone** to **save** them (rescue credit, no death) — they will not casually walk in.
6. Thrown sheep that pass within ~40px of another living sheep → **both explode**. Possessed–sheep / possessed–possessed mutual destroy while thrown is also supported.
7. Win / lose uses rescue + possession accounting (see Build 004 / grab-throw).

#### AI distances (tile = 32px)

| Actor | Behavior | Default |
|-------|----------|---------|
| Silly humans | Flee sheep | `flee_range` **160** (5 tiles) |
| Silly humans | Avoid safe zone (too dumb to enter on purpose) | `avoid_safe_range` **288** (9 tiles) |
| Silly humans | Wander (silly pauses) | after flee/avoid — **no rancher follow** |
| Killer sheep / possessed | Roam by default | `roam_speed` 60 |
| Killer sheep / possessed | Soft interest (slow approach) | `interest_range` **256** (8 tiles) |
| Killer sheep / possessed | Full chase / attack | `attention_range` **160** (5 tiles) |

Priority for silly humans: flee sheep → avoid safe zone → wander. Whip `external_velocity` still shoves them into the zone.

Sheep prefer normal `humans` over the player. Possessed are not in `humans` (not rescue targets) and hunt player / silly humans.

HUD shows rescued X/Y, living humans, living sheep, converted/possessed, and player HP. Damaged (infected) humans get a pulsing red/magenta feet ring; off-screen ones get an edge chevron (`InfectionAlarm`). At level start you should see **0/5** rescued — never an instant win.

### Project layout

```
assets/
  characters/          pixel sheets (rancher, human, sheep)
  fx/                  whip crack + explosion
  spriteframes/        AnimatedSprite2D definitions
  tiles/               terrain atlas + TileSet
scenes/
  Main.tscn            entry shell → Level01
  levels/Level01.tscn  TileMapLayer + entities + HUD
  player/ Player.tscn
  humans/ Human.tscn
  sheep/  Sheep.tscn
  world/  SafeZone.tscn
  ui/     HUD.tscn
scripts/
  level_controller.gd  win/lose, GameState, HUD wiring
  game_state.gd
  player/  player.gd, whip.gd
  humans/  human.gd
  sheep/   sheep.gd
  world/   safe_zone.gd, terrain_painter.gd, sheep_spawner.gd
  ui/      hud.gd, infection_alarm.gd
```

### Collision layers

| Layer | Name | Used by |
|-------|------|---------|
| 1 | World | Tile walls/rocks |
| 2 | Player | Player body |
| 3 | Humans | Silly humans |
| 4 | Sheep | Killer sheep |
| 5 | SafeZone | Rescue Area2D |

Characters mask the World layer so they collide with painted wall/rock tiles.

Groups: `player`, `humans`, `sheep`, `possessed`, `whippable`, `safe_zones`, `level_controller`.

### TileSet / editable maps

Terrain tiles live in:

- `assets/tiles/stsh_terrain_atlas.png` — 32×32 tiles in a row: **grass, dirt, path, rock, wall, tree, bush, decor rock**
- `assets/tiles/stsh_terrain_tileset.tres` — TileSet with physics on **rock** and **wall** only (World layer); tree/bush/decor rock have no collision

`Level01` is a larger open ranch (~72×48 tiles) with walls only on the outer border.
It uses `Ground` plus a non-colliding `Decor` TileMapLayer (trees/bushes/scenic rocks).
On first run, `scripts/world/terrain_painter.gd` paints both if `Ground` is empty.
**Spawns are tile-anchored inside the wall ring** (local slots → `map_to_local`); scene positions are overwritten at runtime.

#### Paint a new level in the editor

1. Duplicate `scenes/levels/Level01.tscn` → e.g. `Level02.tscn`.
2. Open the copy. Select the `Ground` TileMapLayer.
3. Optional: set `paint_on_ready = false` on the terrain painter (Inspector), or remove that script once your painted cells are saved — otherwise an empty layer will be auto-filled again.
4. Paint with the TileSet (`grass` / `dirt` / `path` walkable; `rock` / `wall` block movement).
5. Move `Entities/Player`, `Entities/Humans/*`, `Entities/Sheep/*`, and `Entities/SafeZone` markers/instances.
6. Point `scenes/Main.tscn` at your new level (change the instanced scene), or set **Project → Project Settings → Application → Run → Main Scene** to your level scene.

#### Create a level from scratch

1. New scene → root `Node2D` with `scripts/level_controller.gd`.
2. Add `TileMapLayer`, assign `assets/tiles/stsh_terrain_tileset.tres`, paint tiles.
3. Instance Player, Humans, Sheep, SafeZone under an `Entities` node.
4. Instance `scenes/ui/HUD.tscn` as a child of the root.
5. Save under `scenes/levels/` and set it as the main scene (or instance it from `Main.tscn`).

### Notes

- **False-win fix (build 002):** SafeZone stays `monitoring=false` until tile placement finishes; humans spawn in map corners (≥12 tiles Chebyshev from the safe zone); `GameState.setup_complete` gates win/lose. Instant “all rescued” at t=0 is fixed — herding via whip is required.
- Humans **avoid** the green zone on purpose (“too dumb to enter”); whip shove is the intended rescue path.
- **16-bit art pass:** character sheets, terrain atlas, and FX refreshed toward a classic SNES/Genesis ranch look (clearer silhouettes, limited palettes, dither/shade). Frame layouts stay 32×32 so existing `.tres` spriteframes/tileset keep working.
- Level01 is a larger open ranch with decor tiles; collision walls only on the border.
- Pixel art uses nearest-neighbor filtering (project default).
- Whip targeting is forgiving along the aim ray, not only near the cursor.
- Sheep AI: `attention_range` **160** (5 tiles) for chase/attack; `interest_range` **256** (8 tiles) for soft approach; prefer humans over player in attention range.
- No multiplayer.
