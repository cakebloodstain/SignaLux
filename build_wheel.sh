#!/bin/bash
set -e

# This script automates the full build-test-package lifecycle for the SignaLux project.

# --- Configuration ---
BUILD_DIR="build"
PYTHON_DIR="python"
BUILD_TYPE="Release"

# --- Main Logic ---
echo ">>> [1/6] Cleaning up previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$PYTHON_DIR/dist"

echo ">>> [2/6] Installing C++ dependencies with Conan..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
conan install .. --build=missing -s build_type="$BUILD_TYPE"
cd ..

echo ">>> [3/6] Configuring the C++ project with CMake..."
CMAKE_TOOLCHAIN_FILE="$BUILD_DIR/$BUILD_TYPE/generators/conan_toolchain.cmake"
cmake -B "$BUILD_DIR" -S . \
    -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

echo ">>> [4/6] Building C++ code and Python extension..."
cmake --build "$BUILD_DIR"

echo ">>> [5/6] Running C++ and Python tests..."
# Run C++ tests
cd "$BUILD_DIR"
ctest --output-on-failure
cd ..
# Run Python tests
PYTHONPATH="$BUILD_DIR" pytest

echo ">>> [6/6] Building the Python wheel with Hatch..."
cd "$PYTHON_DIR"
hatch build

echo ""
echo "--- Lifecycle complete! ---"
echo "The Python wheel can be found in: $PYTHON_DIR/dist"
