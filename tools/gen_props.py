"""Build 008 props (y-sorted multi-cell trees, bushes, rocks, ranch decor) and
flat detail decals. Writes assets/tiles/stsh_props_atlas.png,
stsh_details_atlas.png and props_meta.json (sizes, anchors, collision).
Run from the project root: python3 tools/gen_props.py
"""
import json
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from artlib import *  # noqa

T = 32
OUT = 'assets/tiles'
OUTLINE = np.array([16, 30, 18], dtype=np.float32)

OAK = ramp('#12301c', '#1a4224', '#25562a', '#346d30', '#468536', '#5e9d3c', '#7db648', '#a2cf5a', '#c8e47c')
OAK2 = ramp('#122a22', '#183a2a', '#1f4c30', '#2a6036', '#38743c', '#4c8a42', '#66a24c', '#88bb5a')
OAK3 = ramp('#2a3412', '#3c4818', '#52601e', '#6a7a24', '#86952e', '#a3ae3c', '#c2c652', '#dcdc78')
PINE = ramp('#0c2420', '#123228', '#1a4230', '#22543a', '#2e6844', '#3e7e4e', '#56965a', '#78ae68')
BIRCH = ramp('#24401c', '#335822', '#46702a', '#5c8a32', '#78a43c', '#98bc48', '#b8d25c', '#d6e67c')
BARK = ramp('#24160e', '#3a2416', '#55361f', '#6e4a2a', '#8a6038', '#a57a4a')
BIRCHBARK = ramp('#4a4844', '#8a8680', '#c4c0b6', '#e4e0d4', '#f6f4ec')
ROCK = ramp('#24232a', '#38363e', '#4e4c54', '#66636a', '#807c7e', '#9c9792', '#bab3a6', '#d6cfbf')
WOOD = ramp('#2e1c10', '#4a2e18', '#6a4424', '#8a5e32', '#a87a44', '#c49a5e')
HAY = ramp('#5a4214', '#7e601c', '#a28226', '#c4a238', '#dcc058', '#eedb88')
SHADOW = np.array([10, 24, 14], dtype=np.float32)


def shadow_ellipse(rgba, cx, cy, rx, ry, alpha=110):
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    a = np.clip((1.0 - d) * 2.2, 0, 1) * alpha
    a = np.where(bayer(h, w) < np.clip((1.0 - d) * 3, 0, 1) + 0.2, a, a * 0.6)
    m = a > rgba[..., 3]
    rgba[m, :3] = SHADOW
    rgba[m, 3] = a[m]


def clump_canopy(rgba, rng, cx, cy, rx, ry, pal, n=24, rmin=8, rmax=14, fruit=None, airy=False):
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    hf = np.full((h, w), -1.0)
    centers = []
    # edge ring for a scalloped silhouette + interior fill
    ring = int(n * 0.55)
    for i in range(ring):
        a = 2 * np.pi * i / ring + rng.uniform(-0.15, 0.15)
        rr = rng.uniform(0.70, 0.86)
        centers.append((cx + np.cos(a) * rx * rr, cy + np.sin(a) * ry * rr, rng.uniform(rmin, rmax)))
    for i in range(n - ring):
        a = rng.uniform(0, 2 * np.pi)
        rr = np.sqrt(rng.uniform(0, 0.45))
        centers.append((cx + np.cos(a) * rx * rr, cy + np.sin(a) * ry * rr, rng.uniform(rmin + 2, rmax + 3)))
    for (px, py, r) in centers:
        if airy and rng.random() < 0.15:
            continue
        d2 = (xx - px) ** 2 + (yy - py) ** 2
        z = np.sqrt(np.maximum(r * r - d2, 0))
        # higher towards the crown centre and top
        lift = (1 - np.hypot((px - cx) / rx, (py - cy) / ry)) * 9 - (py - cy) * 0.12
        zz = np.where(d2 < r * r, z + lift, -1)
        hf = np.maximum(hf, zz)
    mask = hf > 0
    leafn = big_noise(h, w, 1.6, rng)
    hf2 = np.where(mask, hf + (leafn - 0.5) * 3.2, 0)
    lit = lambert(hf2, 0.55)
    ao = np.clip(hf2 / (np.nanmax(hf2) + 1e-6), 0, 1)
    vert = (yy - (cy - ry)) / (2 * ry)
    v = 0.10 + 0.72 * np.clip(lit, 0, 1) ** 1.3 + 0.20 * ao - 0.18 * vert
    img = ramp_map(v, pal, 0.7)
    rgba[mask, :3] = img[mask]
    rgba[mask, 3] = 255
    # deep crevice line where clumps meet
    gy, gx = np.gradient(hf)
    crev = mask & (np.hypot(gx, gy) > 2.4) & (lit < 0.62)
    rgba[crev, :3] = pal[1]
    # highlight specks on the lit upper-left
    hl = mask & (lit > 0.9) & (leafn > 0.62)
    rgba[hl, :3] = pal[-1]
    if fruit is not None:
        for _ in range(9):
            for _t in range(30):
                fx, fy = int(rng.uniform(cx - rx * 0.8, cx + rx * 0.8)), int(rng.uniform(cy - ry * 0.6, cy + ry * 0.8))
                if 1 < fx < w - 2 and 1 < fy < h - 2 and mask[fy - 1:fy + 2, fx - 1:fx + 2].all():
                    rgba[fy, fx, :3] = fruit[0]; rgba[fy, fx + 1, :3] = fruit[1]
                    rgba[fy + 1, fx, :3] = fruit[1]; rgba[fy + 1, fx + 1, :3] = fruit[2]
                    rgba[fy - 1, fx, :3] = (255, 230, 220)
                    break
    outline(mask, rgba, OUTLINE)
    return mask


