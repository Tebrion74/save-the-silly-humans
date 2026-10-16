#!/usr/bin/env python3
"""Build 026: funk / groove level music (build 027: + taiga, florida and
the extra-epic boss9 / boss10 themes) + a punch-up pass for the boss and
bonus tracks. All original, synthesised here (no samples), MIT.

    python3 tools/gen_funk.py              -> every level + boss + bonus track
    python3 tools/gen_funk.py prairie med  -> only those biomes
    python3 tools/gen_funk.py --bosses     -> only the boss / bonus punch-up

Why: the 015b-025 tracks were 8-bit NES-style pulse waves with leads and
arpeggios at 0.6-2 kHz; 37-74 % of the level tracks' energy sat in the
1-3 kHz "shrill" band and loudness ranged -16..-25 LUFS.

Engine:
  * band-limited additive oscillators (no aliasing) with a time-varying
    low-pass per partial -> slap/synth bass, wah, clav, brass, organ, reeds
  * everything is rendered circularly into one loop buffer, so note tails
    and echoes wrap around: the loop is seamless by construction
  * master: FFT EQ on the whole (circular) loop - high-pass 30 Hz, warm
    low-mid lift, 1-4 kHz dip, high roll-off from ~5 kHz - then a
    look-ahead peak limiter (circular too) and EBU R128 loudness matching
    via ffmpeg. 16-bit mono 22.05 kHz, peak <= -1 dBFS.
"""
import os, sys, wave, subprocess, re, tempfile
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
LEVEL_LUFS = -18.0
BOSS_LUFS = -17.0
PEAK_DB = -1.0


def hz(m):
    return 440.0 * 2 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


# ------------------------------------------------------------------ synthesis
def _t(n):
    return np.arange(n) / SR


def env_adsr(n, a=0.005, d=0.1, s=0.7, r=0.03):
    t = _t(n)
    e = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
    rn = min(n, int(r * SR))
    if rn > 0:
        e[-rn:] *= np.linspace(1, 0, rn) ** 1.5
    return e


def additive(freq, cutoff, kind='saw', res=0.0, w=0.3, kdecay=0.0, phase0=0.0):
    """freq, cutoff: per-sample arrays (Hz). Returns a band-limited wave whose
    partials pass a 12 dB/oct low-pass at `cutoff` (+ resonance bump)."""
    n = len(freq)
    ph = 2 * np.pi * (np.cumsum(freq) / SR) + phase0
    out = np.zeros(n)
    fmin = max(float(freq.min()), 20.0)
    kmax = int(min(60, 9500.0 / fmin))
    t = _t(n) if kdecay else None
    for k in range(1, kmax + 1):
        if kind == 'saw':
            a = 1.0 / k
        elif kind == 'square':
            if k % 2 == 0:
                continue
            a = 1.0 / k
        elif kind == 'pulse':
            a = abs(np.sin(np.pi * k * w)) / k
        elif kind == 'sine':
            if k > 1:
                break
            a = 1.0
        else:
            a = 1.0 / k
        fk = k * freq
        r = fk / np.maximum(cutoff, 30.0)
        g = 1.0 / np.sqrt(1.0 + r ** 4)
        if res:
            g = g + res * np.exp(-((r - 1.0) / 0.22) ** 2) * g.max()
        g = g * np.clip((10000.0 - fk) / 1500.0, 0.0, 1.0)      # alias guard
        if kdecay:
            g = g * np.exp(-t * kdecay * (k - 1))
        if g.max() < 1e-4:
            continue
        out += a * g * np.sin(k * ph)
    return out


def noise(n, rng, lo=None, hi=None):
    x = rng.standard_normal(n)
    if lo is None and hi is None:
        return x
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    H = np.ones_like(f)
    if lo:
        H *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1)) ** 4)
    if hi:
        H *= 1 / np.sqrt(1 + (f / hi) ** 4)
    y = np.fft.irfft(X * H, n)
    return y / (np.abs(y).max() + 1e-9)


# instruments -> mono arrays (amplitude ~ 1)
class Kit:
    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)

    def kick(self, punch=1.0, tone=48.0):
        n = int(0.45 * SR); t = _t(n)
        f = tone + 115 * punch * np.exp(-t / 0.028)
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.32) * np.clip(t / 0.002, 0, 1)
        click = noise(n, self.rng, 800, 4000) * np.exp(-t / 0.004) * 0.18 * punch
        x = body + click
        return np.tanh(1.8 * x) / np.tanh(1.8)

    def snare(self, tight=1.0):
        n = int(0.32 * SR); t = _t(n)
        body = np.sin(2 * np.pi * np.cumsum(185 + 50 * np.exp(-t / 0.01)) / SR) * np.exp(-t / 0.07)
        nz = noise(n, self.rng, 350, 5200) * np.exp(-t / (0.15 / tight))
        return np.tanh(1.4 * (0.55 * body + 0.75 * nz))

    def clap(self):
        n = int(0.25 * SR); t = _t(n)
        nz = noise(n, self.rng, 700, 3500)
        e = sum(np.exp(-np.maximum(t - d, 0) / 0.008) * (t >= d) for d in (0, 0.011, 0.022)) * 0.6 + np.exp(-t / 0.09) * (t > 0.03)
        return nz * e * 0.8

    def rim(self):
        n = int(0.08 * SR); t = _t(n)
        return (np.sin(2 * np.pi * 820 * t) * 0.5 + noise(n, self.rng, 1200, 3800) * 0.5) * np.exp(-t / 0.018)

    def hat(self, open_=False):
        n = int((0.22 if open_ else 0.05) * SR); t = _t(n)
        return noise(n, self.rng, 3500, 7500) * np.exp(-t / (0.08 if open_ else 0.012))

    def shaker(self):
        n = int(0.07 * SR); t = _t(n)
        return noise(n, self.rng, 2500, 6500) * (t / 0.02) * np.exp(-t / 0.02)

    def tom(self, f0=95.0, dec=0.22):
        n = int(0.4 * SR); t = _t(n)
        f = f0 + 60 * np.exp(-t / 0.03)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / dec)

    def tek(self):
        n = int(0.06 * SR); t = _t(n)
        return (noise(n, self.rng, 1500, 4500) * 0.7 + np.sin(2 * np.pi * 1200 * t) * 0.3) * np.exp(-t / 0.012)


def note_len(dur):
    return max(16, int(dur * SR))


def bass_slap(m, dur, pop=False, ghost=False, slide=0.0):
    n = note_len(dur + 0.04); t = _t(n)
    f = hz(m) * np.ones(n)
    if slide:
        f = f * 2 ** (slide * np.clip(t / 0.08, 0, 1) / 12.0)
    if ghost:
        cut = 260 + 500 * np.exp(-t / 0.015)
        x = additive(f, cut, 'saw') * np.exp(-t / 0.04) * 0.45
        return x * env_adsr(n, 0.002, 0.05, 0.0, 0.01)
    cut = (420 if not pop else 700) + (1500 if not pop else 2300) * np.exp(-t / (0.05 if not pop else 0.035))
    x = 0.75 * additive(f, cut, 'saw', res=0.35) + 0.45 * additive(f, cut * 0.7, 'square')
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.05) * 0.5
    e = env_adsr(n, 0.002, 0.35 if not pop else 0.18, 0.55 if not pop else 0.3, 0.03)
    return (x + thump) * e


