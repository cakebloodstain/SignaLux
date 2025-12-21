#pragma once

#include <variant>
#include <string>
#include <vector>
#include <cstdint>
#include <span>
#include <chrono>

namespace signalux
{

    /**
     * @brief 信号原始类型枚举
     * 对应 Python 侧的 NumPy dtype 映射
     */
    enum class RawType : uint8_t
    {
        None = 0,
        Int32,
        Int64,
        Uint32,
        Uint64,
        Float32,
        Float64,
        Boolean,
        String,
        Bytes,  // 用于存储 Proto 原始序列化数据
        Complex // 预留给复杂结构
    };

    /**
     * @brief 统一值容器 (The "Value" in SignalPoint)
     * 使用 std::variant 保证类型安全且高性能
     */
    using VariantValue = std::variant<
        std::monostate,
        int32_t, int64_t, uint32_t, uint64_t,
        float, double,
        bool,
        std::string,
        std::vector<uint8_t> // 支撑非标准/大负载数据
        >;

    /**
     * @brief 信号点 (Signal Sample)
     * 核心高性能存储单元
     */
    struct SignalSample
    {
        uint64_t timestamp_ns; // 硬件/系统高精度时间戳
        VariantValue value;    // 物理值或解析后的值
        uint8_t status;        // 信号质量位 (0: Valid, 1: Invalid, 2: Timeout)

        // C++20 默认比较运算符
        // auto operator<=>(const SignalSample &) const = default;
    };

    /**
     * @brief 报文元数据 (Message Metadata)
     */
    struct MessageInfo
    {
        uint32_t id;
        uint8_t dlc;
        uint32_t flags; // CAN/CANFD/Remote Frame 标志
        std::chrono::nanoseconds receive_time;
    };

} // namespace signalux