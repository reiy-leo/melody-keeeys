#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Keep ae_* symbols alive and visible: Dart loads them via dlsym at runtime,
 * so nothing inside the binary references them statically. */
#define AE_API __attribute__((used)) __attribute__((visibility("default")))

/* Latency presets for ae_create(). */
#define AE_PRESET_ULTRA  0
#define AE_PRESET_NATIVE 1
#define AE_PRESET_SAFE   2

/* Slot = packIndex * 6 + layerIndex (see audio_engine_ffi.dart).
 * Capacity must cover kBuiltinPacks.length * 6 = 132 today. */
#define AE_MAX_SLOTS 160

struct audio_engine;

AE_API const char* ae_version(void);

/* Create and initialize the engine with a latency preset. Returns NULL on failure. */
AE_API struct audio_engine* ae_create(int latency_preset);

AE_API void ae_destroy(struct audio_engine* e);

/*
 * Load (decode) a sound file into a slot. The resource manager shares decoded
 * data across voices, so switching packs only needs unload + load.
 * Returns 0 on success, negative miniaudio result code otherwise.
 */
AE_API int ae_load_sound(struct audio_engine* e, int slot, const char* path);

AE_API void ae_unload_sound(struct audio_engine* e, int slot);

AE_API void ae_unload_all(struct audio_engine* e);

/*
 * Fire-and-forget polyphonic play: round-robins a small voice pool per slot so
 * rapid keystrokes overlap. gain/pitch are linear multipliers.
 * Returns 0 on success.
 */
AE_API int ae_play(struct audio_engine* e, int slot, float gain, float pitch);

AE_API void ae_set_master_volume(struct audio_engine* e, float volume);

AE_API void ae_stop_all(struct audio_engine* e);

/* Approximate output latency in milliseconds for the configured preset. */
AE_API float ae_latency_ms(struct audio_engine* e);

#ifdef __cplusplus
}
#endif

#endif /* AUDIO_ENGINE_H */
