#include "common_phase.h"
#include "variable.h"

#include <spdlog/spdlog.h>

/*
 * Assumption of Input:
 *
 * [number of gaussians]
 * [number of tiles]
 * [gaussian_idx] [is_frustum_culled] [num_duplicated_gaussian]
 * [tile idx for duplicated gaussian] ...
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

common_phase_t::common_phase_t() {
    m_ready = false;
    m_state = COMMON_PHASE_STATE_IDLE;
    m_tile_id = 0;
    m_morton_id = 0;
    m_num_global_sorter = to_u64(get_config("OTHER", "GlobalSorter"));
    m_sorter.resize(m_num_global_sorter);
    m_curr_num_gaussian_per_tile.resize(g_trace->trace.num_tile, 0);
}

common_phase_t::~common_phase_t() {}

void common_phase_t::tick_idle() {
    if (m_ready) {
        m_ready = false;
        m_state = COMMON_PHASE_STATE_FRUSTUM_CULL;

        const u64 num_gaussian = g_trace->trace.num_gaussian;
        const u64 cacheline = to_u64(get_config("DRAM", "CacheLine"));

        m_id = g_dram_wrapper->continuous_dram_access(RAW_GAUSSIAN_POSITION_BASE,
                                                      num_gaussian * RAW_POSTION_SIZE,
                                                      false,
                                                      0,
                                                      "Frustum Culling");

        spdlog::info("Preprocessing Phase: Frustum Culling {} Gaussian ({:.1f} MB)",
                     num_gaussian,
                     ((float)num_gaussian) * RAW_POSTION_SIZE / cacheline / MB);
    }
}

void common_phase_t::tick_frustum_cull() {
    if (g_dram_wrapper->is_finished(m_id)) {
        spdlog::info("Common Phase: Frustum Culling Finish");
        g_dram_wrapper->summary();

        m_state = COMMON_PHASE_STATE_PROJECTION;
        const u64 num_gaussian = g_trace->trace.num_gaussian;
        const u64 cacheline = to_u64(get_config("DRAM", "CacheLine"));

        vector<u64> address_list;
        for (int i = 0; i < num_gaussian; i++)
            if (!(g_trace->trace.is_frustum_culled[i]))
                for (int j = 0; j < (RAW_OTHERS_SIZE + cacheline - 1) / cacheline; j++) {
                    u64 address = RAW_GAUSSIAN_OTHERS_BASE;
                    address += i * RAW_OTHERS_SIZE;
                    address = align_address(address, cacheline);
                    address += j * cacheline;
                    address_list.push_back(address);
                }
        m_id = g_dram_wrapper->discrete_dram_access(address_list,
                                                    false,
                                                    0,
                                                    "Projection (Load)");

        spdlog::info("Preprocessing Phase: Projection (Load) {} Request ({:.1f} MB)",
                     address_list.size(),
                     ((float)address_list.size()) * cacheline / MB);

        // m_id = g_dram_wrapper->continuous_dram_access(RAW_GAUSSIAN_OTHERS_BASE,
        //                                               num_gaussian * RAW_OTHERS_SIZE,
        //                                               false,
        //                                               0,
        //                                               "Projection (Load)");

        // spdlog::info("Preprocessing Phase: Projection (Load) {} Gaussian ({:.1f} MB)",
        //              num_gaussian,
        //              ((float)num_gaussian) * RAW_OTHERS_SIZE / MB);
    }
}

void common_phase_t::tick_projection() {
    if (g_dram_wrapper->is_finished(m_id)) {
        spdlog::info("Common Phase: Projection Finish");
        g_dram_wrapper->summary();

        m_state = COMMON_PHASE_STATE_STORE;
        const u64 num_gaussian = g_trace->trace.num_gaussian;
        const u64 cacheline = to_u64(get_config("DRAM", "CacheLine"));

        vector<u64> address_list;
        for (int i = 0; i < num_gaussian; i++)
            if (!(g_trace->trace.is_frustum_culled[i])) {
                u64 address = CURR_PROJECTION_BASE;
                address += i * PROJECTION_ENTRY_SIZE;
                address = align_address(address, to_u64(get_config("DRAM", "CacheLine")));
                address_list.push_back(address);
            }
        m_id = g_dram_wrapper->discrete_dram_access(address_list,
                                                    true,
                                                    0,
                                                    "Projection (Store)");

        spdlog::info("Preprocessing Phase: Projection (Store) {} Request ({:.1f} MB)",
                     address_list.size(),
                     ((float)address_list.size()) * cacheline / MB);

        // m_id = g_dram_wrapper->continuous_dram_access(CURR_PROJECTION_BASE,
        //                                               num_gaussian * PROJECTION_ENTRY_SIZE,
        //                                               false,
        //                                               0,
        //                                               "Projection (Load)");

        // spdlog::info("Preprocessing Phase: Projection (Store) {} Gaussian ({:.1f} MB)",
        //              num_gaussian,
        //              ((float)num_gaussian) * PROJECTION_ENTRY_SIZE / MB);
    }
}

void common_phase_t::tick_store() {
    if (g_dram_wrapper->is_finished(m_id)) {
        spdlog::info("Common Phase: Store Finish");
        g_dram_wrapper->summary();

        m_state = COMMON_PHASE_STATE_DUPLICATION;
        const u64 num_gaussian = g_trace->trace.num_gaussian;
        const u64 cacheline = to_u64(get_config("DRAM", "CacheLine"));

        vector<u64> address_list;
        for (int i = 0; i < num_gaussian; i++)
            if (!(g_trace->trace.is_frustum_culled[i]))
                for (const auto tile_id : g_trace->trace.duplicated_gaussian_per_gaussian[i]) {
                    u64 address = new_tile_base(tile_id);
                    address = align_address(address, cacheline);
                    address_list.push_back(address);

                    address = new_tile_base(tile_id);
                    address = align_address(address, cacheline);
                    address_list.push_back(address);

                    address = new_tile_base(tile_id) + m_curr_num_gaussian_per_tile[tile_id] * NEW_ENTRY_SIZE;
                    address = align_address(address, cacheline);
                    address_list.push_back(address);

                    m_curr_num_gaussian_per_tile[tile_id]++;
                }

        m_id = g_dram_wrapper->discrete_dram_access(address_list,
                                                    true,
                                                    0,
                                                    "Duplication");

        spdlog::info("Preprocessing Phase: Duplication {} Gaussian ({:.1f} MB)",
                     address_list.size(),
                     ((float)address_list.size()) * to_u64(get_config("DRAM", "CacheLine")) / MB);
    }
}

void common_phase_t::tick_duplication() {
    if (g_dram_wrapper->is_finished(m_id)) {
        spdlog::info("Common Phase: Duplication Finish");
        g_dram_wrapper->summary();

        m_state = COMMON_PHASE_STATE_SORT;
        m_tile_id = 0;
        const u64 num_tile = g_trace->trace.num_tile;
        for (u64 i = 0; i < m_num_global_sorter && m_tile_id < num_tile; i++) {
            if (m_sorter[i].is_finished()) {
                m_sorter[i].ready(parse_tile_id(m_morton_id));
                m_tile_id++;
            }
        }
    }
}

void common_phase_t::tick_sort() {
    const u64 num_tile = g_trace->trace.num_tile;
    bool all_done = m_tile_id >= num_tile;

    for (u64 i = 0; i < m_num_global_sorter && m_tile_id < num_tile; i++)
        if (m_sorter[i].is_finished()) {
            m_sorter[i].ready(parse_tile_id(m_morton_id));
            m_tile_id++;
        }

    for (u64 i = 0; i < m_num_global_sorter; i++)
        if (!m_sorter[i].is_finished())
            all_done = false;

    if (all_done) {
        spdlog::info("Common Phase: Sort Finish");
        spdlog::info("Common Phase Finish");
        g_dram_wrapper->summary();

        m_state = COMMON_PHASE_STATE_IDLE;
    }
}

void common_phase_t::tick() {
    for (u64 i = 0; i < m_num_global_sorter; i++)
        m_sorter[i].tick();

    switch (m_state) {
    case COMMON_PHASE_STATE_IDLE:
        tick_idle();
        break;
    case COMMON_PHASE_STATE_FRUSTUM_CULL:
        tick_frustum_cull();
        break;
    case COMMON_PHASE_STATE_PROJECTION:
        tick_projection();
        break;
    case COMMON_PHASE_STATE_STORE:
        tick_store();
        break;
    case COMMON_PHASE_STATE_DUPLICATION:
        tick_duplication();
        break;
    case COMMON_PHASE_STATE_SORT:
        tick_sort();
        break;
    }
}

void common_phase_t::ready() {
    m_ready = true;
}

bool common_phase_t::is_finished() {
    if (m_ready)
        return false;

    if (m_state != COMMON_PHASE_STATE_IDLE)
        return false;

    return true;
}

} // namespace garnet
