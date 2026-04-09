#ifndef XZEncoder_h
#define XZEncoder_h

#include <stdint.h>
#include <stddef.h>

/// Compress `input` into an XZ stream (LZMA2, preset 9 extreme).
/// On success returns 0, sets *output to a malloc'd buffer and *output_size to
/// its length. Caller must free *output with xz_free().
/// On failure returns a non-zero lzma_ret code.
int xz_compress(const uint8_t *input, size_t input_size,
                uint8_t **output, size_t *output_size);

/// Free a buffer returned by xz_compress.
void xz_free(uint8_t *buf);

#endif /* XZEncoder_h */
