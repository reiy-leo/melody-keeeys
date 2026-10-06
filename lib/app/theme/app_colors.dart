import 'package:flutter/material.dart';

/// Semantic color tokens resolved from the active theme (light / dark).
/// Registered as a ThemeExtension so widgets rebuild on theme switches;
/// access via `context.colors.xxx`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surfaceDim,
    required this.surface,
    required this.containerLow,
    required this.container,
    required this.containerHigh,
    required this.containerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.secondary,
    required this.tertiary,
    required this.error,
    required this.success,
    required this.ghostBorder,
    required this.hoverLayer,
  });

  final Color surfaceDim;
  final Color surface;
  final Color containerLow;
  final Color container;
  final Color containerHigh;
  final Color containerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;
  final Color tertiary;
  final Color error;
  final Color success;

  /// 1px hairline borders on cards (subtle white in dark, black in light).
  final Color ghostBorder;
  /// 8% state layer for hover.
  final Color hoverLayer;

  /// Deep-contrast dark theme ("Kinetic Haptic", the prototype's default).
  static const dark = AppColors(
    surfaceDim: Color(0xFF0C0B12),
    surface: Color(0xFF12111A),
    containerLow: Color(0xFF1A1826),
    container: Color(0xFF232034),
    containerHigh: Color(0xFF2C2941),
    containerHighest: Color(0xFF36324E),
    onSurface: Color(0xFFE5E0EE),
    onSurfaceVariant: Color(0xFFCAC4D4),
    outline: Color(0xFF948E9D),
    outlineVariant: Color(0xFF494552),
    primary: Color(0xFFA78BFA),
    onPrimary: Color(0xFF12111A),
    primaryContainer: Color(0xFF4F319C),
    secondary: Color(0xFFF472B6),
    tertiary: Color(0xFF38BDF8),
    error: Color(0xFFFFB4AB),
    success: Color(0xFF4ADE80),
    ghostBorder: Color(0x0FFFFFFF),
    hoverLayer: Color(0x14FFFFFF),
  );

  /// Violet-tinted light variant: same hue families, accents deepened for
  /// contrast on light surfaces.
  static const light = AppColors(
    surfaceDim: Color(0xFFF2F0F9),
    surface: Color(0xFFFBFAFE),
    containerLow: Color(0xFFF3F1FA),
    container: Color(0xFFECE9F6),
    containerHigh: Color(0xFFE4E1F0),
    containerHighest: Color(0xFFDAD6EA),
    onSurface: Color(0xFF1A1827),
    onSurfaceVariant: Color(0xFF494562),
    outline: Color(0xFF7A7494),
    outlineVariant: Color(0xFFCBC6DD),
    primary: Color(0xFF6D4AD6),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE7DEFF),
    secondary: Color(0xFFC2297F),
    tertiary: Color(0xFF0C7FA6),
    error: Color(0xFFBA1A1A),
    success: Color(0xFF1B8A3F),
    ghostBorder: Color(0x14000000),
    hoverLayer: Color(0x0A000000),
  );

  @override
  AppColors copyWith({
    Color? surfaceDim,
    Color? surface,
    Color? containerLow,
    Color? container,
    Color? containerHigh,
    Color? containerHighest,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? outlineVariant,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? secondary,
    Color? tertiary,
    Color? error,
    Color? success,
    Color? ghostBorder,
    Color? hoverLayer,
  }) =>
      AppColors(
        surfaceDim: surfaceDim ?? this.surfaceDim,
        surface: surface ?? this.surface,
        containerLow: containerLow ?? this.containerLow,
        container: container ?? this.container,
        containerHigh: containerHigh ?? this.containerHigh,
        containerHighest: containerHighest ?? this.containerHighest,
        onSurface: onSurface ?? this.onSurface,
        onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
        outline: outline ?? this.outline,
        outlineVariant: outlineVariant ?? this.outlineVariant,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        primaryContainer: primaryContainer ?? this.primaryContainer,
        secondary: secondary ?? this.secondary,
        tertiary: tertiary ?? this.tertiary,
        error: error ?? this.error,
        success: success ?? this.success,
        ghostBorder: ghostBorder ?? this.ghostBorder,
        hoverLayer: hoverLayer ?? this.hoverLayer,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      surfaceDim: c(surfaceDim, other.surfaceDim),
      surface: c(surface, other.surface),
      containerLow: c(containerLow, other.containerLow),
      container: c(container, other.container),
      containerHigh: c(containerHigh, other.containerHigh),
      containerHighest: c(containerHighest, other.containerHighest),
      onSurface: c(onSurface, other.onSurface),
      onSurfaceVariant: c(onSurfaceVariant, other.onSurfaceVariant),
      outline: c(outline, other.outline),
      outlineVariant: c(outlineVariant, other.outlineVariant),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      secondary: c(secondary, other.secondary),
      tertiary: c(tertiary, other.tertiary),
      error: c(error, other.error),
      success: c(success, other.success),
      ghostBorder: c(ghostBorder, other.ghostBorder),
      hoverLayer: c(hoverLayer, other.hoverLayer),
    );
  }
}

extension AppColorsOnContext on BuildContext {
  /// Semantic color tokens for the active brightness.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
