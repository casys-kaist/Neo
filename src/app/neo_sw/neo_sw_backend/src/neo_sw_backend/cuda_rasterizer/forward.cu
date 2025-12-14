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

#include "auxiliary.h"
#include "forward.h"
#include "utils.h"
#include <cooperative_groups.h>
#include <cooperative_groups/reduce.h>
#include <cuda_runtime.h>
namespace cg = cooperative_groups;

// Forward method for converting the input spherical harmonics
// coefficients of each Gaussian to a simple RGB color.
__device__ glm::vec3 computeColorFromSH(int idx, int deg, int max_coeffs, const glm::vec3 *means, glm::vec3 campos, const float *shs, bool *clamped) {
    // The implementation is loosely based on code for
    // "Differentiable Point-Based Radiance Fields for
    // Efficient View Synthesis" by Zhang et al. (2022)
    glm::vec3 pos = means[idx];
    glm::vec3 dir = pos - campos;
    dir = dir / glm::length(dir);

    glm::vec3 *sh = ((glm::vec3 *)shs) + idx * max_coeffs;
    glm::vec3 result = SH_C0 * sh[0];

    if (deg > 0) {
        float x = dir.x;
        float y = dir.y;
        float z = dir.z;
        result = result - SH_C1 * y * sh[1] + SH_C1 * z * sh[2] - SH_C1 * x * sh[3];

        if (deg > 1) {
            float xx = x * x, yy = y * y, zz = z * z;
            float xy = x * y, yz = y * z, xz = x * z;
            result = result +
                     SH_C2[0] * xy * sh[4] +
                     SH_C2[1] * yz * sh[5] +
                     SH_C2[2] * (2.0f * zz - xx - yy) * sh[6] +
                     SH_C2[3] * xz * sh[7] +
                     SH_C2[4] * (xx - yy) * sh[8];

            if (deg > 2) {
                result = result +
                         SH_C3[0] * y * (3.0f * xx - yy) * sh[9] +
                         SH_C3[1] * xy * z * sh[10] +
                         SH_C3[2] * y * (4.0f * zz - xx - yy) * sh[11] +
                         SH_C3[3] * z * (2.0f * zz - 3.0f * xx - 3.0f * yy) * sh[12] +
                         SH_C3[4] * x * (4.0f * zz - xx - yy) * sh[13] +
                         SH_C3[5] * z * (xx - yy) * sh[14] +
                         SH_C3[6] * x * (xx - 3.0f * yy) * sh[15];
            }
        }
    }
    result += 0.5f;

    // RGB colors are clamped to positive values. If values are
    // clamped, we need to keep track of this for the backward pass.
    clamped[3 * idx + 0] = (result.x < 0);
    clamped[3 * idx + 1] = (result.y < 0);
    clamped[3 * idx + 2] = (result.z < 0);
    return glm::max(result, 0.0f);
}

// Forward version of 2D covariance matrix computation
__device__ float3 computeCov2D(const float3 &mean, float focal_x, float focal_y, float tan_fovx, float tan_fovy, const float *cov3D, const float *viewmatrix) {
    // The following models the steps outlined by equations 29
    // and 31 in "EWA Splatting" (Zwicker et al., 2002).
    // Additionally considers aspect / scaling of viewport.
    // Transposes used to account for row-/column-major conventions.
    float3 t = transformPoint4x3(mean, viewmatrix);

    const float limx = 1.3f * tan_fovx;
    const float limy = 1.3f * tan_fovy;
    const float txtz = t.x / t.z;
    const float tytz = t.y / t.z;
    t.x = min(limx, max(-limx, txtz)) * t.z;
    t.y = min(limy, max(-limy, tytz)) * t.z;

    glm::mat3 J = glm::mat3(
        focal_x / t.z, 0.0f, -(focal_x * t.x) / (t.z * t.z),
        0.0f, focal_y / t.z, -(focal_y * t.y) / (t.z * t.z),
        0, 0, 0);

    glm::mat3 W = glm::mat3(
        viewmatrix[0], viewmatrix[4], viewmatrix[8],
        viewmatrix[1], viewmatrix[5], viewmatrix[9],
        viewmatrix[2], viewmatrix[6], viewmatrix[10]);

    glm::mat3 T = W * J;

    glm::mat3 Vrk = glm::mat3(
        cov3D[0], cov3D[1], cov3D[2],
        cov3D[1], cov3D[3], cov3D[4],
        cov3D[2], cov3D[4], cov3D[5]);

    glm::mat3 cov = glm::transpose(T) * glm::transpose(Vrk) * T;

    return {float(cov[0][0]), float(cov[0][1]), float(cov[1][1])};
}

// Forward method for converting scale and rotation properties of each
// Gaussian to a 3D covariance matrix in world space. Also takes care
// of quaternion normalization.
__device__ void computeCov3D(const glm::vec3 scale, float mod, const glm::vec4 rot, float *cov3D) {
    // Create scaling matrix
    glm::mat3 S = glm::mat3(1.0f);
    S[0][0] = mod * scale.x;
    S[1][1] = mod * scale.y;
    S[2][2] = mod * scale.z;

    // Normalize quaternion to get valid rotation
    glm::vec4 q = rot; // / glm::length(rot);
    float r = q.x;
    float x = q.y;
    float y = q.z;
    float z = q.w;

    // Compute rotation matrix from quaternion
    glm::mat3 R = glm::mat3(
        1.f - 2.f * (y * y + z * z), 2.f * (x * y - r * z), 2.f * (x * z + r * y),
        2.f * (x * y + r * z), 1.f - 2.f * (x * x + z * z), 2.f * (y * z - r * x),
        2.f * (x * z - r * y), 2.f * (y * z + r * x), 1.f - 2.f * (x * x + y * y));

    glm::mat3 M = S * R;

    // Compute 3D world covariance matrix Sigma
    glm::mat3 Sigma = glm::transpose(M) * M;

    // Covariance is symmetric, only store upper right
    cov3D[0] = Sigma[0][0];
    cov3D[1] = Sigma[0][1];
    cov3D[2] = Sigma[0][2];
    cov3D[3] = Sigma[1][1];
    cov3D[4] = Sigma[1][2];
    cov3D[5] = Sigma[2][2];
}

