#!/bin/bash
set -e

# 该脚本自动化了 SignaLux 项目完整的构建-测试-打包-验证生命周期。
# 它遵循 C++/Python 分离的构建哲学。

# --- 配置 ---
BUILD_DIR="build"
BUILD_TYPE="Release"
PROJECT_ROOT=$(dirname "$0")
PYTHON_DIR="$PROJECT_ROOT/python"
PACKAGE_NAME="signalux"

# --- Main Logic ---
cd "$PROJECT_ROOT"

echo ">>> [1/7] 使用 Conan 安装 C++ 依赖..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
conan install . --build=missing -s build_type="$BUILD_TYPE" -of="$BUILD_DIR"

echo ">>> [2/7] 配置并构建纯 C++ 核心库..."
# 使用 Conan 生成的工具链来配置 CMake
CMAKE_TOOLCHAIN_FILE="$BUILD_DIR/conan_toolchain.cmake"
cmake -B "$BUILD_DIR" -S . \
    -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_TESTS=ON

# 只构建 C++ 核心库和测试，不构建 Python 绑定
cmake --build "$BUILD_DIR" --target signalux_core core_tests

echo ">>> [3/7] 运行 C++ 测试..."
cd "$BUILD_DIR"
ctest --output-on-failure
cd ..

echo ">>> [4/7] 构建 Python 库pyd/so..."
cmake --build "$BUILD_DIR" --target signalux_ext

echo ">>> [5/7] 将构建 Python 绑定并封装 Wheel..."
# 现在，我们调用 Python 的构建前端。
# scikit-build-core 会再次调用 CMake，但这很快，因为它已经配置过。
# 它将把已经构建好的 signalux_ext 和 signalux_core 一起打包。
python3 -m pip install --upgrade build
python3 -m build "$PYTHON_DIR"

echo ">>> [6/7] 安装新构建的 Python wheel 包..."
python3 -m pip uninstall -y "$PACKAGE_NAME" || echo "$PACKAGE_NAME not found, skipping uninstall."
# 找到最新生成的 wheel 文件并安装
WHEEL_FILE=$(find "$PYTHON_DIR/dist" -name "*.whl" | sort -r | head -n 1)
if [ -z "$WHEEL_FILE" ]; then
    echo "错误：找不到构建的 wheel 文件！"
    exit 1
fi
python3 -m pip install "$WHEEL_FILE"

echo ">>> [7/7] 运行 Python 测试 (pytest)..."
# pytest 会自动发现并运行 tests/python 目录下的测试
pytest tests/python

echo ""
echo "--- 全流程成功完成! ---"
echo "Python wheel 包位于: $PYTHON_DIR/dist"