def trunk(rgba, rng, cx, top, base, wtop, wbase, pal=BARK, flare=6, birch=False):
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    t = np.clip((yy - top) / max(1, base - top), 0, 1)
    half = wtop / 2 + (wbase - wtop) / 2 * t + flare * np.clip((t - 0.78) / 0.22, 0, 1) ** 2
    m = (yy >= top) & (yy <= base) & (np.abs(xx - cx) <= half)
    u = (xx - cx) / np.maximum(half, 1)
    n = big_noise(h, w, 1.5, rng)
    streak = np.sin(xx * 1.7 + n * 4) * 0.08
    v = 0.62 - u * 0.38 + streak - 0.15 * (u > 0.55)
    img = ramp_map(v, pal, 0.5)
    rgba[m, :3] = img[m]
    rgba[m, 3] = 255
    if birch:
        for _ in range(9):
            y0 = int(rng.uniform(top + 2, base - 4))
            x0 = int(cx + rng.uniform(-wtop / 2, wtop / 2 - 2))
            for dx in range(rng.integers(2, 5)):
                if 0 <= x0 + dx < w and m[y0, x0 + dx]:
                    rgba[y0, x0 + dx, :3] = (40, 38, 36)
    # roots
    for side in (-1, 1):
        for k in range(3):
            rx = int(cx + side * (half[int(base), int(cx)] - k))
            ry = int(base - k)
            if 0 <= rx < w and 0 <= ry < h:
                rgba[ry, rx, :3] = pal[1]; rgba[ry, rx, 3] = 255
    outline(m, rgba, (22, 14, 8))
    return m


def oak(seed, pal, fruit=None):
    r = np.random.default_rng(seed)
    w, h = 96, 128
    rgba = blank(h, w)
    shadow_ellipse(rgba, 54, 117, 34, 9)
    trunk(rgba, r, 48, 66, 117, 13, 16, flare=6)
    clump_canopy(rgba, r, 48, 48, 41, 37, pal, n=30, rmin=9, rmax=14, fruit=fruit)
    return rgba


