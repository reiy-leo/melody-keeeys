#!/usr/bin/env python3
"""Rasterize Lucide tray icons into Melody Keeeys tray asset variants.

Pipeline: fetch SVG (lucide-static) -> qlmanage 256px thumbnail (white bg)
-> chroma-key (alpha = 255 - luminance, monochrome strokes) -> tint & scale.

Outputs per icon <id> in assets/icons/:
  tray_<id>_template.png   44px black  (macOS menu bar, template image)
  tray_<id>_colored.png    32px lavender (Windows/Linux tray)
  tray_<id>_preview.png    72px lavender (settings page preview)

Usage: python3 tool/make_lucide_tray_icons.py
"""

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

LUCIDE_VERSION = "latest"
ICONS = [
    "keyboard",
    "keyboard-music",
    "command",
    "line-squiggle",
    "gamepad-directional",
    "tv",
    "balloon",
]
LAVENDER = (167, 139, 250)
OUT = Path("assets/icons")


def fetch_svg(icon: str, dest: Path) -> None:
    url = f"https://unpkg.com/lucide-static@{LUCIDE_VERSION}/icons/{icon}.svg"
    subprocess.run(["curl", "-sL", "--max-time", "30", "-o", str(dest), url], check=True)
    if b"<svg" not in dest.read_bytes():
        raise RuntimeError(f"download failed for {icon}: {dest.read_bytes()[:60]!r}")


def render_alpha(svg_path: Path, size: int) -> Image.Image:
    """qlmanage renders on white; luminance -> alpha gives clean AA strokes."""
    with tempfile.TemporaryDirectory() as td:
        subprocess.run(
            ["qlmanage", "-t", "-s", "512", "-o", td, str(svg_path)],
            check=True, capture_output=True,
        )
        thumb = Path(td) / f"{svg_path.name}.png"
        img = Image.open(thumb).convert("L")
    alpha = img.point(lambda l: 255 - l)
    # Trim to the glyph bounding box so all icons optically align after scaling.
    bbox = alpha.getbbox()
    if bbox:
        alpha = alpha.crop(bbox)
    alpha.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("L", (size, size), 0)
    canvas.paste(alpha, ((size - alpha.width) // 2, (size - alpha.height) // 2))
    return canvas


def tinted(mask: Image.Image, rgb: tuple) -> Image.Image:
    out = Image.new("RGBA", mask.size, rgb + (0,))
    out.putalpha(mask)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        for icon in ICONS:
            svg = Path(td) / f"{icon}.svg"
            fetch_svg(icon, svg)
            mask = render_alpha(svg, 44)
            tinted(mask, (0, 0, 0)).save(OUT / f"tray_{icon}_template.png")
            colored32 = tinted(render_alpha(svg, 32), LAVENDER)
            colored32.save(OUT / f"tray_{icon}_colored.png")
            tinted(render_alpha(svg, 72), LAVENDER).save(OUT / f"tray_{icon}_preview.png")
            print(f"  {icon:<22} template/colored/preview ok")
    print(f"Done: {len(ICONS)} icons -> {OUT}/")


if __name__ == "__main__":
    sys.exit(main())
