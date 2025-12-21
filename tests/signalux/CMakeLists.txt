# --- C++ 核心库测试 ---
file(GLOB_RECURSE CORE_TEST_SRC_FILES "./*.cpp")

if(CORE_TEST_SRC_FILES)
    # 创建测试可执行文件
    add_executable(core_tests ${CORE_TEST_SRC_FILES})

    # 链接 GTest 和我们的核心库
    target_link_libraries(core_tests PRIVATE
        SignaLux::signalux_core
        GTest::gtest_main
    )

    # 将测试添加到 CTest
    include(GoogleTest)
    gtest_discover_tests(core_tests)
endif()
