#ifndef VARIABLE_H
#define VARIABLE_H

#include "core.h"
#include "dram.h"
#include "simulator.h"
#include "trace.h"

#include <iostream>
#include <queue>
#include <vector>
#include <yaml-cpp/yaml.h>

namespace garnet {

extern YAML::Node g_config;
extern core_t *g_core;
extern dram_wrapper_t *g_dram_wrapper;
extern simulator_t *g_simulator;
extern trace_wrapper_t *g_trace;
extern vector<bool> g_common_finish;
extern vector<bool> g_reuse_finish;
extern queue<int> g_render_queue;

void initialize_simulator(const std::string config_file);
void finalize_simulator();

std::string get_config(const std::string key1);
std::string get_config(const std::string key1, const std::string key2);
std::string get_config(const std::string key1, const std::string key2, const std::string key3);

} // namespace garnet

#endif
