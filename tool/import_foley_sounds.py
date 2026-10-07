#!/usr/bin/env python3
"""Build five foley effect packs from Freesound CC0 recordings.

Sources (all Creative Commons 0 / public domain - see CREDITS.md):
  * sandpaper   - ids 204948, 496287, 726831 (rubbing takes)
  * chalk       - id 378400  (chalk writing on a blackboard)
  * ipad tap    - id 531501, 631822 (touch-screen tap foley)
  * plastic bag - id 405014  (bag handling/crinkle)
  * straw sip   - id 699625  (straw drink sip)

The downloaded files are multi-second continuous recordings; this script
cuts short one-shot windows out of them (a different offset per layer, so
repeated keystrokes don't sound identical) and fades the edges.

Usage:
  python3 tool/import_foley_sounds.py --src /tmp/newfx
"""

import argparse
import math
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

SR = 48000
FADE_IN = 0.002
FADE_OUT = 0.030
TARGET_RMS = 2500.0
PEAK_CEILING = 32000  # int: keeps normalize() output integral for struct.pack

# pack -> source file stem (as downloaded)
PACK_SOURCES = {
    "sandpaper": "sandpaper_c",
    "chalk": "chalk",
    "ipad_tap": "tablet_a",
    "plastic_bag": "bag",
    "straw_sip": "straw",
}

# layer -> (duration seconds, offset fraction into the usable region)
LAYER_CUTS = {
    "alpha":    (0.18, 0.10),
    "space":    (0.22, 0.34),
    "enter":    (0.22, 0.50),
    "modifier": (0.14, 0.66),
    "nav":      (0.16, 0.80),
    "release":  (0.09, 0.24),
}

# Absolute start seconds per layer, picked from loudness/centroid analysis of
# each source (best windows for the effect's character; tap anchors sit on
# detected transient onsets). Overrides the fraction spread above.
ANCHOR_STARTS = {
    # rubbing segments with the highest noise content (6-11s & 47s are best)
    "sandpaper": {"alpha": 6.2, "space": 8.0, "enter": 9.5,
                  "modifier": 10.5, "nav": 17.0, "release": 7.0},
    # quiet, rumble-heavy recording; after the 500 Hz high-pass the scritchy
    # writing lands at 9-14s (these anchors are measured post-filter)
    "chalk": {"alpha": 13.40, "space": 13.62, "enter": 10.45,
              "modifier": 12.42, "nav": 9.45, "release": 13.72},
    # eight distinct tap onsets detected at 33.85-44.42s
    "ipad_tap": {"alpha": 33.80, "space": 34.22, "enter": 42.38,
                 "modifier": 34.54, "nav": 39.73, "release": 42.78},
    # crinkle sections (high centroid) live at 10-36s
    "plastic_bag": {"alpha": 27.0, "space": 24.0, "enter": 36.0,
                    "modifier": 10.0, "nav": 23.0, "release": 28.0},
    # slurp takes at 17-23s and 4-6s
    "straw_sip": {"alpha": 21.0, "space": 17.0, "enter": 18.0,
                  "modifier": 6.0, "nav": 23.0, "release": 4.0},
}

ANCHOR_PREROLL = 0.005  # start a hair before a transient to keep its attack

# Per-pack high-pass (cutoff Hz, passes): removes mic rumble / handling noise
# that otherwise dominates the spectrum and buries the effect's texture.
HIGHPASS = {
    "chalk": (500.0, 2),
    "ipad_tap": (250.0, 1),
    "plastic_bag": (300.0, 1),
    "straw_sip": (150.0, 1),
}


def highpass(samples: list, sr: int, cutoff: float, passes: int = 1) -> list:
    """Cascaded one-pole RC high-pass (each pass is -6 dB/oct)."""
    y = list(samples)
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / sr
    alpha = rc / (rc + dt)
    for _ in range(passes):
        out = [0.0] * len(y)
        prev_in = 0.0
        prev_out = 0.0
        for i, x in enumerate(y):
            prev_out = alpha * (prev_out + x - prev_in)
            prev_in = x
            out[i] = prev_out
        y = out
    return y


