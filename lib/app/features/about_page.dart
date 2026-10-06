import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/audio/sound_engine.dart';
import '../../shared/widgets/app_widgets.dart';

/// 关于 tab: branding, version, tech stack, licenses.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = soundEngine.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: context.colors.containerLow,
              borderRadius: AppRadii.xl,
              border: Border.all(color: context.colors.ghostBorder),
            ),
            child: Column(
              children: [
                Image.asset('assets/icons/tray_256.png', width: 96, height: 96),
                const SizedBox(height: AppSpacing.lg),
                Text('Melody Keeeys', style: AppText.displayLg),
                Text('旋律按键 · 让每一次敲击都有声音',
                    style: AppText.bodyLg.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.md),
                MetricChip(label: 'v0.1.0 · M1-M3', color: context.colors.primary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.containerLow,
              borderRadius: AppRadii.lg,
              border: Border.all(color: context.colors.ghostBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('技术栈', style: AppText.titleLg),
                const SizedBox(height: AppSpacing.md),
                _TechRow(
                    icon: Icons.graphic_eq,
                    title: '音频引擎',
                    detail:
                        'miniaudio ${state.engineVersion} · dart:ffi 直连，内存预解码与复音引擎，输出延迟约 ${state.latencyMs?.toStringAsFixed(1) ?? '--'}ms'),
                _TechRow(
                    icon: Icons.keyboard,
                    title: '全局键盘钩子',
                    detail: 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev（input 组）'),
                _TechRow(
                    icon: Icons.desktop_windows,
                    title: '应用框架',
                    detail: 'Flutter Desktop（macOS / Windows / Linux）+ tray_manager + window_manager'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              PillButton(
                label: '开源许可',
                icon: Icons.description_outlined,
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Melody Keeeys',
                  applicationVersion: '0.1.0',
                  applicationIcon: Image.asset('assets/icons/tray_256.png', width: 48, height: 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TechRow extends StatelessWidget {
  const _TechRow({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.colors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.titleMd),
                Text(detail, style: AppText.bodySm.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
