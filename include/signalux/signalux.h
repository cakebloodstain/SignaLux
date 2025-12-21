// signalux.h
#pragma once

#include <memory>
#include <string>
#include <vector>
#include "signalux/types.h"
#include "signalux/driver.h"

namespace signalux
{

    // 前置声明，隐藏实现细节 (PIMPL)
    class Engine;
    class IDriverBackend;

    /**
     * @brief SignaLux 运行时上下文
     * 管理硬件连接、信号路由和事件分发
     */
    class Context
    {
    public:
        Context();
        ~Context();

        // 禁止拷贝，防止资源重复释放
        Context(const Context &) = delete;
        Context &operator=(const Context &) = delete;

        /**
         * @brief 初始化硬件连接 (Vector/ZLG/SocketCAN)
         */
        bool connect(const std::string &type, const Config &config);

        /**
         * @brief 加载信号定义 (DBC/ARXML)
         */
        void load_database(const std::string &path);

        /**
         * @brief 获取信号引擎，用于注册监控和触发器
         */
        Engine &engine();

        /**
         * @brief 阻塞或非阻塞地处理事件循环（供 Python 调用）
         */
        size_t process_events(uint32_t timeout_ms = 100);

    private:
        struct Impl;
        std::unique_ptr<Impl> pimpl_; // 封装 ENTT Registry 和 Backend
    };

    std::string get_greeting(const std::string &name);

} // namespace signalux
