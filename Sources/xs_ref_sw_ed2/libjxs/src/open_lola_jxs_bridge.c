#include "open_lola_jxs_bridge.h"

#include "libjxs.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static bool open_lola_jxs_make_rgb_image(xs_image_t* image, int width, int height)
{
    memset(image, 0, sizeof(*image));
    image->ncomps = 3;
    image->width = width;
    image->height = height;
    image->depth = 8;
    for (int component = 0; component < image->ncomps; ++component)
    {
        image->sx[component] = 1;
        image->sy[component] = 1;
    }
    return xs_allocate_image(image, false);
}

static void open_lola_jxs_bgra_to_rgb_image(
    const uint8_t* bgra,
    xs_image_t* image
)
{
    const size_t sample_count = (size_t)image->width * (size_t)image->height;
    for (size_t index = 0; index < sample_count; ++index)
    {
        image->comps_array[0][index] = bgra[index * 4 + 2];
        image->comps_array[1][index] = bgra[index * 4 + 1];
        image->comps_array[2][index] = bgra[index * 4 + 0];
    }
}

static bool open_lola_jxs_rgb_image_to_bgra(
    const xs_image_t* image,
    uint8_t** bgra
)
{
    const size_t sample_count = (size_t)image->width * (size_t)image->height;
    uint8_t* output = (uint8_t*)malloc(sample_count * 4);
    if (!output)
    {
        return false;
    }
    for (size_t index = 0; index < sample_count; ++index)
    {
        output[index * 4 + 0] = (uint8_t)image->comps_array[2][index];
        output[index * 4 + 1] = (uint8_t)image->comps_array[1][index];
        output[index * 4 + 2] = (uint8_t)image->comps_array[0][index];
        output[index * 4 + 3] = 255;
    }
    *bgra = output;
    return true;
}

bool open_lola_jxs_encode_bgra8(
    const uint8_t* bgra,
    int width,
    int height,
    float bits_per_pixel,
    uint8_t** codestream,
    size_t* codestream_size
)
{
    if (!bgra || !codestream || !codestream_size || width <= 0 || height <= 0 || bits_per_pixel <= 0)
    {
        return false;
    }
    *codestream = NULL;
    *codestream_size = 0;

    xs_image_t image;
    if (!open_lola_jxs_make_rgb_image(&image, width, height))
    {
        return false;
    }
    open_lola_jxs_bgra_to_rgb_image(bgra, &image);

    xs_config_t config;
    memset(&config, 0, sizeof(config));
    char config_string[64];
    snprintf(config_string, sizeof(config_string), "rate=%.3f;lh=0;rl=1;gains=visual", bits_per_pixel);
    if (!xs_config_parse_and_init(&config, &image, config_string, sizeof(config_string) - 1))
    {
        xs_free_image(&image);
        return false;
    }
    if (!xs_enc_preprocess_image(&config, &image))
    {
        xs_free_image(&image);
        return false;
    }
    xs_enc_context_t* context = xs_enc_init(&config, &image);
    if (!context)
    {
        xs_free_image(&image);
        return false;
    }

    size_t capacity;
    if (config.bitstream_size_in_bytes == (size_t)-1)
    {
        capacity = (size_t)width * (size_t)height * 3 + 1024 * 1024;
    }
    else
    {
        capacity = (config.bitstream_size_in_bytes + 7) & (~(size_t)0x7);
    }
    uint8_t* output = (uint8_t*)malloc(capacity);
    if (!output)
    {
        xs_enc_close(context);
        xs_free_image(&image);
        return false;
    }

    size_t encoded_size = 0;
    const bool encoded = xs_enc_image(context, &image, output, capacity, &encoded_size);
    xs_enc_close(context);
    xs_free_image(&image);
    if (!encoded || encoded_size == 0)
    {
        free(output);
        return false;
    }
    *codestream = output;
    *codestream_size = encoded_size;
    return true;
}

bool open_lola_jxs_decode_bgra8(
    const uint8_t* codestream,
    size_t codestream_size,
    uint8_t** bgra,
    int* width,
    int* height
)
{
    if (!codestream || codestream_size == 0 || !bgra || !width || !height)
    {
        return false;
    }
    *bgra = NULL;
    *width = 0;
    *height = 0;

    xs_config_t config;
    memset(&config, 0, sizeof(config));
    xs_image_t image;
    memset(&image, 0, sizeof(image));
    if (!xs_dec_probe((uint8_t*)codestream, codestream_size, &config, &image))
    {
        return false;
    }
    if (image.ncomps != 3 || image.depth != 8)
    {
        return false;
    }
    if (!xs_allocate_image(&image, false))
    {
        return false;
    }
    xs_dec_context_t* context = xs_dec_init(&config, &image);
    if (!context)
    {
        xs_free_image(&image);
        return false;
    }
    const bool decoded = xs_dec_bitstream(context, (void*)codestream, codestream_size, &image)
        && xs_dec_postprocess_image(&config, &image);
    xs_dec_close(context);
    if (!decoded)
    {
        xs_free_image(&image);
        return false;
    }
    const bool converted = open_lola_jxs_rgb_image_to_bgra(&image, bgra);
    if (converted)
    {
        *width = image.width;
        *height = image.height;
    }
    xs_free_image(&image);
    return converted;
}

void open_lola_jxs_free(void* pointer)
{
    free(pointer);
}
