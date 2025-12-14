#include "variable.h"

#include <iostream>

namespace poc {
// Basic Information
int g_W, g_H;
int g_tile_size;
int g_min_tile_size;
int g_chunk_size;

// Camera Information
cam_t g_cam[2];

// 3D Gaussian Information
float *g_gaussian_mean3D;
float *g_gaussian_opacity;
float *g_gaussian_scale;
float *g_gaussian_rotation;
float *g_gaussian_SH;

// 2D Gaussian Information (GPU)
float *g_gaussian_mean2D[2];
float *g_gaussian_conic_opacity[2];
float *g_gaussian_rgb[2];
int *g_gaussian_radii[2];
float *g_gaussian_depth[2];
float *g_gaussian_eigen_vector[2][2];
float *g_gaussian_eigen_value[2][2];
int *g_gaussian_is_frustum_culled[2];

// 2D Gaussian Information (CPU)
int g_P, g_D, g_M;

float *g_gaussian_mean2D_cpu[2];
float *g_gaussian_conic_opacity_cpu[2];
float *g_gaussian_rgb_cpu[2];
int *g_gaussian_radii_cpu[2];
float *g_gaussian_depth_cpu[2];
float *g_gaussian_eigen_vector_cpu[2][2];
float *g_gaussian_eigen_value_cpu[2][2];
int *g_gaussian_is_frustum_culled_cpu[2];

// Trace Information
bool g_trace = false;
std::string g_trace_dir;

int g_phase = INITIAL_PHASE;
int g_iter = 0;
int g_curr_cam = 0;
int g_prev_cam = 1;

// Rendering Information
std::vector<std::vector<tile_key_t>> g_gaussian_per_tile;
std::vector<std::vector<tile_key_t>> g_reuse_gaussian_per_tile;
std::vector<std::vector<tile_key_t>> g_merge_gaussian_per_tile;

std::vector<std::vector<int>> g_duplicated_gaussian;

float *g_raw_img = NULL;
float *g_raw_T = NULL;
} // namespace poc
