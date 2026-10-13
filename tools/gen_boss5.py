"""Build 020 art generator: boss 5 (GILL BATES) and boss 6 (NANCY PELOTTO),
plus their arena backdrops (Python + Pillow + numpy).

Drawn from code only (no photos, no tracing, no third-party assets):
  assets/boss5/gill_96.png        Gill Bates sheet, 10 frames of 96x112
  assets/boss5/server_gala.png    arena backdrop: a server farm dressed up for a
                                  FOUNDATION GALA (352x184)
  assets/boss6/nancy_96.png       Nancy Pelotto sheet, 10 frames of 96x112
  assets/boss6/capitol_hall.png   arena backdrop: a domed Capitol with an
                                  IN SESSION banner (352x184)
Frames (same as boss 4): 0-1 idle, 2-3 walk, 4 big wind-up prop raised,
5 cast (hand up), 6 palm up to the camera, 7 hurt, 8-9 defeated.

Both are good-natured cartoon parodies built from generic features only:
Gill = a cheerful software tycoon (sandy mop with a side part, big round
glasses, pale-blue V-neck sweater over a collared shirt, khakis, a floppy disk
for a prop). Nancy = a speaker of the house (auburn bob, magenta pantsuit,
pearls, a giant gavel, an ice-cream cone at rest).

Run:  python3 tools/gen_boss5.py
"""
import os
from PIL import Image, ImageDraw
import gen_boss as gb
from gen_boss import Canvas, E, P, R, L, union, INK
from pixtext import draw_text, text_width

HERE = os.path.dirname(os.path.abspath(__file__))
OUT5 = os.path.join(HERE, '..', 'assets', 'boss5')
OUT6 = os.path.join(HERE, '..', 'assets', 'boss6')
os.makedirs(OUT5, exist_ok=True)
os.makedirs(OUT6, exist_ok=True)
FW, FH = 96, 112

gb.PAL.update({
    'gskin': ['#8a5e4c', '#c2907a', '#e8bea6', '#fbe0cf'],
    'ghair': ['#5a3e1e', '#8a6432', '#b48c4c', '#d8b474'],
    'sweater': ['#2a4a72', '#3e6ea0', '#6a9ad0', '#a4c8f0'],
    'collar': ['#9aa4b0', '#d0d8e0', '#f0f4f8', '#ffffff'],
    'khaki': ['#5a4a2a', '#8a7444', '#b49c66', '#d4c08a'],
    'gshoe': ['#1a120c', '#2e2016', '#463222', '#604632'],
    'floppy': ['#0a0a12', '#1a1a2a', '#2c2c44', '#46466a'],
    'label': ['#a8a8a0', '#d8d8d0', '#f4f4ec', '#ffffff'],
    'nhair': ['#4a1c12', '#7a301e', '#a8482c', '#d06a44'],
    'pantsuit': ['#5a0a3a', '#8e1660', '#c42a88', '#ec5ab0'],
    'blouse': ['#a8a0a0', '#d8d0d0', '#f4eeee', '#ffffff'],
    'pearl': ['#b8b0a8', '#e0d8d0', '#f8f4f0', '#ffffff'],
    'gavel': ['#3a1e0e', '#5e341a', '#86522c', '#b07a48'],
    'cone': ['#7a4a1a', '#b07a32', '#d8a456', '#f0c880'],
    'scoop': ['#7a4a3a', '#b07a6a', '#e8b8a8', '#ffe4dc'],
    'nshoe': ['#2a0418', '#4a0a2c', '#6a1240', '#8a2058'],
    'mouth': ['#36100e', '#521816', '#6e2420', '#8a3430'],
    'lips': ['#6a0a2a', '#a0183e', '#d03058', '#f06a88'],
})


