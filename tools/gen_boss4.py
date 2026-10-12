"""Build 018 art generator: boss 4 (SHLAUS KWOBB) and the Davos-style
summit backdrop (Python + Pillow + numpy).

Draws, from code only (no photos, no tracing, no third-party assets):
  assets/boss4/shlaus_96.png       Shlaus Kwobb sheet, 10 frames of 96x112:
                                  0-1 idle (fingertips together), 2-3 walk,
                                  4 RESET remote raised (wind-up), 5 conducting
                                  (summons / cast), 6 "no press!" hand up to the
                                  camera, 7 hurt, 8-9 defeated
  assets/boss4/summit_hall.png    arena backdrop: an alpine conference centre
                                  with snowy peaks and a SUMMIT banner (352x184)

Shlaus Kwobb here is a good-natured cartoon parody of a summit chairman:
tall, a bald dome with a white fringe, bushy white eyebrows, small rimless
glasses, a stern little smile, a dark grey high-collar suit and a VIP lanyard.
Drawn from shapes in this file only; no photo reference, no traced likeness.

Run:  python3 tools/gen_boss4.py   (writes into assets/boss4/)
"""
import os
import numpy as np
from PIL import Image, ImageDraw
import gen_boss as gb
from gen_boss import Canvas, E, P, R, L, union, INK
from pixtext import draw_text, text_width

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'boss4')
os.makedirs(OUT, exist_ok=True)
FW, FH = 96, 112

gb.PAL.update({
    'oskin': ['#8a5e4c', '#c2907a', '#e4b8a2', '#fbdccb'],
    'fringe': ['#9a9a9a', '#c8c8c4', '#e8e8e4', '#ffffff'],
    'gsuit': ['#16181c', '#262a30', '#3a3f48', '#545a66'],
    'gpant': ['#121418', '#20242a', '#30353e', '#464c58'],
    'oshoe': ['#0a0a0c', '#1a1a1e', '#2c2c32', '#44444c'],
    'lanyard': ['#0c2a6a', '#1a44a0', '#2e66d0', '#6a9af0'],
    'badge': ['#a8b0b8', '#d8dee4', '#f4f8fc', '#ffffff'],
    'remote': ['#14141a', '#26262e', '#3a3a44', '#585864'],
    'redbtn': ['#6a0a0e', '#b81a20', '#ec3a36', '#ff8a7a'],
    'omouth': ['#36100e', '#521816', '#6e2420', '#8a3430'],
})


