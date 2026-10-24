import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/audio/sound_engine.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../core/i18n/i18n.dart';

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
                Image.asset('assets/icons/app_icon.png', width: 96, height: 96),
                const SizedBox(height: AppSpacing.lg),
                Text('Melody Keeeys', style: AppText.displayLg),
                Text('${tr('app.name')} · ${tr('about.tagline')}',
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
                Text(tr('about.techStack'), style: AppText.titleLg),
                const SizedBox(height: AppSpacing.md),
                _TechRow(
                    icon: Icons.graphic_eq,
                    title: tr('about.audioEngine'),
                    detail:
                        tr('about.audioEngineDetail', {'version': state.engineVersion, 'latency': state.latencyMs?.toStringAsFixed(1)})),
                _TechRow(
                    icon: Icons.keyboard,
                    title: tr('about.keyHook'),
                    detail: tr('about.keyHookDetail')),
                _TechRow(
                    icon: Icons.desktop_windows,
                    title: tr('about.framework'),
                    detail: 'Flutter Desktop（macOS / Windows / Linux）+ tray_manager + window_manager'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              PillButton(
                label: tr('about.licenses'),
                icon: Icons.description_outlined,
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Melody Keeeys',
                  applicationVersion: '0.1.0',
                  applicationIcon: Image.asset('assets/icons/app_icon.png', width: 48, height: 48),
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
