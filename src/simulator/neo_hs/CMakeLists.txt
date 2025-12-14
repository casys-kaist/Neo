cmake_minimum_required(VERSION 3.14)

project(
  Neo_HS
  VERSION 1.0
  LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

include(FetchContent)
FetchContent_Declare(
  ramulator
  GIT_REPOSITORY https://github.com/Milchstra3e/ramulator.git
  GIT_TAG e7c8d27a47d540c08d67f05cc22ddf8f1dc20beb
  SOURCE_DIR ${CMAKE_SOURCE_DIR}/third_party/ramulator
)
FetchContent_MakeAvailable(ramulator)

FetchContent_Declare(
  argparse
  GIT_REPOSITORY https://github.com/p-ranav/argparse.git
  GIT_TAG 84c02050ea8bd1bf99de0a4943db40235e9fd5e7
  SOURCE_DIR ${CMAKE_SOURCE_DIR}/third_party/argparse
)
FetchContent_MakeAvailable(argparse)

FetchContent_Declare(
  spdlog
  GIT_REPOSITORY https://github.com/gabime/spdlog.git
  GIT_TAG 63f0875000bf90867aa7c76a831bd834cb7d4b5e
  SOURCE_DIR ${CMAKE_SOURCE_DIR}/third_party/spdlog
)
FetchContent_MakeAvailable(spdlog)

FetchContent_Declare(
  yaml-cpp
  GIT_REPOSITORY https://github.com/jbeder/yaml-cpp.git
  GIT_TAG 3d2888cc8a45da2f420454ad728cdfad01a3d54f
  SOURCE_DIR ${CMAKE_SOURCE_DIR}/third_party/yaml-cpp
)
FetchContent_MakeAvailable(yaml-cpp)

file(GLOB SOURCES ${CMAKE_SOURCE_DIR}/src/*.cc)

add_executable(sim ${SOURCES})
add_dependencies(sim ramulator)
target_link_libraries(sim PRIVATE
  ramulator
  argparse
  spdlog
  yaml-cpp
)