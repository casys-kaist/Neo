#ifndef RENDERER_H
#define RENDERER_H

#include "utils.h"

namespace garnet {

enum renderer_state_t {
    RENDERER_STATE_IDLE,
    RENDERER_STATE_RUN,
};

class renderer_t {
  public:
    renderer_t();
    ~renderer_t();

    void tick();
    void ready(u64 tile_id);
    bool is_finished();

  private:
    renderer_state_t m_state;
    bool m_ready;
    u64 m_tile_id;

    // Order Loading
    bool m_order_load_bit;
    u64 m_order_load_id;
    u64 m_order_load_chunk_size;
    u64 m_order_load_base;
    u64 m_order_load_next_base;

    // Feature Loading
    bool m_feature_load_bit;
    u64 m_feature_load_id;
    u64 m_feature_load_chunk_size;
    u64 m_feature_load_base;

    // Rendering
    bool m_render_bit;
    u64 m_render_remain_cycle;
    u64 m_render_chunk_size;
    u64 m_render_base;

    // Order Storing
    bool m_order_store_bit;
    u64 m_order_store_id;
    u64 m_order_store_chunk_size;
    u64 m_order_store_base;

    void tick_idle();
    void tick_run();
};

} // namespace garnet

#endif
