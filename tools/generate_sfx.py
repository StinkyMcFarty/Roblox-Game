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
    """A real one: flappy sphincter buzz (pulse train through a fleshy
    resonance) that bends up then sags, breathy rasp, and a wet sputter tail."""
    dur = 1.35
    n = int(SR * dur)
    t = np.arange(n) / SR
    # pitch contour: quick rise, wobbling sustain, sagging end
    f = 72 + 38 * np.sin(np.pi * np.clip(t / 0.9, 0, 1)) ** 0.6
    f += lowpass(rng.normal(0, 1, n), 12) * 14  # wobble
    f += 6 * np.sin(2 * np.pi * 7.5 * t)
    f *= np.where(t > 0.95, 1 - (t - 0.95) * 0.6, 1)
    ph = np.cumsum(f) / SR
    frac = ph % 1
    cyc = np.floor(ph)
    # each cycle: a sharp flap open then a soft close
    flap = np.where(frac < 0.18, np.sin(np.pi * frac / 0.18), -0.35 * np.sin(np.pi * (frac - 0.18) / 0.82))
    # irregular flap strength + sputter gaps near the end
    strength = 0.7 + 0.5 * lowpass(rng.normal(0, 1, n), 25)
    sputter = np.ones(n)
    tail = t > 0.95
    gaps = rng.random(int(cyc.max()) + 2) < 0.45
    sputter[tail] = np.where(gaps[cyc[tail].astype(int)], 0.08, 1.0)
    src = flap * strength * sputter
    # fleshy resonances + a little brassy edge
    body = resonator(src, 180, 90) * 0.7 + resonator(src, 420, 160) * 1.1 + resonator(src, 900, 300) * 0.6
    body += lowpass(src, 1400) * 0.3
    # breathy air rushing through, gated by the flaps
    air = bandpass(noise(dur), 250, 2200) * (0.3 + 0.7 * np.clip(flap, 0, 1)) * 0.35
    x = body / (np.max(np.abs(body)) + 1e-9) + air
    amp = np.clip(t / 0.03, 0, 1) * np.where(t > 1.2, np.clip((1.35 - t) / 0.15, 0, 1), 1)
    x = np.tanh(x * 1.6) * amp
    return finish(reverb(highpass(x, 45, 2), 0.2, 0.08), 0.85, 0.05)


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


STEP_SLOT = 0.5    # seconds per take in the multi-take footstep files
HEAVY_SLOT = 0.8


def takes(fn, count, slot):
    """Several distinct takes laid end to end so the game can pick a random one
    (Sound.PlaybackRegion) and consecutive steps never sound identical."""
    out = np.zeros(int(SR * slot * count))
    n = int(SR * slot)
    for k in range(count):
        x = fn(k)[:n]
        x = x - np.mean(x)
        f = int(SR * 0.03)
        x[-f:] *= np.linspace(1, 0, f)
        x = x / (np.max(np.abs(x)) + 1e-9) * (0.9 + 0.1 * rng.uniform())
        out[k * n: k * n + len(x)] += x
    return finish(out, 0.9, 0)


def step_take(k):
    """Hard-soled shoe on facility tile: heel click with a short body thump, the
    toe rolling down ~50ms later, a little grit under the sole, tight room."""
    heel_f = rng.uniform(95, 130)
    t = t_axis(0.12)
    body = np.sin(2 * np.pi * heel_f * t * (1 - 0.8 * t)) * env(0.12, 0.001, 0.035)
    click = bandpass(noise(0.03), rng.uniform(1600, 2200), rng.uniform(5200, 7000)) * env(0.03, 0.0003, 0.008)
    tick = ring([rng.uniform(2300, 2900), rng.uniform(4100, 4800)], 0.04, 0.006) * 0.35
    heel = mix(body * 0.9, click * 1.1, tick)
    toe_at = rng.uniform(0.04, 0.06)
    toe = mix(bandpass(noise(0.02), 1200, 4500) * env(0.02, 0.0005, 0.006) * 0.45,
              np.sin(2 * np.pi * heel_f * 1.4 * t_axis(0.05)) * env(0.05, 0.001, 0.015) * 0.3)
    grit = mix(*[pad(highpass(noise(0.004), 5000) * env(0.004, 0.0002, 0.001) * rng.uniform(0.1, 0.25),
                     rng.uniform(0.005, 0.09)) for _ in range(5)])
    scuff = pad(bandpass(noise(0.07), 2500, 8000) * env(0.07, 0.01, 0.03) * 0.12, 0.02)
    x = mix(heel, pad(toe, toe_at), grit, scuff)
    return reverb(x, 0.28, 0.14)


