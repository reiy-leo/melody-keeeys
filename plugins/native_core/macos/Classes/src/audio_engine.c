#include "audio_engine.h"

/* Single translation unit carrying the miniaudio implementation. */
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include <stdlib.h>
#include <string.h>

#define AE_VOICES_PER_SLOT 4

struct ae_voice {
    ma_sound sound;
    ma_bool32 inited;
};

struct ae_slot {
    struct ae_voice voices[AE_VOICES_PER_SLOT];
    int next_voice;
    int voice_count;
};

struct audio_engine {
    /* Own resource manager so decoded samples are stored as s16 at the engine
     * rate instead of miniaudio's default f32: half the resident PCM memory
     * (~6 MB instead of ~12.5 MB for 22 packs), no quality loss for 16-bit
     * source WAVs, and resampling is paid once at load, never per keystroke. */
    ma_resource_manager rm;
    ma_bool32 rm_inited;
    ma_engine engine;
    ma_bool32 engine_inited;
    struct ae_slot slots[AE_MAX_SLOTS];
    int period_size;
    int periods;
    int sample_rate;
};

const char* ae_version(void)
{
    return MA_VERSION_STRING;
}

struct audio_engine* ae_create(int latency_preset)
{
    struct audio_engine* e = (struct audio_engine*)calloc(1, sizeof(*e));
    if (e == NULL) {
        return NULL;
    }

    switch (latency_preset) {
        case AE_PRESET_ULTRA:
            e->period_size = 96;   /* ~2.0 ms mixer update @ 48 kHz */
            e->periods = 2;
            break;
        case AE_PRESET_SAFE:
            e->period_size = 1024; /* ~21.3 ms mixer update @ 48 kHz */
            e->periods = 2;
            break;
        case AE_PRESET_NATIVE:
        default:
            e->period_size = 256;  /* ~5.3 ms mixer update @ 48 kHz */
            e->periods = 2;
            break;
    }
    e->sample_rate = 48000;

    ma_resource_manager_config rm_config = ma_resource_manager_config_init();
    rm_config.decodedFormat = ma_format_s16;
    rm_config.decodedChannels = 0; /* keep the file's channel count */
    rm_config.decodedSampleRate = (ma_uint32)e->sample_rate;
    if (ma_resource_manager_init(&rm_config, &e->rm) != MA_SUCCESS) {
        free(e);
        return NULL;
    }
    e->rm_inited = MA_TRUE;

    ma_engine_config config = ma_engine_config_init();
    config.sampleRate = (ma_uint32)e->sample_rate;
    config.periodSizeInFrames = (ma_uint32)e->period_size;
    config.pResourceManager = &e->rm;

    if (ma_engine_init(&config, &e->engine) != MA_SUCCESS) {
        ma_resource_manager_uninit(&e->rm);
        free(e);
        return NULL;
    }
    e->engine_inited = MA_TRUE;
    return e;
}

void ae_destroy(struct audio_engine* e)
{
    if (e == NULL) {
        return;
    }
    ae_unload_all(e);
    if (e->engine_inited) {
        ma_engine_uninit(&e->engine);
    }
    /* The engine does not own an external resource manager: free it last. */
    if (e->rm_inited) {
        ma_resource_manager_uninit(&e->rm);
    }
    free(e);
}

int ae_load_sound(struct audio_engine* e, int slot, const char* path)
{
    if (e == NULL || !e->engine_inited || slot < 0 || slot >= AE_MAX_SLOTS || path == NULL) {
        return -1;
    }
    ae_unload_sound(e, slot);

    struct ae_slot* s = &e->slots[slot];
    ma_result result = MA_SUCCESS;
    for (int i = 0; i < AE_VOICES_PER_SLOT; i++) {
        /* MA_SOUND_FLAG_DECODE: resource manager pre-decodes into memory once
         * and shares the data buffer across every voice created for this path.
         * NO_SPATIALIZATION: key clicks are not positioned in 3D; skipping the
         * spatializer saves per-voice state (528 voices) and mixer CPU. */
        result = ma_sound_init_from_file(&e->engine, path,
                                         MA_SOUND_FLAG_DECODE | MA_SOUND_FLAG_NO_SPATIALIZATION,
                                         NULL, NULL, &s->voices[i].sound);
        if (result != MA_SUCCESS) {
            s->voice_count = i;
            ae_unload_sound(e, slot);
            return (int)result;
        }
        s->voices[i].inited = MA_TRUE;
    }
    s->voice_count = AE_VOICES_PER_SLOT;
    return 0;
}

void ae_unload_sound(struct audio_engine* e, int slot)
{
    if (e == NULL || slot < 0 || slot >= AE_MAX_SLOTS) {
        return;
    }
    struct ae_slot* s = &e->slots[slot];
    for (int i = 0; i < s->voice_count; i++) {
        if (s->voices[i].inited) {
            ma_sound_uninit(&s->voices[i].sound);
            s->voices[i].inited = MA_FALSE;
        }
    }
    s->voice_count = 0;
    s->next_voice = 0;
}

void ae_unload_all(struct audio_engine* e)
{
    if (e == NULL) {
        return;
    }
    for (int i = 0; i < AE_MAX_SLOTS; i++) {
        ae_unload_sound(e, i);
    }
}

int ae_play(struct audio_engine* e, int slot, float gain, float pitch)
{
    if (e == NULL || !e->engine_inited || slot < 0 || slot >= AE_MAX_SLOTS) {
        return -1;
    }
    struct ae_slot* s = &e->slots[slot];
    if (s->voice_count == 0) {
        return -2;
    }
    struct ae_voice* v = &s->voices[s->next_voice % s->voice_count];
    s->next_voice = (s->next_voice + 1) % (AE_VOICES_PER_SLOT * 8);

    ma_sound_stop(&v->sound);
    ma_sound_seek_to_pcm_frame(&v->sound, 0);
    ma_sound_set_volume(&v->sound, gain <= 0.0f ? 0.0f : gain);
    ma_sound_set_pitch(&v->sound, pitch <= 0.0f ? 1.0f : pitch);
    if (ma_sound_start(&v->sound) != MA_SUCCESS) {
        return (int)MA_ERROR;
    }
    return 0;
}

void ae_set_master_volume(struct audio_engine* e, float volume)
{
    if (e == NULL || !e->engine_inited) {
        return;
    }
    ma_engine_set_volume(&e->engine, volume <= 0.0f ? 0.0f : volume);
}

void ae_stop_all(struct audio_engine* e)
{
    if (e == NULL || !e->engine_inited) {
        return;
    }
    for (int i = 0; i < AE_MAX_SLOTS; i++) {
        struct ae_slot* s = &e->slots[i];
        for (int j = 0; j < s->voice_count; j++) {
            if (s->voices[j].inited) {
                ma_sound_stop(&s->voices[j].sound);
            }
        }
    }
}

float ae_latency_ms(struct audio_engine* e)
{
    if (e == NULL) {
        return 0.0f;
    }
    return ((float)e->period_size * (float)e->periods / (float)e->sample_rate) * 1000.0f;
}
