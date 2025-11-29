#pragma once

#include <string>

namespace signalux {

/**
 * @brief 一个返回问候语的简单函数。
 * @param name 要问候的人的名字。
 * @return std::string 完整的问候语。
 */
std::string get_greeting(const std::string& name);

} // namespace signalux