def _legs(c, Y, sit, walk, pant, shoe):
    if sit:
        c.part(P(c, [(34, Y(62)), (47, Y(62)), (46, Y(76)), (33, Y(76))]), pant)
        c.part(P(c, [(49, Y(62)), (62, Y(62)), (63, Y(76)), (50, Y(76))]), pant)
        c.part(E(c, (26, Y(74), 46, Y(84))), shoe)
        c.part(E(c, (50, Y(74), 70, Y(84))), shoe)
        return
    lo = 2 * walk
    for side, (x0, x1) in ((0, (36, 46)), (1, (50, 60))):
        d = lo if side == 0 else -lo
        c.part(P(c, [(x0 - 1, Y(60)), (x1 + 1, Y(60)), (x1, Y(88) + d), (x0, Y(88) + d)]), pant)
        box = (x0 - 4, Y(85) + d, x0 + 11, Y(92) + d) if side == 0 else (x0 - 1, Y(85) + d, x0 + 14, Y(92) + d)
        c.part(E(c, box), shoe, sigma=1.4)


def _eyes(c, Y, hx, frame, sit, y=17, big_glasses=False):
    for i, x0 in enumerate((36, 51)):
        ex, ey = x0 + 3 + hx, Y(y)
        if big_glasses:
            c.part(E(c, (x0 - 2 + hx, Y(y - 4), x0 + 10 + hx, Y(y + 6))), ['#3a3a40', '#6a6a72', '#9a9aa2', '#c8c8d0'], rim=False, sigma=0.3)
            c.part(E(c, (x0 + hx, Y(y - 2), x0 + 8 + hx, Y(y + 4))), ['#b8d0dc', '#d8e8f0', '#eef6fa', '#ffffff'], rim=False, sigma=0.4, light_bias=0.2)
        if frame == 7 or sit:
            for k in range(3):
                c.px(ex + k, ey + k, INK); c.px(ex + 2 - k, ey + k, INK)
        else:
            c.px(ex, ey, INK); c.px(ex + 1, ey, INK); c.px(ex, ey + 1, INK); c.px(ex + 1, ey + 1, INK)
    if big_glasses:
        c.part(L(c, [(46 + hx, Y(y)), (51 + hx, Y(y))], 1), ['#3a3a40', '#5a5a62', '#7a7a82', '#9a9aa2'], rim=False, sigma=0.2)


def _mouth(c, Y, hx, frame, sit, pal='mouth'):
    if frame == 7:
        c.part(E(c, (44 + hx, Y(30), 52 + hx, Y(36))), 'mouth', sigma=0.6)
    elif sit:
        c.part(L(c, [(42 + hx, Y(33)), (46 + hx, Y(31)), (50 + hx, Y(33)), (54 + hx, Y(31))], 2), pal, rim=False, sigma=0.4)
    elif frame in (4, 5, 6):
        m = c.part(E(c, (43 + hx, Y(29), 53 + hx, Y(35))), 'mouth', sigma=0.6)
        for x in range(45 + hx, 52 + hx):
            if m[Y(30), x]:
                c.px(x, Y(30), '#f4f0e8')
    else:   # big friendly grin
        c.part(L(c, [(41 + hx, Y(29)), (44 + hx, Y(32)), (52 + hx, Y(32)), (55 + hx, Y(29))], 2), pal, rim=False, sigma=0.3)


def _finish(c, oy, sit):
    img = c.finish()
    sh = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    gy = (oy + 14 + 78) if sit else (oy + 92)
    d.ellipse((26, gy - 4, 70, gy + 5), fill=(10, 20, 30, 90))
    sh.alpha_composite(img)
    return sh


def _arms(c, Y, frame, sit, walk, sleeve, skin, prop_up, prop_rest=None):
    swing = -walk * 2
    # back arm
    if sit:
        c.part(P(c, [(27, Y(42)), (34, Y(44)), (28, Y(62)), (21, Y(60))]), sleeve)
        c.part(E(c, (17, Y(58), 27, Y(67))), skin, sigma=1.2)
    elif frame == 5:
        c.part(P(c, [(27, Y(42)), (34, Y(44)), (22, Y(30)), (16, Y(34))]), sleeve)
        c.part(E(c, (10, Y(24), 21, Y(35))), skin, sigma=1.2)
    else:
        c.part(P(c, [(27, Y(42)), (34, Y(44)), (32, Y(64) + swing), (25, Y(64) + swing)]), sleeve)
        c.part(E(c, (23, Y(62) + swing, 32, Y(71) + swing)), skin, sigma=1.2)


