#!/usr/bin/env python3
"""Build 015b/016: generates the looping chiptune tracks (originals, MIT).

    python3 tools/gen_music.py      -> assets/audio/music_level.wav   (015b)
                                       assets/audio/music_boss.wav    (015b)
                                       assets/audio/music_bonus.wav   (016)
                                       assets/audio/music_boss2.wav   (016)
                                       assets/audio/music_boss3.wav   (018)
                                       assets/audio/music_boss4.wav   (018)
    python3 tools/gen_music.py boss3 boss4   -> only those tracks

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


# ---------------------------------------------------------------- build 018 boss 3
def boss3_theme():
    """'Danger Close': a brassy G minor flight-deck march, 144 BPM, 16 bars,
    snare rolls, an afterburner 'whoosh' (falling pulse) every 4 bars, for the
    Beorge Kush Jr. fight."""
    s = Song(144, 16)
    s.rng = np.random.default_rng(1818)
    prog = [('G2', 'min'), ('G2', 'min'), ('Eb2', 'maj'), ('D2', 'maj')] * 2 + \
           [('C2', 'min'), ('D2', 'maj'), ('G2', 'min'), ('F2', 'maj'),
            ('Eb2', 'maj'), ('C2', 'min'), ('D2', 'sus'), ('D2', 'maj')]
    L = {
        0: [(0, 3, 'G4'), (3, 1, 'G4'), (4, 2, 'Bb4'), (6, 2, 'D5'), (8, 4, 'G5'), (12, 2, 'F5'), (14, 2, 'D5')],
        1: [(0, 2, 'Eb5'), (2, 2, 'D5'), (4, 2, 'C5'), (6, 2, 'Bb4'), (8, 6, 'A4'), (14, 2, 'D5')],
        2: [(0, 3, 'G5'), (3, 1, 'F5'), (4, 2, 'Eb5'), (6, 2, 'G5'), (8, 3, 'Bb5'), (11, 1, 'A5'), (12, 4, 'G5')],
        3: [(0, 2, 'F#5'), (2, 2, 'A5'), (4, 4, 'D6'), (8, 2, 'C6'), (10, 2, 'A5'), (12, 4, 'F#5')],
        4: [(0, 2, 'C5'), (2, 2, 'Eb5'), (4, 4, 'G5'), (8, 2, 'F5'), (10, 2, 'Eb5'), (12, 4, 'C5')],
        5: [(0, 1, 'D5'), (1, 1, 'D5'), (2, 2, 'F#5'), (4, 2, 'A5'), (6, 2, 'F#5'), (8, 8, 'D5')],
    }
    order = [0, 1, 0, 3, 2, 1, 2, 3, 4, 5, 0, 2, 4, 1, 5, 3]
    for bar, ((rn, kind), li) in enumerate(zip(prog, order)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        for st, ln, nm in L[li]:
            # brass-ish: lead doubled an octave down on a wider pulse
            s.tone(base + st, ln, midi(nm), 0.17, duty=0.25, vib=0.006 if ln >= 4 else 0.0)
            s.tone(base + st, ln, midi(nm) - 12, 0.08, duty=0.5)
        # stabby chord hits on the off-beats (march feel)
        for i in (2, 6, 10, 14):
            for t in tones:
                s.tone(base + i, 1, t + 24, 0.045, duty=0.125, decay=14)
        # march bass: root / fifth on the beat
        for i in range(4):
            iv = 0 if i % 2 == 0 else 7
            s.tone(base + i * 4, 3, root + 12 + iv, 0.36, wave_='tri')
        for i in range(16):
            if i in (0, 8):
                s.kick(base + i, 0.62)
            if i in (4, 12):
                s.snare(base + i, 0.38)
            if i in (14, 15) or (bar % 2 == 1 and i in (6, 7)):
                s.snare(base + i, 0.16)     # rudiment flams
            if i % 2 == 1:
                s.hat(base + i, 0.1)
        if bar % 4 == 3:
            for i in range(8, 16):
                s.snare(base + i, 0.12 + 0.025 * (i - 8))   # snare roll
            s.tone(base + 12, 4, midi('G6'), 0.07, duty=0.5, slide=-0.9)   # afterburner whoosh
    s.write(os.path.join(OUT, 'music_boss3.wav'))


# ---------------------------------------------------------------- build 018 boss 4
def boss4_theme():
    """'Summit Waltz': an ominous C minor waltz (3/4, 12 sixteenths per bar),
    176 BPM, 24 bars: an organ-ish doubled lead, a sweeping oom-pah-pah bass
    and a bell on every downbeat, for the Shlaus Kwobb fight."""
    s = Song(176, 24, steps_per_bar=12)
    s.rng = np.random.default_rng(1819)
    prog = [('C2', 'min'), ('C2', 'min'), ('Ab1', 'maj'), ('G1', 'maj')] * 2 + \
           [('F1', 'min'), ('G1', 'maj'), ('C2', 'min'), ('Eb2', 'maj')] * 2 + \
           [('Ab1', 'maj'), ('F1', 'min'), ('D2', 'min'), ('G1', 'maj')] * 2
    L = {
        0: [(0, 4, 'C5'), (4, 2, 'Eb5'), (6, 2, 'G5'), (8, 4, 'C6')],
        1: [(0, 4, 'B5'), (4, 4, 'G5'), (8, 4, 'Eb5')],
        2: [(0, 4, 'Ab5'), (4, 2, 'G5'), (6, 2, 'F5'), (8, 4, 'Eb5')],
        3: [(0, 6, 'D5'), (6, 2, 'F5'), (8, 2, 'G5'), (10, 2, 'B5')],
        4: [(0, 4, 'F5'), (4, 4, 'Ab5'), (8, 4, 'C6')],
        5: [(0, 2, 'B5'), (2, 2, 'C6'), (4, 2, 'D6'), (6, 6, 'G5')],
        6: [(0, 8, 'Eb5'), (8, 4, 'D5')],
    }
    order = [0, 1, 2, 3, 0, 1, 2, 5, 4, 3, 0, 6, 4, 5, 0, 6, 2, 4, 6, 3, 2, 4, 1, 5]
    for bar, ((rn, kind), li) in enumerate(zip(prog, order)):
        root = midi(rn)
        base = bar * 12
        tones = chord_tones(root, kind)
        for st, ln, nm in L[li]:
            m = midi(nm)
            s.tone(base + st, ln, m, 0.15, duty=0.5, vib=0.01 if ln >= 4 else 0.0)
            s.tone(base + st, ln, m + 7, 0.05, duty=0.25)       # organ fifth
        # oom-pah-pah: bass on 1, chord on 2 and 3
        s.tone(base, 4, root + 12, 0.38, wave_='tri')
        for i in (4, 8):
            for t in tones:
                s.tone(base + i, 2, t + 24, 0.05, duty=0.125, decay=7)
        # bell (high pulse with a fast decay) on every downbeat, louder every 4 bars
        s.tone(base, 3, tones[0] + 48, 0.09 if bar % 4 == 0 else 0.05, duty=0.125, decay=5)
        s.kick(base, 0.5)
        s.hat(base + 4, 0.08)
        s.hat(base + 8, 0.08)
        if bar % 4 == 3:
            s.snare(base + 8, 0.25)
            s.snare(base + 10, 0.28)
    s.write(os.path.join(OUT, 'music_boss4.wav'))


# ---------------------------------------------------------------- build 020 boss 5
def boss5_theme():
    """'Blue Screen Boogie': a bouncy E minor chiptune shuffle, 150 BPM, 16
    bars: fast 16th arpeggios like a modem handshake, a walking triangle bass,
    'error beep' stabs every 4 bars, for the Gill Bates fight. Original."""
    s = Song(150, 16)
    s.rng = np.random.default_rng(2014)
    prog = [('E2', 'min'), ('C2', 'maj'), ('G2', 'maj'), ('D2', 'maj')] * 2 + \
           [('A2', 'min'), ('E2', 'min'), ('C2', 'maj'), ('B1', 'maj')] * 2
    L = {
        0: [(0, 2, 'E5'), (2, 2, 'G5'), (4, 2, 'B5'), (6, 2, 'E6'), (8, 4, 'D6'), (12, 4, 'B5')],
        1: [(0, 3, 'C6'), (3, 1, 'B5'), (4, 2, 'G5'), (6, 2, 'E5'), (8, 6, 'G5'), (14, 2, 'A5')],
        2: [(0, 2, 'B5'), (2, 2, 'D6'), (4, 4, 'G6'), (8, 2, 'F#6'), (10, 2, 'D6'), (12, 4, 'B5')],
        3: [(0, 2, 'A5'), (2, 2, 'F#5'), (4, 2, 'D5'), (6, 2, 'F#5'), (8, 8, 'A5')],
        4: [(0, 4, 'A5'), (4, 2, 'C6'), (6, 2, 'E6'), (8, 4, 'D6'), (12, 4, 'C6')],
        5: [(0, 2, 'D#6'), (2, 2, 'B5'), (4, 2, 'F#5'), (6, 2, 'D#5'), (8, 8, 'B5')],
    }
    order = [0, 1, 2, 3, 0, 1, 2, 3, 4, 0, 1, 5, 4, 0, 1, 5]
    for bar, ((rn, kind), li) in enumerate(zip(prog, order)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        for st, ln, nm in L[li]:
            s.tone(base + st, ln, midi(nm), 0.15, duty=0.25, vib=0.008 if ln >= 4 else 0.0)
        # modem-handshake arpeggio (quiet, fast)
        for i in range(16):
            t = tones[i % 3] + 24 + (12 if i % 6 >= 3 else 0)
            s.tone(base + i, 1, t, 0.04, duty=0.125, decay=18)
        # walking bass
        for i, iv in enumerate((0, 7, 12, 7)):
            s.tone(base + i * 4, 3, root + 12 + iv, 0.34, wave_='tri')
        for i in range(16):
            if i in (0, 6, 10):
                s.kick(base + i, 0.55)
            if i in (4, 12):
                s.snare(base + i, 0.33)
            if i % 2 == 0:
                s.hat(base + i, 0.09)
        if bar % 4 == 3:
            for k, i in enumerate((12, 13, 14)):   # error beeps
                s.tone(base + i, 1, midi('A6') - k * 5, 0.08, duty=0.5)
    s.write(os.path.join(OUT, 'music_boss5.wav'))


# ---------------------------------------------------------------- build 020 boss 6
def boss6_theme():
    """'Order in the House': a stately, slightly pompous Bb major march,
    132 BPM, 16 bars: a brass-band lead in thirds, gavel-knock woodblocks,
    a tuba triangle bass, for the Nancy Pelotto fight. Original."""
    s = Song(132, 16)
    s.rng = np.random.default_rng(2017)
    prog = [('Bb1', 'maj'), ('Eb2', 'maj'), ('F2', 'maj'), ('Bb1', 'maj')] * 2 + \
           [('G2', 'min'), ('C2', 'min'), ('F2', 'maj'), ('F2', 'sus')] * 2
    L = {
        0: [(0, 4, 'D5'), (4, 2, 'F5'), (6, 2, 'Bb5'), (8, 6, 'D6'), (14, 2, 'C6')],
        1: [(0, 4, 'Bb5'), (4, 4, 'G5'), (8, 4, 'Eb5'), (12, 4, 'G5')],
        2: [(0, 2, 'A5'), (2, 2, 'C6'), (4, 4, 'F6'), (8, 4, 'Eb6'), (12, 4, 'C6')],
        3: [(0, 8, 'Bb5'), (8, 2, 'F5'), (10, 2, 'D5'), (12, 4, 'F5')],
        4: [(0, 4, 'G5'), (4, 2, 'Bb5'), (6, 2, 'D6'), (8, 4, 'C6'), (12, 4, 'Bb5')],
        5: [(0, 2, 'C6'), (2, 2, 'Eb6'), (4, 4, 'G6'), (8, 8, 'F6')],
    }
    order = [0, 1, 2, 3, 0, 1, 2, 3, 4, 1, 5, 2, 4, 1, 5, 3]
    for bar, ((rn, kind), li) in enumerate(zip(prog, order)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        for st, ln, nm in L[li]:
            m = midi(nm)
            s.tone(base + st, ln, m, 0.15, duty=0.25, vib=0.006 if ln >= 4 else 0.0)
            s.tone(base + st, ln, m - 4 if kind != 'min' else m - 3, 0.06, duty=0.5)   # band thirds
        for i in (2, 6, 10, 14):
            for t in tones:
                s.tone(base + i, 1, t + 24, 0.04, duty=0.125, decay=12)
        for i in range(4):
            s.tone(base + i * 4, 2, root + 12 + (0 if i % 2 == 0 else 7), 0.38, wave_='tri')
        for i in range(16):
            if i in (0, 8):
                s.kick(base + i, 0.6)
            if i in (4, 12):
                s.snare(base + i, 0.3)
            if i % 4 == 2:
                s.hat(base + i, 0.08)
        if bar % 4 == 3:
            for i in (8, 10, 12):           # gavel knocks
                s.tone(base + i, 1, midi('E5'), 0.12, duty=0.5, decay=40)
    s.write(os.path.join(OUT, 'music_boss6.wav'))


# ---------------------------------------------------------------- build 023 biome themes
def _tone_x(s, step, length, m, vol, duty=0.5, trem=0.0, trem_hz=7.0, bend=0.0, vib=0.0, decay=0.0, wave_='pulse'):
    """Pulse/triangle with optional tremolo (accordion / surf), a bend-in
    from `bend` semitones (fiddle slide / twang) and vibrato."""
    n = int(s.step * length)
    if n <= 0:
        return
    t = np.arange(n) / RATE
    f = hz(m) * np.ones(n)
    if bend:
        f = f * 2 ** ((bend * np.exp(-t * 28.0)) / 12.0)
    if vib:
        f = f * (1.0 + vib * np.sin(2 * np.pi * 5.8 * t) * np.clip(t / 0.12 - 0.4, 0, 1))
    ph = np.cumsum(f / RATE) % 1.0
    if wave_ == 'pulse':
        sig = np.where(ph < duty, 1.0, -1.0)
    else:
        sig = np.round((1.0 - 4.0 * np.abs(ph - 0.5)) * 7.5) / 7.5
    env = np.ones(n)
    a = min(n, 50)
    env[:a] = np.linspace(0, 1, a)
    r = min(n, 260)
    env[-r:] *= np.linspace(1, 0, r)
    if decay:
        env *= np.exp(-t * decay)
    if trem:
        env *= 1.0 - trem * (0.5 + 0.5 * np.sin(2 * np.pi * trem_hz * t))
    s._place(step * s.step, sig * env * vol)


def _echo(s, delay_steps, gain, taps=2):
    d = int(s.step * delay_steps)
    src = s.mix.copy()
    for k in range(1, taps + 1):
        sh = np.zeros_like(src)
        sh[d * k:] = src[:-d * k] if d * k < len(src) else 0
        # wrap the tail so the loop stays seamless
        sh[:d * k] += src[-d * k:] * 0.0
        s.mix += np.roll(src, d * k) * (gain ** k)


def biome_theme(name, cfg):
    """Generic regional loop: chord progression + scale-constrained melody
    (seeded, so it is reproducible), regional lead timbre, bass and drums."""
    s = Song(cfg['bpm'], cfg['bars'])
    s.rng = np.random.default_rng(cfg['seed'])
    rng = np.random.default_rng(cfg['seed'] + 1)
    scale = cfg['scale']                       # semitone offsets from tonic
    tonic = midi(cfg['tonic'])
    prog = cfg['prog']                         # list of (degree index, kind)
    rhythms = cfg['rhythms']                   # list of [(step, len)]
    motifs = []
    for k in range(4):                         # 4 motifs reused AABA-style
        rh = rhythms[k % len(rhythms)]
        deg = int(rng.integers(4, 8))
        mot = []
        for (st, ln) in rh:
            deg = int(np.clip(deg + rng.choice([-2, -1, -1, 0, 1, 1, 2]), 2, 11))
            mot.append((st, ln, deg))
        motifs.append(mot)
    form = cfg.get('form', [0, 1, 0, 2, 0, 1, 3, 2])
    def note(deg, octv=0):
        o, d = divmod(deg, len(scale))
        return tonic + 12 * (o + octv) + scale[d]
    for bar in range(cfg['bars']):
        base = bar * 16
        dg, kind = prog[bar % len(prog)]
        root = note(dg, -1)
        tones = chord_tones(root, kind)
        mot = motifs[form[bar % len(form)]]
        for st, ln, deg in mot:
            m = note(deg + dg % 2, 1)
            cfg['lead'](s, base + st, ln, m)
        cfg['comp'](s, base, tones, kind)
        cfg['bass'](s, base, root, kind)
        cfg['drums'](s, base, bar)
    if cfg.get('echo'):
        _echo(s, *cfg['echo'])
    m = s.mix / max(1e-9, np.abs(s.mix).max()) * 0.92
    rms = float(np.sqrt((m ** 2).mean()))
    s.write(os.path.join(OUT, 'music_level_%s.wav' % name), peak=min(0.92, 0.92 * 0.24 / max(rms, 1e-6)))


def boss7_theme():
    """'Star Shield Shuffle': a bright C-major space-pop march, 138 BPM,
    16 bars: a square lead over fast arpeggios with little laser zaps, a
    marching triangle bass, for the Reanald Rogan fight. Original."""
    s = Song(138, 16)
    s.rng = np.random.default_rng(2507)
    prog = [('C2', 'maj'), ('A1', 'min'), ('F1', 'maj'), ('G1', 'maj')] * 2 + \
           [('F1', 'maj'), ('G1', 'maj'), ('E1', 'min'), ('A1', 'min')] + [('F1', 'maj'), ('D2', 'min'), ('G1', 'sus'), ('G1', 'maj')]
    L = {
        0: [(0, 3, 'G5'), (3, 1, 'C6'), (4, 4, 'E6'), (8, 2, 'D6'), (10, 2, 'C6'), (12, 4, 'G5')],
        1: [(0, 4, 'A5'), (4, 2, 'C6'), (6, 2, 'E6'), (8, 8, 'D6')],
        2: [(0, 2, 'F5'), (2, 2, 'A5'), (4, 4, 'C6'), (8, 4, 'F6'), (12, 4, 'E6')],
        3: [(0, 4, 'D6'), (4, 2, 'B5'), (6, 2, 'G5'), (8, 6, 'D6'), (14, 2, 'G6')],
        4: [(0, 2, 'E6'), (2, 2, 'D6'), (4, 2, 'C6'), (6, 2, 'D6'), (8, 8, 'E6')],
    }
    order = [0, 1, 2, 3, 0, 1, 2, 3, 2, 3, 4, 1, 2, 4, 3, 3]
    for bar, ((rn, kind), li) in enumerate(zip(prog, order)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        for st, ln, nm in L[li]:
            s.tone(base + st, ln, midi(nm), 0.15, duty=0.5, vib=0.005 if ln >= 4 else 0.0)
        for i in range(16):                      # sparkly 16th arpeggio
            s.tone(base + i, 1, tones[i % 3] + 36, 0.035, duty=0.125, decay=16)
        for i in range(8):
            s.tone(base + i * 2, 2, root + 12 + (0 if i % 2 == 0 else 12), 0.34, wave_='tri')
        for i in range(16):
            if i in (0, 8):
                s.kick(base + i, 0.6)
            if i in (4, 12):
                s.snare(base + i, 0.3)
            if i % 2 == 1:
                s.hat(base + i, 0.07)
        if bar % 4 == 3:
            for k, i in enumerate((12, 13, 14, 15)):   # laser zaps
                s.tone(base + i, 1, midi('C7') - k * 5, 0.06, duty=0.25, decay=24)
    s.write(os.path.join(OUT, 'music_boss7.wav'))


def boss8_theme():
    """'Drone Hopak': a fast, cheeky D-minor folk dance, 164 BPM, 16 bars:
    a bandura-ish plucked lead, oom-pa bass, quick buzzing trills, for the
    Zelodymer Violentsky fight. Original."""
    s = Song(164, 16)
    s.rng = np.random.default_rng(2508)
    prog = [('D2', 'min'), ('D2', 'min'), ('A1', 'maj'), ('D2', 'min'),
            ('G1', 'min'), ('D2', 'min'), ('A1', 'maj'), ('D2', 'min')] * 2
    L = {
        0: [(0, 2, 'D6'), (2, 2, 'E6'), (4, 2, 'F6'), (6, 2, 'D6'), (8, 4, 'A5'), (12, 4, 'A5')],
        1: [(0, 2, 'F6'), (2, 2, 'E6'), (4, 2, 'D6'), (6, 2, 'C#6'), (8, 8, 'D6')],
        2: [(0, 2, 'E6'), (2, 2, 'C#6'), (4, 2, 'A5'), (6, 2, 'C#6'), (8, 4, 'E6'), (12, 4, 'A6')],
        3: [(0, 2, 'G6'), (2, 2, 'F6'), (4, 2, 'E6'), (6, 2, 'F6'), (8, 2, 'G6'), (10, 2, 'A6'), (12, 4, 'D6')],
    }
    order = [0, 1, 2, 1, 3, 1, 2, 1, 0, 3, 2, 1, 3, 3, 2, 1]
    for bar, ((rn, kind), li) in enumerate(zip(prog, order)):
        root = midi(rn)
        base = bar * 16
        tones = chord_tones(root, kind)
        for st, ln, nm in L[li]:
            m = midi(nm)
            s.tone(base + st, ln, m, 0.15, duty=0.25, decay=3.0 if ln <= 2 else 0.0)
            s.tone(base + st, 0.5, m + 12, 0.045, duty=0.125, decay=30)
        for i in (2, 6, 10, 14):                    # off-beat chord chops
            for t in tones:
                s.tone(base + i, 1, t + 24, 0.04, duty=0.5, decay=14)
        for i in range(4):
            s.tone(base + i * 4, 2, root + 12 + (0 if i % 2 == 0 else 7), 0.38, wave_='tri')
        for i in range(16):
            if i % 4 == 0:
                s.kick(base + i, 0.55)
            if i in (4, 12):
                s.snare(base + i, 0.3)
            if i % 2 == 1:
                s.hat(base + i, 0.08)
        if bar % 4 == 3:
            for i in range(12, 16):                  # buzzing trill
                s.tone(base + i, 0.5, midi('A6') + (i % 2), 0.05, duty=0.25)
    s.write(os.path.join(OUT, 'music_boss8.wav'))


def _drums_basic(kick, snare, hats, vol=1.0):
    def f(s, base, bar):
        for i in range(16):
            if i in kick:
                s.kick(base + i, 0.5 * vol)
            if i in snare:
                s.snare(base + i, 0.28 * vol)
            if i in hats:
                s.hat(base + i, 0.10 * vol)
        if bar % 4 == 3:
            for i in (13, 14, 15):
                s.snare(base + i, 0.18 * vol)
    return f


MAJ = [0, 2, 4, 5, 7, 9, 11]
MIXO = [0, 2, 4, 5, 7, 9, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
HIJAZ = [0, 1, 4, 5, 7, 8, 10]          # Phrygian dominant
AEOL = [0, 2, 3, 5, 7, 8, 10]
MAJPENT = [0, 2, 4, 7, 9]

BIOMES = {
    # fiddle-and-guitar prairie hoedown, D mixolydian-ish, 128 BPM
    'prairie': dict(bpm=128, bars=16, seed=2301, tonic='D4', scale=MIXO,
        prog=[(0, 'maj'), (3, 'maj'), (0, 'maj'), (4, 'maj')],
        rhythms=[[(0, 2), (2, 1), (3, 1), (4, 2), (6, 2), (8, 3), (11, 1), (12, 2), (14, 2)],
                 [(0, 1), (1, 1), (2, 2), (4, 4), (8, 2), (10, 2), (12, 4)]],
        lead=lambda s, st, ln, m: _tone_x(s, st, ln, m, 0.17, duty=0.25, bend=-1.0, vib=0.008),
        comp=lambda s, b, t, k: [s.tone(b + i, 1, t[(i // 2) % 3] + 12, 0.055, duty=0.5, decay=14) for i in range(0, 16, 2)],
        bass=lambda s, b, r, k: [s.tone(b + i * 4, 2, r + (0 if i % 2 == 0 else 7) - 12, 0.34, wave_='tri') for i in range(4)],
        drums=_drums_basic((0, 8), (4, 12), (2, 6, 10, 14))),
    # Mediterranean: hijaz scale, oud-like plucked lead, darbuka-ish pattern
    'med': dict(bpm=112, bars=16, seed=2302, tonic='E4', scale=HIJAZ,
        prog=[(0, 'maj'), (0, 'maj'), (1, 'maj'), (0, 'maj'), (6, 'min'), (5, 'maj'), (1, 'maj'), (0, 'maj')],
        rhythms=[[(0, 1), (1, 1), (2, 1), (3, 1), (4, 2), (6, 2), (8, 1), (9, 1), (10, 2), (12, 4)],
                 [(0, 3), (3, 1), (4, 1), (5, 1), (6, 2), (8, 4), (12, 2), (14, 2)]],
        lead=lambda s, st, ln, m: (_tone_x(s, st, ln, m, 0.16, duty=0.35, decay=5.0, bend=0.6),
                                   _tone_x(s, st, 0.5, m + 12, 0.05, duty=0.125, decay=30)),
        comp=lambda s, b, t, k: [_tone_x(s, b + i, 8, t[0] + 12, 0.035, wave_='tri') for i in (0, 8)],
        bass=lambda s, b, r, k: [s.tone(b + i, 1 if i % 4 else 2, r - 12 + (7 if i == 6 else 0), 0.32, wave_='tri') for i in (0, 3, 6, 8, 11, 14)],
        drums=_drums_basic((0, 6, 8), (4, 11, 12), (2, 3, 7, 10, 14, 15))),
    # Texas: twangy bent lead over a train-beat shuffle, A major pentatonic
    'texas': dict(bpm=120, bars=16, seed=2303, tonic='A3', scale=MAJPENT,
        prog=[(0, 'maj'), (0, 'maj'), (2, 'maj'), (0, 'maj'), (3, 'maj'), (2, 'maj'), (0, 'maj'), (3, 'maj')],
        rhythms=[[(0, 2), (3, 1), (4, 2), (6, 1), (7, 1), (8, 4), (12, 2), (14, 2)],
                 [(0, 1), (1, 1), (2, 2), (6, 2), (8, 2), (10, 1), (11, 1), (12, 4)]],
        lead=lambda s, st, ln, m: _tone_x(s, st, ln, m, 0.18, duty=0.18, bend=-2.0, decay=2.5),
        comp=lambda s, b, t, k: [s.tone(b + i, 1, t[1] + 12, 0.05, duty=0.25, decay=20) for i in (2, 6, 10, 14)],
        bass=lambda s, b, r, k: [s.tone(b + i * 4, 2, r - 12 + [0, 7, 12, 7][i], 0.34, wave_='tri') for i in range(4)],
        drums=_drums_basic((0, 8), (4, 12), tuple(range(1, 16, 2)) + (2, 6, 10, 14), 0.9)),
    # Bavaria: oompah waltz-feel polka, accordion tremolo chords, tuba bass
    'bavaria': dict(bpm=140, bars=16, seed=2304, tonic='F4', scale=MAJ,
        prog=[(0, 'maj'), (4, 'maj'), (4, 'maj'), (0, 'maj'), (3, 'maj'), (0, 'maj'), (4, 'maj'), (0, 'maj')],
        rhythms=[[(0, 2), (2, 2), (4, 2), (6, 2), (8, 4), (12, 4)],
                 [(0, 1), (1, 1), (2, 2), (4, 1), (5, 1), (6, 2), (8, 2), (10, 2), (12, 4)]],
        lead=lambda s, st, ln, m: _tone_x(s, st, ln, m, 0.15, duty=0.5, trem=0.35, trem_hz=6.0),
        comp=lambda s, b, t, k: [[_tone_x(s, b + i, 2, x + 12, 0.035, duty=0.5, trem=0.4, trem_hz=6.0) for x in t] for i in (4, 12)],
        bass=lambda s, b, r, k: [s.tone(b + i * 8, 3, r - 12 + (0 if i == 0 else 7), 0.40, wave_='tri') for i in range(2)],
        drums=_drums_basic((0, 8), (4, 12), (4, 12), 0.8)),
    # Pacific Northwest: moody, rainy D dorian, slow, echoing arpeggios
    'pnw': dict(bpm=96, bars=16, seed=2305, tonic='D4', scale=DORIAN,
        prog=[(0, 'min'), (0, 'min'), (5, 'maj'), (3, 'maj'), (0, 'min'), (6, 'maj'), (3, 'maj'), (4, 'min')],
        rhythms=[[(0, 6), (6, 2), (8, 6), (14, 2)], [(0, 4), (4, 4), (8, 8)]],
        lead=lambda s, st, ln, m: _tone_x(s, st, ln, m, 0.13, wave_='tri', vib=0.006),
        comp=lambda s, b, t, k: [s.tone(b + i, 2, t[i // 2 % 3] + 12 + (12 if i % 8 == 6 else 0), 0.06, duty=0.25, decay=6) for i in range(0, 16, 2)],
        bass=lambda s, b, r, k: s.tone(b, 16, r - 12, 0.30, wave_='tri'),
        drums=_drums_basic((0, 10), (8,), (2, 6, 10, 14), 0.6),
        echo=(3, 0.35, 2)),
    # Northern California: surf-folk, tremolo-picked lead + spring echo
    'norcal': dict(bpm=150, bars=16, seed=2306, tonic='E4', scale=MIXO,
        prog=[(0, 'maj'), (0, 'maj'), (3, 'maj'), (3, 'maj'), (4, 'maj'), (3, 'maj'), (0, 'maj'), (4, 'maj')],
        rhythms=[[(0, 2), (2, 2), (4, 4), (8, 2), (10, 2), (12, 4)],
                 [(0, 4), (4, 2), (6, 2), (8, 6), (14, 2)]],
        lead=lambda s, st, ln, m: _tone_x(s, st, ln, m, 0.15, duty=0.25, trem=0.7, trem_hz=14.0, bend=-0.5),
        comp=lambda s, b, t, k: [s.tone(b + i, 1, t[0] + 12, 0.05, duty=0.5, decay=18) for i in (2, 3, 6, 10, 11, 14)],
        bass=lambda s, b, r, k: [s.tone(b + i * 2, 2, r - 12 + [0, 0, 7, 0, 10, 0, 7, 12][i], 0.30, wave_='tri') for i in range(8)],
        drums=_drums_basic((0, 3, 8, 11), (4, 12), tuple(range(0, 16, 2))),
        echo=(1.5, 0.3, 1)),
    # build 025 Midwest: a heartland harvest tune, banjo-roll arpeggios, G major
    'midwest': dict(bpm=124, bars=16, seed=2307, tonic='G4', scale=MAJ,
        prog=[(0, 'maj'), (3, 'maj'), (0, 'maj'), (4, 'maj'), (0, 'maj'), (3, 'maj'), (4, 'maj'), (0, 'maj')],
        rhythms=[[(0, 2), (2, 2), (4, 3), (7, 1), (8, 2), (10, 2), (12, 4)],
                 [(0, 1), (1, 1), (2, 2), (4, 2), (6, 2), (8, 6), (14, 2)]],
        lead=lambda s, st, ln, m: _tone_x(s, st, ln, m, 0.16, duty=0.25, bend=-0.8, vib=0.006),
        comp=lambda s, b, t, k: [s.tone(b + i, 1, t[[0, 1, 2, 1][i % 4]] + 24, 0.045, duty=0.125, decay=22) for i in range(16)],
        bass=lambda s, b, r, k: [s.tone(b + i * 4, 2, r - 12 + (0 if i % 2 == 0 else 7), 0.34, wave_='tri') for i in range(4)],
        drums=_drums_basic((0, 8), (4, 12), (2, 6, 10, 14), 0.85)),
    # build 025 Ukraine: a plucked bandura-like folk melody, A "Ukrainian dorian"
    'ukraine': dict(bpm=108, bars=16, seed=2308, tonic='A4', scale=[0, 2, 3, 6, 7, 9, 10],
        prog=[(0, 'min'), (3, 'maj'), (0, 'min'), (4, 'maj'), (5, 'maj'), (3, 'maj'), (4, 'maj'), (0, 'min')],
        rhythms=[[(0, 2), (2, 1), (3, 1), (4, 2), (6, 2), (8, 4), (12, 2), (14, 2)],
                 [(0, 3), (3, 1), (4, 4), (8, 2), (10, 2), (12, 4)]],
        lead=lambda s, st, ln, m: (_tone_x(s, st, ln, m, 0.16, duty=0.35, decay=4.0, vib=0.004),
                                   _tone_x(s, st, 0.5, m + 12, 0.045, duty=0.125, decay=28)),
        comp=lambda s, b, t, k: [s.tone(b + i, 2, t[(i // 2) % 3] + 12, 0.05, duty=0.25, decay=8) for i in range(0, 16, 2)],
        bass=lambda s, b, r, k: [s.tone(b + i * 8, 4, r - 12 + (0 if i == 0 else 7), 0.32, wave_='tri') for i in range(2)],
        drums=_drums_basic((0, 8), (4, 12), (2, 6, 10, 14), 0.7),
        echo=(2, 0.25, 1)),
}


if __name__ == '__main__':
    import sys
    os.makedirs(OUT, exist_ok=True)
    tracks = {'level': level_theme, 'boss': boss_theme, 'bonus': bonus_theme, 'boss2': boss2_theme,
              'boss3': boss3_theme, 'boss4': boss4_theme, 'boss5': boss5_theme, 'boss6': boss6_theme,
              'boss7': boss7_theme, 'boss8': boss8_theme}
    for _b in BIOMES:   # build 023: 'level_prairie' ... 'level_norcal'
        tracks['level_' + _b] = (lambda b=_b: biome_theme(b, BIOMES[b]))
    for name in (sys.argv[1:] or list(tracks)):
        tracks[name]()
