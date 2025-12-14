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

        const float2 prev_p = {g_gaussian_mean2D_cpu[g_prev_cam][idx * 2],
                               g_gaussian_mean2D_cpu[g_prev_cam][idx * 2 + 1]};
        const int prev_max_radius = g_gaussian_radii_cpu[g_prev_cam][idx];

        float prev_gaussian_e_val[2];
        float2 prev_gaussian_e_vec[2];

        for (int i = 0; i < 2; i++) {
            prev_gaussian_e_val[i] = g_gaussian_eigen_value_cpu[g_prev_cam][i][idx];
            prev_gaussian_e_vec[i] = {g_gaussian_eigen_vector_cpu[g_prev_cam][i][idx * 2],
                                      g_gaussian_eigen_vector_cpu[g_prev_cam][i][idx * 2 + 1]};
        }

        const uint2 rect_min = {
            min(grid.x, max((int)0, (int)((p.x - max_radius) / g_tile_size))),
            min(grid.y, max((int)0, (int)((p.y - max_radius) / g_tile_size)))};
        const uint2 rect_max = {
            min(grid.x, max((int)0, (int)((p.x + max_radius + g_tile_size - 1) / g_tile_size))),
            min(grid.y, max((int)0, (int)((p.y + max_radius + g_tile_size - 1) / g_tile_size)))};
        const uint2 prev_rect_min = {
            min(grid.x, max((int)0, (int)((prev_p.x - prev_max_radius) / g_tile_size))),
            min(grid.y, max((int)0, (int)((prev_p.y - prev_max_radius) / g_tile_size)))};
        const uint2 prev_rect_max = {
            min(grid.x, max((int)0, (int)((prev_p.x + prev_max_radius + g_tile_size - 1) / g_tile_size))),
            min(grid.y, max((int)0, (int)((prev_p.y + prev_max_radius + g_tile_size - 1) / g_tile_size)))};

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

                if (prev_max_radius != 0 &&
                    tx >= prev_rect_min.x && tx < prev_rect_max.x &&
                    ty >= prev_rect_min.y && ty < prev_rect_max.y &&
                    obb_test(prev_p,
                             tx, ty,
                             prev_gaussian_e_vec[0], prev_gaussian_e_vec[1],
                             prev_gaussian_e_val[0], prev_gaussian_e_val[1],
                             g_tile_size))
                    continue;

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

    int total_new_cnt = 0;
    int total_reuse_cnt = 0;

    for (int i = 0; i < NUM_TILE; i++) {
        if (DEBUG_MODE) {
            int w = i % TILE_WIDTH;
            int h = i / TILE_WIDTH;

            if (W_START > w * g_tile_size || W_END < w * g_tile_size)
                continue;
            if (H_START > h * g_tile_size || H_END < h * g_tile_size)
                continue;
        }

        std::sort(g_gaussian_per_tile[i].begin(), g_gaussian_per_tile[i].end(), cmp);

        const int reuse_size = g_reuse_gaussian_per_tile[i].size();

        if (g_iter % 2 == 0) {
            for (int j = 0; j < reuse_size; j += g_chunk_size)
                std::sort(g_reuse_gaussian_per_tile[i].begin() + j,
                          g_reuse_gaussian_per_tile[i].begin() + min(j + g_chunk_size, reuse_size), cmp);
        } else {
            std::sort(g_reuse_gaussian_per_tile[i].begin(),
                      g_reuse_gaussian_per_tile[i].begin() + min(g_chunk_size / 2, reuse_size), cmp);

            for (int j = g_chunk_size / 2; j < reuse_size; j += g_chunk_size)
                std::sort(g_reuse_gaussian_per_tile[i].begin() + j,
                          g_reuse_gaussian_per_tile[i].begin() + min(j + g_chunk_size, reuse_size), cmp);
        }

        g_merge_gaussian_per_tile[i].clear();

        int new_idx = 0;
        int reuse_idx = 0;

        while (new_idx < g_gaussian_per_tile[i].size() || reuse_idx < g_reuse_gaussian_per_tile[i].size()) {
            float new_gaussian_depth = (new_idx < g_gaussian_per_tile[i].size()) ? g_gaussian_per_tile[i][new_idx].depth : 1e10;
            float reuse_gaussian_depth = (reuse_idx < g_reuse_gaussian_per_tile[i].size()) ? g_reuse_gaussian_per_tile[i][reuse_idx].depth : 1e10;

            if (new_gaussian_depth < reuse_gaussian_depth) {
                total_new_cnt++;

                if (g_merge_gaussian_per_tile[i].size() != 0 && g_merge_gaussian_per_tile[i].back().idx == g_gaussian_per_tile[i][new_idx].idx)
                    new_idx++;
                else {
                    g_merge_gaussian_per_tile[i].push_back(g_gaussian_per_tile[i][new_idx]);
                    new_idx++;
                }
            } else {
                total_reuse_cnt++;

                if (g_merge_gaussian_per_tile[i].size() != 0 && g_merge_gaussian_per_tile[i].back().idx == g_reuse_gaussian_per_tile[i][reuse_idx].idx)
                    reuse_idx++;
                else {
                    g_merge_gaussian_per_tile[i].push_back(g_reuse_gaussian_per_tile[i][reuse_idx]);
                    reuse_idx++;
                }
            }
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
