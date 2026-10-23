#!/usr/bin/env python3
"""Build every app icon from assets/icons/source/app_icon_source.webp.

The source is a 1254px render whose "transparent" background is a baked-in
checkerboard, so the rounded square is cut out with a clean supersampled
mask (measured: square x 98..1155, y 102..1149, corner radius ~248px).

Outputs: macOS AppIcon.appiconset (Big Sur grid: 824px square on a 1024
canvas), Windows app_icon.ico (full bleed), assets/icons/app_icon.png
(in-app About page, 512px full bleed).
Usage: python3 tool/make_app_icons.py
"""
import pathlib
from PIL import Image, ImageDraw

root = pathlib.Path(__file__).resolve().parent.parent
src = Image.open(root / 'assets/icons/source/app_icon_source.webp').convert('RGB')
X0, Y0, X1, Y1, R = 102, 106, 1152, 1146, 244  # 4px inside the edge: no checkerboard fringe
SS = 4
mask = Image.new('L', (src.width * SS, src.height * SS), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    (X0 * SS, Y0 * SS, X1 * SS - 1, Y1 * SS - 1), radius=R * SS, fill=255)
mask = mask.resize(src.size, Image.LANCZOS)
rgba = src.copy()
rgba.putalpha(mask)
square = rgba.crop((X0, Y0, X1, Y1))  # full-bleed rounded square, ~1058px

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
