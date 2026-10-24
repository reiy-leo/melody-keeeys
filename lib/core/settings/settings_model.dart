import 'dart:math' as math;

import 'package:flutter/material.dart' show ThemeMode;

import '../audio/sound_pack.dart';
import '../i18n/i18n.dart';

enum TrayLeftClickAction { cycleNext, showHud }

/// App appearance: light / dark / follow the OS.
enum UiTheme { light, dark, system }

extension UiThemeX on UiTheme {
  ThemeMode get themeMode => switch (this) {
        UiTheme.light => ThemeMode.light,
        UiTheme.dark => ThemeMode.dark,
        UiTheme.system => ThemeMode.system,
      };

  String get label => switch (this) {
        UiTheme.light => tr('theme.light'),
        UiTheme.dark => tr('theme.dark'),
        UiTheme.system => tr('common.followSystem'),
      };
}

enum LatencyPreset { ultra, native, safe }

extension LatencyPresetX on LatencyPreset {
  int get enginePreset => switch (this) {
        LatencyPreset.ultra => 0,
        LatencyPreset.native => 1,
        LatencyPreset.safe => 2,
      };

  String get label => switch (this) {
        LatencyPreset.ultra => tr('latency.ultra'),
        LatencyPreset.native => tr('latency.native'),
        LatencyPreset.safe => tr('latency.safe'),
      };
}

/// The Lucide glyphs selectable as the tray/menu-bar icon.
const List<String> kTrayIconIds = [
  'keyboard',
  'keyboard-music',
  'command',
  'line-squiggle',
  'gamepad-directional',
  'tv',
  'balloon',
];

/// (id, localized label) for each selectable tray icon.
List<(String id, String label)> get kTrayIcons =>
    [for (final id in kTrayIconIds) (id, tr('icon.$id'))];

class AppSettings {
  const AppSettings({
    this.engineEnabled = true,
    this.activePackId = 'cherry_mx_blue',
    this.volumeDb = -6.0,
    this.pitchJitter = 0.04,
    this.antiGhostingMs = 35,
    this.modifierAutoRepeat = false,
    this.keyReleaseSound = false,
    this.keyReleaseGain = 0.35,
    this.latencyPreset = LatencyPreset.native,
    this.launchAtLogin = false,
    this.silentStart = false,
    this.uiTheme = UiTheme.system,
    this.layerTones = const {},
    this.leftClickAction = TrayLeftClickAction.cycleNext,
    this.trayIcon = 'keyboard-music',
    this.muteHotkey = 'Option+Shift+K',
    this.cycleHotkey = 'Option+Shift+]',
    this.language = 'system',
  });

  final bool engineEnabled;
  final String activePackId;

  /// Master volume in dB, -12 .. +6.
  final double volumeDb;
  /// Random pitch dispersion per keystroke, 0 .. 0.5 (linear factor range).
  final double pitchJitter;

  /// Minimum interval between overlapping same-layer triggers.
  final int antiGhostingMs;
  final bool modifierAutoRepeat;
  final bool keyReleaseSound;
  final double keyReleaseGain;
  final LatencyPreset latencyPreset;

  final bool launchAtLogin;
  final bool silentStart;

  /// App appearance: light / dark / follow the OS.
  final UiTheme uiTheme;

  /// Per-layer tone (0..1) mapping to a pitch multiplier 0.85..1.25, keyed by
  /// SoundLayer asset name.
  final Map<String, double> layerTones;

  final TrayLeftClickAction leftClickAction;

  /// Tray/menu-bar glyph: one of the Lucide icon ids listed in [kTrayIcons].
  final String trayIcon;

  final String muteHotkey;
  final String cycleHotkey;

  /// UI language: 'system' or a code from assets/i18n/strings.json.
  final String language;

  /// Pitch multiplier applied to a layer's samples from its tone value.
  double layerPitch(String layer) {
    final tone = layerTones[layer] ?? 0.5;
    return 0.85 + 0.4 * tone;
  }

  double get volumeLinear => volumeDb <= -60 ? 0.0 : math.pow(10, volumeDb / 20).toDouble();

