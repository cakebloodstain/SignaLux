#include <gtest/gtest.h>
#include <signalux/signalux.h>

// 测试 get_greeting 函数的基本功能
TEST(SignaLuxCore, GetGreeting) {
    EXPECT_EQ(signalux::get_greeting("Test"), "Hello, Test!");
    EXPECT_STRNE(signalux::get_greeting("World").c_str(), "Hello, test!");
}
