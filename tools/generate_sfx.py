"""Synthesises original sound effects for the game (no samples, no copyrighted audio).

Run:  python3 tools/generate_sfx.py
Output: assets/sfx/*.ogg  (upload in Studio: Asset Manager > Bulk Import, then paste
        the IDs into Config.UploadedSounds in src/shared/Config.lua)
"""
import os

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(3)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.005, decay=0.3, curve=4.0):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4) * curve / 4)
    return a * d


def noise(dur):
    return rng.normal(0, 1, int(SR * dur))


def bandpass(x, lo, hi, order=4):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, f, order=4):
    return signal.sosfilt(signal.butter(order, f, btype="low", fs=SR, output="sos"), x)


def highpass(x, f, order=4):
    return signal.sosfilt(signal.butter(order, f, btype="high", fs=SR, output="sos"), x)


def sweep_band(x, f0, f1, width=0.6, steps=48):
    """Band-pass whose centre frequency glides from f0 to f1 (for whooshes)."""
    out = np.zeros_like(x)
    n = len(x)
    win = n // steps + 1
    for i in range(steps):
        s, e = i * win, min(n, (i + 1) * win + win)
        f = f0 * (f1 / f0) ** (i / max(1, steps - 1))
        lo, hi = f * (1 - width / 2), min(f * (1 + width / 2), SR / 2 - 100)
        seg = bandpass(x[max(0, s - win):e], lo, hi, 2)[-(e - s):]
        w = np.hanning(len(seg))
        out[s:e] += seg * w
    return out


def ring(freqs, dur, decay):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for i, f in enumerate(freqs):
        out += np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t / (decay * (1 - i * 0.12))) / (1 + i * 0.4)
    return out


def reverb(x, size=0.35, mix=0.22):
    n = int(SR * size)
    ir = rng.normal(0, 1, n) * np.exp(-np.linspace(0, 6, n))
    ir = lowpass(ir, 6000)
    dry = np.concatenate([x, np.zeros(n)])
    wet = signal.fftconvolve(x, ir)[: len(dry)]
    wet = np.concatenate([wet, np.zeros(len(dry) - len(wet))])
    wet /= np.max(np.abs(wet)) + 1e-9
    return dry * (1 - mix) + wet * mix * np.max(np.abs(x))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def pad(x, start):
    return np.concatenate([np.zeros(int(SR * start)), x])


def finish(x, gain=0.9, fade=0.02):
    x = x - np.mean(x)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * gain
    f = int(SR * fade)
    if f and len(x) > f:
        x[-f:] *= np.linspace(1, 0, f)
    return x.astype(np.float32)


# ---------------------------------------------------------------------------
# Sounds
# ---------------------------------------------------------------------------

def whoosh(dur=0.32, f0=500, f1=2600, gain=1.0):
    x = sweep_band(noise(dur), f0, f1, 0.7)
    t = t_axis(dur)
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.6
    return x * shape * gain


def metal_scrape(dur, f0, f1):
    x = sweep_band(noise(dur), f0, f1, 0.25)
    return x * env(dur, 0.002, dur * 0.7)


def snikt():
    """Three blades sliding out of bone: scrape + bright steel ring."""
    parts = []
    for k in range(3):
        s = metal_scrape(0.09, 2600 + k * 500, 7200 + k * 400) * (1 - k * 0.12)
        parts.append(pad(s, k * 0.018))
    click = pad(highpass(noise(0.01), 3000) * env(0.01, 0.0005, 0.004), 0.075)
    steel = pad(ring([1870, 3130, 4410, 6020, 7650], 0.9, 0.28) * 0.55, 0.07)
    return finish(reverb(mix(*parts, click * 1.6, steel), 0.5, 0.18))


def slash():
    """Claw whoosh with a wet cutting tail."""
    w = whoosh(0.26, 700, 3800, 1.0)
    cut = pad(bandpass(noise(0.12), 1800, 6000) * env(0.12, 0.001, 0.05), 0.14)
    wet = pad(lowpass(noise(0.2), 900) * env(0.2, 0.004, 0.08) * 0.8, 0.15)
    return finish(reverb(mix(w, cut * 0.9, wet), 0.3, 0.15))


def stab():
    """Blades punching in: steel transient, crunch, squelch, low thump."""
    steel = ring([2200, 3700, 5200], 0.35, 0.09) * 0.5
    crunch = mix(*[pad(bandpass(noise(0.03), 800, 4000) * env(0.03, 0.0005, 0.01), rng.uniform(0, 0.06)) for _ in range(8)])
    squelch = pad(lowpass(noise(0.35), 700) * env(0.35, 0.01, 0.14), 0.02)
    t = t_axis(0.3)
    thump = np.sin(2 * np.pi * (70 - 30 * t) * t) * env(0.3, 0.002, 0.1)
    return finish(reverb(mix(steel, crunch, squelch * 1.1, thump * 1.2), 0.35, 0.15))


