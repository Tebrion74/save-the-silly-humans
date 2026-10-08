# Save The Silly Humans

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf.svg)](https://godotengine.org) [![Play](https://img.shields.io/badge/play-in%20browser-brightgreen.svg)](https://savethesillyhumans.org/game.php)

**A rancher, a whip, killer sheep and a field full of humans too silly to save themselves.**

▶ **Play it in your browser:** https://savethesillyhumans.org/game.php

Current build: **015b** (live: harder boss, sound and music) ([release notes and downloads](https://github.com/Tebrion74/save-the-silly-humans/releases)) · Engine: **Godot 4.7.2** · Published by **Echelon Publishers Group** (Calgary, Alberta)

Watch on [Rumble](https://rumble.com/c/SaveTheSillyHumans) · [YouTube](https://www.youtube.com/@SaveTheSillyHumans)

---

## Features

- **Rancher with a whip.** Crack to shove silly humans toward safety and blow up killer sheep. Grab and throw anything you can lash.
- **Killer sheep.** They roam, hunt and bite. A sheep den keeps breeding more.
- **Possessed humans.** Five bites and a silly human turns into a purple hunter. Explode them, or throw them into the safe zone to save them.
- **Karens (level 3+).** Four possessed humans together become a Karen mob. They chase you, convert humans and shut down the camp.
- **MSM Cam.** A 1980s shoulder camcorder. Film silly humans to convince them to walk to safety, expose Karens to go VIRAL, or swing it to knock enemies back. Watch the battery.
- **Power-ups and inventory.** Long Whip, Strong Throw, Whip Shot, Fire Whip, Shockwave, Health, batteries. Power-ups never time out, and your inventory carries into the next level.
- **Rounds, levels and scoring.** Hit the save target to win, with a Genesis-style HUD and a high score.
- **Boss battle.** Clear level 2 to face TRUSTIN JUDEAU, Prime Minister of Poutine: 10 hearts, telegraphed poutine attacks that escalate in three phases and a rage mode. Beat him to reach level 3.
- **Sound and music (015b).** Generated sound effects for everything (whip, grabs, saves, explosions, cam, boss, UI) and two original chiptune loops, one for the levels and a tenser one for the boss. M (or the speaker icon on touch) cycles sound ON / LOW / OFF.
- **PC and touch controls.** Mouse and keyboard with an aim reticle, or a touch joystick with corner wedges and aim assist.

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
  boss/               boss arena and Trustin Judeau (build 015)
  audio/              sound buses, music and the sound setting (build 015b)
  humans/ sheep/      AI for silly humans, possessed humans, Karens and sheep
  world/              safe zone, camp, sheep den, power-ups, fire, terrain painter
  ui/                 title screen, HUD, touch controls, reticle, pixel font
  level_config.gd     all tuning numbers
assets/               pixel-art sheets, terrain/prop atlases, TileSet, SpriteFrames, shader
tools/                art generators (Python + Pillow) and headless Godot checks
docs/DEVLOG.md        full build history, prototype → 015b
README_PIXEL_PACK.md  sprite sheet layout notes
LICENSE               MIT
```

## Build history and downloads

Every build, from the first prototype through the 009 hotfixes to 015b, has a [GitHub release](https://github.com/Tebrion74/save-the-silly-humans/releases) with its notes and the original source zip. The releases for **007, 008, 009d and 010 through 015b** also include that build's playable Web export (`web-beta-<build>.zip`), so you can host any of those versions yourself: unzip it and serve `index.html` from any web server. No Web exports exist for the prototypes, builds 001–006, or 009, 009b and 009c, so those releases have source only. The full history is in [docs/DEVLOG.md](docs/DEVLOG.md).

## Assets

All art and audio in this game is **original work, made for this project**:

- **Sprites:** the rancher, silly humans, possessed humans, Karens and sheep sheets (`assets/characters/`), drawn for the game. The boss, Trustin Judeau (`assets/boss/`), is an invented, good-natured cartoon parody generated by `tools/gen_boss.py` (no real likeness or photos). STSH Pixel Pack v1 → v2 (16-bit) → v3 (build 007, 32-bit).
- **FX:** whip crack and explosion sheets (`assets/fx/`), plus effects drawn in code (whip lash, reticle, fire, shockwave, camcorder, VIRAL callout).
- **Terrain and props:** grass, dirt, paths, forest floor, water, trees, rocks, fences and decor (`assets/tiles/`), generated by the Python scripts in `tools/` (`gen_terrain.py`, `gen_props.py`, `artlib.py`) and assembled into the TileSet by `tools/build_tileset.gd`.
- **Sound:** sound effects are generated procedurally at runtime (`scripts/sfx.gd`). The two music loops (`assets/audio/music_level.wav` "Ranch Hand Hustle" and `music_boss.wav` "Question Period", build 015b) are original chiptunes generated by `tools/gen_music.py`.
- **Font:** the pixel font is built in code (`scripts/ui/pixel_font.gd`). There are no font files.

The project contains no third-party assets. All assets are covered by the same [MIT licence](LICENSE) as the code.

## Credits

Created by Robert J. Morris. Published by **Echelon Publishers Group**, Calgary, Alberta.

## Licence

[MIT](LICENSE) © 2026 Robert J. Morris (Echelon Publishers Group). The licence covers the code **and** all art and assets: sprites, sprite sheets, FX, terrain and prop atlases, TileSets, SpriteFrames, shaders, procedural sound and generated music, the pixel font and the documentation. In `LICENSE`, "the Software" means everything in this repository. You're free to use, modify and redistribute them as long as you keep the copyright and licence notice.
