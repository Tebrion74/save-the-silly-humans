"""Build 018 art generator: boss 3 (BEORGE KUSH JR.), his jet and the
flight-deck backdrop (Python + Pillow + numpy).

Draws, from code only (no photos, no tracing, no third-party assets):
  assets/boss3/kush_96.png        Beorge Kush Jr. sheet, 10 frames of 96x112:
                                  0-1 idle (thumbs up, helmet under arm),
                                  2-3 walk, 4 radio to the ear (airstrike call),
                                  5 point ("there!"), 6 salute to the camera,
                                  7 hurt, 8-9 defeated
  assets/boss3/jet_80.png         top-down cartoon fighter jet (80x48), nose right
  assets/boss3/flight_deck.png    arena backdrop: a carrier island tower and
                                  hangar with a MISSION ACCOMPLISHED banner (352x184)

Beorge Kush Jr. is an invented, good-natured cartoon parody of a swaggering
ex fighter pilot: olive flight suit with harness straps and a wings name
patch, big ears, a squinty grin, gold aviator shades and a white flight
helmet tucked under his arm. No real likeness.

Run:  python3 tools/gen_boss3.py   (writes into assets/boss3/)
"""
import os
import numpy as np
from PIL import Image, ImageDraw
import gen_boss as gb
from gen_boss import Canvas, E, P, R, L, union, INK
from pixtext import draw_text, text_width

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'boss3')
os.makedirs(OUT, exist_ok=True)
FW, FH = 96, 112

gb.PAL.update({
    'kskin': ['#8e5a40', '#c88a64', '#eab48e', '#ffdcbc'],
    'khair': ['#3a3430', '#5a524a', '#7e766c', '#a29a8e'],
    'fsuit': ['#26301a', '#3e4c26', '#5c6e36', '#7e9450'],
    'strap': ['#3a2a14', '#5e4422', '#86663a', '#a88a58'],
    'boot': ['#140c08', '#2a1a10', '#46301e', '#62462e'],
    'helmet': ['#8a8e96', '#c4c8d0', '#eceef2', '#ffffff'],
    'visor': ['#1a1406', '#4a3808', '#8a6a12', '#d0a828'],
    'shade': ['#06120c', '#0e2a1c', '#1e4632', '#3a6e52'],
    'goldf': ['#6a4a0c', '#b88a1c', '#e8c040', '#fff090'],
    'radio': ['#12140e', '#262a1e', '#3e4430', '#5a6246'],
    'kmouth': ['#3a0a0c', '#5a1216', '#7a1e22', '#963030'],
    'patch': ['#a8a8a0', '#d8d8d0', '#f4f4ec', '#ffffff'],
    'jet': ['#3c4450', '#5e6a7a', '#8a96a8', '#bcc6d4'],
    'canopy': ['#0c1a2c', '#1c3a5c', '#3a6a9a', '#8ac0ec'],
    'deck': ['#3a3e44', '#545a62', '#727a84', '#959ea8'],
})