// Perform initial steps for each Gaussian prior to rasterization.
template <int C>
__global__ void preprocessCUDA(int P, int D, int M,
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
                               const float tan_fovx, float tan_fovy,
                               const float focal_x, float focal_y,
                               int *radii,
                               float2 *points_xy_image,
                               float *depths,
                               float *cov3Ds,
                               float *rgb,
                               float4 *conic_opacity,
                               const dim3 grid,
                               uint32_t *tiles_touched,
                               bool prefiltered,
                               bool antialiasing,
                               uint64_t *prev_gaussian_rect,
                               uint64_t *curr_gaussian_rect,
                               float4 *prev_gaussian_data,
                               float4 *curr_gaussian_data) {
    auto idx = cg::this_grid().thread_rank();
    if (idx >= P)
        return;

    tiles_touched[idx] = 0;
    curr_gaussian_rect[idx] = 0;
    curr_gaussian_data[3 * idx + 0] = {0.0f, 0.0f, 0.0f, 0.0f};
    curr_gaussian_data[3 * idx + 1] = {0.0f, 0.0f, 0.0f, 0.0f};
    curr_gaussian_data[3 * idx + 2] = {0.0f, 0.0f, 0.0f, 0.0f};

    float3 p_view;
    if (!in_frustum(idx, orig_points, viewmatrix, projmatrix, prefiltered, p_view))
        return;

    float3 p_orig = {orig_points[3 * idx], orig_points[3 * idx + 1], orig_points[3 * idx + 2]};
    float4 p_hom = transformPoint4x4(p_orig, projmatrix);
    float p_w = 1.0f / (p_hom.w + 0.0000001f);
    float3 p_proj = {p_hom.x * p_w, p_hom.y * p_w, p_hom.z * p_w};

    const float *cov3D;
    if (cov3D_precomp != nullptr) {
        cov3D = cov3D_precomp + idx * 6;
    } else {
        computeCov3D(scales[idx], scale_modifier, rotations[idx], cov3Ds + idx * 6);
        cov3D = cov3Ds + idx * 6;
    }

    float3 cov = computeCov2D(p_orig, focal_x, focal_y, tan_fovx, tan_fovy, cov3D, viewmatrix);

    constexpr float h_var = 0.3f;
    const float det_cov = cov.x * cov.z - cov.y * cov.y;
    cov.x += h_var;
    cov.z += h_var;
    const float det_cov_plus_h_cov = cov.x * cov.z - cov.y * cov.y;
    float h_convolution_scaling = 1.0f;

    if (antialiasing)
        h_convolution_scaling = sqrt(max(0.000025f, det_cov / det_cov_plus_h_cov)); // max for numerical stability

    const float det = det_cov_plus_h_cov;

    if (det == 0.0f)
        return;
    float det_inv = 1.f / det;
    float3 conic = {cov.z * det_inv, -cov.y * det_inv, cov.x * det_inv};

    float mid = 0.5f * (cov.x + cov.z);
    float lambda1 = mid + sqrt(max(0.1f, mid * mid - det));
    float lambda2 = mid - sqrt(max(0.1f, mid * mid - det));
    float my_radius = ceil(3.f * sqrt(max(lambda1, lambda2)));
    float2 point_image = {ndc2Pix(p_proj.x, W), ndc2Pix(p_proj.y, H)};
    uint2 rect_min, rect_max;
    getRect(point_image, my_radius, rect_min, rect_max, grid);
    if ((rect_max.x - rect_min.x) * (rect_max.y - rect_min.y) == 0)
        return;

    glm::vec3 result = computeColorFromSH(idx, D, M, (glm::vec3 *)orig_points, *cam_pos, shs, clamped);

    float opacity = opacities[idx];

    tiles_touched[idx] = (rect_max.y - rect_min.y) * (rect_max.x - rect_min.x);

    curr_gaussian_rect[idx] = pack_rect(p_view.z, rect_min, rect_max);
    curr_gaussian_data[3 * idx + 0] = {point_image.x, point_image.y, p_view.z, pack_rect(rect_min, rect_max)};
    curr_gaussian_data[3 * idx + 1] = {conic.x, conic.y, conic.z, opacity * h_convolution_scaling};
    curr_gaussian_data[3 * idx + 2] = {result.x, result.y, result.z, 0.0f};
}

