"""Build 025 art generator: boss 7 (REANALD ROGAN) and boss 8 (ZELODYMER
VIOLENTSKY), plus their arena backdrops (Python + Pillow + numpy).

Drawn from code only (no photos, no tracing, no third-party assets):
  assets/boss7/rogan_96.png        Reanald Rogan sheet, 10 frames of 96x112
  assets/boss7/space_hq.png        arena backdrop: a retro SPACE DEFENSE HQ with a
                                   radar screen and an orbit map (352x184)
  assets/boss8/violentsky_96.png   Zelodymer Violentsky sheet, 10 frames of 96x112
  assets/boss8/broadcast_tent.png  arena backdrop: a sunny field tent rigged as a
                                   LIVE broadcast studio, sunflowers (352x184)
Frames (same as bosses 4-6): 0-1 idle, 2-3 walk, 4 big wind-up prop raised,
5 cast (hand up), 6 palm up to the camera, 7 hurt, 8-9 defeated.

Both are good-natured cartoon parodies built from generic features only:
Rogan = a twinkly old actor-turned-president type (dark pompadour with grey
temples, rosy cheeks, a big grin, navy suit, red tie, a toy satellite remote,
a jar of jelly beans at rest). Violentsky = a comedian-turned-commander type
(short dark hair, stubble, an olive tee and cargo trousers, a drone tablet
raised, a microphone at rest). No real likeness, no war imagery.

Run:  python3 tools/gen_boss7.py
"""
import os
from PIL import Image, ImageDraw
import gen_boss as gb
from gen_boss import Canvas, E, P, R, L, union, INK
from pixtext import draw_text, text_width
from gen_boss5 import _legs, _eyes, _mouth, _finish, _arms, _front_arm, FW, FH

HERE = os.path.dirname(os.path.abspath(__file__))
OUT7 = os.path.join(HERE, '..', 'assets', 'boss7')
OUT8 = os.path.join(HERE, '..', 'assets', 'boss8')
os.makedirs(OUT7, exist_ok=True)
os.makedirs(OUT8, exist_ok=True)

gb.PAL.update({
    'rskin': ['#8a5446', '#c48474', '#eab4a0', '#fdd8c8'],
    'rhair': ['#24140c', '#3e2414', '#5c3820', '#7a5030'],
    'grey': ['#7a7a80', '#a4a4aa', '#cacad0', '#ececf0'],
    'navy': ['#10183a', '#1e2c5e', '#304484', '#4c64aa'],
    'rtie': ['#5a0a10', '#900e1a', '#c42030', '#e84a54'],
    'shirt': ['#a8a8b0', '#d8d8de', '#f2f2f6', '#ffffff'],
    'rshoe': ['#140c08', '#24160e', '#382416', '#4c3420'],
    'sat': ['#6a6a74', '#9a9aa6', '#c8c8d4', '#f0f0f8'],
    'panel': ['#0a1a4a', '#14307a', '#2a50b0', '#4a7ae0'],
    'jar': ['#7a8a96', '#aabac6', '#d4e2ec', '#f4fcff'],
    'vskin': ['#7e5240', '#b88068', '#dcaa8e', '#f4ccb2'],
    'vhair': ['#1a120c', '#2c2016', '#40301e', '#58422a'],
    'olive': ['#2a3216', '#424e22', '#5e6c32', '#7e8e48'],
    'cargo': ['#2e2a1a', '#4a4428', '#686038', '#88804c'],
    'boot': ['#140e08', '#22180e', '#342416', '#4a3420'],
    'tablet': ['#0c0c12', '#1c1c26', '#2e2e3c', '#444456'],
    'mic': ['#202024', '#3a3a40', '#5a5a62', '#8a8a94'],
})


# ---------------------------------------------------------------- Reanald Rogan

def _sat_up(c, Y):
    # a toy satellite on a stick: body + two blue solar panels + a dish
    c.part(L(c, [(78, Y(10)), (78, Y(-2))], 2), 'sat', rim=False, sigma=0.3)
    c.part(R(c, (72, Y(-12), 84, Y(-2))), 'sat', sigma=0.6)
    c.part(R(c, (58, Y(-10), 71, Y(-4))), 'panel', sigma=0.4)
    c.part(R(c, (85, Y(-10), 98 - 4, Y(-4))), 'panel', sigma=0.4)
    c.part(E(c, (74, Y(-20), 84, Y(-12))), 'sat', sigma=0.4, light_bias=0.2)
    c.px(79, Y(-22), '#ff4040')


