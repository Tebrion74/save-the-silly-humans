#!/usr/bin/env python3
"""Build 021: regional biome atlases for the regular levels.

For each theme writes assets/tiles/biome/<theme>/stsh_*_atlas.png: same layout,
cells and footprints as the base atlases (so props_meta / collision stay valid),
recoloured by hue class, plus a few new props drawn into existing cells:
  med     (L3-5, Mediterranean semi-arid): olive (oaks), CYPRESS (pine cell), dry scrub
  texas   (L6-8): mesquite (oaks), CACTUS (pine cell), PRICKLY PEAR (bush c/d), red dirt
  bavaria (L9-11): lush fields, dark pine + beech (birch cell), cool lake
  pnw     (L12-14): wet rainforest, mossy dark greens, FERNS (bushes), grey-blue water
  norcal  (L15-17): golden grass hills, oaks, REDWOOD (pine cell), sandy shore
  midwest (L18-20, build 025): Illinois corn belt: summer-green fields, rich dark
          tilled soil, CORN (pine cell), HAY BALES + corn shoots (bushes)
  ukraine (L21-23, build 025): golden wheat steppe, white BIRCH groves,
          SUNFLOWERS (bushes), blue ponds
Then: godot --headless --path . -s res://tools/build_tileset.gd -- --theme=<t>
"""
import colorsys, os, random
from PIL import Image

BASE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'tiles')
NAMES = ['ground', 'dirt', 'path', 'forest', 'water', 'props', 'details']
TS = 32

# per class: (target hue deg or None, hue blend, sat mul, val mul)
THEMES = {
    'med': {
        'green':  (62, 0.85, 0.55, 1.08),
        'brown':  (38, 0.7, 0.45, 1.30),
        'blue':   (182, 0.8, 0.85, 1.05),
        'leaf':   (80, 0.8, 0.45, 0.95),
        'trunk':  (28, 0.5, 0.7, 1.05),
        'path':   (40, 0.6, 0.5, 1.08),
    },
    'texas': {
        'green':  (50, 0.85, 0.62, 1.05),
        'brown':  (12, 0.85, 1.25, 0.95),
        'blue':   (168, 0.7, 0.55, 0.85),
        'leaf':   (82, 0.7, 0.6, 0.9),
        'trunk':  (22, 0.5, 0.9, 0.9),
        'path':   (36, 0.6, 0.6, 1.08),
    },
    'bavaria': {
        'green':  (108, 0.6, 1.15, 1.0),
        'brown':  (28, 0.4, 0.9, 0.85),
        'blue':   (205, 0.8, 0.9, 0.95),
        'leaf':   (115, 0.6, 1.05, 0.82),
        'trunk':  (25, 0.3, 0.6, 0.9),
    },
    'pnw': {
        'green':  (128, 0.7, 0.85, 0.78),
        'brown':  (24, 0.4, 0.7, 0.7),
        'blue':   (206, 0.85, 0.6, 0.85),
        'leaf':   (138, 0.7, 0.85, 0.68),
        'trunk':  (18, 0.5, 0.9, 0.75),
    },
    'norcal': {
        'green':  (43, 0.85, 0.85, 1.15),
        'brown':  (34, 0.6, 0.75, 1.2),
        'blue':   (200, 0.85, 1.05, 1.0),
        'leaf':   (88, 0.7, 0.7, 0.85),
        'trunk':  (10, 0.6, 1.2, 0.85),
    },
    'midwest': {
        'green':  (84, 0.55, 1.05, 1.06),
        'brown':  (22, 0.5, 1.1, 0.72),
        'blue':   (200, 0.7, 0.9, 0.95),
        'leaf':   (92, 0.5, 1.0, 0.95),
        'trunk':  (26, 0.4, 0.8, 0.9),
        'path':   (38, 0.6, 0.45, 1.1),
    },
    'ukraine': {
        'green':  (47, 0.88, 1.05, 1.22),
        'brown':  (32, 0.6, 0.8, 1.05),
        'blue':   (212, 0.8, 1.1, 1.05),
        'leaf':   (96, 0.6, 0.9, 1.0),
        'trunk':  (40, 0.5, 0.25, 1.35),
        'path':   (36, 0.6, 0.5, 1.12),
    },
}


def _cls(h, s, v):
    hd = h * 360
    if s < 0.12:
        return None
    if 55 <= hd <= 170:
        return 'green'
    if 175 <= hd <= 260:
        return 'blue'
    if hd < 50 or hd > 340:
        return 'brown'
    return None


