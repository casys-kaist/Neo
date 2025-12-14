#ifndef REUSE_PHASE_H
#define REUSE_PHASE_H

#include "sorter.h"
#include "utils.h"

#include <vector>

namespace garnet {

enum reuse_phase_state_t {
    REUSE_PHASE_STATE_IDLE,
    REUSE_PHASE_STATE_RUN,
};

class reuse_phase_t {
  public:
    reuse_phase_t();
    ~reuse_phase_t();

    void tick();
    void ready();
    bool is_finished();

  private:
    bool m_ready;
    u64 m_tile_id;
    u64 m_morton_id;
    u64 m_num_adaptive_sorter;
    reuse_phase_state_t m_state;
    std::vector<global_sorter_2_t> m_sorter;

    void tick_idle();
    void tick_run();
};

} // namespace garnet

#endif