def bass_synth(m, dur, slide=0.0):
    n = note_len(dur + 0.05); t = _t(n)
    f = hz(m) * np.ones(n)
    if slide:
        f = f * 2 ** (slide * np.clip(t / 0.1, 0, 1) / 12.0)
    cut = 230 + 700 * np.exp(-t / 0.12)
    x = additive(f, cut, 'square', res=0.6) + 0.6 * np.sin(2 * np.pi * np.cumsum(f) / SR)
    return x * env_adsr(n, 0.004, 0.5, 0.75, 0.05)


def bass_tuba(m, dur):
    n = note_len(dur + 0.05); t = _t(n)
    f = hz(m) * (1 + 0.004 * np.sin(2 * np.pi * 5 * t) * np.clip(t / 0.2, 0, 1))
    cut = 380 + 650 * np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.25) + 150
    x = additive(f, cut, 'saw') * 0.8 + 0.5 * np.sin(2 * np.pi * np.cumsum(f) / SR)
    return x * env_adsr(n, 0.018, 0.3, 0.7, 0.05)


def clav(m, dur, bright=1.0):
    n = note_len(dur + 0.03); t = _t(n)
    f = hz(m) * np.ones(n)
    cut = 700 + 2200 * bright * np.exp(-t / 0.035)
    return additive(f, cut, 'pulse', res=0.3, w=0.22) * env_adsr(n, 0.001, 0.12, 0.25, 0.02)


def wah(m, dur, lfo_rate, lfo_phase):
    n = note_len(dur + 0.03); t = _t(n)
    f = hz(m) * np.ones(n)
    sweep = 0.5 - 0.5 * np.cos(2 * np.pi * (t * lfo_rate + lfo_phase))
    cut = 420 + 1250 * sweep
    return additive(f, cut, 'saw', res=1.1) * env_adsr(n, 0.003, 0.08, 0.45, 0.02)


def brass(m, dur, bright=1.0):
    n = note_len(dur + 0.07); t = _t(n)
    scoop = 2 ** (-0.35 * np.exp(-t / 0.02) / 12.0)
    x = np.zeros(n)
    cut = (450 + 2500 * bright * np.clip(t / 0.03, 0, 1)) * (0.65 + 0.35 * np.exp(-t / 0.2))
    for dc in (-0.07, 0.0, 0.08):
        f = hz(m + dc) * scoop
        x += additive(f * np.ones(n), cut, 'saw', res=0.15)
    return x / 3 * env_adsr(n, 0.012, 0.25, 0.7, 0.06)


def organ(m, dur):
    n = note_len(dur + 0.04); t = _t(n)
    f = hz(m)
    ph = 2 * np.pi * f * t
    x = sum(a * np.sin(k * ph) for k, a in ((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (6, 0.07)))
    x *= 1 + 0.09 * np.sin(2 * np.pi * 5.8 * t)
    return x / 1.9 * env_adsr(n, 0.008, 0.2, 0.9, 0.04)


def rhodes(m, dur):
    n = note_len(dur + 0.25); t = _t(n)
    f = hz(m)
    ph = 2 * np.pi * f * t
    x = np.sin(ph + 0.9 * np.exp(-t / 0.35) * np.sin(ph)) + 0.12 * np.sin(2 * ph) * np.exp(-t / 0.3)
    x *= 1 + 0.18 * np.sin(2 * np.pi * 4.2 * t)
    return x * env_adsr(n, 0.003, 0.9, 0.35, 0.2)


def reed(m, dur, kind='harmonica'):
    """harmonica (bend-in, vibrato) / accordion (musette detune)."""
    n = note_len(dur + 0.04); t = _t(n)
    if kind == 'harmonica':
        f = hz(m) * 2 ** (-0.9 * np.exp(-t / 0.05) / 12) * (1 + 0.007 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.25 - 0.3, 0, 1))
        x = additive(f, 1300 + 300 * np.clip(t / 0.05, 0, 1), 'pulse', res=0.35, w=0.4)
        return x * env_adsr(n, 0.03, 0.3, 0.75, 0.05)
    x = 0
    for dc in (-0.1, 0.1):
        f = hz(m + dc) * np.ones(n)
        x = x + additive(f, 1500 * np.ones(n), 'pulse', w=0.35)
    x *= 1 + 0.06 * np.sin(2 * np.pi * 6 * t)
    return x / 2 * env_adsr(n, 0.02, 0.2, 0.85, 0.04)


def fiddle(m, dur):
    n = note_len(dur + 0.05); t = _t(n)
    f = hz(m) * (1 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip(t / 0.15 - 0.4, 0, 1))
    x = additive(f, 1700 * np.ones(n), 'saw', res=0.25) + 0.4 * additive(f * 2 ** (-7 / 12), 1300 * np.ones(n), 'saw')
    return x * env_adsr(n, 0.035, 0.3, 0.8, 0.05)


def steel(m, dur):
    n = note_len(dur + 0.2); t = _t(n)
    f = hz(m) * 2 ** (-2.0 * np.exp(-t / 0.06) / 12) * (1 + 0.004 * np.sin(2 * np.pi * 5 * t))
    x = 0.7 * np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * additive(f, 1500 * np.ones(n), 'saw')
    return x * env_adsr(n, 0.01, 0.8, 0.5, 0.15)


def pluck(m, dur, bright=2600.0, sustain=0.35):
    n = note_len(dur + 0.25); t = _t(n)
    f = hz(m) * np.ones(n)
    cut = 350 + bright * np.exp(-t / 0.09)
    return additive(f, cut, 'saw', res=0.2) * np.exp(-t / sustain) * env_adsr(n, 0.001, 9, 1.0, 0.03)


def surf(m, dur):
    n = note_len(dur + 0.1); t = _t(n)
    f = hz(m) * np.ones(n)
    x = 0.7 * additive(f, 1400 * np.ones(n), 'saw', res=0.3) + 0.4 * additive(f, 900 * np.ones(n), 'square')
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * 7.0 * t)
    return x * env_adsr(n, 0.004, 0.5, 0.6, 0.06)


def steelpan(m, dur):
    """Build 027: a mellow steel-pan-ish mallet (sine partials 1, 2, 3.01 with
    fast-decaying overtones) - Florida / Gulf flavour without the shrill top."""
    n = note_len(dur + 0.35); t = _t(n)
    f = hz(m)
    ph = 2 * np.pi * f * t
    x = np.sin(ph) + 0.45 * np.sin(2 * ph) * np.exp(-t / 0.18) + 0.18 * np.sin(3.01 * ph) * np.exp(-t / 0.07)
    return x * np.exp(-t / 0.6) * env_adsr(n, 0.002, 9, 1.0, 0.05)


def balalaika(m, dur):
    """Build 027: a tremolo-picked triangle-bodied pluck (re-struck 12x / s)."""
    n = note_len(dur + 0.15); t = _t(n)
    f = hz(m) * np.ones(n)
    rate = 12.0
    ph = (t * rate) % 1.0
    cut = 500 + 1500 * np.exp(-ph / 0.08)
    x = additive(f, cut, 'saw', res=0.2)
    trem = 0.55 + 0.45 * np.exp(-ph / 0.06)
    return x * trem * env_adsr(n, 0.002, 0.6, 0.7, 0.06)


def choir(m, dur):
    """Build 027: a dark "aah" choir pad for the epic boss themes (detuned
    soft saws through a fixed low formant)."""
    n = note_len(dur + 0.1); t = _t(n)
    x = 0
    for dc in (-0.12, 0.0, 0.11):
        f = hz(m + dc) * (1 + 0.004 * np.sin(2 * np.pi * (5.0 + dc) * t))
        x = x + additive(f * np.ones(n), 900 * np.ones(n), 'saw', res=0.5)
    return x / 3 * env_adsr(n, 0.18, 0.5, 0.85, 0.2)


