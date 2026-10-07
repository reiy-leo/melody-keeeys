#!/usr/bin/env python3
"""Import the original Tickeys sound effects into this project.

Source: https://github.com/yingDev/Tickeys (MIT). Per-scheme provenance:
  * mechanical, drum        - Creative Commons 0 (public domain)
  * bubble                  - CC BY 3.0, by "Glaneur de sons" (Freesound)
  * typewriter, sword,
    Cherry_G80_3000/3494    - shipped in the MIT-licensed Tickeys repo
See assets/sounds/CREDITS.md for the full attribution list.

Tickeys maps its samples per keycode (schemes.json: 36=Return, 49=Space,
51=Backspace; other keys round-robin through the first `non_unique_count`
variants). This project uses six fixed layers per pack, so each layer is
mapped to the closest Tickeys file; the derived `release` layer is a short
fade-trimmed excerpt of a real sample so key-up audio stays on-material.

Usage:
  git clone --depth 1 https://github.com/yingDev/Tickeys /tmp/tickeys
  python3 tool/import_tickeys_sounds.py /tmp/tickeys/Tickeys.app/Contents/Resources/data
"""

import argparse
import shutil
import struct
import sys
import wave
from pathlib import Path

# pack_id -> Tickeys scheme dir
SCHEME_DIRS = {
    "bubble": "bubble",
    "typewriter": "typewriter",
    "mechanical": "mechanical",
    "sword": "sword",
    "cherry_g80_3000": "Cherry_G80_3000",
    "cherry_g80_3494": "Cherry_G80_3494",
    "drum": "drum",
}

# pack_id -> layer -> source file inside the scheme dir.
# Chosen to mirror Tickeys' own key mapping: its Return / Space / Backspace
# sounds land on our enter / space layers, the variant pool supplies the
# alpha/modifier/nav layers.
LAYER_MAP = {
    "bubble": {
        "alpha": "1.wav", "space": "4.wav", "enter": "enter.wav",
        "modifier": "2.wav", "nav": "3.wav", "release_from": "5.wav",
    },
    "typewriter": {
        "alpha": "key-new-01.wav", "space": "space-new.wav", "enter": "return-new.wav",
        "modifier": "key-new-02.wav", "nav": "key-new-03.wav", "release_from": "backspace.wav",
    },
    "mechanical": {
        "alpha": "1.wav", "space": "2.wav", "enter": "5.wav",
        "modifier": "3.wav", "nav": "4.wav", "release_from": "1.wav",
    },
    "sword": {
        "alpha": "1.wav", "space": "space.wav", "enter": "enter.wav",
        "modifier": "2.wav", "nav": "3.wav", "release_from": "back.wav",
    },
    "cherry_g80_3000": {
        "alpha": "G80-3000.wav", "space": "G80-3000_slow2.wav", "enter": "G80-3000_slow2.wav",
        "modifier": "G80-3000_fast1.wav", "nav": "G80-3000_slow1.wav",
        "release_from": "G80-3000_fast2.wav",
    },
    "cherry_g80_3494": {
        "alpha": "G80-3494.wav", "space": "G80-3494_space.wav", "enter": "G80-3494_enter.wav",
        "modifier": "G80-3494_fast1.wav", "nav": "G80-3494_slow1.wav",
        "release_from": "G80-3494_backspace.wav",
    },
    "drum": {
        "alpha": "1.wav", "space": "space.wav", "enter": "enter.wav",
        "modifier": "2.wav", "nav": "3.wav", "release_from": "4.wav",
    },
}

RELEASE_SECONDS = 0.10
RELEASE_FADE = 0.05


def write_release(src: Path, dst: Path) -> None:
    """First RELEASE_SECONDS of a real sample with a short fade-out."""
    with wave.open(str(src), "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        sw = w.getsampwidth()
        frames = w.readframes(int(sr * RELEASE_SECONDS))
    if sw != 2:
        raise SystemExit(f"unsupported sample width {sw} in {src}")
    samples = list(struct.unpack("<" + "h" * (len(frames) // 2), frames))
    fade_n = min(int(sr * RELEASE_FADE), len(samples) // (2 * ch) if ch else 0)
    total_frames = len(samples) // ch
    for i in range(fade_n):
        g = 1.0 - i / fade_n
        for c in range(ch):
            idx = (total_frames - fade_n + i) * ch + c
            samples[idx] = int(samples[idx] * g)
    data = struct.pack("<" + "h" * len(samples), *samples)
    with wave.open(str(dst), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("tickeys_data", type=Path,
                    help="path to Tickeys.app/Contents/Resources/data")
    ap.add_argument("--out", type=Path, default=Path("assets/sounds"))
    args = ap.parse_args()

    if not args.tickeys_data.is_dir():
        sys.exit(f"not a directory: {args.tickeys_data}")

    for pack, mapping in LAYER_MAP.items():
        src_dir = args.tickeys_data / SCHEME_DIRS[pack]
        dst_dir = args.out / pack
        dst_dir.mkdir(parents=True, exist_ok=True)
        for layer in ("alpha", "space", "enter", "modifier", "nav", "release"):
            if layer == "release":
                src = src_dir / mapping["release_from"]
                write_release(src, dst_dir / "release.wav")
                print(f"  {pack:18s} release <- {mapping['release_from']} (trimmed)")
                continue
            src = src_dir / mapping[layer]
            if not src.exists():
                sys.exit(f"missing source file: {src}")
            shutil.copyfile(src, dst_dir / f"{layer}.wav")
            print(f"  {pack:18s} {layer:8s} <- {mapping[layer]}")
    print(f"Imported {len(LAYER_MAP)} Tickeys schemes into {args.out}")


if __name__ == "__main__":
    main()