def read_wav(path: Path):
    with wave.open(str(path), "rb") as w:
        ch = w.getnchannels()
        sr = w.getframerate()
        sw = w.getsampwidth()
        frames = w.readframes(w.getnframes())
    if sw != 2:
        sys.exit(f"unsupported sample width in {path}")
    samples = list(struct.unpack("<" + "h" * (len(frames) // 2), frames))
    if ch == 2:  # mono downmix
        samples = [(samples[i] + samples[i + 1]) // 2 for i in range(0, len(samples) - 1, 2)]
    return samples, sr


def convert(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", f"LEI16@{SR}", str(src), str(dst)],
        capture_output=True, text=True)
    if r.returncode != 0 or not dst.exists():
        r2 = subprocess.run(
            ["ffmpeg", "-y", "-i", str(src), "-ar", str(SR), "-ac", "1",
             "-c:a", "pcm_s16le", str(dst)],
            capture_output=True, text=True)
        if r2.returncode != 0:
            sys.exit(f"conversion failed for {src}:\n{r.stderr}\n{r2.stderr}")


def loud_regions(samples, sr: int, win_ms: int = 100) -> int:
    """Index of the first window whose RMS is at least 25% of the file median."""
    win = int(sr * win_ms / 1000)
    if win <= 0 or len(samples) < win * 4:
        return 0
    rms = []
    for start in range(0, len(samples) - win, win):
        chunk = samples[start:start + win]
        rms.append(math.sqrt(sum(s * s for s in chunk) / len(chunk)))
    rms_sorted = sorted(rms)
    median = rms_sorted[len(rms_sorted) // 2] or 1.0
    for i, r in enumerate(rms):
        if r >= median * 0.25:
            return i * win
    return 0


def cut(samples, sr: int, dur: float, offset_fraction: float, usable_from: int) -> list:
    n = int(sr * dur)
    usable = len(samples) - usable_from - n
    if usable <= 0:
        return samples[:n]
    start = usable_from + int(usable * offset_fraction)
    chunk = samples[start:start + n]
    # edge fades
    fi = min(int(sr * FADE_IN), n // 2)
    fo = min(int(sr * FADE_OUT), n // 2)
    for i in range(fi):
        chunk[i] = int(chunk[i] * i / fi)
    for i in range(fo):
        chunk[n - 1 - i] = int(chunk[n - 1 - i] * i / fo)
    return chunk


def cut_at(samples, sr: int, dur: float, start_s: float) -> list:
    """Window starting at an absolute second offset, with edge fades."""
    n = int(sr * dur)
    start = max(0, min(int(start_s * sr), max(0, len(samples) - n)))
    chunk = samples[start:start + n]
    if len(chunk) < n:
        chunk = chunk + [0] * (n - len(chunk))
    fi = min(int(sr * FADE_IN), n // 2)
    fo = min(int(sr * FADE_OUT), n // 2)
    for i in range(fi):
        chunk[i] = int(chunk[i] * i / fi)
    for i in range(fo):
        chunk[n - 1 - i] = int(chunk[n - 1 - i] * i / fo)
    return chunk


def normalize(samples: list) -> list:
    """Scale to the target RMS, clipping only the spikiest transients.

    Scaling by peak (the earlier approach) made transient-heavy takes much
    quieter than the rest; clipping a few milliseconds of a foley spike is
    inaudible, and this keeps every pack at the same perceived level.
    """
    if not samples:
        return samples
    rms = math.sqrt(sum(s * s for s in samples) / len(samples))
    if rms <= 0:
        return samples
    gain = TARGET_RMS / rms
    return [max(-PEAK_CEILING, min(PEAK_CEILING, int(s * gain))) for s in samples]


def write_wav(path: Path, samples: list, sr: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(struct.pack("<" + "h" * len(samples), *samples))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, required=True,
                    help="directory holding the downloaded mp3 files")
    ap.add_argument("--out", type=Path, default=Path("assets/sounds"))
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        for pack, stem in PACK_SOURCES.items():
            src = args.src / f"{stem}.mp3"
            if not src.exists():
                sys.exit(f"missing source: {src}")
            conv = tmpdir / f"{stem}.wav"
            convert(src, conv)
            samples, sr = read_wav(conv)
            hp = HIGHPASS.get(pack)
            if hp:
                samples = [int(max(-32768, min(32767, v)))
                           for v in highpass(samples, sr, hp[0], hp[1])]
            usable_from = loud_regions(samples, sr)
            total = len(samples) / sr
            print(f"  {pack:14s} <- {src.name} ({total:.1f}s"
                  + (f", highpass {hp[0]:.0f}Hz x{hp[1]}" if hp else "") + ")")
            anchors = ANCHOR_STARTS.get(pack)
            for layer, (dur, frac) in LAYER_CUTS.items():
                if anchors and layer in anchors:
                    start_s = max(0.0, anchors[layer] - ANCHOR_PREROLL)
                    chunk = cut_at(samples, sr, dur, start_s)
                    src_desc = f"anchor {anchors[layer]:.2f}s"
                else:
                    chunk = cut(samples, sr, dur, frac, usable_from)
                    src_desc = f"offset {frac:.2f}"
                chunk = normalize(chunk)
                write_wav(args.out / pack / f"{layer}.wav", chunk, sr)
                print(f"      {layer:8s} {dur:.2f}s {src_desc}")
    print(f"Built {len(PACK_SOURCES)} foley packs x 6 layers")


if __name__ == "__main__":
    main()