def pine(seed):
    r = np.random.default_rng(seed)
    w, h = 64, 128
    rgba = blank(h, w)
    shadow_ellipse(rgba, 36, 118, 22, 7)
    trunk(rgba, r, 32, 96, 118, 7, 9, flare=4)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    tiers = [(6, 40, 11), (22, 62, 17), (40, 84, 23), (60, 106, 29)]
    for (ty, by, half) in tiers:
        t = np.clip((yy - ty) / (by - ty), 0, 1)
        wob = np.sin(xx * 0.9 + ty) * 1.6 + np.sin(xx * 0.37 + ty * 2) * 1.2
        m = (yy >= ty) & (yy <= by + wob) & (np.abs(xx - 32) <= half * t ** 0.85 + 1)
        hf = np.where(m, (half * t ** 0.85 + 1 - np.abs(xx - 32)) * 0.9 + t * 4, 0)
        n = big_noise(h, w, 1.4, r)
        lit = lambert(hf + (n - 0.5) * 2.4, 0.7)
        v = 0.12 + 0.75 * np.clip(lit, 0, 1) ** 1.2 - 0.25 * t ** 3 + (xx < 32) * 0.05
        img = ramp_map(v, PINE, 0.7)
        rgba[m, :3] = img[m]
        rgba[m, 3] = 255
        # dark underside band of each tier
        under = m & (yy > by + wob - 2.5)
        rgba[under, :3] = PINE[0]
        hl = m & (lit > 0.93) & (n > 0.6)
        rgba[hl, :3] = PINE[-1]
    mask = rgba[..., 3] > 200
    outline(mask & (yy < 108), rgba, (8, 22, 18))
    return rgba


def birch(seed):
    r = np.random.default_rng(seed)
    w, h = 64, 128
    rgba = blank(h, w)
    shadow_ellipse(rgba, 36, 118, 22, 7)
    trunk(rgba, r, 31, 40, 118, 7, 9, pal=BIRCHBARK, flare=3, birch=True)
    clump_canopy(rgba, r, 32, 40, 27, 32, BIRCH, n=22, rmin=6, rmax=10, airy=True)
    return rgba


def bush(seed, w, h, cx, cy, rx, ry, pal=OAK, fruit=None, flowers=None):
    r = np.random.default_rng(seed)
    rgba = blank(h, w)
    shadow_ellipse(rgba, cx + 3, cy + ry - 1, rx * 0.95, ry * 0.45, 100)
    m = clump_canopy(rgba, r, cx, cy, rx, ry, pal, n=12 if w <= 32 else 20,
                     rmin=max(4, rx * 0.35), rmax=max(6, rx * 0.55), fruit=fruit)
    if flowers:
        for _ in range(12 if w <= 32 else 24):
            fx, fy = int(r.uniform(cx - rx * .8, cx + rx * .8)), int(r.uniform(cy - ry * .7, cy + ry * .6))
            if 0 < fx < w - 1 and 0 < fy < h - 1 and m[fy, fx]:
                rgba[fy, fx, :3] = flowers[0]
                rgba[fy, fx + 1, :3] = flowers[1]
                rgba[fy + 1, fx, :3] = flowers[1]
    return rgba


def rock(seed, w, h, cx, cy, rx, ry, moss=True):
    r = np.random.default_rng(seed)
    rgba = blank(h, w)
    shadow_ellipse(rgba, cx + 3, cy + ry * 0.55, rx * 1.05, ry * 0.5, 120)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    n = big_noise(h, w, 4, r)
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 + (n - 0.5) * 0.5
    m = d < 1
    hf = np.where(m, np.sqrt(np.clip(1 - d, 0, 1)) * ry * 1.4, 0)
    # facets
    fn = big_noise(h, w, 2.5, r)
    hf += np.where(m, np.round(fn * 4) * 1.2, 0)
    hf = gblur(hf, 0.8)
    lit = lambert(hf, 0.9)
    v = 0.05 + 0.85 * np.clip(lit, 0, 1) ** 1.4 - 0.2 * np.clip((yy - cy) / ry, 0, 1)
    img = ramp_map(v, ROCK, 0.6)
    rgba[m, :3] = img[m]
    rgba[m, 3] = 255
    if moss:
        mm = m & (yy < cy) & (n > 0.55) & (lit > 0.6)
        mimg = ramp_map(fn, ramp('#3c5a24', '#557a2c', '#6f9434', '#8cae44'), 0.6)
        rgba[mm, :3] = mimg[mm]
    lich = m & (big_noise(h, w, 1, r) > 0.9)
    rgba[lich, :3] = (196, 192, 140)
    outline(m, rgba, (20, 18, 24))
    return rgba


