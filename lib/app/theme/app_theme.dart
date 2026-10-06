import 'package:flutter/material.dart';

import 'app_tokens.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final isDark = brightness == Brightness.dark;

  final scheme = isDark
      ? ColorScheme.dark(
          primary: c.primary,
          onPrimary: c.onPrimary,
          primaryContainer: c.primaryContainer,
          secondary: c.secondary,
          onSecondary: c.onPrimary,
          tertiary: c.tertiary,
          surface: c.surface,
          onSurface: c.onSurface,
          onSurfaceVariant: c.onSurfaceVariant,
          surfaceContainerLowest: c.surfaceDim,
          surfaceContainerLow: c.containerLow,
          surfaceContainer: c.container,
          surfaceContainerHigh: c.containerHigh,
          surfaceContainerHighest: c.containerHighest,
          outline: c.outline,
          outlineVariant: c.outlineVariant,
          error: c.error,
        )
      : ColorScheme.light(
          primary: c.primary,
          onPrimary: c.onPrimary,
          primaryContainer: c.primaryContainer,
          secondary: c.secondary,
          onSecondary: c.onPrimary,
          tertiary: c.tertiary,
          surface: c.surface,
          onSurface: c.onSurface,
          onSurfaceVariant: c.onSurfaceVariant,
          surfaceContainerLowest: c.surfaceDim,
          surfaceContainerLow: c.containerLow,
          surfaceContainer: c.container,
          surfaceContainerHigh: c.containerHigh,
          surfaceContainerHighest: c.containerHighest,
          outline: c.outline,
          outlineVariant: c.outlineVariant,
          error: c.error,
        );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.surface,
    fontFamily: 'Plus Jakarta Sans',
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    extensions: [c],
    // Every style must carry an explicit color: a null color in textTheme
    // inherits nothing and ends up white, invisible on light surfaces.
    textTheme: base.textTheme.copyWith(
      displayLarge: AppText.displayLg.copyWith(color: c.onSurface),
      headlineLarge: AppText.headlineLg.copyWith(color: c.onSurface),
      headlineMedium: AppText.headlineMd.copyWith(color: c.onSurface),
      titleLarge: AppText.titleLg.copyWith(color: c.onSurface),
      titleMedium: AppText.titleMd.copyWith(color: c.onSurface),
      bodyLarge: AppText.bodyLg.copyWith(color: c.onSurface),
      bodyMedium: AppText.bodyMd.copyWith(color: c.onSurface),
      bodySmall: AppText.bodySm.copyWith(color: c.onSurface),
      labelLarge: AppText.labelLg.copyWith(color: c.onSurface),
      labelMedium: AppText.labelMd.copyWith(color: c.onSurface),
    ),
    cardTheme: CardThemeData(
      color: c.containerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.xl,
        side: BorderSide(color: c.ghostBorder),
      ),
      margin: EdgeInsets.zero,
      elevation: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.containerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.outlineVariant,
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 8,
      thumbColor: c.onSurface,
      inactiveTrackColor: c.containerHighest,
    ),
    dividerTheme: DividerThemeData(color: c.outlineVariant, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      textStyle: AppText.labelMd,
      decoration: BoxDecoration(
        color: c.containerHigh,
        borderRadius: AppRadii.sm,
        border: Border.all(color: c.ghostBorder),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.containerHigh,
      contentTextStyle: AppText.bodyMd,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: c.container,
      hintStyle: AppText.bodyMd.copyWith(color: c.outline),
    ),
  );
}
