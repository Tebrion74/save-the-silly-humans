"""Build 030 art generator: the CAMEO sub-bosses (tech-mogul parodies).

Drawn from code only (no photos, no tracing, no third-party assets), using
the shared boss painter (gen_boss / gen_boss5). Good-natured cartoon types
from generic features only; no logos, no real likeness, nothing hateful or
sexual.
  assets/cameo/tusk_96.png       EELON TUSK      black tee with a tiny rocket, jeans, toy rocket
  assets/cameo/bozos_96.png      JEFF BOZOS      shiny bald head, blue vest, cardboard parcel
  assets/cameo/altmann_96.png    SAM ALTMANN     tousled hair, grey hoodie, glowing chat tablet
  assets/cameo/zuckerbot_96.png  MARK ZUCKERBOT  silver android skin, cropped hair, grey tee, VR goggles
Each sheet: 4 frames of 96x112 -> 0-1 idle, 2 act (arm up with the prop), 3 hurt.

Run:  python3 tools/gen_cameos.py
"""
import os
from PIL import Image
import gen_boss as gb
from gen_boss import Canvas, E, P, R, L, union, INK
from gen_boss5 import _legs, _eyes, _mouth, _finish, _arms, _front_arm, FW, FH

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'cameo')
os.makedirs(OUT, exist_ok=True)

gb.PAL.update({
    'tskin': ['#8e5e48', '#c89078', '#ecbca2', '#fde0cc'],
    'thair': ['#120e0c', '#241c18', '#3a2e26', '#54443a'],
    'tee': ['#08080c', '#16161e', '#262632', '#3c3c4c'],
    'jeans': ['#14203a', '#22345a', '#34507e', '#4e6ea0'],
    'rocket': ['#8a8e98', '#c4c8d0', '#e8ecf2', '#ffffff'],
    'flame': ['#a83a08', '#e06a12', '#ffaa2a', '#ffe27a'],
    'bskin': ['#8a5a44', '#c48a70', '#eab69a', '#ffdcc4'],
    'vest': ['#0e2a4a', '#1a4472', '#2c64a0', '#4a8ad0'],
    'shirt': ['#9aa0a8', '#ccd2da', '#eef2f6', '#ffffff'],
    'box': ['#6a4418', '#9a6a2c', '#c8944a', '#e8bc74'],
    'tape': ['#8a7a5a', '#b8a67e', '#dccaa0', '#f4e6c4'],
    'slacks': ['#2a2620', '#46403a', '#625a50', '#80766a'],
    'ahair': ['#3a2414', '#5a3a20', '#7e5630', '#a27648'],
    'hoodie': ['#3a3e46', '#5a606a', '#80868e', '#a8aeb6'],
    'tablet': ['#0a1a22', '#123040', '#1e5a6e', '#3a9ab0'],
    'glow': ['#3ab8a0', '#6ae0c4', '#a8f6e2', '#e4fff6'],
    'zskin': ['#6a7480', '#98a2ae', '#c4ccd6', '#eef2f8'],
    'zhair': ['#2a1e16', '#3e2e22', '#564232', '#6e5844'],
    'ztee': ['#4a4e56', '#6a6e78', '#8c9098', '#b0b4bc'],
    'visor': ['#0a1030', '#1a2a6a', '#3a5ac0', '#7aa0ff'],
    'shoe': ['#14100c', '#261e18', '#3a2e24', '#504034'],
    'sneak': ['#9a9aa0', '#cacad0', '#ececf0', '#ffffff'],
})

FRAME_MAP = {0: 0, 1: 1, 2: 4, 3: 7}   # our frame -> gen_boss5 pose


