# 定义核心库
add_library(signalux_core signalux.cpp)
add_library(SignaLux::signalux_core ALIAS signalux_core)

# 设置 C++ 标准
target_compile_features(signalux_core PUBLIC cxx_std_20)

# 设置包含路径 (PUBLIC 使得依赖它的库也能看到头文件)
target_include_directories(signalux_core
    PUBLIC
        ${CMAKE_SOURCE_DIR}/include
        $&lt;INSTALL_INTERFACE:include&gt;
)

# 链接纯 C++ 依赖
target_link_libraries(signalux_core PUBLIC
    spdlog::spdlog
    EnTT::EnTT
)

# 安装规则 (用于 C++ SDK 发布)
install(TARGETS signalux_core
    EXPORT SignaLuxTargets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin # Windows DLL 放在 bin
)

install(DIRECTORY ${CMAKE_SOURCE_DIR}/include/
    DESTINATION include
)