template <int C>
__global__ void preprocess_reuseCUDA(int P, int D, int M,
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
                                     const float tan_fovx, float tan_fovy,
                                     const float focal_x, float focal_y,
                                     int *radii,
                                     float2 *points_xy_image,
                                     float *depths,
                                     float *cov3Ds,
                                     float *rgb,
                                     float4 *conic_opacity,
                                     const dim3 grid,
                                     uint32_t *tiles_touched,
                                     bool prefiltered,
                                     bool antialiasing,
                                     uint64_t *prev_gaussian_rect,
                                     uint64_t *curr_gaussian_rect,
                                     float4 *prev_gaussian_data,
                                     float4 *curr_gaussian_data) {
    auto idx = cg::this_grid().thread_rank();
    if (idx >= P)
        return;

    tiles_touched[idx] = 0;
    curr_gaussian_rect[idx] = 0;
    curr_gaussian_data[3 * idx + 0] = {0.0f, 0.0f, 0.0f, 0.0f};
    curr_gaussian_data[3 * idx + 1] = {0.0f, 0.0f, 0.0f, 0.0f};
    curr_gaussian_data[3 * idx + 2] = {0.0f, 0.0f, 0.0f, 0.0f};

    float3 p_view;
    if (!in_frustum(idx, orig_points, viewmatrix, projmatrix, prefiltered, p_view))
        return;

    float3 p_orig = {orig_points[3 * idx], orig_points[3 * idx + 1], orig_points[3 * idx + 2]};
    float4 p_hom = transformPoint4x4(p_orig, projmatrix);
    float p_w = 1.0f / (p_hom.w + 0.0000001f);
    float3 p_proj = {p_hom.x * p_w, p_hom.y * p_w, p_hom.z * p_w};

    const float *cov3D;
    if (cov3D_precomp != nullptr) {
        cov3D = cov3D_precomp + idx * 6;
    } else {
        computeCov3D(scales[idx], scale_modifier, rotations[idx], cov3Ds + idx * 6);
        cov3D = cov3Ds + idx * 6;
    }

    float3 cov = computeCov2D(p_orig, focal_x, focal_y, tan_fovx, tan_fovy, cov3D, viewmatrix);

    constexpr float h_var = 0.3f;
    const float det_cov = cov.x * cov.z - cov.y * cov.y;
    cov.x += h_var;
    cov.z += h_var;
    const float det_cov_plus_h_cov = cov.x * cov.z - cov.y * cov.y;
    float h_convolution_scaling = 1.0f;

    if (antialiasing)
        h_convolution_scaling = sqrt(max(0.000025f, det_cov / det_cov_plus_h_cov)); // max for numerical stability

    const float det = det_cov_plus_h_cov;

    if (det == 0.0f)
        return;
    float det_inv = 1.f / det;
    float3 conic = {cov.z * det_inv, -cov.y * det_inv, cov.x * det_inv};

    float mid = 0.5f * (cov.x + cov.z);
    float lambda1 = mid + sqrt(max(0.1f, mid * mid - det));
    float lambda2 = mid - sqrt(max(0.1f, mid * mid - det));
    float my_radius = ceil(3.f * sqrt(max(lambda1, lambda2)));
    float2 point_image = {ndc2Pix(p_proj.x, W), ndc2Pix(p_proj.y, H)};
    uint2 rect_min, rect_max;
    getRect(point_image, my_radius, rect_min, rect_max, grid);

    uint32_t prev_depth;
    uint2 prev_rect_min, prev_rect_max;
    unpack_rect(prev_gaussian_rect[idx], prev_depth, prev_rect_min, prev_rect_max);

    uint2 intersect_min = {max(rect_min.x, prev_rect_min.x), max(rect_min.y, prev_rect_min.y)};
    uint2 intersect_max = {min(rect_max.x, prev_rect_max.x), min(rect_max.y, prev_rect_max.y)};

    if ((rect_max.x - rect_min.x) * (rect_max.y - rect_min.y) == 0)
        return;

    glm::vec3 result = computeColorFromSH(idx, D, M, (glm::vec3 *)orig_points, *cam_pos, shs, clamped);

    float opacity = opacities[idx];

    int rect_area = (rect_max.y - rect_min.y) * (rect_max.x - rect_min.x);
    int intersect_area = (intersect_min.x > intersect_max.x || intersect_min.y > intersect_max.y)
                             ? 0
                             : (intersect_max.y - intersect_min.y) * (intersect_max.x - intersect_min.x);

    tiles_touched[idx] = rect_area - intersect_area;

    curr_gaussian_rect[idx] = pack_rect(p_view.z, rect_min, rect_max);
    curr_gaussian_data[3 * idx + 0] = {point_image.x, point_image.y, p_view.z, pack_rect(rect_min, rect_max)};
    curr_gaussian_data[3 * idx + 1] = {conic.x, conic.y, conic.z, opacity * h_convolution_scaling};
    curr_gaussian_data[3 * idx + 2] = {result.x, result.y, result.z, 0.0f};
}

