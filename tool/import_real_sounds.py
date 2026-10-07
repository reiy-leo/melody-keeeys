#!/usr/bin/env python3
"""Replace the synthesized placeholder packs with real keyboard recordings.

Sources (all permissively licensed, details in assets/sounds/CREDITS.md):
  * kbsim  - https://github.com/tplai/kbsim (MIT, Copyright (c) Thomas Lai)
             real recordings: mxblue/blackink/holypanda/buckling/boxnavy/
             topre/redink/turquoise/cream/alpaca/mxbrown/mxblack/bluealps
  * Kenney Sci-Fi Sounds - https://kenney.nl/assets/sci-fi-sounds (CC0)
  * Tickeys - https://github.com/yingDev/Tickeys (MIT; bubble variants are
             CC BY 3.0 by Glaneur de sons, see the per-scheme license.txt)

Packs 01-06/10 use kbsim recordings; 07/09 reuse leftover Tickeys variants
(11/12 already use that material); 08 uses a Kenney laser.

Usage:
  git clone --depth 1 https://github.com/tplai/kbsim /tmp/kbsim
  curl -L -o /tmp/kenney_scifi.zip https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip
  unzip -q /tmp/kenney_scifi.zip -d /tmp/kenney_scifi
  git clone --depth 1 https://github.com/yingDev/Tickeys /tmp/tickeys
  python3 tool/import_real_sounds.py \
      --kbsim /tmp/kbsim/src/assets/audio \
      --kenney /tmp/kenney_scifi/Audio \
      --tickeys /tmp/tickeys/Tickeys.app/Contents/Resources/data
"""

import argparse
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

SR = 48000

# Loudness normalization: raw sources range from peak 1113 to 32768 (~30 dB
# spread), which would make pack switching jarring. Align each sample to a
# target RMS, capped so the peak stays below full scale.
TARGET_RMS = 2500.0
PEAK_CEILING = 32000.0

# pack -> source key in kbsim. Layers map to press/GENERIC_R0..R4 plus the
# real key-specific samples; a missing file falls back to GENERIC_R1.
KBSIM_PACKS = {
    "cherry_mx_blue": "mxblue",
    "gateron_oil_king": "blackink",
    "holy_panda": "holypanda",
    "ibm_model_m": "buckling",
    "kailh_box_white": "boxnavy",
    "topre_electrostatic": "topre",
    "silent_red": "redink",
}

KBSIM_LAYERS = {
    "alpha": "press/GENERIC_R0.mp3",
    "space": "press/SPACE.mp3",
    "enter": "press/ENTER.mp3",
    "modifier": "press/GENERIC_R1.mp3",
    "nav": "press/GENERIC_R2.mp3",
    "release": "release/GENERIC.mp3",
}
KBSIM_FALLBACK = "press/GENERIC_R1.mp3"

# Tickeys leftovers for 07 (bubble variants not used by 11) and 09
# (typewriter files not used by 12's mapping).
TICKEYS_PACKS = {
    "bubble_pop": {
        "dir": "bubble",
        "alpha": "6.wav", "space": "8.wav", "enter": "enter.wav",
        "modifier": "7.wav", "nav": "8.wav", "release_from": "6.wav",
    },
    "typewriter_1930s": {
        "dir": "typewriter",
        "alpha": "key-new-05.wav", "space": "space-new.wav", "enter": "return-new.wav",
        "modifier": "key-new-04.wav", "nav": "key-new-03.wav",
        "release_from": "backspace.wav",
    },
}

# 08 scifi_laser from Kenney's laser set.
KENNEY_LASER = {
    "alpha": "laserRetro_000.ogg",
    "space": "laserRetro_004.ogg",
    "enter": "laserRetro_002.ogg",
    "modifier": "laserRetro_001.ogg",
    "nav": "laserRetro_003.ogg",
    "release_from": "laserLarge_003.ogg",
}

RELEASE_SECONDS = 0.10
RELEASE_FADE = 0.05


