# Save The Silly Humans

**A rancher, a whip, killer sheep and a field full of humans too silly to save themselves.**

▶ **Play it in your browser:** https://savethesillyhumans.org/game.php

Current build: **014b** · Engine: **Godot 4.7.2** · Published by **Echelon Publishers Group** (Calgary, Alberta)

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

**Touch**

| Control | Action |
|---|---|
| Joystick (bottom left) | Move |
| Bottom-right wedge | Whip (auto-aims) · with the cam: hold REC |
| Top-right wedge | Grab & throw · with the cam: SWING |
| Top-left wedge | Swap weapon |
| Crosshair | Shows your weapon's reach |

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
  humans/ sheep/      AI for silly humans, possessed humans, Karens and sheep
  world/              safe zone, camp, sheep den, power-ups, fire, terrain painter
  ui/                 title screen, HUD, touch controls, reticle, pixel font
  level_config.gd     all tuning numbers
assets/               pixel-art sheets, terrain/prop atlases, TileSet, SpriteFrames, shader
tools/                art generators (Python + Pillow) and headless Godot checks
docs/DEVLOG.md        build-by-build development notes
README_PIXEL_PACK.md  sprite sheet layout notes
```

## Credits

Published by **Echelon Publishers Group**, Calgary, Alberta.

All rights reserved © Echelon Publishers Group. Licence TBD.
