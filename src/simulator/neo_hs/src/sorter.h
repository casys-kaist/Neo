#ifndef SORTER_H
#define SORTER_H

#include "utils.h"

namespace garnet {

enum global_sorter_state_t {
    GLOBAL_SORTER_STATE_IDLE,
    GLOBAL_SORTER_STATE_APPROXIMATION,
    GLOBAL_SORTER_STATE_PRECISE,
};

class global_sorter_t {
  public:
    global_sorter_t();
    ~global_sorter_t();

    void tick();
    void ready(u64 tile_id);
    bool is_finished();

  private:
    global_sorter_state_t m_state;
    bool m_ready;
    u64 m_tile_id;

    // APPROXIMATION
    u64 m_approximation_load_id;
    u64 m_approximation_cnt;

    // PRECISE LOAD
    u64 m_precise_load_next_base_idx;
    bool m_precise_load_bit;
    u64 m_precise_load_id;
    u64 m_precise_load_chunk_size;
    u64 m_precise_load_base_idx;

    // PRECISE SORT
    bool m_precise_sort_bit;
    u64 m_precise_sort_remain_cycle;
    u64 m_precise_sort_chunk_size;
    u64 m_precise_sort_base_idx;

    // STORE
    bool m_store_bit;
    u64 m_store_id;
    u64 m_store_chunk_size;
    u64 m_store_base_idx;

    void tick_idle();
    void tick_approximation();
    void tick_precise();
};

enum global_sorter_2_state_t {
    GLOBAL_SORTER_2_STATE_IDLE,
    GLOBAL_SORTER_2_STATE_APPROXIMATION,
    GLOBAL_SORTER_2_STATE_PRECISE,
};

class global_sorter_2_t {
  public:
    global_sorter_2_t();
    ~global_sorter_2_t();

    void tick();
    void ready(u64 tile_id);
    bool can_ready();
    bool is_finished();

  private:
    global_sorter_2_state_t m_state;
    bool m_ready;
    u64 m_tile_id;

    // APPROXIMATION
    u64 m_approximation_load_id;
    u64 m_approximation_cnt;

    // PRECISE LOAD
    u64 m_precise_load_next_base_idx;
    bool m_precise_load_bit;
    u64 m_precise_load_id;
    u64 m_precise_load_chunk_size;
    u64 m_precise_load_base_idx;

    // PRECISE SORT
    bool m_precise_sort_bit;
    u64 m_precise_sort_remain_cycle;
    u64 m_precise_sort_chunk_size;
    u64 m_precise_sort_base_idx;

    // STORE
    bool m_store_bit;
    u64 m_store_id;
    u64 m_store_chunk_size;
    u64 m_store_base_idx;

    void tick_idle();
    void tick_approximation();
    void tick_precise();
};

} // namespace garnet

#endif
