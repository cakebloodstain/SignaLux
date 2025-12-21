# 定义核心库
add_library(signalux_core signalux.cpp)
add_library(SignaLux::signalux_core ALIAS signalux_core)

# 设置 C++ 标准
target_compile_features(signalux_core PUBLIC cxx_std_20)

# 设置包含路径 (PUBLIC 使得依赖它的库也能看到头文件)
target_include_directories(signalux_core 
    PUBLIC 
        # 仅在构建时使用的路径
        $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
        # 仅在被安装后使用的路径
        $<INSTALL_INTERFACE:include>
)

# 链接纯 C++ 依赖
target_link_libraries(signalux_core 
    PUBLIC
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
install(DIRECTORY "${PROJECT_SOURCE_DIR}/include/signalux"
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    FILES_MATCHING PATTERN "*.h"
)