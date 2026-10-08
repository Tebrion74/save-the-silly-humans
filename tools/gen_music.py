#!/usr/bin/env python3
"""Build 015b/016: generates the looping chiptune tracks (originals, MIT).

    python3 tools/gen_music.py      -> assets/audio/music_level.wav   (015b)
                                       assets/audio/music_boss.wav    (015b)
                                       assets/audio/music_bonus.wav   (016)
                                       assets/audio/music_boss2.wav   (016)

Four NES-style voices, all synthesised here (no samples, no third-party
material): pulse lead, thin pulse arpeggio, triangle bass and noise drums.
Output is 8-bit mono 22.05 kHz PCM (small, and authentically crunchy). Each
file is an exact whole number of bars, so it loops seamlessly in Godot
(the .import sets loop_mode = forward).
"""
import os, struct, wave
import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6,
        'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def midi(name):
    """'C4' -> 60, 'F#3' -> 54."""
    n, o = name[:-1], int(name[-1])
    return 12 * (o + 1) + NOTE[n]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


class Song:
    def __init__(self, bpm, bars, steps_per_bar=16):
        self.step = int(round(RATE * 60.0 / bpm / 4))      # samples per 16th
        self.spb = steps_per_bar
        self.n = self.step * steps_per_bar * bars
        self.mix = np.zeros(self.n, dtype=np.float64)
        self.rng = np.random.default_rng(1515)

    def _place(self, start, sig):
        end = min(self.n, start + len(sig))
        self.mix[start:end] += sig[:end - start]

    def tone(self, step, length, m, vol, wave_='pulse', duty=0.5, decay=0.0, vib=0.0, slide=0.0):
        n = int(self.step * length)
        t = np.arange(n) / RATE
        f = hz(m) * (1.0 + slide * t / max(t[-1], 1e-6) if slide else 1.0)
        if vib:
            f = f * (1.0 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.15 - 0.5, 0, 1))
        ph = np.cumsum(f / RATE) % 1.0
        if wave_ == 'pulse':
            s = np.where(ph < duty, 1.0, -1.0)
        else:  # triangle (NES-ish 16-step quantised)
            s = np.round((1.0 - 4.0 * np.abs(ph - 0.5)) * 7.5) / 7.5
        env = np.ones(n)
        a = min(n, 40)
        env[:a] = np.linspace(0, 1, a)
        r = min(n, 220)
        env[-r:] *= np.linspace(1, 0, r)
        if decay:
            env *= np.exp(-t * decay)
        self._place(step * self.step, s * env * vol)

    def kick(self, step, vol=0.55):
        n = int(RATE * 0.12)
        t = np.arange(n) / RATE
        ph = np.cumsum(np.linspace(150, 45, n) / RATE)
        self._place(step * self.step, np.sin(2 * np.pi * ph) * np.exp(-t * 28) * vol)

    def snare(self, step, vol=0.32):
        n = int(RATE * 0.14)
        t = np.arange(n) / RATE
        noise = self.rng.uniform(-1, 1, n)
        body = np.sin(2 * np.pi * 190 * t)
        self._place(step * self.step, (noise * 0.8 + body * 0.35) * np.exp(-t * 26) * vol)

    def hat(self, step, vol=0.12, open_=False):
        n = int(RATE * (0.09 if open_ else 0.035))
        t = np.arange(n) / RATE
        noise = self.rng.uniform(-1, 1, n)
        noise = noise - np.concatenate([[0], noise[:-1]])      # crude high-pass
        self._place(step * self.step, noise * np.exp(-t * (30 if open_ else 90)) * vol)

    def write(self, path, peak=0.92):
        m = self.mix / max(1e-9, np.abs(self.mix).max()) * peak
        data = np.clip(np.round(m * 127 + 128), 0, 255).astype(np.uint8)
        with wave.open(path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(1)
            w.setframerate(RATE)
            w.writeframes(data.tobytes())
        print('wrote', os.path.relpath(path), f'{self.n / RATE:.2f}s', f'{os.path.getsize(path) // 1024} KB')


def chord_tones(root, kind):
    iv = {'maj': [0, 4, 7], 'min': [0, 3, 7], 'sus': [0, 5, 7]}[kind]
    return [root + i for i in iv]


# ---------------------------------------------------------------- level theme
def level_theme():
    """'Ranch Hand Hustle': bouncy C major, 132 BPM, 16 bars."""
    s = Song(132, 16)
    prog = [('C3', 'maj'), ('A2', 'min'), ('F2', 'maj'), ('G2', 'maj')] * 2 + \
           [('F2', 'maj'), ('G2', 'maj'), ('E2', 'min'), ('A2', 'min'),
            ('F2', 'maj'), ('G2', 'maj'), ('C3', 'maj'), ('G2', 'maj')]
    # lead motifs: (step, length, semitones above the chord root + 24)
    A = [(0, 2, 7), (2, 2, 12), (4, 1, 11), (5, 1, 12), (6, 2, 16), (8, 4, 14), (12, 2, 12), (14, 2, 7)]
    B = [(0, 3, 12), (3, 1, 10), (4, 2, 7), (6, 2, 4), (8, 2, 5), (10, 2, 7), (12, 4, 4)]
    C = [(0, 1, 7), (1, 1, 9), (2, 2, 12), (4, 2, 7), (6, 2, 12), (8, 6, 14), (14, 2, 12)]
    D = [(0, 2, 16), (2, 2, 14), (4, 2, 12), (6, 2, 7), (8, 8, 12)]
    motifs = [A, B, C, D, A, B, C, A, B, C, B, D, A, C, D, D]
    for bar, ((rn, kind), mot) in enumerate(zip(prog, motifs)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        # lead (pulse 25%)
        for st, ln, iv in mot:
            m = root + 12 + iv
            if kind == 'min' and (iv % 12) == 4:
                m -= 1          # keep the third minor over minor chords
            s.tone(base + st, ln, m, 0.20, duty=0.25, vib=0.004 if ln >= 4 else 0.0)
        # arpeggio (pulse 12.5%, quiet 16ths)
        for i in range(16):
            s.tone(base + i, 1, tones[i % 3] + 24, 0.06, duty=0.125, decay=8)
        # bass (triangle 8ths: root, root, fifth, octave pattern)
        pat = [0, 0, 7, 12, 0, 0, 7, 10 if kind == 'min' else 12]
        for i, iv in enumerate(pat):
            s.tone(base + i * 2, 2, root + iv, 0.34, wave_='tri')
        # drums
        for i in range(16):
            if i in (0, 8, 10) and not (bar % 4 == 3 and i == 10):
                s.kick(base + i)
            if i in (4, 12):
                s.snare(base + i)
            if i % 2 == 0:
                s.hat(base + i, open_=(i == 14))
        if bar % 4 == 3:        # little fill
            for i in (13, 14, 15):
                s.snare(base + i, 0.22)
    s.write(os.path.join(OUT, 'music_level.wav'))


# ---------------------------------------------------------------- boss theme
def boss_theme():
    """'Question Period': tense D minor, 156 BPM, 16 bars, driving bass."""
    s = Song(156, 16)
    prog = [('D2', 'min'), ('D2', 'min'), ('Bb1', 'maj'), ('A1', 'maj')] * 2 + \
           [('G1', 'min'), ('A1', 'maj'), ('D2', 'min'), ('C2', 'maj'),
            ('Bb1', 'maj'), ('G1', 'min'), ('A1', 'sus'), ('A1', 'maj')]
    # lead in absolute notes per bar (step, len, note) -- stabby, chromatic
    L = {
        0: [(0, 3, 'D5'), (3, 1, 'C#5'), (4, 2, 'D5'), (6, 2, 'F5'), (8, 3, 'E5'), (11, 1, 'D5'), (12, 4, 'A4')],
        1: [(0, 2, 'A4'), (2, 2, 'Bb4'), (4, 2, 'A4'), (6, 2, 'G4'), (8, 6, 'F4'), (14, 2, 'E4')],
        2: [(0, 3, 'D5'), (3, 1, 'C5'), (4, 2, 'Bb4'), (6, 2, 'D5'), (8, 3, 'F5'), (11, 1, 'E5'), (12, 4, 'D5')],
        3: [(0, 2, 'C#5'), (2, 2, 'E5'), (4, 2, 'A5'), (6, 2, 'G5'), (8, 4, 'E5'), (12, 4, 'C#5')],
        4: [(0, 2, 'Bb4'), (2, 2, 'D5'), (4, 4, 'G5'), (8, 2, 'F5'), (10, 2, 'D5'), (12, 4, 'Bb4')],
        5: [(0, 2, 'A4'), (2, 2, 'C#5'), (4, 4, 'E5'), (8, 2, 'G5'), (10, 2, 'F5'), (12, 4, 'E5')],
        6: [(0, 2, 'F5'), (2, 1, 'E5'), (3, 1, 'D5'), (4, 4, 'A5'), (8, 2, 'G5'), (10, 2, 'F5'), (12, 4, 'D5')],
        7: [(0, 2, 'E5'), (2, 2, 'G5'), (4, 2, 'C6'), (6, 2, 'G5'), (8, 8, 'E5')],
    }
    order = [0, 1, 0, 3, 2, 1, 0, 3, 4, 5, 6, 7, 4, 5, 6, 3]
    for bar, ((rn, kind), li) in enumerate(zip(prog, order)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        for st, ln, nm in L[li]:
            s.tone(base + st, ln, midi(nm), 0.19, duty=0.25 if bar < 8 else 0.5, vib=0.006 if ln >= 4 else 0.0)
        # tense arp: up-down 16ths, an octave above
        seq = [0, 1, 2, 1]
        for i in range(16):
            s.tone(base + i, 1, tones[seq[i % 4]] + 36, 0.05, duty=0.125, decay=10)
        # driving 8th bass with octave jumps
        for i in range(8):
            iv = 12 if i % 2 else 0
            if i == 7:
                iv = 1 if kind == 'maj' and rn.startswith('A') else 7
            s.tone(base + i * 2, 2, root + 12 + iv, 0.36, wave_='tri')
        # drums: four-on-the-floor-ish with offbeat hats
        for i in range(16):
            if i in (0, 6, 8, 14) or (bar % 2 and i == 11):
                s.kick(base + i, 0.6)
            if i in (4, 12):
                s.snare(base + i, 0.36)
            if i % 2 == 1:
                s.hat(base + i, 0.13)
            elif i % 4 == 2:
                s.hat(base + i, 0.08)
        if bar % 4 == 3:
            for i in (12, 13, 14, 15):
                s.snare(base + i, 0.2 + 0.04 * (i - 12))
    s.write(os.path.join(OUT, 'music_boss.wav'))


# ---------------------------------------------------------------- build 016 bonus stage
def bonus_theme():
    """'Fleece Frenzy': bright, bouncy F major, 150 BPM, 16 bars. Galaga-style
    challenging-stage energy: fast staccato lead, sparkly 16th arps, busy drums."""
    s = Song(150, 16)
    prog = [('F2', 'maj'), ('D2', 'min'), ('Bb1', 'maj'), ('C2', 'maj')] * 2 + \
           [('Bb1', 'maj'), ('C2', 'maj'), ('A1', 'min'), ('D2', 'min'),
            ('G1', 'min'), ('C2', 'maj'), ('F2', 'maj'), ('C2', 'maj')]
    # lead motifs: (step, length, semitones above root+12)
    A = [(0, 1, 12), (1, 1, 16), (2, 1, 19), (3, 1, 24), (4, 2, 19), (6, 1, 16), (7, 1, 19), (8, 2, 24), (10, 2, 26), (12, 4, 24)]
    B = [(0, 2, 19), (2, 1, 17), (3, 1, 16), (4, 2, 14), (6, 2, 12), (8, 1, 14), (9, 1, 16), (10, 2, 19), (12, 4, 16)]
    C = [(0, 1, 24), (1, 1, 19), (2, 1, 16), (3, 1, 19), (4, 1, 24), (5, 1, 19), (6, 1, 16), (7, 1, 19), (8, 4, 26), (12, 2, 24), (14, 2, 19)]
    D = [(0, 2, 28), (2, 2, 26), (4, 2, 24), (6, 2, 19), (8, 1, 24), (9, 1, 24), (10, 6, 24)]
    motifs = [A, B, A, C, A, B, C, D, B, C, B, C, A, C, D, D]
    for bar, ((rn, kind), mot) in enumerate(zip(prog, motifs)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        for st, ln, iv in mot:
            m = root + 12 + iv
            if kind == 'min' and (iv % 12) == 4:
                m -= 1
            s.tone(base + st, ln, m, 0.19, duty=0.25, decay=3.0 if ln <= 1 else 0.0, vib=0.005 if ln >= 4 else 0.0)
        # sparkle arp: up through two octaves, 16ths
        seq = [0, 1, 2, 3, 4, 5, 4, 3]
        notes = tones + [t + 12 for t in tones]
        for i in range(16):
            s.tone(base + i, 1, notes[seq[i % 8]] + 24, 0.055, duty=0.125, decay=9)
        # bouncy octave bass in 8ths
        for i in range(8):
            iv = 12 if i % 2 else 0
            s.tone(base + i * 2, 2, root + 12 + iv, 0.32, wave_='tri')
        for i in range(16):
            if i in (0, 4, 8, 12):
                s.kick(base + i, 0.5)
            if i in (4, 12):
                s.snare(base + i, 0.3)
            s.hat(base + i, 0.09 if i % 2 else 0.12, open_=(i == 14))
        if bar % 4 == 3:
            for i in (12, 13, 14, 15):
                s.snare(base + i, 0.18 + 0.04 * (i - 12))
    s.write(os.path.join(OUT, 'music_bonus.wav'))


# ---------------------------------------------------------------- build 016 boss 2
def boss2_theme():
    """'Firmware Sermon': tense, glitchy E minor, 168 BPM, 16 bars. A cold
    pulse ostinato, a bit-crushed lead and 'glitch' stutters (repeated
    16th-note slices, pitch-drop zaps) for the Huval Yarheyhey fight."""
    s = Song(168, 16)
    prog = [('E2', 'min'), ('E2', 'min'), ('C2', 'maj'), ('D2', 'maj')] * 2 + \
           [('A1', 'min'), ('B1', 'maj'), ('E2', 'min'), ('F2', 'maj'),
            ('C2', 'maj'), ('A1', 'min'), ('B1', 'sus'), ('B1', 'maj')]
    L = {
        0: [(0, 2, 'E5'), (2, 1, 'F5'), (3, 1, 'E5'), (4, 2, 'B4'), (6, 2, 'G4'), (8, 2, 'E5'), (10, 2, 'G5'), (12, 4, 'F#5')],
        1: [(0, 3, 'E5'), (3, 1, 'D5'), (4, 2, 'B4'), (6, 2, 'D5'), (8, 6, 'E5'), (14, 2, 'B4')],
        2: [(0, 2, 'C5'), (2, 2, 'E5'), (4, 2, 'G5'), (6, 2, 'E5'), (8, 2, 'C6'), (10, 2, 'B5'), (12, 4, 'G5')],
        3: [(0, 2, 'D5'), (2, 2, 'F#5'), (4, 2, 'A5'), (6, 2, 'F#5'), (8, 4, 'D5'), (12, 4, 'F#5')],
        4: [(0, 2, 'A4'), (2, 2, 'C5'), (4, 4, 'E5'), (8, 2, 'A5'), (10, 2, 'G5'), (12, 4, 'E5')],
        5: [(0, 2, 'D#5'), (2, 2, 'F#5'), (4, 4, 'B5'), (8, 2, 'A5'), (10, 2, 'F#5'), (12, 4, 'D#5')],
        6: [(0, 1, 'F5'), (1, 1, 'E5'), (2, 2, 'F5'), (4, 2, 'A5'), (6, 2, 'C6'), (8, 8, 'B5')],
    }
    order = [0, 1, 2, 3, 0, 1, 2, 3, 4, 5, 0, 6, 2, 4, 5, 5]
    for bar, ((rn, kind), li) in enumerate(zip(prog, order)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        for st, ln, nm in L[li]:
            s.tone(base + st, ln, midi(nm), 0.17, duty=0.5 if bar % 2 else 0.25, vib=0.008 if ln >= 4 else 0.0)
        # cold ostinato: root-fifth-octave-fifth 16ths, two octaves up
        seq = [0, 2, 3, 2]
        notes = [tones[0], tones[1], tones[2], tones[0] + 12]
        for i in range(16):
            s.tone(base + i, 1, notes[seq[i % 4]] + 24, 0.06, duty=0.125, decay=12)
        # pumping 16th bass on the root with octave pops
        for i in range(16):
            iv = 12 if i % 4 == 3 else 0
            s.tone(base + i, 1, root + 12 + iv, 0.3, wave_='tri', decay=6)
        for i in range(16):
            if i in (0, 3, 8, 11) or (bar % 4 == 2 and i == 14):
                s.kick(base + i, 0.62)
            if i in (4, 12):
                s.snare(base + i, 0.36)
            if i % 2 == 1:
                s.hat(base + i, 0.12)
        # glitch zap (pitch-drop pulse) at the end of every 2nd bar
        if bar % 2 == 1:
            s.tone(base + 15, 1, midi('E6'), 0.12, duty=0.5, slide=-0.85)
    # bit-crush the whole mix a little (4-bit-ish steps) for a digital edge
    m = s.mix / max(1e-9, np.abs(s.mix).max())
    s.mix = np.round(m * 12.0) / 12.0 * 0.7 + m * 0.3
    # stutters: in bars 7, 11 and 15 the last beat repeats its first 16th 4x
    for bar in (7, 11, 15):
        st = (bar * 16 + 12) * s.step
        sl = s.mix[st:st + s.step].copy()
        for k in range(4):
            s.mix[st + k * s.step: st + (k + 1) * s.step] = sl * (1.0 - 0.12 * k)
    s.write(os.path.join(OUT, 'music_boss2.wav'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    level_theme()
    boss_theme()
    bonus_theme()
    boss2_theme()
