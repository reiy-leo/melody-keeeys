import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'settings_model.dart';

/// JSON persistence over SharedPreferences (single 'settings' key).
class SettingsRepository {
  static const _key = 'melody_keeeys.settings.v1';

  AppSettings _cache = const AppSettings();

  AppSettings get settings => _cache;

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _cache = AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
      } catch (_) {
        _cache = const AppSettings();
      }
    }
    return _cache;
  }

  Future<void> save(AppSettings s) async {
    _cache = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }
}
