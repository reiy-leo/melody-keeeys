import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_lifecycle.dart';
import 'app/settings_app.dart';
import 'core/audio/sound_engine.dart';
import 'core/settings/settings_repository.dart';
import 'core/system/hotkey_service.dart';
import 'core/tray/tray_service.dart';
import 'features/hud/hud_window.dart';

const _kMultiWindowArg = 'multi_window';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Second-window entry point (tray HUD), launched by desktop_multi_window.
  if (args.isNotEmpty && args.first == _kMultiWindowArg) {
    await runHudWindow();
    return;
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1020, 700),
      minimumSize: Size(880, 580),
      center: true,
      title: 'Melody Keeeys · 旋律按键',
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      // Window stays hidden until settings load decides (silent start).
    },
  );

  soundEngine = SoundEngine(SettingsRepository());
  await soundEngine.initialize();
  // The HUD isolate loads its own preview engine from the extracted WAVs.
  appLifecycle.soundDir = soundEngine.soundDir;

  launchAtStartup.setup(
    appName: 'Melody Keeeys',
    appPath: Platform.resolvedExecutable,
  );

  await appLifecycle.init(silentStart: soundEngine.state.settings.silentStart);
  await TrayService.instance.init();

  await HotkeyService.instance.register(soundEngine.state.settings);

  // Cross-window command handler: HUD -> main. Deferred so the
  // desktop_multi_window channel is fully attached on the main engine.
  Future.delayed(const Duration(seconds: 1), () async {
    try {
      final controller = await WindowController.fromCurrentEngine();
      controller.setWindowMethodHandler((call) async {
        if (call.method != 'hudCommand') return null;
        final payload = jsonDecode(call.arguments as String? ?? '{}') as Map<String, dynamic>;
        switch (payload['action']) {
          case 'selectPack':
            await soundEngine.selectPack(payload['packId'] as String);
          case 'toggleEngine':
            await soundEngine.toggleEngine();
          case 'preview':
            soundEngine.previewPack(payload['packId'] as String);
          case 'openSettings':
            await appLifecycle.showSettingsWindow();
        }
        return null;
      });
    } catch (_) {
      // Cross-window channel unavailable; HUD still works read-only.
    }
  });

  runApp(const SettingsApp());
}
