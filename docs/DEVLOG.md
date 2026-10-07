# Save The Silly Humans — Development Log

> Build-by-build development notes, kept as-is for reference. "Not deployed" / "stays live" lines
> describe the status at the time each build was made; **build 014b is the current live build**.
> `web-beta-*/` export folders and the temporary `tools/_test_*.gd` / `_logic*.gd` suites mentioned below
> are not included in this repository. For the public overview see the [README](../README.md).

---

# Save the Silly Humans

Zelda-style 2D action-herding prototype in **Godot 4.7.2**.

You are a slightly questionable rancher. Silly humans wander on their own,
flee nearby sheep, and steer clear of the green safe zone. Killer sheep
**roam** until something enters their interest/attention ranges, then hunt.
**Whip-herd** humans into the safe zone and crack sheep (and possessed
humans) into explosions. Sheep bites chip human HP — five hits convert a
silly human into a purple **possessed** hunter.

## Requirements

- Godot **4.7.2** (project feature tag `4.7`)
- Open the project folder in the Godot Project Manager

Main scene: `scenes/Main.tscn` (thin shell that instances `scenes/levels/Level01.tscn`).

## Controls

| Input | Action |
|-------|--------|
| WASD | Move (isometric Y compression) |
| Mouse | Aim (build 014b: in-game reticle replaces the pointer during play) |
| LMB | Crack whip — shove silly humans / explode sheep & possessed |
| RMB | Grab & throw — fling target **180° opposite aim** |
| R | Restart after win or lose |
| Q / wheel / 1-2 | Swap weapon (build 014: with the MSM Cam, LMB = hold REC, RMB = SWING) |

Touch layout and dual-mode weapons: see **Build 014** below. Aim reticle / touch crosshair: see **Build 014b**.

## Gameplay loop

1. **Herd** silly humans into the **green safe zone** with the whip — they will not walk in on purpose (and they never chase you).
2. **LMB** crack: shove silly humans along the aim ray; explode sheep & possessed. The lash is a multi-segment arc that extends to the aim point, with a tip spark and a short afterimage.
3. **RMB** grab/throw: latch a whippable along aim and fling them **opposite** the aim direction (`throw_force` ~800). Teal grab plays a coil wind-up, an extending lash, then a follow-through opposite aim (gameplay still resolves on the click).
4. Sheep deal **1 damage** per bite. Humans have **5 HP**. At 0 HP they **convert in place** into possessed hunters (purple tint) — not deleted.
5. Possessed hunt like killer sheep. **LMB** explodes them. **Throw them into the green zone** to **save** them (rescue credit, no death) — they will not casually walk in.
6. Thrown sheep that pass within ~40px of another living sheep → **both explode**. Possessed–sheep / possessed–possessed mutual destroy while thrown is also supported.
7. Win / lose uses rescue + possession accounting (see Build 004 / grab-throw).

### AI distances (tile = 32px)

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

## Project layout

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

## Collision layers

| Layer | Name | Used by |
|-------|------|---------|
| 1 | World | Tile walls/rocks |
| 2 | Player | Player body |
| 3 | Humans | Silly humans |
| 4 | Sheep | Killer sheep |
| 5 | SafeZone | Rescue Area2D |

Characters mask the World layer so they collide with painted wall/rock tiles.

Groups: `player`, `humans`, `sheep`, `possessed`, `whippable`, `safe_zones`, `level_controller`.

## TileSet / editable maps

Terrain tiles live in:

- `assets/tiles/stsh_terrain_atlas.png` — 32×32 tiles in a row: **grass, dirt, path, rock, wall, tree, bush, decor rock**
- `assets/tiles/stsh_terrain_tileset.tres` — TileSet with physics on **rock** and **wall** only (World layer); tree/bush/decor rock have no collision

`Level01` is a larger open ranch (~72×48 tiles) with walls only on the outer border.
It uses `Ground` plus a non-colliding `Decor` TileMapLayer (trees/bushes/scenic rocks).
On first run, `scripts/world/terrain_painter.gd` paints both if `Ground` is empty.
**Spawns are tile-anchored inside the wall ring** (local slots → `map_to_local`); scene positions are overwritten at runtime.

### Paint a new level in the editor

1. Duplicate `scenes/levels/Level01.tscn` → e.g. `Level02.tscn`.
2. Open the copy. Select the `Ground` TileMapLayer.
3. Optional: set `paint_on_ready = false` on the terrain painter (Inspector), or remove that script once your painted cells are saved — otherwise an empty layer will be auto-filled again.
4. Paint with the TileSet (`grass` / `dirt` / `path` walkable; `rock` / `wall` block movement).
5. Move `Entities/Player`, `Entities/Humans/*`, `Entities/Sheep/*`, and `Entities/SafeZone` markers/instances.
6. Point `scenes/Main.tscn` at your new level (change the instanced scene), or set **Project → Project Settings → Application → Run → Main Scene** to your level scene.

### Create a level from scratch

1. New scene → root `Node2D` with `scripts/level_controller.gd`.
2. Add `TileMapLayer`, assign `assets/tiles/stsh_terrain_tileset.tres`, paint tiles.
3. Instance Player, Humans, Sheep, SafeZone under an `Entities` node.
4. Instance `scenes/ui/HUD.tscn` as a child of the root.
5. Save under `scenes/levels/` and set it as the main scene (or instance it from `Main.tscn`).

