#include <torch/extension.h>

#include "cuda_rasterizer/forward.h"

PYBIND11_MODULE(TORCH_EXTENSION_NAME, m) {
    m.def("set_config", &poc::set_config);
    m.def("set_cam", &poc::set_cam);
    m.def("set_gaussian", &poc::set_gaussian);
    m.def("set_trace", &poc::set_trace);
    m.def("set_phase", &poc::set_phase);

    m.def("render", &poc::render);

    m.def("get_img", &poc::get_img);
}