// Main rasterization method. Collaboratively works on one tile per
// block, each thread treats one pixel. Alternates between fetching
// and rasterizing data.
template <uint32_t CHANNELS>
__global__ void __launch_bounds__(BLOCK_X *BLOCK_Y)
    renderCUDA(
        const uint2 *__restrict__ ranges,
        const uint32_t *__restrict__ point_list,
        int W, int H,
        float *__restrict__ final_T,
        uint32_t *__restrict__ n_contrib,
        const float *__restrict__ bg_color,
        float *__restrict__ out_color,
        const float *__restrict__ depths,
        float *__restrict__ invdepth,
        float4 *__restrict__ curr_gaussian_data) {
    auto block = cg::this_thread_block();
    uint32_t horizontal_blocks = (W + BLOCK_X - 1) / BLOCK_X;
    uint2 pix_min = {block.group_index().x * BLOCK_X, block.group_index().y * BLOCK_Y};
    uint2 pix_max = {min(pix_min.x + BLOCK_X, W), min(pix_min.y + BLOCK_Y, H)};
    uint2 pix = {pix_min.x + block.thread_index().x, pix_min.y + block.thread_index().y};
    uint32_t pix_id = W * pix.y + pix.x;
    float2 pixf = {(float)pix.x, (float)pix.y};

    bool inside = pix.x < W && pix.y < H;
    bool done = !inside;

    uint2 range = ranges[block.group_index().y * horizontal_blocks + block.group_index().x];
    const int rounds = ((range.y - range.x + BLOCK_SIZE - 1) / BLOCK_SIZE);
    int toDo = range.y - range.x;

    __shared__ int collected_id[BLOCK_SIZE];
    __shared__ float2 collected_xy[BLOCK_SIZE];
    __shared__ float4 collected_conic_opacity[BLOCK_SIZE];
    __shared__ float3 collected_features[BLOCK_SIZE];

    float T = 1.0f;
    uint32_t contributor = 0;
    uint32_t last_contributor = 0;
    float C[CHANNELS] = {0};

    for (int i = 0; i < rounds; i++, toDo -= BLOCK_SIZE) {
        int num_done = __syncthreads_count(done);
        if (num_done == BLOCK_SIZE)
            break;

        int progress = i * BLOCK_SIZE + block.thread_rank();
        if (range.x + progress < range.y) {
            int coll_id = point_list[range.x + progress];

            float4 data1 = curr_gaussian_data[3 * coll_id + 0];
            float4 data2 = curr_gaussian_data[3 * coll_id + 1];
            float4 data3 = curr_gaussian_data[3 * coll_id + 2];

            float2 xy = {data1.x, data1.y};
            float4 con_o = {data2.x, data2.y, data2.z, data2.w};
            float3 features = {data3.x, data3.y, data3.z};

            collected_id[block.thread_rank()] = coll_id;
            collected_xy[block.thread_rank()] = xy;
            collected_conic_opacity[block.thread_rank()] = con_o;
            collected_features[block.thread_rank()] = features;
        }
        block.sync();

        for (int j = 0; !done && j < min(BLOCK_SIZE, toDo); j++) {
            contributor++;

            float2 xy = collected_xy[j];
            float2 d = {xy.x - pixf.x, xy.y - pixf.y};
            float4 con_o = collected_conic_opacity[j];
            float3 features = collected_features[j];
            float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;
            if (power > 0.0f)
                continue;
            float alpha = min(0.99f, con_o.w * exp(power));
            if (alpha < 1.0f / 255.0f)
                continue;
            float test_T = T * (1 - alpha);
            if (test_T < 0.0001f) {
                done = true;
                continue;
            }

            C[0] += features.x * alpha * T;
            C[1] += features.y * alpha * T;
            C[2] += features.z * alpha * T;

            T = test_T;

            last_contributor = contributor;
        }
    }

    if (inside) {
        final_T[pix_id] = T;
        n_contrib[pix_id] = last_contributor;
        for (int ch = 0; ch < CHANNELS; ch++)
            out_color[ch * H * W + pix_id] = C[ch] + T * bg_color[ch];
    }
}

template <uint32_t CHANNELS>
__global__ void __launch_bounds__(BLOCK_X *BLOCK_Y)
    render_reuseCUDA(
        uint64_t *__restrict__ gaussian_keys,
        const uint32_t *__restrict__ gaussian_values,
        const uint32_t *__restrict__ ranges,
        const uint64_t *__restrict__ gaussian_rect,
        int W, int H,
        const float2 *__restrict__ points_xy_image,
        const float *__restrict__ features,
        const float4 *__restrict__ conic_opacity,
        float *__restrict__ final_T,
        uint32_t *__restrict__ n_contrib,
        const float *__restrict__ bg_color,
        float *__restrict__ out_color,
        const float *__restrict__ depths,
        float *__restrict__ invdepth,
        float4 *__restrict__ curr_gaussian_data) {
    auto block = cg::this_thread_block();
    uint32_t horizontal_blocks = (W + BLOCK_X - 1) / BLOCK_X;
    uint2 pix_min = {block.group_index().x * BLOCK_X, block.group_index().y * BLOCK_Y};
    uint2 pix_max = {min(pix_min.x + BLOCK_X, W), min(pix_min.y + BLOCK_Y, H)};
    uint2 pix = {pix_min.x + block.thread_index().x, pix_min.y + block.thread_index().y};
    uint32_t pix_id = W * pix.y + pix.x;
    float2 pixf = {(float)pix.x, (float)pix.y};

    bool inside = pix.x < W && pix.y < H;
    bool done = !inside;

    int tile_id = block.group_index().y * horizontal_blocks + block.group_index().x;
    uint32_t range = ranges[tile_id];
    const int rounds = ((range + BLOCK_SIZE - 1) / BLOCK_SIZE);
    int toDo = range;
    const int offset = MAX_ELEMENTS_IN_TILE * tile_id;

    __shared__ int collected_id[BLOCK_SIZE];
    __shared__ float2 collected_xy[BLOCK_SIZE];
    __shared__ float4 collected_conic_opacity[BLOCK_SIZE];
    __shared__ float3 collected_features[BLOCK_SIZE];

    float T = 1.0f;
    uint32_t contributor = 0;
    uint32_t last_contributor = 0;
    float C[CHANNELS] = {0};

    for (int i = 0; i < rounds; i++, toDo -= BLOCK_SIZE) {
        // int num_done = __syncthreads_count(done);
        // if (num_done == BLOCK_SIZE)
        //     break;

        int progress = i * BLOCK_SIZE + block.thread_rank();
        if (progress < range) {
            int coll_id = gaussian_values[offset + progress];

            float4 data1 = curr_gaussian_data[3 * coll_id + 0];
            float4 data2 = curr_gaussian_data[3 * coll_id + 1];
            float4 data3 = curr_gaussian_data[3 * coll_id + 2];

            float2 xy = {data1.x, data1.y};
            float f_depth = data1.z;
            uint32_t depth = *((uint32_t *)&f_depth);
            float f_rect = data1.w;
            float4 con_o = {data2.x, data2.y, data2.z, data2.w};
            float3 features = {data3.x, data3.y, data3.z};

            collected_id[block.thread_rank()] = coll_id;
            collected_xy[block.thread_rank()] = xy;
            collected_conic_opacity[block.thread_rank()] = con_o;
            collected_features[block.thread_rank()] = features;

            uint2 rect_min, rect_max;
            unpack_rect(f_rect, rect_min, rect_max);

            bool valid = (rect_min.x <= block.group_index().x &&
                          rect_max.x > block.group_index().x &&
                          rect_min.y <= block.group_index().y &&
                          rect_max.y > block.group_index().y);
            uint64_t new_key = tile_id;
            new_key <<= 1;
            new_key |= (valid ? 1 : 0);
            new_key <<= 32;
            new_key |= depth;

            gaussian_keys[offset + progress] = new_key;
        }
        block.sync();

        for (int j = 0; !done && j < min(BLOCK_SIZE, toDo); j++) {
            contributor++;

            float2 xy = collected_xy[j];
            float2 d = {xy.x - pixf.x, xy.y - pixf.y};
            float4 con_o = collected_conic_opacity[j];
            float3 features = collected_features[j];
            float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;
            if (power > 0.0f)
                continue;

            float alpha = min(0.99f, con_o.w * exp(power));
            if (alpha < 1.0f / 255.0f)
                continue;
            float test_T = T * (1 - alpha);
            if (test_T < 0.0001f) {
                done = true;
                continue;
            }

            C[0] += features.x * alpha * T;
            C[1] += features.y * alpha * T;
            C[2] += features.z * alpha * T;

            T = test_T;

            last_contributor = contributor;
        }
        block.sync();
    }

    // for (; i < rounds; i++, toDo -= BLOCK_SIZE) {
    //     int progress = i * BLOCK_SIZE + block.thread_rank();
    //     if (progress < range) {
    //         int coll_id = gaussian_values[offset + progress];

    //         float4 data1 = curr_gaussian_data[3 * coll_id + 0];

    //         float2 xy = {data1.x, data1.y};
    //         float f_depth = data1.z;
    //         uint32_t depth = *((uint32_t *)&f_depth);
    //         float f_rect = data1.w;

    //         uint2 rect_min, rect_max;
    //         unpack_rect(f_rect, rect_min, rect_max);

    //         bool valid = (rect_min.x <= block.group_index().x &&
    //                       rect_max.x > block.group_index().x &&
    //                       rect_min.y <= block.group_index().y &&
    //                       rect_max.y > block.group_index().y);
    //         uint64_t new_key = tile_id;
    //         new_key <<= 1;
    //         new_key |= (valid ? 1 : 0);
    //         new_key <<= 32;
    //         new_key |= depth;

    //         gaussian_keys[offset + progress] = new_key;
    //     }
    // }

    if (inside) {
        final_T[pix_id] = T;
        n_contrib[pix_id] = last_contributor;
        for (int ch = 0; ch < CHANNELS; ch++)
            out_color[ch * H * W + pix_id] = C[ch] + T * bg_color[ch];
    }
}

