#ifndef render_phase_H
#define render_phase_H

#include "renderer.h"
#include "utils.h"

#include <vector>

namespace garnet {

enum render_phase_state_t {
    RENDER_PHASE_STATE_IDLE,
    RENDER_PHASE_STATE_RUN,
};

class render_phase_t {
  public:
    render_phase_t();
    ~render_phase_t();

    void tick();
    void ready();
    bool is_finished();

  private:
    bool m_ready;
    u64 m_tile_id;
    u64 m_num_renderer;

    render_phase_state_t m_state;
    std::vector<renderer_t> m_renderer;

    void tick_idle();
    void tick_run();
};

} // namespace garnet

#endif