LEADS = {'fiddle': fiddle, 'steelpan': steelpan, 'balalaika': balalaika, 'choir': choir, 'harmonica': lambda m, d: reed(m, d, 'harmonica'),
         'accordion': lambda m, d: reed(m, d, 'accordion'), 'steel': steel, 'surf': surf,
         'bouzouki': lambda m, d: pluck(m, d, 2000, 0.3), 'bandura': lambda m, d: pluck(m, d, 2300, 0.45),
         'rhodes': rhodes, 'brass': brass, 'organ': organ}


# ------------------------------------------------------------------ loop buffer
class Loop:
    def __init__(self, bpm, bars, swing=0.0):
        self.bpm, self.bars, self.swing = bpm, bars, swing
        self.step_len = SR * 60.0 / bpm / 4.0
        self.n = int(round(self.step_len * 16 * bars))
        self.bus = {}
        self.kick_env = np.zeros(self.n)

    def pos(self, step):
        s = int(np.floor(step))
        frac = step - s
        sw = self.swing * self.step_len if s % 2 == 1 else 0.0
        return int(round((s + frac) * self.step_len + sw)) % self.n

    def secs(self, steps):
        return steps * self.step_len / SR

    def add(self, bus, step, sig, gain=1.0):
        b = self.bus.setdefault(bus, np.zeros(self.n))
        p = self.pos(step)
        L = len(sig)
        while L > 0:                       # circular: tails wrap to the top
            k = min(L, self.n - p)
            b[p:p + k] += sig[:k] * gain
            sig = sig[k:]; L -= k; p = 0
        return b

    def add_kick(self, step, sig, gain):
        self.add('drums', step, sig, gain)
        e = np.exp(-_t(int(0.18 * SR)) / 0.07)
        p = self.pos(step)
        idx = (p + np.arange(len(e))) % self.n
        self.kick_env[idx] = np.maximum(self.kick_env[idx], e)


def echo(x, delay_samples, fb=0.3, taps=3, tone=2500.0):
    y = x.copy()
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    lp = 1 / np.sqrt(1 + (f / tone) ** 2)
    g = 1.0
    cur = X
    for i in range(1, taps + 1):
        g *= fb
        cur = cur * lp
        y += np.roll(np.fft.irfft(cur, len(x)), delay_samples * i) * g
    return y


# ------------------------------------------------------------------ master
def master_eq(x, warm=1.0, top=6200.0):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(n, 1 / SR), 1.0)
    db = np.zeros_like(f)
    db += 20 * np.log10(1 / np.sqrt(1 + (30.0 / f) ** 4))                  # HP 30 Hz
    db += 2.0 * warm / (1 + (f / 140.0) ** 2)                               # low shelf
    db += 1.8 * warm * np.exp(-(np.log2(f / 320.0) / 1.1) ** 2)             # warm low-mid
    db -= 1.5 * np.exp(-(np.log2(f / 2300.0) / 0.9) ** 2)                  # 1-4 kHz dip (shrill)
    db += 20 * np.log10(1 / np.sqrt(1 + (f / top) ** 4))                    # roll-off
    db += 20 * np.log10(1 / np.sqrt(1 + (f / 8500.0) ** 12))                # brick above 8.5k
    y = np.fft.irfft(X * 10 ** (db / 20), n)
    return y - y.mean()


def limiter(x, ceiling_db=PEAK_DB, look=0.003, rel=0.12):
    """Circular look-ahead peak limiter: run over two laps, keep the second."""
    c = 10 ** (ceiling_db / 20)
    n = len(x)
    xx = np.concatenate([x, x])
    need = np.minimum(1.0, c / np.maximum(np.abs(xx), 1e-9))
    la = max(1, int(look * SR))
    # look-ahead minimum (sliding window via stride trick)
    padded = np.concatenate([need, np.ones(la)])
    from numpy.lib.stride_tricks import sliding_window_view
    gmin = sliding_window_view(padded, la + 1).min(axis=1)[:len(need)]
    a = np.exp(-1.0 / (rel * SR))
    g = np.empty_like(gmin)
    cur = 1.0
    gl = gmin.tolist()
    out = [0.0] * len(gl)
    for i, v in enumerate(gl):
        cur = v if v < cur else v + (cur - v) * a
        out[i] = cur
    g = np.array(out)
    y = (xx * g)[n:]
    return np.clip(y, -c, c)


def lufs_of(x):
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tf:
        path = tf.name
    write_wav(path, np.tile(x, 2) if len(x) < SR * 10 else x, quiet=True)
    o = subprocess.run(['ffmpeg', '-nostats', '-hide_banner', '-i', path, '-af', 'ebur128', '-f', 'null', '-'],
                       capture_output=True, text=True).stderr
    os.unlink(path)
    m = re.findall(r'I:\s+(-?[\d.]+) LUFS', o)
    return float(m[-1]) if m else -70.0


def finish(x, target_lufs, warm=1.0, top=6200.0):
    y = master_eq(x, warm, top)
    y = y / (np.abs(y).max() + 1e-9) * 0.5
    for _ in range(3):                          # gain -> limit -> re-measure
        L = lufs_of(np.clip(y, -1, 1))
        y = y * 10 ** ((target_lufs - L) / 20)
        y = limiter(y)
    return y


