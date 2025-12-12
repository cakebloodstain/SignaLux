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
PACKAGE_STAGING_DIR="$PYTHON_DIR/signalux"

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
cmake --build "$BUILD_DIR" --target signalux_pyext
cmake --build "$BUILD_DIR" --target signalux_pyext_stub

echo ">>> [5/7] 准备 Python wheel 包内容..."
# 执行 CMake install 步骤以生成 .pyi 文件和其他必要的文件
cmake --install "$BUILD_DIR" --component python

# 创建 Python 包目录
rm -rf "$PACKAGE_STAGING_DIR"
mkdir -p "$PACKAGE_STAGING_DIR"

# 复制编译好的扩展模块到 Python 包目录
# 查找并复制 .so 或 .dll 文件
EXT_FILE=""
CORE_LIB_FILE=""
PYI_FILE=""

# 查找扩展模块文件
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows 系统查找 .pyd 文件
    EXT_FILE=$(find "$BUILD_DIR" -name "signalux_pyext.pyd" | head -n 1)
    CORE_LIB_FILE=$(find "$BUILD_DIR" -name "signalux_core.dll" | head -n 1)
    PYI_FILE=$(find "$BUILD_DIR" -name "signalux_pyext.pyi" | head -n 1)
else
    # Unix/Linux 系统查找 .so 文件
    EXT_FILE=$(find "$BUILD_DIR/lib" -name "signalux_pyext*.so*" | head -n 1)
    CORE_LIB_FILE=$(find "$BUILD_DIR/lib" -name "libsignalux_core.so*" | head -n 1)
    PYI_FILE=$(find "$BUILD_DIR" -name "signalux_pyext.pyi" | head -n 1)
fi

if [ -n "$EXT_FILE" ] && [ -f "$EXT_FILE" ]; then
    cp "$EXT_FILE" "$PACKAGE_STAGING_DIR/"
    echo "已复制扩展模块: $EXT_FILE"
else
    echo "错误：找不到编译好的扩展模块文件！"
    exit 1
fi

if [ -n "$CORE_LIB_FILE" ] && [ -f "$CORE_LIB_FILE" ]; then
    cp "$CORE_LIB_FILE" "$PACKAGE_STAGING_DIR/"
    echo "已复制核心库: $CORE_LIB_FILE"
else
    echo "警告：找不到核心库文件，将继续打包"
fi

if [ -n "$PYI_FILE" ] && [ -f "$PYI_FILE" ]; then
    cp "$PYI_FILE" "$PACKAGE_STAGING_DIR/"
    echo "已复制类型提示文件: $PYI_FILE"
else
    echo "警告：找不到类型提示文件，将继续打包"
fi

# 创建 py.typed 文件
touch "$PACKAGE_STAGING_DIR/py.typed"

echo ">>> [6/7] 使用 Hatch 构建 Python wheel 包..."
# 安装 hatch
python3 -m pip install --upgrade hatch
# 使用 hatch 构建 wheel
cd "$PYTHON_DIR"
python3 -m hatch build
cd ..

echo ">>> [7/7] 安装并测试新构建的 Python wheel 包..."
python3 -m pip uninstall -y "$PACKAGE_NAME" || echo "$PACKAGE_NAME not found, skipping uninstall."
# 找到最新生成的 wheel 文件并安装
WHEEL_FILE=$(find "$PYTHON_DIR/dist" -name "*.whl" | sort -r | head -n 1)
if [ -z "$WHEEL_FILE" ]; then
    echo "错误：找不到构建的 wheel 文件！"
    exit 1
fi
python3 -m pip install "$WHEEL_FILE"

# 运行 Python 测试 (pytest)
pytest tests/python

echo ""
echo "--- 全流程成功完成! ---"
echo "Python wheel 包位于: $PYTHON_DIR/dist"
