import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
import 'shared/debug_screenshot.dart';

const _kMultiWindowArg = 'multi_window';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Second-window entry point (tray HUD), launched by desktop_multi_window.
  if (args.isNotEmpty && args.first == _kMultiWindowArg) {
    await runHudWindow();
    return;
  }

  if (kNativeHost) {
    await _runHostedSettings();
    return;
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1020, 700),
      minimumSize: Size(880, 580),
      center: true,
      title: 'Melody Keeeys · 旋律键音',
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      // Window stays hidden until settings load decides (silent start).
    },
  );

  soundEngine = SoundEngine(SettingsRepository());
  await soundEngine.initialize();

  launchAtStartup.setup(
    appName: 'Melody Keeeys',
    appPath: Platform.resolvedExecutable,
  );

  // Menu-bar only at launch. The settings window opens by itself only when
  // the key hook could not start (missing Accessibility / input permission),
  // since that page is where the user grants it.
  await appLifecycle.init(showSettings: !soundEngine.state.hookRunning);
  await TrayService.instance.init();

  await HotkeyService.instance.register(soundEngine.state.settings);

  // Cross-window command handler: HUD -> main. Deferred so the
  // desktop_multi_window channel is fully attached on the main engine.
  Future.delayed(const Duration(seconds: 1), () async {
    try {
      final controller = await WindowController.fromCurrentEngine();
      controller.setWindowMethodHandler((call) async {
        if (call.method != 'hudCommand') return null;
        final payload = jsonDecode(
          call.arguments as String? ?? '{}',
        ) as Map<String, dynamic>;
        switch (payload['action']) {
          case 'selectPack':
            await soundEngine.selectPack(payload['packId'] as String);
          case 'toggleEngine':
            await soundEngine.toggleEngine();
          case 'preview':
            soundEngine.previewPack(payload['packId'] as String);
          case 'openSettings':
            await appLifecycle.showSettingsWindow();
          case 'ready':
            await appLifecycle.markHudReady();
          case 'hudDisposed':
            appLifecycle.forgetHud();
        }
        return null;
      });
    } catch (_) {
      // Cross-window channel unavailable; HUD still works read-only.
    }
  });

  runApp(
    kDebugMode && _kScreenshotMode
        ? const ScreenshotHost(child: SettingsApp())
        : const SettingsApp(),
  );
}

/// macOS: this engine exists only while the settings window is open; the
/// native host (menu bar, key hook, audio, hotkeys, tray panel) started it
/// and shuts it down when the window closes.
Future<void> _runHostedSettings() async {
  // Every step is guarded: a failing plugin call must not stop the UI from
  // running, or the settings window would stay blank or never appear.
  Future<void> step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      debugPrint('[settings] $name failed: $e\n$st');
    }
  }

  await step('windowManager', () async {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        // No size/center: the host keeps the window and its last frame.
        minimumSize: Size(880, 580),
        title: 'Melody Keeeys · 旋律键音',
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {},
    );
  });

  soundEngine = SoundEngine(SettingsRepository());
  await step('soundEngine', soundEngine.initialize);

  launchAtStartup.setup(
    appName: 'Melody Keeeys',
    appPath: Platform.resolvedExecutable,
  );

  await step('appLifecycle', () => appLifecycle.init(showSettings: true));
  runApp(
    kDebugMode && _kScreenshotMode
        ? const ScreenshotHost(child: SettingsApp())
        : const SettingsApp(),
  );

  // Order the window front once it has painted (no blank flash); the
  // timeout covers a hidden window that gets no vsync. The native host also
  // shows the window on its own if this never arrives.
  var shown = false;
  Future<void> show() async {
    if (shown) return;
    shown = true;
    await step('show', appLifecycle.showSettingsWindow);
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => show());
  Future.delayed(const Duration(milliseconds: 600), show);
}

/// Set with `--dart-define=MELODY_SCREENSHOTS=true` (debug builds only):
/// wraps the app so README screenshots can be rendered from Flutter's own
/// tree without the macOS screen-recording permission.
final bool _kScreenshotMode = const bool.fromEnvironment('MELODY_SCREENSHOTS');
