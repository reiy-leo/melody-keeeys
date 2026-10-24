import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_lifecycle.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/audio/sound_engine.dart';
import '../../core/settings/settings_model.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../core/i18n/i18n.dart';

/// 通用 tab: engine core, launch behavior, hotkeys, trigger shaping, test zone.
class GeneralPage extends StatefulWidget {
  const GeneralPage({super.key});

  @override
  State<GeneralPage> createState() => _GeneralPageState();
}

class _GeneralPageState extends State<GeneralPage> with WidgetsBindingObserver {
  final _focus = FocusNode();
  String? _permissionError;

  /// Which System Settings pane the banner's 打开设置 should open.
  String _permissionPane = 'accessibility';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from System Settings after ticking the permission checkbox.
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final detail = await KeyHookChannel.instance.permissionDetail();
    final ax = detail['accessibility'] ?? false;
    if (!mounted) return;
    // The tap is an active pass-through tap, which macOS covers with the
    // Accessibility grant alone; Input Monitoring is not required.
    final granted = Platform.isMacOS
        ? ax
        : await KeyHookChannel.instance.isPermissionGranted();
    setState(() {
      _permissionError = granted ? null : _permissionIssue();
      _permissionPane = 'accessibility';
    });
    // The hook only gets one attempt at launch; retry once TCC is granted,
    // otherwise the banner would clear but keys would still stay silent.
    if (granted && !soundEngine.state.hookRunning) {
      await soundEngine.startHook();
    }
  }

  String? _permissionIssue() {
    if (Platform.isMacOS) {
      return tr('general.permMac');
    }
    if (Platform.isLinux) {
      return tr('general.permLinux');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: soundEngine,
      builder: (context, _) {
        final state = soundEngine.state;
        final settings = state.settings;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_permissionError != null)
                _PermissionBanner(
                  message: _permissionError!,
                  onOpen: () async {
                    await KeyHookChannel.instance.openPermissionSettings(
                      which: _permissionPane,
                    );
                  },
                  onRetry: _checkPermission,
                ),
              SectionCard(
                icon: Icons.settings_input_component,
                title: tr('general.systemTitle'),
                badge: tr('general.coreBadge'),
                subtitle: tr('general.engineStatus', {
                  'latency': state.latencyMs?.toStringAsFixed(1),
                  'version': state.engineVersion,
                }),
                child: Column(
                  children: [
                    SettingsRow(
                      icon: Icons.power_settings_new,
                      title: tr('general.soundEngine'),
                      tooltip: tr('general.soundEngineTip'),
                      trailing: Switch(
                        value: settings.engineEnabled,
                        onChanged: (v) => soundEngine.updateSettings(
                          settings.copyWith(engineEnabled: v),
                        ),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.rocket_launch,
                      title: tr('general.launchAtStartup'),
                      tooltip: tr('general.launchTip'),
                      trailing: Switch(
                        value: settings.launchAtLogin,
                        onChanged: (v) async {
                          await soundEngine.updateSettings(
                            settings.copyWith(launchAtLogin: v),
                          );
                          await appLifecycle.setLaunchAtLogin(v);
                        },
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.brightness_6,
                      title: tr('general.theme'),
                      trailing: _UiThemePicker(current: settings.uiTheme),
                    ),
                    SettingsRow(
                      icon: Icons.translate,
                      title: tr('general.language'),
                      tooltip: tr('general.languageTip'),
                      trailing: _LanguagePicker(current: settings.language),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.keyboard_command_key,
                title: tr('general.hotkeysTitle'),
                badge: tr('general.systemBadge'),
                child: Column(
                  children: [
                    SettingsRow(
                      icon: Icons.notifications_off,
                      title: tr('general.muteHotkey'),
                      tooltip: tr('general.muteTip'),
                      trailing: MetricChip(
                        label: settings.muteHotkey,
                        color: context.colors.primary,
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.swap_horiz,
                      title: tr('general.cycleHotkey'),
                      tooltip: tr('general.cycleTip'),
                      trailing: MetricChip(
                        label: settings.cycleHotkey,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.bolt,
                title: tr('general.antiGhostTitle'),
                badge: tr('general.acousticBadge'),
                child: Column(
                  children: [
                    AppSlider(
                      label: tr('general.antiGhostWindow'),
                      value: settings.antiGhostingMs.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      valueText: '${settings.antiGhostingMs} ms',
                      onChanged: (v) => soundEngine.updateSettings(
                        settings.copyWith(antiGhostingMs: v.round()),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.repeat,
                      title: tr('general.modifierRepeat'),
                      tooltip: tr('general.modifierRepeatTip'),
                      trailing: Switch(
                        value: settings.modifierAutoRepeat,
                        onChanged: (v) => soundEngine.updateSettings(
                          settings.copyWith(modifierAutoRepeat: v),
                        ),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.keyboard_return,
                      title: tr('general.releaseSound'),
                      tooltip: tr('general.releaseSoundTip'),
                      trailing: Switch(
                        value: settings.keyReleaseSound,
                        onChanged: (v) => soundEngine.updateSettings(
                          settings.copyWith(keyReleaseSound: v),
                        ),
                      ),
                    ),
                    if (settings.keyReleaseSound)
                      AppSlider(
                        label: tr('general.releaseVolume'),
                        value: settings.keyReleaseGain,
                        min: 0.1,
                        max: 1.0,
                        valueText:
                            '${(settings.keyReleaseGain * 100).round()}%',
                        accent: context.colors.secondary,
                        onChanged: (v) => soundEngine.updateSettings(
                          settings.copyWith(keyReleaseGain: v),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _AcousticTestZone(
                focus: _focus,
                onReset: () {
                  /* counter resets with engine restart */
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.do_not_disturb_on,
                title: tr('general.smartMuteTitle'),
                badge: tr('general.comingSoon'),
                tooltip: tr('general.smartMuteTip'),
                trailing: const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Spacer(),
                  PillButton(
                    label: tr('general.factoryReset'),
                    icon: Icons.restart_alt,
                    danger: true,
                    onPressed: () async {
                      await soundEngine.resetToDefaults();
                      await appLifecycle.setLaunchAtLogin(
                        soundEngine.state.settings.launchAtLogin,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Light / dark / system three-way segmented picker (pill style).
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final options = <(String, String)>[
      (I18n.system, tr('common.followSystem')),
      for (final code in I18n.languages) (code, I18n.names[code] ?? code),
    ];
    final value = options.any((o) => o.$1 == current) ? current : I18n.system;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colors.containerHighest,
        borderRadius: AppRadii.pill,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: context.colors.containerHigh,
          style: AppText.labelMd.copyWith(color: context.colors.onSurface),
          icon: Icon(
            Icons.expand_more,
            size: 16,
            color: context.colors.onSurfaceVariant,
          ),
          items: [
            for (final (code, label) in options)
              DropdownMenuItem(value: code, child: Text(label)),
          ],
          onChanged: (code) {
            if (code == null || code == current) return;
            soundEngine.updateSettings(
              soundEngine.state.settings.copyWith(language: code),
            );
          },
        ),
      ),
    );
  }
}

class _UiThemePicker extends StatelessWidget {
  const _UiThemePicker({required this.current});

  final UiTheme current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.containerHighest,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in UiTheme.values) ...[
            InkWell(
              onTap: () => soundEngine.updateSettings(
                soundEngine.state.settings.copyWith(uiTheme: mode),
              ),
              borderRadius: AppRadii.pill,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: current == mode
                      ? context.colors.primary
                      : Colors.transparent,
                  borderRadius: AppRadii.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      switch (mode) {
                        UiTheme.light => Icons.light_mode,
                        UiTheme.dark => Icons.dark_mode,
                        UiTheme.system => Icons.settings_suggest,
                      },
                      size: 13,
                      color: current == mode
                          ? context.colors.onPrimary
                          : context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mode.label,
                      style: AppText.labelMd.copyWith(
                        color: current == mode
                            ? context.colors.onPrimary
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (mode != UiTheme.values.last) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({
    required this.message,
    required this.onOpen,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.container,
        borderRadius: AppRadii.md,
        border: Border.all(
          color: context.colors.secondary.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: context.colors.secondary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message, style: AppText.bodyMd)),
          const SizedBox(width: AppSpacing.md),
          PillButton(
            label: tr('general.openSettings'),
            icon: Icons.open_in_new,
            onPressed: onOpen,
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              side: BorderSide(color: context.colors.outlineVariant),
            ),
            child: Text(tr('general.recheck')),
          ),
        ],
      ),
    );
  }
}

class _AcousticTestZone extends StatelessWidget {
  const _AcousticTestZone({required this.focus, required this.onReset});

  final FocusNode focus;
  final VoidCallback onReset;

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
              Icon(
                Icons.monitor_heart,
                size: 18,
                color: context.colors.tertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(tr('general.testPad'), style: AppText.titleLg),
              InfoTip(tr('general.testPadTip')),
              const Spacer(),
              // Only this chip listens to the per-keystroke counter.
              ValueListenableBuilder<int>(
                valueListenable: soundEngine.keystrokes,
                builder: (_, count, _) => MetricChip(
                  label: tr('general.keystrokesTotal', {'n': count}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            focusNode: focus,
            style: AppText.bodyLg,
            decoration: InputDecoration(
              hintText: tr('general.testPadHint'),
              hintStyle: AppText.bodyMd.copyWith(color: context.colors.outline),
              filled: true,
              fillColor: context.colors.container,
              border: OutlineInputBorder(
                borderRadius: AppRadii.md,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
