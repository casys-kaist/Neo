#ifndef DRAM_H
#define DRAM_H

#include "Config.h"
#include "Memory.h"
#include "utils.h"

#include <iostream>
#include <map>
#include <vector>

namespace garnet {

class cache_t {
  public:
    cache_t();
    ~cache_t();

    void tick();
    void insert(u64 address);
    bool is_hit(u64 address);

  private:
    u64 m_cycle;
    std::map<u64, u64> m_cache;
    u64 m_max_cache_size;
};

class dram_t {
  public:
    dram_t();
    ~dram_t();

    void tick();
    bool request(u64 address, bool is_write, function<void(ramulator::Request &)> callback, u64 core_id);

  private:
    ramulator::MemoryBase *m_memory;
    ramulator::Config m_config;
};

struct wait_request_t {
    bool is_write;
    int core_id;
    u64 total_request;
    u64 send_request;
    u64 ack_request;
    vector<u64> address_list;
    std::string memo;
};

class dram_wrapper_t {
  public:
    dram_wrapper_t();
    ~dram_wrapper_t();

    void tick();
    bool is_finished(u64 id);
    u64 continuous_dram_access(u64 address, u64 size, bool is_write, u64 core_id, std::string memo);
    u64 discrete_dram_access(vector<u64> &address_list, bool is_write, u64 core_id, std::string memo);
    void summary();

  private:
    dram_t *m_dram;
    cache_t *m_cache;
    u64 m_total_request;
    u64 m_total_dram_request;
    u64 m_cycle;
    u64 m_id;
    std::map<u64, wait_request_t> m_wait_request;
};

} // namespace garnet

#endif
