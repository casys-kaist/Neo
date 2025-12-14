#ifndef CORE_H
#define CORE_H

#include "common_phase.h"
#include "postprocessor.h"
#include "render_phase.h"
#include "reuse_phase.h"
#include "utils.h"

namespace garnet {

enum core_state_t {
    CORE_STATE_IDLE,
    CORE_STATE_PARALLEL,
    CORE_STATE_POSTPROCESSING,
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

    reuse_phase_t m_reuse_phase;
    common_phase_t m_common_phase;
    render_phase_t m_render_phase;
    postprocessor_t m_postprocessor;

    core_state_t m_state;

    void tick_idle();
    void tick_parallel();
    void tick_postprocessing();
};

} // namespace garnet

#endif
