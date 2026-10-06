/// Canonical per-platform keycode tables and the keystroke -> sound-layer
/// classifier. Native layers report raw platform codes; all mapping happens
/// here in Dart (see PLAN.md 3.1).
library;

import '../audio/sound_pack.dart';

enum HookPlatform { macos, windows, linux }

class KeyEvent {
  const KeyEvent({
    required this.platform,
    required this.code,
    required this.isKeyDown,
    required this.isRepeat,
    required this.timestampMs,
  });

  final HookPlatform platform;
  final int code;
  final bool isKeyDown;
  final bool isRepeat;
  final int timestampMs;
}

/// The five playable categories a keypress belongs to. `unknown` keys are silent.
enum KeyCategory { alpha, space, enter, modifier, nav, unknown }

extension KeyCategoryX on KeyCategory {
  SoundLayer get layer => switch (this) {
        KeyCategory.alpha => SoundLayer.alpha,
        KeyCategory.space => SoundLayer.space,
        KeyCategory.enter => SoundLayer.enter,
        KeyCategory.modifier => SoundLayer.modifier,
        KeyCategory.nav => SoundLayer.nav,
        KeyCategory.unknown => SoundLayer.alpha,
      };
}

// ---- macOS kVK_* codes (CGEvent keyboardEventKeycode) ----

const Set<int> _macAlpha = {
  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, // A S D F H G Z X C V
  0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, // B Q W E R Y T
  0x1F, 0x20, 0x22, 0x23, // O U I P
  0x25, 0x26, 0x28, // L J K
  0x2D, 0x2E, // N M
  0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, // Keypad 0-9
};
const Set<int> _macDigitsPunct = {
  0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, // 1..0 - =
  0x1E, 0x21, 0x27, 0x29, 0x2A, 0x2B, 0x2C, 0x2F, 0x32, // [ ' ; \ , . / `
};
const Set<int> _macSpace = {0x31};
const Set<int> _macEnter = {0x24, 0x33, 0x4C}; // Return, Backspace, Keypad-Enter
const Set<int> _macModifier = {
  0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, // RCmd Cmd Shift Caps Opt Ctrl RShift ROpt RCtrl Fn
};
const Set<int> _macNav = {
  0x35, // Escape
  0x40, 0x4F, 0x50, 0x5A, 0x6A, // F17 F18 F19 F20 F16
  0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x67, 0x69, 0x6B, 0x6D, 0x6F, 0x71, 0x76, 0x78, 0x7A, // F5 F6 F7 F3 F8 F9 F11 F13 F14 F10 F12 F15 F4 F2 F1
  0x48, 0x49, 0x4A, // VolumeUp VolumeDown Mute
  0x41, 0x43, 0x45, 0x47, 0x4B, 0x4E, 0x51, // Keypad operators
  0x72, 0x73, 0x74, 0x75, 0x77, 0x79, // Help Home PageUp FwdDelete End PageDown
  0x7B, 0x7C, 0x7D, 0x7E, // Arrows
};

// ---- Windows VK codes ----

const Set<int> _winAlpha = {
  0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D,
  0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A,
};
const Set<int> _winDigitsPunct = {
  0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, // 0-9
  0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xDB, 0xDC, 0xDD, 0xDE, // OEM
  0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, // Numpad 0-9
};
const Set<int> _winSpace = {0x20};
const Set<int> _winEnter = {0x0D, 0x08}; // Return, Backspace
const Set<int> _winModifier = {
  0x10, 0xA0, 0xA1, // Shift, LShift, RShift
  0x11, 0xA2, 0xA3, // Control, LControl, RControl
  0x12, 0xA4, 0xA5, // Menu, LMenu, RMenu
  0x14, 0x5B, 0x5C, 0x5D, // CapsLock, LWin, RWin, Apps
};
const Set<int> _winNav = {
  0x1B, // Escape
  0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, // F1-F12
  0x7C, 0x7D, 0x7E, 0x7F, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, // F13-F24
  0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E, 0x2F, // PgUp..Scroll
  0x90, 0x91, 0x6A, 0x6B, 0x6D, 0x6E, 0x6F, // NumLock ScrollLock keypad ops
};

// ---- Linux evdev codes (input-event-codes.h) ----

const Set<int> _linuxAlpha = {
  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, // Q..P
  30, 31, 32, 33, 34, 35, 36, 37, 38, // A..L
  44, 45, 46, 47, 48, 49, 50, // Z..M
  71, 72, 73, 75, 76, 77, 79, 80, 81, 82, 83, // Keypad 7..KeypadDot
};
const Set<int> _linuxDigitsPunct = {
  2, 3, 4, 5, 6, 7, 8, 9, 10, 11, // 1..0
  12, 13, // Minus Equal
  26, 27, 39, 40, 41, 43, 51, 52, 53, // [ ] ; ' ` \ , . /
};
const Set<int> _linuxSpace = {57};
const Set<int> _linuxEnter = {28, 14, 96}; // Enter, Backspace, Keypad-Enter
const Set<int> _linuxModifier = {
  29, 97, // LeftCtrl RightCtrl
  42, 54, // LeftShift RightShift
  56, 100, // LeftAlt RightAlt
  58, 125, 126, 127, // CapsLock LeftMeta RightMeta Compose
};
const Set<int> _linuxNav = {
  1, // Esc
  59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 87, 88, // F1-F12
  102, 103, 104, 105, 106, 107, 108, 109, 110, 111, // Home..Delete
  69, 70, 119, 120, 121, 122, 123, 124, // Locks + media keys
};

KeyCategory classify(KeyEvent e) => switch (e.platform) {
        HookPlatform.macos => _pick(
            e.code, _macAlpha, _macDigitsPunct, _macSpace, _macEnter, _macModifier, _macNav),
        HookPlatform.windows => _pick(
            e.code, _winAlpha, _winDigitsPunct, _winSpace, _winEnter, _winModifier, _winNav),
        HookPlatform.linux => _pick(
            e.code, _linuxAlpha, _linuxDigitsPunct, _linuxSpace, _linuxEnter, _linuxModifier,
            _linuxNav),
      };

KeyCategory _pick(int code, Set<int> alpha, Set<int> digits, Set<int> space, Set<int> enter,
    Set<int> modifier, Set<int> nav) {
  if (space.contains(code)) return KeyCategory.space;
  if (enter.contains(code)) return KeyCategory.enter;
  if (modifier.contains(code)) return KeyCategory.modifier;
  if (alpha.contains(code) || digits.contains(code)) return KeyCategory.alpha;
  if (nav.contains(code)) return KeyCategory.nav;
  return KeyCategory.unknown;
}
