#include "rasterize.h"
#include "utils.h"
#include "variable.h"

#include <cuda.h>
#include <cuda_runtime.h>

namespace poc {

void rasterize() {
    const int W = g_W;
    const int H = g_H;

    const int tile_W = (W + g_tile_size - 1) / g_tile_size;
    const int tile_H = (H + g_tile_size - 1) / g_tile_size;

    if (g_raw_img != NULL)
        delete[] g_raw_img;

    if (g_raw_T != NULL)
        delete[] g_raw_T;

    g_raw_img = new float[W * H * NUM_CHANNELS];
    g_raw_T = new float[W * H];

    for (int p = 0; p < W * H; p++) {
        for (int ch = 0; ch < NUM_CHANNELS; ch++)
            g_raw_img[p * NUM_CHANNELS + ch] = 0.f;
        g_raw_T[p] = 1.f;
    }

    g_reuse_gaussian_per_tile.clear();
    g_reuse_gaussian_per_tile.resize(NUM_TILE);

    for (int i = 0; i < NUM_TILE; i++) {
        if (DEBUG_MODE) {
            int w = i % TILE_WIDTH;
            int h = i / TILE_WIDTH;

            if (W_START > w * g_tile_size || W_END < w * g_tile_size)
                continue;
            if (H_START > h * g_tile_size || H_END < h * g_tile_size)
                continue;
        }

        int tx = i % TILE_WIDTH;
        int ty = i / TILE_WIDTH;

        for (auto tile_key : g_merge_gaussian_per_tile[i]) {
            const float2 p = {g_gaussian_mean2D_cpu[g_curr_cam][tile_key.idx * 2],
                              g_gaussian_mean2D_cpu[g_curr_cam][tile_key.idx * 2 + 1]};
            const float depth = g_gaussian_depth_cpu[g_curr_cam][tile_key.idx];
            const int max_radius = g_gaussian_radii_cpu[g_curr_cam][tile_key.idx];

            float gaussian_e_val[2];
            float2 gaussian_e_vec[2];

            for (int j = 0; j < 2; j++) {
                gaussian_e_val[j] = g_gaussian_eigen_value_cpu[g_curr_cam][j][tile_key.idx];
                gaussian_e_vec[j] = {g_gaussian_eigen_vector_cpu[g_curr_cam][j][tile_key.idx * 2],
                                     g_gaussian_eigen_vector_cpu[g_curr_cam][j][tile_key.idx * 2 + 1]};
            }

            const tile_key_t next_tile_key = {depth, tile_key.idx};

            if (max_radius != 0 && obb_test(p, tx, ty, gaussian_e_vec[0], gaussian_e_vec[1], gaussian_e_val[0], gaussian_e_val[1], g_tile_size))
                g_reuse_gaussian_per_tile[i].push_back(next_tile_key);
        }
    }

    for (int th = 0; th < tile_H; th++)
        for (int tw = 0; tw < tile_W; tw++) {
            if (DEBUG_MODE) {
                if (W_START > tw * g_tile_size || W_END < tw * g_tile_size)
                    continue;
                if (H_START > th * g_tile_size || H_END < th * g_tile_size)
                    continue;
            }

            int global_tile_idx = th * tile_W + tw;
            for (auto key : g_reuse_gaussian_per_tile[global_tile_idx]) {
                const float2 xy = {g_gaussian_mean2D_cpu[g_curr_cam][key.idx * 2],
                                   g_gaussian_mean2D_cpu[g_curr_cam][key.idx * 2 + 1]};
                const float rgb[3] = {g_gaussian_rgb_cpu[g_curr_cam][key.idx * 3],
                                      g_gaussian_rgb_cpu[g_curr_cam][key.idx * 3 + 1],
                                      g_gaussian_rgb_cpu[g_curr_cam][key.idx * 3 + 2]};
                const float4 con_o = {g_gaussian_conic_opacity_cpu[g_curr_cam][key.idx * 4],
                                      g_gaussian_conic_opacity_cpu[g_curr_cam][key.idx * 4 + 1],
                                      g_gaussian_conic_opacity_cpu[g_curr_cam][key.idx * 4 + 2],
                                      g_gaussian_conic_opacity_cpu[g_curr_cam][key.idx * 4 + 3]};

                for (int dh = 0; dh < g_tile_size; dh++)
                    for (int dw = 0; dw < g_tile_size; dw++) {
                        const float2 pixf = {tw * g_tile_size + dw, th * g_tile_size + dh};
                        const int pix = (int)pixf.y * W + (int)pixf.x;

                        if (pixf.x >= W || pixf.y >= H)
                            continue;

                        const float2 d = {xy.x - pixf.x, xy.y - pixf.y};
                        const float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;

                        if (power > 0.f)
                            continue;

                        const float alpha = min(0.99f, con_o.w * exp(power));

                        if (alpha < 1.f / 255.f)
                            continue;

                        const float test_T = g_raw_T[pix] * (1.f - alpha);

                        if (test_T < 0.0001f)
                            continue;

                        for (int ch = 0; ch < NUM_CHANNELS; ch++)
                            g_raw_img[ch * W * H + pix] += rgb[ch] * alpha * g_raw_T[pix];

                        g_raw_T[pix] = test_T;
                    }
            }
        }
}

} // namespace poc
