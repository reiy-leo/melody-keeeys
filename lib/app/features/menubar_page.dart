import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/audio/sound_engine.dart';
import '../../core/settings/settings_model.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../core/i18n/i18n.dart';

/// 菜单栏 tab: left-click binding, context menu description, tray icon styles.
class MenuBarPage extends StatelessWidget {
  const MenuBarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: soundEngine,
      builder: (context, _) {
        final settings = soundEngine.state.settings;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                icon: Icons.mouse,
                title: tr('menubar.clickTitle'),
                badge: tr('menubar.nativeBadge'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          Text(tr('menubar.leftClick'), style: AppText.labelLg),
                          InfoTip(tr('menubar.linuxTip')),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _LeftClickCard(
                            icon: Icons.swap_horiz,
                            title: tr('menubar.cycleNext'),
                            tooltip: tr('menubar.cycleNextTip'),
                            selected:
                                settings.leftClickAction == TrayLeftClickAction.cycleNext,
                            onTap: () => soundEngine.updateSettings(
                                settings.copyWith(leftClickAction: TrayLeftClickAction.cycleNext)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _LeftClickCard(
                            icon: Icons.layers,
                            title: tr('menubar.showPanel'),
                            tooltip: tr('menubar.showPanelTip'),
                            selected:
                                settings.leftClickAction == TrayLeftClickAction.showHud,
                            onTap: () => soundEngine.updateSettings(
                                settings.copyWith(leftClickAction: TrayLeftClickAction.showHud)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SettingsRow(
                      icon: Icons.menu,
                      title: tr('menubar.contextMenu'),
                      tooltip: tr('menubar.contextMenuTip'),
                      trailing: MetricChip(label: tr('menubar.systemMenu'), color: context.colors.tertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.palette,
                title: tr('menubar.iconTitle'),
                badge: tr('menubar.iconBadge'),
                tooltip: tr('menubar.iconTip'),
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final (id, label) in kTrayIcons)
                      _TrayIconCard(
                        id: id,
                        label: label,
                        selected: settings.trayIcon == id,
                        onTap: () => soundEngine
                            .updateSettings(settings.copyWith(trayIcon: id)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeftClickCard extends StatelessWidget {
  const _LeftClickCard({
    required this.icon,
    required this.title,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.md,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? context.colors.primary.withValues(alpha: 0.9) : context.colors.container,
            borderRadius: AppRadii.md,
            border: Border.all(
                color: selected ? context.colors.primary : context.colors.ghostBorder, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 20,
                      color: selected ? context.colors.onPrimary : context.colors.primary),
                  const Spacer(),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 16,
                    color: selected ? context.colors.onPrimary : context.colors.outline,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title,
                  style: AppText.titleLg.copyWith(
                      color: selected ? context.colors.onPrimary : context.colors.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrayIconCard extends StatelessWidget {
  const _TrayIconCard({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.md,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 108,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? context.colors.container : context.colors.containerLow,
          borderRadius: AppRadii.md,
          border: Border.all(
              color: selected ? context.colors.primary : context.colors.ghostBorder, width: 1.2),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: selected ? 1.0 : 0.55,
              child: Image.asset('assets/icons/tray_${id}_preview.png',
                  width: 40, height: 40),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(label,
                style: AppText.titleMd.copyWith(
                    color: selected ? context.colors.primary : context.colors.onSurface)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              selected ? tr('common.inUse') : tr('common.select'),
              style: AppText.labelMd.copyWith(
                  color: selected ? context.colors.success : context.colors.outline),
            ),
          ],
        ),
      ),
    );
  }
}
