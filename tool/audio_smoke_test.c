/* Standalone smoke test for audio_engine.c (no Flutter involved).
 * Build: clang -o /tmp/ae_test tool/audio_smoke_test.c plugins/native_core/macos/Classes/src/audio_engine.c \
 *        -framework CoreAudio -framework AudioToolbox -framework AudioUnit -framework CoreFoundation
 * Run:   /tmp/ae_test <wav-file> [n]
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "audio_engine.h"

int main(int argc, char** argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <wav> [plays]\n", argv[0]);
        return 1;
    }
    int plays = argc > 2 ? atoi(argv[2]) : 3;

    struct audio_engine* e = ae_create(AE_PRESET_ULTRA);
    if (!e) {
        fprintf(stderr, "ae_create failed\n");
        return 1;
    }
    printf("engine %s, latency ~%.1f ms\n", ae_version(), ae_latency_ms(e));

    if (ae_load_sound(e, 0, argv[1]) != 0) {
        fprintf(stderr, "load failed: %s\n", argv[1]);
        return 1;
    }

    ae_set_master_volume(e, 0.9f);
    for (int i = 0; i < plays; i++) {
        float pitch = 1.0f + 0.06f * (float)(i - plays / 2);
        int rc = ae_play(e, 0, 1.0f, pitch);
        printf("play %d: rc=%d pitch=%.2f\n", i, rc, pitch);
        struct timespec ts = {0, 180000000}; /* 180 ms */
        nanosleep(&ts, NULL);
    }
    struct timespec drain = {0, 400000000};
    nanosleep(&drain, NULL);

    ae_destroy(e);
    printf("OK\n");
    return 0;
}
