"""Build 027 art generator: boss 9 (VLADIMIR PUDDIN) and boss 10 (DONALD
RUMP, the final boss), plus their arena backdrops (Python + Pillow + numpy).

Drawn from code only (no photos, no tracing, no third-party assets):
  assets/boss9/puddin_128.png    Vladimir Puddin on horseback, 10 frames of 128x112
  assets/boss9/taiga_lodge.png   arena backdrop: a snowy log lodge, spruces and
                                 birches (352x184)
  assets/boss10/rump_96.png      Donald Rump sheet, 10 frames of 96x112
  assets/boss10/gold_tower.png   arena backdrop: a gold tower behind a
                                 clubhouse and palms (352x184)
Frames (same layout as bosses 4-8): 0-1 idle, 2-3 walk, 4 big wind-up, 5 cast,
6 palm up to the camera, 7 hurt, 8-9 defeated.

Both are good-natured cartoon parodies from generic features only:
Puddin = a stocky strongman type: shirtless, white judo trousers with a black
belt, short sandy thinning hair, a stern little smirk, riding a brown horse.
Rump = a tycoon golfer type: a huge golden swoop of hair, navy suit, white
shirt, an extra-long red tie, a gold driver raised / a golf ball at rest.
No real likeness, nothing hateful or sexual, no slogans.

Run:  python3 tools/gen_boss9.py
"""
import os
from PIL import Image, ImageDraw
import gen_boss as gb
from gen_boss import Canvas, E, P, R, L, union, INK
from pixtext import draw_text, text_width
from gen_boss5 import _legs, _eyes, _mouth, _finish, _arms, _front_arm, FW, FH

HERE = os.path.dirname(os.path.abspath(__file__))
OUT9 = os.path.join(HERE, '..', 'assets', 'boss9')
OUT10 = os.path.join(HERE, '..', 'assets', 'boss10')
os.makedirs(OUT9, exist_ok=True)
os.makedirs(OUT10, exist_ok=True)
PW = 128

gb.PAL.update({
    'pskin': ['#8a5a48', '#c48c76', '#e8b8a0', '#fcdcc8'],
    'phair': ['#7a6440', '#a08a5c', '#c4ae80', '#e2d0a6'],
    'gi': ['#a8acb4', '#d4d8de', '#eef0f4', '#ffffff'],
    'belt': ['#08080a', '#16161a', '#26262c', '#3a3a42'],
    'horse': ['#3a2414', '#5e3a20', '#86562e', '#ac7844'],
    'mane': ['#140c08', '#24160e', '#382416', '#4c3420'],
    'hoof': ['#1a1410', '#2c241c', '#403428', '#56483a'],
    'blanket': ['#5a0e14', '#8e1a22', '#c02a32', '#e0565a'],
    'tack': ['#1e140c', '#34241a', '#4c3626', '#664a34'],
    'dskin': ['#9a5e40', '#d08e64', '#eeb488', '#ffd4a8'],
    'dhair': ['#a07818', '#d0a42a', '#f0cc50', '#fff09a'],
    'dsuit': ['#0c1430', '#18264e', '#283c74', '#3e5698'],
    'dtie': ['#6a0810', '#a8141e', '#dc2a30', '#ff6a5a'],
    'club': ['#6a5a20', '#a88c30', '#e0c050', '#fff0a0'],
    'shaft': ['#6a6a72', '#9a9aa4', '#c8c8d0', '#f0f0f6'],
    'ball': ['#b8b8b4', '#e2e2de', '#f6f6f2', '#ffffff'],
})


# ---------------------------------------------------------------- Vladimir Puddin (horseback)

