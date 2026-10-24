import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter/painting.dart' show PaintingBinding, Rect, Size;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import '../core/audio/sound_engine.dart';
import '../core/tray/tray_service.dart';

/// App-wide lifecycle glue: settings window visibility, the tray HUD window,
/// login item and quit. Widgets/pages reach it through [appLifecycle].
///
/// On macOS ([kNativeHost]) this engine *is* the settings window: it shows
/// itself once, and closing it asks the native host to shut the engine down.
/// Tray, HUD and quit belong to the host there.
class AppLifecycle with WindowListener {
  AppLifecycle._();
  static final AppLifecycle instance = AppLifecycle._();

  WindowController? _hudController;

  /// Whether the settings UI is mounted. While the window is hidden the whole
  /// MaterialApp is swapped for an empty box (see SettingsApp), so a
  /// menu-bar-only session doesn't keep the widget/render trees, text layout
  /// caches and decoded images of four settings pages alive.
  final ValueNotifier<bool> settingsVisible = ValueNotifier<bool>(false);

  /// Frame of the settings window before it was parked (see [_parkSettings]).
  Rect? _settingsFrame;
  static const Size _settingsMinSize = Size(880, 580);
  static const Size _parkedSize = Size(64, 64);
  bool _hudReady = false;
  bool _quitting = false;

  /// Called by main() after the engine is ready.
  Future<void> init({required bool showSettings}) async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    if (kNativeHost) {
      settingsVisible.value = true;
      return;
    }
    if (showSettings) {
      await showSettingsWindow();
    } else {
      await _parkSettings();
    }
    soundEngine.addListener(_onEngineChanged);
  }

  void _onEngineChanged() {
    TrayService.instance.rebuildMenu();
    _pushStateToHud();
  }

  /// Last payload delivered to the HUD; identical states are not re-sent
  /// (slider drags notify every frame, most of them change nothing the HUD
  /// shows twice).
  String? _lastHudPayload;

  Future<void> showSettingsWindow() async {
    if (kNativeHost) {
      // The native host orders the window front and activates the app
      // (SettingsWindowHost.bringFront); window_manager's show cannot bring
      // an LSUIElement app forward reliably.
      try {
        await _host.invokeMethod('settingsShown');
      } catch (_) {
        await windowManager.show();
        await windowManager.focus();
      }
      return;
    }
    if (!settingsVisible.value) {
      final frame = _settingsFrame;
      await windowManager.setMinimumSize(_settingsMinSize);
      if (frame != null) {
        await windowManager.setBounds(frame);
      } else {
        await windowManager.setSize(const Size(1020, 700));
        await windowManager.center();
      }
      settingsVisible.value = true;
      // Let the remounted tree paint once at full size before ordering the
      // window front, otherwise it flashes the empty parked frame.
      await SchedulerBinding.instance.endOfFrame;
    }
    await windowManager.show();
    await windowManager.focus();
  }

  /// Hide the settings window and release what it holds. Besides unmounting
  /// the UI, the hidden window is shrunk: a hidden Flutter view keeps its
  /// full-size GPU back buffers (1020x700 at 2x is ~11 MB each, and the
  /// compositor keeps up to three), which made up a large share of the
  /// menu-bar-only footprint.
  Future<void> _parkSettings() async {
    await windowManager.hide();
    if (settingsVisible.value) {
      try {
        _settingsFrame = await windowManager.getBounds();
      } catch (_) {
        /* keep the previous frame */
      }
    }
    settingsVisible.value = false;
    final images = PaintingBinding.instance.imageCache;
    images.clear();
    images.clearLiveImages();
    try {
      await windowManager.setMinimumSize(_parkedSize);
      await windowManager.setSize(_parkedSize);
    } catch (e) {
      debugPrint('[melody] park settings failed: $e');
    }
  }

  // ---- HUD window ----

  Future<void> showHud() async {
    final existing = _hudController;
    debugPrint(
      '[melody] showHud: ${existing == null ? 'no controller, creating' : 'reusing ${existing.windowId}'}, ready=$_hudReady',
    );
    final controller = _hudController ?? await _createHud();
    // The HUD shows itself once its engine is up ('ready'); showing it from
    // here before that flashes a black window at the default position.
    if (_hudReady) {
      await _placeHud(controller);
      await controller.show();
    }
    await _pushStateToHud(force: true);
  }

  /// Called by the HUD isolate after its first frame; from then on the window
  /// can be shown/hidden from this side safely.
  Future<void> markHudReady() async {
    debugPrint('[melody] HUD ready');
    _hudReady = true;
    await _pushStateToHud(force: true);
  }

  /// The HUD closed its own window after sitting hidden (its engine is gone);
  /// the next tray click creates a new one.
  void forgetHud() {
    debugPrint('[melody] HUD disposed after idle');
    _hudController = null;
    _hudReady = false;
    _lastHudPayload = null;
  }

  Future<void> _placeHud(WindowController controller) async {
    final bounds = TrayService.instance.bounds;
    if (bounds == null || bounds.isEmpty) return;
    try {
      await controller.invokeMethod(
        'hudState',
        jsonEncode({
          'kind': 'place',
          'bounds': {
            'x': bounds.left,
            'y': bounds.top,
            'w': bounds.width,
            'h': bounds.height,
          },
        }),
      );
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

  Future<void> _pushStateToHud({bool force = false}) async {
    final controller = _hudController;
    if (controller == null) return;
    final state = soundEngine.state;
    final payload = jsonEncode({
      'kind': 'applyState',
      'settings': state.settings.toJson(),
      'latencyMs': state.latencyMs,
    });
    if (!force && _hudReady && payload == _lastHudPayload) return;
    try {
      await controller.invokeMethod('hudState', payload);
      _lastHudPayload = payload;
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
      } catch (_) {
        /* keep the controller */
      }
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
    if (kNativeHost) {
      // The host tears this whole engine down; nothing here outlives it.
      await windowManager.hide();
      await _host.invokeMethod('settingsClosed');
      return;
    }
    // Settings window close = hide to tray, never exit.
    if (!_quitting) {
      await _parkSettings();
    }
  }

  @override
  void onWindowFocus() {
    // Keep the sidebar/settings in sync after returning to the window.
  }

  // ---- Quit ----

  Future<void> quit() async {
    _quitting = true;
    if (kNativeHost) {
      await _host.invokeMethod('quit');
      return;
    }
    await soundEngine.flushSettings(); // debounced write must land before exit
    TrayService.instance.dispose();
    soundEngine.dispose();
    exit(0);
  }
}

final AppLifecycle appLifecycle = AppLifecycle.instance;

const MethodChannel _host = MethodChannel('melody/host');
