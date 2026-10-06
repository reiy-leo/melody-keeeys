import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'sound_pack.dart';

/// FFI binding for the native miniaudio-based engine (native/src/audio_engine.c).
///
/// Slot convention: slot = packIndex * 6 + layerIndex. All 10 packs are decoded
/// up front (~60 short samples) so pack switching and previews are instant.
class AudioEngineFfi {
  AudioEngineFfi._(this._lib);

  final DynamicLibrary _lib;

  late final Pointer<Utf8> Function() _version = _lib
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('ae_version');
  late final Pointer<Void> Function(int) _create = _lib
      .lookupFunction<Pointer<Void> Function(Int32), Pointer<Void> Function(int)>('ae_create');
  late final void Function(Pointer<Void>) _destroy = _lib
      .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('ae_destroy');
  late final int Function(Pointer<Void>, int, Pointer<Utf8>) _loadSound = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>),
      int Function(Pointer<Void>, int, Pointer<Utf8>)>('ae_load_sound');
  late final void Function(Pointer<Void>) _unloadAll = _lib
      .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('ae_unload_all');
  late final int Function(Pointer<Void>, int, double, double) _play = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float, Float),
      int Function(Pointer<Void>, int, double, double)>('ae_play');
  late final void Function(Pointer<Void>, double) _setMasterVolume = _lib.lookupFunction<
      Void Function(Pointer<Void>, Float), void Function(Pointer<Void>, double)>(
      'ae_set_master_volume');
  late final void Function(Pointer<Void>) _stopAll = _lib
      .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('ae_stop_all');
  late final double Function(Pointer<Void>) _latencyMs = _lib
      .lookupFunction<Float Function(Pointer<Void>), double Function(Pointer<Void>)>(
          'ae_latency_ms');

  Pointer<Void>? _engine;

  static AudioEngineFfi open() {
    final lib = _openLibrary();
    return AudioEngineFfi._(lib);
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isMacOS) {
      // Linked into the Runner binary by the native_core podspec.
      try {
        return DynamicLibrary.process();
      } catch (_) {
        return DynamicLibrary.open('libaudio_engine.dylib');
      }
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('audio_engine.dll');
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libaudio_engine.so');
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  String get version {
    final ptr = _version();
    return ptr == nullptr ? '?' : ptr.toDartString();
  }

  bool get isReady => _engine != null;

  /// Returns the approximate output latency in ms, or null if init failed.
  double? init({int preset = 1}) {
    dispose();
    final engine = _create(preset);
    if (engine == nullptr) return null;
    _engine = engine;
    return _latencyMs(engine);
  }

  /// Decode every layer sample of every builtin pack from [baseDir].
  /// Returns the list of failed slot paths (should be empty).
  List<String> loadAllPacks(String baseDir) {
    final engine = _engine;
    if (engine == null) return const [];
    final failures = <String>[];
    for (var i = 0; i < kBuiltinPacks.length; i++) {
      for (final layer in SoundLayer.values) {
        final path = '$baseDir/${kBuiltinPacks[i].assetPathFor(layer)}';
        final pathPtr = path.toNativeUtf8();
        final rc = _loadSound(engine, i * SoundLayer.values.length + layer.index, pathPtr);
        malloc.free(pathPtr);
        if (rc != 0) failures.add(path);
      }
    }
    return failures;
  }

  /// Returns true when a sound was actually fired.
  bool play(SoundLayer layer, {required int packIndex, double gain = 1.0, double pitch = 1.0}) {
    final engine = _engine;
    if (engine == null) return false;
    final slot = packIndex * SoundLayer.values.length + layer.index;
    return _play(engine, slot, gain, pitch) == 0;
  }

  void setMasterVolume(double linearVolume) {
    final engine = _engine;
    if (engine == null) return;
    _setMasterVolume(engine, linearVolume);
  }

  void stopAll() {
    final engine = _engine;
    if (engine != null) _stopAll(engine);
  }

  void dispose() {
    final engine = _engine;
    if (engine != null) {
      _unloadAll(engine);
      _destroy(engine);
      _engine = null;
    }
  }
}
