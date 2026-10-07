import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Rounded section card with an icon chip + title, matching the prototype's
/// tonal containers with ghost borders.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.badge,
    this.subtitle,
    this.trailing,
    this.expand = false,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? badge;
  final String? subtitle;
  final Widget? trailing;

  /// When true the child fills the card's remaining height (the card itself
  /// must be in a bounded-height context). Used for independently scrolling
  /// list bodies inside fixed-height pages.
  final bool expand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.containerLow,
        borderRadius: AppRadii.lg,
        border: Border.all(color: context.colors.ghostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.colors.container,
                  borderRadius: AppRadii.sm,
                  border: Border.all(color: context.colors.ghostBorder),
                ),
                child: Icon(icon, size: 18, color: context.colors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: AppText.titleLg),
                        if (badge != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          _Badge(badge!),
                        ],
                      ],
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: AppText.bodySm.copyWith(
                            color: context.colors.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: AppRadii.pill,
      ),
      child: Text(text, style: AppText.labelMd.copyWith(color: context.colors.primary)),
    );
  }
}

/// A titled row with optional subtitle, icon and a trailing control.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleMd),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          style: AppText.bodySm.copyWith(color: context.colors.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],        ),
      ),
    );
  }
}

/// Slider with an upper label row (label left, mono value badge right).
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueText,
    required this.onChanged,
    this.divisions,
    this.accent,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueText;
  final ValueChanged<double> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? context.colors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppText.labelLg),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.containerHighest,
                borderRadius: AppRadii.pill,
              ),
              child: Text(valueText,
                  style: AppText.mono.copyWith(color: accentColor)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            inactiveTrackColor: context.colors.containerHighest,
          ),
          child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged),
        ),
      ],
    );
  }
}

/// Primary filled pill button.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? context.colors.containerHighest : context.colors.primary;
    final fg = danger ? context.colors.error : context.colors.onPrimary;
    final iconWidget = icon != null ? Icon(icon, size: 16) : null;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
        textStyle: AppText.labelLg,
      ),
      icon: iconWidget,
      label: Text(label),
    );
  }
}

/// Small latency/metric readout chip, e.g. "0.8ms".
class MetricChip extends StatelessWidget {
  const MetricChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.container,
        borderRadius: AppRadii.pill,
        border: Border.all(color: context.colors.ghostBorder),
      ),
      child: Text(label, style: AppText.mono.copyWith(color: color ?? context.colors.tertiary)),
    );
  }
}