void FORWARD::render(
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
    float *curr_gaussian_data) {
    renderCUDA<NUM_CHANNELS><<<grid, block>>>(
        ranges,
        point_list,
        W, H,
        final_T,
        n_contrib,
        bg_color,
        out_color,
        depths,
        depth,
        (float4 *)curr_gaussian_data);
}

void FORWARD::render_reuse(
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
    float *curr_gaussian_data) {
    render_reuseCUDA<NUM_CHANNELS><<<grid, block>>>(
        gaussian_keys,
        gaussian_values,
        ranges,
        gaussian_rect,
        W, H,
        means2D,
        colors,
        conic_opacity,
        final_T,
        n_contrib,
        bg_color,
        out_color,
        depths,
        depth,
        (float4 *)curr_gaussian_data);
}

void FORWARD::preprocess(int P, int D, int M,
                         const float *means3D,
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
                         float2 *means2D,
                         float *depths,
                         float *cov3Ds,
                         float *rgb,
                         float4 *conic_opacity,
                         const dim3 grid,
                         uint32_t *tiles_touched,
                         bool prefiltered,
                         bool antialiasing,
                         bool is_reuse,
                         uint64_t *prev_gaussian_rect,
                         uint64_t *curr_gaussian_rect,
                         float *prev_gaussian_data,
                         float *curr_gaussian_data) {
    if (!is_reuse) {
        preprocessCUDA<NUM_CHANNELS><<<(P + 255) / 256, 256>>>(
            P, D, M,
            means3D,
            scales,
            scale_modifier,
            rotations,
            opacities,
            shs,
            clamped,
            cov3D_precomp,
            colors_precomp,
            viewmatrix,
            projmatrix,
            cam_pos,
            W, H,
            tan_fovx, tan_fovy,
            focal_x, focal_y,
            radii,
            means2D,
            depths,
            cov3Ds,
            rgb,
            conic_opacity,
            grid,
            tiles_touched,
            prefiltered,
            antialiasing,
            prev_gaussian_rect,
            curr_gaussian_rect,
            (float4 *)prev_gaussian_data,
            (float4 *)curr_gaussian_data);
    } else {
        preprocess_reuseCUDA<NUM_CHANNELS><<<(P + 255) / 256, 256>>>(
            P, D, M,
            means3D,
            scales,
            scale_modifier,
            rotations,
            opacities,
            shs,
            clamped,
            cov3D_precomp,
            colors_precomp,
            viewmatrix,
            projmatrix,
            cam_pos,
            W, H,
            tan_fovx, tan_fovy,
            focal_x, focal_y,
            radii,
            means2D,
            depths,
            cov3Ds,
            rgb,
            conic_opacity,
            grid,
            tiles_touched,
            prefiltered,
            antialiasing,
            prev_gaussian_rect,
            curr_gaussian_rect,
            (float4 *)prev_gaussian_data,
            (float4 *)curr_gaussian_data);
    }
}

