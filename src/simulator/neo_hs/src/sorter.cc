#include "sorter.h"
#include "variable.h"

#include <spdlog/spdlog.h>

namespace garnet {

global_sorter_t::global_sorter_t() {
    m_state = GLOBAL_SORTER_STATE_IDLE;
    m_ready = false;
    m_tile_id = 0;

    m_approximation_load_id = 0;
    m_approximation_cnt = 0;

    m_precise_load_next_base_idx = 0;
    m_precise_load_bit = false;
    m_precise_load_id = 0;
    m_precise_load_chunk_size = 0;
    m_precise_load_base_idx = 0;

    m_precise_sort_bit = false;
    m_precise_sort_remain_cycle = 0;
    m_precise_sort_chunk_size = 0;
    m_precise_sort_base_idx = 0;

    m_store_bit = false;
    m_store_id = 0;
    m_store_chunk_size = 0;
    m_store_base_idx = 0;
}

global_sorter_t::~global_sorter_t() {}

void global_sorter_t::tick_idle() {
    if (m_ready) {
        m_ready = false;
        const u64 num_gaussian = g_trace->trace.num_new_gaussian_per_tile[m_tile_id];

        if (num_gaussian != 0) {
            m_state = GLOBAL_SORTER_STATE_APPROXIMATION;
            m_approximation_load_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                             num_gaussian * NEW_ENTRY_SIZE,
                                                                             false,
                                                                             0,
                                                                             "Global Approximation Sort (Load)");
            int max_level = ceil(log2(num_gaussian / to_u64(get_config("OTHER", "GlobalChunkSize")) / 8));
            max_level = (max_level <= 0) ? 2 : max_level + 2;
            m_approximation_cnt = 2 * max_level - 1;
        } else {
            g_common_finish[m_tile_id] = true;
            if (g_reuse_finish[m_tile_id] && g_common_finish[m_tile_id])
                g_render_queue.push(m_tile_id);
        }
    }
}

void global_sorter_t::tick_approximation() {
    const u64 chunksize = to_u64(get_config("OTHER", "GlobalChunkSize"));
    const u64 num_gaussian = g_trace->trace.num_new_gaussian_per_tile[m_tile_id];
    const u64 actual_size = min(chunksize, num_gaussian);

    if (g_dram_wrapper->is_finished(m_approximation_load_id)) {
        if (m_approximation_cnt == 0) {
            m_state = GLOBAL_SORTER_STATE_PRECISE;

            m_precise_load_next_base_idx = actual_size;
            m_precise_load_bit = true;
            m_precise_load_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                       actual_size * NEW_ENTRY_SIZE,
                                                                       false,
                                                                       0,
                                                                       "Global Precise Sort (LOAD)");
            m_precise_load_chunk_size = actual_size;
            m_precise_load_base_idx = 0;

            m_precise_sort_bit = false;
            m_precise_sort_remain_cycle = 0;
            m_precise_sort_chunk_size = 0;
            m_precise_sort_base_idx = 0;

            m_store_bit = false;
            m_store_id = 0;
            m_store_chunk_size = 0;
            m_store_base_idx = 0;
        } else {
            if (m_approximation_cnt % 2) {
                m_approximation_load_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                                 num_gaussian * NEW_ENTRY_SIZE,
                                                                                 true,
                                                                                 0,
                                                                                 "Global Approximation Sort (STORE)");
            } else {
                m_approximation_load_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                                 num_gaussian * NEW_ENTRY_SIZE,
                                                                                 false,
                                                                                 0,
                                                                                 "Global Approximation Sort (LOAD)");
            }
            m_approximation_cnt--;
        }
    }
}

