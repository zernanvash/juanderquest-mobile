"""Plan 84 sample: synthesize the app's sound effects.

Original work (no samples, no third-party audio). Owner 2026-11-13: "foresty
vibes, jazzy chords ... mystical 8-bit, not arcade video games". So: soft
triangle/sine plucks (kalimba-like), wooden knocks, water drops, bird chirps,
jazz voicings (maj9, m9, 13, 6/9) and a short echo. No harsh square leads.
Usage: python make_sfx.py <out_dir>   -> <out_dir>/sfx/*.wav
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 22050
rng = np.random.default_rng(84)


def note(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    acc = 1 if "#" in name else (-1 if "b" in name[1:] else 0)
    semis = names[name[0]] + acc + 12 * (int(name[-1]) + 1)
    return 440.0 * 2 ** ((semis - 69) / 12)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def sine(f0, dur, f1=None):
    n = int(SR * dur)
    f = np.linspace(f0, f1 if f1 else f0, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def tri(f0, dur):
    ph = f0 * t_axis(dur)
    return 4 * np.abs(ph - np.floor(ph) - 0.5) - 1


def lowpass(x, cutoff):
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def fade(x, attack=0.003, release=0.006):
    n = len(x)
    a, r = min(n, int(SR * attack)), min(n, int(SR * release))
    x = x.copy()
    x[:a] *= np.linspace(0, 1, a)
    x[-r:] *= np.linspace(1, 0, r)
    return x


def pluck(name_or_f, dur=0.5, vol=0.5, decay=7.0, bright=0.25):
    """Kalimba-like: triangle body + a quieter octave and twelfth that die faster."""
    f = note(name_or_f) if isinstance(name_or_f, str) else name_or_f
    t = t_axis(dur)
    x = tri(f, dur) * np.exp(-decay * t)
    x += bright * sine(2 * f, dur) * np.exp(-decay * 2.2 * t)
    x += bright * 0.5 * sine(3 * f, dur) * np.exp(-decay * 3.5 * t)
    return fade(x) * vol


def bell(name, dur=0.7, vol=0.4, decay=5.0):
    """Soft glassy bell: sine with an inharmonic partial."""
    f = note(name)
    t = t_axis(dur)
    x = sine(f, dur) * np.exp(-decay * t) + 0.3 * sine(f * 2.76, dur) * np.exp(-decay * 2.5 * t)
    return fade(x) * vol


def wood(f=520, vol=0.6, dur=0.06):
    """Wooden knock: a fast pitch drop plus a tiny filtered click."""
    t = t_axis(dur)
    body = sine(f, dur, f * 0.55) * np.exp(-70 * t)
    click = lowpass(rng.uniform(-1, 1, len(t)), 2500) * np.exp(-220 * t)
    return fade(body + 0.5 * click, attack=0.001) * vol


def rustle(dur=0.14, vol=0.35, cutoff=2200):
    """Leaves: filtered noise with a soft swell."""
    t = t_axis(dur)
    x = lowpass(rng.uniform(-1, 1, len(t)), cutoff)
    return fade(x * np.sin(np.pi * t / dur) ** 2, 0.01, 0.02) * vol * 2.5


def drop(f0=700, f1=1500, dur=0.07, vol=0.5):
    """Water drop: quick upward sine."""
    t = t_axis(dur)
    return fade(sine(f0, dur, f1) * np.exp(-28 * t)) * vol


def chirp(f0=2600, f1=3600, dur=0.045, vol=0.28):
    """Small bird chirp."""
    t = t_axis(dur)
    return fade(sine(f0, dur, f1) * np.sin(np.pi * t / dur)) * vol


def rest(dur):
    return np.zeros(int(SR * dur))


def seq(*parts):
    return np.concatenate(parts)


def mix(*parts):
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, t):
    return seq(rest(t), x)


def echo(x, delay=0.13, feedback=0.32, repeats=3):
    """A short forest echo."""
    d = int(SR * delay)
    out = np.zeros(len(x) + d * repeats)
    for k in range(repeats + 1):
        out[k * d : k * d + len(x)] += x * feedback**k
    return out


def strum(names, gap=0.022, dur=0.9, vol=0.26, decay=4.0):
    return mix(*[at(pluck(n, dur, vol, decay), i * gap) for i, n in enumerate(names)])


def run(names, each=0.075, dur=0.45, vol=0.34, decay=7.0):
    return mix(*[at(pluck(n, dur, vol, decay), i * each) for i, n in enumerate(names)])


CMAJ9 = ["C4", "E4", "G4", "B4", "D5"]
DM9 = ["D4", "F4", "A4", "C5", "E5"]
G13 = ["G3", "F4", "B4", "E5"]
C69 = ["C4", "E4", "A4", "D5", "G5"]
FMAJ7 = ["F4", "A4", "C5", "E5"]
AM9 = ["A4", "C5", "E5", "G5", "B5"]

SFX = {
    # UI: wood, water and single soft plucks
    "tap": wood(540, 0.55),
    "back": seq(wood(430, 0.5), rest(0.015), wood(330, 0.45)),
    "toggle_on": mix(pluck("D5", 0.2, 0.4, 14), at(pluck("A5", 0.3, 0.4, 11), 0.06)),
    "toggle_off": mix(pluck("A5", 0.2, 0.4, 14), at(pluck("D5", 0.3, 0.4, 11), 0.06)),
    "tab": echo(pluck("G5", 0.18, 0.36, 16), 0.09, 0.25, 2),
    "sheet_open": mix(rustle(0.16, 0.3), at(pluck("E5", 0.25, 0.28, 12), 0.07)),
    "error": mix(pluck("E3", 0.3, 0.5, 10, 0.1), at(pluck("F3", 0.38, 0.5, 9, 0.1), 0.11)),
    # Rewards: jazz voicings, kalimba and bells
    "coin": echo(mix(pluck("E6", 0.3, 0.34, 10), at(pluck("B6", 0.4, 0.3, 9), 0.055)), 0.11, 0.3, 2),
    "stamp": mix(wood(240, 0.75, 0.09), at(bell("G5", 0.5, 0.26, 7), 0.03)),
    "unlock": echo(mix(run(DM9, 0.07), at(bell("A5", 0.8, 0.3, 4), 0.36)), 0.14, 0.3, 2),
    "quest_complete": echo(mix(run(FMAJ7, 0.085, 0.5), at(strum(CMAJ9, 0.028, 1.2), 0.4),
                               at(bell("D6", 1.0, 0.2, 3.5), 0.52)), 0.16, 0.28, 2),
    "level_up": echo(mix(strum(DM9, 0.02, 0.5, 0.24, 6), at(strum(G13, 0.02, 0.5, 0.26, 6), 0.3),
                         at(strum(C69, 0.03, 1.3, 0.26, 3.2), 0.6), at(bell("G6", 1.0, 0.16, 3.5), 0.78)), 0.17, 0.28, 2),
    # Navigation: clear bells that cut through road noise without being sharp
    "go": mix(pluck("G4", 0.3, 0.4, 9), at(pluck("D5", 0.4, 0.4, 8), 0.08), at(strum(["G4", "A4", "D5"], 0.02, 0.6, 0.2), 0.16)),
    "turn_chime": echo(seq(bell("E5", 0.2, 0.5, 6), bell("G5", 0.5, 0.5, 4.5)), 0.15, 0.25, 2),
    "reroute": echo(seq(bell("A5", 0.13, 0.42, 9), bell("F5", 0.13, 0.42, 9), bell("D5", 0.4, 0.42, 5)), 0.14, 0.25, 2),
    "checkin": echo(mix(run(AM9, 0.07), at(bell("E6", 0.8, 0.26, 4), 0.36)), 0.14, 0.3, 2),
    "trail_complete": echo(mix(run(DM9, 0.09, 0.5), at(strum(G13, 0.025, 0.6, 0.27, 5), 0.5),
                               at(strum(C69, 0.035, 1.5, 0.27, 2.8), 0.86), at(run(["E6", "G6", "D7"], 0.11, 0.9, 0.16, 4), 1.05)),
                           0.18, 0.3, 2),
    # AR games: woodblocks, whooshes, small arpeggios
    "ar_hit": mix(wood(700, 0.6, 0.05), at(pluck("A5", 0.22, 0.34, 14), 0.01)),
    "ar_miss": rustle(0.22, 0.3, 1200),
    "ar_countdown": wood(820, 0.55, 0.05),
    "ar_win": echo(run(["C5", "E5", "G5", "B5", "D6"], 0.065, 0.5, 0.32, 6), 0.13, 0.28, 2),
    "ar_lose": run(["D5", "C5", "Ab4", "F4"], 0.14, 0.5, 0.32, 6),
    # Map & plaza: water drop and birds
    "pin_select": echo(drop(), 0.08, 0.22, 2),
    "cheer": seq(chirp(2500, 3300), rest(0.03), chirp(2800, 3700), rest(0.03), chirp(3000, 4200, 0.07)),
}


def write(path, x):
    x = np.tanh(x * 1.15)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setframerate(SR)
        w.setsampwidth(2)
        w.writeframes((x * 32000).astype("<i2").tobytes())


if __name__ == "__main__":
    out = Path(sys.argv[1]) / "sfx"
    out.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, x in SFX.items():
        p = out / f"{name}.wav"
        write(p, x)
        total += p.stat().st_size
        print(f"{name:16s} {len(x) / SR:5.2f}s {p.stat().st_size / 1024:6.1f} KB  peak {np.abs(x).max():.2f}")
    print(f"total {total / 1024:.0f} KB, {len(SFX)} effects")
