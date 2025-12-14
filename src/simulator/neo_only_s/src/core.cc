#include "core.h"
#include "variable.h"

#include <spdlog/spdlog.h>

namespace garnet {

core_t::core_t() {
    m_cycle = 0;
    m_ready = false;
    m_state = CORE_STATE_IDLE;
}

core_t::~core_t() {
    const u64 CORE_clock = to_u64(get_config("CORE", "Clock"));
    const double total_time = ((double)m_cycle) / (CORE_clock * MHz);
    const double fps = 1.0f / total_time;

    spdlog::info("Total Simulation Time: {:.1f} ms", total_time * 1000);
    spdlog::info("Expected FPS: {:.1f}", fps);
}

void core_t::tick_idle() {
    if (m_ready) {
        m_ready = false;
        m_state = CORE_STATE_PARALLEL;
        m_common_phase.ready();
    }
}

void core_t::tick_parallel() {
    bool all_done = true;

    if (!m_common_phase.is_finished())
        all_done = false;

    if (all_done)
        m_state = CORE_STATE_IDLE;
}

void core_t::tick() {
    m_cycle++;

    m_common_phase.tick();

    switch (m_state) {
    case CORE_STATE_IDLE:
        tick_idle();
        break;
    case CORE_STATE_PARALLEL:
        tick_parallel();
        break;
    }
}

void core_t::ready() {
    m_ready = true;
}

bool core_t::is_finished() {
    if (m_ready)
        return false;

    if (m_state != CORE_STATE_IDLE)
        return false;

    return true;
}

} // namespace garnet