def step_metal_take(k):
    """Boot on a steel grate / catwalk: bright clank with inharmonic ring, a
    hollow low bong from the span and a loose-panel rattle."""
    t = t_axis(0.4)
    partials = [rng.uniform(360, 420), rng.uniform(880, 960), rng.uniform(1580, 1700), rng.uniform(2650, 2900), rng.uniform(4100, 4500)]
    clank = ring(partials, 0.4, rng.uniform(0.06, 0.09)) * env(0.4, 0.0005, 0.25)
    hit = bandpass(noise(0.025), 1500, 7000) * env(0.025, 0.0002, 0.006)
    bong = np.sin(2 * np.pi * rng.uniform(150, 190) * t) * np.exp(-t / 0.07) * 0.5
    rattle = mix(*[pad(bandpass(noise(0.008), 2500, 6000) * env(0.008, 0.0003, 0.002) * 0.3,
                       0.03 + j * rng.uniform(0.018, 0.028)) for j in range(3)])
    toe = pad(ring([p * 1.03 for p in partials[1:4]], 0.15, 0.03) * 0.25, rng.uniform(0.05, 0.07))
    x = mix(clank * 0.55, hit, bong, rattle, toe)
    return reverb(x, 0.45, 0.2)


def step_heavy_take(k):
    """Sentinel footfall: a servo whine as the leg drives down, a huge metal
    stomp with a sub boom and floor crunch, then the hydraulics venting."""
    at = 0.1
    t = t_axis(at + 0.02)
    whine_f = 700 + 900 * (t / (at + 0.02)) ** 2
    whine = np.sin(2 * np.pi * np.cumsum(whine_f) / SR) * np.linspace(0, 1, len(t)) ** 2 * 0.12
    tb = t_axis(0.5)
    f0 = rng.uniform(52, 60)
    boom = np.sin(2 * np.pi * f0 * tb * (1 - 0.35 * tb)) * np.exp(-tb / 0.12)
    clank = ring([rng.uniform(210, 240), rng.uniform(540, 590), rng.uniform(1080, 1180), rng.uniform(1800, 1950), 3100], 0.5, 0.12) * env(0.5, 0.0005, 0.3)
    crunch = lowpass(noise(0.12), 2500) * env(0.12, 0.0005, 0.03)
    grit = mix(*[pad(bandpass(noise(0.006), 2000, 7000) * env(0.006, 0.0002, 0.0015) * rng.uniform(0.15, 0.35),
                     rng.uniform(0.01, 0.12)) for _ in range(7)])
    hiss = pad(bandpass(noise(0.35), 3000, 9000) * env(0.35, 0.04, 0.2) * 0.12, 0.14)
    impact = mix(boom * 1.2, clank * 0.5, crunch * 0.6, grit, hiss)
    x = mix(whine, pad(impact, at))
    return reverb(x, 0.6, 0.18)


def step():
    return takes(step_take, 4, STEP_SLOT)


def step_metal():
    return takes(step_metal_take, 4, STEP_SLOT)


def step_heavy():
    return takes(step_heavy_take, 3, HEAVY_SLOT)


def pounce_hit():
    """Pounce strike: two claw sets punch in (crisp double 'shk-shk') over a tight thump."""
    parts = []
    for k, t0 in enumerate((0.0, 0.045)):
        cut = sweep_band(noise(0.08), 8500, 3500, 0.5, 12) * env(0.08, 0.001, 0.025, 6)
        tick = highpass(noise(0.01), 5000) * env(0.01, 0.0003, 0.003)
        parts.append(pad(mix(cut * (1 - k * 0.2), tick * 0.6), t0))
    t = t_axis(0.3)
    thump = np.sin(2 * np.pi * (110 - 260 * np.minimum(t, 0.3)) * t) * env(0.3, 0.001, 0.06)
    parts.append(pad(thump * 1.4, 0.04))
    shimmer = ring([3600, 5400, 7900], 0.35, 0.06) * 0.25
    parts.append(pad(shimmer, 0.05))
    x = np.tanh(mix(*parts) * 1.3)
    return finish(reverb(highpass(x, 60, 2), 0.25, 0.1), 0.72, 0.04)


def impale():
    """Impale: steel pierces in (short rising scrape), bright ring, heavy low hit."""
    scrape = sweep_band(noise(0.11), 2500, 7000, 0.35, 16) * env(0.11, 0.004, 0.06, 5)
    t = t_axis(0.45)
    hit = np.sin(2 * np.pi * (80 - 140 * np.minimum(t, 0.45)) * t) * env(0.45, 0.001, 0.1)
    steel = ring([2400, 3900, 5600, 8200], 0.6, 0.12) * 0.35
    tick = highpass(noise(0.012), 4000) * env(0.012, 0.0003, 0.004)
    body = lowpass(noise(0.12), 900) * env(0.12, 0.002, 0.03) * 0.5
    x = mix(scrape * 0.9, pad(tick, 0.09), pad(hit * 1.5, 0.095), pad(steel, 0.095), pad(body, 0.1))
    x = np.tanh(x * 1.2)
    return finish(reverb(highpass(x, 50, 2), 0.3, 0.12), 0.72, 0.05)


