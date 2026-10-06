/// Native core of Melody Keeeys: miniaudio FFI engine + global key hooks.
///
/// Dart consumers talk to the plugin via MethodChannel `native_core/method`
/// and EventChannel `native_core/keyhook`, and load the audio symbols with
/// `dart:ffi` (see lib/core/audio/audio_engine_ffi.dart in the app).
library;
