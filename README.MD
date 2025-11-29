# SignaLux

SignaLux is a high-performance, cross-platform signal monitoring and triggering library, specifically designed for underlying driver layers in applications like autonomous driving and automotive tools. It is built with the C++20 standard to leverage modern features for maximum efficiency and safety.

## Key Features

- **Cross-Platform & Cross-Device**: Natively supports both Windows and Linux, with seamless integration for CAN hardware from vendors like VECTOR and ZLG.
- **Rich Python API**: Provides a comprehensive Python API via `nanobind`, allowing for easy scripting and integration into larger Python-based systems.
- **Advanced Event Triggering**: Offers a powerful event system to monitor various signal behaviors, including:
    - Value updates (any new value)
    - Value changes (only when the value is different)
    - Object creation notifications
- **Flexible Signal Support**: Natively handles both continuous signals (e.g., sensor readings) and event-driven signals.
- **Versatile Value Types**:
    - Standard types: `double`, `int`, `char`
    - Automotive standards: `8*uchar` (CAN) and `64*uchar` (CAN FD)
    - Non-standard types are automatically mapped to `numpy` types in Python for efficient numerical computation.

## Core Technologies

The library is built on a foundation of modern, high-performance C++ technologies:

- **Entity Component System**: `EnTT` for a flexible and cache-friendly design.
- **Python Bindings**: `nanobind` for lightweight, high-performance C++/Python interoperability.
- **Logging**: `spdlog` for fast, asynchronous logging.
- **Concurrency**: `moodycamel::ConcurrentQueue`, `std::jthread`, `std::variant`, and `std::syncstream` for robust, modern concurrent operations.
- **Package Management**: `Conan 2` for managing all C++ dependencies.

---

## Building the Python Wheel

This project uses a two-stage process, fully automated by a single script, to build the C++ core and package the Python bindings.

---

## Development Workflow

This project provides a fully automated script to handle the entire development lifecycle: building, testing, and packaging.

### Prerequisites

- A C++ compiler supporting C++20
- CMake (version 3.25 or later)
- Python (version 3.8 or later)
- Conan, Hatch, and Pytest (can be installed via pip)

```bash
pip install conan hatch pytest
```

### Unified Build & Test Script

The `build_wheel.sh` script is the single entry point for all development tasks.

**To build, test, and package everything, simply run:**
```bash
chmod +x build_wheel.sh
./build_wheel.sh
```

This script executes the full lifecycle:
1.  **Cleans** previous builds.
2.  **Installs** C++ dependencies via Conan.
3.  **Configures & Builds** the C++ project via CMake.
4.  **Runs** both C++ (`ctest`) and Python (`pytest`) tests against the build artifacts.
5.  **Packages** the final Python wheel using Hatch.

The resulting `.whl` file will be available in the `python/dist/` directory, ready for installation or distribution.

### Standalone Testing

If you have already built the project and only want to re-run the tests, you can execute the test commands manually:

- **C++ Tests**: `cd build && ctest`
- **Python Tests**: `PYTHONPATH=build pytest`
