import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/audio/sound_engine.dart';
import '../core/settings/settings_model.dart';
import 'features/about_page.dart';
import 'features/general_page.dart';
import 'features/menubar_page.dart';
import 'features/sound_effects_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

/// Root of the settings window: draggable frameless shell + sidebar nav.
class SettingsApp extends StatelessWidget {
  const SettingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: soundEngine,
      builder: (context, _) {
        final settings = soundEngine.state.settings;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: settings.uiTheme.themeMode,
          home: const SettingsWindow(),
        );
      },
    );
  }
}

enum SettingsTab { general, sounds, menuBar, about }

class SettingsWindow extends StatefulWidget {
  const SettingsWindow({super.key});

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> with WindowListener {
  SettingsTab _tab = SettingsTab.general;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: soundEngine,
      builder: (context, _) {
        final state = soundEngine.state;
        return Scaffold(
          // Full-height sidebar on the left (macOS traffic lights sit over its
          // top), header only over the content column with chips right-aligned.
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(tab: _tab, onSelect: (t) => setState(() => _tab = t)),
              Container(width: 1, color: context.colors.outlineVariant),
              Expanded(
                child: Column(
                  children: [
                    // Header: logo left, status chips right. Draggable.
                    GestureDetector(
                      onPanStart: (_) => windowManager.startDragging(),
                      child: Container(
                        height: 44,
                        color: context.colors.containerLow,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: context.colors.container,
                                borderRadius: AppRadii.sm,
                                border: Border.all(
                                  color: context.colors.ghostBorder,
                                ),
                              ),
                              child: Icon(
                                Icons.piano,
                                size: 16,
                                color: context.colors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Melody Keeeys', style: AppText.titleMd),
                                Text(
                                  '旋律按键',
                                  style: AppText.bodySm.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            _StatusChip(
                              label:
                                  '延迟 ${state.latencyMs?.toStringAsFixed(1) ?? '--'}ms',
                              color: state.hookRunning
                                  ? context.colors.tertiary
                                  : context.colors.error,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _StatusChip(
                              label: state.hookRunning ? '钩子运行中' : '钩子未运行',
                              color: state.hookRunning
                                  ? context.colors.success
                                  : context.colors.error,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _StatusChip(
                              label:
                                  '${state.settings.volumeDb.toStringAsFixed(0)} dB',
                              color: context.colors.secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 1, color: context.colors.outlineVariant),
                    Expanded(child: _buildPage()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage() {
    return switch (_tab) {
      SettingsTab.general => const GeneralPage(),
      SettingsTab.sounds => const SoundEffectsPage(),
      SettingsTab.menuBar => const MenuBarPage(),
      SettingsTab.about => const AboutPage(),
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.container,
        borderRadius: AppRadii.pill,
        border: Border.all(color: context.colors.ghostBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.labelMd),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.tab, required this.onSelect});

  final SettingsTab tab;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final state = soundEngine.state;
    // Full-height column; the top strip is left clear for the macOS traffic
    // lights, which align with the nav icon column right below.
    return Container(
      width: 216,
      color: context.colors.containerLow,
      child: GestureDetector(
        onPanStart: (_) => windowManager.startDragging(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Traffic lights zone; keep tabs close beneath them.
            const SizedBox(height: 34),
            _NavItem(
              icon: Icons.graphic_eq,
              label: '通用',
              selected: tab == SettingsTab.general,
              onTap: () => onSelect(SettingsTab.general),
            ),
            _NavItem(
              icon: Icons.volume_up,
              label: '音效',
              selected: tab == SettingsTab.sounds,
              onTap: () => onSelect(SettingsTab.sounds),
            ),
            _NavItem(
              icon: Icons.window,
              label: '菜单栏',
              selected: tab == SettingsTab.menuBar,
              onTap: () => onSelect(SettingsTab.menuBar),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colors.container,
                borderRadius: AppRadii.md,
                border: Border.all(color: context.colors.ghostBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '引擎状态',
                        style: AppText.labelMd.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        state.settings.engineEnabled && state.hookRunning
                            ? Icons.circle
                            : Icons.circle_outlined,
                        size: 8,
                        color: state.settings.engineEnabled && state.hookRunning
                            ? context.colors.success
                            : context.colors.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.settings.engineEnabled && state.hookRunning
                            ? '运行中'
                            : '停止',
                        style: AppText.labelMd.copyWith(
                          color:
                              state.settings.engineEnabled && state.hookRunning
                              ? context.colors.success
                              : context.colors.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('引擎 ${state.engineVersion}', style: AppText.bodySm),
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: () => onSelect(SettingsTab.about),
                    borderRadius: AppRadii.sm,
                    child: Text(
                      '关于',
                      style: AppText.labelLg.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      child: Material(
        color: selected ? context.colors.primary : Colors.transparent,
        borderRadius: AppRadii.pill,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pill,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                // Icon column centers under the first traffic light (~x26).
                const SizedBox(width: 5),
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? context.colors.onPrimary
                      : context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  label,
                  style: AppText.titleMd.copyWith(
                    color: selected
                        ? context.colors.onPrimary
                        : context.colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