def kush(frame):
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

    # --- legs: baggy flight-suit legs, big boots
    if sit:
        c.part(P(c, [(32, Y(58)), (47, Y(58)), (46, Y(72)), (31, Y(72))]), 'fsuit')
        c.part(P(c, [(49, Y(58)), (64, Y(58)), (65, Y(72)), (50, Y(72))]), 'fsuit')
        c.part(E(c, (24, Y(68), 46, Y(82))), 'boot')
        c.part(E(c, (50, Y(68), 72, Y(82))), 'boot')
    else:
        lo = 2 * walk
        for side, (x0, x1) in ((0, (34, 47)), (1, (49, 62))):
            d = lo if side == 0 else -lo
            c.part(P(c, [(x0 - 1, Y(56)), (x1 + 1, Y(56)), (x1 + 1, Y(80) + d), (x0 - 1, Y(80) + d)]), 'fsuit')
            # leg pocket
            c.part(R(c, (x0 + 2, Y(64) + d, x0 + 9, Y(71) + d)), 'fsuit', sigma=0.8, light_bias=-0.1)
            box = (x0 - 4, Y(78) + d, x0 + 12, Y(88) + d) if side == 0 else (x0 - 1, Y(78) + d, x0 + 15, Y(88) + d)
            c.part(E(c, box), 'boot', sigma=1.4)

    # --- back arm (viewer's left): helmet under the arm in idle / salute
    swing = -walk * 2
    helmet = frame in (0, 1, 6)
    if sit:
        c.part(P(c, [(27, Y(40)), (34, Y(42)), (28, Y(58)), (21, Y(56))]), 'fsuit')
        c.part(E(c, (16, Y(54), 27, Y(64))), 'kskin', sigma=1.2)
    elif helmet:
        c.part(P(c, [(26, Y(40)), (34, Y(42)), (33, Y(56)), (25, Y(56))]), 'fsuit')
        hm = union(c, E(c, (8, Y(42), 32, Y(66))))
        c.part(hm, 'helmet', sigma=2.0, light_bias=0.05)
        c.part(E(c, (12, Y(48), 26, Y(60))), 'visor', sigma=1.0, light_bias=0.15)
        c.px(15, Y(50), '#fff8c0'); c.px(16, Y(50), '#fff8c0'); c.px(15, Y(51), '#fff8c0')
        c.part(R(c, (19, Y(42), 22, Y(66))), ['#a01c22', '#d02a30', '#f04a48', '#ff8a80'], rim=False, sigma=0.4)
        c.part(E(c, (26, Y(52), 35, Y(61))), 'kskin', sigma=1.0)
    else:
        c.part(P(c, [(26, Y(40)), (34, Y(42)), (32, Y(60) + swing), (24, Y(60) + swing)]), 'fsuit')
        c.part(E(c, (22, Y(58) + swing, 32, Y(68) + swing)), 'kskin', sigma=1.2)

    # --- torso: flight suit, chest harness, zipper, name patch with wings
    torso = union(c, P(c, [(30, Y(40)), (66, Y(40)), (64, Y(62)), (32, Y(62))]),
                  E(c, (26, Y(36), 42, Y(48))), E(c, (54, Y(36), 70, Y(48))))
    c.part(torso, 'fsuit', sigma=2.6)
    # collar
    c.part(P(c, [(38, Y(37)), (48, Y(44)), (58, Y(37)), (56, Y(35)), (48, Y(40)), (40, Y(35))]), 'fsuit', sigma=0.8, light_bias=0.15)
    # zipper
    for y in range(44, 62):
        c.px(48, Y(y), '#c8c8b0' if y % 2 else '#8a8a70')
    # harness straps (diagonals + waist belt)
    c.part(L(c, [(36, Y(40)), (44, Y(60))], 3), 'strap', rim=False, sigma=0.5)
    c.part(L(c, [(60, Y(40)), (52, Y(60))], 3), 'strap', rim=False, sigma=0.5)
    c.part(R(c, (32, Y(57), 64, Y(60))), 'strap', rim=False, sigma=0.5)
    c.part(R(c, (45, Y(56), 51, Y(61))), ['#6a6a60', '#a0a098', '#d0d0c8', '#f0f0e8'], rim=False, sigma=0.4)
    # name patch with wings (left chest = viewer's right)
    c.part(R(c, (52, Y(45), 62, Y(51))), 'patch', sigma=0.6)
    for (x, y) in [(53, 47), (54, 46), (55, 47), (56, 48), (57, 48), (58, 47), (59, 46), (60, 47)]:
        c.px(x, Y(y), '#c8961e')
    c.px(57, Y(49), '#1a1a1a'); c.px(55, Y(49), '#1a1a1a'); c.px(59, Y(49), '#1a1a1a')
    # flag-ish shoulder patch (red/white stripes + blue canton, generic)
    for i in range(4):
        for x in range(30, 37):
            c.px(x, Y(42 + i), '#c82a2a' if i % 2 == 0 else '#f4f4f0')
    for x in range(30, 33):
        c.px(x, Y(42), '#2a3a8a'); c.px(x, Y(43), '#2a3a8a')

    # --- head
    hx = tilt
    # big cartoon ears
    c.part(E(c, (21 + hx, Y(10), 31 + hx, Y(28))), 'kskin', sigma=1.0)
    c.part(E(c, (65 + hx, Y(10), 75 + hx, Y(28))), 'kskin', sigma=1.0)
    c.px(25 + hx, Y(18), '#a86a4a'); c.px(25 + hx, Y(19), '#a86a4a'); c.px(70 + hx, Y(18), '#a86a4a'); c.px(70 + hx, Y(19), '#a86a4a')
    head = union(c, E(c, (28 + hx, Y(-2), 68 + hx, Y(34))),
                 P(c, [(32 + hx, Y(20)), (64 + hx, Y(20)), (58 + hx, Y(37)), (38 + hx, Y(37))]))
    c.part(head, 'kskin', sigma=3.2)
    # short cropped greying hair
    hair = union(c, E(c, (28 + hx, Y(-5), 68 + hx, Y(14))))
    hmask = np.array(hair) > 127
    hmask[Y(8):, :] = False
    c.part(Image.fromarray((hmask * 255).astype(np.uint8), 'L'), 'khair', sigma=1.6)
    for x in range(31, 66, 3):
        c.px(x + hx, Y(-1 + (x % 2)), '#b8b0a4')
    # eyebrows (raised in the cocky look)
    if frame == 7 or sit:
        b1 = [(35 + hx, Y(9)), (45 + hx, Y(12))]
        b2 = [(51 + hx, Y(12)), (61 + hx, Y(9))]
    else:
        up = -2 if frame in (4, 6) else 0
        b1 = [(35 + hx, Y(10) + up), (40 + hx, Y(8) + up), (45 + hx, Y(10))]
        b2 = [(51 + hx, Y(10)), (56 + hx, Y(8)), (61 + hx, Y(10))]
    c.part(L(c, b1, 2), 'khair', rim=False, sigma=0.4)
    c.part(L(c, b2, 2), 'khair', rim=False, sigma=0.4)

    # aviator shades (teardrop lenses, thin gold frame) or squint eyes
    def shades(askew=False, cracked=False):
        for i, x0 in enumerate((34, 50)):
            dy = 2 if (askew and i == 1) else 0
            lens = P(c, [(x0 + hx, Y(13) + dy), (x0 + 12 + hx, Y(13) + dy), (x0 + 11 + hx, Y(19) + dy), (x0 + 6 + hx, Y(23) + dy), (x0 + 1 + hx, Y(19) + dy)])
            c.part(lens, 'shade', sigma=0.8, light_bias=0.15)
            ring = c.mask()
            ImageDraw.Draw(ring).polygon([(x0 + hx, Y(13) + dy), (x0 + 12 + hx, Y(13) + dy), (x0 + 11 + hx, Y(19) + dy), (x0 + 6 + hx, Y(23) + dy), (x0 + 1 + hx, Y(19) + dy)], outline=255)
            mk = np.array(ring) > 127
            c.rgba[mk, :3] = gb.hexc('#e8c040')
            c.rgba[mk, 3] = 255
            c.px(x0 + 3 + hx, Y(15) + dy, '#ffffff'); c.px(x0 + 4 + hx, Y(15) + dy, '#ffffff'); c.px(x0 + 3 + hx, Y(16) + dy, '#cfe8d8')
            if cracked and i == 1:
                for k in range(5):
                    c.px(x0 + 3 + k + hx, Y(15) + (k % 2) + dy, '#ffffff')
        c.part(L(c, [(46 + hx, Y(14)), (50 + hx, Y(14))], 1), 'goldf', rim=False, sigma=0.2)
        c.part(L(c, [(34 + hx, Y(14)), (28 + hx, Y(16))], 1), 'goldf', rim=False, sigma=0.2)
        c.part(L(c, [(62 + hx, Y(14)), (67 + hx, Y(16))], 1), 'goldf', rim=False, sigma=0.2)

    if frame == 7:
        shades(askew=True)
    elif sit:
        shades(askew=True, cracked=True)
    else:
        shades()
    # nose (cartoon bulb)
    c.part(E(c, (45 + hx, Y(19), 52 + hx, Y(27))), 'kskin', sigma=1.0, light_bias=0.05)
    c.px(46 + hx, Y(26), '#a86a4a'); c.px(50 + hx, Y(26), '#a86a4a')

    # --- mouth: the squinty, lopsided grin
    mx = hx
    if frame == 7:
        c.part(E(c, (44 + mx, Y(29), 52 + mx, Y(35))), 'kmouth', sigma=0.6)
    elif sit:
        c.part(L(c, [(42 + mx, Y(32)), (46 + mx, Y(30)), (50 + mx, Y(32)), (54 + mx, Y(30))], 2), 'kmouth', rim=False, sigma=0.4)
    elif frame in (4, 5):
        # shouting into the radio: open mouth
        m = c.part(E(c, (41 + mx, Y(28), 55 + mx, Y(35))), 'kmouth', sigma=0.6)
        for x in range(43 + mx, 54 + mx):
            if m[Y(29), x]:
                c.px(x, Y(29), '#f4f0e8')
    else:
        # wide smirk, up on one side, with teeth
        c.part(L(c, [(40 + mx, Y(29)), (45 + mx, Y(32)), (52 + mx, Y(32)), (57 + mx, Y(28))], 2), 'kmouth', rim=False, sigma=0.3)
        for x in range(45 + mx, 52 + mx):
            c.px(x, Y(31), '#f4f0e8')
        c.px(58 + mx, Y(27), '#c88a64')

    # --- front arm (viewer's right)
    if frame == 4:
        # radio handset at the ear, antenna up
        c.part(P(c, [(62, Y(40)), (69, Y(38)), (72, Y(22)), (66, Y(20))]), 'fsuit')
        c.part(R(c, (66, Y(10), 74, Y(26))), 'radio', sigma=0.8)
        c.part(L(c, [(72, Y(10)), (74, Y(-6))], 2), 'radio', rim=False, sigma=0.2)
        c.px(74, Y(-7), '#ff4040'); c.px(75, Y(-7), '#ff8080')
        for yy in (13, 16, 19):
            for xx in (68, 70, 72):
                c.px(xx, Y(yy), '#7a8462')
        c.part(E(c, (64, Y(18), 74, Y(28))), 'kskin', sigma=1.0)
    elif frame == 5:
        # pointing "THERE!" (arm forward, index finger out)
        c.part(P(c, [(62, Y(40)), (69, Y(39)), (84, Y(42)), (82, Y(49))]), 'fsuit')
        c.part(E(c, (79, Y(40), 89, Y(50))), 'kskin', sigma=1.2)
        c.part(R(c, (87, Y(43), 94, Y(46))), 'kskin', sigma=0.6)
    elif frame == 6:
        # crisp salute: hand at the brow
        c.part(P(c, [(62, Y(40)), (69, Y(38)), (74, Y(22)), (68, Y(19))]), 'fsuit')
        c.part(P(c, [(58 + hx, Y(6)), (74, Y(4)), (76, Y(10)), (62 + hx, Y(12))]), 'kskin', sigma=1.0)
    elif frame in (0, 1):
        # thumbs up at chest height
        c.part(P(c, [(62, Y(42)), (69, Y(40)), (76, Y(52)), (69, Y(56))]), 'fsuit')
        c.part(E(c, (67, Y(44), 79, Y(56))), 'kskin', sigma=1.2)
        c.part(R(c, (71, Y(36), 75, Y(46))), 'kskin', sigma=0.6)
    elif sit:
        c.part(P(c, [(63, Y(42)), (69, Y(40)), (75, Y(56)), (68, Y(58))]), 'fsuit')
        c.part(E(c, (69, Y(54), 79, Y(64))), 'kskin', sigma=1.2)
    elif frame == 7:
        c.part(P(c, [(62, Y(40)), (69, Y(38)), (79, Y(30)), (75, Y(25))]), 'fsuit')
        c.part(E(c, (73, Y(20), 83, Y(30))), 'kskin', sigma=1.2)
    else:
        c.part(P(c, [(63, Y(42)), (70, Y(40)), (72, Y(60) - swing), (64, Y(60) - swing)]), 'fsuit')
        c.part(E(c, (63, Y(58) - swing, 73, Y(68) - swing)), 'kskin', sigma=1.2)

    if sit:
        # dropped helmet beside him
        c.part(E(c, (70, Y(66), 90, Y(84))), 'helmet', sigma=1.8)
        c.part(E(c, (74, Y(70), 86, Y(80))), 'visor', sigma=0.8, light_bias=0.15)

    img = c.finish()
    sh = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    gy = (oy + 12 + 72) if sit else (oy + 88)
    d.ellipse((24, gy - 4, 72, gy + 5), fill=(10, 20, 30, 90))
    sh.alpha_composite(img)
    return sh


