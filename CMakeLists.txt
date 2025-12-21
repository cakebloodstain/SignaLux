cmake_minimum_required(VERSION 3.25)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
project(SignaLux LANGUAGES CXX)

# ------------------------------------------------------------
# 全局输出路径配置
# ------------------------------------------------------------
# 保持您原有的配置，用于控制构建的中间产物位置。
# (注意：这不影响最终的安装路径，安装路径由 cmake --install --prefix 控制)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

if(CMAKE_CONFIGURATION_TYPES)
    # ... (保持原有的多配置类型输出目录设置)
    foreach(CONFIG ${CMAKE_CONFIGURATION_TYPES})
        string(TOUPPER "${CONFIG}" CONFIG_UPPER)
        set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG_UPPER} "${CMAKE_BINARY_DIR}/bin")
        set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CONFIG_UPPER} "${CMAKE_BINARY_DIR}/lib")
        set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_UPPER} "${CMAKE_BINARY_DIR}/lib")
    endforeach()
endif()

# ------------------------------------------------------------
# 全局选项
# ------------------------------------------------------------
option(BUILD_PYTHON "Build Python bindings" ON)
option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(BUILD_TESTS "Build the C++ tests" ON)

# ------------------------------------------------------------
# C++ 标准和 Conan
# ------------------------------------------------------------
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# --- 查找 Conan 依赖 ---
find_package(spdlog REQUIRED)
find_package(EnTT REQUIRED)

# ------------------------------------------------------------
# ✨ 优化点 1: Manylinux ABI 兼容性配置（条件静态链接）
# ------------------------------------------------------------
# 目标：解决 Linux 环境下 GLIBCXX 版本冲突问题 (例如 Conda 环境)。
# 仅在启用 Python 绑定，且目标系统不是 Windows 或 macOS 时应用。
if(BUILD_PYTHON AND NOT WIN32 AND NOT APPLE)
    message(STATUS "ABI FIX: Forcing static linking of libstdc++ and libgcc for Python/Manylinux compatibility.")
    
    # 将此标志添加到共享库和可执行文件的链接器标志中。
    # 这会影响后续所有使用 add_library/add_executable 的目标。
    # 这样，核心库 (sign) 和扩展模块 (binding) 都会静态链接 C++ 运行时。
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -static-libgcc -static-libstdc++")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libgcc -static-libstdc++")
endif()

# ------------------------------------------------------------
# 添加核心库 (无条件)
# ------------------------------------------------------------
add_subdirectory(src/signalux)

# ------------------------------------------------------------
# Python 绑定 (有条件)
# ------------------------------------------------------------
if(BUILD_PYTHON)
    message(STATUS "Python binding build is enabled.")

    # 查找 Python
    find_package(Python 3.8 REQUIRED COMPONENTS Interpreter Development.Module)

    # 查找 nanobind
    execute_process(
      COMMAND "${Python_EXECUTABLE}" -m nanobind --cmake_dir
      OUTPUT_STRIP_TRAILING_WHITESPACE OUTPUT_VARIABLE nanobind_ROOT)
    find_package(nanobind CONFIG REQUIRED)

    # 强制默认构建类型 (保持不变)
    if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
      set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
      set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
    endif()

    add_subdirectory(src/binding)
else()
    message(STATUS "Python binding build is disabled.")
endif()

# ------------------------------------------------------------
# C++ 测试
# ------------------------------------------------------------
if(BUILD_TESTS)
    enable_testing()
    find_package(GTest REQUIRED)
    add_subdirectory(tests/signalux)
endif()