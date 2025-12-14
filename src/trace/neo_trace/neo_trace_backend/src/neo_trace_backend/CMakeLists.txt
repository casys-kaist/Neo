cmake_minimum_required(VERSION 3.20)

project(neo_trace_backend LANGUAGES CUDA CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CUDA_STANDARD 17)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")

add_library(CudaRasterizer
	cuda_rasterizer/forward.h
	cuda_rasterizer/forward.cu
	cuda_rasterizer/preprocess.h
	cuda_rasterizer/preprocess.cu
	cuda_rasterizer/rasterize.h
	cuda_rasterizer/rasterize.cu
	cuda_rasterizer/sort.h
	cuda_rasterizer/sort.cu
	cuda_rasterizer/utils.h
	cuda_rasterizer/utils.cu
	cuda_rasterizer/variable.h
	cuda_rasterizer/variable.cu
	cuda_rasterizer/auxiliary.h
)

set_target_properties(CudaRasterizer PROPERTIES CUDA_ARCHITECTURES "70;75;86")

target_include_directories(CudaRasterizer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/cuda_rasterizer)
target_include_directories(CudaRasterizer PRIVATE third_party/glm ${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES})
