#include "reuse_phase.h"
#include "variable.h"

#include <spdlog/spdlog.h>

/*
 * Assumption of Input:
 *
 * [number of tiles]
 * [tile idx] [tile size]
 *
 */

namespace garnet {

static u64 decodeCoordinate(u64 mortonCode, u64 shift) {
    u64 coordinate = 0;
    for (u64 i = 0; i < 32; ++i) { // Up to 32 bits
        coordinate |= ((mortonCode >> (2 * i + shift)) & 1) << i;
    }
    return coordinate;
}

static u64 parse_tile_id(u64 &m_morton_id) {
    const u64 tile_size = g_trace->trace.tile_size;
    const u64 width = g_trace->trace.width;
    const u64 height = g_trace->trace.height;
    const u64 tile_width = (width + tile_size - 1) / tile_size;
    const u64 tile_height = (height + tile_size - 1) / tile_size;

    u64 x, y;

    while (1) {
        x = decodeCoordinate(m_morton_id, 0);
        y = decodeCoordinate(m_morton_id, 1);
        m_morton_id++;

        if (x < tile_width && y < tile_height)
            break;
    }

    return y * tile_width + x;
}

reuse_phase_t::reuse_phase_t() {
    m_ready = false;
    m_state = REUSE_PHASE_STATE_IDLE;
    m_tile_id = 0;
    m_morton_id = 0;
    m_num_adaptive_sorter = to_u64(get_config("OTHER", "AdaptiveSorter"));
    m_sorter.resize(m_num_adaptive_sorter);
}

reuse_phase_t::~reuse_phase_t() {}

void reuse_phase_t::tick_idle() {
    if (m_ready) {
        m_ready = false;
        m_tile_id = 0;
        m_state = REUSE_PHASE_STATE_RUN;

        const u64 num_tile = g_trace->trace.num_tile;

        for (u64 i = 0; i < m_num_adaptive_sorter && m_tile_id < num_tile; i++)
            if (m_sorter[i].can_ready()) {
                m_sorter[i].ready(parse_tile_id(m_morton_id));
                m_tile_id++;
            }
    }
}

void reuse_phase_t::tick_run() {
    const u64 num_tile = g_trace->trace.num_tile;
    bool all_done = m_tile_id >= num_tile;

    for (u64 i = 0; i < m_num_adaptive_sorter && m_tile_id < num_tile; i++)
        if (m_sorter[i].can_ready()) {
            m_sorter[i].ready(parse_tile_id(m_morton_id));
            m_tile_id++;
        }

    for (u64 i = 0; i < m_num_adaptive_sorter; i++)
        if (!m_sorter[i].is_finished())
            all_done = false;

    if (all_done) {
        spdlog::info("Reuse Phase Finish");
        g_dram_wrapper->summary();
        m_state = REUSE_PHASE_STATE_IDLE;
    }
}

void reuse_phase_t::tick() {
    for (u64 i = 0; i < m_num_adaptive_sorter; i++)
        m_sorter[i].tick();

    switch (m_state) {
    case REUSE_PHASE_STATE_IDLE:
        tick_idle();
        break;
    case REUSE_PHASE_STATE_RUN:
        tick_run();
        break;
    default:
        break;
    }
}

void reuse_phase_t::ready() {
    m_ready = true;
}

bool reuse_phase_t::is_finished() {
    if (m_ready)
        return false;

    if (m_state == REUSE_PHASE_STATE_RUN)
        return false;

    return true;
}

} // namespace garnet
