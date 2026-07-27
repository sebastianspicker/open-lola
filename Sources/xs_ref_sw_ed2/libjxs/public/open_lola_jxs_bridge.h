#ifndef OPEN_LOLA_JXS_BRIDGE_H
#define OPEN_LOLA_JXS_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool open_lola_jxs_encode_bgra8(
    const uint8_t* bgra,
    int width,
    int height,
    float bits_per_pixel,
    uint8_t** codestream,
    size_t* codestream_size
);

bool open_lola_jxs_decode_bgra8(
    const uint8_t* codestream,
    size_t codestream_size,
    uint8_t** bgra,
    int* width,
    int* height
);

void open_lola_jxs_free(void* pointer);

#endif