def shlaus(frame):
    c = Canvas(FW, FH)
    oy = 12                     # a head taller than the others
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame == 1 else 0
    hy = oy + bob + (14 if sit else 0)
    if frame == 7:
        hy += 2
    tilt = 3 if frame == 7 else 0

    def Y(v):
        return v + hy

    # --- legs: long dark trousers, polished shoes
    if sit:
        c.part(P(c, [(34, Y(62)), (47, Y(62)), (46, Y(76)), (33, Y(76))]), 'gpant')
        c.part(P(c, [(49, Y(62)), (62, Y(62)), (63, Y(76)), (50, Y(76))]), 'gpant')
        c.part(E(c, (26, Y(74), 46, Y(84))), 'oshoe')
        c.part(E(c, (50, Y(74), 70, Y(84))), 'oshoe')
    else:
        lo = 2 * walk
        for side, (x0, x1) in ((0, (36, 46)), (1, (50, 60))):
            d = lo if side == 0 else -lo
            c.part(P(c, [(x0 - 1, Y(60)), (x1 + 1, Y(60)), (x1, Y(88) + d), (x0, Y(88) + d)]), 'gpant')
            box = (x0 - 4, Y(85) + d, x0 + 11, Y(92) + d) if side == 0 else (x0 - 1, Y(85) + d, x0 + 14, Y(92) + d)
            c.part(E(c, box), 'oshoe', sigma=1.4)

    # --- back arm
    swing = -walk * 2
    if sit:
        c.part(P(c, [(27, Y(42)), (34, Y(44)), (28, Y(62)), (21, Y(60))]), 'gsuit')
        c.part(E(c, (17, Y(58), 27, Y(67))), 'oskin', sigma=1.2)
    elif frame in (0, 1):
        # fingertips together in front of the chest (steepled hands)
        c.part(P(c, [(27, Y(42)), (34, Y(44)), (42, Y(54)), (36, Y(58))]), 'gsuit')
    elif frame == 5:
        # both arms "conducting": back hand up and out
        c.part(P(c, [(27, Y(42)), (34, Y(44)), (22, Y(30)), (16, Y(34))]), 'gsuit')
        c.part(E(c, (10, Y(24), 21, Y(35))), 'oskin', sigma=1.2)
    else:
        c.part(P(c, [(27, Y(42)), (34, Y(44)), (32, Y(64) + swing), (25, Y(64) + swing)]), 'gsuit')
        c.part(E(c, (23, Y(62) + swing, 32, Y(71) + swing)), 'oskin', sigma=1.2)

    # --- torso: long high-collar (collarless) jacket, two rows of buttons
    torso = union(c, P(c, [(31, Y(42)), (65, Y(42)), (64, Y(70)), (32, Y(70))]),
                  E(c, (28, Y(39), 42, Y(50))), E(c, (54, Y(39), 68, Y(50))))
    c.part(torso, 'gsuit', sigma=2.6)
    c.part(R(c, (41, Y(38), 55, Y(44))), 'gsuit', sigma=0.8, light_bias=0.18)   # stand-up collar
    for y in (50, 56, 62):
        c.px(44, Y(y), '#7a808c'); c.px(52, Y(y), '#7a808c')
    for y in range(44, 70):
        c.px(48, Y(y), '#0c0e12')
    # VIP lanyard + badge
    c.part(L(c, [(41, Y(42)), (46, Y(56))], 2), 'lanyard', rim=False, sigma=0.3)
    c.part(L(c, [(55, Y(42)), (50, Y(56))], 2), 'lanyard', rim=False, sigma=0.3)
    c.part(R(c, (42, Y(55), 54, Y(66))), 'badge', sigma=0.6)
    c.part(R(c, (43, Y(56), 53, Y(58))), 'lanyard', rim=False, sigma=0.3)
    for x in range(44, 52):
        if x % 2 == 0:
            c.px(x, Y(61), '#3a3a40')
    c.px(45, Y(63), '#3a3a40'); c.px(46, Y(63), '#3a3a40'); c.px(47, Y(63), '#3a3a40')
    if frame in (0, 1):
        # steepled fingertips over the badge
        c.part(P(c, [(36, Y(56)), (48, Y(46)), (60, Y(56)), (48, Y(60))]), 'oskin', sigma=1.0)
        for k in range(4):
            c.px(48, Y(47 + k), '#a87a66')

    # --- head: tall bald dome, white fringe, big ears
    hx = tilt
    c.part(E(c, (25 + hx, Y(14), 32 + hx, Y(29))), 'oskin', sigma=1.0)
    c.part(E(c, (64 + hx, Y(14), 71 + hx, Y(29))), 'oskin', sigma=1.0)
    head = union(c, E(c, (28 + hx, Y(-12), 68 + hx, Y(34))),
                 P(c, [(33 + hx, Y(22)), (63 + hx, Y(22)), (57 + hx, Y(40)), (39 + hx, Y(40))]))
    c.part(head, 'oskin', sigma=3.4, light_bias=0.03)
    # white fringe on the sides and back
    for (x0, x1) in ((27, 34), (62, 69)):
        fr = E(c, (x0 + hx, Y(2), x1 + hx, Y(20)))
        c.part(fr, 'fringe', sigma=1.0)
    # dome shine + forehead lines
    for (x, y) in [(40, -8), (41, -8), (42, -8), (39, -7), (40, -7), (41, -7), (42, -7), (40, -6), (41, -6)]:
        c.px(x + hx, Y(y), '#ffffff')
    for yy in (3, 6):
        for x in range(40, 57):
            if x % 4:
                c.px(x + hx, Y(yy), '#c08a72')
    # bushy white eyebrows
    if frame == 7 or sit:
        b1 = [(34 + hx, Y(10)), (45 + hx, Y(13))]
        b2 = [(51 + hx, Y(13)), (62 + hx, Y(10))]
    else:
        b1 = [(34 + hx, Y(12)), (40 + hx, Y(10)), (46 + hx, Y(12))]
        b2 = [(50 + hx, Y(12)), (56 + hx, Y(10)), (62 + hx, Y(12))]
    c.part(L(c, b1, 3), 'fringe', rim=False, sigma=0.4)
    c.part(L(c, b2, 3), 'fringe', rim=False, sigma=0.4)
    # small rimless rectangular glasses
    for i, x0 in enumerate((35, 50)):
        dy = 2 if (i == 1 and (frame == 7 or sit)) else 0
        lens = R(c, (x0 + hx, Y(15) + dy, x0 + 10 + hx, Y(21) + dy))
        c.part(lens, ['#9ab8c8', '#c4dce8', '#e4f2f8', '#ffffff'], rim=False, sigma=0.6, light_bias=0.2)
        ex, ey = x0 + 4 + hx, Y(17) + dy
        if frame == 7:
            for k in range(3):
                c.px(ex + k, ey + k, INK); c.px(ex + 2 - k, ey + k, INK)
        elif sit:
            for k in range(3):
                c.px(ex + k, ey + k, INK); c.px(ex + 2 - k, ey + k, INK)
        else:
            c.px(ex, ey + 1, INK); c.px(ex + 1, ey + 1, INK); c.px(ex + 1, ey + 2, INK); c.px(ex, ey + 2, INK)
        c.px(x0 + 8 + hx, Y(16) + dy, '#ffffff')
    c.part(L(c, [(45 + hx, Y(17)), (50 + hx, Y(17))], 1), ['#7a7a80', '#9a9aa0', '#babac0', '#dadae0'], rim=False, sigma=0.2)
    # nose
    c.part(P(c, [(47 + hx, Y(19)), (50 + hx, Y(19)), (52 + hx, Y(28)), (45 + hx, Y(28))]), 'oskin', sigma=0.8, light_bias=0.06)
    c.px(46 + hx, Y(28), '#9a6a58'); c.px(51 + hx, Y(28), '#9a6a58')
    # mouth: stern little smile / open for speeches
    mx = hx
    if frame == 7:
        c.part(E(c, (44 + mx, Y(31), 52 + mx, Y(37))), 'omouth', sigma=0.6)
    elif sit:
        c.part(L(c, [(42 + mx, Y(34)), (46 + mx, Y(32)), (50 + mx, Y(34)), (54 + mx, Y(32))], 2), 'omouth', rim=False, sigma=0.4)
    elif frame in (4, 5, 6):
        m = c.part(E(c, (43 + mx, Y(30), 53 + mx, Y(36))), 'omouth', sigma=0.6)
        for x in range(45 + mx, 52 + mx):
            if m[Y(31), x]:
                c.px(x, Y(31), '#f4f0e8')
    else:
        c.part(L(c, [(42 + mx, Y(32)), (46 + mx, Y(33)), (51 + mx, Y(33)), (55 + mx, Y(31))], 2), 'omouth', rim=False, sigma=0.3)
    # chin dimple + jowls
    c.px(48 + hx, Y(37), '#b07e6a')

    # --- front arm
    if frame == 4:
        # raises the big red RESET remote overhead
        c.part(P(c, [(62, Y(42)), (69, Y(40)), (80, Y(14)), (74, Y(11))]), 'gsuit')
        c.part(E(c, (72, Y(4), 83, Y(15))), 'oskin', sigma=1.2)
        c.part(R(c, (70, Y(-12), 86, Y(4))), 'remote', sigma=0.8)
        c.part(E(c, (73, Y(-10), 83, Y(0))), 'redbtn', sigma=0.8, light_bias=0.15)
        c.px(76, Y(-8), '#ffd0c8'); c.px(77, Y(-8), '#ffd0c8')
        for d in range(1, 5):
            c.px(78, Y(-12) - d * 2, '#ff6060')
    elif frame == 5:
        # conducting: front hand up and out (summoning the delegates)
        c.part(P(c, [(62, Y(42)), (69, Y(44)), (82, Y(30)), (76, Y(26))]), 'gsuit')
        c.part(E(c, (76, Y(20), 87, Y(31))), 'oskin', sigma=1.2)
        for k in range(4):
            c.px(78 + k * 2, Y(19), '#fbdccb')
    elif frame == 6:
        # "NO PRESS!" palm up toward the camera
        c.part(P(c, [(62, Y(42)), (69, Y(40)), (76, Y(28)), (70, Y(25))]), 'gsuit')
        palm = union(c, E(c, (64, Y(10), 80, Y(26))),
                     E(c, (64, Y(4), 68, Y(14))), E(c, (68, Y(2), 72, Y(12))),
                     E(c, (72, Y(3), 76, Y(13))), E(c, (76, Y(6), 80, Y(15))))
        c.part(palm, 'oskin', sigma=1.0)
    elif frame in (0, 1):
        c.part(P(c, [(62, Y(42)), (69, Y(44)), (60, Y(56)), (54, Y(54))]), 'gsuit')
    elif sit:
        c.part(P(c, [(63, Y(44)), (69, Y(42)), (75, Y(60)), (68, Y(62))]), 'gsuit')
        c.part(E(c, (69, Y(58), 79, Y(67))), 'oskin', sigma=1.2)
        c.part(R(c, (74, Y(70), 88, Y(82))), 'remote', sigma=0.8)
        c.part(E(c, (77, Y(72), 85, Y(80))), ['#3a1a1a', '#5a2a2a', '#7a3a3a', '#9a4a4a'], sigma=0.6)
    elif frame == 7:
        c.part(P(c, [(62, Y(42)), (69, Y(40)), (79, Y(32)), (75, Y(27))]), 'gsuit')
        c.part(E(c, (73, Y(22), 83, Y(32))), 'oskin', sigma=1.2)
    else:
        c.part(P(c, [(63, Y(44)), (70, Y(42)), (72, Y(64) - swing), (65, Y(64) - swing)]), 'gsuit')
        c.part(E(c, (64, Y(62) - swing, 74, Y(71) - swing)), 'oskin', sigma=1.2)

    img = c.finish()
    sh = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    gy = (oy + 14 + 78) if sit else (oy + 92)
    d.ellipse((26, gy - 4, 70, gy + 5), fill=(10, 20, 30, 90))
    sh.alpha_composite(img)
    return sh


