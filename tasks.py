"""
SignaLux 构建任务脚本 (基于 PyInvoke)
支持平台: Windows, Linux
功能: 自动化 Conan 依赖管理、CMake 构建、RPATH 修复、Wheel 打包及测试。
"""

import os
import sys
import shutil
import platform
import glob
from pathlib import Path
from invoke import task, Context, Exit

# 获取当前运行 invoke 的 Python 解释器绝对路径
# 这保证了 CMake、Hatch 和 Pip 都使用同一个 Python 环境 (例如 conda env)
PYTHON = sys.executable

# --- 配置常量 ---
PROJECT_ROOT = Path(__file__).parent.resolve()
BUILD_DIR = PROJECT_ROOT / "build"
PYTHON_DIR = PROJECT_ROOT / "python"
PACKAGE_NAME = "signalux"
# CMake install 的目标路径 (直接安装到 python 包源码目录中以便打包)
INSTALL_PREFIX = PYTHON_DIR / PACKAGE_NAME
DIST_DIR = PYTHON_DIR / "dist"

# --- 辅助函数 ---


def is_windows():
    return platform.system() == "Windows"


def is_linux():
    return platform.system() == "Linux"


def print_header(msg):
    print(f"\n{'='*60}\n>>> {msg}\n{'='*60}")


def clean_dir(path: Path):
    """安全地清理目录"""
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


# --- 任务定义 ---


@task
def check_env(c):
    """[Step 0] 检查构建环境依赖 (Conan, CMake, Patchelf, etc.)"""
    print_header(f"检查环境依赖 (使用 Python: {PYTHON})")

    required_cmds = ["conan", "cmake"]
    if is_linux():
        required_cmds.append("patchelf")

    for cmd in required_cmds:
        if shutil.which(cmd) is None:
            print(f"❌ 错误: 未找到命令 '{cmd}'")
            if cmd == "patchelf" and is_linux():
                print(
                    "   提示: 请运行 'sudo apt-get install patchelf' 或 'brew install patchelf'"
                )
            raise Exit(code=1)

    # 检查 Python 库 hatch 是否安装 (使用当前 Python 环境)
    result = c.run(f'"{PYTHON}" -m hatch --version', warn=True, hide=True)
    if result.failed:
        print("⚠️ 未检测到 Hatch，正在安装...")
        c.run(f'"{PYTHON}" -m pip install hatch')

    print("✅ 环境检查通过")


@task
def clean(c):
    """清理构建产生的临时文件"""
    print_header("清理构建目录")
    if BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
        print(f"Removed: {BUILD_DIR}")
    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)
        print(f"Removed: {DIST_DIR}")

    # 清理 Python 包目录下的二进制残留
    extensions = ["*.so", "*.pyd", "*.dll", "*.dylib"]
    for ext in extensions:
        for f in INSTALL_PREFIX.rglob(ext):
            f.unlink()
            print(f"Removed artifact: {f}")


@task(pre=[check_env])
def install_deps(c, build_type="Release"):
    """[Step 1] 使用 Conan 2 安装 C++ 依赖"""
    print_header(f"Conan 安装依赖 ({build_type})")

    # 确保构建目录存在
    BUILD_DIR.mkdir(exist_ok=True)

    # Conan 2 推荐使用 -of (output folder)
    cmd = (
        f"conan install . "
        f"--build=missing "
        f"-s build_type={build_type} "
        f"-of={BUILD_DIR}"
    )
    c.run(cmd)


@task(pre=[check_env])
def build_cpp(c, build_type="Release"):
    """[Step 2-4] 配置 CMake 并构建 C++ 核心库与扩展"""
    print_header(f"CMake 配置与构建 ({build_type})")

    # 1. CMake Configure
    # Conan 2 生成的 toolchain 路径
    toolchain_path = BUILD_DIR / "conan_toolchain.cmake"

    # 获取 Python 根目录 (miniconda 根目录)
    # sys.executable 通常是 .../bin/python
    # 我们需要 .../ (即 prefix)
    python_root = Path(sys.executable).parent.parent

    # 关键修改：
    # 1. 显式指定 Python_ROOT_DIR，帮助 CMake 在第一次运行时就能定位 include/libs
    # 2. 设置 Python_FIND_STRATEGY=LOCATION 优先使用我们指定的路径
    config_cmd = (
        f"cmake -B {BUILD_DIR} -S . "
        f"-DCMAKE_TOOLCHAIN_FILE={toolchain_path} "
        f"-DCMAKE_BUILD_TYPE={build_type} "
        f"-DBUILD_TESTS=ON "
        f'-DPython_EXECUTABLE="{PYTHON}" '
        f'-DPython_ROOT_DIR="{python_root}" '
        f"-DPython_FIND_STRATEGY=LOCATION "
        f"-DPython_FIND_REGISTRY=NEVER "  # Windows 上避免注册表干扰，Linux 上无害
    )

    print(f"Configuring with: {config_cmd}")

    # 首次运行如果失败，尝试清理缓存重试 (虽然加上面参数后应该能一次成功)
    try:
        c.run(config_cmd)
    except Exception:
        print("⚠️ 第一次配置失败，尝试清理缓存后重试...")
        cache_file = BUILD_DIR / "CMakeCache.txt"
        if cache_file.exists():
            cache_file.unlink()
        c.run(config_cmd)

    # 2. CMake Build ... (保持不变)
    targets = ["signalux_core", "signalux_pyext", "signalux_pyext_stub", "core_tests"]
    target_str = " ".join(targets)

    build_cmd = f"cmake --build {BUILD_DIR} --config {build_type} --target {target_str}"
    if is_windows():
        build_cmd += " -- /m"
    else:
        build_cmd += f" -j {os.cpu_count()}"

    c.run(build_cmd)