def _blend_hue(h, target, k):
    t = target / 360.0
    d = ((t - h + 0.5) % 1.0) - 0.5
    return (h + d * k) % 1.0


def recolor(img, th, is_props=False, is_path=False):
    img = img.convert('RGBA')
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            c = _cls(h, s, v)
            if c is None:
                continue
            if is_props and c == 'green':
                c = 'leaf'
            if is_props and c == 'brown':
                c = 'trunk'
            if is_path and c == 'brown' and 'path' in th:
                c = 'path'
            hue, k, sm, vm = th[c]
            h = _blend_hue(h, hue, k)
            s = min(1, s * sm)
            v = min(1, v * vm)
            rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return img


# ---------------------------------------------------------------- new props
OUTLINE = (24, 30, 22, 255)


def _clear(img, cx, cy, w, h):
    for y in range(cy * TS, (cy + h) * TS):
        for x in range(cx * TS, (cx + w) * TS):
            img.putpixel((x, y), (0, 0, 0, 0))


def _shadow(img, ox, oy, cx, cy, rx, ry):
    for y in range(-ry, ry + 1):
        for x in range(-rx, rx + 1):
            if (x / rx) ** 2 + (y / ry) ** 2 <= 1:
                img.putpixel((ox + cx + x, oy + cy + y), (0, 0, 0, 70))


def _fill_shape(img, ox, oy, inside, pal, rnd, light=(-1, -1)):
    """inside(x,y)->bool on local coords; 3-tone shading + outline, dithered."""
    W, H = 200, 200
    pts = set()
    for y in range(0, 130):
        for x in range(0, 100):
            if inside(x, y):
                pts.add((x, y))
    for (x, y) in pts:
        edge = any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            col = OUTLINE
        else:
            # light from top-left: compare to neighbours further along the light dir
            lit = ((x - 3, y - 3) not in pts)
            dark = ((x + 3, y + 2) not in pts)
            n = rnd.random()
            if lit and n < 0.85:
                col = pal[2]
            elif dark and n < 0.85:
                col = pal[0]
            else:
                col = pal[1] if n < 0.82 else (pal[2] if n < 0.91 else pal[0])
        img.putpixel((ox + x, oy + y), col)


def draw_cypress(img, cell=(12, 0)):
    ox, oy = cell[0] * TS, cell[1] * TS
    _clear(img, cell[0], cell[1], 2, 4)
    rnd = random.Random(21)
    _shadow(img, ox, oy, 32, 118, 11, 4)
    # trunk
    _fill_shape(img, ox, oy, lambda x, y: 29 <= x <= 34 and 104 <= y <= 118,
                [(70, 46, 30, 255), (98, 66, 42, 255), (124, 88, 56, 255)], rnd)
    # tall flame-shaped column
    def col(x, y):
        if y < 8 or y > 110:
            return False
        t = (y - 8) / 102.0
        w = 4 + 11 * (t ** 0.6) * (1.0 - 0.55 * max(0, t - 0.75) / 0.25 if t > 0.75 else 1.0)
        wob = 1.2 * ((y * 7) % 5 - 2) / 2.0
        return abs(x - 32 + 0.3 * wob) <= w
    _fill_shape(img, ox, oy, col, [(28, 58, 36, 255), (40, 80, 48, 255), (62, 108, 64, 255)], rnd)


def draw_cactus(img, cell=(12, 0)):
    ox, oy = cell[0] * TS, cell[1] * TS
    _clear(img, cell[0], cell[1], 2, 4)
    rnd = random.Random(22)
    _shadow(img, ox, oy, 32, 118, 10, 4)
    def body(x, y):
        # trunk
        if abs(x - 32) <= 6 and 40 <= y <= 117:
            return (x - 32) ** 2 + max(0, 46 - y) ** 2 <= 49 or y >= 46
        # left arm
        if 66 <= y <= 80 and 17 <= x <= 32:
            return True
        if abs(x - 20) <= 4 and 52 <= y <= 80:
            return (x - 20) ** 2 + max(0, 56 - y) ** 2 <= 20 or y >= 56
        # right arm
        if 78 <= y <= 90 and 32 <= x <= 46:
            return True
        if abs(x - 44) <= 4 and 62 <= y <= 90:
            return (x - 44) ** 2 + max(0, 66 - y) ** 2 <= 20 or y >= 66
        return False
    _fill_shape(img, ox, oy, body, [(40, 84, 44, 255), (66, 118, 60, 255), (104, 150, 82, 255)], rnd)
    # ribs + spines
    for y in range(46, 116, 3):
        for x in (29, 35):
            if img.getpixel((ox + x, oy + y))[3] and img.getpixel((ox + x, oy + y)) != OUTLINE:
                img.putpixel((ox + x, oy + y), (36, 70, 40, 255))
    for i in range(30):
        x, y = rnd.randint(22, 44), rnd.randint(46, 112)
        if img.getpixel((ox + x, oy + y)) not in ((0, 0, 0, 0), OUTLINE):
            img.putpixel((ox + x, oy + y), (232, 226, 190, 255))


