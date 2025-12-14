#ifndef CUDA_RASTERIZER_UTILS_H
#define CUDA_RASTERIZER_UTILS_H

#include "cuda_runtime.h"
#include <cuda.h>

__forceinline__ __device__ uint64_t pack_rect(float depth, uint2 rect_min, uint2 rect_max) {
    uint32_t _depth = *((uint32_t *)&depth);

    return (uint64_t(_depth) << 32) |
           (uint64_t(rect_min.x) << 24) |
           (uint64_t(rect_min.y) << 16) |
           (uint64_t(rect_max.x) << 8) |
           rect_max.y;
}

__forceinline__ __device__ float pack_rect(uint2 rect_min, uint2 rect_max) {
    uint32_t _pack = (rect_min.x << 24) | (rect_min.y << 16) | (rect_max.x << 8) | rect_max.y;
    return *((float *)&_pack);
}

__forceinline__ __device__ void unpack_rect(uint64_t pack_rect, uint32_t &depth, uint2 &rect_min, uint2 &rect_max) {
    depth = (pack_rect >> 32) & 0xFFFFFFFF;
    rect_min.x = (pack_rect >> 24) & 0xFF;
    rect_min.y = (pack_rect >> 16) & 0xFF;
    rect_max.x = (pack_rect >> 8) & 0xFF;
    rect_max.y = pack_rect & 0xFF;
}

__forceinline__ __device__ void unpack_rect(float pack_rect, uint2 &rect_min, uint2 &rect_max) {
    uint32_t _pack = *((uint32_t *)&pack_rect);
    rect_min.x = (_pack >> 24) & 0xFF;
    rect_min.y = (_pack >> 16) & 0xFF;
    rect_max.x = (_pack >> 8) & 0xFF;
    rect_max.y = _pack & 0xFF;
}

#endif // CUDA_RASTERIZER_UTILS_H