def jet():
    """Top-down cartoon fighter, nose to the right."""
    W, H = 80, 48
    c = Canvas(W, H)
    # swept main wings + tail
    c.part(P(c, [(44, 22), (20, 2), (12, 2), (26, 22)]), 'jet', sigma=1.4)
    c.part(P(c, [(44, 26), (20, 46), (12, 46), (26, 26)]), 'jet', sigma=1.4)
    c.part(P(c, [(14, 22), (2, 12), (0, 12), (6, 22)]), 'jet', sigma=1.0)
    c.part(P(c, [(14, 26), (2, 36), (0, 36), (6, 26)]), 'jet', sigma=1.0)
    # fuselage + nose
    c.part(union(c, E(c, (2, 18, 64, 30)), P(c, [(60, 18), (79, 24), (60, 30)])), 'jet', sigma=2.0, light_bias=0.05)
    # canopy
    c.part(E(c, (44, 20, 62, 28)), 'canopy', sigma=1.0, light_bias=0.2)
    c.px(56, 22, '#ffffff'); c.px(57, 22, '#ffffff')
    # wing stripes + star-free roundel (a plain circle) + tail stripe
    for x in range(18, 26):
        c.px(x, 8, '#c82a2a'); c.px(x, 40, '#c82a2a')
    c.part(E(c, (26, 9, 32, 15)), ['#1a2a6a', '#2a3a8a', '#4a5aaa', '#8a9ad0'], rim=False, sigma=0.5)
    c.part(E(c, (26, 33, 32, 39)), ['#1a2a6a', '#2a3a8a', '#4a5aaa', '#8a9ad0'], rim=False, sigma=0.5)
    # engine glow
    c.part(E(c, (0, 21, 6, 27)), ['#a03a0a', '#e86a1a', '#ffb040', '#fff0a0'], rim=False, sigma=0.6, light_bias=0.3)
    return c.finish()