def _jar_rest(c, Y):
    c.part(R(c, (66, Y(52), 80, Y(68))), 'jar', sigma=0.6, light_bias=0.1)
    c.part(R(c, (65, Y(49), 81, Y(53))), 'rtie', rim=False, sigma=0.3)
    beans = ['#e04040', '#40c040', '#f0d040', '#9040e0', '#f08020', '#40a0f0']
    k = 0
    for y in range(55, 67, 3):
        for x in range(68, 79, 3):
            c.px(x, Y(y), beans[k % len(beans)]); c.px(x + 1, Y(y), beans[k % len(beans)])
            k += 1


def rogan(frame):
    c = Canvas(FW, FH)
    oy = 18
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame == 1 else 0
    hy = oy + bob + (14 if sit else 0) + (2 if frame == 7 else 0)
    hx = 3 if frame == 7 else 0

    def Y(v):
        return v + hy

    _legs(c, Y, sit, walk, 'navy', 'rshoe')
    _arms(c, Y, frame, sit, walk, 'navy', 'rskin', None)
    torso = union(c, P(c, [(31, Y(40)), (65, Y(40)), (64, Y(66)), (32, Y(66))]),
                  E(c, (28, Y(37), 44, Y(49))), E(c, (52, Y(37), 68, Y(49))))
    c.part(torso, 'navy', sigma=2.6)
    c.part(P(c, [(41, Y(38)), (55, Y(38)), (48, Y(52))]), 'shirt', sigma=0.6)
    c.part(P(c, [(46, Y(40)), (50, Y(40)), (51, Y(56)), (48, Y(59)), (45, Y(56))]), 'rtie', sigma=0.5)
    # lapels + a tiny flag-free lapel pin
    c.part(L(c, [(41, Y(39)), (46, Y(54))], 2), ['#080c20', '#10183a', '#1e2c5e', '#304484'], rim=False, sigma=0.3)
    c.part(L(c, [(55, Y(39)), (50, Y(54))], 2), ['#080c20', '#10183a', '#1e2c5e', '#304484'], rim=False, sigma=0.3)
    c.px(57, Y(44), '#f0d060')
    # head: broad cheerful face, rosy cheeks
    c.part(E(c, (31 + hx, Y(-2), 65 + hx, Y(35))), 'rskin', sigma=3.0, light_bias=0.16)
    c.part(E(c, (34 + hx, Y(20), 41 + hx, Y(26))), ['#c86a6a', '#e08484', '#f0a0a0', '#f8c0c0'], rim=False, sigma=0.8)
    c.part(E(c, (55 + hx, Y(20), 62 + hx, Y(26))), ['#c86a6a', '#e08484', '#f0a0a0', '#f8c0c0'], rim=False, sigma=0.8)
    # big glossy pompadour with grey temples
    pomp = union(c, E(c, (29 + hx, Y(-14), 67 + hx, Y(8))), E(c, (34 + hx, Y(-18), 58 + hx, Y(-4))))
    c.part(pomp, 'rhair', sigma=1.6, light_bias=0.2)
    c.part(E(c, (28 + hx, Y(4), 35 + hx, Y(18))), 'grey', sigma=0.8)
    c.part(E(c, (61 + hx, Y(4), 68 + hx, Y(18))), 'grey', sigma=0.8)
    for k in range(4):
        c.px(40 + k * 5 + hx, Y(-12), '#9a7048')
    # ears
    c.part(E(c, (27 + hx, Y(12), 33 + hx, Y(22))), 'rskin', sigma=0.8)
    c.part(E(c, (63 + hx, Y(12), 69 + hx, Y(22))), 'rskin', sigma=0.8)
    _eyes(c, Y, hx, frame, sit, y=14)
    c.part(L(c, [(35 + hx, Y(10)), (44 + hx, Y(9))], 1), 'rhair', rim=False, sigma=0.2)
    c.part(L(c, [(52 + hx, Y(9)), (61 + hx, Y(10))], 1), 'rhair', rim=False, sigma=0.2)
    c.part(P(c, [(46 + hx, Y(15)), (50 + hx, Y(15)), (52 + hx, Y(22)), (45 + hx, Y(22))]), 'rskin', sigma=0.8, light_bias=0.06)
    _mouth(c, Y, hx, frame, sit)
    _front_arm(c, Y, frame, sit, walk, 'navy', 'rskin', _sat_up, _jar_rest)
    return _finish(c, oy, sit)


