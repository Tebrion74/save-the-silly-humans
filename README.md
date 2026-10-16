# Save The Silly Humans

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf.svg)](https://godotengine.org) [![Play](https://img.shields.io/badge/play-in%20browser-brightgreen.svg)](https://savethesillyhumans.org/game.php)

**A rancher, a whip, killer sheep and a field full of humans too silly to save themselves.**

▶ **Play it in your browser:** https://savethesillyhumans.org/game.php

Current build: **030** (live since 2026-10-15 ~20:44 MT: surprise cameo sub-bosses Eelon Tusk, Jeff Bozos, Sam Altmann and Mark Zuckerbot, with their own funk stingers and an attract-mode lineup) ([release notes and downloads](https://github.com/Tebrion74/save-the-silly-humans/releases)) · Engine: **Godot 4.7.2** · Published by **Echelon Publishers Group** (Calgary, Alberta)

Watch on [Rumble](https://rumble.com/c/SaveTheSillyHumans) · [YouTube](https://www.youtube.com/@SaveTheSillyHumans)

---

## Features

- **Rancher with a whip.** Crack to shove silly humans toward safety and blow up killer sheep. Grab and throw anything you can lash.
- **Killer sheep.** They roam, hunt and bite. A sheep den keeps breeding more.
- **Possessed humans.** Five bites and a silly human turns into a purple hunter. Explode them, or throw them into the safe zone to save them.
- **Karens (level 3+).** Four possessed humans together become a Karen mob. They chase you, convert humans and shut down the camp.
- **Cantifa (level 4+, 017).** A cartoon black-bloc mob, not a Karen and not a person you can save. One in five humans spawned is one instead, walking in from off the map. They gather as one group at a post just outside the safe zone or the camp, move from post to post together, and shoot first: as soon as the rancher is in range with a clear line, posted or not (telegraphed, dodgeable; trees and rocks block their shots, since 023). From level 9 more of them come, and more often (cap 6 → 10, one in four humans from level 9, one in three from level 12). Two whip hits or one fire hit drives them off. Filming one sends humans on camera running for safety and enrages Karens.
- **MSM Cam.** A 1980s shoulder camcorder. Film silly humans to convince them to walk to safety, expose Karens to go VIRAL, or swing it to knock enemies back. Watch the battery.
- **Power-ups and inventory.** Long Whip, Strong Throw, Whip Shot, Fire Whip, Shockwave, Health, batteries. Collected power-ups never time out, and your inventory carries into the next level. Since 020, power-ups also appear on the map on a timer in regular levels (not in boss or bonus stages).
- **Rounds, levels and scoring.** Hit the save target to win, with a Genesis-style HUD and a high score.
- **Hearts (020, 022).** Start with 5 hearts and earn +1 max heart every 2 levels completed, up to **16** (raised from 12 in build 027; the cap was 8 before build 022). Above 12 the HUD packs them into two rows of 8, with armour shields alongside, on PC and mobile. At full hearts your whip has extra reach until you take a hit.
- **INVINCIBLE star (020).** A rare 30-second pickup: nothing hurts you, every saveable target flashes green and one crack saves it, with combo scoring (200, 400, 800 … up to 102,400) and a warning 3 s before it ends.
- **Regional biomes (021).** Each stretch of regular levels looks like the home region of the boss at its end: Prairie Ranch (L1–2), Olive Hills (L3–5), Lone Star Scrub (L6–8), Alpine Forest (L9–11), Rainforest (L12–14), Golden Coast (L15–17), Corn Belt (L18–20, Midwest farmland with corn rows, hay bales and a farm pond; 025) Wheat Steppe (L21–23, Ukrainian wheat fields, birch groves and sunflowers; 025), Frozen Taiga (L24–26, snow, birch and snowy spruce, frozen ponds; 027) and Palm Links (L27–29, Florida fairways, bunkers, water hazards, palms and pin flags; 027). From L30 all ten biomes cycle, one level each. Bonus stages and boss arenas keep their own looks.
- **Hidden chambers (024).** Every regular level hides 1 or 2 small chambers behind a breakable rock or bush. Some are faintly cracked and discoloured, others look like any other tile. Whip one (2 cracks, or 1 with Fire Whip or Shockwave) to reveal a reward: treasure (+750), a full heal or a power-up. Each chamber pays out once per run. Works the same on touch.
- **Ten boss battles.** A boss waits after levels 2, 5, 8, 11, 14, 17, 20, 23, 26 and 29: Trustin Judeau, Huval Yarheyhey, Beorge Kush Jr., Shlaus Kwobb, Gill Bates, Nancy Pelotto, Reanald Rogan, Zelodymer Violentsky, Vladimir Puddin and, as the final boss, Donald Rump. Each has telegraphed attacks, three phases and a rage mode. Don't touch a boss; dying retries the fight. See [Bosses](#bosses).
- **Bonus stage (016).** After level 1 and then every 3 levels (4, 7, 10, …): a Galaga-style 45-second challenge stage. Eight waves of flying sheep swoop across the field. Pop them before they leave. 100 per hit, +500 for a whole wave, and PERFECT! SPECIAL BONUS 10000 for all of them. You can't get hurt, and power-ups work without being used up. Each repeat brings more and faster sheep. Since 022 the whip cools down twice as fast here and one crack pops every sheep it overlaps.
- **Progression.** L1 → bonus → L2 → Trustin → L3 → L4 → bonus → L5 → Huval → L6 → L7 → bonus → L8 → Kush → L9 → L10 → bonus → L11 → Shlaus → L12 → L13 → bonus → L14 → Gill → L15 → L16 → bonus → L17 → Nancy → L18 → L19 → bonus → L20 → Rogan → L21 → L22 → bonus → L23 → Violentsky → L24 → L25 → bonus → L26 → Puddin → L27 → L28 → bonus → L29 → Rump → the ending.
- **The ending (027).** Beat Donald Rump to see the saved humans celebrate under fireworks, then the credits roll. After that choose ENDLESS MODE (the run carries on from L30, all ten biomes cycling, a bonus stage every 3 levels) or RETURN TO TITLE. When a bonus and a boss share a slot, the bonus comes first.
- **Sound and music (015b, 016, 023, 026).** Generated sound effects for everything (whip, grabs, saves, explosions, cam, bosses, hidden chambers, UI) and original generated music. Since 026 every biome has its own warm, bass-heavy funk / groove loop with slap or synth bass, punchy drums, clav or wah and brass stabs: Prairie Strut (country-funk), Olive Grove Groove (hijaz), Lone Star Strut (Texas shuffle), Oompah Overdrive (Bavarian tuba funk), Rainforest Roll (Rhodes dorian), Golden Coast Cruise (surf funk), Cornfield Cookout (harmonica blues), Steppe Stomp (Ukrainian dorian), Troika Trot (taiga balalaika funk; 027) and Palm Links Shuffle (calypso steel-pan groove; 027). The bonus stage and each boss have their own themes, re-rendered punchier and lower in 026; 027 adds the extra-epic Bareback Blizzard (Puddin) and The Final Round (Rump). The title screen and attract mode have their own anthem, Silly Humans Anthem (slap bass and a brass hook; 028). M (or the speaker icon on touch) cycles sound ON / LOW / OFF.
- **Body armour (025).** From level 12 (after Shlaus Kwobb) a BODY ARMOUR pickup can drop in regular levels. It gives 3 plates; each soaks one hit before you lose a heart. The rancher wears a steel-blue vest while it lasts, and blue shields sit next to your hearts. Armour carries into the next level.
- **Attract mode (028).** Leave the title idle for 10 s and it cycles like an arcade cabinet, one screen every 7 s with a blind-wipe transition: the title with PRESS START, MEET THE VILLAINS (all ten bosses with name, title and level), a Galaga-style SCORE TABLE with every point value in the game, and the HIGH SCORES table. Any key, click, tap or pad button returns to the title at once.
- **Top-10 high scores (028).** A game over (or the ending) with a top-10 score opens an arcade initials screen: on PC, UP/DOWN or W/S pick the letter, LEFT/RIGHT move, type letters directly, ENTER confirms; on touch, tap the arrows and OK. Each entry keeps initials, score and the level reached, and the table is saved on your device (browser storage on the web), so it survives reloads. One entry per run; runs that used the beta testing tools don't count.
- **Surprise cameos (030).** From level 2, tech-mogul parodies drop into regular levels at random for about 15 s, one at a time, with speech-bubble quips and their own funk stinger. **Eelon Tusk** (ally) gives a rocket speed boost and calls STARLINK STRIKEs on nearby sheep. **Jeff Bozos** (wild card) has drones drop parcels: loot, or bombs you can whip to defuse (+100). **Sam Altmann** (wild card) brings a chatbot drone that either points at a hidden chamber and zaps sheep, or confidently points at nothing and misses. **Mark Zuckerbot** (foe) fires slow LIKE bubbles; 6 whip hits unplug him for 1500 (+50 a hit). They're in the attract-mode lineup and score table. Never in boss or bonus stages.
- **HUD (025).** Two compact cards: hearts and armour with your score, level and time on the left; SAVED and the crowd counters on the right. Power-up icons with timers sit underneath. "SECRET FOUND!" shows clear of the score on PC and mobile.
- **PC and touch controls.** Mouse and keyboard with an aim reticle, or a touch joystick with corner wedges and aim assist. Since 029 touch aim snaps to 8 equal directions from the stick's live angle (diagonal whips are as easy as straight ones), with a large high-contrast reticle and direction chevron.

## Bosses

All ten are good-natured cartoon parodies drawn from code (no photos or likenesses). Each fight sits between two levels (Rump, the final boss, leads to the ending): beat the boss to move on, die and you retry the fight.

| # | Boss | When | Lead-in biome | One-liner |
|---|---|---|---|---|
| 1 | **Trustin Judeau**, Prime Minister of Poutine (015) | after L2, before L3 | Prairie Ranch | 10 hearts; telegraphed poutine attacks that escalate through three phases into a rage mode. |
| 2 | **Huval Yarheyhey**, Prophet of the Algorithm (016) | after L5, before L6 | Olive Hills | 12 hearts; programmed sheep that split into micro sheep when hit, a lecture ray and SYSTEM UPDATEs that speed up his flock. |
| 3 | **Beorge Kush Jr.**, The Airstrike Ace (018) | after L8, before L9 | Lone Star Scrub | 15 hearts; radioed-in airstrikes, strafing jets and carpet bombing. Lure him onto his own marks. |
| 4 | **Shlaus Kwobb**, Chairman of the Great Reset (018; renamed from Klaus Schwab in 019) | after L11, before L12 | Alpine Forest | 18 hearts; the puppet master: hologram delegates of the earlier bosses (film them to dispel them), envelope fans and THE GREAT RESET ring. |
| 5 | **Gill Bates**, Patron of the Server Farm (020) | after L14, before L15 | Rainforest | 20 hearts; a server-farm gala with floppy-disk patches, blue-screen rings and a SYSTEM UPDATE shield. |
| 6 | **Nancy Pelotto**, Speaker of the House (020) | after L17, before L18 | Golden Coast | 22 hearts; a Capitol hall with ice-cream cones, "ORDER!" gavel rings and an IN RECESS shield. |
| 7 | **Reanald Rogan**, The Gipper of the Galaxy (025) | after L20, before L21 | Corn Belt | 24 hearts; "Star Wars" missile defence: orbital-laser target rings, a sweeping satellite beam (step to the side it sweeps away from) and UFOs with tractor beams that two whips shoot down. |
| 8 | **Zelodymer Violentsky**, The Comedian Commander (025) | after L23, before L24 | Wheat Steppe | 26 hearts; a broadcast tent in a sunflower field with explosive drone swarms: each drone hovers over a marked spot, then dives and blasts. Step out of the ring or whip it first. |
| 9 | **Vladimir Puddin**, The Bareback Strongman (027) | after L26, before L27 | Frozen Taiga | 30 hearts; a shirtless judo strongman on horseback in a frozen clearing: tank charges down telegraphed lanes, judo grab-and-toss, and the ARENA SHAKE, which flips your controls for 3 seconds (warning and countdown shown) while icicles fall. |
| 10 | **Donald Rump**, the final boss (027) | after L29 | Palm Links | 34 hearts; a golf course under a gold tower: golf-ball drives onto marked spots, walls that drop in and split the arena, and red-cap rally fans that chase you (whip to shoo). At 8 hearts: YOU'RE FIRED! rage. Beat him for the ending. |

## Controls

**PC**

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Aim (reticle turns green when a target is in range) |
| Left click | Whip crack · with the cam: hold to REC |
| Right click | Grab & throw · with the cam: SWING |
| Q / mouse wheel / 1–2 | Swap weapon |
| R | Restart |
| N / Enter | Next level |
| M | Sound ON / LOW / OFF (015b) |

**Touch**

| Control | Action |
|---|---|
| Joystick (bottom left) | Move |
| Bottom-right wedge | Whip (auto-aims) · with the cam: hold REC |
| Top-right wedge | Grab & throw · with the cam: SWING |
| Top-left wedge | Swap weapon |
| Crosshair | Shows your weapon's reach |
| Speaker icon (top) | Sound ON / LOW / OFF (015b) |

## Open in Godot

1. Install **Godot 4.7.x** (built with 4.7.2; the renderer is Compatibility, so it runs on the web).
2. In the Project Manager, choose **Import** and select this folder's `project.godot`.
3. Press **F5** to run. The game starts on the title screen (`scenes/Title.tscn`).

The first time you open the project, Godot builds its `.godot/` import cache. This takes a moment and is not committed.

## Export to Web

1. Install the matching export templates: **Editor → Manage Export Templates**.
2. **Project → Export…** and select the included **Web** preset (single-threaded, no SharedArrayBuffer needed).
3. Export to any folder (the preset defaults to `web-beta/`, which git ignores) and serve `index.html` from a web server.

From the command line:

```sh
mkdir -p export/web
godot --headless --path . --export-release "Web" export/web/index.html
```

The preset excludes `web-beta*/` folders, so old exports inside the project never get packed into a new build.

## Project layout

```
project.godot         Godot project settings (input map, autoloads, renderer)
export_presets.cfg    Web export preset
scenes/               Title, Main, levels, player, humans, sheep, world, UI
scripts/              Game logic
  player/             rancher, whip, MSM Cam, weapons, power-up inventory
  boss/               boss arenas, Trustin Judeau (015), Huval Yarheyhey + programmed sheep (016), Beorge Kush Jr. and Shlaus Kwobb (018), Gill Bates and Nancy Pelotto (020), Reanald Rogan + Star Wars tech and Zelodymer Violentsky + drones (025), Vladimir Puddin, Donald Rump + the finale hazards (027)
  bonus/              Galaga-style bonus stage: waves, flying sheep, tally (016)
  audio/              sound buses, music and the sound setting (build 015b)
  humans/ sheep/      AI for silly humans, possessed humans, Karens, Cantifa (017) and sheep
  world/              safe zone, camp, sheep den, power-ups, fire, terrain painter, hidden chambers (world/secrets/, 024)
  ui/                 title screen, HUD, touch controls, reticle, pixel font
  level_config.gd     all tuning numbers
assets/               pixel-art sheets, terrain/prop atlases, TileSet, SpriteFrames, shader
tools/                art generators (Python + Pillow) and headless Godot checks
docs/DEVLOG.md        full build history, prototype → 016
README_PIXEL_PACK.md  sprite sheet layout notes
LICENSE               MIT
```

## Build history and downloads

Every build, from the first prototype through the 009 hotfixes to 017, has a [GitHub release](https://github.com/Tebrion74/save-the-silly-humans/releases) with its notes and the original source zip. The releases for **007, 008, 009d and 010 through 017** also include that build's playable Web export (`web-beta-<build>.zip`), so you can host any of those versions yourself: unzip it and serve `index.html` from any web server. No Web exports exist for the prototypes, builds 001–006, or 009, 009b and 009c, so those releases have source only. The full history is in [docs/DEVLOG.md](docs/DEVLOG.md).

## Assets

All art and audio in this game is **original work, made for this project**:

- **Sprites:** the rancher, silly humans, possessed humans, Karens and sheep sheets (`assets/characters/`), drawn for the game. The boss, Trustin Judeau (`assets/boss/`), is an invented, good-natured cartoon parody generated by `tools/gen_boss.py` (no real likeness or photos). Boss 2, Huval Yarheyhey, his programmed and micro sheep and the Data Plaza arena (`assets/boss2/`, build 016) are generated the same way by `tools/gen_boss2.py`. Bosses 3 and 4, Beorge Kush Jr. with his jet and flight deck (`assets/boss3/`) and Shlaus Kwobb with the summit hall (`assets/boss4/`), build 018, come from `tools/gen_boss3.py` and `tools/gen_boss4.py`. Bosses 5 and 6, Gill Bates with the server-farm gala (`assets/boss5/`) and Nancy Pelotto with the Capitol hall (`assets/boss6/`), build 020, come from `tools/gen_boss5.py`. STSH Pixel Pack v1 → v2 (16-bit) → v3 (build 007, 32-bit).
- **FX:** whip crack and explosion sheets (`assets/fx/`), plus effects drawn in code (whip lash, reticle, fire, shockwave, camcorder, VIRAL callout).
- **Terrain and props:** grass, dirt, paths, forest floor, water, trees, rocks, fences and decor (`assets/tiles/`), generated by the Python scripts in `tools/` (`gen_terrain.py`, `gen_props.py`, `artlib.py`) and assembled into the TileSet by `tools/build_tileset.gd`.
- **Sound:** sound effects are generated procedurally at runtime (`scripts/sfx.gd`). The music loops (`assets/audio/music_level.wav` "Ranch Hand Hustle" and `music_boss.wav` "Question Period", build 015b; `music_bonus.wav` and `music_boss2.wav`, build 016; `music_boss3.wav` and `music_boss4.wav`, build 018; `music_boss5/6.wav`, build 020; `music_level_<biome>.wav` for prairie, med, texas, bavaria, pnw and norcal, build 023) were original chiptunes generated by `tools/gen_music.py`. Since build 026 all level loops are funk / groove tracks generated by `tools/gen_funk.py` (16-bit, QOA-compressed in the export), which also re-renders the boss and bonus themes.
- **Font:** the pixel font is built in code (`scripts/ui/pixel_font.gd`). There are no font files.

The project contains no third-party assets. All assets are covered by the same [MIT licence](LICENSE) as the code.

## Credits

Created by Robert J. Morris. Published by **Echelon Publishers Group**, Calgary, Alberta.

Code & design assist: Ewan Shepherd, LLM.


## Beta dev cheat codes
Beta-only testing codes (god mode, stage skip, level select, noclip) are listed in [CHEATS.md](CHEATS.md). They will be removed at alpha (v1.0); the game goes closed source beyond the Steam release.

## Licence

[MIT](LICENSE) © 2026 Robert J. Morris (Echelon Publishers Group). The licence covers the code **and** all art and assets: sprites, sprite sheets, FX, terrain and prop atlases, TileSets, SpriteFrames, shaders, procedural sound and generated music, the pixel font and the documentation. In `LICENSE`, "the Software" means everything in this repository. You're free to use, modify and redistribute them as long as you keep the copyright and licence notice.
