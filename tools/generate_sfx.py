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
    """Clean modern claw slice: a tight air-cut 'shk', three quick blade edges and a
    bright steel shimmer. Short, crisp envelopes (no long airy whoosh = no 'wind')."""
    dur = 0.55
    parts = []
    # air cut: high band that zips downward, very fast attack, ~45 ms body
    cut = sweep_band(noise(0.16), 9500, 3200, 0.5, 24) * env(0.16, 0.0015, 0.045, 5)
    parts.append(cut * 1.3)
    # three blade edges, 9 ms apart (three claws), each a crisp high click + short hiss
    for k in range(3):
        edge = highpass(noise(0.05), 4500) * env(0.05, 0.0004, 0.012, 6)
        parts.append(pad(edge * (0.9 - k * 0.2), 0.008 + k * 0.009))
    # steel shimmer: inharmonic partials with a slight downward glide, fast decay
    t = t_axis(dur)
    shimmer = np.zeros_like(t)
    for i, f in enumerate([3150, 4720, 6380, 8210, 10400]):
        glide = f * (1 - 0.035 * np.minimum(t / 0.2, 1))
        shimmer += np.sin(2 * np.pi * np.cumsum(glide) / SR + i) * np.exp(-t / (0.075 - i * 0.009)) / (1 + i * 0.5)
    parts.append(pad(shimmer * 0.3, 0.01))
    # a touch of low weight so it doesn't feel thin (not a boom)
    tt = t_axis(0.08)
    parts.append(np.sin(2 * np.pi * (160 - 700 * tt) * tt) * env(0.08, 0.001, 0.025) * 0.35)
    x = mix(*parts)
    x = highpass(x, 120, 2)
    x = np.tanh(x * 1.4)
    return finish(reverb(x, 0.22, 0.1), 0.7, 0.05)


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


def resonator(x, f, bw):
    """Two-pole formant resonance at f Hz with bandwidth bw Hz."""
    r = np.exp(-np.pi * bw / SR)
    th = 2 * np.pi * f / SR
    return signal.lfilter([1 - r], [1, -2 * r * np.cos(th), r * r], x)


def voice(dur, contour, rough=1.0, vowels=None, seed_shift=0.0):
    """Glottal-pulse beast voice: jittered pitch, period-doubling rasp, formant vowel
    morph, aspiration noise and asymmetric overdrive (a throat being torn open)."""
    t = t_axis(dur)
    n = len(t)
    f = contour(t) * (1 + lowpass(rng.normal(0, 1, n), 25) * 0.035)  # jitter
    f += np.sin(2 * np.pi * (6.2 + seed_shift) * t) * f * 0.02  # tremble
    ph = np.cumsum(f) / SR
    frac = ph % 1.0
    # LF-ish glottal pulse: sharp closure each period
    pulse = np.where(frac < 0.6, np.sin(np.pi * frac / 0.6) ** 2, -1.8 * np.sin(np.pi * (frac - 0.6) / 0.4) ** 3)
    # period doubling / subharmonic rasp: alternate cycles get louder/quieter
    cyc = np.floor(ph)
    sub = 1 + rough * 0.55 * np.where(cyc % 2 == 0, 1, -1) * (0.6 + 0.4 * lowpass(rng.normal(0, 1, n), 8))
    shimmer = 1 + rough * 0.35 * lowpass(rng.normal(0, 1, n), 60)
    src = pulse * sub * shimmer
    # pre-emphasis: a torn, bright throat instead of a muffled hum
    src = signal.lfilter([1, -0.97], [1], src)
    src = signal.lfilter([1, -0.9], [1], src)
    src /= np.max(np.abs(src)) + 1e-9
    asp = highpass(noise(dur), 900) * (0.03 + 0.03 * rough)
    src = src + asp
    vowels = vowels or [(0.0, (600, 1050, 2400, 3300)), (0.25, (820, 1250, 2550, 3500)), (1.0, (650, 1000, 2450, 3300))]
    # morph formants over time by crossfading three filtered versions
    out = np.zeros(n)
    u = t / dur
    for i, (pos, fs) in enumerate(vowels):
        nxt = vowels[i + 1][0] if i + 1 < len(vowels) else 2
        prv = vowels[i - 1][0] if i > 0 else -1
        w = np.clip(np.minimum((u - prv) / max(pos - prv, 1e-3), (nxt - u) / max(nxt - pos, 1e-3)), 0, 1)
        y = sum(resonator(src, f0, bw) * g for f0, bw, g in zip(fs, (120, 140, 190, 260), (1.0, 0.9, 0.55, 0.35)))
        out += y * w
    out += lowpass(src, 300) * 0.15  # chest
    out = out / (np.max(np.abs(out)) + 1e-9)
    # presence: the ragged 1-4 kHz edge of a screaming throat
    out = out + bandpass(out, 1000, 2600, 2) * 4.0 + bandpass(out, 2600, 4500, 2) * 6.0
    out = out / (np.max(np.abs(out)) + 1e-9)
    out = np.tanh(out * 2.4 + 0.2) - np.tanh(0.2)  # asymmetric overdrive
    return out


