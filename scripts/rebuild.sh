#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/build"

echo "Cleaning build directory: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

CMAKE_CMD="/Applications/CMake.app/Contents/bin/cmake"
if command -v cmake >/dev/null 2>&1; then
  CMAKE_CMD=cmake
fi

echo "Configuring..."
"$CMAKE_CMD" -S "$ROOT_DIR" -B "$BUILD_DIR" -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

echo "Building..."
"$CMAKE_CMD" --build "$BUILD_DIR" --config Release

echo "Build finished. To run tests: $BUILD_DIR/unit_tests"