def stump(seed):
    r = np.random.default_rng(seed)
    rgba = blank(32, 32)
    shadow_ellipse(rgba, 18, 24, 12, 5)
    yy, xx = np.mgrid[0:32, 0:32].astype(float)
    side = (np.abs(xx - 16) <= 9) & (yy >= 14) & (yy <= 24)
    u = (xx - 16) / 9
    img = ramp_map(0.6 - u * 0.4 + np.sin(xx * 1.9) * 0.06, BARK, 0.5)
    rgba[side, :3] = img[side]; rgba[side, 3] = 255
    top = ((xx - 16) / 9) ** 2 + ((yy - 14) / 4.5) ** 2 < 1
    rings = np.sqrt(((xx - 16) / 9) ** 2 + ((yy - 14) / 4.5) ** 2)
    img2 = ramp_map(0.75 - 0.25 * (np.sin(rings * 14) > 0.4) - rings * 0.2, WOOD, 0.4)
    rgba[top, :3] = img2[top]; rgba[top, 3] = 255
    rgba[13:15, 16, :3] = WOOD[1]
    outline(side | top, rgba, (22, 14, 8))
    return rgba


def log(seed):
    r = np.random.default_rng(seed)
    rgba = blank(32, 64)
    shadow_ellipse(rgba, 34, 24, 28, 5)
    yy, xx = np.mgrid[0:32, 0:64].astype(float)
    body = (xx >= 6) & (xx <= 54) & (np.abs(yy - 17) <= 6)
    v = 0.65 - (yy - 17) / 6 * 0.35 + np.sin(xx * 0.8 + yy) * 0.05
    img = ramp_map(v, BARK, 0.5)
    rgba[body, :3] = img[body]; rgba[body, 3] = 255
    end = ((xx - 55) / 3.5) ** 2 + ((yy - 17) / 6.5) ** 2 < 1
    rr = np.sqrt(((xx - 55) / 3.5) ** 2 + ((yy - 17) / 6.5) ** 2)
    img2 = ramp_map(0.8 - 0.3 * (np.sin(rr * 12) > 0.3), WOOD, 0.4)
    rgba[end, :3] = img2[end]; rgba[end, 3] = 255
    for x0 in (16, 34):  # moss tufts
        rgba[10:12, x0:x0 + 5, :3] = (86, 130, 52); rgba[10:12, x0:x0 + 5, 3] = 255
        rgba[10, x0 + 1:x0 + 3, :3] = (130, 172, 70)
    outline(body | end | (rgba[..., 3] > 250), rgba, (22, 14, 8))
    return rgba


def fence(kind):
    """kind: 'h_l','h_m','h_r','v','post'."""
    rgba = blank(32, 32)
    def post(x, y0=8, y1=26):
        rgba[y0 + 2:y1 + 2, x - 1:x + 4, :3] = SHADOW; rgba[y0 + 2:y1 + 2, x - 1:x + 4, 3] = 80
        for xx in range(x - 2, x + 3):
            sh = WOOD[4] if xx < x else WOOD[3] if xx == x else WOOD[2]
            rgba[y0:y1, xx, :3] = sh; rgba[y0:y1, xx, 3] = 255
        rgba[y0, x - 2:x + 3, :3] = WOOD[5]
        rgba[y0 - 1, x - 1:x + 2, :3] = WOOD[5]; rgba[y0 - 1, x - 1:x + 2, 3] = 255
        rgba[y0:y1, x - 3, :3] = OUTLINE * 0 + (34, 20, 10); rgba[y0:y1, x - 3, 3] = 255
        rgba[y0:y1, x + 3, :3] = (34, 20, 10); rgba[y0:y1, x + 3, 3] = 255
        rgba[y1, x - 2:x + 3, :3] = (34, 20, 10); rgba[y1, x - 2:x + 3, 3] = 255
    def rail(x0, x1, y):
        rgba[y + 3:y + 5, x0:x1, :3] = SHADOW; rgba[y + 3:y + 5, x0:x1, 3] = 70
        rgba[y - 1, x0:x1, :3] = (34, 20, 10); rgba[y - 1, x0:x1, 3] = 255
        rgba[y, x0:x1, :3] = WOOD[5]; rgba[y, x0:x1, 3] = 255
        rgba[y + 1, x0:x1, :3] = WOOD[3]; rgba[y + 1, x0:x1, 3] = 255
        rgba[y + 2, x0:x1, :3] = (34, 20, 10); rgba[y + 2, x0:x1, 3] = 255
    if kind.startswith('h'):
        x0 = 16 if kind == 'h_l' else 0
        x1 = 16 if kind == 'h_r' else 32
        rail(x0, x1, 12); rail(x0, x1, 19)
        post(16)
    elif kind == 'v':
        for xx_, c in ((14, (34, 20, 10)), (15, WOOD[4]), (16, WOOD[3]), (17, WOOD[2]), (18, (34, 20, 10))):
            rgba[0:32, xx_, :3] = c; rgba[0:32, xx_, 3] = 255
        post(16, 10, 26)
    else:
        post(16)
    return rgba


