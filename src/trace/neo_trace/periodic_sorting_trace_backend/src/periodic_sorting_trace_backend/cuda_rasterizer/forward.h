#ifndef FORWARD_H
#define FORWARD_H

#include <cuda.h>
#include <cuda_runtime.h>
#include <torch/extension.h>

namespace poc {

void set_config(const int W, const int H,
                const int tile_size,
                const int min_tile_size,
                const int chunk_size);

void set_cam(const float tan_fovx, const float tan_fovy,
             const torch::Tensor &view_matrix,
             const torch::Tensor &proj_matrix,
             const torch::Tensor &cam_pos);

void set_gaussian(const torch::Tensor &gaussian_mean3D,
                  const torch::Tensor &gaussian_opacity,
                  const torch::Tensor &gaussian_scale,
                  const torch::Tensor &gaussian_rotation,
                  const torch::Tensor &gaussian_SH,
                  const int degree_of_SH);

void set_trace(bool trace, const std::string trace_dir);

void set_phase(int phase);

void render();

torch::Tensor get_img();

} // namespace poc

#endif
