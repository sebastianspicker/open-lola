#ifndef C_OPUS_BRIDGE_H
#define C_OPUS_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
    OPEN_LOLA_OPUS_SAMPLE_RATE_HZ = 48000,
    OPEN_LOLA_OPUS_FRAME_COUNT = 120,
    OPEN_LOLA_OPUS_BITRATE_BPS = 64000,
    OPEN_LOLA_OPUS_MAX_PACKET_BYTES = 1500
};

typedef struct OpenLolaOpusEncoder OpenLolaOpusEncoder;
typedef struct OpenLolaOpusDecoder OpenLolaOpusDecoder;

int32_t open_lola_opus_create_encoder(int32_t channels, OpenLolaOpusEncoder **encoder);
int32_t open_lola_opus_encode_float(
    OpenLolaOpusEncoder *encoder,
    const float *pcm,
    int32_t frame_count,
    unsigned char *encoded,
    int32_t encoded_capacity
);
void open_lola_opus_destroy_encoder(OpenLolaOpusEncoder *encoder);

int32_t open_lola_opus_create_decoder(int32_t channels, OpenLolaOpusDecoder **decoder);
int32_t open_lola_opus_decode_float(
    OpenLolaOpusDecoder *decoder,
    const unsigned char *encoded,
    int32_t encoded_byte_count,
    float *pcm,
    int32_t frame_count
);
void open_lola_opus_destroy_decoder(OpenLolaOpusDecoder *decoder);

#ifdef __cplusplus
}
#endif

#endif
