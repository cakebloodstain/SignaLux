# --- Python Staging Area ---
# 定义一个临时安装目录，用于存放所有需要打包到 wheel 的文件。
# 这允许我们将 C++ 构建与 Python 打包完全分离。
if(NOT DEFINED ENV{PYTHON_STAGING_DIR})
    set(PYTHON_STAGING_DIR "${PROJECT_BINARY_DIR}/python_staging")
endif()

message(STATUS "Python staging directory: ${PYTHON_STAGING_DIR}")

# --- 安装和存根生成 ---
set(PYTHON_PACKAGE_DIR "${PYTHON_STAGING_DIR}/signalux")

# 将 _signalux 模块安装到临时暂存区的包目录中
install(TARGETS _signalux DESTINATION "${PYTHON_PACKAGE_DIR}")

# 在构建时为 _signalux 模块生成 .pyi 存根文件
nanobind_add_stub(
    _signalux_stub
    MODULE _signalux
    OUTPUT "${PYTHON_PACKAGE_DIR}/_signalux.pyi"
    PYTHON_PATH "$<TARGET_FILE_DIR:_signalux>"
    DEPENDS _signalux
)

# 创建并安装 py.typed 文件到临时暂存区
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/py.typed" "")
install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/py.typed"
    DESTINATION "${PYTHON_PACKAGE_DIR}"
)
