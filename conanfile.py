from conan import ConanFile
from conan.tools.cmake import cmake_layout
from conan.errors import ConanInvalidConfiguration


class SignaLuxConan(ConanFile):
    name = "signalux"
    version = "0.1.0"

    settings = "os", "compiler", "build_type", "arch"

    options = {
        "build_tests": [True, False],
    }

    default_options = {
        "build_tests": False,
    }

    generators = ("CMakeDeps", "CMakeToolchain")

    def layout(self):
        cmake_layout(self)

    def requirements(self):
        # 核心依赖
        self.requires("entt/3.13.0")
        self.requires("spdlog/1.16.0")
        self.requires("fmt/12.1.0", override=True)
        self.requires("concurrentqueue/1.0.4")
        self.requires("exprtk/0.0.3")
        self.requires("mp-units/2.3.0")
        self.requires("duckdb/1.1.3")
        self.requires("zeromq/4.3.5")
        self.requires("protobuf/5.27.0")

        # ✅ 测试依赖（关键）
        if self.options.build_tests:
            self.requires("gtest/1.17.0")
            self.requires("benchmark/1.7.1")