  AppSettings copyWith({
    bool? engineEnabled,
    String? activePackId,
    double? volumeDb,
    double? pitchJitter,
    int? antiGhostingMs,
    bool? modifierAutoRepeat,
    bool? keyReleaseSound,
    double? keyReleaseGain,
    LatencyPreset? latencyPreset,
    bool? launchAtLogin,
    bool? silentStart,
    UiTheme? uiTheme,
    Map<String, double>? layerTones,
    TrayLeftClickAction? leftClickAction,
    String? trayIcon,
    String? muteHotkey,
    String? cycleHotkey,
    String? language,
  }) =>
      AppSettings(
        engineEnabled: engineEnabled ?? this.engineEnabled,
        activePackId: activePackId ?? this.activePackId,
        volumeDb: volumeDb ?? this.volumeDb,
        pitchJitter: pitchJitter ?? this.pitchJitter,
        antiGhostingMs: antiGhostingMs ?? this.antiGhostingMs,
        modifierAutoRepeat: modifierAutoRepeat ?? this.modifierAutoRepeat,
        keyReleaseSound: keyReleaseSound ?? this.keyReleaseSound,
        keyReleaseGain: keyReleaseGain ?? this.keyReleaseGain,
        latencyPreset: latencyPreset ?? this.latencyPreset,
        launchAtLogin: launchAtLogin ?? this.launchAtLogin,
        silentStart: silentStart ?? this.silentStart,
        uiTheme: uiTheme ?? this.uiTheme,
        layerTones: layerTones ?? this.layerTones,
        leftClickAction: leftClickAction ?? this.leftClickAction,
        trayIcon: trayIcon ?? this.trayIcon,
        muteHotkey: muteHotkey ?? this.muteHotkey,
        cycleHotkey: cycleHotkey ?? this.cycleHotkey,
        language: language ?? this.language,
      );

  Map<String, Object?> toJson() => {
        'engineEnabled': engineEnabled,
        'activePackId': activePackId,
        'volumeDb': volumeDb,
        'pitchJitter': pitchJitter,
        'antiGhostingMs': antiGhostingMs,
        'modifierAutoRepeat': modifierAutoRepeat,
        'keyReleaseSound': keyReleaseSound,
        'keyReleaseGain': keyReleaseGain,
        'latencyPreset': latencyPreset.index,
        'launchAtLogin': launchAtLogin,
        'silentStart': silentStart,
        'uiTheme': uiTheme.index,
        'layerTones': layerTones,
        'leftClickAction': leftClickAction.index,
        'trayIcon': trayIcon,
        'muteHotkey': muteHotkey,
        'cycleHotkey': cycleHotkey,
        'language': language,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    int? intOf(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    double? doubleOf(Object? v) => v is num ? v.toDouble() : null;
    bool? boolOf(Object? v) => v is bool ? v : null;
    String? stringOf(Object? v) => v is String ? v : null;
    final preset = intOf(json['latencyPreset']);
    final leftClick = intOf(json['leftClickAction']);
    return AppSettings(
      engineEnabled: boolOf(json['engineEnabled']) ?? true,
      activePackId: stringOf(json['activePackId']) ?? kBuiltinPacks.first.id,
      volumeDb: doubleOf(json['volumeDb']) ?? -6.0,
      pitchJitter: doubleOf(json['pitchJitter']) ?? 0.04,
      antiGhostingMs: intOf(json['antiGhostingMs']) ?? 35,
      modifierAutoRepeat: boolOf(json['modifierAutoRepeat']) ?? false,
      keyReleaseSound: boolOf(json['keyReleaseSound']) ?? false,
      keyReleaseGain: doubleOf(json['keyReleaseGain']) ?? 0.35,
      latencyPreset:
          preset == null ? LatencyPreset.native : LatencyPreset.values[preset.clamp(0, 2)],
      launchAtLogin: boolOf(json['launchAtLogin']) ?? false,
      silentStart: boolOf(json['silentStart']) ?? false,
      uiTheme: intOf(json['uiTheme']) == null
          ? UiTheme.system
          : UiTheme.values[intOf(json['uiTheme'])!.clamp(0, UiTheme.values.length - 1)],
      layerTones: (json['layerTones'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ) ??
          const {},
      leftClickAction: leftClick == null
          ? TrayLeftClickAction.cycleNext
          : TrayLeftClickAction.values[leftClick.clamp(0, 1)],
      trayIcon: stringOf(json['trayIcon']) ?? 'keyboard-music',
      muteHotkey: stringOf(json['muteHotkey']) ?? 'Option+Shift+K',
      cycleHotkey: stringOf(json['cycleHotkey']) ?? 'Option+Shift+]',
      language: stringOf(json['language']) ?? 'system',
    );
  }
}
