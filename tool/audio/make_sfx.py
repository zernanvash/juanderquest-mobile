"""Plan 84 sample: synthesize 8-bit sound effects and one chiptune loop.

Original work (no samples, no third-party audio): square / triangle / noise
oscillators with pitch slides and decay envelopes, in the style of sfxr.
Usage: python make_sfx.py <out_dir>   -> <out_dir>/sfx/*.wav, <out_dir>/music/*.wav
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 22050
rng = np.random.default_rng(84)


def note(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semis = names[name[0]] + (1 if "#" in name else 0) + 12 * (int(name[-1]) + 1)
    return 440.0 * 2 ** ((semis - 69) / 12)


def osc(kind, f0, dur, f1=None, duty=0.5):
    n = int(SR * dur)
    f = np.linspace(f0, f1 if f1 else f0, n)
    ph = np.cumsum(f) / SR
    fr = ph - np.floor(ph)
    if kind == "sq":
        return np.where(fr < duty, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(fr - 0.5) - 1
    if kind == "noise":
        step = max(1, int(SR / max(f0, 1)))
        return np.repeat(rng.uniform(-1, 1, n // step + 1), step)[:n]
    raise ValueError(kind)


def env(x, attack=0.002, decay=6.0, hold=0.0):
    n = len(x)
    t = np.arange(n) / SR
    e = np.minimum(1, t / attack) * np.exp(-decay * np.maximum(0, t - hold))
    tail = min(n, int(SR * 0.004))
    e[-tail:] *= np.linspace(1, 0, tail)
    return x * e


def tone(kind, f0, dur, f1=None, vol=0.5, decay=6.0, duty=0.5, hold=0.0):
    return env(osc(kind, f0, dur, f1, duty), decay=decay, hold=hold) * vol


def seq(*parts):
    return np.concatenate(parts)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def rest(dur):
    return np.zeros(int(SR * dur))


def at(x, t):
    return seq(rest(t), x)


def arp(notes, each, kind="sq", vol=0.4, decay=10.0, duty=0.25):
    return seq(*[tone(kind, note(n), each, vol=vol, decay=decay, duty=duty) for n in notes])


SFX = {
    # UI
    "tap": tone("sq", 740, 0.045, 620, vol=0.35, decay=45, duty=0.25),
    "back": tone("sq", 440, 0.08, 300, vol=0.35, decay=28, duty=0.25),
    "toggle_on": arp(["E5", "A5"], 0.05, vol=0.35, decay=30),
    "toggle_off": arp(["A5", "E5"], 0.05, vol=0.35, decay=30),
    "tab": tone("tri", 880, 0.05, vol=0.5, decay=40),
    "sheet_open": tone("tri", 300, 0.11, 620, vol=0.45, decay=14),
    "error": seq(tone("sq", 196, 0.09, 185, vol=0.4, decay=8), rest(0.03), tone("sq", 175, 0.14, 160, vol=0.4, decay=8)),
    # Rewards
    "coin": seq(tone("sq", note("B5"), 0.06, vol=0.38, decay=10), tone("sq", note("E6"), 0.32, vol=0.38, decay=9)),
    "stamp": mix(tone("noise", 900, 0.09, vol=0.6, decay=30), tone("sq", 160, 0.14, 70, vol=0.55, decay=18)),
    "unlock": mix(arp(["C5", "E5", "G5", "C6", "E6", "G6"], 0.045, kind="tri", vol=0.5, decay=14),
                  at(tone("sq", note("C7"), 0.35, vol=0.18, decay=7, duty=0.125), 0.27)),
    "quest_complete": mix(
        seq(arp(["C5", "E5", "G5"], 0.11, vol=0.36, decay=7), tone("sq", note("C6"), 0.7, vol=0.36, decay=3.5, duty=0.25)),
        seq(arp(["C4", "G4", "C4"], 0.11, kind="tri", vol=0.45, decay=6), tone("tri", note("C4"), 0.7, vol=0.45, decay=3.5)),
        at(tone("sq", note("E6"), 0.6, vol=0.18, decay=4, duty=0.25), 0.33)),
    "level_up": mix(
        seq(arp(["C5", "E5", "G5", "C6", "E6", "G6"], 0.07, vol=0.34, decay=9),
            tone("sq", note("C7"), 0.8, vol=0.3, decay=3, duty=0.25)),
        at(mix(tone("tri", note("C5"), 0.8, vol=0.4, decay=3), tone("tri", note("G5"), 0.8, vol=0.3, decay=3)), 0.42)),
    # Navigation
    "go": arp(["G4", "C5", "E5", "G5"], 0.055, vol=0.36, decay=14),
    "turn_chime": seq(tone("tri", note("E5"), 0.16, vol=0.55, decay=7), tone("tri", note("A5"), 0.3, vol=0.55, decay=6)),
    "reroute": seq(tone("tri", note("A5"), 0.1, vol=0.5, decay=10), tone("tri", note("F5"), 0.1, vol=0.5, decay=10),
                   tone("tri", note("D5"), 0.2, vol=0.5, decay=8)),
    "checkin": mix(arp(["G5", "B5", "D6"], 0.08, vol=0.36, decay=9),
                   at(tone("tri", note("G6"), 0.45, vol=0.4, decay=5), 0.24)),
    "trail_complete": mix(
        seq(arp(["G4", "C5", "E5", "G5", "E5", "G5"], 0.1, vol=0.34, decay=7),
            tone("sq", note("C6"), 0.9, vol=0.34, decay=2.8, duty=0.25)),
        seq(arp(["C3", "C3", "G3", "G3", "A3", "B3"], 0.1, kind="tri", vol=0.5, decay=6),
            tone("tri", note("C4"), 0.9, vol=0.5, decay=2.8))),
    # AR games
    "ar_hit": mix(tone("noise", 2500, 0.07, vol=0.45, decay=35), tone("sq", 620, 0.12, 200, vol=0.4, decay=16, duty=0.25)),
    "ar_miss": tone("sq", 300, 0.2, 140, vol=0.3, decay=8),
    "ar_countdown": tone("sq", 880, 0.1, vol=0.35, decay=12, duty=0.25),
    "ar_win": arp(["C5", "E5", "G5", "C6", "G5", "C6"], 0.08, vol=0.36, decay=7),
    "ar_lose": arp(["G4", "E4", "D4", "C4"], 0.13, vol=0.34, decay=6, duty=0.5),
    # Social / map
    "cheer": seq(tone("sq", 600, 0.05, 900, vol=0.32, decay=14, duty=0.25), rest(0.02),
                 tone("sq", 700, 0.05, 1050, vol=0.32, decay=14, duty=0.25), rest(0.02),
                 tone("sq", 800, 0.09, 1300, vol=0.32, decay=10, duty=0.25)),
    "pin_select": tone("tri", 660, 0.06, 880, vol=0.5, decay=22),
}


def explore_loop(bpm=104):
    """8 bars, C major: C - Am - F - G twice. Lead square, triangle bass, noise hat."""
    beat = 60.0 / bpm
    e = beat / 2
    lead = [
        "E5 G5 C6 G5 E5 G5 A5 G5", "E5 A5 C6 A5 E5 A5 G5 E5",
        "F5 A5 C6 A5 F5 A5 G5 F5", "D5 G5 B5 G5 D5 G5 A5 B5",
        "C6 G5 E5 G5 C6 D6 E6 D6", "C6 A5 E5 A5 C6 A5 G5 E5",
        "F5 A5 C6 F6 E6 C6 A5 F5", "G5 B5 D6 B5 G5 D5 G5 -",
    ]
    bass = ["C3", "A2", "F2", "G2", "C3", "A2", "F2", "G2"]
    total = int(SR * beat * 4 * 8)
    out = np.zeros(total + SR)
    for bar, line in enumerate(lead):
        for i, nm in enumerate(line.split()):
            if nm == "-":
                continue
            s = int(SR * (bar * 4 * beat + i * e))
            x = tone("sq", note(nm), e * 0.95, vol=0.2, decay=5, duty=0.25)
            out[s : s + len(x)] += x
        for q in range(4):
            s = int(SR * (bar * 4 * beat + q * beat))
            f = note(bass[bar]) * (1 if q % 2 == 0 else 1.5)
            x = tone("tri", f, beat * 0.9, vol=0.42, decay=3)
            out[s : s + len(x)] += x
        for h in range(8):
            s = int(SR * (bar * 4 * beat + h * e))
            x = tone("noise", 6000 if h % 2 else 3000, 0.03, vol=0.1 if h % 2 else 0.16, decay=60)
            out[s : s + len(x)] += x
    out[: SR] += out[total : total + SR]  # wrap the tail so the loop has no click
    return out[:total]


def write(path, x, bits=16):
    x = np.tanh(x * 1.1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setframerate(SR)
        if bits == 16:
            w.setsampwidth(2)
            w.writeframes((x * 32000).astype("<i2").tobytes())
        else:
            w.setsampwidth(1)
            w.writeframes((x * 120 + 128).astype("u1").tobytes())


if __name__ == "__main__":
    out = Path(sys.argv[1])
    (out / "sfx").mkdir(parents=True, exist_ok=True)
    (out / "music").mkdir(parents=True, exist_ok=True)
    total = 0
    for name, x in SFX.items():
        p = out / "sfx" / f"{name}.wav"
        write(p, x)
        total += p.stat().st_size
        print(f"{name:16s} {len(x) / SR:5.2f}s {p.stat().st_size / 1024:6.1f} KB")
    p = out / "music" / "explore_loop.wav"
    m = explore_loop()
    write(p, m, bits=8)
    total += p.stat().st_size
    print(f"{'explore_loop':16s} {len(m) / SR:5.2f}s {p.stat().st_size / 1024:6.1f} KB")
    print(f"total {total / 1024:.0f} KB, {len(SFX)} effects")
