#!/bin/bash
set -e

# 该脚本自动化了 SignaLux 项目完整的构建-测试-打包-验证生命周期。
# 它遵循 C++/Python 分离的构建哲学，并采用现代 Python 打包最佳实践。
# 脚本应从项目根目录运行，或调整 PROJECT_ROOT 以确保正确性。

# --- 配置 ---
# 脚本文件位于 PROJECT_ROOT/scripts，因此使用 /../ 获取项目根目录
PROJECT_ROOT=$(dirname "$0")/..
BUILD_DIR="$PROJECT_ROOT/build"
BUILD_TYPE="Release"
PYTHON_DIR="$PROJECT_ROOT/python"
PACKAGE_NAME="signalux"
# CMake 安装到 Python 包目录的临时/最终路径
INSTALL_PREFIX="$PYTHON_DIR/$PACKAGE_NAME" 
# Wheel 包的产物目录
DIST_DIR="$PYTHON_DIR/dist"

# --- 实用函数 ---
# 检查依赖并提示用户
check_dependency() {
    local dep_name=$1
    local install_hint=$2
    if ! command -v "$dep_name" &> /dev/null; then
        echo "⚠️ 警告: 未找到 $dep_name 工具。"
        echo "$install_hint"
        return 1
    fi
    return 0
}

# --- 前置检查 ---
echo ">>> [0/8] 执行前置检查..."
# 检查 patchelf (Linux/macOS RPATH 修复依赖)
if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "win32" ]]; then
    if ! check_dependency "patchelf" "Linux/macOS 环境下，核心库运行时可能找不到！请安装：sudo apt-get install patchelf 或 brew install patchelf"; then
        # 强制退出，因为没有 patchelf 就无法解决 Linux/macOS 的动态链接依赖问题
        exit 1
    fi
fi

# 检查 conan, cmake, python3, hatch
check_dependency "conan" "请安装 Conan: pip install conan"
check_dependency "cmake" "请安装 CMake"
check_dependency "python3" "请确保 python3 可用"
python3 -m pip install --upgrade hatch || { echo "⚠️ 警告: Hatch 安装失败。正在尝试再次安装..."; python3 -m pip install --upgrade hatch; }

# --- Main Logic ---
cd "$PROJECT_ROOT"
echo "--- 项目根目录: $PWD ---"

echo ">>> [1/8] 使用 Conan 安装 C++ 依赖..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
# 使用 --lockfile 保证构建一致性
conan install . --build=missing -s build_type="$BUILD_TYPE" -of="$BUILD_DIR"

echo ">>> [2/8] 配置并构建纯 C++ 核心库..."
CMAKE_TOOLCHAIN_FILE="$BUILD_DIR/conan_toolchain.cmake"
cmake -B "$BUILD_DIR" -S . \
    -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_TESTS=ON

# 构建 C++ 核心库和测试
cmake --build "$BUILD_DIR" --target signalux_core core_tests

echo ">>> [3/8] 运行 C++ 测试..."
# 确保 CTest 在构建目录内执行
(cd "$BUILD_DIR" && ctest --output-on-failure)

echo ">>> [4/8] 构建 Python 扩展模块 (so/pyd) 及类型存根 (pyi)..."
cmake --build "$BUILD_DIR" --target signalux_pyext
cmake --build "$BUILD_DIR" --target signalux_pyext_stub

echo ">>> [5/8] 规范安装到 Python 包目录并修复依赖链接..."

# 1. 确保目标目录存在
mkdir -p "$INSTALL_PREFIX"

# 2. 清理旧的二进制产物 (防止不同构建的残留)
echo "正在清理旧的二进制产物..."
# 仅删除特定二进制文件，保留 __init__.py 等源码
find "$INSTALL_PREFIX" -type f \( -name "signalux_pyext*.so*" -o -name "signalux_pyext*.pyd" -o -name "libsignalux_core*.so*" -o -name "signalux_core*.dll" \) -delete

# 3. **核心步骤**：使用 CMake install 将所有构建产物安装到目标目录
echo "使用 CMake 安装新文件到 $INSTALL_PREFIX ..."
cmake --install "$BUILD_DIR" \
      --component python \
      --prefix "$INSTALL_PREFIX" \
      --strip

# 4. 确保 py.typed 存在
touch "$INSTALL_PREFIX/py.typed"

# 5. **Linux/macOS 关键修复**：设置 RPATH (\$ORIGIN) 确保运行时能找到 libsignalux_core.so
if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "win32" ]]; then
    echo "正在设置 RPATH (\$ORIGIN) 修复依赖链接..."
    # 查找所有安装的 .so 文件并修复 RPATH
    find "$INSTALL_PREFIX" -name "*.so" -exec patchelf --set-rpath '$ORIGIN' --force-rpath {} \;
fi

echo ">>> [6/8] 使用 Hatch 构建 Python wheel 包..."
# 清理旧的 dist 目录
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
# 进入 Python 目录执行构建
(cd "$PYTHON_DIR" && python3 -m hatch build)

echo ">>> [7/8] 安装新构建的 Python wheel 包..."
python3 -m pip uninstall -y "$PACKAGE_NAME" || echo "INFO: $PACKAGE_NAME 未安装，跳过卸载。"
# 找到最新生成的 wheel 文件并安装 (在 dist 目录中)
WHEEL_FILE=$(find "$DIST_DIR" -name "*.whl" | sort -r | head -n 1)
if [ -z "$WHEEL_FILE" ]; then
    echo "错误：找不到构建的 wheel 文件！请检查 Hatch 构建是否成功。"
    exit 1
fi
echo "正在安装: $WHEEL_FILE"
python3 -m pip install "$WHEEL_FILE"

echo ">>> [8/8] 运行 Python 测试..."
# 使用 pytest 运行 Python 目录下的测试
pytest "$PROJECT_ROOT/tests"

echo ""
echo "--- ✅ 全流程成功完成! ---"
echo "Python wheel 包位于: $DIST_DIR"