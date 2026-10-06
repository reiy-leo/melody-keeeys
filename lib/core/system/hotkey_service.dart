import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../audio/sound_engine.dart';
import '../settings/settings_model.dart';

/// Registers the two global hotkeys: mute toggle + cycle pack. Registered via
/// Carbon/event hotkeys, so no accessibility permission is required.
class HotkeyService {
  HotkeyService._();
  static final HotkeyService instance = HotkeyService._();

  HotKey? _muteHotKey;
  HotKey? _cycleHotKey;

  Future<void> register(AppSettings settings) async {
    await unregister();
    _muteHotKey = await _tryRegister(
        settings.muteHotkey,
        (_) async => soundEngine.toggleEngine());
    _cycleHotKey = await _tryRegister(
        settings.cycleHotkey, (_) => soundEngine.cyclePack());
  }

  Future<HotKey?> _tryRegister(String spec, void Function(HotKey) onTap) async {
    final hotKey = parseSpec(spec);
    if (hotKey == null) return null;
    try {
      await hotKeyManager.register(hotKey, keyDownHandler: onTap);
      return hotKey;
    } catch (_) {
      return null; // conflict or unsupported combo; settings UI shows state
    }
  }

  Future<void> unregister() async {
    if (_muteHotKey != null) await hotKeyManager.unregister(_muteHotKey!);
    if (_cycleHotKey != null) await hotKeyManager.unregister(_cycleHotKey!);
    _muteHotKey = null;
    _cycleHotKey = null;
  }

  /// Parses "Option+Shift+K" / "Ctrl+Alt+]" style specs produced by the UI.
  static HotKey? parseSpec(String spec) {
    final parts = spec.split('+').map((p) => p.trim()).toList();
    if (parts.isEmpty) return null;
    final keyPart = parts.removeLast();
    if (keyPart.length != 1) return null;
    if (parts.isEmpty) return null;

    final modifiers = <HotKeyModifier>[];
    for (final p in parts) {
      switch (p.toLowerCase()) {
        case 'option':
        case 'alt':
          modifiers.add(HotKeyModifier.alt);
        case 'ctrl':
        case 'control':
          modifiers.add(HotKeyModifier.control);
        case 'shift':
          modifiers.add(HotKeyModifier.shift);
        case 'cmd':
        case 'meta':
          modifiers.add(HotKeyModifier.meta);
        default:
          return null;
      }
    }

    final key = _keyFromChar(keyPart);
    if (key == null) return null;
    return HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);
  }

  static KeyboardKey? _keyFromChar(String c) {
    final lower = c.toLowerCase();
    final code = lower.runes.first;
    if (code >= 0x61 && code <= 0x7A) {
      return LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + (code - 0x61));
    }
    const punctuation = {
      '[': LogicalKeyboardKey.bracketLeft,
      ']': LogicalKeyboardKey.bracketRight,
      '\\': LogicalKeyboardKey.backslash,
      ';': LogicalKeyboardKey.semicolon,
      '\'': LogicalKeyboardKey.quote,
      ',': LogicalKeyboardKey.comma,
      '.': LogicalKeyboardKey.period,
      '/': LogicalKeyboardKey.slash,
      '`': LogicalKeyboardKey.backquote,
      '-': LogicalKeyboardKey.minus,
      '=': LogicalKeyboardKey.equal,
    };
    return punctuation[lower];
  }
}
