"""Build 015 boss art generator (Python + Pillow + numpy, uses artlib).

Draws, from code only (no photos, no tracing, no third-party assets):
  assets/boss/judeau_96.png      Trustin Judeau sheet, 10 frames of 96x112:
                                 0-1 idle, 2-3 walk, 4 wind-up, 5 throw,
                                 6 camera pose, 7 hurt, 8-9 defeated
  assets/boss/poutine_32.png     poutine projectile (32x32)
  assets/boss/gravy_splat_48.png gravy splat, 4 frames of 48x48
  assets/boss/parliament.png     arena backdrop building (352x184)

Trustin Judeau is an invented, good-natured cartoon parody boss: a bobble-
headed politician with big swoopy hair, a toothy grin, a sharp navy suit, a
maple-leaf lapel pin and red maple-leaf socks. Every pixel is generated here.

Run:  python3 tools/gen_boss.py   (writes into assets/boss/)
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from artlib import gblur, lambert, inner_edge, to_img, blank, hexc

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'boss')
os.makedirs(OUT, exist_ok=True)

INK = hexc('#180c14')
FW, FH = 96, 112

PAL = {
    'skin': ['#8a4f3a', '#c98a62', '#eab48a', '#ffd9b0'],
    'hair': ['#120c0a', '#2a1d17', '#45322a', '#6e5243'],
    'suit': ['#0f1633', '#1d2b5a', '#2f4486', '#4d68b0'],
    'shirt': ['#9aa4b4', '#d8e0ea', '#f4f8ff', '#ffffff'],
    'tie': ['#6a0c14', '#b41a26', '#e23a3e', '#ff7a6a'],
    'sock': ['#7a0e16', '#c81e2a', '#ee3c40', '#ff7a70'],
    'shoe': ['#1e120c', '#3e2618', '#62402a', '#8a5e3e'],
    'mouth': ['#3a0810', '#5e121c', '#7e2028', '#9a3038'],
    'white': ['#b8b4a8', '#e6e2d6', '#fffef4', '#ffffff'],
    'gold': ['#7a5410', '#c8961e', '#f2c840', '#fff08a'],
    'red': ['#7a0e16', '#c81e2a', '#ee3c40', '#ff7a70'],
}


def ramp(name):
    return np.stack([hexc(h) for h in PAL[name]])


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgba = blank(h, w)

    def mask(self):
        return Image.new('L', (self.w, self.h), 0)

    def part(self, m, pal, rim=True, sigma=2.2, flat=False, light_bias=0.0):
        """Composite a shaded part. m: PIL 'L' mask."""
        mk = np.array(m) > 127
        if not mk.any():
            return mk
        r = ramp(pal) if isinstance(pal, str) else np.stack([hexc(h) for h in pal])
        if flat:
            v = np.full(mk.shape, 0.62)
        else:
            hf = gblur(mk.astype(np.float32), sigma) * 6.0
            sh = lambert(hf, 1.0)
            v = np.clip((sh - 0.55) / 0.45, 0, 1) * 0.85 + 0.12 + light_bias
            # simple ordered dither between ramp steps
        n = len(r)
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        dith = (((xx + yy) % 2) - 0.5) * 0.18
        idx = np.clip(np.rint(v * (n - 1) + dith), 0, n - 1).astype(int)
        col = r[idx]
        before = self.rgba[..., 3] > 0
        self.rgba[mk, :3] = col[mk]
        self.rgba[mk, 3] = 255
        if rim:
            outside = before & ~mk
            d = np.zeros_like(outside)
            d[1:, :] |= outside[:-1, :]
            d[:-1, :] |= outside[1:, :]
            d[:, 1:] |= outside[:, :-1]
            d[:, :-1] |= outside[:, 1:]
            e = inner_edge(mk) & d
            self.rgba[e, :3] = INK
        return mk

    def px(self, x, y, c, a=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.rgba[y, x, :3] = hexc(c) if isinstance(c, str) else c
            self.rgba[y, x, 3] = a

    def finish(self, outline=True):
        if outline:
            m = self.rgba[..., 3] > 0
            o = np.zeros_like(m)
            o[1:, :] |= m[:-1, :]
            o[:-1, :] |= m[1:, :]
            o[:, 1:] |= m[:, :-1]
            o[:, :-1] |= m[:, 1:]
            o &= ~m
            self.rgba[o, :3] = INK
            self.rgba[o, 3] = 255
        return to_img(self.rgba)


def E(c, box):
    m = c.mask()
    ImageDraw.Draw(m).ellipse(box, fill=255)
    return m


def P(c, pts):
    m = c.mask()
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def R(c, box):
    m = c.mask()
    ImageDraw.Draw(m).rectangle(box, fill=255)
    return m


def L(c, pts, width):
    m = c.mask()
    ImageDraw.Draw(m).line(pts, fill=255, width=width, joint='curve')
    return m


def union(c, *ms):
    m = c.mask()
    a = np.zeros((c.h, c.w), bool)
    for x in ms:
        a |= np.array(x) > 127
    return Image.fromarray((a * 255).astype(np.uint8), 'L')


MAPLE = [
    "..#..",
    "#.#.#",
    "#####",
    ".###.",
    "..#..",
]


def maple(c, x, y, col, rim=None):
    for j, row in enumerate(MAPLE):
        for i, ch in enumerate(row):
            if ch == '#':
                c.px(x + i, y + j, col)


def poutine_on(c, cx, cy, s=1.0):
    """Small poutine held in hand (same look as the projectile)."""
    def S(v):
        return v * s
    # paper boat
    boat = P(c, [(cx - S(10), cy), (cx + S(10), cy), (cx + S(7), cy + S(9)), (cx - S(7), cy + S(9))])
    mk = c.part(boat, 'white', sigma=1.2)
    for x in range(int(cx - S(10)), int(cx + S(11))):
        if (x // 2) % 2 == 0:
            for y in range(int(cy) + 1, int(cy + S(9)) + 1):
                if 0 <= y < c.h and 0 <= x < c.w and mk[y, x]:
                    c.rgba[y, x, :3] = hexc('#d4202c')
    # fries
    for i, (dx, h, ang) in enumerate([(-6, 8, -3), (-3, 10, -1), (0, 11, 1), (3, 9, 2), (6, 8, 3), (-1, 7, -2)]):
        fr = L(c, [(cx + S(dx), cy + 1), (cx + S(dx + ang), cy - S(h))], max(1, int(round(2 * s))))
        c.part(fr, ['#a8650e', '#e0a020', '#ffd24a', '#fff2a0'], sigma=0.6, light_bias=0.15)
    # gravy
    gv = union(c, E(c, (cx - S(9), cy - S(4), cx + S(9), cy + S(3))),
               E(c, (cx - S(4), cy - S(7), cx + S(5), cy - S(1))))
    c.part(gv, ['#3c1c08', '#6a3612', '#9a5a22', '#c48444'], sigma=1.2)
    for dx in (-6, 2, 7):
        d = L(c, [(cx + S(dx), cy), (cx + S(dx), cy + S(4))], max(1, int(round(2 * s))))
        c.part(d, ['#3c1c08', '#6a3612', '#9a5a22', '#c48444'], rim=False, sigma=0.5)
    # cheese curds
    for (dx, dy) in [(-5, -2), (0, -5), (4, -1), (-1, 0), (6, -4)]:
        cu = E(c, (cx + S(dx) - S(1.6), cy + S(dy) - S(1.3), cx + S(dx) + S(1.6), cy + S(dy) + S(1.3)))
        c.part(cu, ['#c8b890', '#efe4c4', '#fffbe8', '#ffffff'], rim=False, sigma=0.5, light_bias=0.2)


def judeau(frame):
    c = Canvas(FW, FH)
    oy = 16
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame == 1 else 0
    hy = oy + bob + (12 if sit else 0)        # head/torso vertical offset
    if frame == 7:
        hy += 2
    tilt = -3 if frame == 7 else 0

    def Y(v):
        return v + hy

    # --- legs
    if sit:
        # sitting: legs stick forward, soles toward viewer
        c.part(P(c, [(34, Y(58)), (47, Y(58)), (46, Y(70)), (33, Y(70))]), 'suit')
        c.part(P(c, [(49, Y(58)), (62, Y(58)), (63, Y(70)), (50, Y(70))]), 'suit')
        s1 = c.part(R(c, (32, Y(68), 45, Y(74))), 'sock')
        s2 = c.part(R(c, (51, Y(68), 64, Y(74))), 'sock')
        maple(c, 36, Y(69), '#ffffff')
        maple(c, 55, Y(69), '#ffffff')
        c.part(E(c, (28, Y(72), 46, Y(84))), 'shoe')
        c.part(E(c, (50, Y(72), 68, Y(84))), 'shoe')
    else:
        lo = 2 * walk
        for side, (x0, x1) in ((0, (35, 46)), (1, (50, 61))):
            d = lo if side == 0 else -lo
            c.part(P(c, [(x0 - 1, Y(56)), (x1 + 1, Y(56)), (x1, Y(74) + d), (x0, Y(74) + d)]), 'suit')
            sx = x0 + 1
            c.part(R(c, (sx, Y(72) + d, sx + 9, Y(82) + d)), 'sock', sigma=1.2)
            maple(c, sx + 2, Y(75) + d, '#ffffff')
            shoe_box = (sx - 4, Y(80) + d, sx + 11, Y(88) + d) if side == 0 else (sx - 2, Y(80) + d, sx + 13, Y(88) + d)
            c.part(E(c, shoe_box), 'shoe', sigma=1.4)

    # --- back arm (viewer's left = his right hand)
    swing = -walk * 2
    if frame == 6:
        # thumbs up near the chest-left side
        c.part(P(c, [(26, Y(40)), (33, Y(42)), (30, Y(52)), (22, Y(50))]), 'suit')
        c.part(E(c, (17, Y(42), 27, Y(52))), 'skin', sigma=1.2)
        c.part(R(c, (20, Y(35), 23, Y(43))), 'skin', sigma=0.8)   # thumb
    elif sit:
        c.part(P(c, [(27, Y(40)), (33, Y(42)), (28, Y(58)), (21, Y(56))]), 'suit')
        c.part(E(c, (17, Y(54), 27, Y(63))), 'skin', sigma=1.2)
    else:
        c.part(P(c, [(26, Y(40)), (33, Y(42)), (31, Y(60) + swing), (24, Y(60) + swing)]), 'suit')
        c.part(E(c, (22, Y(58) + swing, 31, Y(67) + swing)), 'skin', sigma=1.2)

    # --- torso
    torso = union(c, P(c, [(30, Y(40)), (66, Y(40)), (64, Y(62)), (32, Y(62))]),
                  E(c, (27, Y(37), 41, Y(48))), E(c, (55, Y(37), 69, Y(48))))
    c.part(torso, 'suit', sigma=2.6)
    c.part(P(c, [(41, Y(39)), (55, Y(39)), (48, Y(55))]), 'shirt', sigma=1.0)
    c.part(P(c, [(46, Y(41)), (50, Y(41)), (51, Y(51)), (48, Y(56)), (45, Y(51))]), 'tie', sigma=0.9)
    # lapels (lighter navy strips) + buttons
    c.part(L(c, [(40, Y(39)), (47, Y(57))], 3), ['#2f4486', '#3c55a0', '#4d68b0', '#6680c4'], rim=False, sigma=0.4)
    c.part(L(c, [(56, Y(39)), (49, Y(57))], 3), ['#2f4486', '#3c55a0', '#4d68b0', '#6680c4'], rim=False, sigma=0.4)
    c.px(48, Y(59), INK)
    c.px(48, Y(60), '#c8961e')
    # maple-leaf lapel pin (gold rim, red leaf)
    for j, row in enumerate(MAPLE):
        for i, ch in enumerate(row):
            if ch == '#':
                for (ddx, ddy) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    c.px(55 + i + ddx, Y(43) + j + ddy, '#f2c840')
    maple(c, 55, Y(43), '#e0202c')

    # --- head
    hx = tilt
    c.part(E(c, (23 + hx, Y(16), 29 + hx, Y(28))), 'skin', sigma=1.0)      # ears
    c.part(E(c, (67 + hx, Y(16), 73 + hx, Y(28))), 'skin', sigma=1.0)
    head = union(c, E(c, (26 + hx, Y(2), 70 + hx, Y(36))),
                 P(c, [(31 + hx, Y(24)), (65 + hx, Y(24)), (58 + hx, Y(40)), (38 + hx, Y(40))]))
    c.part(head, 'skin', sigma=3.0)
    # nose shading
    c.px(48 + hx, Y(24), '#c98a62')
    c.px(49 + hx, Y(25), '#c98a62')
    c.px(47 + hx, Y(26), '#8a4f3a')
    c.px(50 + hx, Y(26), '#8a4f3a')
    # cheeks
    for (x, y) in [(33, 27), (34, 28), (62, 27), (61, 28)]:
        c.px(x + hx, Y(y), '#e8907a')

    # --- hair: big swoopy dark quiff
    if sit:
        hair = union(c, E(c, (24 + hx, Y(-2), 72 + hx, Y(14))),
                     P(c, [(28 + hx, Y(10)), (46 + hx, Y(4)), (60 + hx, Y(16)), (54 + hx, Y(18)), (40 + hx, Y(12))]))
        c.part(hair, 'hair', sigma=2.4, light_bias=0.05)
    else:
        # side part on his right (viewer's left); the hair swoops up into a
        # big glossy wave and curls over at the viewer's right temple.
        hair = union(c,
                     E(c, (24 + hx, Y(-5), 72 + hx, Y(9))),                  # crown
                     P(c, [(25 + hx, Y(8)), (30 + hx, Y(-2)), (40 + hx, Y(-12)), (54 + hx, Y(-17)),
                           (68 + hx, Y(-14)), (77 + hx, Y(-6)), (76 + hx, Y(3)), (70 + hx, Y(8)),
                           (66 + hx, Y(2)), (56 + hx, Y(-2)), (44 + hx, Y(0)), (34 + hx, Y(4))]),
                     E(c, (66 + hx, Y(-6), 78 + hx, Y(10))))                 # curl lip
        c.part(hair, 'hair', sigma=2.0, light_bias=0.08)
        # swoop strands (dark) and gloss (light) following the wave
        for pts, col in [([(31, 2), (40, -7), (54, -12), (66, -10), (74, -3)], '#120c0a'),
                         ([(36, 4), (46, -3), (58, -6), (68, -3)], '#120c0a'),
                         ([(34, -1), (43, -9), (55, -14), (64, -13)], '#8a6c5a'),
                         ([(44, 1), (54, -3), (62, -3)], '#6e5243')]:
            seg = L(c, [(x + hx, Y(y)) for (x, y) in pts], 1)
            mk = np.array(seg) > 127
            c.rgba[mk, :3] = hexc(col)
        # little curl hook at the end of the wave
        for (x, y) in [(73, 4), (72, 5), (71, 5), (70, 4), (70, 3), (71, 2)]:
            c.px(x + hx, Y(y), '#120c0a')
    # sideburns
    c.part(R(c, (26 + hx, Y(8), 29 + hx, Y(22))), 'hair', sigma=0.6)
    c.part(R(c, (67 + hx, Y(8), 70 + hx, Y(22))), 'hair', sigma=0.6)

    # --- eyes
    def eye(x0, kind):
        if kind == 'open':
            c.part(E(c, (x0, Y(14), x0 + 11, Y(24))), 'white', sigma=1.0, light_bias=0.2)
            px0 = x0 + 4
            for j in range(4):
                for i in range(3):
                    c.px(px0 + i, Y(17) + j, INK)
            c.px(px0, Y(17), '#ffffff')
        elif kind == 'wink':
            c.part(L(c, [(x0 + 1, Y(21)), (x0 + 5, Y(17)), (x0 + 10, Y(21))], 2), 'hair', rim=False, sigma=0.4)
        elif kind == 'squeeze':
            c.part(L(c, [(x0 + 1, Y(16)), (x0 + 10, Y(19)), (x0 + 1, Y(22))], 2), 'hair', rim=False, sigma=0.4)
        elif kind == 'swirl':
            c.part(E(c, (x0, Y(14), x0 + 11, Y(24))), 'white', sigma=1.0, light_bias=0.2)
            cx, cy = x0 + 5.5, Y(19)
            for k in range(26):
                a = k * 0.55
                r = 0.3 + k * 0.17
                c.px(int(round(cx + np.cos(a) * r)), int(round(cy + np.sin(a) * r * 0.9)), INK)

    ex = hx
    if frame == 6:
        eye(35 + ex, 'open')
        eye(50 + ex, 'wink')
    elif frame == 7:
        eye(35 + ex, 'squeeze')
        eye(50 + ex, 'squeeze')
    elif sit:
        eye(35 + ex, 'swirl')
        eye(50 + ex, 'swirl')
    else:
        eye(35 + ex, 'open')
        eye(50 + ex, 'open')
    # eyebrows (thick, expressive)
    up = -1 if frame in (4, 6) else 0
    if frame == 7 or sit:
        b1 = [(34 + ex, Y(11)), (46 + ex, Y(14))]
        b2 = [(50 + ex, Y(14)), (62 + ex, Y(11))]
    else:
        b1 = [(34 + ex, Y(13) + up), (40 + ex, Y(10) + up), (46 + ex, Y(12) + up)]
        b2 = [(50 + ex, Y(12) + up), (56 + ex, Y(10) + up), (62 + ex, Y(13) + up)]
    c.part(L(c, b1, 3), 'hair', rim=False, sigma=0.5)
    c.part(L(c, b2, 3), 'hair', rim=False, sigma=0.5)

    # --- mouth: the famous toothy grin
    mx = hx
    if frame == 7:
        c.part(E(c, (44 + mx, Y(28), 52 + mx, Y(35))), 'mouth', sigma=0.8)
    elif sit:
        c.part(L(c, [(40 + mx, Y(31)), (44 + mx, Y(29)), (48 + mx, Y(31)), (52 + mx, Y(29)), (56 + mx, Y(31))], 2),
               'mouth', rim=False, sigma=0.4)
    else:
        big = frame in (5,)
        top = 26
        bot = 36 if big else 34
        grin = union(c, P(c, [(35 + mx, Y(top)), (61 + mx, Y(top)), (57 + mx, Y(bot)), (39 + mx, Y(bot))]),
                     E(c, (38 + mx, Y(top + 3), 58 + mx, Y(bot + 1))))
        mk = c.part(grin, 'mouth', sigma=0.8)
        # top teeth row (big and bright)
        for x in range(37 + mx, 60 + mx):
            for y in range(Y(top + 1), Y(top + 4) + 1):
                if mk[y, x]:
                    c.px(x, y, '#fffef4' if (x - mx) % 3 else '#c8c0a8')
        # bottom teeth
        for x in range(40 + mx, 57 + mx):
            y = Y(bot - 1)
            if mk[y, x]:
                c.px(x, y, '#e6e2d6' if (x - mx) % 3 else '#b8b4a8')
        if frame == 6:
            # sparkle on the grin
            sx, sy = 58 + mx, Y(top - 1)
            for d in range(-3, 4):
                c.px(sx + d, sy, '#ffffff')
                c.px(sx, sy + d, '#ffffff')
            c.px(sx, sy, '#fff08a')
    # dimples
    c.px(34 + mx, Y(29), '#c98a62')
    c.px(62 + mx, Y(29), '#c98a62')

    # --- front arm (viewer's right = his left hand), throwing arm
    if frame == 4:
        # wind-up: arm raised high with a poutine
        c.part(P(c, [(62, Y(40)), (69, Y(37)), (80, Y(14)), (74, Y(10))]), 'suit')
        c.part(E(c, (73, Y(4), 83, Y(14))), 'skin', sigma=1.2)
        poutine_on(c, 78, Y(-2), 0.9)
    elif frame == 5:
        # throw: arm thrust forward, open hand
        c.part(P(c, [(62, Y(40)), (69, Y(40)), (82, Y(48)), (78, Y(55))]), 'suit')
        c.part(E(c, (77, Y(45), 88, Y(56))), 'skin', sigma=1.2)
    elif frame == 6:
        # free hand waves
        c.part(P(c, [(62, Y(40)), (69, Y(38)), (78, Y(26)), (72, Y(22))]), 'suit')
        c.part(E(c, (71, Y(14), 82, Y(26))), 'skin', sigma=1.2)
    elif sit:
        c.part(P(c, [(63, Y(42)), (69, Y(40)), (75, Y(56)), (68, Y(58))]), 'suit')
        c.part(E(c, (69, Y(54), 79, Y(63))), 'skin', sigma=1.2)
    elif frame == 7:
        c.part(P(c, [(62, Y(40)), (69, Y(38)), (79, Y(30)), (75, Y(25))]), 'suit')
        c.part(E(c, (73, Y(20), 83, Y(30))), 'skin', sigma=1.2)
    else:
        c.part(P(c, [(63, Y(42)), (70, Y(40)), (72, Y(60) - swing), (65, Y(60) - swing)]), 'suit')
        c.part(E(c, (65, Y(58) - swing, 74, Y(67) - swing)), 'skin', sigma=1.2)

    img = c.finish()
    # soft ground shadow under everything (drawn after the outline pass)
    sh = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    gy = (oy + 12 + 74) if sit else (oy + 88)
    d.ellipse((24, gy - 4, 72, gy + 5), fill=(10, 20, 10, 90))
    sh.alpha_composite(img)
    return sh


def poutine_sprite():
    c = Canvas(32, 32)
    poutine_on(c, 16, 17, 1.25)
    return c.finish()


def splat_frames():
    frames = []
    rng = np.random.default_rng(15)
    drops = [(rng.uniform(0, 2 * np.pi), rng.uniform(0.6, 1.0), rng.uniform(1.5, 3.2)) for _ in range(11)]
    for k in range(4):
        c = Canvas(48, 48)
        t = (k + 1) / 4.0
        rx, ry = 8 + 10 * t, 5 + 6 * t
        blob = E(c, (24 - rx, 26 - ry, 24 + rx, 26 + ry))
        lobes = [blob]
        for i in range(6):
            a = i * 1.05 + 0.4
            lx, ly = 24 + np.cos(a) * rx * 0.85, 26 + np.sin(a) * ry * 0.85
            lobes.append(E(c, (lx - 4 * t - 2, ly - 3 * t - 1, lx + 4 * t + 2, ly + 3 * t + 1)))
        gr = ['#3c1c08', '#6a3612', '#9a5a22', '#c48444']
        c.part(union(c, *lobes), gr, sigma=1.6)
        for (a, r, s) in drops:
            dx = 24 + np.cos(a) * (rx + 4 + 8 * t) * r
            dy = 26 + np.sin(a) * (ry + 3 + 6 * t) * r
            c.part(E(c, (dx - s, dy - s * 0.8, dx + s, dy + s * 0.8)), gr, rim=False, sigma=0.6)
        # curds + a couple of fries in the splat
        for (dx, dy) in [(-5, -2), (3, 1), (7, -3), (-2, 4)]:
            q = 1.6 + t
            c.part(E(c, (24 + dx * t * 1.4 - q, 26 + dy * t - q * 0.8, 24 + dx * t * 1.4 + q, 26 + dy * t + q * 0.8)),
                   ['#c8b890', '#efe4c4', '#fffbe8', '#ffffff'], rim=False, sigma=0.5, light_bias=0.2)
        for (x0, y0, x1, y1) in [(14, 22, 20, 20), (28, 30, 34, 27)]:
            c.part(L(c, [(24 + (x0 - 24) * (0.6 + t * 0.5), y0), (24 + (x1 - 24) * (0.6 + t * 0.5), y1)], 2),
                   ['#a8650e', '#e0a020', '#ffd24a', '#fff2a0'], rim=False, sigma=0.4)
        img = c.finish()
        a = np.array(img).astype(np.float32)
        a[..., 3] *= 1.0 if k < 2 else (0.8 if k == 2 else 0.55)
        frames.append(Image.fromarray(a.astype(np.uint8), 'RGBA'))
    sheet = Image.new('RGBA', (48 * 4, 48), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * 48, 0))
    return sheet


def parliament():
    W, H = 352, 184
    c = Canvas(W, H)
    stone = ['#6e6a58', '#a39c80', '#c9c2a2', '#e6dfc0']
    copper = ['#1e5446', '#2f7a64', '#4fa486', '#86d0b0']
    # wings
    c.part(R(c, (8, 96, 344, 176)), stone, sigma=4.0)
    # wing roofs
    c.part(P(c, [(4, 98), (348, 98), (330, 72), (22, 72)]), copper, sigma=2.5)
    # end pavilions
    for x in (8, 292):
        c.part(R(c, (x, 74, x + 52, 176)), stone, sigma=3.0)
        c.part(P(c, [(x - 4, 78), (x + 56, 78), (x + 26, 44)]), copper, sigma=2.0)
    # central tower
    c.part(R(c, (150, 34, 202, 176)), stone, sigma=3.0)
    c.part(P(c, [(146, 38), (206, 38), (176, 2)]), copper, sigma=2.0)
    # clock face
    c.part(E(c, (164, 52, 188, 76)), ['#c8c0a0', '#efe8d0', '#fffbea', '#ffffff'], sigma=1.2)
    for (x, y) in [(176, 55), (176, 73), (167, 64), (185, 64)]:
        c.px(x, y, INK)
    for i in range(7):
        c.px(176, 64 - i, INK)
    for i in range(5):
        c.px(176 + i, 64, INK)
    # door arch
    c.part(union(c, R(c, (164, 140, 188, 176)), E(c, (164, 128, 188, 152))), ['#2a1a12', '#4a2e1e', '#62402a', '#7a5434'], sigma=1.0)
    # gothic windows
    win = ['#101830', '#1c2a50', '#2c4478', '#5a78b0']
    for row_y in (112, 144):
        for x in list(range(20, 140, 18)) + list(range(214, 336, 18)):
            if 8 <= x <= 56 or 292 <= x <= 340:
                pass
            c.part(union(c, R(c, (x, row_y + 4, x + 8, row_y + 20)), E(c, (x, row_y, x + 8, row_y + 10))), win, sigma=0.8)
    for row_y in (86, 104):
        for x in (160, 186):
            c.part(union(c, R(c, (x, row_y + 4, x + 6, row_y + 14)), E(c, (x, row_y, x + 6, row_y + 8))), win, sigma=0.8)
    # flagpole + flag (red-white-red with a maple leaf)
    for y in range(-14, 4):
        c.px(176, max(0, 4 + y), '#4a4a4a')
    img = c.finish()
    fl = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(fl)
    d.rectangle((177, 0, 197, 11), fill=(24, 12, 20, 255))
    d.rectangle((178, 1, 182, 10), fill=(212, 32, 44, 255))
    d.rectangle((183, 1, 191, 10), fill=(255, 255, 255, 255))
    d.rectangle((192, 1, 196, 10), fill=(212, 32, 44, 255))
    for j, row in enumerate(MAPLE):
        for i, ch in enumerate(row):
            if ch == '#':
                d.point((185 + i, 3 + j), fill=(212, 32, 44, 255))
    img.alpha_composite(fl)
    return img


def main():
    sheet = Image.new('RGBA', (FW * 10, FH), (0, 0, 0, 0))
    for f in range(10):
        sheet.alpha_composite(judeau(f), (f * FW, 0))
    sheet.save(os.path.join(OUT, 'judeau_96.png'))
    poutine_sprite().save(os.path.join(OUT, 'poutine_32.png'))
    splat_frames().save(os.path.join(OUT, 'gravy_splat_48.png'))
    parliament().save(os.path.join(OUT, 'parliament.png'))
    print('wrote', OUT)


if __name__ == '__main__':
    main()
