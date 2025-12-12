#!/bin/bash
set -e

# 核心思路：让 cibuildwheel 负责容器、环境、版本和循环。
# 我们只需要在宿主机器上运行它。

echo ">>> [1] 安装 cibuildwheel 和 Hatch..."
# cibuildwheel 需要在宿主（Host）机器上安装
pip install cibuildwheel hatch

# --- 配置 cibuildwheel 环境变量 ---
# 1. 告诉 cibuildwheel 使用 Hatch 来构建 (而不是默认的 setup.py)
export CIBW_BUILD_FRONTEND=hatch
# 2. 指定要构建的 Python 版本 (例如只构建 Python 3.10 到 3.12)
export CIBW_BUILD="cp310-* cp311-* cp312-*"
# 3. 在构建前，告诉 cibuildwheel 在容器内安装构建依赖
export CIBW_BEFORE_BUILD="pip install conan cmake"
# 4. 指定最终输出目录
export CIBW_WHEEL_DIR="python/dist"
# 5. 可选：跳过 macOS/Windows (因为这是一个 Linux CI 脚本)
export CIBW_SKIP="*-macosx_* *-win_*"

echo ">>> [2] 启动 Manylinux 容器并执行自动化构建..."
# cibuildwheel 会自动选择 Manylinux 镜像并执行多版本构建
cibuildwheel --platform linux

echo ">>> [3] Manylinux 构建完成，请检查 ./python/dist 目录下的 wheels 文件。"

# 备注：您需要确保您的 build_wheel.sh 逻辑现在被转移到 CMake/Hatch 配置中，
# 或作为一个子命令在 CIBW_BEFORE_BUILD 中调用。