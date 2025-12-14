#include "simulator.h"
#include "variable.h"

#include <spdlog/spdlog.h>

namespace garnet {

static u64 gcd(u64 a, u64 b) {
    while (b == 0)
        return a;
    return gcd(b, a % b);
}

static u64 lcm(u64 a, u64 b) {
    return a * b / gcd(a, b);
}

simulator_t::simulator_t() {
    const u64 DRAM_clock = to_u64(get_config("DRAM", "Clock"));
    const u64 CORE_clock = to_u64(get_config("CORE", "Clock"));
    const u64 lcm_clock = lcm(DRAM_clock, CORE_clock);

    m_DRAM_unit_time = lcm_clock / DRAM_clock;
    m_CORE_unit_time = lcm_clock / CORE_clock;
    m_curr_time = 0;
    m_unit_time = gcd(m_DRAM_unit_time, m_CORE_unit_time);

    m_ready = false;
}

simulator_t::~simulator_t() {}

void simulator_t::ready() {
    m_ready = true;
}

bool simulator_t::is_finished() {
    if (m_ready)
        return false;

    if (!g_core->is_finished())
        return false;

    return true;
}

void simulator_t::elapsed_unit_time() {
    m_curr_time += m_unit_time;

    if (m_curr_time % m_DRAM_unit_time == 0)
        g_dram_wrapper->tick();

    if (m_curr_time % m_CORE_unit_time == 0) {
        if (m_ready) {
            m_ready = false;
            g_core->ready();
        }

        g_core->tick();
    }

    if (m_curr_time == lcm(m_DRAM_unit_time, m_CORE_unit_time))
        m_curr_time = 0;
}

} // namespace garnet
