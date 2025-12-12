# python/signalux/__init__.py
import os
import sys

# -------------------------------------------------------------------------
# 1. 核心库路径引导 (Windows 必须，Linux 建议)
# -------------------------------------------------------------------------
# 获取当前包所在的文件夹路径
_package_path = os.path.dirname(__file__)

if sys.platform == "win32":
    # Windows Python 3.8+ 不再搜索 PATH，必须显式添加 DLL 目录
    if os.path.isdir(_package_path):
        os.add_dll_directory(_package_path)

# -------------------------------------------------------------------------
# 2. 导入扩展模块 (Facade 模式)
# -------------------------------------------------------------------------
# 尝试导入二进制扩展
# 注意：这里假设 .so/.pyd 文件已经由构建脚本复制到了当前目录下
try:
    from .signalux_pyext import *
except ImportError as e:
    # 抛出更清晰的错误，帮助调试路径问题
    raise ImportError(
        f"Critical: Failed to load SignaLux native extension from {_package_path}.\n"
        f"Ensure libsignalux_core and signalux_pyext are present.\n"
        f"Details: {e}"
    ) from e

# -------------------------------------------------------------------------
# 3. 导出定义
# -------------------------------------------------------------------------
# 如果 signalux_pyext.pyi 中定义了 __all__，这里会自动继承
# 或手动指定，例如：
__all__ = ["get_greeting"]