def _body(frame, skin, hair_fn, torso_pal, pant, shoe, prop_up, prop_rest, extra=None, glasses=False):
    f = FRAME_MAP[frame]
    c = Canvas(FW, FH)
    oy = 16
    bob = 1 if f == 1 else 0
    hy = oy + bob + (2 if f == 7 else 0)
    hx = 3 if f == 7 else 0

    def Y(v):
        return v + hy

    _legs(c, Y, False, 0, pant, shoe)
    _arms(c, Y, f, False, 0, torso_pal, skin, None)
    torso = union(c, P(c, [(31, Y(40)), (65, Y(40)), (64, Y(66)), (32, Y(66))]),
                  E(c, (28, Y(37), 42, Y(48))), E(c, (54, Y(37), 68, Y(48))))
    c.part(torso, torso_pal, sigma=2.6)
    if extra:
        extra(c, Y)
    c.part(E(c, (27 + hx, Y(12), 34 + hx, Y(26))), skin, sigma=1.0)
    c.part(E(c, (62 + hx, Y(12), 69 + hx, Y(26))), skin, sigma=1.0)
    c.part(union(c, E(c, (30 + hx, Y(-6), 66 + hx, Y(34)))), skin, sigma=3.2, light_bias=0.12)
    hair_fn(c, Y, hx)
    _eyes(c, Y, hx, f, False, y=18, big_glasses=glasses)
    c.part(P(c, [(47 + hx, Y(20)), (50 + hx, Y(20)), (51 + hx, Y(26)), (46 + hx, Y(26))]), skin, sigma=0.8, light_bias=0.06)
    _mouth(c, Y, hx, f, False)
    _front_arm(c, Y, f, False, 0, torso_pal, skin, prop_up, prop_rest)
    return _finish(c, oy, False)


# ---------------------------------------------------------------- Eelon Tusk
def _tusk_hair(c, Y, hx):
    c.part(union(c, E(c, (29 + hx, Y(-9), 67 + hx, Y(5))), E(c, (28 + hx, Y(-2), 34 + hx, Y(12))),
                 E(c, (62 + hx, Y(-2), 68 + hx, Y(12)))), 'thair', sigma=1.4)


def _rocket(c, Y, x, y):
    c.part(E(c, (x, y, x + 10, y + 22)), 'rocket', sigma=1.0, light_bias=0.15)
    c.part(P(c, [(x + 5, y - 6), (x + 10, y + 3), (x, y + 3)]), 'rocket', sigma=0.6)
    c.part(P(c, [(x - 3, y + 16), (x + 2, y + 14), (x + 2, y + 22)]), 'rocket', sigma=0.5)
    c.part(P(c, [(x + 13, y + 16), (x + 8, y + 14), (x + 8, y + 22)]), 'rocket', sigma=0.5)
    c.part(P(c, [(x + 2, y + 22), (x + 8, y + 22), (x + 5, y + 32)]), 'flame', rim=False, sigma=0.6, light_bias=0.3)


def _tusk_tee(c, Y):   # a tiny rocket print
    for k in range(5):
        c.px(48, Y(46 + k), '#d8dce4')
    c.px(47, Y(49), '#d8dce4'); c.px(49, Y(49), '#d8dce4'); c.px(48, Y(51), '#ff9a2a')


def tusk(frame):
    return _body(frame, 'tskin', _tusk_hair, 'tee', 'jeans', 'shoe',
                 lambda c, Y: _rocket(c, Y, 72, Y(-20)), lambda c, Y: _rocket(c, Y, 70, Y(52)), _tusk_tee)


# ---------------------------------------------------------------- Jeff Bozos
def _bozos_hair(c, Y, hx):
    # bald and shiny: a highlight and a thin fringe at the sides
    c.part(E(c, (38 + hx, Y(-4), 50 + hx, Y(2))), ['#ffe6d4', '#fff0e4', '#fff8f0', '#ffffff'], rim=False, sigma=0.8)
    c.part(E(c, (28 + hx, Y(8), 33 + hx, Y(16))), 'slacks', sigma=0.6)
    c.part(E(c, (63 + hx, Y(8), 68 + hx, Y(16))), 'slacks', sigma=0.6)


def _parcel(c, Y, x, y):
    c.part(R(c, (x, y, x + 22, y + 16)), 'box', sigma=0.8)
    c.part(R(c, (x + 9, y, x + 13, y + 16)), 'tape', rim=False, sigma=0.3)


