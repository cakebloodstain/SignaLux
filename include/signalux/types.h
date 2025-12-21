#pragma once

#include <cstdint>
#include <string>
#include <variant>
#include <array>
#include <vector>
#include <chrono>
#include <optional>

namespace signalux
{

    /**
     * @brief 硬件驱动类型枚举
     */
    enum class DriverType
    {
        Vector,    // Windows: Vector XL-Lib
        ZLG,       // Windows: ZLG USBCAN
        SocketCAN, // Linux: SocketCAN
        Virtual    // 仿真/回放模式
    };

    /**
     * @brief 驱动连接配置
     */
    struct Config
    {
        std::string channel_name;  // 例如 "CAN1", "can0"
        uint32_t bitrate = 500000; // 仲裁段比特率
        uint32_t data_bitrate = 0; // 数据段比特率 (CAN FD)
        bool is_fd = false;        // 是否启用 CAN FD
        bool is_brs = false;       // 是否启用比特率切换 (Bit Rate Switch)
    };

    /**
     * @brief 统一的原始 CAN 帧结构
     * 兼容 CAN 2.0 (8字节) 和 CAN FD (64字节)
     */
    struct RawFrame
    {
        uint32_t id;           // CAN ID
        uint64_t timestamp_ns; // 纳秒级时间戳 (由底层驱动或 HAL 获取)
        uint8_t dlc;           // Data Length Code
        bool is_extended;      // 扩展帧标识
        bool is_fd;            // FD 帧标识
        bool is_remote;        // 远程帧标识

        // 使用 std::array 固定分配 64 字节，以获得最佳的内存对齐和性能
        // 对于 Python 侧，通过 nanobind::ndarray 映射时，根据 dlc 动态切片
        alignas(16) std::array<uint8_t, 64> data{};
    };

    /**
     * @brief 信号物理值类型
     * 映射到 Python 侧：
     * - double -> float
     * - int64_t -> int
     * - std::array -> numpy.ndarray (uint8_t)
     */
    using SignalValue = std::variant<
        double,
        int64_t,
        std::array<uint8_t, 64> // 对应你提到的 64*uchar 信号 (CAN FD 原始负载或大信号)
        >;

    /**
     * @brief 触发事件类型
     */
    enum class TriggerType
    {
        OnUpdate,   // 只要收到信号就触发
        OnChange,   // 只有值发生物理变化才触发
        OnRise,     // 针对布尔信号的上升沿
        OnFall,     // 针对布尔信号的下降沿
        OnCondition // 满足特定数学条件 (例如 > threshold)
    };

    /**
     * @brief 事件通知结构体
     * 当 C++ 核心层检测到触发条件时，将此对象推入并发队列供 Python 消费
     */
    struct EventNotification
    {
        std::string signal_name;  // 信号名称
        uint32_t msg_id;          // 原始消息 ID
        SignalValue value;        // 转换后的物理值
        uint64_t timestamp_ns;    // 时间戳
        TriggerType trigger_type; // 触发类型
    };

    /**
     * @brief 信号定义元数据 (用于从数据库解析)
     */
    struct SignalDefinition
    {
        std::string name;
        uint32_t start_bit;
        uint32_t length;
        bool is_big_endian;
        bool is_signed;
        double factor;
        double offset;
        double min;
        double max;
        std::string unit;
    };

} // namespace signalux