__global__ void copyingCUDA(
    int T,
    const uint2 *ranges,
    const uint64_t *src_keys_sorted,
    const uint32_t *src_values_sorted,
    uint64_t *dst_keys_sorted,
    uint32_t *dst_values_sorted,
    uint32_t *dst_ranges_sorted) {
    auto idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= T)
        return;

    uint2 range = ranges[idx];
    const int offset = MAX_ELEMENTS_IN_TILE * idx;
    const int len = range.y - range.x;

    dst_ranges_sorted[idx] = len;

    for (int i = 0; i < len; i++) {
        int src_idx = range.x + i;
        int dst_idx = offset + i;

        dst_keys_sorted[dst_idx] = src_keys_sorted[src_idx];
        dst_values_sorted[dst_idx] = src_values_sorted[src_idx];
    }
}

void FORWARD::copying(
    int T,
    const uint2 *ranges,
    const uint64_t *src_keys_sorted,
    const uint32_t *src_values_sorted,
    uint64_t *dst_keys_sorted,
    uint32_t *dst_values_sorted,
    uint32_t *dst_ranges_sorted) {
    copyingCUDA<<<(T + 255) / 256, 256>>>(
        T,
        ranges,
        src_keys_sorted,
        src_values_sorted,
        dst_keys_sorted,
        dst_values_sorted,
        dst_ranges_sorted);
}

__global__ void mergingCUDA(
    int T,
    const uint32_t *prev_ranges,
    const uint64_t *prev_keys_sorted,
    const uint32_t *prev_values_sorted,
    const uint2 *curr_ranges,
    const uint64_t *curr_keys_sorted,
    const uint32_t *curr_values_sorted,
    uint32_t *merge_ranges,
    uint64_t *merged_keys_sorted,
    uint32_t *merged_values_sorted) {
    auto idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= T)
        return;

    int offset = MAX_ELEMENTS_IN_TILE * idx; // 2^14, used to ensure that the range is within bounds

    int prev_range = prev_ranges[idx];
    int curr_range = curr_ranges[idx].y - curr_ranges[idx].x;

    int prev_idx = 0;
    int curr_idx = 0;
    int merge_idx = 0;
    while (prev_idx < prev_range || curr_idx < curr_range) {
        uint32_t prev_test = (prev_idx < prev_range) ? prev_keys_sorted[offset + prev_idx] >> 32 : 1;

        if ((prev_test & 1) == 0) {
            prev_idx++;
            continue;
        }

        uint32_t prev_depth = (prev_idx < prev_range) ? prev_keys_sorted[offset + prev_idx] & 0xFFFFFFFF : UINT32_MAX;
        uint32_t curr_depth = (curr_idx < curr_range) ? curr_keys_sorted[curr_ranges[idx].x + curr_idx] & 0xFFFFFFFF : UINT32_MAX;

        if (prev_depth <= curr_depth) {
            merged_keys_sorted[offset + merge_idx] = prev_keys_sorted[offset + prev_idx];
            merged_values_sorted[offset + merge_idx] = prev_values_sorted[offset + prev_idx];
            prev_idx++;
            merge_idx++;
        } else {
            merged_keys_sorted[offset + merge_idx] = curr_keys_sorted[curr_ranges[idx].x + curr_idx];
            merged_values_sorted[offset + merge_idx] = curr_values_sorted[curr_ranges[idx].x + curr_idx];
            curr_idx++;
            merge_idx++;
        }
    }

    merge_ranges[idx] = merge_idx;
}

void FORWARD::merging(
    int T,
    const uint32_t *prev_ranges,
    const uint64_t *prev_keys_sorted,
    const uint32_t *prev_values_sorted,
    const uint2 *curr_ranges,
    const uint64_t *curr_keys_sorted,
    const uint32_t *curr_values_sorted,
    uint32_t *merge_ranges,
    uint64_t *merged_keys_sorted,
    uint32_t *merged_values_sorted) {
    mergingCUDA<<<(T + 255) / 256, 256>>>(
        T,
        prev_ranges,
        prev_keys_sorted,
        prev_values_sorted,
        curr_ranges,
        curr_keys_sorted,
        curr_values_sorted,
        merge_ranges,
        merged_keys_sorted,
        merged_values_sorted);
}

struct Pair {
    __host__ __device__ __forceinline__ Pair() {
    }

    __host__ __device__ __forceinline__ Pair(uint64_t key, uint32_t value)
        : k(key), v(value) {
    }

    __host__ __device__ __forceinline__ bool
    operator==(const Pair &rhs) const {
        return (k == rhs.k) && (v == rhs.v);
    }

    __host__ __device__ __forceinline__ bool
    operator!=(const Pair &rhs) const {
        return !operator==(rhs);
    }

    __host__ __device__ __forceinline__ bool
    operator<(const Pair &rhs) const {
        return (k < rhs.k) || ((k == rhs.k) && (v < rhs.v));
    }

    __host__ __device__ __forceinline__ bool
    operator>(const Pair &rhs) const {
        return (k > rhs.k) || ((k == rhs.k) && (v > rhs.v));
    }

    uint64_t k;
    uint32_t v;
};

__device__ __forceinline__ int getLaneId() {
    int laneId;
    asm("mov.s32 %0, %laneid;" : "=r"(laneId));
    return laneId;
}

template <typename T>
__device__ __forceinline__ T shfl_up(const T val, int delta) {
    return __shfl_up_sync(0xFFFFFFFF, val, delta);
}