def _front_arm(c, Y, frame, sit, walk, sleeve, skin, prop_up, prop_rest):
    swing = -walk * 2
    if frame == 4:
        c.part(P(c, [(62, Y(42)), (69, Y(40)), (80, Y(14)), (74, Y(11))]), sleeve)
        c.part(E(c, (72, Y(4), 83, Y(15))), skin, sigma=1.2)
        prop_up(c, Y)
    elif frame == 5:
        c.part(P(c, [(62, Y(42)), (69, Y(44)), (82, Y(30)), (76, Y(26))]), sleeve)
        c.part(E(c, (76, Y(20), 87, Y(31))), skin, sigma=1.2)
    elif frame == 6:
        c.part(P(c, [(62, Y(42)), (69, Y(40)), (76, Y(28)), (70, Y(25))]), sleeve)
        palm = union(c, E(c, (64, Y(10), 80, Y(26))),
                     E(c, (64, Y(4), 68, Y(14))), E(c, (68, Y(2), 72, Y(12))),
                     E(c, (72, Y(3), 76, Y(13))), E(c, (76, Y(6), 80, Y(15))))
        c.part(palm, skin, sigma=1.0)
    elif sit:
        c.part(P(c, [(63, Y(44)), (69, Y(42)), (75, Y(60)), (68, Y(62))]), sleeve)
        c.part(E(c, (69, Y(58), 79, Y(67))), skin, sigma=1.2)
    elif frame == 7:
        c.part(P(c, [(62, Y(42)), (69, Y(40)), (79, Y(32)), (75, Y(27))]), sleeve)
        c.part(E(c, (73, Y(22), 83, Y(32))), skin, sigma=1.2)
    else:
        c.part(P(c, [(63, Y(44)), (70, Y(42)), (72, Y(64) - swing), (65, Y(64) - swing)]), sleeve)
        c.part(E(c, (64, Y(62) - swing, 74, Y(71) - swing)), skin, sigma=1.2)
        if prop_rest is not None and frame in (0, 1):
            prop_rest(c, Y)


# ---------------------------------------------------------------- Gill Bates

def _floppy_up(c, Y):
    c.part(R(c, (68, Y(-14), 88, Y(6))), 'floppy', sigma=0.8)
    c.part(R(c, (72, Y(-14), 84, Y(-7))), 'label', rim=False, sigma=0.4)
    c.part(R(c, (71, Y(-3), 85, Y(5))), 'label', sigma=0.4)
    for d in range(1, 5):
        c.px(78, Y(-14) - d * 2, '#80c8ff')


