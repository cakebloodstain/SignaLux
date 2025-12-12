# 使用 nanobind 创建 Python 模块
# 注意：模块名通常建议加前缀或与包名区分，这里设为 signalux_pyext
nanobind_add_module(signalux_pyext py_main.cpp)

# 链接核心库 (PRIVATE 依赖，核心库不该知道绑定的存在)
target_link_libraries(signalux_pyext PRIVATE SignaLux::signalux_core)

# --- Python Packaging Staging ---
# 这部分逻辑从旧的 python/CMakeLists.txt 移动而来
if(NOT DEFINED ENV{PYTHON_STAGING_DIR})
    set(PYTHON_STAGING_DIR "${PROJECT_BINARY_DIR}/python_staging")
endif()
set(PYTHON_PACKAGE_DIR "${PYTHON_STAGING_DIR}/signalux")

# 将构建好的模块和核心库都安装到 Python 包目录内
install(TARGETS signalux_pyext signalux_core DESTINATION "${PYTHON_PACKAGE_DIR}")

# 在构建时为模块生成 .pyi 存根文件
nanobind_add_stub(
    signalux_pyext_stub
    MODULE signalux_pyext
    OUTPUT "${PYTHON_PACKAGE_DIR}/signalux_pyext.pyi"
    PYTHON_PATH "$<TARGET_FILE_DIR:signalux_pyext>"
    DEPENDS signalux_pyext
)

# 创建并安装 py.typed 文件
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/py.typed" "")
install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/py.typed"
    DESTINATION "${PYTHON_PACKAGE_DIR}"
)