def hay(seed):
    r = np.random.default_rng(seed)
    rgba = blank(32, 32)
    shadow_ellipse(rgba, 18, 26, 14, 5)
    yy, xx = np.mgrid[0:32, 0:32].astype(float)
    body = (np.abs(xx - 16) <= 12) & (yy >= 9) & (yy <= 26)
    face = ((xx - 16) / 12) ** 2 + ((yy - 10) / 5) ** 2 < 1
    n = big_noise(32, 32, 1, r)
    v = 0.62 - (xx - 16) / 12 * 0.3 + (n - 0.5) * 0.3
    img = ramp_map(v, HAY, 0.7)
    rgba[body, :3] = img[body]; rgba[body, 3] = 255
    rr = np.sqrt(((xx - 16) / 12) ** 2 + ((yy - 10) / 5) ** 2)
    img2 = ramp_map(0.85 - 0.3 * (np.sin(rr * 13 + np.arctan2(yy - 10, xx - 16)) > 0.5), HAY, 0.4)
    rgba[face, :3] = img2[face]; rgba[face, 3] = 255
    rgba[17:19, 4:29][(rgba[17:19, 4:29, 3] > 0)] = np.array([140, 60, 40, 255.0])  # twine
    outline(body | face, rgba, (40, 26, 8))
    return rgba


def trough():
    rgba = blank(32, 64)
    shadow_ellipse(rgba, 34, 25, 28, 5)
    rgba[10:24, 6:58, :3] = WOOD[2]; rgba[10:24, 6:58, 3] = 255
    rgba[10:12, 6:58, :3] = WOOD[4]
    rgba[12:18, 9:55, :3] = (52, 110, 170)
    rgba[12, 9:55, :3] = (40, 80, 130)
    rgba[14, 14:22, :3] = (150, 205, 235); rgba[16, 34:40, :3] = (150, 205, 235)
    rgba[18:24, 6:58, :3] = WOOD[3]
    for x in range(10, 58, 9):
        rgba[18:24, x, :3] = WOOD[1]
    rgba[24:27, 8:11, :3] = WOOD[1]; rgba[24:27, 8:11, 3] = 255
    rgba[24:27, 53:56, :3] = WOOD[1]; rgba[24:27, 53:56, 3] = 255
    outline(rgba[..., 3] > 250, rgba, (34, 20, 10))
    return rgba


def sign():
    rgba = blank(32, 32)
    shadow_ellipse(rgba, 18, 26, 8, 3)
    rgba[14:26, 15:18, :3] = WOOD[3]; rgba[14:26, 15:18, 3] = 255
    rgba[14:26, 15, :3] = WOOD[4]
    rgba[5:15, 6:26, :3] = WOOD[4]; rgba[5:15, 6:26, 3] = 255
    rgba[5, 6:26, :3] = WOOD[5]
    rgba[13:15, 6:26, :3] = WOOD[2]
    for y in (8, 11):
        rgba[y, 9:23, :3] = WOOD[1]
    outline(rgba[..., 3] > 250, rgba, (34, 20, 10))
    return rgba


# ---------------------------------------------------------------- details (flat)

