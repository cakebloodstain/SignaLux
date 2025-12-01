cmake_minimum_required(VERSION 3.25)
project(SignaLux LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# --- 全局选项 ---
option(BUILD_PYTHON "Build Python bindings" ON)
option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(BUILD_TESTS "Build the C++ tests" ON)

# --- C++ 标准和 Conan ---
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# --- 查找 Conan 依赖 ---
find_package(spdlog REQUIRED)
find_package(EnTT REQUIRED)

# --- 添加核心库 (无条件) ---
add_subdirectory(src/core)

# --- 添加 Python 绑定 (有条件) ---
if(BUILD_PYTHON)
    message(STATUS "Python binding build is enabled.")
    # 查找 Python
    find_package(Python 3.8 REQUIRED COMPONENTS Interpreter Development.Module)

    # 查找 nanobind
    execute_process(
      COMMAND "${Python_EXECUTABLE}" -m nanobind --cmake_dir
      OUTPUT_STRIP_TRAILING_WHITESPACE OUTPUT_VARIABLE nanobind_ROOT)
    find_package(nanobind CONFIG REQUIRED)
    if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
      set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
      set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
    endif()

    add_subdirectory(src/binding)
else()
    message(STATUS "Python binding build is disabled.")
endif()

# --- C++ 测试 ---
if(BUILD_TESTS)
    enable_testing()
    find_package(GTest REQUIRED)
    add_subdirectory(tests)
endif()
