import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/audio/sound_engine.dart';
import '../../core/audio/sound_pack.dart';
import '../../core/settings/settings_model.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../core/i18n/i18n.dart';

/// 音效 tab: pack list, active pack detail with layer tones, DSP engine, sandbox.
class SoundEffectsPage extends StatelessWidget {
  const SoundEffectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: soundEngine,
      builder: (context, _) {
        final state = soundEngine.state;
        final settings = state.settings;
        // Fixed-height page: the pack list scrolls on its own so the active
        // pack, DSP and sandbox cards stay put while browsing packs.
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.loadError != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.colors.container,
                    borderRadius: AppRadii.md,
                    border: Border.all(color: context.colors.error.withValues(alpha: 0.4)),
                  ),
                  child: Text(state.loadError!, style: AppText.bodySm.copyWith(color: context.colors.error)),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Switch profiles list (independently scrollable)
                    Expanded(
                      flex: 2,
                      child: SectionCard(
                        icon: Icons.list_alt,
                        title: tr('sounds.listTitle'),
                        badge: tr('sounds.loadedBadge', {'n': kBuiltinPacks.length}),
                        expand: true,
                        child: ListView.builder(
                          primary: false,
                          itemCount: kBuiltinPacks.length,
                          itemBuilder: (context, i) => _PackTile(
                            index: i + 1,
                            pack: kBuiltinPacks[i],
                            active: kBuiltinPacks[i].id == settings.activePackId,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    // Active pack detail
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        primary: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ActivePackDetail(pack: state.activePack),
                            const SizedBox(height: AppSpacing.lg),
                            _DspEngine(settings: settings),
                            const SizedBox(height: AppSpacing.lg),
                            _Sandbox(enabled: settings.engineEnabled),
                          ],
                        ),
                      ),
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

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.index,
    required this.pack,
    required this.active,
  });

  final int index;
  final SoundPack pack;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: active ? context.colors.containerHigh : context.colors.container,
        borderRadius: AppRadii.md,
        border: Border.all(
            color: active ? context.colors.primary.withValues(alpha: 0.5) : context.colors.ghostBorder),
      ),
      child: Row(
        children: [
          Text('$index'.padLeft(2, '0'),
              style: AppText.mono.copyWith(
                  color: active ? context.colors.primary : context.colors.outline)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Chinese name leads and keeps its full width; the English
                    // original is the part that yields when space runs short.
                    // Pack description lives in a hover tooltip on the name.
                    Tooltip(
                      message: pack.displayDescription,
                      waitDuration: const Duration(milliseconds: 250),
                      child: Text(pack.displayName, style: AppText.titleMd),
                    ),
                    if (pack.displayTag != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: AppRadii.pill,
                        ),
                        child: Text(pack.displayTag!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.labelMd.copyWith(color: context.colors.primary)),
                      ),
                    ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (active) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.check_circle, size: 18, color: context.colors.success),
          ],
          const SizedBox(width: AppSpacing.sm),
          _RoundIconBtn(
            icon: Icons.play_arrow,
            tooltip: tr('common.preview'),
            onPressed: () => soundEngine.previewPack(pack.id),
          ),
          if (!active)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: _RoundIconBtn(
                icon: Icons.check,
                tooltip: tr('sounds.switchTo'),
                onPressed: () => soundEngine.selectPack(pack.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.tooltip, this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 30,
        height: 30,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            backgroundColor: context.colors.containerHighest,
            foregroundColor: context.colors.onSurface,
            shape: const CircleBorder(),
          ),
          child: Icon(icon, size: 15),
        ),
      ),
    );
  }
}

class _ActivePackDetail extends StatelessWidget {
  const _ActivePackDetail({required this.pack});

  final SoundPack pack;

  static const _layers = ['alpha', 'space', 'enter', 'modifier', 'nav'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: soundEngine,
      builder: (context, _) {
        final settings = soundEngine.state.settings;
        return SectionCard(
          icon: Icons.equalizer,
          title: pack.displayName,
          badge: tr('common.inUse'),
          tooltip: pack.displayDescription,
          trailing: PillButton(
            label: tr('common.preview'),
            icon: Icons.graphic_eq,
            onPressed: () => soundEngine.previewPack(pack.id),
          ),
          child: Column(
            children: [
              for (final layer in _layers)
                AppSlider(
                  label: tr('layer.$layer'),
                  value: settings.layerTones[layer] ?? 0.5,
                  min: 0,
                  max: 1,
                  valueText: '${(((settings.layerTones[layer] ?? 0.5) - 0.5) * 100).round()}%',
                  onChanged: (v) => soundEngine.updateSettings(
                    settings.copyWith(
                      layerTones: {...settings.layerTones, layer: v},
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DspEngine extends StatelessWidget {
  const _DspEngine({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.tune,
      title: tr('sounds.dspTitle'),
      trailing: GestureDetector(
        onTap: () => soundEngine.resetToDefaults(),
        child: Text(tr('common.resetDefault'), style: AppText.labelMd.copyWith(color: context.colors.outline)),
      ),
      child: Column(
        children: [
          AppSlider(
            label: tr('sounds.volume'),
            value: settings.volumeDb,
            min: -12,
            max: 6,
            valueText: '${settings.volumeDb >= 0 ? '+' : ''}${settings.volumeDb.toStringAsFixed(1)} dB',
            onChanged: (v) =>
                soundEngine.updateSettings(settings.copyWith(volumeDb: v)),
          ),
          AppSlider(
            label: tr('sounds.pitchJitter'),
            value: settings.pitchJitter,
            min: 0,
            max: 0.5,
            valueText: '${(settings.pitchJitter * 100).round()}%',
            accent: context.colors.secondary,
            onChanged: (v) =>
                soundEngine.updateSettings(settings.copyWith(pitchJitter: v)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final preset in LatencyPreset.values) ...[
                Expanded(
                  child: _PresetChip(
                    label: preset.label,
                    selected: settings.latencyPreset == preset,
                    onTap: () => soundEngine
                        .updateSettings(settings.copyWith(latencyPreset: preset)),
                  ),
                ),
                if (preset != LatencyPreset.values.last) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.pill,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: selected ? context.colors.container : context.colors.containerHighest,
          borderRadius: AppRadii.pill,
          border: Border.all(
              color: selected ? context.colors.tertiary.withValues(alpha: 0.6) : context.colors.ghostBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.labelMd.copyWith(
              color: selected ? context.colors.tertiary : context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Sandbox extends StatefulWidget {
  const _Sandbox({required this.enabled});

  final bool enabled;

  @override
  State<_Sandbox> createState() => _SandboxState();
}

class _SandboxState extends State<_Sandbox> {
  final _controller = TextEditingController();
  int _count = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              Icon(Icons.keyboard, size: 18, color: context.colors.tertiary),
              const SizedBox(width: AppSpacing.sm),
              Text(tr('sounds.testBench'), style: AppText.titleLg),
              const Spacer(),
              MetricChip(label: tr('sounds.boxKeystrokes', {'n': _count})),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            enabled: widget.enabled,
            maxLines: 3,
            style: AppText.bodyLg,
            decoration: InputDecoration(
              hintText: widget.enabled
                  ? tr('sounds.testHint')
                  : tr('sounds.engineOffHint'),
              hintStyle: AppText.bodyMd.copyWith(color: context.colors.outline),
              filled: true,
              fillColor: context.colors.container,
              border: OutlineInputBorder(borderRadius: AppRadii.md, borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() => _count++),
          ),
        ],
      ),
    );
  }
}
