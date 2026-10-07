import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/audio/audio_engine_ffi.dart';
import '../../core/audio/sound_pack.dart';
import '../../core/settings/settings_model.dart';

const _hudSize = Size(340, 560);

/// Entry for the second window process created by desktop_multi_window.
Future<void> runHudWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.setAsFrameless();
  await windowManager.setSize(_hudSize);
  await windowManager.setMinimumSize(_hudSize);
  await windowManager.setMaximumSize(Size(_hudSize.width + 40, _hudSize.height + 40));
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setSkipTaskbar(true);

  final controller = await WindowController.fromCurrentEngine();
  final arguments = controller.arguments.isEmpty ? '{}' : controller.arguments;
  final args = jsonDecode(arguments) as Map<String, dynamic>;

  // Own preview engine instance for this isolate (shares the output device).
  AudioEngineFfi? previewEngine;
  try {
    final soundDir = args['soundDir'] as String?;
    if (soundDir != null) {
      previewEngine = AudioEngineFfi.open();
      previewEngine.init(preset: 1);
      previewEngine.loadAllPacks(soundDir);
    }
  } catch (_) {
    previewEngine = null;
  }

  runApp(HudApp(
    controller: controller,
    initialSettings: AppSettings.fromJson(
        (args['settings'] as Map<String, dynamic>?) ?? const {}),
    initialLatencyMs: (args['latencyMs'] as num?)?.toDouble(),
    previewEngine: previewEngine,
  ));
}

class HudApp extends StatelessWidget {
  const HudApp({
    super.key,
    required this.controller,
    required this.initialSettings,
    required this.initialLatencyMs,
    required this.previewEngine,
  });

  final WindowController controller;
  final AppSettings initialSettings;
  final double? initialLatencyMs;
  final AudioEngineFfi? previewEngine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: initialSettings.uiTheme.themeMode,
      home: HudWindow(
        controller: controller,
        initialSettings: initialSettings,
        initialLatencyMs: initialLatencyMs,
        previewEngine: previewEngine,
      ),
    );
  }
}

class HudWindow extends StatefulWidget {
  const HudWindow({
    super.key,
    required this.controller,
    required this.initialSettings,
    required this.initialLatencyMs,
    required this.previewEngine,
  });

  final WindowController controller;
  final AppSettings initialSettings;
  final double? initialLatencyMs;
  final AudioEngineFfi? previewEngine;

  @override
  State<HudWindow> createState() => _HudWindowState();
}