def draw_pear(img, cell, seed):
    ox, oy = cell[0] * TS, cell[1] * TS
    _clear(img, cell[0], cell[1], 1, 1)
    rnd = random.Random(seed)
    pads = [(16, 19, 6, 7), (10, 12, 4, 5), (22, 11, 4, 5)]
    if seed % 2:
        pads = [(15, 19, 6, 7), (21, 12, 5, 5)]
    def inside(x, y):
        return any(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 for cx, cy, rx, ry in pads)
    _fill_shape(img, ox, oy, inside, [(52, 96, 52, 255), (82, 132, 68, 255), (118, 164, 88, 255)], rnd)
    for cx, cy, rx, ry in pads:   # little red fruit on top
        if rnd.random() < 0.8:
            img.putpixel((ox + cx, oy + cy - ry), (200, 40, 70, 255))
            img.putpixel((ox + cx + 1, oy + cy - ry), (170, 30, 60, 255))


def draw_fern(img, cell, seed):
    ox, oy = cell[0] * TS, cell[1] * TS
    _clear(img, cell[0], cell[1], 1, 1)
    rnd = random.Random(seed)
    import math
    base = (16, 25)
    cols = [(30, 70, 40, 255), (52, 104, 52, 255), (84, 140, 70, 255)]
    for k in range(7):
        ang = math.radians(-160 + k * 23.3 + rnd.uniform(-5, 5))
        L = rnd.uniform(11, 15)
        for i in range(int(L)):
            t = i / L
            x = base[0] + math.cos(ang) * i
            y = base[1] + math.sin(ang) * i + (t * t) * 4
            for ddx in (0, 1):
                if 0 <= x + ddx < 32 and 0 <= y < 32:
                    img.putpixel((ox + int(x) + ddx, oy + int(y)), cols[0])
            for s in (-1, 1):   # leaflets
                lx = x + math.cos(ang + s * 1.3) * (2.5 * (1 - t) + 0.5)
                ly = y + math.sin(ang + s * 1.3) * (2.5 * (1 - t) + 0.5)
                for (qx, qy) in ((lx, ly), (lx + math.cos(ang + s * 1.3), ly + math.sin(ang + s * 1.3))):
                  if 0 <= qx < 32 and 0 <= qy < 32:
                    img.putpixel((ox + int(qx), oy + int(qy)), cols[2] if s < 0 else cols[1])
                if 0 <= lx < 32 and 0 <= ly < 32:
                    img.putpixel((ox + int(lx), oy + int(ly)), cols[2] if s < 0 else cols[1])


def draw_corn(img, cell=(12, 0)):
    """build 025 midwest: a clump of tall corn stalks with leaves, ears, tassels."""
    import math
    ox, oy = cell[0] * TS, cell[1] * TS
    _clear(img, cell[0], cell[1], 2, 4)
    rnd = random.Random(25)
    _shadow(img, ox, oy, 32, 118, 18, 5)
    stalk = [(40, 92, 30, 255), (70, 132, 44, 255), (110, 170, 64, 255)]
    for k, x0 in enumerate((18, 26, 33, 40, 46)):
        top = 14 + (k * 7) % 12
        _fill_shape(img, ox, oy, lambda x, y, x0=x0, top=top: abs(x - x0) <= 1 and top <= y <= 117, stalk, rnd)
        for j in range(5):                       # arching leaves
            y0 = top + 18 + j * 17
            side = 1 if (j + k) % 2 else -1
            for i in range(13):
                xx = x0 + side * i
                yy = y0 + int((i / 13.0) ** 2 * 9) - 2
                for w in (0, 1):
                    if 0 <= xx < 64 and 0 <= yy + w < 128:
                        img.putpixel((ox + xx, oy + yy + w), stalk[1] if w == 0 else stalk[0])
        for t in range(6):                       # tassel
            img.putpixel((ox + x0 + rnd.randint(-2, 2), oy + top - t), (214, 186, 96, 255))
        ey = top + 44
        _fill_shape(img, ox, oy, lambda x, y, x0=x0, ey=ey: ((x - x0 - 3) / 2.5) ** 2 + ((y - ey) / 6.0) ** 2 <= 1,
                    [(170, 140, 40, 255), (226, 196, 70, 255), (250, 230, 130, 255)], rnd)


