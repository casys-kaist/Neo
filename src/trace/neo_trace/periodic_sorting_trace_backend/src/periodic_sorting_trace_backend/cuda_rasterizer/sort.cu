#include "sort.h"
#include "utils.h"
#include "variable.h"

#include <algorithm>
#include <cuda.h>
#include <cuda_runtime.h>
#include <iostream>
#include <vector>

namespace poc {

static void scratch_sort() {
    const uint2 grid = {TILE_WIDTH, TILE_HEIGHT};

    g_gaussian_per_tile.clear();
    g_gaussian_per_tile.resize(NUM_TILE);

    g_merge_gaussian_per_tile.clear();
    g_merge_gaussian_per_tile.resize(NUM_TILE);

    g_duplicated_gaussian.clear();
    g_duplicated_gaussian.resize(g_P);

    for (int idx = 0; idx < g_P; idx++) {
        const float2 p = {g_gaussian_mean2D_cpu[g_curr_cam][idx * 2],
                          g_gaussian_mean2D_cpu[g_curr_cam][idx * 2 + 1]};
        const float depth = g_gaussian_depth_cpu[g_curr_cam][idx];
        const int max_radius = g_gaussian_radii_cpu[g_curr_cam][idx];

        float gaussian_e_val[2];
        float2 gaussian_e_vec[2];

        for (int i = 0; i < 2; i++) {
            gaussian_e_val[i] = g_gaussian_eigen_value_cpu[g_curr_cam][i][idx];
            gaussian_e_vec[i] = {g_gaussian_eigen_vector_cpu[g_curr_cam][i][idx * 2],
                                 g_gaussian_eigen_vector_cpu[g_curr_cam][i][idx * 2 + 1]};
        }

        const uint2 rect_min = {
            min(grid.x, max((int)0, (int)((p.x - max_radius) / g_tile_size))),
            min(grid.y, max((int)0, (int)((p.y - max_radius) / g_tile_size)))};
        const uint2 rect_max = {
            min(grid.x, max((int)0, (int)((p.x + max_radius + g_tile_size - 1) / g_tile_size))),
            min(grid.y, max((int)0, (int)((p.y + max_radius + g_tile_size - 1) / g_tile_size)))};

        for (int tx = rect_min.x; tx < rect_max.x; tx++)
            for (int ty = rect_min.y; ty < rect_max.y; ty++) {
                if (DEBUG_MODE) {
                    if (W_START > tx * g_tile_size || W_END < tx * g_tile_size)
                        continue;
                    if (H_START > ty * g_tile_size || H_END < ty * g_tile_size)
                        continue;
                }

                tile_key_t tile_key = {depth, idx};
                const uint64_t key = ty * grid.x + tx;
                if (max_radius != 0 && obb_test(p,
                                                tx, ty,
                                                gaussian_e_vec[0], gaussian_e_vec[1],
                                                gaussian_e_val[0], gaussian_e_val[1],
                                                g_tile_size)) {
                    g_gaussian_per_tile[key].push_back(tile_key);
                    g_duplicated_gaussian[idx].push_back(key);
                }
            }
    }

    auto cmp = [](const tile_key_t &a, const tile_key_t &b) {
        return a.depth < b.depth;
    };

    for (int i = 0; i < NUM_TILE; i++) {
        std::sort(g_gaussian_per_tile[i].begin(), g_gaussian_per_tile[i].end(), cmp);

        g_merge_gaussian_per_tile[i].clear();

        int new_idx = 0;
        while (new_idx < g_gaussian_per_tile[i].size()) {
            g_merge_gaussian_per_tile[i].push_back(g_gaussian_per_tile[i][new_idx]);
            new_idx++;
        }
    }
}

static void reuse_sort() {
    const uint2 grid = {TILE_WIDTH, TILE_HEIGHT};

    g_gaussian_per_tile.clear();
    g_gaussian_per_tile.resize(NUM_TILE);

    g_merge_gaussian_per_tile.clear();
    g_merge_gaussian_per_tile.resize(NUM_TILE);

    g_duplicated_gaussian.clear();
    g_duplicated_gaussian.resize(g_P);

    for (int i = 0; i < NUM_TILE; i++) {
        g_merge_gaussian_per_tile[i].clear();

        int reuse_idx = 0;

        while (reuse_idx < g_reuse_gaussian_per_tile[i].size()) {
            g_merge_gaussian_per_tile[i].push_back(g_reuse_gaussian_per_tile[i][reuse_idx]);
            reuse_idx++;
        }
    }
}

void sort() {
    if (g_phase == INITIAL_PHASE)
        scratch_sort();
    else
        reuse_sort();
}

} // namespace poc
