/*
 * Copyright (C) 2023, Inria
 * GRAPHDECO research group, https://team.inria.fr/graphdeco
 * All rights reserved.
 *
 * This software is free for non-commercial, research and evaluation use
 * under the terms of the LICENSE.md file.
 *
 * For inquiries contact  george.drettakis@inria.fr
 */

#ifndef CUDA_RASTERIZER_FORWARD_H_INCLUDED
#define CUDA_RASTERIZER_FORWARD_H_INCLUDED

#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <cuda.h>
#define GLM_FORCE_CUDA
#include <glm/glm.hpp>

#define WARP_SIZE 32
#define HALF_WARP_SIZE 16
#define MAX_ELEMENTS_IN_TILE 32768
#define MAX_THREADS_PER_BLOCK 1024

namespace FORWARD {
// Perform initial steps for each Gaussian prior to rasterization.
void preprocess(int P, int D, int M,
                const float *orig_points,
                const glm::vec3 *scales,
                const float scale_modifier,
                const glm::vec4 *rotations,
                const float *opacities,
                const float *shs,
                bool *clamped,
                const float *cov3D_precomp,
                const float *colors_precomp,
                const float *viewmatrix,
                const float *projmatrix,
                const glm::vec3 *cam_pos,
                const int W, int H,
                const float focal_x, float focal_y,
                const float tan_fovx, float tan_fovy,
                int *radii,
                float2 *points_xy_image,
                float *depths,
                float *cov3Ds,
                float *colors,
                float4 *conic_opacity,
                const dim3 grid,
                uint32_t *tiles_touched,
                bool prefiltered,
                bool antialiasing,
                bool is_reuse,
                uint64_t *prev_gaussian_rect,
                uint64_t *curr_gaussian_rect,
                float *prev_gaussian_data = nullptr,
                float *curr_gaussian_data = nullptr);

// Main rasterization method.
void render(
    const dim3 grid, dim3 block,
    const uint2 *ranges,
    const uint32_t *point_list,
    int W, int H,
    float *final_T,
    uint32_t *n_contrib,
    const float *bg_color,
    float *out_color,
    float *depths,
    float *depth,
    float *curr_gaussian_data);

void render_reuse(
    const dim3 grid, dim3 block,
    uint64_t *gaussian_keys,
    const uint32_t *gaussian_values,
    const uint32_t *ranges,
    const uint64_t *gaussian_rect,
    int W, int H,
    const float2 *means2D,
    const float *colors,
    const float4 *conic_opacity,
    float *final_T,
    uint32_t *n_contrib,
    const float *bg_color,
    float *out_color,
    float *depths,
    float *depth,
    float *curr_gaussian_data);

void copying(
    int T,
    const uint2 *ranges,
    const uint64_t *src_keys_sorted,
    const uint32_t *src_values_sorted,
    uint64_t *dst_keys_sorted,
    uint32_t *dst_values_sorted,
    uint32_t *dst_ranges_sorted);

void merging(
    int T,
    const uint32_t *prev_ranges,
    const uint64_t *prev_keys_sorted,
    const uint32_t *prev_values_sorted,
    const uint2 *curr_ranges,
    const uint64_t *curr_keys_sorted,
    const uint32_t *curr_values_sorted,
    uint32_t *merge_ranges,
    uint64_t *merged_keys_sorted,
    uint32_t *merged_values_sorted);

void optimized_merging(
    int T,
    const uint32_t *prev_ranges,
    const uint64_t *prev_keys_sorted,
    const uint32_t *prev_values_sorted,
    const uint2 *curr_ranges,
    const uint64_t *curr_keys_sorted,
    const uint32_t *curr_values_sorted,
    uint32_t *merge_ranges,
    uint64_t *merged_keys_sorted,
    uint32_t *merged_values_sorted);

void dynamic_partial_sorting(
    bool is_even,
    int T,
    const uint32_t *ranges,
    uint64_t *keys,
    uint32_t *values);

} // namespace FORWARD

#endif
