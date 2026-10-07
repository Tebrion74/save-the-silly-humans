"""Build 008 terrain atlases: grass variants, stone wall autotile, corner-matched
transition overlays (dirt, path, forest floor) and animated pond water.

Corner mask bits (per cell): TL=1, TR=2, BL=4, BR=8 (a bit is set when that
corner vertex belongs to the overlay terrain). Run from the project root:
    python3 tools/gen_terrain.py
"""
import json
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from artlib import *  # noqa

T = 32
OUT = 'assets/tiles'
rng = np.random.default_rng(8008)

GRASS = ramp('#163d26', '#1f4f2b', '#2b6331', '#3a7835', '#4c8c3a', '#63a241', '#7fb84b', '#a3cf5c', '#c6e27a')
DIRT = ramp('#3a2416', '#55361f', '#6e4829', '#875a33', '#a06e40', '#b88452', '#cf9f6a')
PATH = ramp('#6a4e33', '#86663f', '#a2804f', '#b99862', '#cdae76', '#ddc28d', '#ead6a8')
FOREST = ramp('#17321e', '#1f3f23', '#284a28', '#325a2c', '#3f6a31', '#4f7a36')
LEAF = ramp('#5a3a1e', '#7a4f24', '#9c6a2c', '#b9853a')
WATER = ramp('#163663', '#1b4580', '#215699', '#2a68ae', '#357cc0', '#4a95d0', '#67b1de', '#8dcbe8')
FOAM = hexc('#d9f1f7')
MUD = ramp('#3b2a1c', '#4d3824', '#62482e', '#7a5c3a')
STONE = ramp('#2c2a30', '#413f47', '#57555d', '#6e6b71', '#878380', '#a39d92', '#c2baa8')
MOSS = ramp('#2f4a22', '#456a2c', '#5f8a36')

# ----------------------------------------------------------------- grass
grass_base_noise = periodic_noise(T, 10, rng)
grass_fine = periodic_noise(T, 3, rng)


