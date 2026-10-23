#!/usr/bin/env python3
"""Regenerate assets/sounds/packs.json from kBuiltinPacks in sound_pack.dart.

The macOS native host (plugins/native_core/macos/Classes/MelodyHost.swift)
reads this manifest for the menu-bar menu, the tray panel and sample paths,
so it must list the packs in exactly the same order as the Dart table.
test/packs_manifest_test.dart fails when the two drift apart.

Usage: python3 tool/gen_packs_json.py
"""
import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / 'lib/core/audio/sound_pack.dart').read_text(encoding='utf-8')
table = src[src.index('const List<SoundPack> kBuiltinPacks'):]
packs = []
for block in re.findall(r'SoundPack\((.*?)\n  \),', table, re.S):
    fields = dict(re.findall(r"(\w+):\s*'((?:[^'\\]|\\.)*)'", block))
    packs.append({k: fields[k] for k in ('id', 'name', 'nameEn', 'description')})
out = root / 'assets/sounds/packs.json'
out.write_text(json.dumps(packs, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'wrote {len(packs)} packs -> {out.relative_to(root)}')
