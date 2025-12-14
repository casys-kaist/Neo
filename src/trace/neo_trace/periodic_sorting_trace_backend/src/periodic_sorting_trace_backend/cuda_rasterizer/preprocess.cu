#include "auxiliary.h"
#include "preprocess.h"
#include "variable.h"

#include <cooperative_groups.h>
#include <cooperative_groups/reduce.h>
#include <cuda.h>

#define GLM_FORCE_CUDA
#include <glm/glm.hpp>

namespace cg = cooperative_groups;

namespace poc {

__device__ void computeCov3D(const glm::vec3 scale, const glm::vec4 rot, float *cov3D) {
    glm::mat3 S = glm::mat3(1.0f);
    S[0][0] = scale.x;
    S[1][1] = scale.y;
    S[2][2] = scale.z;

    glm::vec4 q = rot;
    float r = q.x;
    float x = q.y;
    float y = q.z;
    float z = q.w;

    glm::mat3 R = glm::mat3(
        1.f - 2.f * (y * y + z * z), 2.f * (x * y - r * z), 2.f * (x * z + r * y),
        2.f * (x * y + r * z), 1.f - 2.f * (x * x + z * z), 2.f * (y * z - r * x),
        2.f * (x * z - r * y), 2.f * (y * z + r * x), 1.f - 2.f * (x * x + y * y));

    glm::mat3 M = S * R;

    glm::mat3 Sigma = glm::transpose(M) * M;

    cov3D[0] = Sigma[0][0];
    cov3D[1] = Sigma[0][1];
    cov3D[2] = Sigma[0][2];
    cov3D[3] = Sigma[1][1];
    cov3D[4] = Sigma[1][2];
    cov3D[5] = Sigma[2][2];
}

__device__ float3 computeCov2D(const float3 &mean, float focal_x, float focal_y, float tan_fovx, float tan_fovy, const float *cov3D, const float *viewmatrix) {
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

    cov[0][0] += 0.3f;
    cov[1][1] += 0.3f;
    return {float(cov[0][0]), float(cov[0][1]), float(cov[1][1])};
}

__device__ glm::vec3 computeColorFromSH(int idx, int deg, int max_coeffs, const glm::vec3 *means, glm::vec3 campos, const float *shs) {
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
    return glm::max(result, 0.0f);
}

template <int C>
__global__ void preprocessCUDA(
    // Tile Inputs
    const dim3 grid,
    const int tile_size,

    // Camera Inputs
    const float tan_fovx, float tan_fovy,
    const float focal_x, float focal_y,
    const float *viewmatrix,
    const float *projmatrix,
    const glm::vec3 *cam_pos,
    const int W, int H,

    // 3D Gaussian Inputs
    const int P, int D, int M,
    const float *means3D,
    const float *opacities,
    const glm::vec3 *scales,
    const glm::vec4 *rotations,
    const float *SHs,

    // 2D Gaussian Outputs
    float2 *means2D,
    float4 *conic_opacity,
    float *rgb,
    int *radii,
    float *depths,
    float *first_eigen_vec, float *first_eigen_val,
    float *second_eigen_vec, float *second_eigen_val,
    int *frustum_culling) {
    auto idx = cg::this_grid().thread_rank();
    if (idx >= P)
        return;

    means2D[idx] = {0, 0};
    conic_opacity[idx] = {0, 0, 0};
    rgb[idx * C + 0] = 0;
    rgb[idx * C + 1] = 0;
    rgb[idx * C + 2] = 0;
    radii[idx] = 0;
    depths[idx] = 0;
    first_eigen_vec[2 * idx] = 0;
    first_eigen_vec[2 * idx + 1] = 0;
    first_eigen_val[idx] = 0;
    second_eigen_vec[2 * idx] = 0;
    second_eigen_vec[2 * idx + 1] = 0;
    second_eigen_val[idx] = 0;
    frustum_culling[idx] = 1;

    float3 p_view;
    if (!in_frustum(idx, means3D, viewmatrix, projmatrix, p_view))
        return;

    float3 p_orig = {means3D[3 * idx], means3D[3 * idx + 1], means3D[3 * idx + 2]};
    float4 p_hom = transformPoint4x4(p_orig, projmatrix);
    float p_w = 1.0f / (p_hom.w + 0.0000001f);
    float3 p_proj = {p_hom.x * p_w, p_hom.y * p_w, p_hom.z * p_w};

    float cov3D[6];
    computeCov3D(scales[idx], rotations[idx], cov3D);

    float3 cov = computeCov2D(p_orig, focal_x, focal_y, tan_fovx, tan_fovy, cov3D, viewmatrix);

    float det = (cov.x * cov.z - cov.y * cov.y);
    if (det == 0.0f)
        return;
    float det_inv = 1.f / det;
    float3 conic = {cov.z * det_inv, -cov.y * det_inv, cov.x * det_inv};

    float mid = 0.5f * (cov.x + cov.z);
    float lambda1 = mid + sqrt(max(0.1f, mid * mid - det));
    float lambda2 = mid - sqrt(max(0.1f, mid * mid - det));
    float my_radius = ceil(3.f * sqrt(max(lambda1, lambda2)));
    float2 point_image = {ndc2Pix(p_proj.x, W), ndc2Pix(p_proj.y, H)};

    float2 e_vec1, e_vec2;
    e_vec1 = {cov.y, lambda1 - cov.x};

    float length = sqrt(e_vec1.x * e_vec1.x + e_vec1.y * e_vec1.y);
    e_vec1 = {e_vec1.x / length, e_vec1.y / length};
    e_vec2 = {-1.0f * e_vec1.y, e_vec1.x};

    float e_val1, e_val2;
    e_val1 = 3.f * sqrt(lambda1);
    e_val2 = 3.f * sqrt(lambda2);

    glm::vec3 result = computeColorFromSH(idx, D, M, (glm::vec3 *)means3D, *cam_pos, SHs);

    means2D[idx] = point_image;

    conic_opacity[idx] = {conic.x, conic.y, conic.z, opacities[idx]};

    rgb[idx * C + 0] = result.x;
    rgb[idx * C + 1] = result.y;
    rgb[idx * C + 2] = result.z;

    radii[idx] = my_radius;

    depths[idx] = p_view.z;

    first_eigen_vec[2 * idx] = e_vec1.x;
    first_eigen_vec[2 * idx + 1] = e_vec1.y;
    first_eigen_val[idx] = e_val1;

    second_eigen_vec[2 * idx] = e_vec2.x;
    second_eigen_vec[2 * idx + 1] = e_vec2.y;
    second_eigen_val[idx] = e_val2;

    frustum_culling[idx] = 0;
}

static void preprocessCUDA_wrapper(
    // Tile Inputs
    const dim3 grid,
    const int tile_size,

    // Camera Inputs
    const float tan_fovx, float tan_fovy,
    const float *viewmatrix,
    const float *projmatrix,
    const glm::vec3 *cam_pos,
    const int W, int H,

    // 3D Gaussian Inputs
    const int P, int D, int M,
    const float *means3D,
    const float *opacities,
    const glm::vec3 *scales,
    const glm::vec4 *rotations,
    const float *SHs,

    // 2D Gaussian Outputs
    float2 *means2D,
    float4 *conic_opacity,
    float *rgb,
    int *radii,
    float *depths,
    float *first_eigen_vec, float *first_eigen_val,
    float *second_eigen_vec, float *second_eigen_val,
    int *frustum_culling) {
    const float focal_x = W / (2.0f * tan_fovx);
    const float focal_y = H / (2.0f * tan_fovy);

    preprocessCUDA<NUM_CHANNELS><<<(P + 255) / 256, 256>>>(
        // Tile Inputs
        grid,
        tile_size,

        // Camera Inputs
        tan_fovx, tan_fovy,
        focal_x, focal_y,
        viewmatrix,
        projmatrix,
        cam_pos,
        W, H,

        // 3D Gaussian Inputs
        P, D, M,
        means3D,
        opacities,
        scales,
        rotations,
        SHs,

        // 2D Gaussian Outputs
        means2D,
        conic_opacity,
        rgb,
        radii,
        depths,
        first_eigen_vec, first_eigen_val,
        second_eigen_vec, second_eigen_val,
        frustum_culling);
}

void preprocess() {
    const dim3 tile_grid(TILE_WIDTH, TILE_HEIGHT, 1);

    preprocessCUDA_wrapper(
        // Tile Inputs
        tile_grid,
        g_tile_size,

        // Camera Inputs
        g_cam[g_curr_cam].tan_fovx, g_cam[g_curr_cam].tan_fovy,
        g_cam[g_curr_cam].view_matrix,
        g_cam[g_curr_cam].proj_matrix,
        (glm::vec3 *)g_cam[g_curr_cam].cam_pos,
        g_W, g_H,

        // 3D Gaussian Inputs
        g_P, g_D, g_M,
        g_gaussian_mean3D,
        g_gaussian_opacity,
        (glm::vec3 *)g_gaussian_scale,
        (glm::vec4 *)g_gaussian_rotation,
        g_gaussian_SH,

        // 2D Gaussian Outputs
        (float2 *)g_gaussian_mean2D[g_curr_cam],
        (float4 *)g_gaussian_conic_opacity[g_curr_cam],
        g_gaussian_rgb[g_curr_cam],
        g_gaussian_radii[g_curr_cam],
        g_gaussian_depth[g_curr_cam],
        g_gaussian_eigen_vector[g_curr_cam][0], g_gaussian_eigen_value[g_curr_cam][0],
        g_gaussian_eigen_vector[g_curr_cam][1], g_gaussian_eigen_value[g_curr_cam][1],
        g_gaussian_is_frustum_culled[g_curr_cam]);
}

} // namespace poc