def grass_tile(seed, kind):
    r = np.random.default_rng(seed)
    v = 0.40 + (grass_base_noise - 0.5) * 0.22 + (grass_fine - 0.5) * 0.10
    v = v.copy()
    # blades: dark root -> light tip, wrapped so the tile stays seamless
    nb = 70 if kind != 'short' else 50
    for _ in range(nb):
        x, y = r.integers(0, T), r.integers(0, T)
        ln = r.integers(2, 6)
        lean = r.choice([-1, 0, 0, 1])
        base = r.uniform(0.18, 0.30)
        tip = r.uniform(0.55, 0.78)
        for i in range(ln):
            t = i / max(1, ln - 1)
            px = (x + int(round(lean * t * 1.5))) % T
            py = (y - i) % T
            v[py, px] = base + (tip - base) * t
    img = ramp_map(v, GRASS, 0.6)
    rgba = np.concatenate([img, np.full((T, T, 1), 255.0)], axis=2)

    def put(x, y, c):
        if 0 <= x < T and 0 <= y < T:
            rgba[y, x, :3] = hexc(c) if isinstance(c, str) else c

    if kind == 'tuft':
        for _ in range(r.integers(1, 3)):
            cx, cy = r.integers(7, 25), r.integers(10, 26)
            for k in range(-3, 4):
                h = 6 - abs(k) + r.integers(0, 2)
                for i in range(h):
                    t = i / max(1, h - 1)
                    c = GRASS[int(1 + t * 6)]
                    put(cx + k + (k * i) // 6, cy - i, c)
            put(cx - 3, cy + 1, GRASS[1]); put(cx + 3, cy + 1, GRASS[1])
    elif kind in ('flowers', 'flowers2', 'daisy'):
        pal = {'flowers': [('#f4e04d', '#b88a1c'), ('#ffffff', '#b8c4d8')],
               'flowers2': [('#e86a9a', '#9a2f5c'), ('#b48cf0', '#6044a8')],
               'daisy': [('#ffffff', '#c0c8d8')]}[kind]
        for _ in range(r.integers(3, 6)):
            cx, cy = r.integers(4, 28), r.integers(4, 28)
            pc, sc = pal[r.integers(0, len(pal))]
            put(cx, cy + 1, GRASS[2]); put(cx, cy + 2, GRASS[3])
            put(cx - 1, cy, pc); put(cx + 1, cy, pc); put(cx, cy - 1, pc)
            put(cx, cy + 1 - 1 + 1, sc)
            put(cx, cy, '#f8c040' if pc == '#ffffff' else '#fff2a0')
            put(cx + 1, cy + 1, sc)
    elif kind == 'clover':
        for _ in range(r.integers(2, 4)):
            cx, cy = r.integers(5, 27), r.integers(5, 27)
            for dx, dy in ((0, -1), (-1, 0), (1, 0)):
                put(cx + dx, cy + dy, GRASS[7]); put(cx + dx * 2, cy + dy * 2 + (1 if dy == 0 else 0), GRASS[6])
            put(cx, cy, GRASS[4]); put(cx, cy + 1, GRASS[2])
    elif kind == 'pebble':
        cx, cy = r.integers(8, 24), r.integers(8, 24)
        for dx, dy, c in ((0, 0, '#a39d92'), (1, 0, '#c2baa8'), (0, 1, '#6e6b71'), (1, 1, '#57555d'), (-1, 1, '#2b4a26'), (2, 1, '#2b4a26')):
            put(cx + dx, cy + dy, c)
    elif kind == 'dark':
        pass
    elif kind == 'light':
        pass
    if kind == 'dark':
        rgba[..., :3] *= 0.93
    if kind == 'light':
        rgba[..., :3] = np.minimum(255, rgba[..., :3] * 1.05)
    return rgba


GRASS_KINDS = ['plain', 'plain', 'plain', 'short', 'tuft', 'tuft', 'flowers', 'flowers2',
               'daisy', 'clover', 'pebble', 'plain', 'dark', 'light', 'tuft', 'plain']

# ----------------------------------------------------------------- corner fields

def corner_field(mask, sigma, noise, amp):
    """Metaball field over the 64x64 canvas (tile px -16..48) from the tile's
    four corner vertices. The kernel has compact support (32px), so inside the
    tile the field equals the global field over the whole vertex grid: edges
    always match neighbouring tiles, while shapes round off with a ~17px radius
    (diagonal staircases become smooth, wavy shorelines). 'sigma' is unused and
    kept for call compatibility."""
    yy, xx = np.mgrid[0:64, 0:64].astype(float) + 0.5
    f = np.zeros((64, 64))
    for bit, (vx, vy) in ((1, (16, 16)), (2, (48, 16)), (4, (16, 48)), (8, (48, 48))):
        if mask & bit:
            u = ((xx - vx) ** 2 + (yy - vy) ** 2) / (32.0 * 32.0)
            f += np.where(u < 1, (1 - u) ** 2, 0)
    big = np.tile(noise, (2, 2))
    big = np.roll(big, (16, 16), axis=(0, 1))
    return f + (big - 0.5) * amp, f


def overlay_tile(mask, kind, variant=0):
    cfg = {
        'dirt': dict(sigma=4.8, amp=0.30, noise=dirt_edge_noise),
        'path': dict(sigma=4.8, amp=0.22, noise=path_edge_noise),
        'forest': dict(sigma=5.0, amp=0.40, noise=forest_edge_noise),
    }[kind]
    if mask == 0:
        return blank(T, T)
    f64, _ = corner_field(mask, cfg['sigma'], cfg['noise'], cfg['amp'])
    f = f64[16:48, 16:48]
    out = blank(T, T)
    tex = interior[kind][variant] if mask == 15 else interior[kind][0]
    if kind in ('dirt', 'path'):
        inside = f > 0.5
        out[inside, :3] = tex[inside, :3]
        out[inside, 3] = 255
        # shaded inner rim (ground sits slightly below the turf)
        sh_up = f64[16 - 2:48 - 2, 16 - 2:48 - 2]
        rim = inside & (sh_up < 0.5)
        out[rim, :3] *= 0.72
        rim2 = inside & (f < 0.58)
        out[rim2, :3] *= 0.88
        # grass fringe hanging over the edge
        edge = inside & (f < 0.60) & (fringe_noise > 0.62)
        out[edge, :3] = GRASS[3]
        tip = inside & (f < 0.56) & (fringe_noise > 0.75)
        out[tip, :3] = GRASS[5]
        # dark turf lip just outside the edge
        lip = (~inside) & (f > 0.44)
        out[lip, :3] = GRASS[1]
        out[lip, 3] = 200
    else:  # forest floor: soft dithered blend
        a = smoothstep(0.30, 0.70, f)
        keep = a > bayer(T, T)
        out[keep, :3] = tex[keep, :3]
        out[keep, 3] = 255
    return out


def make_interior(kind, variant):
    r = np.random.default_rng(1000 + variant * 7 + hash(kind) % 97)
    if kind == 'dirt':
        v = 0.45 + (periodic_noise(T, 6, r) - 0.5) * 0.45 + (periodic_noise(T, 2, r) - 0.5) * 0.2
        img = ramp_map(v, DIRT, 0.7)
        rgba = np.concatenate([img, np.full((T, T, 1), 255.0)], axis=2)
        npb = [5, 9, 3, 7][variant]
        for _ in range(npb):
            x, y = r.integers(0, T), r.integers(0, T)
            s = r.integers(1, 3)
            for dy in range(s):
                for dx in range(s + 1):
                    rgba[(y + dy) % T, (x + dx) % T, :3] = DIRT[6] if dy == 0 else DIRT[5]
            for dx in range(s + 1):
                rgba[(y + s) % T, (x + dx) % T, :3] = DIRT[1]
        if variant == 2:  # hoof prints
            for _ in range(4):
                x, y = r.integers(2, 28), r.integers(2, 28)
                for dx, dy in ((0, 0), (2, 0)):
                    rgba[y, x + dx, :3] = DIRT[1]; rgba[y + 1, x + dx, :3] = DIRT[2]
        return rgba
    if kind == 'path':
        v = 0.52 + (periodic_noise(T, 7, r) - 0.5) * 0.30 + (periodic_noise(T, 2, r) - 0.5) * 0.18
        img = ramp_map(v, PATH, 0.6)
        rgba = np.concatenate([img, np.full((T, T, 1), 255.0)], axis=2)
        for _ in range([6, 3, 10, 5][variant]):
            x, y = r.integers(0, T), r.integers(0, T)
            rgba[y, x, :3] = PATH[6]
            rgba[(y + 1) % T, x, :3] = PATH[1]
            if r.random() < 0.5:
                rgba[y, (x + 1) % T, :3] = PATH[5]
                rgba[(y + 1) % T, (x + 1) % T, :3] = PATH[2]
        if variant == 3:
            for _ in range(2):
                x, y = r.integers(4, 26), r.integers(4, 26)
                for i in range(4):
                    rgba[y + i // 2, x + i, :3] = PATH[2]
        return rgba
    if kind == 'forest':
        v = 0.48 + (periodic_noise(T, 6, r) - 0.5) * 0.5 + (periodic_noise(T, 2, r) - 0.5) * 0.25
        img = ramp_map(v, FOREST, 0.7)
        rgba = np.concatenate([img, np.full((T, T, 1), 255.0)], axis=2)
        for _ in range([14, 22, 10, 18][variant]):
            x, y = r.integers(0, T), r.integers(0, T)
            c = LEAF[r.integers(0, 4)]
            rgba[y, x, :3] = c
            if r.random() < 0.6:
                rgba[y, (x + 1) % T, :3] = LEAF[max(0, r.integers(0, 4) - 1)]
        for _ in range(10):
            x, y = r.integers(0, T), r.integers(0, T)
            rgba[y, x, :3] = FOREST[5]
            rgba[(y - 1) % T, x, :3] = GRASS[4]
        return rgba


dirt_edge_noise = periodic_noise(T, 6, rng, octaves=2)
path_edge_noise = periodic_noise(T, 7, rng, octaves=2)
forest_edge_noise = periodic_noise(T, 6, rng, octaves=2)
fringe_noise = periodic_noise(T, 1.2, rng)
interior = {k: [make_interior(k, v) for v in range(4)] for k in ('dirt', 'path', 'forest')}

# ----------------------------------------------------------------- water
water_edge_noise = periodic_noise(T, 5, rng)
water_tex_noise = periodic_noise(T, 8, rng)
water_tex_noise2 = periodic_noise(T, 3, rng)
water_edge_noise = periodic_noise(T, 6, rng, octaves=2)
FRAMES = 4


def water_tile(mask, frame, variant=0):
    out = blank(T, T)
    if mask == 0:
        return out
    f64, b64 = corner_field(mask, 4.6, water_edge_noise, 0.18)
    f = f64[16:48, 16:48]
    deep = np.clip((b64[16:48, 16:48] - 0.55) / 0.4, 0, 1)
    yy, xx = np.mgrid[0:T, 0:T]
    ph = 2 * np.pi * frame / FRAMES
    water = f > 0.5
    bank = (~water) & (f > 0.34)
    v = 0.66 - deep * 0.50 + (water_tex_noise - 0.5) * 0.16
    # soft rolling bands
    band = np.sin(2 * np.pi * (yy * 2 + 3 * np.sin(2 * np.pi * xx / T + ph) ) / T + ph)
    v += band * 0.035
    up = f64[16 - 3:48 - 3, 16 - 3:48 - 3]
    v = v - np.where(up < 0.5, 0.14, 0.0)
    img = ramp_map(v, WATER, 0.45, ox=frame, oy=0)
    out[water, :3] = img[water]
    out[water, 3] = 255
    # ripple dashes that drift with the frame
    rip = np.sin(2 * np.pi * (yy * 3) / T + water_tex_noise * 7.0 + 1.5 * np.sin(2 * np.pi * xx / T) - ph)
    dash = water & (rip > 0.93) & (water_tex_noise2 > 0.52) & (deep > 0.25)
    out[dash, :3] = WATER[7]
    dash2 = water & (rip > 0.93) & (water_tex_noise2 > 0.40) & (water_tex_noise2 <= 0.52) & (deep > 0.25)
    out[dash2, :3] = WATER[5]
    rr = np.random.default_rng(500 + variant * 13 + frame)
    for _ in range(2 if mask == 15 else 0):
        x, y = rr.integers(2, T - 3), rr.integers(2, T - 2)
        if deep[y, x] > 0.5:
            out[y, x, :3] = (255, 255, 255)
            out[y, x + 1, :3] = WATER[7]
            out[y, x - 1, :3] = WATER[7]
            out[y - 1, x, :3] = WATER[6]; out[y + 1, x, :3] = WATER[6]
    # foam line at the shore, breathing with the frame
    foam_w = 0.05 + 0.03 * np.sin(ph + water_edge_noise * 6)
    foam = water & (f < 0.5 + foam_w)
    out[foam, :3] = FOAM
    foam2 = water & (f >= 0.5 + foam_w) & (f < 0.5 + foam_w + 0.06)
    out[foam2, :3] = WATER[6]
    bv = smoothstep(0.34, 0.5, f)
    bimg = ramp_map(1 - bv, MUD, 0.6)
    out[bank, :3] = bimg[bank]
    out[bank, 3] = 255
    lip = bank & (f < 0.39)
    out[lip, :3] = GRASS[1]
    turf = (~water) & (~bank) & (f > 0.27) & (bayer(T, T) < 0.5)
    out[turf, :3] = GRASS[2]
    out[turf, 3] = 210
    return out


def water_collision(mask, inset=6):
    """Polygons (tile-centre coords) for each water quadrant, inset where the
    neighbouring quadrant inside this tile is land."""
    quads = {1: (0, 0), 2: (1, 0), 4: (0, 1), 8: (1, 1)}
    polys = []
    for bit, (qx, qy) in quads.items():
        if not mask & bit:
            continue
        x0, x1 = (-16, 0) if qx == 0 else (0, 16)
        y0, y1 = (-16, 0) if qy == 0 else (0, 16)
        hbit = {1: 2, 2: 1, 4: 8, 8: 4}[bit]   # horizontal neighbour quadrant
        vbit = {1: 4, 2: 8, 4: 1, 8: 2}[bit]   # vertical neighbour quadrant
        if not mask & hbit:
            if qx == 0: x1 -= inset
            else: x0 += inset
        if not mask & vbit:
            if qy == 0: y1 -= inset
            else: y0 += inset
        polys.append([[x0, y0], [x1, y0], [x1, y1], [x0, y1]])
    return polys

# ----------------------------------------------------------------- wall (4-neighbour)

def wall_tile(m):
    """m bits: N=1, E=2, S=4, W=8 (connected wall neighbours)."""
    rgba = grass_tile(77, 'short')
    region = np.zeros((T, T), bool)
    region[3:29, 3:29] = True
    if m & 1: region[0:16, 3:29] = True
    if m & 4: region[16:32, 3:29] = True
    if m & 8: region[3:29, 0:16] = True
    if m & 2: region[3:29, 16:32] = True
    # drop shadow on turf (down-right)
    sh = np.zeros_like(region)
    sh[3:, 2:] = region[:-3, :-2]
    sh &= ~region
    rgba[sh, :3] *= 0.55
    # brick id map, periodic so neighbouring tiles line up
    yy, xx = np.mgrid[0:T, 0:T]
    row = yy // 8
    off = (row % 2) * 6
    widths = [10, 12, 10]
    col = ((xx + off) % T)
    edges = np.cumsum([0] + widths)
    bid = np.digitize(col, edges[1:-1]) + row * 10
    local_x = col - edges[np.digitize(col, edges[1:-1])]
    local_y = yy % 8
    wv = np.array(widths)[np.digitize(col, edges[1:-1])]
    dx = np.minimum(local_x, wv - 1 - local_x)
    dy = np.minimum(local_y, 7 - local_y)
    d = np.minimum(dx, dy)
    mortar = d == 0
    hf = np.minimum(d, 3).astype(float)
    shade = lambert(gblur(hf, 0.7) * 1.4, 1.0)
    br = np.random.default_rng(31)
    tone = br.uniform(-0.12, 0.12, size=200)[bid % 200]
    v = 0.15 + shade * 0.62 + tone + (grass_fine - 0.5) * 0.12
    img = ramp_map(v, STONE, 0.5)
    rgba[region, :3] = img[region]
    rgba[region & mortar, :3] = STONE[0]
    # moss on top faces
    moss = region & (grass_base_noise > 0.62) & (local_y <= 2) & ~mortar
    mimg = ramp_map(grass_fine, MOSS, 0.6)
    rgba[moss, :3] = mimg[moss]
    # dark outline where wall meets turf
    e = inner_edge(region)
    # do not outline across connected tile borders
    if m & 1: e[0, :] = False
    if m & 4: e[T - 1, :] = False
    if m & 8: e[:, 0] = False
    if m & 2: e[:, T - 1] = False
    rgba[e, :3] = (28, 26, 30)
    return rgba


# ----------------------------------------------------------------- assemble
os.makedirs(OUT, exist_ok=True)
meta = {}

# ground atlas: row0-1 grass variants (16), row2 wall masks 0..15
ground = blank(T * 3, T * 16)
for i, k in enumerate(GRASS_KINDS):
    ground[(i // 16) * T:(i // 16 + 1) * T, (i % 16) * T:(i % 16 + 1) * T] = grass_tile(100 + i, k)
for m in range(16):
    ground[2 * T:3 * T, m * T:(m + 1) * T] = wall_tile(m)
# row 1 currently empty except none -> fill with extra plain grass variants
for i in range(16):
    ground[T:2 * T, i * T:(i + 1) * T] = grass_tile(300 + i, ['plain', 'tuft', 'short', 'clover', 'plain', 'flowers', 'plain', 'daisy',
                                                              'plain', 'pebble', 'tuft', 'plain', 'short', 'flowers2', 'plain', 'light'][i])
to_img(ground).save(f'{OUT}/stsh_ground_atlas.png')
meta['ground'] = dict(grass=[[i % 16, i // 16] for i in range(32)], wall_row=2)

for kind in ('dirt', 'path', 'forest'):
    atl = blank(T * 2, T * 16)
    for m in range(16):
        atl[0:T, m * T:(m + 1) * T] = overlay_tile(m, kind)
    for v in range(4):
        atl[T:2 * T, v * T:(v + 1) * T] = overlay_tile(15, kind, v)
    to_img(atl).save(f'{OUT}/stsh_{kind}_atlas.png')

# water: mask m at ((m%4)*4, m//4), 4 frames each; extra full variants on row 4
wat = blank(T * 5, T * 16)
for m in range(16):
    cx, cy = (m % 4) * 4, m // 4
    for fr in range(FRAMES):
        wat[cy * T:(cy + 1) * T, (cx + fr) * T:(cx + fr + 1) * T] = water_tile(m, fr)
for v in range(1, 4):
    cx = (v - 1) * 4
    for fr in range(FRAMES):
        wat[4 * T:5 * T, (cx + fr) * T:(cx + fr + 1) * T] = water_tile(15, fr, v)
to_img(wat).save(f'{OUT}/stsh_water_atlas.png')
meta['water_collision'] = {str(m): water_collision(m) for m in range(16)}

with open(f'{OUT}/terrain_meta.json', 'w') as fh:
    json.dump(meta, fh, indent=1)
print('terrain atlases written')