void global_sorter_t::tick_precise() {
    const u64 cacheline = to_u64(get_config("DRAM", "CacheLine"));
    const u64 chunksize = to_u64(get_config("OTHER", "GlobalChunkSize"));
    const u64 num_gaussian = g_trace->trace.num_new_gaussian_per_tile[m_tile_id];

    bool all_done = true;

    if (m_precise_load_bit && !g_dram_wrapper->is_finished(m_precise_load_id))
        all_done = false;

    if (m_precise_sort_bit && m_precise_sort_remain_cycle > 0)
        all_done = false;

    if (m_store_bit && !g_dram_wrapper->is_finished(m_store_id))
        all_done = false;

    if (all_done) {
        if (!m_precise_load_bit && !m_precise_sort_bit && !m_store_bit) {
            m_state = GLOBAL_SORTER_STATE_IDLE;

            g_common_finish[m_tile_id] = true;
            if (g_reuse_finish[m_tile_id] && g_common_finish[m_tile_id])
                g_render_queue.push(m_tile_id);

            return;
        }

        if (m_store_bit) {
            m_store_bit = false;
            m_store_id = 0;
            m_store_chunk_size = 0;
            m_store_base_idx = 0;
        }

        if (m_precise_sort_bit) {
            m_precise_sort_bit = false;

            m_store_bit = true;
            m_store_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                m_store_chunk_size * NEW_ENTRY_SIZE,
                                                                true,
                                                                0,
                                                                "Global Precise Sort (Store)");
            m_store_chunk_size = m_precise_sort_chunk_size;
            m_store_base_idx = m_precise_sort_base_idx;
        }

        if (m_precise_load_bit) {
            m_precise_load_bit = false;

            m_precise_sort_bit = true;
            const u64 sort_granularity = to_u64(get_config("OTHER", "SortGranularity"));
            const u64 merge_sort_max_depth = (m_precise_load_chunk_size <= sort_granularity) ? 1 : ceil(log2(m_precise_load_chunk_size / sort_granularity));
            m_precise_sort_remain_cycle = merge_sort_max_depth * m_precise_load_chunk_size;
            m_precise_sort_chunk_size = m_precise_load_chunk_size;
            m_precise_sort_base_idx = m_precise_load_base_idx;
        }

        if (m_precise_load_next_base_idx < num_gaussian) {
            const u64 next_base_idx = min(m_precise_load_next_base_idx + chunksize, num_gaussian);
            const u64 actual_size = next_base_idx - m_precise_load_next_base_idx;

            m_precise_load_bit = true;
            m_precise_load_id = g_dram_wrapper->continuous_dram_access(new_tile_base(m_tile_id),
                                                                       actual_size * NEW_ENTRY_SIZE,
                                                                       false,
                                                                       0,
                                                                       "PRECISE (LOAD)");
            m_precise_load_chunk_size = actual_size;
            m_precise_load_base_idx = m_precise_load_next_base_idx;
            m_precise_load_next_base_idx = next_base_idx;
        }
    }
}

void global_sorter_t::tick() {
    m_precise_sort_remain_cycle = (m_precise_sort_remain_cycle > 0) ? m_precise_sort_remain_cycle - 1 : 0;

    switch (m_state) {
    case GLOBAL_SORTER_STATE_IDLE:
        tick_idle();
        break;
    case GLOBAL_SORTER_STATE_APPROXIMATION:
        tick_approximation();
        break;
    case GLOBAL_SORTER_STATE_PRECISE:
        tick_precise();
        break;
    }
}

void global_sorter_t::ready(u64 tile_id) {
    m_ready = true;
    m_tile_id = tile_id;
}

bool global_sorter_t::is_finished() {
    if (m_ready)
        return false;

    if (m_state != GLOBAL_SORTER_STATE_IDLE)
        return false;

    return true;
}

///