def growl(dur, f_base, f_peak, rough=0.9):
    contour = lambda t: f_base + (f_peak - f_base) * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.7
    shape = env(dur, 0.1, dur * 0.8) * np.clip(np.sin(np.pi * np.clip(t_axis(dur) / dur, 0, 1)) * 1.6, 0, 1)
    return voice(dur, contour, rough) * shape


def roar():
    """Logan's berserker roar: a sharp inhale snarl, then a huge raw yell that
    climbs, cracks into rasp and sags, stacked with an octave-down beast layer,
    a cinematic sub hit and a big concrete-lab reverb."""
    dur = 2.6
    t = t_axis(dur)

    def contour(tt):
        rise = 118 + 72 * (1 - np.exp(-tt / 0.18))  # snaps up to ~190 Hz
        sag = np.clip((tt - 0.9) / 1.6, 0, 1) ** 1.3 * 70
        return rise - sag

    # amplitude: slam in, sustain with strain swells, long ragged tail
    amp = np.clip(t / 0.06, 0, 1) * (1 - np.clip((t - 1.3) / 1.3, 0, 1) ** 1.6)
    amp *= 1 + 0.15 * np.sin(2 * np.pi * 2.3 * t) * (t > 0.3)
    layers = []
    for k, (det, rough, g) in enumerate([(1.0, 1.1, 1.0), (1.012, 1.3, 0.7), (0.988, 0.9, 0.7)]):
        layers.append(voice(dur, lambda tt, d=det: contour(tt) * d, rough, seed_shift=k * 0.7) * g)
    beast = voice(dur, lambda tt: contour(tt) * 0.5, 1.6,
                  vowels=[(0.0, (420, 820, 2100, 3000)), (1.0, (380, 760, 2000, 2900))], seed_shift=2) * 0.8
    scream = highpass(voice(dur, lambda tt: contour(tt) * 2.0, 1.4, seed_shift=3), 1800) * 0.25
    body = mix(*layers, beast, scream)
    # post-EQ: tame boom, push the torn 1-4 kHz yell forward
    body = highpass(body, 90, 2) - lowpass(body, 220, 2) * 0.45
    body = body + bandpass(body, 900, 2200, 2) * 3.5 + bandpass(body, 2200, 4800, 2) * 5.0
    body = body / (np.max(np.abs(body)) + 1e-9) * amp

    # short snarling inhale before the roar
    inh_d = 0.32
    inhale = bandpass(noise(inh_d), 900, 5200) * np.linspace(0.2, 1, int(SR * inh_d)) ** 2
    inhale *= 1 + 0.6 * np.sin(2 * np.pi * 38 * t_axis(inh_d))
    # cinematic hit on the roar onset
    ht = t_axis(1.2)
    hit = np.sin(2 * np.pi * (58 - 26 * np.minimum(ht / 0.6, 1)) * ht) * env(1.2, 0.003, 0.5) * 0.9
    x = mix(inhale * 0.35, pad(body, inh_d), pad(hit, inh_d))
    x = highpass(x, 35, 2)
    x = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 1.8)
    return finish(reverb(reverb(x, 1.6, 0.28), 0.35, 0.15), 0.95, 0.3)


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


def paw():
    """All-fours footfall: padded thump, a scuff of grit and a claw tick on the floor."""
    t = t_axis(0.25)
    thump = np.sin(2 * np.pi * (95 - 180 * np.minimum(t, 0.25)) * t) * env(0.25, 0.002, 0.05)
    pad_ = lowpass(noise(0.12), 700) * env(0.12, 0.001, 0.03)
    scuff = pad(bandpass(noise(0.09), 1500, 5000) * env(0.09, 0.004, 0.035) * 0.35, 0.012)
    clicks = mix(*[pad(highpass(noise(0.006), 4500) * env(0.006, 0.0003, 0.0015) * 0.5, 0.004 + k * 0.011) for k in range(3)])
    return finish(reverb(mix(thump * 1.3, pad_ * 0.8, scuff, clicks), 0.18, 0.08), 0.85)


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
    "UIHover": ui_hover, "UIClick": ui_click, "Paw": paw,
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