def impact():
    t = t_axis(0.45)
    thump = np.sin(2 * np.pi * (62 - 28 * t / 0.45) * t) * env(0.45, 0.002, 0.16)
    click = highpass(noise(0.02), 2000) * env(0.02, 0.0005, 0.006)
    body = lowpass(noise(0.3), 1400) * env(0.3, 0.002, 0.07)
    return finish(reverb(mix(thump * 1.4, click * 0.8, body * 0.9), 0.4, 0.18))


def leap():
    w = whoosh(0.5, 250, 1800, 1.0)
    t = t_axis(0.5)
    rumble = lowpass(noise(0.5), 180) * np.sin(np.pi * t / 0.5)
    return finish(reverb(mix(w, rumble * 1.5), 0.3, 0.12))


def land():
    t = t_axis(0.6)
    thud = np.sin(2 * np.pi * (48 - 18 * t / 0.6) * t) * env(0.6, 0.002, 0.2)
    debris = mix(*[pad(bandpass(noise(0.04), 600, 5000) * env(0.04, 0.0005, 0.015) * rng.uniform(0.2, 0.7), rng.uniform(0.02, 0.4)) for _ in range(24)])
    return finish(reverb(mix(thud * 1.5, debris), 0.5, 0.2))


def growl(dur, f_base, f_peak, rough=0.9):
    """Formant-filtered roughened pulse wave: a beast's voice."""
    t = t_axis(dur)
    contour = f_base + (f_peak - f_base) * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.7
    jitter = lowpass(rng.normal(0, 1, len(t)), 40) * 6
    f = contour + jitter + np.sin(2 * np.pi * 5.5 * t) * 3
    phase = 2 * np.pi * np.cumsum(f) / SR
    src = signal.sawtooth(phase) + 0.5 * signal.sawtooth(phase * 0.5)
    rasp = 1 + rough * lowpass(rng.normal(0, 1, len(t)), 70) * 0.6
    src = src * rasp
    breath = highpass(noise(dur), 900) * 0.35
    voice = src + breath
    formants = [(650, 1.0), (1150, 0.6), (2500, 0.28), (3400, 0.15)]
    out = sum(bandpass(voice, f0 * 0.82, f0 * 1.18, 2) * g for f0, g in formants)
    out += lowpass(voice, 300) * 0.9
    out = np.tanh(out * 2.2)
    shape = env(dur, 0.12, dur * 0.8) * np.clip(np.sin(np.pi * np.clip(t / dur, 0, 1)) * 1.6, 0, 1)
    return out * shape


def roar():
    main = growl(2.0, 85, 140)
    sub = growl(2.0, 42, 70, 0.5) * 0.7
    top = growl(2.0, 170, 260, 1.2) * 0.25
    return finish(reverb(mix(main, sub, top), 0.9, 0.3), 0.95)


def snarl():
    x = growl(0.8, 95, 150, 1.3)
    return finish(reverb(x, 0.4, 0.2))


def tear():
    """Ripping apart: accelerating crackle + wet squelch + bone snap."""
    dur = 0.9
    x = np.zeros(int(SR * dur))
    tt = 0.0
    while tt < 0.7:
        g = bandpass(noise(0.012), 400, 5000) * env(0.012, 0.0003, 0.004)
        start = int(tt * SR)
        x[start:start + len(g)] += g[: len(x) - start] * rng.uniform(0.3, 1)
        tt += rng.uniform(0.002, 0.02) * (1 - tt)
    squelch = lowpass(noise(dur), 800) * env(dur, 0.05, 0.4)
    snap = pad(mix(ring([900, 1700, 2600], 0.2, 0.03), highpass(noise(0.02), 1500) * env(0.02, 0.0005, 0.005)), 0.55)
    return finish(reverb(mix(x * 1.2, squelch * 0.8, snap * 1.3), 0.4, 0.18))


def gore():
    splat = lowpass(noise(0.4), 1200) * env(0.4, 0.002, 0.1)
    drops = mix(*[pad(bandpass(noise(0.02), 300, 1500) * env(0.02, 0.001, 0.008) * 0.5, rng.uniform(0.08, 0.35)) for _ in range(10)])
    return finish(reverb(mix(splat, drops), 0.3, 0.15))


