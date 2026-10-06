#!/usr/bin/env python3
"""Generate tray/menu-bar icons from a keycap + soundwave motif.

Outputs:
  assets/icons/tray_template.png    macOS menu bar (black, template alpha)
  assets/icons/tray_colored.png     Windows/Linux tray (lavender on transparent)
  assets/icons/tray.ico             Windows multi-size
"""

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path("assets/icons")
S = 64  # master size before downscale


def rounded_rect(draw, box, radius, **kw):
    draw.rounded_rectangle(box, radius=radius, **kw)


def draw_glyph(size, fg):
    """Keycap silhouette with mini equalizer bars, stroked keycap style."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = size / 64.0  # unit scale from master design

    # keycap body
    rounded_rect(d, (6 * u, 16 * u, 58 * u, 48 * u), radius=10 * u,
                 outline=fg, width=int(4.5 * u))

    # three equalizer bars inside (sound motif)
    bars = [(20, 34, 26, 42), (29, 26, 35, 42), (38, 30, 44, 42)]
    for x0, y0, x1, y1 in bars:
        rounded_rect(d, (x0 * u, y0 * u, x1 * u, y1 * u), radius=3 * u, fill=fg)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    template = draw_glyph(S, (0, 0, 0, 255))
    template.resize((44, 44), Image.LANCZOS).save(OUT / "tray_template.png")

    colored = draw_glyph(S, (167, 139, 250, 255))
    colored.resize((32, 32), Image.LANCZOS).save(OUT / "tray_colored.png")
    colored.resize((22, 22), Image.LANCZOS).save(OUT / "tray_colored_22.png")

    colored.resize((16, 16), Image.LANCZOS).save(OUT / "tray_16.png")
    colored.resize((32, 32), Image.LANCZOS).save(OUT / "tray_32.png")
    colored.resize((48, 48), Image.LANCZOS).save(OUT / "tray_48.png")
    colored.resize((256, 256), Image.LANCZOS).save(OUT / "tray_256.png")

    (OUT / "tray.ico").unlink(missing_ok=True)
    Image.open(OUT / "tray_16.png").save(
        OUT / "tray.ico", format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (256, 256)])

    for f in sorted(OUT.iterdir()):
        print(f"{f.name:<20} {f.stat().st_size} bytes")


if __name__ == "__main__":
    main()
