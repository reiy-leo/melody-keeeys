import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
  bool _hudReady = false;
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
    final existing = _hudController;
    debugPrint('[melody] showHud: ${existing == null ? 'no controller, creating' : 'reusing ${existing.windowId}'}, ready=$_hudReady');
    final controller = _hudController ?? await _createHud();
    // The HUD shows itself once its engine is up ('ready'); showing it from
    // here before that flashes a black window at the default position.
    if (_hudReady) {
      await _placeHud(controller);
      await controller.show();
    }
    await _pushStateToHud();
  }

  /// Called by the HUD isolate after its first frame; from then on the window
  /// can be shown/hidden from this side safely.
  Future<void> markHudReady() async {
    debugPrint('[melody] HUD ready');
    _hudReady = true;
    await _pushStateToHud();
  }

  Future<void> _placeHud(WindowController controller) async {
    final bounds = TrayService.instance.bounds;
    if (bounds == null || bounds.isEmpty) return;
    try {
      await controller.invokeMethod('hudState', jsonEncode({
        'kind': 'place',
        'bounds': {
          'x': bounds.left, 'y': bounds.top,
          'w': bounds.width, 'h': bounds.height,
        },
      }));
    } catch (e) {
      debugPrint('[melody] place failed: $e');
    }
  }

  Future<WindowController> _createHud() async {
    final state = soundEngine.state;
    final bounds = TrayService.instance.bounds;
    debugPrint('[melody] create HUD, tray bounds: $bounds');
    _hudReady = false;
    final config = WindowConfiguration(
      arguments: jsonEncode({
        'settings': state.settings.toJson(),
        'latencyMs': state.latencyMs,
        if (_soundDir != null) 'soundDir': _soundDir,
        if (bounds != null && !bounds.isEmpty)
          'bounds': {
            'x': bounds.left,
            'y': bounds.top,
            'w': bounds.width,
            'h': bounds.height,
          },
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
      // A successful push proves the HUD engine is up; treat it as ready even
      // if the 'ready' message itself was lost.
      _hudReady = true;
    } catch (e) {
      // Channel errors happen while the HUD engine is still booting; only
      // drop the controller when the window is actually gone, otherwise a
      // fresh window gets created on every click.
      debugPrint('[melody] pushState failed: $e');
      try {
        final all = await WindowController.getAll();
        final alive = all.any((w) => w.windowId == controller.windowId);
        if (!alive) {
          debugPrint('[melody] HUD window gone; dropping controller');
          _hudController = null;
          _hudReady = false;
        }
      } catch (_) {/* keep the controller */}
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