@task
def test_cpp(c, build_type="Release"):
    """[Step 3b] 运行 C++ 单元测试 (CTest)"""
    print_header("运行 C++ 测试")
    with c.cd(BUILD_DIR):
        # --output-on-failure: 测试失败时输出日志
        # -C: 指定配置 (主要针对 Windows MSVC)
        c.run(f"ctest --output-on-failure -C {build_type}")


@task
def install_artifacts(c, build_type="Release"):
    """[Step 5] 安装二进制文件到 Python 源码目录并修复 RPATH"""
    print_header("安装 Artifacts 到 Python 目录")

    # 1. 清理旧产物 (防止版本混淆)
    extensions = ["*.so*", "*.pyd", "*.dll"]
    for ext in extensions:
        for f in INSTALL_PREFIX.glob(ext):
            f.unlink()

    # 2. CMake Install
    # 使用 --component python 确保只安装 Python 相关的库
    # --strip 减小二进制体积
    cmd = (
        f"cmake --install {BUILD_DIR} "
        f"--config {build_type} "
        f"--component python "
        f"--prefix {INSTALL_PREFIX} "
        "--strip"
    )
    c.run(cmd)

    # 3. 创建 py.typed (PEP 561)
    (INSTALL_PREFIX / "py.typed").touch()

    # 4. RPATH 修复 (Linux 专属)
    if is_linux():
        print("🔧 正在修复 Linux RPATH...")
        so_files = list(INSTALL_PREFIX.glob("*.so"))
        for so in so_files:
            # $ORIGIN 代表 .so 文件所在的当前路径
            c.run(f"patchelf --set-rpath '$ORIGIN' {so}")


@task
def build_wheel(c):
    """[Step 6] 使用 Hatch 构建 Python Wheel 包"""
    print_header("构建 Python Wheel")

    # 清理旧的 dist
    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)

    with c.cd(PYTHON_DIR):
        # 使用当前 Python 环境执行 hatch
        c.run(f'"{PYTHON}" -m hatch env prune', warn=True)
        c.run(f'"{PYTHON}" -m hatch build')


@task
def install_wheel(c):
    """[Step 7] 卸载旧包并安装新构建的 Wheel"""
    print_header("安装新构建的 Wheel")

    # 卸载旧版 (使用当前 Python)
    c.run(f'"{PYTHON}" -m pip uninstall -y {PACKAGE_NAME}', warn=True)

    # 查找最新的 wheel 文件
    wheels = list(DIST_DIR.glob("*.whl"))
    if not wheels:
        print("❌ 错误: dist 目录下未找到 Wheel 文件")
        raise Exit(code=1)

    # 按修改时间排序，取最新的
    latest_wheel = sorted(wheels, key=lambda f: f.stat().st_mtime, reverse=True)[0]
    print(f"安装: {latest_wheel.name}")

    c.run(f'"{PYTHON}" -m pip install {latest_wheel}')


@task
def test_python(c):
    """[Step 8] 运行 Python 集成测试 (Pytest)"""
    print_header("运行 Python 测试 (Pytest)")

    # 指向根目录下的 tests 文件夹
    test_dir = PROJECT_ROOT / "tests"
    if not test_dir.exists():
        print("⚠️ Warning: tests 目录不存在")
        return

    # 使用当前 Python 运行 pytest
    # -v: 详细输出
    # -s: 允许 stdout 输出 (调试打印)
    c.run(f'"{PYTHON}" -m pytest {test_dir} -v -s')


@task(default=True)
def build_all(c, build_type="Release"):
    """执行完整的 构建-打包-测试 流程"""
    check_env(c)
    install_deps(c, build_type)
    build_cpp(c, build_type)
    test_cpp(c, build_type)
    install_artifacts(c, build_type)
    build_wheel(c)
    install_wheel(c)
    test_python(c)
    print_header("🎉 全流程构建成功！")
