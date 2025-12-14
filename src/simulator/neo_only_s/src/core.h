#ifndef CORE_H
#define CORE_H

#include "common_phase.h"
#include "utils.h"

namespace garnet {

enum core_state_t {
    CORE_STATE_IDLE,
    CORE_STATE_PARALLEL,
};

class core_t {
  public:
    core_t();
    ~core_t();

    void tick();
    void ready();
    bool is_finished();

  private:
    u64 m_cycle;
    bool m_ready;

    common_phase_t m_common_phase;

    core_state_t m_state;

    void tick_idle();
    void tick_parallel();
};

} // namespace garnet

#endif