def flight_deck():
    W, H = 352, 184
    c = Canvas(W, H)
    hangar = ['#3c424a', '#565e68', '#767e8a', '#9aa2ae']
    tower = ['#4a5058', '#6a727c', '#8c949e', '#b2bac4']
    # hangar block across the bottom
    c.part(R(c, (8, 104, 344, 178)), hangar, sigma=4.0)
    # the island tower (centre-right of the hangar)
    c.part(R(c, (138, 28, 214, 120)), tower, sigma=3.0)
    c.part(R(c, (128, 56, 224, 72)), tower, sigma=2.0, light_bias=0.05)    # bridge deck
    # mast + radar
    c.part(R(c, (172, 4, 178, 30)), tower, sigma=0.8)
    c.part(E(c, (156, 10, 194, 22)), ['#2a2e34', '#4a5058', '#6a727c', '#9aa2ae'], sigma=1.0)
    img = c.finish()
    d = ImageDraw.Draw(img)
    # bridge windows
    for x in range(132, 222, 8):
        d.rectangle((x, 60, x + 5, 66), fill=(40, 90, 140, 255))
        d.rectangle((x + 1, 61, x + 2, 62), fill=(170, 220, 255, 255))
    # tower windows
    for y in (36, 46):
        for x in range(146, 208, 10):
            d.rectangle((x, y, x + 5, y + 4), fill=(32, 70, 110, 255))
    # hull number on the tower
    draw_text(d, 165, 80, "18", (240, 240, 230, 255), scale=4)
    # hangar doors
    for x0 in (24, 252):
        d.rectangle((x0, 128, x0 + 76, 178), fill=(36, 40, 46, 255))
        for x in range(x0 + 2, x0 + 76, 6):
            d.line((x, 130, x, 178), fill=(60, 66, 74, 255))
    # the banner: red/white/blue edges, white field, MISSION ACCOMPLISHED
    msg = "MISSION ACCOMPLISHED"
    sc = 2
    tw = text_width(msg, sc)
    bx0 = (W - tw) // 2 - 10
    bx1 = bx0 + tw + 20
    d.rectangle((bx0 - 2, 106, bx1 + 2, 128), fill=(24, 12, 20, 255))
    d.rectangle((bx0, 108, bx1, 126), fill=(246, 244, 236, 255))
    for x in range(bx0, bx1, 8):
        d.rectangle((x, 108, x + 3, 110), fill=(200, 40, 44, 255))
        d.rectangle((x + 4, 108, x + 7, 110), fill=(40, 60, 150, 255))
        d.rectangle((x, 124, x + 3, 126), fill=(40, 60, 150, 255))
        d.rectangle((x + 4, 124, x + 7, 126), fill=(200, 40, 44, 255))
    draw_text(d, bx0 + 10, 112, msg, (30, 44, 120, 255), scale=sc)
    # banner ties
    d.line((bx0 - 2, 106, bx0 - 8, 98), fill=(24, 12, 20, 255), width=2)
    d.line((bx1 + 2, 106, bx1 + 8, 98), fill=(24, 12, 20, 255), width=2)
    # deck-edge warning stripes along the base
    for x in range(8, 344, 12):
        d.polygon([(x, 178), (x + 6, 178), (x + 12, 172), (x + 6, 172)], fill=(240, 200, 40, 255))
    # blinking mast light
    d.rectangle((173, 0, 177, 4), fill=(255, 60, 60, 255))
    return img


def main():
    sheet = Image.new('RGBA', (FW * 10, FH), (0, 0, 0, 0))
    for f in range(10):
        sheet.alpha_composite(kush(f), (f * FW, 0))
    sheet.save(os.path.join(OUT, 'kush_96.png'))
    jet().save(os.path.join(OUT, 'jet_80.png'))
    flight_deck().save(os.path.join(OUT, 'flight_deck.png'))
    print('wrote', OUT)


if __name__ == '__main__':
    main()