template <typename T>
struct LessThan {
    static __device__ __forceinline__ bool compare(const T lhs, const T rhs) {
        return (lhs < rhs);
    }
};

__device__ __forceinline__ Pair shfl_xor(const Pair &p, int laneMask, int width = WARP_SIZE) {
    return Pair(
        __shfl_xor_sync(0xFFFFFFFF, p.k, laneMask, width),
        __shfl_xor_sync(0xFFFFFFFF, p.v, laneMask, width));
}

__device__ __forceinline__ Pair shflSwap(const Pair x, int mask, int dir) {
    Pair y = shfl_xor(x, mask);
    return LessThan<Pair>::compare(x, y) == dir ? y : x;
}

__device__ __forceinline__ int getBit(int val, int pos) {
    int ret;
    asm("bfe.u32 %0, %1, %2, 1;" : "=r"(ret) : "r"(val), "r"(pos));
    return ret;
}

__device__ Pair warpBitonicSort(Pair val) {
    const int laneId = getLaneId();
    // 2
    val = shflSwap(val, 0x01, getBit(laneId, 1) ^ getBit(laneId, 0));

    // 4
    val = shflSwap(val, 0x02, getBit(laneId, 2) ^ getBit(laneId, 1));
    val = shflSwap(val, 0x01, getBit(laneId, 2) ^ getBit(laneId, 0));

    // 8
    val = shflSwap(val, 0x04, getBit(laneId, 3) ^ getBit(laneId, 2));
    val = shflSwap(val, 0x02, getBit(laneId, 3) ^ getBit(laneId, 1));
    val = shflSwap(val, 0x01, getBit(laneId, 3) ^ getBit(laneId, 0));

    // 16
    val = shflSwap(val, 0x08, getBit(laneId, 4) ^ getBit(laneId, 3));
    val = shflSwap(val, 0x04, getBit(laneId, 4) ^ getBit(laneId, 2));
    val = shflSwap(val, 0x02, getBit(laneId, 4) ^ getBit(laneId, 1));
    val = shflSwap(val, 0x01, getBit(laneId, 4) ^ getBit(laneId, 0));

    // 32
    val = shflSwap(val, 0x10, getBit(laneId, 4));
    val = shflSwap(val, 0x08, getBit(laneId, 3));
    val = shflSwap(val, 0x04, getBit(laneId, 2));
    val = shflSwap(val, 0x02, getBit(laneId, 1));
    val = shflSwap(val, 0x01, getBit(laneId, 0));

    return val;
}

__device__ __forceinline__ int warpSum(int val) {
    for (int offset = 16; offset > 0; offset /= 2)
        val += __shfl_down_sync(0xFFFFFFFF, val, offset);
    int total = __shfl_sync(0xFFFFFFFF, val, 0);
    return total;
}

__device__ __forceinline__ void saveHalfWarp(
    Pair merge_pair,
    uint64_t *merged_keys_sorted,
    uint32_t *merged_values_sorted,
    int merge_offset,
    int merge_idx,
    int validSum) {

    int laneId = getLaneId();
    int start_laneId = HALF_WARP_SIZE - validSum;

    if (laneId >= start_laneId && laneId < HALF_WARP_SIZE) {
        int idx = merge_offset + merge_idx + (laneId - start_laneId);
        merged_keys_sorted[idx] = merge_pair.k;
        merged_values_sorted[idx] = merge_pair.v;
    }
}

__device__ __forceinline__ void saveFullWarp(
    Pair merge_pair,
    uint64_t *merged_keys_sorted,
    uint32_t *merged_values_sorted,
    int merge_offset,
    int merge_idx,
    int validSum) {

    int laneId = getLaneId();
    int start_laneId = WARP_SIZE - validSum;

    if (laneId >= start_laneId) {
        int idx = merge_offset + merge_idx + (laneId - start_laneId);
        merged_keys_sorted[idx] = merge_pair.k;
        merged_values_sorted[idx] = merge_pair.v;
    }
}

__device__ __forceinline__ Pair getMulti(
    Pair merge_pair,
    const uint64_t *keys_sorted,
    const uint32_t *values_sorted,
    int offset,
    int idx,
    int len) {

    int laneId = getLaneId();
    idx = idx + laneId;

    Pair new_pair;
    new_pair.k = (idx < len) ? keys_sorted[offset + idx] : 0;
    new_pair.v = (idx < len) ? values_sorted[offset + idx] : 0xFFFFFFFF;

    return (laneId < HALF_WARP_SIZE) ? new_pair : merge_pair;
}

