import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';

// Color tokens live in app_colors.dart (ThemeExtension, light + dark).
export 'app_colors.dart' show AppColors, AppColorsOnContext;

abstract final class AppRadii {
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(16)); // keycap containers
  static const lg = BorderRadius.all(Radius.circular(20)); // tray popover
  static const xl = BorderRadius.all(Radius.circular(32)); // window shells/cards
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Windows uses the system UI font for the current language instead of the
/// bundled Latin fonts: Flutter's own CJK fallback there picks odd faces.
abstract final class AppFonts {
  static bool get _windows => !kIsWeb && Platform.isWindows;

  /// Primary family on Windows, or null to keep the design fonts.
  static String? get windowsFamily {
    if (!_windows) return null;
    switch (I18n.lang) {
      case 'zh':
        return 'Microsoft YaHei UI';
      case 'ja':
        return 'Yu Gothic UI';
      default:
        return 'Segoe UI Variable Display';
    }
  }

  static List<String>? get fallback {
    if (!_windows) return null;
    switch (I18n.lang) {
      case 'zh':
        return const ['Microsoft YaHei', 'Segoe UI'];
      case 'ja':
        return const ['Meiryo UI', 'Yu Gothic', 'Segoe UI'];
      default:
        return const ['Segoe UI', 'Microsoft YaHei UI'];
    }
  }
}

/// Space Grotesk for headlines/labels, Plus Jakarta Sans for body text
/// (system UI fonts per language on Windows, see [AppFonts]).
abstract final class AppText {
  static String get _grotesk => AppFonts.windowsFamily ?? 'Space Grotesk';
  static String get _jakarta => AppFonts.windowsFamily ?? 'Plus Jakarta Sans';
  static List<String>? get _fb => AppFonts.fallback;

  static TextStyle get displayLg => TextStyle(
      fontFamily: _grotesk,
      fontFamilyFallback: _fb, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.02);
  static TextStyle get headlineLg => TextStyle(
      fontFamily: _grotesk,
      fontFamilyFallback: _fb, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.02);
  static TextStyle get headlineMd => TextStyle(
      fontFamily: _grotesk,
      fontFamilyFallback: _fb, fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle get titleLg => TextStyle(
      fontFamily: _jakarta,
      fontFamilyFallback: _fb, fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle get titleMd => TextStyle(
      fontFamily: _jakarta,
      fontFamilyFallback: _fb, fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle get bodyLg => TextStyle(
      fontFamily: _jakarta,
      fontFamilyFallback: _fb, fontSize: 15, height: 1.45);
  static TextStyle get bodyMd => TextStyle(
      fontFamily: _jakarta,
      fontFamilyFallback: _fb, fontSize: 13, height: 1.4);
  static TextStyle get bodySm => TextStyle(
      fontFamily: _jakarta,
      fontFamilyFallback: _fb, fontSize: 11, height: 1.35);
  static TextStyle get labelLg => TextStyle(
      fontFamily: _grotesk,
      fontFamilyFallback: _fb, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.02);
  static TextStyle get labelMd => TextStyle(
      fontFamily: _grotesk,
      fontFamilyFallback: _fb,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.04,
      height: 1.2);
  static TextStyle get mono => TextStyle(
      fontFamily: _grotesk,
      fontFamilyFallback: _fb, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.04);
}
