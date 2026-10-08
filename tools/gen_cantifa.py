"""Build 017 art: CANTIFA, a cartoon black-bloc mob (Python + Pillow).

Drawn from code only. No photos, no real likeness, no slogans.
Generic and comedic: black hoodie, two round white eye-holes, a red
bandana, a tiny two-colour flag, and a blocky grey rifle.
Not a Karen (no blue hair, no pink shirt) and not possessed (no purple).

  assets/characters/cantifa_32.png   8 frames of 64x64:
      0 idle down (flag)   1 shoot down
      2 idle side          3 shoot side
      4 idle up            5 shoot up
      6 hurt               7 flee (rifle lowered)

Run: python3 tools/gen_cantifa.py
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "characters", "cantifa_32.png")

INK = (14, 12, 18, 255)
HOOD = (28, 28, 36, 255)
HOOD2 = (48, 48, 60, 255)
BAND = (186, 36, 44, 255)
BAND2 = (130, 20, 30, 255)
EYE = (250, 250, 255, 255)
PUPIL = (18, 16, 22, 255)
FLAG_R = (210, 48, 52, 255)
FLAG_K = (18, 16, 22, 255)
POLE = (120, 86, 48, 255)
GUN = (78, 82, 92, 255)
GUN2 = (150, 156, 166, 255)
SKIN = (210, 164, 122, 255)
FLASH = (255, 226, 90, 255)
SHOE = (10, 10, 14, 255)


def rect(d, x, y, w, h, c):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def figure(face, shoot, hurt, flee):
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # ground shadow
    d.ellipse([16, 50, 48, 58], fill=(0, 0, 0, 80))
    # shoes
    rect(d, 22, 48, 8, 5, SHOE)
    rect(d, 34, 48, 8, 5, SHOE)
    if flee:
        rect(d, 16, 48, 8, 5, SHOE)
        rect(d, 38, 46, 8, 5, SHOE)
    # torso
    rect(d, 18, 28, 28, 20, HOOD)
    rect(d, 22, 32, 20, 12, HOOD2)
    # hood (big, so the mask reads)
    rect(d, 16, 10, 32, 22, HOOD)
    rect(d, 20, 14, 24, 14, HOOD2)
    # bandana across the lower face
    rect(d, 16, 28, 32, 8, BAND)
    rect(d, 20, 32, 24, 3, BAND2)
    # two eye holes (never a single visor bar)
    if face != "up":
        for ex in (22, 34):
            rect(d, ex, 18, 8, 8, EYE)
            rect(d, ex + 3, 21, 3, 3, PUPIL)
    else:
        # hood from behind: no face, a seam
        rect(d, 30, 16, 4, 12, INK)
    if hurt:
        rect(d, 22, 18, 8, 8, FLASH)
        rect(d, 34, 18, 8, 8, (255, 80, 70, 255))
        rect(d, 26, 36, 12, 4, (220, 50, 50, 255))
    # hands + rifle + flag
    if hurt or flee:
        rect(d, 8, 40, 14, 4, GUN)
        rect(d, 18, 38, 5, 5, SKIN)
    elif shoot and face == "side":
        rect(d, 44, 34, 16, 4, GUN)
        rect(d, 56, 32, 4, 4, GUN2)
        rect(d, 60, 32, 4, 6, FLASH)
        rect(d, 40, 34, 6, 6, SKIN)
    elif shoot and face == "up":
        rect(d, 30, 2, 4, 12, GUN)
        rect(d, 28, 0, 8, 4, FLASH)
        rect(d, 26, 12, 6, 5, SKIN)
    elif shoot and face == "down":
        rect(d, 30, 50, 4, 12, GUN)
        rect(d, 26, 58, 12, 4, FLASH)
        rect(d, 26, 44, 6, 5, SKIN)
    elif face == "side":
        rect(d, 46, 38, 12, 4, GUN)
        rect(d, 40, 36, 6, 6, SKIN)
        # flag behind
        rect(d, 10, 16, 3, 22, POLE)
        rect(d, 2, 8, 8, 6, FLAG_K)
        rect(d, 2, 14, 8, 6, FLAG_R)
    elif face == "up":
        rect(d, 14, 36, 10, 4, GUN)
        rect(d, 46, 20, 3, 18, POLE)
        rect(d, 49, 12, 10, 6, FLAG_R)
        rect(d, 49, 18, 10, 6, FLAG_K)
    else:
        rect(d, 42, 40, 10, 4, GUN)
        rect(d, 36, 38, 6, 6, SKIN)
        rect(d, 48, 14, 3, 24, POLE)
        rect(d, 51, 8, 10, 7, FLAG_K)
        rect(d, 51, 15, 10, 7, FLAG_R)
    return im


def main():
    specs = [
        ("down", False, False, False),
        ("down", True, False, False),
        ("side", False, False, False),
        ("side", True, False, False),
        ("up", False, False, False),
        ("up", True, False, False),
        ("down", False, True, False),
        ("side", False, False, True),
    ]
    sheet = Image.new("RGBA", (64 * 8, 64), (0, 0, 0, 0))
    for i, (face, shoot, hurt, flee) in enumerate(specs):
        sheet.paste(figure(face, shoot, hurt, flee), (i * 64, 0))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