def detail(kind, seed):
    r = np.random.default_rng(seed)
    rgba = blank(32, 32)
    G = ramp('#1f4f2b', '#2b6331', '#3a7835', '#4c8c3a', '#63a241', '#7fb84b', '#a3cf5c', '#c6e27a')

    def put(x, y, c, a=255):
        if 0 <= x < 32 and 0 <= y < 32:
            rgba[y, x, :3] = c; rgba[y, x, 3] = a
    if kind.startswith('tuft') or kind == 'tall':
        n = 9 if kind != 'tall' else 13
        for k in range(n):
            x = 16 + int(r.normal(0, 3.2))
            hgt = r.integers(4, 9 if kind != 'tall' else 13)
            lean = r.uniform(-0.35, 0.35)
            for i in range(hgt):
                t = i / max(1, hgt - 1)
                put(int(round(x + lean * i)), 24 - i, G[min(7, int(1 + t * 6.5))])
        for dx in range(-4, 5):
            put(16 + dx, 25, (20, 50, 26), 120)
    elif kind.startswith('flower'):
        cols = {'flower_y': ((246, 214, 70), (190, 140, 30)), 'flower_w': ((250, 250, 245), (180, 190, 210)),
                'flower_r': ((222, 60, 52), (140, 28, 30)), 'flower_p': ((176, 126, 236), (96, 64, 168))}[kind]
        for _ in range(r.integers(4, 7)):
            x, y = r.integers(5, 27), r.integers(6, 27)
            put(x, y + 1, G[1]); put(x, y + 2, G[2]); put(x + 1, y + 2, G[3])
            put(x - 1, y, cols[0]); put(x + 1, y, cols[0]); put(x, y - 1, cols[0]); put(x, y + 1, cols[1])
            put(x, y, (255, 236, 120) if kind != 'flower_y' else (200, 110, 30))
    elif kind.startswith('mush'):
        cap = ((200, 40, 36), (240, 90, 70)) if kind == 'mush_r' else ((150, 100, 60), (190, 140, 90))
        for (x, y, s) in ((13, 20, 3), (19, 23, 2), (17, 17, 2)):
            for dx in range(-s, s + 1):
                put(x + dx, y - 1, cap[0]); put(x + dx, y - 2, cap[1] if dx < 0 else cap[0])
            put(x, y - 3, cap[1])
            put(x, y, (236, 226, 200)); put(x, y + 1, (200, 186, 160))
            if kind == 'mush_r':
                put(x - 1, y - 2, (255, 255, 255))
            put(x + 1, y + 1, (20, 40, 20), 120)
    elif kind.startswith('leaves'):
        L = ramp('#5a3a1e', '#7a4f24', '#9c6a2c', '#b9853a', '#cf8a2e', '#a34a22')
        for _ in range(16 if kind == 'leaves_a' else 24):
            x, y = r.integers(3, 29), r.integers(3, 29)
            c = L[r.integers(0, 6)]
            put(x, y, c, 255); put(x + 1, y, c * 0.85, 255)
    elif kind == 'twig':
        x, y = 8, 18
        for i in range(16):
            put(x + i, y - i // 4, (74, 48, 26)); put(x + i, y - i // 4 + 1, (40, 26, 14))
        for i in range(4):
            put(x + 9 + i, y - 3 - i, (90, 60, 32))
    elif kind == 'pebbles':
        for _ in range(5):
            x, y = r.integers(5, 26), r.integers(6, 26)
            put(x, y, (190, 182, 168)); put(x + 1, y, (150, 144, 136)); put(x, y + 1, (110, 106, 104)); put(x + 1, y + 1, (80, 76, 78))
            put(x + 2, y + 1, (20, 40, 20), 110)
    elif kind.startswith('fern'):
        F = ramp('#16351e', '#1f4a26', '#2d6230', '#3f7c38', '#5a9a44')
        for a in np.linspace(-2.5, -0.6, 6 if kind == 'fern' else 5):
            ln = r.integers(8, 13)
            for i in range(ln):
                x = 16 + np.cos(a) * i
                y = 24 + np.sin(a) * i + (i * i) * 0.04
                c = F[min(4, 1 + i * 4 // ln)]
                put(int(x), int(y), c)
                if i % 2 == 0 and i > 2:
                    put(int(x + np.cos(a + 1.4) * 2), int(y + np.sin(a + 1.4) * 2), F[2])
                    put(int(x + np.cos(a - 1.4) * 2), int(y + np.sin(a - 1.4) * 2), F[3])
    elif kind.startswith('reed'):
        R = ramp('#2a4a20', '#3c6428', '#5a8434', '#86a848', '#b0c464')
        for k in range(8 if kind == 'reed_a' else 6):
            x = r.integers(8, 25)
            hgt = r.integers(10, 20)
            for i in range(hgt):
                put(x + (i // 7) * (1 if k % 2 else -1), 27 - i, R[min(4, 1 + i * 4 // hgt)])
            if kind == 'reed_b' and k % 2 == 0:
                for i in range(4):
                    put(x + (hgt // 7) * (1 if k % 2 else -1), 27 - hgt + i, (110, 64, 34) if i else (150, 96, 50))
    elif kind.startswith('lily'):
        P = ramp('#1e4a26', '#2d6630', '#438838', '#62a648')
        for (x, y, s) in ((12, 14, 5), (21, 20, 4), (14, 23, 3))[: (3 if kind == 'lily_b' else 2)]:
            yy, xx = np.mgrid[0:32, 0:32]
            m = ((xx - x) ** 2 + ((yy - y) * 1.3) ** 2 < s * s) & ~((xx > x) & (np.abs(yy - y) <= (xx - x) * 0.35))
            v = 0.7 - (yy - y) / (2 * s) * 0.6 - (xx - x) / (2 * s) * 0.2
            img = ramp_map(v, P, 0.5)
            rgba[m, :3] = img[m]; rgba[m, 3] = 255
            o = np.zeros_like(m); o[1:, :] |= m[:-1, :]; o &= ~m
            rgba[o, :3] = (16, 40, 70); rgba[o, 3] = 160
        if kind == 'lily_f':
            for dx, dy, c in ((0, 0, (255, 240, 120)), (-1, 0, (250, 170, 200)), (1, 0, (250, 170, 200)), (0, -1, (255, 220, 236)), (0, 1, (230, 140, 180))):
                put(12 + dx, 13 + dy, c)
    elif kind == 'roots':
        for k in range(4):
            x, y = 16, 12
            a = r.uniform(0, np.pi)
            for i in range(10):
                x += np.cos(a); y += np.sin(a) * 0.6 + 0.4
                put(int(x), int(y), (70, 46, 24)); put(int(x), int(y) + 1, (30, 20, 12))
    elif kind == 'shore_stones':
        for _ in range(4):
            x, y = r.integers(6, 25), r.integers(8, 25)
            for dx in range(3):
                put(x + dx, y, (160, 156, 150)); put(x + dx, y + 1, (110, 106, 106))
            put(x, y - 1, (200, 196, 186)); put(x + 1, y - 1, (200, 196, 186))
            put(x + 1, y + 2, (20, 30, 40), 110)
    return rgba


DETAILS = ['tuft_a', 'tuft_b', 'tall', 'flower_y', 'flower_w', 'flower_r', 'flower_p', 'mush_r', 'mush_b',
           'leaves_a', 'leaves_b', 'twig', 'pebbles', 'fern', 'fern2', 'roots',
           'reed_a', 'reed_b', 'lily_a', 'lily_b', 'lily_f', 'shore_stones']

# ---------------------------------------------------------------- pack
PROPS = []  # name, atlas cell, size cells, anchor px in image, collision polys relative to anchor


def ell(cx, cy, rx, ry, n=10):
    return [[round(cx + np.cos(2 * np.pi * i / n) * rx, 1), round(cy + np.sin(2 * np.pi * i / n) * ry, 1)] for i in range(n)]


atlas = blank(T * 6, T * 16)


def place(name, img, cell, anchor, polys, ysort=0):
    h, w = img.shape[:2]
    x, y = cell
    atlas[y * T:y * T + h, x * T:x * T + w] = img
    PROPS.append(dict(name=name, cell=list(cell), size=[w // T, h // T], anchor=list(anchor), polys=polys, ysort=ysort))


TRUNK = [ell(0, 0, 11, 6)]
place('oak_a', oak(11, OAK), (0, 0), (48, 116), TRUNK)
place('oak_b', oak(12, OAK2), (3, 0), (48, 116), TRUNK)
place('oak_c', oak(13, OAK3), (6, 0), (48, 116), TRUNK)
place('oak_fruit', oak(14, OAK, fruit=((200, 40, 40), (150, 20, 26), (90, 10, 20))), (9, 0), (48, 116), TRUNK)
place('pine_a', pine(21), (12, 0), (32, 117), [ell(0, 0, 7, 5)])
place('birch_a', birch(31), (14, 0), (31, 117), [ell(0, 0, 6, 4)])
# row 4
place('bush_a', bush(41, 32, 32, 16, 18, 13, 10), (0, 4), (16, 26), [], ysort=0)
place('bush_b', bush(42, 32, 32, 16, 18, 12, 9, pal=OAK2, fruit=((60, 80, 200), (40, 50, 140), (20, 24, 80))), (1, 4), (16, 26), [])
place('bush_c', bush(43, 32, 32, 16, 18, 13, 10, pal=OAK, flowers=((250, 180, 210), (220, 110, 160))), (2, 4), (16, 26), [])
place('bush_d', bush(44, 32, 32, 16, 19, 12, 9, pal=OAK3, flowers=((255, 255, 250), (220, 220, 200))), (3, 4), (16, 26), [])
place('bush_big', bush(45, 64, 64, 32, 34, 27, 20, pal=OAK), (4, 4), (32, 52), [])
place('boulder', rock(51, 64, 64, 32, 38, 25, 18), (6, 4), (32, 46), [ell(0, -2, 24, 11)])
place('rock_a', rock(52, 32, 32, 16, 18, 11, 8), (8, 4), (16, 22), [ell(0, -2, 10, 5, 8)])
place('rock_b', rock(53, 32, 32, 16, 19, 9, 7, moss=False), (9, 4), (16, 22), [ell(0, -2, 8, 5, 8)])
place('rock_c', rock(54, 32, 32, 16, 19, 12, 7), (10, 4), (16, 22), [ell(0, -2, 11, 5, 8)])
place('log', log(61), (11, 4), (32, 20), [[[-26, -6], [24, -6], [24, 4], [-26, 4]]])
place('fence_h_l', fence('h_l'), (13, 4), (16, 20), [[[-3, -10], [16, -10], [16, 2], [-3, 2]]])
place('fence_h_m', fence('h_m'), (14, 4), (16, 20), [[[-16, -10], [16, -10], [16, 2], [-16, 2]]])
place('fence_h_r', fence('h_r'), (15, 4), (16, 20), [[[-16, -10], [3, -10], [3, 2], [-16, 2]]])
place('fence_v', fence('v'), (8, 5), (16, 16), [[[-4, -16], [4, -16], [4, 16], [-4, 16]]])
place('fence_post', fence('post'), (9, 5), (16, 22), [ell(0, -2, 4, 4, 6)])
place('stump', stump(71), (10, 5), (16, 20), [ell(0, 0, 9, 5, 8)])
place('hay', hay(72), (11, 5), (16, 22), [ell(0, -2, 12, 6, 8)])
place('sign', sign(), (12, 5), (16, 24), [ell(0, 0, 3, 3, 6)])
place('trough', trough(), (13, 5), (32, 22), [[[-26, -10], [26, -10], [26, 3], [-26, 3]]])

to_img(atlas).save(f'{OUT}/stsh_props_atlas.png')
det = blank(T * 2, T * 16)
for i, k in enumerate(DETAILS):
    det[(i // 16) * T:(i // 16 + 1) * T, (i % 16) * T:(i % 16 + 1) * T] = detail(k, 900 + i)
to_img(det).save(f'{OUT}/stsh_details_atlas.png')
with open(f'{OUT}/props_meta.json', 'w') as fh:
    json.dump(dict(props=PROPS, details=[dict(name=k, cell=[i % 16, i // 16]) for i, k in enumerate(DETAILS)]), fh, indent=1)
print('props written', len(PROPS))
