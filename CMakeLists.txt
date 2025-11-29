cmake_minimum_required(VERSION 3.25)
project(signalux LANGUAGES CXX)

# --- C++ 标准和 Conan ---
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON) # 对于库很重要

# Conan 工具链已通过 CMAKE_TOOLCHAIN_FILE 在命令行加载，此处无需重复

# --- 查找 Conan 依赖 ---
# CMakeDeps 生成器要求我们为每个包调用 find_package
find_package(fmt REQUIRED)
find_package(spdlog REQUIRED)
find_package(EnTT REQUIRED)

# --- 查找 Python ---
find_package(Python 3.8 REQUIRED COMPONENTS Interpreter Development.Module)

# --- 查找通过 pip 安装的 nanobind (根据官方文档) ---
execute_process(
  COMMAND "${Python_EXECUTABLE}" -m nanobind --cmake_dir
  OUTPUT_STRIP_TRAILING_WHITESPACE OUTPUT_VARIABLE nanobind_ROOT)
find_package(nanobind CONFIG REQUIRED)
if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

# --- 核心 C++ 库 (signalux) ---
# 收集核心库的源文件 (假设在 src/core/ 下)
file(GLOB_RECURSE CORE_SRC_FILES "src/core/*.cpp")

# 定义库 target
add_library(signalux ${CORE_SRC_FILES})
add_library(signalux::signalux ALIAS signalux)

# 设置包含目录
target_include_directories(signalux PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# 为核心库链接 Conan 依赖
target_link_libraries(signalux PUBLIC fmt::fmt spdlog::spdlog EnTT::EnTT)

# --- Python 绑定模块 (_signalux) ---
# 收集绑定代码的源文件 (假设在 src/binding/ 下)
file(GLOB_RECURSE BINDING_SRC_FILES "src/binding/*.cpp")

if(BINDING_SRC_FILES)
    # 使用 nanobind 创建 Python 模块
    nanobind_add_module(_signalux ${BINDING_SRC_FILES})

    # 将 Python 模块链接到我们的核心库
    target_link_libraries(_signalux PRIVATE signalux::signalux)
else()
    message(STATUS "No binding sources found, Python module will not be built.")
endif()

# --- C++ 测试 ---
option(BUILD_TESTS "Build the C++ tests" ON)

if(BUILD_TESTS)
    enable_testing()
    find_package(GTest REQUIRED)
    add_subdirectory(tests)
endif()

# --- Python Packaging Staging ---
# This will trigger the install() commands in python/CMakeLists.txt
# which will place the necessary files into a staging directory.
add_subdirectory(python)
