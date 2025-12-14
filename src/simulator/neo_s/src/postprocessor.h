#ifndef POSTPROCESSOR_H
#define POSTPROCESSOR_H

#include "utils.h"

namespace garnet {

enum postprocessor_state_t {
    POSTPROCESSOR_STATE_IDLE,
    POSTPROCESSOR_STATE_RUN,
};

class postprocessor_t {
  public:
    postprocessor_t();
    ~postprocessor_t();

    void tick();
    void ready();
    bool is_finished();

  private:
    postprocessor_state_t m_state;
    bool m_ready;
    u64 m_read_id;
    u64 m_write_id;

    void tick_idle();
    void tick_run();
};

} // namespace garnet

#endif