def _horse(c, frame, sit, walk, bob):
    hy = (12 if sit else 0) + bob
    rear = 4 if frame == 7 else 0           # hurt: the horse rears a little

    def Y(v):
        return v + hy

    # tail
    c.part(P(c, [(24, Y(60)), (14, Y(70)), (12, Y(88)), (20, Y(84)), (26, Y(70))]), 'mane', sigma=1.0)
    # legs (folded when down)
    if sit:
        for x0 in (30, 48, 80, 96):
            c.part(E(c, (x0 - 6, Y(82), x0 + 12, Y(94))), 'horse', sigma=1.2)
            c.part(E(c, (x0 + 4, Y(88), x0 + 14, Y(96))), 'hoof', sigma=0.6)
    else:
        sw = 3 * walk
        for x0, d in ((32, sw), (46, -sw), (84, -sw), (98, sw)):
            top = Y(76) - (rear if x0 > 80 else 0)
            c.part(P(c, [(x0 - 4, top), (x0 + 5, top), (x0 + 4 + d, Y(100) - (rear * 2 if x0 > 80 else 0)), (x0 - 3 + d, Y(100) - (rear * 2 if x0 > 80 else 0))]), 'horse', sigma=1.2)
            c.part(R(c, (x0 - 4 + d, Y(99) - (rear * 2 if x0 > 80 else 0), x0 + 5 + d, Y(104) - (rear * 2 if x0 > 80 else 0))), 'hoof', sigma=0.5)
    # body
    c.part(union(c, E(c, (22, Y(54) - rear // 2, 108, Y(88) - rear))), 'horse', sigma=3.0, light_bias=0.06)
    # neck + head (facing right)
    c.part(P(c, [(88, Y(62) - rear), (100, Y(36) - rear), (112, Y(38) - rear), (106, Y(70) - rear)]), 'horse', sigma=1.8)
    c.part(union(c, E(c, (98, Y(26) - rear, 122, Y(46) - rear)), E(c, (108, Y(34) - rear, 126, Y(52) - rear))), 'horse', sigma=1.6, light_bias=0.1)
    c.part(E(c, (116, Y(42) - rear, 126, Y(52) - rear)), ['#2a1a10', '#4a2e1c', '#6a442a', '#8a5e3c'], rim=False, sigma=0.6)
    c.part(P(c, [(102, Y(28) - rear), (104, Y(18) - rear), (109, Y(27) - rear)]), 'horse', sigma=0.5)
    c.px(112, Y(34) - rear, INK); c.px(113, Y(34) - rear, INK)
    c.px(122, Y(47) - rear, INK)
    # mane
    c.part(P(c, [(90, Y(56) - rear), (100, Y(30) - rear), (104, Y(32) - rear), (96, Y(60) - rear)]), 'mane', sigma=0.8)
    # bridle + reins
    c.part(L(c, [(104, Y(40) - rear), (118, Y(44) - rear)], 1), 'tack', rim=False, sigma=0.2)
    # saddle blanket
    c.part(R(c, (50, Y(52) - rear // 2, 80, Y(66) - rear // 2)), 'blanket', sigma=0.8)
    c.part(R(c, (50, Y(64) - rear // 2, 80, Y(66) - rear // 2)), 'gold', rim=False, sigma=0.3)
    return hy - rear // 2


def puddin(frame):
    c = Canvas(PW, FH)
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame in (1, 3) else 0
    base = _horse(c, frame, sit, walk, bob)
    slump = 8 if sit else 0
    lean = 3 if frame == 7 else 0

    def Y(v):
        return v + base + slump + 16

    cx = 64 + lean
    # leg (white judo trousers) over the horse's side + bare foot in a stirrup
    c.part(P(c, [(cx - 8, Y(48)), (cx + 6, Y(48)), (cx + 4, Y(72)), (cx - 6, Y(72))]), 'gi', sigma=1.0)
    c.part(E(c, (cx - 8, Y(70), cx + 6, Y(77))), 'pskin', sigma=0.8)
    c.part(L(c, [(cx - 2, Y(62)), (cx - 2, Y(70))], 1), 'tack', rim=False, sigma=0.2)
    # torso: shirtless, stocky (plain shading: shoulders, chest line, belly)
    torso = union(c, P(c, [(cx - 15, Y(18)), (cx + 15, Y(18)), (cx + 13, Y(48)), (cx - 13, Y(48))]),
                  E(c, (cx - 19, Y(14), cx - 5, Y(26))), E(c, (cx + 5, Y(14), cx + 19, Y(26))))
    c.part(torso, 'pskin', sigma=2.4, light_bias=0.08)
    c.part(L(c, [(cx - 10, Y(28)), (cx - 2, Y(30)), (cx + 2, Y(30)), (cx + 10, Y(28))], 1), ['#a06a56', '#b47a64', '#c48c76', '#d09a84'], rim=False, sigma=0.2)
    c.part(L(c, [(cx, Y(32)), (cx, Y(44))], 1), ['#a06a56', '#b47a64', '#c48c76', '#d09a84'], rim=False, sigma=0.2)
    # judo trousers top + black belt with a knot
    c.part(R(c, (cx - 14, Y(46), cx + 14, Y(52))), 'gi', sigma=0.6)
    c.part(R(c, (cx - 14, Y(44), cx + 14, Y(48))), 'belt', sigma=0.4)
    c.part(P(c, [(cx + 2, Y(46)), (cx + 6, Y(46)), (cx + 8, Y(56)), (cx + 4, Y(56))]), 'belt', sigma=0.3)
    # arms
    if frame == 4:            # strongman flex: both fists up
        for s in (-1, 1):
            c.part(P(c, [(cx + s * 14, Y(18)), (cx + s * 22, Y(16)), (cx + s * 28, Y(2)), (cx + s * 22, Y(0))]), 'pskin', sigma=1.2)
            c.part(E(c, (cx + s * 25 - 6, Y(-8), cx + s * 25 + 6, Y(3))), 'pskin', sigma=1.0)
            c.part(E(c, (cx + s * 18 - 5, Y(8), cx + s * 18 + 5, Y(18))), 'pskin', sigma=0.8, light_bias=0.12)
    elif frame == 5:          # cast: one arm forward, pointing
        c.part(P(c, [(cx + 12, Y(18)), (cx + 18, Y(24)), (cx + 36, Y(18)), (cx + 34, Y(12))]), 'pskin', sigma=1.2)
        c.part(E(c, (cx + 32, Y(10), cx + 42, Y(20))), 'pskin', sigma=0.9)
        c.part(P(c, [(cx - 12, Y(18)), (cx - 18, Y(22)), (cx - 16, Y(40)), (cx - 10, Y(38))]), 'pskin', sigma=1.2)
    elif frame == 6:          # palm to the camera
        c.part(P(c, [(cx + 12, Y(18)), (cx + 18, Y(20)), (cx + 22, Y(6)), (cx + 16, Y(4))]), 'pskin', sigma=1.2)
        c.part(union(c, E(c, (cx + 12, Y(-10), cx + 28, Y(6))), E(c, (cx + 12, Y(-16), cx + 16, Y(-6))),
                     E(c, (cx + 17, Y(-18), cx + 21, Y(-8))), E(c, (cx + 22, Y(-16), cx + 26, Y(-6)))), 'pskin', sigma=1.0)
        c.part(P(c, [(cx - 12, Y(18)), (cx - 18, Y(22)), (cx - 16, Y(40)), (cx - 10, Y(38))]), 'pskin', sigma=1.2)
    else:                     # arms down holding the reins
        sw = -walk * 2
        for s in (-1, 1):
            c.part(P(c, [(cx + s * 13, Y(18)), (cx + s * 19, Y(22)), (cx + s * 18 + sw, Y(42)), (cx + s * 12 + sw, Y(40))]), 'pskin', sigma=1.2)
            c.part(E(c, (cx + s * 15 - 5 + sw, Y(38), cx + s * 15 + 5 + sw, Y(47))), 'pskin', sigma=0.8)
        if not sit:
            c.part(L(c, [(cx + 16, Y(44)), (104, base + 42)], 1), 'tack', rim=False, sigma=0.2)
    # head: compact, square jaw, short sandy thinning hair
    hx = cx + (2 if frame == 7 else 0)
    c.part(E(c, (hx - 11, Y(-12), hx + 11, Y(14))), 'pskin', sigma=2.2, light_bias=0.14)
    c.part(E(c, (hx - 12, Y(-1), hx - 8, Y(6))), 'pskin', sigma=0.6)
    c.part(E(c, (hx + 8, Y(-1), hx + 12, Y(6))), 'pskin', sigma=0.6)
    c.part(union(c, E(c, (hx - 11, Y(-14), hx - 2, Y(-4))), E(c, (hx + 2, Y(-14), hx + 11, Y(-4)))), 'phair', sigma=0.8)
    c.part(E(c, (hx - 5, Y(-15), hx + 5, Y(-9))), 'pskin', rim=False, sigma=0.6, light_bias=0.2)   # thin on top
    # eyes + brows (stern), little smirk
    if frame == 7 or sit:
        for ex in (hx - 6, hx + 3):
            for k in range(3):
                c.px(ex + k, Y(1) + k, INK); c.px(ex + 2 - k, Y(1) + k, INK)
    else:
        for ex in (hx - 5, hx + 4):
            c.px(ex, Y(2), INK); c.px(ex + 1, Y(2), INK)
        c.part(L(c, [(hx - 8, Y(-2)), (hx - 3, Y(0))], 1), 'phair', rim=False, sigma=0.2)
        c.part(L(c, [(hx + 2, Y(0)), (hx + 8, Y(-2))], 1), 'phair', rim=False, sigma=0.2)
    c.px(hx, Y(5), '#b07a64'); c.px(hx, Y(6), '#b07a64')
    if frame in (4, 5):
        c.part(E(c, (hx - 3, Y(8), hx + 3, Y(12))), 'mouth', sigma=0.4)
    else:
        c.part(L(c, [(hx - 4, Y(10)), (hx + 1, Y(10)), (hx + 4, Y(8))], 1), 'mouth', rim=False, sigma=0.2)
    img = c.finish()
    sh = Image.new('RGBA', (PW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    d.ellipse((18, 100, 112, 110), fill=(10, 20, 30, 90))
    sh.alpha_composite(img)
    return sh


def taiga_lodge():
    W, H = 352, 184
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # snowy ground band
    d.rectangle((0, 150, W, 184), fill=(232, 240, 250, 255))
    # spruces behind
    import random
    rnd = random.Random(9)
    for x in list(range(4, 90, 22)) + list(range(268, 352, 22)):
        h = rnd.randint(70, 110)
        for k in range(4):
            y0 = 160 - h + k * h // 4
            w = 8 + k * 6
            d.polygon([(x, y0), (x - w, y0 + h // 3), (x + w, y0 + h // 3)], fill=(30, 66, 52, 255), outline=(14, 30, 24, 255))
            d.line((x - w + 3, y0 + h // 3 - 2, x + w - 3, y0 + h // 3 - 2), fill=(240, 246, 255, 255), width=2)
        d.polygon([(x, 160 - h), (x - 4, 160 - h + 10), (x + 4, 160 - h + 10)], fill=(245, 248, 255, 255))
    # birches
    for x in (98, 112, 240, 254):
        d.rectangle((x, 70, x + 5, 160), fill=(236, 236, 228, 255), outline=(40, 40, 40, 255))
        for y in range(76, 160, 9):
            d.line((x + 1, y, x + 3, y), fill=(40, 40, 40, 255))
    # the log lodge
    d.rectangle((120, 86, 232, 156), fill=(122, 76, 42, 255), outline=(40, 24, 14, 255), width=2)
    for y in range(90, 156, 7):
        d.line((122, y, 230, y), fill=(92, 56, 30, 255), width=2)
    d.polygon([(110, 90), (176, 44), (242, 90)], fill=(84, 52, 30, 255), outline=(40, 24, 14, 255))
    d.polygon([(114, 88), (176, 46), (238, 88), (232, 82), (176, 52), (120, 82)], fill=(244, 248, 255, 255))
    d.rectangle((164, 118, 188, 156), fill=(60, 36, 20, 255), outline=(30, 18, 10, 255))
    for wx in (134, 204):
        d.rectangle((wx, 104, wx + 16, 120), fill=(255, 210, 120, 255), outline=(40, 24, 14, 255), width=2)
        d.line((wx + 8, 104, wx + 8, 120), fill=(40, 24, 14, 255))
    d.rectangle((196, 52, 208, 72), fill=(90, 90, 96, 255), outline=(30, 30, 34, 255))
    for k in range(3):
        d.ellipse((198 + k * 4, 36 - k * 8, 210 + k * 4, 46 - k * 8), fill=(220, 224, 232, 200))
    # snow drifts in front
    for x in range(0, W, 26):
        d.ellipse((x - 8, 146, x + 30, 162), fill=(250, 252, 255, 255))
    return img


# ---------------------------------------------------------------- Donald Rump

def _driver_up(c, Y):
    c.part(L(c, [(78, Y(10)), (92, Y(-26))], 2), 'shaft', rim=False, sigma=0.3)
    c.part(E(c, (86, Y(-34), 98, Y(-24))), 'club', sigma=0.6, light_bias=0.2)


def _ball_rest(c, Y):
    c.part(L(c, [(72, Y(60)), (80, Y(88))], 2), 'shaft', rim=False, sigma=0.3)
    c.part(E(c, (76, Y(84), 88, Y(92))), 'club', sigma=0.5)


def rump(frame):
    c = Canvas(FW, FH)
    oy = 18
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame == 1 else 0
    hy = oy + bob + (14 if sit else 0) + (2 if frame == 7 else 0)
    hx = 3 if frame == 7 else 0

    def Y(v):
        return v + hy

    _legs(c, Y, sit, walk, 'dsuit', 'shoe')
    _arms(c, Y, frame, sit, walk, 'dsuit', 'dskin', None)
    torso = union(c, P(c, [(29, Y(40)), (67, Y(40)), (68, Y(68)), (28, Y(68))]),
                  E(c, (26, Y(37), 44, Y(50))), E(c, (52, Y(37), 70, Y(50))), E(c, (30, Y(52), 66, Y(70))))
    c.part(torso, 'dsuit', sigma=2.6)
    c.part(P(c, [(41, Y(38)), (55, Y(38)), (48, Y(52))]), 'shirt', sigma=0.6)
    # the extra-long red tie
    c.part(P(c, [(46, Y(40)), (50, Y(40)), (52, Y(72)), (48, Y(76)), (44, Y(72))]), 'dtie', sigma=0.5)
    c.part(L(c, [(41, Y(39)), (46, Y(56))], 2), ['#060a1a', '#0c1430', '#18264e', '#283c74'], rim=False, sigma=0.3)
    c.part(L(c, [(55, Y(39)), (50, Y(56))], 2), ['#060a1a', '#0c1430', '#18264e', '#283c74'], rim=False, sigma=0.3)
    # head
    c.part(E(c, (31 + hx, Y(-2), 65 + hx, Y(36))), 'dskin', sigma=3.0, light_bias=0.14)
    c.part(E(c, (36 + hx, Y(8), 46 + hx, Y(16))), ['#e8c0a0', '#f2d0b4', '#f8dcc4', '#ffe8d4'], rim=False, sigma=0.8)
    c.part(E(c, (50 + hx, Y(8), 60 + hx, Y(16))), ['#e8c0a0', '#f2d0b4', '#f8dcc4', '#ffe8d4'], rim=False, sigma=0.8)
    # the huge golden swoop
    swoop = union(c, E(c, (26 + hx, Y(-16), 70 + hx, Y(8))), E(c, (22 + hx, Y(-8), 44 + hx, Y(12))),
                  P(c, [(30 + hx, Y(-10)), (76 + hx, Y(-14)), (70 + hx, Y(0)), (40 + hx, Y(2))]))
    c.part(swoop, 'dhair', sigma=1.8, light_bias=0.22)
    for k in range(5):
        c.px(36 + k * 7 + hx, Y(-8) + (k % 2), '#c09024')
    c.part(E(c, (27 + hx, Y(12), 33 + hx, Y(22))), 'dskin', sigma=0.8)
    c.part(E(c, (63 + hx, Y(12), 69 + hx, Y(22))), 'dskin', sigma=0.8)
    # squinty eyes, raised brows
    for ex in (39, 53):
        if frame == 7 or sit:
            for k in range(3):
                c.px(ex + k + hx, Y(12) + k, INK); c.px(ex + 2 - k + hx, Y(12) + k, INK)
        else:
            c.part(L(c, [(ex - 1 + hx, Y(13)), (ex + 4 + hx, Y(13))], 1), ['#1a0c08', '#1a0c08', '#1a0c08', '#1a0c08'], rim=False, sigma=0.1)
        c.part(L(c, [(ex - 2 + hx, Y(8)), (ex + 5 + hx, Y(7))], 1), 'dhair', rim=False, sigma=0.2)
    c.part(P(c, [(46 + hx, Y(15)), (50 + hx, Y(15)), (52 + hx, Y(23)), (45 + hx, Y(23))]), 'dskin', sigma=0.8, light_bias=0.06)
    if frame in (4, 5, 6):          # shouting "FORE!" / "YOU'RE FIRED!"
        m = c.part(E(c, (43 + hx, Y(27), 53 + hx, Y(35))), 'mouth', sigma=0.6)
        for x in range(45 + hx, 52 + hx):
            if m[Y(28), x]:
                c.px(x, Y(28), '#f4f0e8')
    elif frame == 7 or sit:
        _mouth(c, Y, hx, frame, sit)
    else:                           # the pursed pout
        c.part(E(c, (45 + hx, Y(28), 51 + hx, Y(33))), 'mouth', sigma=0.4)
        c.part(E(c, (46 + hx, Y(29), 50 + hx, Y(31))), ['#a8484a', '#c05a5a', '#d87070', '#e88a8a'], rim=False, sigma=0.3)
    _front_arm(c, Y, frame, sit, walk, 'dsuit', 'dskin', _driver_up, _ball_rest)
    return _finish(c, oy, sit)


def gold_tower():
    W, H = 352, 184
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 120, W, 184), fill=(90, 170, 80, 255))
    # the gold tower
    d.rectangle((140, 0, 212, 150), fill=(196, 150, 40, 255), outline=(70, 50, 10, 255), width=3)
    for y in range(26, 146, 10):
        for x in range(148, 206, 12):
            d.rectangle((x, y, x + 8, y + 6), fill=(255, 226, 120, 255) if (x + y) % 3 else (230, 190, 70, 255))
    d.rectangle((134, 0, 218, 22), fill=(120, 90, 20, 255), outline=(70, 50, 10, 255), width=2)
    msg = "RUMP"
    sc = 2
    tw = text_width(msg, sc)
    draw_text(d, 176 - tw // 2, 5, msg, (255, 240, 170, 255), scale=sc)
    # clubhouse
    d.rectangle((40, 92, 132, 150), fill=(240, 236, 220, 255), outline=(60, 50, 40, 255), width=2)
    d.polygon([(32, 94), (86, 66), (140, 94)], fill=(150, 60, 50, 255), outline=(60, 30, 20, 255))
    d.rectangle((222, 100, 318, 150), fill=(240, 236, 220, 255), outline=(60, 50, 40, 255), width=2)
    d.polygon([(214, 102), (270, 74), (326, 102)], fill=(150, 60, 50, 255), outline=(60, 30, 20, 255))
    for wx in (52, 76, 100, 234, 258, 282):
        d.rectangle((wx, 108 if wx < 200 else 114, wx + 14, 126 if wx < 200 else 132), fill=(120, 190, 230, 255), outline=(60, 50, 40, 255))
    # palms
    for x in (12, 30, 334, 314):
        d.line((x, 150, x + 6, 70), fill=(140, 100, 60, 255), width=5)
        for a in range(-150, 31, 30):
            import math
            ex = x + 6 + int(math.cos(math.radians(a)) * 26)
            ey = 70 + int(math.sin(math.radians(a)) * 14) + 8
            d.line((x + 6, 70, ex, ey), fill=(40, 130, 50, 255), width=4)
    # flag + pin on the green, a gold golf cart
    d.ellipse((150, 152, 210, 168), fill=(120, 210, 100, 255))
    d.line((190, 158, 190, 128), fill=(250, 250, 250, 255), width=2)
    d.polygon([(191, 128), (206, 133), (191, 138)], fill=(220, 40, 40, 255))
    d.rectangle((246, 150, 286, 166), fill=(230, 190, 60, 255), outline=(60, 40, 10, 255))
    d.ellipse((250, 162, 260, 172), fill=(30, 30, 30, 255)); d.ellipse((274, 162, 284, 172), fill=(30, 30, 30, 255))
    d.line((250, 150, 252, 138), fill=(60, 40, 10, 255), width=2); d.line((282, 150, 280, 138), fill=(60, 40, 10, 255), width=2)
    d.rectangle((246, 134, 286, 138), fill=(255, 240, 200, 255))
    return img


def main():
    sheet = Image.new('RGBA', (PW * 10, FH), (0, 0, 0, 0))
    for f in range(10):
        sheet.alpha_composite(puddin(f), (f * PW, 0))
    sheet.save(os.path.join(OUT9, 'puddin_128.png'))
    sheet = Image.new('RGBA', (FW * 10, FH), (0, 0, 0, 0))
    for f in range(10):
        sheet.alpha_composite(rump(f), (f * FW, 0))
    sheet.save(os.path.join(OUT10, 'rump_96.png'))
    taiga_lodge().save(os.path.join(OUT9, 'taiga_lodge.png'))
    gold_tower().save(os.path.join(OUT10, 'gold_tower.png'))
    print('wrote', OUT9, OUT10)


if __name__ == '__main__':
    main()
