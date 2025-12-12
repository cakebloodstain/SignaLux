#!/bin/bash
set -e

# 该脚本自动化了 SignaLux 项目完整的构建-测试-打包-验证生命周期。
# 它遵循 C++/Python 分离的构建哲学，并采用现代 Python 打包最佳实践。

# --- 配置 ---
BUILD_DIR="build"
BUILD_TYPE="Release"
PROJECT_ROOT=$(dirname "$0")
PYTHON_DIR="$PROJECT_ROOT/python"
PACKAGE_NAME="signalux"
INSTALL_PREFIX="$PYTHON_DIR/$PACKAGE_NAME" # CMake 安装的最终目录

# --- 前置检查 ---
# 检查 patchelf 是否存在，Linux RPATH 修复依赖此工具
if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "win32" ]]; then
    if ! command -v patchelf &> /dev/null; then
        echo "⚠️ 警告: 未找到 patchelf 工具。"
        echo "Linux/macOS 环境下，核心库 (libsignalux_core.so) 运行时可能找不到！"
        echo "请安装：sudo apt-get install patchelf"
    fi
fi

# --- Main Logic ---
cd "$PROJECT_ROOT"

echo ">>> [1/7] 使用 Conan 安装 C++ 依赖..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
conan install . --build=missing -s build_type="$BUILD_TYPE" -of="$BUILD_DIR"

echo ">>> [2/7] 配置并构建纯 C++ 核心库..."
CMAKE_TOOLCHAIN_FILE="$BUILD_DIR/conan_toolchain.cmake"
cmake -B "$BUILD_DIR" -S . \
    -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_TESTS=ON

# 构建 C++ 核心库和测试
cmake --build "$BUILD_DIR" --target signalux_core core_tests

echo ">>> [3/7] 运行 C++ 测试..."
cd "$BUILD_DIR"
ctest --output-on-failure
cd ..

echo ">>> [4/7] 构建 Python 扩展模块 (so/pyd) 及类型存根 (pyi)..."
cmake --build "$BUILD_DIR" --target signalux_pyext
cmake --build "$BUILD_DIR" --target signalux_pyext_stub

echo ">>> [5/7] 规范安装到 Python 包目录并修复依赖链接..."

# 1. 确保目标目录存在 (不删除 __init__.py 等源码文件)
mkdir -p "$INSTALL_PREFIX"

# 2. 清理旧的二进制产物 (防止不同 Python 版本残留)
echo "正在清理旧的二进制产物..."
find "$INSTALL_PREFIX" -type f \( -name "signalux_pyext*.so*" -o -name "signalux_pyext*.pyd" -o -name "libsignalux_core*.so*" -o -name "signalux_core*.dll" \) -delete

# 3. **核心步骤**：使用 CMake install 将所有构建产物安装到目标目录
# 依赖于 CMakeLists.txt 中对 signalux_core, signalux_pyext, pyi 的 install(COMPONENT python) 配置
echo "使用 CMake 安装新文件到 $INSTALL_PREFIX ..."
cmake --install "$BUILD_DIR" \
      --component python \
      --prefix "$INSTALL_PREFIX" \
      --strip

# 4. 确保 py.typed 存在 (标记包支持类型提示)
touch "$INSTALL_PREFIX/py.typed"

# 5. **Linux/macOS 关键修复**：设置 RPATH ($ORIGIN) 确保运行时能找到 libsignalux_core.so
if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "win32" ]]; then
    if command -v patchelf &> /dev/null; then
        echo "正在设置 RPATH (\$ORIGIN) 修复依赖链接..."
        # 确保 patchelf 命令作用于正确的文件，并且在文件安装到 $INSTALL_PREFIX 后
        find "$INSTALL_PREFIX" -name "*.so" -exec patchelf --set-rpath '$ORIGIN' --force-rpath {} \;
    else
        echo "致命错误：未找到 patchelf。RPATH 修复失败！"
        exit 1 # 强制退出，因为没有 patchelf 就无法解决依赖问题
    fi
fi

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