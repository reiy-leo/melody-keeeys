#!/usr/bin/env python3
"""Synthesize stylized placeholder keyboard sound packs.

Generates 10 packs x 6 layers (alpha/space/enter/modifier/nav/release) of
48 kHz mono 16-bit WAV files under assets/sounds/. These are development
placeholders - replace with CC0 recordings or real captures before release.

Usage: python3 tool/make_placeholder_sounds.py [--out assets/sounds]
"""

import argparse
import math
import wave
from pathlib import Path

import numpy as np

SR = 48000


def _t(dur):
    return np.arange(int(SR * dur)) / SR


def _env(n, attack, decay, hold=0.0):
    """Linear attack, optional hold, exponential decay to silence."""
    a = max(1, int(SR * attack))
    env = np.exp(-_t(n / SR - hold) / max(decay, 1e-4))
    env[: min(a, n)] *= np.linspace(0.0, 1.0, min(a, n))
    return env


def _biquad_bandpass(x, center, q):
    """RBJ cookbook constant-skirt bandpass."""
    w0 = 2 * math.pi * min(center, SR / 2 - 100) / SR
    alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = math.cos(w0), 0.0, -math.cos(w0)
    a0, a1, a2 = 1.0 + alpha, -2 * math.cos(w0), 1.0 - alpha
    # normalize with gain 1 (constant skirt: divide by sqrt(a0*a0) keeps amplitude)
    b0, b1, b2 = b0 / a0 * math.sqrt(a0), 0.0, b2 / a0 * math.sqrt(a0)
    a1, a2 = a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, xi in enumerate(x):
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[i] = yi
        x2, x1 = x1, xi
        y2, y1 = y1, yi
    return y


def _lowpass(x, cutoff):
    """One-pole lowpass."""
    dt = 1.0 / SR
    rc = 1.0 / (2 * math.pi * min(cutoff, SR / 2 - 100))
    alpha = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    for i, xi in enumerate(x):
        acc += alpha * (xi - acc)
        y[i] = acc
    return y


def _highpass(x, cutoff):
    return x - _lowpass(x, cutoff)


def _sine(dur, freq, freq_end=None, phase=0.0):
    t = _t(dur)
    if freq_end is None:
        return np.sin(2 * math.pi * freq * t + phase)
    f = np.geomspace(freq, max(freq_end, 1.0), len(t))
    return np.sin(2 * math.pi * np.cumsum(f) / SR + phase)


def _noise_burst(dur, lp, hp, attack, decay, gain=1.0, q=0.9, bp=None):
    rng = np.random.default_rng(len(str(dur)) + int(lp) + int(hp))
    x = rng.uniform(-1, 1, int(SR * dur))
    if bp is not None:
        x = _biquad_bandpass(x, bp, q)
    if hp:
        x = _highpass(x, hp)
    if lp:
        x = _lowpass(x, lp)
    return x * _env(len(x), attack, decay) * gain


def _tone(dur, freq, freq_end, decay, attack, gain=1.0):
    x = _sine(dur, freq, freq_end)
    return x * _env(len(x), attack, decay) * gain


