#include "XZEncoder.h"
#include <lzma.h>
#include <stdlib.h>

int xz_compress(const uint8_t *input, size_t input_size,
                uint8_t **output, size_t *output_size) {
    // Preset 9 | LZMA_PRESET_EXTREME gives maximum compression.
    uint32_t preset = 9 | LZMA_PRESET_EXTREME;

    size_t out_bound = lzma_stream_buffer_bound(input_size);
    uint8_t *out_buf = malloc(out_bound);
    if (!out_buf) return LZMA_MEM_ERROR;

    size_t out_pos = 0;
    lzma_ret ret = lzma_easy_buffer_encode(
        preset,
        LZMA_CHECK_CRC64,
        NULL,          /* use default allocator */
        input, input_size,
        out_buf, &out_pos, out_bound
    );

    if (ret != LZMA_OK) {
        free(out_buf);
        return (int)ret;
    }

    *output  = out_buf;
    *output_size = out_pos;
    return 0;
}

void xz_free(uint8_t *buf) {
    free(buf);
}
