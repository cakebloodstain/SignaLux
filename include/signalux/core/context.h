#pragma once
#include <entt/entt.hpp>
#include <concurrentqueue.h>
#include <spdlog/spdlog.h>
#include "types.h"

namespace signalux
{

    class Context
    {
    public:
        Context();
        ~Context();

        // 禁止拷贝，保证单例或显式生命周期管理
        Context(const Context &) = delete;
        Context &operator=(const Context &) = delete;

        // 获取 ECS 注册表
        entt::registry &registry() { return m_registry; }

        // 报文分发入口 (从驱动线程调用)
        void dispatch_frame(const RawFrame &frame)
        {
            m_frame_queue.enqueue(frame);
        }

        // 处理循环 (通常在 jthread 中运行)
        void process_once();

        // 信号注册接口
        entt::entity create_signal(const std::string &name);

    private:
        entt::registry m_registry;

        // 高性能无锁队列，承接来自不同硬件驱动的报文
        moodycamel::ConcurrentQueue<RawFrame> m_frame_queue;

        std::shared_ptr<spdlog::logger> m_logger;
    };

} // namespace signalux