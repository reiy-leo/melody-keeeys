import 'package:flutter/material.dart';

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

/// Space Grotesk for headlines/labels, Plus Jakarta Sans for body text.
abstract final class AppText {
  static const _grotesk = 'Space Grotesk';
  static const _jakarta = 'Plus Jakarta Sans';

  static const displayLg = TextStyle(
      fontFamily: _grotesk, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.02);
  static const headlineLg = TextStyle(
      fontFamily: _grotesk, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.02);
  static const headlineMd = TextStyle(
      fontFamily: _grotesk, fontSize: 18, fontWeight: FontWeight.w600);
  static const titleLg = TextStyle(fontFamily: _jakarta, fontSize: 16, fontWeight: FontWeight.w600);
  static const titleMd = TextStyle(fontFamily: _jakarta, fontSize: 14, fontWeight: FontWeight.w600);
  static const bodyLg = TextStyle(fontFamily: _jakarta, fontSize: 15, height: 1.45);
  static const bodyMd = TextStyle(fontFamily: _jakarta, fontSize: 13, height: 1.4);
  static const bodySm = TextStyle(fontFamily: _jakarta, fontSize: 11, height: 1.35);
  static const labelLg = TextStyle(
      fontFamily: _grotesk, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.02);
  static const labelMd = TextStyle(
      fontFamily: _grotesk,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.04,
      height: 1.2);
  static const mono = TextStyle(
      fontFamily: _grotesk, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.04);
}
