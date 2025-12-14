#include "simulator.h"
#include "variable.h"

#include <iostream>

#include <argparse/argparse.hpp>
#include <spdlog/spdlog.h>

int main(int argc, char *argv[]) {
    argparse::ArgumentParser program("garnet", "1.0");
    program.add_argument("-f", "--config_file")
        .metavar("path-to-configuration-file")
        .help("Path to a YAML configuration file.")
        .required();

    try {
        program.parse_args(argc, argv);
    } catch (const std::runtime_error &err) {
        spdlog::error(err.what());
        std::cerr << program;
    std:
        exit(1);
    }

    const std::string config_file = *program.present("-f");
    garnet::initialize_simulator(config_file);

    const auto start_time = std::chrono::high_resolution_clock::now();

    garnet::g_simulator->ready();
    while (!(garnet::g_simulator->is_finished()))
        garnet::g_simulator->elapsed_unit_time();

    garnet::finalize_simulator();

    const auto end_time = std::chrono::high_resolution_clock::now();
    const std::chrono::duration<double> elapsed_time = end_time - start_time;
    spdlog::info("Elapsed Time : {:.2f} sec", elapsed_time.count());

    return 0;
}
