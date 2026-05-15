#include "COpusBridge.h"

#include <stdlib.h>
#include "opus.h"

struct OpenLolaOpusEncoder {
    OpusEncoder *encoder;
};

struct OpenLolaOpusDecoder {
    OpusDecoder *decoder;
};

int32_t open_lola_opus_create_encoder(int32_t channels, OpenLolaOpusEncoder **encoder) {
    if (encoder == NULL || channels < 1 || channels > 2) {
        return OPUS_BAD_ARG;
    }

    int error = OPUS_OK;
    OpusEncoder *opus_encoder = opus_encoder_create(
        OPEN_LOLA_OPUS_SAMPLE_RATE_HZ,
        channels,
        OPUS_APPLICATION_RESTRICTED_LOWDELAY,
        &error
    );
    if (error != OPUS_OK || opus_encoder == NULL) {
        return error == OPUS_OK ? OPUS_ALLOC_FAIL : error;
    }

    error = opus_encoder_ctl(opus_encoder, OPUS_SET_BITRATE(OPEN_LOLA_OPUS_BITRATE_BPS));
    if (error == OPUS_OK) {
        error = opus_encoder_ctl(opus_encoder, OPUS_SET_VBR(0));
    }
    if (error == OPUS_OK) {
        error = opus_encoder_ctl(opus_encoder, OPUS_SET_FORCE_CHANNELS(channels));
    }
    if (error == OPUS_OK) {
        error = opus_encoder_ctl(opus_encoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_MUSIC));
    }
    if (error == OPUS_OK) {
        error = opus_encoder_ctl(opus_encoder, OPUS_SET_EXPERT_FRAME_DURATION(OPUS_FRAMESIZE_2_5_MS));
    }
    if (error != OPUS_OK) {
        opus_encoder_destroy(opus_encoder);
        return error;
    }

    OpenLolaOpusEncoder *wrapper = (OpenLolaOpusEncoder *)malloc(sizeof(OpenLolaOpusEncoder));
    if (wrapper == NULL) {
        opus_encoder_destroy(opus_encoder);
        return OPUS_ALLOC_FAIL;
    }
    wrapper->encoder = opus_encoder;
    *encoder = wrapper;
    return OPUS_OK;
}

int32_t open_lola_opus_encode_float(
    OpenLolaOpusEncoder *encoder,
    const float *pcm,
    int32_t frame_count,
    unsigned char *encoded,
    int32_t encoded_capacity
) {
    if (encoder == NULL || encoder->encoder == NULL || pcm == NULL || encoded == NULL) {
        return OPUS_BAD_ARG;
    }
    return opus_encode_float(encoder->encoder, pcm, frame_count, encoded, encoded_capacity);
}

void open_lola_opus_destroy_encoder(OpenLolaOpusEncoder *encoder) {
    if (encoder != NULL) {
        opus_encoder_destroy(encoder->encoder);
        free(encoder);
    }
}

int32_t open_lola_opus_create_decoder(int32_t channels, OpenLolaOpusDecoder **decoder) {
    if (decoder == NULL || channels < 1 || channels > 2) {
        return OPUS_BAD_ARG;
    }

    int error = OPUS_OK;
    OpusDecoder *opus_decoder = opus_decoder_create(
        OPEN_LOLA_OPUS_SAMPLE_RATE_HZ,
        channels,
        &error
    );
    if (error != OPUS_OK || opus_decoder == NULL) {
        return error == OPUS_OK ? OPUS_ALLOC_FAIL : error;
    }

    OpenLolaOpusDecoder *wrapper = (OpenLolaOpusDecoder *)malloc(sizeof(OpenLolaOpusDecoder));
    if (wrapper == NULL) {
        opus_decoder_destroy(opus_decoder);
        return OPUS_ALLOC_FAIL;
    }
    wrapper->decoder = opus_decoder;
    *decoder = wrapper;
    return OPUS_OK;
}

int32_t open_lola_opus_decode_float(
    OpenLolaOpusDecoder *decoder,
    const unsigned char *encoded,
    int32_t encoded_byte_count,
    float *pcm,
    int32_t frame_count
) {
    if (decoder == NULL || decoder->decoder == NULL || encoded == NULL || pcm == NULL) {
        return OPUS_BAD_ARG;
    }
    return opus_decode_float(decoder->decoder, encoded, encoded_byte_count, pcm, frame_count, 0);
}

void open_lola_opus_destroy_decoder(OpenLolaOpusDecoder *decoder) {
    if (decoder != NULL) {
        opus_decoder_destroy(decoder->decoder);
        free(decoder);
    }
}
