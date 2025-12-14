#include "trace.h"

#include <fstream>
#include <iostream>

namespace garnet {

trace_wrapper_t::trace_wrapper_t(std::string trace_dir) {
    std::string trace_file_path = trace_dir + "/poc.trace";
    std::ifstream trace_file(trace_file_path);
    if (!trace_file.is_open()) {
        throw std::runtime_error("Failed to open preprocessing_phase file");
    }

    trace_file >> trace.width;
    trace_file >> trace.height;
    trace_file >> trace.tile_size;
    trace_file >> trace.sub_tile_size;
    trace_file >> trace.chunk_size;
    trace_file >> trace.num_gaussian;
    trace_file >> trace.num_tile;

    trace.is_frustum_culled.clear();
    trace.is_frustum_culled.resize(trace.num_gaussian);

    trace.duplicated_gaussian_per_gaussian.clear();
    trace.duplicated_gaussian_per_gaussian.resize(trace.num_gaussian);

    trace.num_new_gaussian_per_tile.clear();
    trace.num_new_gaussian_per_tile.resize(trace.num_tile);

    trace.num_reuse_gaussian_per_tile.clear();
    trace.num_reuse_gaussian_per_tile.resize(trace.num_tile);

    trace.duplicated_gaussian_per_tile.clear();
    trace.duplicated_gaussian_per_tile.resize(trace.num_tile);

    trace.num_total_duplicated_gaussian = 0;

    for (int i = 0; i < trace.num_gaussian; i++) {
        int is_frustum_culled;
        trace_file >> is_frustum_culled;
        trace.is_frustum_culled[i] = (is_frustum_culled ? true : false);

        int num_duplicated_gaussian;
        trace_file >> num_duplicated_gaussian;

        trace.duplicated_gaussian_per_gaussian[i].clear();

        for (int j = 0; j < num_duplicated_gaussian; j++) {
            int idx;
            trace_file >> idx;
            trace.duplicated_gaussian_per_gaussian[i].push_back(idx);
        }
    }

    for (int i = 0; i < trace.num_tile; i++) {
        trace_file >> trace.num_new_gaussian_per_tile[i];
        trace_file >> trace.num_reuse_gaussian_per_tile[i];

        int num_duplicated_gaussian;
        trace_file >> num_duplicated_gaussian;

        trace.duplicated_gaussian_per_tile[i].clear();

        for (int j = 0; j < num_duplicated_gaussian; j++) {
            duplicated_gaussian_information_t info;
            trace_file >> info.idx;

            u64 K = (trace.tile_size * trace.tile_size) / (trace.sub_tile_size * trace.sub_tile_size);
            info.subtile.resize(K);

            for (int k = 0; k < K; k++) {
                int subtile;
                trace_file >> subtile;
                info.subtile[k] = (subtile ? true : false);
            }

            trace.duplicated_gaussian_per_tile[i].push_back(info);
        }
    }

    trace_file.close();
}

trace_wrapper_t::~trace_wrapper_t() {}

} // namespace garnet
