#include "renderer.h"
#include "variable.h"

#include <spdlog/spdlog.h>

namespace garnet {

renderer_t::renderer_t() {
    m_state = RENDERER_STATE_IDLE;
    m_ready = false;
    m_tile_id = 0;

    m_order_load_bit = false;
    m_order_load_id = 0;
    m_order_load_chunk_size = 0;
    m_order_load_base = 0;
    m_order_load_next_base = 0;

    m_feature_load_bit = false;
    m_feature_load_id = 0;
    m_feature_load_chunk_size = 0;
    m_feature_load_base = 0;

    m_render_bit = false;
    m_render_remain_cycle = 0;
    m_render_chunk_size = 0;
    m_render_base = 0;

    m_order_store_bit = false;
    m_order_store_id = 0;
    m_order_store_chunk_size = 0;
    m_order_store_base = 0;
}

renderer_t::~renderer_t() {}

void renderer_t::tick_idle() {
    if (m_ready) {
        m_ready = false;
        m_state = RENDERER_STATE_RUN;

        if (g_trace->trace.duplicated_gaussian_per_tile[m_tile_id].size() == 0) {
            m_state = RENDERER_STATE_IDLE;
            return;
        }

        m_order_load_bit = true;

        const auto total_size = g_trace->trace.duplicated_gaussian_per_tile[m_tile_id].size();
        const auto chunk_size = to_u64(get_config("OTHER", "RenderChunkSize"));

        m_order_load_chunk_size = (total_size > chunk_size) ? chunk_size : total_size;
        m_order_load_base = 0;
        m_order_load_next_base = m_order_load_chunk_size;
        m_order_load_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                 m_order_load_chunk_size * NEW_ENTRY_SIZE,
                                                                 false,
                                                                 0,
                                                                 "New Gaussian Order (Load)");
    }
}

void renderer_t::tick_run() {
    bool all_done = true;

    if (m_order_load_bit && !g_dram_wrapper->is_finished(m_order_load_id))
        all_done = false;

    if (m_feature_load_bit && !g_dram_wrapper->is_finished(m_feature_load_id))
        all_done = false;

    if (m_render_bit && m_render_remain_cycle > 0)
        all_done = false;

    if (m_order_store_bit && !g_dram_wrapper->is_finished(m_order_store_id))
        all_done = false;

    if (all_done) {
        if (!m_order_load_bit &&
            !m_feature_load_bit &&
            !m_render_bit &&
            !m_order_store_bit)
            m_state = RENDERER_STATE_IDLE;
        else {
            if (m_order_store_bit)
                m_order_store_bit = false;

            if (m_render_bit) {
                m_render_bit = false;
                m_order_store_bit = true;
                m_order_store_chunk_size = m_render_chunk_size;
                m_order_store_base = m_render_base;
                m_order_store_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                          m_order_store_chunk_size * NEW_ENTRY_SIZE,
                                                                          true,
                                                                          0,
                                                                          "New Gaussian Order (Store)");
            }

            if (m_feature_load_bit) {
                m_feature_load_bit = false;

                m_render_bit = true;
                m_render_chunk_size = m_feature_load_chunk_size;
                m_render_base = m_feature_load_base;

                u64 render_subtile = 0;

                for (int idx = m_feature_load_base; idx < m_feature_load_base + m_feature_load_chunk_size; idx++) {
                    for (auto subtile : g_trace->trace.duplicated_gaussian_per_tile[m_tile_id][idx].subtile) {
                        if (subtile)
                            render_subtile++;
                    }
                }

                m_render_remain_cycle = render_subtile;
            }

            if (m_order_load_bit) {
                m_order_load_bit = false;

                m_feature_load_bit = true;
                m_feature_load_chunk_size = m_order_load_chunk_size;
                m_feature_load_base = m_order_load_base;

                std::vector<u64> address_list;

                for (int idx = m_order_load_base; idx < m_order_load_next_base; idx++) {
                    u64 address = CURR_PROJECTION_BASE;
                    address += g_trace->trace.duplicated_gaussian_per_tile[m_tile_id][idx].idx * PROJECTION_ENTRY_SIZE;
                    address = align_address(address, to_u64(get_config("DRAM", "CacheLine")));
                    address_list.push_back(address);
                }

                m_feature_load_id = g_dram_wrapper->discrete_dram_access(address_list,
                                                                         false,
                                                                         0,
                                                                         "Projection Information");
            }

            if (m_order_load_next_base < g_trace->trace.duplicated_gaussian_per_tile[m_tile_id].size()) {
                m_order_load_bit = true;

                const auto total_size = g_trace->trace.duplicated_gaussian_per_tile[m_tile_id].size() - m_order_load_next_base;
                const auto chunk_size = to_u64(get_config("OTHER", "RenderChunkSize"));

                m_order_load_chunk_size = (total_size > chunk_size) ? chunk_size : total_size;
                m_order_load_base = m_order_load_next_base;
                m_order_load_next_base += m_order_load_chunk_size;

                m_order_load_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                         m_order_load_chunk_size * NEW_ENTRY_SIZE,
                                                                         false,
                                                                         0,
                                                                         "New Gaussian Order (Load)");
            }
        }
    }
}

void renderer_t::tick() {
    m_render_remain_cycle = (m_render_remain_cycle > 0) ? m_render_remain_cycle - 1 : 0;

    switch (m_state) {
    case RENDERER_STATE_IDLE:
        tick_idle();
        break;
    case RENDERER_STATE_RUN:
        tick_run();
        break;
    }
}

void renderer_t::ready(u64 tile_id) {
    m_ready = true;
    m_tile_id = tile_id;
}

bool renderer_t::is_finished() {
    if (m_ready)
        return false;

    if (m_state != RENDERER_STATE_IDLE)
        return false;

    return true;
}

} // namespace garnet
