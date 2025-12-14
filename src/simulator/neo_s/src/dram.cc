#include "dram.h"
#include "variable.h"

#include "DDR3.h"
#include "DDR4.h"
#include "HBM.h"
#include "LPDDR3.h"
#include "LPDDR4.h"
#include "MemoryFactory.h"
#include "Request.h"
#include "Statistics.h"

#include <map>
#include <spdlog/spdlog.h>

namespace garnet {

cache_t::cache_t() {
    m_cycle = 0;
    m_max_cache_size = to_u64(get_config("OTHER", "CacheSize")) / to_u64(get_config("DRAM", "CacheLine"));
    m_cache.clear();
}

cache_t::~cache_t() {
    m_cache.clear();
}

void cache_t::tick() {
    m_cycle++;
}

void cache_t::insert(u64 address) {
    if (address < CURR_PROJECTION_BASE || REUSE_BASE < address)
        return;

    if (m_cache.size() < m_max_cache_size)
        m_cache[address] = m_cycle;
    else if (m_max_cache_size > 0) {
        u64 delete_key = 0;
        u64 min_cycle = m_cycle;

        for (auto &entry : m_cache) {
            if (entry.second < min_cycle) {
                min_cycle = entry.second;
                delete_key = entry.first;
            }
        }

        m_cache.erase(delete_key);
        m_cache[address] = m_cycle;
    }
}

bool cache_t::is_hit(u64 address) {
    if (m_cache.find(address) == m_cache.end())
        return false;

    m_cache[address] = m_cycle;
    return true;
}

static std::map<std::string, function<ramulator::MemoryBase *(const ramulator::Config &, int)>> name_to_func = {
    {"DDR3", &ramulator::MemoryFactory<ramulator::DDR3>::create},
    {"DDR4", &ramulator::MemoryFactory<ramulator::DDR4>::create},
    {"LPDDR3", &ramulator::MemoryFactory<ramulator::LPDDR3>::create},
    {"LPDDR4", &ramulator::MemoryFactory<ramulator::LPDDR4>::create},
    {"HBM", &ramulator::MemoryFactory<ramulator::HBM>::create},
};

dram_t::dram_t() {
    m_config.parse(get_config("DRAM", "Config"));
    m_config.set_core_num(1);
    m_memory = name_to_func[m_config["standard"]](m_config, to_u64(get_config("DRAM", "CacheLine")));
}

dram_t::~dram_t() {
    m_memory->finish();
    delete m_memory;
}

void dram_t::tick() {
    m_memory->tick();
}

bool dram_t::request(u64 address, bool is_write, function<void(ramulator::Request &)> callback, u64 core_id) {
    auto req_type = is_write ? ramulator::Request::Type::WRITE : ramulator::Request::Type::READ;

    ramulator::Request req(address, req_type, callback, core_id);

    return m_memory->send(req);
}

dram_wrapper_t::dram_wrapper_t() {
    m_dram = new dram_t();
    m_cache = new cache_t();

    m_total_request = 0;
    m_total_dram_request = 0;
    m_cycle = 0;
    m_id = 0;
}

dram_wrapper_t::~dram_wrapper_t() {
    delete m_dram;
}

void dram_wrapper_t::tick() {
    m_cycle++;
    m_dram->tick();
    m_cache->tick();

    for (auto &wait_req : m_wait_request) {
        while (wait_req.second.send_request < wait_req.second.total_request) {
            u64 address = wait_req.second.address_list[wait_req.second.send_request];

            if (m_cache->is_hit(address)) {
                m_total_request++;
                wait_req.second.send_request++;
                wait_req.second.ack_request++;
                continue;
            }

            auto callback = [this, reqid = wait_req.first, addr = address](ramulator::Request &req) {
                if (req.type == ramulator::Request::Type::READ) {
                    m_wait_request[reqid].ack_request++;
                    m_cache->insert(addr);
                }
            };

            bool accept = m_dram->request(address, wait_req.second.is_write, callback, 0);

            if (accept) {
                m_total_dram_request++;
                wait_req.second.send_request++;
            } else
                break;
        }
    }
}

u64 dram_wrapper_t::continuous_dram_access(u64 address, u64 size, bool is_write, u64 core_id, std::string memo) {
    m_wait_request[m_id] = wait_request_t();
    auto &wait_req = m_wait_request[m_id];

    wait_req.is_write = is_write;
    wait_req.core_id = core_id;
    wait_req.total_request = size / to_u64(get_config("DRAM", "CacheLine"));
    wait_req.send_request = 0;
    wait_req.ack_request = 0;
    wait_req.memo = memo;

    for (u64 i = 0; i < wait_req.total_request; i++) {
        u64 aligned_address = align_address(address + i * to_u64(get_config("DRAM", "CacheLine")), to_u64(get_config("DRAM", "CacheLine")));
        wait_req.address_list.push_back(aligned_address);
    }

    return m_id++;
}

u64 dram_wrapper_t::discrete_dram_access(vector<u64> &address_list, bool is_write, u64 core_id, std::string memo) {
    m_wait_request[m_id] = wait_request_t();
    auto &wait_req = m_wait_request[m_id];

    wait_req.is_write = is_write;
    wait_req.core_id = core_id;
    wait_req.total_request = address_list.size();
    wait_req.send_request = 0;
    wait_req.ack_request = 0;
    wait_req.memo = memo;

    for (auto &address : address_list) {
        u64 aligned_address = align_address(address, to_u64(get_config("DRAM", "CacheLine")));
        wait_req.address_list.push_back(aligned_address);
    }

    return m_id++;
}

bool dram_wrapper_t::is_finished(u64 id) {
    if (m_wait_request.find(id) == m_wait_request.end())
        return true;

    auto &req = m_wait_request[id];

    if (req.is_write) {
        if (req.total_request == req.send_request) {
            m_wait_request.erase(id);
            return true;
        } else
            return false;
    } else {
        if (req.total_request == req.ack_request) {
            m_wait_request.erase(id);
            return true;
        } else
            return false;
    }
}

void dram_wrapper_t::summary() {
    double total_cache_traffic = ((double)m_total_request * to_u64(get_config("DRAM", "CacheLine")));
    spdlog::info("Total Cache Traffic : {:.1f} MB", total_cache_traffic / MB);

    double total_dram_traffic = ((double)(m_total_dram_request * to_u64(get_config("DRAM", "CacheLine"))));
    spdlog::info("Total DRAM Traffic : {:.1f} MB", total_dram_traffic / MB);

    double total_time = (double)m_cycle / (to_u64(get_config("DRAM", "Clock")) * MHz);
    spdlog::info("Total DRAM Time : {:.1f} ms ({:.1f} FPS)", total_time * 1000, 1 / total_time);

    double total_bandwidth = total_dram_traffic / total_time / GB;
    spdlog::info("Total DRAM Bandwidth : {:.1f} GB/s", total_bandwidth);
}

} // namespace garnet
