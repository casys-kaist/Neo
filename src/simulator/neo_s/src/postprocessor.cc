#include "postprocessor.h"
#include "variable.h"

#include <spdlog/spdlog.h>

namespace garnet {

postprocessor_t::postprocessor_t() {
    m_state = POSTPROCESSOR_STATE_IDLE;
    m_ready = false;
    m_read_id = 0;
    m_write_id = 0;
}

postprocessor_t::~postprocessor_t() {}

void postprocessor_t::tick_idle() {
    if (m_ready) {
        m_ready = false;
        m_state = POSTPROCESSOR_STATE_RUN;

        vector<u64> read_address_list;
        vector<u64> write_address_list;
        for (int i = 0; i < g_trace->trace.num_tile; i++) {
            int size = g_trace->trace.duplicated_gaussian_per_tile[i].size();

            for (int idx = 0; idx < size; idx++) {
                const auto &info = g_trace->trace.duplicated_gaussian_per_tile[i][idx];
                u64 read_address = CURR_PROJECTION_BASE + info.idx * PROJECTION_ENTRY_SIZE;
                read_address = align_address(read_address, to_u64(get_config("DRAM", "CacheLine")));
                read_address_list.push_back(read_address);
            }

            for (int idx = 0; idx < size; idx += (64 / REUSE_ENTRY_SIZE)) {
                u64 write_address = reuse_tile_base(i) + idx * REUSE_ENTRY_SIZE;
                write_address = align_address(write_address, to_u64(get_config("DRAM", "CacheLine")));
                write_address_list.push_back(write_address);
            }
        }

        m_read_id = g_dram_wrapper->discrete_dram_access(read_address_list, false, 0, "Read Update");
        m_write_id = g_dram_wrapper->discrete_dram_access(write_address_list, true, 0, "Write Update");
    }
}

void postprocessor_t::tick_run() {
    if (g_dram_wrapper->is_finished(m_read_id) && g_dram_wrapper->is_finished(m_write_id)) {
        spdlog::info("Postprocessing Phase Finish");
        g_dram_wrapper->summary();
        m_state = POSTPROCESSOR_STATE_IDLE;
    }
}

void postprocessor_t::tick() {
    switch (m_state) {
    case POSTPROCESSOR_STATE_IDLE:
        tick_idle();
        break;
    case POSTPROCESSOR_STATE_RUN:
        tick_run();
        break;
    }
}

void postprocessor_t::ready() {
    m_ready = true;
}

bool postprocessor_t::is_finished() {
    if (m_ready)
        return false;

    if (m_state != POSTPROCESSOR_STATE_IDLE)
        return false;

    return true;
}

} // namespace garnet
