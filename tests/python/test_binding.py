import sys
import os

# 将构建目录的路径添加到 sys.path
# __file__ 是当前脚本的路径 (e.g., .../SignaLux/tests/python/test_binding.py)
# os.path.dirname() 会给我们 .../SignaLux/tests/python
# 最终我们想到达 .../SignaLux/build
project_root = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
build_dir = os.path.join(project_root, 'build')
sys.path.append(build_dir)

try:
    import _signalux
    print("Successfully imported the '_signalux' module!")
    
    # 调用 C++ 库中的函数
    message = _signalux.get_greeting("Python Binding Test")
    print(f"Message from C++: {message}")
    
    # 验证返回的内容
    assert message == "Hello, Python Binding Test!"
    print("Python binding test passed!")
    
except ImportError as e:
    print(f"Failed to import the module: {e}")
    print(f"Please make sure the .so file is in the '{build_dir}' directory.")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