def synth_pack(p):
    """Build the 6 layer samples for one pack. Returns {layer: float array}."""
    d = p["dur"]
    out = {}

    def base(layer):
        g = p.get("layer_gain", {}).get(layer, 1.0)
        click_f = p["click_f"] * p.get("layer_pitch", {}).get(layer, 1.0)
        body_f = p["body_f"] * p.get("layer_pitch", {}).get(layer, 1.0)
        decay = p["decay"] * p.get("layer_decay", {}).get(layer, 1.0)
        return click_f, body_f, decay, g

    for layer in ("alpha", "space", "enter", "modifier", "nav"):
        click_f, body_f, decay, gain = base(layer)
        n = int(SR * d)
        parts = []

        # click transient: short bandpassed noise
        parts.append(_noise_burst(
            min(0.02, d), p["noise_lp"], p["noise_hp"], p["attack"],
            p["click_decay"], p["click_gain"], bp=click_f, q=p["click_q"]))
        # tonal body with optional pitch sweep
        parts.append(_tone(d, body_f, body_f * p.get("body_sweep", 0.85),
                           decay, p["attack"] * 2, p["body_gain"]))
        # mid crack for definition
        parts.append(_noise_burst(d, p["noise_lp"], 400, p["attack"] * 2,
                                  decay * 0.6, p["crack_gain"]))
        # extra ringing partial (metallic packs)
        if p.get("ring"):
            parts.append(_tone(d, click_f * 1.5, None, decay * 1.4,
                               p["attack"] * 3, p["body_gain"] * 0.4))

        x = np.zeros(n)
        for part in parts:
            x[: len(part)] += part[:n]
        out[layer] = x * gain

    # release: quiet, short, slightly higher pitched tap
    rp = p["layer_pitch"].get("release", 1.2)
    rel_parts = [
        _noise_burst(0.012, p["noise_lp"] * 0.8, p["noise_hp"] * 1.2, 0.0002,
                     0.006, p["click_gain"] * 0.5, bp=click_f_default(p) * rp, q=1.2),
        _tone(0.03, p["body_f"] * rp, None, 0.012, 0.0004, p["body_gain"] * 0.5),
    ]
    n_rel = max(len(x) for x in rel_parts)
    rel = np.zeros(n_rel)
    for part in rel_parts:
        rel[: len(part)] += part
    out["release"] = rel * p.get("layer_gain", {}).get("release", 0.35)
    return out


def click_f_default(p):
    return p["click_f"]


