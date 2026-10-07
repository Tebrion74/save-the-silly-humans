"""Shared painting helpers for the STSH build 008 terrain art (numpy + Pillow)."""
import numpy as np
from PIL import Image

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def ramp(*hexes):
    return np.stack([hexc(h) for h in hexes])


def bayer(h, w, ox=0, oy=0):
    yy, xx = np.mgrid[0:h, 0:w]
    return BAYER4[(yy + oy) % 4, (xx + ox) % 4]


def ramp_map(v, rmp, dither=0.55, ox=0, oy=0):
    """Map v in [0,1] onto a palette ramp with ordered dithering -> HxWx3 float."""
    h, w = v.shape
    n = len(rmp)
    t = np.clip(v, 0, 1) * (n - 1) + (bayer(h, w, ox, oy) - 0.5) * dither
    idx = np.clip(np.rint(t), 0, n - 1).astype(int)
    return rmp[idx]


def periodic_noise(size, scale, rng, octaves=1):
    """Tileable noise (period=size) with feature size ~scale px, normalised 0..1."""
    out = np.zeros((size, size))
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        s = scale / (2 ** o)
        w = rng.standard_normal((size, size))
        fy = np.fft.fftfreq(size)[:, None]
        fx = np.fft.fftfreq(size)[None, :]
        f = np.sqrt(fx * fx + fy * fy)
        filt = np.exp(-(f * s) ** 2 * 4.0)
        filt[0, 0] = 0
        n = np.real(np.fft.ifft2(np.fft.fft2(w) * filt))
        n = (n - n.mean()) / (n.std() + 1e-9)
        out += n * amp
        tot += amp
        amp *= 0.5
    out /= tot
    out = (out - out.min()) / (out.max() - out.min() + 1e-9)
    return out


def big_noise(h, w, scale, rng):
    """Non-tile noise for sprites."""
    s = max(h, w)
    s2 = 1
    while s2 < s:
        s2 *= 2
    n = periodic_noise(s2, scale, rng)
    return n[:h, :w]


def gblur(a, sigma, radius=None):
    if sigma <= 0:
        return a.copy()
    r = radius if radius is not None else int(np.ceil(sigma * 3))
    x = np.arange(-r, r + 1)
    k = np.exp(-(x * x) / (2 * sigma * sigma))
    k /= k.sum()
    p = np.pad(a, r, mode='edge')
    t = np.apply_along_axis(lambda m: np.convolve(m, k, mode='valid'), 1, p)
    t = np.apply_along_axis(lambda m: np.convolve(m, k, mode='valid'), 0, t)
    return t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


LIGHT = np.array([-0.55, -0.7, 0.9])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def lambert(hf, strength=1.0):
    gy, gx = np.gradient(hf)
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(hf)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return (nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / l


def outline(mask, rgba, color, alpha=255):
    """Draw a 1px outline outside 'mask' into rgba (HxWx4 uint-ish float)."""
    m = mask
    o = np.zeros_like(m)
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    o &= ~m
    rgba[o, :3] = color
    rgba[o, 3] = alpha
    return o


def inner_edge(mask):
    e = np.zeros_like(mask)
    e[1:, :] |= ~mask[:-1, :]
    e[:-1, :] |= ~mask[1:, :]
    e[:, 1:] |= ~mask[:, :-1]
    e[:, :-1] |= ~mask[:, 1:]
    return e & mask


def to_img(rgba):
    return Image.fromarray(np.clip(np.rint(rgba), 0, 255).astype(np.uint8), 'RGBA')


def blank(h, w):
    return np.zeros((h, w, 4), dtype=np.float32)