def wall_break():
    t = t_axis(0.8)
    boom = np.sin(2 * np.pi * (55 - 20 * t / 0.8) * t) * env(0.8, 0.002, 0.22)
    chunks = mix(*[pad(bandpass(noise(0.05), rng.uniform(300, 900), rng.uniform(2000, 6000)) * env(0.05, 0.0005, 0.02) * rng.uniform(0.3, 1), rng.uniform(0, 0.5)) for _ in range(40)])
    crack = highpass(noise(0.06), 1500) * env(0.06, 0.0005, 0.02)
    return finish(reverb(mix(boom * 1.3, chunks, crack * 1.2), 0.6, 0.25))


def heartbeat():
    def beat(f=48):
        t = t_axis(0.18)
        return np.sin(2 * np.pi * f * t) * env(0.18, 0.004, 0.07) + lowpass(noise(0.18), 120) * env(0.18, 0.004, 0.05) * 0.5
    x = mix(beat(52), pad(beat(44) * 0.8, 0.22))
    x = np.concatenate([x, np.zeros(int(SR * 1.0) - len(x))])
    return finish(x, 0.9, 0.0)


def fart():
    dur = 0.85
    t = t_axis(dur)
    f = 85 + 25 * np.sin(2 * np.pi * 3 * t) + lowpass(rng.normal(0, 1, len(t)), 30) * 25
    phase = 2 * np.pi * np.cumsum(f) / SR
    buzz = signal.square(phase, duty=0.3) * (1 + 0.6 * lowpass(rng.normal(0, 1, len(t)), 60))
    x = lowpass(buzz, 700) + lowpass(noise(dur), 400) * 0.4
    shape = env(dur, 0.02, 0.6) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t) ** 2)
    return finish(reverb(x * shape, 0.25, 0.1))


def sniff():
    def inhale(d):
        x = bandpass(noise(d), 1500, 7000)
        tt = t_axis(d)
        return x * np.sin(np.pi * tt / d) ** 2
    return finish(reverb(mix(inhale(0.18), pad(inhale(0.14), 0.24), pad(inhale(0.3) * 1.2, 0.45)), 0.3, 0.1))


def laser():
    dur = 0.7
    t = t_axis(dur)
    f = 2400 * np.exp(-t * 5) + 180
    zap = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * env(dur, 0.002, 0.35)
    buzz = signal.square(2 * np.pi * 110 * t) * env(dur, 0.01, 0.5) * 0.3
    crackle = highpass(noise(dur), 3000) * (rng.random(len(t)) > 0.97) * env(dur, 0.001, 0.3)
    return finish(reverb(mix(lowpass(zap, 6000), buzz, crackle), 0.5, 0.25))


def punch():
    clang = ring([310, 730, 1180, 1690], 0.8, 0.22)
    t = t_axis(0.4)
    thump = np.sin(2 * np.pi * (70 - 30 * t / 0.4) * t) * env(0.4, 0.001, 0.12)
    return finish(reverb(mix(clang * 0.8, thump * 1.4, highpass(noise(0.02), 2000) * env(0.02, 0.0005, 0.006)), 0.5, 0.2))


def terminal():
    t = t_axis(0.35)
    a = np.sin(2 * np.pi * 880 * t) * env(0.35, 0.003, 0.12)
    b = pad(np.sin(2 * np.pi * 1320 * t) * env(0.35, 0.003, 0.15), 0.1)
    return finish(reverb(mix(a, b), 0.3, 0.2), 0.7)


def ui_hover():
    return finish(whoosh(0.13, 2200, 7000, 1.0), 0.6)


def ui_click():
    s = metal_scrape(0.05, 4000, 9000)
    r = ring([3100, 5200, 7400], 0.18, 0.05) * 0.5
    return finish(mix(s, pad(r, 0.02)), 0.6)


SOUNDS = {
    "Snikt": snikt, "Slash": slash, "Whoosh": lambda: finish(reverb(whoosh(0.3, 400, 2400), 0.25, 0.12)),
    "Stab": stab, "Impact": impact, "Leap": leap, "Land": land, "Roar": roar, "Snarl": snarl,
    "Tear": tear, "Gore": gore, "Break": wall_break, "Heartbeat": heartbeat, "Fart": fart,
    "Sniff": sniff, "Laser": laser, "Punch": punch, "Terminal": terminal,
    "UIHover": ui_hover, "UIClick": ui_click,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = fn()
        path = os.path.join(OUT, name + ".ogg")
        sf.write(path, x, SR, format="OGG", subtype="VORBIS")
        print(f"wrote {path}  ({len(x) / SR:.2f}s)")


if __name__ == "__main__":
    main()