def death_ray():
    """Charge whine (0.35s) into a screaming, distorted beam blast (~0.9s) with crackle."""
    ch = 0.35
    t = t_axis(ch)
    f = 180 * (12 ** (t / ch))  # rising whine
    whine = np.sin(2 * np.pi * np.cumsum(f) / SR + 3 * np.sin(2 * np.pi * 37 * t)) * (t / ch) ** 1.5
    whine += bandpass(noise(ch), 2000, 8000) * (t / ch) ** 3 * 0.4
    bd = 1.0
    tb = t_axis(bd)
    envb = np.minimum(1, tb / 0.01) * np.exp(-np.maximum(tb - 0.55, 0) / 0.18)
    saw = signal.sawtooth(2 * np.pi * 55 * tb) + 0.6 * signal.sawtooth(2 * np.pi * 110.7 * tb)
    scream = np.sin(2 * np.pi * np.cumsum(1400 + 500 * np.sin(2 * np.pi * 11 * tb)) / SR)
    ringmod = scream * np.sin(2 * np.pi * 317 * tb)
    crackle = highpass(noise(bd), 3000) * (rng.random(len(tb)) < 0.02) * 6
    hiss = bandpass(noise(bd), 1500, 9000) * 0.5
    trem = 1 + 0.25 * np.sin(2 * np.pi * 42 * tb)
    blast = (saw * 0.8 + ringmod * 0.6 + scream * 0.3 + hiss + lowpass(crackle, 9000) * 0.5) * trem
    blast = np.tanh(blast * 2.2) * envb
    tt = t_axis(0.6)
    boom = np.sin(2 * np.pi * (70 - 40 * np.minimum(tt / 0.4, 1)) * tt) * env(0.6, 0.002, 0.25) * 1.2
    x = mix(whine * 0.6, pad(blast, ch), pad(boom, ch))
    return finish(reverb(highpass(x, 35, 2), 0.5, 0.18), 0.9, 0.1)


def chase():
    """8-bar chase loop at 150 BPM: pounding low drums, pulsing bass ostinato,
    dissonant string stabs and metal hits. Loops seamlessly."""
    bpm = 150
    beat = 60 / bpm
    bars = 4
    dur = beat * 4 * bars
    n = int(SR * dur)
    out = np.zeros(n)
    def put(x, at):
        i = int(at * SR) % n
        seg = x[: n - i]
        out[i:i + len(seg)] += seg
        if len(x) > len(seg):
            out[: len(x) - len(seg)] += x[len(seg):]
    kick_t = t_axis(0.35)
    kick = np.sin(2 * np.pi * (48 + 90 * np.exp(-kick_t * 30)) * kick_t) * env(0.35, 0.001, 0.18) * 1.2
    tom_t = t_axis(0.3)
    tom = np.sin(2 * np.pi * (95 + 60 * np.exp(-tom_t * 20)) * tom_t) * env(0.3, 0.001, 0.12)
    hit = mix(ring([1310, 2210, 3470], 0.5, 0.1) * 0.5, highpass(noise(0.05), 2000) * env(0.05, 0.001, 0.01))
    for b in range(bars * 4):
        at = b * beat
        put(kick, at)
        if b % 2 == 1:
            put(tom * 0.7, at + beat * 0.5)
            put(tom * 0.5, at + beat * 0.75)
        if b % 8 == 7:
            put(hit * 0.8, at + beat * 0.5)
    # 8th-note bass ostinato (E minor-ish with a b2 for dread)
    notes = [41.2, 41.2, 43.65, 41.2, 41.2, 49.0, 46.25, 43.65]
    bt = t_axis(beat / 2)
    for i in range(bars * 8):
        f0 = notes[i % 8]
        tone = (signal.sawtooth(2 * np.pi * f0 * bt) + 0.5 * signal.square(2 * np.pi * f0 * 2 * bt)) * env(beat / 2, 0.004, beat * 0.3)
        put(lowpass(tone, 600) * 0.45, i * beat / 2)
    # string stabs: dissonant cluster on bar starts
    st_t = t_axis(beat * 1.5)
    for bar in range(bars):
        cluster = sum(signal.sawtooth(2 * np.pi * f * st_t) for f in (329.6, 349.2, 493.9)) / 3
        stab = bandpass(cluster, 300, 3500) * env(beat * 1.5, 0.01, beat * 0.7) * 0.35
        put(stab, bar * beat * 4)
    x = np.tanh(out * 0.9)
    return finish(reverb(x, 0.35, 0.12)[:n], 0.85, 0.0)


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
    "UIHover": ui_hover, "UIClick": ui_click, "Paw": paw, "PounceHit": pounce_hit, "Impale": impale, "DeathRay": death_ray, "Chase": chase,
    "Step": step, "StepMetal": step_metal, "StepHeavy": step_heavy,
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
