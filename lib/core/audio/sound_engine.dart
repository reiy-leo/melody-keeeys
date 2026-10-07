import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' hide KeyEvent;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_engine_ffi.dart';
import '../hooks/keymap_classifier.dart';
import 'sound_pack.dart';
import '../settings/settings_model.dart';
import '../settings/settings_repository.dart';

/// Snapshot consumed by the settings UI and the tray HUD.
@immutable
class EngineState {
  const EngineState({
    required this.settings,
    required this.latencyMs,
    required this.engineVersion,
    required this.keystrokeCount,
    required this.lastEventAtMs,
    required this.hookRunning,
    this.loadError,
  });

  final AppSettings settings;
  final double? latencyMs;
  final String engineVersion;
  final int keystrokeCount;
  final int lastEventAtMs;
  final bool hookRunning;
  final String? loadError;

  SoundPack get activePack => packById(settings.activePackId);
  int get activePackIndex =>
      kBuiltinPacks.indexWhere((p) => p.id == settings.activePackId).clamp(0, kBuiltinPacks.length - 1);

  EngineState copyWith({
    AppSettings? settings,
    double? latencyMs,
    String? engineVersion,
    int? keystrokeCount,
    int? lastEventAtMs,
    bool? hookRunning,
    String? loadError,
  }) =>
      EngineState(
        settings: settings ?? this.settings,
        latencyMs: latencyMs ?? this.latencyMs,
        engineVersion: engineVersion ?? this.engineVersion,
        keystrokeCount: keystrokeCount ?? this.keystrokeCount,
        lastEventAtMs: lastEventAtMs ?? this.lastEventAtMs,
        hookRunning: hookRunning ?? this.hookRunning,
        loadError: loadError ?? this.loadError,
      );
}

/// Owns the native audio engine, the settings repository and the keystroke
/// play policy (classification, anti-ghosting, pitch jitter, release sounds).
class SoundEngine extends ChangeNotifier {
  SoundEngine(this._repo);

  final SettingsRepository _repo;
  AudioEngineFfi? _ffi;
  final Random _random = Random();
  final Map<KeyCategory, int> _lastPlayAtMs = {};
  int _lastReleaseAtMs = 0;
  String? _soundDir;

  EngineState _state = EngineState(
    settings: const AppSettings(),
    latencyMs: null,
    engineVersion: '-',
    keystrokeCount: 0,
    lastEventAtMs: 0,
    hookRunning: false,
  );
  EngineState get state => _state;

  /// Directory holding the extracted sample WAVs (shared with the HUD window).
  String? get soundDir => _soundDir;

  Future<void> initialize() async {
    final settings = await _repo.load();
    _state = _state.copyWith(settings: settings);

    // 1. Materialize bundled WAVs to a real path (native code can't read the asset bundle).
    final support = await getApplicationSupportDirectory();
    final soundDir = Directory('${support.path}/sounds');
    _soundDir = soundDir.path;
    await _extractAssets(soundDir);

    // 2. Bring up the native engine and decode every pack.
    try {
      final ffi = AudioEngineFfi.open();
      debugPrint('[melody] audio engine version: ${ffi.version}');
      final latency = ffi.init(preset: settings.latencyPreset.enginePreset);
      debugPrint('[melody] engine init latency: $latency');
      if (latency == null) throw Exception('ae_create failed');
      final failures = ffi.loadAllPacks(soundDir.path);
      debugPrint('[melody] packs loaded, failures: ${failures.length}');
      ffi.setMasterVolume(settings.volumeLinear);
      _ffi = ffi;
      // Debug-only self test: one blip through the real output device.
      if (kDebugMode) {
        final rc =
            ffi.play(SoundLayer.alpha, packIndex: 0, gain: 1.0, pitch: 1.0);
        debugPrint('[melody] selftest play rc: $rc');
      }
      _state = _state.copyWith(
        latencyMs: latency,
        engineVersion: ffi.version,
        loadError: failures.isEmpty
            ? null
            : 'Failed to load ${failures.length} samples, e.g. ${failures.first}',
      );
    } catch (e) {
      debugPrint('[melody] audio engine init FAILED: $e');
      _state = _state.copyWith(loadError: 'Audio engine init failed: $e');
    }

    // 3. Start the global key hook.
    await startHook();
    notifyListeners();
  }