def space_hq():
    W, H = 352, 184
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # wall + console desk
    d.rectangle((6, 18, 346, 178), fill=(36, 42, 62, 255), outline=(14, 16, 26, 255), width=3)
    for x in range(14, 340, 22):
        d.line((x, 22, x, 120), fill=(44, 52, 76, 255))
    # big orbit-map screen
    d.rectangle((96, 26, 256, 112), fill=(8, 14, 30, 255), outline=(120, 200, 255, 255), width=3)
    import random
    rnd = random.Random(7)
    for _ in range(60):
        d.point((rnd.randint(100, 252), rnd.randint(30, 108)), fill=(200, 220, 255, 255))
    d.ellipse((150, 50, 202, 102), fill=(40, 90, 170, 255), outline=(120, 200, 255, 255))
    d.ellipse((160, 60, 180, 76), fill=(70, 150, 90, 255))
    d.arc((118, 36, 234, 112), 200, 340, fill=(255, 220, 90, 255), width=2)
    d.arc((126, 44, 226, 108), 20, 160, fill=(255, 220, 90, 255), width=2)
    for (x, y) in ((126, 58), (220, 54), (176, 40), (138, 98)):
        d.rectangle((x - 3, y - 2, x + 3, y + 2), fill=(230, 230, 240, 255))
        d.line((x - 8, y, x + 8, y), fill=(80, 140, 255, 255), width=2)
    # side radar scopes
    for cx in (48, 304):
        d.ellipse((cx - 30, 40, cx + 30, 100), fill=(6, 30, 14, 255), outline=(90, 255, 120, 255), width=2)
        d.line((cx, 70, cx + 22, 52), fill=(140, 255, 160, 255), width=2)
        for r in (10, 20):
            d.ellipse((cx - r, 70 - r, cx + r, 70 + r), outline=(40, 140, 60, 255))
    # console with blinkenlights
    d.rectangle((10, 122, 342, 176), fill=(70, 76, 96, 255), outline=(20, 22, 34, 255), width=2)
    for k in range(40):
        x = 18 + (k % 20) * 16
        y = 132 + (k // 20) * 14
        d.rectangle((x, y, x + 8, y + 5), fill=[(255, 80, 80, 255), (80, 255, 120, 255), (255, 220, 80, 255), (120, 180, 255, 255)][(k * 7) % 4])
    msg = "SPACE DEFENSE"
    sc = 2
    tw = text_width(msg, sc)
    bx0 = (W - tw) // 2 - 16
    bx1 = bx0 + tw + 40
    d.rectangle((bx0 - 2, 2, bx1 + 2, 20), fill=(14, 16, 26, 255))
    d.rectangle((bx0, 4, bx1, 18), fill=(30, 60, 150, 255))
    draw_text(d, bx0 + 8, 6, msg, (255, 255, 255, 255), scale=sc)
    return img


# ---------------------------------------------------------------- Zelodymer Violentsky

def _tablet_up(c, Y):
    c.part(R(c, (66, Y(-14), 90, Y(4))), 'tablet', sigma=0.6)
    c.part(R(c, (69, Y(-11), 87, Y(1))), ['#1a6040', '#2a9060', '#40c080', '#80f0b0'], rim=False, sigma=0.3)
    c.part(L(c, [(88, Y(-14)), (92, Y(-24))], 1), 'mic', rim=False, sigma=0.2)
    c.px(92, Y(-25), '#ff5050')
    # a little drone icon on the screen
    c.px(77, Y(-6), '#ffffff'); c.px(78, Y(-6), '#ffffff')
    c.px(75, Y(-7), '#ffffff'); c.px(80, Y(-7), '#ffffff')


def _mic_rest(c, Y):
    c.part(L(c, [(72, Y(58)), (74, Y(70))], 2), 'mic', rim=False, sigma=0.3)
    c.part(E(c, (68, Y(50), 78, Y(60))), 'mic', sigma=0.6, light_bias=0.2)


def violentsky(frame):
    c = Canvas(FW, FH)
    oy = 18
    sit = frame in (8, 9)
    walk = {2: 1, 3: -1}.get(frame, 0)
    bob = 1 if frame == 1 else 0
    hy = oy + bob + (14 if sit else 0) + (2 if frame == 7 else 0)
    hx = 3 if frame == 7 else 0

    def Y(v):
        return v + hy

    _legs(c, Y, sit, walk, 'cargo', 'boot')
    _arms(c, Y, frame, sit, walk, 'olive', 'vskin', None)
    torso = union(c, P(c, [(32, Y(40)), (64, Y(40)), (63, Y(66)), (33, Y(66))]),
                  E(c, (29, Y(37), 43, Y(48))), E(c, (53, Y(37), 67, Y(48))))
    c.part(torso, 'olive', sigma=2.6)
    # crew-neck collar and a chest pocket (plain, no insignia)
    c.part(E(c, (41, Y(36), 55, Y(43))), 'vskin', sigma=0.6)
    c.part(R(c, (52, Y(46), 60, Y(53))), ['#222a10', '#36401c', '#4a5628', '#606e36'], rim=False, sigma=0.3)
    # head: compact face, short hair, stubble
    c.part(E(c, (33 + hx, Y(-2), 63 + hx, Y(34))), 'vskin', sigma=3.0, light_bias=0.16)
    hair = union(c, E(c, (32 + hx, Y(-8), 64 + hx, Y(10))))
    c.part(hair, 'vhair', sigma=1.2)
    c.part(E(c, (36 + hx, Y(18), 60 + hx, Y(36))), ['#4a3a30', '#5e4a3c', '#725a4a', '#86705e'], rim=False, sigma=1.2)
    c.part(E(c, (40 + hx, Y(14), 56 + hx, Y(28))), 'vskin', rim=False, sigma=1.0)
    c.part(E(c, (29 + hx, Y(10), 35 + hx, Y(20))), 'vskin', sigma=0.8)
    c.part(E(c, (61 + hx, Y(10), 67 + hx, Y(20))), 'vskin', sigma=0.8)
    _eyes(c, Y, hx, frame, sit, y=13)
    c.part(L(c, [(35 + hx, Y(8)), (44 + hx, Y(8))], 2), 'vhair', rim=False, sigma=0.2)
    c.part(L(c, [(52 + hx, Y(8)), (61 + hx, Y(8))], 2), 'vhair', rim=False, sigma=0.2)
    c.part(P(c, [(46 + hx, Y(14)), (50 + hx, Y(14)), (51 + hx, Y(21)), (45 + hx, Y(21))]), 'vskin', sigma=0.8, light_bias=0.06)
    _mouth(c, Y, hx, frame, sit)
    _front_arm(c, Y, frame, sit, walk, 'olive', 'vskin', _tablet_up, _mic_rest)
    return _finish(c, oy, sit)


def broadcast_tent():
    W, H = 352, 184
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # a sunny sky band and a wheat-gold field behind the tent
    d.rectangle((0, 40, W, 120), fill=(120, 180, 240, 255))
    d.rectangle((0, 120, W, 184), fill=(220, 186, 80, 255))
    for x in range(0, W, 6):
        d.line((x, 120, x + 2, 112), fill=(236, 206, 104, 255))
    # sunflowers along the front
    for k, x in enumerate(range(14, W, 30)):
        y = 132 + (k % 2) * 8
        d.line((x, y, x, y + 40), fill=(60, 120, 40, 255), width=3)
        d.ellipse((x - 9, y - 9, x + 9, y + 9), fill=(250, 200, 30, 255), outline=(150, 100, 10, 255))
        d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(90, 50, 20, 255))
    # canvas tent
    d.polygon([(70, 120), (176, 30), (282, 120)], fill=(196, 186, 150, 255), outline=(90, 80, 60, 255))
    d.polygon([(150, 120), (176, 60), (202, 120)], fill=(70, 60, 44, 255))
    d.line((176, 30, 176, 22), fill=(90, 80, 60, 255), width=2)
    # broadcast kit: camera on a tripod, a ring light, a workbench with a drone
    d.line((110, 120, 100, 150), fill=(30, 30, 30, 255), width=2)
    d.line((110, 120, 120, 150), fill=(30, 30, 30, 255), width=2)
    d.rectangle((98, 106, 124, 122), fill=(40, 40, 46, 255), outline=(10, 10, 14, 255))
    d.ellipse((92, 108, 104, 120), fill=(80, 140, 220, 255), outline=(10, 10, 14, 255))
    d.ellipse((232, 86, 262, 116), outline=(255, 250, 220, 255), width=4)
    d.line((247, 116, 247, 150), fill=(30, 30, 30, 255), width=2)
    d.rectangle((206, 132, 262, 140), fill=(110, 80, 50, 255))
    d.rectangle((226, 124, 242, 130), fill=(60, 64, 72, 255))
    for dx in (-10, 10):
        d.line((234, 127, 234 + dx, 122), fill=(60, 64, 72, 255), width=2)
        d.ellipse((234 + dx - 4, 120, 234 + dx + 4, 124), outline=(200, 200, 210, 255))
    msg = "LIVE"
    sc = 3
    tw = text_width(msg, sc)
    bx0 = (W - tw) // 2 - 10
    bx1 = bx0 + tw + 20
    d.rectangle((bx0 - 2, 4, bx1 + 2, 30), fill=(20, 10, 10, 255))
    d.rectangle((bx0, 6, bx1, 28), fill=(210, 30, 40, 255))
    draw_text(d, bx0 + 10, 9, msg, (255, 255, 255, 255), scale=sc)
    return img


def main():
    for fn, out, name in ((rogan, OUT7, 'rogan_96.png'), (violentsky, OUT8, 'violentsky_96.png')):
        sheet = Image.new('RGBA', (FW * 10, FH), (0, 0, 0, 0))
        for f in range(10):
            sheet.alpha_composite(fn(f), (f * FW, 0))
        sheet.save(os.path.join(out, name))
    space_hq().save(os.path.join(OUT7, 'space_hq.png'))
    broadcast_tent().save(os.path.join(OUT8, 'broadcast_tent.png'))
    print('wrote', OUT7, OUT8)


if __name__ == '__main__':
    main()
