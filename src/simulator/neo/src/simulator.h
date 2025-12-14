#ifndef SIMULATOR_H
#define SIMULATOR_H

#include "utils.h"

namespace garnet {

class simulator_t {
  public:
    simulator_t();
    ~simulator_t();

    void ready();
    bool is_finished();
    void elapsed_unit_time();

  private:
    u64 m_curr_time;
    u64 m_unit_time;
    u64 m_DRAM_unit_time;
    u64 m_CORE_unit_time;

    bool m_ready;
};

} // namespace garnet

#endif
