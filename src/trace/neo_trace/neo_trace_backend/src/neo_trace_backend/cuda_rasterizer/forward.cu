#include "forward.h"
#include "preprocess.h"
#include "rasterize.h"
#include "sort.h"
#include "utils.h"
#include "variable.h"
#include <fstream>

namespace poc {

static torch::Tensor l_view_matrix[2];
static torch::Tensor l_proj_matrix[2];
static torch::Tensor l_cam_pos[2];

static torch::Tensor l_gaussian_mean3D;
static torch::Tensor l_gaussian_opacity;
static torch::Tensor l_gaussian_scale;
static torch::Tensor l_gaussian_rotation;
static torch::Tensor l_gaussian_SH;

static torch::Tensor l_gaussian_mean2D[2];
static torch::Tensor l_gaussian_conic_opacity[2];
static torch::Tensor l_gaussian_rgb[2];
static torch::Tensor l_gaussian_radii[2];
static torch::Tensor l_gaussian_depth[2];
static torch::Tensor l_gaussian_eigen_vector[2][2];
static torch::Tensor l_gaussian_eigen_value[2][2];
static torch::Tensor l_gaussian_is_frustum_culled[2];

static torch::Tensor l_gaussian_mean2D_cpu[2];
static torch::Tensor l_gaussian_conic_opacity_cpu[2];
static torch::Tensor l_gaussian_rgb_cpu[2];
static torch::Tensor l_gaussian_radii_cpu[2];
static torch::Tensor l_gaussian_depth_cpu[2];
static torch::Tensor l_gaussian_eigen_vector_cpu[2][2];
static torch::Tensor l_gaussian_eigen_value_cpu[2][2];
static torch::Tensor l_gaussian_is_frustum_culled_cpu[2];

static torch::Tensor img;

void set_config(const int W, const int H,
                const int tile_size,
                const int min_tile_size,
                const int chunk_size) {
    g_W = W;
    g_H = H;
    g_tile_size = tile_size;
    g_min_tile_size = min_tile_size;
    g_chunk_size = chunk_size;
}

void set_cam(const float tan_fovx, const float tan_fovy,
             const torch::Tensor &view_matrix,
             const torch::Tensor &proj_matrix,
             const torch::Tensor &cam_pos) {
    g_cam[g_curr_cam].tan_fovx = tan_fovx;
    g_cam[g_curr_cam].tan_fovy = tan_fovy;

    l_view_matrix[g_curr_cam] = view_matrix.contiguous();
    l_proj_matrix[g_curr_cam] = proj_matrix.contiguous();
    l_cam_pos[g_curr_cam] = cam_pos.contiguous();

    g_cam[g_curr_cam].view_matrix = l_view_matrix[g_curr_cam].data_ptr<float>();
    g_cam[g_curr_cam].proj_matrix = l_proj_matrix[g_curr_cam].data_ptr<float>();
    g_cam[g_curr_cam].cam_pos = l_cam_pos[g_curr_cam].data_ptr<float>();
}

void set_gaussian(const torch::Tensor &gaussian_mean3D,
                  const torch::Tensor &gaussian_opacity,
                  const torch::Tensor &gaussian_scale,
                  const torch::Tensor &gaussian_rotation,
                  const torch::Tensor &gaussian_SH,
                  const int degree_of_SH) {
    auto int_opts = gaussian_mean3D.options().dtype(torch::kInt32);
    auto float_opts = gaussian_mean3D.options().dtype(torch::kFloat32);

    g_P = gaussian_mean3D.size(0);
    g_D = degree_of_SH;
    g_M = gaussian_SH.size(1);

    l_gaussian_mean3D = gaussian_mean3D;
    l_gaussian_opacity = gaussian_opacity;
    l_gaussian_scale = gaussian_scale;
    l_gaussian_rotation = gaussian_rotation;
    l_gaussian_SH = gaussian_SH;

    g_gaussian_mean3D = l_gaussian_mean3D.data_ptr<float>();
    g_gaussian_opacity = l_gaussian_opacity.data_ptr<float>();
    g_gaussian_scale = l_gaussian_scale.data_ptr<float>();
    g_gaussian_rotation = l_gaussian_rotation.data_ptr<float>();
    g_gaussian_SH = l_gaussian_SH.data_ptr<float>();

    for (int cam = 0; cam < 2; cam++) {
        l_gaussian_mean2D[cam] = torch::zeros({g_P, 2}, float_opts);
        l_gaussian_conic_opacity[cam] = torch::zeros({g_P, 4}, float_opts);
        l_gaussian_rgb[cam] = torch::zeros({g_P, 3}, float_opts);
        l_gaussian_radii[cam] = torch::zeros({g_P}, int_opts);
        l_gaussian_depth[cam] = torch::zeros({g_P}, float_opts);
        l_gaussian_is_frustum_culled[cam] = torch::zeros({g_P}, int_opts);

        g_gaussian_mean2D[cam] = l_gaussian_mean2D[cam].data_ptr<float>();
        g_gaussian_conic_opacity[cam] = l_gaussian_conic_opacity[cam].data_ptr<float>();
        g_gaussian_rgb[cam] = l_gaussian_rgb[cam].data_ptr<float>();
        g_gaussian_radii[cam] = l_gaussian_radii[cam].data_ptr<int>();
        g_gaussian_depth[cam] = l_gaussian_depth[cam].data_ptr<float>();
        g_gaussian_is_frustum_culled[cam] = l_gaussian_is_frustum_culled[cam].data_ptr<int>();

        for (int i = 0; i < 2; i++) {
            l_gaussian_eigen_vector[cam][i] = torch::zeros({g_P, 3}, float_opts);
            l_gaussian_eigen_value[cam][i] = torch::zeros({g_P}, float_opts);
            g_gaussian_eigen_vector[cam][i] = l_gaussian_eigen_vector[cam][i].data_ptr<float>();
            g_gaussian_eigen_value[cam][i] = l_gaussian_eigen_value[cam][i].data_ptr<float>();
        }
    }
}

void set_trace(bool trace, const std::string trace_dir) {
    g_trace = trace;
    g_trace_dir = trace_dir;
}

void set_phase(int phase) {
    g_phase = phase;
}

static torch::Tensor wrap_pointer_to_tensor(float *array, int size) {
    auto options = torch::TensorOptions().dtype(torch::kFloat32).requires_grad(false);
    torch::Tensor tensor = torch::from_blob(array, {size}, options);

    return tensor;
}

void render() {
    preprocess();

    l_gaussian_mean2D_cpu[g_curr_cam] = l_gaussian_mean2D[g_curr_cam].cpu().contiguous();
    l_gaussian_conic_opacity_cpu[g_curr_cam] = l_gaussian_conic_opacity[g_curr_cam].cpu().contiguous();
    l_gaussian_rgb_cpu[g_curr_cam] = l_gaussian_rgb[g_curr_cam].cpu().contiguous();
    l_gaussian_radii_cpu[g_curr_cam] = l_gaussian_radii[g_curr_cam].cpu().contiguous();
    l_gaussian_depth_cpu[g_curr_cam] = l_gaussian_depth[g_curr_cam].cpu().contiguous();
    l_gaussian_is_frustum_culled_cpu[g_curr_cam] = l_gaussian_is_frustum_culled[g_curr_cam].cpu().contiguous();

    g_gaussian_mean2D_cpu[g_curr_cam] = l_gaussian_mean2D_cpu[g_curr_cam].data_ptr<float>();
    g_gaussian_conic_opacity_cpu[g_curr_cam] = l_gaussian_conic_opacity_cpu[g_curr_cam].data_ptr<float>();
    g_gaussian_rgb_cpu[g_curr_cam] = l_gaussian_rgb_cpu[g_curr_cam].data_ptr<float>();
    g_gaussian_radii_cpu[g_curr_cam] = l_gaussian_radii_cpu[g_curr_cam].data_ptr<int>();
    g_gaussian_depth_cpu[g_curr_cam] = l_gaussian_depth_cpu[g_curr_cam].data_ptr<float>();
    g_gaussian_is_frustum_culled_cpu[g_curr_cam] = l_gaussian_is_frustum_culled_cpu[g_curr_cam].data_ptr<int>();

    for (int i = 0; i < 2; i++) {
        l_gaussian_eigen_vector_cpu[g_curr_cam][i] = l_gaussian_eigen_vector[g_curr_cam][i].cpu().contiguous();
        l_gaussian_eigen_value_cpu[g_curr_cam][i] = l_gaussian_eigen_value[g_curr_cam][i].cpu().contiguous();

        g_gaussian_eigen_vector_cpu[g_curr_cam][i] = l_gaussian_eigen_vector_cpu[g_curr_cam][i].data_ptr<float>();
        g_gaussian_eigen_value_cpu[g_curr_cam][i] = l_gaussian_eigen_value_cpu[g_curr_cam][i].data_ptr<float>();
    }

    sort();

    std::vector<int> num_new_duplicated_gaussian_per_tile;
    std::vector<int> num_reuse_duplicated_gaussian_per_tile;

    if (g_trace) {
        if (g_phase == REUSE_PHASE) {
            num_new_duplicated_gaussian_per_tile.resize(NUM_TILE);
            num_reuse_duplicated_gaussian_per_tile.resize(NUM_TILE);

            for (int i = 0; i < NUM_TILE; i++) {
                num_new_duplicated_gaussian_per_tile[i] = g_gaussian_per_tile[i].size();
                num_reuse_duplicated_gaussian_per_tile[i] = g_reuse_gaussian_per_tile[i].size();
            }
        } else {
            num_new_duplicated_gaussian_per_tile.resize(NUM_TILE);

            for (int i = 0; i < NUM_TILE; i++)
                num_new_duplicated_gaussian_per_tile[i] = g_gaussian_per_tile[i].size();
        }
    }

    rasterize();

    img = wrap_pointer_to_tensor(g_raw_img, g_W * g_H * NUM_CHANNELS);

    if (g_trace) {
        if (g_phase == REUSE_PHASE) {
            std::ofstream trace_file(g_trace_dir + "/poc.trace");
            if (trace_file.is_open()) {
                trace_file << g_W << "\n";
                trace_file << g_H << "\n";
                trace_file << g_tile_size << "\n";
                trace_file << g_min_tile_size << "\n";
                trace_file << g_chunk_size << "\n";
                trace_file << g_P << "\n";
                trace_file << NUM_TILE << "\n";

                for (int i = 0; i < g_P; i++) {
                    trace_file << g_gaussian_is_frustum_culled_cpu[g_curr_cam][i] << "\n";
                    trace_file << g_duplicated_gaussian[i].size() << "\n";

                    for (auto e : g_duplicated_gaussian[i])
                        trace_file << e << " ";

                    if (g_duplicated_gaussian[i].size() > 0)
                        trace_file << "\n";
                }

                for (int i = 0; i < NUM_TILE; i++) {
                    trace_file << num_new_duplicated_gaussian_per_tile[i] << "\n";
                    trace_file << num_reuse_duplicated_gaussian_per_tile[i] << "\n";
                    trace_file << g_reuse_gaussian_per_tile[i].size() << "\n";

                    for (auto e : g_reuse_gaussian_per_tile[i]) {
                        trace_file << e.idx << " ";

                        const float2 p = {g_gaussian_mean2D_cpu[g_curr_cam][e.idx * 2],
                                          g_gaussian_mean2D_cpu[g_curr_cam][e.idx * 2 + 1]};

                        float gaussian_e_val[2];
                        float2 gaussian_e_vec[2];

                        for (int j = 0; j < 2; j++) {
                            gaussian_e_val[j] = g_gaussian_eigen_value_cpu[g_curr_cam][j][e.idx];
                            gaussian_e_vec[j] = {g_gaussian_eigen_vector_cpu[g_curr_cam][j][e.idx * 2],
                                                 g_gaussian_eigen_vector_cpu[g_curr_cam][j][e.idx * 2 + 1]};
                        }

                        std::vector<bool> subtiles;

                        int factor = g_tile_size / g_min_tile_size;

                        subtiles.clear();
                        subtiles.resize(factor * factor);

                        int tx = i % TILE_WIDTH;
                        int ty = i / TILE_WIDTH;

                        for (int dx = 0; dx < factor; dx++)
                            for (int dy = 0; dy < factor; dy++) {
                                if (obb_test(p,
                                             factor * tx + dx, factor * ty + dy,
                                             gaussian_e_vec[0], gaussian_e_vec[1],
                                             gaussian_e_val[0], gaussian_e_val[1],
                                             g_tile_size / factor))
                                    subtiles[factor * dy + dx] = true;
                            }

                        for (auto subtile : subtiles)
                            trace_file << subtile << " ";

                        trace_file << "\n";
                    }

                    if (g_reuse_gaussian_per_tile[i].size() > 0)
                        trace_file << "\n";
                }

                trace_file.close();
            } else {
                std::cerr << "Unable to open trace file\n";
            }
        } else {
            std::ofstream trace_file(g_trace_dir + "/poc.trace");
            if (trace_file.is_open()) {
                trace_file << g_W << "\n";
                trace_file << g_H << "\n";
                trace_file << g_tile_size << "\n";
                trace_file << g_min_tile_size << "\n";
                trace_file << g_chunk_size << "\n";
                trace_file << g_P << "\n";
                trace_file << NUM_TILE << "\n";

                for (int i = 0; i < g_P; i++) {
                    trace_file << g_gaussian_is_frustum_culled_cpu[g_curr_cam][i] << "\n";
                    trace_file << g_duplicated_gaussian[i].size() << "\n";

                    for (auto e : g_duplicated_gaussian[i])
                        trace_file << e << " ";

                    if (g_duplicated_gaussian[i].size() > 0)
                        trace_file << "\n";
                }

                for (int i = 0; i < NUM_TILE; i++) {
                    trace_file << num_new_duplicated_gaussian_per_tile[i] << "\n";
                    trace_file << 0 << "\n";
                    trace_file << g_reuse_gaussian_per_tile[i].size() << "\n";

                    for (auto e : g_reuse_gaussian_per_tile[i]) {
                        trace_file << e.idx << " ";

                        const float2 p = {g_gaussian_mean2D_cpu[g_curr_cam][e.idx * 2],
                                          g_gaussian_mean2D_cpu[g_curr_cam][e.idx * 2 + 1]};

                        float gaussian_e_val[2];
                        float2 gaussian_e_vec[2];

                        for (int j = 0; j < 2; j++) {
                            gaussian_e_val[j] = g_gaussian_eigen_value_cpu[g_curr_cam][j][e.idx];
                            gaussian_e_vec[j] = {g_gaussian_eigen_vector_cpu[g_curr_cam][j][e.idx * 2],
                                                 g_gaussian_eigen_vector_cpu[g_curr_cam][j][e.idx * 2 + 1]};
                        }

                        std::vector<bool> subtiles;

                        int factor = g_tile_size / g_min_tile_size;

                        subtiles.clear();
                        subtiles.resize(factor * factor);

                        int tx = i % TILE_WIDTH;
                        int ty = i / TILE_WIDTH;

                        for (int dx = 0; dx < factor; dx++)
                            for (int dy = 0; dy < factor; dy++) {
                                if (obb_test(p,
                                             factor * tx + dx, factor * ty + dy,
                                             gaussian_e_vec[0], gaussian_e_vec[1],
                                             gaussian_e_val[0], gaussian_e_val[1],
                                             g_tile_size / factor))
                                    subtiles[factor * dy + dx] = true;
                            }

                        for (auto subtile : subtiles)
                            trace_file << subtile << " ";

                        trace_file << "\n";
                    }

                    if (g_reuse_gaussian_per_tile[i].size() > 0)
                        trace_file << "\n";
                }

                trace_file.close();
            } else {
                std::cerr << "Unable to open trace file\n";
            }
        }
    }

    g_iter++;
    g_prev_cam = (g_prev_cam ? 0 : 1);
    g_curr_cam = (g_curr_cam ? 0 : 1);
}

torch::Tensor get_img() {
    return img;
}

} // namespace poc
