#include "variable.h"

#include <map>
#include <spdlog/spdlog.h>

namespace garnet {

YAML::Node g_config;
core_t *g_core;
dram_wrapper_t *g_dram_wrapper;
simulator_t *g_simulator;
trace_wrapper_t *g_trace;
vector<bool> g_common_finish;
vector<bool> g_reuse_finish;
queue<int> g_render_queue;

std::string get_config(const std::string key1) {
    return g_config[key1].as<std::string>();
}

std::string get_config(const std::string key1, const std::string key2) {
    return g_config[key1][key2].as<std::string>();
}

std::string get_config(const std::string key1, const std::string key2, const std::string key3) {
    return g_config[key1][key2][key3].as<std::string>();
}

void initialize_simulator(const std::string config_file) {
    spdlog::info("Initialize Configuration: {}", config_file);
    g_config = YAML::LoadFile(config_file);

    spdlog::info("Initialize Trace: {}", get_config("OTHER", "Trace"));
    g_trace = new trace_wrapper_t(get_config("OTHER", "Trace"));

    spdlog::info("Initialize Simulator");
    g_simulator = new simulator_t();

    spdlog::info("Initialize Core");
    g_core = new core_t();

    spdlog::info("Initialize DRAM: {}", get_config("DRAM", "Config"));
    g_dram_wrapper = new dram_wrapper_t();

    g_common_finish.assign(g_trace->trace.num_tile, false);
    g_reuse_finish.assign(g_trace->trace.num_tile, false);
}

void finalize_simulator() {
    delete g_dram_wrapper;
    delete g_core;
    delete g_simulator;
}

} // namespace garnet