def write_wav(path, x, quiet=False):
    d = np.clip(np.round(x * 32767), -32768, 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(d.tobytes())
    if not quiet:
        print('wrote', os.path.relpath(path), f'{len(x) / SR:.2f}s', f'{os.path.getsize(path) // 1024} KB')


# ------------------------------------------------------------------ arranging
QUAL = {'7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'M7': [0, 4, 7, 11], 'M': [0, 4, 7, 12], 'm': [0, 3, 7, 12],
        '9': [0, 4, 10, 14], 'm9': [0, 3, 10, 14], 'sus': [0, 5, 7, 10], '6': [0, 4, 7, 9]}


def chord_interval(tok, q):
    tones = QUAL[q]
    third = tones[1]
    sev = 10 if 10 in tones else (11 if 11 in tones else 9)
    return {'R': 0, '3': third, '5': 7, '6': 9, '7': sev, '8': 12, 'b2': 1, '2': 2, '4': 5, 'b5': 6,
            '-5': -5, '-7': sev - 12, '-1': -1, '-2': -2}[tok]


def voice(root_mid, q, prev=None, centre=55):
    """Close voicing near `centre` (MIDI) with simple voice leading."""
    ivs = QUAL[q]
    best = None
    for base in range(root_mid - 12, root_mid + 13):
        if (base - root_mid) % 12:
            continue
        for inv in range(len(ivs)):
            notes = sorted(base + ((iv + 12) if i < inv else iv) for i, iv in enumerate(ivs))
            notes = [x for x in notes]
            c = abs(np.mean(notes) - (np.mean(prev) if prev else centre))
            if best is None or c < best[0]:
                best = (c, notes)
    return best[1]


BASS = {   # (step, chord token, length steps, kind) kinds: s slap, p pop, g ghost, n normal
    'slap16': [(0, 'R', 3, 's'), (3, 'R', 1, 'g'), (4, '8', 1, 'p'), (6, 'R', 1, 's'), (7, '7', 1, 'p'),
               (10, 'R', 2, 's'), (11, 'R', 1, 'g'), (12, '5', 1, 's'), (14, '8', 1, 'p'), (15, '7', 1, 'p')],
    'cookout': [(0, 'R', 2, 's'), (2, 'R', 1, 'g'), (3, '8', 1, 'p'), (5, 'R', 1, 's'), (6, '5', 2, 's'),
                (9, '6', 1, 's'), (10, '7', 1, 'p'), (11, '8', 1, 'p'), (12, 'R', 2, 's'), (14, '3', 1, 's'), (15, '-1', 1, 's')],
    'halftime': [(0, 'R', 5, 's'), (6, 'R', 1, 'g'), (7, '8', 1, 'p'), (10, 'R', 2, 's'), (12, 'b2', 2, 'n'), (14, 'R', 2, 's')],
    'shuffle': [(0, 'R', 2, 's'), (2, '3', 2, 'n'), (4, '5', 2, 'n'), (6, '6', 2, 'n'), (8, '7', 2, 'p'),
                (10, '6', 2, 'n'), (12, '5', 2, 'n'), (14, '3', 1, 'n'), (15, '-1', 1, 'g')],
    'oompah': [(0, 'R', 3, 'n'), (6, '8', 1, 'p'), (8, '-5', 3, 'n'), (11, 'R', 1, 'g'), (12, 'R', 2, 'n'), (14, '8', 1, 'p'), (15, '7', 1, 'p')],
    'laidback': [(0, 'R', 5, 'n'), (6, 'R', 1, 'n'), (7, '8', 2, 'n'), (10, '5', 2, 'n'), (12, '7', 3, 'n'), (15, '8', 1, 'n')],
    'cruise': [(0, 'R', 2, 's'), (3, '8', 1, 'p'), (4, 'R', 1, 'g'), (6, '5', 2, 's'), (9, 'R', 1, 's'),
               (10, '7', 1, 'p'), (11, '8', 1, 'p'), (12, 'R', 2, 's'), (14, '5', 1, 's'), (15, '7', 1, 'p')],
    'stomp': [(0, 'R', 2, 's'), (2, 'R', 1, 'g'), (3, '8', 1, 'p'), (4, 'R', 2, 's'), (6, '5', 1, 's'), (7, '8', 1, 'p'),
              (8, 'R', 2, 's'), (10, '3', 1, 's'), (11, '5', 1, 's'), (12, '7', 2, 's'), (14, '5', 1, 's'), (15, '8', 1, 'p')],
    'hustle': [(0, 'R', 2, 's'), (2, '8', 1, 'p'), (3, 'R', 1, 'g'), (6, 'R', 1, 's'), (7, '5', 1, 's'), (8, '7', 1, 'p'),
               (10, 'R', 2, 's'), (13, '3', 1, 's'), (14, '5', 1, 's'), (15, '8', 1, 'p')],
    # build 027
    'troika': [(0, 'R', 2, 's'), (2, 'R', 1, 'g'), (3, '5', 1, 's'), (4, '8', 1, 'p'), (6, 'R', 2, 's'), (8, '3', 2, 's'),
               (10, '5', 1, 's'), (11, 'R', 1, 'g'), (12, '7', 2, 's'), (14, '5', 1, 's'), (15, '-1', 1, 'p')],
    'calypso': [(0, 'R', 3, 's'), (3, '5', 1, 's'), (6, 'R', 1, 'p'), (7, '8', 1, 'p'), (8, '3', 3, 's'), (11, '5', 1, 's'),
                (14, '6', 1, 's'), (15, '7', 1, 'p')],
    'gallop': [(0, 'R', 1, 's'), (1, 'R', 1, 'g'), (2, 'R', 1, 's'), (4, 'R', 1, 's'), (5, 'R', 1, 'g'), (6, '8', 1, 'p'),
               (8, 'R', 1, 's'), (9, 'R', 1, 'g'), (10, 'R', 1, 's'), (12, '5', 1, 's'), (13, '5', 1, 'g'), (14, '7', 1, 's'), (15, '8', 1, 'p')],
    'tower': [(0, 'R', 2, 's'), (2, 'R', 1, 'g'), (3, 'R', 1, 's'), (4, '8', 1, 'p'), (6, 'R', 1, 's'), (7, 'b2', 1, 's'),
              (8, 'R', 2, 's'), (10, '8', 1, 'p'), (11, 'R', 1, 's'), (12, '5', 1, 's'), (13, 'b5', 1, 's'), (14, '4', 1, 's'), (15, '-1', 1, 'p')],
}

DRUMS = {  # K kick, S snare, G ghost, H hat steps (accent list), O open hats, extra
    'funk':     dict(K=[0, 7, 10], S=[4, 12], G=[6, 9, 15], H=list(range(16)), O=[11]),
    'cookout':  dict(K=[0, 8, 10], S=[4, 12], G=[2, 7, 14], H=list(range(16)), O=[15]),
    'halftime': dict(K=[0, 10], S=[8], G=[3, 14], H=list(range(0, 16, 2)), O=[], doum=[0, 6, 10], tek=[2, 4, 7, 12, 14, 15]),
    'shuffle':  dict(K=[0, 8, 11], S=[4, 12], G=[3, 7, 15], H=list(range(0, 16, 2)), O=[14]),
    'oompah':   dict(K=[0, 4, 8, 12], S=[4, 12], G=[10, 15], H=[2, 6, 10, 14], O=[2, 6, 10, 14], clap=[4, 12]),
    'laidback': dict(K=[0, 9], S=[4, 12], G=[7, 14], H=list(range(0, 16, 2)), O=[], rim=[3, 10]),
    'cruise':   dict(K=[0, 3, 8, 11], S=[4, 12], G=[6, 10, 15], H=list(range(16)), O=[7]),
    'stomp':    dict(K=[0, 4, 8, 10, 12], S=[4, 12], G=[7, 15], H=list(range(16)), O=[14], clap=[12]),
    'hustle':   dict(K=[0, 6, 10], S=[4, 12], G=[3, 9, 13], H=list(range(16)), O=[2, 14]),
    # build 027
    'troika':   dict(K=[0, 6, 8, 14], S=[4, 12], G=[2, 10, 15], H=list(range(16)), O=[7], clap=[12]),
    'calypso':  dict(K=[0, 3, 8, 11], S=[4, 12], G=[7, 14], H=list(range(0, 16, 2)), O=[], rim=[0, 3, 6, 10, 12]),
    'gallop':   dict(K=[0, 2, 4, 8, 10, 12], S=[4, 12], G=[7, 15], H=list(range(16)), O=[14], clap=[4, 12], timp=[0, 8]),
    'tower':    dict(K=[0, 3, 6, 8, 11, 14], S=[4, 12], G=[2, 9, 15], H=list(range(16)), O=[7, 15], clap=[4, 12], timp=[0, 6, 8]),
}

COMP = {   # (step, length steps) chord hits per bar
    'clav':   [(2, 1), (5, 1), (6, 1), (10, 1), (13, 1), (14, 1)],
    'scratch': [(i, 0.5) for i in range(16)],
    'offbeat': [(2, 1.5), (6, 1.5), (10, 1.5), (14, 1.5)],
    'pads':   [(0, 6), (6, 2), (8, 6), (14, 2)],
    'rhodes': [(0, 3), (3, 1), (6, 4), (10, 2), (13, 3)],
    'roll':   [(i, 1) for i in range(16)],
    'organ':  [(0, 7), (7, 1), (8, 6), (14, 2)],
}


def scale_note(tonic, scale, deg):
    o, d = divmod(deg, len(scale))
    return tonic + 12 * o + scale[d]


def render_biome(name, c):
    L = Loop(c['bpm'], 16, c.get('swing', 0.0))
    kit = Kit(c['seed'])
    K = kit.kick(c.get('punch', 1.0)); S = kit.snare(); G = kit.snare(1.6)
    Hc = kit.hat(); Ho = kit.hat(True); CL = kit.clap(); RIM = kit.rim()
    DOUM = kit.tom(90, 0.25); TEK = kit.tek(); TIMP = kit.tom(c.get('timp_hz', 62), 0.5)
    dr = DRUMS[c['drums']]
    bass_pat = BASS[c['bass']]
    root = c['root']                    # bass root (MIDI, octave 1-2)
    prog = c['prog']                    # 8 bars of (semitones from root, quality); B section reuses
    prev = None
    sec = L.secs(1)
    for bar in range(16):
        b0 = bar * 16
        off, q = prog[bar % len(prog)]
        croot = root + off
        breakdown = bar in (12, 13)
        fillbar = bar == 15
        # ---------------- drums
        for st in dr['K']:
            if breakdown and st != 0:
                continue
            L.add_kick(b0 + st, K, 0.95 if st == 0 else 0.8)
        for st in dr['S']:
            if fillbar and st > 8:
                continue
            L.add('drums', b0 + st, S, 0.62)
        for st in dr.get('clap', []):
            L.add('drums', b0 + st, CL, 0.32)
        for st in dr['G']:
            L.add('drums', b0 + st, G, 0.12)
        for st in dr.get('rim', []):
            L.add('drums', b0 + st, RIM, 0.2)
        for st in dr.get('doum', []):
            L.add('drums', b0 + st, DOUM, 0.5)
        for st in dr.get('tek', []):
            L.add('drums', b0 + st, TEK, 0.22)
        for st in dr.get('timp', []):            # build 027: epic timpani hits
            if not breakdown or st == 0:
                L.add('drums', b0 + st, TIMP, 0.55)
        for st in dr['H']:
            acc = 1.0 if st % 4 == 2 else (0.75 if st % 2 == 0 else 0.5)
            L.add('hats', b0 + st, Ho if st in dr['O'] else Hc, 0.075 * acc)
        if fillbar:                          # snare/tom fill that leads back to bar 1
            for i, st in enumerate(range(8, 16)):
                L.add('drums', b0 + st, S if i % 2 == 0 else kit.tom(130 - 8 * i, 0.15), 0.25 + 0.05 * i)
        # ---------------- bass
        bfun = {'synth': bass_synth, 'tuba': bass_tuba}.get(c.get('bass_voice'), None)
        for st, tok, ln, kind in bass_pat:
            m = croot + chord_interval(tok, q)
            d = L.secs(ln) * 0.92
            if bfun is bass_synth:
                sig = bass_synth(m, d)
            elif bfun is bass_tuba:
                sig = bass_tuba(m, d) if kind != 'p' else bass_slap(m, d, pop=True)
            else:
                sig = bass_slap(m, d, pop=(kind == 'p'), ghost=(kind == 'g'))
            L.add('bass', b0 + st, sig, 0.9 if kind != 'g' else 0.7)
        # ---------------- comp
        notes = voice(croot + 24, q, prev, c.get('comp_centre', 55))
        prev = notes
        cv = c['comp_voice']
        rate = c['bpm'] / 60.0 / 2
        for i, (st, ln) in enumerate(COMP[c['comp']]):
            if breakdown and c['comp'] in ('scratch', 'roll') and st % 4:
                continue
            d = L.secs(ln) * 0.9
            for j, m in enumerate(notes[:3]):
                if cv == 'clav':
                    sig = clav(m, d)
                elif cv == 'wah':
                    sig = wah(m, d, rate, (b0 + st) / 8.0)
                elif cv == 'organ':
                    sig = organ(m, d)
                elif cv == 'rhodes':
                    sig = rhodes(m, d)
                elif cv == 'accordion':
                    sig = reed(m, d, 'accordion')
                elif cv in ('bouzouki', 'bandura', 'banjo'):
                    # arpeggiated pluck: one chord tone per hit
                    if j:
                        continue
                    m = notes[i % len(notes)]
                    sig = pluck(m, d, 2100 if cv == 'banjo' else 1900, 0.18)
                elif cv == 'surf':
                    sig = surf(m, d)
                elif cv == 'steelpan':
                    if j == 2:
                        continue
                    sig = steelpan(m, d)
                elif cv == 'balalaika':
                    if j:
                        continue
                    m = notes[i % len(notes)]
                    sig = balalaika(m, d)
                else:
                    sig = clav(m, d)
                acc = 1.0 if st % 4 == 2 else 0.8
                L.add('comp', b0 + st, sig, c.get('comp_gain', 0.16) * acc)
        if c.get('pad'):
            pv = {'organ': organ, 'choir': choir}.get(c['pad'], rhodes)
            for m in notes:
                L.add('pad', b0, pv(m - 12 if m > 60 else m, L.secs(16) * 0.98), c.get('pad_gain', 0.06))
        # ---------------- brass stabs (bombastic)
        stabs = c['stabs_b'] if bar >= 8 else (c['stabs_a'] if bar % 4 == 3 else [])
        if breakdown:
            stabs = []
        bnotes = voice(croot + 24, q, None, c.get('brass_centre', 58))
        for st, ln in stabs:
            for m in bnotes:
                L.add('brass', b0 + st, brass(m, L.secs(ln) * 0.85), 0.11 * c.get('brass_gain', 1.0))
            L.add('brass', b0 + st, brass(bnotes[0] - 12, L.secs(ln) * 0.85), 0.12)   # low horn
        if fillbar:
            for k, st in enumerate((12, 13, 14, 15)):
                for m in voice(croot + 24 + k, q, None, 58):
                    L.add('brass', b0 + st, brass(m, L.secs(0.8)), 0.06 + 0.02 * k)
    # ---------------- regional lead / hook
    lv = LEADS[c['lead']]
    tonic = c['lead_tonic']
    for bar_rel, st, ln, deg in c['hook']:
        for rep_bar in c['hook_bars']:
            m = scale_note(tonic, c['scale'], deg)
            L.add('lead', (rep_bar + bar_rel) * 16 + st, lv(m, L.secs(ln) * 0.95), c.get('lead_gain', 0.2))
    for bar_rel, st, ln, deg in c.get('answer', []):
        m = scale_note(tonic, c['scale'], deg)
        L.add('lead', (c['answer_bar'] + bar_rel) * 16 + st, lv(m, L.secs(ln) * 0.95), c.get('lead_gain', 0.2))
    # ---------------- mix
    n = L.n
    get = lambda k: L.bus.get(k, np.zeros(n))
    duck = 1.0 - 0.28 * np.clip(L.kick_env, 0, 1)
    lead = get('lead')
    if c.get('lead_echo'):
        lead = echo(lead, int(L.step_len * 3), 0.28, 2, 1800)
    comp = get('comp')
    if c.get('comp_echo'):
        comp = echo(comp, int(L.step_len * 2), 0.22, 2, 1600)
    # bus balance (RMS targets ~ drums -10, bass -12, comp -18, lead -17, brass -19, hats -33 dB)
    mix = (get('drums') * 1.0 + get('hats') * 8.0 + get('bass') * 0.42 * (0.75 + 0.25 * duck) +
           comp * 2.4 * duck + get('pad') * 2.0 * duck + get('brass') * 2.8 + lead * 2.0)
    return finish(mix, c.get('lufs', LEVEL_LUFS), warm=c.get('warm', 1.0), top=c.get('top', 6200.0))


MIXO = [0, 2, 4, 5, 7, 9, 10]; DOR = [0, 2, 3, 5, 7, 9, 10]; HIJAZ = [0, 1, 4, 5, 7, 8, 10]
MAJ = [0, 2, 4, 5, 7, 9, 11]; UKR = [0, 2, 3, 6, 7, 9, 10]; BLUES = [0, 3, 5, 6, 7, 10]
MPENT = [0, 2, 4, 7, 9]

BIOMES = {
    # L1-2 Trustin / Canadian prairie: country-funk, G mixolydian
    'prairie': dict(title='Prairie Strut', bpm=100, swing=0.10, seed=2601, root=31,      # G1
        prog=[(0, '7'), (0, '7'), (5, '7'), (0, '7'), (7, '7'), (5, '7'), (0, '7'), (7, '7')],
        bass='slap16', drums='funk', comp='clav', comp_voice='banjo', comp_gain=0.2,
        stabs_a=[(10, 2), (14, 2)], stabs_b=[(6, 1), (10, 2), (14, 1)],
        lead='fiddle', lead_tonic=55, scale=MIXO, lead_gain=0.17,                       # G3
        hook=[(0, 0, 2, 4), (0, 2, 1, 5), (0, 3, 1, 4), (0, 4, 2, 2), (0, 6, 2, 0), (0, 8, 3, 4),
              (0, 11, 1, 6), (0, 12, 4, 7), (1, 0, 2, 6), (1, 2, 2, 4), (1, 4, 4, 2), (1, 8, 6, 4)],
        hook_bars=[2, 6], answer_bar=9,
        answer=[(0, 0, 3, 7), (0, 3, 1, 6), (0, 4, 2, 4), (0, 6, 2, 6), (0, 8, 4, 7), (1, 0, 2, 9),
                (1, 2, 2, 7), (1, 4, 2, 6), (1, 6, 2, 4), (1, 8, 8, 7)]),
    # fallback (theme-less levels): plain hustle, Eb mixolydian
    'level': dict(title='Ranch Hand Hustle', bpm=104, swing=0.08, seed=2600, root=27,     # Eb1
        prog=[(0, '9'), (0, '9'), (5, '9'), (5, '9'), (0, '9'), (8, 'M7'), (10, '7'), (0, '9')],
        bass='hustle', drums='hustle', comp='scratch', comp_voice='wah', comp_gain=0.12,
        stabs_a=[(6, 2), (10, 2)], stabs_b=[(0, 2), (6, 1), (7, 1), (10, 3)],
        lead='brass', lead_tonic=51, scale=MIXO, lead_gain=0.16,                          # Eb3
        hook=[(0, 0, 2, 7), (0, 3, 1, 6), (0, 4, 2, 4), (0, 6, 2, 6), (0, 8, 6, 7), (1, 0, 2, 4), (1, 3, 1, 2), (1, 4, 8, 4)],
        hook_bars=[2, 10], answer_bar=6, answer=[(0, 8, 2, 4), (0, 10, 2, 6), (0, 12, 4, 7)]),
    # L3-5 Huval / Mediterranean: half-time funk, D hijaz, doumbek + bouzouki
    'med': dict(title='Olive Grove Groove', bpm=94, swing=0.0, seed=2603, root=38,        # D2
        prog=[(0, 'M'), (0, 'M'), (1, 'M'), (0, 'M'), (-2, 'm'), (1, 'M'), (0, 'M'), (0, '7')],
        bass='halftime', drums='halftime', comp='roll', comp_voice='bouzouki', comp_gain=0.15,
        stabs_a=[(8, 3)], stabs_b=[(0, 2), (8, 3), (14, 1)],
        lead='bouzouki', lead_tonic=50, scale=HIJAZ, lead_gain=0.2, lead_echo=True,       # D3
        hook=[(0, 0, 1, 4), (0, 1, 1, 5), (0, 2, 2, 4), (0, 4, 2, 3), (0, 6, 2, 2), (0, 8, 2, 1),
              (0, 10, 2, 2), (0, 12, 4, 0), (1, 0, 2, 1), (1, 2, 2, 2), (1, 4, 4, 4), (1, 8, 8, 0)],
        hook_bars=[2, 6, 10], answer_bar=14, answer=[(0, 0, 2, 7), (0, 2, 2, 6), (0, 4, 2, 5), (0, 6, 2, 4)]),
    # L6-8 Kush / Texas: shuffle funk, E, pedal-steel hook
    'texas': dict(title='Lone Star Strut', bpm=108, swing=0.30, seed=2606, root=28,      # E1
        prog=[(0, '7'), (0, '7'), (5, '7'), (0, '7'), (7, '7'), (5, '7'), (0, '7'), (7, '7')],
        bass='shuffle', drums='shuffle', comp='clav', comp_voice='organ', comp_gain=0.1, pad=None,
        stabs_a=[(12, 2)], stabs_b=[(4, 1), (6, 2), (12, 2)],
        lead='steel', lead_tonic=52, scale=BLUES, lead_gain=0.2,                          # E3
        hook=[(0, 0, 4, 6), (0, 4, 2, 5), (0, 6, 2, 3), (0, 8, 8, 4), (1, 0, 3, 3), (1, 3, 1, 2), (1, 4, 4, 0), (1, 8, 8, 1)],
        hook_bars=[2, 6, 10], answer_bar=14, answer=[(0, 0, 4, 6), (0, 4, 4, 9), (0, 8, 8, 6)]),
    # L9-11 Shlaus / Bavaria: oompah funk, Bb major, accordion + big brass
    'bavaria': dict(title='Oompah Overdrive', bpm=116, swing=0.0, seed=2609, root=34,    # Bb1
        prog=[(0, 'M'), (0, 'M'), (7, '7'), (7, '7'), (0, 'M'), (5, 'M'), (7, '7'), (0, 'M')],
        bass='oompah', bass_voice='tuba', drums='oompah', comp='offbeat', comp_voice='accordion', comp_gain=0.13,
        stabs_a=[(0, 2), (8, 2)], stabs_b=[(0, 3), (6, 1), (8, 3), (14, 2)],
        lead='brass', lead_tonic=46, scale=MAJ, lead_gain=0.2,                            # Bb2
        hook=[(0, 0, 2, 7), (0, 2, 2, 9), (0, 4, 4, 11), (0, 8, 2, 9), (0, 10, 2, 7), (0, 12, 4, 4),
              (1, 0, 2, 6), (1, 2, 2, 8), (1, 4, 4, 10), (1, 8, 4, 8), (1, 12, 4, 6)],
        hook_bars=[8, 12], answer_bar=2,
        answer=[(0, 0, 2, 4), (0, 2, 2, 4), (0, 4, 2, 5), (0, 6, 2, 6), (0, 8, 8, 7)]),
    # L12-14 Gill / Pacific Northwest: laid-back rainy funk, F dorian, Rhodes
    'pnw': dict(title='Rainforest Roll', bpm=90, swing=0.14, seed=2612, root=29,         # F1
        prog=[(0, 'm9'), (0, 'm9'), (5, '9'), (5, '9'), (0, 'm9'), (0, 'm9'), (3, 'M7'), (5, '9')],
        bass='laidback', bass_voice='synth', drums='laidback', comp='rhodes', comp_voice='rhodes', comp_gain=0.13,
        comp_echo=True, stabs_a=[(8, 6)], stabs_b=[(0, 6), (8, 6)],
        lead='rhodes', lead_tonic=53, scale=DOR, lead_gain=0.18, lead_echo=True,           # F3
        hook=[(0, 0, 3, 4), (0, 3, 3, 3), (0, 6, 2, 2), (0, 8, 8, 0), (1, 0, 3, 2), (1, 3, 3, 3), (1, 6, 10, 4)],
        hook_bars=[2, 6, 10, 14], answer_bar=12, answer=[]),
    # L15-17 Nancy / Golden Coast: cruising surf-funk, A dorian, tremolo guitar
    'norcal': dict(title='Golden Coast Cruise', bpm=102, swing=0.06, seed=2615, root=33,  # A1
        prog=[(0, 'm7'), (0, 'm7'), (5, '9'), (5, '9'), (0, 'm7'), (0, 'm7'), (-2, 'M'), (5, '9')],
        bass='cruise', drums='cruise', comp='scratch', comp_voice='wah', comp_gain=0.11,
        stabs_a=[(14, 2)], stabs_b=[(2, 1), (6, 2), (14, 2)],
        lead='surf', lead_tonic=57, scale=DOR, lead_gain=0.16, lead_echo=True,             # A3
        hook=[(0, 0, 2, 0), (0, 2, 2, 2), (0, 4, 2, 4), (0, 6, 2, 6), (0, 8, 6, 7), (0, 14, 2, 6),
              (1, 0, 4, 4), (1, 4, 2, 2), (1, 6, 2, 3), (1, 8, 8, 4)],
        hook_bars=[2, 10], answer_bar=6, answer=[(0, 8, 2, 7), (0, 10, 2, 6), (0, 12, 4, 4)]),
    # L18-20 Rogan / Midwest: cookout funk, C, harmonica + gospel organ
    'midwest': dict(title='Cornfield Cookout', bpm=98, swing=0.18, seed=2618, root=36,    # C2
        prog=[(0, '7'), (0, '7'), (5, '7'), (0, '7'), (7, '7'), (5, '7'), (0, '7'), (7, '7')],
        bass='cookout', drums='cookout', comp='clav', comp_voice='clav', comp_gain=0.14, pad='organ',
        stabs_a=[(6, 2)], stabs_b=[(0, 1), (6, 2), (10, 1), (12, 2)],
        lead='harmonica', lead_tonic=60, scale=BLUES, lead_gain=0.15,                      # C4 (warm reed)
        hook=[(0, 0, 2, 0), (0, 2, 2, 1), (0, 4, 1, 2), (0, 5, 3, 3), (0, 8, 4, 4), (0, 12, 4, 3),
              (1, 0, 2, 1), (1, 2, 2, 0), (1, 4, 4, -2), (1, 8, 8, 0)],
        hook_bars=[2, 6, 10], answer_bar=14, answer=[(0, 0, 2, 5), (0, 2, 2, 4), (0, 4, 4, 3), (0, 8, 8, 4)]),
    # L21-23 Violentsky / Ukraine: steppe stomp, B Ukrainian dorian, bandura + brass
    'ukraine': dict(title='Steppe Stomp', bpm=112, swing=0.0, seed=2621, root=35,         # B1
        prog=[(0, 'm'), (0, 'm'), (5, 'M'), (0, 'm'), (7, '7'), (5, 'M'), (7, '7'), (0, 'm')],
        bass='stomp', drums='stomp', comp='roll', comp_voice='bandura', comp_gain=0.16,
        stabs_a=[(12, 2)], stabs_b=[(0, 2), (4, 1), (8, 2), (12, 1), (14, 1)],
        lead='bandura', lead_tonic=47, scale=UKR, lead_gain=0.22, lead_echo=True,          # B2
        hook=[(0, 0, 2, 7), (0, 2, 2, 8), (0, 4, 2, 9), (0, 6, 2, 10), (0, 8, 4, 11), (0, 12, 2, 10), (0, 14, 2, 9),
              (1, 0, 2, 10), (1, 2, 2, 9), (1, 4, 2, 8), (1, 6, 2, 7), (1, 8, 8, 7)],
        hook_bars=[2, 6, 10], answer_bar=14, answer=[(0, 0, 4, 11), (0, 4, 4, 10), (0, 8, 8, 7)]),
    # build 027 - L24-26 Puddin / snowy taiga: troika funk, F# harmonic minor, balalaika tremolo + bayan
    'taiga': dict(title='Troika Trot', bpm=110, swing=0.04, seed=2701, root=30,          # F#1
        prog=[(0, 'm'), (0, 'm'), (5, 'm'), (0, 'm'), (7, '7'), (5, 'm'), (7, '7'), (0, 'm')],
        bass='troika', drums='troika', comp='roll', comp_voice='balalaika', comp_gain=0.13, pad='organ',
        stabs_a=[(8, 2), (12, 2)], stabs_b=[(0, 2), (4, 1), (8, 2), (12, 2)],
        lead='accordion', lead_tonic=54, scale=[0, 2, 3, 5, 7, 8, 11], lead_gain=0.15,      # F#3 bayan
        hook=[(0, 0, 2, 4), (0, 2, 2, 3), (0, 4, 2, 2), (0, 6, 2, 1), (0, 8, 4, 0), (0, 12, 4, 4),
              (1, 0, 2, 5), (1, 2, 2, 4), (1, 4, 2, 3), (1, 6, 2, 2), (1, 8, 8, 4)],
        hook_bars=[2, 6, 10], answer_bar=14, answer=[(0, 0, 2, 7), (0, 2, 2, 6), (0, 4, 4, 5), (0, 8, 8, 4)]),
    # build 027 - L27-29 Rump / Florida palms + golf greens: calypso funk, Ab, steel pan + horns
    'florida': dict(title='Palm Links Shuffle', bpm=96, swing=0.12, seed=2704, root=32,   # Ab1
        prog=[(0, 'M7'), (0, 'M7'), (5, '9'), (5, '9'), (0, 'M7'), (9, 'm7'), (2, 'm7'), (7, '7')],
        bass='calypso', drums='calypso', comp='offbeat', comp_voice='steelpan', comp_gain=0.12, pad='rhodes',
        stabs_a=[(14, 2)], stabs_b=[(2, 1), (6, 2), (10, 1), (14, 2)],
        lead='steelpan', lead_tonic=56, scale=MAJ, lead_gain=0.2, lead_echo=True,           # Ab3
        hook=[(0, 0, 2, 4), (0, 2, 1, 5), (0, 3, 3, 4), (0, 6, 2, 2), (0, 8, 2, 0), (0, 10, 2, 2), (0, 12, 4, 4),
              (1, 0, 2, 5), (1, 2, 2, 7), (1, 4, 4, 5), (1, 8, 8, 4)],
        hook_bars=[2, 10], answer_bar=6, answer=[(0, 8, 2, 7), (0, 10, 2, 8), (0, 12, 4, 9)]),
}

# build 027: extra-epic boss themes (same engine, -17 LUFS, timpani + choir)
EPIC = {
    # Vladimir Puddin: a galloping cossack-march funk, C# harmonic minor, 136 BPM
    'boss9': dict(title='Bareback Blizzard', bpm=136, swing=0.0, seed=2709, root=37, lufs=BOSS_LUFS,   # C#2
        prog=[(0, 'm'), (0, 'm'), (8, 'M'), (7, '7'), (0, 'm'), (5, 'm'), (7, '7'), (7, '7')],
        bass='gallop', drums='gallop', comp='roll', comp_voice='balalaika', comp_gain=0.12,
        pad='choir', pad_gain=0.09, brass_gain=1.35, timp_hz=58,
        stabs_a=[(0, 2), (8, 2)], stabs_b=[(0, 3), (6, 1), (8, 3), (14, 2)],
        lead='brass', lead_tonic=49, scale=[0, 2, 3, 5, 7, 8, 11], lead_gain=0.22,          # C#3
        hook=[(0, 0, 3, 4), (0, 3, 1, 3), (0, 4, 4, 4), (0, 8, 2, 5), (0, 10, 2, 4), (0, 12, 4, 3),
              (1, 0, 2, 2), (1, 2, 2, 3), (1, 4, 4, 1), (1, 8, 8, 0)],
        hook_bars=[2, 6, 10, 14], answer_bar=12, answer=[(0, 0, 4, 7), (0, 4, 4, 6), (0, 8, 8, 4)], top=6500.0),
    # Donald Rump: the final boss - a towering gold-brass funk march, G minor, 142 BPM
    'boss10': dict(title='The Final Round', bpm=142, swing=0.0, seed=2710, root=31, lufs=BOSS_LUFS,   # G1
        prog=[(0, 'm'), (0, 'm'), (3, 'M'), (1, 'M'), (0, 'm'), (8, 'M'), (7, '7'), (6, 'M')],
        bass='tower', drums='tower', comp='clav', comp_voice='clav', comp_gain=0.12,
        pad='choir', pad_gain=0.1, brass_gain=1.5, timp_hz=52, punch=1.2,
        stabs_a=[(0, 2), (6, 1), (8, 2)], stabs_b=[(0, 3), (3, 1), (6, 2), (8, 3), (11, 1), (14, 2)],
        lead='brass', lead_tonic=55, scale=[0, 2, 3, 5, 7, 8, 10], lead_gain=0.22,          # G3
        hook=[(0, 0, 2, 0), (0, 2, 2, 2), (0, 4, 2, 4), (0, 6, 2, 5), (0, 8, 6, 7), (0, 14, 2, 6),
              (1, 0, 2, 5), (1, 2, 2, 4), (1, 4, 4, 2), (1, 8, 4, 4), (1, 12, 4, 7)],
        hook_bars=[2, 6, 10, 14], answer_bar=12, answer=[(0, 0, 2, 9), (0, 2, 2, 8), (0, 4, 4, 7), (0, 8, 8, 4)], top=6800.0),
    # build 028: title / attract-mode theme. Anthemic arcade hook on brass over
    # slap bass, Bb mixolydian-major, 112 BPM, low-mid focus.
    'title': dict(title='Silly Humans Anthem', bpm=112, swing=0.06, seed=2801, root=34, lufs=-17.5,   # Bb1
        prog=[(0, 'M'), (0, 'M'), (5, 'M'), (5, 'M'), (9, 'm'), (7, 'M'), (5, 'M'), (7, '7')],
        bass='slap16', drums='funk', comp='clav', comp_voice='clav', comp_gain=0.13,
        pad='choir', pad_gain=0.06, brass_gain=1.3, punch=1.1,
        stabs_a=[(0, 2), (6, 1), (10, 2)], stabs_b=[(0, 2), (3, 1), (6, 2), (10, 1), (12, 2), (14, 1)],
        lead='brass', lead_tonic=58, scale=[0, 2, 4, 5, 7, 9, 10], lead_gain=0.2,          # Bb3
        hook=[(0, 0, 2, 0), (0, 2, 2, 4), (0, 4, 4, 7), (0, 8, 2, 6), (0, 10, 2, 7), (0, 12, 4, 9),
              (1, 0, 3, 8), (1, 3, 1, 7), (1, 4, 4, 5), (1, 8, 2, 4), (1, 10, 2, 5), (1, 12, 4, 7)],
        hook_bars=[0, 4, 8, 12], answer_bar=14,
        answer=[(0, 0, 2, 9), (0, 2, 2, 7), (0, 4, 2, 9), (0, 6, 2, 11), (0, 8, 8, 7)], top=6200.0),
}


# ------------------------------------------------------------------ boss / bonus punch-up
def punch_up(names):
    """Re-render the 015b-025 boss/bonus themes through gen_music.py with
    their melodies and tempos intact, but: 16-bit, band-limited voices, the
    leads and arps an octave lower (anything above C5), no thin 12.5 %
    duties, the new punchy kick/snare, and the new master chain."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gen_music as gm
    kit = Kit(2650)
    KICK = kit.kick(1.15, 50.0); SN = kit.snare()
    captured = {}

    def tone(self, step, length, m, vol, wave_='pulse', duty=0.5, decay=0.0, vib=0.0, slide=0.0):
        n = int(self.step * length)
        if n < 8:
            return
        t = np.arange(n) / SR
        while m > 72:                       # nothing above C5
            m -= 12
        f = hz(m) * ((1.0 + slide * t / max(t[-1], 1e-6)) if slide else 1.0) * np.ones(n)
        if vib:
            f = f * (1.0 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.15 - 0.5, 0, 1))
        if wave_ == 'pulse':
            w = min(max(duty, 0.3), 0.5)
            cut = 2200 + 1800 * np.exp(-t / 0.06)
            s = additive(f, cut, 'pulse', w=w) * 1.4
        else:
            s = 0.8 * np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.35 * additive(f, 500 * np.ones(n), 'saw')
            s = s * 1.25
        env = env_adsr(n, 0.004, 9, 1.0, 0.012)
        if decay:
            env *= np.exp(-t * decay)
        self._place(step * self.step, s * env * vol)

    def kick(self, step, vol=0.55):
        self._place(step * self.step, KICK * vol * 1.15)

    def snare(self, step, vol=0.32):
        self._place(step * self.step, SN * vol * 1.2)

    def hat(self, step, vol=0.12, open_=False):
        self._place(step * self.step, kit.hat(open_) * vol * 0.45)

    def _place(self, start, sig):           # circular, like Loop.add
        p = start % self.n
        while len(sig):
            k = min(len(sig), self.n - p)
            self.mix[p:p + k] += sig[:k]
            sig = sig[k:]; p = 0

    def write(self, path, peak=0.92):
        captured[path] = self.mix.copy()

    gm.Song.tone = tone; gm.Song.kick = kick; gm.Song.snare = snare; gm.Song.hat = hat
    gm.Song._place = _place; gm.Song.write = write
    if hasattr(gm, '_tone_x'):
        orig_tx = gm._tone_x
        def tone_x(s, step, length, m, vol, duty=0.5, trem=0.0, trem_hz=7.0, bend=0.0, vib=0.0, decay=0.0, wave_='pulse'):
            return tone(s, step, length, m, vol, wave_=wave_, duty=duty, decay=decay, vib=vib)
        gm._tone_x = tone_x
    fns = {'boss': gm.boss_theme, 'bonus': gm.bonus_theme, 'boss2': gm.boss2_theme, 'boss3': gm.boss3_theme,
           'boss4': gm.boss4_theme, 'boss5': gm.boss5_theme, 'boss6': gm.boss6_theme,
           'boss7': gm.boss7_theme, 'boss8': gm.boss8_theme}
    for nm in names:
        captured.clear()
        fns[nm]()
        (path, mix), = captured.items()
        y = finish(mix, BOSS_LUFS, warm=0.9, top=7200.0)
        write_wav(os.path.join(OUT, 'music_%s.wav' % nm), y)


BOSS_TRACKS = ['boss', 'bonus', 'boss2', 'boss3', 'boss4', 'boss5', 'boss6', 'boss7', 'boss8']

if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['--bosses']:
        punch_up(BOSS_TRACKS); sys.exit()
    todo = args or (list(BIOMES) + list(EPIC) + ['--bosses'])
    for nm in todo:
        if nm == '--bosses':
            punch_up(BOSS_TRACKS)
        elif nm in BOSS_TRACKS:
            punch_up([nm])
        elif nm in EPIC:
            write_wav(os.path.join(OUT, 'music_%s.wav' % nm), render_biome(nm, EPIC[nm]))
        else:
            y = render_biome(nm, BIOMES[nm])
            write_wav(os.path.join(OUT, 'music_level.wav' if nm == 'level' else 'music_level_%s.wav' % nm), y)
