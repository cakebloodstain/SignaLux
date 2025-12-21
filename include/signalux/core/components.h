#pragma once
#include "types.h"
#include <entt/entt.hpp>
#include <exprtk.hpp>

namespace signalux::components
{

    // 1. 物理属性组件
    struct Physics
    {
        double scale{1.0};
        double offset{0.0};
        double min_value{0.0};
        double max_value{0.0};
        std::string unit; // 结合 mp-units 使用
    };

    // 2. 数据存储组件 (当前值)
    struct CurrentValue
    {
        SignalValue value;
        uint64_t last_update_ns;
    };

    // 3. 总线映射组件 (定义该信号属于哪个报文)
    struct BusMapping
    {
        uint32_t message_id;
        uint16_t start_bit;
        uint16_t bit_length;
        bool is_big_endian;
    };

    // 4. 触发器组件
    struct Trigger
    {
        std::string expression_str;
        std::shared_ptr<exprtk::expression<double>> compiled_expr;
        bool last_trigger_state{false};
    };

    // 5. 回调组件 (用于 Python/C++ 层的事件订阅)
    struct OnChangeCallback
    {
        std::function<void(entt::entity, const SignalValue &)> func;
    };

} // namespace signalux::components