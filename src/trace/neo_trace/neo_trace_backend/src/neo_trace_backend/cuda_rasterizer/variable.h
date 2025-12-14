#ifndef VARIABLE_H
#define VARIABLE_H

#include <iostream>
#include <string>
#include <vector>

namespace poc {
// Basic Information
extern int g_W, g_H;
extern int g_tile_size;
extern int g_min_tile_size;
extern int g_chunk_size;

#define TILE_WIDTH ((g_W + g_tile_size - 1) / g_tile_size)
#define TILE_HEIGHT ((g_H + g_tile_size - 1) / g_tile_size)
#define NUM_TILE (TILE_WIDTH * TILE_HEIGHT)
#define NUM_CHANNELS 3

// Camera Information
struct cam_t {
    float tan_fovx, tan_fovy;
    float *view_matrix;
    float *proj_matrix;
    float *cam_pos;
};

extern cam_t g_cam[2];

// 3D Gaussian Information
extern float *g_gaussian_mean3D;
extern float *g_gaussian_opacity;
extern float *g_gaussian_scale;
extern float *g_gaussian_rotation;
extern float *g_gaussian_SH;

// 2D Gaussian Information (GPU)
extern float *g_gaussian_mean2D[2];
extern float *g_gaussian_conic_opacity[2];
extern float *g_gaussian_rgb[2];
extern int *g_gaussian_radii[2];
extern float *g_gaussian_depth[2];
extern float *g_gaussian_eigen_vector[2][2];
extern float *g_gaussian_eigen_value[2][2];
extern int *g_gaussian_is_frustum_culled[2];

// 2D Gaussian Information (CPU)
extern int g_P, g_D, g_M;

extern float *g_gaussian_mean2D_cpu[2];
extern float *g_gaussian_conic_opacity_cpu[2];
extern float *g_gaussian_rgb_cpu[2];
extern int *g_gaussian_radii_cpu[2];
extern float *g_gaussian_depth_cpu[2];
extern float *g_gaussian_eigen_vector_cpu[2][2];
extern float *g_gaussian_eigen_value_cpu[2][2];
extern int *g_gaussian_is_frustum_culled_cpu[2];

// Trace Information
extern bool g_trace;
extern std::string g_trace_dir;

// Rendering Information
struct tile_key_t {
    float depth;
    int idx;
};

#define DEBUG_MODE 0
#define W_START 64
#define W_END 192
#define H_START 192
#define H_END 256

#define INITIAL_PHASE 0
#define REUSE_PHASE 1

extern int g_phase;
extern int g_iter;
extern int g_curr_cam;
extern int g_prev_cam;

extern std::vector<std::vector<tile_key_t>> g_gaussian_per_tile;
extern std::vector<std::vector<tile_key_t>> g_reuse_gaussian_per_tile;
extern std::vector<std::vector<tile_key_t>> g_merge_gaussian_per_tile;

extern std::vector<std::vector<int>> g_duplicated_gaussian;

extern float *g_raw_img;
extern float *g_raw_T;
} // namespace poc

#endif
