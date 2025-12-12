# 使用 nanobind 创建 Python 模块
nanobind_add_module(signalux_pyext py_main.cpp)

# 链接核心库 (PRIVATE 依赖)
target_link_libraries(signalux_pyext PRIVATE SignaLux::signalux_core)

# -----------------------------------------------------------------
# 规范化安装规则 (依赖 --prefix 参数)
# -----------------------------------------------------------------

# 1. 安装 Python 扩展模块 (signalux_pyext)
# DESTINATION "." 表示安装到 --prefix 指定的根目录 (即 python/signalux)
install(TARGETS signalux_pyext
    DESTINATION "."
    COMPONENT python
    # 添加 RPATH 确保其能找到同目录下的 libsignalux_core.so
    # $ORIGIN 在 Linux/macOS 下非常关键
    # install(TARGETS) 会自动处理 RPATH，但我们这里设置一个默认值，或者依靠 sh 脚本修复
    # set_target_properties(signalux_pyext PROPERTIES INSTALL_RPATH "$ORIGIN")
)

# 2. 安装 C++ 核心库 (libsignalux_core.so / signalux_core.dll)
# 核心库也必须安装到包的根目录，作为运行时依赖
install(TARGETS signalux_core # 核心库目标名来自 src/core
    DESTINATION "."
    COMPONENT python
    # 强制将动态库安装到目标目录根部
    # ARCHIVE/LIBRARY/RUNTIME 区分 .a/.so/.dll，确保所有动态库类型都在根目录
    ARCHIVE DESTINATION "."
    LIBRARY DESTINATION "."
    RUNTIME DESTINATION "."
)

# 3. 生成并安装 .pyi 存根文件
nanobind_add_stub(
    signalux_pyext_stub
    MODULE signalux_pyext
    # OUTPUT 现在指向一个临时文件，但安装 DESTINATION 为 "."
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/signalux_pyext.pyi" 
    PYTHON_PATH "$<TARGET_FILE_DIR:signalux_pyext>"
    DEPENDS signalux_pyext
)

# 存根文件的安装
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/signalux_pyext.pyi"
    DESTINATION "."
    COMPONENT python
)