__global__ void optimized_mergingCUDA(
    int T,
    const uint32_t *prev_ranges,
    const uint64_t *prev_keys_sorted,
    const uint32_t *prev_values_sorted,
    const uint2 *curr_ranges,
    const uint64_t *curr_keys_sorted,
    const uint32_t *curr_values_sorted,
    uint32_t *merge_ranges,
    uint64_t *merged_keys_sorted,
    uint32_t *merged_values_sorted) {
    auto block = cg::this_thread_block();
    int tile_id = block.group_index().x;

    int prev_offset = MAX_ELEMENTS_IN_TILE * tile_id;
    int prev_len = prev_ranges[tile_id];

    int curr_offset = curr_ranges[tile_id].x;
    int curr_len = (curr_ranges[tile_id].y - curr_ranges[tile_id].x);

    int merge_offset = MAX_ELEMENTS_IN_TILE * tile_id;

    const int laneId = getLaneId();

    Pair merge_pair;
    merge_pair.k = shfl_up((laneId < curr_len) ? curr_keys_sorted[curr_offset + laneId] : uint64_t(0), HALF_WARP_SIZE);
    merge_pair.v = shfl_up((laneId < curr_len) ? curr_values_sorted[curr_offset + laneId] : uint32_t(0xFFFFFFFF), HALF_WARP_SIZE);

    merge_pair.k = (laneId < HALF_WARP_SIZE) ? ((laneId < prev_len) ? prev_keys_sorted[prev_offset + laneId] : uint64_t(0))
                                             : merge_pair.k;
    merge_pair.v = (laneId < HALF_WARP_SIZE) ? ((laneId < prev_len) ? prev_values_sorted[prev_offset + laneId] : uint32_t(0xFFFFFFFF))
                                             : merge_pair.v;

    int prev_idx = min(HALF_WARP_SIZE, prev_len);
    int curr_idx = min(HALF_WARP_SIZE, curr_len);
    int merge_idx = 0;

    while (prev_idx < prev_len || curr_idx < curr_len) {
        merge_pair = warpBitonicSort(merge_pair);

        int valid = (laneId < HALF_WARP_SIZE) ? ((merge_pair.k >> 32) & 0x1) : 0;
        int validSum = warpSum(valid);
        saveHalfWarp(merge_pair, merged_keys_sorted, merged_values_sorted, merge_offset, merge_idx, validSum);
        merge_idx = merge_idx + validSum;

        if (prev_idx >= prev_len) {
            merge_pair = getMulti(merge_pair, curr_keys_sorted, curr_values_sorted, curr_offset, curr_idx, curr_len);
            curr_idx = min(curr_idx + HALF_WARP_SIZE, curr_len);
        } else if (curr_idx >= curr_len) {
            merge_pair = getMulti(merge_pair, prev_keys_sorted, prev_values_sorted, prev_offset, prev_idx, prev_len);
            prev_idx = min(prev_idx + HALF_WARP_SIZE, prev_len);
        } else {
            const uint32_t prev_depth = prev_keys_sorted[prev_offset + prev_idx];
            const uint32_t curr_depth = curr_keys_sorted[curr_offset + curr_idx];

            if (prev_depth < curr_depth) {
                merge_pair = getMulti(merge_pair, prev_keys_sorted, prev_values_sorted, prev_offset, prev_idx, prev_len);
                prev_idx = min(prev_idx + HALF_WARP_SIZE, prev_len);
            } else {
                merge_pair = getMulti(merge_pair, curr_keys_sorted, curr_values_sorted, curr_offset, curr_idx, curr_len);
                curr_idx = min(curr_idx + HALF_WARP_SIZE, curr_len);
            }
        }
    }

    merge_pair = warpBitonicSort(merge_pair);

    int valid = (merge_pair.k >> 32) & 0x1;
    int validSum = warpSum(valid);
    saveFullWarp(merge_pair, merged_keys_sorted, merged_values_sorted, merge_offset, merge_idx, validSum);
    merge_idx = merge_idx + validSum;

    if (laneId == 0)
        merge_ranges[tile_id] = merge_idx;
}

void FORWARD::optimized_merging(
    int T,
    const uint32_t *prev_ranges,
    const uint64_t *prev_keys_sorted,
    const uint32_t *prev_values_sorted,
    const uint2 *curr_ranges,
    const uint64_t *curr_keys_sorted,
    const uint32_t *curr_values_sorted,
    uint32_t *merge_ranges,
    uint64_t *merged_keys_sorted,
    uint32_t *merged_values_sorted) {
    dim3 grid(T);
    dim3 block(32);

    optimized_mergingCUDA<<<grid, block>>>(
        T,
        prev_ranges,
        prev_keys_sorted,
        prev_values_sorted,
        curr_ranges,
        curr_keys_sorted,
        curr_values_sorted,
        merge_ranges,
        merged_keys_sorted,
        merged_values_sorted);
}

__global__ void dynamic_partial_sortingCUDA(
    bool is_even,
    int T,
    const uint32_t *ranges,
    uint64_t *keys,
    uint32_t *values) {
    int tile_id = blockIdx.y;
    int len = ranges[tile_id];
    int idx = threadIdx.x + blockIdx.x * MAX_THREADS_PER_BLOCK;

    if (idx >= ((len + WARP_SIZE - 1) / WARP_SIZE) * WARP_SIZE)
        return;

    Pair sort_pair;

    int offset = MAX_ELEMENTS_IN_TILE * tile_id;
    uint64_t max_key = uint64_t(0x00FFFFFF) << 33;

    if (is_even) {
        sort_pair.k = (idx < len) ? keys[offset + idx] : max_key;
        sort_pair.v = (idx < len) ? values[offset + idx] : 0;

        sort_pair = warpBitonicSort(sort_pair);

        if (idx < len) {
            keys[offset + idx] = sort_pair.k;
            values[offset + idx] = sort_pair.v;
        }
    } else {
        int psuedo_idx = idx + (WARP_SIZE / 2);

        sort_pair.k = (psuedo_idx < len) ? keys[offset + psuedo_idx] : max_key;
        sort_pair.v = (psuedo_idx < len) ? values[offset + psuedo_idx] : 0;

        sort_pair = warpBitonicSort(sort_pair);

        if (psuedo_idx < len) {
            keys[offset + psuedo_idx] = sort_pair.k;
            values[offset + psuedo_idx] = sort_pair.v;
        }
    }
}

void FORWARD::dynamic_partial_sorting(
    bool is_even,
    int T,
    const uint32_t *ranges,
    uint64_t *keys,
    uint32_t *values) {
    dim3 grid(MAX_ELEMENTS_IN_TILE / MAX_THREADS_PER_BLOCK, T);
    dim3 block(MAX_THREADS_PER_BLOCK);

    dynamic_partial_sortingCUDA<<<grid, block>>>(
        is_even,
        T,
        ranges,
        keys,
        values);
}