## Notes

- **False-win fix (build 002):** SafeZone stays `monitoring=false` until tile placement finishes; humans spawn in map corners (≥12 tiles Chebyshev from the safe zone); `GameState.setup_complete` gates win/lose. Instant “all rescued” at t=0 is fixed — herding via whip is required.
- Humans **avoid** the green zone on purpose (“too dumb to enter”); whip shove is the intended rescue path.
- **16-bit art pass:** character sheets, terrain atlas, and FX refreshed toward a classic SNES/Genesis ranch look (clearer silhouettes, limited palettes, dither/shade). Frame layouts stay 32×32 so existing `.tres` spriteframes/tileset keep working.
- Level01 is a larger open ranch with decor tiles; collision walls only on the border.
- Pixel art uses nearest-neighbor filtering (project default).
- Whip targeting is forgiving along the aim ray, not only near the cursor.
- Sheep AI: `attention_range` **160** (5 tiles) for chase/attack; `interest_range` **256** (8 tiles) for soft approach; prefer humans over player in attention range.
- No multiplayer.

## Build 003 note

Rescues stay locked until physics syncs spawn teleports (fixes false 5/5 at start).
Humans spawn in corners and avoid the green zone; whip-herd them in.
Gates kept in build 004: `rescues_unlocked`, baked tile positions, deferred SafeZone monitoring.

## Build 004 mechanics

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

## Grab / throw (RMB)

- Input action `whip_grab` = mouse button 2 (right click).
- Same `find_target` ray/cursor targeting as LMB; does **not** zip (no parent-to-target reel).
- Throw direction = **−aim** (180° from player→mouse). Tunables on `Whip`: `throw_force` **800**, `grab_cooldown_time` **0.40**.
- Targets implement `receive_throw(throw_direction, force)` with `_throw_timer` / `_thrown`.
- Sheep–sheep collision radius while thrown: `throw_collide_radius` **40**.
- Possessed flung into green → saved via `add_possession_save()` (not kill).

## Build 006 layout

- **Safe zone** moved to **bottom-right** interior (`SLOT_SAFE` local `(60, 38)`), path pad painted around it.
- Humans repositioned away from BR (≥12 Chebyshev): `(8,8)`, `(8,40)`, `(40,8)`, `(20,20)`, `(12,32)`.
- Player mid-field `(36, 24)` (old safe cell).
- **Sheep den** top-left (`SLOT_SHEEP_SPAWNER` `(8, 10)`): `scripts/world/sheep_spawner.gd` instances `Sheep.tscn` under `Entities/Sheep` every **60s** after `rescues_unlocked`, with ±16px jitter and soft cap **20** living sheep.
- Initial sheep: `(18,14)`, `(45,12)`, `(50,30)` (not on the den cell).
- Builds 003–005 kept: rescue unlock, HP/possession, grab/throw, HUD/alarm.

## Build 007 — whip animation and 32-bit art

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

## Build 008 — painted terrain (grassland, woods, paths, ponds)

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
Web build: `web-beta-008/` (single-threaded "Web" preset), not deployed.

## Build 009 — mobile touch controls (PC controls unchanged)

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
- End screen: big PLAY AGAIN button under the win/lose message (works with mouse click
  and touch tap); R still restarts on keyboard. End messages no longer say "Press R".
  While the game is over, touches only hit PLAY AGAIN (joystick/WHIP/GRAB hidden).
- 009 hotfix (joystick): phone browsers send fake mouse events around touches, which the
  hybrid-laptop check treated as a real mouse and switched touch mode off mid-drag (rancher
  froze). Now mouse input is ignored while a finger is down and for 2 s after the last touch,
  and tiny mouse moves are ignored. TouchControls reports every touch to TouchInput, drags
  with a renumbered finger id on the left side still drive the joystick, the joystick has a
  small dead zone and reaches full speed at ~70% deflection, and the player reads the touch
  vector whenever the keyboard vector is zero.
- 009 hotfix (facing whip): on touch, whip and grab aim along the rancher's facing
  direction (WHIP / playfield tap crack forward, GRAB throws behind). Mouse aim and
  LMB/RMB on non-touch stay exactly as before. Touch targeting uses the facing ray only.

## Build 010 — rounds & levels, human camp, diagonal touch whip, directional throw

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
- Web build: `web-beta-010/` (single-threaded "Web" preset). Not deployed.

## Build 011 — title screen, mobile aim assist, fixed joystick, square buttons, spawn tuning

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
- Web build: `web-beta-011/`. Not deployed.

## Build 012: immediate win, scoring, Genesis-style HUD, How to Play

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
- Web build: `web-beta-012/`. Not deployed.

## Build 013: Karens, camp hold, power-ups

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
`web-beta-013/`, exported with the same preset. **Not deployed.** Build 012 stays live.

## Build 014: MSM Cam, inventory (no power-up timers), corner-wedge touch controls

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
`web-beta-014/`, exported with the same Web preset (`--export-release`). **Not deployed.** Build 013 stays live.


## Build 014b: aim reticle (PC) and reach crosshair (touch)
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
`web-beta-014b/`, exported with the same Web preset (`--export-release`). Now the live build at https://savethesillyhumans.org/game.php.