def gill(frame):
    c = Canvas(FW, FH)
    oy = 16
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame == 1 else 0
    hy = oy + bob + (14 if sit else 0) + (2 if frame == 7 else 0)
    hx = 3 if frame == 7 else 0

    def Y(v):
        return v + hy

    _legs(c, Y, sit, walk, 'khaki', 'gshoe')
    _arms(c, Y, frame, sit, walk, 'sweater', 'gskin', None)
    torso = union(c, P(c, [(31, Y(40)), (65, Y(40)), (64, Y(66)), (32, Y(66))]),
                  E(c, (28, Y(37), 42, Y(48))), E(c, (54, Y(37), 68, Y(48))))
    c.part(torso, 'sweater', sigma=2.6)
    # V-neck with the shirt collar
    c.part(P(c, [(40, Y(38)), (56, Y(38)), (48, Y(52))]), 'collar', sigma=0.6)
    c.part(P(c, [(40, Y(37)), (46, Y(37)), (44, Y(43))]), 'collar', sigma=0.4, light_bias=0.2)
    c.part(P(c, [(50, Y(37)), (56, Y(37)), (52, Y(43))]), 'collar', sigma=0.4, light_bias=0.2)
    for y in range(58, 66):
        if y % 2 == 0:
            c.px(34, Y(y), '#2a4a72'); c.px(62, Y(y), '#2a4a72')
    # head
    c.part(E(c, (27 + hx, Y(12), 34 + hx, Y(26))), 'gskin', sigma=1.0)
    c.part(E(c, (62 + hx, Y(12), 69 + hx, Y(26))), 'gskin', sigma=1.0)
    head = union(c, E(c, (30 + hx, Y(-6), 66 + hx, Y(34))))
    c.part(head, 'gskin', sigma=3.2, light_bias=0.12)
    # sandy mop with a side part, sweeping over the forehead
    hair = union(c, E(c, (29 + hx, Y(-9), 67 + hx, Y(6))),
                 P(c, [(29 + hx, Y(0)), (44 + hx, Y(-4)), (60 + hx, Y(4)), (36 + hx, Y(9))]),
                 E(c, (28 + hx, Y(-2), 35 + hx, Y(14))), E(c, (61 + hx, Y(-2), 68 + hx, Y(14))))
    c.part(hair, 'ghair', sigma=1.6)
    for x in range(36, 40):
        c.px(x + hx, Y(-6), '#3a2810')
    for k in range(6):
        c.px(42 + k * 3 + hx, Y(2 + (k % 2)), '#6a4a22')
    _eyes(c, Y, hx, frame, sit, y=18, big_glasses=True)
    # nose
    c.part(P(c, [(47 + hx, Y(20)), (50 + hx, Y(20)), (51 + hx, Y(26)), (46 + hx, Y(26))]), 'gskin', sigma=0.8, light_bias=0.06)
    _mouth(c, Y, hx, frame, sit)
    _front_arm(c, Y, frame, sit, walk, 'sweater', 'gskin', _floppy_up, None)
    return _finish(c, oy, sit)