global_sorter_2_t::global_sorter_2_t() {
    m_state = GLOBAL_SORTER_2_STATE_IDLE;
    m_ready = false;
    m_tile_id = 0;

    m_approximation_load_id = 0;
    m_approximation_cnt = 0;

    m_precise_load_next_base_idx = 0;
    m_precise_load_bit = false;
    m_precise_load_id = 0;
    m_precise_load_chunk_size = 0;
    m_precise_load_base_idx = 0;

    m_precise_sort_bit = false;
    m_precise_sort_remain_cycle = 0;
    m_precise_sort_chunk_size = 0;
    m_precise_sort_base_idx = 0;

    m_store_bit = false;
    m_store_id = 0;
    m_store_chunk_size = 0;
    m_store_base_idx = 0;
}

global_sorter_2_t::~global_sorter_2_t() {}

void global_sorter_2_t::tick_idle() {
    if (m_ready) {
        m_ready = false;
        const u64 num_gaussian = g_trace->trace.num_reuse_gaussian_per_tile[m_tile_id];

        if (num_gaussian != 0) {
            m_state = GLOBAL_SORTER_2_STATE_APPROXIMATION;
            m_approximation_load_id = g_dram_wrapper->continuous_dram_access(reuse_tile_base(m_tile_id),
                                                                             num_gaussian * REUSE_ENTRY_SIZE,
                                                                             false,
                                                                             0,
                                                                             "Global Approximation Sort (Load)");
            int max_level = ceil(log2(num_gaussian / to_u64(get_config("OTHER", "GlobalChunkSize")) / 8));
            max_level = (max_level <= 0) ? 2 : max_level + 2;
            m_approximation_cnt = 2 * max_level - 1;
        } else {
            g_common_finish[m_tile_id] = true;
            if (g_reuse_finish[m_tile_id] && g_common_finish[m_tile_id])
                g_render_queue.push(m_tile_id);
        }
    }
}

void global_sorter_2_t::tick_approximation() {
    const u64 chunksize = to_u64(get_config("OTHER", "GlobalChunkSize"));
    const u64 num_gaussian = g_trace->trace.num_reuse_gaussian_per_tile[m_tile_id];
    const u64 actual_size = min(chunksize, num_gaussian);

    if (g_dram_wrapper->is_finished(m_approximation_load_id)) {
        if (m_approximation_cnt == 0) {
            m_state = GLOBAL_SORTER_2_STATE_PRECISE;

            m_precise_load_next_base_idx = actual_size;
            m_precise_load_bit = true;
            m_precise_load_id = g_dram_wrapper->continuous_dram_access(reuse_tile_base(m_tile_id),
                                                                       actual_size * REUSE_ENTRY_SIZE,
                                                                       false,
                                                                       0,
                                                                       "Global Precise Sort (LOAD)");
            m_precise_load_chunk_size = actual_size;
            m_precise_load_base_idx = 0;

            m_precise_sort_bit = false;
            m_precise_sort_remain_cycle = 0;
            m_precise_sort_chunk_size = 0;
            m_precise_sort_base_idx = 0;

            m_store_bit = false;
            m_store_id = 0;
            m_store_chunk_size = 0;
            m_store_base_idx = 0;
        } else {
            if (m_approximation_cnt % 2) {
                m_approximation_load_id = g_dram_wrapper->continuous_dram_access(reuse_tile_base(m_tile_id),
                                                                                 num_gaussian * REUSE_ENTRY_SIZE,
                                                                                 true,
                                                                                 0,
                                                                                 "Global Approximation Sort (STORE)");
            } else {
                m_approximation_load_id = g_dram_wrapper->continuous_dram_access(reuse_tile_base(m_tile_id),
                                                                                 num_gaussian * REUSE_ENTRY_SIZE,
                                                                                 false,
                                                                                 0,
                                                                                 "Global Approximation Sort (LOAD)");
            }
            m_approximation_cnt--;
        }
    }
}

