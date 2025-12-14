#include "render_phase.h"
#include "variable.h"

#include <spdlog/spdlog.h>

/*
 * Assumption of Input:
 *
 * [width] [height]
 * [number of gaussians]
 * [number of tiles]
 * [tile idx] [number of new gaussian] [number of reuse gaussian]
 *
 */

namespace garnet {

render_phase_t::render_phase_t() {
    m_ready = false;
    m_tile_id = 0;
    m_state = RENDER_PHASE_STATE_IDLE;
    m_num_renderer = to_u64(get_config("OTHER", "Renderer"));
    m_renderer.resize(m_num_renderer);
}

render_phase_t::~render_phase_t() {}

void render_phase_t::tick_idle() {
    if (m_ready) {
        m_ready = false;
        m_state = RENDER_PHASE_STATE_RUN;
    }
}

void render_phase_t::tick_run() {
    const u64 num_tile = g_trace->trace.num_tile;
    bool all_done = m_tile_id >= num_tile;

    for (int i = 0; i < m_num_renderer && m_tile_id < num_tile && !g_render_queue.empty(); i++) {
        int front = g_render_queue.front();

        if (m_renderer[i].is_finished()) {
            if (m_tile_id % 100 == 0)
                spdlog::info("Serial Phase Ready: {}", m_tile_id);
            g_render_queue.pop();
            m_renderer[i].ready(front);
            m_tile_id++;
        }
    }

    for (int i = 0; i < m_num_renderer; i++)
        if (!m_renderer[i].is_finished())
            all_done = false;

    if (all_done) {
        spdlog::info("Serial Phase Finish");
        g_dram_wrapper->summary();
        m_state = RENDER_PHASE_STATE_IDLE;
    }
}

void render_phase_t::tick() {
    for (int i = 0; i < m_num_renderer; i++)
        m_renderer[i].tick();

    switch (m_state) {
    case RENDER_PHASE_STATE_IDLE:
        tick_idle();
        break;
    case RENDER_PHASE_STATE_RUN:
        tick_run();
        break;
    }
}

void render_phase_t::ready() {
    m_ready = true;
}

bool render_phase_t::is_finished() {
    if (m_ready)
        return false;

    if (m_state != RENDER_PHASE_STATE_IDLE)
        return false;

    return true;
}

} // namespace garnet
