#ifndef UTILS_H
#define UTILS_H

#include <cuda.h>
#include <cuda_runtime.h>

namespace poc {

bool obb_test(const float2 p,
              const int tx, const int ty,
              const float2 eigen_vec1, const float2 eigen_vec2,
              const float eigen_val1, const float eigen_val2,
              const float tile_size);

}

#endif