def server_gala():
    W, H = 352, 184
    c = Canvas(W, H)
    wall = ['#1a1e2a', '#2a3040', '#3c4458', '#566078']
    rack = ['#0c0e14', '#1a1e28', '#2a3040', '#3e4658']
    roof = ['#20242e', '#343a48', '#4c5466', '#6a7488']
    c.part(R(c, (14, 60, 338, 180)), wall, sigma=3.0)
    c.part(P(c, [(4, 64), (348, 64), (338, 50), (14, 50)]), roof, sigma=1.5)
    # cooling units on the roof
    for x in (40, 110, 220, 290):
        c.part(R(c, (x, 34, x + 36, 50)), roof, sigma=1.0)
    img = c.finish()
    d = ImageDraw.Draw(img)
    for x in (44, 114, 224, 294):
        for k in range(3):
            d.ellipse((x + k * 10, 38, x + k * 10 + 8, 46), fill=(30, 34, 44, 255), outline=(90, 100, 120, 255))
    # glass front showing server racks with blinking LEDs
    d.rectangle((28, 96, 324, 178), fill=(14, 20, 34, 255))
    import random
    rnd = random.Random(2020)
    for x in range(34, 318, 24):
        d.rectangle((x, 100, x + 18, 176), fill=(22, 26, 36, 255), outline=(60, 70, 90, 255))
        for y in range(104, 172, 6):
            d.line((x + 2, y, x + 16, y), fill=(40, 46, 60, 255))
            col = rnd.choice([(80, 255, 120, 255), (80, 200, 255, 255), (255, 200, 60, 255), (40, 60, 50, 255)])
            d.point((x + 14, y + 2), fill=col)
            d.point((x + 12, y + 2), fill=rnd.choice([(80, 255, 120, 255), (40, 60, 50, 255)]))
    # gala red carpet entrance + string lights
    d.rectangle((160, 140, 192, 178), fill=(20, 26, 40, 255))
    d.rectangle((162, 142, 190, 178), fill=(255, 230, 170, 170))
    for i in range(0, 352, 12):
        yy = 70 + int(6 * abs(((i // 12) % 6) - 3))
        d.ellipse((i, yy, i + 4, yy + 4), fill=[(255, 220, 120, 255), (255, 120, 200, 255), (120, 220, 255, 255)][(i // 12) % 3])
    msg = "FOUNDATION GALA"
    sc = 2
    tw = text_width(msg, sc)
    bx0 = (W - tw) // 2 - 8
    bx1 = bx0 + tw + 16
    d.rectangle((bx0 - 2, 76, bx1 + 2, 94), fill=(24, 12, 20, 255))
    d.rectangle((bx0, 78, bx1, 92), fill=(30, 110, 190, 255))
    draw_text(d, bx0 + 8, 80, msg, (255, 255, 255, 255), scale=sc)
    return img


# ---------------------------------------------------------------- Nancy Pelotto

def _gavel_up(c, Y):
    c.part(L(c, [(78, Y(10)), (78, Y(-2))], 3), 'gavel', rim=False, sigma=0.4)
    c.part(R(c, (66, Y(-13), 90, Y(-2))), 'gavel', sigma=0.8)
    c.part(R(c, (64, Y(-12), 68, Y(-3))), ['#806030', '#b08840', '#e0b850', '#fff080'], rim=False, sigma=0.3)
    c.part(R(c, (88, Y(-12), 92, Y(-3))), ['#806030', '#b08840', '#e0b850', '#fff080'], rim=False, sigma=0.3)


def _cone_rest(c, Y):
    c.part(P(c, [(68, Y(56)), (78, Y(56)), (73, Y(70))]), 'cone', sigma=0.6)
    c.part(E(c, (66, Y(46), 80, Y(58))), 'scoop', sigma=0.8, light_bias=0.1)
    c.px(73, Y(47), '#c8202a')


def nancy(frame):
    c = Canvas(FW, FH)
    oy = 18
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame == 1 else 0
    hy = oy + bob + (14 if sit else 0) + (2 if frame == 7 else 0)
    hx = 3 if frame == 7 else 0

    def Y(v):
        return v + hy

    _legs(c, Y, sit, walk, 'pantsuit', 'nshoe')
    _arms(c, Y, frame, sit, walk, 'pantsuit', 'gskin', None)
    torso = union(c, P(c, [(32, Y(40)), (64, Y(40)), (63, Y(66)), (33, Y(66))]),
                  E(c, (29, Y(37), 43, Y(48))), E(c, (53, Y(37), 67, Y(48))))
    c.part(torso, 'pantsuit', sigma=2.6)
    c.part(P(c, [(41, Y(38)), (55, Y(38)), (48, Y(50))]), 'blouse', sigma=0.6)
    # lapels + buttons
    c.part(L(c, [(41, Y(39)), (46, Y(52))], 2), ['#3a0626', '#5a0a3a', '#7a1250', '#9a2068'], rim=False, sigma=0.3)
    c.part(L(c, [(55, Y(39)), (50, Y(52))], 2), ['#3a0626', '#5a0a3a', '#7a1250', '#9a2068'], rim=False, sigma=0.3)
    for y in (54, 60):
        c.px(48, Y(y), '#f0c0e0')
    # pearls
    for k in range(7):
        a = k / 6.0
        x = int(41 + a * 14)
        y = int(39 + 4 * (1 - (2 * a - 1) ** 2))
        c.part(E(c, (x - 1, Y(y) - 1, x + 2, Y(y) + 2)), 'pearl', rim=False, sigma=0.3, light_bias=0.2)
    # head + coiffed bob
    hair_back = union(c, E(c, (26 + hx, Y(-8), 70 + hx, Y(30))))
    c.part(hair_back, 'nhair', sigma=2.0)
    c.part(E(c, (32 + hx, Y(-2), 64 + hx, Y(34))), 'gskin', sigma=3.0, light_bias=0.16)
    fringe = union(c, E(c, (28 + hx, Y(-10), 68 + hx, Y(10))),
                   P(c, [(30 + hx, Y(2)), (40 + hx, Y(-4)), (34 + hx, Y(12))]))
    c.part(fringe, 'nhair', sigma=1.6)
    c.part(E(c, (24 + hx, Y(10), 34 + hx, Y(32))), 'nhair', sigma=1.2)
    c.part(E(c, (62 + hx, Y(10), 72 + hx, Y(32))), 'nhair', sigma=1.2)
    for k in range(5):
        c.px(38 + k * 5 + hx, Y(-6), '#d88050')
    # earrings
    c.part(E(c, (32 + hx, Y(24), 36 + hx, Y(28))), 'pearl', rim=False, sigma=0.3)
    c.part(E(c, (60 + hx, Y(24), 64 + hx, Y(28))), 'pearl', rim=False, sigma=0.3)
    _eyes(c, Y, hx, frame, sit, y=15)
    # brows
    c.part(L(c, [(35 + hx, Y(11)), (44 + hx, Y(10))], 1), 'nhair', rim=False, sigma=0.2)
    c.part(L(c, [(52 + hx, Y(10)), (61 + hx, Y(11))], 1), 'nhair', rim=False, sigma=0.2)
    c.part(P(c, [(47 + hx, Y(17)), (50 + hx, Y(17)), (51 + hx, Y(23)), (46 + hx, Y(23))]), 'gskin', sigma=0.8, light_bias=0.06)
    _mouth(c, Y, hx, frame, sit, pal='lips')
    _front_arm(c, Y, frame, sit, walk, 'pantsuit', 'gskin', _gavel_up, _cone_rest)
    return _finish(c, oy, sit)


def capitol_hall():
    W, H = 352, 184
    c = Canvas(W, H)
    marble = ['#9aa0aa', '#c4c8d0', '#e4e6ec', '#ffffff']
    shade = ['#6a707c', '#8a909c', '#aab0bc', '#cacfd8']
    # wings
    c.part(R(c, (10, 110, 342, 178)), marble, sigma=3.0)
    # drum + dome + lantern
    c.part(R(c, (120, 64, 232, 112)), marble, sigma=2.0)
    c.part(E(c, (116, 10, 236, 120)), marble, sigma=3.0, light_bias=0.05)
    c.part(R(c, (116, 64, 236, 72)), shade, rim=False, sigma=0.6)
    c.part(R(c, (168, 0, 184, 16)), marble, sigma=0.8)
    img = c.finish()
    d = ImageDraw.Draw(img)
    # cut the dome ellipse at the drum (lower half hidden by the drum)
    for x in range(124, 230, 10):
        d.line((x, 72, x, 110), fill=(150, 156, 168, 255))
    for x in range(20, 340, 16):
        d.line((x, 120, x, 176), fill=(160, 166, 178, 255), width=3)
    d.polygon([(140, 112), (176, 92), (212, 112)], fill=(230, 232, 238, 255), outline=(120, 126, 140, 255))
    d.rectangle((158, 144, 194, 178), fill=(40, 34, 30, 255))
    d.rectangle((160, 146, 192, 178), fill=(255, 220, 150, 170))
    # flags (plain stripes, no real flag detail)
    for x in (40, 312):
        d.line((x, 110, x, 70), fill=(200, 200, 210, 255), width=2)
        for k in range(4):
            d.rectangle((x + 1, 70 + k * 3, x + 20, 71 + k * 3), fill=(210, 50, 60, 255) if k % 2 == 0 else (245, 245, 245, 255))
        d.rectangle((x + 1, 70, x + 8, 76), fill=(40, 70, 160, 255))
    msg = "IN SESSION"
    sc = 2
    tw = text_width(msg, sc)
    bx0 = (W - tw) // 2 - 8
    bx1 = bx0 + tw + 16
    d.rectangle((bx0 - 2, 122, bx1 + 2, 140), fill=(24, 12, 20, 255))
    d.rectangle((bx0, 124, bx1, 138), fill=(140, 20, 90, 255))
    draw_text(d, bx0 + 8, 126, msg, (255, 255, 255, 255), scale=sc)
    return img


def main():
    for fn, out, name in ((gill, OUT5, 'gill_96.png'), (nancy, OUT6, 'nancy_96.png')):
        sheet = Image.new('RGBA', (FW * 10, FH), (0, 0, 0, 0))
        for f in range(10):
            sheet.alpha_composite(fn(f), (f * FW, 0))
        sheet.save(os.path.join(out, name))
    server_gala().save(os.path.join(OUT5, 'server_gala.png'))
    capitol_hall().save(os.path.join(OUT6, 'capitol_hall.png'))
    print('wrote', OUT5, OUT6)


if __name__ == '__main__':
    main()
