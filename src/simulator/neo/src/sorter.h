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

enum adaptive_sorter_state_t {
    ADAPTIVE_SORTER_STATE_IDLE,
    ADAPTIVE_SORTER_STATE_RUN,
};

class adaptive_sorter_t {
  public:
    adaptive_sorter_t();
    ~adaptive_sorter_t();

    void tick();
    void ready(u64 tile_id);
    bool can_ready();
    bool is_finished();

  private:
    bool m_ready;
    u64 m_ready_tile_id;
    u64 m_remain_gaussian;

    adaptive_sorter_state_t m_state;

    bool m_load_bit;
    bool m_load_end;
    u64 m_load_id;
    u64 m_load_tile_id;
    u64 m_load_chunk_size;

    bool m_sort_bit;
    bool m_sort_end;
    u64 m_sort_tile_id;
    u64 m_sort_remain_cycle;
    u64 m_sort_chunk_size;

    bool m_store_bit;
    bool m_store_end;
    u64 m_store_id;
    u64 m_store_tile_id;
    u64 m_store_chunk_size;

    void tick_idle();
    void tick_run();
};

} // namespace garnet

#endif