  Future<void> _extractAssets(Directory target) async {
    await target.create(recursive: true);
    // Bump when the bundled WAVs change: a version change re-copies every
    // file so existing installs pick up regenerated samples.
    const assetVersion = '6';
    final manifest = File('${target.path}/.manifest');
    final upToDate = manifest.existsSync() &&
        manifest.readAsStringSync().startsWith('v$assetVersion ');
    // Extract per file, not once per install: packs added by an update must
    // land in the existing support directory too.
    for (final pack in kBuiltinPacks) {
      for (final layer in SoundLayer.values) {
        final asset = pack.assetPathFor(layer);
        final file = File('${target.path}/$asset');
        if (upToDate && file.existsSync()) continue;
        final data = await rootBundle.load('assets/$asset');
        await file.create(recursive: true);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
    }
    await manifest.writeAsString(
        'v$assetVersion · ${kBuiltinPacks.length} packs · ${DateTime.now().toIso8601String()}');
  }

  Future<void> startHook() async {
    try {
      await KeyHookChannel.instance.start();
      _state = _state.copyWith(hookRunning: true);
    } catch (e) {
      _state = _state.copyWith(hookRunning: false);
    }
    notifyListeners();
  }

  Future<void> stopHook() async {
    await KeyHookChannel.instance.stop();
    _state = _state.copyWith(hookRunning: false);
    notifyListeners();
  }

  /// Main keystroke entry point, called from KeyHookChannel.
  void handleKeyEvent(KeyEvent event) {
    final settings = _state.settings;
    if (!settings.engineEnabled || _ffi == null) return;

    final category = classify(event);
    if (category == KeyCategory.unknown) return;
    if (kDebugMode) {
      debugPrint('[melody] key code=${event.code} down=${event.isKeyDown} '
          'repeat=${event.isRepeat} cat=${category.name}');
    }

    if (event.isRepeat) {
      // OS auto-repeat: only modifiers with the auto-repeat option play.
      if (category == KeyCategory.modifier && settings.modifierAutoRepeat) {
        _playCategory(category, settings);
      }
      return;
    }

    if (event.isKeyDown) {
      _playCategory(category, settings);
      _state = _state.copyWith(
        keystrokeCount: _state.keystrokeCount + 1,
        lastEventAtMs: event.timestampMs,
      );
      notifyListeners();
    } else if (settings.keyReleaseSound &&
        (category == KeyCategory.alpha ||
            category == KeyCategory.space ||
            category == KeyCategory.enter ||
            category == KeyCategory.nav)) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastReleaseAtMs < settings.antiGhostingMs) return;
      _lastReleaseAtMs = now;
      _play(SoundLayer.release, settings);
    }
  }

  bool _throttled(KeyCategory c, int nowMs, int windowMs) {
    final last = _lastPlayAtMs[c];
    return last != null && nowMs - last < windowMs;
  }

  void _playCategory(KeyCategory category, AppSettings settings) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_throttled(category, now, settings.antiGhostingMs)) return;
    _lastPlayAtMs[category] = now;
    _play(category.layer, settings);
  }

  void _play(SoundLayer layer, AppSettings settings) {
    final ffi = _ffi;
    if (ffi == null) return;
    final gain =
        layer == SoundLayer.release ? settings.keyReleaseGain : layer.baseGain;
    // Pitch jitter: full dispersion range is ±jitter around 1.0, then the
    // per-layer tone multiplier from settings.
    final j = settings.pitchJitter;
    final jitter = j <= 0 ? 1.0 : 1.0 + (2 * _random.nextDouble() - 1) * j;
    final pitch = jitter * settings.layerPitch(layer.assetName);
    final ok = ffi.play(layer, packIndex: _state.activePackIndex, gain: gain, pitch: pitch);
    if (kDebugMode && !ok) {
      debugPrint('[melody] play FAILED layer=${layer.name} '
          'pack=${_state.activePackIndex}');
    }
  }

  // ---- Mutators used by UI / tray ----

  Future<void> updateSettings(AppSettings next, {bool persist = true}) async {
    final old = _state.settings;
    _state = _state.copyWith(settings: next);
    if (persist) await _repo.save(next);
    _ffi?.setMasterVolume(next.volumeLinear);
    if (next.latencyPreset != old.latencyPreset) {
      final latency = _ffi?.init(preset: next.latencyPreset.enginePreset);
      if (latency != null && _soundDir != null) {
        _ffi?.loadAllPacks(_soundDir!);
        _state = _state.copyWith(latencyMs: latency);
      }
    }
    notifyListeners();
  }

  Future<void> selectPack(String packId, {bool preview = true}) async {
    final next = _state.settings.copyWith(activePackId: packId);
    await updateSettings(next);
    if (preview) {
      _lastPlayAtMs.clear(); // let the preview through
      _play(SoundLayer.alpha, next);
    }
  }

  void cyclePack() {
    final i = _state.activePackIndex;
    final next = kBuiltinPacks[(i + 1) % kBuiltinPacks.length];
    selectPack(next.id);
  }

  Future<void> toggleEngine() async =>
      updateSettings(_state.settings.copyWith(engineEnabled: !_state.settings.engineEnabled));

  Future<void> resetToDefaults() async {
    const defaults = AppSettings();
    await updateSettings(defaults);
    _lastPlayAtMs.clear();
  }

  /// Fire a sample directly (Strike button, pack list previews).
  void previewPack(String packId, [SoundLayer layer = SoundLayer.alpha]) {
    final ffi = _ffi;
    if (ffi == null) return;
    final idx = kBuiltinPacks.indexWhere((p) => p.id == packId).clamp(0, kBuiltinPacks.length - 1);
    final j = _state.settings.pitchJitter;
    ffi.play(layer, packIndex: idx, gain: layer.baseGain, pitch: 1.0 + (2 * _random.nextDouble() - 1) * j);
  }

  @override
  void dispose() {
    _ffi?.dispose();
    KeyHookChannel.instance.stop();
    super.dispose();
  }
}