PACKS = [
    dict(id="cherry_mx_blue", name="Cherry MX Blue", dur=0.10,
         click_f=3200, click_q=1.4, click_decay=0.006, click_gain=1.0,
         body_f=900, body_gain=0.5, noise_lp=9000, noise_hp=900,
         attack=0.0002, decay=0.022, crack_gain=0.7, ring=False,
         layer_pitch={"space": 0.7, "enter": 0.75, "modifier": 1.15, "nav": 1.05, "release": 1.25},
         layer_gain={"space": 1.15, "enter": 1.2, "modifier": 0.7, "nav": 0.85, "release": 0.35}),
    dict(id="gateron_oil_king", name="Gateron Oil King", dur=0.18,
         click_f=1200, click_q=1.0, click_decay=0.005, click_gain=0.55,
         body_f=110, body_gain=1.0, noise_lp=4000, noise_hp=300,
         attack=0.0006, decay=0.085, crack_gain=0.45, ring=False, body_sweep=0.6,
         layer_pitch={"space": 0.75, "enter": 0.8, "modifier": 1.2, "nav": 1.1, "release": 1.35},
         layer_gain={"space": 1.25, "enter": 1.3, "modifier": 0.6, "nav": 0.85, "release": 0.3}),
    dict(id="holy_panda", name="Holy Panda", dur=0.14,
         click_f=1800, click_q=1.2, click_decay=0.006, click_gain=0.85,
         body_f=220, body_gain=0.85, noise_lp=6000, noise_hp=500,
         attack=0.0003, decay=0.045, crack_gain=0.6, ring=False, body_sweep=0.7,
         layer_pitch={"space": 0.7, "enter": 0.75, "modifier": 1.2, "nav": 1.05, "release": 1.3},
         layer_gain={"space": 1.2, "enter": 1.25, "modifier": 0.65, "nav": 0.85, "release": 0.35}),
    dict(id="ibm_model_m", name="IBM Model M", dur=0.20,
         click_f=2600, click_q=2.2, click_decay=0.005, click_gain=0.9,
         body_f=400, body_gain=0.55, noise_lp=10000, noise_hp=800,
         attack=0.0002, decay=0.035, crack_gain=0.7, ring=True,
         layer_pitch={"space": 0.7, "enter": 0.7, "modifier": 1.2, "nav": 1.1, "release": 1.35},
         layer_gain={"space": 1.2, "enter": 1.3, "modifier": 0.7, "nav": 0.9, "release": 0.35}),
    dict(id="kailh_box_white", name="Kailh Box White", dur=0.09,
         click_f=4800, click_q=2.5, click_decay=0.004, click_gain=1.0,
         body_f=700, body_gain=0.4, noise_lp=12000, noise_hp=1500,
         attack=0.0002, decay=0.014, crack_gain=0.55, ring=False,
         layer_pitch={"space": 0.75, "enter": 0.8, "modifier": 1.15, "nav": 1.05, "release": 1.25},
         layer_gain={"space": 1.1, "enter": 1.15, "modifier": 0.7, "nav": 0.85, "release": 0.35}),
    dict(id="topre_electrostatic", name="Topre Electrostatic", dur=0.16,
         click_f=900, click_q=0.9, click_decay=0.008, click_gain=0.6,
         body_f=180, body_gain=0.9, noise_lp=3500, noise_hp=250,
         attack=0.001, decay=0.06, crack_gain=0.4, ring=False, body_sweep=0.75,
         layer_pitch={"space": 0.75, "enter": 0.8, "modifier": 1.25, "nav": 1.1, "release": 1.35},
         layer_gain={"space": 1.25, "enter": 1.3, "modifier": 0.65, "nav": 0.85, "release": 0.3}),
    dict(id="bubble_pop", name="Bubble Pop", dur=0.12,
         click_f=1500, click_q=1.5, click_decay=0.004, click_gain=0.7,
         body_f=420, body_gain=0.8, noise_lp=8000, noise_hp=600,
         attack=0.0003, decay=0.035, crack_gain=0.4, ring=False, body_sweep=2.2,
         layer_pitch={"space": 0.7, "enter": 0.75, "modifier": 1.25, "nav": 1.1, "release": 1.4},
         layer_gain={"space": 1.2, "enter": 1.2, "modifier": 0.65, "nav": 0.85, "release": 0.35}),
    dict(id="scifi_laser", name="Sci-Fi Laser", dur=0.16,
         click_f=1400, click_q=3.0, click_decay=0.004, click_gain=0.8,
         body_f=1400, body_gain=0.7, noise_lp=12000, noise_hp=700,
         attack=0.0003, decay=0.06, crack_gain=0.3, ring=True, body_sweep=0.18,
         layer_pitch={"space": 0.7, "enter": 0.75, "modifier": 1.3, "nav": 1.15, "release": 1.5},
         layer_gain={"space": 1.15, "enter": 1.2, "modifier": 0.7, "nav": 0.9, "release": 0.35}),
    dict(id="typewriter_1930s", name="Typewriter 1930s", dur=0.22,
         click_f=2400, click_q=1.8, click_decay=0.005, click_gain=0.95,
         body_f=300, body_gain=0.7, noise_lp=11000, noise_hp=700,
         attack=0.0002, decay=0.03, crack_gain=0.75, ring=True,
         layer_pitch={"space": 0.7, "enter": 0.65, "modifier": 1.15, "nav": 1.05, "release": 1.3},
         layer_gain={"space": 1.2, "enter": 1.35, "modifier": 0.7, "nav": 0.9, "release": 0.35}),
    dict(id="silent_red", name="Silent Red", dur=0.08,
         click_f=2000, click_q=0.8, click_decay=0.004, click_gain=0.35,
         body_f=150, body_gain=0.55, noise_lp=2200, noise_hp=200,
         attack=0.0006, decay=0.012, crack_gain=0.25, ring=False,
         layer_pitch={"space": 0.8, "enter": 0.8, "modifier": 1.2, "nav": 1.1, "release": 1.3},
         layer_gain={"space": 1.15, "enter": 1.2, "modifier": 0.7, "nav": 0.85, "release": 0.3}),
]


def write_wav(path, data):
    peak = np.max(np.abs(data)) or 1.0
    data = data / peak * 0.72
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/sounds")
    args = ap.parse_args()
    out = Path(args.out)
    for p in PACKS:
        samples = synth_pack(p)
        pack_dir = out / p["id"]
        pack_dir.mkdir(parents=True, exist_ok=True)
        for layer, data in samples.items():
            write_wav(pack_dir / f"{layer}.wav", data)
        print(f"  {p['id']:<22} 6 layers -> {pack_dir}")
    print(f"Done: {len(PACKS)} packs x 6 layers @ {SR} Hz mono 16-bit")


if __name__ == "__main__":
    main()
