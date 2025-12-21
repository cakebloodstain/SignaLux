import os
import sys
import shutil
import platform
from pathlib import Path
from invoke import task, Exit

PYTHON = sys.executable

PROJECT_ROOT = Path(__file__).parent.resolve()
BUILD_ROOT = PROJECT_ROOT / "build"

PYTHON_DIR = PROJECT_ROOT / "python"
PACKAGE_NAME = "signalux"
INSTALL_PREFIX = PYTHON_DIR / PACKAGE_NAME
DIST_DIR = PYTHON_DIR / "dist"


def is_windows():
    return platform.system() == "Windows"


def is_linux():
    return platform.system() == "Linux"


def print_header(msg):
    print(f"\n{'=' * 60}\n>>> {msg}\n{'=' * 60}")


def get_run_kwargs():
    kwargs = {"pty": not is_windows(), "echo": True}
    env = os.environ.copy()
    env["CLICOLOR_FORCE"] = "1"
    env["CONAN_COLOR_DISPLAY"] = "1"
    env["PY_COLORS"] = "1"
    kwargs["env"] = env
    return kwargs


@task
def check_env(c):
    print_header(f"检查环境 (Python: {PYTHON})")

    for cmd in ("conan", "cmake"):
        if shutil.which(cmd) is None:
            raise Exit(f"未找到命令: {cmd}", code=1)

    if is_linux() and shutil.which("patchelf") is None:
        raise Exit("Linux 需要 patchelf", code=1)

    result = c.run(f'"{PYTHON}" -m hatch --version', warn=True, hide=True)
    if result.failed:
        c.run(f'"{PYTHON}" -m pip install hatch', **get_run_kwargs())


@task(pre=[check_env])
def clean(c):
    print_header("清理构建产物")

    if BUILD_ROOT.exists():
        shutil.rmtree(BUILD_ROOT)

    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)

    for ext in ("*.so*", "*.pyd", "*.dll", "*.dylib"):
        for f in INSTALL_PREFIX.rglob(ext):
            f.unlink()


@task(pre=[check_env])
def install_deps(c, build_type="Release"):
    print_header(f"Conan install ({build_type})")

    BUILD_ROOT.mkdir(parents=True, exist_ok=True)

    c.run(
        f"conan install . "
        f"--build=missing "
        f"-s build_type={build_type} "
        f"-o signalux/*:build_tests=True ",
        **get_run_kwargs(),
    )


@task(pre=[check_env])
def build_cpp(c, build_type="Release"):
    print_header(f"CMake configure & build ({build_type})")

    preset = f"conan-{build_type.lower()}"

    # Configure
    c.run(
        f"cmake --preset {preset} "
        f'-DPython_EXECUTABLE="{PYTHON}" '
        f'-DPython_ROOT_DIR="{Path(PYTHON).parent.parent}" '
        f"-DPython_FIND_STRATEGY=LOCATION "
        f"-DPython_FIND_REGISTRY=NEVER",
        **get_run_kwargs(),
    )

    # Build
    c.run(
        f"cmake --build --preset {preset}",
        **get_run_kwargs(),
    )


@task
def test_cpp(c, build_type="Release"):
    print_header("运行 C++ 测试")

    build_dir = BUILD_ROOT / build_type
    with c.cd(build_dir):
        c.run(
            f"ctest --output-on-failure -C {build_type}",
            **get_run_kwargs(),
        )


@task
def install_artifacts(c, build_type="Release"):
    print_header("安装 Python 扩展")

    build_dir = BUILD_ROOT / build_type

    for ext in ("*.so*", "*.pyd", "*.dll"):
        for f in INSTALL_PREFIX.glob(ext):
            f.unlink()

    c.run(
        f"cmake --install {build_dir} "
        f"--config {build_type} "
        f"--component python "
        f"--prefix {INSTALL_PREFIX} "
        f"--strip",
        **get_run_kwargs(),
    )

    (INSTALL_PREFIX / "py.typed").touch()

    if is_linux():
        for so in INSTALL_PREFIX.glob("*.so"):
            c.run(
                f"patchelf --set-rpath '$ORIGIN' {so}",
                **get_run_kwargs(),
            )


@task
def build_wheel(c):
    print_header("构建 Wheel")

    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)

    with c.cd(PYTHON_DIR):
        c.run(f'"{PYTHON}" -m hatch env prune', warn=True)
        c.run(f'"{PYTHON}" -m hatch build', **get_run_kwargs())


@task
def install_wheel(c):
    print_header("安装 Wheel")

    c.run(f'"{PYTHON}" -m pip uninstall -y {PACKAGE_NAME}', warn=True)

    wheels = sorted(
        DIST_DIR.glob("*.whl"),
        key=lambda f: f.stat().st_mtime,
        reverse=True,
    )

    if not wheels:
        raise Exit("未找到 wheel", code=1)

    c.run(
        f'"{PYTHON}" -m pip install {wheels[0]}',
        **get_run_kwargs(),
    )


@task
def test_python(c):
    print_header("Python 测试")

    test_dir = PROJECT_ROOT / "tests"
    if test_dir.exists():
        c.run(
            f'"{PYTHON}" -m pytest {test_dir} -v -s',
            **get_run_kwargs(),
        )


@task(default=True)
def build_all(c, build_type="Release"):
    check_env(c)
    install_deps(c, build_type)
    build_cpp(c, build_type)
    test_cpp(c, build_type)
    install_artifacts(c, build_type)
    build_wheel(c)
    install_wheel(c)
    test_python(c)

    print_header("构建完成")
