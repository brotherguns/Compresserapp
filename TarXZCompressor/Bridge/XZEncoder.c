#include "XZEncoder.h"
#include <lzma.h>
#include <stdlib.h>
#include <unistd.h>

int xz_compress(const uint8_t *input, size_t input_size,
                uint8_t **output, size_t *output_size) {

    // Use every available core. lzma_stream_encoder_mt splits the input into
    // independent blocks and compresses them in parallel.
    uint32_t threads = (uint32_t)sysconf(_SC_NPROCESSORS_ONLN);
    if (threads < 1) threads = 1;

    // Divide input evenly so every core gets a block.
    // With block_size=0 (auto), liblzma defaults to 3x the dict size (192 MB
    // for preset 9), meaning a 300 MB input only makes 2 blocks and wastes
    // 4 of 6 cores. Sizing to input/threads keeps all cores busy.
    // Floor at 8 MB so tiny inputs don't create degenerate blocks.
    size_t block_size = input_size / threads;
    if (block_size < 8 * 1024 * 1024) block_size = 8 * 1024 * 1024;

    lzma_mt mt = {
        .flags      = 0,
        .threads    = threads,
        .block_size = block_size,
        .timeout    = 0,
        .preset     = 9 | LZMA_PRESET_EXTREME,
        .filters    = NULL,
        .check      = LZMA_CHECK_CRC64,
    };

    lzma_stream strm = LZMA_STREAM_INIT;
    lzma_ret ret = lzma_stream_encoder_mt(&strm, &mt);
    if (ret != LZMA_OK) return (int)ret;

    size_t out_bound = lzma_stream_buffer_bound(input_size);
    uint8_t *out_buf = malloc(out_bound);
    if (!out_buf) {
        lzma_end(&strm);
        return LZMA_MEM_ERROR;
    }

    strm.next_in   = input;
    strm.avail_in  = input_size;
    strm.next_out  = out_buf;
    strm.avail_out = out_bound;

    ret = lzma_code(&strm, LZMA_FINISH);

    if (ret != LZMA_STREAM_END) {
        free(out_buf);
        lzma_end(&strm);
        return (int)ret;
    }

    *output      = out_buf;
    *output_size = strm.total_out;
    lzma_end(&strm);
    return 0;
}

void xz_free(uint8_t *buf) {
    free(buf);
}
