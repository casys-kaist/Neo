#ifndef UTILS_H
#define UTILS_H

#include <iostream>

typedef uint64_t u64;

#define KB (1024)
#define MB (1024 * KB)
#define GB (1024 * MB)

#define MHz 1000000

#define to_u64(x) (std::stoull(x))
#define align_address(x, y) (((x) / (y)) * (y))

#define RAW_GAUSSIAN_POSITION_BASE (0x0000000)
#define RAW_GAUSSIAN_OTHERS_BASE (0x3000000)

#define PREV_PROJECTION_BASE (0x6000000)
#define CURR_PROJECTION_BASE (0x9000000)

#define COMMON_PHASE 0
#define REUSE_PHASE 1

#define REUSE_BASE (0xc000000)
#define NEW_BASE (0xf000000)

#define RAW_POSTION_SIZE (6) // x, y, z: 2B each

#define RAW_OTHERS_SIZE (2 + 6 + 8 + 96) /* Opacity: 2B                      \
                                          * Scale (x, y, z): 2B each         \
                                          * Quaternion (w, x, y, z): 2B each \
                                          * SHs for RGB: 3 * 16 * 2B */

#define PROJECTION_ENTRY_SIZE (2 + 2 + 4 + 8 + 6) /* Depth: 2B                               \
                                                   * Radii: 2B                               \
                                                   * Position (x, y): 2B each                \
                                                   * Conic (c00, c01, c11), Opacity: 2B each \
                                                   * RGB: 2B each */

#define NEW_ENTRY_SIZE (8)
#define REUSE_ENTRY_SIZE (8)

#define MAX_GAUSSIAN_IN_TILE (8198)

#define reuse_tile_base(x) (REUSE_BASE + (x) * MAX_GAUSSIAN_IN_TILE * REUSE_ENTRY_SIZE)
#define new_tile_base(x) (NEW_BASE + (x) * MAX_GAUSSIAN_IN_TILE * NEW_ENTRY_SIZE)

#endif
