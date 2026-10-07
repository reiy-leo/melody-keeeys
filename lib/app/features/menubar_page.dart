import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/audio/sound_engine.dart';
import '../../core/settings/settings_model.dart';
import '../../shared/widgets/app_widgets.dart';

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
                title: '点击与手势绑定',
                badge: '原生钩子',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text('左键行为（主要触发方式）', style: AppText.labelLg),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _LeftClickCard(
                            icon: Icons.swap_horiz,
                            title: '轮换下一个音效',
                            subtitle: '立即切换声音配置，无 UI 打扰，快速而带感。',
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
                            title: '显示托盘面板',
                            subtitle: '弹出紧凑的悬浮调音面板：滑杆、音效包与预设。',
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
                      title: '右键上下文菜单',
                      subtitle: '完整的音效包选择、快速面板与设置入口（系统级菜单）',
                      trailing: MetricChip(label: '系统级菜单', color: context.colors.tertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.palette,
                title: '菜单栏图标',
                badge: 'Lucide 图标库',
                subtitle: '从 Lucide 图标库中选择托盘/菜单栏图标',
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
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.tips_and_updates,
                title: '平台提示',
                child: Text(
                  'Linux 部分 DE（GNOME + AppIndicator）下左键会直接打开上下文菜单，'
                  '菜单首项「切换下一个音效」可完成同样的操作。',
                  style: AppText.bodySm.copyWith(color: context.colors.onSurfaceVariant),
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
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppText.bodySm.copyWith(
                  color:
                      selected ? context.colors.onPrimary.withValues(alpha: 0.8) : context.colors.onSurfaceVariant),
            ),
          ],
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
              selected ? '使用中' : '选择',
              style: AppText.labelMd.copyWith(
                  color: selected ? context.colors.success : context.colors.outline),
            ),
          ],
        ),
      ),
    );
  }
}