/// Global singleton engine wired through main(); exposed to widgets via
/// [engineProvider] (ChangeNotifierProvider).
late final SoundEngine soundEngine;

/// EventChannel bridge to the per-platform key-hook plugin.
class KeyHookChannel {
  KeyHookChannel._();
  static final KeyHookChannel instance = KeyHookChannel._();

  static const _method = MethodChannel('native_core/method');
  static const _events = EventChannel('native_core/keyhook');

  Stream<KeyEvent>? _stream;
  StreamSubscription<KeyEvent>? _sub;
  bool _started = false;

  /// Accessibility / input-group permission status (platform dependent).
  Future<bool> isPermissionGranted() async {
    try {
      return await _method.invokeMethod('isPermissionGranted') as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// macOS only: per-permission detail (accessibility + input monitoring).
  /// Falls back to [isPermissionGranted] semantics when the native side does
  /// not implement the method (older builds / other platforms).
  Future<Map<String, bool>> permissionDetail() async {
    try {
      final raw = await _method.invokeMethod('permissionDetail');
      if (raw is Map) {
        return {
          'accessibility': raw['accessibility'] as bool? ?? false,
          'inputMonitoring': raw['inputMonitoring'] as bool? ?? false,
        };
      }
    } on PlatformException {/* fall through */}
    final granted = await isPermissionGranted();
    return {'accessibility': granted, 'inputMonitoring': granted};
  }

  /// macOS only: trigger the system "监视输入" prompt and register the app in
  /// the Input Monitoring pane.
  Future<void> requestInputMonitoring() async {
    try {
      await _method.invokeMethod('requestInputMonitoring');
    } on PlatformException {/* UI message only */}
  }

  Future<void> openPermissionSettings({String which = 'accessibility'}) async {
    try {
      await _method.invokeMethod('openPermissionSettings', which);
    } on PlatformException {/* UI message only */}
  }

  Future<void> start() async {
    if (_started) return;
    _sub ??= events.listen(soundEngine.handleKeyEvent,
        onError: (Object e) {/* hook died; UI shows status */});
    try {
      await _method.invokeMethod('startKeyHook');
      _started = true;
    } on PlatformException {
      _started = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    try {
      await _method.invokeMethod('stopKeyHook');
    } on PlatformException {/* ignore */}
    _started = false;
  }

  Stream<KeyEvent> get events {
    _stream ??= _events.receiveBroadcastStream().map((raw) {
      final map = raw as Map;
      final platform = HookPlatform.values.firstWhere(
          (p) => p.name == (map['platform'] as String? ?? Platform.operatingSystem),
          orElse: () => HookPlatform.macos);
      return KeyEvent(
        platform: platform,
        code: (map['code'] as num).toInt(),
        isKeyDown: map['down'] as bool? ?? true,
        isRepeat: map['repeat'] as bool? ?? false,
        timestampMs: (map['ts'] as num).toInt(),
      );
    });
    return _stream!;
  }
}
