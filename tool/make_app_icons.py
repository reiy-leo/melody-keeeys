#!/usr/bin/env python3
"""Build every app icon from assets/icons/source/app_icon_source.png.

The source is a 1254px PNG with real transparency (a rounded square plus a
soft drop shadow). The rounded square is found from the opaque pixels
(alpha > 128) and cropped to a centered square, keeping the alpha as is.

Outputs: macOS AppIcon.appiconset (Big Sur grid: 824px square on a 1024
canvas), Windows app_icon.ico (full bleed), assets/icons/app_icon.png
(in-app About page, 512px full bleed).
Usage: python3 tool/make_app_icons.py
"""
import pathlib
from PIL import Image

root = pathlib.Path(__file__).resolve().parent.parent
src = Image.open(root / 'assets/icons/source/app_icon_source.png').convert('RGBA')
x0, y0, x1, y1 = src.split()[3].point(lambda v: 255 if v > 128 else 0).getbbox()
side = max(x1 - x0, y1 - y0)
cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
square = src.crop((round(cx - side / 2), round(cy - side / 2),
                   round(cx + side / 2), round(cy + side / 2)))  # full-bleed rounded square

def fitted(size, inset):
    """Square of `size` px with the icon scaled to size*inset, centered."""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    inner = round(size * inset)
    icon = square.resize((inner, inner), Image.LANCZOS)
    canvas.alpha_composite(icon, ((size - inner) // 2, (size - inner) // 2))
    return canvas

appiconset = root / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
for px in (16, 32, 64, 128, 256, 512, 1024):
    fitted(px, 824 / 1024).save(appiconset / f'app_icon_{px}.png')

fitted(512, 1.0).save(root / 'assets/icons/app_icon.png')
fitted(256, 1.0).save(root / 'windows/runner/resources/app_icon.ico',
                      sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print('icons written')