void global_sorter_2_t::tick_precise() {
    const u64 cacheline = to_u64(get_config("DRAM", "CacheLine"));
    const u64 chunksize = to_u64(get_config("OTHER", "GlobalChunkSize"));
    const u64 num_gaussian = g_trace->trace.num_reuse_gaussian_per_tile[m_tile_id];

    bool all_done = true;

    if (m_precise_load_bit && !g_dram_wrapper->is_finished(m_precise_load_id))
        all_done = false;

    if (m_precise_sort_bit && m_precise_sort_remain_cycle > 0)
        all_done = false;

    if (m_store_bit && !g_dram_wrapper->is_finished(m_store_id))
        all_done = false;

    if (all_done) {
        if (!m_precise_load_bit && !m_precise_sort_bit && !m_store_bit) {
            m_state = GLOBAL_SORTER_2_STATE_IDLE;

            g_reuse_finish[m_tile_id] = true;
            if (g_reuse_finish[m_tile_id] && g_common_finish[m_tile_id])
                g_render_queue.push(m_tile_id);

            return;
        }

        if (m_store_bit) {
            m_store_bit = false;
            m_store_id = 0;
            m_store_chunk_size = 0;
            m_store_base_idx = 0;
        }

        if (m_precise_sort_bit) {
            m_precise_sort_bit = false;

            m_store_bit = true;
            m_store_id = g_dram_wrapper->continuous_dram_access(reuse_tile_base(m_tile_id),
                                                                m_store_chunk_size * REUSE_ENTRY_SIZE,
                                                                true,
                                                                0,
                                                                "Global Precise Sort (Store)");
            m_store_chunk_size = m_precise_sort_chunk_size;
            m_store_base_idx = m_precise_sort_base_idx;
        }

        if (m_precise_load_bit) {
            m_precise_load_bit = false;

            m_precise_sort_bit = true;
            const u64 sort_granularity = to_u64(get_config("OTHER", "SortGranularity"));
            const u64 merge_sort_max_depth = (m_precise_load_chunk_size <= sort_granularity) ? 1 : ceil(log2(m_precise_load_chunk_size / sort_granularity));
            m_precise_sort_remain_cycle = merge_sort_max_depth * m_precise_load_chunk_size;
            m_precise_sort_chunk_size = m_precise_load_chunk_size;
            m_precise_sort_base_idx = m_precise_load_base_idx;
        }

        if (m_precise_load_next_base_idx < num_gaussian) {
            const u64 next_base_idx = min(m_precise_load_next_base_idx + chunksize, num_gaussian);
            const u64 actual_size = next_base_idx - m_precise_load_next_base_idx;

            m_precise_load_bit = true;
            m_precise_load_id = g_dram_wrapper->continuous_dram_access(reuse_tile_base(m_tile_id),
                                                                       actual_size * REUSE_ENTRY_SIZE,
                                                                       false,
                                                                       0,
                                                                       "PRECISE (LOAD)");
            m_precise_load_chunk_size = actual_size;
            m_precise_load_base_idx = m_precise_load_next_base_idx;
            m_precise_load_next_base_idx = next_base_idx;
        }
    }
}

void global_sorter_2_t::tick() {
    m_precise_sort_remain_cycle = (m_precise_sort_remain_cycle > 0) ? m_precise_sort_remain_cycle - 1 : 0;

    switch (m_state) {
    case GLOBAL_SORTER_2_STATE_IDLE:
        tick_idle();
        break;
    case GLOBAL_SORTER_2_STATE_APPROXIMATION:
        tick_approximation();
        break;
    case GLOBAL_SORTER_2_STATE_PRECISE:
        tick_precise();
        break;
    }
}

void global_sorter_2_t::ready(u64 tile_id) {
    m_ready = true;
    m_tile_id = tile_id;
}

bool global_sorter_2_t::is_finished() {
    if (m_ready)
        return false;

    if (m_state != GLOBAL_SORTER_2_STATE_IDLE)
        return false;

    return true;
}

bool global_sorter_2_t::can_ready() {
    if (m_ready)
        return false;

    return true;
}

} // namespace garnet
