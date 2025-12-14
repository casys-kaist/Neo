#ifndef COMMON_PHASE_H
#define COMMON_PHASE_H

#include "sorter.h"
#include "utils.h"

#include <vector>

namespace garnet {

enum common_phase_state_t {
    COMMON_PHASE_STATE_IDLE,
    COMMON_PHASE_STATE_FRUSTUM_CULL,
    COMMON_PHASE_STATE_PROJECTION,
    COMMON_PHASE_STATE_STORE,
    COMMON_PHASE_STATE_DUPLICATION,
    COMMON_PHASE_STATE_SORT,
};

class common_phase_t {
  public:
    common_phase_t();
    ~common_phase_t();

    void tick();
    void ready();
    bool is_finished();

  private:
    bool m_ready;
    u64 m_id;
    u64 m_tile_id;
    u64 m_morton_id;
    u64 m_num_global_sorter;

    common_phase_state_t m_state;
    std::vector<global_sorter_t> m_sorter;
    std::vector<u64> m_curr_num_gaussian_per_tile;

    void tick_idle();
    void tick_duplication();
    void tick_sort();
};

} // namespace garnet

#endif
