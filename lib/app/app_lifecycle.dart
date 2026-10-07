import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import '../core/audio/sound_engine.dart';
import '../core/tray/tray_service.dart';
/// App-wide lifecycle glue: settings window visibility, the tray HUD window,
/// login item and quit. Widgets/pages reach it through [appLifecycle].
class AppLifecycle with WindowListener {
  AppLifecycle._();
  static final AppLifecycle instance = AppLifecycle._();

  WindowController? _hudController;
  bool _quitting = false;

  /// Called by main() after the engine is ready.
  Future<void> init({required bool silentStart}) async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    if (silentStart) {
      await windowManager.hide();
    } else {
      await showSettingsWindow();
    }
    soundEngine.addListener(_onEngineChanged);
  }

  void _onEngineChanged() {
    TrayService.instance.rebuildMenu();
    _pushStateToHud();
  }

  Future<void> showSettingsWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  // ---- HUD window ----

  Future<void> showHud() async {
    final controller = _hudController ?? await _createHud();
    // Position before showing so it never flashes at the default spot.
    final bounds = TrayService.instance.bounds;
    if (bounds != null) {
      try {
        await controller.invokeMethod('hudState', jsonEncode({
          'kind': 'place',
          'bounds': {
            'x': bounds.left, 'y': bounds.top,
            'w': bounds.width, 'h': bounds.height,
          },
        }));
      } catch (_) {}
    }
    await controller.show();
    await _pushStateToHud();
  }

  Future<WindowController> _createHud() async {
    final state = soundEngine.state;
    final config = WindowConfiguration(
      arguments: jsonEncode({
        'settings': state.settings.toJson(),
        'latencyMs': state.latencyMs,
        if (_soundDir != null) 'soundDir': _soundDir,
      }),
      hiddenAtLaunch: true,
    );
    final controller = await WindowController.create(config);
    _hudController = controller;
    return controller;
  }

  String? _soundDir;

  /// Sound files live here; the HUD isolate loads its own preview engine.
  set soundDir(String? path) => _soundDir = path;

  Future<void> _pushStateToHud() async {
    final controller = _hudController;
    if (controller == null) return;
    final state = soundEngine.state;
    try {
      await controller.invokeMethod('hudState', jsonEncode({
        'kind': 'applyState',
        'settings': state.settings.toJson(),
        'latencyMs': state.latencyMs,
      }));
    } catch (_) {
      // HUD window closed; drop the stale controller.
      _hudController = null;
    }
  }

  // ---- Login item ----

  Future<void> setLaunchAtLogin(bool enabled) async {
    try {
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (_) {
      // Best-effort; settings UI reflects the stored preference regardless.
    }
  }

  // ---- WindowListener ----

  @override
  void onWindowClose() async {
    // Settings window close = hide to tray, never exit.
    if (!_quitting) {
      await windowManager.hide();
    }
  }

  @override
  void onWindowFocus() {
    // Keep the sidebar/settings in sync after returning to the window.
  }

  // ---- Quit ----

  Future<void> quit() async {
    _quitting = true;
    TrayService.instance.dispose();
    soundEngine.dispose();
    exit(0);
  }
}

final AppLifecycle appLifecycle = AppLifecycle.instance;
