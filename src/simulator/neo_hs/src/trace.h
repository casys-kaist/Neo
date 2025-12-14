#ifndef TRACE_H
#define TRACE_H

#include "utils.h"

#include <iostream>
#include <vector>

namespace garnet {

struct duplicated_gaussian_information_t {
    u64 idx;
    std::vector<bool> subtile;
};

struct trace_t {
    u64 width;
    u64 height;
    u64 tile_size;
    u64 sub_tile_size;
    u64 chunk_size;
    u64 num_gaussian;
    u64 num_tile;
    u64 num_total_duplicated_gaussian;

    std::vector<bool> is_frustum_culled;
    std::vector<std::vector<u64>> duplicated_gaussian_per_gaussian;

    std::vector<u64> num_new_gaussian_per_tile;
    std::vector<u64> num_reuse_gaussian_per_tile;
    std::vector<std::vector<duplicated_gaussian_information_t>> duplicated_gaussian_per_tile;
};

class trace_wrapper_t {
  public:
    trace_wrapper_t(std::string trace_dir);
    ~trace_wrapper_t();

    trace_t trace;
};

} // namespace garnet

#endif
