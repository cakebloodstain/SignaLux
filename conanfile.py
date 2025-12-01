from conan import ConanFile

class SignaLuxConan(ConanFile):
    name = "signalux"
    version = "0.1.0"
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"

    def requirements(self):
        self.requires("entt/3.13.0")
        self.requires("spdlog/1.16.0")
        self.requires("fmt/12.1.0", override=True)
        self.requires("gtest/1.17.0")
