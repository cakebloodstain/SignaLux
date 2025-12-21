#pragma once
#include <variant>
#include <cstdint>
#include <string>
#include <vector>

namespace signalux
{

    // 扩展类型以支持 CAN/CANFD 及 Proto 动态类型
    using SignalValue = std::variant<
        std::monostate,
        int64_t,
        double,
        bool,
        std::string,
        std::vector<uint8_t>>;

    // 报文基础结构
    struct RawFrame
    {
        uint32_t id;
        uint8_t dlc;
        std::vector<uint8_t> data;
        uint64_t timestamp_ns;
        uint32_t channel;
    };

} // namespace signalux