def draw_haybale(img, cell, seed):
    ox, oy = cell[0] * TS, cell[1] * TS
    _clear(img, cell[0], cell[1], 1, 1)
    rnd = random.Random(seed)
    _shadow(img, ox, oy, 16, 27, 12, 3)
    _fill_shape(img, ox, oy, lambda x, y: ((x - 16) / 12.5) ** 2 + ((y - 18) / 9.5) ** 2 <= 1,
                [(150, 112, 44, 255), (200, 160, 70, 255), (232, 200, 110, 255)], rnd)
    for x in range(7, 26, 4):
        for y in range(11, 26):
            p = img.getpixel((ox + x, oy + y))
            if p[3] and p != OUTLINE and rnd.random() < 0.6:
                img.putpixel((ox + x, oy + y), (170, 128, 52, 255))


def draw_shoot(img, cell, seed):
    ox, oy = cell[0] * TS, cell[1] * TS
    _clear(img, cell[0], cell[1], 1, 1)
    rnd = random.Random(seed)
    cols = [(40, 92, 30, 255), (70, 132, 44, 255), (110, 170, 64, 255)]
    for x0 in (9, 16, 23):
        for i in range(14):
            img.putpixel((ox + x0, oy + 27 - i), cols[1])
        for j, side in enumerate((-1, 1, -1)):
            y0 = 24 - j * 4
            for i in range(6):
                img.putpixel((ox + x0 + side * i, oy + y0 - i // 2), cols[2] if side < 0 else cols[0])


def draw_sunflower(img, cell, seed):
    """build 025 ukraine: a sunflower (no collision bush cell)."""
    import math
    ox, oy = cell[0] * TS, cell[1] * TS
    _clear(img, cell[0], cell[1], 1, 1)
    rnd = random.Random(seed)
    _shadow(img, ox, oy, 16, 29, 7, 2)
    for y in range(12, 30):
        img.putpixel((ox + 16, oy + y), (60, 118, 40, 255))
        img.putpixel((ox + 17, oy + y), (44, 92, 30, 255))
    for side in (-1, 1):
        for i in range(5):
            img.putpixel((ox + 16 + side * (i + 1), oy + 22 - i // 2), (84, 150, 56, 255))
    cx, cy = 16, 10 + seed % 2
    for a in range(16):
        ang = a * math.pi / 8
        for r in range(5, 9):
            x, y = int(cx + math.cos(ang) * r), int(cy + math.sin(ang) * r * 0.9)
            if 0 <= x < 32 and 0 <= y < 32:
                img.putpixel((ox + x, oy + y), (250, 200, 30, 255) if r < 8 else (200, 140, 10, 255))
    for y in range(-4, 5):
        for x in range(-4, 5):
            if x * x + y * y <= 17:
                img.putpixel((ox + cx + x, oy + cy + y), (92, 52, 22, 255) if (x + y) % 2 else (64, 36, 14, 255))


def main():
    srcs = {n: Image.open(os.path.join(BASE, 'stsh_%s_atlas.png' % n)).convert('RGBA') for n in NAMES}
    for theme, th in THEMES.items():
        out = os.path.join(BASE, 'biome', theme)
        os.makedirs(out, exist_ok=True)
        for n in NAMES:
            img = recolor(srcs[n].copy(), th, is_props=(n == 'props'), is_path=(n == 'path'))
            if n == 'props':
                if theme == 'med':
                    draw_cypress(img)
                elif theme == 'texas':
                    draw_cactus(img)
                    draw_pear(img, (2, 4), 1)
                    draw_pear(img, (3, 4), 2)
                elif theme == 'pnw':
                    for i in range(4):
                        draw_fern(img, (i, 4), 30 + i)
                elif theme == 'midwest':
                    draw_corn(img)
                    draw_haybale(img, (0, 4), 41)
                    draw_haybale(img, (1, 4), 42)
                    draw_shoot(img, (2, 4), 43)
                    draw_shoot(img, (3, 4), 44)
                elif theme == 'ukraine':
                    for i in range(4):
                        draw_sunflower(img, (i, 4), 50 + i)
            img.save(os.path.join(out, 'stsh_%s_atlas.png' % n))
        print('biome', theme, 'ok')


if __name__ == '__main__':
    main()