def _vest(c, Y):
    c.part(P(c, [(40, Y(38)), (56, Y(38)), (48, Y(54))]), 'shirt', sigma=0.6)
    c.part(P(c, [(31, Y(40)), (42, Y(40)), (46, Y(66)), (32, Y(66))]), 'vest', sigma=1.6)
    c.part(P(c, [(54, Y(40)), (65, Y(40)), (64, Y(66)), (50, Y(66))]), 'vest', sigma=1.6)


def bozos(frame):
    return _body(frame, 'bskin', _bozos_hair, 'shirt', 'slacks', 'shoe',
                 lambda c, Y: _parcel(c, Y, 66, Y(-14)), lambda c, Y: _parcel(c, Y, 62, Y(54)), _vest)


# ---------------------------------------------------------------- Sam Altmann
def _altmann_hair(c, Y, hx):
    blobs = [E(c, (29 + hx, Y(-8), 67 + hx, Y(6)))]
    for k in range(6):
        blobs.append(E(c, (28 + k * 6 + hx, Y(-11 + (k % 2) * 2), 36 + k * 6 + hx, Y(-3 + (k % 2) * 2))))
    c.part(union(c, *blobs), 'ahair', sigma=1.4)


def _tablet(c, Y, x, y):
    c.part(R(c, (x, y, x + 18, y + 22)), 'tablet', sigma=0.6)
    c.part(R(c, (x + 2, y + 2, x + 16, y + 18)), 'glow', rim=False, sigma=0.4, light_bias=0.3)
    for k in range(3):
        c.px(x + 5 + k * 3, y + 10, '#0a3a40')


def _hood(c, Y):
    c.part(E(c, (34, Y(34), 62, Y(44))), 'hoodie', sigma=1.2)
    c.px(44, Y(46), '#d0d4da'); c.px(44, Y(48), '#d0d4da'); c.px(52, Y(46), '#d0d4da'); c.px(52, Y(48), '#d0d4da')
    c.part(R(c, (38, Y(56), 58, Y(63))), 'hoodie', sigma=0.6, light_bias=-0.1)


def altmann(frame):
    return _body(frame, 'tskin', _altmann_hair, 'hoodie', 'jeans', 'sneak',
                 lambda c, Y: _tablet(c, Y, 70, Y(-16)), lambda c, Y: _tablet(c, Y, 66, Y(50)), _hood)


# ---------------------------------------------------------------- Mark Zuckerbot
def _zuck_hair(c, Y, hx):
    c.part(union(c, E(c, (30 + hx, Y(-8), 66 + hx, Y(2))), R(c, (31 + hx, Y(-2), 65 + hx, Y(3)))), 'zhair', sigma=1.0)
    for k in range(9):
        c.px(33 + k * 4 + hx, Y(3), '#2a1e16')
    # android seams + antenna bolt
    c.px(29 + hx, Y(20), '#4a5260'); c.px(67 + hx, Y(20), '#4a5260')
    c.part(R(c, (46 + hx, Y(-14), 50 + hx, Y(-8))), 'rocket', sigma=0.4)
    c.part(E(c, (45 + hx, Y(-18), 51 + hx, Y(-12))), 'visor', rim=False, sigma=0.4, light_bias=0.3)


def _goggles(c, Y, x, y):
    c.part(R(c, (x, y, x + 24, y + 12)), 'ztee', sigma=0.6)
    c.part(R(c, (x + 2, y + 2, x + 22, y + 10)), 'visor', rim=False, sigma=0.4, light_bias=0.3)


def zuckerbot(frame):
    return _body(frame, 'zskin', _zuck_hair, 'ztee', 'jeans', 'sneak',
                 lambda c, Y: _goggles(c, Y, 66, Y(-10)), lambda c, Y: _goggles(c, Y, 60, Y(56)))


def main():
    for fn, name in ((tusk, 'tusk'), (bozos, 'bozos'), (altmann, 'altmann'), (zuckerbot, 'zuckerbot')):
        sheet = Image.new('RGBA', (FW * 4, FH), (0, 0, 0, 0))
        for f in range(4):
            sheet.alpha_composite(fn(f), (f * FW, 0))
        sheet.save(os.path.join(OUT, '%s_96.png' % name))
    print('wrote', OUT)


if __name__ == '__main__':
    main()