def convert(src: Path, dst: Path) -> None:
    """mp3/ogg -> 48 kHz 16-bit WAV via afconvert (ffmpeg fallback)."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", f"LEI16@{SR}", str(src), str(dst)],
        capture_output=True, text=True)
    if r.returncode != 0 or not dst.exists():
        r2 = subprocess.run(
            ["ffmpeg", "-y", "-i", str(src), "-ar", str(SR), "-ac", "2",
             "-c:a", "pcm_s16le", str(dst)],
            capture_output=True, text=True)
        if r2.returncode != 0:
            sys.exit(f"conversion failed for {src}:\n{r.stderr}\n{r2.stderr}")


def normalize(path: Path, target_rms: float = TARGET_RMS) -> None:
    """Scale a 16-bit WAV to a target RMS, keeping the peak under the ceiling."""
    with wave.open(str(path), "rb") as w:
        ch, sr, sw = w.getnchannels(), w.getframerate(), w.getsampwidth()
        frames = w.readframes(w.getnframes())
    if sw != 2:
        return
    samples = list(struct.unpack("<" + "h" * (len(frames) // 2), frames))
    if not samples:
        return
    rms = (sum(s * s for s in samples) / len(samples)) ** 0.5
    peak = max(abs(s) for s in samples)
    if rms <= 0 or peak <= 0:
        return
    gain = target_rms / rms
    if peak * gain > PEAK_CEILING:
        gain = PEAK_CEILING / peak
    scaled = [max(-32768, min(32767, int(s * gain))) for s in samples]
    with wave.open(str(path), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(struct.pack("<" + "h" * len(scaled), *scaled))


def emit(src: Path, dst: Path) -> None:
    """Copy a converted sample to its final path and normalize loudness."""
    shutil.copyfile(src, dst)
    normalize(dst)


def write_release(src_wav: Path, dst: Path) -> None:
    """First RELEASE_SECONDS of a converted sample with a short fade-out."""
    with wave.open(str(src_wav), "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        frames = w.readframes(int(sr * RELEASE_SECONDS))
    samples = list(struct.unpack("<" + "h" * (len(frames) // 2), frames))
    total_frames = len(samples) // max(ch, 1)
    fade_n = min(int(sr * RELEASE_FADE), total_frames)
    for i in range(fade_n):
        g = 1.0 - i / fade_n
        for c in range(ch):
            idx = (total_frames - fade_n + i) * ch + c
            samples[idx] = int(samples[idx] * g)
    with wave.open(str(dst), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(struct.pack("<" + "h" * len(samples), *samples))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kbsim", type=Path, required=True,
                    help="path to kbsim/src/assets/audio")
    ap.add_argument("--kenney", type=Path, required=True,
                    help="path to the extracted Kenney sci-fi Audio/ dir")
    ap.add_argument("--tickeys", type=Path, required=True,
                    help="path to Tickeys.app/Contents/Resources/data")
    ap.add_argument("--out", type=Path, default=Path("assets/sounds"))
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)

        # ---- kbsim recordings (01-06, 10) ----
        for pack, src_name in KBSIM_PACKS.items():
            src_dir = args.kbsim / src_name
            dst_dir = args.out / pack
            dst_dir.mkdir(parents=True, exist_ok=True)
            for layer, rel in KBSIM_LAYERS.items():
                src = src_dir / rel
                if not src.exists():
                    src = src_dir / KBSIM_FALLBACK
                    note = f" (fallback {KBSIM_FALLBACK})"
                else:
                    note = ""
                conv = tmpdir / f"{src_name}_{layer}.wav"
                convert(src, conv)
                emit(conv, dst_dir / f"{layer}.wav")
                print(f"  {pack:20s} {layer:8s} <- {src_name}/{src.name}{note}")

        # ---- Tickeys leftovers (07, 09) ----
        for pack, m in TICKEYS_PACKS.items():
            src_dir = args.tickeys / m["dir"]
            dst_dir = args.out / pack
            dst_dir.mkdir(parents=True, exist_ok=True)
            for layer in ("alpha", "space", "enter", "modifier", "nav", "release"):
                if layer == "release":
                    src = src_dir / m["release_from"]
                    conv = tmpdir / f"{pack}_rel.wav"
                    convert(src, conv)
                    write_release(conv, dst_dir / "release.wav")
                    normalize(dst_dir / "release.wav")
                    print(f"  {pack:20s} release  <- {m['dir']}/{m['release_from']} (trimmed)")
                    continue
                src = src_dir / m[layer]
                if not src.exists():
                    sys.exit(f"missing source: {src}")
                conv = tmpdir / f"{pack}_{layer}.wav"
                convert(src, conv)
                emit(conv, dst_dir / f"{layer}.wav")
                print(f"  {pack:20s} {layer:8s} <- {m['dir']}/{m[layer]}")

        # ---- Kenney laser (08) ----
        for layer, rel in KENNEY_LASER.items():
            src = args.kenney / rel
            dst_dir = args.out / "scifi_laser"
            dst_dir.mkdir(parents=True, exist_ok=True)
            conv = tmpdir / f"laser_{layer}.wav"
            convert(src, conv)
            if layer == "release_from":
                write_release(conv, dst_dir / "release.wav")
                normalize(dst_dir / "release.wav")
                print(f"  {'scifi_laser':20s} release  <- kenney/{rel} (trimmed)")
            else:
                emit(conv, dst_dir / f"{layer}.wav")
                print(f"  {'scifi_laser':20s} {layer:8s} <- kenney/{rel}")

    print(f"Replaced {len(KBSIM_PACKS) + len(TICKEYS_PACKS) + 1} packs with real recordings")


if __name__ == "__main__":
    main()
