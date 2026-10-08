"""Build 016 art generator: boss 2 (HUVAL YARHEYHEY), his programmed sheep,
the micro sheep and the data-plaza backdrop (Python + Pillow + numpy).

Draws, from code only (no photos, no tracing, no third-party assets):
  assets/boss2/huval_96.png        Huval Yarheyhey sheet, 10 frames of 96x112:
                                   0-1 idle (lecturing), 2-3 walk, 4 clicker up
                                   (spawn wind-up), 5 clicker point (cast),
                                   6 lecturing to the camera, 7 hurt, 8-9 defeated
  assets/boss2/robo_sheep_32.png   programmed sheep (steel wool, cyan circuit
                                   traces, glowing eyes, antenna), same 6x4 layout
                                   of 64x64 cells as assets/characters/sheep_32.png
  assets/boss2/micro_sheep_32.png  micro sheep (neon magenta, lime circuits);
                                   drawn at ~0.55 scale in game
  assets/boss2/data_plaza.png      arena backdrop: a glassy lecture hall with a
                                   big DATA screen (352x184)

Huval Yarheyhey is an invented, good-natured cartoon parody of a generic
futurist lecturer: a shiny bald dome, round glasses, a smug half-smile, a
dark crew-neck sweater and a presentation clicker. No real likeness.

Run:  python3 tools/gen_boss2.py   (writes into assets/boss2/)
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from artlib import hexc
import gen_boss as gb
from gen_boss import Canvas, E, P, R, L, union, INK

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'boss2')
os.makedirs(OUT, exist_ok=True)
FW, FH = 96, 112

gb.PAL.update({
    'hskin': ['#93624c', '#cf9877', '#ecc19d', '#ffe3c8'],
    'sweater': ['#121319', '#1f2129', '#30333f', '#474c5c'],
    'pants': ['#191c22', '#2a2f38', '#3c4350', '#545c6a'],
    'hshoe': ['#0c0c10', '#1c1c22', '#2e2e36', '#46464e'],
    'frame': ['#05060a', '#14161c', '#262a32', '#3a3f4a'],
    'lens': ['#7aa8c8', '#a8d4ec', '#d4f0ff', '#ffffff'],
    'clicker': ['#101216', '#22262e', '#363c48', '#545c6c'],
    'tablet': ['#0e1420', '#1c2638', '#2c3c58', '#40587c'],
    'stub': ['#6a5a52', '#86746a', '#9e8c80', '#b4a294'],
    'hmouth': ['#2a0a0e', '#3e1016', '#56181e', '#6c2228'],
    'mic': ['#0a0a0e', '#1c1c22', '#34343e', '#5a5a66'],
})


def huval(frame):
    c = Canvas(FW, FH)
    oy = 16
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame == 1 else 0
    hy = oy + bob + (12 if sit else 0)
    if frame == 7:
        hy += 2
    tilt = 3 if frame == 7 else 0

    def Y(v):
        return v + hy

    # --- legs (slim dark trousers, black shoes)
    if sit:
        c.part(P(c, [(34, Y(58)), (47, Y(58)), (46, Y(72)), (33, Y(72))]), 'pants')
        c.part(P(c, [(49, Y(58)), (62, Y(58)), (63, Y(72)), (50, Y(72))]), 'pants')
        c.part(E(c, (28, Y(70), 46, Y(82))), 'hshoe')
        c.part(E(c, (50, Y(70), 68, Y(82))), 'hshoe')
    else:
        lo = 2 * walk
        for side, (x0, x1) in ((0, (36, 46)), (1, (50, 60))):
            d = lo if side == 0 else -lo
            c.part(P(c, [(x0 - 1, Y(56)), (x1 + 1, Y(56)), (x1, Y(82) + d), (x0, Y(82) + d)]), 'pants')
            sx = x0
            shoe_box = (sx - 4, Y(79) + d, sx + 11, Y(87) + d) if side == 0 else (sx - 1, Y(79) + d, sx + 14, Y(87) + d)
            c.part(E(c, shoe_box), 'hshoe', sigma=1.4)

    # --- back arm (viewer's left)
    swing = -walk * 2
    tablet_left = frame in (0, 1, 6)
    if sit:
        c.part(P(c, [(28, Y(40)), (34, Y(42)), (29, Y(58)), (22, Y(56))]), 'sweater')
        c.part(E(c, (18, Y(54), 28, Y(63))), 'hskin', sigma=1.2)
    elif tablet_left:
        # holds a tablet against the hip
        c.part(P(c, [(27, Y(40)), (34, Y(42)), (32, Y(56)), (25, Y(56))]), 'sweater')
        c.part(R(c, (14, Y(46), 29, Y(66))), 'tablet', sigma=1.0)
        c.part(R(c, (16, Y(48), 27, Y(63))), ['#1a6a8a', '#2aa0c8', '#4ad0f0', '#9af0ff'], rim=False, sigma=1.4, light_bias=0.1)
        for yy in (51, 55, 59):
            for xx in range(18, 25):
                if (xx + yy) % 3:
                    c.px(xx, Y(yy), '#e8fcff')
        c.part(E(c, (24, Y(52), 32, Y(60))), 'hskin', sigma=1.0)
    else:
        c.part(P(c, [(27, Y(40)), (34, Y(42)), (32, Y(60) + swing), (25, Y(60) + swing)]), 'sweater')
        c.part(E(c, (23, Y(58) + swing, 32, Y(67) + swing)), 'hskin', sigma=1.2)

    # --- torso: dark crew-neck sweater, slim
    torso = union(c, P(c, [(31, Y(40)), (65, Y(40)), (63, Y(62)), (33, Y(62))]),
                  E(c, (28, Y(37), 42, Y(48))), E(c, (54, Y(37), 68, Y(48))))
    c.part(torso, 'sweater', sigma=2.6)
    # crew neck + a hint of collar
    c.part(E(c, (40, Y(36), 56, Y(44))), 'hskin', sigma=1.0)
    c.part(L(c, [(40, Y(40)), (44, Y(44)), (52, Y(44)), (56, Y(40))], 2), ['#30333f', '#474c5c', '#5c6274', '#747b8e'], rim=False, sigma=0.4)
    # ribbed hem
    for x in range(33, 64, 2):
        c.px(x, Y(61), '#3a3e4c')
    # little glowing "DATA" pin (cyan square)
    for (x, y) in [(57, 46), (58, 46), (57, 47), (58, 47)]:
        c.px(x, Y(y), '#6af4ff')

    # --- head: shiny bald dome, faint stubble ring
    hx = tilt
    c.part(E(c, (25 + hx, Y(14), 31 + hx, Y(27))), 'hskin', sigma=1.0)     # ears
    c.part(E(c, (65 + hx, Y(14), 71 + hx, Y(27))), 'hskin', sigma=1.0)
    head = union(c, E(c, (27 + hx, Y(-6), 69 + hx, Y(34))),
                 P(c, [(32 + hx, Y(22)), (64 + hx, Y(22)), (58 + hx, Y(38)), (38 + hx, Y(38))]))
    c.part(head, 'hskin', sigma=3.4, light_bias=0.04)
    # short-cropped stubble at the sides/back only
    for (x0, x1) in ((28, 33), (63, 68)):
        for y in range(3, 16):
            for x in range(x0, x1):
                if (x + y) % 2 == 0:
                    xx = x + hx
                    if c.rgba[Y(y), xx, 3] > 0 and not np.all(c.rgba[Y(y), xx, :3] == INK):
                        c.px(xx, Y(y), '#a58a76')
    # dome highlight (big shine) + forehead wrinkle
    for (x, y) in [(40, -2), (41, -2), (42, -2), (39, -1), (40, -1), (41, -1), (42, -1), (43, -1),
                   (39, 0), (40, 0), (41, 0), (42, 0), (40, 1), (41, 1), (45, -3), (46, -3), (46, -4)]:
        c.px(x + hx, Y(y), '#ffffff')
    for x in range(41, 56):
        if x % 5:
            c.px(x + hx, Y(8), '#c98f6c')

    # --- glasses: round dark frames, lens glint
    def eyes(kind):
        for x0 in (35, 50):
            ring = c.mask()
            ImageDraw.Draw(ring).ellipse((x0 + hx, Y(12), x0 + 11 + hx, Y(23)), outline=255, width=2)
            if kind in ('askew', 'x') and x0 == 50:
                ring = c.mask()
                ImageDraw.Draw(ring).ellipse((x0 + hx, Y(14), x0 + 11 + hx, Y(25)), outline=255, width=2)
            lens = c.mask()
            ImageDraw.Draw(lens).ellipse((x0 + 2 + hx, Y(14), x0 + 9 + hx, Y(21)), fill=255)
            c.part(lens, 'lens', rim=False, sigma=0.8, light_bias=0.25)
            # eye inside the lens
            ex, ey = x0 + 4 + hx, Y(16)
            if kind == 'open':
                for j in range(3):
                    for i in range(2):
                        c.px(ex + i + 1, ey + j, INK)
            elif kind == 'smug':
                for i in range(4):
                    c.px(ex + i, ey + 2, INK)
                c.px(ex + 1, ey + 1, INK)
                c.px(ex + 2, ey + 1, INK)
            elif kind == 'squeeze':
                c.px(ex, ey, INK); c.px(ex + 1, ey + 1, INK); c.px(ex + 2, ey + 2, INK); c.px(ex + 1, ey + 3, INK); c.px(ex, ey + 4, INK)
            elif kind in ('x', 'askew'):
                for k in range(4):
                    c.px(ex + k, ey + k, INK)
                    c.px(ex + 3 - k, ey + k, INK)
            mk = np.array(ring) > 127
            c.rgba[mk, :3] = hexc('#0c0e14')
            c.rgba[mk, 3] = 255
            # glint
            c.px(x0 + 7 + hx, Y(14), '#ffffff')
            c.px(x0 + 8 + hx, Y(15), '#ffffff')
        # bridge + temples
        c.part(L(c, [(46 + hx, Y(17)), (50 + hx, Y(17))], 2), 'frame', rim=False, sigma=0.3)
        c.part(L(c, [(35 + hx, Y(17)), (29 + hx, Y(18))], 2), 'frame', rim=False, sigma=0.3)
        c.part(L(c, [(61 + hx, Y(17)), (67 + hx, Y(18))], 2), 'frame', rim=False, sigma=0.3)
        if kind == 'x':
            # cracked lens
            for k in range(5):
                c.px(52 + k + hx, Y(15) + (k % 2), '#ffffff')

    if frame == 7:
        eyes('squeeze')
    elif sit:
        eyes('x')
    elif frame in (0, 2, 3, 6):
        eyes('smug')
    else:
        eyes('open')
    # eyebrows: one raised (the smug lecturer look)
    if frame == 7 or sit:
        b1 = [(35 + hx, Y(9)), (45 + hx, Y(11))]
        b2 = [(51 + hx, Y(11)), (61 + hx, Y(9))]
    else:
        raise_ = -2 if frame in (4, 6) else 0
        b1 = [(35 + hx, Y(10)), (40 + hx, Y(9)), (45 + hx, Y(10))]
        b2 = [(51 + hx, Y(8) + raise_), (56 + hx, Y(6) + raise_), (61 + hx, Y(8) + raise_)]
    c.part(L(c, b1, 2), 'stub', rim=False, sigma=0.4)
    c.part(L(c, b2, 2), 'stub', rim=False, sigma=0.4)
    # nose
    c.px(48 + hx, Y(22), '#c98f6c'); c.px(48 + hx, Y(23), '#c98f6c'); c.px(47 + hx, Y(25), '#93624c'); c.px(49 + hx, Y(25), '#93624c')

    # --- mouth
    mx = hx
    if frame == 7:
        c.part(E(c, (45 + mx, Y(28), 51 + mx, Y(34))), 'hmouth', sigma=0.6)
    elif sit:
        c.part(L(c, [(42 + mx, Y(31)), (46 + mx, Y(29)), (50 + mx, Y(31)), (54 + mx, Y(29))], 2), 'hmouth', rim=False, sigma=0.4)
    elif frame in (5, 6):
        # talking: open "and THAT, my friends..."
        m = c.part(E(c, (42 + mx, Y(27), 54 + mx, Y(34))), 'hmouth', sigma=0.6)
        for x in range(44 + mx, 53 + mx):
            if m[Y(28), x]:
                c.px(x, Y(28), '#f4f0e8')
    else:
        # smug lopsided half-smile (up on his left = viewer's right)
        c.part(L(c, [(42 + mx, Y(30)), (47 + mx, Y(31)), (52 + mx, Y(30)), (56 + mx, Y(27))], 2), 'hmouth', rim=False, sigma=0.3)
        c.px(57 + mx, Y(27), '#c98f6c')

    # TED-style headset microphone: ear hook -> thin boom -> mic at the mouth corner
    if not sit:
        c.part(L(c, [(66 + hx, Y(22)), (62 + hx, Y(28)), (57 + hx, Y(31))], 1), 'mic', rim=False, sigma=0.2)
        c.part(E(c, (54 + hx, Y(29), 58 + hx, Y(33))), 'mic', sigma=0.4)

    # --- front arm (viewer's right) with the clicker
    def clicker(x, y, led=True):
        c.part(R(c, (x, y, x + 5, y + 10)), 'clicker', sigma=0.6)
        if led:
            c.px(x + 2, y + 2, '#ff3040')
            c.px(x + 3, y + 2, '#ff8090')

    if frame == 4:
        c.part(P(c, [(62, Y(40)), (69, Y(37)), (80, Y(12)), (74, Y(9))]), 'sweater')
        c.part(E(c, (72, Y(2), 83, Y(13))), 'hskin', sigma=1.2)
        clicker(75, Y(-8))
        # beam sparkle from the clicker LED
        for d in range(1, 6):
            c.px(77, Y(-8) - d, '#ff7080' if d % 2 else '#ffd0d8')
        for (dx, dy) in [(-3, -3), (3, -3), (-4, 0), (4, 0)]:
            c.px(77 + dx, Y(-8) + dy, '#ffd0d8')
    elif frame == 5:
        c.part(P(c, [(62, Y(40)), (69, Y(40)), (83, Y(46)), (80, Y(53))]), 'sweater')
        c.part(E(c, (78, Y(43), 89, Y(54))), 'hskin', sigma=1.2)
        c.part(R(c, (84, Y(44), 93, Y(49))), 'clicker', sigma=0.6)
        c.px(91, Y(45), '#ff3040')
        c.px(92, Y(45), '#ff8090')
    elif frame == 6:
        # open palm "let me explain", up by the shoulder (whole hand, fingers spread)
        c.part(P(c, [(62, Y(40)), (69, Y(38)), (78, Y(28)), (72, Y(24))]), 'sweater')
        palm = union(c, E(c, (69, Y(14), 84, Y(28))),
                     E(c, (69, Y(8), 73, Y(18))), E(c, (73, Y(6), 77, Y(16))),
                     E(c, (77, Y(7), 81, Y(17))), E(c, (80, Y(10), 84, Y(19))),
                     E(c, (65, Y(18), 71, Y(24))))
        c.part(palm, 'hskin', sigma=1.0)
    elif frame == 1:
        # gesturing with the clicker at chest height
        c.part(P(c, [(62, Y(42)), (69, Y(40)), (76, Y(52)), (69, Y(56))]), 'sweater')
        c.part(E(c, (68, Y(46), 78, Y(56))), 'hskin', sigma=1.2)
        clicker(71, Y(41))
    elif sit:
        c.part(P(c, [(63, Y(42)), (69, Y(40)), (75, Y(56)), (68, Y(58))]), 'sweater')
        c.part(E(c, (69, Y(54), 79, Y(63))), 'hskin', sigma=1.2)
        clicker(78, Y(64), led=False)
    elif frame == 7:
        c.part(P(c, [(62, Y(40)), (69, Y(38)), (79, Y(30)), (75, Y(25))]), 'sweater')
        c.part(E(c, (73, Y(20), 83, Y(30))), 'hskin', sigma=1.2)
    else:
        c.part(P(c, [(63, Y(42)), (70, Y(40)), (72, Y(60) - swing), (65, Y(60) - swing)]), 'sweater')
        c.part(E(c, (64, Y(58) - swing, 74, Y(67) - swing)), 'hskin', sigma=1.2)
        clicker(66, Y(63) - swing)

    img = c.finish()
    sh = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    gy = (oy + 12 + 72) if sit else (oy + 88)
    d.ellipse((26, gy - 4, 70, gy + 5), fill=(10, 20, 30, 90))
    sh.alpha_composite(img)
    return sh


# ---------------------------------------------------------------- sheep variants

def _sheep_variant(wool_ramp, trace, node, eye, dark_ramp, horn_ramp, seed):
    src = np.array(Image.open(os.path.join(HERE, '..', 'assets', 'characters', 'sheep_32.png')).convert('RGBA')).astype(np.float32)
    out = src.copy()
    rgb = src[..., :3]
    a = src[..., 3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    solid = a > 200
    sat = (rgb.max(axis=2) - rgb.min(axis=2)) / 255.0
    eye_m = solid & (r > 140) & (g < 90) & (b < 110)
    warm = solid & (r - b > 18) & (lum > 0.22) & (lum < 0.62) & ~eye_m
    wool = solid & (lum > 0.33) & (sat < 0.16) & ~eye_m
    dark = solid & ~wool & ~eye_m & ~warm
    wr = np.stack([hexc(h) for h in wool_ramp])
    dr = np.stack([hexc(h) for h in dark_ramp])
    hr = np.stack([hexc(h) for h in horn_ramp])

    def remap(mask, ramp, lo, hi):
        t = np.clip((lum - lo) / (hi - lo), 0, 1)
        idx = np.clip(np.rint(t * (len(ramp) - 1)), 0, len(ramp) - 1).astype(int)
        out[mask, :3] = ramp[idx][mask]

    remap(wool, wr, 0.35, 1.0)
    remap(dark, dr, 0.0, 0.3)
    remap(warm, hr, 0.2, 0.6)
    H, W = a.shape
    yy, xx = np.mgrid[0:H, 0:W]
    lx, ly = xx % 64, yy % 64
    # circuit traces: horizontal runs every 6 px with vertical drops, on wool only
    interior = wool.copy()
    for sh in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        interior &= np.roll(wool, sh, axis=(0, 1))
    tr = interior & (((ly % 6) == 2) & (((lx // 4) + (ly // 6)) % 3 != 0) |
                     ((lx % 7) == 3) & ((ly % 6) >= 2) & ((ly % 6) <= 4) & (((lx // 7) + (ly // 6)) % 2 == 0))
    out[tr, :3] = hexc(trace)
    nd = interior & ((ly % 6) == 2) & ((lx % 7) == 3) & (((lx // 7) + (ly // 6)) % 2 == 0)
    out[nd, :3] = hexc(node)
    # glowing eyes + 1px glow
    out[eye_m, :3] = hexc(eye)
    glow = np.zeros_like(eye_m)
    for sh in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        glow |= np.roll(eye_m, sh, axis=(0, 1))
    glow &= ~eye_m & solid
    ec = hexc(eye)
    out[glow, :3] = out[glow, :3] * 0.45 + ec * 0.55
    return Image.fromarray(np.clip(np.rint(out), 0, 255).astype(np.uint8), 'RGBA')


def robo_sheep():
    return _sheep_variant(['#26304a', '#3c4c68', '#5c7090', '#8aa4c4', '#c4d6ea'],
                          '#2ee6ff', '#eaffff', '#7dfcff',
                          ['#0e1016', '#1a1e28', '#2a303c', '#3e4656'],
                          ['#6c7484', '#a0a8b8', '#d4dae4', '#ffffff'], 1)


def micro_sheep():
    return _sheep_variant(['#3a0c48', '#681a84', '#a232c4', '#d66af0', '#f6b6ff'],
                          '#9dff4a', '#f0ffd0', '#c4ff5a',
                          ['#16081c', '#26102e', '#3a1a44', '#542a60'],
                          ['#9a8cff', '#c0b6ff', '#e4deff', '#ffffff'], 2)


# ---------------------------------------------------------------- arena backdrop

def data_plaza():
    W, H = 352, 184
    c = Canvas(W, H)
    concrete = ['#4a505c', '#6c7482', '#9098a6', '#b8c0cc']
    glass = ['#0c1830', '#14284c', '#20406e', '#386aa0']
    # main hall: wide low block with a curved glass front
    c.part(R(c, (10, 92, 342, 178)), concrete, sigma=4.0)
    c.part(union(c, R(c, (40, 66, 312, 176)), E(c, (40, 40, 312, 96))), glass, sigma=5.0)
    # vertical mullions on the glass
    for x in range(52, 304, 16):
        for y in range(52, 176):
            if c.rgba[y, x, 3] > 0:
                c.px(x, y, '#5a7ea8')
    # cyan light strips
    for y in (100, 140):
        for x in range(44, 310):
            if c.rgba[y, x, 3] > 0:
                c.px(x, y, '#38e8ff')
    # big DATA screen (centre)
    c.part(R(c, (120, 50, 232, 116)), ['#05080e', '#0a1220', '#101c30', '#18283e'], sigma=1.0)
    img = c.finish()
    d = ImageDraw.Draw(img)
    # line graph going up and to the right (of course)
    pts = [(128, 104), (142, 98), (154, 101), (168, 90), (182, 86), (196, 74), (210, 70), (224, 58)]
    d.line(pts, fill=(80, 240, 255, 255), width=2)
    for p in pts:
        d.rectangle((p[0] - 1, p[1] - 1, p[0] + 1, p[1] + 1), fill=(220, 255, 255, 255))
    # bars
    for i, hgt in enumerate([10, 16, 13, 22, 28]):
        x = 130 + i * 9
        d.rectangle((x, 112 - hgt, x + 5, 112), fill=(255, 90, 200, 200))
    # "DATA" in chunky pixel letters
    glyph = {
        'D': ["110", "101", "101", "101", "110"],
        'A': ["010", "101", "111", "101", "101"],
        'T': ["111", "010", "010", "010", "010"],
    }
    x0, y0 = 196, 92
    for ch in "DATA":
        for j, row in enumerate(glyph[ch]):
            for i, v in enumerate(row):
                if v == '1':
                    d.rectangle((x0 + i * 2, y0 + j * 2, x0 + i * 2 + 1, y0 + j * 2 + 1), fill=(255, 255, 255, 255))
        x0 += 8
    # entrance + steps
    d.rectangle((160, 148, 192, 178), fill=(20, 30, 50, 255))
    d.rectangle((162, 150, 190, 178), fill=(120, 220, 255, 140))
    for k in range(3):
        d.rectangle((150 - k * 6, 170 + k * 3, 202 + k * 6, 172 + k * 3), fill=(150, 156, 168, 255))
    # rooftop antenna + blinking light, server-rack LEDs on the wings
    d.line((176, 40, 176, 8), fill=(24, 12, 20, 255), width=3)
    d.line((176, 40, 176, 8), fill=(160, 168, 184, 255), width=1)
    d.rectangle((174, 4, 178, 8), fill=(255, 60, 70, 255))
    for x in range(18, 36, 4):
        for y in range(104, 170, 6):
            d.point((x, y), fill=(60, 255, 120, 255) if (x * 7 + y) % 3 else (255, 200, 60, 255))
    for x in range(318, 336, 4):
        for y in range(104, 170, 6):
            d.point((x, y), fill=(60, 255, 120, 255) if (x * 5 + y) % 3 else (80, 200, 255, 255))
    return img


def main():
    sheet = Image.new('RGBA', (FW * 10, FH), (0, 0, 0, 0))
    for f in range(10):
        sheet.alpha_composite(huval(f), (f * FW, 0))
    sheet.save(os.path.join(OUT, 'huval_96.png'))
    robo_sheep().save(os.path.join(OUT, 'robo_sheep_32.png'))
    micro_sheep().save(os.path.join(OUT, 'micro_sheep_32.png'))
    data_plaza().save(os.path.join(OUT, 'data_plaza.png'))
    print('wrote', OUT)


if __name__ == '__main__':
    main()
