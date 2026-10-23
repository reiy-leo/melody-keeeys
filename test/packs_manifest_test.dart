import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melody_keeeys/core/audio/sound_pack.dart';

/// The macOS native host reads assets/sounds/packs.json instead of the Dart
/// table; regenerate it with `python3 tool/gen_packs_json.py`.
void main() {
  test('packs.json mirrors kBuiltinPacks', () {
    final raw = jsonDecode(File('assets/sounds/packs.json').readAsStringSync())
        as List<dynamic>;
    expect(raw.length, kBuiltinPacks.length);
    for (var i = 0; i < raw.length; i++) {
      final p = raw[i] as Map<String, dynamic>;
      final d = kBuiltinPacks[i];
      expect(
        [p['id'], p['name'], p['nameEn'], p['description']],
        [d.id, d.name, d.nameEn, d.description],
      );
    }
  });
}