def summit_hall():
    W, H = 352, 184
    c = Canvas(W, H)
    rock = ['#5a6478', '#7a86a0', '#a0aac0', '#c8d0e0']
    snow = ['#b8c8dc', '#d8e4f0', '#eef4fa', '#ffffff']
    wood = ['#3a2416', '#5a3a22', '#7e5632', '#a47a4c']
    glass = ['#0e1a2a', '#1a2e48', '#2c4a70', '#4a72a0']
    # snowy peaks behind
    c.part(P(c, [(0, 110), (60, 20), (120, 100)]), rock, sigma=3.0)
    c.part(P(c, [(90, 110), (176, 6), (262, 110)]), rock, sigma=3.0)
    c.part(P(c, [(230, 110), (300, 28), (352, 96), (352, 110)]), rock, sigma=3.0)
    c.part(P(c, [(46, 36), (60, 20), (74, 36), (66, 42), (58, 36), (52, 42)]), snow, sigma=1.0)
    c.part(P(c, [(156, 30), (176, 6), (196, 30), (186, 38), (176, 30), (166, 38)]), snow, sigma=1.0)
    c.part(P(c, [(286, 44), (300, 28), (314, 44), (306, 50), (298, 44), (292, 50)]), snow, sigma=1.0)
    # the conference centre: glass hall with a broad chalet roof
    c.part(R(c, (20, 104, 332, 178)), glass, sigma=4.0)
    c.part(P(c, [(6, 108), (176, 62), (346, 108), (346, 116), (176, 72), (6, 116)]), wood, sigma=2.0)
    c.part(P(c, [(10, 106), (176, 60), (342, 106), (342, 110), (176, 66), (10, 110)]), snow, rim=False, sigma=1.0)
    img = c.finish()
    d = ImageDraw.Draw(img)
    # mullions + warm lit windows
    for x in range(30, 326, 14):
        d.line((x, 118, x, 178), fill=(70, 100, 140, 255))
    for x in range(36, 320, 28):
        d.rectangle((x, 150, x + 8, 160), fill=(255, 210, 120, 255))
    # entrance
    d.rectangle((160, 146, 192, 178), fill=(20, 26, 40, 255))
    d.rectangle((162, 148, 190, 178), fill=(255, 220, 150, 170))
    # SUMMIT banner under the roof
    msg = "WORLD SUMMIT"
    sc = 2
    tw = text_width(msg, sc)
    bx0 = (W - tw) // 2 - 8
    bx1 = bx0 + tw + 16
    d.rectangle((bx0 - 2, 118, bx1 + 2, 136), fill=(24, 12, 20, 255))
    d.rectangle((bx0, 120, bx1, 134), fill=(26, 68, 160, 255))
    draw_text(d, bx0 + 8, 122, msg, (255, 255, 255, 255), scale=sc)
    # little generic pennants (plain colours) on poles either side
    for i, x in enumerate((30, 60, 292, 322)):
        d.line((x, 104, x, 70), fill=(200, 200, 210, 255), width=2)
        col = [(220, 60, 60, 255), (60, 140, 220, 255), (240, 200, 60, 255), (80, 180, 110, 255)][i]
        d.polygon([(x + 1, 70), (x + 18, 75), (x + 1, 80)], fill=col)
    # snow drifts along the base
    for x in range(10, 344, 22):
        d.ellipse((x, 172, x + 26, 186), fill=(240, 246, 252, 255))
    return img


def main():
    sheet = Image.new('RGBA', (FW * 10, FH), (0, 0, 0, 0))
    for f in range(10):
        sheet.alpha_composite(shlaus(f), (f * FW, 0))
    sheet.save(os.path.join(OUT, 'shlaus_96.png'))
    summit_hall().save(os.path.join(OUT, 'summit_hall.png'))
    print('wrote', OUT)


if __name__ == '__main__':
    main()