class _HudWindowState extends State<HudWindow> with WindowListener {
  AppSettings _settings = const AppSettings();
  double? _latencyMs;
  WindowController? _mainWindow;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _latencyMs = widget.initialLatencyMs;
    windowManager.addListener(this);
    widget.controller.setWindowMethodHandler((call) async {
      if (call.method == 'hudState') {
        final data =
            jsonDecode(call.arguments as String? ?? '{}') as Map<String, dynamic>;
        if (!mounted) return null;
        switch (data['kind']) {
          case 'place':
            final b = data['bounds'] as Map<String, dynamic>?;
            if (b != null) await _place(b);
          case 'applyState':
            setState(() {
              _settings = AppSettings.fromJson(
                  (data['settings'] as Map<String, dynamic>?) ?? const {});
              _latencyMs = (data['latencyMs'] as num?)?.toDouble();
            });
        }
      }
      return null;
    });
    _findMainWindow();
  }

  /// Position under the menu bar (macOS) or above the taskbar tray icon,
  /// using the tray icon bounds sent from the main window.
  Future<void> _place(Map<String, dynamic> b) async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screen = view.physicalSize / view.devicePixelRatio;
    final w = (b['w'] as num).toDouble();
    final h = (b['h'] as num).toDouble();
    final trayOnBottom = (b['y'] as num).toDouble() > screen.height / 2;
    var x = (b['x'] as num).toDouble() + w / 2 - _hudSize.width / 2;
    x = x.clamp(8.0, screen.width - _hudSize.width - 8);
    final y = trayOnBottom
        ? (b['y'] as num).toDouble() - _hudSize.height - 6
        : (b['y'] as num).toDouble() + h + 6;
    await windowManager.setPosition(Offset(x, y));
  }

  Future<void> _findMainWindow() async {
    try {
      final all = await WindowController.getAll();
      _mainWindow = all.firstWhere(
        (w) => w.windowId != widget.controller.windowId,
        orElse: () => all.first,
      );
    } catch (_) {
      _mainWindow = null;
    }
  }

  Future<void> _command(String action, [Map<String, dynamic>? extra]) async {
    final payload = jsonEncode({'action': action, ...?extra});
    try {
      await _mainWindow?.invokeMethod('hudCommand', payload);
    } catch (_) {}
  }

  void _preview(SoundPack pack) {
    if (widget.previewEngine != null) {
      final idx = kBuiltinPacks.indexOf(pack).clamp(0, kBuiltinPacks.length - 1);
      widget.previewEngine!.play(SoundLayer.alpha,
          packIndex: idx, gain: 1.0, pitch: _settings.layerPitch('alpha'));
    }
    _command('preview', {'packId': pack.id});
  }

  @override
  void onWindowBlur() {
    // Tray-HUD convention: dismiss on losing focus.
    widget.controller.hide();
  }

  @override
  Widget build(BuildContext context) {
    final pack = packById(_settings.activePackId);
    // Resolve the pushed uiTheme against the OS brightness so the HUD follows
    // live changes from the main window (the MaterialApp ancestor stays on
    // ThemeMode.system).
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = switch (_settings.uiTheme) {
      UiTheme.light => false,
      UiTheme.dark => true,
      UiTheme.system => platformDark,
    };
    return Theme(
      data: buildAppTheme(isDark ? Brightness.dark : Brightness.light),
      child: Scaffold(
      backgroundColor: context.colors.containerHigh.withValues(alpha: 0.96),
      body: Container(
        decoration: BoxDecoration(
          color: context.colors.containerHigh,
          borderRadius: AppRadii.lg,
          border: Border.all(color: context.colors.ghostBorder),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.piano, size: 18, color: context.colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Melody Keeeys', style: AppText.titleLg),
                const Spacer(),
                Text('TRAY HUD', style: AppText.labelMd.copyWith(color: context.colors.outline)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.container,
                borderRadius: AppRadii.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _settings.engineEnabled ? context.colors.tertiary : context.colors.outline,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _settings.engineEnabled
                          ? 'AUDIO ENGINE ACTIVE  ${_latencyMs?.toStringAsFixed(1) ?? '--'}ms'
                          : 'AUDIO ENGINE MUTED',
                      style: AppText.labelMd.copyWith(color: context.colors.tertiary),
                    ),
                  ),
                  Switch(
                    value: _settings.engineEnabled,
                    onChanged: (_) => _command('toggleEngine'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colors.container,
                borderRadius: AppRadii.md,
                border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('正在使用',
                                style: AppText.labelMd
                                    .copyWith(color: context.colors.success)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(pack.name,
                                  style: AppText.headlineMd,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _TagChip(pack.tag),
                          ],
                        ),
                        Text(pack.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodySm.copyWith(color: context.colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    height: 34,
                    child: FilledButton.icon(
                      onPressed: () => _preview(pack),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.containerHighest,
                        foregroundColor: context.colors.primary,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.graphic_eq, size: 14),
                      label: const Text('Strike', style: AppText.labelMd),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < kBuiltinPacks.length; i++)
                      _HudPackRow(
                        index: i + 1,
                        pack: kBuiltinPacks[i],
                        active: kBuiltinPacks[i].id == _settings.activePackId,
                        onSelect: () => _command('selectPack', {'packId': kBuiltinPacks[i].id}),
                        onPreview: () => _preview(kBuiltinPacks[i]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 34,
              child: OutlinedButton.icon(
                onPressed: () => _command('openSettings'),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: BorderSide(color: context.colors.outlineVariant),
                ),
                icon: const Icon(Icons.settings, size: 14),
                label: Text('打开设置…', style: AppText.labelMd),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: AppRadii.pill,
      ),
      child: Text(text, style: AppText.labelMd.copyWith(color: context.colors.primary)),
    );
  }
}

class _HudPackRow extends StatelessWidget {
  const _HudPackRow({
    required this.index,
    required this.pack,
    required this.active,
    required this.onSelect,
    required this.onPreview,
  });

  final int index;
  final SoundPack pack;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: AppRadii.md,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
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
              child: Row(
                children: [
                  Flexible(
                    child: Text(pack.name,
                        style: AppText.titleMd,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TagChip(pack.tag),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (active)
              Icon(Icons.check_circle, size: 16, color: context.colors.success)
            else
              SizedBox(
                width: 26,
                height: 26,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  onPressed: onPreview,
                  icon: const Icon(Icons.play_arrow),
                  color: context.colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
